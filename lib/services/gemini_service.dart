import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  // IMPORTANT:
  // 1. Revoke the API key that was pasted into chat.
  // 2. Create a new key and put it here locally.
  // 3. Never commit a real API key to GitHub.
  
  static const String _apiKey = 'YOUR_NEW_GEMINI_API_KEY';

  // Use the model that was previously confirmed to work in this project.
  static const String _model = 'gemini-3.5-flash-lite';

  /// Print long responses in chunks so Android Logcat does not cut them off.
  void _printLongText(String text) {
    const chunkSize = 800;
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      debugPrint(
        'Gemini result [${i ~/ chunkSize + 1}]: ${text.substring(i, end)}',
        wrapWidth: 800,
      );
    }
  }

  /// Send request and retry on HTTP 503 or timeout.
  /// Up to 3 attempts, with exponential backoff.
  Future<http.Response> _postWithRetry({
    required Uri url,
    required Map<String, String> headers,
    required String body,
  }) async {
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final response = await http
            .post(url, headers: headers, body: body)
            .timeout(const Duration(seconds: 30));

        debugPrint('Gemini HTTP status: ${response.statusCode}');

        if (response.statusCode == 503 && attempt < 2) {
          final waitSeconds = 2 * (1 << attempt);
          debugPrint(
            'Gemini đang quá tải. Thử lại lần ${attempt + 2}/3 '
            'sau $waitSeconds giây.',
          );
          await Future.delayed(Duration(seconds: waitSeconds));
          continue;
        }

        return response;
      } on TimeoutException {
        debugPrint('Gemini timeout lần ${attempt + 1}/3.');

        if (attempt == 2) {
          rethrow;
        }

        final waitSeconds = 2 * (1 << attempt);
        debugPrint('Thử lại sau $waitSeconds giây.');
        await Future.delayed(Duration(seconds: waitSeconds));
      }
    }

    throw Exception('Gemini không phản hồi sau nhiều lần thử.');
  }

  Future<String> analyzeSpending({
    required String expenseData,
    required double monthlyBudget,
  }) async {
    if (_apiKey == 'YOUR_NEW_GEMINI_API_KEY' || _apiKey.trim().isEmpty) {
      throw Exception(
        'Bạn chưa cấu hình Gemini API key trong gemini_service.dart.',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/'
      'models/$_model:generateContent',
    );

    final prompt = '''
Bạn là chuyên gia phân tích tài chính cá nhân của ứng dụng Monee.

Hãy phân tích dữ liệu giao dịch thực tế bên dưới. Bắt đầu ngay từ mục 1,
không chào hỏi, không giới thiệu bản thân, không lặp lại toàn bộ dữ liệu đầu vào.

Ngân sách tháng: ${monthlyBudget.toStringAsFixed(0)} VND

DỮ LIỆU GIAO DỊCH:
$expenseData

Trả lời bằng tiếng Việt, ngắn gọn nhưng đầy đủ theo đúng 5 mục sau:

1. **TỔNG QUAN CHI TIÊU**
- Tổng số tiền đã chi.
- Số tiền còn lại và tỷ lệ đã sử dụng ngân sách, nếu tính được.

2. **PHÂN TÍCH DANH MỤC**
- Danh mục chi nhiều nhất.
- Số tiền và tỷ trọng từng danh mục nếu dữ liệu cho phép.

3. **CÁC KHOẢN CHI ĐÁNG CHÚ Ý**
- Nêu giao dịch hoặc xu hướng nổi bật có căn cứ từ dữ liệu.

4. **GỢI Ý TIẾT KIỆM**
- Đưa ra 3 gợi ý thực tế, gắn với dữ liệu chi tiêu.

5. **MỤC TIÊU THÁNG TỚI**
- Đề xuất mục tiêu phù hợp với ngân sách và thói quen chi tiêu.

QUY TẮC:
- Phải hoàn thành cả 5 mục và kết thúc bằng một câu kết luận.
- Không tự bịa số tiền, danh mục hoặc giao dịch.
- Nếu dữ liệu thiếu hoặc rỗng, hãy nêu rõ giới hạn thay vì đoán.
- Không viết quá dài; ưu tiên nhận xét cụ thể, hữu ích.
''';

    try {
      final response = await _postWithRetry(
        url: url,
        headers: {
          'Content-Type': 'application/json',
          'x-goog-api-key': _apiKey,
        },
        body: jsonEncode({
          'contents': [
            {
              'parts': [
                {'text': prompt}
              ]
            }
          ],
          'generationConfig': {
            'temperature': 0.3,
            // Increased from 1000 to reduce the chance of a cut-off response.
            'maxOutputTokens': 1800,
          },
        }),
      );

      if (response.statusCode != 200) {
        // Do not print the API key. The response body contains no request key.
        debugPrint('Gemini error response: ${response.body}');

        switch (response.statusCode) {
          case 400:
            throw Exception('Yêu cầu Gemini không hợp lệ (400).');
          case 401:
          case 403:
            throw Exception(
              'API key không hợp lệ hoặc chưa được cấp quyền '
              '(${response.statusCode}).',
            );
          case 404:
            throw Exception(
              'Không tìm thấy model hoặc endpoint Gemini (404).',
            );
          case 429:
            throw Exception(
              'Gemini đã giới hạn lượt gọi hoặc hết quota (429). '
              'Hãy kiểm tra hạn mức API.',
            );
          case 503:
            throw Exception(
              'Gemini vẫn quá tải sau 3 lần thử. '
              'Vui lòng đợi một lúc rồi thử lại.',
            );
          default:
            throw Exception(
              'Gemini lỗi HTTP ${response.statusCode}. '
              'Xem Terminal để biết chi tiết.',
            );
        }
      }

      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final candidates = data['candidates'] as List?;

      if (candidates == null || candidates.isEmpty) {
        debugPrint('Gemini response had no candidates: ${response.body}');
        throw Exception('Gemini không trả về nội dung.');
      }

      final candidate = candidates.first as Map<String, dynamic>;
      final finishReason = candidate['finishReason'];
      final usageMetadata = data['usageMetadata'];

      debugPrint('Gemini finishReason: $finishReason');
      debugPrint('Gemini usageMetadata: $usageMetadata');

      final content = candidate['content'] as Map<String, dynamic>?;
      final parts = content?['parts'] as List?;

      if (parts == null || parts.isEmpty) {
        debugPrint('Gemini candidate had no text parts: ${candidate.toString()}');
        throw Exception(
          'Gemini không trả về phần văn bản. '
          'Lý do kết thúc: ${finishReason ?? 'không rõ'}.',
        );
      }

      final result = parts
          .whereType<Map<String, dynamic>>()
          .where((part) => part['text'] is String)
          .map((part) => part['text'] as String)
          .join('\n')
          .trim();

      if (result.isEmpty) {
        throw Exception('Gemini trả về nội dung trống.');
      }

      debugPrint('===== GEMINI ANALYSIS RESULT =====');
      _printLongText(result);
      debugPrint('===== END GEMINI RESULT =====');

      if (finishReason == 'MAX_TOKENS') {
        debugPrint(
          'CẢNH BÁO: Gemini dừng vì MAX_TOKENS. '
          'Có thể câu trả lời chưa đầy đủ; hãy tăng maxOutputTokens '
          'hoặc rút gọn prompt.',
        );
      } else if (finishReason != null && finishReason != 'STOP') {
        debugPrint('Gemini kết thúc với lý do: $finishReason');
      }

      return result;
    } on TimeoutException {
      throw Exception(
        'Gemini phản hồi quá chậm sau nhiều lần thử. '
        'Kiểm tra mạng rồi thử lại.',
      );
    } on http.ClientException catch (e) {
      debugPrint('Gemini network error: $e');
      throw Exception(
        'Không kết nối được Gemini. '
        'Hãy kiểm tra Internet trên điện thoại.',
      );
    }
  }
}
