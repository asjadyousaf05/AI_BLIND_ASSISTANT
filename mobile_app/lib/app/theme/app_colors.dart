import 'package:flutter/material.dart';

abstract final class AppColors {
  static const primary = Color(0xFF25C0F4);
  static const onPrimary = Color(0xFF06232D);

  static const secondary = slate500;
  static const onSecondary = Color(0xFFFFFFFF);

  static const lightBackground = Color(0xFFF5F8F8);
  static const darkBackground = Color(0xFF101E22);

  static const lightSurface = Color(0xFFFFFFFF);
  static const darkSurface = slate800;
  static const lightSurfaceMuted = slate100;
  static const darkSurfaceMuted = Color(0xFF14272D);

  static const onLightSurface = slate900;
  static const onDarkSurface = slate50;
  static const mutedLightText = slate600;
  static const mutedDarkText = slate400;

  static const success = Color(0xFF10B981);
  static const warning = Color(0xFFF59E0B);
  static const error = Color(0xFFEF4444);

  static const primaryOverlay05 = Color(0x0D25C0F4);
  static const primaryOverlay10 = Color(0x1A25C0F4);
  static const primaryOverlay20 = Color(0x3325C0F4);
  static const primaryOverlay30 = Color(0x4D25C0F4);
  static const primaryOverlay40 = Color(0x6625C0F4);

  static const slate50 = Color(0xFFF8FAFC);
  static const slate100 = Color(0xFFF1F5F9);
  static const slate200 = Color(0xFFE2E8F0);
  static const slate300 = Color(0xFFCBD5E1);
  static const slate400 = Color(0xFF94A3B8);
  static const slate500 = Color(0xFF64748B);
  static const slate600 = Color(0xFF475569);
  static const slate700 = Color(0xFF334155);
  static const slate800 = Color(0xFF1E293B);
  static const slate900 = Color(0xFF0F172A);
}
