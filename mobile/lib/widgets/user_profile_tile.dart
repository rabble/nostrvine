// ABOUTME: Reusable tile widget for displaying user profile information in lists
// ABOUTME: Shows avatar, name, and follow button with tap handling for navigation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// A tile widget for displaying user profile information in lists.
///
/// Uses callback mode for follow button behavior - the parent widget
/// controls the follow state via [isFollowing] and [onToggleFollow].
///
/// Set [showFollowButton] to false to hide the follow button entirely.
class UserProfileTile extends ConsumerWidget {
  const UserProfileTile({
    super.key,
    required this.pubkey,
    this.onTap,
    this.showFollowButton = true,
    this.isFollowing,
    this.onToggleFollow,
  });

  /// The public key of the user to display.
  final String pubkey;

  /// Callback when the tile (avatar or name) is tapped.
  final VoidCallback? onTap;

  /// Whether to show the follow button. Defaults to true.
  final bool showFollowButton;

  /// Whether the current user is following this user.
  /// Required when [showFollowButton] is true.
  final bool? isFollowing;

  /// Callback to toggle follow state.
  /// Required when [showFollowButton] is true.
  final VoidCallback? onToggleFollow;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;

    return FutureBuilder(
      future: userProfileService.fetchProfile(pubkey),
      builder: (context, snapshot) {
        final profile = userProfileService.getCachedProfile(pubkey);
        // wrapping with Semantics for testability and accessibility
        return Semantics(
          label: profile?.betterDisplayName('Unknown'),
          container: true,
          explicitChildNodes: false,
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VineTheme.cardBackground,
              borderRadius: BorderRadius.circular(12),
            ),
            child: GestureDetector(
              onTap: onTap,
              child: Row(
                children: [
                  // Avatar
                  UserAvatar(imageUrl: profile?.picture, size: 48),
                  const SizedBox(width: 12),

                  // Name and details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          profile?.bestDisplayName ?? 'Loading...',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (profile?.about != null &&
                            profile!.about!.isNotEmpty)
                          Text(
                            profile.about!,
                            style: TextStyle(
                              color: Colors.grey[400],
                              fontSize: 14,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Follow button
                  if (showFollowButton &&
                      !isCurrentUser &&
                      isFollowing != null &&
                      onToggleFollow != null) ...[
                    const SizedBox(width: 12),
                    _FollowButton(
                      isFollowing: isFollowing!,
                      onToggleFollow: onToggleFollow!,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Follow button widget for user profile tiles.
class _FollowButton extends StatelessWidget {
  const _FollowButton({
    required this.isFollowing,
    required this.onToggleFollow,
  });

  final bool isFollowing;
  final VoidCallback onToggleFollow;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: onToggleFollow,
        style: ElevatedButton.styleFrom(
          backgroundColor: isFollowing ? Colors.white : VineTheme.vineGreen,
          foregroundColor: isFollowing ? VineTheme.vineGreen : Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(fontSize: 12),
        ),
      ),
    );
  }
}
