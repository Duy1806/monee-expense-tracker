import 'package:expense_tracker/services/receipt_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const parser = ReceiptParser();
  final now = DateTime(2026, 10, 18, 9, 0);

  group('Hóa đơn giấy', () {
    test('lấy tên cửa hàng, tổng cộng và ngày', () {
      const text = '''
Highlands Coffee
123 Nguyễn Huệ, Quận 1
Ngày: 15/10/2026
Cà phê sữa 45.000
Tổng cộng: 65.000 VND
''';

      final data = parser.parse(text, now: now);

      expect(data.title, 'Highlands Coffee');
      expect(data.amount, 65000);
      expect(data.date, DateTime(2026, 10, 15));
    });

    test('nhiều số trên hóa đơn: chọn tổng tiền, không chọn tiền mặt/thừa/SĐT', () {
      const text = '''
Siêu thị ABC
Địa chỉ: 12 Lê Lợi
SĐT: 0901234567
Tiền mặt: 200.000
Tổng tiền: 168.500
Tiền thừa: 31.500
''';

      final data = parser.parse(text, now: now);

      expect(data.amount, 168500);
      expect(data.title, 'Siêu thị ABC');
    });

    test('dòng SĐT và ngày không bị coi là số tiền', () {
      const text = '''
Quán Ba Miền
SĐT: 0901234567
Ngày: 15/10/2026
Tổng cộng: 120.000
''';

      expect(parser.parse(text, now: now).amount, 120000);
    });

    test('nhãn và giá trị nằm ở hai dòng khác nhau', () {
      const text = '''
Tổng cộng
65.000
''';

      expect(parser.parse(text, now: now).amount, 65000);
    });
  });

  group('Định dạng số tiền Việt Nam', () {
    test('dấu chấm ngăn cách và VND', () {
      expect(parser.parse('Total: 65.000 VND', now: now).amount, 65000);
    });

    test('dấu phẩy ngăn cách và ký hiệu đ', () {
      expect(parser.parse('Thành tiền: 65,000 đ', now: now).amount, 65000);
    });

    test('không có dấu ngăn cách, dính liền chữ đ', () {
      expect(parser.parse('Tổng cộng 65000đ', now: now).amount, 65000);
    });
  });

  group('Phiếu chuyển khoản', () {
    test('lấy số tiền, người nhận và ngày; không lấy số tài khoản', () {
      const text = '''
Chuyển khoản thành công
Số tiền: 1.500.000 VND
Người nhận: NGUYEN VAN A
Số tài khoản: 0123456789
Ngày: 18/10/2026
''';

      final data = parser.parse(text, now: now);

      expect(data.amount, 1500000);
      expect(data.title, 'NGUYEN VAN A');
      expect(data.date, DateTime(2026, 10, 18));
    });

    test('không có nhãn số tiền thì để trống, không đoán số tài khoản', () {
      const text = '''
Chuyển khoản thành công
Số tài khoản: 0123456789
Người nhận: LE THI B
''';

      final data = parser.parse(text, now: now);

      expect(data.amount, isNull);
      expect(data.title, 'LE THI B');
    });
  });

  group('Không nhận diện được', () {
    test('không có số nào thì số tiền để trống', () {
      const text = '''
Cảm ơn quý khách
Hẹn gặp lại
''';

      final data = parser.parse(text, now: now);

      expect(data.amount, isNull);
      expect(data.title, 'Cảm ơn quý khách');
      expect(data.date, now);
    });

    test('văn bản rỗng cho kết quả mặc định', () {
      final data = parser.parse('', now: now);

      expect(data.amount, isNull);
      expect(data.title, 'Chi tiêu từ hóa đơn');
      expect(data.date, now);
    });
  });

  group('Ngày tháng', () {
    test('định dạng yyyy-MM-dd', () {
      expect(parser.parse('Date: 2026-10-05', now: now).date, DateTime(2026, 10, 5));
    });

    test('tháng không hợp lệ bị bỏ qua, dùng ngày mặc định', () {
      const text = '''
Ngày: 31/13/2026
Tổng cộng: 50.000
''';

      expect(parser.parse(text, now: now).date, now);
    });

    test('ngày không tồn tại (30/02) bị bỏ qua', () {
      expect(parser.parse('Ngày: 30/02/2026', now: now).date, now);
    });
  });

  group('guessCategory', () {
    test('các quy tắc cũ', () {
      expect(guessCategory('Highlands Coffee'), 'Ăn uống');
      expect(guessCategory('Grab Bike'), 'Di chuyển');
      expect(guessCategory('Siêu thị ABC'), 'Mua sắm');
      expect(guessCategory('Tiền điện tháng 10'), 'Hóa đơn');
    });

    test('nhóm bổ sung và mặc định', () {
      expect(guessCategory('Nhà thuốc Long Châu'), 'Sức khỏe');
      expect(guessCategory('Linh tinh'), 'Khác');
    });
  });
}