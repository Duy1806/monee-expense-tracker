import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/features/statistics/monthly_report.dart';
import 'package:flutter_test/flutter_test.dart';

Expense ex(String category, double amount, DateTime date) {
  return Expense(
    userId: 1,
    title: 'giao dịch',
    category: category,
    amount: amount,
    date: date,
  );
}

void main() {
  final now = DateTime(2026, 10, 18);

  final data = <Expense>[
    ex('Ăn uống', 60000, DateTime(2026, 10, 3)),
    ex('Ăn uống', 40000, DateTime(2026, 10, 10)),
    ex('Di chuyển', 50000, DateTime(2026, 10, 18)),
    ex('Mua sắm', 100000, DateTime(2026, 9, 20)),
    ex('Ăn uống', 100000, DateTime(2026, 8, 1)),
  ];

  group('computeMonthlyReport', () {
    test('tháng hiện tại: tổng, số lượng, trung bình tính đến hôm nay', () {
      final report = computeMonthlyReport(
        data,
        month: DateTime(2026, 10, 1),
        now: now,
      );

      expect(report.total, 150000);
      expect(report.count, 3);
      expect(report.dayCount, 18);
      expect(report.averagePerDay, closeTo(150000 / 18, 1e-9));
    });

    test('so sánh với tháng trước', () {
      final report = computeMonthlyReport(
        data,
        month: DateTime(2026, 10, 1),
        now: now,
      );

      expect(report.previousTotal, 100000);
      expect(report.changePercent, closeTo(50, 1e-9));
    });

    test('theo danh mục, nhiều nhất trước', () {
      final report = computeMonthlyReport(
        data,
        month: DateTime(2026, 10, 1),
        now: now,
      );

      expect(report.categories.map((c) => c.category).toList(),
          ['Ăn uống', 'Di chuyển']);
      expect(report.categories.first.amount, 100000);
      expect(report.categories.first.share, closeTo(100000 / 150000, 1e-9));
    });

    test('tháng đã qua tính trung bình trên đủ số ngày của tháng', () {
      final report = computeMonthlyReport(
        data,
        month: DateTime(2026, 9, 15),
        now: now,
      );

      expect(report.month, DateTime(2026, 9));
      expect(report.total, 100000);
      expect(report.dayCount, 30);
      // Tháng 8 có 100000 → tháng 9 bằng đúng 0% thay đổi.
      expect(report.previousTotal, 100000);
      expect(report.changePercent, closeTo(0, 1e-9));
    });

    test('tháng không có dữ liệu', () {
      final report = computeMonthlyReport(
        data,
        month: DateTime(2026, 1, 1),
        now: now,
      );

      expect(report.total, 0);
      expect(report.count, 0);
      expect(report.categories, isEmpty);
      expect(report.changePercent, isNull);
      expect(report.dayCount, 31);
    });

    test('qua năm: tháng 1 so sánh với tháng 12 năm trước', () {
      final report = computeMonthlyReport(
        [
          ex('Ăn uống', 10000, DateTime(2026, 1, 5)),
          ex('Ăn uống', 20000, DateTime(2025, 12, 31)),
        ],
        month: DateTime(2026, 1, 1),
        now: now,
      );

      expect(report.total, 10000);
      expect(report.previousTotal, 20000);
      expect(report.changePercent, closeTo(-50, 1e-9));
    });
  });

  group('daysInMonth', () {
    test('tháng 2 năm nhuận và không nhuận', () {
      expect(daysInMonth(2024, 2), 29);
      expect(daysInMonth(2026, 2), 28);
      expect(daysInMonth(2026, 12), 31);
    });
  });
}