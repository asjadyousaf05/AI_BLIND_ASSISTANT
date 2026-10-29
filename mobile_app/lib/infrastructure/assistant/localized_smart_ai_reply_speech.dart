import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import '../../domain/services/smart_ai_cloud_service.dart';
import '../../domain/services/smart_ai_reply_speech_service.dart';
import '../../domain/services/smart_ai_interaction_policy.dart';

class _ReplyPlayback {
  _ReplyPlayback(this.text);
  final String text;
  int offset = 0;
  int attempt = 0;
  bool paused = false;
  Completer<void>? resumeGate;
}

/// Selects installed offline voices only for Smart AI's existing shared speech
/// owner. Serialized locale changes cannot outlive cancellation or screen exit.
class LocalizedSmartAiReplySpeech implements SmartAiReplySpeechService {
  LocalizedSmartAiReplySpeech({
    required this._tts,
    required this._speakExisting,
    required this._stopExisting,
    this._speakWithProgress,
  });

  final FlutterTts _tts;
  final Future<void> Function(String) _speakExisting;
  final Future<void> Function() _stopExisting;
  final Future<bool> Function(String text, void Function(int start) onProgress)?
  _speakWithProgress;
  Future<void> _voiceWork = Future.value();
  int _generation = 0;
  bool _changedVoice = false;
  _ReplyPlayback? _playback;
  Future<void>? _pausing;

  Future<void> _serialize(Future<void> Function() action) {
    final next = _voiceWork.then((_) => action());
    _voiceWork = next.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return next;
  }

  @override
  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;
    final generation = ++_generation;
    if (_playback?.resumeGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    final playback = _ReplyPlayback(text);
    _playback = playback;
    await _stopExisting();
    try {
      while (generation == _generation && playback.offset < text.length) {
        if (playback.paused) {
          await playback.resumeGate!.future;
          continue;
        }
        await _serialize(() async {
          if (generation != _generation || playback.paused) return;
          final urdu = SmartAiInteractionPolicy.urduScript.hasMatch(text);
          final language = urdu ? 'ur' : 'en';
          final preferred = urdu ? 'ur-PK' : 'en-US';
          final raw = await _tts.getVoices.timeout(const Duration(seconds: 3));
          if (generation != _generation || playback.paused) return;
          final voices = raw is List
              ? raw.whereType<Map>().where((v) {
                  final locale = '${v['locale']}'.replaceAll('_', '-');
                  return (locale == language ||
                          locale.startsWith('$language-')) &&
                      (v['network_required'] == '0' ||
                          v['network_required'] == false) &&
                      !'${v['features'] ?? ''}'.toLowerCase().contains(
                        'notinstalled',
                      ) &&
                      v['name'] is String;
                }).toList()
              : <Map>[];
          voices.sort((a, b) {
            final aPreferred =
                '${a['locale']}'.replaceAll('_', '-') == preferred;
            final bPreferred =
                '${b['locale']}'.replaceAll('_', '-') == preferred;
            return aPreferred == bPreferred
                ? 0
                : aPreferred
                ? -1
                : 1;
          });
          if (voices.isEmpty) {
            throw SmartAiCloudException(
              'No offline ${urdu ? 'Urdu' : 'English'} voice is installed. Install its voice data in Android text-to-speech settings, then tap Read last answer aloud.',
            );
          }
          final voice = voices.first;
          _changedVoice = true;
          final selected = await _tts.setVoice({
            'name': voice['name'] as String,
            'locale': voice['locale'] as String,
          });
          if (selected != 1) {
            throw const SmartAiCloudException(
              'The phone could not select the reply voice. Check text-to-speech settings and tap Read last answer aloud.',
            );
          }
        });
        if (generation != _generation) return;
        if (playback.paused) continue;
        final attempt = ++playback.attempt;
        final start = playback.offset;
        var end = text.length;
        // Keep shared sentence playback within its native completion budget.
        if (_speakWithProgress != null && end - start > 180) {
          end = start + 180;
          final space = text.lastIndexOf(' ', end);
          if (space > start) end = space + 1;
          if (end < text.length &&
              text.codeUnitAt(end - 1) >= 0xd800 &&
              text.codeUnitAt(end - 1) <= 0xdbff) {
            end--;
          }
        }
        try {
          if (_speakWithProgress != null) {
            final completed = await _speakWithProgress(
              text.substring(start, end),
              (offset) {
                if (generation == _generation &&
                    attempt == playback.attempt &&
                    !playback.paused) {
                  // Resume at the last reported word, never skip an unfinished word.
                  playback.offset = start + offset.clamp(0, end - start);
                }
              },
            );
            if (!completed &&
                generation == _generation &&
                attempt == playback.attempt &&
                !playback.paused) {
              throw const SmartAiCloudException(
                'Smart AI speech was interrupted by local controls. Tap Read last answer aloud to replay it.',
              );
            }
          } else {
            await _speakExisting(text.substring(start, end));
          }
        } catch (_) {
          if (generation == _generation &&
              attempt == playback.attempt &&
              !playback.paused) {
            rethrow;
          }
        }
        if (generation == _generation &&
            attempt == playback.attempt &&
            !playback.paused) {
          playback.offset = end;
        }
      }
    } finally {
      await _serialize(() async {
        if (generation == _generation) {
          _playback = null;
          await _restoreEnglish();
        }
      });
    }
  }

  Future<void> _restoreEnglish() async {
    if (!_changedVoice) return;
    final restored = await _tts.setLanguage('en-US');
    if (restored != 1) {
      throw const SmartAiCloudException(
        'The phone could not restore its English voice. Reopen Smart AI audio settings.',
      );
    }
    _changedVoice = false;
  }

  @override
  Future<void> stop() async {
    final generation = ++_generation;
    final playback = _playback;
    _playback = null;
    if (playback?.resumeGate case final gate? when !gate.isCompleted) {
      gate.complete();
    }
    // Releasing an idle/paused Smart AI screen must not stop a newer Vision AI
    // navigation acknowledgement on the shared speech engine.
    if (playback != null && !playback.paused) await _stopExisting();
    await _pausing;
    await _serialize(() async {
      if (generation == _generation) await _restoreEnglish();
    });
  }

  @override
  Future<void> pause() {
    final playback = _playback;
    if (playback == null || playback.paused) return _pausing ?? Future.value();
    playback.paused = true;
    playback.attempt++;
    playback.resumeGate = Completer<void>();
    final operation = _pause(playback);
    _pausing = operation;
    return operation.whenComplete(() {
      if (identical(_pausing, operation)) _pausing = null;
    });
  }

  Future<void> _pause(_ReplyPlayback playback) async {
    await _stopExisting();
    await _serialize(() async {
      if (identical(_playback, playback) && playback.paused) {
        await _restoreEnglish();
      }
    });
  }

  @override
  Future<void> resume() async {
    final playback = _playback;
    await _pausing;
    if (playback == null ||
        !identical(_playback, playback) ||
        !playback.paused) {
      return;
    }
    playback.paused = false;
    final gate = playback.resumeGate;
    if (gate != null && !gate.isCompleted) gate.complete();
  }
}
