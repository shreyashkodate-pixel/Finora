import 'package:flutter/material.dart';

/// Authoritative Stitch Precision Enterprise Ops Color System.
/// Strictly derived from design/stitch HTML/CSS tokens.
class AppColors {
  // Brand & Primary (Stitch: primary = #1E40AF / #00288E, secondary = #4648d4)
  static const Color primaryBlue = Color(0xFF1E40AF); // Deep Enterprise Blue
  static const Color primaryDark = Color(0xFF00288E); // Reference Primary Dark
  static const Color primaryHover = Color(0xFF173BAB); // Stitch on-primary-fixed-variant
  static const Color primaryLight = Color(0xFF3755C3); // Stitch surface-tint
  static const Color primaryContainer = Color(0xFFEFF4FF); // Stitch surface-container-low
  static const Color primaryButton = Color(0xFF1E40AF); // Stitch primary-container button

  // Background & Surfaces (Stitch Light Enterprise)
  static const Color backgroundLight = Color(0xFFF8FAFC); // Canvas Base
  static const Color backgroundCanvas = Color(0xFFF8F9FF); // Stitch Pure Canvas Base
  static const Color surfaceLight = Color(0xFFFFFFFF); // Stitch surface-container-lowest
  static const Color surfaceContainerLow = Color(0xFFEFF4FF); // Stitch surface-container-low
  static const Color surfaceContainer = Color(0xFFE5EEFF); // Stitch surface-container
  static const Color surfaceContainerHigh = Color(0xFFDCE9FF); // Stitch surface-container-high
  static const Color surfaceMuted = Color(0xFFEFF4FF); // Headers, inputs
  static const Color borderLight = Color(0xFFE2E8F0); // 1px Geometric Dividers
  static const Color borderSubtle = Color(0xFFEFF4FF);
  static const Color outline = Color(0xFF757684); // Stitch outline
  static const Color outlineVariant = Color(0xFFC4C5D5); // Stitch outline-variant

  // Background & Surfaces (Prevent dark leaks: lock to Stitch light)
  static const Color backgroundDark = Color(0xFFF8F9FF);
  static const Color surfaceDark = Color(0xFFFFFFFF);
  static const Color surfaceMutedDark = Color(0xFFEFF4FF);
  static const Color borderDark = Color(0xFFE2E8F0);

  // Typography Tokens
  static const Color textPrimaryLight = Color(0xFF0B1C30); // Stitch on-surface
  static const Color textSecondaryLight = Color(0xFF444653); // Stitch on-surface-variant
  static const Color textPrimaryDark = Color(0xFF0B1C30);
  static const Color textSecondaryDark = Color(0xFF444653);
  static const Color textInverse = Color(0xFFFFFFFF);

  // Priority Palettes (High visibility & contrast)
  static const Color priorityP1 = Color(0xFFDC2626); // Critical (Red)
  static const Color priorityP1Background = Color(0xFFFEF2F2);
  static const Color priorityP1Border = Color(0xFFFCA5A5);

  static const Color priorityP2 = Color(0xFFEA580C); // High (Amber/Orange)
  static const Color priorityP2Background = Color(0xFFFFF7ED);
  static const Color priorityP2Border = Color(0xFFFDBA74);

  static const Color priorityP3 = Color(0xFF2563EB); // Normal (Royal Blue)
  static const Color priorityP3Background = Color(0xFFEFF6FF);
  static const Color priorityP3Border = Color(0xFF93C5FD);

  static const Color priorityP4 = Color(0xFF64748B); // Low (Neutral Slate)
  static const Color priorityP4Background = Color(0xFFF8F9FF);
  static const Color priorityP4Border = Color(0xFFCBD5E1);

  // Status Colors
  static const Color statusNew = Color(0xFF0284C7); // Sky Blue
  static const Color statusInAssessment = Color(0xFF7C3AED); // Purple
  static const Color statusAssigned = Color(0xFF2563EB); // Royal Blue
  static const Color statusAwaiting = Color(0xFFD97706); // Amber
  static const Color statusWarning = Color(0xFFD97706); // Warning state
  static const Color statusResolved = Color(0xFF16A34A); // Emerald Green
  static const Color statusResolvedBackground = Color(0xFFF0FDF4);
  static const Color statusClosed = Color(0xFF475569); // Slate
  static const Color statusCancelled = Color(0xFF9CA3AF); // Muted Gray

  // AI & Ambient Copilot Accents
  static const Color aiAccent = Color(0xFF6366F1); // Ambient Copilot Indigo
  static const Color secondaryIndigo = Color(0xFF4648D4); // Stitch Secondary Token
  static const Color secondaryFixed = Color(0xFFE1E0FF); // Stitch Secondary Fixed
  static const Color onSecondaryFixed = Color(0xFF07006C);
  static const Color aiBackground = Color(0xFFEEF2FF);
  static const Color aiBorder = Color(0xFFC7D2FE);

  // SLA Warnings & Breaches
  static const Color slaHealthy = Color(0xFF16A34A);
  static const Color slaWarning = Color(0xFFD97706);
  static const Color slaWarningBackground = Color(0xFFFFFBEB);
  static const Color slaBreached = Color(0xFFDC2626);
  static const Color slaBreachedBackground = Color(0xFFFEF2F2);
}

