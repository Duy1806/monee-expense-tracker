import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/utils/formatters.dart';
import '../../expenses/category_icons.dart';
import '../dashboard_stats.dart';

class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.data,
    this.size = 168,
    this.center,
  });

  final List<CategoryTotal> data;
  final double size;

  /// Nội dung đặt giữa vòng tròn (ví dụ tổng tiền).
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final label = data.isEmpty
        ? 'Biểu đồ danh mục: chưa có dữ liệu'
        : 'Biểu đồ danh mục: ${data.map(
              (e) => '${e.category} ${(e.share * 100).round()}% '
                  '(${formatVnd(e.amount)})',
            ).join(', ')}';

    return Semantics(
      label: label,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            ExcludeSemantics(
              child: CustomPaint(
                size: Size.square(size),
                painter: DonutPainter(
                  sections: [
                    for (final item in data)
                      DonutSection(
                        value: item.amount,
                        color: colorForCategory(item.category),
                      ),
                  ],
                  trackColor: scheme.surfaceContainerHighest,
                ),
              ),
            ),
            ?center,
          ],
        ),
      ),
    );
  }
}

class DonutSection {
  const DonutSection({required this.value, required this.color});

  final double value;
  final Color color;
}

class DonutPainter extends CustomPainter {
  DonutPainter({required this.sections, required this.trackColor});

  final List<DonutSection> sections;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 7;
    final rect = Rect.fromCircle(center: center, radius: radius);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 22
      ..strokeCap = StrokeCap.round;

    final total = sections.fold<double>(0, (sum, s) => sum + s.value);

    if (total <= 0) {
      paint.color = trackColor;
      canvas.drawArc(rect, 0, math.pi * 2, false, paint);
      return;
    }

    var start = -math.pi / 2;

    for (final section in sections) {
      final sweep = section.value / total * math.pi * 2;

      paint.color = section.color;
      canvas.drawArc(rect, start, math.max(0, sweep - 0.035), false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant DonutPainter oldDelegate) {
    return oldDelegate.trackColor != trackColor ||
        !_sameSections(oldDelegate.sections, sections);
  }
}

bool _sameSections(List<DonutSection> a, List<DonutSection> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;

  for (var i = 0; i < a.length; i++) {
    if (a[i].value != b[i].value || a[i].color != b[i].color) return false;
  }

  return true;
}