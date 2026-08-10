import 'package:ai_blind_assistant/core/errors/app_failure.dart';
import 'package:ai_blind_assistant/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UT-CORE-001 result maps success and failure branches', () {
    const success = Success<int>(7);
    const failure = Failure<int>(UnknownFailure());

    expect(success.when(success: (value) => value * 2, failure: (_) => 0), 14);

    expect(
      failure.when(
        success: (_) => 'unexpected',
        failure: (appFailure) => appFailure.userMessage,
      ),
      'Something went wrong. Please try again.',
    );
  });
}
