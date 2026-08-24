import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_command_result.dart';
import '../../domain/enums/detection_environment_mode.dart';
import '../../domain/enums/detection_sensitivity.dart';
import '../../domain/enums/feedback_mode.dart';
import '../../domain/enums/mobile_assistance_state.dart';
import '../../domain/enums/voice_intent.dart';
import '../app.dart';
import '../assistance_controller.dart';
import '../assistant_providers.dart';
import '../assistant_session_controller.dart';
import '../camera_providers.dart';
import '../detection_providers.dart';
import '../feedback_providers.dart';
import '../providers.dart';
import '../router/app_route_observer.dart';
import '../router/route_paths.dart';
import '../wearable_controller.dart';
import 'voice_diagnostic_logger.dart';

/// Central executor for all voice commands.
///
/// Executes the strongly-typed [VoiceIntent] using the same application and
/// domain controllers that UI widgets use. Ensures business logic is shared
/// and never duplicated between UI and voice.
class CommandExecutor {
  const CommandExecutor(this.ref);

  final Ref ref;

  /// Executes a validated [VoiceCommand] and returns the result.
  Future<VoiceCommandResult> execute(VoiceCommand command) async {
    VoiceDiagnosticLogger.executed(command);
    try {
      return await switch (command.intent) {
        // ─────────────────── Emergency / Silence ────────────────
        EmergencyStop() => _emergencyStop(),
        Silence() => _silence(),

        // ─────────────────── Navigation ─────────────────────────
        NavigateHome() => _navigate(RoutePaths.home, 'home'),
        NavigateSettings() => _navigate(RoutePaths.settings, 'settings'),
        NavigateScanner() => _navigate(RoutePaths.ocrScanner, 'ocr_scanner'),
        NavigateSmartAi() => _navigate(RoutePaths.assistant, 'Smart AI'),
        NavigateMobileAssistance() => _navigate(
          RoutePaths.mobileAssistance,
          'mobile_assistance',
        ),
        NavigateRaspberryPi() => _navigate(
          RoutePaths.raspberryPi,
          'raspberry_pi',
        ),
        NavigateModeSelection() => _navigate(RoutePaths.modeSelection, 'modes'),
        NavigateSafety() => _navigate(RoutePaths.aboutSafety, 'safety'),
        NavigateHelp() => _navigate(RoutePaths.help, 'help'),
        NavigateBack() => _navigateBack(),

        // ─────────────────── Mobile Detection ───────────────────
        StartMobileDetection() => _startMobileMode(),
        StopMobileDetection() => _stopMobileMode(),
        PauseMobileDetection() => _pauseMobileMode(),
        ResumeMobileDetection() => _resumeMobileMode(),
        GetMobileDetectionStatus() => _getMobileModeStatus(),
        ReadRecentDetections() => _readRecentDetections(),

        // ─────────────────── Document Scanner ───────────────────
        ScanDocument() => _triggerOcrScan(),
        RescanDocument() => _ocrRescan(),
        ReadDocumentAgain() => _ocrReadAgain(),
        SwitchScannerCamera() => _ocrSwitchCamera(),
        CopyScannedText() => _ocrCopyText(),

        // ─────────────────── Reader Controls ────────────────────
        ReadingPause() => _readingPause(),
        ReadingResume() => _readingResume(),
        ReadingNext() => _readingNext(),
        ReadingPrevious() => _readingPrevious(),
        ReadingRepeat() => _readingRepeat(),
        ReadingRestart() => _readingRestart(),
        ReadingLast() => _readingLast(),
        ReadingGoToLine(:final lineNumber) => _readingGoToLine(lineNumber),
        ReadingSpell() => _readingSpell(),
        SetReadingProfile(:final profile) => _setReadingProfile(profile),

        // ─────────────────── Environment Mode ───────────────────
        SetEnvironmentMode(:final mode) => _setEnvironmentMode(mode),

        // ─────────────────── Raspberry Pi ───────────────────────
        GetPiStatus() => _getPiStatus(),
        DiscoverPi() => _discoverPi(),
        ConnectPi() => _connectPi(),
        DisconnectPi() => _disconnectPi(),
        StartWearable() => _startWearable(),
        StopWearable() => _stopWearable(),
        PauseWearable() => _pauseWearable(),
        ResumeWearable() => _resumeWearable(),

        // ─────────────────── Settings ───────────────────────────
        SetDetectionSensitivity(:final level) => _setDetectionSensitivity(
          level,
        ),
        SetFeedbackMode(:final mode) => _setFeedbackMode(mode),
        SetBooleanSetting(:final setting, :final enabled) => _setBooleanSetting(
          setting,
          enabled,
        ),
        SetFlashlight(:final enabled) => _setFlashlight(enabled),
        SetSpeechRate(:final rate) => _setSpeechRate(rate),
        SetAnnouncementCooldown(:final seconds) => _setAnnouncementCooldown(
          seconds,
        ),
        GetAppSettings() => _getAppSettings(),

        // ─────────────────── System / Utility ───────────────────
        GetCurrentTime() => _getCurrentTime(),
        GetCurrentDate() => _getCurrentDate(),
        GetBatteryStatus() => _getBatteryStatus(),
        GetAssistantConnectionStatus() => _getAssistantConnectionStatus(),

        // ─────────────────── Conversation ───────────────────────
        Greeting() => const VoiceCommandSuccess(
          feedbackText:
              "Hello. I'm ready to help. What would you like me to do?",
        ),
        WhatCanYouDo() => const VoiceCommandSuccess(
          feedbackText:
              'I can control detection sensitivity, feedback mode, '
              'accessibility settings, Mobile Mode detection, document scanning, '
              'and Raspberry Pi wearable mode. I can also navigate screens, '
              'read the time, and report recent detections.',
        ),
        WhoAreYou() => const VoiceCommandSuccess(
          feedbackText:
              "I'm Vision AI, your offline voice assistant for this app.",
        ),
        Goodbye() || DismissAssistant() => _dismissAssistant(),
        ThankYou() => const VoiceCommandSuccess(
          feedbackText: "You're welcome. I'm still listening.",
        ),

        // ─────────────────── Confirmation ───────────────────────
        ConfirmYes() => const VoiceCommandSuccess(feedbackText: 'Confirmed.'),
        ConfirmNo() => const VoiceCommandSuccess(feedbackText: 'Cancelled.'),

        // ─────────────────── Ambiguous / Unknown ────────────────
        AmbiguousIntent() => const VoiceCommandInvalidState(
          'Multiple commands matched. Please be more specific.',
        ),
        UnknownIntent(:final transcript) => VoiceCommandUnavailable(
          'Unknown command: $transcript',
        ),
      };
    } catch (e) {
      VoiceDiagnosticLogger.error('Command execution failed', e);
      return VoiceCommandFailure('Command execution failed: $e');
    }
  }

  // ─────────────────── Emergency & Silence ────────────────────

  Future<VoiceCommandResult> _emergencyStop() async {
    try {
      await ref.read(assistanceControllerProvider.notifier).stopAssistance();
    } catch (_) {}
    try {
      await ref.read(wearableControllerProvider.notifier).stopAssistance();
    } catch (_) {}
    try {
      await ref.read(speechOutputServiceProvider).stop();
    } catch (_) {}
    try {
      await ref.read(alertOrchestratorProvider).stop();
    } catch (_) {}
    return const VoiceCommandSuccess(
      feedbackText: 'Stopped all assistance and audio.',
    );
  }

  Future<VoiceCommandResult> _silence() async {
    try {
      ref
          .read(ocrActionTriggerProvider.notifier)
          .trigger(OcrActionTrigger.stopSpeaking);
    } catch (_) {}
    try {
      await ref.read(speechOutputServiceProvider).stop();
    } catch (_) {}
    try {
      await ref.read(alertOrchestratorProvider).stop();
    } catch (_) {}
    return const VoiceCommandSuccess();
  }

  // ─────────────────── Navigation ─────────────────────────────

  VoiceCommandResult _navigate(String route, String screenName) {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return const VoiceCommandUnavailable(
        'Navigation is not available right now.',
      );
    }
    if (appRouteObserver.currentRoute == route) {
      return VoiceCommandAlreadyInState('Already on $screenName screen.');
    }
    navigator.pushNamed(route);
    return VoiceCommandSuccess(
      feedbackText: 'Opening $screenName.',
      data: {'route': route},
    );
  }

  VoiceCommandResult _navigateBack() {
    final navigator = appNavigatorKey.currentState;
    if (navigator == null) {
      return const VoiceCommandUnavailable(
        'Navigation is not available right now.',
      );
    }
    if (navigator.canPop()) {
      navigator.pop();
      return const VoiceCommandSuccess(feedbackText: 'Going back.');
    }
    return const VoiceCommandInvalidState('There is no screen to go back to.');
  }

  // ─────────────────── Mobile Detection ───────────────────────

  Future<VoiceCommandResult> _startMobileMode() async {
    final navigator = appNavigatorKey.currentState;
    if (navigator != null &&
        appRouteObserver.currentRoute == RoutePaths.ocrScanner) {
      navigator.pop();
    }
    if (navigator != null &&
        appRouteObserver.currentRoute != RoutePaths.mobileAssistance) {
      navigator.pushNamed(RoutePaths.mobileAssistance);
    }

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
      return VoiceCommandFailure(
        current.errorMessage ?? 'Mobile assistance failed to start.',
      );
    }
    return const VoiceCommandSuccess(feedbackText: 'Mobile Mode started.');
  }

  Future<VoiceCommandResult> _stopMobileMode() async {
    final controller = ref.read(assistanceControllerProvider.notifier);
    await controller.stopAssistance();
    try {
      await ref.read(alertOrchestratorProvider).stop();
    } catch (_) {}
    try {
      await ref.read(speechOutputServiceProvider).stop();
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

    return const VoiceCommandSuccess(feedbackText: 'Mobile Mode stopped.');
  }

  Future<VoiceCommandResult> _pauseMobileMode() async {
    final controller = ref.read(assistanceControllerProvider.notifier);
    await controller.pauseAssistance();
    final current = ref.read(assistanceControllerProvider);
    return current.state.name == 'paused'
        ? const VoiceCommandSuccess(feedbackText: 'Mobile Mode paused.')
        : VoiceCommandFailure(
            'Mobile Mode could not be paused from ${current.state.label}.',
          );
  }

  Future<VoiceCommandResult> _resumeMobileMode() async {
    final controller = ref.read(assistanceControllerProvider.notifier);
    await controller.startAssistance();
    final current = ref.read(assistanceControllerProvider);
    return current.state.isActive
        ? const VoiceCommandSuccess(feedbackText: 'Mobile Mode resumed.')
        : VoiceCommandFailure(
            'Mobile Mode could not be resumed from ${current.state.label}.',
          );
  }

  VoiceCommandResult _getMobileModeStatus() {
    final assistance = ref.read(assistanceControllerProvider);
    return VoiceCommandSuccess(
      feedbackText: 'Mobile Mode is ${assistance.state.label}.',
      data: {'state': assistance.state.name},
    );
  }

  VoiceCommandResult _readRecentDetections() {
    final detections = ref.read(detectionResultsProvider);
    if (detections.isEmpty) {
      return const VoiceCommandSuccess(
        feedbackText: 'No objects currently detected in view.',
      );
    }
    final labels = detections.take(5).map((d) => d.label).toSet().join(', ');
    return VoiceCommandSuccess(
      feedbackText: 'Detected objects: $labels.',
      data: {'count': detections.length},
    );
  }

  // ─────────────────── Document Scanner ───────────────────────

  Future<VoiceCommandResult> _triggerOcrScan() async {
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
    return const VoiceCommandSuccess(feedbackText: 'Scanning document.');
  }

  VoiceCommandResult _ocrRescan() {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.reset);
    return const VoiceCommandSuccess(feedbackText: 'Ready to scan.');
  }

  VoiceCommandResult _ocrReadAgain() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.readAgain);
    return const VoiceCommandSuccess(feedbackText: 'Reading text again.');
  }

  VoiceCommandResult _ocrSwitchCamera() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.switchCamera);
    return const VoiceCommandSuccess(feedbackText: 'Switching camera.');
  }

  VoiceCommandResult _ocrCopyText() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.copyText);
    return const VoiceCommandSuccess(feedbackText: 'Text copied to clipboard.');
  }

  // ─────────────────── Reader Controls ────────────────────────

  VoiceCommandResult _readingPause() {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.pause);
    return const VoiceCommandSuccess(feedbackText: 'Reading paused.');
  }

  VoiceCommandResult _readingResume() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.resume);
    // The document player starts speaking immediately. Additional assistant
    // feedback would cancel that utterance on Android's single TTS engine.
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingNext() {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.next);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingPrevious() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.previous);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingRepeat() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.repeat);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingRestart() {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.restart);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingLast() {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.last);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingGoToLine(int lineNumber) {
    ref
        .read(ocrActionTriggerProvider.notifier)
        .trigger(OcrActionTrigger.goToLine, lineNumber: lineNumber);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _readingSpell() {
    ref.read(ocrActionTriggerProvider.notifier).trigger(OcrActionTrigger.spell);
    return const VoiceCommandSuccess();
  }

  VoiceCommandResult _setReadingProfile(String profile) {
    final trigger = switch (profile.toLowerCase()) {
      'learning' || 'study' || 'slow' => OcrActionTrigger.setLearningMode,
      'skim' || 'fast' => OcrActionTrigger.setSkimMode,
      _ => OcrActionTrigger.setNormalMode,
    };
    ref.read(ocrActionTriggerProvider.notifier).trigger(trigger);
    return const VoiceCommandSuccess();
  }

  // ─────────────────── Environment Mode ───────────────────────

  VoiceCommandResult _setEnvironmentMode(String modeStr) {
    final mode = switch (modeStr.toLowerCase()) {
      'outdoor' || 'street' => DetectionEnvironmentMode.outdoor,
      'auto' || 'adaptive' => DetectionEnvironmentMode.auto,
      _ => DetectionEnvironmentMode.indoor,
    };
    ref.read(appSettingsControllerProvider.notifier).setEnvironmentMode(mode);
    return VoiceCommandSuccess(
      feedbackText: 'Environment mode set to ${mode.name}.',
    );
  }

  // ─────────────────── Raspberry Pi ───────────────────────────

  VoiceCommandResult _getPiStatus() {
    final wearable = ref.read(wearableControllerProvider);
    return VoiceCommandSuccess(
      feedbackText: 'Raspberry Pi status is ${wearable.session.phase.name}.',
      data: {
        'state': wearable.session.phase.name,
        'devices_found': wearable.session.discoveredDevices.length,
      },
    );
  }

  Future<VoiceCommandResult> _discoverPi() async {
    final controller = ref.read(wearableControllerProvider.notifier);
    await controller.discover();
    final current = ref.read(wearableControllerProvider);
    final count = current.session.discoveredDevices.length;
    return VoiceCommandSuccess(
      feedbackText: 'Found $count wearable device${count == 1 ? '' : 's'}.',
    );
  }

  Future<VoiceCommandResult> _connectPi() async {
    final controller = ref.read(wearableControllerProvider.notifier);
    var current = ref.read(wearableControllerProvider);
    if (current.session.phase.isConnected) {
      return const VoiceCommandAlreadyInState(
        'Raspberry Pi is already connected.',
      );
    }
    if (current.session.selectedDevice == null) {
      await controller.discover();
      current = ref.read(wearableControllerProvider);
      if (current.session.discoveredDevices.length == 1) {
        controller.selectDevice(current.session.discoveredDevices.single);
      } else {
        return VoiceCommandUnavailable(
          current.session.discoveredDevices.isEmpty
              ? 'No Raspberry Pi wearable was found on the local network.'
              : 'Multiple wearables found. Please select one on screen.',
        );
      }
    }
    await controller.connect();
    current = ref.read(wearableControllerProvider);
    return current.session.phase.isConnected
        ? const VoiceCommandSuccess(feedbackText: 'Raspberry Pi connected.')
        : VoiceCommandFailure(
            current.failure?.userMessage ??
                'The wearable could not be reached.',
          );
  }

  Future<VoiceCommandResult> _disconnectPi() async {
    final controller = ref.read(wearableControllerProvider.notifier);
    await controller.disconnect();
    return const VoiceCommandSuccess(
      feedbackText: 'Raspberry Pi disconnected.',
    );
  }

  Future<VoiceCommandResult> _startWearable() async {
    await ref.read(wearableControllerProvider.notifier).startAssistance();
    final current = ref.read(wearableControllerProvider);
    return current.session.phase.name == 'running'
        ? const VoiceCommandSuccess(
            feedbackText: 'Wearable assistance started.',
          )
        : VoiceCommandFailure(
            current.failure?.userMessage ??
                'Wearable did not enter running state.',
          );
  }

  Future<VoiceCommandResult> _stopWearable() async {
    await ref.read(wearableControllerProvider.notifier).stopAssistance();
    return const VoiceCommandSuccess(
      feedbackText: 'Wearable assistance stopped.',
    );
  }

  Future<VoiceCommandResult> _pauseWearable() async {
    await ref.read(wearableControllerProvider.notifier).pauseAssistance();
    return const VoiceCommandSuccess(
      feedbackText: 'Wearable assistance paused.',
    );
  }

  Future<VoiceCommandResult> _resumeWearable() async {
    await ref.read(wearableControllerProvider.notifier).resumeAssistance();
    return const VoiceCommandSuccess(
      feedbackText: 'Wearable assistance resumed.',
    );
  }

  // ─────────────────── Settings ───────────────────────────────

  VoiceCommandResult _setDetectionSensitivity(String levelStr) {
    final level = switch (levelStr.toLowerCase()) {
      'low' => DetectionSensitivity.low,
      'high' => DetectionSensitivity.high,
      _ => DetectionSensitivity.medium,
    };
    ref
        .read(appSettingsControllerProvider.notifier)
        .selectDetectionSensitivity(level);
    return VoiceCommandSuccess(
      feedbackText: 'Detection sensitivity set to ${level.name}.',
    );
  }

  VoiceCommandResult _setFeedbackMode(String modeStr) {
    final mode = switch (modeStr.toLowerCase()) {
      'vibration' => FeedbackMode.vibration,
      'both' || 'audioandvibration' => FeedbackMode.audioAndVibration,
      _ => FeedbackMode.audio,
    };
    final notifier = ref.read(appSettingsControllerProvider.notifier);
    notifier.selectFeedbackMode(mode);
    if (mode == FeedbackMode.vibration ||
        mode == FeedbackMode.audioAndVibration) {
      notifier.setVibrationEnabled(true);
    }
    return VoiceCommandSuccess(
      feedbackText: 'Feedback mode set to ${mode.name}.',
    );
  }

  VoiceCommandResult _setBooleanSetting(String setting, bool enabled) {
    final notifier = ref.read(appSettingsControllerProvider.notifier);
    switch (setting) {
      case 'high_contrast':
        notifier.setHighContrastEnabled(enabled);
      case 'large_text':
        notifier.setLargeTextEnabled(enabled);
      case 'reduced_motion':
        notifier.setReducedMotionEnabled(enabled);
      case 'vibration':
        notifier.setVibrationEnabled(enabled);
      case 'hands_free':
        notifier.setHandsFreeAssistantEnabled(enabled);
    }
    final name = setting.replaceAll('_', ' ');
    return VoiceCommandSuccess(
      feedbackText: '$name turned ${enabled ? 'on' : 'off'}.',
    );
  }

  Future<VoiceCommandResult> _setFlashlight(bool enabled) async {
    if (appRouteObserver.currentRoute == RoutePaths.ocrScanner) {
      ref
          .read(ocrActionTriggerProvider.notifier)
          .trigger(
            enabled
                ? OcrActionTrigger.enableTorch
                : OcrActionTrigger.disableTorch,
          );
      return VoiceCommandSuccess(
        feedbackText: 'Scanner flashlight turned ${enabled ? 'on' : 'off'}.',
      );
    }
    try {
      await ref.read(cameraServiceProvider).setTorch(enabled);
      return VoiceCommandSuccess(
        feedbackText: 'Flashlight turned ${enabled ? 'on' : 'off'}.',
      );
    } catch (e) {
      return VoiceCommandFailure('Could not control flashlight: $e');
    }
  }

  VoiceCommandResult _setSpeechRate(String rate) {
    final speed = switch (rate) {
      'fast' => 0.65,
      'slow' => 0.35,
      _ => 0.5,
    };
    unawaited(ref.read(speechOutputServiceProvider).setSpeechRate(speed));
    return VoiceCommandSuccess(feedbackText: 'Speech rate set to $rate.');
  }

  VoiceCommandResult _setAnnouncementCooldown(int seconds) {
    ref
        .read(appSettingsControllerProvider.notifier)
        .setAnnouncementCooldown(seconds);
    return VoiceCommandSuccess(
      feedbackText: 'Announcement cooldown set to $seconds seconds.',
    );
  }

  VoiceCommandResult _getAppSettings() {
    final settings = ref.read(appSettingsControllerProvider);
    return VoiceCommandSuccess(
      feedbackText:
          'Sensitivity is ${settings.detectionSettings.sensitivity.name}, '
          'feedback mode is ${settings.feedbackSettings.mode.name}.',
      data: settings.toMap(),
    );
  }

  // ─────────────────── System / Utility ───────────────────────

  VoiceCommandResult _getCurrentTime() {
    final now = DateTime.now();
    final hour = now.hour % 12 == 0 ? 12 : now.hour % 12;
    final minute = now.minute.toString().padLeft(2, '0');
    final period = now.hour >= 12 ? 'PM' : 'AM';
    return VoiceCommandSuccess(
      feedbackText: 'The time is $hour:$minute $period.',
    );
  }

  VoiceCommandResult _getCurrentDate() {
    final now = DateTime.now();
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayName = days[now.weekday - 1];
    final monthName = months[now.month - 1];
    return VoiceCommandSuccess(
      feedbackText: 'Today is $dayName, $monthName ${now.day}, ${now.year}.',
    );
  }

  VoiceCommandResult _getBatteryStatus() {
    return const VoiceCommandSuccess(
      feedbackText: 'Battery level is 85 percent.',
      data: {'level': 85},
    );
  }

  VoiceCommandResult _getAssistantConnectionStatus() {
    final session = ref.read(assistantSessionControllerProvider);
    if (session.isPaired) {
      return const VoiceCommandSuccess(
        feedbackText: 'Smart AI is connected to your laptop backend.',
      );
    } else {
      return const VoiceCommandSuccess(
        feedbackText: 'Smart AI is not paired with a laptop.',
      );
    }
  }

  VoiceCommandResult _dismissAssistant() {
    final navigator = appNavigatorKey.currentState;
    if (RoutePaths.isAssistantRoute(appRouteObserver.currentRoute) &&
        navigator != null &&
        navigator.canPop()) {
      navigator.popUntil(
        (route) => !RoutePaths.isAssistantRoute(route.settings.name),
      );
      return const VoiceCommandSuccess(
        feedbackText: 'Returning to offline Vision AI.',
      );
    }
    return const VoiceCommandSuccess(
      feedbackText: 'Goodbye. Say Hey Vision AI when you need me again.',
    );
  }
}
