
class ReceiptOcr {
  Future<String> recognizeText(String imagePath) async {
    throw UnsupportedError(
      'OCR chỉ hỗ trợ Android/iOS, chưa hỗ trợ Chrome.',
    );
  }

  Future<void> close() async {}
}
