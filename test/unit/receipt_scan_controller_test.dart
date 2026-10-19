import 'package:expense_tracker/features/receipt_scanner/providers/receipt_scan_controller.dart';
import 'package:flutter_test/flutter_test.dart';

const _sampleReceipt = '''
Highlands Coffee
123 Nguyễn Huệ, Quận 1
Ngày: 15/10/2026
Cà phê sữa 45.000
Tổng cộng: 65.000 VND
''';

void main() {
  const imagePath = '/tmp/hoa-don.jpg';

  ReceiptScanController build({
    Future<String?> Function(ReceiptImageSource source)? pick,
    Future<String> Function(String path)? recognize,
  }) {
    return ReceiptScanController(
      pickImage: pick ?? (_) async => imagePath,
      recognizeText: recognize ?? (_) async => _sampleReceipt,
    );
  }

  group('ReceiptScanController', () {
    test('quét thành công: trả về bản nháp từ dữ liệu OCR', () async {
      final controller = build();

      final draft = await controller.scan(ReceiptImageSource.gallery);

      expect(draft, isNotNull);
      expect(draft!.title, 'Highlands Coffee');
      expect(draft.amount, 65000);
      expect(draft.category, 'Ăn uống');
      expect(draft.date, DateTime(2026, 10, 15));
      expect(draft.receiptSourcePath, imagePath);
      expect(draft.rawText, _sampleReceipt);
      expect(controller.status, ReceiptScanStatus.idle);
      expect(controller.errorMessage, isNull);
    });

    test('người dùng hủy chọn ảnh: không nhận dạng, không lỗi', () async {
      var recognizeCalls = 0;

      final controller = build(
        pick: (_) async => null,
        recognize: (_) async {
          recognizeCalls++;
          return _sampleReceipt;
        },
      );

      final draft = await controller.scan(ReceiptImageSource.camera);

      expect(draft, isNull);
      expect(recognizeCalls, 0);
      expect(controller.status, ReceiptScanStatus.idle);
      expect(controller.errorMessage, isNull);
      expect(controller.pickedImagePath, isNull);
    });

    test('truyền đúng nguồn ảnh cho bộ chọn ảnh', () async {
      ReceiptImageSource? received;

      final controller = build(
        pick: (source) async {
          received = source;
          return imagePath;
        },
      );

      await controller.scan(ReceiptImageSource.camera);

      expect(received, ReceiptImageSource.camera);
    });

    test('OCR trả về văn bản rỗng: báo lỗi và vẫn giữ ảnh để nhập thủ công',
        () async {
      final controller = build(recognize: (_) async => '   \n ');

      final draft = await controller.scan(ReceiptImageSource.gallery);

      expect(draft, isNull);
      expect(controller.status, ReceiptScanStatus.failed);
      expect(controller.errorMessage, isNotNull);
      expect(controller.errorMessage, isNotEmpty);
      expect(controller.pickedImagePath, imagePath);

      final manual = controller.manualDraft();

      expect(manual.title, '');
      expect(manual.amount, isNull);
      expect(manual.receiptSourcePath, imagePath);
    });

    test('bộ nhận dạng ném lỗi: chuyển sang failed, không văng ngoại lệ',
        () async {
      final controller = build(
        recognize: (_) async => throw Exception('ML Kit lỗi'),
      );

      final draft = await controller.scan(ReceiptImageSource.gallery);

      expect(draft, isNull);
      expect(controller.status, ReceiptScanStatus.failed);
      expect(controller.errorMessage, isNotNull);
      // Thông báo thân thiện, không lộ chi tiết kỹ thuật.
      expect(controller.errorMessage, isNot(contains('ML Kit')));
      expect(controller.pickedImagePath, imagePath);
    });

    test('bộ chọn ảnh ném lỗi (thiếu quyền): failed và không có ảnh', () async {
      final controller = build(
        pick: (_) async => throw Exception('permission denied'),
      );

      final draft = await controller.scan(ReceiptImageSource.camera);

      expect(draft, isNull);
      expect(controller.status, ReceiptScanStatus.failed);
      expect(controller.errorMessage, isNotNull);
      expect(controller.pickedImagePath, isNull);
    });

    test('retryRecognition thành công sau khi lần đầu thất bại', () async {
      var calls = 0;

      final controller = build(
        recognize: (_) async {
          calls++;
          if (calls == 1) throw Exception('lần đầu lỗi');
          return _sampleReceipt;
        },
      );

      expect(await controller.scan(ReceiptImageSource.gallery), isNull);
      expect(controller.status, ReceiptScanStatus.failed);

      final draft = await controller.retryRecognition();

      expect(calls, 2);
      expect(draft, isNotNull);
      expect(draft!.amount, 65000);
      expect(draft.receiptSourcePath, imagePath);
      expect(controller.status, ReceiptScanStatus.idle);
      expect(controller.errorMessage, isNull);
    });

    test('retryRecognition khi chưa chọn ảnh: không làm gì', () async {
      var calls = 0;

      final controller = build(
        recognize: (_) async {
          calls++;
          return _sampleReceipt;
        },
      );

      expect(await controller.retryRecognition(), isNull);
      expect(calls, 0);
      expect(controller.status, ReceiptScanStatus.idle);
    });

    test('đang nhận dạng thì bỏ qua yêu cầu quét thứ hai', () async {
      var pickCalls = 0;
      final gate = Future<void>.delayed(const Duration(milliseconds: 50));

      final controller = build(
        pick: (_) async {
          pickCalls++;
          return imagePath;
        },
        recognize: (_) async {
          await gate;
          return _sampleReceipt;
        },
      );

      final first = controller.scan(ReceiptImageSource.gallery);
      await Future<void>.delayed(Duration.zero);

      expect(controller.recognizing, isTrue);
      expect(await controller.scan(ReceiptImageSource.camera), isNull);
      expect(pickCalls, 1);

      expect(await first, isNotNull);
      expect(controller.recognizing, isFalse);
    });

    test('reset xóa trạng thái, lỗi và ảnh đã chọn', () async {
      final controller = build(recognize: (_) async => '');

      await controller.scan(ReceiptImageSource.gallery);
      expect(controller.status, ReceiptScanStatus.failed);

      controller.reset();

      expect(controller.status, ReceiptScanStatus.idle);
      expect(controller.errorMessage, isNull);
      expect(controller.pickedImagePath, isNull);
    });

    test('không thông báo sau khi dispose', () async {
      final controller = build(
        recognize: (_) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return _sampleReceipt;
        },
      );

      final pending = controller.scan(ReceiptImageSource.gallery);
      await Future<void>.delayed(Duration.zero);
      controller.dispose();

      // Không được ném "used after being disposed".
      expect(await pending, isNotNull);
    });
  });
}