import 'package:flutter/foundation.dart';

import '../../../core/validators/auth_validator.dart';
import '../../../data/models/app_user.dart';
import '../../../data/repositories/account_repository.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthController extends ChangeNotifier {
  AuthController(this._accounts);

  final AccountRepository _accounts;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  bool _busy = false;
  String? _errorMessage;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get busy => _busy;
  String? get errorMessage => _errorMessage;

  bool get isAuthenticated =>
      _status == AuthStatus.authenticated && _user != null;

  /// Gọi một lần khi khởi động app.
  Future<void> restoreSession() async {
    try {
      _user = await _accounts.restoreSession();
    } catch (_) {
      _user = null;
    }

    _status =
        _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;
    notifyListeners();
  }

  Future<bool> login({required String email, required String password}) {
    return _runAuth(() async {
      final user = await _accounts.authenticate(
        email: email,
        password: password,
      );
      await _accounts.saveSession(user.id);
      return user;
    });
  }

  Future<bool> register({
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
  }) {
    final mismatch = validateConfirmPassword(password, confirmPassword);

    if (mismatch != null) {
      _errorMessage = mismatch;
      notifyListeners();
      return Future<bool>.value(false);
    }

    return _runAuth(() async {
      final user = await _accounts.register(
        name: name,
        email: email,
        password: password,
      );
      await _accounts.saveSession(user.id);
      return user;
    });
  }

  Future<void> logout() async {
    try {
      await _accounts.clearSession();
    } finally {
      _user = null;
      _status = AuthStatus.unauthenticated;
      _errorMessage = null;
      notifyListeners();
    }
  }

  void clearError() {
    if (_errorMessage != null) {
      _errorMessage = null;
      notifyListeners();
    }
  }

  // ----------------------------------------------------------
  // HỒ SƠ — trả về null nếu thành công, hoặc thông báo lỗi.
  // ----------------------------------------------------------

  Future<String?> updateName(String name) async {
    final current = _user;
    if (current == null) return 'Bạn chưa đăng nhập.';

    try {
      _user = await _accounts.updateName(userId: current.id, name: name);
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể cập nhật. Vui lòng thử lại.';
    }
  }

  Future<String?> updateAvatarPath(String? path) async {
    final current = _user;
    if (current == null) return 'Bạn chưa đăng nhập.';

    try {
      _user = await _accounts.updateAvatarPath(userId: current.id, path: path);
      notifyListeners();
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể cập nhật ảnh đại diện. Vui lòng thử lại.';
    }
  }

  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    final current = _user;
    if (current == null) return 'Bạn chưa đăng nhập.';

    try {
      await _accounts.changePassword(
        userId: current.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
      return null;
    } on AuthException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể đổi mật khẩu. Vui lòng thử lại.';
    }
  }

  // ----------------------------------------------------------
  // NỘI BỘ
  // ----------------------------------------------------------

  Future<bool> _runAuth(Future<AppUser> Function() action) async {
    if (_busy) return false;

    _busy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _user = await action();
      _status = AuthStatus.authenticated;
      return true;
    } on AuthException catch (e) {
      _errorMessage = e.message;
      return false;
    } catch (_) {
      _errorMessage = 'Đã xảy ra lỗi. Vui lòng thử lại.';
      return false;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }
}