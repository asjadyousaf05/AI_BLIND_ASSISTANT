import 'dart:typed_data';

import 'package:ai_blind_assistant/domain/services/document_framing_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DocumentFramingAnalyzer', () {
    const analyzer = DocumentFramingAnalyzer();

    test('returns noDocument on empty plane', () {
      final cue = analyzer.analyzeYPlane(Uint8List(0), width: 100, height: 100);
      expect(cue, FramingCue.noDocument);
    });

    test('returns tooDark on low luminance plane', () {
      final darkBytes = Uint8List(100 * 100);
      darkBytes.fillRange(0, darkBytes.length, 10); // L = 10
      final cue = analyzer.analyzeYPlane(darkBytes, width: 100, height: 100);
      expect(cue, FramingCue.tooDark);
    });

    test('returns tooBright on high luminance plane', () {
      final brightBytes = Uint8List(100 * 100);
      brightBytes.fillRange(0, brightBytes.length, 250); // L = 250
      final cue = analyzer.analyzeYPlane(brightBytes, width: 100, height: 100);
      expect(cue, FramingCue.tooBright);
    });

    test('returns aligned when contrast is centered and well-distributed', () {
      final bytes = Uint8List(120 * 120);
      bytes.fillRange(0, bytes.length, 128);
      // Create horizontal and vertical gradient edges in the center region
      for (int y = 40; y < 80; y++) {
        for (int x = 40; x < 80; x++) {
          bytes[y * 120 + x] = ((x + y) % 2 == 0) ? 50 : 200;
        }
      }
      final cue = analyzer.analyzeYPlane(bytes, width: 120, height: 120);
      expect(cue, FramingCue.aligned);
      expect(cue.spokenGuidance.toLowerCase(), contains('document aligned'));
    });

    test('returns moveHigher when contrast is concentrated at bottom', () {
      final bytes = Uint8List(120 * 120);
      bytes.fillRange(0, bytes.length, 128);
      // High contrast edges only in bottom row (y from 90 to 115)
      for (int y = 90; y < 115; y++) {
        for (int x = 20; x < 100; x++) {
          bytes[y * 120 + x] = ((x + y) % 2 == 0) ? 30 : 220;
        }
      }
      final cue = analyzer.analyzeYPlane(bytes, width: 120, height: 120);
      expect(cue, FramingCue.moveHigher);
      expect(cue.spokenGuidance, contains('Move phone higher'));
    });

    test('returns moveLower when contrast is concentrated at top', () {
      final bytes = Uint8List(120 * 120);
      bytes.fillRange(0, bytes.length, 128);
      // High contrast edges only in top row (y from 5 to 30)
      for (int y = 5; y < 30; y++) {
        for (int x = 20; x < 100; x++) {
          bytes[y * 120 + x] = ((x + y) % 2 == 0) ? 30 : 220;
        }
      }
      final cue = analyzer.analyzeYPlane(bytes, width: 120, height: 120);
      expect(cue, FramingCue.moveLower);
      expect(cue.spokenGuidance, contains('Move phone lower'));
    });
  });
}
