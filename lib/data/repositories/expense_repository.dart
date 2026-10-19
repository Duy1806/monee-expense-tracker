import '../../core/validators/expense_validator.dart';
import '../database/data_store.dart';
import '../models/expense.dart';
import 'settings_repository.dart';

class ExpenseNotFoundException implements Exception {
  const ExpenseNotFoundException();

  @override
  String toString() => 'Không tìm thấy giao dịch hoặc bạn không có quyền sửa.';
}

class ExpenseRepository {
  ExpenseRepository(this._store, this._settings);

  final DataStore _store;
  final SettingsRepository _settings;

  static const String _orderNewestFirst = 'date DESC, id DESC';

  // ----------------------------------------------------------
  // ĐỌC
  // ----------------------------------------------------------

  Future<List<Expense>> getAll(int userId) async {
    final rows = await _store.query(
      tableExpenses,
      where: {'user_id': userId},
      orderBy: _orderNewestFirst,
    );

    return rows.map(Expense.fromMap).toList();
  }

  Future<Expense?> getById(int userId, int id) async {
    final rows = await _store.query(
      tableExpenses,
      where: {'id': id, 'user_id': userId},
    );

    if (rows.isEmpty) {
      return null;
    }

    return Expense.fromMap(rows.first);
  }

  Future<double> getTotal(int userId) async {
    final expenses = await getAll(userId);

    return expenses.fold<double>(0, (sum, item) => sum + item.amount);
  }

  // ----------------------------------------------------------
  // GHI
  // ----------------------------------------------------------

  Future<Expense> add(Expense expense) async {
    if (expense.userId <= 0) {
      throw ArgumentError('Thiếu tài khoản sở hữu giao dịch.');
    }

    final error = validateExpense(expense);

    if (error != null) {
      throw ArgumentError(error);
    }

    final now = DateTime.now();
    final toSave = expense.copyWith(
      title: expense.title.trim(),
      createdAt: now,
      updatedAt: now,
    );

    final values = toSave.toMap()..remove('id');
    final id = await _store.insert(tableExpenses, values);

    return toSave.copyWith(id: id);
  }

  Future<Expense> update(Expense expense) async {
    final id = expense.id;

    if (id == null) {
      throw ArgumentError('Thiếu ID giao dịch cần sửa.');
    }

    final error = validateExpense(expense);

    if (error != null) {
      throw ArgumentError(error);
    }

    final values = <String, Object?>{
      'title': expense.title.trim(),
      'category': expense.category,
      'amount': expense.amount,
      'date': expense.date.toIso8601String(),
      'receipt_image_path': expense.receiptImagePath,
      'updated_at': DateTime.now().toIso8601String(),
    };

    // Điều kiện user_id bảo đảm chỉ chủ sở hữu mới sửa được.
    final count = await _store.update(
      tableExpenses,
      values,
      where: {'id': id, 'user_id': expense.userId},
    );

    if (count == 0) {
      throw const ExpenseNotFoundException();
    }

    final saved = await getById(expense.userId, id);

    if (saved == null) {
      throw const ExpenseNotFoundException();
    }

    return saved;
  }

  /// Trả về giao dịch đã xóa (để nơi gọi dọn ảnh biên lai nếu không còn
  /// được tham chiếu), hoặc null nếu không tìm thấy / không thuộc tài khoản.
  Future<Expense?> delete({required int userId, required int id}) async {
    final existing = await getById(userId, id);

    if (existing == null) {
      return null;
    }

    await _store.delete(
      tableExpenses,
      where: {'id': id, 'user_id': userId},
    );

    return existing;
  }

  // ----------------------------------------------------------
  // ẢNH BIÊN LAI
  // ----------------------------------------------------------

  /// Đếm số giao dịch (của mọi tài khoản) đang tham chiếu tới [path].
  /// Cố ý không lọc theo user: chỉ dùng để quyết định có được xóa file ảnh.
  Future<int> countReceiptReferences(String path) async {
    final rows = await _store.query(
      tableExpenses,
      where: {'receipt_image_path': path},
    );

    return rows.length;
  }

  // ----------------------------------------------------------
  // DỮ LIỆU LEGACY (giao dịch từ phiên bản chưa có tài khoản)
  // ----------------------------------------------------------

  Future<int> countLegacy() async {
    final rows = await _store.query(
      tableExpenses,
      where: {'user_id': null},
    );

    return rows.length;
  }

  /// Có dữ liệu cũ và chưa từng được nhận về tài khoản nào.
  Future<bool> isLegacyClaimPending() async {
    final claimedBy = await _settings.getString(SettingsKeys.legacyClaimedBy);

    if (claimedBy != null) {
      return false;
    }

    return (await countLegacy()) > 0;
  }

  /// Gán toàn bộ giao dịch legacy cho [userId]. Chỉ chạy được một lần:
  /// sau đó cờ legacy_claimed_by được ghi và các lần gọi sau trả về 0.
  Future<int> claimLegacyExpenses(int userId) async {
    if (userId <= 0) {
      throw ArgumentError('Tài khoản không hợp lệ.');
    }

    final claimedBy = await _settings.getString(SettingsKeys.legacyClaimedBy);

    if (claimedBy != null) {
      return 0;
    }

    final count = await _store.update(
      tableExpenses,
      {'user_id': userId},
      where: {'user_id': null},
    );

    await _settings.setString(SettingsKeys.legacyClaimedBy, userId.toString());

    return count;
  }
}