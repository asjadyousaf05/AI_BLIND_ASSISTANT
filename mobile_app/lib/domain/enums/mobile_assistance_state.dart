/// Unified state for the Mobile Mode assistance session.
///
/// Only valid transitions are enforced by [AssistanceController].
enum MobileAssistanceState {
  /// No session active. Ready to start.
  idle,

  /// Camera permission has not been granted.
  permissionRequired,

  /// Camera hardware is being initialised.
  initialisingCamera,

  /// TFLite model is being loaded.
  loadingModel,

  /// Camera and model are ready. User may start.
  ready,

  /// Startup sequence is in progress.
  starting,

  /// Detection pipeline is active and producing feedback.
  active,

  /// Session was paused by a lifecycle event.
  paused,

  /// Shutdown sequence is in progress.
  stopping,

  /// A recoverable or unrecoverable error occurred.
  error;

  String get label => switch (this) {
    MobileAssistanceState.idle => 'Idle',
    MobileAssistanceState.permissionRequired => 'Permission required',
    MobileAssistanceState.initialisingCamera => 'Initialising camera',
    MobileAssistanceState.loadingModel => 'Loading model',
    MobileAssistanceState.ready => 'Ready',
    MobileAssistanceState.starting => 'Starting',
    MobileAssistanceState.active => 'Detecting',
    MobileAssistanceState.paused => 'Paused',
    MobileAssistanceState.stopping => 'Stopping',
    MobileAssistanceState.error => 'Error',
  };

  bool get isActive => this == MobileAssistanceState.active;
  bool get isBusy =>
      this == MobileAssistanceState.starting ||
      this == MobileAssistanceState.stopping ||
      this == MobileAssistanceState.initialisingCamera ||
      this == MobileAssistanceState.loadingModel;
  bool get canStart =>
      this == MobileAssistanceState.idle ||
      this == MobileAssistanceState.ready ||
      this == MobileAssistanceState.paused ||
      this == MobileAssistanceState.error;
  bool get canStop =>
      this == MobileAssistanceState.active ||
      this == MobileAssistanceState.paused;
  bool get canPause => this == MobileAssistanceState.active;
}
