import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/camera_providers.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/core/widgets/visual_components.dart';
import 'package:ai_blind_assistant/domain/enums/camera_state.dart';
import 'package:ai_blind_assistant/domain/services/camera_service.dart';
import 'package:ai_blind_assistant/domain/services/speech_output_service.dart';
import 'package:ai_blind_assistant/features/ocr_scanner/presentation/ocr_scanner_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCameraService implements CameraService {
  @override
  bool get isTorchOn => false;
  @override
  Future<void> setTorch(bool enabled) async {}
  @override
  Future<void> initialize() async {}
  @override
  Future<void> startPreview() async {}
  @override
  Future<void> stopPreview() async {}
  @override
  Future<void> release() async {}
  @override
  Future<void> dispose() async {}
  @override
  void setFrameCallback(FrameCallback? callback) {}
  @override
  dynamic get previewWidget => null;
  @override
  String? get lastError => null;
  @override
  CameraState get currentState => CameraState.uninitialized;
  @override
  Stream<CameraState> get stateStream => const Stream.empty();
}

class _FakeSpeechOutput implements SpeechOutputService {
  @override
  bool isSpeaking = false;
  final List<String> spoken = [];

  @override
  Future<void> speak(String text) async {
    spoken.add(text);
  }

  @override
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    spoken.add(text);
    onStart?.call();
    onDone?.call();
  }

  @override
  Future<void> setSpeechRate(double rate) async {}

  @override
  Future<void> stop() async {}

  @override
  Future<void> dispose() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('OcrScannerScreen renders scaffold and title for accessibility', (
    tester,
  ) async {
    final fakeSpeech = _FakeSpeechOutput();
    final fakeCamera = _FakeCameraService();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(fakeCamera),
          speechOutputServiceProvider.overrideWithValue(fakeSpeech),
        ],
        child: const MaterialApp(home: OcrScannerScreen()),
      ),
    );

    await tester.pump();

    // Verify title and screen scaffold
    expect(find.text('Document Scanner'), findsAtLeastNWidgets(1));
    expect(find.byType(OcrScannerScreen), findsOneWidget);
    expect(find.byType(StatusPill), findsOneWidget);
    expect(find.text('Document Scanner Privacy'), findsOneWidget);
  });

  testWidgets('OcrScannerScreen handles action triggers without error', (
    tester,
  ) async {
    final fakeSpeech = _FakeSpeechOutput();
    final fakeCamera = _FakeCameraService();

    late ProviderContainer container;
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container = ProviderContainer(
          overrides: [
            cameraServiceProvider.overrideWithValue(fakeCamera),
            speechOutputServiceProvider.overrideWithValue(fakeSpeech),
          ],
        ),
        child: const MaterialApp(home: OcrScannerScreen()),
      ),
    );

    await tester.pump();

    // Trigger pause action via provider
    container
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.pause);
    await tester.pump();

    // Trigger stopSpeaking
    container
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.stopSpeaking);
    await tester.pump();

    expect(find.byType(OcrScannerScreen), findsOneWidget);
  });
}
