import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_dimensions.dart';
import 'app_radii.dart';
import 'app_typography.dart';

abstract final class AppTheme {
  static ThemeData get light => _buildTheme(Brightness.light);
  static ThemeData get dark => _buildTheme(Brightness.dark);
  static ThemeData get highContrastLight =>
      _buildTheme(Brightness.light, highContrast: true);
  static ThemeData get highContrastDark =>
      _buildTheme(Brightness.dark, highContrast: true);

  static ThemeData _buildTheme(
    Brightness brightness, {
    bool highContrast = false,
  }) {
    final seededScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: brightness,
    );

    final colorScheme = seededScheme.copyWith(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      surface: highContrast
          ? (brightness == Brightness.dark ? Colors.black : Colors.white)
          : (brightness == Brightness.dark
                ? AppColors.darkBackground
                : AppColors.lightBackground),
      onSurface: highContrast
          ? (brightness == Brightness.dark ? Colors.white : Colors.black)
          : (brightness == Brightness.dark
                ? AppColors.onDarkSurface
                : AppColors.onLightSurface),
      surfaceContainerHighest: brightness == Brightness.dark
          ? AppColors.darkSurface
          : AppColors.lightSurfaceMuted,
      secondaryContainer: brightness == Brightness.dark
          ? AppColors.primaryOverlay20
          : AppColors.primaryOverlay10,
      onSecondaryContainer: brightness == Brightness.dark
          ? AppColors.onDarkSurface
          : AppColors.onLightSurface,
      outline: highContrast
          ? (brightness == Brightness.dark ? Colors.white : Colors.black)
          : (brightness == Brightness.dark
                ? AppColors.slate700
                : AppColors.slate300),
      outlineVariant: highContrast
          ? (brightness == Brightness.dark
                ? AppColors.slate300
                : AppColors.slate700)
          : (brightness == Brightness.dark
                ? AppColors.slate800
                : AppColors.slate200),
      error: AppColors.error,
    );

    return ThemeData(
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      useMaterial3: true,
      textTheme: AppTypography.textTheme(colorScheme),
      iconTheme: IconThemeData(
        color: colorScheme.onSurface,
        size: AppDimensions.iconMedium,
      ),
      dividerColor: colorScheme.outlineVariant,
      focusColor: AppColors.primaryOverlay20,
      hoverColor: AppColors.primaryOverlay10,
      appBarTheme: AppBarTheme(
        centerTitle: true,
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          minimumSize: const Size.fromHeight(
            AppDimensions.primaryControlHeight,
          ),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.extraLarge),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(
            AppDimensions.primaryControlHeight,
          ),
          foregroundColor: colorScheme.onSurface,
          side: BorderSide(color: colorScheme.outline),
          textStyle: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            letterSpacing: 0,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.extraLarge),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        color: brightness == Brightness.dark
            ? AppColors.darkSurface
            : AppColors.lightSurfaceMuted,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.extraLarge),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.onPrimary;
          }
          return AppColors.lightSurface;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return brightness == Brightness.dark
              ? AppColors.slate700
              : AppColors.slate200;
        }),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.primary;
          }
          return colorScheme.outline;
        }),
      ),
    );
  }
}
