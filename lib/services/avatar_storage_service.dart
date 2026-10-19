import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AvatarStorageException implements Exception {
  const AvatarStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AvatarStorageService {
  AvatarStorageService({
    Future<Directory> Function()? baseDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _baseDirectoryProvider =
            baseDirectoryProvider ?? getApplicationDocumentsDirectory,
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const int maxBytes = 10 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };
  static const String folderName = 'avatars';

  final Future<Directory> Function() _baseDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<Directory> _avatarDirectory() async {
    final base = await _baseDirectoryProvider();
    final directory = Directory(p.join(base.path, folderName));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  /// Sao chép ảnh vào thư mục bền vững của app và trả về đường dẫn mới.
  /// Mỗi lần lưu dùng tên file mới để tránh hiển thị ảnh cũ từ cache.
  Future<String> saveAvatar({
    required int userId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw const AvatarStorageException('Không tìm thấy ảnh đã chọn.');
    }

    final extension = p.extension(sourcePath).toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      throw const AvatarStorageException(
        'Chỉ hỗ trợ ảnh định dạng JPG, PNG hoặc WebP.',
      );
    }

    final length = await source.length();

    if (length == 0) {
      throw const AvatarStorageException('Ảnh không hợp lệ.');
    }

    if (length > maxBytes) {
      throw const AvatarStorageException('Ảnh quá lớn (tối đa 10 MB).');
    }

    try {
      final directory = await _avatarDirectory();
      final target = p.join(
        directory.path,
        'avatar_${userId}_${DateTime.now().microsecondsSinceEpoch}$extension',
      );

      await source.copy(target);

      return target;
    } on FileSystemException {
      throw const AvatarStorageException(
        'Không thể lưu ảnh đại diện. Hãy kiểm tra dung lượng bộ nhớ.',
      );
    }
  }

  /// Đường dẫn có nằm trong thư mục avatars của app hay không.
  Future<bool> isManagedPath(String path) async {
    final directory = await _avatarDirectory();

    return p.isWithin(directory.path, path);
  }

  /// Chỉ xóa file nằm trong thư mục avatars của app, không bao giờ xóa
  /// file ở nơi khác. Lỗi hệ thống tệp được bỏ qua.
  Future<void> deleteAvatar(String path) async {
    try {
      if (!await isManagedPath(path)) return;

      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Không để lỗi dọn file làm hỏng luồng chính.
    }
  }

  /// Dọn ảnh tạm mà image_picker để lại, nhưng CHỈ khi nó nằm trong thư mục
  /// cache của app. Không bao giờ xóa ảnh gốc của người dùng.
  Future<void> discardTemporary(String path) async {
    try {
      final temporary = await _temporaryDirectoryProvider();

      if (!p.isWithin(temporary.path, path)) return;

      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Bỏ qua.
    }
  }
}