// ABOUTME: Shared bottom navigation bar widget for app shell and profile screens
// ABOUTME: Provides consistent bottom nav across screens with/without shell

import 'dart:ui' show ImageFilter;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/relay_notifications_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/utils/camera_permission_check.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/notification_badge.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

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
      2 => context.go(InboxPage.path),
      _ => context.go(VideoFeedPage.pathForIndex(lastIndex ?? 0)),
    };
  }

  String _tabName(int index) {
    return switch (index) {
      0 => 'Home',
      1 => 'Explore',
      2 => 'Inbox',
      3 => 'Profile',
      _ => 'Unknown',
    };
  }

  /// Combined unread count for the inbox tab (DMs + notifications).
  int _inboxUnreadCount(BuildContext context, WidgetRef ref) {
    final dmCount = context.watch<DmUnreadCountCubit>().state;
    final notifCount = ref.watch(relayNotificationUnreadCountProvider);
    return dmCount + notifCount;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: VineTheme.surfaceBackground,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _IconTabButton(
              semanticIdentifier: 'home_tab',
              semanticLabel: context.l10n.navHome,
              icon: DivineIconName.houseSimple,
              isSelected: currentIndex == 0,
              onTap: () => _handleTabTap(context, ref, 0),
            ),
            _IconTabButton(
              semanticIdentifier: 'explore_tab',
              semanticLabel: context.l10n.navExplore,
              icon: DivineIconName.search,
              isSelected: currentIndex == 1,
              onTap: () => _handleTabTap(context, ref, 1),
            ),
            // Camera button in center of bottom nav
            _CameraButton(
              onTap: () {
                Log.info(
                  '👆 User tapped camera button',
                  name: 'Navigation',
                  category: LogCategory.ui,
                );
                context.pushToCameraWithPermission();
              },
            ),
            NotificationBadge(
              count: _inboxUnreadCount(context, ref),
              child: _IconTabButton(
                semanticIdentifier: 'inbox_tab',
                semanticLabel: context.l10n.navInbox,
                icon: DivineIconName.chat,
                isSelected: currentIndex == 2,
                onTap: () => _handleTabTap(context, ref, 2),
              ),
            ),
            _ProfileTabButton(
              semanticLabel: context.l10n.navProfile,
              isSelected: currentIndex == 3,
              onTap: () => _handleTabTap(context, ref, 3),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Tab buttons
// =============================================================================
//
// The Figma component (node 5595:133692) specifies two tab-button shapes:
//   * **Icon tabs** (Home / Search / Inbox) — 48×48 tap target, 24×24 glyph,
//     selected = full opacity + shadow-10 drop shadows on the glyph,
//     unselected = 32 % opacity, no shadow.
//   * **Profile tab** — 48×48 tap target, 24×24 rounded-8 box,
//     lime fallback fill with the user's avatar on top. Selected and
//     unselected differ only in the outer border (2 px white vs 1 px
//     `onSurfaceDisabled`); no filter / opacity / shadow on the avatar
//     itself.

/// Tap target + Semantics wrapper shared by the three icon tabs.
///
/// The child gets the 32 %-opacity dim in the unselected state and the
/// glyph-shaped shadow pair in the selected state. See [_ShadowedNavIcon].
class _IconTabButton extends StatelessWidget {
  const _IconTabButton({
    required this.semanticIdentifier,
    required this.semanticLabel,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  final String semanticIdentifier;
  final String semanticLabel;
  final DivineIconName icon;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: semanticIdentifier,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: Opacity(
              // Figma: unselected tabs render at 32 % opacity; selected stays
              // at 100 %. No color tint — just dim + shadow toggle.
              opacity: isSelected ? 1.0 : 0.32,
              child: _ShadowedNavIcon(icon: icon, showShadow: isSelected),
            ),
          ),
        ),
      ),
    );
  }
}

/// 24×24 [DivineIcon] that optionally paints the Figma `effects/shadow-10`
/// drop-shadow pair underneath the glyph. The shadow copies are
/// [DivineIcon]s tinted in [VineTheme.innerShadow] and blurred via
/// [ImageFiltered] so the shadow silhouette tracks the glyph, not the
/// bounding rect.
///
/// Same pattern as `_ShadowedIcon` in `video_action_button.dart` — when we
/// consolidate those, move to a shared `divine_ui` widget.
class _ShadowedNavIcon extends StatelessWidget {
  const _ShadowedNavIcon({required this.icon, required this.showShadow});

  final DivineIconName icon;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final glyph = DivineIcon(icon: icon, color: VineTheme.whiteText);
    if (!showShadow) return glyph;
    return Stack(
      alignment: Alignment.center,
      children: [
        _NavIconShadow(icon: icon, offset: const Offset(1, 1), blurSigma: 1),
        _NavIconShadow(
          icon: icon,
          offset: const Offset(0.4, 0.4),
          blurSigma: 0.6,
        ),
        glyph,
      ],
    );
  }
}

class _NavIconShadow extends StatelessWidget {
  const _NavIconShadow({
    required this.icon,
    required this.offset,
    required this.blurSigma,
  });

  final DivineIconName icon;
  final Offset offset;
  final double blurSigma;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: offset,
      child: ImageFiltered(
        imageFilter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        // Excluded from semantics — the foreground glyph carries the
        // accessibility node; these are decorative shadow copies.
        child: ExcludeSemantics(
          child: DivineIcon(icon: icon, color: VineTheme.innerShadow),
        ),
      ),
    );
  }
}

/// Profile tab: 24×24 rounded-8 box with a lime fallback background and
/// the currently-signed-in user's avatar on top. Selection state is
/// communicated only by the outer border (1 px `onSurfaceDisabled` →
/// 2 px white).
///
/// Falls back to the standard icon-tab treatment with [DivineIconName.userCircle]
/// when no user is signed in (e.g. during sign-out) or while the profile
/// is still loading.
class _ProfileTabButton extends ConsumerWidget {
  const _ProfileTabButton({
    required this.semanticLabel,
    required this.isSelected,
    required this.onTap,
  });

  final String semanticLabel;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    final profile = pubkey == null
        ? null
        : ref.watch(userProfileReactiveProvider(pubkey)).value;
    final imageUrl = profile?.picture;
    final hasAvatar = imageUrl != null && imageUrl.isNotEmpty;

    return Semantics(
      identifier: 'profile_tab',
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 48,
          height: 48,
          child: Center(
            child: hasAvatar
                ? _ProfileAvatarBox(
                    imageUrl: imageUrl,
                    isSelected: isSelected,
                  )
                // No signed-in avatar: render the same icon-tab treatment
                // (opacity dim / shadow) as Home / Search / Inbox so the
                // nav bar still feels uniform until the profile loads.
                : Opacity(
                    opacity: isSelected ? 1.0 : 0.32,
                    child: _ShadowedNavIcon(
                      icon: DivineIconName.userCircle,
                      showShadow: isSelected,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// The Figma profile-tab avatar box: 24×24 rounded-8 container with a
/// lime fallback fill and the user's avatar image on top. The two
/// variants differ only in the outer border — 1 px `onSurfaceDisabled`
/// when unselected, 2 px white when selected.
class _ProfileAvatarBox extends StatelessWidget {
  const _ProfileAvatarBox({
    required this.imageUrl,
    required this.isSelected,
  });

  final String imageUrl;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 24,
      child: Stack(
        children: [
          // Lime base — visible through transparent pixels of the
          // avatar and while the image is still loading.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: const ColoredBox(color: VineTheme.accentLime),
            ),
          ),
          // Avatar image, clipped to the rounded 8-px square.
          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: VineCachedImage(
                imageUrl: imageUrl,
                width: 24,
                height: 24,
              ),
            ),
          ),
          // Border on top — 1 px `onSurfaceDisabled` when unselected,
          // 2 px white when selected. (No inset shadow / opacity / blend
          // — the avatar shows in full color in both states.)
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected
                        ? VineTheme.whiteText
                        : VineTheme.onSurfaceDisabled,
                    width: isSelected ? 2 : 1,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Camera button in the center of the bottom navigation bar.
class _CameraButton extends StatelessWidget {
  const _CameraButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'camera_button',
      button: true,
      label: context.l10n.navOpenCamera,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 72,
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(
            color: VineTheme.cameraButtonGreen,
            borderRadius: BorderRadius.circular(20),
          ),
          child: const DivineIcon(icon: .cameraRetro, size: 32),
        ),
      ),
    );
  }
}
