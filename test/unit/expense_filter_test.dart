import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/features/expenses/expense_filter.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _e(
  int id,
  String title,
  String category,
  double amount,
  DateTime date,
) {
  return Expense(
    id: id,
    userId: 1,
    title: title,
    category: category,
    amount: amount,
    date: date,
  );
}

void main() {
  final e1 = _e(1, 'Cà phê sáng', 'Ăn uống', 30000, DateTime(2026, 10, 1, 8));
  final e2 = _e(2, 'Grab đi làm', 'Di chuyển', 55000, DateTime(2026, 10, 3, 9));
  final e3 = _e(3, 'Cơm trưa', 'Ăn uống', 45000, DateTime(2026, 10, 3, 12));
  final e4 = _e(4, 'Tiền điện', 'Hóa đơn', 400000, DateTime(2026, 10, 10, 10));
  final e5 = _e(5, 'Áo thun', 'Mua sắm', 250000, DateTime(2026, 9, 28, 18));
  final all = [e1, e2, e3, e4, e5];

  List<int?> ids(List<Expense> list) => list.map((e) => e.id).toList();

  group('Sắp xếp', () {
    test('mặc định: ngày mới nhất trước', () {
      expect(ids(applyExpenseFilter(all, const ExpenseFilter())), [4, 3, 2, 1, 5]);
    });

    test('ngày cũ nhất trước', () {
      final result = applyExpenseFilter(
        all,
        const ExpenseFilter(sort: ExpenseSort.dateAsc),
      );

      expect(ids(result), [5, 1, 2, 3, 4]);
    });

    test('số tiền giảm dần', () {
      final result = applyExpenseFilter(
        all,
        const ExpenseFilter(sort: ExpenseSort.amountDesc),
      );

      expect(ids(result), [4, 5, 2, 3, 1]);
    });

    test('số tiền tăng dần', () {
      final result = applyExpenseFilter(
        all,
        const ExpenseFilter(sort: ExpenseSort.amountAsc),
      );

      expect(ids(result), [1, 3, 2, 5, 4]);
    });
  });

  group('Tìm kiếm', () {
    test('không phân biệt dấu và hoa thường', () {
      expect(ids(applyExpenseFilter(all, const ExpenseFilter(query: 'ca phe'))), [1]);
      expect(ids(applyExpenseFilter(all, const ExpenseFilter(query: 'CƠM'))), [3]);
      expect(ids(applyExpenseFilter(all, const ExpenseFilter(query: 'grab'))), [2]);
    });

    test('không có kết quả', () {
      expect(applyExpenseFilter(all, const ExpenseFilter(query: 'xyz')), isEmpty);
    });
  });

  group('Danh mục và khoảng ngày', () {
    test('lọc theo danh mục', () {
      final result = applyExpenseFilter(
        all,
        const ExpenseFilter(category: 'Ăn uống'),
      );

      expect(ids(result), [3, 1]);
    });

    test('khoảng ngày bao gồm cả ngày đầu và ngày cuối', () {
      final result = applyExpenseFilter(
        all,
        ExpenseFilter(start: DateTime(2026, 10, 3), end: DateTime(2026, 10, 3)),
      );

      expect(ids(result), [3, 2]);
    });

    test('chỉ có ngày bắt đầu', () {
      final result = applyExpenseFilter(
        all,
        ExpenseFilter(start: DateTime(2026, 10, 5)),
      );

      expect(ids(result), [4]);
    });

    test('chỉ có ngày kết thúc', () {
      final result = applyExpenseFilter(
        all,
        ExpenseFilter(end: DateTime(2026, 9, 30)),
      );

      expect(ids(result), [5]);
    });

    test('kết hợp danh mục và khoảng ngày', () {
      final result = applyExpenseFilter(
        all,
        ExpenseFilter(category: 'Ăn uống', start: DateTime(2026, 10, 2)),
      );

      expect(ids(result), [3]);
    });
  });

  group('Tổng và trạng thái bộ lọc', () {
    test('tổng theo bộ lọc', () {
      final filtered = applyExpenseFilter(
        all,
        const ExpenseFilter(category: 'Ăn uống'),
      );

      expect(sumAmount(filtered), 75000);
      expect(sumAmount(all), 780000);
      expect(sumAmount(const <Expense>[]), 0);
    });

    test('isActive và cleared', () {
      expect(const ExpenseFilter().isActive, isFalse);
      expect(const ExpenseFilter(query: '  ').isActive, isFalse);
      expect(const ExpenseFilter(query: 'a').isActive, isTrue);
      expect(const ExpenseFilter(category: 'Khác').isActive, isTrue);

      final cleared = const ExpenseFilter(
        query: 'a',
        category: 'Khác',
        sort: ExpenseSort.amountDesc,
      ).cleared();

      expect(cleared.isActive, isFalse);
      expect(cleared.sort, ExpenseSort.amountDesc);
    });

    test('withDateRange và withCategory giữ nguyên các trường còn lại', () {
      final filter = const ExpenseFilter(query: 'a')
          .withCategory('Khác')
          .withDateRange(DateTime(2026, 1, 1), null);

      expect(filter.query, 'a');
      expect(filter.category, 'Khác');
      expect(filter.start, DateTime(2026, 1, 1));
      expect(filter.end, isNull);
    });
  });
}