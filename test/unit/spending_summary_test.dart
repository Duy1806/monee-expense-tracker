import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/features/ai/spending_summary.dart';
import 'package:flutter_test/flutter_test.dart';

Expense ex(String title, String category, double amount, DateTime date) {
  return Expense(
    userId: 1,
    title: title,
    category: category,
    amount: amount,
    date: date,
  );
}

void main() {
  final now = DateTime(2026, 10, 18, 9);

  final data = <Expense>[
    ex('Chuyển tiền cho Nguyễn Văn A', 'Khác', 500000, DateTime(2026, 10, 10)),
    ex('Cà phê với bạn Lan', 'Ăn uống', 50000, DateTime(2026, 10, 18)),
    ex('Xe buýt', 'Di chuyển', 20000, DateTime(2026, 10, 17)),
    ex('Khoản tháng trước', 'Mua sắm', 100000, DateTime(2026, 9, 20)),
  ];

  test('không có giao dịch: hasData = false', () {
    final summary = buildSpendingSummary(const [], budget: 1000000, now: now);

    expect(summary.hasData, isFalse);
    expect(summary.text, isEmpty);
  });

  test('có số liệu tổng hợp đúng', () {
    final summary = buildSpendingSummary(data, budget: 1000000, now: now);

    expect(summary.hasData, isTrue);
    expect(summary.text, contains('Ngân sách tháng: 1000000 VND'));
    expect(summary.text, contains('Tổng chi tháng này: 570000 VND (3 giao dịch)'));
    expect(summary.text, contains('Còn lại so với ngân sách: 430000 VND'));
    expect(summary.text, contains('Tổng chi tháng trước: 100000 VND'));
    expect(summary.text, contains('- Khác: 500000 VND (88%)'));
    expect(summary.text, contains('- 2026-10-18: 50000 VND'));
  });

  test('không chứa tên giao dịch của người dùng', () {
    final summary = buildSpendingSummary(data, budget: 1000000, now: now);

    expect(summary.text, isNot(contains('Nguyễn Văn A')));
    expect(summary.text, isNot(contains('Lan')));
    expect(summary.text, isNot(contains('Xe buýt')));
    expect(summary.text, isNot(contains('Chuyển tiền')));
  });

  test('vượt ngân sách được ghi rõ', () {
    final summary = buildSpendingSummary(data, budget: 100000, now: now);

    expect(summary.text, contains('Đã vượt ngân sách: 470000 VND'));
  });

  test('khoản chi lớn nhất: sắp theo số tiền và giới hạn số lượng', () {
    final summary = buildSpendingSummary(
      data,
      budget: 1000000,
      now: now,
      maxLargest: 2,
    );

    final largest = summary.text.split('Các khoản chi lớn nhất').last;

    expect(largest, contains('2026-10-10; Khác; 500000 VND'));
    expect(largest, contains('2026-10-18; Ăn uống; 50000 VND'));
    expect(largest, isNot(contains('Di chuyển; 20000 VND')));
  });

  test('chỉ có dữ liệu tháng trước: vẫn hasData, tháng này bằng 0', () {
    final summary = buildSpendingSummary(
      [ex('Cũ', 'Mua sắm', 100000, DateTime(2026, 9, 20))],
      budget: 1000000,
      now: now,
    );

    expect(summary.hasData, isTrue);
    expect(summary.text, contains('Tổng chi tháng này: 0 VND (0 giao dịch)'));
    expect(summary.text, contains('(chưa có chi tiêu trong tháng này)'));
  });
}