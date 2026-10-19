import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/legacy_claim_controller.dart';

/// Gọi sau khi đăng nhập. Chỉ hiển thị nếu còn giao dịch cũ chưa có chủ.
Future<void> showLegacyClaimDialogIfNeeded(
  BuildContext context, {
  required int userId,
}) async {
  final controller = context.read<LegacyClaimController>();
  final messenger = ScaffoldMessenger.of(context);

  await controller.refresh();

  if (!context.mounted || !controller.shouldPrompt) return;

  final accept = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Nhận lại dữ liệu cũ?'),
        content: Text(
          'Phát hiện ${controller.pendingCount} giao dịch được lưu trước khi '
          'ứng dụng có tài khoản. Dữ liệu này chưa thuộc về ai và chỉ có thể '
          'gán cho MỘT tài khoản, một lần duy nhất.\n\n'
          'Bạn có muốn nhận về tài khoản hiện tại không?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Để sau'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Nhận về tài khoản này'),
          ),
        ],
      );
    },
  );

  if (accept != true) {
    controller.dismissForSession();
    return;
  }

  try {
    final count = await controller.claim(userId);
    messenger.showSnackBar(
      SnackBar(content: Text('Đã nhận $count giao dịch cũ.')),
    );
  } catch (_) {
    messenger.showSnackBar(
      const SnackBar(
        content: Text('Không thể nhận dữ liệu cũ. Vui lòng thử lại.'),
      ),
    );
  }
}