import 'dart:async';

import 'package:expense_tracker/data/models/expense.dart';
import 'package:expense_tracker/features/ai/providers/ai_controller.dart';
import 'package:expense_tracker/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeAnalyzer implements SpendingAnalyzer {
  FakeAnalyzer({this.configured = true});

  bool configured;
  int calls = 0;
  String? lastData;
  Completer<String>? gate;
  Object? error;
  String response = 'Kết quả AI';

  @override
  bool get isConfigured => configured;

  @override
  Future<String> analyzeSpending({
    required String expenseData,
    required double monthlyBudget,
  }) async {
    calls++;
    lastData = expenseData;

    if (gate != null) return gate!.future;

    final failure = error;

    if (failure != null) throw failure;

    return response;
  }
}

Expense sample({String title = 'Bí mật cá nhân'}) {
  return Expense(
    userId: 1,
    title: title,
    category: 'Ăn uống',
    amount: 50000,
    date: DateTime(2026, 10, 18),
  );
}

void main() {
  final fixedNow = DateTime(2026, 10, 18, 9);

  late FakeAnalyzer analyzer;
  late AiController controller;

  Future<void> bind(int? userId) async {
    controller.bindUser(userId);
    await pumpEventQueue();
  }

  setUp(() {
    analyzer = FakeAnalyzer();
    controller = AiController(analyzer, clock: () => fixedNow);
  });

  tearDown(() => controller.dispose());

  test('chưa cấu hình: báo lỗi và không gọi AI', () async {
    analyzer.configured = false;
    await bind(1);

    await controller.analyze(expenses: [sample()], budget: 1000000);

    expect(controller.status, AiStatus.error);
    expect(controller.errorMessage, contains('chưa được cấu hình'));
    expect(analyzer.calls, 0);
  });

  test('chưa có giao dịch: báo lỗi và không gọi AI', () async {
    await bind(1);

    await controller.analyze(expenses: const [], budget: 1000000);

    expect(controller.status, AiStatus.error);
    expect(controller.errorMessage, contains('thêm giao dịch'));
    expect(analyzer.calls, 0);
  });

  test('chưa đăng nhập: không làm gì', () async {
    await controller.analyze(expenses: [sample()], budget: 1000000);

    expect(controller.status, AiStatus.idle);
    expect(analyzer.calls, 0);
  });

  test('thành công: lưu kết quả và chỉ gửi dữ liệu tổng hợp', () async {
    await bind(1);

    await controller.analyze(
      expenses: [sample(title: 'Bí mật cá nhân')],
      budget: 1000000,
    );

    expect(controller.status, AiStatus.success);
    expect(controller.result, 'Kết quả AI');
    expect(controller.analyzedAt, fixedNow);
    expect(analyzer.calls, 1);
    expect(analyzer.lastData, contains('Tổng chi tháng này: 50000 VND'));
    expect(analyzer.lastData, isNot(contains('Bí mật cá nhân')));
  });

  test('lỗi Gemini: hiện thông báo của lỗi đó, không có kết quả', () async {
    await bind(1);
    analyzer.error = const GeminiException(
      GeminiFailure.network,
      'Không kết nối được Gemini.',
    );

    await controller.analyze(expenses: [sample()], budget: 1000000);

    expect(controller.status, AiStatus.error);
    expect(controller.errorMessage, 'Không kết nối được Gemini.');
    expect(controller.result, isNull);
  });

  test('lỗi bất ngờ: thông báo chung, không lộ chi tiết', () async {
    await bind(1);
    analyzer.error = StateError('chi tiết nội bộ');

    await controller.analyze(expenses: [sample()], budget: 1000000);

    expect(controller.status, AiStatus.error);
    expect(controller.errorMessage, isNot(contains('nội bộ')));
  });

  test('đang chạy thì bỏ qua lệnh phân tích thứ hai', () async {
    await bind(1);
    analyzer.gate = Completer<String>();

    final first = controller.analyze(expenses: [sample()], budget: 1000000);
    await pumpEventQueue();

    expect(controller.isLoading, isTrue);

    await controller.analyze(expenses: [sample()], budget: 1000000);

    expect(analyzer.calls, 1);

    analyzer.gate!.complete('Xong');
    await first;

    expect(controller.status, AiStatus.success);
  });

  test('đổi tài khoản: xóa kết quả cũ', () async {
    await bind(1);
    await controller.analyze(expenses: [sample()], budget: 1000000);

    expect(controller.result, isNotNull);

    await bind(2);

    expect(controller.status, AiStatus.idle);
    expect(controller.result, isNull);
    expect(controller.analyzedAt, isNull);
  });

  test('đổi tài khoản khi đang chờ: bỏ kết quả của tài khoản cũ', () async {
    await bind(1);
    analyzer.gate = Completer<String>();

    final pending = controller.analyze(expenses: [sample()], budget: 1000000);
    await pumpEventQueue();

    await bind(2);

    analyzer.gate!.complete('Kết quả của tài khoản 1');
    await pending;

    expect(controller.result, isNull);
    expect(controller.status, AiStatus.idle);
  });
}