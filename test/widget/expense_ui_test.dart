import 'dart:io';

import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/expenses/providers/expense_controller.dart';
import 'package:expense_tracker/features/expenses/screens/expense_detail_screen.dart';
import 'package:expense_tracker/features/expenses/screens/expense_form_screen.dart';
import 'package:expense_tracker/features/expenses/screens/expense_list_screen.dart';
import 'package:expense_tracker/features/receipt_scanner/providers/receipt_scan_controller.dart';
import 'package:expense_tracker/features/receipt_scanner/screens/receipt_scanner_screen.dart';
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
  late ExpenseController controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    baseDir = Directory.systemTemp.createTempSync('monee_ui_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_ui_tmp_');

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

  Future<Expense> seed(
    WidgetTester tester, {
    required String title,
    required double amount,
    String category = 'Ăn uống',
  }) async {
    final saved = await tester.runAsync(
      () => repository.add(
        Expense(
          userId: _userId,
          title: title,
          category: category,
          amount: amount,
          date: DateTime.now(),
        ),
      ),
    );

    return saved!;
  }

  Future<void> bind(WidgetTester tester) async {
    await tester.runAsync(() async {
      controller.bindUser(_userId);
      await pumpEventQueue();
    });
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  Widget wrap(Widget child) {
    return ChangeNotifierProvider<ExpenseController>.value(
      value: controller,
      child: MaterialApp(home: Scaffold(body: child)),
    );
  }

  /// Màn hình chủ có nút mở [screen], để màn con thoát được bằng pop.
  Widget host(Widget screen) {
    return wrap(
      Builder(
        builder: (context) {
          return Center(
            child: ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<bool>(builder: (_) => screen),
                );
              },
              child: const Text('mở'),
            ),
          );
        },
      ),
    );
  }

  void useTallSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  group('ExpenseListScreen', () {
    testWidgets('chưa có dữ liệu: hiện trạng thái rỗng', (tester) async {
      await bind(tester);

      await tester.pumpWidget(wrap(const ExpenseListScreen()));
      await settle(tester);

      expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
    });

    testWidgets('hiện giao dịch và số lượng', (tester) async {
      await seed(tester, title: 'Cà phê sữa', amount: 30000);
      await seed(
        tester,
        title: 'Xe buýt',
        amount: 10000,
        category: 'Di chuyển',
      );
      await bind(tester);

      await tester.pumpWidget(wrap(const ExpenseListScreen()));
      await settle(tester);

      expect(find.text('Cà phê sữa'), findsOneWidget);
      expect(find.text('Xe buýt'), findsOneWidget);
      expect(find.text('2 giao dịch'), findsOneWidget);
      expect(find.text('40.000 đ'), findsOneWidget);
    });

    testWidgets('tìm kiếm không phân biệt dấu và báo khi không có kết quả',
        (tester) async {
      await seed(tester, title: 'Cà phê sữa', amount: 30000);
      await seed(
        tester,
        title: 'Xe buýt',
        amount: 10000,
        category: 'Di chuyển',
      );
      await bind(tester);

      await tester.pumpWidget(wrap(const ExpenseListScreen()));
      await settle(tester);

      await tester.enterText(
        find.byKey(const Key('expense_search_field')),
        'ca phe',
      );
      await tester.pump();

      expect(find.text('Cà phê sữa'), findsOneWidget);
      expect(find.text('Xe buýt'), findsNothing);
      expect(find.text('1 giao dịch'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('expense_search_field')),
        'zzzz',
      );
      await tester.pump();

      expect(find.text('Không có giao dịch phù hợp'), findsOneWidget);
    });
  });

  group('ExpenseFormScreen', () {
    testWidgets('để trống thì báo lỗi và không lưu', (tester) async {
      useTallSurface(tester);
      await bind(tester);

      await tester.pumpWidget(host(const ExpenseFormScreen()));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pump();

      expect(find.text('Tên giao dịch không được để trống.'), findsOneWidget);
      expect(find.textContaining('Số tiền không hợp lệ'), findsOneWidget);
      expect(controller.allExpenses, isEmpty);
    });

    testWidgets('số tiền bằng 0 bị từ chối', (tester) async {
      useTallSurface(tester);
      await bind(tester);

      await tester.pumpWidget(host(const ExpenseFormScreen()));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ăn trưa');
      await tester.enterText(find.byType(TextFormField).at(1), '0');
      await tester.tap(find.text('Lưu giao dịch'));
      await tester.pump();

      expect(find.text('Số tiền phải lớn hơn 0.'), findsOneWidget);
      expect(controller.allExpenses, isEmpty);
    });

    testWidgets('dữ liệu hợp lệ: lưu giao dịch và đóng form', (tester) async {
      useTallSurface(tester);
      await bind(tester);

      await tester.pumpWidget(host(const ExpenseFormScreen()));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextFormField).at(0), 'Ăn trưa');
      await tester.enterText(find.byType(TextFormField).at(1), '50.000');
      await tester.tap(find.text('Di chuyển'));
      await tester.pump();

      await tester.tap(find.text('Lưu giao dịch'));
      await settle(tester);

      expect(controller.allExpenses, hasLength(1));

      final saved = controller.allExpenses.first;

      expect(saved.title, 'Ăn trưa');
      expect(saved.amount, 50000);
      expect(saved.category, 'Di chuyển');
      expect(saved.userId, _userId);

      // Form đã đóng, quay lại màn chủ.
      expect(find.text('mở'), findsOneWidget);
    });
  });

  group('ExpenseDetailScreen', () {
    testWidgets('xóa có xác nhận', (tester) async {
      useTallSurface(tester);

      final saved = await seed(tester, title: 'Cà phê', amount: 30000);
      await bind(tester);

      await tester.pumpWidget(
        host(ExpenseDetailScreen(expenseId: saved.id!)),
      );
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      expect(find.text('Cà phê'), findsOneWidget);

      await tester.tap(find.byTooltip('Xóa'));
      await tester.pumpAndSettle();

      expect(find.text('Xóa giao dịch?'), findsOneWidget);

      // Hủy: giao dịch vẫn còn.
      await tester.tap(find.text('Hủy'));
      await tester.pumpAndSettle();

      expect(controller.allExpenses, hasLength(1));

      // Xóa thật.
      await tester.tap(find.byTooltip('Xóa'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Xóa'));
      await settle(tester);

      expect(controller.allExpenses, isEmpty);
      expect(find.text('mở'), findsOneWidget);
    });
  });

  group('ReceiptScannerScreen', () {
    testWidgets('quét thành công mở form xác nhận với dữ liệu gợi ý',
        (tester) async {
      useTallSurface(tester);
      await bind(tester);

      final scan = ReceiptScanController(
        pickImage: (_) async => '${tempDir.path}/khong-ton-tai.jpg',
        recognizeText: (_) async => '''
Highlands Coffee
Ngày: 15/10/2026
Tổng cộng: 65.000 VND
''',
      );
      addTearDown(scan.dispose);

      await tester.pumpWidget(host(ReceiptScannerScreen(controller: scan)));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chọn từ thư viện'));
      await settle(tester);

      expect(find.text('Xác nhận hóa đơn'), findsOneWidget);
      expect(find.text('Highlands Coffee'), findsOneWidget);
      expect(find.text('65000'), findsOneWidget);

      // OCR chỉ là gợi ý: chưa lưu gì cho tới khi người dùng xác nhận.
      expect(controller.allExpenses, isEmpty);
    });

    testWidgets('OCR thất bại: báo lỗi và cho nhập thủ công', (tester) async {
      useTallSurface(tester);
      await bind(tester);

      final scan = ReceiptScanController(
        pickImage: (_) async => '${tempDir.path}/khong-ton-tai.jpg',
        recognizeText: (_) async => throw Exception('lỗi OCR'),
      );
      addTearDown(scan.dispose);

      await tester.pumpWidget(host(ReceiptScannerScreen(controller: scan)));
      await tester.tap(find.text('mở'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chọn từ thư viện').first);
      await settle(tester);

      expect(find.textContaining('Không thể nhận dạng hóa đơn'), findsOneWidget);
      expect(find.text('Thử nhận dạng lại'), findsOneWidget);

      await tester.tap(find.textContaining('Nhập thủ công'));
      await settle(tester);

      expect(find.text('Xác nhận hóa đơn'), findsOneWidget);
      expect(controller.allExpenses, isEmpty);
    });
  });
}