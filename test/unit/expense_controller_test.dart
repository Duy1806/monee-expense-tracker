import 'dart:io';

import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/expenses/expense_filter.dart';
import 'package:expense_tracker/features/expenses/providers/expense_controller.dart';
import 'package:expense_tracker/services/receipt_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late ExpenseRepository repository;
  late ExpenseController controller;

  File makeImage(String name) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsBytesSync([1, 2, 3, 4]);
    return file;
  }

  int receiptCount() {
    final dir = Directory(p.join(baseDir.path, ReceiptStorageService.folderName));
    return dir.existsSync() ? dir.listSync().length : 0;
  }

  Future<void> bind(int userId) async {
    controller.bindUser(userId);
    await pumpEventQueue();
  }

  Future<Expense> seed(
    int userId, {
    String title = 'Seed',
    double amount = 10000,
    DateTime? date,
    String? receipt,
  }) {
    return repository.add(
      Expense(
        userId: userId,
        title: title,
        category: 'Ăn uống',
        amount: amount,
        date: date ?? DateTime.now(),
        receiptImagePath: receipt,
      ),
    );
  }

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    baseDir = Directory.systemTemp.createTempSync('monee_exp_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_exp_tmp_');

    final store = PrefsDataStore();
    repository = ExpenseRepository(store, SettingsRepository(store));

    controller = ExpenseController(
      repository,
      ReceiptStorageService(
        baseDirectoryProvider: () async => baseDir,
        temporaryDirectoryProvider: () async => tempDir,
      ),
    );
  });

  tearDown(() {
    controller.dispose();

    for (final dir in [baseDir, tempDir]) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Bỏ qua.
      }
    }
  });

  group('Tài khoản', () {
    test('chỉ tải giao dịch của tài khoản hiện tại và dọn khi đổi/đăng xuất', () async {
      await seed(1, title: 'A1');
      await seed(1, title: 'A2');
      await seed(2, title: 'B1');

      await bind(1);

      expect(controller.status, ExpenseLoadStatus.ready);
      expect(controller.allExpenses.map((e) => e.title).toSet(), {'A1', 'A2'});

      await bind(2);

      expect(controller.allExpenses.map((e) => e.title).toList(), ['B1']);

      controller.bindUser(null);

      expect(controller.allExpenses, isEmpty);
      expect(controller.status, ExpenseLoadStatus.idle);
    });

    test('chưa đăng nhập thì các thao tác báo lỗi', () async {
      final error = await controller.add(
        title: 'X',
        amount: 1000,
        category: 'Khác',
        date: DateTime.now(),
      );

      expect(error, isNotNull);
    });
  });

  group('Thêm', () {
    test('thêm giao dịch và sắp xếp mới nhất trước', () async {
      await bind(1);

      final now = DateTime.now();

      await controller.add(
        title: 'Cũ',
        amount: 1000,
        category: 'Khác',
        date: now.subtract(const Duration(days: 3)),
      );
      await controller.add(
        title: 'Mới',
        amount: 2000,
        category: 'Khác',
        date: now,
      );

      expect(controller.allExpenses.map((e) => e.title).toList(), ['Mới', 'Cũ']);
      expect(controller.total, 3000);
    });

    test('thêm kèm ảnh biên lai: lưu bền vững và dọn ảnh tạm', () async {
      await bind(1);

      final picked = makeImage('p.jpg');

      final error = await controller.add(
        title: 'Cơm',
        amount: 45000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: picked.path,
      );

      expect(error, isNull);

      final saved = controller.allExpenses.first;

      expect(saved.receiptImagePath, isNotNull);
      expect(File(saved.receiptImagePath!).existsSync(), isTrue);
      expect(
        p.isWithin(
          p.join(baseDir.path, ReceiptStorageService.folderName),
          saved.receiptImagePath!,
        ),
        isTrue,
      );
      expect(picked.existsSync(), isFalse);
      expect((await repository.getAll(1)).first.receiptImagePath,
          saved.receiptImagePath);
    });

    test('dữ liệu không hợp lệ: báo lỗi và không để lại ảnh', () async {
      await bind(1);

      final picked = makeImage('p.jpg');

      final error = await controller.add(
        title: 'Lỗi',
        amount: 0,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: picked.path,
      );

      expect(error, isNotNull);
      expect(controller.allExpenses, isEmpty);
      expect(receiptCount(), 0);
      expect(picked.existsSync(), isFalse);
    });
  });

  group('Sửa', () {
    test('sửa nội dung giữ nguyên ảnh biên lai', () async {
      await bind(1);

      await controller.add(
        title: 'Cũ',
        amount: 10000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: makeImage('a.jpg').path,
      );

      final original = controller.allExpenses.first;

      final error = await controller.update(
        original,
        title: 'Mới',
        amount: 20000,
        category: 'Hóa đơn',
        date: original.date,
      );

      final updated = controller.allExpenses.first;

      expect(error, isNull);
      expect(updated.title, 'Mới');
      expect(updated.amount, 20000);
      expect(updated.category, 'Hóa đơn');
      expect(updated.receiptImagePath, original.receiptImagePath);
      expect(File(updated.receiptImagePath!).existsSync(), isTrue);
    });

    test('thay ảnh biên lai: xóa ảnh cũ, giữ ảnh mới', () async {
      await bind(1);

      await controller.add(
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: makeImage('a.jpg').path,
      );

      final original = controller.allExpenses.first;
      final oldPath = original.receiptImagePath!;

      final error = await controller.update(
        original,
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: original.date,
        newReceiptSourcePath: makeImage('b.png').path,
      );

      final updated = controller.allExpenses.first;

      expect(error, isNull);
      expect(updated.receiptImagePath, isNot(oldPath));
      expect(File(oldPath).existsSync(), isFalse);
      expect(File(updated.receiptImagePath!).existsSync(), isTrue);
      expect(receiptCount(), 1);
    });

    test('gỡ ảnh biên lai', () async {
      await bind(1);

      await controller.add(
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: makeImage('a.jpg').path,
      );

      final original = controller.allExpenses.first;

      await controller.update(
        original,
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: original.date,
        removeReceipt: true,
      );

      expect(controller.allExpenses.first.receiptImagePath, isNull);
      expect(File(original.receiptImagePath!).existsSync(), isFalse);
    });

    test('sửa thất bại: giữ ảnh cũ và không để lại ảnh mới', () async {
      await bind(1);

      await controller.add(
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: makeImage('a.jpg').path,
      );

      final original = controller.allExpenses.first;

      final error = await controller.update(
        original,
        title: 'A',
        amount: -5,
        category: 'Ăn uống',
        date: original.date,
        newReceiptSourcePath: makeImage('b.png').path,
      );

      expect(error, isNotNull);
      expect(File(original.receiptImagePath!).existsSync(), isTrue);
      expect(receiptCount(), 1);
      expect(controller.allExpenses.first.amount, 10000);
    });
  });

  group('Xóa', () {
    test('xóa giao dịch và ảnh biên lai không còn ai dùng', () async {
      await bind(1);

      await controller.add(
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: makeImage('a.jpg').path,
      );

      final expense = controller.allExpenses.first;

      expect(await controller.delete(expense), isNull);
      expect(controller.allExpenses, isEmpty);
      expect(File(expense.receiptImagePath!).existsSync(), isFalse);
    });

    test('không xóa ảnh khi giao dịch khác vẫn tham chiếu', () async {
      await bind(1);

      await controller.add(
        title: 'A',
        amount: 10000,
        category: 'Ăn uống',
        date: DateTime.now(),
        receiptSourcePath: makeImage('a.jpg').path,
      );

      final first = controller.allExpenses.first;
      final sharedPath = first.receiptImagePath!;

      await seed(1, title: 'B', receipt: sharedPath);
      await controller.load();

      expect(await controller.delete(first), isNull);
      expect(File(sharedPath).existsSync(), isTrue);

      final second = controller.allExpenses.single;

      expect(await controller.delete(second), isNull);
      expect(File(sharedPath).existsSync(), isFalse);
    });

    test('không xóa được giao dịch của tài khoản khác', () async {
      final others = await seed(2, title: 'Của B');

      await bind(1);

      final error = await controller.delete(others);

      expect(error, isNotNull);
      expect(await repository.getAll(2), hasLength(1));
    });
  });

  group('Bộ lọc', () {
    test('tìm kiếm, danh mục, tổng theo bộ lọc và xóa bộ lọc', () async {
      await seed(1, title: 'Cà phê', amount: 30000);
      await repository.add(
        Expense(
          userId: 1,
          title: 'Tiền điện',
          category: 'Hóa đơn',
          amount: 400000,
          date: DateTime.now(),
        ),
      );

      await bind(1);

      expect(controller.visibleExpenses, hasLength(2));

      controller.setQuery('ca phe');

      expect(controller.visibleExpenses.map((e) => e.title).toList(), ['Cà phê']);
      expect(controller.visibleTotal, 30000);
      expect(controller.total, 430000);
      expect(controller.filter.isActive, isTrue);

      controller.clearFilters();
      controller.setCategory('Hóa đơn');

      expect(controller.visibleExpenses.map((e) => e.title).toList(), ['Tiền điện']);

      controller.setSort(ExpenseSort.amountAsc);

      expect(controller.filter.sort, ExpenseSort.amountAsc);
      expect(controller.filter.category, 'Hóa đơn');

      controller.clearFilters();

      expect(controller.filter.isActive, isFalse);
      expect(controller.visibleExpenses, hasLength(2));
    });

    test('đổi tài khoản thì xóa bộ lọc cũ', () async {
      await seed(1);
      await bind(1);

      controller.setQuery('abc');

      await bind(2);

      expect(controller.filter.isActive, isFalse);
    });
  });
}