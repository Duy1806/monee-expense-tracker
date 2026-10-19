import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/percent_format.dart';
import '../../dashboard/widgets/category_breakdown_list.dart';
import '../../dashboard/widgets/donut_chart.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../../expenses/providers/expense_controller.dart';
import '../monthly_report.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();

    final now = DateTime.now();

    _month = DateTime(now.year, now.month);
  }

  bool get _isCurrentMonth {
    final now = DateTime.now();

    return _month.year == now.year && _month.month == now.month;
  }

  bool get _isEarliestMonth => _month.year <= 2000 && _month.month <= 1;

  void _shift(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseController>();
    final report = computeMonthlyReport(expenses.allExpenses, month: _month);
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Thống kê')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  margin: EdgeInsets.zero,
                  child: Row(
                    children: [
                      IconButton(
                        tooltip: 'Tháng trước',
                        onPressed: _isEarliestMonth ? null : () => _shift(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Expanded(
                        child: Text(
                          'Tháng ${_month.month}/${_month.year}',
                          key: const Key('statistics_month_label'),
                          textAlign: TextAlign.center,
                          style: textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tháng sau',
                        onPressed: _isCurrentMonth ? null : () => _shift(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tổng chi tiêu',
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formatVnd(report.total),
                          key: const Key('statistics_total'),
                          style: textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: scheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          describeChange(report.changePercent, 'tháng trước'),
                          style: textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: StatTile(
                        icon: Icons.calendar_view_day_outlined,
                        label: 'Trung bình mỗi ngày',
                        value: formatVnd(report.averagePerDay),
                        subtitle: 'Trên ${report.dayCount} ngày',
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: StatTile(
                        icon: Icons.receipt_long_outlined,
                        label: 'Số giao dịch',
                        value: '${report.count}',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Theo danh mục', style: textTheme.titleMedium),
                        const SizedBox(height: 16),
                        if (report.categories.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 24),
                            child: Center(
                              child: Text('Chưa có chi tiêu trong tháng này.'),
                            ),
                          )
                        else ...[
                          Center(
                            child: DonutChart(
                              data: report.categories,
                              center: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '${report.count}',
                                    style: textTheme.headlineSmall?.copyWith(
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  Text(
                                    'giao dịch',
                                    style: textTheme.bodySmall,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          CategoryBreakdownList(items: report.categories),
                        ],
                      ],
                    ),
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