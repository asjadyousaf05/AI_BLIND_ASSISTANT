import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/detection_result.dart';
import '../domain/entities/raw_inference_output.dart';
import '../domain/services/detection_post_processor.dart';
import '../infrastructure/detection/detection_stabilizer.dart';
import '../infrastructure/detection/yolo_post_processor.dart';
import '../infrastructure/inference/model_assets.dart';
import 'providers.dart';

final detectionPostProcessorProvider = FutureProvider<DetectionPostProcessor>((
  ref,
) async {
  final labels = await ModelAssets.loadLabels();
  return YoloPostProcessor(labels: labels);
});

final householdPostProcessorProvider = FutureProvider<DetectionPostProcessor>((
  ref,
) async {
  final labels = await ModelAssets.loadHouseholdLabels();
  return YoloPostProcessor(labels: labels);
});

final detectionResultsProvider =
    NotifierProvider<DetectionResultsController, List<DetectionResult>>(
      DetectionResultsController.new,
    );

class DetectionResultsController extends Notifier<List<DetectionResult>> {
  static const _defaultIouThreshold = 0.45;
  late final DetectionStabilizer _stabilizer;

  @override
  List<DetectionResult> build() {
    _stabilizer = DetectionStabilizer();
    return [];
  }

  void updateFromRawOutput(dynamic rawOutput) {
    if (rawOutput == null) return;

    final postProcessorAsync = ref.read(detectionPostProcessorProvider);
    final postProcessor = postProcessorAsync.asData?.value;
    if (postProcessor == null) return;

    final settings = ref.read(appSettingsControllerProvider);
    final confidenceThreshold = settings.detectionSettings.confidenceThreshold;

    final currentDetections = postProcessor.process(
      rawOutput,
      confidenceThreshold: confidenceThreshold,
      iouThreshold: _defaultIouThreshold,
    );

    List<DetectionResult> householdDetections = const [];
    if (rawOutput is RawInferenceOutput &&
        rawOutput.householdData != null &&
        rawOutput.householdOutputShape != null) {
      final householdPostProcessor = ref
          .read(householdPostProcessorProvider)
          .asData
          ?.value;
      if (householdPostProcessor != null) {
        final householdRaw = RawInferenceOutput(
          data: rawOutput.householdData!,
          outputShape: rawOutput.householdOutputShape!,
          inferenceTimeMs: rawOutput.inferenceTimeMs,
          timestamp: rawOutput.timestamp,
          inputWidth: rawOutput.inputWidth,
          inputHeight: rawOutput.inputHeight,
          previewWidth: rawOutput.previewWidth,
          previewHeight: rawOutput.previewHeight,
          letterboxScale: rawOutput.letterboxScale,
          letterboxPaddingX: rawOutput.letterboxPaddingX,
          letterboxPaddingY: rawOutput.letterboxPaddingY,
          boxCoordinatesNormalized: rawOutput.boxCoordinatesNormalized,
        );
        householdDetections = householdPostProcessor.process(
          householdRaw,
          confidenceThreshold: confidenceThreshold,
          iouThreshold: _defaultIouThreshold,
        );
      }
    }

    final householdEngine = ref.read(householdDetectionEngineProvider);
    final householdEnhanced = householdEngine.process(
      rawDetections: householdDetections.isNotEmpty
          ? householdDetections
          : currentDetections,
      mode: settings.environmentMode,
    );

    final fusionService = ref.read(multiModelFusionServiceProvider);
    final fused = fusionService.fuse(
      primaryModelDetections: currentDetections,
      householdModelDetections: householdEnhanced,
    );

    state = _stabilizer.update(fused);
  }

  void clear() {
    _stabilizer.reset();
    state = [];
  }
}
