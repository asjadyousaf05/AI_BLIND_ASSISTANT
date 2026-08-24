import 'dart:math';

import 'package:ai_blind_assistant/app/wearable_controller.dart';
import 'package:ai_blind_assistant/domain/entities/protocol_envelope.dart';
import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_credential.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_settings_snapshot.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_telemetry.dart';
import 'package:ai_blind_assistant/domain/enums/protocol_message_type.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_direction.dart';
import 'package:ai_blind_assistant/infrastructure/networking/bounded_retry_policy.dart';
import 'package:ai_blind_assistant/infrastructure/networking/protocol_codec.dart';
import 'package:ai_blind_assistant/infrastructure/networking/sequence_deduplicator.dart';
import 'package:ai_blind_assistant/infrastructure/networking/wearable_authenticator.dart';
import 'package:ai_blind_assistant/infrastructure/networking/wearable_settings_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const secret = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
  final timestamp = DateTime.parse('2026-08-09T12:34:56.123456Z');
  final credential = WearableCredential(
    deviceId: 'pi-test',
    deviceName: 'Test Pi',
    host: '127.0.0.1',
    port: 8765,
    serviceName: '_aiba-wearable._tcp',
    clientId: 'client-1',
    credentialId: 'credential-1',
    secret: secret,
    createdAt: timestamp,
  );

  test('Dart authentication proof matches the Python protocol vector', () {
    const authenticator = WearableAuthenticator();
    final proof = authenticator.createProof(
      credential: credential,
      nonce: 'server-nonce',
      messageId: '12345678abcdef00',
      timestamp: timestamp,
    );
    expect(
      proof.tag,
      'd22439b5824ae63ac10b224b37485da4e6c8f9c470532d514d425e5b83125aae',
    );
    expect(
      authenticator.verifyProof(
        proof: proof,
        messageId: '12345678abcdef00',
        secret: secret,
        now: timestamp,
      ),
      isTrue,
    );
  });

  test('Dart envelope HMAC matches Python and round-trips strictly', () {
    final settings = WearableSettingsSnapshot(
      version: WearableSettingsVersion(
        revision: 3,
        updatedAt: timestamp,
        source: WearableSettingsSource.phone,
        sourceId: 'client-1',
      ),
      confidenceThreshold: 0.45,
      announcementCooldownSeconds: 5,
      speechEnabled: true,
      vibrationEnabled: false,
      assistanceMode: 'object_detection',
    );
    final envelope = ProtocolEnvelope(
      protocolVersion: 1,
      type: ProtocolMessageType.updateSettings,
      messageId: '12345678abcdef00',
      timestamp: timestamp,
      sequence: 7,
      payload: settings.toPayload(),
    );
    const signer = AuthenticatedEnvelopeSigner(sessionNonce: 'server-nonce');
    final signed = signer.sign(envelope, credential);
    expect(
      signed.authenticationTag,
      'e3c8939e78704106797cde113efaa93fb36c00137a127df2d33563473575d142',
    );
    const codec = ProtocolCodec();
    final decoded = codec.decode(codec.encode(signed));
    expect(signer.verify(decoded, credential), isTrue);
    expect(
      () => codec.decode(
        '{"protocolVersion":1,"type":"bad","messageId":"12345678",'
        '"timestamp":"2026-08-09T12:34:56Z","sequence":0,"payload":{}}',
      ),
      throwsA(anything),
    );
  });

  test('retry policy is bounded exponential backoff', () async {
    final delays = <Duration>[];
    final policy = BoundedRetryPolicy(
      maximumAttempts: 4,
      baseDelay: const Duration(milliseconds: 100),
      maximumDelay: const Duration(milliseconds: 250),
      jitterFraction: 0,
      random: Random(1),
    );
    var calls = 0;
    final result = await policy.execute<int>((_) async {
      calls++;
      if (calls < 4) throw StateError('temporary');
      return 42;
    }, sleeper: (delay) async => delays.add(delay));
    expect(result, 42);
    expect(calls, 4);
    expect(delays, const [
      Duration(milliseconds: 100),
      Duration(milliseconds: 200),
      Duration(milliseconds: 250),
    ]);
  });

  test('deduplicator rejects duplicate and out-of-order events', () {
    final deduplicator = SequenceDeduplicator();
    expect(
      deduplicator.accept(sourceId: 'boot-1', sequence: 2, messageId: 'a'),
      isTrue,
    );
    expect(
      deduplicator.accept(sourceId: 'boot-1', sequence: 2, messageId: 'b'),
      isFalse,
    );
    expect(
      deduplicator.accept(sourceId: 'boot-1', sequence: 3, messageId: 'a'),
      isFalse,
    );
  });

  test('settings conflict resolution is deterministic', () {
    const resolver = WearableSettingsResolver();
    WearableSettingsSnapshot snapshot(
      WearableSettingsSource source,
      String sourceId,
    ) => WearableSettingsSnapshot(
      version: WearableSettingsVersion(
        revision: 2,
        updatedAt: timestamp,
        source: source,
        sourceId: sourceId,
      ),
      confidenceThreshold: 0.5,
      announcementCooldownSeconds: 5,
      speechEnabled: true,
      vibrationEnabled: true,
      assistanceMode: 'object_detection',
    );
    final pi = snapshot(WearableSettingsSource.pi, 'pi-test');
    final phone = snapshot(WearableSettingsSource.phone, 'phone-test');
    expect(resolver.resolve(pi, phone), same(phone));
  });

  test('wearable settings reject values outside the shared Pi contract', () {
    Map<String, Object?> payload(double confidence, int cooldown) => {
      'version': {
        'revision': 1,
        'updatedAt': timestamp.toIso8601String(),
        'source': 'pi',
        'sourceId': 'pi-test',
      },
      'confidenceThreshold': confidence,
      'announcementCooldownSeconds': cooldown,
      'speechEnabled': true,
      'vibrationEnabled': false,
      'assistanceMode': 'object_detection',
    };

    expect(
      () => WearableSettingsSnapshot.fromPayload(payload(0.01, 5)),
      throwsFormatException,
    );
    expect(
      () => WearableSettingsSnapshot.fromPayload(payload(0.45, 0)),
      throwsFormatException,
    );
  });

  test('manual endpoint validation only accepts local targets', () {
    expect(WearableController.validateHost('192.168.50.24'), isNull);
    expect(WearableController.validateHost('rpi3-ml.local'), isNull);
    expect(WearableController.validateHost('rpi3-ml'), isNull);
    expect(WearableController.validateHost('8.8.8.8'), isNotNull);
    expect(WearableController.validateHost('example.com'), isNotNull);
  });

  test('code-free enrollment messages validate strictly', () {
    const codec = ProtocolCodec();
    final request = ProtocolEnvelope(
      protocolVersion: 1,
      type: ProtocolMessageType.enrollmentRequest,
      messageId: 'enrollment-request-0001',
      timestamp: timestamp,
      sequence: 0,
      payload: const {'clientId': 'phone-1', 'clientName': 'Vision phone'},
    );
    final decodedRequest = codec.decode(codec.encode(request));
    expect(decodedRequest.type, ProtocolMessageType.enrollmentRequest);
    expect(decodedRequest.payload, request.payload);

    final result = ProtocolEnvelope(
      protocolVersion: 1,
      type: ProtocolMessageType.enrollmentResult,
      messageId: 'enrollment-result-0001',
      timestamp: timestamp,
      sequence: 0,
      payload: const {
        'requestMessageId': 'enrollment-request-0001',
        'enrolled': false,
        'errorCode': 'enrollment_closed',
      },
    );
    final decodedResult = codec.decode(codec.encode(result));
    expect(decodedResult.type, ProtocolMessageType.enrollmentResult);
    expect(decodedResult.payload, result.payload);
  });

  test('wearable phone announcement uses relative position, not distance', () {
    final detection = WearableDetectionEvent(
      sourceDeviceId: 'pi-test',
      frameSequence: 1,
      classId: 104,
      className: 'chair',
      confidence: 0.8,
      boundingBox: const BoundingBox(
        left: 0.2,
        top: 0.1,
        right: 0.8,
        bottom: 0.9,
      ),
      direction: WearableDirection.right,
      capturedAt: timestamp,
      priority: 80,
      relativeProximity: 'very_close',
      feedbackTarget: WearableFeedbackTarget.phone,
    );

    expect(detection.spokenDescription, 'Chair very close on the right');
    expect(detection.spokenDescription, isNot(contains('meter')));
  });
}
