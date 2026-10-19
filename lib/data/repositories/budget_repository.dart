import '../../core/constants/app_constants.dart';
import '../database/data_store.dart';
import '../models/budget.dart';

class BudgetRepository {
  BudgetRepository(this._store);

  final DataStore _store;

  static String monthKey(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');

    return '$year-$month';
  }

  /// Ngân sách đặt riêng cho đúng tháng [month], hoặc null.
  Future<Budget?> getForMonth(int userId, DateTime month) async {
    final rows = await _store.query(
      tableBudgets,
      where: {'user_id': userId, 'month': monthKey(month)},
    );

    if (rows.isEmpty) {
      return null;
    }

    return Budget.fromMap(rows.first);
  }

  /// Số tiền ngân sách áp dụng cho [month]:
  /// 1) đúng tháng đó; 2) tháng gần nhất trước đó; 3) mặc định.
  Future<double> getEffectiveAmount(int userId, DateTime month) async {
    final rows = await _store.query(
      tableBudgets,
      where: {'user_id': userId},
    );

    final key = monthKey(month);
    Budget? best;

    for (final row in rows) {
      final budget = Budget.fromMap(row);

      // So sánh chuỗi yyyy-MM cũng chính là so sánh thời gian.
      if (budget.month.compareTo(key) <= 0 &&
          (best == null || budget.month.compareTo(best.month) > 0)) {
        best = budget;
      }
    }

    return best?.amount ?? kDefaultMonthlyBudget;
  }

  Future<Budget> setMonthlyBudget({
    required int userId,
    required DateTime month,
    required double amount,
  }) async {
    if (userId <= 0) {
      throw ArgumentError('Tài khoản không hợp lệ.');
    }

    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('Ngân sách phải lớn hơn 0.');
    }

    if (amount > kMaxMoneyAmount) {
      throw ArgumentError('Ngân sách quá lớn.');
    }

    final key = monthKey(month);
    final existing = await _store.query(
      tableBudgets,
      where: {'user_id': userId, 'month': key},
    );

    if (existing.isEmpty) {
      final id = await _store.insert(tableBudgets, {
        'user_id': userId,
        'month': key,
        'amount': amount,
      });

      return Budget(id: id, userId: userId, month: key, amount: amount);
    }

    await _store.update(
      tableBudgets,
      {'amount': amount},
      where: {'user_id': userId, 'month': key},
    );

    return Budget(
      id: (existing.first['id'] as num?)?.toInt(),
      userId: userId,
      month: key,
      amount: amount,
    );
  }
}