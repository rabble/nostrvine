// ABOUTME: Shared bottom navigation bar widget for app shell and profile screens
// ABOUTME: Provides consistent bottom nav across screens with/without shell

import 'dart:ui' show ImageFilter;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
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
    final notifCount = context.watch<NotificationBadgeCubit>().state;
    return dmCount + notifCount;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: VineTheme.surfaceBackground,
      // The bottom nav has no Container padding — all four edges of the
      // breathing room around the icons are folded into adjacent tab hit
      // targets (see [_kTopExtraTapHeight], [_kBottomExtraTapHeight],
      // [_kHorizontalEdgePad]). [SafeArea] still keeps tap targets clear
      // of the iOS home indicator and Android navigation bar.
      child: SafeArea(
        top: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            // Each tab's slot covers its icon plus half of each adjacent
            // inter-icon gap, so taps closer to a given icon than to its
            // neighbour route to that tab. Home and Profile additionally
            // span the [_kHorizontalEdgePad] strip out to the screen edge.
            // Icons sit at their Figma-specified positions.
            const iconWidth = kMinInteractiveDimension;
            const cameraWidth = _kCameraButtonWidth;
            const totalIconWidth = iconWidth * 4 + cameraWidth;
            const totalEdgePad = _kHorizontalEdgePad * 2;
            // 4 inter-icon gaps × 2 halves = 8.
            final halfGap =
                ((constraints.maxWidth - totalIconWidth - totalEdgePad) / 8)
                    .clamp(0.0, double.infinity);

            return Row(
              children: [
                _IconTabButton(
                  semanticIdentifier: 'home_tab',
                  semanticLabel: context.l10n.navHome,
                  icon: DivineIconName.houseSimple,
                  isSelected: currentIndex == 0,
                  onTap: () => _handleTabTap(context, ref, 0),
                  tapTargetWidth: _kHorizontalEdgePad + iconWidth + halfGap,
                  iconAlignment: AlignmentDirectional.centerStart,
                  edgePadding: const EdgeInsetsDirectional.only(
                    start: _kHorizontalEdgePad,
                  ),
                ),
                _IconTabButton(
                  semanticIdentifier: 'explore_tab',
                  semanticLabel: context.l10n.navExplore,
                  icon: DivineIconName.search,
                  isSelected: currentIndex == 1,
                  onTap: () => _handleTabTap(context, ref, 1),
                  tapTargetWidth: iconWidth + halfGap * 2,
                ),
                // Camera button in center of bottom nav
                _CameraButton(
                  tapTargetWidth: cameraWidth + halfGap * 2,
                  onTap: () {
                    Log.info(
                      '👆 User tapped camera button',
                      name: 'Navigation',
                      category: LogCategory.ui,
                    );
                    context.pushToCameraWithPermission();
                  },
                ),
                _IconTabButton(
                  semanticIdentifier: 'inbox_tab',
                  semanticLabel: context.l10n.navInbox,
                  icon: DivineIconName.chat,
                  isSelected: currentIndex == 2,
                  onTap: () => _handleTabTap(context, ref, 2),
                  tapTargetWidth: iconWidth + halfGap * 2,
                  badgeCount: _inboxUnreadCount(context, ref),
                ),
                _ProfileTabButton(
                  semanticLabel: context.l10n.navProfile,
                  isSelected: currentIndex == 3,
                  onTap: () => _handleTabTap(context, ref, 3),
                  tapTargetWidth: iconWidth + halfGap + _kHorizontalEdgePad,
                  iconAlignment: AlignmentDirectional.centerEnd,
                  edgePadding: const EdgeInsetsDirectional.only(
                    end: _kHorizontalEdgePad,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Visible width of the green camera-button pill in the bottom nav.
const double _kCameraButtonWidth = 72;

/// Extra hit-target height stacked above the [kMinInteractiveDimension]
/// icon row, so taps in the strip immediately above the visible icons
/// route to the tab below.
const double _kTopExtraTapHeight = 12;

/// Extra hit-target height stacked below the [kMinInteractiveDimension]
/// icon row (above the [SafeArea] inset), so taps in the strip
/// immediately beneath the visible icons route to the tab above.
const double _kBottomExtraTapHeight = 12;

/// Total vertical hit-target height per tab. The icon container sits at
/// the vertical centre of this slot — top and bottom extras are equal —
/// so taps both above and below the visible glyph route to the right tab.
const double _kTabSlotHeight =
    kMinInteractiveDimension + _kTopExtraTapHeight + _kBottomExtraTapHeight;

/// Lateral inset between the screen edge and the visible position of the
/// outermost icons (Home / Profile). Folded into Home's and Profile's hit
/// targets so taps inside the 16 px strip on the screen edge still route
/// to the adjacent tab.
const double _kHorizontalEdgePad = 16;

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
///
/// [tapTargetWidth] is the full width the GestureDetector occupies inside
/// the bottom nav row — usually larger than the 48 px icon container so
/// taps in the surrounding gap also route to this tab. The icon itself
/// stays a [kMinInteractiveDimension]-sized box positioned via
/// [iconAlignment].
class _IconTabButton extends StatelessWidget {
  const _IconTabButton({
    required this.semanticIdentifier,
    required this.semanticLabel,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    required this.tapTargetWidth,
    this.iconAlignment = Alignment.center,
    this.edgePadding = EdgeInsets.zero,
    this.badgeCount,
  });

  final String semanticIdentifier;
  final String semanticLabel;
  final DivineIconName icon;
  final bool isSelected;
  final VoidCallback onTap;
  final double tapTargetWidth;

  /// Where to place the 48 px icon container inside the slot. Defaults to
  /// [Alignment.center] so the icon sits at the slot's centre with equal
  /// hit-target padding above and below it. Use `centerStart` /
  /// `centerEnd` (combined with [edgePadding]) for the leftmost /
  /// rightmost tabs so they hug the row's edge.
  final AlignmentGeometry iconAlignment;

  /// Horizontal inset between the slot edge and the icon container.
  /// Non-zero only for Home and Profile, where the slot extends all the
  /// way to the screen edge but the icon must still sit
  /// [_kHorizontalEdgePad] in from that edge per the Figma spec. The
  /// edge strip itself stays inside the [GestureDetector] so taps there
  /// route to the tab.
  final EdgeInsetsGeometry edgePadding;

  /// When non-null, wraps the inner icon container in a [NotificationBadge]
  /// so the badge stays anchored to the icon's top-right corner rather
  /// than to the (potentially much wider) tap target. Pass `null` on tabs
  /// that never show a badge — that keeps `NotificationBadge` out of the
  /// widget tree entirely so finders downstream still match exactly one
  /// instance.
  final int? badgeCount;

  @override
  Widget build(BuildContext context) {
    Widget iconBox = SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Center(
        child: Opacity(
          // Figma: unselected tabs render at 32 % opacity; selected stays
          // at 100 %. No color tint — just dim + shadow toggle.
          opacity: isSelected ? 1.0 : 0.32,
          child: _ShadowedNavIcon(icon: icon, showShadow: isSelected),
        ),
      ),
    );

    if (badgeCount != null) {
      iconBox = NotificationBadge(count: badgeCount!, child: iconBox);
    }

    return Semantics(
      identifier: semanticIdentifier,
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: SizedBox(
          width: tapTargetWidth,
          height: _kTabSlotHeight,
          child: Padding(
            padding: edgePadding,
            child: Align(alignment: iconAlignment, child: iconBox),
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
    required this.tapTargetWidth,
    this.iconAlignment = Alignment.center,
    this.edgePadding = EdgeInsets.zero,
  });

  final String semanticLabel;
  final bool isSelected;
  final VoidCallback onTap;
  final double tapTargetWidth;
  final AlignmentGeometry iconAlignment;

  /// See [_IconTabButton.edgePadding].
  final EdgeInsetsGeometry edgePadding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.watch(authServiceProvider);
    final pubkey = authService.currentPublicKeyHex;
    final profile = pubkey == null
        ? null
        : ref.watch(userProfileReactiveProvider(pubkey)).value;
    final imageUrl = profile?.picture;
    final hasAvatar = imageUrl != null && imageUrl.isNotEmpty;

    final iconBox = SizedBox.square(
      dimension: kMinInteractiveDimension,
      child: Center(
        child: hasAvatar
            ? _ProfileAvatarBox(imageUrl: imageUrl, isSelected: isSelected)
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
    );

    return Semantics(
      identifier: 'profile_tab',
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: SizedBox(
          width: tapTargetWidth,
          height: _kTabSlotHeight,
          child: Padding(
            padding: edgePadding,
            child: Align(alignment: iconAlignment, child: iconBox),
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
  const _ProfileAvatarBox({required this.imageUrl, required this.isSelected});

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
              child: VineCachedImage(imageUrl: imageUrl, width: 24, height: 24),
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
  const _CameraButton({required this.onTap, required this.tapTargetWidth});

  final VoidCallback onTap;
  final double tapTargetWidth;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'camera_button',
      button: true,
      label: context.l10n.navOpenCamera,
      child: GestureDetector(
        onTap: onTap,
        behavior: .opaque,
        child: SizedBox(
          width: tapTargetWidth,
          height: _kTabSlotHeight,
          // Centered so the visible pill keeps its on-screen position
          // even though the slot is taller and wider than the pill —
          // the extra space all goes to hit-target absorption.
          child: Center(
            child: Container(
              width: _kCameraButtonWidth,
              height: kMinInteractiveDimension,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: VineTheme.cameraButtonGreen,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const DivineIcon(icon: .cameraRetro, size: 32),
            ),
          ),
        ),
      ),
    );
  }
}
