/// Raw output from a single inference run before post-processing.
class RawInferenceOutput {
  const RawInferenceOutput({
    required this.data,
    required this.outputShape,
    required this.inferenceTimeMs,
    required this.timestamp,
    required this.inputWidth,
    required this.inputHeight,
    this.previewWidth,
    this.previewHeight,
    this.letterboxScale = 1,
    this.letterboxPaddingX = 0,
    this.letterboxPaddingY = 0,
    this.boxCoordinatesNormalized = false,
  });

  /// Flat float32 output values from the model.
  final List<double> data;

  /// Shape of the output tensor, e.g. [1, 84, 2100].
  final List<int> outputShape;

  /// How long inference took in milliseconds.
  final int inferenceTimeMs;

  /// When this inference was initiated.
  final DateTime timestamp;

  /// Input dimensions used for coordinate scaling.
  final int inputWidth;
  final int inputHeight;

  /// Upright camera-preview dimensions before letterboxing.
  final int? previewWidth;
  final int? previewHeight;

  /// Transform used to place the upright preview inside the model input.
  final double letterboxScale;
  final double letterboxPaddingX;
  final double letterboxPaddingY;

  /// Current Ultralytics LiteRT exports produce normalized xywh box values.
  /// Legacy exports may use model-input pixels, so this is explicit metadata.
  final bool boxCoordinatesNormalized;

  int get effectivePreviewWidth => previewWidth ?? inputWidth;
  int get effectivePreviewHeight => previewHeight ?? inputHeight;
}
