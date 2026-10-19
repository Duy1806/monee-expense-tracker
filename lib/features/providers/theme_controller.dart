import 'package:flutter/material.dart';

import '../../../data/repositories/settings_repository.dart';

class ThemeController extends ChangeNotifier {
  ThemeController(this._settings);

  final SettingsRepository _settings;

  ThemeMode _mode = ThemeMode.system;
  bool _disposed = false;

  ThemeMode get mode => _mode;

  static ThemeMode parse(String? value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String encode(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  Future<void> load() async {
    try {
      _mode = parse(await _settings.getString(SettingsKeys.themeMode));
    } catch (_) {
      _mode = ThemeMode.system;
    }

    _notify();
  }

  /// Áp dụng ngay, rồi lưu. Nếu lưu lỗi thì chế độ vẫn đổi trong phiên này.
  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;

    _mode = mode;
    _notify();

    try {
      await _settings.setString(SettingsKeys.themeMode, encode(mode));
    } catch (_) {
      // Không chặn người dùng chỉ vì không lưu được cài đặt.
    }
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}