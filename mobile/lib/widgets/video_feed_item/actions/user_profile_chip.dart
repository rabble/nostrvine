// ABOUTME: User profile chip with follow button for video overlay.
// ABOUTME: Shows username that navigates to profile, and follow/unfollow button.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/social_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/user_name.dart';

/// User profile chip with optional follow button for video overlay.
///
/// Displays the video author's username in a tappable chip that navigates
/// to their profile. For videos by other users, also shows a follow/unfollow
/// button.
class UserProfileChip extends ConsumerWidget {
  const UserProfileChip({required this.pubkey, super.key});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch UserProfileService directly (now a ChangeNotifier)
    // This will rebuild when profiles are added/updated
    final userProfileService = ref.watch(userProfileServiceProvider);
    final profile = userProfileService.getCachedProfile(pubkey);

    // If profile not cached and not known missing, fetch it
    if (profile == null && !userProfileService.shouldSkipProfileFetch(pubkey)) {
      Future.microtask(() {
        ref.read(userProfileProvider.notifier).fetchProfile(pubkey);
      });
    }

    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo = currentUserPubkey == pubkey;

    final socialState = ref.watch(socialProvider);
    final isFollowing = socialState.isFollowing(pubkey);
    final isFollowInProgress = socialState.isFollowInProgress(pubkey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Username chip (tappable to go to profile)
        GestureDetector(
          onTap: () {
            Log.info(
              '👤 User tapped profile: authorPubkey=$pubkey',
              name: 'UserProfileChip',
              category: LogCategory.ui,
            );
            context.goProfileGrid(pubkey);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.person, size: 14, color: Colors.white),
                const SizedBox(width: 6),
                UserName.fromPubKey(
                  pubkey,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
        // Follow button next to username (only for other users' videos)
        if (!isOwnVideo) ...[
          const SizedBox(width: 8),
          _FollowButton(
            pubkey: pubkey,
            isFollowing: isFollowing,
            isFollowInProgress: isFollowInProgress,
          ),
        ],
      ],
    );
  }
}

/// Follow/Unfollow button widget.
class _FollowButton extends ConsumerWidget {
  const _FollowButton({
    required this.pubkey,
    required this.isFollowing,
    required this.isFollowInProgress,
  });

  final String pubkey;
  final bool isFollowing;
  final bool isFollowInProgress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: isFollowInProgress
          ? null
          : () async {
              Log.info(
                '👤 Follow button tapped for $pubkey',
                name: 'UserProfileChip',
                category: LogCategory.ui,
              );
              if (isFollowing) {
                await ref.read(socialProvider.notifier).unfollowUser(pubkey);
              } else {
                await ref.read(socialProvider.notifier).followUser(pubkey);
              }
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: (isFollowing ? Colors.grey[800] : VineTheme.vineGreen)
              ?.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                (isFollowing ? Colors.grey[600] : VineTheme.vineGreen)
                    ?.withValues(alpha: 0.5) ??
                Colors.transparent,
          ),
        ),
        child: isFollowInProgress
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : Text(
                isFollowing ? 'Following' : 'Follow',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
      ),
    );
  }
}
