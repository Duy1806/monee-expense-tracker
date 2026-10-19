import '../../data/models/expense.dart';
import '../expenses/expense_filter.dart';

/// Từ ngưỡng này trở lên (so với ngân sách) thì cảnh báo "sắp hết".
const double kBudgetWarningRatio = 0.8;

enum BudgetLevel { ok, warning, exceeded }

BudgetLevel budgetLevelFor(double spent, double budget) {
  if (budget <= 0) {
    return spent > 0 ? BudgetLevel.exceeded : BudgetLevel.ok;
  }

  if (spent > budget) return BudgetLevel.exceeded;
  if (spent / budget >= kBudgetWarningRatio) return BudgetLevel.warning;

  return BudgetLevel.ok;
}

class CategoryTotal {
  const CategoryTotal({
    required this.category,
    required this.amount,
    required this.share,
  });

  final String category;
  final double amount;

  /// Tỷ lệ trên tổng (0..1).
  final double share;
}

class DailyTotal {
  const DailyTotal({required this.date, required this.amount});

  /// Chỉ có phần ngày (00:00).
  final DateTime date;
  final double amount;
}

class DashboardStats {
  const DashboardStats({
    required this.now,
    required this.monthTotal,
    required this.monthCount,
    required this.budget,
    required this.todayTotal,
    required this.last7Days,
    required this.weekTotal,
    required this.previousWeekTotal,
    required this.categoryTotals,
    required this.recent,
    required this.hasAnyExpense,
  });

  final DateTime now;
  final double monthTotal;
  final int monthCount;
  final double budget;
  final double todayTotal;

  /// 7 ngày gần nhất, cũ nhất trước, phần tử cuối là hôm nay.
  final List<DailyTotal> last7Days;
  final double weekTotal;
  final double previousWeekTotal;

  /// Chi tiêu theo danh mục trong tháng, nhiều nhất trước.
  final List<CategoryTotal> categoryTotals;
  final List<Expense> recent;
  final bool hasAnyExpense;

  /// Ngân sách còn lại; âm nghĩa là đã vượt.
  double get remaining => budget - monthTotal;

  double get usedRatio => budget > 0 ? monthTotal / budget : 0;

  BudgetLevel get budgetLevel => budgetLevelFor(monthTotal, budget);

  CategoryTotal? get topCategory =>
      categoryTotals.isEmpty ? null : categoryTotals.first;

  /// Thay đổi % so với 7 ngày trước đó; null nếu trước đó không chi gì.
  double? get weekChangePercent {
    if (previousWeekTotal <= 0) return null;

    return (weekTotal - previousWeekTotal) / previousWeekTotal * 100;
  }

  double get maxDaily {
    var max = 0.0;

    for (final day in last7Days) {
      if (day.amount > max) max = day.amount;
    }

    return max;
  }
}

int _dayKey(DateTime d) => d.year * 10000 + d.month * 100 + d.day;

DashboardStats computeDashboardStats(
  Iterable<Expense> expenses, {
  required double budget,
  DateTime? now,
  int recentCount = 5,
}) {
  final reference = now ?? DateTime.now();
  final today = DateTime(reference.year, reference.month, reference.day);

  // Ngày đầu của 7 ngày gần nhất và của 7 ngày liền trước.
  final weekStart = DateTime(today.year, today.month, today.day - 6);
  final previousWeekStart = DateTime(today.year, today.month, today.day - 13);

  final days = <DateTime>[
    for (var i = 0; i < 7; i++)
      DateTime(weekStart.year, weekStart.month, weekStart.day + i),
  ];
  final dailyByKey = <int, double>{for (final d in days) _dayKey(d): 0};

  final todayKey = _dayKey(today);
  final weekStartKey = _dayKey(weekStart);
  final previousWeekStartKey = _dayKey(previousWeekStart);

  var monthTotal = 0.0;
  var monthCount = 0;
  var todayTotal = 0.0;
  var weekTotal = 0.0;
  var previousWeekTotal = 0.0;
  var any = false;
  final byCategory = <String, double>{};
  final all = <Expense>[];

  for (final expense in expenses) {
    any = true;
    all.add(expense);

    final date = expense.date;
    final key = _dayKey(date);
    final amount = expense.amount;

    if (date.year == today.year && date.month == today.month) {
      monthTotal += amount;
      monthCount++;
      byCategory[expense.category] =
          (byCategory[expense.category] ?? 0) + amount;
    }

    if (key == todayKey) {
      todayTotal += amount;
    }

    if (key >= weekStartKey && key <= todayKey) {
      weekTotal += amount;

      if (dailyByKey.containsKey(key)) {
        dailyByKey[key] = dailyByKey[key]! + amount;
      }
    } else if (key >= previousWeekStartKey && key < weekStartKey) {
      previousWeekTotal += amount;
    }
  }

  final categories = byCategory.entries
      .map(
        (entry) => CategoryTotal(
          category: entry.key,
          amount: entry.value,
          share: monthTotal > 0 ? entry.value / monthTotal : 0,
        ),
      )
      .toList()
    ..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);

      return byAmount != 0 ? byAmount : a.category.compareTo(b.category);
    });

  all.sort(compareExpensesNewestFirst);

  return DashboardStats(
    now: reference,
    monthTotal: monthTotal,
    monthCount: monthCount,
    budget: budget,
    todayTotal: todayTotal,
    last7Days: [
      for (final d in days) DailyTotal(date: d, amount: dailyByKey[_dayKey(d)]!),
    ],
    weekTotal: weekTotal,
    previousWeekTotal: previousWeekTotal,
    categoryTotals: categories,
    recent: all.take(recentCount).toList(),
    hasAnyExpense: any,
  );
}