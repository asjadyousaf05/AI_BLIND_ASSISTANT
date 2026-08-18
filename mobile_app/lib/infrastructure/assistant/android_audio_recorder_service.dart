import 'dart:io';

import 'package:flutter/services.dart';

import '../../domain/services/audio_recorder_service.dart';

/// Android implementation of [AudioRecorderService] using Flutter [MethodChannel].
///
/// Uses the native Android MediaRecorder via `ai_blind_assistant/assistant_audio_recorder`.
/// Records push-to-talk audio to a temporary m4a file in app cache.
/// Automatically caps recording at [AudioRecorderService.maxDurationSeconds].
class AndroidAudioRecorderService implements AudioRecorderService {
  AndroidAudioRecorderService();

  static const _channel = MethodChannel(
    'ai_blind_assistant/assistant_audio_recorder',
  );

  String? _currentFilePath;
  bool _isRecording = false;

  @override
  bool get isRecording => _isRecording;

  @override
  Future<void> startRecording() async {
    if (_isRecording) {
      throw const AudioRecorderException('A recording is already in progress.');
    }

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempDir = Directory.systemTemp.path;
      final path = '$tempDir/assistant_audio_$timestamp.m4a';

      final success = await _channel.invokeMethod<bool>('startRecording', {
        'path': path,
      });

      if (success != true) {
        throw const AudioRecorderException(
          'Audio recording is unavailable on this device.',
        );
      }

      _currentFilePath = path;
      _isRecording = true;
    } on AudioRecorderException {
      rethrow;
    } on MissingPluginException {
      throw const AudioRecorderException(
        'Audio recording is unavailable on this device.',
      );
    } on PlatformException catch (e) {
      throw AudioRecorderException(
        e.message ?? 'The microphone could not start recording.',
      );
    } catch (e) {
      throw const AudioRecorderException(
        'The microphone could not start recording.',
      );
    }
  }

  @override
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;

    try {
      await _channel.invokeMethod<void>('stopRecording');
    } on MissingPluginException {
      await cancelRecording();
      throw const AudioRecorderException(
        'Audio recording is unavailable on this device.',
      );
    } on PlatformException catch (e) {
      await cancelRecording();
      throw AudioRecorderException(
        e.message ?? 'The recording could not be completed.',
      );
    }

    _isRecording = false;
    final path = _currentFilePath;
    _currentFilePath = null;

    if (path == null) return null;

    // In native runtime, validate file. In tests, return the path.
    final file = File(path);
    if (!await file.exists()) return null;
    final len = await file.length();
    if (len < 100) {
      await _deleteSafely(path);
      return null;
    }
    if (len > AudioRecorderService.maxFileSizeBytes) {
      await _deleteSafely(path);
      throw const AudioRecorderException(
        'The recording exceeded the four megabyte safety limit.',
      );
    }

    return path;
  }

  @override
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    try {
      await _channel.invokeMethod<void>('cancelRecording');
    } on MissingPluginException {
      // Ignored
    } catch (_) {}

    _isRecording = false;
    if (_currentFilePath != null) {
      await _deleteSafely(_currentFilePath!);
      _currentFilePath = null;
    }
  }

  @override
  Future<void> dispose() async {
    if (_isRecording) await cancelRecording();
  }

  Future<void> _deleteSafely(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
