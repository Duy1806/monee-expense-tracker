import 'package:sqflite/sqflite.dart';

const int kDatabaseVersion = 2;
const String kDatabaseFileName = 'expense_tracker.db';

const String _createUsers = '''
CREATE TABLE IF NOT EXISTS users (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  name TEXT NOT NULL,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  avatar_path TEXT,
  created_at TEXT NOT NULL
)
''';

const String _createExpensesV2 = '''
CREATE TABLE IF NOT EXISTS expenses (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER,
  title TEXT NOT NULL,
  category TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  date TEXT NOT NULL,
  receipt_image_path TEXT,
  created_at TEXT,
  updated_at TEXT
)
''';

const String _createBudgets = '''
CREATE TABLE IF NOT EXISTS budgets (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id INTEGER NOT NULL,
  month TEXT NOT NULL,
  amount REAL NOT NULL CHECK(amount > 0),
  UNIQUE(user_id, month)
)
''';

const String _createAppSettings = '''
CREATE TABLE IF NOT EXISTS app_settings (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL
)
''';

Future<void> _createIndexes(Database db) async {
  await db.execute(
    'CREATE INDEX IF NOT EXISTS idx_expenses_user_date '
    'ON expenses(user_id, date)',
  );
}

/// Tạo schema mới hoàn toàn (database lần đầu).
Future<void> createSchema(Database db) async {
  await db.execute(_createUsers);
  await db.execute(_createExpensesV2);
  await db.execute(_createBudgets);
  await db.execute(_createAppSettings);
  await _createIndexes(db);
}

/// Nâng cấp từ phiên bản cũ. Không xóa bảng, không xóa dòng dữ liệu.
Future<void> migrateDatabase(
  Database db,
  int oldVersion,
  int newVersion,
) async {
  if (oldVersion < 2) {
    await _migrateV1ToV2(db);
  }
}

Future<void> _migrateV1ToV2(Database db) async {
  // Giao dịch cũ giữ nguyên, user_id = NULL (dữ liệu legacy chưa có chủ).
  await db.execute('ALTER TABLE expenses ADD COLUMN user_id INTEGER');
  await db.execute('ALTER TABLE expenses ADD COLUMN receipt_image_path TEXT');
  await db.execute('ALTER TABLE expenses ADD COLUMN created_at TEXT');
  await db.execute('ALTER TABLE expenses ADD COLUMN updated_at TEXT');

  await db.execute(_createUsers);
  await db.execute(_createBudgets);
  await db.execute(_createAppSettings);
  await _createIndexes(db);
}