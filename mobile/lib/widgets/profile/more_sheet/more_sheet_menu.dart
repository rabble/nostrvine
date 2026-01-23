// ABOUTME: Menu widget for the More sheet with profile actions
// ABOUTME: Copy public key, unfollow, and block/unblock actions

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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

  @override
  Widget build(BuildContext context) {
    return Column(
      key: const ValueKey('menu'),
      mainAxisSize: MainAxisSize.min,
      children: [
        // Copy public key action
        InkWell(
          onTap: onCopy,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Row(
              children: [
                SvgPicture.asset(
                  'assets/icon/copy.svg',
                  width: 24,
                  height: 24,
                  colorFilter: const ColorFilter.mode(
                    VineTheme.whiteText,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  'Copy public key (npub)',
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
                    'assets/icon/userMinus.svg',
                    width: 24,
                    height: 24,
                    colorFilter: const ColorFilter.mode(
                      VineTheme.whiteText,
                      BlendMode.srcIn,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Unfollow $displayName',
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
                      ? 'assets/icon/prohibitInset.svg'
                      : 'assets/icon/prohibit.svg',
                  width: 24,
                  height: 24,
                  colorFilter: ColorFilter.mode(
                    isBlocked ? VineTheme.onSurface : VineTheme.error,
                    BlendMode.srcIn,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  isBlocked ? 'Unblock $displayName' : 'Block $displayName',
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
