// ABOUTME: Action buttons widget for profile page (edit, clips, share, follow, block)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

/// Action buttons shown on profile page
/// Different buttons shown for own profile vs other user profiles
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.onEditProfile,
    this.onOpenClips,
    this.onShareProfile,
    this.onBlockUser,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenClips;
  final VoidCallback? onShareProfile;
  final void Function(bool isCurrentlyBlocked)? onBlockUser;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
    child: Row(
      children: [
        if (isOwnProfile) ...[
          Expanded(
            child: ElevatedButton(
              onPressed: onEditProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.onPrimary,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Edit',
                style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              key: const Key('library-button'),
              onPressed: onOpenClips,
              style: OutlinedButton.styleFrom(
                backgroundColor: VineTheme.surfaceContainer,
                foregroundColor: VineTheme.vineGreen,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Library',
                style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton(
              onPressed: onShareProfile,
              style: OutlinedButton.styleFrom(
                backgroundColor: VineTheme.surfaceContainer,
                foregroundColor: VineTheme.vineGreen,
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 24,
                ),
                side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              child: Text(
                'Share',
                style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
              ),
            ),
          ),
        ] else ...[
          Expanded(child: FollowFromProfileButton(pubkey: userIdHex)),
          const SizedBox(width: 12),
          Consumer(
            builder: (context, ref, _) {
              final blocklistService = ref.watch(
                contentBlocklistServiceProvider,
              );
              final isBlocked = blocklistService.isBlocked(userIdHex);
              final buttonColor = isBlocked
                  ? VineTheme.onSurfaceMuted
                  : VineTheme.likeRed;
              return OutlinedButton(
                onPressed: () => onBlockUser?.call(isBlocked),
                style: OutlinedButton.styleFrom(
                  foregroundColor: buttonColor,
                  side: BorderSide(color: buttonColor),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                child: Text(
                  isBlocked ? 'Unblock' : 'Block',
                  style: VineTheme.titleMediumFont(color: buttonColor),
                ),
              );
            },
          ),
        ],
      ],
    ),
  );
}
