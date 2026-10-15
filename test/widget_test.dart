
import 'package:flutter_test/flutter_test.dart';
import 'package:expense_tracker/data/expense_repository.dart';

void main() {
  group('Expense validation', () {
    final validExpense = Expense(
      title: 'Ăn trưa',
      category: 'Ăn uống',
      amount: 50000,
      date: DateTime.now(),
    );

    test('TC-01: Chấp nhận giao dịch hợp lệ', () {
      expect(validateExpense(validExpense), isNull);
    });

    test('TC-02: Từ chối tên giao dịch rỗng', () {
      final expense = Expense(
        title: '   ',
        category: 'Ăn uống',
        amount: 50000,
        date: DateTime.now(),
      );

      expect(validateExpense(expense), isNotNull);
    });

    test('TC-03: Từ chối số tiền bằng 0', () {
      final expense = Expense(
        title: 'Ăn trưa',
        category: 'Ăn uống',
        amount: 0,
        date: DateTime.now(),
      );

      expect(validateExpense(expense), isNotNull);
    });

    test('TC-04: Từ chối số tiền âm', () {
      final expense = Expense(
        title: 'Ăn trưa',
        category: 'Ăn uống',
        amount: -1000,
        date: DateTime.now(),
      );

      expect(validateExpense(expense), isNotNull);
    });

    test('Từ chối danh mục không hợp lệ', () {
      final expense = Expense(
        title: 'Ăn trưa',
        category: 'Không tồn tại',
        amount: 50000,
        date: DateTime.now(),
      );

      expect(validateExpense(expense), isNotNull);
    });
  });
}
