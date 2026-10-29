import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_command_result.dart';
import '../../domain/entities/voice_recognition_event.dart';
import '../../domain/enums/assistant_session_state.dart';
import '../../domain/enums/voice_feature_context.dart';
import '../../domain/enums/voice_intent.dart';
import '../../domain/enums/voice_rejection_reason.dart';
import '../../domain/enums/voice_runtime_state.dart';
import '../../domain/services/intelligent_intent_resolver.dart';
import '../../domain/services/on_device_speech_recognition_service.dart';
import '../../domain/services/reader_barge_in_recognition.dart';
import '../../domain/services/reader_voice_command_policy.dart';
import '../../domain/services/speech_output_service.dart';
import '../../domain/services/tts_echo_guard.dart';
import '../../domain/services/voice_action_registry.dart';
import '../../domain/services/voice_listening_feedback.dart';
import '../assistant_providers.dart';
import '../assistant_session_controller.dart';
import '../providers.dart';
import '../router/app_route_observer.dart';
import '../router/route_paths.dart';
import 'command_authorizer.dart';
import 'command_circuit_breaker.dart';
import 'command_deduplicator.dart';
import 'command_executor.dart';
import 'voice_diagnostic_logger.dart';

/// Immutable state for [VisionVoiceKernelV3].
class VoiceKernelState {
  const VoiceKernelState({
    this.runtimeState = VoiceRuntimeState.disabled,
    this.activeContext = VoiceFeatureContext.unknown,
    this.recognizerSessionId = 0,
    this.commandSessionId = 0,
    this.contextGeneration = 0,
    this.ttsGeneration = 0,
    this.lastResolvedCommand,
    this.pendingConfirmationCommand,
    this.lastRejectionReason,
    this.lastResult,
    this.isHandsFreeActive = false,
    this.isCommandSessionActive = false,
    this.statusMessage = 'Voice assistant is ready.',
  });

  final VoiceRuntimeState runtimeState;
  final VoiceFeatureContext activeContext;
  final int recognizerSessionId;
  final int commandSessionId;
  final int contextGeneration;
  final int ttsGeneration;
  final VoiceCommand? lastResolvedCommand;
  final VoiceCommand? pendingConfirmationCommand;
  final VoiceRejectionReason? lastRejectionReason;
  final VoiceCommandResult? lastResult;
  final bool isHandsFreeActive;
  final bool isCommandSessionActive;
  final String statusMessage;

  VoiceKernelState copyWith({
    VoiceRuntimeState? runtimeState,
    VoiceFeatureContext? activeContext,
    int? recognizerSessionId,
    int? commandSessionId,
    int? contextGeneration,
    int? ttsGeneration,
    VoiceCommand? lastResolvedCommand,
    VoiceCommand? pendingConfirmationCommand,
    VoiceRejectionReason? lastRejectionReason,
    VoiceCommandResult? lastResult,
    bool? isHandsFreeActive,
    bool? isCommandSessionActive,
    String? statusMessage,
    bool clearCommand = false,
    bool clearRejection = false,
    bool clearResult = false,
    bool clearPendingConfirmation = false,
  }) => VoiceKernelState(
    runtimeState: runtimeState ?? this.runtimeState,
    activeContext: activeContext ?? this.activeContext,
    recognizerSessionId: recognizerSessionId ?? this.recognizerSessionId,
    commandSessionId: commandSessionId ?? this.commandSessionId,
    contextGeneration: contextGeneration ?? this.contextGeneration,
    ttsGeneration: ttsGeneration ?? this.ttsGeneration,
    lastResolvedCommand: clearCommand
        ? null
        : (lastResolvedCommand ?? this.lastResolvedCommand),
    pendingConfirmationCommand: clearPendingConfirmation
        ? null
        : (pendingConfirmationCommand ?? this.pendingConfirmationCommand),
    lastRejectionReason: clearRejection
        ? null
        : (lastRejectionReason ?? this.lastRejectionReason),
    lastResult: clearResult ? null : (lastResult ?? this.lastResult),
    isHandsFreeActive: isHandsFreeActive ?? this.isHandsFreeActive,
    isCommandSessionActive:
        isCommandSessionActive ?? this.isCommandSessionActive,
    statusMessage: statusMessage ?? this.statusMessage,
  );
}

/// VisionVoiceKernelV3 — Central offline voice assistant orchestrator.
///
/// Rules:
/// - One recognizer owner.
/// - One TTS owner.
/// - Monotonic session and generation IDs prevent stale callbacks.
/// - Shared business logic via [CommandExecutor].
/// - Pure Dart intent resolution via [IntelligentIntentResolver].
class VisionVoiceKernelV3 extends Notifier<VoiceKernelState> {
  late final IntelligentIntentResolver _resolver;
  late final CommandDeduplicator _deduplicator;
  late final CommandCircuitBreaker _circuitBreaker;
  late final CommandAuthorizer _authorizer;
  late final CommandExecutor _executor;
  late final TtsEchoGuard _ttsEchoGuard;
  late final OnDeviceSpeechRecognitionService _speechRecognizer;
  late final SpeechOutputService _speechOutput;

  StreamSubscription<HandsFreeSpeechEvent>? _handsFreeSub;
  AppLifecycleListener? _lifecycleListener;
  int _eventCounter = 0;
  bool _initialized = false;
  bool _readerPlaybackActive = false;
  bool _readerCommandsDismissed = false;
  bool _claimingReaderCandidate = false;
  bool _voiceSuspended = false;
  bool _smartAiButtonMode = false;
  bool _commandInProgress = false;
  bool _handlingRecognition = false;
  bool _deferredResume = false;
  bool _recognizerNeedsRecovery = false;
  int _listenerGeneration = 0;
  Future<void>? _startOperation;
  Future<void>? _recoveryOperation;
  Future<void> Function()? _prepareSmartAiControl;
  VoiceFeatureContext _scannerContext = VoiceFeatureContext.scannerCapture;

  Future<void> setSmartAiButtonMode(
    bool active, {
    Future<void> Function()? beforeCommand,
  }) async {
    _smartAiButtonMode = active;
    _prepareSmartAiControl = active ? beforeCommand : null;
    if (state.activeContext == VoiceFeatureContext.smartAi) {
      await _speechRecognizer.setRecognitionProfile(
        _profileFor(state.activeContext),
      );
    }
  }

  String _profileFor(VoiceFeatureContext context) => switch (context) {
    VoiceFeatureContext.smartAi =>
      _smartAiButtonMode ? 'app_commands' : 'conversation',
    VoiceFeatureContext.scannerCapture ||
    VoiceFeatureContext.scannerReading => 'scanner_commands',
    _ => 'app_commands',
  };

  @override
  VoiceKernelState build() {
    _resolver = IntelligentIntentResolver();
    _deduplicator = CommandDeduplicator();
    _circuitBreaker = CommandCircuitBreaker();
    _ttsEchoGuard = ref.read(ttsEchoGuardProvider);
    _authorizer = CommandAuthorizer(
      deduplicator: _deduplicator,
      circuitBreaker: _circuitBreaker,
      ttsEchoGuard: _ttsEchoGuard,
    );
    _executor = CommandExecutor(ref);
    _speechRecognizer = ref.read(onDeviceSpeechRecognitionServiceProvider);
    _speechOutput = ref.read(speechOutputServiceProvider);

    ref.onDispose(_cleanup);

    // Initialize after build completes
    Future.microtask(_init);

    return const VoiceKernelState();
  }

  void _init() {
    if (!ref.mounted) return;
    if (_initialized) return;
    _initialized = true;

    _setupLifecycle();
    _subscribeHandsFree();
    appRouteObserver.addListener(_syncVisibleContext);
    _syncVisibleContext();

    final handsFreeEnabled = ref
        .read(appSettingsControllerProvider)
        .handsFreeAssistantEnabled;
    if (handsFreeEnabled) {
      unawaited(startHandsFree());
    }
  }

  // ─────────────────── Public API ──────────────────────────────

  /// Updates the active user-facing feature context.
  ///
  /// Increments [contextGeneration] so any pending recognitions from previous
  /// screens are rejected as stale.
  void setFeatureContext(VoiceFeatureContext newContext) {
    if (!ref.mounted) return;
    if (newContext.isScanner) _scannerContext = newContext;
    newContext = _visibleContext(newContext) ?? newContext;
    if (state.activeContext == newContext) return;

    final oldContext = state.activeContext;
    if (newContext != VoiceFeatureContext.scannerReading) {
      _readerCommandsDismissed = false;
      setReaderPlaybackActive(false);
    }
    final nextGen = state.contextGeneration + 1;
    final nextCmdSession = state.commandSessionId + 1;

    VoiceDiagnosticLogger.contextChange(oldContext, newContext, nextGen);

    state = state.copyWith(
      activeContext: newContext,
      contextGeneration: nextGen,
      commandSessionId: nextCmdSession,
      clearCommand: true,
      clearRejection: true,
    );

    // Reset circuit breaker on context change so user has fresh limits
    _circuitBreaker.reset();

    final profile = _profileFor(newContext);
    unawaited(_speechRecognizer.setRecognitionProfile(profile));
  }

  VoiceFeatureContext? _visibleContext(VoiceFeatureContext requested) =>
      switch (appRouteObserver.currentRoute) {
        RoutePaths.home => VoiceFeatureContext.home,
        RoutePaths.mobileAssistance => VoiceFeatureContext.mobileDetection,
        RoutePaths.raspberryPi ||
        RoutePaths.raspberryPiError => VoiceFeatureContext.wearable,
        RoutePaths.assistant => VoiceFeatureContext.smartAi,
        RoutePaths.settings ||
        RoutePaths.assistantConnection ||
        RoutePaths.assistantSettings => VoiceFeatureContext.settings,
        RoutePaths.ocrScanner =>
          requested.isScanner ? requested : _scannerContext,
        RoutePaths.aboutSafety ||
        RoutePaths.help => VoiceFeatureContext.informational,
        RoutePaths.startup ||
        RoutePaths.permissions ||
        RoutePaths.modeSelection => VoiceFeatureContext.unknown,
        _ => null,
      };

  void _syncVisibleContext() {
    if (ref.mounted) setFeatureContext(state.activeContext);
  }

  /// Foreground Smart AI accepts local app commands without a second wake.
  /// Questions still require the circle; this never enters a conversation path.
  Future<void> listenForSmartAiControls() async {
    if (!_smartAiButtonMode ||
        state.activeContext != VoiceFeatureContext.smartAi) {
      return;
    }
    _voiceSuspended = false;
    state = state.copyWith(isCommandSessionActive: true);
    if (!state.isHandsFreeActive) {
      await startHandsFree();
    } else {
      await _resumeListeningForCurrentSession();
    }
  }

  /// Keeps contextual reader controls available even during continuous TTS.
  /// Explicit goodbye remains respected until another wake or reader entry.
  void setReaderPlaybackActive(bool active) {
    if (!ref.mounted || _readerPlaybackActive == active) return;
    _readerPlaybackActive = active;
    final recognizer = _speechRecognizer;
    if (recognizer case ReaderBargeInRecognition readerRecognizer) {
      unawaited(readerRecognizer.setReaderPlaybackActive(active));
    }
    if (active &&
        !_voiceSuspended &&
        !_readerCommandsDismissed &&
        state.isHandsFreeActive &&
        !state.isCommandSessionActive &&
        state.activeContext == VoiceFeatureContext.scannerReading) {
      state = state.copyWith(isCommandSessionActive: true);
      unawaited(_resumeListeningForCurrentSession());
    }
  }

  /// Starts the hands-free wake-word recognition loop.
  Future<void> startHandsFree() {
    final pending = _startOperation ?? _recoveryOperation;
    if (pending != null) return pending;
    final operation = _startHandsFree();
    _startOperation = operation;
    return operation.whenComplete(() {
      if (identical(_startOperation, operation)) _startOperation = null;
    });
  }

  Future<void> _startHandsFree() async {
    if (!ref.mounted || _voiceSuspended) return;
    final generation = _listenerGeneration;
    final permissionService = ref.read(microphonePermissionServiceProvider);
    var permission = await permissionService.checkPermission();
    if (!permission.isGranted) {
      permission = await permissionService.requestPermission();
    }
    if (!ref.mounted || _voiceSuspended || generation != _listenerGeneration) {
      return;
    }
    if (!permission.isGranted) {
      state = state.copyWith(
        isHandsFreeActive: false,
        statusMessage: 'Allow microphone access once to use hands-free voice.',
      );
      return;
    }

    _transitionTo(VoiceRuntimeState.initializing);
    try {
      final continueCommandSession =
          state.isCommandSessionActive ||
          (_smartAiButtonMode &&
              state.activeContext == VoiceFeatureContext.smartAi) ||
          (_readerPlaybackActive && !_readerCommandsDismissed);
      final nextRecSession = state.recognizerSessionId + 1;
      state = state.copyWith(
        recognizerSessionId: nextRecSession,
        isHandsFreeActive: true,
        isCommandSessionActive: continueCommandSession,
        statusMessage: continueCommandSession
            ? _activeSessionStatus
            : _wakeListeningStatus,
      );

      VoiceDiagnosticLogger.sessionInfo(
        recognizerSession: nextRecSession,
        commandSession: state.commandSessionId,
        context: state.activeContext,
      );

      // Ask the native recognizer to use the hands-free profile if available.
      // This enables more aggressive VAD, noise suppression, and optimized
      // vocabularies for wake+command recognition on devices that support it.
      try {
        final profile = _profileFor(state.activeContext);
        await _speechRecognizer.setRecognitionProfile(profile);
      } catch (_) {}

      await _speechRecognizer
          .startHandsFree(locale: 'en-US')
          .timeout(const Duration(seconds: 15));
      if (!ref.mounted ||
          _voiceSuspended ||
          generation != _listenerGeneration) {
        await _speechRecognizer.stopHandsFree();
        if (ref.mounted) state = state.copyWith(isHandsFreeActive: false);
        return;
      }
      final recognizer = _speechRecognizer;
      if (recognizer case ReaderBargeInRecognition readerRecognizer) {
        await readerRecognizer.setReaderPlaybackActive(_readerPlaybackActive);
      }
      if (continueCommandSession) {
        await _speechRecognizer.resumeHandsFree(acceptNextCommand: true);
        _transitionTo(VoiceRuntimeState.commandListening);
      } else {
        _transitionTo(VoiceRuntimeState.wakeListening);
      }
    } catch (e) {
      VoiceDiagnosticLogger.error('Failed to start hands-free', e);
      if (!ref.mounted || generation != _listenerGeneration) return;
      await _speechRecognizer.stopHandsFree();
      if (!ref.mounted || generation != _listenerGeneration) return;
      _transitionTo(VoiceRuntimeState.error);
      state = state.copyWith(
        isHandsFreeActive: false,
        statusMessage: 'Could not start offline voice listener.',
      );
    }
  }

  /// Stops hands-free recognition and releases resources.
  Future<void> stopHandsFree() async {
    _listenerGeneration++;
    _recognizerNeedsRecovery = false;
    _transitionTo(VoiceRuntimeState.disabled);
    state = state.copyWith(
      isHandsFreeActive: false,
      isCommandSessionActive: false,
      statusMessage: 'Voice assistant is off.',
    );
    try {
      await _speechRecognizer.stopHandsFree();
    } catch (_) {}
  }

  /// Explicit accessible recovery without changing saved settings or trust.
  Future<void> restartHandsFree() async {
    final continueSession = state.isCommandSessionActive;
    await stopHandsFree();
    await _startOperation;
    await _recoveryOperation;
    if (!ref.mounted || _voiceSuspended) return;
    state = state.copyWith(isCommandSessionActive: continueSession);
    await startHandsFree();
    if (ref.mounted && state.isHandsFreeActive) await _signalListeningReady();
  }

  /// Pauses voice recognition (e.g. during phone call or app background).
  Future<void> pauseVoice() async {
    _listenerGeneration++;
    _voiceSuspended = true;
    _transitionTo(VoiceRuntimeState.suspended);
    try {
      await _speechRecognizer.pauseHandsFree();
    } catch (_) {}
  }

  /// Resumes voice recognition after pause.
  Future<void> resumeVoice() async {
    if (!_voiceSuspended) return;
    _voiceSuspended = false;
    try {
      await _resumeListeningForCurrentSession(signalReady: true);
    } catch (e) {
      VoiceDiagnosticLogger.error('Failed to resume voice', e);
      _transitionTo(VoiceRuntimeState.error);
    }
  }

  /// Restores the shared hands-free recognizer after a bounded external
  /// recording session, such as Smart AI push-to-talk.
  Future<void> resumeAfterExternalRecording({
    required bool acceptNextCommand,
  }) async {
    if (!ref.read(appSettingsControllerProvider).handsFreeAssistantEnabled) {
      return;
    }
    if (!state.isHandsFreeActive) {
      await startHandsFree();
    }
    if (!state.isHandsFreeActive) return;

    try {
      final continueCommandSession =
          acceptNextCommand || _shouldContinueCommandSession;
      if (continueCommandSession) {
        state = state.copyWith(isCommandSessionActive: true);
      }
      await _resumeListeningForCurrentSession(signalReady: true);
    } catch (error) {
      VoiceDiagnosticLogger.error(
        'Failed to restore hands-free recognition',
        error,
      );
      _transitionTo(VoiceRuntimeState.error);
    }
  }

  /// Speaks feedback text aloud and manages TTS echo guard.
  Future<void> speakFeedback(
    String text, {
    bool reportFailure = false,
    bool resumeListening = true,
  }) async {
    if (text.isEmpty || !ref.mounted) return;

    final nextTtsGen = state.ttsGeneration + 1;
    state = state.copyWith(ttsGeneration: nextTtsGen);

    _transitionTo(VoiceRuntimeState.speaking);
    final utteranceId =
        'voice_feedback_${DateTime.now().millisecondsSinceEpoch}';

    _ttsEchoGuard.onTtsStart(
      utteranceId: utteranceId,
      sentenceId: utteranceId,
      sentenceText: text,
      generation: nextTtsGen,
    );

    Object? speechFailure;
    StackTrace? speechFailureStack;
    try {
      // Pause mic while speaking unless barge-in is enabled
      await _speechRecognizer.pauseHandsFree();
      if (!ref.mounted || state.ttsGeneration != nextTtsGen) return;
      await _speechOutput.speak(text);
    } catch (e, stack) {
      VoiceDiagnosticLogger.error('TTS feedback failed', e);
      speechFailure = e;
      speechFailureStack = stack;
    }

    _ttsEchoGuard.onTtsDone(utteranceId: utteranceId, generation: nextTtsGen);

    // Async gap: verify this TTS generation was not superseded
    if (!ref.mounted || state.ttsGeneration != nextTtsGen || _voiceSuspended) {
      return;
    }
    if (!resumeListening) {
      _transitionTo(VoiceRuntimeState.executing);
      return;
    }

    final handsFreeEnabled = ref
        .read(appSettingsControllerProvider)
        .handsFreeAssistantEnabled;
    if (state.isHandsFreeActive &&
        (handsFreeEnabled ||
            (_smartAiButtonMode &&
                state.activeContext == VoiceFeatureContext.smartAi))) {
      await _resumeListeningForCurrentSession(signalReady: true);
    } else {
      if (state.isHandsFreeActive) {
        await stopHandsFree();
      }
      _transitionTo(VoiceRuntimeState.disabled);
    }
    if (reportFailure && speechFailure != null) {
      Error.throwWithStackTrace(speechFailure, speechFailureStack!);
    }
  }

  /// Silences all active speech immediately.
  Future<void> stopSpeaking() async {
    if (!ref.mounted) return;
    final stopGeneration = state.ttsGeneration + 1;
    state = state.copyWith(ttsGeneration: stopGeneration);
    _ttsEchoGuard.onTtsStop();
    try {
      await _speechOutput.stop();
    } catch (_) {}
    if (!ref.mounted || state.ttsGeneration != stopGeneration) return;
    if (state.isHandsFreeActive) {
      await _resumeListeningForCurrentSession();
    } else {
      _transitionTo(VoiceRuntimeState.disabled);
    }
  }

  // ─────────────────── Event Pipeline ──────────────────────────

  /// Processes a manually submitted text transcript (e.g. from push-to-talk).
  /// Returns the feedback text if the kernel executed a local app-control command,
  /// or null if it was unrecognized.
  Future<String?> processManualCommand(String transcript) async {
    if (!ref.mounted) return null;
    _syncVisibleContext();

    // Resolve intent based on current context
    final command = _resolver.resolve(transcript, context: state.activeContext);

    VoiceDiagnosticLogger.resolved(command);

    if (command.isUnrecognized) {
      return null; // Fallback to Smart AI or ignore
    }

    if (!VoiceActionRegistry.isAllowedIn(command.intent, state.activeContext)) {
      const message = 'That command is not available on this screen.';
      await speakFeedback(message);
      return message;
    }
    if (_commandInProgress) {
      return 'Please wait for the current action to finish.';
    }

    final contextBeforeCommand = state.activeContext;
    final result = await _executeWithProgress(command);
    _applySessionExitIfNeeded(command, contextBeforeCommand);
    _syncAssistantContextAfterCommand(command, result, contextBeforeCommand);

    final feedback = switch (result) {
      VoiceCommandSuccess(:final feedbackText) => feedbackText,
      VoiceCommandAlreadyInState(:final message) => message,
      VoiceCommandUnavailable(:final reason) => reason,
      VoiceCommandInvalidState(:final reason) => reason,
      VoiceCommandNeedsConfirmation(:final prompt) => prompt,
      VoiceCommandFailure(:final message) => message,
      _ => null,
    };

    if (feedback != null && feedback.isNotEmpty) {
      await speakFeedback(feedback);
    }

    return feedback ?? '';
  }

  void _subscribeHandsFree() {
    _handsFreeSub?.cancel();
    _handsFreeSub = _speechRecognizer.handsFreeEvents.listen(
      _handleNativeEvent,
      onError: (e) {
        VoiceDiagnosticLogger.error('HandsFree stream error', e);
        // Attempt to recover the recognizer when the native hands-free stream errors.
        unawaited(_recoverRecognizer());
      },
      onDone: () {
        VoiceDiagnosticLogger.info(
          'HandsFree stream completed unexpectedly — recovering recognizer',
        );
        unawaited(_recoverRecognizer());
      },
    );
  }

  void _handleNativeEvent(HandsFreeSpeechEvent event) {
    if (!ref.mounted || _voiceSuspended || !state.isHandsFreeActive) return;
    if (event.type == HandsFreeSpeechEventType.error) {
      VoiceDiagnosticLogger.error('Native recognition error event received');
      _recognizerNeedsRecovery = true;
      if (!_handlingRecognition &&
          !_commandInProgress &&
          state.runtimeState != VoiceRuntimeState.speaking) {
        unawaited(_recoverRecognizer());
      }
      return;
    }
    if (_handlingRecognition || _commandInProgress) {
      if (event.type != HandsFreeSpeechEventType.readerCandidate) {
        _deferredResume = true;
      }
      return;
    }
    if (state.runtimeState == VoiceRuntimeState.speaking ||
        state.runtimeState == VoiceRuntimeState.executing) {
      return;
    }
    _syncVisibleContext();
    switch (event.type) {
      case HandsFreeSpeechEventType.wake:
        unawaited(_runRecognition(_handleWake));
      case HandsFreeSpeechEventType.command:
        if (event.transcript?.trim().isNotEmpty == true) {
          unawaited(
            _runRecognition(() => _handleCommandTranscript(event.transcript!)),
          );
        } else {
          unawaited(_runRecognition(_resumeListeningForCurrentSession));
        }
      case HandsFreeSpeechEventType.readerCandidate:
        unawaited(_handleReaderCandidate(event));
      case HandsFreeSpeechEventType.timeout:
        unawaited(_runRecognition(_handleTimeout));
      case HandsFreeSpeechEventType.error:
        break;
    }
  }

  Future<void> _runRecognition(Future<void> Function() operation) async {
    _handlingRecognition = true;
    try {
      await operation();
    } catch (error) {
      VoiceDiagnosticLogger.error('Voice command handling failed', error);
      if (ref.mounted && state.isHandsFreeActive && !_voiceSuspended) {
        await _resumeListeningForCurrentSession();
      }
    } finally {
      _handlingRecognition = false;
      final resume = _deferredResume;
      _deferredResume = false;
      if (ref.mounted && state.isHandsFreeActive && !_voiceSuspended) {
        if (_recognizerNeedsRecovery) {
          await _recoverRecognizer();
        } else if (resume && state.runtimeState.isListening) {
          await _resumeListeningForCurrentSession();
        }
      }
    }
  }

  int _retryAttempts = 0;

  Future<void> _handleReaderCandidate(HandsFreeSpeechEvent event) async {
    final recognizer = _speechRecognizer;
    final transcript = event.transcript;
    final id = event.candidateId;
    if (_claimingReaderCandidate ||
        _voiceSuspended ||
        recognizer is! ReaderBargeInRecognition ||
        transcript == null ||
        id == null ||
        !state.isHandsFreeActive ||
        !state.runtimeState.acceptsVoiceInput ||
        !state.isCommandSessionActive ||
        !_readerPlaybackActive ||
        state.activeContext != VoiceFeatureContext.scannerReading ||
        _ttsEchoGuard.isSelfEcho(transcript)) {
      return;
    }
    final command = _resolver.resolve(transcript, context: state.activeContext);
    if (!ReaderVoiceCommandPolicy.allowsImmediate(command)) return;
    final contextGeneration = state.contextGeneration;
    final session = state.recognizerSessionId;
    final commandSession = state.commandSessionId;
    _claimingReaderCandidate = true;
    try {
      if (!await (recognizer as ReaderBargeInRecognition)
          .acceptReaderCommandCandidate(id)) {
        return;
      }
      if (!ref.mounted) return;
      if (state.contextGeneration != contextGeneration ||
          state.recognizerSessionId != session ||
          state.commandSessionId != commandSession ||
          !state.isHandsFreeActive ||
          !state.runtimeState.acceptsVoiceInput ||
          !_readerPlaybackActive) {
        if (state.isHandsFreeActive && !_voiceSuspended) {
          await _resumeListeningForCurrentSession();
        }
        return;
      }
      await _handleCommandTranscript(transcript);
    } finally {
      _claimingReaderCandidate = false;
    }
  }

  Future<void> _handleWake() async {
    if (_ttsEchoGuard.isWakeWordEcho()) {
      VoiceDiagnosticLogger.info('Discarding wake event due to TTS echo');
      // Native wake delivery pauses capture. A rejected echo must not leave
      // an otherwise active listener permanently paused.
      if (state.runtimeState.isListening) {
        await _resumeListeningForCurrentSession();
      }
      return;
    }

    VoiceDiagnosticLogger.wakeDetected();
    _readerCommandsDismissed = false;
    final nextCmdSession = state.commandSessionId + 1;
    _retryAttempts = 0;
    state = state.copyWith(
      commandSessionId: nextCmdSession,
      isCommandSessionActive: true,
      statusMessage: 'Listening for your command…',
    );
    _transitionTo(VoiceRuntimeState.commandListening);

    // If reading or speaking, immediately pause TTS/OCR and provide tactile feedback
    if (state.activeContext == VoiceFeatureContext.scannerReading ||
        _speechOutput.isSpeaking) {
      unawaited(_speechOutput.stop());
      ref
          .read(ocrActionTriggerProvider.notifier)
          .trigger(OcrActionTrigger.pause);
      try {
        HapticFeedback.mediumImpact();
      } catch (_) {}
    } else {
      _announceAccessibility('Listening');
      try {
        HapticFeedback.selectionClick();
      } catch (_) {}
    }

    await _acknowledgeWakeAndListen(nextCmdSession);
  }

  Future<void> _handleTimeout() async {
    VoiceDiagnosticLogger.info('Command listening window timed out');
    if (state.isHandsFreeActive) {
      await _resumeListeningForCurrentSession();
    }
  }

  Future<void> _handleCommandTranscript(String transcript) async {
    final recognitionId =
        'rec_${++_eventCounter}_${DateTime.now().millisecondsSinceEpoch}';

    final event = VoiceRecognitionEvent(
      recognitionId: recognitionId,
      recognizerSessionId: state.recognizerSessionId,
      commandSessionId: state.commandSessionId,
      contextGeneration: state.contextGeneration,
      transcript: transcript,
      timestamp: DateTime.now(),
      isFinal: true,
    );

    VoiceDiagnosticLogger.asrEvent(event);

    if (_ttsEchoGuard.isSelfEcho(transcript)) {
      VoiceDiagnosticLogger.info('Discarding transcript due to TTS echo');
      await _resumeListeningForCurrentSession();
      return;
    }

    // 1. Resolve intent
    var command = _resolver.resolve(
      transcript,
      context: state.activeContext,
      isBargeIn: _ttsEchoGuard.isSpeaking,
    );

    if (command.isUnrecognized &&
        !_smartAiButtonMode &&
        state.activeContext == VoiceFeatureContext.smartAi &&
        _looksLikeIntentionalConversation(transcript)) {
      await _submitSmartAiConversation(transcript);
      return;
    }

    // If we're in a focused feature context (mobile detection or reader), be conservative:
    // accept only contextual commands and a small set of navigation/silence intents
    bool isAllowedInCurrentContext(VoiceCommand cmd) {
      final intent = cmd.intent;
      final ctx = state.activeContext;

      // Always allow navigation back and dismiss intents
      if (intent is NavigateBack ||
          intent is DismissAssistant ||
          intent is Silence) {
        return true;
      }

      // Protect mobile detection from noisy false-stops while still allowing
      // the rest of the deterministic app-control registry during an active
      // foreground session.
      if (ctx == VoiceFeatureContext.mobileDetection) {
        const highConfidence = 0.7;
        if (intent is StopMobileDetection ||
            intent is PauseMobileDetection ||
            intent is ResumeMobileDetection) {
          return cmd.matchScore >= highConfidence;
        }
      }

      // Scanner capture and reading accept explicit scan/rescan phrases with
      // moderate confidence. VoiceActionRegistry remains the authority for
      // every other context-specific scanner command.
      if (ctx.isScanner) {
        if (intent is ScanDocument || intent is RescanDocument) {
          return cmd.matchScore >= 0.35;
        }
      }

      return true; // default allow in other contexts
    }

    // If the resolver returned a command that is not allowed in the current
    // focused context, silently continue the current listening mode.
    if (!isAllowedInCurrentContext(command)) {
      VoiceDiagnosticLogger.info(
        'Ignored out-of-context command in ${state.activeContext.label}: ${command.intent.runtimeType}',
      );
      if (state.isHandsFreeActive) {
        await _resumeListeningForCurrentSession();
      }
      return;
    }

    // Intercept confirmation logic
    if (state.pendingConfirmationCommand != null) {
      if (command.intent is ConfirmYes) {
        command = state.pendingConfirmationCommand!;
      }
      // Regardless of yes, no, or a new command entirely, the confirmation window closes
      state = state.copyWith(clearPendingConfirmation: true);
    }

    VoiceDiagnosticLogger.resolved(command);

    // 2. Authorize command
    final auth = _authorizer.authorize(
      event: event,
      command: command,
      activeContext: state.activeContext,
      currentRecognizerSessionId: state.recognizerSessionId,
      currentCommandSessionId: state.commandSessionId,
      currentContextGeneration: state.contextGeneration,
    );

    if (!auth.isAllowed) {
      final reason = auth.rejection!;
      VoiceDiagnosticLogger.rejected(command, reason);

      final wasCommandListening =
          state.runtimeState == VoiceRuntimeState.commandListening;

      // If user explicitly woke assistant and recognition was low, permit exactly ONE retry prompt
      if (wasCommandListening &&
          _retryAttempts == 0 &&
          (reason == VoiceRejectionReason.lowMatch ||
              reason == VoiceRejectionReason.emptyOrNonsense)) {
        _retryAttempts++;
        state = state.copyWith(
          lastResolvedCommand: command,
          lastRejectionReason: reason,
          statusMessage: 'Please repeat.',
        );
        // In focused feature contexts (mobileDetection / scannerReading) avoid noisy retry TTS;
        // silently resume listening once instead of speaking "Please repeat." which can echo.
        if (state.activeContext == VoiceFeatureContext.mobileDetection ||
            state.activeContext == VoiceFeatureContext.scannerReading) {
          if (state.isHandsFreeActive) {
            await _resumeListeningForCurrentSession();
          }
        } else {
          await speakFeedback('Please repeat.');
        }
        return;
      }

      _retryAttempts = 0;
      state = state.copyWith(
        lastResolvedCommand: command,
        lastRejectionReason: reason,
        statusMessage: reason.userMessage.isNotEmpty && !reason.isSilent
            ? reason.userMessage
            : state.statusMessage,
      );

      if (!reason.isSilent && reason.userMessage.isNotEmpty) {
        await speakFeedback(reason.userMessage);
      } else {
        if (state.isHandsFreeActive) {
          await _resumeListeningForCurrentSession();
        }
      }
      return;
    }

    _retryAttempts = 0;

    // 3. Authorized — execute
    VoiceDiagnosticLogger.authorized(command);
    _transitionTo(VoiceRuntimeState.executing);

    state = state.copyWith(
      lastResolvedCommand: command,
      clearRejection: true,
      statusMessage: 'Executing ${command.intent.runtimeType}…',
    );

    final contextBeforeCommand = state.activeContext;
    final result = await _executeWithProgress(command);
    VoiceDiagnosticLogger.consumed(recognitionId);
    _applySessionExitIfNeeded(command, contextBeforeCommand);
    _syncAssistantContextAfterCommand(command, result, contextBeforeCommand);

    state = state.copyWith(
      lastResult: result,
      pendingConfirmationCommand: result is VoiceCommandNeedsConfirmation
          ? command
          : null,
      clearPendingConfirmation: result is! VoiceCommandNeedsConfirmation,
    );

    // 4. Handle result feedback
    final feedback = switch (result) {
      VoiceCommandSuccess(:final feedbackText) => feedbackText,
      VoiceCommandAlreadyInState(:final message) => message,
      VoiceCommandUnavailable(:final reason) => reason,
      VoiceCommandInvalidState(:final reason) => reason,
      VoiceCommandNeedsConfirmation(:final prompt) => prompt,
      VoiceCommandFailure(:final message) => message,
      _ => null,
    };

    if (feedback != null && feedback.isNotEmpty) {
      await speakFeedback(feedback);
    } else {
      if (state.isHandsFreeActive) {
        await _resumeListeningForCurrentSession();
      } else {
        _transitionTo(VoiceRuntimeState.disabled);
      }
    }
  }

  Future<VoiceCommandResult> _executeWithProgress(VoiceCommand command) async {
    _commandInProgress = true;
    try {
      if (_smartAiButtonMode &&
          state.activeContext == VoiceFeatureContext.smartAi) {
        // Finish reply cancellation and restore its voice before local feedback.
        await _prepareSmartAiControl?.call();
      }
      return await _executor.execute(
        command,
        onProgress: (message) async {
          if (!ref.mounted) return;
          state = state.copyWith(statusMessage: message);
          await speakFeedback(message, resumeListening: false);
        },
      );
    } finally {
      _commandInProgress = false;
    }
  }

  Future<void> _recoverRecognizer() {
    final pending = _recoveryOperation;
    if (pending != null) return pending;
    if (!ref.mounted || !state.isHandsFreeActive || _voiceSuspended) {
      return Future<void>.value();
    }
    final operation = _restoreRecognizer();
    _recoveryOperation = operation;
    return operation.whenComplete(() {
      if (identical(_recoveryOperation, operation)) _recoveryOperation = null;
    });
  }

  Future<void> _restoreRecognizer() async {
    final generation = _listenerGeneration;
    bool current() =>
        ref.mounted &&
        !_voiceSuspended &&
        state.isHandsFreeActive &&
        _listenerGeneration == generation;
    _recognizerNeedsRecovery = false;
    _transitionTo(VoiceRuntimeState.recovering);
    state = state.copyWith(statusMessage: 'Restoring voice listening…');
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _speechRecognizer.stopHandsFree().timeout(
          const Duration(seconds: 3),
        );
        await Future<void>.delayed(Duration(milliseconds: 150 * (attempt + 1)));
        if (!current()) return;
        await _speechRecognizer.setRecognitionProfile(
          _profileFor(state.activeContext),
        );
        await _speechRecognizer
            .startHandsFree(locale: 'en-US')
            .timeout(const Duration(seconds: 12));
        if (!current()) {
          await _speechRecognizer.stopHandsFree();
          return;
        }
        await _speechRecognizer.resumeHandsFree(
          acceptNextCommand: _shouldContinueCommandSession,
        );
        if (!current()) {
          await _speechRecognizer.pauseHandsFree();
          return;
        }
        _recognizerNeedsRecovery = false;
        state = state.copyWith(
          recognizerSessionId: state.recognizerSessionId + 1,
          statusMessage: _shouldContinueCommandSession
              ? _activeSessionStatus
              : _wakeListeningStatus,
        );
        _transitionTo(
          _shouldContinueCommandSession
              ? VoiceRuntimeState.commandListening
              : VoiceRuntimeState.wakeListening,
        );
        await _signalListeningReady();
        return;
      } catch (error) {
        VoiceDiagnosticLogger.error(
          'Offline microphone recovery failed',
          error,
        );
        if (!current()) return;
      }
    }
    await _speechRecognizer.stopHandsFree();
    if (!current()) return;
    _recognizerNeedsRecovery = false;
    state = state.copyWith(
      isHandsFreeActive: false,
      statusMessage:
          'Voice listening stopped. Turn Hands-free off and on in Settings, or use the screen buttons.',
    );
    _transitionTo(VoiceRuntimeState.error);
    _announceAccessibility(state.statusMessage);
  }

  Future<void> _acknowledgeWakeAndListen(int commandSession) async {
    if (!state.isHandsFreeActive) return;

    const acknowledgement = 'Listening.';
    final generation = state.ttsGeneration + 1;
    final utteranceId = 'wake_$generation';
    state = state.copyWith(ttsGeneration: generation);
    _transitionTo(VoiceRuntimeState.speaking);
    _ttsEchoGuard.onTtsStart(
      utteranceId: utteranceId,
      sentenceId: utteranceId,
      sentenceText: acknowledgement,
      generation: generation,
    );
    try {
      await _speechOutput.speak(acknowledgement);
    } catch (error) {
      VoiceDiagnosticLogger.error('Wake acknowledgement failed', error);
    } finally {
      _ttsEchoGuard.onTtsDone(utteranceId: utteranceId, generation: generation);
    }

    if (!state.isHandsFreeActive ||
        _voiceSuspended ||
        state.commandSessionId != commandSession ||
        state.ttsGeneration != generation) {
      return;
    }
    _transitionTo(VoiceRuntimeState.commandListening);
    await _resumeListeningForCurrentSession(signalReady: true);
  }

  bool _looksLikeIntentionalConversation(String transcript) {
    final words = transcript
        .toLowerCase()
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.length >= 2)
        .toList(growable: false);
    if (words.length < 2) return false;
    const lowInformationWords = {
      'the',
      'an',
      'is',
      'it',
      'to',
      'of',
      'and',
      'or',
      'uh',
      'um',
    };
    return words.any(
      (word) => word.length >= 3 && !lowInformationWords.contains(word),
    );
  }

  Future<void> _submitSmartAiConversation(String transcript) async {
    _transitionTo(VoiceRuntimeState.executing);
    state = state.copyWith(statusMessage: 'Smart AI is thinking…');

    final controller = ref.read(assistantSessionControllerProvider.notifier);
    await controller.sendConversationQuery(transcript);
    if (!ref.mounted) return;

    final assistantState = ref.read(assistantSessionControllerProvider);
    final error = assistantState.errorMessage;
    if (error != null && error.trim().isNotEmpty) {
      await speakFeedback(error);
      return;
    }
    if (assistantState.sessionState ==
        AssistantSessionState.laptopUnavailable) {
      await speakFeedback(
        'Smart AI is unavailable. App controls still work offline.',
      );
      return;
    }

    if (state.isHandsFreeActive) {
      state = state.copyWith(
        statusMessage: 'Listening for your next question…',
      );
      _transitionTo(VoiceRuntimeState.commandListening);
    }
  }

  void _syncAssistantContextAfterCommand(
    VoiceCommand command,
    VoiceCommandResult result,
    VoiceFeatureContext contextBeforeCommand,
  ) {
    if (result is! VoiceCommandSuccess) return;
    _syncVisibleContext();
    if (command.intent is NavigateSmartAi) {
      setFeatureContext(VoiceFeatureContext.smartAi);
    } else if (command.intent is DismissAssistant &&
        contextBeforeCommand == VoiceFeatureContext.smartAi) {
      setFeatureContext(VoiceFeatureContext.unknown);
    }
  }

  void _applySessionExitIfNeeded(
    VoiceCommand command,
    VoiceFeatureContext contextBeforeCommand,
  ) {
    final isGoodbye =
        command.intent is Goodbye || command.intent is DismissAssistant;
    if (isGoodbye && contextBeforeCommand != VoiceFeatureContext.smartAi) {
      _readerCommandsDismissed = true;
      state = state.copyWith(
        isCommandSessionActive: false,
        statusMessage: _wakeListeningStatus,
      );
    }
  }

  bool get _shouldContinueCommandSession =>
      state.isCommandSessionActive ||
      (!_smartAiButtonMode &&
          state.activeContext == VoiceFeatureContext.smartAi);

  String get _activeSessionStatus =>
      state.activeContext == VoiceFeatureContext.smartAi
      ? (_smartAiButtonMode
            ? 'Vision AI is listening for app commands. Hold the circle to ask Smart AI.'
            : 'Listening for your next question…')
      : state.activeContext.isScanner
      ? 'Listening for scanner commands…'
      : 'Listening for your next command…';

  static const _wakeListeningStatus =
      'Say "Hey Vision AI", "Hi Vision AI", or "Listen Vision AI".';

  Future<void> _resumeListeningForCurrentSession({
    bool signalReady = false,
  }) async {
    if (!ref.mounted || !state.isHandsFreeActive || _voiceSuspended) return;
    if (_recognizerNeedsRecovery) {
      await _recoverRecognizer();
      return;
    }
    final continueCommandSession = _shouldContinueCommandSession;
    final generation = _listenerGeneration;
    try {
      await _speechRecognizer.resumeHandsFree(
        acceptNextCommand: continueCommandSession,
      );
    } catch (error) {
      VoiceDiagnosticLogger.error('Offline microphone resume failed', error);
      await _recoverRecognizer();
      return;
    }
    if (!ref.mounted ||
        _voiceSuspended ||
        !state.isHandsFreeActive ||
        generation != _listenerGeneration) {
      return;
    }
    state = state.copyWith(
      statusMessage: continueCommandSession
          ? _activeSessionStatus
          : _wakeListeningStatus,
    );
    _transitionTo(
      continueCommandSession
          ? VoiceRuntimeState.commandListening
          : VoiceRuntimeState.wakeListening,
    );
    if (signalReady) await _signalListeningReady();
  }

  Future<void> _signalListeningReady() async {
    if (!ref.mounted ||
        _voiceSuspended ||
        _smartAiButtonMode ||
        _readerPlaybackActive ||
        state.runtimeState != VoiceRuntimeState.commandListening) {
      return;
    }
    final recognizer = _speechRecognizer;
    if (recognizer is! VoiceListeningFeedback) return;
    try {
      await (recognizer as VoiceListeningFeedback)
          .playListeningReadyCue()
          .timeout(const Duration(milliseconds: 500));
    } catch (error) {
      VoiceDiagnosticLogger.error('Listening feedback unavailable', error);
    }
  }

  // ─────────────────── Helpers ─────────────────────────────────

  void _transitionTo(VoiceRuntimeState newState) {
    if (!ref.mounted) return;
    if (state.runtimeState == newState) return;
    final oldState = state.runtimeState;
    VoiceDiagnosticLogger.stateTransition(oldState, newState);
    state = state.copyWith(runtimeState: newState);
  }

  void _announceAccessibility(String message) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view != null && message.isNotEmpty) {
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    }
  }

  void _setupLifecycle() {
    _lifecycleListener = AppLifecycleListener(
      onPause: () {
        VoiceDiagnosticLogger.info('App paused — suspending voice');
        unawaited(pauseVoice());
      },
      onResume: () {
        VoiceDiagnosticLogger.info('App resumed — syncing voice');
        final wasSuspended = _voiceSuspended;
        _voiceSuspended = false;
        unawaited(_restoreForegroundVoice(wasSuspended));
      },
      onDetach: () {
        VoiceDiagnosticLogger.info('App detached — stopping voice');
        unawaited(stopHandsFree());
      },
    );
  }

  Future<void> _restoreForegroundVoice(bool wasSuspended) async {
    final generation = _listenerGeneration;
    // Permission dialogs can resume the Activity before the old start finishes.
    // Let that cancelled start settle before opening exactly one replacement.
    await _startOperation;
    await _recoveryOperation;
    if (!ref.mounted || _voiceSuspended || generation != _listenerGeneration) {
      return;
    }
    final enabled = ref
        .read(appSettingsControllerProvider)
        .handsFreeAssistantEnabled;
    if (enabled && !state.isHandsFreeActive) {
      await startHandsFree();
    } else if (state.isHandsFreeActive &&
        (wasSuspended ||
            state.runtimeState == VoiceRuntimeState.suspended ||
            state.runtimeState == VoiceRuntimeState.recovering)) {
      await _resumeListeningForCurrentSession(signalReady: true);
    }
  }

  void _cleanup() {
    _listenerGeneration++;
    _voiceSuspended = true;
    appRouteObserver.removeListener(_syncVisibleContext);
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _handsFreeSub?.cancel();
    _handsFreeSub = null;
    unawaited(_speechRecognizer.stopHandsFree());
  }
}
