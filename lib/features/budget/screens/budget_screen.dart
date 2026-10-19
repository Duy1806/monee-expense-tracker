import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/money_parser.dart';
import '../../../core/utils/percent_format.dart';
import '../../dashboard/dashboard_stats.dart';
import '../../expenses/providers/expense_controller.dart';
import '../providers/budget_controller.dart';

class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  static const List<double> _suggestions = [
    3000000,
    5000000,
    8000000,
    10000000,
    15000000,
  ];

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _amountController = TextEditingController(
      text: context.read<BudgetController>().amount.round().toString(),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String? _validate(String? value) {
    final amount = parseAmountInput(value ?? '');

    if (amount == null) {
      return 'Số tiền không hợp lệ. Ví dụ: 8000000 hoặc 8.000.000';
    }

    if (amount <= 0) return 'Ngân sách phải lớn hơn 0.';
    if (amount > kMaxMoneyAmount) return 'Ngân sách quá lớn.';

    return null;
  }

  Future<void> _save() async {
    if (_saving) return;

    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) return;

    final amount = parseAmountInput(_amountController.text);

    if (amount == null) return;

    final budget = context.read<BudgetController>();
    final messenger = ScaffoldMessenger.of(context);

    setState(() {
      _saving = true;
      _error = null;
    });

    final error = await budget.setAmount(amount);

    if (!mounted) return;

    setState(() {
      _saving = false;
      _error = error;
    });

    if (error == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Đã lưu ngân sách tháng này.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final budget = context.watch<BudgetController>();
    final expenses = context.watch<ExpenseController>();

    final stats = computeDashboardStats(
      expenses.allExpenses,
      budget: budget.amount,
    );

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final month = budget.month;

    return Scaffold(
      appBar: AppBar(
        title: Text('Ngân sách tháng ${month.month}/${month.year}'),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: ListView(
              padding: const EdgeInsets.all(16),
              keyboardDismissBehavior:
                  ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Ngân sách hiện tại',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatVnd(budget.amount),
                          key: const Key('budget_current_amount'),
                          style: textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: stats.usedRatio.clamp(0.0, 1.0),
                            minHeight: 10,
                            color: _levelColor(stats.budgetLevel, scheme),
                            backgroundColor: scheme.surfaceContainerHighest,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _Figure(
                                label: 'Đã chi',
                                value: formatVnd(stats.monthTotal),
                              ),
                            ),
                            Expanded(
                              child: _Figure(
                                label: stats.remaining >= 0
                                    ? 'Còn lại'
                                    : 'Vượt ngân sách',
                                value: formatVnd(stats.remaining.abs()),
                              ),
                            ),
                            Expanded(
                              child: _Figure(
                                label: 'Đã dùng',
                                value: formatPercent(
                                  stats.usedRatio * 100,
                                  showSign: false,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (stats.budgetLevel != BudgetLevel.ok) ...[
                          const SizedBox(height: 12),
                          BudgetAlertBanner(stats: stats),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (_error != null)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: scheme.errorContainer,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(color: scheme.onErrorContainer),
                          ),
                        ),
                      TextFormField(
                        controller: _amountController,
                        enabled: !_saving,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            RegExp(r'[0-9., ]'),
                          ),
                        ],
                        decoration: const InputDecoration(
                          labelText: 'Ngân sách mỗi tháng',
                          prefixIcon: Icon(Icons.savings_outlined),
                          suffixText: 'đ',
                          border: OutlineInputBorder(),
                        ),
                        validator: _validate,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final value in _suggestions)
                            ActionChip(
                              label: Text(formatVnd(value)),
                              onPressed: _saving
                                  ? null
                                  : () {
                                      _amountController.text =
                                          value.round().toString();
                                    },
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _saving ? null : _save,
                        icon: _saving
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.check_rounded),
                        label: const Text('Lưu ngân sách'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Ngân sách áp dụng cho tháng này và các tháng sau, '
                        'cho đến khi bạn đặt mức mới.',
                        textAlign: TextAlign.center,
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
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

Color _levelColor(BudgetLevel level, ColorScheme scheme) {
  switch (level) {
    case BudgetLevel.ok:
      return scheme.primary;
    case BudgetLevel.warning:
      return const Color(0xFFF59E0B);
    case BudgetLevel.exceeded:
      return scheme.error;
  }
}

class _Figure extends StatelessWidget {
  const _Figure({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
      ],
    );
  }
}

/// Banner cảnh báo ngân sách: "sắp hết" hoặc "đã vượt".
class BudgetAlertBanner extends StatelessWidget {
  const BudgetAlertBanner({super.key, required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final exceeded = stats.budgetLevel == BudgetLevel.exceeded;

    if (stats.budgetLevel == BudgetLevel.ok) {
      return const SizedBox.shrink();
    }

    final Color background =
        exceeded ? scheme.errorContainer : const Color(0xFFFFF3CD);
    final Color foreground =
        exceeded ? scheme.onErrorContainer : const Color(0xFF5C4400);

    final message = exceeded
        ? 'Đã vượt ngân sách ${formatVnd(-stats.remaining)}. '
            'Hãy cân nhắc giảm các khoản chi không cần thiết.'
        : 'Bạn đã dùng ${formatPercent(stats.usedRatio * 100, showSign: false)} '
            'ngân sách tháng này, còn lại ${formatVnd(stats.remaining)}.';

    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              exceeded
                  ? Icons.error_outline_rounded
                  : Icons.warning_amber_rounded,
              size: 20,
              color: foreground,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(message, style: TextStyle(color: foreground)),
            ),
          ],
        ),
      ),
    );
  }
}