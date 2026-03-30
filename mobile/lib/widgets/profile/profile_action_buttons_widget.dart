// ABOUTME: Action buttons widget for profile page (library, share, follow)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

/// Action buttons shown on profile page
/// Different buttons shown for own profile vs other user profiles
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.displayName,
    this.onOpenClips,
    this.onShareProfile,
    this.onBlockedTap,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;

  /// Display name for unfollow confirmation (required when not own profile).
  final String? displayName;
  final VoidCallback? onOpenClips;
  final VoidCallback? onShareProfile;

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
            key: const Key('library-button'),
            expanded: true,
            leadingIcon: .filmSlate,
            type: .secondary,
            size: .small,
            label: 'My Library',
            onPressed: onOpenClips,
          ),
        ),
        DivineIconButton(
          icon: .shareFat,
          type: .secondary,
          size: .small,
          onPressed: onShareProfile,
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
