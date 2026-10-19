import 'package:expense_tracker/core/utils/money_parser.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseAmountInput', () {
    test('số nguyên không dấu', () {
      expect(parseAmountInput('50000'), 50000);
      expect(parseAmountInput('  120000  '), 120000);
    });

    test('dấu ngăn nghìn bằng chấm, phẩy hoặc khoảng trắng', () {
      expect(parseAmountInput('50.000'), 50000);
      expect(parseAmountInput('1.250.000'), 1250000);
      expect(parseAmountInput('1,250,000'), 1250000);
      expect(parseAmountInput('65 000'), 65000);
    });

    test('chấp nhận hậu tố đơn vị', () {
      expect(parseAmountInput('65.000 đ'), 65000);
      expect(parseAmountInput('65.000 VND'), 65000);
      expect(parseAmountInput('65000đ'), 65000);
    });

    test('từ chối số thập phân và nhóm sai độ dài', () {
      expect(parseAmountInput('1.5'), isNull);
      expect(parseAmountInput('1,5'), isNull);
      expect(parseAmountInput('12.34'), isNull);
      expect(parseAmountInput('1.2345'), isNull);
      expect(parseAmountInput('.000'), isNull);
    });

    test('từ chối số âm, chữ và chuỗi rỗng', () {
      expect(parseAmountInput('-5'), isNull);
      expect(parseAmountInput('abc'), isNull);
      expect(parseAmountInput('12abc'), isNull);
      expect(parseAmountInput(''), isNull);
      expect(parseAmountInput('   '), isNull);
      expect(parseAmountInput('đ'), isNull);
    });

    test('số 0 được đọc ra (việc từ chối 0 thuộc về validator)', () {
      expect(parseAmountInput('0'), 0);
    });

    test('từ chối số quá dài', () {
      expect(parseAmountInput('1234567890123456'), isNull);
    });
  });
}