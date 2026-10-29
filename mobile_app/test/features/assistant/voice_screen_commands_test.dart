import 'dart:async';

import 'package:ai_blind_assistant/app/app.dart';
import 'package:ai_blind_assistant/app/assistance_controller.dart';
import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/router/app_route_observer.dart';
import 'package:ai_blind_assistant/app/router/route_paths.dart';
import 'package:ai_blind_assistant/app/smart_ai_cloud_providers.dart';
import 'package:ai_blind_assistant/app/voice_kernel/voice_kernel_providers.dart';
import 'package:ai_blind_assistant/app/wearable_controller.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_device.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_failure.dart';
import 'package:ai_blind_assistant/domain/entities/wearable_session_state.dart';
import 'package:ai_blind_assistant/domain/enums/mobile_assistance_state.dart';
import 'package:ai_blind_assistant/domain/enums/voice_feature_context.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_connection_phase.dart';
import 'package:ai_blind_assistant/domain/enums/wearable_failure_kind.dart';
import 'package:ai_blind_assistant/domain/services/on_device_speech_recognition_service.dart';
import 'package:ai_blind_assistant/domain/services/smart_ai_reply_speech_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'assistant_controller_test.dart'
    show
        FakeAssistanceController,
        FakeMicrophonePermissionService,
        FakeOnDeviceSpeechRecognitionService,
        FakeSpeechOutputService;

const _device = WearableDevice(
  id: 'test-pi',
  name: 'Test Pi',
  host: '192.168.1.2',
  port: 8765,
  source: WearableDeviceSource.discovered,
);
const _networkFailure = WearableFailure(
  kind: WearableFailureKind.network,
  code: 'test_network',
  userMessage: 'Local network discovery is unavailable. Check Wi-Fi.',
);

class _Wearable extends WearableController {
  List<WearableDevice> devices = [];
  WearableFailure? discoveryFailure;
  WearableFailure? connectionFailure;
  Completer<void>? discoveryGate;
  int discoveries = 0;
  int connections = 0;
  WearableConnectionPhase controlOutcome = WearableConnectionPhase.error;
  @override
  WearableControllerState build() => const WearableControllerState(
    session: WearableSessionState.disconnected,
    liveMessage: 'Ready',
  );
  @override
  Future<void> discover() async {
    discoveries++;
    await discoveryGate?.future;
    state = WearableControllerState(
      session: WearableSessionState(
        phase: WearableConnectionPhase.deviceFound,
        discoveredDevices: devices,
        failure: discoveryFailure,
      ),
      liveMessage: 'Discovery finished',
    );
  }

  @override
  void selectDevice(WearableDevice device) {
    state = state.copyWith(
      session: state.session.copyWith(selectedDevice: device),
    );
  }

  @override
  Future<void> connect() async {
    connections++;
    state = state.copyWith(
      session: state.session.copyWith(
        phase: connectionFailure == null
            ? WearableConnectionPhase.connected
            : WearableConnectionPhase.error,
        failure: connectionFailure,
      ),
    );
  }

  @override
  Future<void> pauseAssistance() async {
    state = state.copyWith(
      session: state.session.copyWith(phase: controlOutcome),
    );
  }

  @override
  Future<void> resumeAssistance() => pauseAssistance();
  @override
  Future<void> stopAssistance() => pauseAssistance();
}

class _Mobile extends FakeAssistanceController {
  MobileAssistanceState outcome = MobileAssistanceState.active;
  int starts = 0;
  @override
  Future<void> startAssistance() async {
    starts++;
    setAssistanceState(outcome);
  }
}

class _Reply implements SmartAiReplySpeechService {
  @override
  Future<void> speak(String text) async {}
  @override
  Future<void> stop() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> resume() async {}
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late ProviderContainer container;
  late _Wearable wearable;
  late _Mobile mobile;
  late FakeSpeechOutputService speech;
  late FakeOnDeviceSpeechRecognitionService recognizer;
  setUp(() async {
    binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    appRouteObserver.currentRoute = null;
    wearable = _Wearable();
    mobile = _Mobile();
    speech = FakeSpeechOutputService();
    recognizer = FakeOnDeviceSpeechRecognitionService();
    container = ProviderContainer(
      overrides: [
        wearableControllerProvider.overrideWith(() => wearable),
        assistanceControllerProvider.overrideWith(() => mobile),
        speechOutputServiceProvider.overrideWithValue(speech),
        onDeviceSpeechRecognitionServiceProvider.overrideWithValue(recognizer),
        microphonePermissionServiceProvider.overrideWithValue(
          FakeMicrophonePermissionService(),
        ),
        smartAiReplySpeechProvider.overrideWithValue(_Reply()),
        assistantRepositoryProvider.overrideWith(
          (_) => throw StateError('Local control contacted Smart AI'),
        ),
      ],
    );
    container.read(visionVoiceKernelProvider);
    await Future<void>.delayed(Duration.zero);
  });
  tearDown(() {
    container.dispose();
    appRouteObserver.currentRoute = null;
  });

  test(
    'Pi discovery speaks progress before waiting, then useful not-found guidance',
    () async {
      wearable.discoveryGate = Completer<void>();
      final kernel = container.read(visionVoiceKernelProvider.notifier);
      final resumes = recognizer.handsFreeResumeCount;
      final operation = kernel.processManualCommand('connect to raspberry pi');
      await Future<void>.delayed(Duration.zero);
      expect(speech.spokenTexts, [
        'Finding Raspberry Pi on your local network.',
      ]);
      expect(wearable.discoveries, 1);
      expect(recognizer.handsFreeResumeCount, resumes);
      recognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(
          type: HandsFreeSpeechEventType.command,
          transcript: 'connect to raspberry pi',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(wearable.discoveries, 1);
      wearable.discoveryGate!.complete();
      expect(await operation, contains('same Wi-Fi or phone hotspot'));
      expect(wearable.connections, 0);
      expect(speech.spokenTexts.last, startsWith('No Raspberry Pi was found.'));
    },
  );

  test(
    'Pi connection announces finding, connecting and verified success in order',
    () async {
      wearable.devices = [_device];
      final kernel = container.read(visionVoiceKernelProvider.notifier);
      await kernel.processManualCommand(
        'can you please connect to raspberry pi',
      );
      expect(wearable.connections, 1);
      expect(speech.spokenTexts, [
        'Finding Raspberry Pi on your local network.',
        'Connecting to Raspberry Pi.',
        'Raspberry Pi connected. Say start wearable to begin detection.',
      ]);
      await kernel.processManualCommand('connect to raspberry pi');
      expect(speech.spokenTexts.last, 'Raspberry Pi is already connected.');
      expect(wearable.connections, 1);
    },
  );

  test('discovery and connection failures never announce success', () async {
    final kernel = container.read(visionVoiceKernelProvider.notifier);
    wearable.discoveryFailure = _networkFailure;
    expect(
      await kernel.processManualCommand('find raspberry pi'),
      _networkFailure.userMessage,
    );
    expect(wearable.connections, 0);
    wearable.discoveryFailure = null;
    wearable.devices = [_device];
    wearable.connectionFailure = _networkFailure;
    expect(
      await kernel.processManualCommand('connect pi'),
      _networkFailure.userMessage,
    );
    expect(
      speech.spokenTexts.where((s) => s.startsWith('Raspberry Pi connected')),
      isEmpty,
    );
  });

  test(
    'multiple Pi devices request selection without connecting arbitrarily',
    () async {
      wearable.devices = [
        _device,
        _device.copyWith(id: 'second', host: '192.168.1.3'),
      ];
      final result = await container
          .read(visionVoiceKernelProvider.notifier)
          .processManualCommand('connect pi');
      expect(result, contains('Choose one'));
      expect(wearable.connections, 0);
    },
  );

  for (final outcome in [
    MobileAssistanceState.active,
    MobileAssistanceState.permissionRequired,
    MobileAssistanceState.error,
    MobileAssistanceState.paused,
  ]) {
    test('Mobile Mode reports actual $outcome startup outcome', () async {
      mobile.outcome = outcome;
      final result = await container
          .read(visionVoiceKernelProvider.notifier)
          .processManualCommand('start mobile mode');
      expect(
        speech.spokenTexts.first,
        'Starting Mobile Mode. Preparing the camera.',
      );
      expect(result!.contains('Object detection is active'), outcome.isActive);
      if (outcome == MobileAssistanceState.permissionRequired) {
        expect(result, contains('Allow camera access'));
      }
      expect(mobile.starts, 1);
    });
  }

  test(
    'manual controls apply the same screen restrictions as spoken controls',
    () async {
      final kernel = container.read(visionVoiceKernelProvider.notifier);
      kernel.setFeatureContext(VoiceFeatureContext.settings);
      expect(
        await kernel.processManualCommand('pause reading'),
        contains('not available on this screen'),
      );
      expect(
        await kernel.processManualCommand('start mobile mode'),
        contains('not available on this screen'),
      );
      expect(mobile.starts, 0);
    },
  );

  for (final action in ['pause', 'resume', 'stop']) {
    for (final succeeds in [true, false]) {
      test(
        'wearable $action reports only confirmed outcome (success=$succeeds)',
        () async {
          final kernel = container.read(visionVoiceKernelProvider.notifier);
          kernel.setFeatureContext(VoiceFeatureContext.wearable);
          wearable.controlOutcome = !succeeds
              ? WearableConnectionPhase.error
              : switch (action) {
                  'pause' => WearableConnectionPhase.paused,
                  'resume' => WearableConnectionPhase.running,
                  _ => WearableConnectionPhase.connected,
                };
          final result = await kernel.processManualCommand(action);
          expect(
            result!.contains('could not') || result.contains('did not confirm'),
            !succeeds,
          );
        },
      );
    }
  }

  testWidgets(
    'route restoration preserves reader context and Home clears covered screens',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [appRouteObserver],
          initialRoute: RoutePaths.home,
          routes: {
            for (final route in [
              RoutePaths.home,
              RoutePaths.ocrScanner,
              RoutePaths.settings,
            ])
              route: (_) => Scaffold(body: Text(route)),
          },
        ),
      );
      await tester.pumpAndSettle();
      final kernel = container.read(visionVoiceKernelProvider.notifier);
      appNavigatorKey.currentState!.pushNamed(RoutePaths.ocrScanner);
      await tester.pumpAndSettle();
      kernel.setFeatureContext(VoiceFeatureContext.scannerReading);
      appNavigatorKey.currentState!.pushNamed(RoutePaths.settings);
      await tester.pumpAndSettle();
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.settings,
      );
      appNavigatorKey.currentState!.pop();
      await tester.pumpAndSettle();
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.scannerReading,
      );
      await kernel.processManualCommand('go home');
      await tester.pumpAndSettle();
      expect(appRouteObserver.currentRoute, RoutePaths.home);
      expect(appNavigatorKey.currentState!.canPop(), false);
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.home,
      );
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'Smart AI idle and paused accept direct navigation using the visible screen',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: appNavigatorKey,
          navigatorObservers: [appRouteObserver],
          initialRoute: RoutePaths.home,
          routes: {
            for (final route in [
              RoutePaths.home,
              RoutePaths.assistant,
              RoutePaths.settings,
              RoutePaths.aboutSafety,
            ])
              route: (_) => Scaffold(body: Text(route)),
          },
        ),
      );
      await tester.pumpAndSettle();
      appNavigatorKey.currentState!.pushNamed(RoutePaths.assistant);
      await tester.pumpAndSettle();
      final audio = container.read(smartAiAudioCoordinatorProvider);
      await audio.acquire();
      expect(recognizer.acceptNextCommand, true);
      expect(
        container.read(visionVoiceKernelProvider).isCommandSessionActive,
        true,
      );
      await audio.pauseSpeech();
      expect(recognizer.acceptNextCommand, true);
      recognizer.handsFreeEventController.add(
        const HandsFreeSpeechEvent(
          type: HandsFreeSpeechEventType.command,
          transcript: 'can you please go back',
        ),
      );
      await tester.pumpAndSettle();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pumpAndSettle();
      expect(appRouteObserver.currentRoute, RoutePaths.home);
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.home,
      );
      // A late dispose from the page we just left cannot erase Home's context.
      container
          .read(visionVoiceKernelProvider.notifier)
          .setFeatureContext(VoiceFeatureContext.unknown);
      expect(
        container.read(visionVoiceKernelProvider).activeContext,
        VoiceFeatureContext.home,
      );
      await tester.runAsync(audio.release);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
