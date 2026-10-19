import 'package:expense_tracker/core/utils/percent_format.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatPercent', () {
    test('có dấu cộng cho số dương, dấu trừ cho số âm', () {
      expect(formatPercent(12.4), '+12%');
      expect(formatPercent(-8.2), '-8%');
    });

    test('làm tròn về 0 thì không có dấu', () {
      expect(formatPercent(0.3), '0%');
      expect(formatPercent(-0.4), '0%');
    });

    test('tùy chọn bỏ dấu', () {
      expect(formatPercent(12, showSign: false), '12%');
    });

    test('giá trị không hữu hạn', () {
      expect(formatPercent(double.nan), '0%');
      expect(formatPercent(double.infinity), '0%');
    });
  });

  group('describeChange', () {
    test('tăng, giảm, không đổi', () {
      expect(describeChange(50, 'tháng trước'), 'Tăng 50% so với tháng trước');
      expect(
        describeChange(-28.6, '7 ngày trước đó'),
        'Giảm 29% so với 7 ngày trước đó',
      );
      expect(describeChange(0.2, 'tháng trước'), 'Không đổi so với tháng trước');
    });

    test('không có mốc so sánh', () {
      expect(
        describeChange(null, 'tháng trước'),
        'Chưa có dữ liệu tháng trước để so sánh',
      );
    });
  });
}