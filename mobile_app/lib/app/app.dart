import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants/app_strings.dart';
import 'providers.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';
import 'theme/app_theme.dart';

class AiBlindAssistantApp extends ConsumerWidget {
  const AiBlindAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      initialRoute: RoutePaths.startup,
      onGenerateRoute: AppRouter.onGenerateRoute,
      theme: settings.highContrastEnabled
          ? AppTheme.highContrastLight
          : AppTheme.light,
      darkTheme: settings.highContrastEnabled
          ? AppTheme.highContrastDark
          : AppTheme.dark,
      themeMode: ThemeMode.system,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        final systemScale = mediaQuery.textScaler.scale(1);
        final preferredScale = settings.largeTextEnabled
            ? (systemScale * 1.2).clamp(1.0, 2.5).toDouble()
            : systemScale;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: TextScaler.linear(preferredScale),
            disableAnimations:
                mediaQuery.disableAnimations || settings.reducedMotionEnabled,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
