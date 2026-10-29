import 'dart:async';
import 'package:ai_blind_assistant/domain/services/smart_ai_interaction_policy.dart';
import 'dart:io';
import 'package:ai_blind_assistant/domain/entities/assistant_message.dart';
import 'package:ai_blind_assistant/domain/entities/smart_ai_cloud_configuration.dart';
import 'package:ai_blind_assistant/domain/repositories/smart_ai_cloud_configuration_repository.dart';
import 'package:ai_blind_assistant/domain/services/audio_recorder_service.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_audio_coordinator.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_cloud_service.dart';

const testSmartAiConfiguration = SmartAiCloudConfiguration(
  groqKey: 'synthetic-groq-key-only',
  routerKey: 'synthetic-router-key-only',
);

const testGroqSmartAiConfiguration = SmartAiCloudConfiguration(
  groqKey: 'synthetic-groq-key-only',
  answerProvider: SmartAiAnswerProvider.groq,
);

class FakeSmartAiConfigurationRepository
    implements SmartAiCloudConfigurationRepository {
  SmartAiCloudConfiguration? configuration;
  Completer<SmartAiCloudConfiguration?>? loadGate;
  bool failSave = false;
  bool failDelete = false;
  @override
  Future<SmartAiCloudConfiguration?> load() async =>
      loadGate == null ? configuration : await loadGate!.future;
  @override
  Future<void> save(SmartAiCloudConfiguration value) async {
    if (failSave) throw StateError('synthetic storage failure');
    configuration = value;
  }

  @override
  Future<void> delete() async {
    if (failDelete) throw StateError('synthetic storage failure');
    configuration = null;
  }
}

class FakeSmartAiService implements SmartAiCloudService {
  FakeSmartAiService(this.events);
  final List<String> events;
  Completer<String>? transcriptionGate;
  Completer<String>? replyGate;
  Object? transcriptionFailure;
  Object? replyFailure;
  String transcript = 'A synthetic question';
  SmartAiSpeechLanguage? transcriptionLanguage;
  SmartAiSpeechLanguage? replyLanguage;
  int cancellations = 0;
  List<AssistantMessage> history = [];
  @override
  Future<String> transcribe({
    required SmartAiCloudConfiguration configuration,
    required String audioPath,
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  }) async {
    if (!await File(audioPath).exists()) {
      throw StateError('Clip deleted before upload');
    }
    events.add('transcribe');
    transcriptionLanguage = language;
    if (transcriptionFailure != null) throw transcriptionFailure!;
    return transcriptionGate == null
        ? transcript
        : await transcriptionGate!.future;
  }

  @override
  Future<String> reply({
    required SmartAiCloudConfiguration configuration,
    required String transcript,
    required List<AssistantMessage> history,
    SmartAiSpeechLanguage language = SmartAiSpeechLanguage.automatic,
  }) async {
    events.add('reply');
    replyLanguage = language;
    this.history = history;
    if (replyFailure != null) throw replyFailure!;
    return replyGate == null
        ? 'A brief synthetic answer.'
        : await replyGate!.future;
  }

  @override
  void cancelPending() {
    cancellations++;
  }
}

class FakeSmartAiAudioCoordinator implements SmartAiAudioCoordinator {
  FakeSmartAiAudioCoordinator(this.events);
  final List<String> events;
  final spoken = <String>[];
  final routed = <String>[];
  String? localResult;
  Completer<void>? speechGate;
  Completer<void>? acquireGate;
  Completer<void>? releaseGate;
  bool failSpeech = false;
  int recordingCues = 0;
  int cueStops = 0;
  void Function()? onRecordingCue;
  Object? cueFailure;
  final goodbyeEvents = StreamController<void>.broadcast();
  @override
  Stream<void> get goodbyeRequests => goodbyeEvents.stream;
  @override
  Future<void> prepareRecording() => acquire();
  @override
  Future<void> recordingFinished() async {}
  @override
  Future<void> acquire() async {
    events.add('acquire');
    if (acquireGate != null) await acquireGate!.future;
  }

  @override
  Future<void> release() async {
    events.add('release');
    if (releaseGate != null) await releaseGate!.future;
  }

  @override
  Future<String?> routeLocalControl(String transcript) async {
    events.add('local');
    routed.add(transcript);
    return localResult;
  }

  @override
  Future<void> speak(String text) async {
    events.add('speak');
    spoken.add(text);
    if (failSpeech) throw StateError('synthetic TTS unavailable');
    if (speechGate != null) await speechGate!.future;
  }

  @override
  Future<void> stopSpeech() async {
    events.add('stop');
    if (speechGate != null && !speechGate!.isCompleted) speechGate!.complete();
  }

  @override
  Future<void> pauseSpeech() async {
    events.add('pause');
  }

  @override
  Future<void> resumeSpeech() async {
    events.add('resume');
  }

  @override
  Future<void> recordingStartedCue() async {
    recordingCues++;
    onRecordingCue?.call();
    if (cueFailure != null) throw cueFailure!;
  }

  @override
  Future<void> stopRecordingCue() async {
    cueStops++;
  }
}

class FakeSmartAiRecorder implements AudioRecorderService {
  FakeSmartAiRecorder(this.directory, this.events);
  final Directory directory;
  final List<String> events;
  String? lastPath;
  String? _ownedPath;
  bool _recording = false;
  @override
  bool get isRecording => _recording;
  @override
  Future<void> startRecording() async {
    events.add('record');
    _recording = true;
    lastPath = '${directory.path}/synthetic.m4a';
    _ownedPath = lastPath;
    await File(lastPath!).writeAsBytes(List.filled(128, 0));
  }

  @override
  Future<String?> stopRecording() async {
    events.add('stop-record');
    _recording = false;
    _ownedPath = null;
    return lastPath;
  }

  @override
  Future<void> cancelRecording() async {
    _recording = false;
    // Like the production recorder, relinquish clip ownership before async I/O.
    final path = _ownedPath;
    _ownedPath = null;
    if (path != null && await File(path).exists()) {
      await File(path).delete();
    }
  }

  @override
  Future<void> dispose() => cancelRecording();
}
