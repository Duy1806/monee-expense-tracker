class ExpenseDraft {
  const ExpenseDraft({
    required this.title,
    this.amount,
    required this.category,
    required this.date,
    this.receiptSourcePath,
    this.rawText,
  });

  final String title;

  /// null nghĩa là chưa tự nhận diện được số tiền.
  final double? amount;
  final String category;
  final DateTime date;

  /// Ảnh vừa chọn (chưa được lưu vào thư mục bền vững).
  final String? receiptSourcePath;

  /// Văn bản OCR gốc để người dùng đối chiếu.
  final String? rawText;
}