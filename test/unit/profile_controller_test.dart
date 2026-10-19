import 'dart:io';

import 'package:expense_tracker/core/security/password_hasher.dart';
import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/repositories/account_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/auth/providers/auth_controller.dart';
import 'package:expense_tracker/features/profile/providers/profile_controller.dart';
import 'package:expense_tracker/services/avatar_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late AuthController auth;
  late ProfileController profile;
  String? nextPick;

  File makePicked(String name) {
    final file = File(p.join(tempDir.path, name));
    file.writeAsBytesSync([1, 2, 3, 4]);
    return file;
  }

  int avatarCount() {
    final dir = Directory(p.join(baseDir.path, AvatarStorageService.folderName));
    return dir.existsSync() ? dir.listSync().length : 0;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    baseDir = Directory.systemTemp.createTempSync('monee_profile_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_profile_tmp_');
    nextPick = null;

    final store = PrefsDataStore();
    final accounts = AccountRepository(
      store,
      SettingsRepository(store),
      const PasswordHasher(iterations: 1000, useIsolate: false),
    );

    auth = AuthController(accounts);

    await auth.register(
      name: 'Nguyễn An',
      email: 'an@example.com',
      password: 'matkhau123',
      confirmPassword: 'matkhau123',
    );

    final storage = AvatarStorageService(
      baseDirectoryProvider: () async => baseDir,
      temporaryDirectoryProvider: () async => tempDir,
    );

    profile = ProfileController(
      auth,
      storage,
      pickImage: (source) async => nextPick,
    );
  });

  tearDown(() {
    for (final dir in [baseDir, tempDir]) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Bỏ qua.
      }
    }
  });

  test('đổi ảnh: lưu vào thư mục app, cập nhật hồ sơ, dọn ảnh tạm', () async {
    final picked = makePicked('a.jpg');
    nextPick = picked.path;

    final error = await profile.changeAvatar(ImageSource.gallery);

    expect(error, isNull);

    final path = auth.user!.avatarPath!;

    expect(File(path).existsSync(), isTrue);
    expect(
      p.isWithin(p.join(baseDir.path, AvatarStorageService.folderName), path),
      isTrue,
    );
    expect(picked.existsSync(), isFalse);
    expect(profile.busy, isFalse);
  });

  test('đổi ảnh lần hai: xóa ảnh cũ, chỉ còn ảnh mới', () async {
    nextPick = makePicked('a.jpg').path;
    await profile.changeAvatar(ImageSource.gallery);
    final oldPath = auth.user!.avatarPath!;

    nextPick = makePicked('b.png').path;
    final error = await profile.changeAvatar(ImageSource.camera);

    expect(error, isNull);

    final newPath = auth.user!.avatarPath!;

    expect(newPath, isNot(oldPath));
    expect(File(oldPath).existsSync(), isFalse);
    expect(File(newPath).existsSync(), isTrue);
    expect(avatarCount(), 1);
  });

  test('người dùng hủy chọn ảnh: không đổi gì và không báo lỗi', () async {
    nextPick = null;

    final error = await profile.changeAvatar(ImageSource.gallery);

    expect(error, isNull);
    expect(auth.user!.avatarPath, isNull);
    expect(avatarCount(), 0);
  });

  test('định dạng ảnh không hỗ trợ: báo lỗi và không đổi hồ sơ', () async {
    nextPick = makePicked('tai-lieu.pdf').path;

    final error = await profile.changeAvatar(ImageSource.gallery);

    expect(error, isNotNull);
    expect(auth.user!.avatarPath, isNull);
    expect(avatarCount(), 0);
  });

  test('xóa ảnh đại diện: gỡ khỏi hồ sơ và xóa file', () async {
    nextPick = makePicked('a.jpg').path;
    await profile.changeAvatar(ImageSource.gallery);
    final path = auth.user!.avatarPath!;

    final error = await profile.removeAvatar();

    expect(error, isNull);
    expect(auth.user!.avatarPath, isNull);
    expect(File(path).existsSync(), isFalse);
  });

  test('chưa đăng nhập thì báo lỗi', () async {
    await auth.logout();

    expect(await profile.changeAvatar(ImageSource.gallery), isNotNull);
    expect(await profile.removeAvatar(), isNotNull);
  });
}