// ABOUTME: Shared bottom navigation bar widget for app shell and profile screens
// ABOUTME: Provides consistent bottom nav across screens with/without shell

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/router/last_tab_position_provider.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Shared bottom navigation bar used by AppShell and standalone profile screens.
class VineBottomNav extends ConsumerWidget {
  const VineBottomNav({required this.currentIndex, super.key});

  /// Currently selected tab index (0-3), or -1 if no tab is selected.
  final int currentIndex;

  /// Maps tab index to RouteType
  RouteType _routeTypeForTab(int index) {
    switch (index) {
      case 0:
        return RouteType.home;
      case 1:
        return RouteType.explore;
      case 2:
        return RouteType.notifications;
      case 3:
        return RouteType.profile;
      default:
        return RouteType.home;
    }
  }

  /// Handles tab tap - navigates to last known position in that tab
  void _handleTabTap(BuildContext context, WidgetRef ref, int tabIndex) {
    final routeType = _routeTypeForTab(tabIndex);
    final lastIndex = ref
        .read(lastTabPositionProvider.notifier)
        .getPosition(routeType);

    // Log user interaction
    Log.info(
      '👆 User tapped bottom nav: tab=$tabIndex (${_tabName(tabIndex)})',
      name: 'Navigation',
      category: LogCategory.ui,
    );

    // Pop any pushed routes first
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    }

    // Navigate to last position in that tab
    switch (tabIndex) {
      case 0:
        context.goHome(lastIndex ?? 0);
        break;
      case 1:
        context.goExplore(null);
        break;
      case 2:
        context.goNotifications(lastIndex ?? 0);
        break;
      case 3:
        context.goProfileGrid('me');
        break;
    }
  }

  String _tabName(int index) {
    switch (index) {
      case 0:
        return 'Home';
      case 1:
        return 'Explore';
      case 2:
        return 'Notifications';
      case 3:
        return 'Profile';
      default:
        return 'Unknown';
    }
  }

  Widget _buildTabButton(
    BuildContext context,
    WidgetRef ref,
    String iconPath,
    int tabIndex,
    String semanticIdentifier,
  ) {
    final isSelected = currentIndex == tabIndex;
    final iconColor = isSelected ? Colors.white : VineTheme.tabIconInactive;

    return Semantics(
      identifier: semanticIdentifier,
      child: GestureDetector(
        onTap: () => _handleTabTap(context, ref, tabIndex),
        child: Container(
          width: 48,
          height: 48,
          padding: const EdgeInsets.all(8),
          child: SvgPicture.asset(
            iconPath,
            width: 32,
            height: 32,
            colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: VineTheme.navGreen,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildTabButton(
              context,
              ref,
              'assets/icon/house.svg',
              0,
              'home_tab',
            ),
            _buildTabButton(
              context,
              ref,
              'assets/icon/compass.svg',
              1,
              'explore_tab',
            ),
            // Camera button in center of bottom nav
            Semantics(
              identifier: 'camera_button',
              button: true,
              label: 'Open camera',
              child: GestureDetector(
                onTap: () {
                  Log.info(
                    '👆 User tapped camera button',
                    name: 'Navigation',
                    category: LogCategory.ui,
                  );
                  context.pushCamera();
                },
                child: Container(
                  width: 72,
                  height: 48,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: VineTheme.cameraButtonGreen,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: SvgPicture.asset(
                    'assets/icon/retro-camera.svg',
                    width: 32,
                    height: 32,
                  ),
                ),
              ),
            ),
            _buildTabButton(
              context,
              ref,
              'assets/icon/bell.svg',
              2,
              'notifications_tab',
            ),
            _buildTabButton(
              context,
              ref,
              'assets/icon/userCircle.svg',
              3,
              'profile_tab',
            ),
          ],
        ),
      ),
    );
  }
}
