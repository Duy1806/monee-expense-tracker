import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/expense_categories.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/expense.dart';
import '../add_expense_actions.dart';
import '../category_icons.dart';
import '../expense_filter.dart';
import '../providers/expense_controller.dart';
import 'expense_detail_screen.dart';

String _sortLabel(ExpenseSort sort) {
  switch (sort) {
    case ExpenseSort.dateDesc:
      return 'Mới nhất';
    case ExpenseSort.dateAsc:
      return 'Cũ nhất';
    case ExpenseSort.amountDesc:
      return 'Số tiền giảm dần';
    case ExpenseSort.amountAsc:
      return 'Số tiền tăng dần';
  }
}

class ExpenseListScreen extends StatefulWidget {
  const ExpenseListScreen({super.key});

  @override
  State<ExpenseListScreen> createState() => _ExpenseListScreenState();
}

class _ExpenseListScreenState extends State<ExpenseListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ----------------------------------------------------------
  // BỘ LỌC
  // ----------------------------------------------------------

  Future<void> _pickCategory() async {
    final controller = context.read<ExpenseController>();
    final current = controller.filter.category;

    final choice = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.apps_rounded),
                  title: const Text('Tất cả danh mục'),
                  trailing:
                      current == null ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(sheetContext, ''),
                ),
                for (final category in expenseCategories)
                  ListTile(
                    leading: Icon(
                      iconForCategory(category),
                      color: colorForCategory(category),
                    ),
                    title: Text(category),
                    trailing: current == category
                        ? const Icon(Icons.check_rounded)
                        : null,
                    onTap: () => Navigator.pop(sheetContext, category),
                  ),
              ],
            ),
          ),
        );
      },
    );

    if (choice == null) return;

    controller.setCategory(choice.isEmpty ? null : choice);
  }

  Future<void> _pickRange() async {
    final controller = context.read<ExpenseController>();
    final filter = controller.filter;
    final now = DateTime.now();
    final lastDate =
        DateTime(now.year, now.month, now.day).add(const Duration(days: 1));

    DateTimeRange? initial;

    if (filter.start != null &&
        filter.end != null &&
        !filter.end!.isAfter(lastDate)) {
      initial = DateTimeRange(start: filter.start!, end: filter.end!);
    }

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: lastDate,
      initialDateRange: initial,
      helpText: 'Chọn khoảng ngày',
      saveText: 'Áp dụng',
    );

    if (range == null) return;

    controller.setDateRange(range.start, range.end);
  }

  Future<void> _pickSort() async {
    final controller = context.read<ExpenseController>();
    final current = controller.filter.sort;

    final choice = await showModalBottomSheet<ExpenseSort>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final sort in ExpenseSort.values)
                ListTile(
                  title: Text(_sortLabel(sort)),
                  trailing:
                      current == sort ? const Icon(Icons.check_rounded) : null,
                  onTap: () => Navigator.pop(sheetContext, sort),
                ),
            ],
          ),
        );
      },
    );

    if (choice != null) {
      controller.setSort(choice);
    }
  }

  void _clearFilters() {
    _searchController.clear();
    context.read<ExpenseController>().clearFilters();
  }

  // ----------------------------------------------------------
  // XÓA
  // ----------------------------------------------------------

  Future<bool> _confirmDelete(Expense expense) async {
    final result = await showDialog<bool>(
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

    return result == true;
  }

  Future<void> _deleteWithConfirm(Expense expense) async {
    final controller = context.read<ExpenseController>();
    final messenger = ScaffoldMessenger.of(context);

    if (!await _confirmDelete(expense)) return;

    final error = await controller.delete(expense);

    messenger.showSnackBar(
      SnackBar(content: Text(error ?? 'Đã xóa giao dịch.')),
    );
  }

  void _openDetail(Expense expense) {
    final id = expense.id;

    if (id == null) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ExpenseDetailScreen(expenseId: id),
      ),
    );
  }

  // ----------------------------------------------------------
  // GIAO DIỆN
  // ----------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ExpenseController>();

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: Column(
          children: [
            _buildHeader(controller),
            Expanded(child: _buildBody(controller)),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(ExpenseController controller) {
    final filter = controller.filter;
    final scheme = Theme.of(context).colorScheme;

    String rangeLabel = 'Khoảng ngày';

    if (filter.start != null && filter.end != null) {
      rangeLabel =
          '${formatDate(filter.start!)} – ${formatDate(filter.end!)}';
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            key: const Key('expense_search_field'),
            controller: _searchController,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: 'Tìm theo tên giao dịch',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _searchController.text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Xóa tìm kiếm',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        controller.setQuery('');
                      },
                    ),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: (value) {
              controller.setQuery(value);
            },
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                FilterChip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: Text(filter.category ?? 'Danh mục'),
                  selected: filter.category != null,
                  showCheckmark: false,
                  onSelected: (_) => _pickCategory(),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  avatar: const Icon(Icons.date_range_outlined, size: 18),
                  label: Text(rangeLabel),
                  selected: filter.start != null && filter.end != null,
                  showCheckmark: false,
                  onSelected: (_) => _pickRange(),
                ),
                const SizedBox(width: 8),
                ActionChip(
                  avatar: const Icon(Icons.sort_rounded, size: 18),
                  label: Text(_sortLabel(filter.sort)),
                  onPressed: _pickSort,
                ),
                if (filter.isActive) ...[
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: const Icon(Icons.filter_alt_off_outlined, size: 18),
                    label: const Text('Xóa lọc'),
                    onPressed: _clearFilters,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (controller.status == ExpenseLoadStatus.ready &&
              controller.allExpenses.isNotEmpty)
            Card(
              margin: EdgeInsets.zero,
              color: scheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${controller.visibleExpenses.length} giao dịch',
                            style: TextStyle(color: scheme.onPrimaryContainer),
                          ),
                          if (filter.isActive)
                            Text(
                              'trên tổng ${controller.allExpenses.length}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: scheme.onPrimaryContainer,
                                  ),
                            ),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          filter.isActive ? 'Tổng sau lọc' : 'Tổng chi tiêu',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: scheme.onPrimaryContainer,
                              ),
                        ),
                        Text(
                          formatVnd(controller.visibleTotal),
                          key: const Key('expense_visible_total'),
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                fontWeight: FontWeight.w900,
                                color: scheme.onPrimaryContainer,
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildBody(ExpenseController controller) {
    switch (controller.status) {
      case ExpenseLoadStatus.idle:
      case ExpenseLoadStatus.loading:
        if (controller.allExpenses.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
      case ExpenseLoadStatus.error:
        return _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: controller.errorMessage ?? 'Không thể tải giao dịch.',
          actionLabel: 'Thử lại',
          onAction: controller.load,
        );
      case ExpenseLoadStatus.ready:
        break;
    }

    if (controller.allExpenses.isEmpty) {
      return _StateMessage(
        icon: Icons.receipt_long_outlined,
        title: 'Chưa có giao dịch nào',
        message: 'Thêm giao dịch đầu tiên hoặc quét một hóa đơn.',
        actionLabel: 'Thêm giao dịch',
        onAction: () => showAddExpenseOptions(context),
      );
    }

    final visible = controller.visibleExpenses;

    if (visible.isEmpty) {
      return _StateMessage(
        icon: Icons.search_off_rounded,
        title: 'Không có giao dịch phù hợp',
        message: 'Thử đổi từ khóa hoặc bỏ bớt bộ lọc.',
        actionLabel: 'Xóa bộ lọc',
        onAction: _clearFilters,
      );
    }

    return RefreshIndicator(
      onRefresh: controller.load,
      child: ListView.builder(
        key: const Key('expense_list'),
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
        itemCount: visible.length,
        itemBuilder: (context, index) {
          final expense = visible[index];

          return _ExpenseTile(
            key: ValueKey('expense_${expense.id}'),
            expense: expense,
            onTap: () => _openDetail(expense),
            confirmDismiss: (_) async {
              await _deleteWithConfirm(expense);

              // Danh sách do controller cập nhật, không để Dismissible tự gỡ.
              return false;
            },
          );
        },
      ),
    );
  }
}

class _ExpenseTile extends StatelessWidget {
  const _ExpenseTile({
    super.key,
    required this.expense,
    required this.onTap,
    required this.confirmDismiss,
  });

  final Expense expense;
  final VoidCallback onTap;
  final Future<bool?> Function(DismissDirection direction) confirmDismiss;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = colorForCategory(expense.category);

    return Dismissible(
      key: ValueKey('dismiss_${expense.id}'),
      direction: DismissDirection.endToStart,
      confirmDismiss: confirmDismiss,
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        decoration: BoxDecoration(
          color: scheme.errorContainer,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.delete_outline_rounded, color: scheme.error),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(vertical: 4),
        child: ListTile(
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: color.withAlpha(36),
            child: Icon(iconForCategory(expense.category), color: color),
          ),
          title: Text(
            expense.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Row(
            children: [
              Flexible(
                child: Text(
                  '${expense.category} · ${formatDate(expense.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (expense.receiptImagePath != null) ...[
                const SizedBox(width: 6),
                Icon(
                  Icons.receipt_long_outlined,
                  size: 14,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ],
          ),
          trailing: Text(
            formatVnd(expense.amount),
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: scheme.onSurfaceVariant),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(message!, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}