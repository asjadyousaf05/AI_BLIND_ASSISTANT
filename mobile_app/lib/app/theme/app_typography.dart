import 'package:flutter/material.dart';

abstract final class AppTypography {
  static TextTheme textTheme(ColorScheme colorScheme) {
    return Typography.material2021().black.copyWith(
      displayLarge: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 48,
        fontWeight: FontWeight.w900,
        height: 1.05,
        letterSpacing: 0,
      ),
      displayMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 42,
        fontWeight: FontWeight.w800,
        height: 1.08,
        letterSpacing: 0,
      ),
      headlineLarge: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 32,
        fontWeight: FontWeight.w800,
        height: 1.12,
        letterSpacing: 0,
      ),
      headlineMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.16,
        letterSpacing: 0,
      ),
      headlineSmall: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleLarge: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 22,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      titleMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: 0,
      ),
      bodyLarge: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
        height: 1.4,
        letterSpacing: 0,
      ),
      bodyMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        height: 1.4,
        letterSpacing: 0,
      ),
      labelLarge: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      labelMedium: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 14,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
      labelSmall: TextStyle(
        color: colorScheme.onSurface,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: 0,
      ),
    );
  }
}
