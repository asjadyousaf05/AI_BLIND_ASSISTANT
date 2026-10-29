import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:ai_blind_assistant/infrastructure/assistant/secure_smart_ai_cloud_configuration_repository.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/smart_ai_audio_recorder.dart';
import 'package:ai_blind_assistant/domain/services/audio_recorder_service.dart';
import 'package:ai_blind_assistant/domain/entities/smart_ai_cloud_configuration.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/smart_ai_cloud_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const secure = MethodChannel('ai_blind_assistant/wearable');
  const recorderChannel = MethodChannel(
    'ai_blind_assistant/assistant_audio_recorder',
  );
  late Directory directory;
  late Map<String, String> values;
  late List<String> methods;
  String? recordingPath;
  Completer<bool>? startGate;
  var saveOk = true;
  var deleteOk = true;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('smart-ai-storage-test-');
    values = {
      'assistant_gemini_v1': 'synthetic-gemini',
      'assistant_credential_v2': 'synthetic-laptop',
      'wearable_pairing_v1': 'synthetic-pi',
    };
    methods = [];
    recordingPath = null;
    startGate = null;
    saveOk = true;
    deleteOk = true;
    messenger.setMockMethodCallHandler(secure, (call) async {
      final data = call.arguments as Map;
      final key = data['key'] as String;
      switch (call.method) {
        case 'secureRead':
          return values[key];
        case 'secureWrite':
          if (!saveOk) return false;
          values[key] = data['value'] as String;
          return true;
        case 'secureDelete':
          if (!deleteOk) return false;
          values.remove(key);
          return true;
      }
      return null;
    });
    messenger.setMockMethodCallHandler(recorderChannel, (call) async {
      methods.add(call.method);
      if (call.method == 'getSmartAiCacheDirectory') return directory.path;
      if (call.method == 'startRecording') {
        recordingPath = (call.arguments as Map)['path'] as String;
        await File(recordingPath!).writeAsBytes(List.filled(128, 0));
        return startGate == null ? true : await startGate!.future;
      }
      return null;
    });
  });
  tearDown(() async {
    messenger.setMockMethodCallHandler(secure, null);
    messenger.setMockMethodCallHandler(recorderChannel, null);
    await directory.delete(recursive: true);
  });

  test(
    'separate Keystore configuration round trip preserves all older credentials',
    () async {
      final repository = SecureSmartAiCloudConfigurationRepository();
      expect(await repository.load(), isNull);
      await repository.save(testSmartAiConfiguration);
      final restored = (await repository.load())!;
      expect(restored.groqKey, testSmartAiConfiguration.groqKey);
      expect(restored.routerKey, testSmartAiConfiguration.routerKey);
      expect(
        restored.toString(),
        isNot(contains(testSmartAiConfiguration.groqKey)),
      );
      expect(
        restored.toString(),
        isNot(contains(testSmartAiConfiguration.routerKey)),
      );
      await repository.delete();
      expect(await repository.load(), isNull);
      expect(values, {
        'assistant_gemini_v1': 'synthetic-gemini',
        'assistant_credential_v2': 'synthetic-laptop',
        'wearable_pairing_v1': 'synthetic-pi',
      });
    },
  );

  test(
    'native false saves/deletes are errors and cannot report successful removal',
    () async {
      final repository = SecureSmartAiCloudConfigurationRepository();
      saveOk = false;
      await expectLater(
        repository.save(testSmartAiConfiguration),
        throwsA(isA<SmartAiStorageException>()),
      );
      deleteOk = false;
      await expectLater(
        repository.delete(),
        throwsA(isA<SmartAiStorageException>()),
      );
    },
  );

  test(
    'Groq-only configuration persists without requiring an AgentRouter key',
    () async {
      final repository = SecureSmartAiCloudConfigurationRepository();
      await repository.save(testGroqSmartAiConfiguration);
      final restored = (await repository.load())!;
      expect(restored.isValid, true);
      expect(restored.routerKey, isEmpty);
      expect(restored.answerProvider, SmartAiAnswerProvider.groq);
      expect(restored.answerModel, 'openai/gpt-oss-20b');
    },
  );

  test(
    'legacy provider selection is retained and unknown selections fail closed',
    () async {
      final repository = SecureSmartAiCloudConfigurationRepository();
      final old = {
        'groq_key': testSmartAiConfiguration.groqKey,
        'router_key': testSmartAiConfiguration.routerKey,
      };
      values['smart_ai_cloud_v1'] = jsonEncode(old);
      expect(
        (await repository.load())!.answerProvider,
        SmartAiAnswerProvider.agentRouter,
      );
      values['smart_ai_cloud_v1'] = jsonEncode({
        ...old,
        'answer_provider': 'unknown-provider',
      });
      expect(await repository.load(), isNull);
    },
  );

  test('corrupt or invalid restored keys never enable cloud capture', () async {
    final repository = SecureSmartAiCloudConfigurationRepository();
    for (final raw in [
      'not json',
      '{}',
      jsonEncode({'groq_key': 'invalid', 'router_key': 'invalid'}),
    ]) {
      values['smart_ai_cloud_v1'] = raw;
      expect(await repository.load(), isNull);
    }
  });

  test(
    'recorder removes only its own orphan clips and transfers successful file ownership',
    () async {
      final orphan = await File(
        '${directory.path}/smart_ai_audio_old.m4a',
      ).writeAsBytes([0]);
      final legacy = await File(
        '${directory.path}/assistant_audio_keep.m4a',
      ).writeAsBytes([0]);
      final recorder = SmartAiAudioRecorder(directory: directory);
      await recorder.startRecording();
      expect(await orphan.exists(), false);
      expect(await legacy.exists(), true);
      expect(recordingPath, endsWith('.m4a'));
      expect(recorder.isRecording, true);
      final path = await recorder.stopRecording();
      expect(path, recordingPath);
      expect(await File(path!).exists(), true);
      expect(recorder.isRecording, false);
      await File(path).delete();
      await recorder.dispose();
    },
  );

  test(
    'default recorder obtains private cache from Android rather than system temp',
    () async {
      final recorder = SmartAiAudioRecorder();
      await recorder.startRecording();
      expect(methods.take(2), ['getSmartAiCacheDirectory', 'startRecording']);
      expect(recordingPath, startsWith(directory.path));
      await recorder.cancelRecording();
      expect(await File(recordingPath!).exists(), false);
    },
  );

  test(
    'cancelled capture removes the clip and releases the native recorder',
    () async {
      final recorder = SmartAiAudioRecorder(directory: directory);
      await recorder.startRecording();
      await recorder.cancelRecording();
      expect(await File(recordingPath!).exists(), false);
      expect(recorder.isRecording, false);
      expect(methods, ['startRecording', 'cancelRecording']);
    },
  );

  test(
    'cancellation while native start is pending cannot leave a late recording',
    () async {
      final recorder = SmartAiAudioRecorder(directory: directory);
      startGate = Completer<bool>();
      final start = recorder.startRecording();
      final expectation = expectLater(
        start,
        throwsA(isA<AudioRecorderException>()),
      );
      while (!methods.contains('startRecording')) {
        await Future<void>.delayed(Duration.zero);
      }
      final cancel = recorder.cancelRecording();
      startGate!.complete(true);
      await expectation;
      await cancel;
      expect(await File(recordingPath!).exists(), false);
      expect(recorder.isRecording, false);
      expect(methods, contains('cancelRecording'));
    },
  );

  test('an empty clip is deleted and never becomes an upload path', () async {
    final recorder = SmartAiAudioRecorder(directory: directory);
    await recorder.startRecording();
    await File(recordingPath!).writeAsBytes([]);
    expect(await recorder.stopRecording(), isNull);
    expect(await File(recordingPath!).exists(), false);
  });
}
