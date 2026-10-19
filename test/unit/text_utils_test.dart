import 'package:expense_tracker/core/utils/text_utils.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeForSearch', () {
    test('bỏ dấu và đưa về chữ thường', () {
      expect(normalizeForSearch('Cà Phê  SỮA'), 'ca phe sua');
      expect(normalizeForSearch('Đường'), 'duong');
      expect(normalizeForSearch('Nguyễn Văn Ánh'), 'nguyen van anh');
    });

    test('xử lý cả ký tự dạng tổ hợp (dấu rời)', () {
      // "ề" viết dạng e + dấu mũ + dấu huyền.
      expect(normalizeForSearch('ne\u0302\u0300'), 'ne');
    });

    test('gộp khoảng trắng và cắt hai đầu', () {
      expect(normalizeForSearch('  a   b  '), 'a b');
    });

    test('giữ nguyên chữ số và ký tự thường', () {
      expect(normalizeForSearch('Grab 123'), 'grab 123');
    });

    test('chuỗi rỗng', () {
      expect(normalizeForSearch(''), '');
    });
  });
}