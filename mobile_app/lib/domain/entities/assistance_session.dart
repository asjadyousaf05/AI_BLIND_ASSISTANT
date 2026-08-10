import '../enums/assistance_state.dart';
import '../enums/operating_mode.dart';

class AssistanceSession {
  const AssistanceSession({
    required this.mode,
    required this.state,
    this.startedAt,
  });

  static const idleMobile = AssistanceSession(
    mode: OperatingMode.mobile,
    state: AssistanceState.idle,
  );

  final OperatingMode mode;
  final AssistanceState state;
  final DateTime? startedAt;

  bool get isActive => state.isActive;

  AssistanceSession copyWith({
    OperatingMode? mode,
    AssistanceState? state,
    DateTime? startedAt,
  }) {
    return AssistanceSession(
      mode: mode ?? this.mode,
      state: state ?? this.state,
      startedAt: startedAt ?? this.startedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is AssistanceSession &&
        other.mode == mode &&
        other.state == state &&
        other.startedAt == startedAt;
  }

  @override
  int get hashCode => Object.hash(mode, state, startedAt);
}
