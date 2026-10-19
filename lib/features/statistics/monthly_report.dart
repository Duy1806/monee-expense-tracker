import '../../data/models/expense.dart';
import '../dashboard/dashboard_stats.dart';

class MonthlyReport {
  const MonthlyReport({
    required this.month,
    required this.total,
    required this.count,
    required this.dayCount,
    required this.categories,
    required this.previousTotal,
  });

  /// Ngày mùng 1 của tháng báo cáo.
  final DateTime month;
  final double total;
  final int count;

  /// Số ngày dùng để tính trung bình: tháng hiện tại tính đến hôm nay,
  /// tháng đã qua tính đủ cả tháng.
  final int dayCount;
  final List<CategoryTotal> categories;
  final double previousTotal;

  double get averagePerDay => dayCount > 0 ? total / dayCount : 0;

  /// Thay đổi % so với tháng trước; null nếu tháng trước không chi gì.
  double? get changePercent {
    if (previousTotal <= 0) return null;

    return (total - previousTotal) / previousTotal * 100;
  }
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

MonthlyReport computeMonthlyReport(
  Iterable<Expense> expenses, {
  required DateTime month,
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final first = DateTime(month.year, month.month);
  final previous = DateTime(month.year, month.month - 1);

  var total = 0.0;
  var count = 0;
  var previousTotal = 0.0;
  final byCategory = <String, double>{};

  for (final expense in expenses) {
    final date = expense.date;

    if (date.year == first.year && date.month == first.month) {
      total += expense.amount;
      count++;
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0) + expense.amount;
    } else if (date.year == previous.year && date.month == previous.month) {
      previousTotal += expense.amount;
    }
  }

  final categories = byCategory.entries
      .map(
        (entry) => CategoryTotal(
          category: entry.key,
          amount: entry.value,
          share: total > 0 ? entry.value / total : 0,
        ),
      )
      .toList()
    ..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);

      return byAmount != 0 ? byAmount : a.category.compareTo(b.category);
    });

  final isCurrentMonth =
      reference.year == first.year && reference.month == first.month;

  return MonthlyReport(
    month: first,
    total: total,
    count: count,
    dayCount:
        isCurrentMonth ? reference.day : daysInMonth(first.year, first.month),
    categories: categories,
    previousTotal: previousTotal,
  );
}