import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/assistant_session_controller.dart';
import 'package:ai_blind_assistant/app/providers.dart';
import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/domain/enums/feedback_mode.dart';
import 'package:ai_blind_assistant/domain/enums/microphone_permission_status.dart';
import 'package:ai_blind_assistant/domain/repositories/assistant_credential_repository.dart';
import 'package:ai_blind_assistant/domain/services/microphone_permission_service.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/speech_output_service.dart';

class _FakeCredentialRepo implements AssistantCredentialRepository {
  @override
  Future<void> deleteCredential() async {}
  @override
  Future<bool> hasPairedCredential() async => false;
  @override
  Future<AssistantCredential?> loadCredential() async => null;
  @override
  Future<void> saveCredential(AssistantCredential credential) async {}
}

class _FakeSpeechOutput implements SpeechOutputService {
  @override
  bool isSpeaking = false;
  @override
  Future<void> stop() async {}
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> speakSentence(
    String utteranceId,
    String text, {
    void Function()? onStart,
    void Function(int start, int end, String word)? onProgress,
    void Function()? onDone,
    void Function(String error)? onError,
  }) async {
    onStart?.call();
    onDone?.call();
  }

  @override
  Future<void> setSpeechRate(double rate) async {}
  @override
  Future<void> dispose() async {}
}

class _FakeSpeechRecognizer implements OnDeviceSpeechRecognitionService {
  @override
  Stream<HandsFreeSpeechEvent> get handsFreeEvents => const Stream.empty();
  @override
  Future<OnDeviceSpeechAvailability> checkAvailability() async =>
      const OnDeviceSpeechAvailability(available: false, platformVersion: 33);
  @override
  Future<void> startListening({required String locale}) async {}
  @override
  Future<OnDeviceSpeechResult> stopListening() async =>
      const OnDeviceSpeechResult(transcript: '', confidence: 1.0);
  @override
  Future<void> cancelListening() async {}
  @override
  Future<void> startHandsFree({required String locale}) async {}
  @override
  Future<void> pauseHandsFree() async {}
  @override
  Future<void> resumeHandsFree({bool acceptNextCommand = false}) async {}
  @override
  Future<void> stopHandsFree() async {}
  @override
  Future<void> setRecognitionProfile(String profile) async {}
  @override
  Future<void> dispose() async {}
}

class _FakeMicPermission implements MicrophonePermissionService {
  @override
  Future<MicrophonePermissionStatus> checkPermission() async =>
      MicrophonePermissionStatus.granted;
  @override
  Future<MicrophonePermissionStatus> requestPermission() async =>
      MicrophonePermissionStatus.granted;
  @override
  Future<void> openAppSettings() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantSessionController — Self-Healing Feedback Settings', () {
    test(
      'change feedback mode auto-enables vibration when vibration mode is requested',
      () async {
        final container = ProviderContainer(
          overrides: [
            assistantCredentialRepositoryProvider.overrideWithValue(
              _FakeCredentialRepo(),
            ),
            speechOutputServiceProvider.overrideWithValue(_FakeSpeechOutput()),
            onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
              _FakeSpeechRecognizer(),
            ),
            microphonePermissionServiceProvider.overrideWithValue(
              _FakeMicPermission(),
            ),
          ],
        );
        addTearDown(container.dispose);

        container
            .read(appSettingsControllerProvider.notifier)
            .setVibrationEnabled(false);

        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );
        await controller.sendTextQuery('set feedback to vibration');

        final settings = container.read(appSettingsControllerProvider);
        expect(settings.feedbackSettings.mode, FeedbackMode.vibration);
        expect(settings.vibrationEnabled, isTrue);
      },
    );

    test(
      'start mobile mode auto-resolves disabled vibration before startup',
      () async {
        final container = ProviderContainer(
          overrides: [
            assistantCredentialRepositoryProvider.overrideWithValue(
              _FakeCredentialRepo(),
            ),
            speechOutputServiceProvider.overrideWithValue(_FakeSpeechOutput()),
            onDeviceSpeechRecognitionServiceProvider.overrideWithValue(
              _FakeSpeechRecognizer(),
            ),
            microphonePermissionServiceProvider.overrideWithValue(
              _FakeMicPermission(),
            ),
          ],
        );
        addTearDown(container.dispose);

        // Force inconsistent state
        container
            .read(appSettingsControllerProvider.notifier)
            .selectFeedbackMode(FeedbackMode.vibration);
        container
            .read(appSettingsControllerProvider.notifier)
            .setVibrationEnabled(false);

        final controller = container.read(
          assistantSessionControllerProvider.notifier,
        );
        await controller.sendTextQuery('start mobile mode');
        await controller.confirmAction();

        final settings = container.read(appSettingsControllerProvider);
        expect(settings.vibrationEnabled, isTrue);
      },
    );
  });
}
