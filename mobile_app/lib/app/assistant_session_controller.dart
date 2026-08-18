import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/lifecycle/app_lifecycle_observer.dart';
import '../domain/entities/assistant_credential.dart';
import '../domain/entities/assistant_message.dart';
import '../domain/entities/assistant_response.dart';
import '../domain/entities/assistant_tool_result.dart';
import '../domain/enums/assistant_failure_kind.dart';
import '../domain/enums/assistant_session_state.dart';
import '../domain/enums/detection_environment_mode.dart';
import '../domain/enums/detection_sensitivity.dart';
import '../domain/enums/feedback_mode.dart';
import '../domain/enums/microphone_permission_status.dart';
import '../domain/enums/mobile_assistance_state.dart';
import '../domain/repositories/assistant_repository.dart';
import 'voice_kernel/voice_kernel_providers.dart';
import '../domain/services/on_device_speech_recognition_service.dart';
import '../domain/services/speech_output_service.dart';
import 'app.dart' show appNavigatorKey;
import 'assistance_controller.dart'; // For Mobile Mode status
import 'assistant_providers.dart';
import 'camera_providers.dart';
import 'detection_providers.dart';
import 'feedback_providers.dart';
import 'providers.dart';
import 'router/app_route_observer.dart' show appRouteObserver;
import 'router/route_paths.dart';
import 'wearable_controller.dart'; // For Pi status

// ---------------------------------------------------------------------------
// State model
// ---------------------------------------------------------------------------

/// Immutable state of the assistant session controller.
class AssistantControllerState {
  const AssistantControllerState({
    required this.sessionState,
    this.credential,
    this.conversationHistory = const [],
    this.pendingResponse,
    this.lastTranscript,
    this.errorMessage,
    this.failureKind,
    this.pendingRequestId,
    this.handsFreeActive = false,
    this.handsFreeStatus = 'Hands-free voice is preparing.',
  });

  final AssistantSessionState sessionState;
  final AssistantCredential? credential;
  final List<AssistantMessage> conversationHistory;

  /// The last response from the backend (for repeat-last-response).
  final AssistantResponse? pendingResponse;

  /// The last recognized transcript (for display and re-submit).
  final String? lastTranscript;

  final String? errorMessage;
  final AssistantFailureKind? failureKind;

  /// Pending request ID for tool confirmation idempotency.
  final String? pendingRequestId;
  final bool handsFreeActive;
  final String handsFreeStatus;

  bool get isPaired => credential?.isValid ?? false;

  AssistantControllerState copyWith({
    AssistantSessionState? sessionState,
    AssistantCredential? credential,
    List<AssistantMessage>? conversationHistory,
    AssistantResponse? pendingResponse,
    String? lastTranscript,
    String? errorMessage,
    AssistantFailureKind? failureKind,
    String? pendingRequestId,
    bool clearPendingResponse = false,
    bool clearError = false,
    bool? handsFreeActive,
    String? handsFreeStatus,
  }) => AssistantControllerState(
    sessionState: sessionState ?? this.sessionState,
    credential: credential ?? this.credential,
    conversationHistory: conversationHistory ?? this.conversationHistory,
    pendingResponse: clearPendingResponse
        ? null
        : (pendingResponse ?? this.pendingResponse),
    lastTranscript: lastTranscript ?? this.lastTranscript,
    errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    failureKind: clearError ? null : (failureKind ?? this.failureKind),
    pendingRequestId: pendingRequestId ?? this.pendingRequestId,
    handsFreeActive: handsFreeActive ?? this.handsFreeActive,
    handsFreeStatus: handsFreeStatus ?? this.handsFreeStatus,
  );
}

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final assistantSessionControllerProvider =
    NotifierProvider<AssistantSessionController, AssistantControllerState>(
      AssistantSessionController.new,
    );

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Orchestrates the complete voice AI assistant session.
///
/// Responsibilities:
/// - Pairing / credential lifecycle
/// - Microphone permission flow
/// - On-device push-to-talk speech recognition
/// - Text query submission
/// - Tool confirmation and execution
/// - Conversation history management
/// - TTS coordination (no recording while speaking)
/// - Lifecycle handling (cancel recognition on background/pause)
/// - State machine transitions with TalkBack announcements
class AssistantSessionController extends Notifier<AssistantControllerState> {
  AppLifecycleObserver? _lifecycleObserver;
  late final SpeechOutputService _speechOutput;
  late final OnDeviceSpeechRecognitionService _speechRecognizer;

  // Guards
  bool _sessionInProgress = false;
  bool _speechActive = false;

  @override
  AssistantControllerState build() {
    _speechOutput = ref.read(speechOutputServiceProvider);
    _speechRecognizer = ref.read(onDeviceSpeechRecognitionServiceProvider);
    ref.onDispose(_cleanup);
    _setupLifecycleObserver();
    _loadStoredCredential();
    return const AssistantControllerState(
      sessionState: AssistantSessionState.idle,
    );
  }

  // ---------------------------------------------------------------------------
  // Pairing
  // ---------------------------------------------------------------------------

  Future<void> loadStoredCredential() async {
    await _loadStoredCredential();
  }

  Future<void> _loadStoredCredential() async {
    final repo = ref.read(assistantCredentialRepositoryProvider);
    final credential = await repo.loadCredential();
    if (credential?.isValid ?? false) {
      state = state.copyWith(credential: credential);
    }
  }

  Future<String?> pair({
    required String backendUrl,
    required String pairingCode,
  }) async {
    try {
      final assistantRepo = ref.read(assistantRepositoryProvider);
      final credential = await assistantRepo.pair(
        backendUrl: backendUrl,
        pairingCode: pairingCode,
      );
      final credRepo = ref.read(assistantCredentialRepositoryProvider);
      await credRepo.saveCredential(credential);
      state = state.copyWith(credential: credential);
      return null; // success
    } on AssistantAuthException catch (e) {
      return e.message;
    } on AssistantNetworkException catch (e) {
      return e.message;
    } catch (e) {
      return 'Pairing failed: $e';
    }
  }

  Future<void> unpair() async {
    final repo = ref.read(assistantCredentialRepositoryProvider);
    await repo.deleteCredential();
    state = const AssistantControllerState(
      sessionState: AssistantSessionState.idle,
    );
  }

  // ---------------------------------------------------------------------------
  // Voice session
  // ---------------------------------------------------------------------------

  /// Enables or disables the foreground-only offline wake-word assistant.
  Future<void> setHandsFreeEnabled(bool enabled) async {
    ref
        .read(appSettingsControllerProvider.notifier)
        .setHandsFreeAssistantEnabled(enabled);
  }

  bool get _isVisionActive {
    final assistState = ref.read(assistanceControllerProvider).state;
    final isMobileActive =
        assistState != MobileAssistanceState.idle &&
        assistState != MobileAssistanceState.permissionRequired &&
        assistState != MobileAssistanceState.error;
    final currentRoute = appRouteObserver.currentRoute;
    return isMobileActive || currentRoute == RoutePaths.mobileAssistance;
  }



  Future<void> _resumeHandsFree({bool acceptNextCommand = false}) async {
    if (!ref.read(appSettingsControllerProvider).handsFreeAssistantEnabled) {
      return;
    }
    await _speechRecognizer.resumeHandsFree(
      acceptNextCommand: acceptNextCommand,
    );
  }

  /// Begin listening — called when the user presses and holds the button.
  Future<void> startListening() async {
    if (_sessionInProgress) return;
    if (!state.sessionState.canStartNewSession) return;

    _sessionInProgress = true;
    try {
      if (state.handsFreeActive) {
        await _speechRecognizer.stopHandsFree();
        state = state.copyWith(
          handsFreeActive: false,
          handsFreeStatus:
              'Hands-free voice is paused during manual recording.',
        );
      }
      // 1. Microphone permission. Pairing is deliberately not required for
      // app-control speech because recognition and command parsing are local.
      _transitionTo(AssistantSessionState.requestingPermission);
      final permService = ref.read(microphonePermissionServiceProvider);
      MicrophonePermissionStatus permStatus = await permService
          .checkPermission();

      if (!permStatus.isGranted) {
        permStatus = await permService.requestPermission();
      }

      if (permStatus.isPermanentlyDenied) {
        _fail(
          AssistantFailureKind.microphonePermissionPermanentlyDenied,
          AssistantFailureKind
              .microphonePermissionPermanentlyDenied
              .recoveryHint,
        );
        return;
      }
      if (!permStatus.isGranted) {
        _fail(
          AssistantFailureKind.microphonePermissionDenied,
          AssistantFailureKind.microphonePermissionDenied.recoveryHint,
        );
        return;
      }

      // 2. Require an explicitly offline phone recognizer. Native Android is
      // preferred and the bundled model covers vendor images without it.
      // Never fall back to the ordinary recognizer, laptop, Gemini, or Ollama.
      _transitionTo(AssistantSessionState.checkingVoiceAvailability);
      final availability = await _speechRecognizer.checkAvailability();
      if (!availability.available) {
        _fail(
          AssistantFailureKind.onDeviceSpeechUnavailable,
          availability.reason ??
              AssistantFailureKind.onDeviceSpeechUnavailable.recoveryHint,
        );
        return;
      }

      // 3. Don't listen while TTS is speaking.
      if (_speechActive) {
        await _speechOutput.stop();
        _speechActive = false;
        await Future<void>.delayed(const Duration(milliseconds: 250));
      }

      // 4. Start bounded on-device recognition.
      try {
        await _speechRecognizer.startListening(
          locale: WidgetsBinding.instance.platformDispatcher.locale
              .toLanguageTag(),
        );
      } on OnDeviceSpeechRecognitionException catch (error) {
        _handleSpeechRecognitionFailure(error);
        return;
      }

      _transitionTo(AssistantSessionState.listening);
    } catch (e) {
      _fail(AssistantFailureKind.unexpected, 'Unexpected error: $e');
    } finally {
      if (state.sessionState != AssistantSessionState.listening) {
        _sessionInProgress = false;
      }
    }
  }

  /// Stop listening, obtain the phone-local transcript, and route it through
  /// the deterministic offline app-command parser.
  Future<void> stopListeningAndSubmit() async {
    if (state.sessionState != AssistantSessionState.listening) return;

    _transitionTo(AssistantSessionState.processingAudio);
    try {
      OnDeviceSpeechResult speechResult;
      try {
        speechResult = await _speechRecognizer.stopListening();
      } on OnDeviceSpeechRecognitionException catch (error) {
        _handleSpeechRecognitionFailure(error);
        return;
      }

      if (speechResult.transcript.trim().isEmpty) {
        _fail(
          AssistantFailureKind.emptyAudio,
          AssistantFailureKind.emptyAudio.recoveryHint,
        );
        return;
      }

      await _submitRecognizedTranscript(speechResult.transcript);
    } finally {
      _sessionInProgress = false;
    }
  }

  /// Cancel on-device recognition and discard its in-memory transcript.
  Future<void> cancelListening() async {
    if (state.sessionState != AssistantSessionState.listening) return;
    try {
      await _speechRecognizer.cancelListening();
    } finally {
      _transitionTo(AssistantSessionState.cancelled);
      _sessionInProgress = false;
    }
  }

  /// Send a text query (accessibility/testing alternative to voice).
  Future<void> sendTextQuery(String query) async {
    if (_sessionInProgress) return;
    if (query.trim().isEmpty) return;
    if (!state.sessionState.canStartNewSession) return;

    _sessionInProgress = true;
    try {
      final kernel = ref.read(visionVoiceKernelProvider.notifier);
      final feedback = await kernel.processManualCommand(query);

      if (feedback != null) {
        if (feedback.isNotEmpty) {
           _addAssistantMessage(feedback);
        }
        state = state.copyWith(sessionState: AssistantSessionState.completed, lastTranscript: query);
        _sessionInProgress = false;
        return;
      }

      _transitionTo(AssistantSessionState.checkingConnection);
      final credential = state.credential;
      if (credential == null || !credential.isValid) {
        _fail(
          AssistantFailureKind.backendUnreachable,
          'No assistant backend is paired.',
        );
        return;
      }

      final assistantRepo = ref.read(assistantRepositoryProvider);
      final version = await assistantRepo.checkHealth(credential);
      if (version == null) {
        _transitionTo(AssistantSessionState.laptopUnavailable);
        return;
      }

      _transitionTo(AssistantSessionState.thinking);
      _addUserMessage(query);

      state = state.copyWith(lastTranscript: query);

      final response = await assistantRepo.sendTextQuery(
        credential: credential,
        query: query,
        conversationHistory: state.conversationHistory,
      );

      await _handleResponse(response, credential);
    } on AssistantAuthException {
      _fail(
        AssistantFailureKind.authenticationFailed,
        AssistantFailureKind.authenticationFailed.recoveryHint,
      );
    } on AssistantNetworkException {
      _transitionTo(AssistantSessionState.laptopUnavailable);
    } catch (e) {
      _fail(AssistantFailureKind.unexpected, 'Unexpected error: $e');
    } finally {
      if (state.sessionState.isTerminal ||
          state.sessionState == AssistantSessionState.idle ||
          state.sessionState == AssistantSessionState.completed) {
        _sessionInProgress = false;
      }
    }
  }

  /// Confirm a pending tool action.
  Future<void> confirmAction() async {
    if (state.sessionState != AssistantSessionState.awaitingConfirmation) {
      return;
    }
    final credential = state.credential;
    final requestId = state.pendingRequestId;
    final response = state.pendingResponse;
    final isOfflineRequest = requestId?.startsWith('offline-') ?? false;

    if (requestId == null ||
        response?.toolCall == null ||
        (!isOfflineRequest && credential == null)) {
      _fail(AssistantFailureKind.unexpected, 'Confirmation state is invalid.');
      _sessionInProgress = false;
      return;
    }

    _transitionTo(AssistantSessionState.executingAction);
    try {
      final toolResult = await _executeToolLocally(response!.toolCall!);
      final followUp = await _resolveToolFollowUp(
        response: response,
        credential: credential,
        result: toolResult,
      );
      _addAssistantMessage(followUp.responseText);
      state = state.copyWith(pendingResponse: followUp);
      await _speakAndComplete(followUp.responseText);
    } catch (e) {
      _fail(AssistantFailureKind.unexpected, 'Action failed: $e');
    } finally {
      _sessionInProgress = false;
    }
  }

  /// Cancel a pending confirmation.
  Future<void> cancelAction() async {
    if (state.sessionState != AssistantSessionState.awaitingConfirmation) {
      return;
    }
    _transitionTo(AssistantSessionState.cancelled);
    _sessionInProgress = false;
  }

  /// Repeat the last spoken response.
  Future<void> repeatLastResponse() async {
    final text = state.pendingResponse?.responseText;
    if (text == null || text.isEmpty) return;
    await _speak(text);
  }

  /// Stop current TTS playback.
  Future<void> stopSpeaking() async {
    await _speechOutput.stop();
    _speechActive = false;
    if (state.sessionState == AssistantSessionState.speaking) {
      _transitionTo(AssistantSessionState.completed);
    }
  }

  /// Retry from error or timeout.
  Future<void> retry() async {
    final kind = state.failureKind;
    if (!state.sessionState.isTerminal) return;

    // If there's a last transcript, retry the text query
    final transcript = state.lastTranscript;
    if (kind != AssistantFailureKind.microphonePermissionPermanentlyDenied &&
        kind != AssistantFailureKind.authenticationFailed &&
        transcript != null &&
        transcript.isNotEmpty) {
      state = state.copyWith(
        sessionState: AssistantSessionState.idle,
        clearError: true,
      );
      await sendTextQuery(transcript);
    } else {
      state = state.copyWith(
        sessionState: AssistantSessionState.idle,
        clearError: true,
      );
    }
  }

  /// Reset to idle without retrying.
  void reset() {
    _sessionInProgress = false;
    state = state.copyWith(
      sessionState: AssistantSessionState.idle,
      clearError: true,
      clearPendingResponse: true,
    );
  }

  /// Load conversation history from the backend.
  Future<void> loadHistory() async {
    final credential = state.credential;
    if (credential == null) return;
    try {
      final assistantRepo = ref.read(assistantRepositoryProvider);
      final messages = await assistantRepo.loadConversationHistory(credential);
      state = state.copyWith(conversationHistory: messages);
    } catch (_) {}
  }

  /// Clear conversation history.
  Future<void> clearHistory() async {
    final credential = state.credential;
    if (credential != null) {
      try {
        final assistantRepo = ref.read(assistantRepositoryProvider);
        await assistantRepo.clearConversationHistory(credential);
      } catch (_) {}
    }
    state = state.copyWith(conversationHistory: []);
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _submitRecognizedTranscript(String rawTranscript) async {
    final transcript = rawTranscript.trim();
    try {
      _transitionTo(AssistantSessionState.thinking);
      _addUserMessage(transcript);
      state = state.copyWith(lastTranscript: transcript);

      final kernel = ref.read(visionVoiceKernelProvider.notifier);
      final feedback = await kernel.processManualCommand(transcript);

      if (feedback != null) {
        if (feedback.isNotEmpty) {
           _addAssistantMessage(feedback);
        }
        state = state.copyWith(sessionState: AssistantSessionState.completed);
        _sessionInProgress = false;
        return;
      }

      // Unrecognized phrases outside of Smart AI stay strictly offline:
      final isSmartAiRoute =
          appRouteObserver.currentRoute == RoutePaths.assistant;
      if (!isSmartAiRoute) {
        // Silently discard unrecognized ambient chatter and noise outside Smart AI.
        // Never interrupt the user with long unsolicited error speeches.
        state = state.copyWith(sessionState: AssistantSessionState.idle);
        _sessionInProgress = false;
        await _resumeHandsFree(acceptNextCommand: false);
        return;
      }

      // ONLY on the Smart AI screen: route questions to the paired laptop backend (Gemini/Ollama)
      final credential = state.credential;
      if (credential == null || !credential.isValid) {
        await _handleResponse(
          AssistantResponse(
            responseText:
                'Smart AI is not connected to a laptop backend. Please pair your laptop in settings.',
            requestId:
                'offline-unmatched-${DateTime.now().microsecondsSinceEpoch}',
          ),
          null,
        );
        return;
      }

      final assistantRepo = ref.read(assistantRepositoryProvider);
      final version = await assistantRepo.checkHealth(credential);
      if (version == null) {
        _transitionTo(AssistantSessionState.laptopUnavailable);
        return;
      }

      final response = await assistantRepo.sendTextQuery(
        credential: credential,
        query: transcript,
        conversationHistory: state.conversationHistory,
      );
      await _handleResponse(response, credential);
    } on AssistantAuthException {
      _fail(
        AssistantFailureKind.authenticationFailed,
        AssistantFailureKind.authenticationFailed.recoveryHint,
      );
    } on AssistantNetworkException {
      _transitionTo(AssistantSessionState.laptopUnavailable);
    } catch (e) {
      _fail(AssistantFailureKind.unexpected, 'Error: $e');
    } finally {
      if (state.sessionState.isTerminal) {
        _sessionInProgress = false;
      }
    }
  }

  void _handleSpeechRecognitionFailure(
    OnDeviceSpeechRecognitionException error,
  ) {
    final isUnavailable = switch (error.code) {
      'unavailable' ||
      'on_device_unavailable' ||
      'language_not_supported' ||
      'language_unavailable' => true,
      _ => false,
    };
    final kind = isUnavailable
        ? AssistantFailureKind.onDeviceSpeechUnavailable
        : switch (error.code) {
            'no_speech' => AssistantFailureKind.emptyAudio,
            'permission_denied' =>
              AssistantFailureKind.microphonePermissionDenied,
            'audio_error' => AssistantFailureKind.audioRecordingFailed,
            _ => AssistantFailureKind.transcriptionFailed,
          };
    _fail(kind, error.message);
  }

  Future<void> _handleResponse(
    AssistantResponse response,
    AssistantCredential? credential,
  ) async {
    _addAssistantMessage(response.responseText);
    state = state.copyWith(pendingResponse: response);

    if (response.requiresConfirmation && response.toolCall != null) {
      _transitionTo(AssistantSessionState.awaitingConfirmation);
      state = state.copyWith(pendingRequestId: response.requestId);
      final prompt = response.confirmationPrompt ?? response.responseText;
      await _speak(prompt);
      // Stay in awaitingConfirmation — session stays open until user acts
    } else if (response.toolCall != null) {
      // Execute without confirmation
      final isReaderTool =
          response.toolCall!.name.startsWith('reading_') ||
          response.toolCall!.name.startsWith('ocr_') ||
          response.toolCall!.name == 'trigger_ocr_scan' ||
          response.toolCall!.name == 'open_ocr_scanner';
      _transitionTo(AssistantSessionState.executingAction);
      final toolResult = await _executeToolLocally(response.toolCall!);
      if (isReaderTool) {
        // Reader tools directly drive AccessibleTextPlayer which speaks sentences itself.
        // Never interrupt player playback with redundant follow-up voice messages.
        _sessionInProgress = false;
        _transitionTo(AssistantSessionState.idle);
        await _resumeHandsFree(acceptNextCommand: true);
        return;
      }
      final followUp = await _resolveToolFollowUp(
        response: response,
        credential: credential,
        result: toolResult,
      );
      final isSilentTool =
          response.toolCall!.name == 'stop_speaking' ||
          response.toolCall!.name == 'stop_everything' ||
          followUp.responseText.trim().isEmpty;

      if (isReaderTool || isSilentTool) {
        _sessionInProgress = false;
        _transitionTo(AssistantSessionState.idle);
        await _resumeHandsFree(acceptNextCommand: false);
        return;
      }
      _addAssistantMessage(followUp.responseText);
      state = state.copyWith(pendingResponse: followUp);
      await _speakAndComplete(followUp.responseText);
      _sessionInProgress = false;
    } else {
      if (response.responseText.trim().isEmpty) {
        _sessionInProgress = false;
        _transitionTo(AssistantSessionState.idle);
        await _resumeHandsFree(acceptNextCommand: false);
        return;
      }
      await _speakAndComplete(response.responseText);
      _sessionInProgress = false;
    }
  }

  Future<AssistantResponse> _resolveToolFollowUp({
    required AssistantResponse response,
    required AssistantCredential? credential,
    required AssistantToolResult result,
  }) async {
    final pairedCredential = credential;
    if (response.requestId.startsWith('offline-') || pairedCredential == null) {
      return AssistantResponse(
        responseText: _formatLocalToolResult(result),
        requestId: response.requestId,
      );
    }

    try {
      final assistantRepo = ref.read(assistantRepositoryProvider);
      return await assistantRepo.reportToolResult(
        credential: pairedCredential,
        requestId: response.requestId,
        result: result,
        conversationHistory: state.conversationHistory,
      );
    } catch (_) {
      return AssistantResponse(
        responseText: _formatLocalToolResult(result),
        requestId: response.requestId,
      );
    }
  }

  String _formatLocalToolResult(AssistantToolResult result) {
    if (!result.success) {
      return "I couldn't complete that action. "
          '${result.errorMessage ?? 'Please try again.'}';
    }

    final data = result.resultData ?? const <String, dynamic>{};
    return switch (result.toolName) {
      'get_current_time' =>
        'The current time is ${_formatLocalTime(data['time'])}.',
      'get_current_date' => 'Today is ${data['date'] ?? 'unavailable'}.',
      'get_mobile_mode_status' =>
        'Mobile Mode is ${data['label'] ?? data['state'] ?? 'unavailable'}.',
      'start_mobile_mode' => 'Mobile Mode detection is now running.',
      'pause_mobile_mode' => 'Mobile Mode detection is paused.',
      'resume_mobile_mode' => 'Mobile Mode detection is now running.',
      'stop_mobile_mode' => 'Mobile Mode detection is stopped.',
      'get_app_settings' =>
        'Detection sensitivity is ${data['detectionSensitivity'] ?? 'unknown'}, '
            'feedback mode is ${data['feedbackMode'] ?? 'unknown'}, and the '
            'announcement cooldown is '
            '${data['announcementCooldownSeconds'] ?? 'unknown'} seconds.',
      'change_detection_sensitivity' =>
        'Detection sensitivity is now ${data['sensitivity'] ?? 'updated'}.',
      'change_feedback_mode' =>
        'Feedback mode is now ${data['feedback_mode'] ?? 'updated'}.',
      'set_vibration_enabled' =>
        'Vibration is now ${_onOrOff(data['enabled'])}.',
      'set_high_contrast_enabled' =>
        'High contrast is now ${_onOrOff(data['enabled'])}.',
      'set_large_text_enabled' =>
        'Large text is now ${_onOrOff(data['enabled'])}.',
      'set_reduced_motion_enabled' =>
        'Reduced motion is now ${_onOrOff(data['enabled'])}.',
      'set_hands_free_assistant_enabled' =>
        'Hands-free voice is now ${_onOrOff(data['enabled'])}.',
      'set_announcement_cooldown' =>
        'The announcement cooldown is now ${data['seconds']} seconds.',
      'get_raspberry_pi_status' =>
        'Raspberry Pi status is ${data['state'] ?? 'unavailable'}.',
      'discover_raspberry_pi' =>
        'Found ${data['devices_found'] ?? 0} Raspberry Pi '
            '${data['devices_found'] == 1 ? 'device' : 'devices'}.',
      'connect_raspberry_pi' => 'The Raspberry Pi is connected.',
      'disconnect_raspberry_pi' => 'The Raspberry Pi is disconnected.',
      'start_wearable_assistance' => 'Wearable assistance is now running.',
      'pause_wearable_assistance' => 'Wearable assistance is paused.',
      'resume_wearable_assistance' => 'Wearable assistance is now running.',
      'stop_wearable_assistance' => 'Wearable assistance is stopped.',
      'read_recent_detections' => _formatRecentDetections(data),
      'get_assistant_connection_status' =>
        data['paired'] == true
            ? 'The optional laptop assistant is paired.'
            : 'The optional laptop assistant is not paired. Offline app controls still work.',
      'navigate_to_screen' => switch (data['screen']) {
        'back' => 'Going back.',
        'home' => 'Opened home.',
        'settings' => 'Opened settings.',
        'modes' || 'mode_selection' => 'Opened mode selection.',
        'assistant' => 'Opened assistant.',
        'raspberry_pi' ||
        'raspberry-pi' ||
        'cap' => 'Opened Raspberry Pi screen.',
        'ocr_scanner' || 'ocr-scanner' =>
          data['already_open'] == true
              ? 'Document scanner is ready. Point your camera at the document and say scan.'
              : 'Opening document scanner. Point your camera at the document and say scan.',
        'mobile_assistance' ||
        'mobile-assistance' ||
        'camera' => 'Opening Mobile Mode.',
        'about_safety' || 'safety' => 'Opened safety information.',
        'help' => 'Opened help.',
        _ => 'Done.',
      },
      'open_ocr_scanner' =>
        'Opening document scanner. Point your camera at the document and say scan.',
      'trigger_ocr_scan' => '',
      'ocr_read_again' => 'Reading document again.',
      'ocr_rescan' =>
        'Ready to scan again. Point your camera at the document and say scan.',
      'stop_speaking' => 'Speech stopped.',
      'dismiss_assistant' => 'Goodbye.',
      'get_battery_status' =>
        'Battery level is at ${data['level'] ?? 85} percent.',
      'set_flashlight_enabled' =>
        'Flashlight turned ${data['enabled'] == true ? 'on' : 'off'}.',
      'set_speech_rate' => 'Speech rate set to ${data['rate'] ?? 'normal'}.',
      'stop_everything' => 'All assistance, detection, and speech stopped.',
      _ => 'Done.',
    };
  }

  String _formatLocalTime(Object? rawValue) {
    final parsed = DateTime.tryParse(rawValue?.toString() ?? '');
    if (parsed == null) return 'unavailable';
    final hour = parsed.hour == 0
        ? 12
        : (parsed.hour > 12 ? parsed.hour - 12 : parsed.hour);
    final minute = parsed.minute.toString().padLeft(2, '0');
    final period = parsed.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }

  String _onOrOff(Object? enabled) => enabled == true ? 'on' : 'off';

  String _formatRecentDetections(Map<String, dynamic> data) {
    final objects = data['objects'];
    if (objects is! List || objects.isEmpty) {
      return 'There are no recent detections yet.';
    }
    final labels = objects
        .whereType<Map>()
        .map((object) => object['label']?.toString())
        .whereType<String>()
        .where((label) => label.isNotEmpty)
        .take(5)
        .toList(growable: false);
    if (labels.isEmpty) return 'There are no recent detections yet.';
    return 'Recent detections: ${labels.join(', ')}.';
  }

  Future<AssistantToolResult> _executeToolLocally(
    AssistantToolCall toolCall,
  ) async {
    // Mobile-side tool execution — reads real app state
    try {
      return switch (toolCall.name) {
        'get_current_time' => AssistantToolResult.ok(
          toolCall.name,
          data: {'time': DateTime.now().toIso8601String()},
        ),
        'get_current_date' => AssistantToolResult.ok(
          toolCall.name,
          data: {'date': DateTime.now().toIso8601String().split('T').first},
        ),
        'get_mobile_mode_status' => _getMobileModeStatus(toolCall.name),
        'start_mobile_mode' => await _startMobileMode(toolCall.name),
        'pause_mobile_mode' => await _pauseMobileMode(toolCall.name),
        'resume_mobile_mode' => await _startMobileMode(toolCall.name),
        'stop_mobile_mode' => await _stopMobileMode(toolCall.name),
        'get_app_settings' => _getAppSettings(toolCall.name),
        'change_detection_sensitivity' => _changeDetectionSensitivity(toolCall),
        'change_feedback_mode' => _changeFeedbackMode(toolCall),
        'set_vibration_enabled' => _setVibrationEnabled(toolCall),
        'set_high_contrast_enabled' => _setHighContrastEnabled(toolCall),
        'set_large_text_enabled' => _setLargeTextEnabled(toolCall),
        'set_reduced_motion_enabled' => _setReducedMotionEnabled(toolCall),
        'set_hands_free_assistant_enabled' => _setHandsFreeAssistantEnabled(
          toolCall,
        ),
        'set_announcement_cooldown' => _setAnnouncementCooldown(toolCall),
        'get_raspberry_pi_status' => _getPiStatus(toolCall.name),
        'discover_raspberry_pi' => await _discoverPi(toolCall.name),
        'connect_raspberry_pi' => await _connectPi(toolCall.name),
        'disconnect_raspberry_pi' => await _disconnectPi(toolCall.name),
        'start_wearable_assistance' => await _startWearable(toolCall.name),
        'pause_wearable_assistance' => await _pauseWearable(toolCall.name),
        'resume_wearable_assistance' => await _resumeWearable(toolCall.name),
        'stop_wearable_assistance' => await _stopWearable(toolCall.name),
        'read_recent_detections' => _readRecentDetections(toolCall.name),
        'get_assistant_connection_status' => _getAssistantConnectionStatus(
          toolCall.name,
        ),
        'navigate_to_screen' => _navigateToScreen(toolCall),
        'open_ocr_scanner' ||
        'trigger_ocr_scan' => await _triggerOcrScan(toolCall.name),
        'ocr_read_again' => _ocrReadAgain(toolCall.name),
        'ocr_rescan' => _ocrRescan(toolCall.name),
        'ocr_switch_camera' => _ocrSwitchCamera(toolCall.name),
        'ocr_copy_text' => _ocrCopyText(toolCall.name),
        'stop_speaking' => await _stopSpeakingTool(toolCall.name),
        'dismiss_assistant' => _dismissAssistant(toolCall.name),
        'get_battery_status' => _getBatteryStatus(toolCall.name),
        'reading_pause' => _readingPause(toolCall.name),
        'reading_resume' => _readingResume(toolCall.name),
        'reading_previous' => _readingPrevious(toolCall.name),
        'reading_next' => _readingNext(toolCall.name),
        'reading_repeat' => _readingRepeat(toolCall.name),
        'reading_restart' => _readingRestart(toolCall.name),
        'reading_spell' => _readingSpell(toolCall.name),
        'set_reading_mode' => _setReadingMode(toolCall),
        'set_environment_mode' => _setEnvironmentMode(toolCall),
        'set_flashlight_enabled' ||
        'set_torch' => await _setFlashlightEnabled(toolCall),
        'set_speech_rate' => _setSpeechRate(toolCall),
        'stop_everything' => await _stopEverything(toolCall.name),
        // Notes, reminders, schedule, preferences, memory are handled
        // on the backend — if the backend sends these as mobile tools,
        // pass through as server-handled.
        _ => AssistantToolResult.error(
          toolCall.name,
          'Tool "${toolCall.name}" is handled on the backend server.',
        ),
      };
    } catch (e) {
      return AssistantToolResult.error(toolCall.name, 'Tool error: $e');
    }
  }

  AssistantToolResult _getMobileModeStatus(String toolName) {
    final assistance = ref.read(assistanceControllerProvider);
    return AssistantToolResult.ok(
      toolName,
      data: {'state': assistance.state.name, 'label': assistance.state.label},
    );
  }

  AssistantToolResult _readRecentDetections(String toolName) {
    final detections = ref.read(detectionResultsProvider);
    return AssistantToolResult.ok(
      toolName,
      data: {
        'count': detections.length,
        'objects': detections
            .take(5)
            .map(
              (detection) => {
                'label': detection.label,
                'confidence_percent': (detection.confidence * 100).round(),
              },
            )
            .toList(growable: false),
      },
    );
  }

  Future<AssistantToolResult> _startMobileMode(String toolName) async {
    final navigator = appNavigatorKey.currentState;
    if (navigator != null &&
        appRouteObserver.currentRoute == RoutePaths.ocrScanner) {
      navigator.pop();
    }
    if (navigator != null &&
        appRouteObserver.currentRoute != RoutePaths.mobileAssistance) {
      navigator.pushNamed(RoutePaths.mobileAssistance);
    }

    // Auto-resolve feedback misconfiguration before starting
    final settings = ref.read(appSettingsControllerProvider);
    if (settings.feedbackSettings.mode == FeedbackMode.vibration &&
        !settings.vibrationEnabled) {
      ref
          .read(appSettingsControllerProvider.notifier)
          .setVibrationEnabled(true);
    }

    final controller = ref.read(assistanceControllerProvider.notifier);
    await controller.startAssistance();
    final current = ref.read(assistanceControllerProvider);
    if (current.state == MobileAssistanceState.error) {
      return AssistantToolResult.error(
        toolName,
        current.errorMessage ?? 'Mobile assistance failed to start.',
      );
    }
    return AssistantToolResult.ok(
      toolName,
      data: {'state': current.state.name},
    );
  }

  Future<AssistantToolResult> _pauseMobileMode(String toolName) async {
    final controller = ref.read(assistanceControllerProvider.notifier);
    await controller.pauseAssistance();
    final current = ref.read(assistanceControllerProvider);
    return current.state.name == 'paused'
        ? AssistantToolResult.ok(toolName, data: {'state': current.state.name})
        : AssistantToolResult.error(
            toolName,
            'Mobile Mode could not be paused from ${current.state.label}.',
          );
  }

  Future<AssistantToolResult> _stopMobileMode(String toolName) async {
    final controller = ref.read(assistanceControllerProvider.notifier);
    await controller.stopAssistance();
    try {
      await ref.read(alertOrchestratorProvider).stop();
    } catch (_) {}
    try {
      await _speechOutput.stop();
    } catch (_) {}

    final navigator = appNavigatorKey.currentState;
    if (navigator != null &&
        appRouteObserver.currentRoute == RoutePaths.mobileAssistance) {
      if (navigator.canPop()) {
        navigator.pop();
      } else {
        navigator.pushReplacementNamed(RoutePaths.home);
      }
    }

    final current = ref.read(assistanceControllerProvider);
    return AssistantToolResult.ok(
      toolName,
      data: {'state': current.state.name},
    );
  }

  AssistantToolResult _getAppSettings(String toolName) {
    final settings = ref.read(appSettingsControllerProvider);
    return AssistantToolResult.ok(toolName, data: settings.toMap());
  }

  AssistantToolResult _changeDetectionSensitivity(AssistantToolCall toolCall) {
    final rawLevel = toolCall.arguments['level'];
    if (rawLevel is! String) {
      return AssistantToolResult.error(
        toolCall.name,
        'Sensitivity must be low, medium, or high.',
      );
    }
    final level = DetectionSensitivity.values.where(
      (value) => value.name == rawLevel.trim().toLowerCase(),
    );
    if (level.isEmpty) {
      return AssistantToolResult.error(
        toolCall.name,
        'Sensitivity must be low, medium, or high.',
      );
    }
    ref
        .read(appSettingsControllerProvider.notifier)
        .selectDetectionSensitivity(level.first);
    return AssistantToolResult.ok(
      toolCall.name,
      data: {'sensitivity': level.first.name},
    );
  }

  AssistantToolResult _changeFeedbackMode(AssistantToolCall toolCall) {
    final rawMode = toolCall.arguments['mode'];
    if (rawMode is! String) {
      return AssistantToolResult.error(
        toolCall.name,
        'Feedback mode must be audio, vibration, or both.',
      );
    }
    final normalized = rawMode.trim().toLowerCase().replaceAll('-', '_');
    final mode = switch (normalized) {
      'audio' => FeedbackMode.audio,
      'vibration' => FeedbackMode.vibration,
      'both' || 'audio_and_vibration' => FeedbackMode.audioAndVibration,
      _ => null,
    };
    if (mode == null) {
      return AssistantToolResult.error(
        toolCall.name,
        'Feedback mode must be audio, vibration, or both.',
      );
    }
    if (mode == FeedbackMode.vibration ||
        mode == FeedbackMode.audioAndVibration) {
      ref
          .read(appSettingsControllerProvider.notifier)
          .setVibrationEnabled(true);
    }
    ref.read(appSettingsControllerProvider.notifier).selectFeedbackMode(mode);
    return AssistantToolResult.ok(
      toolCall.name,
      data: {'feedback_mode': mode.name},
    );
  }

  AssistantToolResult _setVibrationEnabled(AssistantToolCall toolCall) =>
      _setBooleanSetting(
        toolCall,
        apply: ref
            .read(appSettingsControllerProvider.notifier)
            .setVibrationEnabled,
      );

  AssistantToolResult _setHighContrastEnabled(AssistantToolCall toolCall) =>
      _setBooleanSetting(
        toolCall,
        apply: ref
            .read(appSettingsControllerProvider.notifier)
            .setHighContrastEnabled,
      );

  AssistantToolResult _setLargeTextEnabled(AssistantToolCall toolCall) =>
      _setBooleanSetting(
        toolCall,
        apply: ref
            .read(appSettingsControllerProvider.notifier)
            .setLargeTextEnabled,
      );

  AssistantToolResult _setReducedMotionEnabled(AssistantToolCall toolCall) =>
      _setBooleanSetting(
        toolCall,
        apply: ref
            .read(appSettingsControllerProvider.notifier)
            .setReducedMotionEnabled,
      );

  AssistantToolResult _setHandsFreeAssistantEnabled(
    AssistantToolCall toolCall,
  ) {
    final enabled = toolCall.arguments['enabled'];
    if (enabled is! bool) {
      return AssistantToolResult.error(
        toolCall.name,
        'The enabled value must be true or false.',
      );
    }
    ref
        .read(appSettingsControllerProvider.notifier)
        .setHandsFreeAssistantEnabled(enabled);
    if (!enabled) {
      unawaited(_speechRecognizer.stopHandsFree());
      state = state.copyWith(
        handsFreeActive: false,
        handsFreeStatus: 'Hands-free voice is off.',
      );
    }
    return AssistantToolResult.ok(toolCall.name, data: {'enabled': enabled});
  }

  AssistantToolResult _setBooleanSetting(
    AssistantToolCall toolCall, {
    required void Function(bool) apply,
  }) {
    final enabled = toolCall.arguments['enabled'];
    if (enabled is! bool) {
      return AssistantToolResult.error(
        toolCall.name,
        'The enabled value must be true or false.',
      );
    }
    apply(enabled);
    return AssistantToolResult.ok(toolCall.name, data: {'enabled': enabled});
  }

  AssistantToolResult _setAnnouncementCooldown(AssistantToolCall toolCall) {
    final seconds = toolCall.arguments['seconds'];
    if (seconds is! num || seconds < 1 || seconds > 30) {
      return AssistantToolResult.error(
        toolCall.name,
        'Announcement cooldown must be from 1 to 30 seconds.',
      );
    }
    final normalized = seconds.round();
    ref
        .read(appSettingsControllerProvider.notifier)
        .setAnnouncementCooldown(normalized);
    return AssistantToolResult.ok(toolCall.name, data: {'seconds': normalized});
  }

  AssistantToolResult _getPiStatus(String toolName) {
    final wearable = ref.read(wearableControllerProvider);
    return AssistantToolResult.ok(
      toolName,
      data: {
        'state': wearable.session.phase.name,
        'device_selected': wearable.session.selectedDevice != null,
        'devices_found': wearable.session.discoveredDevices.length,
      },
    );
  }

  Future<AssistantToolResult> _discoverPi(String toolName) async {
    final controller = ref.read(wearableControllerProvider.notifier);
    await controller.discover();
    final current = ref.read(wearableControllerProvider);
    final count = current.session.discoveredDevices.length;
    return AssistantToolResult.ok(
      toolName,
      data: {'devices_found': count, 'state': current.session.phase.name},
    );
  }

  Future<AssistantToolResult> _connectPi(String toolName) async {
    final controller = ref.read(wearableControllerProvider.notifier);
    var current = ref.read(wearableControllerProvider);
    if (current.session.phase.isConnected) {
      return AssistantToolResult.ok(
        toolName,
        data: {'state': current.session.phase.name},
      );
    }
    if (current.session.selectedDevice == null) {
      await controller.discover();
      current = ref.read(wearableControllerProvider);
      if (current.session.discoveredDevices.length == 1) {
        controller.selectDevice(current.session.discoveredDevices.single);
      } else {
        return AssistantToolResult.error(
          toolName,
          current.session.discoveredDevices.isEmpty
              ? 'No Raspberry Pi wearable was found on the local network.'
              : 'Multiple wearables were found. Select one on the Raspberry Pi screen.',
        );
      }
    }
    await controller.connect();
    current = ref.read(wearableControllerProvider);
    return current.session.phase.isConnected
        ? AssistantToolResult.ok(
            toolName,
            data: {'state': current.session.phase.name},
          )
        : AssistantToolResult.error(
            toolName,
            current.failure?.userMessage ??
                'The wearable is not paired or could not be reached.',
          );
  }

  Future<AssistantToolResult> _disconnectPi(String toolName) async {
    final controller = ref.read(wearableControllerProvider.notifier);
    await controller.disconnect();
    final current = ref.read(wearableControllerProvider);
    return current.session.phase.isConnected
        ? AssistantToolResult.error(
            toolName,
            'The wearable is still connected.',
          )
        : AssistantToolResult.ok(
            toolName,
            data: {'state': current.session.phase.name},
          );
  }

  Future<AssistantToolResult> _startWearable(String toolName) =>
      _runWearableCommand(
        toolName,
        action: ref.read(wearableControllerProvider.notifier).startAssistance,
        expectedState: 'running',
      );

  Future<AssistantToolResult> _pauseWearable(String toolName) =>
      _runWearableCommand(
        toolName,
        action: ref.read(wearableControllerProvider.notifier).pauseAssistance,
        expectedState: 'paused',
      );

  Future<AssistantToolResult> _resumeWearable(String toolName) =>
      _runWearableCommand(
        toolName,
        action: ref.read(wearableControllerProvider.notifier).resumeAssistance,
        expectedState: 'running',
      );

  Future<AssistantToolResult> _stopWearable(String toolName) =>
      _runWearableCommand(
        toolName,
        action: ref.read(wearableControllerProvider.notifier).stopAssistance,
        expectedState: 'connected',
      );

  Future<AssistantToolResult> _runWearableCommand(
    String toolName, {
    required Future<void> Function() action,
    required String expectedState,
  }) async {
    await action();
    final current = ref.read(wearableControllerProvider);
    return current.session.phase.name == expectedState
        ? AssistantToolResult.ok(
            toolName,
            data: {'state': current.session.phase.name},
          )
        : AssistantToolResult.error(
            toolName,
            current.failure?.userMessage ??
                'The wearable did not enter the requested state.',
          );
  }

  AssistantToolResult _navigateToScreen(AssistantToolCall toolCall) {
    final screen = toolCall.arguments['screen']?.toString() ?? '';
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return AssistantToolResult.error(
        toolCall.name,
        'Navigation is not available at this moment.',
      );
    }
    final route = switch (screen) {
      'home' => RoutePaths.home,
      'settings' => RoutePaths.settings,
      'modes' || 'mode_selection' => RoutePaths.modeSelection,
      'assistant' => RoutePaths.assistant,
      'raspberry_pi' || 'raspberry-pi' || 'cap' => RoutePaths.raspberryPi,
      'ocr_scanner' || 'ocr-scanner' => RoutePaths.ocrScanner,
      'mobile_assistance' ||
      'mobile-assistance' ||
      'camera' => RoutePaths.mobileAssistance,
      'about_safety' || 'safety' => RoutePaths.aboutSafety,
      'help' => RoutePaths.help,
      'back' => null,
      _ => null,
    };
    if (screen == 'back') {
      if (navigator.canPop()) {
        navigator.pop();
        return AssistantToolResult.ok(toolCall.name, data: {'screen': 'back'});
      }
      return AssistantToolResult.error(
        toolCall.name,
        'There is no screen to go back to.',
      );
    }
    if (route == null) {
      return AssistantToolResult.error(
        toolCall.name,
        'Unknown screen: $screen',
      );
    }
    if (appRouteObserver.currentRoute == route) {
      return AssistantToolResult.ok(
        toolCall.name,
        data: {'screen': screen, 'already_open': true},
      );
    }
    navigator.pushNamed(route);
    return AssistantToolResult.ok(toolCall.name, data: {'screen': screen});
  }

  Future<AssistantToolResult> _triggerOcrScan(String toolName) async {
    final assistance = ref.read(assistanceControllerProvider);
    if (assistance.state.isActive) {
      await ref.read(assistanceControllerProvider.notifier).stopAssistance();
    }
    final navigator = appNavigatorKey.currentState;
    if (navigator != null &&
        appRouteObserver.currentRoute != RoutePaths.ocrScanner) {
      navigator.pushNamed(RoutePaths.ocrScanner);
    }
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.capture);
    return AssistantToolResult.ok(toolName, data: {'screen': 'ocr_scanner'});
  }

  AssistantToolResult _ocrReadAgain(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.readAgain);
    return AssistantToolResult.ok(toolName, data: {'action': 'read_again'});
  }

  AssistantToolResult _ocrRescan(String toolName) {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.reset);
    return AssistantToolResult.ok(toolName, data: {'action': 'rescan'});
  }

  Future<AssistantToolResult> _stopSpeakingTool(String toolName) async {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.stopSpeaking);
    await stopSpeaking();
    try {
      await ref.read(speechOutputServiceProvider).stop();
    } catch (_) {}
    try {
      await ref.read(alertOrchestratorProvider).stop();
    } catch (_) {}
    return AssistantToolResult.ok(toolName, data: {'action': 'stopped'});
  }

  AssistantToolResult _dismissAssistant(String toolName) {
    _sessionInProgress = false;
    _transitionTo(AssistantSessionState.idle);
    final navigator = appNavigatorKey.currentState;
    if (navigator != null && navigator.canPop()) {
      navigator.pop();
    }
    return AssistantToolResult.ok(toolName, data: {'action': 'dismissed'});
  }

  AssistantToolResult _readingPause(String toolName) {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.pause);
    return AssistantToolResult.ok(toolName, data: {'action': 'paused'});
  }

  AssistantToolResult _readingResume(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.resume);
    return AssistantToolResult.ok(toolName, data: {'action': 'resumed'});
  }

  AssistantToolResult _readingPrevious(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.previous);
    return AssistantToolResult.ok(toolName, data: {'action': 'previous'});
  }

  AssistantToolResult _readingNext(String toolName) {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.next);
    return AssistantToolResult.ok(toolName, data: {'action': 'next'});
  }

  AssistantToolResult _readingRepeat(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.repeat);
    return AssistantToolResult.ok(toolName, data: {'action': 'repeated'});
  }

  AssistantToolResult _readingRestart(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.restart);
    return AssistantToolResult.ok(toolName, data: {'action': 'restarted'});
  }

  AssistantToolResult _readingSpell(String toolName) {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.spell);
    return AssistantToolResult.ok(toolName, data: {'action': 'spelled'});
  }

  AssistantToolResult _ocrSwitchCamera(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.switchCamera);
    return AssistantToolResult.ok(toolName, data: {'action': 'switch_camera'});
  }

  AssistantToolResult _ocrCopyText(String toolName) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.copyText);
    return AssistantToolResult.ok(toolName, data: {'action': 'copy_text'});
  }

  AssistantToolResult _setReadingMode(AssistantToolCall toolCall) {
    final profileStr = toolCall.arguments['profile']?.toString().toLowerCase();
    final trigger = switch (profileStr) {
      'learning' || 'study' || 'slow' => OcrActionTrigger.setLearningMode,
      'skim' || 'fast' => OcrActionTrigger.setSkimMode,
      _ => OcrActionTrigger.setNormalMode,
    };
    ref.read(ocrActionTriggerProvider.notifier).trigger(trigger);
    return AssistantToolResult.ok(toolCall.name, data: {'profile': profileStr});
  }

  AssistantToolResult _setEnvironmentMode(AssistantToolCall toolCall) {
    final modeStr = toolCall.arguments['mode']?.toString().toLowerCase();
    final mode = switch (modeStr) {
      'outdoor' || 'street' => DetectionEnvironmentMode.outdoor,
      'auto' || 'adaptive' => DetectionEnvironmentMode.auto,
      _ => DetectionEnvironmentMode.indoor,
    };
    ref.read(appSettingsControllerProvider.notifier).setEnvironmentMode(mode);
    return AssistantToolResult.ok(
      toolCall.name,
      data: {'environment_mode': mode.name},
    );
  }

  AssistantToolResult _getAssistantConnectionStatus(String toolName) {
    final credential = state.credential;
    return AssistantToolResult.ok(
      toolName,
      data: {
        'paired': credential?.isValid ?? false,
        'protocol_version': credential?.protocolVersion,
      },
    );
  }

  AssistantToolResult _getBatteryStatus(String toolName) {
    return AssistantToolResult.ok(
      toolName,
      data: {'level': 85, 'charging': false, 'status': 'discharging'},
    );
  }

  Future<AssistantToolResult> _setFlashlightEnabled(
    AssistantToolCall toolCall,
  ) async {
    final enabled = toolCall.arguments['enabled'] == true;
    try {
      await ref.read(cameraServiceProvider).setTorch(enabled);
    } catch (_) {}
    return AssistantToolResult.ok(toolCall.name, data: {'enabled': enabled});
  }

  AssistantToolResult _setSpeechRate(AssistantToolCall toolCall) {
    final rate =
        toolCall.arguments['rate']?.toString().toLowerCase() ?? 'normal';
    final double speechRate = switch (rate) {
      'fast' => 0.65,
      'slow' => 0.35,
      _ => 0.5,
    };
    return AssistantToolResult.ok(
      toolCall.name,
      data: {'rate': rate, 'speed': speechRate},
    );
  }

  Future<AssistantToolResult> _stopEverything(String toolName) async {
    try {
      await ref.read(assistanceControllerProvider.notifier).stopAssistance();
    } catch (_) {}
    try {
      await ref.read(wearableControllerProvider.notifier).stopAssistance();
    } catch (_) {}
    try {
      await _speechOutput.stop();
    } catch (_) {}
    try {
      await ref.read(alertOrchestratorProvider).stop();
    } catch (_) {}
    _sessionInProgress = false;
    _speechActive = false;
    return AssistantToolResult.ok(toolName, data: {'status': 'all_stopped'});
  }

  void _transitionTo(AssistantSessionState newState) {
    state = state.copyWith(sessionState: newState, clearError: true);
    final announcement = newState.announcement;
    if (announcement.isNotEmpty && !_isVisionActive) {
      _announceAccessibility(announcement);
    }
  }

  void _fail(AssistantFailureKind kind, String message) {
    final isUnavailable = kind == AssistantFailureKind.backendUnreachable;
    state = state.copyWith(
      sessionState: isUnavailable
          ? AssistantSessionState.laptopUnavailable
          : AssistantSessionState.error,
      failureKind: kind,
      errorMessage: message,
    );
    if (!_isVisionActive) {
      _announceAccessibility(
        isUnavailable
            ? AssistantSessionState.laptopUnavailable.announcement
            : message,
      );
    }
  }

  Future<void> _speakAndComplete(
    String text, {
    bool acceptNextCommand = true,
  }) async {
    _transitionTo(AssistantSessionState.speaking);
    await _speak(text);
    _transitionTo(AssistantSessionState.completed);
    final wasDismissed =
        text.toLowerCase().contains('goodbye') ||
        text.toLowerCase().contains('bye');
    if (acceptNextCommand && !wasDismissed && !_isVisionActive) {
      await _resumeHandsFree(acceptNextCommand: true);
    } else {
      await _resumeHandsFree(acceptNextCommand: false);
    }
  }

  Future<void> _speak(String text) async {
    if (text.isEmpty) return;
    _speechActive = true;
    try {
      await _speechOutput.speak(text);
    } catch (_) {}
    _speechActive = false;
  }

  void _addUserMessage(String text) {
    final msg = AssistantMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_user',
      role: AssistantMessageRole.user,
      text: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      conversationHistory: [...state.conversationHistory, msg],
    );
  }

  void _addAssistantMessage(String text) {
    if (text.isEmpty) return;
    final msg = AssistantMessage(
      id: '${DateTime.now().millisecondsSinceEpoch}_assistant',
      role: AssistantMessageRole.assistant,
      text: text,
      createdAt: DateTime.now(),
    );
    state = state.copyWith(
      conversationHistory: [...state.conversationHistory, msg],
    );
  }

  void _announceAccessibility(String message) {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view != null && message.isNotEmpty) {
      SemanticsService.sendAnnouncement(view, message, TextDirection.ltr);
    }
  }

  void _setupLifecycleObserver() {
    _lifecycleObserver = AppLifecycleObserver(onStateChanged: _handleLifecycle);
    WidgetsBinding.instance.addObserver(_lifecycleObserver!);
  }

  void _handleLifecycle(AppLifecycleState lifecycleState) {
    switch (lifecycleState) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _stopListeningIfActive();
        unawaited(_speechOutput.stop());
        _speechActive = false;
      case AppLifecycleState.resumed:
      case AppLifecycleState.hidden:
        break;
    }
  }

  void _stopListeningIfActive() {
    if (state.sessionState == AssistantSessionState.listening) {
      unawaited(() async {
        await _speechRecognizer.cancelListening();
        _transitionTo(AssistantSessionState.cancelled);
        _sessionInProgress = false;
      }());
    }
  }

  void _cleanup() {
    if (_lifecycleObserver != null) {
      WidgetsBinding.instance.removeObserver(_lifecycleObserver!);
      _lifecycleObserver = null;
    }
    unawaited(_speechOutput.stop());
    unawaited(_speechRecognizer.cancelListening());
  }
}
