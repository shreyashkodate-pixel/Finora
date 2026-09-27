import 'package:flutter/material.dart';
import 'colors.dart';
import 'dimensions.dart';
import 'typography.dart';

/// Centralized Material 3 ThemeData with WCAG 2.1 AA Compliance.
class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: AppTypography.fontFamilyPrimary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primaryBlue,
        primary: AppColors.primaryBlue,
        onPrimary: Colors.white,
        primaryContainer: AppColors.primaryContainer,
        onPrimaryContainer: AppColors.primaryBlue,
        surface: AppColors.surfaceLight,
        onSurface: AppColors.textPrimaryLight,
        error: AppColors.priorityP1,
        onError: Colors.white,
        outline: AppColors.borderLight,
        outlineVariant: AppColors.borderSubtle,
        brightness: Brightness.light,
      ),
      scaffoldBackgroundColor: AppColors.backgroundLight,
      cardTheme: CardThemeData(
        color: AppColors.surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppDimensions.cardBorderRadius,
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.borderLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: AppTypography.bodyMd.copyWith(color: AppColors.textSecondaryLight),
        labelStyle: AppTypography.labelMd.copyWith(color: AppColors.textSecondaryLight),
        border: OutlineInputBorder(
          borderRadius: AppDimensions.buttonBorderRadius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppDimensions.buttonBorderRadius,
          borderSide: const BorderSide(color: AppColors.borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppDimensions.buttonBorderRadius,
          borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.buttonBorderRadius,
          borderSide: const BorderSide(color: AppColors.priorityP1),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppDimensions.buttonBorderRadius,
          borderSide: const BorderSide(color: AppColors.priorityP1, width: 1.5),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(AppDimensions.minTouchTargetSize, AppDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
          elevation: 0,
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w600, color: Colors.white),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.textPrimaryLight,
          backgroundColor: Colors.white,
          minimumSize: const Size(AppDimensions.minTouchTargetSize, AppDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primaryBlue,
          minimumSize: const Size(AppDimensions.minTouchTargetSize, AppDimensions.buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          shape: RoundedRectangleBorder(borderRadius: AppDimensions.buttonBorderRadius),
          textStyle: AppTypography.bodyMd.copyWith(fontWeight: FontWeight.w500),
        ),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: Colors.white,
        selectedIconTheme: const IconThemeData(color: AppColors.primaryBlue, size: 24),
        unselectedIconTheme: const IconThemeData(color: AppColors.textSecondaryLight, size: 24),
        selectedLabelTextStyle: AppTypography.labelSm.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600, fontSize: 10),
        unselectedLabelTextStyle: AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight, fontSize: 10),
        indicatorColor: AppColors.surfaceContainerLow,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        elevation: 0,
        height: AppDimensions.navBarHeight,
        indicatorColor: AppColors.surfaceContainerLow,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: AppColors.primaryBlue);
          }
          return const IconThemeData(color: AppColors.textSecondaryLight);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppTypography.labelSm.copyWith(color: AppColors.primaryBlue, fontWeight: FontWeight.w600);
          }
          return AppTypography.labelSm.copyWith(color: AppColors.textSecondaryLight);
        }),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusDialog),
          side: const BorderSide(color: AppColors.borderLight, width: 1),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: AppDimensions.pillBorderRadius),
        side: const BorderSide(color: AppColors.borderLight, width: 1),
        labelStyle: AppTypography.labelMd.copyWith(color: AppColors.textPrimaryLight),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textPrimaryLight,
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: AppTypography.bodySm.copyWith(color: Colors.white),
      ),
    );
  }

  /// Dark mode is locked to the authoritative Stitch Precision Enterprise Ops Light Theme
  /// to eliminate all theme collision and preserve 100% Stitch visual fidelity.
  static ThemeData get darkTheme => lightTheme;
}
