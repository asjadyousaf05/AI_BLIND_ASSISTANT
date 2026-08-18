import 'package:ai_blind_assistant/core/accessibility/preferred_text_scaler.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UT-ACC-001 preserves a nonlinear platform scaling curve', () {
    const scaler = PreferredTextScaler(platformScaler: _NonlinearTestScaler());

    expect(scaler.scale(10), 24);
    expect(scaler.scale(30), 54);
  });

  test('UT-ACC-002 bounds the preferred scale factor', () {
    const scaler = PreferredTextScaler(platformScaler: TextScaler.linear(3));

    expect(scaler.scale(10), 25);
    expect(scaler.scale(0), 0);
  });
}

class _NonlinearTestScaler extends TextScaler {
  const _NonlinearTestScaler();

  @override
  double scale(double fontSize) =>
      fontSize < 20 ? fontSize * 2 : fontSize * 1.5;

  @override
  double get textScaleFactor => 2;
}
