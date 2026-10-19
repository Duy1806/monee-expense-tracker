const int kMinPasswordLength = 8;
const int kMaxPasswordLength = 128;

final RegExp _emailPattern =
    RegExp(r'^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$');

/// Email được lưu ở dạng chữ thường, bỏ khoảng trắng hai đầu.
String normalizeEmail(String email) => email.trim().toLowerCase();

String? validateName(String? value) {
  final text = (value ?? '').trim();

  if (text.isEmpty) {
    return 'Vui lòng nhập họ tên.';
  }

  if (text.length > 60) {
    return 'Họ tên tối đa 60 ký tự.';
  }

  return null;
}

String? validateEmail(String? value) {
  final text = (value ?? '').trim();

  if (text.isEmpty) {
    return 'Vui lòng nhập email.';
  }

  if (text.length > 254 || !_emailPattern.hasMatch(text)) {
    return 'Email không hợp lệ.';
  }

  return null;
}

/// Không trim mật khẩu: khoảng trắng là một phần của mật khẩu.
String? validatePassword(String? value) {
  final text = value ?? '';

  if (text.isEmpty) {
    return 'Vui lòng nhập mật khẩu.';
  }

  if (text.length < kMinPasswordLength) {
    return 'Mật khẩu phải có ít nhất $kMinPasswordLength ký tự.';
  }

  if (text.length > kMaxPasswordLength) {
    return 'Mật khẩu tối đa $kMaxPasswordLength ký tự.';
  }

  return null;
}

String? validateConfirmPassword(String? password, String? confirm) {
  if ((confirm ?? '').isEmpty) {
    return 'Vui lòng nhập lại mật khẩu.';
  }

  if (password != confirm) {
    return 'Mật khẩu xác nhận không khớp.';
  }

  return null;
}