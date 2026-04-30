// ABOUTME: Menu widget for the More sheet with profile actions
// ABOUTME: Copy public key, unfollow, and block/unblock actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/l10n/l10n.dart';

/// Menu widget for the More sheet with copy, unfollow, and block actions.
class MoreSheetMenu extends StatelessWidget {
  /// Creates a More sheet menu.
  const MoreSheetMenu({
    required this.displayName,
    required this.isFollowing,
    required this.isBlocked,
    required this.onCopy,
    required this.onUnfollow,
    required this.onBlockTap,
    this.onAddToList,
    super.key,
  });

  /// The display name of the user.
  final String displayName;

  /// Whether the current user is following this user.
  final bool isFollowing;

  /// Whether this user is blocked.
  final bool isBlocked;

  /// Called when copy public key is tapped.
  final VoidCallback onCopy;

  /// Called when unfollow is tapped.
  final VoidCallback onUnfollow;

  /// Called when block/unblock is tapped.
  final VoidCallback onBlockTap;

  /// Optional callback for the "Add to list" action.
  ///
  /// When null, the action is hidden (used for feature-flag gating).
  final VoidCallback? onAddToList;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Add to list action (curated lists feature flag gated by the caller)
        if (onAddToList != null)
          InkWell(
            onTap: onAddToList,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: 16,
                horizontal: 16,
              ),
              child: Row(
                children: [
                  SvgPicture.asset(
                    DivineIconName.listPlus.assetPath,
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.whiteText,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    context.l10n.profileAddToListDisplayName(displayName),
                    style: VineTheme.titleMediumFont(),
                  ),
                ],
              ),
            ),
          ),
        // Copy public key action
        InkWell(
          onTap: onCopy,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  DivineIconName.copy.assetPath,
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  context.l10n.profileCopyPublicKey,
                  style: VineTheme.titleMediumFont(),
                ),
              ],
            ),
          ),
        ),
        // Unfollow action (only if following)
        if (isFollowing)
          InkWell(
            onTap: onUnfollow,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
              child: Row(
                children: [
                  SvgPicture.asset(
                    DivineIconName.userMinus.assetPath,
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.whiteText,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    context.l10n.profileUnfollowDisplayName(displayName),
                    style: VineTheme.titleMediumFont(),
                  ),
                ],
              ),
            ),
          ),
        // Block/Unblock action
        InkWell(
          onTap: onBlockTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  isBlocked
                      ? DivineIconName.prohibitInset.assetPath
                      : DivineIconName.prohibit.assetPath,
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    isBlocked ? VineTheme.onSurface : VineTheme.error,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  isBlocked
                      ? context.l10n.profileUnblockDisplayName(displayName)
                      : context.l10n.profileBlockDisplayName(displayName),
                  style: VineTheme.titleMediumFont(
                    color: isBlocked ? VineTheme.onSurface : VineTheme.error,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
