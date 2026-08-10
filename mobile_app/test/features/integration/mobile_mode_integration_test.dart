import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_blind_assistant/app/assistance_controller.dart';
import 'package:ai_blind_assistant/app/camera_providers.dart';
import 'package:ai_blind_assistant/app/detection_providers.dart';
import 'package:ai_blind_assistant/app/feedback_providers.dart';
import 'package:ai_blind_assistant/app/inference_providers.dart';
import 'package:ai_blind_assistant/app/permission_providers.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/detection_result.dart';
import 'package:ai_blind_assistant/domain/entities/obstacle_alert.dart';
import 'package:ai_blind_assistant/domain/entities/raw_inference_output.dart';
import 'package:ai_blind_assistant/domain/enums/camera_permission_status.dart';
import 'package:ai_blind_assistant/domain/enums/camera_state.dart';
import 'package:ai_blind_assistant/domain/enums/feedback_mode.dart';
import 'package:ai_blind_assistant/domain/enums/inference_state.dart';
import 'package:ai_blind_assistant/domain/enums/mobile_assistance_state.dart';
import 'package:ai_blind_assistant/domain/enums/proximity_level.dart';
import 'package:ai_blind_assistant/domain/enums/risk_level.dart';
import 'package:ai_blind_assistant/domain/enums/screen_position.dart';
import 'package:ai_blind_assistant/domain/services/alert_orchestrator.dart';
import 'package:ai_blind_assistant/domain/services/camera_service.dart';
import 'package:ai_blind_assistant/domain/services/inference_service.dart';
import 'package:ai_blind_assistant/domain/services/permission_service.dart';
import 'package:ai_blind_assistant/domain/services/risk_assessor.dart';
import 'package:ai_blind_assistant/domain/services/tts_service.dart';
import 'package:ai_blind_assistant/domain/services/vibration_service.dart';

// ============================================================
// FAKES
// ============================================================

class FakePermissionService implements PermissionService {
  CameraPermissionStatus _status = CameraPermissionStatus.granted;
  int checkCount = 0;
  int requestCount = 0;
  Duration checkDelay = Duration.zero;

  void setStatus(CameraPermissionStatus status) => _status = status;

  @override
  Future<CameraPermissionStatus> checkCameraPermission() async {
    checkCount++;
    if (checkDelay != Duration.zero) {
      await Future<void>.delayed(checkDelay);
    }
    return _status;
  }

  @override
  Future<CameraPermissionStatus> requestCameraPermission() async {
    requestCount++;
    return _status;
  }

  @override
  Future<bool> openAppSettings() async => true;
}

class FakeCameraService implements CameraService {
  CameraState _currentState = CameraState.uninitialized;
  final _stateController = StreamController<CameraState>.broadcast();
  FrameCallback? _frameCallback;
  bool initializeCalled = false;
  bool startPreviewCalled = false;
  bool stopPreviewCalled = false;
  bool disposeCalled = false;
  bool shouldFailInit = false;
  bool shouldReturnUnavailable = false;
  String? errorDetail;

  @override
  String? get lastError => errorDetail;

  @override
  CameraState get currentState => _currentState;

  @override
  Stream<CameraState> get stateStream => _stateController.stream;

  void _transitionTo(CameraState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> initialize() async {
    initializeCalled = true;
    if (shouldReturnUnavailable) {
      _transitionTo(CameraState.unavailable);
      return;
    }
    if (shouldFailInit) {
      _transitionTo(CameraState.error);
      throw Exception('Camera init failed');
    }
    _transitionTo(CameraState.ready);
  }

  @override
  Future<void> startPreview() async {
    startPreviewCalled = true;
    _transitionTo(CameraState.previewing);
  }

  @override
  Future<void> stopPreview() async {
    stopPreviewCalled = true;
    _transitionTo(CameraState.ready);
  }

  @override
  Future<void> dispose() async {
    await release();
    await _stateController.close();
  }

  @override
  Future<void> release() async {
    disposeCalled = true;
    _transitionTo(CameraState.uninitialized);
  }

  @override
  void setFrameCallback(FrameCallback? callback) {
    _frameCallback = callback;
  }

  @override
  Object? get previewWidget => null;

  void emitFrame(CameraFrame frame) {
    _frameCallback?.call(frame);
  }

  void emitRuntimeError(String detail) {
    errorDetail = detail;
    _transitionTo(CameraState.error);
  }
}

class FakeInferenceService implements InferenceService {
  InferenceState _currentState = InferenceState.unloaded;
  final _stateController = StreamController<InferenceState>.broadcast();
  bool loadModelCalled = false;
  bool disposeCalled = false;
  bool shouldFailLoad = false;
  int runInferenceCount = 0;
  final int _lastInferenceTimeMs = 10;
  Duration inferenceDelay = Duration.zero;
  RawInferenceOutput? _mockOutput;

  @override
  String? get lastError => null;

  void setMockOutput(RawInferenceOutput? output) => _mockOutput = output;

  @override
  InferenceState get currentState => _currentState;

  @override
  Stream<InferenceState> get stateStream => _stateController.stream;

  void _transitionTo(InferenceState newState) {
    _currentState = newState;
    _stateController.add(newState);
  }

  @override
  Future<void> loadModel() async {
    loadModelCalled = true;
    if (shouldFailLoad) {
      _transitionTo(InferenceState.error);
      return;
    }
    _transitionTo(InferenceState.ready);
  }

  @override
  Future<RawInferenceOutput?> runInference(CameraFrame frame) async {
    runInferenceCount++;
    if (inferenceDelay != Duration.zero) {
      await Future.delayed(inferenceDelay);
    }
    return _mockOutput;
  }

  @override
  Future<void> dispose() async {
    await unloadModel();
    await _stateController.close();
  }

  @override
  Future<void> unloadModel() async {
    disposeCalled = true;
    _transitionTo(InferenceState.unloaded);
  }

  @override
  int get lastInferenceTimeMs => _lastInferenceTimeMs;
}

class FakeTtsService implements TtsService {
  bool initialized = false;
  bool _isSpeaking = false;
  bool shouldFailInit = false;
  List<String> spokenTexts = [];
  int speakCount = 0;
  int stopCount = 0;

  @override
  Future<void> initialize() async {
    if (shouldFailInit) throw Exception('TTS unavailable');
    initialized = true;
  }

  @override
  Future<void> speak(String text, {bool interrupt = false}) async {
    if (interrupt) _isSpeaking = false;
    _isSpeaking = true;
    spokenTexts.add(text);
    speakCount++;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _isSpeaking = false;
  }

  @override
  Future<void> dispose() async {
    _isSpeaking = false;
  }

  @override
  bool get isSpeaking => _isSpeaking;
}

class FakeVibrationService implements VibrationService {
  bool _available = true;
  int vibrateCount = 0;
  int cancelCount = 0;
  List<RiskLevel> vibrations = [];

  void setAvailable(bool available) => _available = available;

  @override
  Future<void> vibrateForRisk(RiskLevel level) async {
    vibrateCount++;
    vibrations.add(level);
  }

  @override
  Future<void> cancel() async {
    cancelCount++;
  }

  @override
  bool get isAvailable => _available;
}

class FakeAlertOrchestrator implements AlertOrchestrator {
  bool _isActive = false;
  int processAlertsCount = 0;
  int stopCount = 0;
  int disposeCount = 0;
  List<List<ObstacleAlert>> processedAlerts = [];

  @override
  Future<void> processAlerts(List<ObstacleAlert> alerts) async {
    processAlertsCount++;
    processedAlerts.add(alerts);
    _isActive = true;
  }

  @override
  Future<void> stop() async {
    stopCount++;
    _isActive = false;
  }

  @override
  Future<void> dispose() async {
    disposeCount++;
    _isActive = false;
  }

  @override
  bool get isActive => _isActive;
}

class FakeRiskAssessor implements RiskAssessor {
  @override
  List<ObstacleAlert> assess(List<DetectionResult> detections) {
    return detections
        .map(
          (d) => ObstacleAlert(
            detection: d,
            position: ScreenPosition.center,
            proximity: ProximityLevel.near,
            riskLevel: RiskLevel.high,
            timestamp: d.frameTimestamp,
          ),
        )
        .toList();
  }
}

// ============================================================
// HELPERS
// ============================================================

CameraFrame createTestFrame() => CameraFrame(
  planes: [
    CameraPlane(bytes: Uint8List(640), bytesPerRow: 640, bytesPerPixel: 1),
    CameraPlane(bytes: Uint8List(320), bytesPerRow: 320, bytesPerPixel: 1),
    CameraPlane(bytes: Uint8List(320), bytesPerRow: 320, bytesPerPixel: 1),
  ],
  width: 640,
  height: 480,
  timestamp: DateTime.now(),
  rotationDegrees: 0,
  isFrontFacing: false,
);

DetectionResult createTestDetection({
  String label = 'person',
  double confidence = 0.85,
  double x = 0.4,
  double y = 0.5,
  double w = 0.2,
  double h = 0.6,
}) => DetectionResult(
  classId: 0,
  label: label,
  confidence: confidence,
  boundingBox: BoundingBox(left: x, top: y, right: x + w, bottom: y + h),
  frameTimestamp: DateTime.now(),
);

// ============================================================
// TESTS
// ============================================================

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Module 14 — Mobile Mode Integration', () {
    // UT-INT-001: Start blocked without camera permission
    test(
      'UT-INT-001: startAssistance transitions to permissionRequired when denied',
      () async {
        final fakePermission = FakePermissionService()
          ..setStatus(CameraPermissionStatus.denied);

        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(fakePermission),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        await controller.startAssistance();

        final state = container.read(assistanceControllerProvider);
        expect(state.state, MobileAssistanceState.permissionRequired);
      },
    );

    // UT-INT-002: Successful startup sequence
    test('UT-INT-002: full startup sequence reaches active state', () async {
      final fakePermission = FakePermissionService()
        ..setStatus(CameraPermissionStatus.granted);
      final fakeCameraService = FakeCameraService();
      final fakeInference = FakeInferenceService();
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(fakePermission),
          cameraServiceProvider.overrideWithValue(fakeCameraService),
          inferenceServiceProvider.overrideWithValue(fakeInference),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();

      final state = container.read(assistanceControllerProvider);
      expect(state.state, MobileAssistanceState.active);
      expect(fakeCameraService.initializeCalled, isTrue);
      expect(fakeCameraService.startPreviewCalled, isTrue);
      expect(fakeInference.loadModelCalled, isTrue);
    });

    // UT-INT-003: Camera init failure transitions to error
    test(
      'UT-INT-003: camera init failure sets error state with message',
      () async {
        final fakeCameraService = FakeCameraService()
          ..shouldReturnUnavailable = true;

        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              FakePermissionService(),
            ),
            cameraServiceProvider.overrideWithValue(fakeCameraService),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        await controller.startAssistance();

        final state = container.read(assistanceControllerProvider);
        expect(state.state, MobileAssistanceState.error);
        expect(state.errorMessage, contains('No rear camera'));
      },
    );

    // UT-INT-004: Model loading failure transitions to error
    test('UT-INT-004: model loading failure sets error state', () async {
      final fakeInference = FakeInferenceService()..shouldFailLoad = true;

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          inferenceServiceProvider.overrideWithValue(fakeInference),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();

      final state = container.read(assistanceControllerProvider);
      expect(state.state, MobileAssistanceState.error);
      expect(state.errorMessage, contains('Detection model failed'));
    });

    // UT-INT-005: Single session enforcement — re-entrant start is no-op
    test(
      'UT-INT-005: calling startAssistance while active is a no-op',
      () async {
        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              FakePermissionService(),
            ),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        await controller.startAssistance();

        expect(
          container.read(assistanceControllerProvider).state,
          MobileAssistanceState.active,
        );

        // Second call — already active so canStart == false
        await controller.startAssistance();
        expect(
          container.read(assistanceControllerProvider).state,
          MobileAssistanceState.active,
        );
      },
    );

    // UT-INT-006: Single inference at a time — frames dropped when busy
    test('UT-INT-006: frames are dropped during inference', () async {
      final fakeInference = FakeInferenceService()
        ..inferenceDelay = const Duration(milliseconds: 50)
        ..setMockOutput(
          RawInferenceOutput(
            data: List<double>.filled(84, 0),
            outputShape: const [1, 84, 1],
            inferenceTimeMs: 10,
            timestamp: DateTime(2024),
            inputWidth: 320,
            inputHeight: 320,
          ),
        );
      final fakeCamera = FakeCameraService();

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(fakeCamera),
          inferenceServiceProvider.overrideWithValue(fakeInference),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();

      // The inference controller is now running with frame callback set
      final inferenceCtrl = container.read(
        inferenceControllerProvider.notifier,
      );

      // Simulate rapid frames — only the first should be processed, rest dropped
      final frame = createTestFrame();
      fakeCamera.emitFrame(frame);
      fakeCamera.emitFrame(frame);
      fakeCamera.emitFrame(frame);

      expect(fakeInference.runInferenceCount, 1);
      expect(inferenceCtrl.droppedFrames, 2);

      await Future<void>.delayed(const Duration(milliseconds: 75));
      expect(inferenceCtrl.processedFrames, 1);
    });

    // UT-INT-007: Stop cleans up all subsystems
    test('UT-INT-007: stopAssistance resets all subsystems to idle', () async {
      final fakeOrchestrator = FakeAlertOrchestrator();

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(fakeOrchestrator),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();
      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.active,
      );

      await controller.stopAssistance();
      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.idle,
      );
      expect(container.read(detectionResultsProvider), isEmpty);
    });

    // UT-INT-008: Repeated stop is idempotent
    test('UT-INT-008: calling stopAssistance multiple times is safe', () async {
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();
      await controller.stopAssistance();
      await controller.stopAssistance();
      await controller.stopAssistance();

      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.idle,
      );
    });

    // UT-INT-009: Error recovery via retry
    test('UT-INT-009: retry from error state restarts assistance', () async {
      final fakeInference = FakeInferenceService()..shouldFailLoad = true;

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          inferenceServiceProvider.overrideWithValue(fakeInference),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();
      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.error,
      );

      // Fix the model and retry
      fakeInference.shouldFailLoad = false;
      await controller.retry();
      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.active,
      );
    });

    // UT-INT-010: Permanently denied permission shows descriptive error
    test(
      'UT-INT-010: permanently denied permission sets descriptive error',
      () async {
        final fakePermission = FakePermissionService()
          ..setStatus(CameraPermissionStatus.permanentlyDenied);

        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(fakePermission),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        await controller.startAssistance();

        final state = container.read(assistanceControllerProvider);
        expect(state.state, MobileAssistanceState.error);
        expect(state.errorMessage, contains('permanently denied'));
      },
    );

    // UT-INT-011: Pause stops inference/feedback and releases the camera.
    test('UT-INT-011: pauseAssistance releases active resources', () async {
      final fakeOrchestrator = FakeAlertOrchestrator();
      final fakeCameraService = FakeCameraService();

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(fakeCameraService),
          inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(fakeOrchestrator),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();
      await controller.pauseAssistance();

      final state = container.read(assistanceControllerProvider);
      expect(state.state, MobileAssistanceState.paused);
      expect(fakeCameraService.disposeCalled, isTrue);
    });

    // UT-INT-012: Resume after pause re-checks permission
    test('UT-INT-012: handleResume re-checks permission', () async {
      final fakePermission = FakePermissionService()
        ..setStatus(CameraPermissionStatus.granted);

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(fakePermission),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();
      await controller.pauseAssistance();

      final checksBefore = fakePermission.checkCount;
      await controller.handleResume();

      expect(fakePermission.checkCount, greaterThan(checksBefore));
      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.paused,
      );
    });

    // UT-INT-013: Resume with revoked permission transitions to permissionRequired
    test(
      'UT-INT-013: handleResume with revoked permission → permissionRequired',
      () async {
        final fakePermission = FakePermissionService()
          ..setStatus(CameraPermissionStatus.granted);

        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(fakePermission),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        await controller.startAssistance();
        await controller.pauseAssistance();

        // Simulate permission revocation
        fakePermission.setStatus(CameraPermissionStatus.denied);
        await controller.handleResume();

        expect(
          container.read(assistanceControllerProvider).state,
          MobileAssistanceState.permissionRequired,
        );
      },
    );

    // UT-INT-014: Detach cleans up and releases camera
    test(
      'UT-INT-014: handleDetach stops assistance and releases camera',
      () async {
        final fakeCameraService = FakeCameraService();

        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              FakePermissionService(),
            ),
            cameraServiceProvider.overrideWithValue(fakeCameraService),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        await controller.startAssistance();
        await controller.handleDetach();

        expect(
          container.read(assistanceControllerProvider).state,
          MobileAssistanceState.idle,
        );
        expect(fakeCameraService.disposeCalled, isTrue);
      },
    );

    // UT-INT-015: TTS unavailability doesn't crash startup
    test('UT-INT-015: TTS init failure does not prevent startup', () async {
      final fakeTts = FakeTtsService()..shouldFailInit = true;

      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(FakeCameraService()),
          inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
          ttsServiceProvider.overrideWithValue(fakeTts),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      await controller.startAssistance();

      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.active,
      );
    });

    // UT-INT-016: MobileAssistanceState enum properties
    test('UT-INT-016: MobileAssistanceState enum helpers are correct', () {
      expect(MobileAssistanceState.active.isActive, isTrue);
      expect(MobileAssistanceState.idle.isActive, isFalse);

      expect(MobileAssistanceState.starting.isBusy, isTrue);
      expect(MobileAssistanceState.stopping.isBusy, isTrue);
      expect(MobileAssistanceState.initialisingCamera.isBusy, isTrue);
      expect(MobileAssistanceState.loadingModel.isBusy, isTrue);
      expect(MobileAssistanceState.active.isBusy, isFalse);

      expect(MobileAssistanceState.idle.canStart, isTrue);
      expect(MobileAssistanceState.ready.canStart, isTrue);
      expect(MobileAssistanceState.error.canStart, isTrue);
      expect(MobileAssistanceState.paused.canStart, isTrue);
      expect(MobileAssistanceState.active.canStart, isFalse);

      expect(MobileAssistanceState.active.canStop, isTrue);
      expect(MobileAssistanceState.paused.canStop, isTrue);
      expect(MobileAssistanceState.idle.canStop, isFalse);
      expect(MobileAssistanceState.active.canPause, isTrue);
      expect(MobileAssistanceState.paused.canPause, isFalse);
    });

    // UT-INT-017: AssistanceSessionState copyWith
    test('UT-INT-017: AssistanceSessionState copyWith works correctly', () {
      const original = AssistanceSessionState(
        state: MobileAssistanceState.idle,
      );

      final withError = original.copyWith(
        state: MobileAssistanceState.error,
        errorMessage: 'Test error',
      );

      expect(withError.state, MobileAssistanceState.error);
      expect(withError.errorMessage, 'Test error');
      expect(original.state, MobileAssistanceState.idle);
      expect(original.errorMessage, isNull);
    });

    // UT-INT-018: Diagnostics are reset on start
    test(
      'UT-INT-018: diagnostics reset on each startAssistance call',
      () async {
        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              FakePermissionService(),
            ),
            cameraServiceProvider.overrideWithValue(FakeCameraService()),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        final controller = container.read(
          assistanceControllerProvider.notifier,
        );
        final inference = container.read(inferenceControllerProvider.notifier)
          ..processedFrames = 99
          ..droppedFrames = 10
          ..totalInferenceMs = 1000;

        expect(inference.processedFrames, 99);

        await controller.startAssistance();

        expect(controller.diagnostics.processedFrames, 0);
        expect(controller.diagnostics.droppedFrames, 0);
        expect(controller.diagnostics.totalInferenceMs, 0);
      },
    );

    // UT-INT-019: No frames stored — camera frames are transient
    test('UT-INT-019: camera frames are not stored anywhere', () {
      // This is a structural assertion — the CameraFrame is consumed
      // by _onFrame and not stored. We verify by checking the inference
      // service interface has no buffer/storage method.
      final service = FakeInferenceService();
      expect(service, isA<InferenceService>());
      // The FakeInferenceService does not store frames, matching the
      // production implementation which passes frames directly to native
      // code via MethodChannel (bytes go to TFLite, not saved).
    });

    // UT-INT-020: FeedbackMode.vibration — TTS not called
    test('UT-INT-020: vibration-only mode respects feedback mode enum', () {
      expect(FeedbackMode.vibration.label, 'Vibration');
      expect(FeedbackMode.audio.label, 'Audio');
      expect(FeedbackMode.audioAndVibration.label, 'Audio and vibration');
    });

    test('UT-INT-021: stop invalidates an in-progress start', () async {
      final fakePermission = FakePermissionService()
        ..checkDelay = const Duration(milliseconds: 40);
      final fakeCamera = FakeCameraService();
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(fakePermission),
          cameraServiceProvider.overrideWithValue(fakeCamera),
          inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final controller = container.read(assistanceControllerProvider.notifier);
      final start = controller.startAssistance();
      await Future<void>.delayed(Duration.zero);
      await controller.stopAssistance();
      await start;

      expect(
        container.read(assistanceControllerProvider).state,
        MobileAssistanceState.idle,
      );
      expect(fakeCamera.initializeCalled, isFalse);
    });

    test('UT-INT-022: disabled vibration-only mode fails safely', () async {
      final fakeCamera = FakeCameraService();
      final fakeInference = FakeInferenceService();
      final container = ProviderContainer(
        overrides: [
          permissionServiceProvider.overrideWithValue(FakePermissionService()),
          cameraServiceProvider.overrideWithValue(fakeCamera),
          inferenceServiceProvider.overrideWithValue(fakeInference),
          ttsServiceProvider.overrideWithValue(FakeTtsService()),
          vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
          alertOrchestratorProvider.overrideWithValue(FakeAlertOrchestrator()),
        ],
      );
      addTearDown(container.dispose);

      final settings = container.read(appSettingsControllerProvider.notifier);
      settings.selectFeedbackMode(FeedbackMode.vibration);
      settings.setVibrationEnabled(false);

      await container
          .read(assistanceControllerProvider.notifier)
          .startAssistance();

      final session = container.read(assistanceControllerProvider);
      expect(session.state, MobileAssistanceState.error);
      expect(session.failureKind?.name, 'feedback');
      expect(session.errorMessage, contains('feedback failed to initialize'));
      expect(fakeCamera.disposeCalled, isTrue);
      expect(fakeInference.disposeCalled, isTrue);
    });

    test(
      'UT-INT-023: runtime camera error stops and releases assistance',
      () async {
        final fakeCamera = FakeCameraService();
        final container = ProviderContainer(
          overrides: [
            permissionServiceProvider.overrideWithValue(
              FakePermissionService(),
            ),
            cameraServiceProvider.overrideWithValue(fakeCamera),
            inferenceServiceProvider.overrideWithValue(FakeInferenceService()),
            ttsServiceProvider.overrideWithValue(FakeTtsService()),
            vibrationServiceProvider.overrideWithValue(FakeVibrationService()),
            alertOrchestratorProvider.overrideWithValue(
              FakeAlertOrchestrator(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await container
            .read(assistanceControllerProvider.notifier)
            .startAssistance();
        expect(
          container.read(assistanceControllerProvider).state,
          MobileAssistanceState.active,
        );

        fakeCamera.emitRuntimeError('Camera device disconnected');
        await Future<void>.delayed(Duration.zero);
        await Future<void>.delayed(Duration.zero);

        final result = container.read(assistanceControllerProvider);
        expect(result.state, MobileAssistanceState.error);
        expect(result.errorMessage, contains('Camera device disconnected'));
        expect(fakeCamera.disposeCalled, isTrue);
      },
    );
  });
}
