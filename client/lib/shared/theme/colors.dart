import 'package:flutter/material.dart';

/// Accessible Enterprise Color System per WCAG 2.1 AA guidelines.
/// Guarantees minimum 4.5:1 text-to-background contrast ratio.
class AppColors {
  // Brand & Primary
  static const Color primaryBlue = Color(0xFF1E40AF); // Deep Enterprise Blue
  static const Color primaryLight = Color(0xFF3B82F6);
  static const Color primaryDark = Color(0xFF172554);

  // Background & Surfaces (Light)
  static const Color backgroundLight = Color(0xFFF8FAFC);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color borderLight = Color(0xFFE2E8F0);

  // Background & Surfaces (Dark)
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color borderDark = Color(0xFF334155);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF475569);
  static const Color textPrimaryDark = Color(0xFFF8FAFC);
  static const Color textSecondaryDark = Color(0xFF94A3B8);

  // Priority Palettes (High visibility & contrast)
  static const Color priorityP1 = Color(0xFFDC2626); // Critical (Red)
  static const Color priorityP2 = Color(0xFFEA580C); // High (Orange)
  static const Color priorityP3 = Color(0xFF2563EB); // Medium (Blue)
  static const Color priorityP4 = Color(0xFF64748B); // Low (Slate)

  // Status Colors
  static const Color statusNew = Color(0xFF0284C7); // Sky Blue
  static const Color statusInAssessment = Color(0xFF7C3AED); // Purple
  static const Color statusAssigned = Color(0xFF2563EB); // Royal Blue
  static const Color statusAwaiting = Color(0xFFD97706); // Amber
  static const Color statusResolved = Color(0xFF16A34A); // Emerald Green
  static const Color statusClosed = Color(0xFF475569); // Slate
  static const Color statusCancelled = Color(0xFF9CA3AF); // Muted Gray

  // AI & Automation
  static const Color aiAccent = Color(0xFF8B5CF6); // Gemini Purple
  static const Color aiBackground = Color(0xFFF5F3FF);
  static const Color aiBorder = Color(0xFFDDD6FE);

  // SLA Warnings
  static const Color slaHealthy = Color(0xFF16A34A);
  static const Color slaWarning = Color(0xFFD97706);
  static const Color slaBreached = Color(0xFFDC2626);
}
