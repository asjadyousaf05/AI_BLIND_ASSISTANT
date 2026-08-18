import '../entities/raw_inference_output.dart';
import '../enums/inference_state.dart';
import 'camera_service.dart';

abstract interface class InferenceService {
  InferenceState get currentState;

  Stream<InferenceState> get stateStream;

  Future<void> loadModel();

  Future<RawInferenceOutput?> runInference(CameraFrame frame);

  /// Releases the interpreter while keeping the service reusable.
  Future<void> unloadModel();

  Future<void> dispose();

  int get lastInferenceTimeMs;

  String? get lastError;
}
