import 'dart:async';
import 'dart:io';

import 'package:camera_platform_interface/camera_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/app/voice_kernel/voice_kernel_providers.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/services/ocr_service.dart';
import 'package:ai_blind_assistant/features/ocr_scanner/presentation/ocr_scanner_screen.dart';

import '../assistant/assistant_controller_test.dart'
    show
        FakeMicrophonePermissionService,
        FakeOnDeviceSpeechRecognitionService,
        FakeSpeechOutputService;

class _SyntheticCamera extends CameraPlatform {
  _SyntheticCamera(this.directory);
  final Directory directory;
  int captures = 0;
  bool framingStarted = false;
  Completer<void>? captureGate;
  final captureStarted = Completer<void>();
  final List<File> photos = [];

  @override
  Future<List<CameraDescription>> availableCameras() async => const [
    CameraDescription(
      name: 'synthetic',
      lensDirection: CameraLensDirection.back,
      sensorOrientation: 90,
    ),
  ];

  @override
  Future<int> createCamera(
    CameraDescription cameraDescription,
    ResolutionPreset? resolutionPreset, {
    bool enableAudio = false,
  }) async => 1;

  @override
  Future<void> initializeCamera(
    int cameraId, {
    ImageFormatGroup imageFormatGroup = ImageFormatGroup.unknown,
  }) async {}

  @override
  Stream<CameraInitializedEvent> onCameraInitialized(int cameraId) =>
      Stream.value(
        CameraInitializedEvent(
          cameraId,
          640,
          480,
          ExposureMode.auto,
          true,
          FocusMode.auto,
          true,
        ),
      );

  @override
  Stream<CameraErrorEvent> onCameraError(int cameraId) => Stream.multi((_) {});

  @override
  Stream<DeviceOrientationChangedEvent> onDeviceOrientationChanged() =>
      Stream.multi((_) {});

  @override
  bool supportsImageStreaming() => true;

  @override
  Stream<CameraImageData> onStreamedFrameAvailable(
    int cameraId, {
    CameraImageStreamOptions? options,
  }) {
    framingStarted = true;
    return Stream.multi((_) {});
  }

  @override
  Future<XFile> takePicture(int cameraId) async {
    captures++;
    if (!captureStarted.isCompleted) captureStarted.complete();
    await captureGate?.future;
    // Empty test fixture only; no camera frames or actual image data.
    final photo = await File('${directory.path}/capture-$captures').create();
    photos.add(photo);
    return XFile(photo.path);
  }

  @override
  Widget buildPreview(int cameraId) => const SizedBox();

  @override
  Future<void> dispose(int cameraId) async {}
}

class _SyntheticOcr implements OcrService {
  int calls = 0;
  bool sawExistingPhoto = false;
  @override
  Future<String> recogniseText(String imagePath) async {
    calls++;
    sawExistingPhoto = File(imagePath).existsSync();
    return 'Fresh page text.';
  }

  @override
  Future<void> dispose() async {}
}

class _ReadingSpeech extends FakeSpeechOutputService {
  final freshPageSpoken = Completer<void>();

  @override
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    await super.speakSentence(
      utteranceId,
      text,
      onStart: onStart,
      onProgress: onProgress,
      onDone: onDone,
      onError: onError,
    );
    if (text == 'Fresh page text.' && !freshPageSpoken.isCompleted) {
      freshPageSpoken.complete();
    }
  }
}

Future<void> _pumpUntil(WidgetTester tester, bool Function() completed) async {
  final elapsed = Stopwatch()..start();
  // Camera/OCR callbacks run in the widget test zone; temporary-file IO runs
  // on the real event loop. Service both until the observable action finishes.
  while (!completed() && elapsed.elapsed < const Duration(seconds: 5)) {
    await tester.pump(const Duration(milliseconds: 10));
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1)),
    );
  }
  expect(completed(), isTrue, reason: 'Scanner workflow did not finish.');
  await tester.pump();
}

void main() {
  for (final phrase in ['scan again', 'restart scanner']) {
    testWidgets('$phrase waits in framing until an explicit capture request', (
      tester,
    ) async {
      final originalPlatform = CameraPlatform.instance;
      final directory = (await tester.runAsync(
        () => Directory.systemTemp.createTemp('aiba-scanner-test-'),
      ))!;
      final camera = _SyntheticCamera(directory);
      CameraPlatform.instance = camera;
      final speech = _ReadingSpeech();
      final ocr = _SyntheticOcr();
      final container = ProviderContainer(
        overrides: [
          speechOutputServiceProvider.overrideWithValue(speech),
          onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
            FakeOnDeviceSpeechRecognitionService(),
          ),
          microphonePermissionServiceProvider.overrideWithValue(
            FakeMicrophonePermissionService(),
          ),
          ocrServiceProvider.overrideWithValue(ocr),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        CameraPlatform.instance = originalPlatform;
        container.dispose();
        await tester.runAsync(() => directory.delete(recursive: true));
      });
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OcrScannerScreen(
              initialDocumentTextForTesting: 'Previous page text.',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      final gate = Completer<void>();
      camera.captureGate = gate;
      final kernel = container.read(visionVoiceKernelProvider.notifier);
      final feedback = await tester.runAsync(
        () => kernel.processManualCommand(phrase),
      );
      await _pumpUntil(tester, () => camera.framingStarted);
      expect(feedback, ''); // Scanner owns its ready announcement.
      expect(camera.captures, 0);
      expect(ocr.calls, 0);
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.scannerCapture,
      );
      expect(find.text('Previous page text.'), findsNothing);
      // Positioning has no countdown or delayed automatic capture.
      await tester.pump(const Duration(seconds: 10));
      expect(camera.captures, 0);
      expect(ocr.calls, 0);
      await tester.runAsync(() => kernel.processManualCommand(phrase));
      await tester.pump();
      expect(camera.captures, 0);
      await tester.runAsync(() => kernel.processManualCommand('scan document'));
      await _pumpUntil(tester, () => camera.captureStarted.isCompleted);
      expect(camera.captures, 1);
      expect(ocr.calls, 0);
      await tester.runAsync(() => kernel.processManualCommand(phrase));
      await tester.pump();
      expect(camera.captures, 1); // No overlapping second capture.
      gate.complete();
      await _pumpUntil(tester, () => speech.freshPageSpoken.isCompleted);
      expect(ocr.calls, 1);
      expect(ocr.sawExistingPhoto, isTrue);
      expect(camera.photos.every((photo) => !photo.existsSync()), isTrue);
      expect(
        speech.spokenTexts,
        contains('Fresh page text.'),
        reason: tester
            .widgetList<Text>(find.byType(Text))
            .map((text) => text.data)
            .join('; '),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }
}
