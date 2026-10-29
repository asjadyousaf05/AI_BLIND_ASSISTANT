import 'dart:async';
import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/lifecycle/app_lifecycle_observer.dart';
import '../domain/entities/assistant_message.dart';
import '../domain/entities/smart_ai_cloud_configuration.dart';
import '../domain/services/audio_recorder_service.dart';
import '../domain/services/microphone_permission_service.dart';
import '../domain/services/smart_ai_audio_coordinator.dart';
import '../domain/services/smart_ai_cloud_service.dart';
import '../domain/services/smart_ai_interaction_policy.dart';
import 'assistant_providers.dart';
import 'smart_ai_cloud_providers.dart';

enum SmartAiPhase {
  idle,
  preparing,
  recording,
  transcribing,
  thinking,
  speaking,
  paused,
  failed,
}

class SmartAiCloudState {
  const SmartAiCloudState({
    this.configuration,
    this.loaded = false,
    this.ready = false,
    this.phase = SmartAiPhase.idle,
    this.messages = const [],
    this.error,
    this.returnHomeRequested = false,
    this.speechLanguage = SmartAiSpeechLanguage.automatic,
    this.speechIsGuide = false,
  });
  final SmartAiCloudConfiguration? configuration;
  final bool loaded;
  final bool ready;
  final SmartAiPhase phase;
  final List<AssistantMessage> messages;
  final String? error;
  final bool returnHomeRequested;
  final SmartAiSpeechLanguage speechLanguage;
  final bool speechIsGuide;
  bool get busy => phase != SmartAiPhase.idle && phase != SmartAiPhase.failed;
  SmartAiCloudState copy({
    SmartAiCloudConfiguration? configuration,
    bool removeConfiguration = false,
    bool? loaded,
    bool? ready,
    SmartAiPhase? phase,
    List<AssistantMessage>? messages,
    String? error,
    bool clearError = false,
    bool? returnHomeRequested,
    SmartAiSpeechLanguage? speechLanguage,
    bool? speechIsGuide,
  }) => SmartAiCloudState(
    configuration: removeConfiguration
        ? null
        : configuration ?? this.configuration,
    loaded: loaded ?? this.loaded,
    ready: ready ?? this.ready,
    phase: phase ?? this.phase,
    messages: messages ?? this.messages,
    error: clearError ? null : error ?? this.error,
    returnHomeRequested: returnHomeRequested ?? this.returnHomeRequested,
    speechLanguage: speechLanguage ?? this.speechLanguage,
    speechIsGuide: speechIsGuide ?? this.speechIsGuide,
  );
}

final smartAiCloudControllerProvider =
    NotifierProvider<SmartAiCloudController, SmartAiCloudState>(
      SmartAiCloudController.new,
    );

/// A separate, foreground-only sequential turn. Vision AI never invokes this
/// controller and its recognizer/provider paths do not depend on it.
class SmartAiCloudController extends Notifier<SmartAiCloudState> {
  SmartAiCloudController({
    this.recordingLimit = const Duration(
      seconds: AudioRecorderService.maxDurationSeconds,
    ),
    this.turnTimeout = const Duration(seconds: 45),
  });
  final Duration recordingLimit;
  final Duration turnTimeout;
  Future<void>? _loading;
  Future<void>? _cancelling;
  Future<void>? _focusAcquisition;
  Future<void>? _releasingAudio;
  int _configurationGeneration = 0;
  int _generation = 0;
  bool _active = false;
  bool _foreground = true;
  Timer? _recordingDeadline;
  Timer? _networkDeadline;
  SmartAiCloudService? _service;
  AudioRecorderService? _recorder;
  SmartAiAudioCoordinator? _audio;
  AppLifecycleObserver? _observer;
  bool _holding = false;
  bool _heldRecordingReady = false;
  int _holdGeneration = 0;
  Future<void>? _holdStarting;
  Future<void>? _speechTransition;
  StreamSubscription<void>? _goodbyeSubscription;
  SmartAiSpeechLanguage _recordingLanguage = SmartAiSpeechLanguage.automatic;

  @override
  SmartAiCloudState build() {
    _observer = AppLifecycleObserver(onStateChanged: _lifecycle);
    WidgetsBinding.instance.addObserver(_observer!);
    ref.onDispose(() {
      final ownedAudio = _active;
      _generation++;
      _active = false;
      _recordingDeadline?.cancel();
      _networkDeadline?.cancel();
      unawaited(_goodbyeSubscription?.cancel());
      _service?.cancelPending();
      if (_audio != null) unawaited(_audio!.stopRecordingCue());
      if (_recorder != null) unawaited(_recorder!.cancelRecording());
      if (ownedAudio && _audio != null) unawaited(_audio!.stopSpeech());
      WidgetsBinding.instance.removeObserver(_observer!);
    });
    unawaited(loadConfiguration());
    return const SmartAiCloudState();
  }

  Future<void> loadConfiguration() => _loading ??= _loadConfiguration();
  Future<void> _loadConfiguration() async {
    final generation = _configurationGeneration;
    SmartAiCloudConfiguration? configuration;
    try {
      configuration = await ref
          .read(smartAiCloudConfigurationRepositoryProvider)
          .load()
          .timeout(const Duration(seconds: 3));
    } catch (_) {}
    if (ref.mounted && generation == _configurationGeneration) {
      state = state.copy(configuration: configuration, loaded: true);
    }
  }

  Future<String?> configure(SmartAiCloudConfiguration configuration) async {
    if (state.busy) {
      return 'Finish or cancel your current Smart AI request first.';
    }
    if (!configuration.isValid) {
      return 'Enter the personal keys for the selected provider.';
    }
    _configurationGeneration++;
    try {
      await ref
          .read(smartAiCloudConfigurationRepositoryProvider)
          .save(configuration);
      if (ref.mounted) {
        state = state.copy(
          configuration: configuration,
          loaded: true,
          messages: const [],
          phase: SmartAiPhase.idle,
          clearError: true,
        );
      }
      return null;
    } catch (_) {
      return 'Could not save Smart AI keys securely. Please try again.';
    }
  }

  Future<String?> removeConfiguration() async {
    if (state.busy) {
      return 'Finish or cancel your current Smart AI request first.';
    }
    _configurationGeneration++;
    try {
      await ref.read(smartAiCloudConfigurationRepositoryProvider).delete();
      if (ref.mounted) {
        state = state.copy(
          removeConfiguration: true,
          loaded: true,
          messages: const [],
          phase: SmartAiPhase.idle,
          clearError: true,
        );
      }
      return null;
    } catch (_) {
      return 'Could not remove Smart AI keys securely. Please try again.';
    }
  }

  Future<void> activate() async {
    _active = true;
    state = state.copy(returnHomeRequested: false);
    final generation = _generation;
    final release = _releasingAudio;
    if (release != null) await release;
    await loadConfiguration();
    if (!ref.mounted || !_active || generation != _generation) {
      return;
    }
    _foreground =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    if (state.configuration != null) {
      _service ??= ref.read(smartAiCloudServiceProvider);
      _recorder ??= ref.read(smartAiAudioRecorderProvider);
    }
    _audio ??= ref.read(smartAiAudioCoordinatorProvider);
    if (!_foreground) return;
    _goodbyeSubscription ??= _audio!.goodbyeRequests.listen((_) {
      if (_active &&
          _foreground &&
          state.phase != SmartAiPhase.recording &&
          state.phase != SmartAiPhase.preparing) {
        unawaited(returnHome());
      }
    });
    try {
      final pending = _focusAcquisition;
      if (pending != null) await pending;
      if (!_current(generation)) return;
      final acquisition = _audio!.acquire();
      _focusAcquisition = acquisition;
      await acquisition;
      if (identical(_focusAcquisition, acquisition)) _focusAcquisition = null;
      if (_current(generation)) {
        state = state.copy(ready: true, clearError: true);
      }
    } catch (_) {
      _focusAcquisition = null;
      if (_current(generation)) {
        state = state.copy(
          ready: false,
          phase: SmartAiPhase.failed,
          error:
              'Could not prepare phone audio. Retry Smart AI audio or reopen this screen.',
        );
      }
    }
  }

  Future<void> deactivate() async {
    if (!_active) return;
    _active = false;
    final completion = Completer<void>();
    _releasingAudio = completion.future;
    if (ref.mounted) state = state.copy(ready: false);
    try {
      unawaited(_goodbyeSubscription?.cancel());
      _goodbyeSubscription = null;
      await cancel();
      try {
        await _focusAcquisition;
      } catch (_) {}
      await _audio?.release();
    } finally {
      completion.complete();
      if (identical(_releasingAudio, completion.future)) _releasingAudio = null;
    }
  }

  bool _current(int generation) =>
      ref.mounted && _active && _foreground && generation == _generation;

  Future<void> startRecording() async {
    if (!state.ready ||
        state.busy ||
        state.configuration == null ||
        !_active ||
        !_foreground) {
      return;
    }
    final generation = ++_generation;
    _recordingLanguage = state.speechLanguage;
    state = state.copy(
      phase: SmartAiPhase.preparing,
      clearError: true,
      speechIsGuide: false,
    );
    final pendingCancellation = _cancelling;
    if (pendingCancellation != null) await pendingCancellation;
    if (!_current(generation)) return;
    try {
      final MicrophonePermissionService permission = ref.read(
        microphonePermissionServiceProvider,
      );
      var status = await permission.checkPermission();
      if (!_current(generation)) return;
      if (!status.isGranted) status = await permission.requestPermission();
      if (!_current(generation)) return;
      if (!status.isGranted) {
        throw SmartAiCloudException(
          status.isPermanentlyDenied
              ? 'Allow microphone access in Android Settings, or use text input.'
              : 'Microphone permission is needed to record. You can also type.',
        );
      }
      await _audio!.prepareRecording();
      if (!_current(generation)) return;
      await _recorder!.startRecording();
      if (!_current(generation)) {
        await _recorder!.cancelRecording();
        return;
      }
      state = state.copy(phase: SmartAiPhase.recording);
      try {
        await _audio!.recordingStartedCue();
      } catch (error) {
        if (_current(generation)) {
          state = state.copy(
            error: error is SmartAiCloudException
                ? error.message
                : 'Listening feedback is unavailable. Follow the Listening label or use Button controls.',
          );
        }
      }
      if (!_current(generation)) return;
      _recordingDeadline = Timer(
        recordingLimit,
        () => unawaited(stopAndSubmit()),
      );
    } catch (error) {
      if (_current(generation)) {
        try {
          await _audio?.recordingFinished();
        } catch (_) {}
        if (_current(generation)) _fail(error);
      }
    }
  }

  Future<void> stopAndSubmit() async {
    if (state.phase != SmartAiPhase.recording) return;
    final generation = _generation;
    _recordingDeadline?.cancel();
    state = state.copy(phase: SmartAiPhase.transcribing);
    String? path;
    try {
      await _audio!.stopRecordingCue();
      path = await _recorder!.stopRecording();
      if (!_current(generation)) return;
      await _audio!.recordingFinished();
      if (!_current(generation)) return;
      if (path == null) {
        throw const SmartAiCloudException(
          'No usable audio was recorded. Please try again.',
        );
      }
      _startNetworkDeadline();
      String transcript;
      try {
        transcript = await _service!.transcribe(
          configuration: state.configuration!,
          audioPath: path,
          language: _recordingLanguage,
        );
      } finally {
        await _deleteClip(path);
        path = null;
      }
      if (!_current(generation)) return;
      await _answer(transcript, generation, language: _recordingLanguage);
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (path != null) await _deleteClip(path);
    }
  }

  Future<void> sendText(String text) async {
    if (!state.ready ||
        state.busy ||
        state.configuration == null ||
        text.trim().isEmpty ||
        !_active ||
        !_foreground) {
      return;
    }
    final generation = ++_generation;
    state = state.copy(phase: SmartAiPhase.thinking, clearError: true);
    final pendingCancellation = _cancelling;
    if (pendingCancellation != null) await pendingCancellation;
    if (!_current(generation)) return;
    _startNetworkDeadline();
    try {
      await _answer(text.trim(), generation);
    } catch (error) {
      if (_current(generation)) _fail(error);
    }
  }

  Future<void> _answer(
    String transcript,
    int generation, {
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  }) async {
    if (transcript.isEmpty || transcript.length > 4096) {
      throw const SmartAiCloudException(
        'Use a question of at most 4096 characters.',
      );
    }
    if (SmartAiInteractionPolicy.isGoodbye(transcript)) {
      await returnHome();
      return;
    }
    final history = List<AssistantMessage>.of(state.messages);
    _append(transcript, AssistantMessageRole.user);
    state = state.copy(phase: SmartAiPhase.thinking);
    final local = await _audio!.routeLocalControl(transcript);
    if (!_current(generation)) return;
    if (local != null) {
      _networkDeadline?.cancel();
      if (local.isNotEmpty) _append(local, AssistantMessageRole.assistant);
      state = state.copy(phase: SmartAiPhase.idle);
      return;
    }
    final answer = await _service!.reply(
      configuration: state.configuration!,
      transcript: transcript,
      history: history,
      language: language,
    );
    if (!_current(generation)) return;
    _networkDeadline?.cancel();
    _append(answer, AssistantMessageRole.assistant);
    state = state.copy(phase: SmartAiPhase.speaking, speechIsGuide: false);
    await _audio!.speak(answer);
    if (_current(generation)) state = state.copy(phase: SmartAiPhase.idle);
  }

  void _append(String text, AssistantMessageRole role) {
    final next = [
      ...state.messages,
      AssistantMessage(
        id: '${DateTime.now().microsecondsSinceEpoch}-${state.messages.length}',
        role: role,
        text: text,
        createdAt: DateTime.now(),
      ),
    ];
    state = state.copy(
      messages: List.unmodifiable(
        next.skip(next.length > 12 ? next.length - 12 : 0),
      ),
    );
  }

  void _startNetworkDeadline() {
    final generation = _generation;
    _networkDeadline?.cancel();
    _networkDeadline = Timer(turnTimeout, () {
      if (!_current(generation) || !state.busy) return;
      unawaited(
        cancel(
          error:
              'Smart AI timed out. Check your internet connection and try again.',
        ),
      );
    });
  }

  Future<void> cancel({String? error, bool preserveHold = false}) {
    if (!preserveHold) {
      _holding = false;
      _heldRecordingReady = false;
      _holdGeneration++;
    }
    _generation++;
    _recordingDeadline?.cancel();
    _networkDeadline?.cancel();
    _service?.cancelPending();
    if (ref.mounted) {
      state = state.copy(
        phase: error == null ? SmartAiPhase.idle : SmartAiPhase.failed,
        error: error,
        clearError: error == null,
      );
    }
    final operation = _cancelResources();
    _cancelling = operation;
    return operation.whenComplete(() {
      if (identical(_cancelling, operation)) _cancelling = null;
    });
  }

  Future<void> _cancelResources() async {
    await _audio?.stopRecordingCue();
    await _recorder?.cancelRecording();
    await _audio?.stopSpeech();
    if (_active && _foreground) await _audio?.recordingFinished();
  }

  void setSpeechLanguage(SmartAiSpeechLanguage language) {
    if (!state.busy) state = state.copy(speechLanguage: language);
  }

  Future<void> returnHome() async {
    if (!_active) return;
    await deactivate();
    if (ref.mounted) state = state.copy(returnHomeRequested: true);
  }

  Future<void> testListeningCue() async {
    if (!state.ready || state.busy || !_active || !_foreground) return;
    try {
      state = state.copy(clearError: true);
      await _audio!.recordingStartedCue();
    } catch (error) {
      if (ref.mounted) {
        state = state.copy(
          error: error is SmartAiCloudException
              ? error.message
              : 'Listening feedback is unavailable. Follow the Listening label or use Button controls.',
        );
      }
    }
  }

  Future<void> speakGuide() async {
    if (!state.ready || state.busy || !_active || !_foreground) return;
    final generation = ++_generation;
    state = state.copy(
      phase: SmartAiPhase.speaking,
      speechIsGuide: true,
      clearError: true,
    );
    try {
      await _audio!.speak(
        state.configuration == null
            ? 'Welcome to Smart AI. Choose Set up Smart AI to save your personal key and review audio-sharing consent on this phone. '
                  'Questions stay disabled until setup is complete. Local Vision AI is listening for go back, go home, open settings and open about page without holding the circle. '
                  'The vibration and sound test works without a cloud account.'
            : 'Welcome to Smart AI. Hold the large microphone circle for one second. '
                  'Wait for the vibration and short chime, speak, then lift your finger to send. '
                  'Tap the circle during an answer to pause. Tap again to resume. '
                  'Hold again to ask a new question. Choose English or Urdu if automatic speech recognition gets the language wrong. '
                  'Local Vision AI listens for app commands between recordings and when an answer is paused. '
                  'Say go back, go home, open settings, or open about page without holding the circle. '
                  'To return home, say goodbye Smart AI without holding the circle, '
                  'or use Back to Home. You can also open Button controls.',
      );
      if (_current(generation)) {
        state = state.copy(phase: SmartAiPhase.idle, speechIsGuide: false);
      }
    } catch (error) {
      if (_current(generation)) _fail(error);
    }
  }

  void clearHistory() {
    if (!state.busy) state = state.copy(messages: const [], clearError: true);
  }

  Future<void> beginHold() {
    if (!state.ready ||
        state.configuration == null ||
        !_active ||
        !_foreground ||
        _holding ||
        state.phase == SmartAiPhase.preparing ||
        state.phase == SmartAiPhase.recording) {
      return Future.value();
    }
    final hold = ++_holdGeneration;
    _holding = true;
    _heldRecordingReady = false;
    final operation = _beginHold(hold);
    _holdStarting = operation;
    return operation;
  }

  Future<void> _beginHold(int hold) async {
    if (state.busy) await cancel(preserveHold: true);
    if (!_holding || hold != _holdGeneration) return;
    await startRecording();
    if (hold != _holdGeneration) return;
    if (!_holding) {
      await cancel(); // Released during permission/microphone setup: no upload.
    } else {
      _heldRecordingReady = state.phase == SmartAiPhase.recording;
    }
  }

  Future<void> endHold() async {
    if (!_holding) return;
    final hold = _holdGeneration;
    _holding = false;
    await _holdStarting;
    if (hold != _holdGeneration) return;
    final recorded = _heldRecordingReady;
    _heldRecordingReady = false;
    if (recorded && state.phase == SmartAiPhase.recording) {
      await stopAndSubmit();
    }
  }

  Future<void> cancelHold() async {
    if (_holding || _heldRecordingReady) await cancel();
  }

  Future<void> toggleSpeechPause() async {
    if (_speechTransition != null || !_active || !_foreground) return;
    if (state.phase != SmartAiPhase.speaking &&
        state.phase != SmartAiPhase.paused) {
      return;
    }
    final generation = _generation;
    final pause = state.phase == SmartAiPhase.speaking;
    state = state.copy(
      phase: pause ? SmartAiPhase.paused : SmartAiPhase.speaking,
    );
    final operation = pause ? _audio!.pauseSpeech() : _audio!.resumeSpeech();
    _speechTransition = operation;
    try {
      await operation;
    } catch (error) {
      if (_current(generation)) _fail(error);
    } finally {
      if (identical(_speechTransition, operation)) _speechTransition = null;
    }
  }

  /// Replays the retained answer after a voice-data/language repair, without
  /// another transcription, provider request or local control execution.
  Future<void> repeatLastAnswer() async {
    if (!state.ready || state.busy || !_active || !_foreground) return;
    final answers = state.messages.where((message) => message.isAssistant);
    if (answers.isEmpty) return;
    final generation = ++_generation;
    state = state.copy(phase: SmartAiPhase.speaking, clearError: true);
    final pendingCancellation = _cancelling;
    if (pendingCancellation != null) await pendingCancellation;
    if (!_current(generation)) return;
    try {
      await _audio!.speak(answers.last.text);
      if (_current(generation)) state = state.copy(phase: SmartAiPhase.idle);
    } catch (error) {
      if (_current(generation)) _fail(error);
    }
  }

  void _fail(Object error) {
    _networkDeadline?.cancel();
    _recordingDeadline?.cancel();
    state = state.copy(
      phase: SmartAiPhase.failed,
      error: error is SmartAiCloudException
          ? error.message
          : error is AudioRecorderException
          ? error.message
          : 'Smart AI could not finish. Please try again.',
    );
  }

  Future<void> _deleteClip(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  void _lifecycle(AppLifecycleState phase) {
    _foreground = phase == AppLifecycleState.resumed;
    if (!_active) return;
    if (!_foreground) {
      unawaited(cancel());
      if (ref.mounted) state = state.copy(ready: false);
    } else if (_active) {
      unawaited(activate());
    }
  }
}
