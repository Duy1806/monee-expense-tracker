import 'package:flutter/foundation.dart';

import '../../../data/repositories/expense_repository.dart';

class LegacyClaimController extends ChangeNotifier {
  LegacyClaimController(this._expenses);

  final ExpenseRepository _expenses;

  int _pendingCount = 0;
  bool _busy = false;
  bool _dismissedThisSession = false;

  int get pendingCount => _pendingCount;
  bool get hasPending => _pendingCount > 0;
  bool get busy => _busy;

  /// Có nên hỏi người dùng ngay bây giờ hay không.
  bool get shouldPrompt => hasPending && !_dismissedThisSession;

  /// Kiểm tra lại số giao dịch cũ chưa có chủ.
  Future<void> refresh() async {
    try {
      final pending = await _expenses.isLegacyClaimPending();
      _pendingCount = pending ? await _expenses.countLegacy() : 0;
    } catch (_) {
      _pendingCount = 0;
    }

    notifyListeners();
  }

  /// Người dùng chọn "Để sau": không hỏi lại trong phiên làm việc này.
  void dismissForSession() {
    _dismissedThisSession = true;
    notifyListeners();
  }

  /// Gán dữ liệu cũ cho [userId]. Trả về số giao dịch đã nhận.
  Future<int> claim(int userId) async {
    if (_busy) return 0;

    _busy = true;
    notifyListeners();

    try {
      final count = await _expenses.claimLegacyExpenses(userId);
      _pendingCount = 0;
      return count;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}