import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/app/voice_kernel/voice_kernel_providers.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/enums/voice_runtime_state.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/reader_barge_in_recognition.dart';
import 'package:ai_blind_assistant/features/ocr_scanner/presentation/ocr_scanner_screen.dart';
import '../assistant/assistant_controller_test.dart'
    show
        FakeOnDeviceSpeechRecognitionService,
        FakeMicrophonePermissionService,
        FakeSpeechOutputService;

class _Recognizer extends FakeOnDeviceSpeechRecognitionService
    implements ReaderBargeInRecognition {
  bool readerActive = false;
  final claimed = <String>[];
  final consumed = <String>{};
  Completer<bool>? claimGate;
  int pauses = 0;
  int sequence = 0;
  @override
  Future<void> setReaderPlaybackActive(bool active) async {
    readerActive = active;
  }

  @override
  Future<bool> acceptReaderCommandCandidate(String id) async {
    claimed.add(id);
    return claimGate == null ? consumed.add(id) : await claimGate!.future;
  }

  @override
  Future<void> pauseHandsFree() async {
    pauses++;
  }

  void propose(String text) => handsFreeEventController.add(
    HandsFreeSpeechEvent(
      type: HandsFreeSpeechEventType.readerCandidate,
      transcript: text,
      candidateId: 'candidate-${++sequence}',
    ),
  );
}

class _Speech extends FakeSpeechOutputService {
  final sentences = <String>[];
  final rates = <double>[];
  Completer<void>? _sentence;
  @override
  Future<void> speakSentence(
    String id,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    sentences.add(text);
    isSpeaking = true;
    final gate = Completer<void>();
    _sentence = gate;
    onStart?.call();
    onProgress?.call(0, text.length, text);
    await gate.future;
    if (identical(_sentence, gate)) isSpeaking = false;
  }

  @override
  Future<void> setSpeechRate(double rate) async {
    rates.add(rate);
  }

  @override
  Future<void> stop() async {
    isSpeaking = false;
    final gate = _sentence;
    _sentence = null;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}

class _Harness {
  _Harness(this.container, this.recognizer, this.speech, this.requests);
  final ProviderContainer container;
  final _Recognizer recognizer;
  final _Speech speech;
  final List<OcrActionRequest> requests;
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 30));
  await tester.pump();
  await tester.pump();
}

Future<_Harness> _open(
  WidgetTester tester, {
  String text = 'First synthetic sentence. Second synthetic sentence.',
}) async {
  final recognizer = _Recognizer();
  final speech = _Speech();
  final requests = <OcrActionRequest>[];
  final container = ProviderContainer(
    overrides: [
      onDeviceSpeechRecognitionServiceProvider.overrideWithValue(recognizer),
      speechOutputServiceProvider.overrideWithValue(speech),
      microphonePermissionServiceProvider.overrideWithValue(
        FakeMicrophonePermissionService(),
      ),
    ],
  );
  container.listen(ocrActionTriggerProvider, (_, value) {
    if (value != null) requests.add(value);
  });
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        home: OcrScannerScreen(initialDocumentTextForTesting: text),
      ),
    ),
  );
  await _settle(tester);
  await tester.ensureVisible(find.byKey(const Key('ocr_play_pause_button')));
  await tester.tap(find.byKey(const Key('ocr_play_pause_button')));
  await _settle(tester);
  expect(speech.sentences, isNotEmpty);
  expect(recognizer.readerActive, isTrue);
  expect(
    container.read(visionVoiceKernelProvider).isCommandSessionActive,
    isTrue,
  );
  return _Harness(container, recognizer, speech, requests);
}

Future<void> _close(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await _settle(tester);
  expect(tester.takeException(), isNull);
}

void main() {
  final controls = <String, OcrActionTrigger>{
    'stop reading': OcrActionTrigger.stopSpeaking,
    'pause reading': OcrActionTrigger.pause,
    'read again': OcrActionTrigger.readAgain,
    'read first line': OcrActionTrigger.restart,
    'read last line': OcrActionTrigger.last,
    'next line': OcrActionTrigger.next,
    'previous line': OcrActionTrigger.previous,
    'repeat sentence': OcrActionTrigger.repeat,
    'spell out': OcrActionTrigger.spell,
    'study mode': OcrActionTrigger.setLearningMode,
    'normal speed': OcrActionTrigger.setNormalMode,
    'fast mode': OcrActionTrigger.setSkimMode,
    'go to line two': OcrActionTrigger.goToLine,
  };
  for (final entry in controls.entries) {
    testWidgets('${entry.key} works before the document becomes silent', (
      tester,
    ) async {
      final h = await _open(tester);
      h.recognizer.propose(entry.key);
      await _settle(tester);
      expect(h.recognizer.claimed, hasLength(1));
      expect(h.requests.map((r) => r.action), contains(entry.value));
      if (entry.value == OcrActionTrigger.pause ||
          entry.value == OcrActionTrigger.stopSpeaking) {
        expect(h.recognizer.readerActive, isFalse);
      } else {
        expect(h.speech.sentences, hasLength(2));
        expect(h.recognizer.readerActive, isTrue);
      }
      if ([
        OcrActionTrigger.next,
        OcrActionTrigger.last,
        OcrActionTrigger.goToLine,
      ].contains(entry.value)) {
        expect(h.speech.sentences.last, 'Second synthetic sentence.');
      }
      if (entry.value == OcrActionTrigger.setSkimMode) {
        expect(h.speech.rates.last, .75);
      }
      if (entry.value == OcrActionTrigger.spell) {
        expect(h.speech.sentences.last, startsWith('F, I, R, S, T'));
      }
      expect(h.speech.spokenTexts, isNot(contains('Reading text again.')));
      await _close(tester);
    });
  }
  testWidgets('document speech cannot trigger its own commands or wake phrase', (
    tester,
  ) async {
    final h = await _open(
      tester,
      text:
          'The manual says stop reading, pause reading, read first line, spell out, fast mode, next line and hey vision ai.',
    );
    final resumes = h.recognizer.handsFreeResumeCount;
    final pauses = h.recognizer.pauses;
    for (final phrase in [
      'stop reading',
      'pause reading',
      'read first line',
      'spell out',
      'fast mode',
      'next line',
    ]) {
      h.recognizer.propose(phrase);
      await _settle(tester);
    }
    h.recognizer.handsFreeEventController.add(
      const HandsFreeSpeechEvent(type: HandsFreeSpeechEventType.wake),
    );
    await _settle(tester);
    expect(h.recognizer.claimed, isEmpty);
    expect(h.requests, isEmpty);
    expect(h.speech.sentences, hasLength(1));
    // Native wake delivery pauses capture even when it is speaker echo.
    // Restore that capture without claiming a reader action or stopping speech.
    expect(h.recognizer.handsFreeResumeCount, resumes + 1);
    expect(h.recognizer.pauses, pauses);
    h.recognizer.handsFreeEventController.add(
      const HandsFreeSpeechEvent(
        type: HandsFreeSpeechEventType.command,
        transcript: '[unk] stop reading [unk]',
      ),
    );
    await _settle(tester);
    expect(h.requests, isEmpty);
    expect(h.speech.sentences, hasLength(1));
    await _close(tester);
  });
  testWidgets('partial navigation and capture cannot interrupt reading', (
    tester,
  ) async {
    final h = await _open(tester);
    for (final phrase in [
      'open settings',
      'restart scanner',
      'scan again',
      'confirm',
      'turn flashlight on',
    ]) {
      h.recognizer.propose(phrase);
      await _settle(tester);
    }
    expect(h.recognizer.claimed, isEmpty);
    expect(h.requests, isEmpty);
    await _close(tester);
  });
  for (final background in [false, true]) {
    testWidgets(
      'late claim cannot execute after ${background ? 'backgrounding' : 'leaving reader'}',
      (tester) async {
        final h = await _open(tester);
        final gate = Completer<bool>();
        h.recognizer.claimGate = gate;
        h.recognizer.propose('pause reading');
        await _settle(tester);
        final kernel = h.container.read(visionVoiceKernelProvider.notifier);
        if (background) {
          await kernel.pauseVoice();
        } else {
          kernel.setFeatureContext(VoiceFeatureContext.home);
        }
        final resumes = h.recognizer.handsFreeResumeCount;
        gate.complete(true);
        await _settle(tester);
        expect(h.requests, isEmpty);
        if (background) {
          expect(h.recognizer.handsFreeResumeCount, resumes);
          expect(
            h.container.read(visionVoiceKernelProvider).runtimeState,
            VoiceRuntimeState.suspended,
          );
        }
        await _close(tester);
      },
    );
  }
  testWidgets('goodbye remains effective when playback changes', (
    tester,
  ) async {
    final h = await _open(tester);
    final kernel = h.container.read(visionVoiceKernelProvider.notifier);
    await kernel.processManualCommand('goodbye');
    kernel.setReaderPlaybackActive(false);
    kernel.setReaderPlaybackActive(true);
    h.recognizer.propose('pause reading');
    await _settle(tester);
    expect(
      h.container.read(visionVoiceKernelProvider).isCommandSessionActive,
      isFalse,
    );
    expect(h.recognizer.claimed, isEmpty);
    expect(h.requests, isEmpty);
    await _close(tester);
  });
}
