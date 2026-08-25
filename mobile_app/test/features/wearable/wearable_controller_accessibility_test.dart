import 'dart:async';

import 'package:ai_blind_assistant/app/wearable_controller.dart';
import 'package:ai_blind_assistant/app/wearable_providers.dart';
import 'package:ai_blind_assistant/core/constants/wearable_defaults.dart';
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
      expect(find.bySemanticsLabel('No wearable configured'), findsWidgets);
      expect(
        find.bySemanticsLabel(
          'Search the local network for a Raspberry Pi wearable',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Validate and select this local Raspberry Pi address',
        ),
        findsOneWidget,
      );
      // The default hostname appears in the pre-filled host text field and
      // also in the connection guidance card below it.
      expect(find.text(WearableDefaults.host), findsWidgets);
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      await repository.dispose();
    }
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

  @override
  Future<void> announce(WearableDetectionEvent detection) async {
    detections.add(detection);
  }
}

class _FakeWearableRepository implements WearableRepository {
  _FakeWearableRepository(this._state);

  WearableSessionState _state;
  final _states = StreamController<WearableSessionState>.broadcast();
  final _events = StreamController<WearableRepositoryEvent>.broadcast();
  int connectCalls = 0;
  int enrollCalls = 0;
  int disconnectCalls = 0;
  int stopCalls = 0;
  int startCalls = 0;
  int settingsWrites = 0;
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
  Future<List<WearableDevice>> discover() async => const [];

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
  Future<void> pauseAssistance() async {}

  @override
  Future<void> resumeAssistance() async {}

  @override
  Future<void> stopAssistance() async {
    stopCalls++;
  }

  @override
  Future<void> changeMode(String mode) async {}

  @override
  Future<void> updateSettings(WearableSettingsSnapshot settings) async {
    settingsWrites++;
    _set(_state.copyWith(currentSettings: settings));
  }

  @override
  Future<void> requestCurrentSettings() async {}

  @override
  Future<void> forgetDevice() async {
    _set(WearableSessionState.notConfigured);
  }
}
