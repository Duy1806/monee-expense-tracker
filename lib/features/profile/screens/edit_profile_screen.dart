import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../../core/validators/auth_validator.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_controller.dart';
import '../providers/profile_controller.dart';

enum _AvatarAction { camera, gallery, remove }

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(
      text: context.read<AuthController>().user?.name ?? '',
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _showAvatarOptions() async {
    final profile = context.read<ProfileController>();
    final messenger = ScaffoldMessenger.of(context);
    final hasAvatar = context.read<AuthController>().user?.avatarPath != null;

    final action = await showModalBottomSheet<_AvatarAction>(
      context: context,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_camera_outlined),
                title: const Text('Chụp ảnh'),
                onTap: () => Navigator.pop(sheetContext, _AvatarAction.camera),
              ),
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Chọn từ thư viện'),
                onTap: () => Navigator.pop(sheetContext, _AvatarAction.gallery),
              ),
              if (hasAvatar)
                ListTile(
                  leading: const Icon(Icons.delete_outline_rounded),
                  title: const Text('Xóa ảnh đại diện'),
                  onTap: () => Navigator.pop(sheetContext, _AvatarAction.remove),
                ),
            ],
          ),
        );
      },
    );

    if (action == null) return;

    final String? error = switch (action) {
      _AvatarAction.camera => await profile.changeAvatar(ImageSource.camera),
      _AvatarAction.gallery => await profile.changeAvatar(ImageSource.gallery),
      _AvatarAction.remove => await profile.removeAvatar(),
    };

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final auth = context.read<AuthController>();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    setState(() => _saving = true);

    final error = await auth.updateName(_nameController.text);

    if (!mounted) return;

    setState(() => _saving = false);

    if (error != null) {
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Đã cập nhật hồ sơ.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;
    final busy = context.watch<ProfileController>().busy;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Chỉnh sửa hồ sơ')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          UserAvatar(
                            name: user.name,
                            avatarPath: user.avatarPath,
                            radius: 52,
                          ),
                          if (busy)
                            const SizedBox(
                              width: 104,
                              height: 104,
                              child: CircularProgressIndicator(strokeWidth: 3),
                            ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: IconButton.filled(
                              tooltip: 'Đổi ảnh đại diện',
                              onPressed: busy ? null : _showAvatarOptions,
                              icon: const Icon(Icons.photo_camera_rounded),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                    TextFormField(
                      controller: _nameController,
                      enabled: !_saving,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _save(),
                      decoration: const InputDecoration(
                        labelText: 'Họ tên',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                        border: OutlineInputBorder(),
                      ),
                      validator: validateName,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      initialValue: user.email,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Email',
                        prefixIcon: Icon(Icons.mail_outline_rounded),
                        border: OutlineInputBorder(),
                        helperText:
                            'Email là định danh đăng nhập và hiện không thể thay đổi.',
                      ),
                    ),
                    const SizedBox(height: 28),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48),
                      ),
                      onPressed: _saving ? null : _save,
                      child: _saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Lưu thay đổi'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}