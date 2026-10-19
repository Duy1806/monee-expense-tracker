import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../data/models/expense.dart';
import '../../../services/gemini_service.dart';
import '../spending_summary.dart';

enum AiStatus { idle, loading, success, error }

class AiController extends ChangeNotifier {
  AiController(this._analyzer, {DateTime Function()? clock})
      : _clock = clock ?? DateTime.now;

  final SpendingAnalyzer _analyzer;
  final DateTime Function() _clock;

  int? _userId;
  AiStatus _status = AiStatus.idle;
  String? _result;
  String? _errorMessage;
  DateTime? _analyzedAt;
  int _token = 0;
  bool _disposed = false;

  AiStatus get status => _status;
  String? get result => _result;
  String? get errorMessage => _errorMessage;
  DateTime? get analyzedAt => _analyzedAt;
  bool get isLoading => _status == AiStatus.loading;
  bool get isConfigured => _analyzer.isConfigured;

  /// Gắn với tài khoản hiện tại. Đổi tài khoản thì xóa kết quả cũ.
  void bindUser(int? userId) {
    if (_userId == userId) return;

    _token++;
    _userId = userId;
    _status = AiStatus.idle;
    _result = null;
    _errorMessage = null;
    _analyzedAt = null;

    scheduleMicrotask(_notify);
  }

  Future<void> analyze({
    required List<Expense> expenses,
    required double budget,
  }) async {
    if (isLoading || _userId == null) return;

    if (!_analyzer.isConfigured) {
      _fail(
        'Tính năng AI chưa được cấu hình. '
        'Hãy chạy ứng dụng với khóa Gemini API (xem README).',
      );
      return;
    }

    final summary = buildSpendingSummary(
      expenses,
      budget: budget,
      now: _clock(),
    );

    if (!summary.hasData) {
      _fail('Hãy thêm giao dịch trước khi phân tích nhé.');
      return;
    }

    final token = ++_token;

    _status = AiStatus.loading;
    _errorMessage = null;
    _notify();

    try {
      final text = await _analyzer.analyzeSpending(
        expenseData: summary.text,
        monthlyBudget: budget,
      );

      // Đã đổi tài khoản hoặc có lệnh mới hơn: bỏ kết quả này.
      if (token != _token) return;

      _result = text;
      _analyzedAt = _clock();
      _status = AiStatus.success;
    } on GeminiException catch (e) {
      if (token != _token) return;

      _errorMessage = e.message;
      _status = AiStatus.error;
    } catch (_) {
      if (token != _token) return;

      _errorMessage = 'Không thể phân tích lúc này. Vui lòng thử lại.';
      _status = AiStatus.error;
    }

    _notify();
  }

  void _fail(String message) {
    _errorMessage = message;
    _status = AiStatus.error;
    _notify();
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