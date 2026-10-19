import 'dart:io';

import 'package:expense_tracker/data/database/data_store.dart';
import 'package:expense_tracker/data/database/sqlite_data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/budget_repository.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Directory tempDir;
  late String dbPath;
  final openedStores = <DataStore>[];

  setUpAll(sqfliteFfiInit);

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('monee_migration_');
    dbPath = p.join(tempDir.path, 'expense_tracker.db');
  });

  tearDown(() async {
    for (final store in openedStores) {
      await store.close();
    }
    openedStores.clear();

    try {
      tempDir.deleteSync(recursive: true);
    } catch (_) {
      // Bỏ qua nếu Windows còn khóa file tạm.
    }
  });

  Future<DataStore> openStore() async {
    final store = await SqliteDataStore.open(
      path: dbPath,
      factory: databaseFactoryFfi,
    );
    openedStores.add(store);
    return store;
  }

  /// Tạo database đúng schema v1 của bản cũ và chèn 2 giao dịch.
  Future<void> createVersion1Database() async {
    final db = await databaseFactoryFfi.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: 1,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE expenses (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              title TEXT NOT NULL,
              category TEXT NOT NULL,
              amount REAL NOT NULL CHECK(amount > 0),
              date TEXT NOT NULL
            )
          ''');
        },
      ),
    );

    await db.insert('expenses', {
      'title': 'Ăn trưa',
      'category': 'Ăn uống',
      'amount': 50000.0,
      'date': '2026-10-01T12:00:00.000',
    });
    await db.insert('expenses', {
      'title': 'Grab',
      'category': 'Di chuyển',
      'amount': 35000.0,
      'date': '2026-10-02T08:30:00.000',
    });

    await db.close();
  }

  group('Migration SQLite v1 → v2', () {
    test('giữ nguyên toàn bộ giao dịch cũ, user_id để trống', () async {
      await createVersion1Database();

      final store = await openStore();
      final rows = await store.query(tableExpenses, orderBy: 'id ASC');

      expect(rows, hasLength(2));
      expect(rows[0]['title'], 'Ăn trưa');
      expect(rows[0]['amount'], 50000.0);
      expect(rows[0]['date'], '2026-10-01T12:00:00.000');
      expect(rows[1]['title'], 'Grab');
      expect(rows[1]['category'], 'Di chuyển');
      expect(rows.every((row) => row['user_id'] == null), isTrue);
    });

    test('có đủ cột và bảng mới sau khi nâng cấp', () async {
      await createVersion1Database();

      final store = await openStore();

      final userId = await store.insert(tableUsers, {
        'name': 'An',
        'email': 'an@example.com',
        'password_hash': 'hash',
        'password_salt': 'salt',
        'avatar_path': null,
        'created_at': DateTime.now().toIso8601String(),
      });

      final settings = SettingsRepository(store);
      final expenses = ExpenseRepository(store, settings);
      final budgets = BudgetRepository(store);

      final saved = await expenses.add(
        Expense(
          userId: userId,
          title: 'Hóa đơn điện',
          category: 'Hóa đơn',
          amount: 400000,
          date: DateTime.now(),
          receiptImagePath: '/data/receipts/dien.jpg',
        ),
      );

      await budgets.setMonthlyBudget(
        userId: userId,
        month: DateTime(2026, 10, 1),
        amount: 7000000,
      );
      await settings.setString(SettingsKeys.themeMode, 'dark');

      expect(
        (await expenses.getById(userId, saved.id!))?.receiptImagePath,
        '/data/receipts/dien.jpg',
      );
      expect(
        await budgets.getEffectiveAmount(userId, DateTime(2026, 10, 18)),
        7000000,
      );
      expect(await settings.getString(SettingsKeys.themeMode), 'dark');
    });

    test('giao dịch cũ chưa thuộc ai, nhận được đúng một lần', () async {
      await createVersion1Database();

      final store = await openStore();
      final expenses = ExpenseRepository(store, SettingsRepository(store));

      expect(await expenses.countLegacy(), 2);
      expect(await expenses.getAll(1), isEmpty);
      expect(await expenses.isLegacyClaimPending(), isTrue);

      expect(await expenses.claimLegacyExpenses(1), 2);
      expect(await expenses.getAll(1), hasLength(2));

      expect(await expenses.claimLegacyExpenses(2), 0);
      expect(await expenses.getAll(2), isEmpty);
      expect(await expenses.isLegacyClaimPending(), isFalse);
    });

    test('mở lại database đã ở v2 không mất dữ liệu', () async {
      await createVersion1Database();

      final first = await openStore();
      final expenses = ExpenseRepository(first, SettingsRepository(first));

      await expenses.claimLegacyExpenses(1);
      await expenses.add(
        Expense(
          userId: 1,
          title: 'Mới',
          category: 'Khác',
          amount: 10000,
          date: DateTime.now(),
        ),
      );
      await first.close();
      openedStores.clear();

      final second = await openStore();
      final again = ExpenseRepository(second, SettingsRepository(second));

      expect(await again.getAll(1), hasLength(3));
    });

    test('database mới hoàn toàn tạo được đủ schema v2', () async {
      final store = await openStore();
      final expenses = ExpenseRepository(store, SettingsRepository(store));

      expect(await expenses.countLegacy(), 0);
      expect(await expenses.isLegacyClaimPending(), isFalse);

      final saved = await expenses.add(
        Expense(
          userId: 1,
          title: 'Cà phê',
          category: 'Ăn uống',
          amount: 30000,
          date: DateTime.now(),
        ),
      );

      expect(saved.id, isNotNull);
      expect(await expenses.getAll(1), hasLength(1));
    });
  });
}