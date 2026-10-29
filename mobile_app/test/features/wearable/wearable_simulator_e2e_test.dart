import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:ai_blind_assistant/app/wearable_controller.dart';
import 'package:ai_blind_assistant/app/wearable_phone_feedback_service.dart';
import 'package:ai_blind_assistant/app/wearable_providers.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_credential.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_device.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_repository_event.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_connection_phase.dart';
import 'package:ai_blind_assistant/domain/repositories/wearable_credential_repository.dart';
import 'package:ai_blind_assistant/domain/services/wearable_discovery_service.dart';
import 'package:ai_blind_assistant/infrastructure/networking/bounded_retry_policy.dart';
import 'package:ai_blind_assistant/infrastructure/networking/protocol_message_factory.dart';
import 'package:ai_blind_assistant/infrastructure/networking/web_socket_wearable_repository.dart';
import 'package:ai_blind_assistant/infrastructure/networking/web_socket_wearable_transport.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final python = Platform.environment['AIBA_PI_PYTHON'];

  for (final clockOffset in [
    Duration.zero,
    const Duration(days: 365),
    const Duration(days: -365),
  ]) {
    test(
      'Flutter completes code-free enrollment, control, event and reconnect '
      'against the Python simulated Pi (phone clock offset $clockOffset)',
      () async {
        final root = await Directory.systemTemp.createTemp('aiba-cross-stack-');
        final readyFile = File('${root.path}/ready.json');
        final environment = <String, String>{
          ...Platform.environment,
          'AIBA_BIND_HOST': '127.0.0.1',
          'AIBA_DEVICE_ID': 'pi-flutter-e2e',
          'AIBA_DEVICE_NAME': 'Flutter simulated wearable',
          'AIBA_STATE_DIR': '${root.path}/state',
          'AIBA_LOG_DIR': '${root.path}/logs',
          'AIBA_ENABLE_MDNS': 'false',
          'AIBA_ENABLE_LOCAL_SPEECH': 'false',
          'AIBA_ALLOW_FIRST_CLIENT_ENROLLMENT': 'true',
        };
        final process = await Process.start(
          python!,
          [
            '-m',
            'ai_blind_pi',
            'serve',
            '--simulate',
            '--ready-file',
            readyFile.path,
          ],
          environment: {...environment, 'AIBA_PORT': '0'},
        );
        final processOutput = StringBuffer();
        final stdoutSubscription = process.stdout
            .transform(utf8.decoder)
            .listen(processOutput.write);
        final stderrSubscription = process.stderr
            .transform(utf8.decoder)
            .listen(processOutput.write);

        WebSocketWearableRepository? repository;
        ProviderContainer? container;
        StreamSubscription<WearableRepositoryEvent>? eventSubscription;
        try {
          final ready = await _waitForReadyFile(readyFile);
          final device = WearableDevice(
            id: 'manual:simulator',
            name: 'Flutter simulated wearable',
            host: ready['host']! as String,
            port: ready['port']! as int,
            source: WearableDeviceSource.manual,
          );
          final credentials = _MemoryCredentials();
          repository = WebSocketWearableRepository(
            messageFactory: ProtocolMessageFactory(
              clock: () => DateTime.now().toUtc().add(clockOffset),
            ),
            discoveryService: _FixedDiscovery(device),
            credentialRepository: credentials,
            transport: WebSocketWearableTransport(
              heartbeatInterval: const Duration(milliseconds: 250),
              staleTimeout: const Duration(seconds: 3),
            ),
            retryPolicy: BoundedRetryPolicy(
              maximumAttempts: 2,
              baseDelay: const Duration(milliseconds: 20),
              maximumDelay: const Duration(milliseconds: 20),
              jitterFraction: 0,
            ),
          );
          final failures = <WearableFailureReceived>[];
          eventSubscription = repository.events.listen((event) {
            if (event is WearableFailureReceived) failures.add(event);
          });
          await repository.initialize();
          repository.selectDevice(device);
          await repository.enroll();
          await repository.connect();
          expect(repository.state.phase, WearableConnectionPhase.connected);
          expect(repository.state.currentSettings, isNotNull);
          final spoken = <String>[];
          container = ProviderContainer(
            overrides: [
              wearableRepositoryProvider.overrideWithValue(repository),
              wearableClientIdProvider.overrideWith(
                (ref) async => 'flutter-e2e-client',
              ),
              wearablePhoneFeedbackServiceProvider.overrideWithValue(
                VoiceKernelWearablePhoneFeedbackService(
                  speak: (text) async {
                    spoken.add(text);
                  },
                  stopSpeaking: () async {},
                ),
              ),
            ],
          );
          final controller = container.read(
            wearableControllerProvider.notifier,
          );

          final detectionFuture = repository.events
              .where(
                (event) => event is WearableDetectionReceived && event.isHazard,
              )
              .cast<WearableDetectionReceived>()
              .first
              .timeout(const Duration(seconds: 4));
          await controller.connectAndStartAssistance();
          final event = await detectionFuture;
          expect(event.detection.className, 'Car');
          expect(event.detection.sourceDeviceId, 'pi-flutter-e2e');
          expect(event.detection.direction.name, 'center');
          expect(event.detection.feedbackTarget.name, 'phone');
          expect(event.detection.piAnnounced, isFalse);

          // Heartbeats and commands must share one strictly increasing sequence.
          // Keep the connection alive beyond several independent timer ticks.
          await Future<void>.delayed(const Duration(milliseconds: 1100));
          expect(failures, isEmpty);
          expect(spoken, contains(event.detection.spokenDescription));
          expect(repository.state.phase, WearableConnectionPhase.running);
          await repository.pauseAssistance();
          await repository.resumeAssistance();

          await repository.disconnect();
          expect(repository.state.phase, WearableConnectionPhase.disconnected);
          // A manually refreshed address must reuse the existing credential even
          // though the already claimed Pi advertises enrollment as closed.
          repository.selectDevice(device);
          await repository.enroll();
          expect(repository.state.phase, WearableConnectionPhase.paired);
          await repository.connect();
          expect(repository.state.phase, WearableConnectionPhase.running);
          await repository.pauseAssistance();
          await repository.resumeAssistance();
          await repository.stopAssistance();
          await repository.forgetDevice();
          expect(repository.state.phase, WearableConnectionPhase.notConfigured);
          expect(await credentials.readLastPaired(), isNull);
        } finally {
          container?.dispose();
          await eventSubscription?.cancel();
          await repository?.dispose();
          process.kill(ProcessSignal.sigterm);
          await process.exitCode.timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              process.kill();
              return process.exitCode;
            },
          );
          await stdoutSubscription.cancel();
          await stderrSubscription.cancel();
          await root.delete(recursive: true);
        }
      },
      skip: python == null
          ? 'Set AIBA_PI_PYTHON to the Pi-service test virtualenv interpreter.'
          : false,
    );
  }
}

Future<Map<String, Object?>> _waitForReadyFile(File file) async {
  for (var attempt = 0; attempt < 100; attempt++) {
    if (await file.exists()) {
      return (jsonDecode(await file.readAsString()) as Map)
          .cast<String, Object?>();
    }
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }
  throw TimeoutException('Python simulated Pi did not become ready');
}

class _FixedDiscovery implements WearableDiscoveryService {
  _FixedDiscovery(this.device);

  final WearableDevice device;

  @override
  Future<List<WearableDevice>> discover({Duration? timeout}) async => [device];

  @override
  Future<WearableDevice?> resolve(String hostOrServiceName) async => device;

  @override
  Future<void> stop() async {}
}

class _MemoryCredentials implements WearableCredentialRepository {
  final Map<String, WearableCredential> _values = {};
  String? _last;

  @override
  Future<void> delete(String deviceId) async {
    _values.remove(deviceId);
    if (_last == deviceId) _last = null;
  }

  @override
  Future<String> getOrCreateClientId() async => 'flutter-e2e-client';

  @override
  Future<WearableCredential?> read(String deviceId) async => _values[deviceId];

  @override
  Future<WearableCredential?> readLastPaired() async =>
      _last == null ? null : _values[_last];

  @override
  Future<void> write(WearableCredential credential) async {
    _values[credential.deviceId] = credential;
    _last = credential.deviceId;
  }
}
