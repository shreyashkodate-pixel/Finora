import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Reusable layout builder that renders the appropriate layout widget
/// based on the current window / device width.
class ResponsiveLayout extends StatelessWidget {
  final Widget Function(BuildContext context) mobile;
  final Widget Function(BuildContext context)? tablet;
  final Widget Function(BuildContext context) desktop;

  const ResponsiveLayout({
    super.key,
    required this.mobile,
    this.tablet,
    required this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth > ResponsiveBreakpoints.tabletMax) {
          return desktop(context);
        } else if (constraints.maxWidth >= ResponsiveBreakpoints.tabletMin) {
          return tablet != null ? tablet!(context) : desktop(context);
        }
        return mobile(context);
      },
    );
  }
}
