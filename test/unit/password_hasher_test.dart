import 'package:expense_tracker/core/security/password_hasher.dart';
import 'package:flutter_test/flutter_test.dart';

String _hex(List<int> bytes) {
  return bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

void main() {
  group('pbkdf2Sha256', () {
    test('khớp vector chuẩn với 1 vòng lặp', () {
      final key = pbkdf2Sha256('password'.codeUnits, 'salt'.codeUnits, 1, 32);

      expect(
        _hex(key),
        '120fb6cffcf8b32c43e7225256c4f837a86548c92ccc35480805987cb70be17b',
      );
    });

    test('khớp vector chuẩn với 2 vòng lặp', () {
      final key = pbkdf2Sha256('password'.codeUnits, 'salt'.codeUnits, 2, 32);

      expect(
        _hex(key),
        'ae4d0c95af6b46d32d0adff928f06dd02a303f8ef3c251dfd6e2d85a95474c43',
      );
    });
  });

  group('PasswordHasher', () {
    const hasher = PasswordHasher(iterations: 1000, useIsolate: false);

    test('cùng mật khẩu nhưng hash và salt khác nhau', () async {
      final a = await hasher.hash('matkhau123');
      final b = await hasher.hash('matkhau123');

      expect(a.salt, isNot(b.salt));
      expect(a.hash, isNot(b.hash));
    });

    test('hash không chứa mật khẩu gốc và có định dạng đúng', () async {
      final result = await hasher.hash('matkhau123');

      expect(result.hash.startsWith(r'pbkdf2_sha256$1000$'), isTrue);
      expect(result.hash.contains('matkhau123'), isFalse);
    });

    test('verify đúng mật khẩu trả về true, sai trả về false', () async {
      final result = await hasher.hash('matkhau123');

      expect(
        await hasher.verify(
          'matkhau123',
          storedHash: result.hash,
          storedSalt: result.salt,
        ),
        isTrue,
      );
      expect(
        await hasher.verify(
          'matkhau124',
          storedHash: result.hash,
          storedSalt: result.salt,
        ),
        isFalse,
      );
    });

    test('từ chối chuỗi hash sai định dạng', () async {
      expect(
        await hasher.verify('x', storedHash: 'abc', storedSalt: 'AAAA'),
        isFalse,
      );
      expect(
        await hasher.verify(
          'x',
          storedHash: r'pbkdf2_sha256$khongphaiso$AAAA',
          storedSalt: 'AAAA',
        ),
        isFalse,
      );
    });
  });
}