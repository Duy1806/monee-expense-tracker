import 'dart:io';

import 'package:expense_tracker/app/app_dependencies.dart';
import 'package:expense_tracker/app/monee_app.dart';
import 'package:expense_tracker/core/security/password_hasher.dart';
import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/features/settings/providers/theme_controller.dart';
import 'package:expense_tracker/services/avatar_storage_service.dart';
import 'package:expense_tracker/services/gemini_service.dart';
import 'package:expense_tracker/services/receipt_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _NoAi implements SpendingAnalyzer {
  @override
  bool get isConfigured => false;

  @override
  Future<String> analyzeSpending({
    required String expenseData,
    required double monthlyBudget,
  }) async {
    throw const GeminiException(GeminiFailure.notConfigured, 'chưa cấu hình');
  }
}

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late AppDependencies deps;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    baseDir = Directory.systemTemp.createTempSync('monee_flow_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_flow_tmp_');

    deps = AppDependencies.create(
      store: PrefsDataStore(),
      analyzer: _NoAi(),
      hasher: const PasswordHasher(iterations: 1000, useIsolate: false),
      receiptStorage: ReceiptStorageService(
        baseDirectoryProvider: () async => baseDir,
        temporaryDirectoryProvider: () async => tempDir,
      ),
      avatarStorage: AvatarStorageService(
        baseDirectoryProvider: () async => baseDir,
        temporaryDirectoryProvider: () async => tempDir,
      ),
    );
  });

  tearDown(() {
    for (final dir in [baseDir, tempDir]) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Bỏ qua.
      }
    }
  });

  void useSurface(WidgetTester tester, {double width = 800}) {
    tester.view.physicalSize = Size(width, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 3; i++) {
      await tester.runAsync(() => pumpEventQueue());
      await tester.pump(const Duration(milliseconds: 100));
    }

    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> startApp(WidgetTester tester) async {
    await tester.pumpWidget(MonneeApp(dependencies: deps));
    await settle(tester);
  }

  Future<void> register(
    WidgetTester tester, {
    required String name,
    required String email,
  }) async {
    await tester.tap(find.text('Chưa có tài khoản? Đăng ký'));
    await settle(tester);

    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), name);
    await tester.enterText(fields.at(1), email);
    await tester.enterText(fields.at(2), 'matkhau123');
    await tester.enterText(fields.at(3), 'matkhau123');

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng ký'));
    await settle(tester);
  }

  Finder navItem(String label) {
    return find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );
  }

  Future<void> openProfileAndLogout(WidgetTester tester) async {
    await tester.tap(navItem('Hồ sơ'));
    await settle(tester);

    await tester.tap(find.widgetWithText(ListTile, 'Đăng xuất'));
    await settle(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Đăng xuất'));
    await settle(tester);
  }

  testWidgets('chưa đăng nhập: hiện màn đăng nhập', (tester) async {
    useSurface(tester);
    await startApp(tester);

    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('đăng ký, thêm giao dịch, thấy ở danh sách và dashboard',
      (tester) async {
    useSurface(tester);
    await startApp(tester);
    await register(tester, name: 'Duy', email: 'duy@example.com');

    // Đã vào khung chính.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Chưa có giao dịch nào'), findsOneWidget);

    // Thêm giao dịch qua nút "Thêm" → "Thêm thủ công".
    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.tap(find.text('Thêm thủ công'));
    await settle(tester);

    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'Cà phê sáng');
    await tester.enterText(fields.at(1), '45.000');
    await tester.tap(find.text('Lưu giao dịch'));
    await settle(tester);

    // Quay lại khung chính; dashboard cập nhật tổng tháng.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('dashboard_month_total'))).data,
      '45.000 đ',
    );

    // Tab Giao dịch hiển thị giao dịch vừa thêm.
    await tester.tap(navItem('Giao dịch'));
    await settle(tester);

    expect(find.text('Cà phê sáng'), findsOneWidget);
    expect(find.text('1 giao dịch'), findsOneWidget);
  });

  testWidgets('đăng xuất rồi đăng ký tài khoản khác: không thấy dữ liệu cũ',
      (tester) async {
    useSurface(tester);
    await startApp(tester);
    await register(tester, name: 'Người A', email: 'a@example.com');

    await tester.tap(find.byType(FloatingActionButton));
    await settle(tester);
    await tester.tap(find.text('Thêm thủ công'));
    await settle(tester);

    final fields = find.byType(TextFormField);

    await tester.enterText(fields.at(0), 'Khoản của A');
    await tester.enterText(fields.at(1), '70000');
    await tester.tap(find.text('Lưu giao dịch'));
    await settle(tester);

    await openProfileAndLogout(tester);

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Chưa có tài khoản? Đăng ký'), findsOneWidget);

    await register(tester, name: 'Người B', email: 'b@example.com');

    await tester.tap(navItem('Giao dịch'));
    await settle(tester);

    expect(find.text('Khoản của A'), findsNothing);
    expect(find.text('Chưa có giao dịch nào'), findsOneWidget);
  });

  testWidgets('đổi sang giao diện Tối và được lưu lại', (tester) async {
    useSurface(tester);
    await startApp(tester);
    await register(tester, name: 'Duy', email: 'duy@example.com');

    await tester.tap(find.byTooltip('Cài đặt'));
    await settle(tester);

    expect(find.text('Cài đặt'), findsWidgets);

    await tester.tap(find.text('Tối'));
    await settle(tester);

    final context = tester.element(find.byType(Scaffold).first);

    expect(Theme.of(context).brightness, Brightness.dark);

    // Khởi động lại "ứng dụng": lựa chọn vẫn được giữ.
    final reloaded = ThemeController(deps.settings);
    addTearDown(reloaded.dispose);

    await tester.runAsync(reloaded.load);

    expect(reloaded.mode, ThemeMode.dark);
  });

  testWidgets('màn rộng dùng thanh bên thay cho thanh dưới', (tester) async {
    useSurface(tester, width: 1200);
    await startApp(tester);
    await register(tester, name: 'Duy', email: 'duy@example.com');

    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}