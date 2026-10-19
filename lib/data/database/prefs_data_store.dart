import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'data_store.dart';

class PrefsDataStore implements DataStore {
    PrefsDataStore([this._preferences]);

  static const String keyPrefix = 'monee_store_v2_';

  /// Khóa của bản Web cũ (chưa có user_id).
  static const String legacyExpensesKey = 'expense_tracker_transactions_v1';

  SharedPreferences? _preferences;
  Future<void> _tail = Future<void>.value();

  Future<SharedPreferences> _prefs() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  /// Thực thi tuần tự để các thao tác đọc-sửa-ghi không ghi đè lẫn nhau.
  Future<T> _synchronized<T>(Future<T> Function() action) {
    final completer = Completer<T>();
    final previous = _tail;

    _tail = completer.future.then<void>((_) {}, onError: (Object _) {});

    previous.then<void>((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });

    return completer.future;
  }

  Future<List<Map<String, Object?>>> _load(String table) async {
    final prefs = await _prefs();
    final raw = prefs.getString('$keyPrefix$table');

    if (raw == null) {
      if (table == tableExpenses) {
        return _readLegacyExpenses(prefs);
      }
      return [];
    }

    final decoded = jsonDecode(raw) as List<dynamic>;

    return decoded
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList();
  }

  List<Map<String, Object?>> _readLegacyExpenses(SharedPreferences prefs) {
    final raw = prefs.getString(legacyExpensesKey);

    if (raw == null || raw.isEmpty) {
      return [];
    }

    try {
      final decoded = jsonDecode(raw) as List<dynamic>;

      return decoded.map<Map<String, Object?>>((item) {
        final map = Map<String, Object?>.from(item as Map);

        return {
          'id': map['id'],
          'user_id': null,
          'title': map['title'],
          'category': map['category'],
          'amount': map['amount'],
          'date': map['date'],
          'receipt_image_path': null,
          'created_at': null,
          'updated_at': null,
        };
      }).toList();
    } catch (_) {
      // Dữ liệu cũ hỏng: bỏ qua, không làm ứng dụng dừng.
      return [];
    }
  }

  Future<void> _save(String table, List<Map<String, Object?>> rows) async {
    final prefs = await _prefs();
    final ok = await prefs.setString('$keyPrefix$table', jsonEncode(rows));

    if (!ok) {
      throw StateError('Không thể lưu dữ liệu vào bộ nhớ trình duyệt.');
    }
  }

  bool _matches(Map<String, Object?> row, Map<String, Object?> where) {
    for (final entry in where.entries) {
      if (row[entry.key] != entry.value) {
        return false;
      }
    }
    return true;
  }

  int _compare(Object? a, Object? b) {
    if (a == null && b == null) return 0;
    if (a == null) return -1;
    if (b == null) return 1;

    if (a is num && b is num) {
      return a.compareTo(b);
    }

    return a.toString().compareTo(b.toString());
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> where = const {},
    String? orderBy,
  }) {
    return _synchronized(() async {
      ensureSafeIdentifier(table);

      final terms = parseOrderBy(orderBy);
      final rows =
          (await _load(table)).where((row) => _matches(row, where)).toList();

      if (terms.isNotEmpty) {
        rows.sort((a, b) {
          for (final term in terms) {
            final result = _compare(a[term.column], b[term.column]);

            if (result != 0) {
              return term.descending ? -result : result;
            }
          }
          return 0;
        });
      }

      return rows;
    });
  }

  @override
  Future<int> insert(String table, Map<String, Object?> values) {
    return _synchronized(() async {
      ensureSafeIdentifier(table);

      final rows = await _load(table);
      var maxId = 0;

      for (final row in rows) {
        final id = row['id'];

        if (id is num && id > maxId) {
          maxId = id.toInt();
        }
      }

      final newId = maxId + 1;
      final row = Map<String, Object?>.of(values);
      row['id'] = newId;

      rows.add(row);
      await _save(table, rows);

      return newId;
    });
  }

  @override
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required Map<String, Object?> where,
  }) {
    return _synchronized(() async {
      ensureSafeIdentifier(table);

      if (where.isEmpty) {
        throw ArgumentError('update bắt buộc có điều kiện where.');
      }

      final rows = await _load(table);
      final changes = Map<String, Object?>.of(values)..remove('id');
      var count = 0;

      for (final row in rows) {
        if (_matches(row, where)) {
          row.addAll(changes);
          count++;
        }
      }

      if (count > 0) {
        await _save(table, rows);
      }

      return count;
    });
  }

  @override
  Future<int> delete(
    String table, {
    required Map<String, Object?> where,
  }) {
    return _synchronized(() async {
      ensureSafeIdentifier(table);

      if (where.isEmpty) {
        throw ArgumentError('delete bắt buộc có điều kiện where.');
      }

      final rows = await _load(table);
      final before = rows.length;

      rows.removeWhere((row) => _matches(row, where));

      final removed = before - rows.length;

      if (removed > 0) {
        await _save(table, rows);
      }

      return removed;
    });
  }

  @override
  Future<void> close() async {}
}