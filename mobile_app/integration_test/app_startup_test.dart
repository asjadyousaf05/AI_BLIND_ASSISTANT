import 'package:ai_blind_assistant/app/app.dart';
import 'package:ai_blind_assistant/core/constants/app_strings.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('IT-STARTUP-001 app starts on startup route', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: AiBlindAssistantApp()));

    expect(find.text(AppStrings.startupTitle), findsWidgets);
    expect(find.text(AppStrings.continueToHome), findsOneWidget);
  });
}
