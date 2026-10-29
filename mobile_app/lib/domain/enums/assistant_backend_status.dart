/// Reachability of the saved laptop, independent of phone-local voice control.
enum AssistantBackendStatus {
  notChecked,
  checking,
  reachable,
  unavailable,
  incompatible,
  authenticationFailed;

  String get label => switch (this) {
    notChecked => 'Laptop connection not checked',
    checking => 'Connecting to laptop assistant',
    reachable => 'Laptop assistant is reachable',
    unavailable => 'Laptop assistant unavailable',
    incompatible => 'Laptop assistant version is incompatible',
    authenticationFailed => 'Pair with the laptop assistant again',
  };
}
