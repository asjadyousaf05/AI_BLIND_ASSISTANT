import 'dart:ui' show SemanticsAction;

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

import 'package:ai_blind_assistant/app/router/route_paths.dart';

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
  bool holdSentences = false;

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
    if (!holdSentences) onDone?.call();
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

  testWidgets('reader announces start pause and resume as its action changes', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    try {
      final speech = _FakeSpeechOutput()..holdSentences = true;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            cameraServiceProvider.overrideWithValue(_FakeCameraService()),
            speechOutputServiceProvider.overrideWithValue(speech),
          ],
          child: const MaterialApp(
            home: OcrScannerScreen(
              initialDocumentTextForTesting: 'A reading line.',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      for (final label in [
        'Start Reading',
        'Pause Reading',
        'Resume Reading',
      ]) {
        await tester.ensureVisible(
          find.byKey(const Key('ocr_play_pause_button')),
        );
        await tester.pump();
        final node = find.semantics.byLabel(label).evaluate().single;
        expect(node.flagsCollection.isButton, isTrue);
        node.owner!.performAction(node.id, SemanticsAction.tap);
        await tester.pump();
        await tester.pump();
      }
      await tester.ensureVisible(
        find.byKey(const Key('ocr_stop_reading_button')),
      );
      await tester.pump();
      final stop = find.semantics
          .byLabel('Stop document reading')
          .evaluate()
          .first;
      stop.owner!.performAction(stop.id, SemanticsAction.tap);
      await tester.pump();
      await tester.pump();
    } finally {
      semantics.dispose();
    }
  });

  testWidgets(
    'reader controls have precise labels and support TalkBack actions',
    (tester) async {
      final semantics = tester.ensureSemantics();
      try {
        final speech = _FakeSpeechOutput();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              cameraServiceProvider.overrideWithValue(_FakeCameraService()),
              speechOutputServiceProvider.overrideWithValue(speech),
            ],
            child: const MaterialApp(
              home: OcrScannerScreen(
                initialDocumentTextForTesting: 'First line. Last line.',
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump();
        const labels = {
          'ocr_prev_button': 'Read previous document line',
          'ocr_play_pause_button': 'Start Reading',
          'ocr_next_button': 'Read next document line',
          'ocr_first_line_button': 'Read first line',
          'ocr_line_picker_button': 'Choose reading line',
          'ocr_last_line_button': 'Read last line',
          'ocr_stop_reading_button': 'Stop document reading',
          'ocr_repeat_button': 'Repeat current line',
          'ocr_spell_button': 'Spell out current line letter by letter',
          'ocr_speed_learning_button': 'Set study reading speed',
          'ocr_speed_normal_button': 'Set normal reading speed',
          'ocr_speed_skim_button': 'Set fast reading speed',
          'ocr_copy_button': 'Copy full document text to clipboard',
          'ocr_rescan_button': 'Scan another document',
        };
        for (final entry in labels.entries) {
          await tester.ensureVisible(find.byKey(Key(entry.key)));
          await tester.pump();
          final node = find.semantics.byLabel(entry.value).evaluate().single;
          expect(node.label, entry.value);
          expect(node.flagsCollection.isButton, isTrue);
          expect(
            node.getSemanticsData().hasAction(SemanticsAction.tap),
            isTrue,
          );
        }

        await tester.ensureVisible(
          find.byKey(const Key('ocr_last_line_button')),
        );
        await tester.pump();
        final last = find.semantics.byLabel('Read last line').evaluate().single;
        last.owner!.performAction(last.id, SemanticsAction.tap);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        expect(speech.spoken, ['Last line.']);
      } finally {
        semantics.dispose();
      }
    },
  );

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

  testWidgets('reader UI exposes complete accessible playback navigation', (
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
        child: const MaterialApp(
          home: OcrScannerScreen(
            initialDocumentTextForTesting:
                'First reading line. Second reading line. Third reading line.',
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Line 1 of 3'), findsOneWidget);
    expect(find.byKey(const Key('ocr_first_line_button')), findsOneWidget);
    expect(find.byKey(const Key('ocr_last_line_button')), findsOneWidget);
    expect(find.byKey(const Key('ocr_line_picker_button')), findsOneWidget);
    expect(find.byKey(const Key('ocr_stop_reading_button')), findsOneWidget);
    expect(find.byKey(const Key('ocr_spell_button')), findsOneWidget);
    expect(find.text('VOICE CONTROLS'), findsOneWidget);

    final picker = find.byKey(const Key('ocr_line_picker_button'));
    await tester.ensureVisible(picker);
    await tester.tap(picker);
    await tester.pump();

    expect(find.text('Go to line'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('ocr_line_number_field')), '2');
    await tester.tap(find.byKey(const Key('ocr_go_to_line_confirm_button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));

    expect(fakeSpeech.spoken, contains('Second reading line.'));
  });

  testWidgets('Ask AI opens an editable local draft only after confirmation', (
    tester,
  ) async {
    final fakeSpeech = _FakeSpeechOutput();
    String? passedDraft;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(_FakeCameraService()),
          speechOutputServiceProvider.overrideWithValue(fakeSpeech),
        ],
        child: MaterialApp(
          home: const OcrScannerScreen(
            initialDocumentTextForTesting: 'Private document text.',
          ),
          onGenerateRoute: (settings) {
            if (settings.name != RoutePaths.assistant) return null;
            passedDraft = settings.arguments as String?;
            return MaterialPageRoute<void>(
              builder: (_) => const Scaffold(body: Text('Assistant draft')),
            );
          },
        ),
      ),
    );
    await tester.pump();
    await tester.ensureVisible(find.text('Ask AI'));
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();

    expect(passedDraft, isNull);
    expect(
      find.textContaining('Nothing is sent until you tap Send'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(passedDraft, isNull);

    await tester.ensureVisible(find.text('Ask AI'));
    await tester.tap(find.text('Ask AI'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ocr_review_in_assistant_button')));
    await tester.pumpAndSettle();
    expect(passedDraft, contains('Private document text.'));
    expect(find.text('Assistant draft'), findsOneWidget);
  });

  testWidgets('reader actions remain available at 2x text scale', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          cameraServiceProvider.overrideWithValue(_FakeCameraService()),
          speechOutputServiceProvider.overrideWithValue(_FakeSpeechOutput()),
        ],
        child: const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(2)),
            child: OcrScannerScreen(
              initialDocumentTextForTesting: 'First line. Second line.',
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.byKey(const Key('ocr_line_picker_button')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('ocr_rescan_button')));
    expect(tester.takeException(), isNull);
  });
}
