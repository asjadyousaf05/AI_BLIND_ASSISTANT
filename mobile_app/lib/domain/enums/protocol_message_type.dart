/// The complete version 1 wearable protocol vocabulary.
enum ProtocolMessageType {
  hello('hello'),
  authentication('authentication'),
  heartbeat('heartbeat'),
  deviceStatus('device_status'),
  pairRequest('pair_request'),
  pairResult('pair_result'),
  startAssistance('start_assistance'),
  pauseAssistance('pause_assistance'),
  resumeAssistance('resume_assistance'),
  stopAssistance('stop_assistance'),
  changeMode('change_mode'),
  updateSettings('update_settings'),
  requestCurrentSettings('request_current_settings'),
  synchronizeSettings('synchronize_settings'),
  detectionEvent('detection_event'),
  priorityHazardAlert('priority_hazard_alert'),
  cameraStatus('camera_status'),
  cameraError('camera_error'),
  modelStatus('model_status'),
  modelError('model_error'),
  deviceHealth('device_health'),
  acknowledgement('acknowledgement'),
  error('error'),
  revokeCredential('revoke_credential'),
  gracefulDisconnect('graceful_disconnect');

  const ProtocolMessageType(this.wireName);

  final String wireName;

  static ProtocolMessageType fromWireName(String value) {
    return values.firstWhere(
      (type) => type.wireName == value,
      orElse: () =>
          throw FormatException('Unsupported wearable message type: $value'),
    );
  }
}
