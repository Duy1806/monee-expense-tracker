import 'dart:io';

import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/budget_repository.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/budget/providers/budget_controller.dart';
import 'package:expense_tracker/features/budget/screens/budget_screen.dart';
import 'package:expense_tracker/features/dashboard/screens/dashboard_screen.dart';
import 'package:expense_tracker/features/expenses/providers/expense_controller.dart';
import 'package:expense_tracker/features/statistics/screens/statistics_screen.dart';
import 'package:expense_tracker/services/receipt_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _userId = 1;

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late ExpenseRepository repository;
  late ExpenseController expenses;
  late BudgetController budget;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    baseDir = Directory.systemTemp.createTempSync('monee_dash_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_dash_tmp_');

    final store = PrefsDataStore();
    repository = ExpenseRepository(store, SettingsRepository(store));

    expenses = ExpenseController(
      repository,
      ReceiptStorageService(
        baseDirectoryProvider: () async => baseDir,
        temporaryDirectoryProvider: () async => tempDir,
      ),
    );
    budget = BudgetController(BudgetRepository(store));
  });

  tearDown(() {
    expenses.dispose();
    budget.dispose();

    for (final dir in [baseDir, tempDir]) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Bỏ qua.
      }
    }
  });

  Future<void> seedToday(
    WidgetTester tester,
    String category,
    double amount,
  ) async {
    final now = DateTime.now();

    await tester.runAsync(
      () => repository.add(
        Expense(
          userId: _userId,
          title: 'Khoản $category',
          category: category,
          amount: amount,
          date: DateTime(now.year, now.month, now.day),
        ),
      ),
    );
  }

  Future<void> bind(WidgetTester tester, {double? budgetAmount}) async {
    await tester.runAsync(() async {
      expenses.bindUser(_userId);
      budget.bindUser(_userId);
      await pumpEventQueue();

      if (budgetAmount != null) {
        await budget.setAmount(budgetAmount);
      }
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Widget wrap(Widget child) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseController>.value(value: expenses),
        ChangeNotifierProvider<BudgetController>.value(value: budget),
      ],
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  Widget host(Widget screen) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ExpenseController>.value(value: expenses),
        ChangeNotifierProvider<BudgetController>.value(value: budget),
      ],
      child: MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(builder: (_) => screen),
                  );
                },
                child: const Text('mở'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('DashboardScreen', () {
    testWidgets('chưa có giao dịch: hiện gợi ý thêm giao dịch', (tester) async {
      useTallSurface(tester);
      await bind(tester);

      await tester.pumpWidget(wrap(const DashboardScreen()));
      await settle(tester);

      expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
      expect(find.byKey(const Key('dashboard_month_total')), findsOneWidget);
      expect(find.text('0 đ'), findsWidgets);
    });

    testWidgets('có dữ liệu: tổng tháng, còn lại, danh mục, biểu đồ',
        (tester) async {
      useTallSurface(tester);
      await seedToday(tester, 'Ăn uống', 50000);
      await seedToday(tester, 'Di chuyển', 150000);
      await bind(tester, budgetAmount: 1000000);

      await tester.pumpWidget(wrap(const DashboardScreen()));
      await settle(tester);

      final total = tester.widget<Text>(
        find.byKey(const Key('dashboard_month_total')),
      );
      final remaining = tester.widget<Text>(
        find.byKey(const Key('dashboard_remaining')),
      );

      expect(total.data, '200.000 đ');
      expect(remaining.data, 'Còn 800.000 đ');

      expect(find.text('Chi tiêu theo danh mục'), findsOneWidget);
      expect(find.text('Chi tiêu 7 ngày gần nhất'), findsOneWidget);
      expect(find.text('Gần đây'), findsOneWidget);

      // Cả hai danh mục xuất hiện trong danh sách tỷ lệ.
      expect(find.textContaining('Di chuyển · 75%'), findsOneWidget);
      expect(find.textContaining('Ăn uống · 25%'), findsOneWidget);

      // Không có cảnh báo khi dùng dưới 80%.
      expect(find.textContaining('Đã vượt ngân sách'), findsNothing);
      expect(find.textContaining('Bạn đã dùng'), findsNothing);
    });

    testWidgets('dùng từ 80% ngân sách: cảnh báo sắp hết', (tester) async {
      useTallSurface(tester);
      await seedToday(tester, 'Ăn uống', 200000);
      await bind(tester, budgetAmount: 220000);

      await tester.pumpWidget(wrap(const DashboardScreen()));
      await settle(tester);

      expect(find.textContaining('Bạn đã dùng 91%'), findsOneWidget);
    });

    testWidgets('vượt ngân sách: cảnh báo vượt và hiện số tiền vượt',
        (tester) async {
      useTallSurface(tester);
      await seedToday(tester, 'Ăn uống', 200000);
      await bind(tester, budgetAmount: 150000);

      await tester.pumpWidget(wrap(const DashboardScreen()));
      await settle(tester);

      expect(find.textContaining('Đã vượt ngân sách 50.000 đ'), findsOneWidget);

      final remaining = tester.widget<Text>(
        find.byKey(const Key('dashboard_remaining')),
      );

      expect(remaining.data, 'Vượt 50.000 đ');
    });

    testWidgets('thêm giao dịch thì thống kê cập nhật ngay', (tester) async {
      useTallSurface(tester);
      await seedToday(tester, 'Ăn uống', 50000);
      await bind(tester, budgetAmount: 1000000);

      await tester.pumpWidget(wrap(const DashboardScreen()));
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard_month_total'))).data,
        '50.000 đ',
      );

      await tester.runAsync(() async {
        await expenses.add(
          title: 'Thêm',
          amount: 25000,
          category: 'Mua sắm',
          date: DateTime.now(),
        );
      });
      await settle(tester);

      expect(
        tester.widget<Text>(find.byKey(const Key('dashboard_month_total'))).data,
        '75.000 đ',
      );
    });
  });

  group('BudgetScreen', () {
    testWidgets('lưu ngân sách hợp lệ', (tester) async {
      useTallSurface(tester);
      await bind(tester);

      await tester.pumpWidget(host(const BudgetScreen()));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '5.000.000');
      await tester.tap(find.text('Lưu ngân sách'));
      await settle(tester);

      expect(budget.amount, 5000000);
      expect(
        tester.widget<Text>(find.byKey(const Key('budget_current_amount'))).data,
        '5.000.000 đ',
      );
    });

    testWidgets('từ chối 0 và số thập phân, không đổi dữ liệu',
        (tester) async {
      useTallSurface(tester);
      await bind(tester, budgetAmount: 4000000);

      await tester.pumpWidget(host(const BudgetScreen()));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField), '0');
      await tester.tap(find.text('Lưu ngân sách'));
      await tester.pump();

      expect(find.text('Ngân sách phải lớn hơn 0.'), findsOneWidget);

      await tester.enterText(find.byType(TextFormField), '1.5');
      await tester.tap(find.text('Lưu ngân sách'));
      await tester.pump();

      expect(find.textContaining('Số tiền không hợp lệ'), findsOneWidget);
      expect(budget.amount, 4000000);
    });
  });

  group('StatisticsScreen', () {
    testWidgets('hiện tổng tháng và chuyển sang tháng trước', (tester) async {
      useTallSurface(tester);
      await seedToday(tester, 'Ăn uống', 60000);
      await bind(tester);

      await tester.pumpWidget(host(const StatisticsScreen()));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      expect(
        tester.widget<Text>(find.byKey(const Key('statistics_total'))).data,
        '60.000 đ',
      );

      final now = DateTime.now();

      expect(
        tester.widget<Text>(find.byKey(const Key('statistics_month_label'))).data,
        'Tháng ${now.month}/${now.year}',
      );

      // Không thể sang tháng sau của tháng hiện tại.
      final next = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, Icons.chevron_right_rounded),
      );

      expect(next.onPressed, isNull);

      await tester.tap(find.byTooltip('Tháng trước'));
      await tester.pump();

      expect(
        tester.widget<Text>(find.byKey(const Key('statistics_total'))).data,
        '0 đ',
      );
      expect(find.text('Chưa có chi tiêu trong tháng này.'), findsOneWidget);
    });
  });
}