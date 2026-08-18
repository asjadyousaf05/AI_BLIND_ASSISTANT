import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/enums/inference_state.dart';
import '../domain/services/camera_service.dart';
import '../domain/services/inference_service.dart';
import '../infrastructure/inference/tflite_inference_service.dart';
import 'camera_providers.dart';
import 'detection_providers.dart';

final inferenceServiceProvider = Provider<InferenceService>((ref) {
  final service = TfliteInferenceService();
  ref.onDispose(() => service.dispose());
  return service;
});

final inferenceControllerProvider =
    NotifierProvider<InferenceController, InferenceState>(
      InferenceController.new,
    );

class InferenceController extends Notifier<InferenceState> {
  StreamSubscription<InferenceState>? _stateSub;
  bool _running = false;
  bool _inferenceInProgress = false;

  int processedFrames = 0;
  int droppedFrames = 0;
  int totalInferenceMs = 0;

  @override
  InferenceState build() {
    ref.onDispose(_cleanup);
    _listenToService();
    return InferenceState.unloaded;
  }

  InferenceService get _service => ref.read(inferenceServiceProvider);

  Future<void> loadModel() async {
    await _service.loadModel();
  }

  void startProcessingFrames() {
    if (_running) return;
    _running = true;
    _inferenceInProgress = false;
    processedFrames = 0;
    droppedFrames = 0;
    totalInferenceMs = 0;
    final cameraController = ref.read(cameraControllerProvider.notifier);
    cameraController.setFrameCallback(_onFrame);
  }

  void stopProcessingFrames() {
    _running = false;
    _inferenceInProgress = false;
    final cameraController = ref.read(cameraControllerProvider.notifier);
    cameraController.setFrameCallback(null);
    ref.read(detectionResultsProvider.notifier).clear();
  }

  Future<void> unloadModel() async {
    stopProcessingFrames();
    await _service.unloadModel();
  }

  int get lastInferenceTimeMs => _service.lastInferenceTimeMs;

  String? get lastError => _service.lastError;

  int get averageInferenceMs =>
      processedFrames > 0 ? totalInferenceMs ~/ processedFrames : 0;

  void _onFrame(CameraFrame frame) async {
    if (!_running) return;

    if (_inferenceInProgress) {
      droppedFrames++;
      return;
    }

    _inferenceInProgress = true;
    try {
      final sw = Stopwatch()..start();
      final rawOutput = await _service.runInference(frame);
      sw.stop();
      if (rawOutput != null && _running) {
        totalInferenceMs += rawOutput.inferenceTimeMs;
        processedFrames++;
        ref
            .read(detectionResultsProvider.notifier)
            .updateFromRawOutput(rawOutput);
      }
    } finally {
      _inferenceInProgress = false;
    }
  }

  void _listenToService() {
    _stateSub = _service.stateStream.listen((s) {
      state = s;
    });
  }

  void _cleanup() {
    _running = false;
    _stateSub?.cancel();
  }
}
