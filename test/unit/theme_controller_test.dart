import 'package:expense_tracker/core/theme/app_theme.dart';
import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/settings/providers/theme_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SettingsRepository settings;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = SettingsRepository(PrefsDataStore());
  });

  test('mặc định theo hệ thống', () async {
    final controller = ThemeController(settings);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('đổi chế độ rồi tạo controller mới vẫn giữ lựa chọn', () async {
    final first = ThemeController(settings);
    addTearDown(first.dispose);

    await first.setMode(ThemeMode.dark);

    final second = ThemeController(SettingsRepository(PrefsDataStore()));
    addTearDown(second.dispose);

    await second.load();

    expect(second.mode, ThemeMode.dark);

    await second.setMode(ThemeMode.light);

    final third = ThemeController(SettingsRepository(PrefsDataStore()));
    addTearDown(third.dispose);

    await third.load();

    expect(third.mode, ThemeMode.light);
  });

  test('giá trị lạ trong bộ nhớ được coi là hệ thống', () async {
    await settings.setString(SettingsKeys.themeMode, 'rainbow');

    final controller = ThemeController(settings);
    addTearDown(controller.dispose);

    await controller.load();

    expect(controller.mode, ThemeMode.system);
  });

  test('thông báo khi đổi, không thông báo khi chọn lại cùng chế độ',
      () async {
    final controller = ThemeController(settings);
    addTearDown(controller.dispose);

    var notifications = 0;

    controller.addListener(() => notifications++);

    await controller.setMode(ThemeMode.dark);
    await controller.setMode(ThemeMode.dark);

    expect(notifications, 1);
  });

  test('parse và encode khớp nhau', () {
    for (final mode in ThemeMode.values) {
      expect(ThemeController.parse(ThemeController.encode(mode)), mode);
    }

    expect(ThemeController.parse(null), ThemeMode.system);
  });

  group('AppTheme', () {
    test('có cả hai chế độ Material 3', () {
      final light = AppTheme.light();
      final dark = AppTheme.dark();

      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(
        light.scaffoldBackgroundColor,
        isNot(dark.scaffoldBackgroundColor),
      );
    });
  });
}