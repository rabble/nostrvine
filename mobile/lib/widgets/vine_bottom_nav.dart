// ABOUTME: Shared bottom navigation bar widget for app shell and profile screens
// ABOUTME: Provides consistent bottom nav across screens with/without shell

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/svg.dart';
import 'package:go_router/go_router.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/home_screen_router.dart';
import 'package:openvine/screens/notifications_screen.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

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
    return switch (tabIndex) {
      1 => context.go(ExploreScreen.path),
      2 => context.go(NotificationsScreen.pathForIndex(lastIndex ?? 0)),
      3 => context.go(ProfileScreenRouter.pathForIndex('me', lastIndex ?? 0)),
      _ => context.go(HomeScreenRouter.pathForIndex(lastIndex ?? 0)),
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

/// Camera button widget that disables when a background upload is in progress.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BackgroundPublishBloc, BackgroundPublishState>(
      builder: (context, state) {
        final isDisabled = state.hasUploadInProgress;

        return Semantics(
          identifier: 'camera_button',
          button: true,
          label: isDisabled ? 'Camera disabled during upload' : 'Open camera',
          child: GestureDetector(
            onTap: isDisabled ? null : onTap,
            child: Opacity(
              opacity: isDisabled ? 0.5 : 1.0,
              child: Container(
                width: 72,
                height: 48,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isDisabled
                      ? VineTheme.tabIconInactive
                      : VineTheme.cameraButtonGreen,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: SvgPicture.asset(
                  'assets/icon/retro-camera.svg',
                  width: 32,
                  height: 32,
                  colorFilter: isDisabled
                      ? const ColorFilter.mode(Colors.grey, BlendMode.srcIn)
                      : null,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
