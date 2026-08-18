import '../entities/voice_action_definition.dart';
import '../enums/voice_feature_context.dart';
import '../enums/voice_intent.dart';

/// Central registry of all voice-controllable actions.
///
/// Each action has metadata controlling authorization, confirmation policy,
/// and execution behavior. The kernel queries this registry to authorize
/// commands before execution.
abstract final class VoiceActionRegistry {
  /// Returns the definition for a given intent type, or null if unregistered.
  static VoiceActionDefinition? getDefinition(VoiceIntent intent) =>
      _definitions[intent.runtimeType];

  /// Whether the given intent is allowed in the given context.
  static bool isAllowedIn(VoiceIntent intent, VoiceFeatureContext context) =>
      _definitions[intent.runtimeType]?.isAllowedIn(context) ?? false;

  /// Whether the given intent requires user confirmation.
  static bool requiresConfirmation(VoiceIntent intent) =>
      _definitions[intent.runtimeType]?.requiresConfirmation ?? false;

  /// Whether the given intent is an emergency command.
  static bool isEmergency(VoiceIntent intent) =>
      _definitions[intent.runtimeType]?.isEmergency ?? false;

  static final Map<Type, VoiceActionDefinition> _definitions = {
    // ─────────────────── Emergency ──────────────────────────
    EmergencyStop: const VoiceActionDefinition(
      intentType: EmergencyStop,
      canonicalName: 'emergency_stop',
      allowedContexts: {},
      isEmergency: true,
      interruptsTts: true,
      interruptsDetection: true,
      feedbackText: 'Stopping all assistance and audio.',
    ),
    Silence: const VoiceActionDefinition(
      intentType: Silence,
      canonicalName: 'silence',
      allowedContexts: {},
      isEmergency: true,
      interruptsTts: true,
    ),

    // ─────────────────── Navigation ─────────────────────────
    NavigateHome: const VoiceActionDefinition(
      intentType: NavigateHome,
      canonicalName: 'navigate_home',
      allowedContexts: {},
      feedbackText: 'Going home.',
    ),
    NavigateSettings: const VoiceActionDefinition(
      intentType: NavigateSettings,
      canonicalName: 'navigate_settings',
      allowedContexts: {},
      feedbackText: 'Opening settings.',
    ),
    NavigateScanner: const VoiceActionDefinition(
      intentType: NavigateScanner,
      canonicalName: 'navigate_scanner',
      allowedContexts: {},
      feedbackText: 'Opening document scanner.',
    ),
    NavigateSmartAi: const VoiceActionDefinition(
      intentType: NavigateSmartAi,
      canonicalName: 'navigate_smart_ai',
      allowedContexts: {},
      feedbackText: 'Opening smart AI assistant.',
    ),
    NavigateMobileAssistance: const VoiceActionDefinition(
      intentType: NavigateMobileAssistance,
      canonicalName: 'navigate_mobile_assistance',
      allowedContexts: {},
      feedbackText: 'Opening mobile mode.',
    ),
    NavigateRaspberryPi: const VoiceActionDefinition(
      intentType: NavigateRaspberryPi,
      canonicalName: 'navigate_raspberry_pi',
      allowedContexts: {},
      feedbackText: 'Opening Raspberry Pi.',
    ),
    NavigateModeSelection: const VoiceActionDefinition(
      intentType: NavigateModeSelection,
      canonicalName: 'navigate_mode_selection',
      allowedContexts: {},
      feedbackText: 'Opening mode selection.',
    ),
    NavigateSafety: const VoiceActionDefinition(
      intentType: NavigateSafety,
      canonicalName: 'navigate_safety',
      allowedContexts: {},
      feedbackText: 'Opening safety information.',
    ),
    NavigateHelp: const VoiceActionDefinition(
      intentType: NavigateHelp,
      canonicalName: 'navigate_help',
      allowedContexts: {},
      feedbackText: 'Opening help.',
    ),
    NavigateBack: const VoiceActionDefinition(
      intentType: NavigateBack,
      canonicalName: 'navigate_back',
      allowedContexts: {},
      feedbackText: 'Going back.',
    ),

    // ─────────────────── Mobile Detection ───────────────────
    StartMobileDetection: const VoiceActionDefinition(
      intentType: StartMobileDetection,
      canonicalName: 'start_mobile_detection',
      allowedContexts: {
        VoiceFeatureContext.home,
        VoiceFeatureContext.mobileDetection,
        VoiceFeatureContext.unknown,
      },
      requiresConfirmation: true,
      feedbackText: 'Starting mobile mode detection.',
    ),
    StopMobileDetection: const VoiceActionDefinition(
      intentType: StopMobileDetection,
      canonicalName: 'stop_mobile_detection',
      allowedContexts: {
        VoiceFeatureContext.mobileDetection,
        VoiceFeatureContext.home,
      },
      interruptsDetection: true,
      feedbackText: 'Stopping mobile mode detection.',
    ),
    PauseMobileDetection: const VoiceActionDefinition(
      intentType: PauseMobileDetection,
      canonicalName: 'pause_mobile_detection',
      allowedContexts: {VoiceFeatureContext.mobileDetection},
      feedbackText: 'Pausing mobile mode.',
    ),
    ResumeMobileDetection: const VoiceActionDefinition(
      intentType: ResumeMobileDetection,
      canonicalName: 'resume_mobile_detection',
      allowedContexts: {VoiceFeatureContext.mobileDetection},
      feedbackText: 'Resuming mobile mode.',
    ),
    GetMobileDetectionStatus: const VoiceActionDefinition(
      intentType: GetMobileDetectionStatus,
      canonicalName: 'get_mobile_detection_status',
      allowedContexts: {},
    ),
    ReadRecentDetections: const VoiceActionDefinition(
      intentType: ReadRecentDetections,
      canonicalName: 'read_recent_detections',
      allowedContexts: {
        VoiceFeatureContext.mobileDetection,
        VoiceFeatureContext.home,
      },
    ),

    // ─────────────────── Document Scanner ───────────────────
    ScanDocument: const VoiceActionDefinition(
      intentType: ScanDocument,
      canonicalName: 'scan_document',
      allowedContexts: {
        VoiceFeatureContext.scannerCapture,
        VoiceFeatureContext.scannerReading,
        VoiceFeatureContext.home,
      },
      feedbackText: 'Scanning.',
    ),
    RescanDocument: const VoiceActionDefinition(
      intentType: RescanDocument,
      canonicalName: 'rescan_document',
      allowedContexts: {
        VoiceFeatureContext.scannerCapture,
        VoiceFeatureContext.scannerReading,
      },
      feedbackText: 'Ready to scan.',
    ),
    ReadDocumentAgain: const VoiceActionDefinition(
      intentType: ReadDocumentAgain,
      canonicalName: 'read_document_again',
      allowedContexts: {
        VoiceFeatureContext.scannerReading,
        VoiceFeatureContext.scannerCapture,
      },
      feedbackText: 'Reading again.',
    ),

    // ─────────────── Reader Controls ────────────────────────
    ReadingPause: const VoiceActionDefinition(
      intentType: ReadingPause,
      canonicalName: 'reading_pause',
      allowedContexts: {VoiceFeatureContext.scannerReading},
      interruptsTts: true,
    ),
    ReadingResume: const VoiceActionDefinition(
      intentType: ReadingResume,
      canonicalName: 'reading_resume',
      allowedContexts: {VoiceFeatureContext.scannerReading},
    ),
    ReadingNext: const VoiceActionDefinition(
      intentType: ReadingNext,
      canonicalName: 'reading_next',
      allowedContexts: {VoiceFeatureContext.scannerReading},
      interruptsTts: true,
    ),
    ReadingPrevious: const VoiceActionDefinition(
      intentType: ReadingPrevious,
      canonicalName: 'reading_previous',
      allowedContexts: {VoiceFeatureContext.scannerReading},
      interruptsTts: true,
    ),
    ReadingRepeat: const VoiceActionDefinition(
      intentType: ReadingRepeat,
      canonicalName: 'reading_repeat',
      allowedContexts: {VoiceFeatureContext.scannerReading},
      interruptsTts: true,
    ),
    ReadingRestart: const VoiceActionDefinition(
      intentType: ReadingRestart,
      canonicalName: 'reading_restart',
      allowedContexts: {VoiceFeatureContext.scannerReading},
      interruptsTts: true,
    ),
    ReadingSpell: const VoiceActionDefinition(
      intentType: ReadingSpell,
      canonicalName: 'reading_spell',
      allowedContexts: {VoiceFeatureContext.scannerReading},
      interruptsTts: true,
    ),
    SetReadingProfile: const VoiceActionDefinition(
      intentType: SetReadingProfile,
      canonicalName: 'set_reading_profile',
      allowedContexts: {VoiceFeatureContext.scannerReading},
    ),
    SwitchScannerCamera: const VoiceActionDefinition(
      intentType: SwitchScannerCamera,
      canonicalName: 'switch_scanner_camera',
      allowedContexts: {VoiceFeatureContext.scannerCapture},
    ),
    CopyScannedText: const VoiceActionDefinition(
      intentType: CopyScannedText,
      canonicalName: 'copy_scanned_text',
      allowedContexts: {
        VoiceFeatureContext.scannerReading,
        VoiceFeatureContext.scannerCapture,
      },
    ),

    // ─────────────── Environment Mode ───────────────────────
    SetEnvironmentMode: const VoiceActionDefinition(
      intentType: SetEnvironmentMode,
      canonicalName: 'set_environment_mode',
      allowedContexts: {},
    ),

    // ─────────────── Raspberry Pi ───────────────────────────
    GetPiStatus: const VoiceActionDefinition(
      intentType: GetPiStatus,
      canonicalName: 'get_pi_status',
      allowedContexts: {},
    ),
    DiscoverPi: const VoiceActionDefinition(
      intentType: DiscoverPi,
      canonicalName: 'discover_pi',
      allowedContexts: {},
    ),
    ConnectPi: const VoiceActionDefinition(
      intentType: ConnectPi,
      canonicalName: 'connect_pi',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    DisconnectPi: const VoiceActionDefinition(
      intentType: DisconnectPi,
      canonicalName: 'disconnect_pi',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    StartWearable: const VoiceActionDefinition(
      intentType: StartWearable,
      canonicalName: 'start_wearable',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    StopWearable: const VoiceActionDefinition(
      intentType: StopWearable,
      canonicalName: 'stop_wearable',
      allowedContexts: {},
    ),
    PauseWearable: const VoiceActionDefinition(
      intentType: PauseWearable,
      canonicalName: 'pause_wearable',
      allowedContexts: {},
    ),
    ResumeWearable: const VoiceActionDefinition(
      intentType: ResumeWearable,
      canonicalName: 'resume_wearable',
      allowedContexts: {},
    ),

    // ─────────────── Settings ───────────────────────────────
    SetDetectionSensitivity: const VoiceActionDefinition(
      intentType: SetDetectionSensitivity,
      canonicalName: 'set_detection_sensitivity',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    SetFeedbackMode: const VoiceActionDefinition(
      intentType: SetFeedbackMode,
      canonicalName: 'set_feedback_mode',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    SetBooleanSetting: const VoiceActionDefinition(
      intentType: SetBooleanSetting,
      canonicalName: 'set_boolean_setting',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    SetFlashlight: const VoiceActionDefinition(
      intentType: SetFlashlight,
      canonicalName: 'set_flashlight',
      allowedContexts: {},
    ),
    SetSpeechRate: const VoiceActionDefinition(
      intentType: SetSpeechRate,
      canonicalName: 'set_speech_rate',
      allowedContexts: {},
    ),
    SetAnnouncementCooldown: const VoiceActionDefinition(
      intentType: SetAnnouncementCooldown,
      canonicalName: 'set_announcement_cooldown',
      allowedContexts: {},
      requiresConfirmation: true,
    ),
    GetAppSettings: const VoiceActionDefinition(
      intentType: GetAppSettings,
      canonicalName: 'get_app_settings',
      allowedContexts: {},
    ),

    // ─────────────── System / Utility ───────────────────────
    GetCurrentTime: const VoiceActionDefinition(
      intentType: GetCurrentTime,
      canonicalName: 'get_current_time',
      allowedContexts: {},
    ),
    GetCurrentDate: const VoiceActionDefinition(
      intentType: GetCurrentDate,
      canonicalName: 'get_current_date',
      allowedContexts: {},
    ),
    GetBatteryStatus: const VoiceActionDefinition(
      intentType: GetBatteryStatus,
      canonicalName: 'get_battery_status',
      allowedContexts: {},
    ),
    GetAssistantConnectionStatus: const VoiceActionDefinition(
      intentType: GetAssistantConnectionStatus,
      canonicalName: 'get_assistant_connection_status',
      allowedContexts: {},
    ),

    // ─────────────── Conversation ───────────────────────────
    Greeting: const VoiceActionDefinition(
      intentType: Greeting,
      canonicalName: 'greeting',
      allowedContexts: {},
    ),
    WhatCanYouDo: const VoiceActionDefinition(
      intentType: WhatCanYouDo,
      canonicalName: 'what_can_you_do',
      allowedContexts: {},
    ),
    WhoAreYou: const VoiceActionDefinition(
      intentType: WhoAreYou,
      canonicalName: 'who_are_you',
      allowedContexts: {},
    ),
    Goodbye: const VoiceActionDefinition(
      intentType: Goodbye,
      canonicalName: 'goodbye',
      allowedContexts: {},
    ),
    ThankYou: const VoiceActionDefinition(
      intentType: ThankYou,
      canonicalName: 'thank_you',
      allowedContexts: {},
    ),
    DismissAssistant: const VoiceActionDefinition(
      intentType: DismissAssistant,
      canonicalName: 'dismiss_assistant',
      allowedContexts: {},
    ),

    // ─────────────── Confirmation ───────────────────────────
    ConfirmYes: const VoiceActionDefinition(
      intentType: ConfirmYes,
      canonicalName: 'confirm_yes',
      allowedContexts: {},
    ),
    ConfirmNo: const VoiceActionDefinition(
      intentType: ConfirmNo,
      canonicalName: 'confirm_no',
      allowedContexts: {},
    ),
  };
}
