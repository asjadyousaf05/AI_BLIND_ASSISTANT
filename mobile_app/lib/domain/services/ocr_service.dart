/// Domain service interface for on-device optical character recognition.
///
/// Implementations must process images locally — no image data is uploaded
/// to any cloud service or remote endpoint.
abstract interface class OcrService {
  /// Recognises text in the image at [imagePath].
  ///
  /// Returns the full recognised text, or an empty string if no text was found.
  /// Throws [OcrException] on unrecoverable recognition failure.
  Future<String> recogniseText(String imagePath);

  /// Releases any resources held by the service.
  Future<void> dispose();
}

/// Thrown when OCR recognition fails unrecoverably.
class OcrException implements Exception {
  const OcrException(this.message);

  final String message;

  @override
  String toString() => 'OcrException: $message';
}
