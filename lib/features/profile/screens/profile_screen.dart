import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/providers/auth_controller.dart';
import 'change_password_screen.dart';
import 'edit_profile_screen.dart';

/// Nội dung tab Hồ sơ. Khung Scaffold do màn hình chứa cung cấp.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key, this.onOpenSettings});

  /// Nếu có, hiển thị thêm mục "Cài đặt" (đợt 8).
  final VoidCallback? onOpenSettings;

  Future<void> _confirmLogout(BuildContext context) async {
    final auth = context.read<AuthController>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Đăng xuất?'),
          content: const Text(
            'Bạn sẽ cần đăng nhập lại để xem dữ liệu chi tiêu của mình.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Hủy'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthController>().user;

    if (user == null) {
      return const SizedBox.shrink();
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        UserAvatar(
                          name: user.name,
                          avatarPath: user.avatarPath,
                          radius: 44,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          user.name,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          user.email,
                          style: textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Thành viên từ ${formatDate(user.createdAt)}',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.edit_outlined),
                        title: const Text('Chỉnh sửa hồ sơ'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_reset_rounded),
                        title: const Text('Đổi mật khẩu'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          );
                        },
                      ),
                      if (onOpenSettings != null) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.settings_outlined),
                          title: const Text('Cài đặt'),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: onOpenSettings,
                        ),
                      ],
                      const Divider(height: 1),
                      ListTile(
                        leading: Icon(Icons.logout_rounded, color: scheme.error),
                        title: Text(
                          'Đăng xuất',
                          style: TextStyle(color: scheme.error),
                        ),
                        onTap: () => _confirmLogout(context),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}