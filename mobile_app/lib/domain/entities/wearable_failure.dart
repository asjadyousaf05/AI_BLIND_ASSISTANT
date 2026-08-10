import '../enums/wearable_failure_kind.dart';

class WearableFailure {
  const WearableFailure({
    required this.kind,
    required this.code,
    required this.userMessage,
    this.canRetry = true,
  });

  final WearableFailureKind kind;
  final String code;
  final String userMessage;
  final bool canRetry;
}
