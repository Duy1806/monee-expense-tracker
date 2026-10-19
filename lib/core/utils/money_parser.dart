/// Đọc số tiền VND từ ô nhập. Trả về null nếu không hợp lệ.
///
/// Chấp nhận: `50000`, `50.000`, `1,250,000`, `65 000`, `65.000 đ`,
/// `65.000 VND`. Từ chối: `1.5`, `1,5`, `12.34`, `-5`, `abc`, chuỗi rỗng.
double? parseAmountInput(String input) {
  var text = input.trim().toLowerCase();

  text = text.replaceFirst(RegExp(r'\s*(vnd|vnđ|đ)$'), '').trim();

  if (text.isEmpty) return null;

  final valid = RegExp(r'^(\d{1,3}([.,\s]\d{3})+|\d+)$').hasMatch(text);

  if (!valid) return null;

  final digits = text.replaceAll(RegExp(r'[.,\s]'), '');

  if (digits.length > 15) return null;

  final value = int.tryParse(digits);

  return value?.toDouble();
}