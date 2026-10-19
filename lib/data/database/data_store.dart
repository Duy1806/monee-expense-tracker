const String tableUsers = 'users';
const String tableExpenses = 'expenses';
const String tableBudgets = 'budgets';
const String tableAppSettings = 'app_settings';

abstract class DataStore {
  /// [where]: các cặp cột = giá trị, nối bằng AND. Giá trị null nghĩa là IS NULL.
  /// [orderBy]: ví dụ 'date DESC, id DESC'.
  Future<List<Map<String, Object?>>> query(
    String table, {
    Map<String, Object?> where = const {},
    String? orderBy,
  });

  /// Trả về id (rowid) của dòng mới.
  Future<int> insert(String table, Map<String, Object?> values);

  /// [where] bắt buộc không rỗng. Trả về số dòng bị ảnh hưởng.
  Future<int> update(
    String table,
    Map<String, Object?> values, {
    required Map<String, Object?> where,
  });

  /// [where] bắt buộc không rỗng. Trả về số dòng bị xóa.
  Future<int> delete(
    String table, {
    required Map<String, Object?> where,
  });

  Future<void> close();
}

final RegExp _safeIdentifier = RegExp(r'^[a-z_][a-z0-9_]*$');

void ensureSafeIdentifier(String name) {
  if (!_safeIdentifier.hasMatch(name)) {
    throw ArgumentError.value(name, 'identifier', 'Tên bảng/cột không hợp lệ.');
  }
}

class OrderTerm {
  const OrderTerm(this.column, this.descending);

  final String column;
  final bool descending;
}

List<OrderTerm> parseOrderBy(String? orderBy) {
  if (orderBy == null || orderBy.trim().isEmpty) {
    return const [];
  }

  return orderBy.split(',').map((part) {
    final tokens = part.trim().split(RegExp(r'\s+'));

    if (tokens.isEmpty || tokens.length > 2) {
      throw ArgumentError.value(
        orderBy,
        'orderBy',
        'Định dạng orderBy không hợp lệ.',
      );
    }

    ensureSafeIdentifier(tokens[0]);

    var descending = false;

    if (tokens.length == 2) {
      final direction = tokens[1].toUpperCase();

      if (direction == 'DESC') {
        descending = true;
      } else if (direction != 'ASC') {
        throw ArgumentError.value(
          orderBy,
          'orderBy',
          'Hướng sắp xếp không hợp lệ.',
        );
      }
    }

    return OrderTerm(tokens[0], descending);
  }).toList();
}