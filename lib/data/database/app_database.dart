import 'package:flutter/foundation.dart';

import 'data_store.dart';
import 'prefs_data_store.dart';
import 'sqlite_data_store.dart';

Future<DataStore> openAppDataStore() async {
  if (kIsWeb) {
    return PrefsDataStore();
  }

  return SqliteDataStore.open();
}