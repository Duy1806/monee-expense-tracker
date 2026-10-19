import '../../core/security/password_hasher.dart';
import '../../core/validators/auth_validator.dart';
import '../database/data_store.dart';
import '../models/app_user.dart';
import 'settings_repository.dart';

class AuthException implements Exception {
  const AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AccountRepository {
  AccountRepository(this._store, this._settings, this._hasher);

  final DataStore _store;
  final SettingsRepository _settings;
  final PasswordHasher _hasher;

  static const String invalidCredentialsMessage =
      'Email hoặc mật khẩu không đúng.';
  static const String duplicateEmailMessage =
      'Email này đã được đăng ký.';

  // ----------------------------------------------------------
  // ĐĂNG KÝ / ĐĂNG NHẬP
  // ----------------------------------------------------------

  Future<AppUser> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final nameError = validateName(name);
    if (nameError != null) throw AuthException(nameError);

    final emailError = validateEmail(email);
    if (emailError != null) throw AuthException(emailError);

    final passwordError = validatePassword(password);
    if (passwordError != null) throw AuthException(passwordError);

    final normalizedEmail = normalizeEmail(email);

    if (await _emailExists(normalizedEmail)) {
      throw const AuthException(duplicateEmailMessage);
    }

    final hashed = await _hasher.hash(password);
    final createdAt = DateTime.now();
    final trimmedName = name.trim();

    try {
      final id = await _store.insert(tableUsers, {
        'name': trimmedName,
        'email': normalizedEmail,
        'password_hash': hashed.hash,
        'password_salt': hashed.salt,
        'avatar_path': null,
        'created_at': createdAt.toIso8601String(),
      });

      return AppUser(
        id: id,
        name: trimmedName,
        email: normalizedEmail,
        createdAt: createdAt,
      );
    } catch (_) {
      // Có thể do hai lần đăng ký trùng email chạy gần như đồng thời.
      if (await _emailExists(normalizedEmail)) {
        throw const AuthException(duplicateEmailMessage);
      }
      rethrow;
    }
  }

  /// Dùng cùng một thông báo cho "không có email" và "sai mật khẩu".
  Future<AppUser> authenticate({
    required String email,
    required String password,
  }) async {
    if (validateEmail(email) != null || password.isEmpty) {
      throw const AuthException(invalidCredentialsMessage);
    }

    final rows = await _store.query(
      tableUsers,
      where: {'email': normalizeEmail(email)},
    );

    if (rows.isEmpty) {
      throw const AuthException(invalidCredentialsMessage);
    }

    final row = rows.first;

    final ok = await _hasher.verify(
      password,
      storedHash: row['password_hash'] as String,
      storedSalt: row['password_salt'] as String,
    );

    if (!ok) {
      throw const AuthException(invalidCredentialsMessage);
    }

    return AppUser.fromMap(row);
  }

  // ----------------------------------------------------------
  // SESSION (phiên cục bộ, không phải xác thực từ server)
  // ----------------------------------------------------------

  Future<void> saveSession(int userId) {
    return _settings.setString(SettingsKeys.sessionUserId, userId.toString());
  }

  Future<void> clearSession() {
    return _settings.remove(SettingsKeys.sessionUserId);
  }

  Future<AppUser?> restoreSession() async {
    final raw = await _settings.getString(SettingsKeys.sessionUserId);
    final id = int.tryParse(raw ?? '');

    if (id == null) {
      return null;
    }

    final user = await getById(id);

    if (user == null) {
      await clearSession();
    }

    return user;
  }

  // ----------------------------------------------------------
  // HỒ SƠ
  // ----------------------------------------------------------

  Future<AppUser?> getById(int userId) async {
    final rows = await _store.query(tableUsers, where: {'id': userId});

    if (rows.isEmpty) {
      return null;
    }

    return AppUser.fromMap(rows.first);
  }

  Future<AppUser> updateName({
    required int userId,
    required String name,
  }) async {
    final error = validateName(name);
    if (error != null) throw AuthException(error);

    await _store.update(
      tableUsers,
      {'name': name.trim()},
      where: {'id': userId},
    );

    return _requireUser(userId);
  }

  Future<AppUser> updateAvatarPath({
    required int userId,
    required String? path,
  }) async {
    await _store.update(
      tableUsers,
      {'avatar_path': path},
      where: {'id': userId},
    );

    return _requireUser(userId);
  }

  Future<void> changePassword({
    required int userId,
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final newError = validatePassword(newPassword);
    if (newError != null) throw AuthException(newError);

    final confirmError = validateConfirmPassword(newPassword, confirmPassword);
    if (confirmError != null) throw AuthException(confirmError);

    final rows = await _store.query(tableUsers, where: {'id': userId});

    if (rows.isEmpty) {
      throw const AuthException('Không tìm thấy tài khoản.');
    }

    final row = rows.first;

    final currentOk = await _hasher.verify(
      currentPassword,
      storedHash: row['password_hash'] as String,
      storedSalt: row['password_salt'] as String,
    );

    if (!currentOk) {
      throw const AuthException('Mật khẩu hiện tại không đúng.');
    }

    if (newPassword == currentPassword) {
      throw const AuthException(
        'Mật khẩu mới phải khác mật khẩu hiện tại.',
      );
    }

    final hashed = await _hasher.hash(newPassword);

    await _store.update(
      tableUsers,
      {'password_hash': hashed.hash, 'password_salt': hashed.salt},
      where: {'id': userId},
    );
  }

  // ----------------------------------------------------------
  // NỘI BỘ
  // ----------------------------------------------------------

  Future<bool> _emailExists(String normalizedEmail) async {
    final rows = await _store.query(
      tableUsers,
      where: {'email': normalizedEmail},
    );

    return rows.isNotEmpty;
  }

  Future<AppUser> _requireUser(int userId) async {
    final user = await getById(userId);

    if (user == null) {
      throw const AuthException('Không tìm thấy tài khoản.');
    }

    return user;
  }
}