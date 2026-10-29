import 'dart:io';
import 'dart:math';
import 'package:flutter/services.dart';
import '../../domain/services/audio_recorder_service.dart';

/// Uses the existing bounded native 16 kHz mono AAC/M4A recorder, with its own
/// temporary-file namespace. No resampling or additional worker is needed.
class SmartAiAudioRecorder implements AudioRecorderService {
  SmartAiAudioRecorder({this._directory});
  static const _channel = MethodChannel(
    'ai_blind_assistant/assistant_audio_recorder',
  );
  Directory? _directory;
  String? _path;
  bool _recording = false;
  int _generation = 0;
  Future<void>? _starting;
  @override
  bool get isRecording => _recording;

  @override
  Future<void> startRecording() {
    if (_starting != null || _path != null) {
      throw const AudioRecorderException('A recording is already in progress.');
    }
    final operation = _start();
    _starting = operation;
    return operation.whenComplete(() => _starting = null);
  }

  Future<void> _start() async {
    final generation = _generation;
    try {
      var directory = _directory;
      if (directory == null) {
        final path = await _channel.invokeMethod<String>(
          'getSmartAiCacheDirectory',
        );
        if (path == null || path.isEmpty) {
          throw const AudioRecorderException(
            'Phone recording storage is unavailable. Reopen Smart AI.',
          );
        }
        directory = Directory(path);
        _directory = directory;
      }
      // Remove this feature's abandoned cache clips after a previous process
      // death. Do not inspect, log or touch legacy/Vision AI files.
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith('smart_ai_audio_') &&
            entity.path.endsWith('.m4a')) {
          await entity.delete();
        }
      }
      if (generation != _generation) {
        throw const AudioRecorderException('Recording cancelled.');
      }
      _path =
          '${directory.path}/smart_ai_audio_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 32)}.m4a';
      final started = await _channel.invokeMethod<bool>('startRecording', {
        'path': _path,
      });
      if (started != true || generation != _generation) {
        await _channel.invokeMethod<void>('cancelRecording');
        throw const AudioRecorderException(
          'Recording could not start. Please try again.',
        );
      }
      _recording = true;
    } catch (error) {
      if (_path != null) {
        try {
          await _channel.invokeMethod<void>('cancelRecording');
        } catch (_) {}
      }
      await _delete();
      throw AudioRecorderException(switch (error) {
        PlatformException(code: 'invalid_output_path') ||
        FileSystemException() =>
          'Phone recording storage is unavailable. Reopen Smart AI and try again.',
        PlatformException(code: 'recording_in_progress') =>
          'The microphone is already recording. Cancel the current recording and try again.',
        PlatformException(code: 'recording_cache_unavailable') =>
          'Phone recording storage is unavailable. Reopen Smart AI and try again.',
        MissingPluginException() =>
          'Smart AI audio needs the latest app update. Reopen the updated app.',
        AudioRecorderException(:final message) => message,
        _ =>
          'The microphone could not start recording. Check permission and try again.',
      });
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (!_recording) return null;
    try {
      await _channel.invokeMethod<void>('stopRecording');
      _recording = false;
      final path = _path;
      if (path == null) return null;
      final file = File(path);
      final size = await file.length();
      if (size < 100 || size > AudioRecorderService.maxFileSizeBytes) {
        await _delete();
        return null;
      }
      _path = null; // Ownership transfers to the caller, which must delete it.
      return path;
    } catch (_) {
      await cancelRecording();
      throw const AudioRecorderException(
        'The recording could not finish. Please try again.',
      );
    }
  }

  @override
  Future<void> cancelRecording() async {
    _generation++;
    try {
      await _starting;
    } catch (_) {}
    if (_recording || _path != null) {
      try {
        await _channel.invokeMethod<void>('cancelRecording');
      } catch (_) {}
    }
    _recording = false;
    await _delete();
  }

  Future<void> _delete() async {
    final path = _path;
    _path = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  @override
  Future<void> dispose() => cancelRecording();
}
