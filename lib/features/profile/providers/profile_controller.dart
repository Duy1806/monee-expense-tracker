import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

import '../../../services/avatar_storage_service.dart';
import '../../auth/providers/auth_controller.dart';

typedef AvatarImagePicker = Future<String?> Function(ImageSource source);

Future<String?> _defaultImagePicker(ImageSource source) async {
  final picked = await ImagePicker().pickImage(
    source: source,
    maxWidth: 768,
    maxHeight: 768,
    imageQuality: 85,
  );

  return picked?.path;
}

class ProfileController extends ChangeNotifier {
  ProfileController(
    this._auth,
    this._storage, {
    AvatarImagePicker? pickImage,
  }) : _pickImage = pickImage ?? _defaultImagePicker;

  final AuthController _auth;
  final AvatarStorageService _storage;
  final AvatarImagePicker _pickImage;

  bool _busy = false;

  bool get busy => _busy;

  void _setBusy(bool value) {
    _busy = value;
    notifyListeners();
  }

  /// Trả về null nếu thành công hoặc người dùng hủy chọn ảnh;
  /// ngược lại trả về thông báo lỗi tiếng Việt.
  Future<String?> changeAvatar(ImageSource source) async {
    if (_busy) return null;

    final user = _auth.user;

    if (user == null) return 'Bạn chưa đăng nhập.';

    if (kIsWeb) {
      return 'Ảnh đại diện chưa được hỗ trợ trên trình duyệt. '
          'Hãy dùng ứng dụng Android.';
    }

    _setBusy(true);

    try {
      final pickedPath = await _pickImage(source);

      if (pickedPath == null) return null; // Người dùng hủy.

      final String newPath;

      try {
        newPath = await _storage.saveAvatar(
          userId: user.id,
          sourcePath: pickedPath,
        );
      } finally {
        await _storage.discardTemporary(pickedPath);
      }

      final error = await _auth.updateAvatarPath(newPath);

      if (error != null) {
        await _storage.deleteAvatar(newPath);
        return error;
      }

      final oldPath = user.avatarPath;

      if (oldPath != null && oldPath != newPath) {
        await _storage.deleteAvatar(oldPath);
      }

      return null;
    } on AvatarStorageException catch (e) {
      return e.message;
    } catch (_) {
      return 'Không thể đổi ảnh đại diện. '
          'Hãy kiểm tra quyền truy cập camera hoặc thư viện ảnh.';
    } finally {
      _setBusy(false);
    }
  }

  Future<String?> removeAvatar() async {
    if (_busy) return null;

    final user = _auth.user;

    if (user == null) return 'Bạn chưa đăng nhập.';

    final oldPath = user.avatarPath;

    if (oldPath == null) return null;

    _setBusy(true);

    try {
      final error = await _auth.updateAvatarPath(null);

      if (error != null) return error;

      await _storage.deleteAvatar(oldPath);

      return null;
    } finally {
      _setBusy(false);
    }
  }
}