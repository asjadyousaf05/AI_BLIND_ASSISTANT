abstract final class RoutePaths {
  static const startup = '/startup';
  static const home = '/home';
  static const modeSelection = '/modes';
  static const mobileAssistance = '/mobile-assistance';
  static const raspberryPi = '/raspberry-pi';
  static const raspberryPiError = '/raspberry-pi/error';
  static const settings = '/settings';
  static const aboutSafety = '/about-safety';
  static const permissions = '/permissions/camera';
  static const help = '/help';
  static const assistant = '/assistant';
  static const assistantConnection = '/assistant/connection';
  static const assistantSettings = '/assistant/settings';
  static const ocrScanner = '/ocr-scanner';

  static bool isAssistantRoute(String? path) =>
      path == assistant ||
      path == assistantConnection ||
      path == assistantSettings;
}
