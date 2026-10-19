import 'package:expense_tracker/core/constants/app_constants.dart';
import 'package:expense_tracker/core/constants/expense_categories.dart';
import 'package:expense_tracker/core/validators/expense_validator.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 18, 9, 0);

  String? check({
    String title = 'Ăn trưa',
    double amount = 50000,
    String category = 'Ăn uống',
    DateTime? date,
  }) {
    return validateExpenseFields(
      title: title,
      amount: amount,
      category: category,
      date: date ?? DateTime(2026, 10, 18),
      now: now,
    );
  }

  group('validateExpenseFields', () {
    test('TC-01: chấp nhận giao dịch hợp lệ', () {
      expect(check(), isNull);
    });

    test('TC-02: từ chối tên rỗng hoặc chỉ có khoảng trắng', () {
      expect(check(title: ''), isNotNull);
      expect(check(title: '   '), 'Tên giao dịch không được để trống.');
    });

    test('tên tối đa 120 ký tự', () {
      expect(check(title: 'a' * 120), isNull);
      expect(check(title: 'a' * 121), 'Tên giao dịch tối đa 120 ký tự.');
    });

    test('TC-03: từ chối số tiền bằng 0', () {
      expect(check(amount: 0), isNotNull);
    });

    test('TC-04: từ chối số tiền âm', () {
      expect(check(amount: -1000), isNotNull);
    });

    test('từ chối số tiền không hữu hạn', () {
      expect(check(amount: double.nan), isNotNull);
      expect(check(amount: double.infinity), isNotNull);
      expect(check(amount: double.negativeInfinity), isNotNull);
    });

    test('số tiền tối đa là kMaxMoneyAmount', () {
      expect(check(amount: kMaxMoneyAmount), isNull);
      expect(check(amount: kMaxMoneyAmount + 1), 'Số tiền quá lớn.');
    });

    test('TC-05: từ chối danh mục không hợp lệ', () {
      expect(check(category: 'Không tồn tại'), 'Danh mục không hợp lệ.');
      expect(check(category: ''), isNotNull);
    });

    test('chấp nhận mọi danh mục được hỗ trợ', () {
      for (final category in expenseCategories) {
        expect(check(category: category), isNull, reason: category);
      }
    });

    test('từ chối ngày trước năm 2000', () {
      expect(
        check(date: DateTime(1999, 12, 31)),
        'Ngày giao dịch không hợp lệ.',
      );
      expect(check(date: DateTime(2000, 1, 1)), isNull);
    });

    test('cho phép đến tối đa 1 ngày sau thời điểm hiện tại', () {
      expect(check(date: now.add(const Duration(days: 1))), isNull);
      expect(
        check(date: now.add(const Duration(days: 1, seconds: 1))),
        'Ngày giao dịch không hợp lệ.',
      );
    });
  });

  group('validateExpense', () {
    Expense build({String title = 'Ăn trưa', double amount = 50000}) {
      return Expense(
        userId: 1,
        title: title,
        category: 'Ăn uống',
        amount: amount,
        date: DateTime(2026, 10, 18),
      );
    }

    test('giao dịch hợp lệ', () {
      expect(validateExpense(build(), now: now), isNull);
    });

    test('giao dịch không hợp lệ trả về thông báo lỗi', () {
      expect(validateExpense(build(title: ' '), now: now), isNotNull);
      expect(validateExpense(build(amount: 0), now: now), isNotNull);
    });
  });
}