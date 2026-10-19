import '../../data/models/expense.dart';
import '../dashboard/dashboard_stats.dart';
import '../statistics/monthly_report.dart';

class SpendingSummary {
  const SpendingSummary({required this.text, required this.hasData});

  /// Văn bản dữ liệu tổng hợp để gửi cho AI.
  final String text;

  /// false nếu người dùng chưa có giao dịch nào.
  final bool hasData;
}

String _isoDate(DateTime date) {
  final month = date.month.toString().padLeft(2, '0');
  final day = date.day.toString().padLeft(2, '0');

  return '${date.year}-$month-$day';
}

String _vnd(double amount) => '${amount.round()} VND';

/// Tóm tắt số liệu để gửi AI. Chỉ gồm ngày, danh mục và số tiền.
/// Tuyệt đối không đưa tên giao dịch hay thông tin tài khoản vào đây.
SpendingSummary buildSpendingSummary(
  Iterable<Expense> expenses, {
  required double budget,
  DateTime? now,
  int maxLargest = 5,
}) {
  final reference = now ?? DateTime.now();
  final list = expenses.toList();

  if (list.isEmpty) {
    return const SpendingSummary(text: '', hasData: false);
  }

  final stats = computeDashboardStats(list, budget: budget, now: reference);
  final report = computeMonthlyReport(
    list,
    month: reference,
    now: reference,
  );

  final buffer = StringBuffer()
    ..writeln('Thời điểm phân tích: ${_isoDate(reference)}')
    ..writeln(
      'Tháng hiện tại: ${reference.month}/${reference.year} '
      '(đã qua ${reference.day} ngày)',
    )
    ..writeln('Ngân sách tháng: ${_vnd(budget)}')
    ..writeln(
      'Tổng chi tháng này: ${_vnd(stats.monthTotal)} '
      '(${stats.monthCount} giao dịch)',
    );

  if (stats.remaining >= 0) {
    buffer.writeln('Còn lại so với ngân sách: ${_vnd(stats.remaining)}');
  } else {
    buffer.writeln('Đã vượt ngân sách: ${_vnd(-stats.remaining)}');
  }

  buffer
    ..writeln('Tổng chi tháng trước: ${_vnd(report.previousTotal)}')
    ..writeln(
      'Chi 7 ngày gần nhất: ${_vnd(stats.weekTotal)}; '
      '7 ngày trước đó: ${_vnd(stats.previousWeekTotal)}',
    )
    ..writeln('Chi theo danh mục trong tháng này:');

  if (stats.categoryTotals.isEmpty) {
    buffer.writeln('- (chưa có chi tiêu trong tháng này)');
  }

  for (final item in stats.categoryTotals) {
    buffer.writeln(
      '- ${item.category}: ${_vnd(item.amount)} '
      '(${(item.share * 100).round()}%)',
    );
  }

  buffer.writeln('Chi theo ngày trong 7 ngày gần nhất:');

  for (final day in stats.last7Days) {
    buffer.writeln('- ${_isoDate(day.date)}: ${_vnd(day.amount)}');
  }

  final monthExpenses = list
      .where(
        (e) => e.date.year == reference.year && e.date.month == reference.month,
      )
      .toList()
    ..sort((a, b) {
      final byAmount = b.amount.compareTo(a.amount);

      return byAmount != 0 ? byAmount : b.date.compareTo(a.date);
    });

  if (monthExpenses.isNotEmpty) {
    buffer.writeln('Các khoản chi lớn nhất tháng này (không kèm tên):');

    for (final e in monthExpenses.take(maxLargest)) {
      buffer.writeln('- ${_isoDate(e.date)}; ${e.category}; ${_vnd(e.amount)}');
    }
  }

  return SpendingSummary(text: buffer.toString().trimRight(), hasData: true);
}