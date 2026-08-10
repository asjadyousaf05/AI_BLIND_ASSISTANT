import '../entities/detection_result.dart';
import '../entities/raw_inference_output.dart';

abstract interface class DetectionPostProcessor {
  List<DetectionResult> process(
    RawInferenceOutput rawOutput, {
    double confidenceThreshold,
    double iouThreshold,
    Set<int>? allowedClassIds,
  });
}
