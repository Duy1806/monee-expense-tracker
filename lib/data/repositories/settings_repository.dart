import '../database/data_store.dart';

class SettingsKeys {
  const SettingsKeys._();

  static const String themeMode = 'theme_mode';
  static const String sessionUserId = 'session_user_id';
  static const String legacyClaimedBy = 'legacy_claimed_by';
}

class SettingsRepository {
  SettingsRepository(this._store);

  final DataStore _store;

  Future<String?> getString(String key) async {
    final rows = await _store.query(tableAppSettings, where: {'key': key});

    if (rows.isEmpty) {
      return null;
    }

    return rows.first['value'] as String?;
  }

  Future<void> setString(String key, String value) async {
    final rows = await _store.query(tableAppSettings, where: {'key': key});

    if (rows.isEmpty) {
      await _store.insert(tableAppSettings, {'key': key, 'value': value});
      return;
    }

    await _store.update(
      tableAppSettings,
      {'value': value},
      where: {'key': key},
    );
  }

  Future<void> remove(String key) async {
    await _store.delete(tableAppSettings, where: {'key': key});
  }
}