import 'package:flutter/material.dart';

/// Centralized Spacing, Radius, and Elevation Tokens per Stitch DESIGN.md.
/// Anchored on an 8px grid baseline discipline.
class AppDimensions {
  // Spacing (8px Baseline Grid)
  static const double space2xs = 2.0;
  static const double spaceXs = 4.0;
  static const double spaceSm = 8.0;
  static const double spaceMd = 16.0;
  static const double spaceLg = 24.0;
  static const double spaceXl = 32.0;
  static const double space2xl = 48.0;

  // Layout Gutters & Margins
  static const double gutterMobile = 16.0;
  static const double gutterDesktop = 24.0;
  static const double marginMobile = 16.0;
  static const double marginDesktop = 24.0;

  // Corner Radii
  static const double radiusPriority = 4.0;
  static const double radiusButton = 6.0;
  static const double radiusCard = 8.0;
  static const double radiusDialog = 8.0;
  static const double radiusPill = 9999.0;
  static const double radiusBottomSheet = 12.0;

  // Border Radii Helpers
  static final BorderRadius cardBorderRadius = BorderRadius.circular(radiusCard);
  static final BorderRadius buttonBorderRadius = BorderRadius.circular(radiusButton);
  static final BorderRadius priorityBorderRadius = BorderRadius.circular(radiusPriority);
  static final BorderRadius pillBorderRadius = BorderRadius.circular(radiusPill);

  // Touch Target Sizing (WCAG 2.1 AA)
  static const double minTouchTargetSize = 48.0;
  static const double buttonHeight = 40.0;
  static const double inputHeight = 44.0;

  // Navigation Sizes
  static const double navRailWidthCompact = 72.0;
  static const double navRailWidthExpanded = 240.0;
  static const double navBarHeight = 64.0;
}
