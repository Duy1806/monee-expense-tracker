import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../ai/providers/ai_controller.dart';
import '../../budget/providers/budget_controller.dart';
import '../../budget/screens/budget_screen.dart';
import '../providers/theme_controller.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final budget = context.watch<BudgetController>();
    final aiConfigured = context.read<AiController>().isConfigured;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Cài đặt')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Giao diện', style: textTheme.titleSmall),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.light,
                      icon: Icon(Icons.light_mode_outlined),
                      label: Text('Sáng'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      icon: Icon(Icons.dark_mode_outlined),
                      label: Text('Tối'),
                    ),
                    ButtonSegment(
                      value: ThemeMode.system,
                      icon: Icon(Icons.brightness_auto_outlined),
                      label: Text('Hệ thống'),
                    ),
                  ],
                  selected: {theme.mode},
                  onSelectionChanged: (selection) {
                    theme.setMode(selection.first);
                  },
                ),
                const SizedBox(height: 24),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.savings_outlined),
                        title: const Text('Ngân sách tháng'),
                        subtitle: Text(formatVnd(budget.amount)),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const BudgetScreen(),
                            ),
                          );
                        },
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.auto_awesome_outlined),
                        title: const Text('Phân tích AI (Gemini)'),
                        subtitle: Text(
                          aiConfigured
                              ? 'Đã cấu hình'
                              : 'Chưa cấu hình khóa API (xem README)',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dữ liệu & quyền riêng tư',
                        style: textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '• Giao dịch, ngân sách và ảnh hóa đơn được lưu ngay '
                        'trên thiết bị này, riêng cho từng tài khoản.\n'
                        '• Nhận dạng hóa đơn chạy trên thiết bị, không cần '
                        'Internet.\n'
                        '• Phân tích AI chỉ gửi số liệu tổng hợp (ngày, danh '
                        'mục, số tiền) tới Google Gemini, không gửi tên giao '
                        'dịch, họ tên, email hay ảnh.',
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.info_outline_rounded),
                    title: const Text('Về $kAppName'),
                    subtitle: const Text('Phiên bản $kAppVersion'),
                    onTap: () {
                      showAboutDialog(
                        context: context,
                        applicationName: kAppName,
                        applicationVersion: kAppVersion,
                        applicationLegalese:
                            'Ứng dụng quản lý chi tiêu cá nhân offline-first.',
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}