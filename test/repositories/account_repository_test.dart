import 'package:expense_tracker/core/security/password_hasher.dart';
import 'package:expense_tracker/data/database/data_store.dart';
import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/repositories/account_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

AccountRepository _buildRepository(DataStore store) {
  return AccountRepository(
    store,
    SettingsRepository(store),
    const PasswordHasher(iterations: 1000, useIsolate: false),
  );
}

void main() {
  late DataStore store;
  late AccountRepository accounts;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    store = PrefsDataStore();
    accounts = _buildRepository(store);
  });

  Future<void> registerAn() async {
    await accounts.register(
      name: 'Nguyễn An',
      email: 'an@example.com',
      password: 'matkhau123',
    );
  }

  group('Đăng ký', () {
    test('thành công và chuẩn hóa email', () async {
      final user = await accounts.register(
        name: '  Nguyễn An ',
        email: ' An@Example.COM ',
        password: 'matkhau123',
      );

      expect(user.id, greaterThan(0));
      expect(user.name, 'Nguyễn An');
      expect(user.email, 'an@example.com');
    });

    test('mật khẩu được lưu dưới dạng hash, không phải văn bản thuần', () async {
      await registerAn();

      final rows = await store.query(tableUsers);
      final hash = rows.first['password_hash'] as String;

      expect(hash.startsWith(r'pbkdf2_sha256$'), isTrue);
      expect(hash.contains('matkhau123'), isFalse);
      expect(rows.first['password_salt'], isNotEmpty);
    });

    test('từ chối email trùng, không phân biệt hoa thường', () async {
      await registerAn();

      expect(
        () => accounts.register(
          name: 'Người khác',
          email: 'AN@EXAMPLE.COM',
          password: 'matkhau456',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('từ chối email không hợp lệ', () {
      expect(
        () => accounts.register(
          name: 'An',
          email: 'khong-phai-email',
          password: 'matkhau123',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('từ chối mật khẩu ngắn', () {
      expect(
        () => accounts.register(
          name: 'An',
          email: 'an@example.com',
          password: '1234567',
        ),
        throwsA(isA<AuthException>()),
      );
    });
  });

  group('Đăng nhập', () {
    test('đúng email (không phân biệt hoa thường) và mật khẩu', () async {
      await registerAn();

      final user = await accounts.authenticate(
        email: 'AN@example.com',
        password: 'matkhau123',
      );

      expect(user.email, 'an@example.com');
    });

    test('từ chối sai mật khẩu', () async {
      await registerAn();

      expect(
        () => accounts.authenticate(
          email: 'an@example.com',
          password: 'sai-mat-khau',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('email không tồn tại cho cùng thông báo với sai mật khẩu', () async {
      await registerAn();

      Future<String> messageFor(String email, String password) async {
        try {
          await accounts.authenticate(email: email, password: password);
        } on AuthException catch (e) {
          return e.message;
        }
        return '';
      }

      final unknown = await messageFor('khong@example.com', 'matkhau123');
      final wrong = await messageFor('an@example.com', 'sai-mat-khau');

      expect(unknown, AccountRepository.invalidCredentialsMessage);
      expect(wrong, unknown);
    });
  });

  group('Session', () {
    test('khôi phục sau khi khởi động lại và xóa khi đăng xuất', () async {
      final user = await accounts.register(
        name: 'Nguyễn An',
        email: 'an@example.com',
        password: 'matkhau123',
      );
      await accounts.saveSession(user.id);

      // Mô phỏng khởi động lại ứng dụng: repository và store mới.
      final restarted = _buildRepository(PrefsDataStore());
      final restored = await restarted.restoreSession();

      expect(restored?.email, 'an@example.com');

      await restarted.clearSession();

      expect(await restarted.restoreSession(), isNull);
    });

    test('session trỏ tới tài khoản không còn tồn tại thì bị xóa', () async {
      await accounts.saveSession(999);

      expect(await accounts.restoreSession(), isNull);
      expect(await accounts.restoreSession(), isNull);
    });
  });

  group('Hồ sơ và đổi mật khẩu', () {
    test('đổi mật khẩu: sai mật khẩu hiện tại bị từ chối', () async {
      final user = await accounts.register(
        name: 'An',
        email: 'an@example.com',
        password: 'matkhau123',
      );

      expect(
        () => accounts.changePassword(
          userId: user.id,
          currentPassword: 'sai-roi',
          newPassword: 'matkhaumoi1',
          confirmPassword: 'matkhaumoi1',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('đổi mật khẩu thành công: mật khẩu cũ mất hiệu lực', () async {
      final user = await accounts.register(
        name: 'An',
        email: 'an@example.com',
        password: 'matkhau123',
      );

      await accounts.changePassword(
        userId: user.id,
        currentPassword: 'matkhau123',
        newPassword: 'matkhaumoi1',
        confirmPassword: 'matkhaumoi1',
      );

      expect(
        () => accounts.authenticate(
          email: 'an@example.com',
          password: 'matkhau123',
        ),
        throwsA(isA<AuthException>()),
      );

      final loggedIn = await accounts.authenticate(
        email: 'an@example.com',
        password: 'matkhaumoi1',
      );

      expect(loggedIn.id, user.id);
    });

    test('từ chối khi xác nhận mật khẩu mới không khớp', () async {
      final user = await accounts.register(
        name: 'An',
        email: 'an@example.com',
        password: 'matkhau123',
      );

      expect(
        () => accounts.changePassword(
          userId: user.id,
          currentPassword: 'matkhau123',
          newPassword: 'matkhaumoi1',
          confirmPassword: 'matkhaumoi2',
        ),
        throwsA(isA<AuthException>()),
      );
    });

    test('đổi tên', () async {
      final user = await accounts.register(
        name: 'An',
        email: 'an@example.com',
        password: 'matkhau123',
      );

      final updated = await accounts.updateName(
        userId: user.id,
        name: 'Nguyễn Văn An',
      );

      expect(updated.name, 'Nguyễn Văn An');
      expect((await accounts.getById(user.id))?.name, 'Nguyễn Văn An');
    });
  });
}