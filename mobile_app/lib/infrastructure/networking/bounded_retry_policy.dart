import 'dart:async';
import 'dart:math';

typedef RetrySleeper = Future<void> Function(Duration delay);

class BoundedRetryPolicy {
  BoundedRetryPolicy({
    this.maximumAttempts = 5,
    this.baseDelay = const Duration(milliseconds: 500),
    this.maximumDelay = const Duration(seconds: 8),
    this.jitterFraction = 0.20,
    Random? random,
  }) : _random = random ?? Random.secure() {
    if (maximumAttempts < 1 ||
        baseDelay.isNegative ||
        maximumDelay < baseDelay ||
        jitterFraction < 0 ||
        jitterFraction > 1) {
      throw ArgumentError('Invalid bounded retry policy');
    }
  }

  final int maximumAttempts;
  final Duration baseDelay;
  final Duration maximumDelay;
  final double jitterFraction;
  final Random _random;

  /// Returns the delay before retry number [retryNumber], where the first
  /// retry is 1. The initial attempt does not use this method.
  Duration delayBeforeRetry(int retryNumber) {
    if (retryNumber < 1 || retryNumber >= maximumAttempts) {
      throw RangeError.range(retryNumber, 1, maximumAttempts - 1);
    }
    final exponential = baseDelay.inMilliseconds * pow(2, retryNumber - 1);
    final capped = min(exponential.round(), maximumDelay.inMilliseconds);
    final multiplier = 1 + ((_random.nextDouble() * 2) - 1) * jitterFraction;
    return Duration(milliseconds: max(0, (capped * multiplier).round()));
  }

  Future<T> execute<T>(
    Future<T> Function(int attempt) operation, {
    bool Function(Object error)? shouldRetry,
    RetrySleeper sleeper = _defaultSleeper,
  }) async {
    Object? lastError;
    StackTrace? lastStackTrace;
    for (var attempt = 1; attempt <= maximumAttempts; attempt++) {
      try {
        return await operation(attempt);
      } on Object catch (error, stackTrace) {
        lastError = error;
        lastStackTrace = stackTrace;
        if (attempt == maximumAttempts ||
            (shouldRetry != null && !shouldRetry(error))) {
          Error.throwWithStackTrace(error, stackTrace);
        }
        await sleeper(delayBeforeRetry(attempt));
      }
    }
    Error.throwWithStackTrace(lastError!, lastStackTrace!);
  }

  static Future<void> _defaultSleeper(Duration delay) =>
      Future<void>.delayed(delay);
}
