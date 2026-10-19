import 'package:flutter/foundation.dart';

import '../../../core/constants/expense_categories.dart';
import '../../../services/receipt_parser.dart';
import '../expense_draft.dart';

enum ReceiptImageSource { camera, gallery }

enum ReceiptScanStatus { idle, recognizing, failed }

typedef ReceiptImagePicker = Future<String?> Function(
  ReceiptImageSource source,
);

typedef ReceiptTextRecognizer = Future<String> Function(String imagePath);

class ReceiptScanController extends ChangeNotifier {
  ReceiptScanController({
    required this.pickImage,
    required this.recognizeText,
    this.parser = const ReceiptParser(),
  });

  final ReceiptImagePicker pickImage;
  final ReceiptTextRecognizer recognizeText;
  final ReceiptParser parser;

  ReceiptScanStatus _status = ReceiptScanStatus.idle;
  String? _errorMessage;
  String? _pickedImagePath;
  bool _disposed = false;

  ReceiptScanStatus get status => _status;
  String? get errorMessage => _errorMessage;
  String? get pickedImagePath => _pickedImagePath;
  bool get recognizing => _status == ReceiptScanStatus.recognizing;

  /// Chọn ảnh rồi nhận dạng. Trả về null nếu người dùng hủy hoặc thất bại
  /// (khi thất bại, [errorMessage] có nội dung và ảnh vẫn được giữ lại).
  Future<ExpenseDraft?> scan(ReceiptImageSource source) async {
    if (recognizing) return null;

    final String? path;

    try {
      path = await pickImage(source);
    } catch (_) {
      _fail(
        'Không thể mở camera hoặc thư viện ảnh. '
        'Hãy kiểm tra quyền truy cập.',
      );
      return null;
    }

    if (path == null) return null; // Người dùng hủy chọn ảnh.

    _pickedImagePath = path;

    return _recognize(path);
  }

  /// Thử nhận dạng lại trên ảnh đã chọn.
  Future<ExpenseDraft?> retryRecognition() async {
    final path = _pickedImagePath;

    if (path == null || recognizing) return null;

    return _recognize(path);
  }

  /// Form trống kèm ảnh đã chọn, dùng khi OCR thất bại và người dùng
  /// chọn nhập thủ công.
  ExpenseDraft manualDraft() {
    return ExpenseDraft(
      title: '',
      category: defaultExpenseCategory,
      date: DateTime.now(),
      receiptSourcePath: _pickedImagePath,
    );
  }

  void reset() {
    _status = ReceiptScanStatus.idle;
    _errorMessage = null;
    _pickedImagePath = null;
    _notify();
  }

  Future<ExpenseDraft?> _recognize(String path) async {
    _status = ReceiptScanStatus.recognizing;
    _errorMessage = null;
    _notify();

    try {
      final text = await recognizeText(path);

      if (text.trim().isEmpty) {
        _fail(
          'Không đọc được chữ trên ảnh. Hãy chụp rõ, đủ sáng hơn, '
          'hoặc nhập thủ công.',
        );
        return null;
      }

      final data = parser.parse(text);

      _status = ReceiptScanStatus.idle;
      _notify();

      return ExpenseDraft(
        title: data.title,
        amount: data.amount,
        category: guessCategory(data.title),
        date: data.date,
        receiptSourcePath: path,
        rawText: text,
      );
    } catch (_) {
      _fail('Không thể nhận dạng hóa đơn. Bạn có thể nhập thủ công.');
      return null;
    }
  }

  void _fail(String message) {
    _status = ReceiptScanStatus.failed;
    _errorMessage = message;
    _notify();
  }

  void _notify() {
    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}