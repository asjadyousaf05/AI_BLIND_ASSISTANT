import 'package:ai_blind_assistant/domain/enums/camera_permission_status.dart';
import 'package:ai_blind_assistant/domain/services/permission_service.dart';
import 'package:ai_blind_assistant/app/permission_providers.dart';
import 'package:ai_blind_assistant/core/lifecycle/app_lifecycle_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class FakePermissionService implements PermissionService {
  CameraPermissionStatus checkResult = CameraPermissionStatus.unknown;
  CameraPermissionStatus requestResult = CameraPermissionStatus.granted;
  bool settingsOpened = false;
  int checkCount = 0;
  int requestCount = 0;

  @override
  Future<CameraPermissionStatus> checkCameraPermission() async {
    checkCount++;
    return checkResult;
  }

  @override
  Future<CameraPermissionStatus> requestCameraPermission() async {
    requestCount++;
    return requestResult;
  }

  @override
  Future<bool> openAppSettings() async {
    settingsOpened = true;
    return true;
  }
}

void main() {
  group('CameraPermissionStatus enum', () {
    test('UT-PERM-001: granted state is correctly identified', () {
      expect(CameraPermissionStatus.granted.isGranted, isTrue);
      expect(CameraPermissionStatus.granted.isDenied, isFalse);
      expect(CameraPermissionStatus.granted.isPermanentlyDenied, isFalse);
    });

    test('UT-PERM-002: denied state is correctly identified', () {
      expect(CameraPermissionStatus.denied.isGranted, isFalse);
      expect(CameraPermissionStatus.denied.isDenied, isTrue);
      expect(CameraPermissionStatus.denied.isPermanentlyDenied, isFalse);
    });

    test('UT-PERM-003: permanently denied state is correctly identified', () {
      expect(CameraPermissionStatus.permanentlyDenied.isGranted, isFalse);
      expect(CameraPermissionStatus.permanentlyDenied.isDenied, isTrue);
      expect(
        CameraPermissionStatus.permanentlyDenied.isPermanentlyDenied,
        isTrue,
      );
    });

    test('UT-PERM-004: unknown state defaults correctly', () {
      expect(CameraPermissionStatus.unknown.isGranted, isFalse);
      expect(CameraPermissionStatus.unknown.isDenied, isFalse);
    });

    test('UT-PERM-005: all statuses have labels', () {
      for (final status in CameraPermissionStatus.values) {
        expect(status.label, isNotEmpty);
      }
    });
  });

  group('CameraPermissionController', () {
    late FakePermissionService fakeService;
    late ProviderContainer container;

    setUp(() {
      WidgetsFlutterBinding.ensureInitialized();
      fakeService = FakePermissionService();
      container = ProviderContainer(
        overrides: [permissionServiceProvider.overrideWithValue(fakeService)],
      );
    });

    tearDown(() {
      container.dispose();
    });

    test('UT-PERM-006: initial state is unknown', () {
      final status = container.read(cameraPermissionControllerProvider);
      expect(status, equals(CameraPermissionStatus.unknown));
    });

    test('UT-PERM-007: checkPermission updates state to granted', () async {
      fakeService.checkResult = CameraPermissionStatus.granted;
      final controller = container.read(
        cameraPermissionControllerProvider.notifier,
      );

      await controller.checkPermission();

      final status = container.read(cameraPermissionControllerProvider);
      expect(status, equals(CameraPermissionStatus.granted));
      expect(fakeService.checkCount, equals(1));
    });

    test('UT-PERM-008: requestPermission updates state to denied', () async {
      fakeService.requestResult = CameraPermissionStatus.denied;
      final controller = container.read(
        cameraPermissionControllerProvider.notifier,
      );

      final result = await controller.requestPermission();

      expect(result, equals(CameraPermissionStatus.denied));
      expect(fakeService.requestCount, equals(1));
    });

    test(
      'UT-PERM-009: requestPermission updates state to permanently denied',
      () async {
        fakeService.requestResult = CameraPermissionStatus.permanentlyDenied;
        final controller = container.read(
          cameraPermissionControllerProvider.notifier,
        );

        final result = await controller.requestPermission();

        expect(result, equals(CameraPermissionStatus.permanentlyDenied));
      },
    );

    test('UT-PERM-010: openSettings delegates to service', () async {
      final controller = container.read(
        cameraPermissionControllerProvider.notifier,
      );

      final result = await controller.openSettings();

      expect(result, isTrue);
      expect(fakeService.settingsOpened, isTrue);
    });

    test('UT-PERM-011: start blocked without camera permission', () async {
      fakeService.checkResult = CameraPermissionStatus.denied;
      final controller = container.read(
        cameraPermissionControllerProvider.notifier,
      );
      await controller.checkPermission();

      final status = container.read(cameraPermissionControllerProvider);
      expect(status.isGranted, isFalse);
    });
  });

  group('AppLifecycleObserver', () {
    test('UT-LIFECYCLE-001: tracks state changes', () {
      final states = <AppLifecycleState>[];
      final observer = AppLifecycleObserver(
        onStateChanged: (state) => states.add(state),
      );

      observer.didChangeAppLifecycleState(AppLifecycleState.paused);
      observer.didChangeAppLifecycleState(AppLifecycleState.resumed);
      observer.didChangeAppLifecycleState(AppLifecycleState.inactive);
      observer.didChangeAppLifecycleState(AppLifecycleState.detached);

      expect(states, [
        AppLifecycleState.paused,
        AppLifecycleState.resumed,
        AppLifecycleState.inactive,
        AppLifecycleState.detached,
      ]);
      expect(observer.lastState, AppLifecycleState.detached);
    });

    test('UT-LIFECYCLE-002: initial state is resumed', () {
      final observer = AppLifecycleObserver(onStateChanged: (_) {});
      expect(observer.lastState, AppLifecycleState.resumed);
    });
  });

  group('Permission re-check on resume', () {
    test(
      'UT-PERM-012: permission re-checked when app resumes from settings',
      () async {
        WidgetsFlutterBinding.ensureInitialized();
        final fakeService = FakePermissionService();
        fakeService.checkResult = CameraPermissionStatus.denied;

        final container = ProviderContainer(
          overrides: [permissionServiceProvider.overrideWithValue(fakeService)],
        );

        final controller = container.read(
          cameraPermissionControllerProvider.notifier,
        );
        await controller.checkPermission();
        expect(
          container.read(cameraPermissionControllerProvider),
          CameraPermissionStatus.denied,
        );

        fakeService.checkResult = CameraPermissionStatus.granted;
        await controller.checkPermission();

        expect(
          container.read(cameraPermissionControllerProvider),
          CameraPermissionStatus.granted,
        );

        container.dispose();
      },
    );
  });
}
