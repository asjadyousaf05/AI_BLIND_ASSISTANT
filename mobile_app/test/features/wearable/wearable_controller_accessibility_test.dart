import 'dart:async';

import 'package:ai_blind_assistant/app/wearable_controller.dart';
import 'package:ai_blind_assistant/app/wearable_phone_feedback_service.dart';
import 'package:ai_blind_assistant/app/wearable_providers.dart';
import 'package:ai_blind_assistant/core/constants/wearable_defaults.dart';
import 'package:ai_blind_assistant/core/constants/app_keys.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_device.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_repository_event.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_session_state.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_settings_snapshot.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_telemetry.dart';
import 'package:ai_blind_assistant/domain/entities/bounding_box.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_connection_phase.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_direction.dart';
import 'package:ai_blind_assistant/domain/repositories/wearable_repository.dart';
import 'package:ai_blind_assistant/domain/services/wearable_phone_feedback_service.dart';
import 'package:ai_blind_assistant/features/raspberry_pi/presentation/raspberry_pi_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('phone feedback speaks the Pi object name and direction', () async {
    String? spoken;
    final feedback = VoiceKernelWearablePhoneFeedbackService(
      speak: (text) async => spoken = text,
      stopSpeaking: () async {},
    );

    await feedback.announce(_phoneDetection);

    expect(spoken, 'Car very close ahead');
  });

  testWidgets('audio test works before Pi connection without enrolling', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
    );
    final feedback = _RecordingWearablePhoneFeedback();
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearablePhoneFeedbackServiceProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    await tester.pump();

    await controller.testPhoneAudio();

    expect(feedback.tests, 1);
    expect(repository.connectCalls, 0);
    expect(repository.enrollCalls, 0);
    expect(
      container.read(wearableControllerProvider).liveMessage,
      contains('If you did not hear it'),
    );
  });

  for (final action in ['disconnect', 'background', 'pause', 'stop']) {
    testWidgets(
      'active phone speech stops on $action and ignores late failure',
      (tester) async {
        final repository = _FakeWearableRepository(
          const WearableSessionState(
            phase: WearableConnectionPhase.running,
            selectedDevice: _device,
          ),
        );
        final gate = Completer<void>();
        final feedback = _RecordingWearablePhoneFeedback()..pending = gate;
        final container = ProviderContainer(
          overrides: [
            wearableRepositoryProvider.overrideWithValue(repository),
            wearablePhoneFeedbackServiceProvider.overrideWithValue(feedback),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await repository.dispose();
        });
        final controller = container.read(wearableControllerProvider.notifier);
        await tester.pump();
        repository.emitEvent(
          WearableDetectionReceived(_phoneDetection, isHazard: true),
        );
        await tester.pump();
        expect(feedback.detections, hasLength(1));

        switch (action) {
          case 'background':
            await controller.handleLifecycleChange(AppLifecycleState.paused);
          case 'pause':
            await controller.pauseAssistance();
          case 'stop':
            await controller.stopAssistance();
          default:
            await controller.disconnect();
        }
        expect(feedback.stops, 1);
        gate.completeError(StateError('late platform failure'));
        await tester.pump();
        expect(
          container.read(wearableControllerProvider).phoneFeedbackWarning,
          isNull,
        );
        repository.emitEvent(
          WearableDetectionReceived(_phoneDetection, isHazard: true),
        );
        await tester.pump();
        expect(feedback.detections, hasLength(1));
      },
    );
  }

  testWidgets('failed audio test reports a useful warning', (tester) async {
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearablePhoneFeedbackServiceProvider.overrideWithValue(
          _FailingWearablePhoneFeedback(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    await tester.pump();
    await controller.testPhoneAudio();
    expect(
      container.read(wearableControllerProvider).phoneFeedbackWarning,
      contains('audio test failed'),
    );
    expect(
      container.read(wearableControllerProvider).actionInProgress,
      isFalse,
    );
  });

  testWidgets('Disconnect remains available while detection starts', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.starting,
        selectedDevice: _device,
      ),
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [wearableRepositoryProvider.overrideWithValue(repository)],
        child: const MaterialApp(home: RaspberryPiScreen()),
      ),
    );
    await tester.pump();
    final disconnect = find.byKey(AppKeys.raspberryPiDisconnectButton);
    await tester.ensureVisible(disconnect);
    await tester.tap(disconnect);
    await tester.pump();
    expect(repository.disconnectCalls, 1);
    await tester.pumpWidget(const SizedBox.shrink());
    await repository.dispose();
  });

  testWidgets('lifecycle disconnects only transport and reconnects once', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.connected,
        selectedDevice: _device,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    container.read(wearableControllerProvider);
    await tester.pump();

    await controller.handleLifecycleChange(AppLifecycleState.paused);
    expect(repository.disconnectCalls, 1);
    expect(repository.stopCalls, 0);
    expect(
      container.read(wearableControllerProvider).lifecycleSuspended,
      isTrue,
    );

    await controller.handleLifecycleChange(AppLifecycleState.resumed);
    expect(repository.connectCalls, 1);
    expect(
      container.read(wearableControllerProvider).lifecycleSuspended,
      isFalse,
    );
  });

  testWidgets('wearable setup exposes truthful TalkBack controls and state', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
    );
    final feedback = _RecordingWearablePhoneFeedback();
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wearableRepositoryProvider.overrideWithValue(repository),
            wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
            wearablePhoneFeedbackServiceProvider.overrideWithValue(feedback),
          ],
          child: const MaterialApp(home: RaspberryPiScreen()),
        ),
      );
      await tester.pump();
      expect(find.bySemanticsLabel('No wearable configured'), findsWidgets);
      expect(
        find.bySemanticsLabel(
          'Search the local network for a Raspberry Pi wearable',
        ),
        findsOneWidget,
      );
      expect(find.text('Connection options'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Validate and select this local Raspberry Pi address',
        ),
        findsNothing,
      );
      await tester.ensureVisible(find.text('Connection options'));
      await tester.tap(find.text('Connection options'));
      await tester.pumpAndSettle();
      expect(
        find.bySemanticsLabel(
          'Validate and select this local Raspberry Pi address',
        ),
        findsOneWidget,
      );
      expect(find.text(WearableDefaults.host), findsWidgets);
      expect(find.text('Phone hotspot setup'), findsOneWidget);
      expect(find.text('Alerts play on this phone'), findsOneWidget);
      final audioTest = find.bySemanticsLabel(
        'Play a test message through the phone speaker',
      );
      expect(audioTest, findsOneWidget);
      await tester.ensureVisible(audioTest);
      await tester.tap(audioTest);
      await tester.pumpAndSettle();
      expect(feedback.tests, 1);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      await repository.dispose();
    }
  });

  for (final background in [false, true]) {
    testWidgets(
      background
          ? 'background cancels the whole discovery and connection flow'
          : 'cancel stops the whole flow and concurrent Connect is ignored',
      (tester) async {
        final gate = Completer<List<WearableDevice>>();
        final repository = _FakeWearableRepository(
          WearableSessionState.notConfigured,
        )..discoveryGate = gate;
        final container = ProviderContainer(
          overrides: [
            wearableRepositoryProvider.overrideWithValue(repository),
            wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
          ],
        );
        addTearDown(() async {
          container.dispose();
          await repository.dispose();
        });
        final controller = container.read(wearableControllerProvider.notifier);
        await tester.pump();
        final first = controller.connectDefaultAndStartAssistance();
        await tester.pump();
        await controller.connectDefaultAndStartAssistance();
        expect(repository.discoverCalls, 1);
        expect(
          container.read(wearableControllerProvider).actionInProgress,
          isTrue,
        );
        if (background) {
          await controller.handleLifecycleChange(AppLifecycleState.paused);
        } else {
          await controller.disconnect();
        }
        gate.complete([_device]);
        await first;
        expect(repository.disconnectCalls, 1);
        expect(repository.enrollCalls, 0);
        expect(repository.connectCalls, 0);
        expect(repository.startCalls, 0);
        expect(
          container.read(wearableControllerProvider).actionInProgress,
          isFalse,
        );
        expect(container.read(wearableControllerProvider).failure, isNull);
      },
    );
  }

  testWidgets('late phone alerts are ignored after disconnect or background', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.running,
        selectedDevice: _device,
      ),
    );
    final feedback = _RecordingWearablePhoneFeedback();
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearablePhoneFeedbackServiceProvider.overrideWithValue(feedback),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    await tester.pump();
    await controller.handleLifecycleChange(AppLifecycleState.paused);
    repository.emitEvent(
      WearableDetectionReceived(_phoneDetection, isHazard: true),
    );
    await tester.pump();
    expect(feedback.detections, isEmpty);
  });

  testWidgets('one action enrolls, connects, and starts an unclaimed Pi', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.deviceFound,
        selectedDevice: _device,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    container.read(wearableControllerProvider);
    await tester.pump();

    await controller.connectAndStartAssistance();

    expect(repository.enrollCalls, 1);
    expect(repository.connectCalls, 1);
    expect(repository.startCalls, 1);
    expect(repository.state.phase, WearableConnectionPhase.running);
  });

  testWidgets('fresh install Connect action selects the configured Pi itself', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    container.read(wearableControllerProvider);
    await tester.pump();

    await controller.connectDefaultAndStartAssistance();

    expect(repository.selectedDevices.single.host, WearableDefaults.host);
    expect(repository.selectedDevices.single.port, WearableDefaults.port);
    expect(repository.enrollCalls, 1);
    expect(repository.connectCalls, 1);
    expect(repository.startCalls, 1);
  });

  testWidgets('fresh install Connect action uses the discovered Pi address', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
      discovered: const [_device],
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    container.read(wearableControllerProvider);
    await tester.pump();

    await controller.connectDefaultAndStartAssistance();

    expect(repository.selectedDevices.single.host, _device.host);
    expect(repository.enrollCalls, 1);
    expect(repository.connectCalls, 1);
    expect(repository.startCalls, 1);
  });

  testWidgets('fresh install does not auto-enroll among multiple wearables', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
      discovered: const [
        _device,
        WearableDevice(
          id: 'pi-other',
          name: 'Other wearable',
          host: '192.168.1.5',
          port: 8765,
          source: WearableDeviceSource.discovered,
        ),
      ],
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    container.read(wearableControllerProvider);
    await tester.pump();

    await controller.connectDefaultAndStartAssistance();

    expect(repository.selectedDevices, isEmpty);
    expect(repository.enrollCalls, 0);
    expect(repository.connectCalls, 0);
  });

  testWidgets('failed settings sync does not start or claim success', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      WearableSessionState.notConfigured,
      discovered: const [_device],
    )..settingsError = StateError('Pi settings storage unavailable');
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    final controller = container.read(wearableControllerProvider.notifier);
    await tester.pump();

    await controller.connectDefaultAndStartAssistance();

    final view = container.read(wearableControllerProvider);
    expect(repository.startCalls, 0);
    expect(view.settingsSyncState, WearableSettingsSyncState.failed);
    expect(view.failure?.code, 'settings_sync_failed');
    expect(view.liveMessage, contains('not synchronized'));
    expect(view.actionInProgress, isFalse);
  });

  testWidgets('first connection needs one button and no pairing-code field', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.deviceFound,
        selectedDevice: _device,
      ),
    );
    try {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            wearableRepositoryProvider.overrideWithValue(repository),
            wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
          ],
          child: const MaterialApp(home: RaspberryPiScreen()),
        ),
      );
      await tester.pump();

      expect(find.text('Pairing code'), findsNothing);
      expect(find.text('Pair Device'), findsNothing);
      expect(find.text('Connect & Start Detection'), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          'Connect securely to Test wearable and start Raspberry Pi object detection',
        ),
        findsOneWidget,
      );
    } finally {
      semantics.dispose();
      await repository.dispose();
    }
  });

  testWidgets('priority phone-target event is announced once on the phone', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.running,
        selectedDevice: _device,
      ),
    );
    final feedback = _RecordingWearablePhoneFeedback();
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
        wearablePhoneFeedbackServiceProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    container.read(wearableControllerProvider);
    await tester.pump();

    repository.emitEvent(
      WearableDetectionReceived(_phoneDetection, isHazard: true),
    );
    await tester.pump();

    expect(feedback.detections, [_phoneDetection]);
  });

  testWidgets('ordinary and Pi-target events do not trigger phone speech', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.running,
        selectedDevice: _device,
      ),
    );
    final feedback = _RecordingWearablePhoneFeedback();
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
        wearablePhoneFeedbackServiceProvider.overrideWithValue(feedback),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    container.read(wearableControllerProvider);
    await tester.pump();

    repository.emitEvent(
      WearableDetectionReceived(_phoneDetection, isHazard: false),
    );
    repository.emitEvent(
      WearableDetectionReceived(
        WearableDetectionEvent.fromPayload({
          ..._phoneDetection.toPayload(),
          'feedbackTarget': 'pi',
        }),
        isHazard: true,
      ),
    );
    await tester.pump();

    expect(feedback.detections, isEmpty);
  });

  testWidgets('failed phone speech shows an accessible warning', (
    tester,
  ) async {
    final repository = _FakeWearableRepository(
      const WearableSessionState(
        phase: WearableConnectionPhase.running,
        selectedDevice: _device,
      ),
    );
    final container = ProviderContainer(
      overrides: [
        wearableRepositoryProvider.overrideWithValue(repository),
        wearableClientIdProvider.overrideWith((ref) async => 'test-client'),
        wearablePhoneFeedbackServiceProvider.overrideWithValue(
          _FailingWearablePhoneFeedback(),
        ),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await repository.dispose();
    });
    container.read(wearableControllerProvider);
    await tester.pump();

    repository.emitEvent(
      WearableDetectionReceived(_phoneDetection, isHazard: true),
    );
    await tester.pump();

    expect(
      container.read(wearableControllerProvider).phoneFeedbackWarning,
      contains('phone could not announce'),
    );
  });
}

const _device = WearableDevice(
  id: 'pi-test',
  name: 'Test wearable',
  host: '192.168.1.4',
  port: 8765,
  source: WearableDeviceSource.saved,
);

final _phoneDetection = WearableDetectionEvent(
  sourceDeviceId: 'pi-test',
  frameSequence: 7,
  classId: 90,
  className: 'Car',
  confidence: 0.91,
  boundingBox: const BoundingBox(left: 0.2, top: 0.1, right: 0.8, bottom: 0.9),
  direction: WearableDirection.center,
  capturedAt: DateTime.utc(2026, 8, 20),
  priority: 92,
  relativeProximity: 'very_close',
  feedbackTarget: WearableFeedbackTarget.phone,
);

class _RecordingWearablePhoneFeedback implements WearablePhoneFeedbackService {
  final List<WearableDetectionEvent> detections = [];
  int tests = 0;
  int stops = 0;
  Completer<void>? pending;

  @override
  Future<void> announce(WearableDetectionEvent detection) async {
    detections.add(detection);
    await pending?.future;
  }

  @override
  Future<void> testAudio() async {
    tests++;
  }

  @override
  Future<void> stop() async {
    stops++;
  }
}

class _FailingWearablePhoneFeedback implements WearablePhoneFeedbackService {
  @override
  Future<void> announce(WearableDetectionEvent detection) async {
    throw StateError('TTS unavailable');
  }

  @override
  Future<void> testAudio() async => throw StateError('TTS unavailable');

  @override
  Future<void> stop() async {}
}

class _FakeWearableRepository implements WearableRepository {
  _FakeWearableRepository(this._state, {this.discovered = const []});

  WearableSessionState _state;
  final List<WearableDevice> discovered;
  final _states = StreamController<WearableSessionState>.broadcast();
  final _events = StreamController<WearableRepositoryEvent>.broadcast();
  int connectCalls = 0;
  int enrollCalls = 0;
  int disconnectCalls = 0;
  int stopCalls = 0;
  int startCalls = 0;
  int settingsWrites = 0;
  Object? settingsError;
  int discoverCalls = 0;
  Completer<List<WearableDevice>>? discoveryGate;
  final List<WearableDevice> selectedDevices = [];

  @override
  WearableSessionState get state => _state;

  @override
  Stream<WearableSessionState> get states => _states.stream;

  @override
  Stream<WearableRepositoryEvent> get events => _events.stream;

  void _set(WearableSessionState value) {
    _state = value;
    _states.add(value);
  }

  void emitEvent(WearableRepositoryEvent event) {
    _events.add(event);
  }

  @override
  Future<void> connect() async {
    connectCalls++;
    _set(
      _state.copyWith(
        phase: WearableConnectionPhase.connected,
        selectedDevice: _device,
      ),
    );
  }

  @override
  Future<void> disconnect() async {
    disconnectCalls++;
    _set(_state.copyWith(phase: WearableConnectionPhase.disconnected));
  }

  @override
  Future<List<WearableDevice>> discover() async {
    discoverCalls++;
    return discoveryGate == null ? discovered : discoveryGate!.future;
  }

  @override
  Future<void> dispose() async {
    if (!_states.isClosed) await _states.close();
    if (!_events.isClosed) await _events.close();
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> enroll() async {
    enrollCalls++;
    _set(
      _state.copyWith(
        phase: WearableConnectionPhase.paired,
        selectedDevice: _device,
      ),
    );
  }

  @override
  void selectDevice(WearableDevice device) {
    selectedDevices.add(device);
    _set(
      _state.copyWith(
        phase: WearableConnectionPhase.deviceFound,
        selectedDevice: device,
      ),
    );
  }

  @override
  Future<void> pair(String pairingCode) async {}

  @override
  Future<void> startAssistance() async {
    startCalls++;
    _set(_state.copyWith(phase: WearableConnectionPhase.running));
  }

  @override
  Future<void> pauseAssistance() async {
    _set(_state.copyWith(phase: WearableConnectionPhase.paused));
  }

  @override
  Future<void> resumeAssistance() async {}

  @override
  Future<void> stopAssistance() async {
    stopCalls++;
    _set(_state.copyWith(phase: WearableConnectionPhase.connected));
  }

  @override
  Future<void> changeMode(String mode) async {}

  @override
  Future<void> updateSettings(WearableSettingsSnapshot settings) async {
    settingsWrites++;
    if (settingsError case final error?) throw error;
    _set(_state.copyWith(currentSettings: settings));
  }

  @override
  Future<void> requestCurrentSettings() async {}

  @override
  Future<void> forgetDevice() async {
    _set(WearableSessionState.notConfigured);
  }
}
