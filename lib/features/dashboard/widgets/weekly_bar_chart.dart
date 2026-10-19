import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../dashboard_stats.dart';

const List<String> _weekdayLabels = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

/// [weekday] theo DateTime.weekday (1 = thứ Hai ... 7 = Chủ nhật).
String weekdayLabel(int weekday) => _weekdayLabels[(weekday - 1) % 7];

class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({super.key, required this.days, this.height = 180});

  /// Đủ 7 ngày, cũ nhất trước, cuối cùng là hôm nay.
  final List<DailyTotal> days;
  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    var maxValue = 0.0;

    for (final day in days) {
      maxValue = math.max(maxValue, day.amount);
    }

    final label = 'Chi tiêu 7 ngày gần nhất: ${days.map(
          (d) => '${weekdayLabel(d.date.weekday)} ${formatVnd(d.amount)}',
        ).join(', ')}';

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          height: height,
          width: double.infinity,
          child: CustomPaint(
            painter: WeeklyBarPainter(
              values: [for (final d in days) d.amount],
              labels: [for (final d in days) weekdayLabel(d.date.weekday)],
              maxValue: maxValue,
              todayIndex: days.length - 1,
              activeColor: scheme.primary,
              barColor: scheme.primary.withAlpha(90),
              gridColor: scheme.outlineVariant,
              labelColor: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class WeeklyBarPainter extends CustomPainter {
  WeeklyBarPainter({
    required this.values,
    required this.labels,
    required this.maxValue,
    required this.todayIndex,
    required this.activeColor,
    required this.barColor,
    required this.gridColor,
    required this.labelColor,
  });

  final List<double> values;
  final List<String> labels;
  final double maxValue;
  final int todayIndex;
  final Color activeColor;
  final Color barColor;
  final Color gridColor;
  final Color labelColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    const left = 5.0;
    const bottom = 25.0;
    const top = 8.0;
    const minBar = 3.0;

    final chartHeight = math.max(0.0, size.height - bottom - top);
    final chartWidth = size.width - left * 2;
    final slot = chartWidth / values.length;

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    for (var i = 0; i < 4; i++) {
      final y = top + chartHeight * i / 3;

      canvas.drawLine(Offset(left, y), Offset(size.width - left, y), gridPaint);
    }

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (var i = 0; i < values.length; i++) {
      final isToday = i == todayIndex;
      final barHeight = maxValue <= 0
          ? minBar
          : math.max(minBar, chartHeight * values[i] / maxValue);

      final x = left + i * slot + slot * 0.23;
      final barWidth = slot * 0.54;
      final y = top + chartHeight - barHeight;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, math.min(chartHeight, barHeight)),
        const Radius.circular(5),
      );

      canvas.drawRRect(
        rect,
        Paint()..color = isToday ? activeColor : barColor,
      );

      textPainter.text = TextSpan(
        text: i < labels.length ? labels[i] : '',
        style: TextStyle(
          fontSize: 10,
          color: isToday ? activeColor : labelColor,
          fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
        ),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x + (barWidth - textPainter.width) / 2, size.height - 17),
      );
    }
  }

  @override
  bool shouldRepaint(covariant WeeklyBarPainter oldDelegate) {
    return oldDelegate.maxValue != maxValue ||
        oldDelegate.todayIndex != todayIndex ||
        oldDelegate.activeColor != activeColor ||
        oldDelegate.barColor != barColor ||
        oldDelegate.gridColor != gridColor ||
        oldDelegate.labelColor != labelColor ||
        !_sameDoubles(oldDelegate.values, values) ||
        !_sameStrings(oldDelegate.labels, labels);
  }
}

bool _sameDoubles(List<double> a, List<double> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}

bool _sameStrings(List<String> a, List<String> b) {
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }

  return true;
}