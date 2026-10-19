import 'dart:convert';

import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/expenses/providers/legacy_claim_controller.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _legacyKey = PrefsDataStore.legacyExpensesKey;

String _legacyJson() {
  return jsonEncode([
    {
      'id': 1760000000000001,
      'title': 'Cũ 1',
      'category': 'Ăn uống',
      'amount': 45000.0,
      'date': '2026-09-20T10:00:00.000',
    },
    {
      'id': 1760000000000002,
      'title': 'Cũ 2',
      'category': 'Di chuyển',
      'amount': 25000.0,
      'date': '2026-09-21T10:00:00.000',
    },
  ]);
}

ExpenseRepository _repository() {
  final store = PrefsDataStore();
  return ExpenseRepository(store, SettingsRepository(store));
}

Expense _expense(int userId, {String title = 'Mới'}) {
  return Expense(
    userId: userId,
    title: title,
    category: 'Ăn uống',
    amount: 10000,
    date: DateTime.now(),
  );
}

void main() {
  group('Nhập dữ liệu Web cũ (chưa có tài khoản)', () {
    test('coi là giao dịch legacy, không tài khoản nào thấy', () async {
      SharedPreferences.setMockInitialValues({_legacyKey: _legacyJson()});
      final expenses = _repository();

      expect(await expenses.countLegacy(), 2);
      expect(await expenses.getAll(1), isEmpty);
      expect(await expenses.getAll(2), isEmpty);
    });

    test('thêm giao dịch mới không làm mất hay trộn dữ liệu cũ', () async {
      SharedPreferences.setMockInitialValues({_legacyKey: _legacyJson()});
      final expenses = _repository();

      await expenses.add(_expense(1));

      expect(await expenses.countLegacy(), 2);
      expect(await expenses.getAll(1), hasLength(1));
      expect(await expenses.getAll(2), isEmpty);

      // Khóa dữ liệu cũ vẫn còn nguyên, không bị xóa.
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString(_legacyKey), isNotNull);
    });

    test('nhận dữ liệu cũ về đúng một tài khoản', () async {
      SharedPreferences.setMockInitialValues({_legacyKey: _legacyJson()});
      final expenses = _repository();

      expect(await expenses.claimLegacyExpenses(1), 2);
      expect(await expenses.getAll(1), hasLength(2));
      expect(await expenses.getTotal(1), 70000);
      expect(await expenses.claimLegacyExpenses(2), 0);
      expect(await expenses.getAll(2), isEmpty);
    });

    test('dữ liệu cũ bị hỏng thì bỏ qua, ứng dụng vẫn dùng được', () async {
      SharedPreferences.setMockInitialValues({_legacyKey: 'khong phai json'});
      final expenses = _repository();

      expect(await expenses.countLegacy(), 0);

      await expenses.add(_expense(1));

      expect(await expenses.getAll(1), hasLength(1));
    });
  });

  group('Ghi đồng thời', () {
    test('30 lần thêm song song không tạo ID trùng và không mất dữ liệu', () async {
      SharedPreferences.setMockInitialValues({});
      final expenses = _repository();

      final saved = await Future.wait(
        List.generate(30, (i) => expenses.add(_expense(1, title: 'GD $i'))),
      );

      expect(saved.map((e) => e.id).toSet(), hasLength(30));
      expect(await expenses.getAll(1), hasLength(30));
    });
  });

  group('LegacyClaimController', () {
    test('refresh, từ chối trong phiên và nhận dữ liệu cũ', () async {
      SharedPreferences.setMockInitialValues({_legacyKey: _legacyJson()});
      final controller = LegacyClaimController(_repository());

      await controller.refresh();

      expect(controller.pendingCount, 2);
      expect(controller.shouldPrompt, isTrue);

      controller.dismissForSession();

      expect(controller.shouldPrompt, isFalse);
      expect(controller.hasPending, isTrue);

      expect(await controller.claim(1), 2);
      expect(controller.pendingCount, 0);
      expect(controller.hasPending, isFalse);
    });

    test('không có dữ liệu cũ thì không hỏi', () async {
      SharedPreferences.setMockInitialValues({});
      final controller = LegacyClaimController(_repository());

      await controller.refresh();

      expect(controller.shouldPrompt, isFalse);
    });
  });
}