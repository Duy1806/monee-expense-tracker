const Map<String, String> _vietnameseGroups = {
  'a': 'àáạảãâầấậẩẫăằắặẳẵ',
  'e': 'èéẹẻẽêềếệểễ',
  'i': 'ìíịỉĩ',
  'o': 'òóọỏõôồốộổỗơờớợởỡ',
  'u': 'ùúụủũưừứựửữ',
  'y': 'ỳýỵỷỹ',
  'd': 'đ',
};

final Map<String, String> _diacriticMap = _buildDiacriticMap();

Map<String, String> _buildDiacriticMap() {
  final map = <String, String>{};

  _vietnameseGroups.forEach((base, characters) {
    for (final rune in characters.runes) {
      map[String.fromCharCode(rune)] = base;
    }
  });

  return map;
}

/// Đưa về chữ thường, bỏ dấu tiếng Việt, gộp khoảng trắng.
/// Ví dụ: 'Cà Phê  SỮA' -> 'ca phe sua'.
String normalizeForSearch(String input) {
  final lower = input
      .toLowerCase()
      .replaceAll(RegExp(r'[\u0300-\u036f]'), '');

  final buffer = StringBuffer();

  for (final rune in lower.runes) {
    final character = String.fromCharCode(rune);
    buffer.write(_diacriticMap[character] ?? character);
  }

  return buffer.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
}