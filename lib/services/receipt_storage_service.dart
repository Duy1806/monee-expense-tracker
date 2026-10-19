import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class ReceiptStorageException implements Exception {
  const ReceiptStorageException(this.message);

  final String message;

  @override
  String toString() => message;
}

class ReceiptStorageService {
  ReceiptStorageService({
    Future<Directory> Function()? baseDirectoryProvider,
    Future<Directory> Function()? temporaryDirectoryProvider,
  })  : _baseDirectoryProvider =
            baseDirectoryProvider ?? getApplicationDocumentsDirectory,
        _temporaryDirectoryProvider =
            temporaryDirectoryProvider ?? getTemporaryDirectory;

  static const int maxBytes = 20 * 1024 * 1024;
  static const Set<String> allowedExtensions = {
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
  };
  static const String folderName = 'receipts';

  final Future<Directory> Function() _baseDirectoryProvider;
  final Future<Directory> Function() _temporaryDirectoryProvider;

  Future<Directory> _receiptDirectory() async {
    final base = await _baseDirectoryProvider();
    final directory = Directory(p.join(base.path, folderName));

    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    return directory;
  }

  /// Sao chép ảnh biên lai vào thư mục bền vững và trả về đường dẫn mới.
  Future<String> saveReceipt({
    required int userId,
    required String sourcePath,
  }) async {
    final source = File(sourcePath);

    if (!await source.exists()) {
      throw const ReceiptStorageException('Không tìm thấy ảnh biên lai.');
    }

    final extension = p.extension(sourcePath).toLowerCase();

    if (!allowedExtensions.contains(extension)) {
      throw const ReceiptStorageException(
        'Chỉ hỗ trợ ảnh định dạng JPG, PNG hoặc WebP.',
      );
    }

    final length = await source.length();

    if (length == 0) {
      throw const ReceiptStorageException('Ảnh biên lai không hợp lệ.');
    }

    if (length > maxBytes) {
      throw const ReceiptStorageException('Ảnh quá lớn (tối đa 20 MB).');
    }

    try {
      final directory = await _receiptDirectory();
      final target = p.join(
        directory.path,
        'receipt_${userId}_${DateTime.now().microsecondsSinceEpoch}$extension',
      );

      await source.copy(target);

      return target;
    } on FileSystemException {
      throw const ReceiptStorageException(
        'Không thể lưu ảnh biên lai. Hãy kiểm tra dung lượng bộ nhớ.',
      );
    }
  }

  Future<bool> exists(String path) => File(path).exists();

  Future<bool> isManagedPath(String path) async {
    final directory = await _receiptDirectory();

    return p.isWithin(directory.path, path);
  }

  /// Chỉ xóa nếu file nằm trong thư mục receipts của app VÀ không còn giao
  /// dịch nào tham chiếu. [countReferences] trả về số tham chiếu hiện có.
  Future<void> deleteIfUnreferenced(
    String path,
    Future<int> Function(String path) countReferences,
  ) async {
    try {
      if (!await isManagedPath(path)) return;
      if (await countReferences(path) > 0) return;

      final file = File(path);

      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {
      // Lỗi dọn file không được làm hỏng luồng chính.
    }
  }

  /// Dọn ảnh tạm của image_picker, chỉ khi nằm trong thư mục cache của app.
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