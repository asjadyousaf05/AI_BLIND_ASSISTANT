import 'dart:convert';

import 'package:ai_blind_assistant/infrastructure/assistant/secure_gemini_configuration_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/gemini_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_blind_assistant/wearable');
  final binding =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late Map<String, String> secureValues;
  late List<String> changedKeys;
  var acceptWrites = true;
  var acceptDeletes = true;
  setUp(() {
    secureValues = {'assistant_credential_v2': 'synthetic-pairing'};
    changedKeys = [];
    acceptWrites = true;
    acceptDeletes = true;
    binding.setMockMethodCallHandler(channel, (call) async {
      final key = (call.arguments as Map)['key'] as String;
      switch (call.method) {
        case 'secureRead':
          return secureValues[key];
        case 'secureWrite':
          if (!acceptWrites) return false;
          changedKeys.add(key);
          secureValues[key] = (call.arguments as Map)['value'] as String;
          return true;
        case 'secureDelete':
          if (!acceptDeletes) return false;
          changedKeys.add(key);
          secureValues.remove(key);
          return true;
        default:
          throw StateError('Unexpected channel operation');
      }
    });
  });
  tearDown(() => binding.setMockMethodCallHandler(channel, null));

  test(
    'stores and restores only through Keystore channel and preserves pairing',
    () async {
      final repository = SecureGeminiConfigurationRepository();
      expect(await repository.load(), isNull);
      await repository.save(testGeminiConfiguration);
      expect((await repository.load())!.apiKey, testGeminiConfiguration.apiKey);
      expect(
        (await repository.load())!.toString(),
        isNot(contains(testGeminiConfiguration.apiKey)),
      );
      await repository.delete();
      expect(await repository.load(), isNull);
      expect(secureValues['assistant_credential_v2'], 'synthetic-pairing');
      expect(changedKeys.every((key) => key == 'assistant_gemini_v1'), isTrue);
    },
  );

  test('failed native save or delete is reported', () async {
    final repository = SecureGeminiConfigurationRepository();
    acceptWrites = false;
    await expectLater(
      repository.save(testGeminiConfiguration),
      throwsA(isA<GeminiStorageException>()),
    );
    acceptDeletes = false;
    await expectLater(
      repository.delete(),
      throwsA(isA<GeminiStorageException>()),
    );
  });

  test(
    'invalid restored configuration cannot enable cloud conversation',
    () async {
      secureValues['assistant_gemini_v1'] = jsonEncode({
        'api_key': 'invalid',
        'model': 'https://other-host',
      });
      expect(await SecureGeminiConfigurationRepository().load(), isNull);
    },
  );
}
