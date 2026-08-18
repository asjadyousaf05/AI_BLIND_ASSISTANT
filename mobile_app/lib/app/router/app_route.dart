import '../../core/constants/app_strings.dart';
import 'route_paths.dart';

enum AppRoute {
  startup(RoutePaths.startup, AppStrings.startupTitle),
  home(RoutePaths.home, AppStrings.homeTitle),
  modeSelection(RoutePaths.modeSelection, AppStrings.modeSelectionTitle),
  mobileAssistance(
    RoutePaths.mobileAssistance,
    AppStrings.mobileAssistanceTitle,
  ),
  raspberryPi(RoutePaths.raspberryPi, AppStrings.raspberryPiTitle),
  raspberryPiError(
    RoutePaths.raspberryPiError,
    AppStrings.connectionErrorTitle,
  ),
  settings(RoutePaths.settings, AppStrings.settingsTitle),
  aboutSafety(RoutePaths.aboutSafety, AppStrings.aboutSafetyTitle),
  permissions(RoutePaths.permissions, AppStrings.permissionsTitle),
  help(RoutePaths.help, AppStrings.helpTitle),
  assistant(RoutePaths.assistant, AppStrings.assistantTitle),
  assistantConnection(
    RoutePaths.assistantConnection,
    AppStrings.assistantConnectionTitle,
  ),
  assistantSettings(
    RoutePaths.assistantSettings,
    AppStrings.assistantSettingsTitle,
  );

  const AppRoute(this.path, this.title);

  final String path;
  final String title;
}
