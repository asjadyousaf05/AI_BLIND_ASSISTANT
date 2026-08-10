enum AssistanceState {
  idle,
  starting,
  active,
  stopping,
  error;

  bool get isActive => this == AssistanceState.active;
}
