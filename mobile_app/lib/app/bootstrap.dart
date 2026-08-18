import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/logging/app_logger.dart';
import '../core/logging/safe_debug_logger.dart';
import 'app.dart';
import 'providers.dart';

void bootstrapApplication() {
  WidgetsFlutterBinding.ensureInitialized();

  const AppLogger logger = SafeDebugLogger();
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    logger.error(
      'Flutter framework error',
      error: details.exception,
      stackTrace: details.stack,
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stackTrace) {
    logger.error(
      'Uncaught platform error',
      error: error,
      stackTrace: stackTrace,
    );
    return false;
  };

  final container = ProviderContainer();

  // Load persisted settings at startup
  container.read(appSettingsControllerProvider.notifier).loadFromStorage();

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const AiBlindAssistantApp(),
    ),
  );
}
