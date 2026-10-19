import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data_store.dart';
import 'migrations.dart';

class SqliteDataStore implements DataStore {
  SqliteDataStore._(this._db);

  final Database _db;

  /// Mở database. Khi test có thể truyền [factory] (ví dụ databaseFactoryFfi)
  /// và [path] (ví dụ inMemoryDatabasePath).
  static Future<SqliteDataStore> open({
    String? path,
    DatabaseFactory? factory,
  }) async {
    final dbFactory = factory ?? databaseFactory;
    final dbPath = path ??
        p.join(await dbFactory.getDatabasesPath(), kDatabaseFileName);

    final db = await dbFactory.openDatabase(
      dbPath,
      options: OpenDatabaseOptions(
        version: kDatabaseVersion,
        onCreate: (db, version) => createSchema(db),
        onUpgrade: (db, oldVersion, newVersion) =>
            migrateDatabase(db, oldVersion, newVersion),
      ),
    );

    return SqliteDataStore._(db);
  }

  ({String? clause, List<Object?> args}) _buildWhere(
    Map<String, Object?> where,
  ) {
    if (where.isEmpty) {
      return (clause: null, args: <Object?>[]);
    }

    final parts = <String>[];
    final args = <Object?>[];

    where.forEach((column, value) {
      ensureSafeIdentifier(column);

      if (value == null) {
        parts.add('$column IS NULL');
      } else {
        parts.add('$column = ?');
        args.add(value);
      }
    });

    return (clause: parts.join(' AND '), args: args);
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> where = const {},
    String? orderBy,
  }) async {
    ensureSafeIdentifier(table);

    final built = _buildWhere(where);
    final terms = parseOrderBy(orderBy);
    final order = terms.isEmpty
        ? null
        : terms
            .map((t) => '${t.column} ${t.descending ? 'DESC' : 'ASC'}')
            .join(', ');

    final rows = await _db.query(
      table,
      where: built.clause,
      whereArgs: built.args.isEmpty ? null : built.args,
      orderBy: order,
    );

    return rows.map((row) => Map<String, Object?>.from(row)).toList();
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values) {
    ensureSafeIdentifier(table);

    final data = Map<String, Object?>.of(values);

    if (data['id'] == null) {
      data.remove('id');
    }

    for (final column in data.keys) {
      ensureSafeIdentifier(column);
    }

    return _db.insert(table, data);
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required Map<String, Object?> where,
  }) {
    ensureSafeIdentifier(table);

    if (where.isEmpty) {
      throw ArgumentError('update bắt buộc có điều kiện where.');
    }

    final data = Map<String, Object?>.of(values)..remove('id');

    for (final column in data.keys) {
      ensureSafeIdentifier(column);
    }

    final built = _buildWhere(where);

    return _db.update(
      table,
      data,
      where: built.clause,
      whereArgs: built.args.isEmpty ? null : built.args,
    );
  }

  @override
  Future<int> delete(
    String table, {
    required Map<String, Object?> where,
  }) {
    ensureSafeIdentifier(table);

    if (where.isEmpty) {
      throw ArgumentError('delete bắt buộc có điều kiện where.');
    }

    final built = _buildWhere(where);

    return _db.delete(
      table,
      where: built.clause,
      whereArgs: built.args.isEmpty ? null : built.args,
    );
  }

  @override
  Future<void> close() async {
    if (_db.isOpen) {
      await _db.close();
    }
  }
}