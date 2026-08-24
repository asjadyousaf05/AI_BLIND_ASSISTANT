import 'package:flutter/widgets.dart';

abstract final class AppKeys {
  static const startupContinueButton = Key('startup_continue_button');
  static const startupHelpButton = Key('startup_help_button');
  static const homeModeSelectionButton = Key('home_mode_selection_button');
  static const homeMobileAssistanceButton = Key(
    'home_mobile_assistance_button',
  );
  static const homeStopAssistanceButton = Key('home_stop_assistance_button');
  static const homeRaspberryPiButton = Key('home_raspberry_pi_button');
  static const homeSettingsButton = Key('home_settings_button');
  static const homeAboutSafetyButton = Key('home_about_safety_button');
  static const homeHelpButton = Key('home_help_button');
  static const selectMobileModeButton = Key('select_mobile_mode_button');
  static const selectRaspberryPiModeButton = Key(
    'select_raspberry_pi_mode_button',
  );
  static const confirmModeButton = Key('confirm_mode_button');
  static const mobileStartAssistanceButton = Key(
    'mobile_start_assistance_button',
  );
  static const mobileStopAssistanceButton = Key(
    'mobile_stop_assistance_button',
  );
  static const mobilePauseAssistanceButton = Key(
    'mobile_pause_assistance_button',
  );
  static const mobilePermissionButton = Key('mobile_permission_button');
  static const raspberryPiConnectButton = Key('raspberry_pi_connect_button');
  static const raspberryPiScanButton = Key('raspberry_pi_scan_button');
  static const raspberryPiErrorButton = Key('raspberry_pi_error_button');
  static const raspberryPiStatus = Key('raspberry_pi_status');
  static const raspberryPiManualHostField = Key(
    'raspberry_pi_manual_host_field',
  );
  static const raspberryPiManualPortField = Key(
    'raspberry_pi_manual_port_field',
  );
  static const raspberryPiUseManualAddressButton = Key(
    'raspberry_pi_use_manual_address_button',
  );
  static const raspberryPiDisconnectButton = Key(
    'raspberry_pi_disconnect_button',
  );
  static const raspberryPiStartButton = Key('raspberry_pi_start_button');
  static const raspberryPiPauseButton = Key('raspberry_pi_pause_button');
  static const raspberryPiResumeButton = Key('raspberry_pi_resume_button');
  static const raspberryPiStopButton = Key('raspberry_pi_stop_button');
  static const raspberryPiSyncSettingsButton = Key(
    'raspberry_pi_sync_settings_button',
  );
  static const raspberryPiEditSettingsButton = Key(
    'raspberry_pi_edit_settings_button',
  );
  static const raspberryPiForgetButton = Key('raspberry_pi_forget_button');
  static const connectionRetryButton = Key('connection_retry_button');
  static const connectionSwitchMobileButton = Key(
    'connection_switch_mobile_button',
  );
  static const settingsSaveButton = Key('settings_save_button');
  static const settingsCancelButton = Key('settings_cancel_button');
  static const settingsFeedbackAudioButton = Key(
    'settings_feedback_audio_button',
  );
  static const settingsFeedbackVibrationButton = Key(
    'settings_feedback_vibration_button',
  );
  static const settingsFeedbackBothButton = Key(
    'settings_feedback_both_button',
  );
  static const settingsSensitivityLowButton = Key(
    'settings_sensitivity_low_button',
  );
  static const settingsSensitivityMediumButton = Key(
    'settings_sensitivity_medium_button',
  );
  static const settingsSensitivityHighButton = Key(
    'settings_sensitivity_high_button',
  );
  static const permissionsAllowButton = Key('permissions_allow_button');
  static const permissionsContinueButton = Key('permissions_continue_button');
  static const helpPreviousButton = Key('help_previous_button');
  static const helpNextButton = Key('help_next_button');
  static const helpDoneButton = Key('help_done_button');
  // Assistant keys
  static const homeAssistantButton = Key('home_assistant_button');
  static const assistantPushToTalkButton = Key('assistant_push_to_talk_button');
  static const assistantCancelButton = Key('assistant_cancel_button');
  static const assistantStopSpeakingButton = Key(
    'assistant_stop_speaking_button',
  );
  static const assistantRepeatButton = Key('assistant_repeat_button');
  static const assistantTextInputToggle = Key('assistant_text_input_toggle');
  static const assistantTextInput = Key('assistant_text_input');
  static const assistantTextSubmitButton = Key('assistant_text_submit_button');
  static const assistantConfirmActionButton = Key(
    'assistant_confirm_action_button',
  );
  static const assistantCancelActionButton = Key(
    'assistant_cancel_action_button',
  );
  static const assistantSettingsButton = Key('assistant_settings_button');
  static const assistantConnectionButton = Key('assistant_connection_button');
  static const assistantNotPairedBanner = Key('assistant_not_paired_banner');
  static const assistantHostField = Key('assistant_host_field');
  static const assistantPortField = Key('assistant_port_field');
  static const assistantPairingCodeField = Key('assistant_pairing_code_field');
  static const assistantPairButton = Key('assistant_pair_button');
  static const assistantUnpairButton = Key('assistant_unpair_button');
}
