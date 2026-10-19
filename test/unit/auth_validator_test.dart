import 'package:expense_tracker/core/validators/auth_validator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateEmail', () {
    test('chấp nhận email hợp lệ', () {
      expect(validateEmail('an@example.com'), isNull);
      expect(validateEmail('  An.Nguyen+x@mail.example.vn '), isNull);
    });

    test('từ chối email không hợp lệ', () {
      expect(validateEmail(''), isNotNull);
      expect(validateEmail('abc'), isNotNull);
      expect(validateEmail('abc@'), isNotNull);
      expect(validateEmail('abc@domain'), isNotNull);
    });
  });

  group('validatePassword', () {
    test('từ chối mật khẩu ngắn hơn 8 ký tự', () {
      expect(validatePassword('1234567'), isNotNull);
    });

    test('chấp nhận mật khẩu từ 8 ký tự', () {
      expect(validatePassword('12345678'), isNull);
    });
  });

  group('validateConfirmPassword', () {
    test('từ chối khi không khớp', () {
      expect(validateConfirmPassword('12345678', '12345679'), isNotNull);
    });

    test('chấp nhận khi khớp', () {
      expect(validateConfirmPassword('12345678', '12345678'), isNull);
    });
  });

  test('normalizeEmail đưa về chữ thường và bỏ khoảng trắng', () {
    expect(normalizeEmail('  An@Example.COM '), 'an@example.com');
  });

  test('validateName từ chối tên rỗng', () {
    expect(validateName('   '), isNotNull);
    expect(validateName('Nguyễn An'), isNull);
  });
}