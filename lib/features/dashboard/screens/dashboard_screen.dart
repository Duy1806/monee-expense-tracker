import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../../core/utils/percent_format.dart';
import '../../../data/models/expense.dart';
import '../../budget/providers/budget_controller.dart';
import '../../budget/screens/budget_screen.dart';
import '../../expenses/add_expense_actions.dart';
import '../../expenses/category_icons.dart';
import '../../expenses/providers/expense_controller.dart';
import '../../expenses/screens/expense_detail_screen.dart';
import '../../statistics/screens/statistics_screen.dart';
import '../dashboard_stats.dart';
import '../widgets/category_breakdown_list.dart';
import '../widgets/donut_chart.dart';
import '../widgets/stat_tile.dart';
import '../widgets/weekly_bar_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key, this.onSeeAllTransactions});

  /// Chuyển sang tab Giao dịch. null thì ẩn nút "Xem tất cả".
  final VoidCallback? onSeeAllTransactions;

  @override
  Widget build(BuildContext context) {
    final expenses = context.watch<ExpenseController>();
    final budget = context.watch<BudgetController>();

    final loading = expenses.status == ExpenseLoadStatus.idle ||
        expenses.status == ExpenseLoadStatus.loading;

    if (loading && expenses.allExpenses.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (expenses.status == ExpenseLoadStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 56),
              const SizedBox(height: 16),
              Text(
                expenses.errorMessage ?? 'Không thể tải dữ liệu.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: expenses.load,
                child: const Text('Thử lại'),
              ),
            ],
          ),
        ),
      );
    }

    final stats = computeDashboardStats(
      expenses.allExpenses,
      budget: budget.amount,
    );

    return RefreshIndicator(
      onRefresh: () async {
        await expenses.load();
        await budget.load();
      },
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
            children: [
              _HeroCard(stats: stats),
              if (stats.budgetLevel != BudgetLevel.ok) ...[
                const SizedBox(height: 12),
                BudgetAlertBanner(stats: stats),
              ],
              const SizedBox(height: 12),
              if (!stats.hasAnyExpense)
                _EmptyHint(
                  onAdd: () => showAddExpenseOptions(context),
                )
              else ...[
                _StatGrid(stats: stats),
                const SizedBox(height: 12),
                _CategoryCard(stats: stats),
                const SizedBox(height: 12),
                _WeekCard(stats: stats),
                const SizedBox(height: 12),
                _RecentCard(
                  recent: stats.recent,
                  onSeeAll: onSeeAllTransactions,
                ),
              ],
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const StatisticsScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.insights_outlined),
                label: const Text('Thống kê theo tháng'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// THẺ TỔNG QUAN THÁNG
// ------------------------------------------------------------

class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final Color barColor;

    switch (stats.budgetLevel) {
      case BudgetLevel.ok:
        barColor = const Color(0xFFB5E7CE);
      case BudgetLevel.warning:
        barColor = const Color(0xFFFFD166);
      case BudgetLevel.exceeded:
        barColor = const Color(0xFFFF8A80);
    }

    final exceeded = stats.remaining < 0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF173B32), Color(0xFF246C53)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Chi tiêu tháng ${stats.now.month}/${stats.now.year}',
            style: const TextStyle(color: Color(0xFFD4E8DE), fontSize: 13),
          ),
          const SizedBox(height: 6),
          Text(
            formatVnd(stats.monthTotal),
            key: const Key('dashboard_month_total'),
            style: textTheme.headlineLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: stats.usedRatio.clamp(0.0, 1.0),
              minHeight: 8,
              color: barColor,
              backgroundColor: Colors.white24,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Ngân sách ${formatVnd(stats.budget)}',
                  style: const TextStyle(color: Color(0xFFD4E8DE)),
                ),
              ),
              Text(
                exceeded
                    ? 'Vượt ${formatVnd(-stats.remaining)}'
                    : 'Còn ${formatVnd(stats.remaining)}',
                key: const Key('dashboard_remaining'),
                style: TextStyle(
                  color: barColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const BudgetScreen(),
                  ),
                );
              },
              icon: const Icon(Icons.tune_rounded, size: 18),
              label: const Text('Đặt ngân sách'),
              style: TextButton.styleFrom(foregroundColor: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 48,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 12),
            Text(
              'Chưa có giao dịch nào',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 6),
            const Text(
              'Thêm giao dịch đầu tiên hoặc quét hóa đơn để xem thống kê.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add_rounded),
              label: const Text('Thêm giao dịch'),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// Ô SỐ LIỆU
// ------------------------------------------------------------

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final top = stats.topCategory;

    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.today_outlined,
                label: 'Hôm nay',
                value: formatVnd(stats.todayTotal),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: Icons.date_range_outlined,
                label: '7 ngày gần nhất',
                value: formatVnd(stats.weekTotal),
                subtitle: stats.weekChangePercent == null
                    ? null
                    : '${formatPercent(stats.weekChangePercent!)} '
                        'so với 7 ngày trước',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: StatTile(
                icon: Icons.receipt_long_outlined,
                label: 'Giao dịch trong tháng',
                value: '${stats.monthCount}',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatTile(
                icon: top == null
                    ? Icons.category_outlined
                    : iconForCategory(top.category),
                label: 'Danh mục chi nhiều nhất',
                value: top?.category ?? '—',
                subtitle: top == null ? null : formatVnd(top.amount),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ------------------------------------------------------------
// BIỂU ĐỒ
// ------------------------------------------------------------

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chi tiêu theo danh mục', style: textTheme.titleMedium),
            const SizedBox(height: 16),
            if (stats.categoryTotals.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(
                  child: Text('Chưa có chi tiêu trong tháng này.'),
                ),
              )
            else ...[
              Center(
                child: DonutChart(
                  data: stats.categoryTotals,
                  center: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('Tháng này', style: textTheme.bodySmall),
                      Text(
                        formatVnd(stats.monthTotal),
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              CategoryBreakdownList(items: stats.categoryTotals),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeekCard extends StatelessWidget {
  const _WeekCard({required this.stats});

  final DashboardStats stats;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Chi tiêu 7 ngày gần nhất', style: textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              describeChange(stats.weekChangePercent, '7 ngày trước đó'),
              style: textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            WeeklyBarChart(days: stats.last7Days),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------
// GIAO DỊCH GẦN ĐÂY
// ------------------------------------------------------------

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.recent, required this.onSeeAll});

  final List<Expense> recent;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text('Gần đây', style: textTheme.titleMedium),
                  ),
                  if (onSeeAll != null)
                    TextButton(
                      onPressed: onSeeAll,
                      child: const Text('Xem tất cả'),
                    ),
                ],
              ),
            ),
            for (final expense in recent)
              ListTile(
                key: ValueKey('recent_${expense.id}'),
                onTap: expense.id == null
                    ? null
                    : () {
                        Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) =>
                                ExpenseDetailScreen(expenseId: expense.id!),
                          ),
                        );
                      },
                leading: CircleAvatar(
                  backgroundColor:
                      colorForCategory(expense.category).withAlpha(36),
                  child: Icon(
                    iconForCategory(expense.category),
                    color: colorForCategory(expense.category),
                  ),
                ),
                title: Text(
                  expense.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${expense.category} · ${formatDate(expense.date)}',
                ),
                trailing: Text(
                  formatVnd(expense.amount),
                  style: textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}