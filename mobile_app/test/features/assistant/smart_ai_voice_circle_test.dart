import 'package:ai_blind_assistant/features/assistant/presentation/smart_ai_voice_circle.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> events;
  setUp(() => events = []);
  Widget circle() => MaterialApp(
    home: Scaffold(
      body: SmartAiVoiceCircle(
        label: 'Hold to talk',
        hint: 'Hold one second, speak, then release.',
        icon: Icons.mic,
        enabled: true,
        listening: false,
        onTap: () => events.add('tap'),
        onHoldStart: () => events.add('hold'),
        onHoldEnd: () => events.add('release'),
        onHoldCancel: () => events.add('cancel'),
      ),
    ),
  );
  testWidgets(
    'one-second hold starts once and release sends once without a tap',
    (tester) async {
      await tester.pumpWidget(circle());
      final target = find.byKey(const Key('smart_ai_voice_circle'));
      final gesture = await tester.startGesture(tester.getCenter(target));
      await tester.pump(const Duration(milliseconds: 900));
      expect(events, isEmpty);
      await tester.pump(const Duration(milliseconds: 200));
      expect(events, ['hold']);
      await gesture.up();
      await tester.pump();
      expect(events, ['hold', 'release']);
    },
  );
  testWidgets('a short tap has no hold or release callback', (tester) async {
    await tester.pumpWidget(circle());
    await tester.tap(find.byKey(const Key('smart_ai_voice_circle')));
    expect(events.where((event) => event != 'cancel'), ['tap']);
  });
  testWidgets('TalkBack activation is available without a timed hold', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(circle());
    final node = tester.getSemantics(
      find.byKey(const Key('smart_ai_voice_circle')),
    );
    expect(node.getSemanticsData().label, 'Smart AI voice control');
    tester.binding.performSemanticsAction(
      SemanticsActionEvent(
        type: SemanticsAction.tap,
        viewId: tester.view.viewId,
        nodeId: node.id,
      ),
    );
    expect(events, ['tap']);
    semantics.dispose();
  });
  testWidgets('pointer cancellation after a hold does not submit', (
    tester,
  ) async {
    await tester.pumpWidget(circle());
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(const Key('smart_ai_voice_circle'))),
    );
    await tester.pump(const Duration(milliseconds: 1100));
    await gesture.cancel();
    await tester.pump();
    expect(events, contains('hold'));
    expect(events, isNot(contains('release')));
    expect(events, contains('cancel'));
  });
}
