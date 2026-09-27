import 'package:flutter/material.dart';
import 'colors.dart';

/// Centralized Typography System per Stitch DESIGN.md.
/// - Primary: Inter for high-density structural grids and forms.
/// - Monospace: JetBrains Mono for ticket references, SLA timers, and error traces.
class AppTypography {
  // Font Family Constants
  static const String fontFamilyPrimary = 'Inter';
  static const String fontFamilyMonospace = 'JetBrains Mono';

  // Desktop / Standard Headlines
  static const TextStyle headlineLg = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 32,
    fontWeight: FontWeight.w600,
    height: 40 / 32,
    letterSpacing: -0.64,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
    letterSpacing: -0.33,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle headlineSm = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 24 / 18,
    letterSpacing: -0.18,
    color: AppColors.textPrimaryLight,
  );

  // Body Typography
  static const TextStyle bodyLg = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 24 / 16,
    letterSpacing: 0.0,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle bodyMd = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 20 / 14,
    letterSpacing: 0.0,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle bodySm = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: 0.065,
    color: AppColors.textSecondaryLight,
  );

  // Labels & Badges
  static const TextStyle labelMd = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.24,
    color: AppColors.textSecondaryLight,
  );

  static const TextStyle labelSm = TextStyle(
    fontFamily: fontFamilyPrimary,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 14 / 11,
    letterSpacing: 0.44,
    color: AppColors.textSecondaryLight,
  );

  // Monospace Tokens (SLA countdown, Ticket Reference, Terminal/Logs)
  static const TextStyle codeMd = TextStyle(
    fontFamily: fontFamilyMonospace,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 18 / 13,
    letterSpacing: -0.13,
    color: AppColors.textPrimaryLight,
  );

  static const TextStyle slaTimer = TextStyle(
    fontFamily: fontFamilyMonospace,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 16 / 12,
    letterSpacing: 0.24,
  );

  static const TextStyle ticketReference = TextStyle(
    fontFamily: fontFamilyMonospace,
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.2,
  );
}
