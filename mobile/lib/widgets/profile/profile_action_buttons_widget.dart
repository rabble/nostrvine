// ABOUTME: Action buttons widget for profile page (edit, drafts, share, follow, block)
// ABOUTME: Shows different buttons for own profile vs other user profiles

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/theme/vine_theme.dart';

/// Action buttons shown on profile page
/// Different buttons shown for own profile vs other user profiles
class ProfileActionButtons extends StatelessWidget {
  const ProfileActionButtons({
    required this.userIdHex,
    required this.isOwnProfile,
    this.onEditProfile,
    this.onOpenDrafts,
    this.onShareProfile,
    this.onFollowUser,
    this.onUnfollowUser,
    this.onBlockUser,
    super.key,
  });

  final String userIdHex;
  final bool isOwnProfile;
  final VoidCallback? onEditProfile;
  final VoidCallback? onOpenDrafts;
  final VoidCallback? onShareProfile;
  final VoidCallback? onFollowUser;
  final VoidCallback? onUnfollowUser;
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
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Edit Profile'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              key: const Key('drafts-button'),
              onPressed: onOpenDrafts,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Drafts'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: ElevatedButton(
              onPressed: onShareProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.grey[800],
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Share Profile'),
            ),
          ),
        ] else ...[
          Expanded(
            child: Consumer(
              builder: (context, ref, _) {
                final isFollowing = ref.watch(isFollowingProvider(userIdHex));
                return isFollowing
                    ? OutlinedButton(
                        onPressed: onUnfollowUser,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VineTheme.vineGreen,
                          side: const BorderSide(color: VineTheme.vineGreen),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Following'),
                      )
                    : ElevatedButton(
                        onPressed: onFollowUser,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VineTheme.vineGreen,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: const Text('Follow'),
                      );
              },
            ),
          ),
          const SizedBox(width: 12),
          Consumer(
            builder: (context, ref, _) {
              final blocklistService = ref.watch(
                contentBlocklistServiceProvider,
              );
              final isBlocked = blocklistService.isBlocked(userIdHex);
              return OutlinedButton(
                onPressed: () => onBlockUser?.call(isBlocked),
                style: OutlinedButton.styleFrom(
                  foregroundColor: isBlocked ? Colors.grey : Colors.red,
                  side: BorderSide(color: isBlocked ? Colors.grey : Colors.red),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(isBlocked ? 'Unblock' : 'Block User'),
              );
            },
          ),
        ],
      ],
    ),
  );
}
