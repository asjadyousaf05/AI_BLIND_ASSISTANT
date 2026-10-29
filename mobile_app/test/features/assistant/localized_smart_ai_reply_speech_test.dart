import 'dart:async';
import 'package:ai_blind_assistant/domain/services/smart_ai_cloud_service.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/localized_smart_ai_reply_speech.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_tts/flutter_tts.dart';

class _Voices extends FlutterTts {
  List<Map<String, dynamic>> voices = [
    {'name': 'english-offline', 'locale': 'en-US', 'network_required': '0'},
    {'name': 'urdu-india-offline', 'locale': 'ur-IN', 'network_required': '0'},
    {
      'name': 'urdu-pakistan-online',
      'locale': 'ur-PK',
      'network_required': '1',
    },
    {
      'name': 'urdu-pakistan-offline',
      'locale': 'ur-PK',
      'network_required': '0',
    },
  ];
  final selected = <Map<String, String>>[];
  final restored = <String>[];
  Completer<dynamic>? voicesGate;
  Completer<dynamic>? selectionGate;
  int selectionResult = 1;
  @override
  Future<dynamic> get getVoices async =>
      voicesGate == null ? voices : await voicesGate!.future;
  @override
  Future<dynamic> setVoice(Map<String, String> voice) async {
    selected.add(voice);
    return selectionGate == null
        ? selectionResult
        : await selectionGate!.future;
  }

  @override
  Future<dynamic> setLanguage(String language) async {
    restored.add(language);
    return 1;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Voices tts;
  late LocalizedSmartAiReplySpeech service;
  late List<String> spoken;
  Completer<void>? speechGate;
  setUp(() {
    tts = _Voices();
    spoken = [];
    speechGate = null;
    service = LocalizedSmartAiReplySpeech(
      tts: tts,
      speakExisting: (text) async {
        spoken.add(text);
        await speechGate?.future;
      },
      stopExisting: () async {
        if (speechGate != null && !speechGate!.isCompleted) {
          speechGate!.complete();
        }
      },
    );
  });
  test(
    'releasing idle or paused Smart AI cannot stop newer local feedback',
    () async {
      var stops = 0;
      final pending = Completer<bool>();
      var began = false;
      final player = LocalizedSmartAiReplySpeech(
        tts: tts,
        speakExisting: (_) async {},
        stopExisting: () async {
          stops++;
          if (began && !pending.isCompleted) pending.complete(false);
        },
        speakWithProgress: (_, _) async {
          began = true;
          return pending.future;
        },
      );
      await player.stop();
      expect(stops, 0);
      final reply = player.speak('An answer.');
      while (!began) {
        await Future<void>.delayed(Duration.zero);
      }
      await player.pause();
      final beforeLocalFeedback = stops;
      await player.stop();
      await reply;
      expect(stops, beforeLocalFeedback);
      await player.stop();
      expect(stops, beforeLocalFeedback);
    },
  );

  test(
    'Urdu selects installed Pakistan offline voice and restores English',
    () async {
      await service.speak('آپ کیسے ہیں؟');
      expect(tts.selected.single['name'], 'urdu-pakistan-offline');
      expect(spoken, ['آپ کیسے ہیں؟']);
      expect(tts.restored, ['en-US']);
    },
  );
  test('English selects English and never a network Urdu voice', () async {
    await service.speak('A brief reply.');
    expect(tts.selected.single['name'], 'english-offline');
    expect(tts.restored, ['en-US']);
  });
  test(
    'installed Urdu India voice is usable when Pakistan voice is absent',
    () async {
      tts.voices.removeWhere((v) => v['name'] == 'urdu-pakistan-offline');
      await service.speak('یہ ایک مختصر جواب ہے۔');
      expect(tts.selected.single['name'], 'urdu-india-offline');
    },
  );
  test(
    'missing offline Urdu gives actionable error without English mispronunciation',
    () async {
      tts.voices.removeWhere(
        (v) =>
            '${v['name']}'.endsWith('offline') &&
            '${v['locale']}'.startsWith('ur'),
      );
      await expectLater(
        service.speak('سلام'),
        throwsA(
          isA<SmartAiCloudException>().having(
            (e) => e.message,
            'recovery',
            contains('No offline Urdu voice'),
          ),
        ),
      );
      expect(spoken, isEmpty);
      expect(tts.selected, isEmpty);
    },
  );
  test('voice data flagged not installed is never selected', () async {
    tts.voices
        .where((v) => '${v['locale']}'.startsWith('ur'))
        .forEach((v) => v['features'] = 'notInstalled');
    await expectLater(
      service.speak('سلام'),
      throwsA(isA<SmartAiCloudException>()),
    );
    expect(tts.selected, isEmpty);
  });
  test(
    'cancelling pending voice enumeration prevents speech and locale changes',
    () async {
      tts.voicesGate = Completer<dynamic>();
      final turn = service.speak('سلام');
      await Future<void>.delayed(Duration.zero);
      final stopped = service.stop();
      tts.voicesGate!.complete(tts.voices);
      await Future.wait([turn, stopped]);
      expect(tts.selected, isEmpty);
      expect(spoken, isEmpty);
    },
  );
  test(
    'cancelling during voice selection restores English after late selection',
    () async {
      tts.selectionGate = Completer<dynamic>();
      final turn = service.speak('سلام');
      while (tts.selected.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      final stopped = service.stop();
      tts.selectionGate!.complete(1);
      await Future.wait([turn, stopped]);
      expect(spoken, isEmpty);
      expect(tts.restored, ['en-US']);
    },
  );
  test(
    'failed voice selection restores English and does not speak with wrong locale',
    () async {
      tts.selectionResult = 0;
      await expectLater(
        service.speak('سلام'),
        throwsA(isA<SmartAiCloudException>()),
      );
      expect(spoken, isEmpty);
      expect(tts.restored, ['en-US']);
    },
  );
  test(
    'stopping spoken Urdu finishes awaiting speech and restores English once',
    () async {
      // Wait until voice selection before adding the pending native speech gate.
      tts.selectionGate = Completer<dynamic>();
      final turn = service.speak('سلام');
      while (tts.selected.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      speechGate = Completer<void>();
      tts.selectionGate!.complete(1);
      while (spoken.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await service.stop();
      await turn;
      expect(tts.restored, ['en-US']);
    },
  );

  test(
    'pause preserves the pending reply and resumes from the last reported word',
    () async {
      Completer<void>? native;
      void Function(int)? progress;
      final pieces = <String>[];
      final player = LocalizedSmartAiReplySpeech(
        tts: tts,
        speakExisting: (_) async {},
        stopExisting: () async {
          if (native != null && !native!.isCompleted) native!.complete();
        },
        speakWithProgress: (text, onProgress) {
          pieces.add(text);
          progress = onProgress;
          native = Completer<void>();
          return native!.future.then((_) => true);
        },
      );
      var finished = false;
      final turn = player.speak('One two three.').then((_) => finished = true);
      while (pieces.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      progress!(4);
      await player.pause();
      expect(finished, false);
      expect(tts.restored, ['en-US']);
      await player.resume();
      while (pieces.length < 2) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(pieces, ['One two three.', 'two three.']);
      native!.complete();
      await turn;
      expect(finished, true);
      expect(tts.restored, ['en-US', 'en-US']);
    },
  );

  test(
    'cancelling paused Urdu finishes the caller and cannot resume stale speech',
    () async {
      Completer<void>? native;
      final pieces = <String>[];
      final player = LocalizedSmartAiReplySpeech(
        tts: tts,
        speakExisting: (_) async {},
        stopExisting: () async {
          if (native != null && !native!.isCompleted) native!.complete();
        },
        speakWithProgress: (text, onProgress) {
          pieces.add(text);
          native = Completer<void>();
          return native!.future.then((_) => true);
        },
      );
      final turn = player.speak('یہ ایک مختصر جواب ہے۔');
      while (pieces.isEmpty) {
        await Future<void>.delayed(Duration.zero);
      }
      await player.pause();
      await player.stop();
      await turn;
      await player.resume();
      expect(pieces.length, 1);
      expect(tts.restored, ['en-US']);
    },
  );
  test(
    'external local speech interruption cannot queue another reply chunk',
    () async {
      final pieces = <String>[];
      final player = LocalizedSmartAiReplySpeech(
        tts: tts,
        speakExisting: (_) async {},
        stopExisting: () async {},
        speakWithProgress: (text, onProgress) async {
          pieces.add(text);
          return false;
        },
      );
      await expectLater(
        player.speak(List.filled(80, 'word').join(' ')),
        throwsA(
          isA<SmartAiCloudException>().having(
            (e) => e.message,
            'recovery',
            contains('Read last answer aloud'),
          ),
        ),
      );
      expect(pieces.length, 1);
      expect(tts.restored, ['en-US']);
    },
  );
}
