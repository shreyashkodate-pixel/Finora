import 'package:flutter/material.dart';
import '../responsive/breakpoints.dart';
import '../theme/colors.dart';
import '../theme/typography.dart';

class NavigationDestinationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;

  const NavigationDestinationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });
}

/// Adaptive Scaffold providing responsive layout across Mobile, Tablet, and Desktop per Section 6 & 7.
class ResponsiveScaffold extends StatelessWidget {
  final String title;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<NavigationDestinationItem> destinations;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const ResponsiveScaffold({
    super.key,
    required this.title,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    final isDesktopOrTablet = ResponsiveBreakpoints.isDesktopOrTablet(context);

    if (isDesktopOrTablet) {
      return Scaffold(
        backgroundColor: AppColors.backgroundLight,
        appBar: AppBar(
          titleSpacing: 16,
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.corporate_fare_rounded, size: 16, color: AppColors.primaryBlue),
                    SizedBox(width: 6),
                    Text(
                      'Acme Enterprise Corp',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    SizedBox(width: 4),
                    Icon(Icons.unfold_more_rounded, size: 14, color: AppColors.textSecondaryLight),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(width: 1, height: 16, color: AppColors.borderLight),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTypography.headlineSm.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: AppColors.textPrimaryLight,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          elevation: 0,
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          bottom: const PreferredSize(
            preferredSize: Size.fromHeight(1),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),
          actions: [
            // Stitch "All Systems Live" pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: const BoxDecoration(
                      color: AppColors.slaHealthy,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text(
                    'ALL SYSTEMS LIVE',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.6,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            if (actions != null) ...actions!,
          ],
        ),
        body: Row(
          children: [
            Container(
              width: 72,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(right: BorderSide(color: AppColors.borderLight, width: 1)),
              ),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // Stitch Shield Icon
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.shield_outlined, color: AppColors.primaryBlue, size: 22),
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: AppColors.borderLight),
                  const SizedBox(height: 8),
                  // Scrollable navigation icons
                  Expanded(
                    child: ListView.builder(
                      itemCount: destinations.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, idx) {
                        final d = destinations[idx];
                        final isSelected = selectedIndex == idx;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3.0),
                          child: InkWell(
                            onTap: () => onDestinationSelected(idx),
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              height: 54,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.surfaceContainerLow : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Stack(
                                children: [
                                  Center(
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(
                                          isSelected ? d.selectedIcon : d.icon,
                                          size: 20,
                                          color: isSelected ? AppColors.primaryBlue : AppColors.textSecondaryLight,
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          d.label,
                                          style: TextStyle(
                                            fontSize: 9.5,
                                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                                            color: isSelected ? AppColors.primaryBlue : AppColors.textSecondaryLight,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (isSelected)
                                    Positioned(
                                      right: 0,
                                      top: 14,
                                      bottom: 14,
                                      child: Container(
                                        width: 3,
                                        decoration: const BoxDecoration(
                                          color: AppColors.primaryBlue,
                                          borderRadius: BorderRadius.horizontal(left: Radius.circular(2)),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
        floatingActionButton: floatingActionButton,
      );
    }

    // Mobile layout with BottomNavigationBar
    return Scaffold(
      backgroundColor: AppColors.backgroundLight,
      appBar: AppBar(
        title: Text(
          title,
          style: AppTypography.headlineSm.copyWith(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: AppColors.borderLight),
        ),
        actions: actions,
      ),
      body: body,
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedIndex < destinations.length ? selectedIndex : 0,
        onDestinationSelected: onDestinationSelected,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.surfaceContainerLow,
        destinations: destinations.map((d) {
          return NavigationDestination(
            icon: Icon(d.icon),
            selectedIcon: Icon(d.selectedIcon, color: AppColors.primaryBlue),
            label: d.label,
          );
        }).toList(),
      ),
      floatingActionButton: floatingActionButton,
    );
  }
}
