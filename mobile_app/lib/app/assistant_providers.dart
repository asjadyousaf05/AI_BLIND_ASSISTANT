import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../domain/enums/assistant_audio_state.dart';
import '../domain/repositories/assistant_credential_repository.dart';
import '../domain/repositories/assistant_repository.dart';
import '../domain/services/audio_recorder_service.dart';
import '../domain/services/microphone_permission_service.dart';
import '../domain/services/on_device_speech_recognition_service.dart';
import '../domain/services/speech_output_service.dart';
import '../domain/services/tts_echo_guard.dart';
import '../infrastructure/assistant/android_audio_recorder_service.dart';
import '../infrastructure/assistant/android_microphone_permission_service.dart';
import '../infrastructure/assistant/android_on_device_speech_recognition_service.dart';
import '../infrastructure/assistant/flutter_tts_speech_output_service.dart';
import '../infrastructure/assistant/http_assistant_repository.dart';
import '../infrastructure/assistant/secure_assistant_credential_repository.dart';

/// Microphone permission service provider.
final microphonePermissionServiceProvider =
    Provider<MicrophonePermissionService>((_) {
      return AndroidMicrophonePermissionService();
    });

/// Audio recorder service provider.
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  final service = AndroidAudioRecorderService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Dedicated Android API 31+ speech recognition that never uses a remote
/// recognizer. It is the only speech-input path used for app controls.
final onDeviceSpeechRecognitionServiceProvider =
    Provider<OnDeviceSpeechRecognitionService>((ref) {
      final service = AndroidOnDeviceSpeechRecognitionService();
      ref.onDispose(() => unawaited(service.dispose()));
      return service;
    });

/// Shared underlying TTS engine.
final flutterTtsInstanceProvider = Provider<FlutterTts>((ref) {
  return FlutterTts();
});

/// Platform speech output provider.
final speechOutputServiceProvider = Provider<SpeechOutputService>((ref) {
  final tts = ref.read(flutterTtsInstanceProvider);
  final service = FlutterTtsSpeechOutputService(tts: tts);
  ref.onDispose(() => service.dispose());
  return service;
});

/// Assistant credential repository provider.
final assistantCredentialRepositoryProvider =
    Provider<AssistantCredentialRepository>((_) {
      return SecureAssistantCredentialRepository();
    });

/// HTTP assistant repository provider.
final assistantRepositoryProvider = Provider<AssistantRepository>((_) {
  return HttpAssistantRepository();
});

/// Shared TTS echo guard tracking live speech ranges.
final ttsEchoGuardProvider = Provider<TtsEchoGuard>((ref) {
  return TtsEchoGuard();
});

/// Notifier for AssistantAudioState.
class AssistantAudioStateController extends Notifier<AssistantAudioState> {
  @override
  AssistantAudioState build() => AssistantAudioState.idle;

  void setAudioState(AssistantAudioState newState) {
    state = newState;
  }

  @override
  set state(AssistantAudioState newState) {
    super.state = newState;
  }
}

/// Authoritative Assistant Audio State Machine provider.
final assistantAudioStateProvider =
    NotifierProvider<AssistantAudioStateController, AssistantAudioState>(
      AssistantAudioStateController.new,
    );
