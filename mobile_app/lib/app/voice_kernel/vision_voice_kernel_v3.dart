import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_command_result.dart';
import '../../domain/entities/voice_recognition_event.dart';
import '../../domain/enums/voice_feature_context.dart';
import '../../domain/enums/voice_intent.dart';
import '../../domain/enums/voice_rejection_reason.dart';
import '../../domain/enums/voice_runtime_state.dart';
import '../../domain/services/intelligent_intent_resolver.dart';
import '../../domain/services/on_device_speech_recognition_service.dart';
import '../../domain/services/speech_output_service.dart';
import '../../domain/services/tts_echo_guard.dart';
import '../assistant_providers.dart';
import '../providers.dart';
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
    String? statusMessage,
    bool clearCommand = false,
    bool clearRejection = false,
    bool clearResult = false,
    bool clearPendingConfirmation = false,
  }) =>
      VoiceKernelState(
        runtimeState: runtimeState ?? this.runtimeState,
        activeContext: activeContext ?? this.activeContext,
        recognizerSessionId:
            recognizerSessionId ?? this.recognizerSessionId,
        commandSessionId: commandSessionId ?? this.commandSessionId,
        contextGeneration: contextGeneration ?? this.contextGeneration,
        ttsGeneration: ttsGeneration ?? this.ttsGeneration,
        lastResolvedCommand:
            clearCommand ? null : (lastResolvedCommand ?? this.lastResolvedCommand),
        pendingConfirmationCommand:
            clearPendingConfirmation ? null : (pendingConfirmationCommand ?? this.pendingConfirmationCommand),
        lastRejectionReason:
            clearRejection
                ? null
                : (lastRejectionReason ?? this.lastRejectionReason),
        lastResult: clearResult ? null : (lastResult ?? this.lastResult),
        isHandsFreeActive: isHandsFreeActive ?? this.isHandsFreeActive,
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

    final handsFreeEnabled =
        ref.read(appSettingsControllerProvider).handsFreeAssistantEnabled;
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
    if (state.activeContext == newContext) return;

    final oldContext = state.activeContext;
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
  }

  /// Starts the hands-free wake-word recognition loop.
  Future<void> startHandsFree() async {
    final permissionService = ref.read(microphonePermissionServiceProvider);
    var permission = await permissionService.checkPermission();
    if (!permission.isGranted) {
      permission = await permissionService.requestPermission();
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
      final nextRecSession = state.recognizerSessionId + 1;
      state = state.copyWith(
        recognizerSessionId: nextRecSession,
        isHandsFreeActive: true,
        statusMessage: 'Listening for "Vision" wake word.',
      );

      VoiceDiagnosticLogger.sessionInfo(
        recognizerSession: nextRecSession,
        commandSession: state.commandSessionId,
        context: state.activeContext,
      );

      await _speechRecognizer.startHandsFree(locale: 'en-US');
      _transitionTo(VoiceRuntimeState.wakeListening);
    } catch (e) {
      VoiceDiagnosticLogger.error('Failed to start hands-free', e);
      _transitionTo(VoiceRuntimeState.error);
      state = state.copyWith(
        isHandsFreeActive: false,
        statusMessage: 'Could not start offline voice listener.',
      );
    }
  }

  /// Stops hands-free recognition and releases resources.
  Future<void> stopHandsFree() async {
    _transitionTo(VoiceRuntimeState.disabled);
    state = state.copyWith(
      isHandsFreeActive: false,
      statusMessage: 'Voice assistant is off.',
    );
    try {
      await _speechRecognizer.stopHandsFree();
    } catch (_) {}
  }

  /// Pauses voice recognition (e.g. during phone call or app background).
  Future<void> pauseVoice() async {
    if (!state.runtimeState.isListening) return;
    _transitionTo(VoiceRuntimeState.suspended);
    try {
      await _speechRecognizer.pauseHandsFree();
    } catch (_) {}
  }

  /// Resumes voice recognition after pause.
  Future<void> resumeVoice() async {
    if (state.runtimeState != VoiceRuntimeState.suspended) return;
    try {
      await _speechRecognizer.resumeHandsFree(acceptNextCommand: false);
      _transitionTo(VoiceRuntimeState.wakeListening);
    } catch (e) {
      VoiceDiagnosticLogger.error('Failed to resume voice', e);
      _transitionTo(VoiceRuntimeState.error);
    }
  }

  /// Speaks feedback text aloud and manages TTS echo guard.
  Future<void> speakFeedback(String text) async {
    if (text.isEmpty) return;

    final nextTtsGen = state.ttsGeneration + 1;
    state = state.copyWith(ttsGeneration: nextTtsGen);

    _transitionTo(VoiceRuntimeState.speaking);
    final utteranceId = 'voice_feedback_${DateTime.now().millisecondsSinceEpoch}';

    _ttsEchoGuard.onTtsStart(
      utteranceId: utteranceId,
      sentenceId: utteranceId,
      sentenceText: text,
      generation: nextTtsGen,
    );

    try {
      // Pause mic while speaking unless barge-in is enabled
      await _speechRecognizer.pauseHandsFree();
      await _speechOutput.speak(text);
    } catch (e) {
      VoiceDiagnosticLogger.error('TTS feedback failed', e);
    }

    _ttsEchoGuard.onTtsDone(utteranceId: utteranceId, generation: nextTtsGen);
      
    // Async gap: verify this TTS generation was not superseded
    if (state.ttsGeneration != nextTtsGen) return;

    if (state.isHandsFreeActive) {
      await _speechRecognizer.resumeHandsFree(acceptNextCommand: false);
      _transitionTo(VoiceRuntimeState.wakeListening);
    } else {
      _transitionTo(VoiceRuntimeState.disabled);
    }
  }

  /// Silences all active speech immediately.
  Future<void> stopSpeaking() async {
    _ttsEchoGuard.onTtsStop();
    try {
      await _speechOutput.stop();
    } catch (_) {}
    if (state.isHandsFreeActive) {
      _transitionTo(VoiceRuntimeState.wakeListening);
    }
  }

  // ─────────────────── Event Pipeline ──────────────────────────
  
  /// Processes a manually submitted text transcript (e.g. from push-to-talk).
  /// Returns the feedback text if the kernel executed a local app-control command,
  /// or null if it was unrecognized.
  Future<String?> processManualCommand(String transcript) async {
    if (!ref.mounted) return null;

    // Resolve intent based on current context
    final command = _resolver.resolve(
      transcript,
      context: state.activeContext,
    );
    
    VoiceDiagnosticLogger.resolved(command);

    if (command.isUnrecognized) {
      return null; // Fallback to Smart AI or ignore
    }

    final currentGen = state.contextGeneration;
    final result = await _executor.execute(command);
    
    // Async gap: ensure the user hasn't changed screens
    if (state.contextGeneration != currentGen) return null;
    
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
      },
    );
  }

  void _handleNativeEvent(HandsFreeSpeechEvent event) {
    switch (event.type) {
      case HandsFreeSpeechEventType.wake:
        unawaited(_handleWake());
      case HandsFreeSpeechEventType.command:
        if (event.transcript != null) {
          unawaited(_handleCommandTranscript(event.transcript!));
        }
      case HandsFreeSpeechEventType.timeout:
        unawaited(_handleTimeout());
      case HandsFreeSpeechEventType.error:
        VoiceDiagnosticLogger.error('Native recognition error event received');
        unawaited(_recoverRecognizer());
    }
  }

  int _retryAttempts = 0;

  Future<void> _handleWake() async {
    VoiceDiagnosticLogger.wakeDetected();
    final nextCmdSession = state.commandSessionId + 1;
    _retryAttempts = 0;
    state = state.copyWith(
      commandSessionId: nextCmdSession,
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
    }

    if (state.isHandsFreeActive) {
      await _speechRecognizer.resumeHandsFree(acceptNextCommand: true);
    }
  }

  Future<void> _handleTimeout() async {
    VoiceDiagnosticLogger.info('Command listening window timed out');
    state = state.copyWith(
      statusMessage: 'Listening for "Vision" wake word.',
    );
    if (state.isHandsFreeActive) {
      await _speechRecognizer.resumeHandsFree(acceptNextCommand: false);
      _transitionTo(VoiceRuntimeState.wakeListening);
    }
  }

  Future<void> _handleCommandTranscript(String transcript) async {
    final recognitionId = 'rec_${++_eventCounter}_${DateTime.now().millisecondsSinceEpoch}';

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

    // 1. Resolve intent
    var command = _resolver.resolve(
      transcript,
      context: state.activeContext,
    );
    
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
        await speakFeedback('Please repeat.');
        if (state.isHandsFreeActive) {
          await _speechRecognizer.resumeHandsFree(acceptNextCommand: true);
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
        // Return to wake listening cleanly
        if (state.isHandsFreeActive) {
          await _speechRecognizer.resumeHandsFree(acceptNextCommand: false);
          _transitionTo(VoiceRuntimeState.wakeListening);
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

    final result = await _executor.execute(command);
    VoiceDiagnosticLogger.consumed(recognitionId);

    // Async gap: ensure the user hasn't triggered another session or exited
    if (state.commandSessionId != event.commandSessionId) return;

    state = state.copyWith(
      lastResult: result,
      pendingConfirmationCommand: result is VoiceCommandNeedsConfirmation ? command : null,
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
        await _speechRecognizer.resumeHandsFree(acceptNextCommand: false);
        _transitionTo(VoiceRuntimeState.wakeListening);
      } else {
        _transitionTo(VoiceRuntimeState.disabled);
      }
    }
  }

  Future<void> _recoverRecognizer() async {
    _transitionTo(VoiceRuntimeState.recovering);
    try {
      await _speechRecognizer.stopHandsFree();
      await Future<void>.delayed(const Duration(milliseconds: 500));
      if (state.isHandsFreeActive) {
        await startHandsFree();
      }
    } catch (e) {
      VoiceDiagnosticLogger.error('Recognizer recovery failed', e);
      _transitionTo(VoiceRuntimeState.error);
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
        final handsFreeEnabled = ref
            .read(appSettingsControllerProvider)
            .handsFreeAssistantEnabled;
        if (handsFreeEnabled && !state.isHandsFreeActive) {
          unawaited(startHandsFree());
        } else if (state.runtimeState == VoiceRuntimeState.suspended) {
          unawaited(resumeVoice());
        }
      },
      onDetach: () {
        VoiceDiagnosticLogger.info('App detached — stopping voice');
        unawaited(stopHandsFree());
      },
    );
  }

  void _cleanup() {
    _lifecycleListener?.dispose();
    _lifecycleListener = null;
    _handsFreeSub?.cancel();
    _handsFreeSub = null;
  }
}
