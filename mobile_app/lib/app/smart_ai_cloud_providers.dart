import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/repositories/smart_ai_cloud_configuration_repository.dart';
import '../domain/services/audio_recorder_service.dart';
import '../domain/services/smart_ai_audio_coordinator.dart';
import '../domain/services/smart_ai_cloud_service.dart';
import '../domain/services/smart_ai_reply_speech_service.dart';
import '../domain/services/smart_ai_foreground_recognition.dart';
import '../infrastructure/assistant/smart_ai_recording_cue.dart';
import '../domain/enums/voice_feature_context.dart';
import '../infrastructure/assistant/http_smart_ai_cloud_service.dart';
import '../infrastructure/assistant/secure_smart_ai_cloud_configuration_repository.dart';
import '../infrastructure/assistant/smart_ai_audio_recorder.dart';
import '../infrastructure/assistant/localized_smart_ai_reply_speech.dart';
import 'assistant_providers.dart';
import 'providers.dart';
import 'voice_kernel/voice_kernel_providers.dart';

final smartAiCloudConfigurationRepositoryProvider =
    Provider<SmartAiCloudConfigurationRepository>(
      (_) => SecureSmartAiCloudConfigurationRepository(),
    );
final smartAiCloudServiceProvider = Provider<SmartAiCloudService>((ref) {
  final service = HttpSmartAiCloudService();
  ref.onDispose(service.close);
  return service;
});
final smartAiAudioRecorderProvider = Provider<AudioRecorderService>((ref) {
  final service = SmartAiAudioRecorder();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});
final smartAiAudioCoordinatorProvider = Provider<SmartAiAudioCoordinator>(
  (ref) => _LocalAudioCoordinator(ref),
);
final smartAiReplySpeechProvider = Provider<SmartAiReplySpeechService>((ref) {
  return LocalizedSmartAiReplySpeech(
    tts: ref.read(flutterTtsInstanceProvider),
    speakExisting: (text) => ref
        .read(visionVoiceKernelProvider.notifier)
        .speakFeedback(text, reportFailure: true),
    stopExisting: () =>
        ref.read(visionVoiceKernelProvider.notifier).stopSpeaking(),
    speakWithProgress: (text, onProgress) async {
      final guard = ref.read(ttsEchoGuardProvider);
      final generation = DateTime.now().microsecondsSinceEpoch;
      final id = 'smart_ai_$generation';
      guard.onTtsStart(
        utteranceId: id,
        sentenceId: id,
        sentenceText: text,
        generation: generation,
      );
      var completed = false;
      try {
        await ref
            .read(speechOutputServiceProvider)
            .speakSentence(
              id,
              text,
              onDone: () => completed = true,
              onProgress: (start, end, word) {
                guard.onTtsRange(
                  utteranceId: id,
                  rangeStart: start,
                  rangeEnd: end,
                  word: word,
                  generation: generation,
                );
                onProgress(start);
              },
            );
        return completed;
      } finally {
        guard.onTtsDone(utteranceId: id, generation: generation);
      }
    },
  );
});

/// One microphone owner: local controls yield only during button capture.
class _LocalAudioCoordinator implements SmartAiAudioCoordinator {
  _LocalAudioCoordinator(this.ref);
  final Ref ref;
  bool _active = false;
  Future<void>? _localStarting;
  final _cue = SmartAiRecordingCue();
  VisionVoiceKernelV3 get _kernel =>
      ref.read(visionVoiceKernelProvider.notifier);
  SmartAiForegroundRecognition? get _controls {
    final recognizer = ref.read(onDeviceSpeechRecognitionServiceProvider);
    return recognizer is SmartAiForegroundRecognition
        ? recognizer as SmartAiForegroundRecognition
        : null;
  }

  @override
  Stream<void> get goodbyeRequests =>
      (_controls?.smartAiGoodbyes ?? const Stream<void>.empty()).where(
        (_) =>
            _active &&
            ref.read(visionVoiceKernelProvider).activeContext ==
                VoiceFeatureContext.smartAi &&
            !ref.read(ttsEchoGuardProvider).isSelfEcho('goodbye smart ai'),
      );

  @override
  Future<void> acquire() async {
    _active = true;
    await _kernel.setSmartAiButtonMode(
      true,
      beforeCommand: () => ref.read(smartAiReplySpeechProvider).stop(),
    );
    await ref.read(smartAiReplySpeechProvider).stop();
    _kernel.setFeatureContext(VoiceFeatureContext.smartAi);
    await _controls?.setSmartAiControlsActive(true);
    await _kernel.listenForSmartAiControls();
  }

  @override
  Future<void> prepareRecording() async {
    await _cue.stop();
    await _localStarting;
    await ref.read(smartAiReplySpeechProvider).stop();
    // Stopping releases AudioRecord; pausing alone still owns the microphone.
    await _kernel.stopHandsFree();
  }

  @override
  Future<void> recordingFinished() {
    if (!_active ||
        WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      return Future.value();
    }
    final pending = _localStarting;
    if (pending != null) return pending;
    final operation = _kernel.listenForSmartAiControls();
    _localStarting = operation;
    return operation.whenComplete(() {
      if (identical(_localStarting, operation)) _localStarting = null;
    });
  }

  @override
  Future<void> release() async {
    _active = false;
    await _cue.stop();
    await _localStarting;
    if (!ref.mounted) return;
    await ref.read(smartAiReplySpeechProvider).stop();
    await _controls?.setSmartAiControlsActive(false);
    _kernel.setFeatureContext(VoiceFeatureContext.unknown);
    await _kernel.setSmartAiButtonMode(false);
    await _kernel.stopHandsFree();
    if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed &&
        ref.read(appSettingsControllerProvider).handsFreeAssistantEnabled) {
      await _kernel.startHandsFree();
    } else {
      await _kernel.stopHandsFree();
    }
  }

  @override
  Future<String?> routeLocalControl(String transcript) =>
      _kernel.processManualCommand(transcript);
  @override
  Future<void> speak(String text) =>
      ref.read(smartAiReplySpeechProvider).speak(text);
  @override
  Future<void> stopSpeech() => ref.read(smartAiReplySpeechProvider).stop();
  @override
  Future<void> pauseSpeech() async {
    await ref.read(smartAiReplySpeechProvider).pause();
    if (_active) await _kernel.listenForSmartAiControls();
  }

  @override
  Future<void> resumeSpeech() => ref.read(smartAiReplySpeechProvider).resume();
  @override
  Future<void> recordingStartedCue() => _cue.play();
  @override
  Future<void> stopRecordingCue() => _cue.stop();
}
