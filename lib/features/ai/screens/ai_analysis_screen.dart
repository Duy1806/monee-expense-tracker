import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/formatters.dart';
import '../../budget/providers/budget_controller.dart';
import '../../dashboard/dashboard_stats.dart';
import '../../dashboard/widgets/stat_tile.dart';
import '../../expenses/providers/expense_controller.dart';
import '../providers/ai_controller.dart';
import '../widgets/ai_analysis_content.dart';

String _formatTime(DateTime t) {
  final hh = t.hour.toString().padLeft(2, '0');
  final mm = t.minute.toString().padLeft(2, '0');

  return '$hh:$mm ${formatDate(t)}';
}

class AiAnalysisScreen extends StatelessWidget {
  const AiAnalysisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final ai = context.watch<AiController>();
    final expenses = context.watch<ExpenseController>();
    final budget = context.watch<BudgetController>();

    final stats = computeDashboardStats(
      expenses.allExpenses,
      budget: budget.amount,
    );

    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final canAnalyze = ai.isConfigured && !ai.isLoading;

    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF173B32), Color(0xFF246C53)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFB5E7CE),
                      size: 25,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Phân tích chi tiêu AI',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Nhận xét, gợi ý ngân sách và mục tiêu tiết kiệm',
                          style: TextStyle(
                            color: Color(0xFFD4E8DE),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: StatTile(
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Chi tiêu tháng này',
                    value: formatVnd(stats.monthTotal),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: StatTile(
                    icon: Icons.savings_outlined,
                    label: stats.remaining >= 0
                        ? 'Ngân sách còn lại'
                        : 'Vượt ngân sách',
                    value: formatVnd(stats.remaining.abs()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.privacy_tip_outlined,
                    size: 20,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Khi phân tích, ứng dụng chỉ gửi số liệu tổng hợp '
                      '(ngày, danh mục, số tiền) tới Google Gemini. Tên giao '
                      'dịch, họ tên, email và ảnh hóa đơn không được gửi. '
                      'Cần có kết nối Internet.',
                      style: textTheme.bodySmall?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (!ai.isConfigured)
              Container(
                key: const Key('ai_not_configured'),
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.tertiaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'Tính năng AI chưa được cấu hình trên bản chạy này. '
                  'Các chức năng khác vẫn hoạt động bình thường.',
                  style: TextStyle(color: scheme.onTertiaryContainer),
                ),
              ),
            FilledButton.icon(
              key: const Key('ai_analyze_button'),
              onPressed: canAnalyze
                  ? () => ai.analyze(
                        expenses: expenses.allExpenses,
                        budget: budget.amount,
                      )
                  : null,
              icon: ai.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(
                ai.isLoading ? 'Đang phân tích…' : 'Phân tích bằng Gemini',
              ),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
            ),
            const SizedBox(height: 12),
            if (ai.isLoading)
              Semantics(
                liveRegion: true,
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Column(
                    children: [
                      LinearProgressIndicator(),
                      SizedBox(height: 8),
                      Text(
                        'AI đang phân tích, có thể mất vài chục giây…',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            if (ai.status == AiStatus.error && ai.errorMessage != null)
              Semantics(
                liveRegion: true,
                child: Container(
                  key: const Key('ai_error'),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.error_outline_rounded,
                            size: 20,
                            color: scheme.onErrorContainer,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              ai.errorMessage!,
                              style:
                                  TextStyle(color: scheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                      if (ai.isConfigured) ...[
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () => ai.analyze(
                            expenses: expenses.allExpenses,
                            budget: budget.amount,
                          ),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Thử lại'),
                          style: TextButton.styleFrom(
                            foregroundColor: scheme.onErrorContainer,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (ai.status == AiStatus.success && ai.result != null)
              Card(
                key: const Key('ai_result'),
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.lightbulb_outline_rounded,
                            color: scheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Báo cáo AI',
                              style: textTheme.titleMedium,
                            ),
                          ),
                          if (ai.analyzedAt != null)
                            Text(
                              _formatTime(ai.analyzedAt!),
                              style: textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      AiAnalysisContent(text: ai.result!),
                      const Divider(height: 24),
                      Text(
                        'Nội dung do AI tạo, chỉ mang tính tham khảo và '
                        'không phải tư vấn tài chính chuyên nghiệp. '
                        'Hãy tự kiểm tra trước khi ra quyết định.',
                        key: const Key('ai_disclaimer'),
                        style: textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}