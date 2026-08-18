import 'dart:developer' as developer;

import '../../domain/entities/voice_command.dart';
import '../../domain/entities/voice_recognition_event.dart';
import '../../domain/enums/voice_feature_context.dart';
import '../../domain/enums/voice_rejection_reason.dart';
import '../../domain/enums/voice_runtime_state.dart';

/// Structured diagnostic logger for the voice kernel.
///
/// All output uses [developer.log] and is only visible in debug builds.
/// No user data, transcripts, or personal information is logged — only
/// intent names, state transitions, and session metadata.
abstract final class VoiceDiagnosticLogger {
  static const _name = 'VoiceKernel';

  static void stateTransition(
    VoiceRuntimeState from,
    VoiceRuntimeState to,
  ) {
    developer.log(
      'STATE ${from.name} → ${to.name}',
      name: _name,
    );
  }

  static void contextChange(
    VoiceFeatureContext from,
    VoiceFeatureContext to,
    int generation,
  ) {
    developer.log(
      'CONTEXT ${from.label} → ${to.label} gen=$generation',
      name: _name,
    );
  }

  static void sessionInfo({
    required int recognizerSession,
    required int commandSession,
    required VoiceFeatureContext context,
  }) {
    developer.log(
      'SESSION recognizer=$recognizerSession '
      'command=$commandSession '
      'context=${context.label}',
      name: _name,
    );
  }

  static void asrEvent(VoiceRecognitionEvent event) {
    final type = event.isFinal ? 'ASR_FINAL' : 'ASR_PARTIAL';
    developer.log(
      '$type recognition=${event.recognitionId} '
      'recSession=${event.recognizerSessionId} '
      'cmdSession=${event.commandSessionId} '
      'text="${_truncate(event.transcript, 60)}"',
      name: _name,
    );
  }

  static void resolved(VoiceCommand command) {
    developer.log(
      'RESOLVE intent=${command.intent.runtimeType} '
      'score=${command.matchScore.toStringAsFixed(2)} '
      'type=${command.matchType.name}',
      name: _name,
    );
  }

  static void authorized(VoiceCommand command) {
    developer.log(
      'AUTH allowed=true intent=${command.intent.runtimeType}',
      name: _name,
    );
  }

  static void rejected(
    VoiceCommand command,
    VoiceRejectionReason reason,
  ) {
    developer.log(
      'AUTH allowed=false intent=${command.intent.runtimeType} '
      'reason=${reason.name}',
      name: _name,
    );
  }

  static void executed(VoiceCommand command) {
    developer.log(
      'EXECUTE ${command.intent.runtimeType}',
      name: _name,
    );
  }

  static void consumed(String recognitionId) {
    developer.log(
      'CONSUME recognition=$recognitionId',
      name: _name,
    );
  }

  static void wakeDetected({bool withCommand = false}) {
    developer.log(
      'WAKE detected withCommand=$withCommand',
      name: _name,
    );
  }

  static void error(String message, [Object? error]) {
    developer.log(
      'ERROR $message',
      name: _name,
      error: error,
    );
  }

  static void info(String message) {
    developer.log(message, name: _name);
  }

  // ─────────────────── Scanner Diagnostics ────────────────────

  static const _scannerName = 'Scanner';

  static void scanRequest({
    required String source,
    required String scanRequestId,
  }) {
    developer.log(
      'SCAN_REQUEST source=$source requestId=$scanRequestId',
      name: _scannerName,
    );
  }

  static void scanAccepted(String scanRequestId) {
    developer.log(
      'SCAN_ACCEPTED requestId=$scanRequestId',
      name: _scannerName,
    );
  }

  static void scanConsumed(String scanRequestId) {
    developer.log(
      'SCAN_CONSUMED requestId=$scanRequestId',
      name: _scannerName,
    );
  }

  static void ocrAction(String action, {String? detail}) {
    developer.log(
      'OCR_ACTION action=$action${detail != null ? ' detail=$detail' : ''}',
      name: _scannerName,
    );
  }

  // ─────────────────── Reader Diagnostics ─────────────────────

  static const _readerName = 'Reader';

  static void readerEvent({
    required String event,
    int? sentenceIndex,
    int? generation,
    String? status,
    String? detail,
  }) {
    final parts = <String>['READER $event'];
    if (sentenceIndex != null) parts.add('sentence=$sentenceIndex');
    if (generation != null) parts.add('gen=$generation');
    if (status != null) parts.add('status=$status');
    if (detail != null) parts.add('detail=$detail');
    developer.log(parts.join(' '), name: _readerName);
  }

  static void readerTtsCallback({
    required String event,
    required int generation,
    required int currentGeneration,
    int? sentenceIndex,
  }) {
    final stale = generation != currentGeneration ? ' STALE' : '';
    developer.log(
      'TTS_CALLBACK $event gen=$generation '
      'currentGen=$currentGeneration'
      '${sentenceIndex != null ? ' sentence=$sentenceIndex' : ''}'
      '$stale',
      name: _readerName,
    );
  }

  static String _truncate(String text, int maxLength) =>
      text.length <= maxLength ? text : '${text.substring(0, maxLength)}…';
}
