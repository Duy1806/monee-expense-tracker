import 'dart:io';
import 'dart:typed_data';

import 'package:expense_tracker/services/avatar_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late Directory outsideDir;
  late AvatarStorageService service;

  File writeFile(Directory dir, String name, {List<int>? bytes}) {
    final file = File(p.join(dir.path, name));
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(bytes ?? [1, 2, 3, 4]);
    return file;
  }

  List<FileSystemEntity> avatarFiles() {
    final dir = Directory(p.join(baseDir.path, AvatarStorageService.folderName));
    return dir.existsSync() ? dir.listSync() : <FileSystemEntity>[];
  }

  setUp(() {
    baseDir = Directory.systemTemp.createTempSync('monee_avatar_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_avatar_tmp_');
    outsideDir = Directory.systemTemp.createTempSync('monee_avatar_out_');

    service = AvatarStorageService(
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

  group('saveAvatar', () {
    test('sao chép ảnh vào thư mục avatars của app', () async {
      final source = writeFile(outsideDir, 'anh.JPG', bytes: [9, 8, 7]);

      final saved = await service.saveAvatar(
        userId: 5,
        sourcePath: source.path,
      );

      expect(
        p.isWithin(p.join(baseDir.path, AvatarStorageService.folderName), saved),
        isTrue,
      );
      expect(p.basename(saved).startsWith('avatar_5_'), isTrue);
      expect(p.extension(saved), '.jpg');
      expect(File(saved).readAsBytesSync(), [9, 8, 7]);
      expect(source.existsSync(), isTrue); // Không đụng tới ảnh gốc.
    });

    test('mỗi lần lưu dùng tên file khác nhau', () async {
      final source = writeFile(outsideDir, 'anh.png');

      final first = await service.saveAvatar(userId: 1, sourcePath: source.path);
      final second = await service.saveAvatar(userId: 1, sourcePath: source.path);

      expect(first, isNot(second));
      expect(avatarFiles(), hasLength(2));
    });

    test('từ chối file không tồn tại', () async {
      await expectLater(
        service.saveAvatar(
          userId: 1,
          sourcePath: p.join(outsideDir.path, 'khong-co.jpg'),
        ),
        throwsA(isA<AvatarStorageException>()),
      );
    });

    test('từ chối định dạng không hỗ trợ', () async {
      final source = writeFile(outsideDir, 'tai-lieu.pdf');

      await expectLater(
        service.saveAvatar(userId: 1, sourcePath: source.path),
        throwsA(isA<AvatarStorageException>()),
      );
      expect(avatarFiles(), isEmpty);
    });

    test('từ chối file rỗng', () async {
      final source = writeFile(outsideDir, 'rong.jpg', bytes: const []);

      await expectLater(
        service.saveAvatar(userId: 1, sourcePath: source.path),
        throwsA(isA<AvatarStorageException>()),
      );
    });

    test('từ chối ảnh lớn hơn 10 MB', () async {
      final source = writeFile(
        outsideDir,
        'lon.jpg',
        bytes: Uint8List(AvatarStorageService.maxBytes + 1),
      );

      await expectLater(
        service.saveAvatar(userId: 1, sourcePath: source.path),
        throwsA(isA<AvatarStorageException>()),
      );
      expect(avatarFiles(), isEmpty);
    });
  });

  group('deleteAvatar', () {
    test('xóa file nằm trong thư mục avatars', () async {
      final source = writeFile(outsideDir, 'anh.png');
      final saved = await service.saveAvatar(userId: 1, sourcePath: source.path);

      await service.deleteAvatar(saved);

      expect(File(saved).existsSync(), isFalse);
    });

    test('không xóa file nằm ngoài thư mục avatars', () async {
      final outside = writeFile(outsideDir, 'quan-trong.jpg');

      await service.deleteAvatar(outside.path);

      expect(outside.existsSync(), isTrue);
    });

    test('không xóa file ở thư mục có tên gần giống', () async {
      final lookalike = writeFile(
        baseDir,
        p.join('${AvatarStorageService.folderName}_evil', 'x.jpg'),
      );

      await service.deleteAvatar(lookalike.path);

      expect(lookalike.existsSync(), isTrue);
    });

    test('không báo lỗi khi file không tồn tại', () async {
      await service.deleteAvatar(
        p.join(baseDir.path, AvatarStorageService.folderName, 'khong-co.jpg'),
      );
    });
  });

  group('discardTemporary', () {
    test('xóa ảnh tạm nằm trong thư mục cache của app', () async {
      final temp = writeFile(tempDir, 'picked.jpg');

      await service.discardTemporary(temp.path);

      expect(temp.existsSync(), isFalse);
    });

    test('không bao giờ xóa ảnh nằm ngoài thư mục cache', () async {
      final original = writeFile(outsideDir, 'anh-goc.jpg');

      await service.discardTemporary(original.path);

      expect(original.existsSync(), isTrue);
    });
  });
}