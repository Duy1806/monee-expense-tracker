import 'dart:io';

import 'package:expense_tracker/data/database/prefs_data_store.dart';
import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/data/repositories/budget_repository.dart';
import 'package:expense_tracker/data/repositories/expense_repository.dart';
import 'package:expense_tracker/data/repositories/settings_repository.dart';
import 'package:expense_tracker/features/ai/providers/ai_controller.dart';
import 'package:expense_tracker/features/ai/screens/ai_analysis_screen.dart';
import 'package:expense_tracker/features/ai/widgets/ai_analysis_content.dart';
import 'package:expense_tracker/features/budget/providers/budget_controller.dart';
import 'package:expense_tracker/features/expenses/providers/expense_controller.dart';
import 'package:expense_tracker/services/gemini_service.dart';
import 'package:expense_tracker/services/receipt_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Analyzer implements SpendingAnalyzer {
  _Analyzer({this.configured = true});

  final bool configured;
  Object? error;
  int calls = 0;

  @override
  bool get isConfigured => configured;

  @override
  Future<String> analyzeSpending({
    required String expenseData,
    required double monthlyBudget,
  }) async {
    calls++;

    final failure = error;

    if (failure != null) throw failure;

    return '1. **TỔNG QUAN CHI TIÊU**\n- Bạn đã chi 50.000 đ.\nKết luận.';
  }
}

void main() {
  late Directory baseDir;
  late Directory tempDir;
  late ExpenseRepository repository;
  late ExpenseController expenses;
  late BudgetController budget;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    baseDir = Directory.systemTemp.createTempSync('monee_ai_base_');
    tempDir = Directory.systemTemp.createTempSync('monee_ai_tmp_');

    final store = PrefsDataStore();
    repository = ExpenseRepository(store, SettingsRepository(store));
    expenses = ExpenseController(
      repository,
      ReceiptStorageService(
        baseDirectoryProvider: () async => baseDir,
        temporaryDirectoryProvider: () async => tempDir,
      ),
    );
    budget = BudgetController(BudgetRepository(store));
  });

  tearDown(() {
    expenses.dispose();
    budget.dispose();

    for (final dir in [baseDir, tempDir]) {
      try {
        dir.deleteSync(recursive: true);
      } catch (_) {
        // Bỏ qua.
      }
    }
  });

  Future<AiController> pump(
    WidgetTester tester,
    _Analyzer analyzer,
  ) async {
    final ai = AiController(analyzer);
    addTearDown(ai.dispose);

    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final now = DateTime.now();

    await tester.runAsync(() async {
      await repository.add(
        Expense(
          userId: 1,
          title: 'Ăn trưa',
          category: 'Ăn uống',
          amount: 50000,
          date: DateTime(now.year, now.month, now.day),
        ),
      );
      expenses.bindUser(1);
      budget.bindUser(1);
      ai.bindUser(1);
      await pumpEventQueue();
    });

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ExpenseController>.value(value: expenses),
          ChangeNotifierProvider<BudgetController>.value(value: budget),
          ChangeNotifierProvider<AiController>.value(value: ai),
        ],
        child: const MaterialApp(home: Scaffold(body: AiAnalysisScreen())),
      ),
    );
    await tester.pump();

    return ai;
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(() => pumpEventQueue());
    await tester.pump();
  }

  testWidgets('chưa cấu hình: có thông báo và nút bị khóa', (tester) async {
    final analyzer = _Analyzer(configured: false);

    await pump(tester, analyzer);

    expect(find.byKey(const Key('ai_not_configured')), findsOneWidget);

    final button = tester.widget<FilledButton>(
      find.byKey(const Key('ai_analyze_button')),
    );

    expect(button.onPressed, isNull);
    expect(analyzer.calls, 0);
    // Lời nói rõ dữ liệu nào được gửi đi luôn hiển thị.
    expect(find.textContaining('chỉ gửi số liệu tổng hợp'), findsOneWidget);
  });

  testWidgets('phân tích thành công: hiện kết quả và lời tuyên bố AI',
      (tester) async {
    final analyzer = _Analyzer();

    await pump(tester, analyzer);

    await tester.tap(find.byKey(const Key('ai_analyze_button')));
    await settle(tester);

    expect(analyzer.calls, 1);
    expect(find.byKey(const Key('ai_result')), findsOneWidget);
    expect(find.text('TỔNG QUAN CHI TIÊU'), findsOneWidget);
    expect(find.text('Bạn đã chi 50.000 đ.'), findsOneWidget);
    expect(find.byKey(const Key('ai_disclaimer')), findsOneWidget);
    expect(find.textContaining('không phải tư vấn tài chính'), findsOneWidget);
  });

  testWidgets('lỗi mạng: hiện lỗi, cho thử lại và không mất dữ liệu',
      (tester) async {
    final analyzer = _Analyzer()
      ..error = const GeminiException(
        GeminiFailure.network,
        'Không kết nối được Gemini. Hãy kiểm tra Internet rồi thử lại.',
      );

    await pump(tester, analyzer);

    await tester.tap(find.byKey(const Key('ai_analyze_button')));
    await settle(tester);

    expect(find.byKey(const Key('ai_error')), findsOneWidget);
    expect(find.textContaining('Không kết nối được Gemini'), findsOneWidget);
    expect(find.text('Thử lại'), findsOneWidget);

    // Giao dịch đã lưu vẫn còn nguyên.
    expect(expenses.allExpenses, hasLength(1));
  });

  testWidgets('AiAnalysisContent dựng tiêu đề, gạch đầu dòng và đoạn văn',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AiAnalysisContent(
            text: '1. **PHÂN TÍCH DANH MỤC**\n- Ăn uống chiếm nhiều nhất.\n'
                'Đoạn kết luận.',
          ),
        ),
      ),
    );

    expect(find.text('PHÂN TÍCH DANH MỤC'), findsOneWidget);
    expect(find.text('Ăn uống chiếm nhiều nhất.'), findsOneWidget);
    expect(find.text('Đoạn kết luận.'), findsOneWidget);
  });
}