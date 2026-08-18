import 'package:flutter/material.dart';

import '../../app/router/app_route.dart';
import '../../app/router/route_paths.dart';
import '../../app/theme/app_icons.dart';

class AppBottomNavigationItem {
  const AppBottomNavigationItem({
    required this.label,
    required this.icon,
    required this.routePath,
  });

  final String label;
  final IconData icon;
  final String routePath;
}

class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    super.key,
    required this.selectedRoutePath,
    this.items = mainItems,
  });

  static const mainItems = <AppBottomNavigationItem>[
    AppBottomNavigationItem(
      label: 'Home',
      icon: AppIcons.home,
      routePath: RoutePaths.home,
    ),
    AppBottomNavigationItem(
      label: 'Mode',
      icon: AppIcons.mode,
      routePath: RoutePaths.modeSelection,
    ),
    AppBottomNavigationItem(
      label: 'Cap',
      icon: AppIcons.bluetooth,
      routePath: RoutePaths.raspberryPi,
    ),
    AppBottomNavigationItem(
      label: 'Settings',
      icon: AppIcons.settings,
      routePath: RoutePaths.settings,
    ),
  ];

  static const aboutItems = <AppBottomNavigationItem>[
    AppBottomNavigationItem(
      label: 'Home',
      icon: AppIcons.home,
      routePath: RoutePaths.home,
    ),
    AppBottomNavigationItem(
      label: 'Help',
      icon: AppIcons.help,
      routePath: RoutePaths.help,
    ),
    AppBottomNavigationItem(
      label: 'About',
      icon: AppIcons.info,
      routePath: RoutePaths.aboutSafety,
    ),
  ];

  final String selectedRoutePath;
  final List<AppBottomNavigationItem> items;

  @override
  Widget build(BuildContext context) {
    final selectedIndex = items.indexWhere(
      (item) => item.routePath == selectedRoutePath,
    );

    return NavigationBar(
      selectedIndex: selectedIndex < 0 ? 0 : selectedIndex,
      onDestinationSelected: (index) {
        final destination = items[index];
        if (destination.routePath == selectedRoutePath) {
          return;
        }
        Navigator.of(context).pushReplacementNamed(destination.routePath);
      },
      destinations: [
        for (final item in items)
          NavigationDestination(
            icon: Icon(item.icon),
            label: item.label,
            tooltip: item.label == 'Cap' ? AppRoute.raspberryPi.title : null,
          ),
      ],
    );
  }
}
