import 'package:flutter/material.dart';

/// Central design tokens for MeraVyapar AI.
/// PhonePe-inspired white-and-purple design language with full dark mode support.
class AppColors {
  AppColors._();

  // --- Light Palette ---
  static const Color primaryPurple = Color(0xFF5F259F);
  static const Color secondaryPurple = Color(0xFF6F35B5);
  static const Color accentPurple = Color(0xFF8B5CF6);
  static const Color lightLavender = Color(0xFFF3EBFA);
  static const Color subtleLavender = Color(0xFFFAF7FD);
  
  static const Color lightBackground = Color(0xFFFFFFFF);
  static const Color lightSecondaryBackground = Color(0xFFF7F6F9);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightSurface = Color(0xFFFAF9FC);
  
  static const Color lightTextPrimary = Color(0xFF211B27);
  static const Color lightTextSecondary = Color(0xFF716B78);
  static const Color lightTextMuted = Color(0xFF9E97A6);
  static const Color lightDivider = Color(0xFFEAE6EF);
  static const Color lightBorder = Color(0xFFE2DCE8);

  // --- Dark Palette ---
  static const Color darkPrimaryPurple = Color(0xFFB58AE8);
  static const Color darkSecondaryPurple = Color(0xFF9B6BD3);
  static const Color darkAccentPurple = Color(0xFFC7A6F1);
  static const Color darkLavenderSurface = Color(0xFF2B213A);
  
  static const Color darkBackground = Color(0xFF121017);
  static const Color darkSecondaryBackground = Color(0xFF19151F);
  static const Color darkCard = Color(0xFF211B2A);
  static const Color darkSurface = Color(0xFF292232);
  
  static const Color darkTextPrimary = Color(0xFFF8F5FC);
  static const Color darkTextSecondary = Color(0xFFB9B0C3);
  static const Color darkTextMuted = Color(0xFF82788D);
  static const Color darkDivider = Color(0xFF393141);
  static const Color darkBorder = Color(0xFF42394C);

  // --- Semantic Financial Status Colors (Consistent Across Modes) ---
  static const Color success = Color(0xFF168653);
  static const Color successLight = Color(0xFFE7F6EE);
  static const Color darkSuccess = Color(0xFF4ADE80);
  static const Color darkSuccessBg = Color(0xFF132E1F);

  static const Color warning = Color(0xFFD68A16);
  static const Color warningLight = Color(0xFFFEF5E7);
  static const Color darkWarning = Color(0xFFFBBF24);
  static const Color darkWarningBg = Color(0xFF332408);

  static const Color error = Color(0xFFD64545);
  static const Color errorLight = Color(0xFFFDECEC);
  static const Color darkError = Color(0xFFF87171);
  static const Color darkErrorBg = Color(0xFF351515);

  static const Color info = Color(0xFF2563EB);
  static const Color infoLight = Color(0xFFEFF6FF);
  static const Color darkInfo = Color(0xFF60A5FA);
  static const Color darkInfoBg = Color(0xFF172554);
}
