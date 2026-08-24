/// Sealed class hierarchy for all canonical voice intents.
///
/// Every voice-controllable action in the application is represented by
/// exactly one [VoiceIntent] variant. The intent resolver produces these
/// from raw transcript text; the kernel authorizes and executes them.
///
/// This is a domain type with no Flutter or infrastructure dependency.
sealed class VoiceIntent {
  const VoiceIntent();
}

// ─────────────────────────── Emergency ────────────────────────────

/// Stop all active assistance, audio, and detection immediately.
class EmergencyStop extends VoiceIntent {
  const EmergencyStop();
}

/// Silence all TTS/audio output without stopping features.
class Silence extends VoiceIntent {
  const Silence();
}

// ─────────────────────────── Navigation ───────────────────────────

class NavigateHome extends VoiceIntent {
  const NavigateHome();
}

class NavigateSettings extends VoiceIntent {
  const NavigateSettings();
}

class NavigateScanner extends VoiceIntent {
  const NavigateScanner();
}

class NavigateSmartAi extends VoiceIntent {
  const NavigateSmartAi();
}

class NavigateMobileAssistance extends VoiceIntent {
  const NavigateMobileAssistance();
}

class NavigateRaspberryPi extends VoiceIntent {
  const NavigateRaspberryPi();
}

class NavigateModeSelection extends VoiceIntent {
  const NavigateModeSelection();
}

class NavigateSafety extends VoiceIntent {
  const NavigateSafety();
}

class NavigateHelp extends VoiceIntent {
  const NavigateHelp();
}

class NavigateBack extends VoiceIntent {
  const NavigateBack();
}

// ──────────────────────── Mobile Detection ────────────────────────

class StartMobileDetection extends VoiceIntent {
  const StartMobileDetection();
}

class StopMobileDetection extends VoiceIntent {
  const StopMobileDetection();
}

class PauseMobileDetection extends VoiceIntent {
  const PauseMobileDetection();
}

class ResumeMobileDetection extends VoiceIntent {
  const ResumeMobileDetection();
}

class GetMobileDetectionStatus extends VoiceIntent {
  const GetMobileDetectionStatus();
}

class ReadRecentDetections extends VoiceIntent {
  const ReadRecentDetections();
}

// ──────────────────────── Document Scanner ────────────────────────

class ScanDocument extends VoiceIntent {
  const ScanDocument();
}

class RescanDocument extends VoiceIntent {
  const RescanDocument();
}

class ReadDocumentAgain extends VoiceIntent {
  const ReadDocumentAgain();
}

// ──────────────────── Document Reader Controls ───────────────────

class ReadingPause extends VoiceIntent {
  const ReadingPause();
}

class ReadingResume extends VoiceIntent {
  const ReadingResume();
}

class ReadingNext extends VoiceIntent {
  const ReadingNext();
}

class ReadingPrevious extends VoiceIntent {
  const ReadingPrevious();
}

class ReadingRepeat extends VoiceIntent {
  const ReadingRepeat();
}

class ReadingRestart extends VoiceIntent {
  const ReadingRestart();
}

class ReadingLast extends VoiceIntent {
  const ReadingLast();
}

/// Reads from a one-based visible line number in the document reader.
class ReadingGoToLine extends VoiceIntent {
  final int lineNumber;
  const ReadingGoToLine(this.lineNumber);
}

class ReadingSpell extends VoiceIntent {
  const ReadingSpell();
}

class SetReadingProfile extends VoiceIntent {
  final String profile; // 'learning', 'skim', 'normal'
  const SetReadingProfile(this.profile);
}

class SwitchScannerCamera extends VoiceIntent {
  const SwitchScannerCamera();
}

class CopyScannedText extends VoiceIntent {
  const CopyScannedText();
}

// ──────────────────────── Environment Mode ───────────────────────

class SetEnvironmentMode extends VoiceIntent {
  final String mode; // 'indoor', 'outdoor', 'auto'
  const SetEnvironmentMode(this.mode);
}

// ──────────────────────── Raspberry Pi ────────────────────────────

class GetPiStatus extends VoiceIntent {
  const GetPiStatus();
}

class DiscoverPi extends VoiceIntent {
  const DiscoverPi();
}

class ConnectPi extends VoiceIntent {
  const ConnectPi();
}

class DisconnectPi extends VoiceIntent {
  const DisconnectPi();
}

class StartWearable extends VoiceIntent {
  const StartWearable();
}

class StopWearable extends VoiceIntent {
  const StopWearable();
}

class PauseWearable extends VoiceIntent {
  const PauseWearable();
}

class ResumeWearable extends VoiceIntent {
  const ResumeWearable();
}

// ──────────────────────── Settings ────────────────────────────────

class SetDetectionSensitivity extends VoiceIntent {
  final String level; // 'low', 'medium', 'high'
  const SetDetectionSensitivity(this.level);
}

class SetFeedbackMode extends VoiceIntent {
  final String mode; // 'audio', 'vibration', 'both'
  const SetFeedbackMode(this.mode);
}

class SetBooleanSetting extends VoiceIntent {
  final String
  setting; // 'high_contrast', 'large_text', 'reduced_motion', 'vibration', 'hands_free'
  final bool enabled;
  const SetBooleanSetting(this.setting, {required this.enabled});
}

class SetFlashlight extends VoiceIntent {
  final bool enabled;
  const SetFlashlight({required this.enabled});
}

class SetSpeechRate extends VoiceIntent {
  final String rate; // 'fast', 'slow', 'normal'
  const SetSpeechRate(this.rate);
}

class SetAnnouncementCooldown extends VoiceIntent {
  final int seconds;
  const SetAnnouncementCooldown(this.seconds);
}

class GetAppSettings extends VoiceIntent {
  const GetAppSettings();
}

// ──────────────────────── System / Utility ────────────────────────

class GetCurrentTime extends VoiceIntent {
  const GetCurrentTime();
}

class GetCurrentDate extends VoiceIntent {
  const GetCurrentDate();
}

class GetBatteryStatus extends VoiceIntent {
  const GetBatteryStatus();
}

class GetAssistantConnectionStatus extends VoiceIntent {
  const GetAssistantConnectionStatus();
}

// ──────────────────────── Conversation ────────────────────────────

class Greeting extends VoiceIntent {
  const Greeting();
}

class WhatCanYouDo extends VoiceIntent {
  const WhatCanYouDo();
}

class WhoAreYou extends VoiceIntent {
  const WhoAreYou();
}

class Goodbye extends VoiceIntent {
  const Goodbye();
}

class ThankYou extends VoiceIntent {
  const ThankYou();
}

class DismissAssistant extends VoiceIntent {
  const DismissAssistant();
}

// ──────────────────────── Confirmation ────────────────────────────

class ConfirmYes extends VoiceIntent {
  const ConfirmYes();
}

class ConfirmNo extends VoiceIntent {
  const ConfirmNo();
}

// ──────────────────────── Ambiguous / Unknown ────────────────────

/// Multiple intents matched with similar confidence.
class AmbiguousIntent extends VoiceIntent {
  final List<VoiceIntent> candidates;
  const AmbiguousIntent(this.candidates);
}

/// No intent matched the transcript.
class UnknownIntent extends VoiceIntent {
  final String transcript;
  const UnknownIntent(this.transcript);
}
