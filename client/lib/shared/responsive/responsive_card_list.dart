import 'package:flutter/material.dart';
import 'breakpoints.dart';

/// Transforms dense tabular data into an accessible card feed on mobile
/// to avoid uncontrolled horizontal scrolling per Locked Invariant 5.
class ResponsiveDataView<T> extends StatelessWidget {
  final List<T> items;
  final Widget Function(BuildContext context, T item, int index) mobileCardBuilder;
  final Widget Function(BuildContext context, List<T> items) desktopTableBuilder;
  final Widget? emptyState;
  final bool isLoading;
  final Widget? loadingState;

  const ResponsiveDataView({
    super.key,
    required this.items,
    required this.mobileCardBuilder,
    required this.desktopTableBuilder,
    this.emptyState,
    this.isLoading = false,
    this.loadingState,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return loadingState ?? const Center(child: CircularProgressIndicator());
    }

    if (items.isEmpty) {
      return emptyState ?? const Center(child: Text('No records found.'));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ResponsiveBreakpoints.tabletMin) {
          // Desktop / Tablet Data Table
          return SingleChildScrollView(
            child: desktopTableBuilder(context, items),
          );
        }

        // Mobile Card Feed (Stacked vertical cards)
        return ListView.separated(
          itemCount: items.length,
          padding: const EdgeInsets.symmetric(vertical: 8),
          separatorBuilder: (_, __) => const SizedBox(height: 8),
          itemBuilder: (context, index) => mobileCardBuilder(context, items[index], index),
        );
      },
    );
  }
}
