import 'package:expense_tracker/features/dashboard/dashboard_stats.dart';
import 'package:expense_tracker/features/dashboard/widgets/donut_chart.dart';
import 'package:expense_tracker/features/dashboard/widgets/weekly_bar_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget wrap(Widget child, {Brightness brightness = Brightness.light}) {
  return MaterialApp(
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: const Color(0xFF168568),
        brightness: brightness,
      ),
    ),
    home: Scaffold(body: Center(child: child)),
  );
}

List<DailyTotal> sampleDays() {
  return [
    for (var i = 0; i < 7; i++)
      DailyTotal(
        date: DateTime(2026, 10, 12 + i),
        amount: i == 6 ? 50000 : i * 1000.0,
      ),
  ];
}

void main() {
  group('weekdayLabel', () {
    test('nhãn thứ trong tuần', () {
      expect(weekdayLabel(DateTime.monday), 'T2');
      expect(weekdayLabel(DateTime.saturday), 'T7');
      expect(weekdayLabel(DateTime.sunday), 'CN');
    });
  });

  group('DonutChart', () {
    testWidgets('dựng được với dữ liệu', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DonutChart(
            data: [
              CategoryTotal(category: 'Ăn uống', amount: 60000, share: 0.6),
              CategoryTotal(category: 'Di chuyển', amount: 40000, share: 0.4),
            ],
            center: Text('100.000 đ'),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('100.000 đ'), findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp('Ăn uống 60%')),
        findsOneWidget,
      );
    });

    testWidgets('dữ liệu rỗng vẫn vẽ vòng nền', (tester) async {
      await tester.pumpWidget(wrap(const DonutChart(data: [])));

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel('Biểu đồ danh mục: chưa có dữ liệu'),
        findsOneWidget,
      );
    });

    testWidgets('theme tối', (tester) async {
      await tester.pumpWidget(
        wrap(
          const DonutChart(
            data: [
              CategoryTotal(category: 'Khác', amount: 1000, share: 1),
            ],
          ),
          brightness: Brightness.dark,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });

  group('WeeklyBarChart', () {
    testWidgets('dựng được với 7 ngày', (tester) async {
      await tester.pumpWidget(
        wrap(SizedBox(width: 360, child: WeeklyBarChart(days: sampleDays()))),
      );

      expect(tester.takeException(), isNull);
      expect(
        find.bySemanticsLabel(RegExp('Chi tiêu 7 ngày gần nhất')),
        findsOneWidget,
      );
    });

    testWidgets('mọi ngày bằng 0 không lỗi chia cho 0', (tester) async {
      final zero = [
        for (var i = 0; i < 7; i++)
          DailyTotal(date: DateTime(2026, 10, 12 + i), amount: 0),
      ];

      await tester.pumpWidget(
        wrap(
          SizedBox(width: 360, child: WeeklyBarChart(days: zero)),
          brightness: Brightness.dark,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}