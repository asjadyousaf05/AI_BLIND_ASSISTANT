/// Safety circuit breaker to prevent command loops.
///
/// If the same intent type fires N+ times within the window without
/// distinct user sessions, the breaker trips and suppresses further
/// executions until the window expires or a manual reset occurs.
class CommandCircuitBreaker {
  CommandCircuitBreaker({
    this.maxRepeats = 3,
    this.window = const Duration(seconds: 5),
  });

  final int maxRepeats;
  final Duration window;

  final Map<String, List<DateTime>> _intentHistory = {};
  bool _tripped = false;

  /// Whether the circuit breaker is currently tripped.
  bool get isTripped => _tripped;

  /// Records an intent execution. Returns true if the execution is allowed,
  /// false if the circuit breaker has tripped.
  bool recordAndCheck(String intentName) {
    final now = DateTime.now();
    final history = _intentHistory.putIfAbsent(intentName, () => []);

    // Remove entries outside the window.
    history.removeWhere((t) => now.difference(t) > window);
    history.add(now);

    if (history.length >= maxRepeats) {
      _tripped = true;
      return false;
    }
    return true;
  }

  /// Resets the circuit breaker (e.g. after context change or manual reset).
  void reset() {
    _intentHistory.clear();
    _tripped = false;
  }

  /// Resets history for a specific intent.
  void resetIntent(String intentName) {
    _intentHistory.remove(intentName);
    if (_intentHistory.isEmpty) {
      _tripped = false;
    }
  }
}
