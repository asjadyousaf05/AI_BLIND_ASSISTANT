import 'dart:async';

import 'package:ai_blind_assistant/app/wearable_controller.dart';
import 'package:ai_blind_assistant/app/wearable_providers.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_device.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_repository_event.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_session_state.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_settings_snapshot.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_connection_phase.dart';
import 'package:ai_blind_assistant/domain/repositories/wearable_repository.dart';
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
      expect(tester.takeException(), isNull);
    } finally {
      semantics.dispose();
      await repository.dispose();
    }
  });
}

const _device = WearableDevice(
  id: 'pi-test',
  name: 'Test wearable',
  host: '192.168.1.4',
  port: 8765,
  source: WearableDeviceSource.saved,
);

class _FakeWearableRepository implements WearableRepository {
  _FakeWearableRepository(this._state);

  WearableSessionState _state;
  final _states = StreamController<WearableSessionState>.broadcast();
  final _events = StreamController<WearableRepositoryEvent>.broadcast();
  int connectCalls = 0;
  int disconnectCalls = 0;
  int stopCalls = 0;
  int settingsWrites = 0;

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
  void selectDevice(WearableDevice device) {
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
  Future<void> startAssistance() async {}

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
