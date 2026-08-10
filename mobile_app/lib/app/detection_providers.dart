import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/entities/detection_result.dart';
import '../domain/services/detection_post_processor.dart';
import '../infrastructure/detection/yolo_post_processor.dart';
import '../infrastructure/detection/detection_stabilizer.dart';
import '../infrastructure/inference/model_assets.dart';
import 'providers.dart';

final detectionPostProcessorProvider = FutureProvider<DetectionPostProcessor>((
  ref,
) async {
  final labels = await ModelAssets.loadLabels();
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
    state = _stabilizer.update(currentDetections);
  }

  void clear() {
    _stabilizer.reset();
    state = [];
  }
}
