import 'package:ai_blind_assistant/app/theme/app_colors.dart';
import 'package:ai_blind_assistant/app/theme/app_dimensions.dart';
import 'package:ai_blind_assistant/app/theme/app_icons.dart';
import 'package:ai_blind_assistant/app/theme/app_motion.dart';
import 'package:ai_blind_assistant/app/theme/app_radii.dart';
import 'package:ai_blind_assistant/app/theme/app_shadows.dart';
import 'package:ai_blind_assistant/app/theme/app_spacing.dart';
import 'package:ai_blind_assistant/app/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('UT-THEME-001 Stitch color tokens are centralized', () {
    expect(AppColors.primary.toARGB32(), 0xFF25C0F4);
    expect(AppColors.lightBackground.toARGB32(), 0xFFF5F8F8);
    expect(AppColors.darkBackground.toARGB32(), 0xFF101E22);
  });

  test('UT-THEME-002 primary button text contrast is accessible', () {
    expect(
      _contrastRatio(AppColors.primary, AppColors.onPrimary),
      greaterThanOrEqualTo(4.5),
    );
  });

  test('UT-THEME-003 spacing and sizing tokens preserve touch targets', () {
    expect(AppSpacing.space4, AppSpacing.md);
    expect(AppSpacing.space6, AppSpacing.lg);
    expect(AppDimensions.minTouchTarget, greaterThanOrEqualTo(48));
    expect(AppDimensions.primaryControlHeight, greaterThanOrEqualTo(56));
    expect(AppDimensions.prominentControlHeight, greaterThanOrEqualTo(64));
  });

  test('UT-THEME-004 radii, motion, shadow, and icon tokens are usable', () {
    expect(AppRadii.defaultRadius, 8);
    expect(AppRadii.large, 16);
    expect(AppRadii.extraLarge, 24);
    expect(AppMotion.activeScale, allOf(greaterThan(0), lessThan(1)));
    expect(AppMotion.fast, lessThan(AppMotion.slow));
    expect(AppShadows.primaryGlow, isNotEmpty);
    expect(AppIcons.visibility, isA<IconData>());
  });

  test('UT-THEME-005 light and dark Flutter themes build from tokens', () {
    expect(AppTheme.light.colorScheme.primary, AppColors.primary);
    expect(AppTheme.light.colorScheme.onPrimary, AppColors.onPrimary);
    expect(AppTheme.dark.colorScheme.primary, AppColors.primary);
    expect(AppTheme.dark.scaffoldBackgroundColor, AppColors.darkBackground);
  });
}

double _contrastRatio(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = foregroundLuminance > backgroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final darker = foregroundLuminance > backgroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;

  return (lighter + 0.05) / (darker + 0.05);
}
