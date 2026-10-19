import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/features/dashboard/dashboard_stats.dart';
import 'package:flutter_test/flutter_test.dart';

Expense ex(String category, double amount, DateTime date, {int? id}) {
  return Expense(
    id: id,
    userId: 1,
    title: 'giao dịch',
    category: category,
    amount: amount,
    date: date,
  );
}

void main() {
  // Chủ nhật 18/10/2026.
  final now = DateTime(2026, 10, 18, 9, 30);

  final sample = <Expense>[
    ex('Ăn uống', 50000, DateTime(2026, 10, 18), id: 1), // hôm nay
    ex('Di chuyển', 20000, DateTime(2026, 10, 17), id: 2),
    ex('Ăn uống', 30000, DateTime(2026, 10, 12), id: 3), // ngày đầu của 7 ngày
    ex('Mua sắm', 100000, DateTime(2026, 10, 11), id: 4), // 7 ngày trước đó
    ex('Ăn uống', 40000, DateTime(2026, 10, 5), id: 5), // đầu 7 ngày trước đó
    ex('Hóa đơn', 70000, DateTime(2026, 10, 4), id: 6), // ngoài 14 ngày, vẫn trong tháng
    ex('Ăn uống', 999999, DateTime(2026, 9, 30), id: 7), // tháng trước
  ];

  group('computeDashboardStats', () {
    late DashboardStats stats;

    setUp(() {
      stats = computeDashboardStats(sample, budget: 1000000, now: now);
    });

    test('tổng và số giao dịch của tháng hiện tại', () {
      // 50 + 20 + 30 + 100 + 40 + 70 = 310 nghìn; không tính tháng 9.
      expect(stats.monthTotal, 310000);
      expect(stats.monthCount, 6);
    });

    test('ngân sách còn lại và tỷ lệ đã dùng', () {
      expect(stats.budget, 1000000);
      expect(stats.remaining, 690000);
      expect(stats.usedRatio, closeTo(0.31, 1e-9));
      expect(stats.budgetLevel, BudgetLevel.ok);
    });

    test('chi tiêu hôm nay chỉ tính đúng ngày hiện tại', () {
      expect(stats.todayTotal, 50000);
    });

    test('7 ngày gần nhất đủ 7 phần tử, kể cả ngày không chi', () {
      expect(stats.last7Days, hasLength(7));
      expect(stats.last7Days.first.date, DateTime(2026, 10, 12));
      expect(stats.last7Days.last.date, DateTime(2026, 10, 18));
      expect(
        stats.last7Days.map((d) => d.amount).toList(),
        [30000, 0, 0, 0, 0, 20000, 50000],
      );
      expect(stats.maxDaily, 50000);
    });

    test('tổng 7 ngày gần nhất và 7 ngày trước đó', () {
      expect(stats.weekTotal, 100000);
      expect(stats.previousWeekTotal, 140000);
      expect(stats.weekChangePercent, closeTo(-28.571, 0.01));
    });

    test('danh mục trong tháng, nhiều nhất trước', () {
      expect(
        stats.categoryTotals.map((c) => c.category).toList(),
        ['Ăn uống', 'Mua sắm', 'Hóa đơn', 'Di chuyển'],
      );
      expect(stats.topCategory!.category, 'Ăn uống');
      expect(stats.topCategory!.amount, 120000);
      expect(stats.topCategory!.share, closeTo(120000 / 310000, 1e-9));

      final shares = stats.categoryTotals.fold<double>(
        0,
        (sum, c) => sum + c.share,
      );

      expect(shares, closeTo(1, 1e-9));
    });

    test('giao dịch gần đây mới nhất trước và giới hạn số lượng', () {
      expect(stats.recent, hasLength(5));
      expect(stats.recent.first.id, 1);
      expect(stats.recent.map((e) => e.id).toList(), [1, 2, 3, 4, 5]);
    });
  });

  group('trường hợp biên', () {
    test('không có giao dịch', () {
      final stats = computeDashboardStats(
        const [],
        budget: 500000,
        now: now,
      );

      expect(stats.hasAnyExpense, isFalse);
      expect(stats.monthTotal, 0);
      expect(stats.monthCount, 0);
      expect(stats.remaining, 500000);
      expect(stats.topCategory, isNull);
      expect(stats.recent, isEmpty);
      expect(stats.last7Days, hasLength(7));
      expect(stats.weekChangePercent, isNull);
      expect(stats.maxDaily, 0);
    });

    test('7 ngày trước đó không chi thì không có % thay đổi', () {
      final stats = computeDashboardStats(
        [ex('Ăn uống', 10000, DateTime(2026, 10, 18))],
        budget: 100000,
        now: now,
      );

      expect(stats.previousWeekTotal, 0);
      expect(stats.weekChangePercent, isNull);
    });

    test('ngày 11/10 thuộc 7 ngày trước, 12/10 thuộc 7 ngày này', () {
      final stats = computeDashboardStats(
        [
          ex('Ăn uống', 1000, DateTime(2026, 10, 12)),
          ex('Ăn uống', 2000, DateTime(2026, 10, 11)),
        ],
        budget: 100000,
        now: now,
      );

      expect(stats.weekTotal, 1000);
      expect(stats.previousWeekTotal, 2000);
    });

    test('đầu tháng: 7 ngày gần nhất kéo sang tháng trước', () {
      final firstOfMonth = DateTime(2026, 11, 2);
      final stats = computeDashboardStats(
        [
          ex('Ăn uống', 5000, DateTime(2026, 10, 30)),
          ex('Ăn uống', 7000, DateTime(2026, 11, 1)),
        ],
        budget: 100000,
        now: firstOfMonth,
      );

      expect(stats.monthTotal, 7000); // Chỉ tháng 11.
      expect(stats.weekTotal, 12000); // Cả hai nằm trong 7 ngày gần nhất.
      expect(stats.last7Days.first.date, DateTime(2026, 10, 27));
    });

    test('giao dịch ngày mai (được phép nhập) không vào 7 ngày gần nhất', () {
      final stats = computeDashboardStats(
        [ex('Ăn uống', 9000, DateTime(2026, 10, 19))],
        budget: 100000,
        now: now,
      );

      expect(stats.weekTotal, 0);
      expect(stats.monthTotal, 9000);
    });

    test('số tiền bằng nhau thì sắp theo tên danh mục để ổn định', () {
      final stats = computeDashboardStats(
        [
          ex('Mua sắm', 1000, DateTime(2026, 10, 18)),
          ex('Di chuyển', 1000, DateTime(2026, 10, 18)),
        ],
        budget: 100000,
        now: now,
      );

      expect(stats.topCategory!.category, 'Di chuyển');
    });
  });

  group('budgetLevelFor', () {
    test('dưới 80% là ok', () {
      expect(budgetLevelFor(790000, 1000000), BudgetLevel.ok);
    });

    test('từ đúng 80% đến hết ngân sách là warning', () {
      expect(budgetLevelFor(800000, 1000000), BudgetLevel.warning);
      expect(budgetLevelFor(1000000, 1000000), BudgetLevel.warning);
    });

    test('vượt ngân sách là exceeded', () {
      expect(budgetLevelFor(1000001, 1000000), BudgetLevel.exceeded);
    });

    test('ngân sách không hợp lệ', () {
      expect(budgetLevelFor(0, 0), BudgetLevel.ok);
      expect(budgetLevelFor(1, 0), BudgetLevel.exceeded);
    });
  });
}