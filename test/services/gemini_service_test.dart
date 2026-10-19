import 'dart:async';
import 'dart:convert';

import 'package:expense_tracker/services/gemini_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

const _key = 'TEST-KEY-123456';

http.Response okBody(String text, {String? finishReason}) {
  return http.Response(
    jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': text},
            ],
          },
          'finishReason': ?finishReason,
        },
      ],
    }),
    200,
    headers: {'content-type': 'application/json; charset=utf-8'},
  );
}

GeminiService build(
  MockClient client, {
  String apiKey = _key,
  List<Duration>? delays,
  Duration timeout = const Duration(seconds: 5),
}) {
  return GeminiService(
    apiKey: apiKey,
    client: client,
    timeout: timeout,
    delay: (d) async => delays?.add(d),
  );
}

Future<GeminiException> failureOf(Future<Object?> Function() action) async {
  try {
    await action();
  } on GeminiException catch (e) {
    return e;
  }

  fail('Đáng lẽ phải ném GeminiException');
}

void main() {
  group('cấu hình', () {
    test('chưa có khóa: không gọi mạng và ném notConfigured', () async {
      var calls = 0;
      final service = build(
        MockClient((request) async {
          calls++;
          return okBody('x');
        }),
        apiKey: '   ',
      );

      expect(service.isConfigured, isFalse);

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.notConfigured);
      expect(calls, 0);
    });
  });

  group('gọi thành công', () {
    test('khóa chỉ nằm ở header, không nằm trong URL hay nội dung', () async {
      late http.Request captured;

      final service = build(
        MockClient((request) async {
          captured = request;
          return okBody('Kết quả phân tích');
        }),
      );

      final result = await service.analyzeSpending(
        expenseData: 'DU-LIEU-MAU',
        monthlyBudget: 5000000,
      );

      expect(result, 'Kết quả phân tích');
      expect(captured.headers['x-goog-api-key'], _key);
      expect(captured.url.toString(), contains(GeminiService.model));
      expect(captured.url.toString(), isNot(contains(_key)));
      expect(captured.body, isNot(contains(_key)));
      expect(captured.body, contains('DU-LIEU-MAU'));
      expect(captured.body, contains('5000000'));
    });

    test('ghép nhiều phần văn bản', () async {
      final service = build(
        MockClient((_) async {
          return http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {
                    'parts': [
                      {'text': 'Phần 1'},
                      {'text': 'Phần 2'},
                    ],
                  },
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );

      final result = await service.analyzeSpending(
        expenseData: 'd',
        monthlyBudget: 1,
      );

      expect(result, 'Phần 1\nPhần 2');
    });

    test('dừng vì MAX_TOKENS thì kèm ghi chú bị cắt', () async {
      final service = build(
        MockClient((_) async => okBody('Dở dang', finishReason: 'MAX_TOKENS')),
      );

      final result = await service.analyzeSpending(
        expenseData: 'd',
        monthlyBudget: 1,
      );

      expect(result, startsWith('Dở dang'));
      expect(result, contains('cắt ngắn'));
    });
  });

  group('thử lại và hết thời gian', () {
    test('503 rồi 200: thử lại với thời gian chờ tăng dần', () async {
      var calls = 0;
      final delays = <Duration>[];

      final service = build(
        MockClient((_) async {
          calls++;
          return calls == 1 ? http.Response('busy', 503) : okBody('OK');
        }),
        delays: delays,
      );

      expect(
        await service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
        'OK',
      );
      expect(calls, 2);
      expect(delays, [const Duration(seconds: 2)]);
    });

    test('503 liên tiếp 3 lần: ném overloaded', () async {
      var calls = 0;
      final delays = <Duration>[];

      final service = build(
        MockClient((_) async {
          calls++;
          return http.Response('busy', 503);
        }),
        delays: delays,
      );

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.overloaded);
      expect(calls, 3);
      expect(delays, [const Duration(seconds: 2), const Duration(seconds: 4)]);
    });

    test('không phản hồi: ném timeout sau 3 lần', () async {
      var calls = 0;

      final service = build(
        MockClient((_) {
          calls++;
          return Completer<http.Response>().future;
        }),
        timeout: const Duration(milliseconds: 20),
      );

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.timeout);
      expect(calls, 3);
    });
  });

  group('ánh xạ lỗi', () {
    final cases = <int, GeminiFailure>{
      400: GeminiFailure.badRequest,
      401: GeminiFailure.invalidKey,
      403: GeminiFailure.invalidKey,
      404: GeminiFailure.notFound,
      429: GeminiFailure.quota,
      500: GeminiFailure.server,
    };

    cases.forEach((status, expected) {
      test('HTTP $status → $expected', () async {
        final service = build(
          MockClient((_) async => http.Response('{"error":"x"}', status)),
        );

        final error = await failureOf(
          () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
        );

        expect(error.failure, expected);
      });
    });

    test('thông báo lỗi không chứa khóa API hay thân phản hồi', () async {
      final service = build(
        MockClient(
          (_) async => http.Response('SECRET-BODY $_key', 429),
        ),
      );

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.message, isNot(contains('SECRET-BODY')));
      expect(error.message, isNot(contains(_key)));
      expect(error.toString(), isNot(contains(_key)));
    });
  });

  group('phản hồi bất thường', () {
    test('không có candidates', () async {
      final service = build(
        MockClient((_) async => http.Response('{"candidates":[]}', 200)),
      );

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.emptyResponse);
    });

    test('JSON hỏng', () async {
      final service = build(
        MockClient((_) async => http.Response('<html>', 200)),
      );

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.emptyResponse);
    });

    test('văn bản rỗng', () async {
      final service = build(MockClient((_) async => okBody('   ')));

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.emptyResponse);
    });

    test('mất mạng: ném network', () async {
      final service = build(
        MockClient((_) async => throw http.ClientException('offline')),
      );

      final error = await failureOf(
        () => service.analyzeSpending(expenseData: 'd', monthlyBudget: 1),
      );

      expect(error.failure, GeminiFailure.network);
    });
  });
}