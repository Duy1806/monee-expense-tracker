import 'dart:io';
import 'dart:typed_data';

import 'package:expense_tracker/services/receipt_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late Directory outsideDir;
  late ReceiptStorageService service;

  File writeFile(Directory dir, String name, {List<int>? bytes}) {
    final file = File(p.join(dir.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes ?? [1, 2, 3, 4]);
    return file;
  }

  int receiptCount() {
    final dir = Directory(p.join(baseDir.path, ReceiptStorageService.folderName));
    return dir.existsSync() ? dir.listSync().length : 0;
  }

  setUp(() {
    baseDir = Directory.systemTemp.createTempSync('monee_receipt_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_receipt_tmp_');
    outsideDir = Directory.systemTemp.createTempSync('monee_receipt_out_');

    service = ReceiptStorageService(
      baseDirectoryProvider: () async => baseDir,
      temporaryDirectoryProvider: () async => tempDir,
    );
  });

  tearDown(() {
    for (final dir in [baseDir, tempDir, outsideDir]) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Bỏ qua nếu Windows còn khóa file tạm.
      }
    }
  });

  group('saveReceipt', () {
    test('sao chép vào thư mục receipts, không đụng tới ảnh gốc', () async {
      final source = writeFile(outsideDir, 'hoa-don.JPG', bytes: [9, 8, 7]);

      final saved = await service.saveReceipt(userId: 3, sourcePath: source.path);

      expect(
        p.isWithin(
          p.join(baseDir.path, ReceiptStorageService.folderName),
          saved,
        ),
        isTrue,
      );
      expect(p.basename(saved).startsWith('receipt_3_'), isTrue);
      expect(File(saved).readAsBytesSync(), [9, 8, 7]);
      expect(source.existsSync(), isTrue);
      expect(await service.exists(saved), isTrue);
    });

    test('hai lần lưu cho hai tên file khác nhau', () async {
      final source = writeFile(outsideDir, 'a.png');

      final first = await service.saveReceipt(userId: 1, sourcePath: source.path);
      final second = await service.saveReceipt(userId: 1, sourcePath: source.path);

      expect(first, isNot(second));
      expect(receiptCount(), 2);
    });

    test('từ chối file không tồn tại, sai định dạng, rỗng, quá lớn', () async {
      await expectLater(
        service.saveReceipt(
          userId: 1,
          sourcePath: p.join(outsideDir.path, 'khong-co.jpg'),
        ),
        throwsA(isA<ReceiptStorageException>()),
      );

      await expectLater(
        service.saveReceipt(
          userId: 1,
          sourcePath: writeFile(outsideDir, 'a.pdf').path,
        ),
        throwsA(isA<ReceiptStorageException>()),
      );

      await expectLater(
        service.saveReceipt(
          userId: 1,
          sourcePath: writeFile(outsideDir, 'rong.jpg', bytes: const []).path,
        ),
        throwsA(isA<ReceiptStorageException>()),
      );

      await expectLater(
        service.saveReceipt(
          userId: 1,
          sourcePath: writeFile(
            outsideDir,
            'lon.jpg',
            bytes: Uint8List(ReceiptStorageService.maxBytes + 1),
          ).path,
        ),
        throwsA(isA<ReceiptStorageException>()),
      );

      expect(receiptCount(), 0);
    });
  });

  group('deleteIfUnreferenced', () {
    test('không xóa khi còn giao dịch tham chiếu', () async {
      final source = writeFile(outsideDir, 'a.jpg');
      final saved = await service.saveReceipt(userId: 1, sourcePath: source.path);

      await service.deleteIfUnreferenced(saved, (path) async => 2);

      expect(File(saved).existsSync(), isTrue);
    });

    test('xóa khi không còn tham chiếu', () async {
      final source = writeFile(outsideDir, 'a.jpg');
      final saved = await service.saveReceipt(userId: 1, sourcePath: source.path);

      await service.deleteIfUnreferenced(saved, (path) async => 0);

      expect(File(saved).existsSync(), isFalse);
    });

    test('không bao giờ xóa file nằm ngoài thư mục receipts', () async {
      final outside = writeFile(outsideDir, 'quan-trong.jpg');

      await service.deleteIfUnreferenced(outside.path, (path) async => 0);

      expect(outside.existsSync(), isTrue);
    });

    test('không báo lỗi khi bộ đếm tham chiếu ném lỗi', () async {
      final source = writeFile(outsideDir, 'a.jpg');
      final saved = await service.saveReceipt(userId: 1, sourcePath: source.path);

      await service.deleteIfUnreferenced(
        saved,
        (path) async => throw StateError('lỗi'),
      );

      expect(File(saved).existsSync(), isTrue);
    });
  });

  group('discardTemporary', () {
    test('xóa ảnh tạm trong cache của app', () async {
      final temp = writeFile(tempDir, 'picked.jpg');

      await service.discardTemporary(temp.path);

      expect(temp.existsSync(), isFalse);
    });

    test('không xóa ảnh nằm ngoài cache', () async {
      final original = writeFile(outsideDir, 'anh-goc.jpg');

      await service.discardTemporary(original.path);

      expect(original.existsSync(), isTrue);
    });
  });
}