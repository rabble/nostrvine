// ABOUTME: Shared bottom navigation bar widget for app shell and profile screens
// ABOUTME: Provides consistent bottom nav across screens with/without shell

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/notification_badge.dart';

/// Shared bottom navigation bar used by AppShell and standalone profile screens.
class VineBottomNav extends ConsumerWidget {
  const VineBottomNav({required this.currentIndex, super.key});

  /// Currently selected tab index (0-3), or -1 if no tab is selected.
  final int currentIndex;

  /// Maps tab index to RouteType
  RouteType _routeTypeForTab(int index) {
    return switch (index) {
      0 => RouteType.home,
      1 => RouteType.explore,
      2 => RouteType.notifications,
      3 => RouteType.profile,
      _ => RouteType.home,
    };
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
    if (tabIndex == 3) {
      // Navigate to own profile grid mode using actual npub (matches AppShell behavior).
      // When already on /profile/{npub}, GoRouter sees the same URL and no-ops.
      final authService = ref.read(authServiceProvider);
      final hex = authService.currentPublicKeyHex;
      if (hex != null) {
        final npub = NostrKeyUtils.encodePubKey(hex);
        context.go(ProfileScreenRouter.pathForNpub(npub));
      }
      return;
    }

    return switch (tabIndex) {
      1 => context.go(ExploreScreen.path),
      2 => context.go(NotificationsScreen.pathForIndex(lastIndex ?? 0)),
      _ => context.go(VideoFeedPage.pathForIndex(lastIndex ?? 0)),
    };
  }

  String _tabName(int index) {
    return switch (index) {
      0 => 'Home',
      1 => 'Explore',
      2 => 'Notifications',
      3 => 'Profile',
      _ => 'Unknown',
    };
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
            _CameraButton(
              onTap: () {
                Log.info(
                  '👆 User tapped camera button',
                  name: 'Navigation',
                  category: LogCategory.ui,
                );
                context.push(VideoRecorderScreen.path);
              },
            ),
            NotificationBadge(
              count: ref.watch(relayNotificationUnreadCountProvider),
              child: _buildTabButton(
                context,
                ref,
                'assets/icon/bell.svg',
                2,
                'notifications_tab',
              ),
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

/// Camera button widget that disables when a background upload is in progress.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'camera_button',
      button: true,
      label: 'Open camera',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: 1.0,
          child: Container(
            width: 72,
            height: 48,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
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
    );
  }
}
