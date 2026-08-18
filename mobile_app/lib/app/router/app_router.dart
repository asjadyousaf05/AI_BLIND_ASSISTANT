import 'package:flutter/material.dart';

import '../../features/about/presentation/about_safety_screen.dart';
import '../../features/assistant/presentation/assistant_connection_screen.dart';
import '../../features/assistant/presentation/assistant_screen.dart';
import '../../features/assistant/presentation/assistant_settings_screen.dart';
import '../../features/help/presentation/help_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/mobile_assistance/presentation/mobile_assistance_screen.dart';
import '../../features/mode_selection/presentation/mode_selection_screen.dart';
import '../../features/ocr_scanner/presentation/ocr_scanner_screen.dart';
import '../../features/permissions/presentation/permissions_screen.dart';
import '../../features/raspberry_pi/presentation/connection_error_screen.dart';
import '../../features/raspberry_pi/presentation/raspberry_pi_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/startup/presentation/startup_screen.dart';
import 'route_paths.dart';
import 'unknown_route_screen.dart';

abstract final class AppRouter {
  static Route<void> onGenerateRoute(RouteSettings settings) {
    final routeName = settings.name;
    final Widget screen = switch (routeName) {
      RoutePaths.startup => const StartupScreen(),
      RoutePaths.home => const HomeScreen(),
      RoutePaths.modeSelection => const ModeSelectionScreen(),
      RoutePaths.mobileAssistance => const MobileAssistanceScreen(),
      RoutePaths.raspberryPi => const RaspberryPiScreen(),
      RoutePaths.raspberryPiError => const ConnectionErrorScreen(),
      RoutePaths.settings => const SettingsScreen(),
      RoutePaths.aboutSafety => const AboutSafetyScreen(),
      RoutePaths.permissions => const PermissionsScreen(),
      RoutePaths.help => const HelpScreen(),
      RoutePaths.assistant => const AssistantScreen(),
      RoutePaths.assistantConnection => const AssistantConnectionScreen(),
      RoutePaths.assistantSettings => const AssistantSettingsScreen(),
      RoutePaths.ocrScanner => const OcrScannerScreen(),
      _ => UnknownRouteScreen(unknownRouteName: routeName),
    };

    return MaterialPageRoute<void>(builder: (_) => screen, settings: settings);
  }
}
