import 'package:ai_blind_assistant/domain/entities/assistant_credential.dart';
import 'package:ai_blind_assistant/infrastructure/assistant/secure_assistant_credential_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('ai_blind_assistant/wearable');
  late Map<String, String> secureValues;

  setUp(() {
    secureValues = {};
    SharedPreferences.setMockInitialValues({});
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = (call.arguments as Map).cast<String, Object?>();
          final key = arguments['key'] as String?;
          return switch (call.method) {
            'secureWrite' => () {
              secureValues[key!] = arguments['value']! as String;
              return true;
            }(),
            'secureRead' => secureValues[key],
            'secureDelete' => secureValues.remove(key) != null,
            _ => throw PlatformException(code: 'not_implemented'),
          };
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test(
    'stores, loads, and deletes the bearer through secure channel',
    () async {
      final repository = SecureAssistantCredentialRepository();
      final credential = AssistantCredential(
        backendUrl: 'http://192.168.1.8:8765',
        bearerToken: 'opaque-test-token',
        userId: 'test-user',
        displayName: 'Test User',
        pairedAt: DateTime.utc(2026, 8, 14),
      );

      await repository.saveCredential(credential);
      final loaded = await repository.loadCredential();

      expect(secureValues, hasLength(1));
      expect(loaded?.bearerToken, 'opaque-test-token');
      expect(loaded?.backendUrl, 'http://192.168.1.8:8765');

      await repository.deleteCredential();
      expect(await repository.loadCredential(), isNull);
    },
  );
}
