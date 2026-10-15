
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/data/expense_repository.dart';

void main() {
  late ExpenseRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = ExpenseRepository(useWebStorage: true);
  });

  tearDown(() async {
    await repository.close();
  });

  Expense makeExpense({
    String title = 'Ăn trưa',
    String category = 'Ăn uống',
    double amount = 50000,
    DateTime? date,
  }) {
    return Expense(
      title: title,
      category: category,
      amount: amount,
      date: date ?? DateTime.now(),
    );
  }

  group('ExpenseRepository - Web storage', () {
    test('TC-06: Thêm giao dịch và đọc lại được dữ liệu', () async {
      final saved = await repository.add(makeExpense());

      final expenses = await repository.getAll();

      expect(expenses, hasLength(1));
      expect(expenses.first.id, saved.id);
      expect(expenses.first.title, 'Ăn trưa');
      expect(expenses.first.amount, 50000);
      expect(expenses.first.category, 'Ăn uống');
    });

    test('TC-07: Dữ liệu vẫn còn sau khi tạo repository mới', () async {
      await repository.add(makeExpense());

      final anotherRepository =
          ExpenseRepository(useWebStorage: true);

      final expenses = await anotherRepository.getAll();

      expect(expenses, hasLength(1));
      expect(expenses.first.title, 'Ăn trưa');

      await anotherRepository.close();
    });

    test('Xóa giao dịch thì danh sách không còn giao dịch đó', () async {
      final saved = await repository.add(makeExpense());

      await repository.delete(saved.id!);

      final expenses = await repository.getAll();

      expect(expenses, isEmpty);
    });

    test('Từ chối giao dịch không hợp lệ và không lưu dữ liệu',
        () async {
      expect(
        () => repository.add(makeExpense(amount: 0)),
        throwsArgumentError,
      );

      expect(await repository.getAll(), isEmpty);
    });

    test('Tổng chi tiêu bằng tổng số tiền các giao dịch', () async {
      await repository.add(makeExpense(amount: 50000));
      await repository.add(
        makeExpense(title: 'Xe buýt', category: 'Di chuyển', amount: 10000),
      );

      final expenses = await repository.getAll();
      final total = expenses.fold<double>(
        0,
        (sum, expense) => sum + expense.amount,
      );

      expect(total, 60000);
    });
  });
}
