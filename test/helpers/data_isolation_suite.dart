import 'package:expense_tracker/core/constants/app_constants.dart';
import 'package:expense_tracker/data/database/data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/budget_repository.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import 'test_stores.dart';

void runDataIsolationSuite(
  String label,
  Future<TestStore> Function() createTestStore,
) {
  group('Cách ly dữ liệu - $label', () {
    const userA = 1;
    const userB = 2;

    late TestStore env;
    late SettingsRepository settings;
    late ExpenseRepository expenses;
    late BudgetRepository budgets;

    setUp(() async {
      env = await createTestStore();
      settings = SettingsRepository(env.store);
      expenses = ExpenseRepository(env.store, settings);
      budgets = BudgetRepository(env.store);
    });

    tearDown(() => env.dispose());

    Expense newExpense(
      int userId, {
      String title = 'Ăn trưa',
      double amount = 50000,
      String category = 'Ăn uống',
      DateTime? date,
    }) {
      return Expense(
        userId: userId,
        title: title,
        category: category,
        amount: amount,
        date: date ?? DateTime.now(),
      );
    }

    Future<int> insertLegacy(String title, double amount) {
      return env.store.insert(tableExpenses, {
        'user_id': null,
        'title': title,
        'category': 'Ăn uống',
        'amount': amount,
        'date': DateTime(2026, 1, 5).toIso8601String(),
        'receipt_image_path': null,
        'created_at': null,
        'updated_at': null,
      });
    }

    // --------------------------------------------------------
    // GIAO DỊCH: ĐỌC
    // --------------------------------------------------------

    test('A chỉ thấy giao dịch của A, B chỉ thấy giao dịch của B', () async {
      await expenses.add(newExpense(userA, title: 'A-1'));
      await expenses.add(newExpense(userA, title: 'A-2'));
      await expenses.add(newExpense(userB, title: 'B-1'));

      final listA = await expenses.getAll(userA);
      final listB = await expenses.getAll(userB);

      expect(listA.map((e) => e.title).toSet(), {'A-1', 'A-2'});
      expect(listB.map((e) => e.title).toList(), ['B-1']);
      expect(listA.every((e) => e.userId == userA), isTrue);
    });

    test('A không đọc được giao dịch của B bằng ID', () async {
      final bExpense = await expenses.add(newExpense(userB, title: 'Của B'));

      expect(await expenses.getById(userA, bExpense.id!), isNull);
      expect((await expenses.getById(userB, bExpense.id!))?.title, 'Của B');
    });

    test('tổng chi tiêu không tính giao dịch của tài khoản khác', () async {
      await expenses.add(newExpense(userA, amount: 10000));
      await expenses.add(newExpense(userA, amount: 20000));
      await expenses.add(newExpense(userB, amount: 999000));

      expect(await expenses.getTotal(userA), 30000);
      expect(await expenses.getTotal(userB), 999000);
      expect(await expenses.getTotal(3), 0);
    });

    // --------------------------------------------------------
    // GIAO DỊCH: SỬA / XÓA
    // --------------------------------------------------------

    test('A không sửa được giao dịch của B', () async {
      final bExpense = await expenses.add(
        newExpense(userB, title: 'Của B', amount: 90000),
      );

      final attack = bExpense.copyWith(
        userId: userA,
        title: 'Bị sửa',
        amount: 1,
      );

      await expectLater(
        expenses.update(attack),
        throwsA(isA<ExpenseNotFoundException>()),
      );

      final stillB = await expenses.getById(userB, bExpense.id!);

      expect(stillB?.title, 'Của B');
      expect(stillB?.amount, 90000);
    });

    test('A không xóa được giao dịch của B', () async {
      final bExpense = await expenses.add(newExpense(userB, title: 'Của B'));

      final deleted = await expenses.delete(userId: userA, id: bExpense.id!);

      expect(deleted, isNull);
      expect(await expenses.getById(userB, bExpense.id!), isNotNull);
    });

    test('sửa giao dịch của chính mình: đổi nội dung, giữ ngày tạo', () async {
      final saved = await expenses.add(newExpense(userA, title: 'Cũ'));
      final before = await expenses.getById(userA, saved.id!);

      final updated = await expenses.update(
        saved.copyWith(title: '  Mới  ', amount: 70000, category: 'Hóa đơn'),
      );

      expect(updated.title, 'Mới');
      expect(updated.amount, 70000);
      expect(updated.category, 'Hóa đơn');
      expect(updated.createdAt, before?.createdAt);
    });

    test('xóa giao dịch của chính mình trả về giao dịch đã xóa', () async {
      final saved = await expenses.add(newExpense(userA, title: 'Sẽ xóa'));

      final deleted = await expenses.delete(userId: userA, id: saved.id!);

      expect(deleted?.title, 'Sẽ xóa');
      expect(await expenses.getAll(userA), isEmpty);
    });

    // --------------------------------------------------------
    // KIỂM TRA DỮ LIỆU ĐẦU VÀO
    // --------------------------------------------------------

    test('từ chối số tiền bằng 0, âm hoặc không hợp lệ', () async {
      for (final amount in [0.0, -1000.0, double.nan, double.infinity]) {
        await expectLater(
          expenses.add(newExpense(userA, amount: amount)),
          throwsArgumentError,
        );
      }

      expect(await expenses.getAll(userA), isEmpty);
    });

    test('từ chối tài khoản sở hữu không hợp lệ', () async {
      await expectLater(
        expenses.add(newExpense(0)),
        throwsArgumentError,
      );
    });

    // --------------------------------------------------------
    // BỀN VỮNG
    // --------------------------------------------------------

    test('dữ liệu còn nguyên sau khi mở lại database', () async {
      final saved = await expenses.add(newExpense(userA, title: 'Giữ lại'));

      final reopened = await env.reopen();
      final again = ExpenseRepository(reopened, SettingsRepository(reopened));
      final list = await again.getAll(userA);

      expect(list.map((e) => e.id).toList(), [saved.id]);
      expect(list.first.title, 'Giữ lại');
      expect(await again.getAll(userB), isEmpty);
    });

    // --------------------------------------------------------
    // NGÂN SÁCH
    // --------------------------------------------------------

    test('ngân sách tách riêng theo tài khoản và có quy tắc dự phòng', () async {
      final october = DateTime(2026, 10, 18);

      await budgets.setMonthlyBudget(
        userId: userA,
        month: DateTime(2026, 9, 1),
        amount: 5000000,
      );

      // Tháng chưa đặt dùng ngân sách của tháng gần nhất trước đó.
      expect(await budgets.getEffectiveAmount(userA, october), 5000000);

      // Trước tháng đã đặt thì dùng mặc định.
      expect(
        await budgets.getEffectiveAmount(userA, DateTime(2026, 8, 1)),
        kDefaultMonthlyBudget,
      );

      // Tài khoản khác không bị ảnh hưởng.
      expect(
        await budgets.getEffectiveAmount(userB, october),
        kDefaultMonthlyBudget,
      );

      // Đặt hai lần cho cùng một tháng thì cập nhật, không nhân bản.
      await budgets.setMonthlyBudget(
        userId: userA,
        month: october,
        amount: 6000000,
      );
      await budgets.setMonthlyBudget(
        userId: userA,
        month: october,
        amount: 6500000,
      );

      expect(await budgets.getEffectiveAmount(userA, october), 6500000);

      final rows = await env.store.query(
        tableBudgets,
        where: {'user_id': userA, 'month': '2026-10'},
      );

      expect(rows, hasLength(1));
    });

    test('từ chối ngân sách bằng 0 hoặc âm', () async {
      await expectLater(
        budgets.setMonthlyBudget(
          userId: userA,
          month: DateTime(2026, 10, 1),
          amount: 0,
        ),
        throwsArgumentError,
      );
      await expectLater(
        budgets.setMonthlyBudget(
          userId: userA,
          month: DateTime(2026, 10, 1),
          amount: -5,
        ),
        throwsArgumentError,
      );
    });

    // --------------------------------------------------------
    // DỮ LIỆU LEGACY
    // --------------------------------------------------------

    test('dữ liệu cũ chưa có chủ: không tài khoản nào thấy hay xóa được', () async {
      final legacyId = await insertLegacy('Cũ 1', 30000);
      await insertLegacy('Cũ 2', 20000);

      expect(await expenses.countLegacy(), 2);
      expect(await expenses.isLegacyClaimPending(), isTrue);

      expect(await expenses.getAll(userA), isEmpty);
      expect(await expenses.getAll(userB), isEmpty);
      expect(await expenses.getTotal(userA), 0);
      expect(await expenses.getById(userA, legacyId), isNull);
      expect(await expenses.delete(userId: userA, id: legacyId), isNull);
      expect(await expenses.countLegacy(), 2);
    });

    test('nhận dữ liệu cũ: chỉ một tài khoản, chỉ một lần', () async {
      await insertLegacy('Cũ 1', 30000);
      await insertLegacy('Cũ 2', 20000);

      expect(await expenses.claimLegacyExpenses(userA), 2);

      expect(await expenses.getAll(userA), hasLength(2));
      expect(await expenses.getTotal(userA), 50000);
      expect(await expenses.getAll(userB), isEmpty);

      // Tài khoản thứ hai không nhận thêm được gì.
      expect(await expenses.claimLegacyExpenses(userB), 0);
      expect(await expenses.getAll(userB), isEmpty);

      expect(await expenses.isLegacyClaimPending(), isFalse);
      expect(await expenses.countLegacy(), 0);
    });

    test('không còn dữ liệu cũ thì không có gì để nhận', () async {
      expect(await expenses.isLegacyClaimPending(), isFalse);
    });

    test('nhận dữ liệu cũ với tài khoản không hợp lệ bị từ chối', () async {
      await insertLegacy('Cũ 1', 30000);

      await expectLater(
        expenses.claimLegacyExpenses(0),
        throwsArgumentError,
      );

      expect(await expenses.countLegacy(), 1);
      expect(await expenses.isLegacyClaimPending(), isTrue);
    });
  });
}