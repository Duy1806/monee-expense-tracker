import 'dart:io';

import 'package:expense_tracker/data/database/data_store.dart';
import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/database/sqlite_data_store.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

class TestStore {
  TestStore({
    required this.store,
    required this.reopen,
    required this.dispose,
  });

  final DataStore store;

  /// Đóng store hiện tại rồi mở lại cùng nguồn dữ liệu (mô phỏng khởi động lại).
  final Future<DataStore> Function() reopen;

  final Future<void> Function() dispose;
}

Future<TestStore> createPrefsTestStore() async {
  SharedPreferences.setMockInitialValues({});

  return TestStore(
    store: PrefsDataStore(),
    reopen: () async => PrefsDataStore(),
    dispose: () async {},
  );
}

Future<TestStore> createSqliteTestStore() async {
  sqfliteFfiInit();

  final directory = Directory.systemTemp.createTempSync('monee_test_');
  final path = p.join(directory.path, 'test.db');
  final opened = <DataStore>[];

  Future<DataStore> open() async {
    final store = await SqliteDataStore.open(
      path: path,
      factory: databaseFactoryFfi,
    );
    opened.add(store);
    return store;
  }

  Future<void> closeAll() async {
    for (final store in opened) {
      await store.close();
    }
    opened.clear();
  }

  final first = await open();

  return TestStore(
    store: first,
    reopen: () async {
      await closeAll();
      return open();
    },
    dispose: () async {
      await closeAll();

      try {
        directory.deleteSync(recursive: true);
      } catch (_) {
        // Windows đôi khi còn khóa file; thư mục tạm không ảnh hưởng kết quả.
      }
    },
  );
}