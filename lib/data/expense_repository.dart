
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

// ============================================================
// MODEL: EXPENSE
// ============================================================

class Expense {
  final int? id;
  final String title;
  final String category;
  final double amount;
  final DateTime date;

  const Expense({
    this.id,
    required this.title,
    required this.category,
    required this.amount,
    required this.date,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'amount': amount,
      'date': date.toIso8601String(),
    };
  }

  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'] as int?,
      title: map['title'] as String,
      category: map['category'] as String,
      amount: (map['amount'] as num).toDouble(),
      date: DateTime.parse(map['date'] as String),
    );
  }
}

// ============================================================
// VALIDATION
// ============================================================

const List<String> expenseCategories = [
  'Ăn uống',
  'Di chuyển',
  'Mua sắm',
  'Hóa đơn',
  'Giải trí',
  'Khác',
];

String? validateExpense(Expense expense) {
  if (expense.title.trim().isEmpty) {
    return 'Tên giao dịch không được để trống.';
  }

  if (!expense.amount.isFinite || expense.amount <= 0) {
    return 'Số tiền phải lớn hơn 0 và hợp lệ.';
  }

  if (!expenseCategories.contains(expense.category)) {
    return 'Danh mục không hợp lệ.';
  }

  final now = DateTime.now();

  if (expense.date.year < 2000 ||
      expense.date.isAfter(now.add(const Duration(days: 1)))) {
    return 'Ngày giao dịch không hợp lệ.';
  }

  return null;
}

// ============================================================
// REPOSITORY
// Web: SharedPreferences
// Android/iOS: SQLite
// ============================================================

class ExpenseRepository {
  ExpenseRepository({bool? useWebStorage})
      : _useWebStorage = useWebStorage ?? kIsWeb;

  final bool _useWebStorage;

  static const String _webStorageKey =
      'expense_tracker_transactions_v1';

  static const String _databaseName = 'expense_tracker.db';
  static const String _tableName = 'expenses';

  Database? _database;

  // ----------------------------------------------------------
  // OPEN DATABASE
  // ----------------------------------------------------------

  Future<Database> _openDatabase() async {
    if (_useWebStorage) {
      throw UnsupportedError(
        'Web đang sử dụng SharedPreferences, không sử dụng SQLite.',
      );
    }

    if (_database != null && _database!.isOpen) {
      return _database!;
    }

    final dbPath = p.join(
      await getDatabasesPath(),
      _databaseName,
    );

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE $_tableName (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            amount REAL NOT NULL CHECK(amount > 0),
            date TEXT NOT NULL
          )
        ''');
      },
    );

    return _database!;
  }

  // ----------------------------------------------------------
  // GET ALL EXPENSES
  // ----------------------------------------------------------

  Future<List<Expense>> getAll() async {
    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_webStorageKey);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final decoded = jsonDecode(jsonString) as List<dynamic>;

      final expenses = decoded.map((item) {
        return Expense.fromMap(
          Map<String, dynamic>.from(item as Map),
        );
      }).toList();

      expenses.sort((a, b) => b.date.compareTo(a.date));

      return expenses;
    }

    final db = await _openDatabase();

    final rows = await db.query(
      _tableName,
      orderBy: 'date DESC, id DESC',
    );

    return rows.map((row) => Expense.fromMap(row)).toList();
  }

  // ----------------------------------------------------------
  // ADD EXPENSE
  // ----------------------------------------------------------

  Future<Expense> add(Expense expense) async {
    final error = validateExpense(expense);

    if (error != null) {
      throw ArgumentError(error);
    }

    final normalizedTitle = expense.title.trim();

    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final current = await getAll();

      final saved = Expense(
        id: DateTime.now().microsecondsSinceEpoch,
        title: normalizedTitle,
        category: expense.category,
        amount: expense.amount,
        date: expense.date,
      );

      current.add(saved);

      final success = await prefs.setString(
        _webStorageKey,
        jsonEncode(
          current.map((item) => item.toMap()).toList(),
        ),
      );

      if (!success) {
        throw StateError('Không thể lưu giao dịch vào bộ nhớ trình duyệt.');
      }

      return saved;
    }

    final db = await _openDatabase();

    final id = await db.insert(
      _tableName,
      {
        'title': normalizedTitle,
        'category': expense.category,
        'amount': expense.amount,
        'date': expense.date.toIso8601String(),
      },
    );

    return Expense(
      id: id,
      title: normalizedTitle,
      category: expense.category,
      amount: expense.amount,
      date: expense.date,
    );
  }

  // ----------------------------------------------------------
  // DELETE EXPENSE
  // ----------------------------------------------------------

  Future<void> delete(int id) async {
    if (_useWebStorage) {
      final prefs = await SharedPreferences.getInstance();
      final current = await getAll();

      current.removeWhere((expense) => expense.id == id);

      final success = await prefs.setString(
        _webStorageKey,
        jsonEncode(
          current.map((item) => item.toMap()).toList(),
        ),
      );

      if (!success) {
        throw StateError('Không thể cập nhật dữ liệu trong trình duyệt.');
      }

      return;
    }

    final db = await _openDatabase();

    await db.delete(
      _tableName,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ----------------------------------------------------------
  // TOTAL EXPENSE
  // ----------------------------------------------------------

  Future<double> getTotal() async {
    final expenses = await getAll();

    return expenses.fold<double>(
      0,
      (total, expense) => total + expense.amount,
    );
  }

  // ----------------------------------------------------------
  // CLOSE DATABASE
  // ----------------------------------------------------------

  Future<void> close() async {
    if (_database != null && _database!.isOpen) {
      await _database!.close();
    }

    _database = null;
  }
}
