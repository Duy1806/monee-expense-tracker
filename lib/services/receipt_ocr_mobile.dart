
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class ReceiptOcr {
  final TextRecognizer _recognizer = TextRecognizer(
    script: TextRecognitionScript.latin,
  );

  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final recognizedText = await _recognizer.processImage(inputImage);

    return recognizedText.text;
  }

  Future<void> close() async {
    await _recognizer.close();
  }
}
