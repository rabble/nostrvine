// ABOUTME: Action buttons widget for profile page (edit, library, follow)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

/// Action buttons shown on profile page
/// Different buttons shown for own profile vs other user profiles
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.displayName,
    this.onEditProfile,
    this.onOpenClips,
    this.onOpenAnalytics,
    this.onBlockedTap,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (required when not own profile).
  final String? displayName;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenClips;
  final VoidCallback? onOpenAnalytics;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final buttons = _buildButtons(context);
      // Use Row with Expanded when content fits, scroll when it overflows
      return SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: constraints.maxWidth - 48),
          child: IntrinsicWidth(
            child: Row(
              spacing: 12,
              children: buttons,
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _buildButtons(BuildContext context) {
    if (isOwnProfile) {
      return [
        Expanded(
          child: DivineButton(
            expanded: true,
            leadingIcon: .pencilSimpleLineDuo,
            label: context.l10n.profileEditLabel,
            onPressed: onEditProfile,
          ),
        ),
        Expanded(
          child: DivineButton(
            key: const Key('library-button'),
            expanded: true,
            type: .secondary,
            leadingIcon: .filmSlate,
            label: context.l10n.profileLibraryLabel,
            onPressed: onOpenClips,
          ),
        ),
        SizedBox.square(
          dimension: max(48, MediaQuery.textScalerOf(context).scale(48)),
          child: OutlinedButton(
            onPressed: onOpenAnalytics,
            style: OutlinedButton.styleFrom(
              padding: EdgeInsets.zero,
              backgroundColor: VineTheme.surfaceContainer,
              foregroundColor: VineTheme.whiteText,
              side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: Icon(
              Icons.analytics_outlined,
              size: max(20, MediaQuery.textScalerOf(context).scale(20)),
            ),
          ),
        ),
      ];
    }
    return [
      Expanded(
        child: FollowFromProfileButton(
          pubkey: userIdHex,
          displayName: displayName ?? 'user',
          onBlockedTap: onBlockedTap,
        ),
      ),
    ];
  }
}
