import 'package:flutter/material.dart';

/// Centralized Responsive Breakpoints per Section 6 of Phase 1 requirements.
/// - Mobile:  < 768px
/// - Tablet:  768px – 1024px
/// - Desktop: > 1024px
class ResponsiveBreakpoints {
  static const double mobileMax = 767.0;
  static const double tabletMin = 768.0;
  static const double tabletMax = 1024.0;
  static const double desktopMin = 1025.0;

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < tabletMin;

  static bool isTablet(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return width >= tabletMin && width <= tabletMax;
  }

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width > tabletMax;

  static bool isDesktopOrTablet(BuildContext context) =>
      MediaQuery.of(context).size.width >= tabletMin;

  static T valueByScreen<T>({
    required BuildContext context,
    required T mobile,
    T? tablet,
    required T desktop,
  }) {
    final width = MediaQuery.of(context).size.width;
    if (width > tabletMax) {
      return desktop;
    } else if (width >= tabletMin) {
      return tablet ?? desktop;
    }
    return mobile;
  }
}
