import 'package:expense_tracker/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatVnd', () {
    test('định dạng phân cách hàng nghìn bằng dấu chấm', () {
      expect(formatVnd(0), '0 đ');
      expect(formatVnd(999), '999 đ');
      expect(formatVnd(1000), '1.000 đ');
      expect(formatVnd(65000), '65.000 đ');
      expect(formatVnd(8000000), '8.000.000 đ');
      expect(formatVnd(1234567890), '1.234.567.890 đ');
    });

    test('làm tròn số lẻ', () {
      expect(formatVnd(1234.6), '1.235 đ');
    });

    test('xử lý số âm và giá trị không hợp lệ', () {
      expect(formatVnd(-65000), '-65.000 đ');
      expect(formatVnd(double.nan), '0 đ');
      expect(formatVnd(double.infinity), '0 đ');
    });
  });

  test('formatDate luôn có hai chữ số cho ngày và tháng', () {
    expect(formatDate(DateTime(2026, 3, 5)), '05/03/2026');
    expect(formatDate(DateTime(2026, 10, 18)), '18/10/2026');
  });
}