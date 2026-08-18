import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/accessibility/preferred_text_scaler.dart';
import '../core/constants/app_strings.dart';
import 'providers.dart';
import 'router/app_route_observer.dart';
import 'router/app_router.dart';
import 'router/route_paths.dart';
import 'theme/app_theme.dart';
import 'voice_kernel/voice_kernel_providers.dart';

/// Application-scoped navigator key.
///
/// Exposed via [navigatorKeyProvider] so that the assistant controller can
/// perform voice-driven navigation without a BuildContext.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

class AiBlindAssistantApp extends ConsumerWidget {
  const AiBlindAssistantApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsControllerProvider);
    // Keep the foreground voice kernel coordinator alive from app startup
    ref.watch(visionVoiceKernelProvider);
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      navigatorKey: appNavigatorKey,
      navigatorObservers: [appRouteObserver],
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
        final preferredScaler = settings.largeTextEnabled
            ? PreferredTextScaler(platformScaler: mediaQuery.textScaler)
            : mediaQuery.textScaler;
        return MediaQuery(
          data: mediaQuery.copyWith(
            textScaler: preferredScaler,
            disableAnimations:
                mediaQuery.disableAnimations || settings.reducedMotionEnabled,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
