import 'package:ai_blind_assistant/app/assistant_providers.dart';
import 'package:ai_blind_assistant/app/voice_kernel/command_executor.dart';
import 'package:ai_blind_assistant/domain/entities/voice_command.dart';
import 'package:ai_blind_assistant/domain/entities/voice_command_result.dart';
import 'package:ai_blind_assistant/domain/enums/voice_intent.dart';
import 'package:ai_blind_assistant/domain/services/speech_output_service.dart';
import 'package:ai_blind_assistant/infrastructure/device/android_battery_status_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _Speech implements SpeechOutputService {
  double? rate;
  bool fail = false;
  @override
  Future<void> setSpeechRate(double value) async {
    if (fail) throw StateError('Test speech engine failure');
    rate = value;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const service = AndroidBatteryStatusService();
  final executorProvider = Provider((ref) => CommandExecutor(ref));
  late ProviderContainer container;
  late _Speech speech;
  setUp(() {
    speech = _Speech();
    container = ProviderContainer(
      overrides: [speechOutputServiceProvider.overrideWithValue(speech)],
    );
  });
  tearDown(() {
    container.dispose();
    messenger.setMockMethodCallHandler(
      AndroidBatteryStatusService.channel,
      null,
    );
  });

  for (final percentage in [0, 37, 100, -1, 101, null]) {
    test(
      'battery channel validates $percentage and never invents a level',
      () async {
        messenger.setMockMethodCallHandler(
          AndroidBatteryStatusService.channel,
          (call) async {
            expect(call.method, 'batteryPercentage');
            return percentage;
          },
        );
        final expected =
            percentage != null && percentage >= 0 && percentage <= 100
            ? percentage
            : null;
        expect(await service.readPercentage(), expected);
        final result = await container
            .read(executorProvider)
            .execute(
              const VoiceCommand(
                intent: GetBatteryStatus(),
                matchScore: 1,
                matchType: VoiceMatchType.exact,
              ),
            );
        if (expected == null) {
          expect(result, isA<VoiceCommandUnavailable>());
        } else {
          expect((result as VoiceCommandSuccess).data['level'], expected);
          expect(result.feedbackText, contains('$expected percent'));
        }
      },
    );
  }

  test('battery plugin failure reports unavailable', () async {
    messenger.setMockMethodCallHandler(
      AndroidBatteryStatusService.channel,
      (_) async => throw PlatformException(code: 'unavailable'),
    );
    expect(await service.readPercentage(), isNull);
  });

  test(
    'speech rate command applies the selected rate before success',
    () async {
      final result = await container
          .read(executorProvider)
          .execute(
            const VoiceCommand(
              intent: SetSpeechRate('slow'),
              matchScore: 1,
              matchType: VoiceMatchType.exact,
            ),
          );
      expect(result, isA<VoiceCommandSuccess>());
      expect(speech.rate, 0.35);
      speech.fail = true;
      final failed = await container
          .read(executorProvider)
          .execute(
            const VoiceCommand(
              intent: SetSpeechRate('fast'),
              matchScore: 1,
              matchType: VoiceMatchType.exact,
            ),
          );
      expect(failed, isA<VoiceCommandFailure>());
    },
  );

  test('uninitialized camera cannot claim torch-on success', () async {
    final result = await container
        .read(executorProvider)
        .execute(
          const VoiceCommand(
            intent: SetFlashlight(enabled: true),
            matchScore: 1,
            matchType: VoiceMatchType.exact,
          ),
        );
    expect(result, isA<VoiceCommandUnavailable>());
  });
}
