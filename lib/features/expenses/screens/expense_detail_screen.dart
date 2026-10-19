import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../data/models/expense.dart';
import '../category_icons.dart';
import '../providers/expense_controller.dart';
import '../widgets/receipt_image.dart';
import 'expense_form_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  const ExpenseDetailScreen({super.key, required this.expenseId});

  final int expenseId;

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  bool _deleting = false;

  Expense? _find(ExpenseController controller) {
    for (final expense in controller.allExpenses) {
      if (expense.id == widget.expenseId) return expense;
    }

    return null;
  }

  Future<void> _edit(Expense expense) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => ExpenseFormScreen(expense: expense),
      ),
    );

    if (saved == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã cập nhật giao dịch.')),
      );
    }
  }

  Future<void> _delete(Expense expense) async {
    if (_deleting) return;

    final controller = context.read<ExpenseController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final scheme = Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: const Text('Xóa giao dịch?'),
          content: Text(
            '"${expense.title}" (${formatVnd(expense.amount)}) sẽ bị xóa '
            'và không thể khôi phục.',
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
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirmed != true || !mounted) return;

    setState(() => _deleting = true);

    final error = await controller.delete(expense);

    if (!mounted) return;

    if (error != null) {
      setState(() => _deleting = false);
      messenger.showSnackBar(SnackBar(content: Text(error)));
      return;
    }

    messenger.showSnackBar(
      const SnackBar(content: Text('Đã xóa giao dịch.')),
    );
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();
    final expense = _find(controller);

    if (expense == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Chi tiết giao dịch')),
        body: const Center(
          child: Padding(
            padding: EdgeInsets.all(24),
            child: Text('Không tìm thấy giao dịch.'),
          ),
        ),
      );
    }

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final categoryColor = colorForCategory(expense.category);
    final receipt = expense.receiptImagePath;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chi tiết giao dịch'),
        actions: [
          IconButton(
            tooltip: 'Sửa',
            onPressed: _deleting ? null : () => _edit(expense),
            icon: const Icon(Icons.edit_outlined),
          ),
          IconButton(
            tooltip: 'Xóa',
            onPressed: _deleting ? null : () => _delete(expense),
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: categoryColor.withAlpha(36),
                          child: Icon(
                            iconForCategory(expense.category),
                            color: categoryColor,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          expense.title,
                          textAlign: TextAlign.center,
                          style: textTheme.titleLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatVnd(expense.amount),
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Column(
                    children: [
                      _InfoRow(
                        icon: Icons.category_outlined,
                        label: 'Danh mục',
                        value: expense.category,
                      ),
                      const Divider(height: 1),
                      _InfoRow(
                        icon: Icons.event_outlined,
                        label: 'Ngày giao dịch',
                        value: formatDate(expense.date),
                      ),
                      if (expense.createdAt != null) ...[
                        const Divider(height: 1),
                        _InfoRow(
                          icon: Icons.history_rounded,
                          label: 'Ngày tạo',
                          value: formatDate(expense.createdAt!),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (receipt != null)
                  Card(
                    margin: EdgeInsets.zero,
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReceiptViewerScreen(path: receipt),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.receipt_long_outlined),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Ảnh hóa đơn',
                                    style: textTheme.titleSmall,
                                  ),
                                ),
                                Text(
                                  'Chạm để phóng to',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ReceiptImage(path: receipt, height: 220),
                          ],
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _deleting ? null : () => _delete(expense),
                  icon: _deleting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.delete_outline_rounded),
                  label: const Text('Xóa giao dịch'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: scheme.error,
                    minimumSize: const Size.fromHeight(48),
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

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      leading: Icon(icon, color: scheme.onSurfaceVariant),
      title: Text(label),
      trailing: Text(
        value,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}