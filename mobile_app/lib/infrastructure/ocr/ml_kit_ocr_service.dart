import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../../domain/services/ocr_service.dart';

/// On-device OCR implementation using Google ML Kit text recognition.
///
/// All processing is local — no image data is transmitted to any external
/// server or API. The recogniser is initialised lazily on first use.
class MlKitOcrService implements OcrService {
  TextRecognizer? _recognizer;

  TextRecognizer get _activeRecognizer {
    return _recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
  }

  @override
  Future<String> recogniseText(String imagePath) async {
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _activeRecognizer.processImage(inputImage);

      final buffer = StringBuffer();
      for (final block in recognizedText.blocks) {
        for (final line in block.lines) {
          buffer.writeln(line.text);
        }
      }
      return buffer.toString().trim();
    } catch (e) {
      throw OcrException('Text recognition failed: $e');
    }
  }

  @override
  Future<void> dispose() async {
    await _recognizer?.close();
    _recognizer = null;
  }
}
