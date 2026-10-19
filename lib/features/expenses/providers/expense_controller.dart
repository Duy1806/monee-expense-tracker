import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/expense.dart';
import '../../../data/repositories/expense_repository.dart';
import '../../../services/receipt_storage_service.dart';
import '../expense_filter.dart';

enum ExpenseLoadStatus { idle, loading, ready, error }

class ExpenseController extends ChangeNotifier {
  ExpenseController(this._repository, this._receipts);

  final ExpenseRepository _repository;
  final ReceiptStorageService _receipts;

  static const String _notLoggedIn = 'Bạn chưa đăng nhập.';

  int? _userId;
  List<Expense> _all = const [];
  ExpenseLoadStatus _status = ExpenseLoadStatus.idle;
  String? _errorMessage;
  ExpenseFilter _filter = const ExpenseFilter();
  List<Expense>? _visibleCache;
  int _loadToken = 0;
  bool _disposed = false;

  ExpenseLoadStatus get status => _status;
  String? get errorMessage => _errorMessage;
  ExpenseFilter get filter => _filter;
  int? get userId => _userId;

  /// Toàn bộ giao dịch của tài khoản hiện tại, mới nhất trước.
  List<Expense> get allExpenses => List.unmodifiable(_all);

  /// Giao dịch sau khi áp dụng tìm kiếm, lọc và sắp xếp.
  List<Expense> get visibleExpenses =>
      _visibleCache ??= applyExpenseFilter(_all, _filter);

  double get total => sumAmount(_all);
  double get visibleTotal => sumAmount(visibleExpenses);

  // ----------------------------------------------------------
  // TÀI KHOẢN
  // ----------------------------------------------------------

  /// Gắn controller với tài khoản hiện tại. Gọi lặp lại với cùng một
  /// [userId] là vô hại. Không gọi notifyListeners đồng bộ.
  void bindUser(int? userId) {
    if (_userId == userId) return;

    _loadToken++;
    _userId = userId;
    _all = const [];
    _visibleCache = null;
    _filter = const ExpenseFilter();
    _errorMessage = null;
    _status =
        userId == null ? ExpenseLoadStatus.idle : ExpenseLoadStatus.loading;

    if (userId != null) {
      scheduleMicrotask(() {
        load();
      });
    }
  }

  Future<void> load() async {
    final userId = _userId;

    if (userId == null) return;

    final token = ++_loadToken;

    _status = ExpenseLoadStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      final items = await _repository.getAll(userId);

      // Bỏ kết quả cũ nếu đã đổi tài khoản hoặc có lệnh tải mới hơn.
      if (token != _loadToken || _userId != userId) return;

      _all = items;
      _status = ExpenseLoadStatus.ready;
    } catch (_) {
      if (token != _loadToken || _userId != userId) return;

      _status = ExpenseLoadStatus.error;
      _errorMessage = 'Không thể tải giao dịch. Vui lòng thử lại.';
    }

    _notify();
  }

  // ----------------------------------------------------------
  // CRUD — trả về null nếu thành công, hoặc thông báo lỗi.
  // ----------------------------------------------------------

  Future<String?> add({
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? receiptSourcePath,
  }) async {
    final userId = _userId;

    if (userId == null) return _notLoggedIn;

    String? storedReceipt;

    try {
      if (receiptSourcePath != null) {
        storedReceipt = await _receipts.saveReceipt(
          userId: userId,
          sourcePath: receiptSourcePath,
        );
      }

      final saved = await _repository.add(
        Expense(
          userId: userId,
          title: title,
          category: category,
          amount: amount,
          date: date,
          receiptImagePath: storedReceipt,
        ),
      );

      if (_userId == userId) {
        _all = _sorted([..._all, saved]);
        _notify();
      }

      return null;
    } on ReceiptStorageException catch (e) {
      return e.message;
    } on ArgumentError catch (e) {
      await _deleteReceiptIfUnreferenced(storedReceipt);
      return _messageOf(e);
    } catch (_) {
      await _deleteReceiptIfUnreferenced(storedReceipt);
      return 'Không thể lưu giao dịch. Vui lòng thử lại.';
    } finally {
      if (receiptSourcePath != null) {
        await _receipts.discardTemporary(receiptSourcePath);
      }
    }
  }

  /// [newReceiptSourcePath]: ảnh biên lai mới (thay ảnh cũ).
  /// [removeReceipt]: gỡ ảnh biên lai hiện có (bị bỏ qua nếu có ảnh mới).
  Future<String?> update(
    Expense original, {
    required String title,
    required double amount,
    required String category,
    required DateTime date,
    String? newReceiptSourcePath,
    bool removeReceipt = false,
  }) async {
    final userId = _userId;

    if (userId == null) return _notLoggedIn;

    String? newStored;

    try {
      if (newReceiptSourcePath != null) {
        newStored = await _receipts.saveReceipt(
          userId: userId,
          sourcePath: newReceiptSourcePath,
        );
      }

      final String? receiptPath =
          newStored ?? (removeReceipt ? null : original.receiptImagePath);

      // Luôn ép userId hiện tại: không thể sửa dữ liệu tài khoản khác.
      final saved = await _repository.update(
        original.copyWith(
          userId: userId,
          title: title,
          category: category,
          amount: amount,
          date: date,
          receiptImagePath: receiptPath,
          clearReceiptImage: receiptPath == null,
        ),
      );

      if (_userId == userId) {
        _all = _sorted(_all.map((e) => e.id == saved.id ? saved : e));
        _notify();
      }

      final oldPath = original.receiptImagePath;

      if (oldPath != null && oldPath != saved.receiptImagePath) {
        await _deleteReceiptIfUnreferenced(oldPath);
      }

      return null;
    } on ReceiptStorageException catch (e) {
      return e.message;
    } on ExpenseNotFoundException {
      await _deleteReceiptIfUnreferenced(newStored);
      return 'Không tìm thấy giao dịch.';
    } on ArgumentError catch (e) {
      await _deleteReceiptIfUnreferenced(newStored);
      return _messageOf(e);
    } catch (_) {
      await _deleteReceiptIfUnreferenced(newStored);
      return 'Không thể cập nhật giao dịch. Vui lòng thử lại.';
    } finally {
      if (newReceiptSourcePath != null) {
        await _receipts.discardTemporary(newReceiptSourcePath);
      }
    }
  }

  Future<String?> delete(Expense expense) async {
    final userId = _userId;
    final id = expense.id;

    if (userId == null) return _notLoggedIn;
    if (id == null) return 'Không tìm thấy ID giao dịch để xóa.';

    try {
      final deleted = await _repository.delete(userId: userId, id: id);

      if (deleted == null) {
        await load();
        return 'Không tìm thấy giao dịch.';
      }

      if (_userId == userId) {
        _all = _all.where((e) => e.id != id).toList();
        _notify();
      }

      await _deleteReceiptIfUnreferenced(deleted.receiptImagePath);

      return null;
    } catch (_) {
      return 'Không thể xóa giao dịch. Vui lòng thử lại.';
    }
  }

  /// Dọn ảnh tạm khi người dùng hủy trước khi lưu (ví dụ đóng form quét).
  Future<void> discardTemporaryImage(String path) {
    return _receipts.discardTemporary(path);
  }

  // ----------------------------------------------------------
  // BỘ LỌC
  // ----------------------------------------------------------

  void setQuery(String query) => _applyFilter(_filter.copyWith(query: query));

  void setCategory(String? category) {
    _applyFilter(_filter.withCategory(category));
  }

  void setDateRange(DateTime? start, DateTime? end) {
    _applyFilter(_filter.withDateRange(start, end));
  }

  void setSort(ExpenseSort sort) => _applyFilter(_filter.copyWith(sort: sort));

  void clearFilters() => _applyFilter(_filter.cleared());

  // ----------------------------------------------------------
  // NỘI BỘ
  // ----------------------------------------------------------

  void _applyFilter(ExpenseFilter filter) {
    _filter = filter;
    _notify();
  }

  List<Expense> _sorted(Iterable<Expense> items) {
    final list = items.toList()..sort(compareExpensesNewestFirst);

    return list;
  }

  String _messageOf(ArgumentError error) {
    final message = error.message;

    return message is String && message.isNotEmpty
        ? message
        : 'Dữ liệu không hợp lệ.';
  }

  Future<void> _deleteReceiptIfUnreferenced(String? path) async {
    if (path == null) return;

    await _receipts.deleteIfUnreferenced(
      path,
      _repository.countReceiptReferences,
    );
  }

  void _notify() {
    _visibleCache = null;

    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}