import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../core/constants/app_constants.dart';
import '../../../data/repositories/budget_repository.dart';

class BudgetController extends ChangeNotifier {
  BudgetController(this._repository, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final BudgetRepository _repository;
  final DateTime Function() _clock;

  int? _userId;
  double? _amount;
  String? _errorMessage;
  int _loadToken = 0;
  bool _disposed = false;

  /// Ngân sách áp dụng cho tháng hiện tại.
  double get amount => _amount ?? kDefaultMonthlyBudget;

  bool get isLoaded => _amount != null;
  String? get errorMessage => _errorMessage;
  DateTime get month => _clock();

  void bindUser(int? userId) {
    if (_userId == userId) return;

    _loadToken++;
    _userId = userId;
    _amount = null;
    _errorMessage = null;

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

    try {
      final value = await _repository.getEffectiveAmount(userId, _clock());

      if (token != _loadToken || _userId != userId) return;

      _amount = value;
      _errorMessage = null;
    } catch (_) {
      if (token != _loadToken || _userId != userId) return;

      _errorMessage = 'Không thể tải ngân sách. Đang dùng mức mặc định.';
    }

    _notify();
  }

  /// Đặt ngân sách cho tháng hiện tại. Trả về null nếu thành công.
  Future<String?> setAmount(double value) async {
    final userId = _userId;

    if (userId == null) return 'Bạn chưa đăng nhập.';

    try {
      final saved = await _repository.setMonthlyBudget(
        userId: userId,
        month: _clock(),
        amount: value,
      );

      if (_userId == userId) {
        _amount = saved.amount;
        _errorMessage = null;
        _notify();
      }

      return null;
    } on ArgumentError catch (e) {
      final message = e.message;

      return message is String && message.isNotEmpty
          ? message
          : 'Ngân sách không hợp lệ.';
    } catch (_) {
      return 'Không thể lưu ngân sách. Vui lòng thử lại.';
    }
  }

  void _notify() {
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