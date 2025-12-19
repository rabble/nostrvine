// ABOUTME: Reusable tile widget for displaying user profile information in lists
// ABOUTME: Shows avatar, name, and follow button with tap handling for navigation

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:openvine/widgets/user_avatar.dart';

/// A tile widget for displaying user profile information in lists.
///
/// Supports two modes for follow button behavior:
/// 1. **Callback mode** (for BLoC integration): Pass [isFollowing] and
///    [onToggleFollow] to control follow state externally.
/// 2. **Riverpod mode** (default): Uses [isFollowingProvider] and
///    [FollowActionsHelper] internally.
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

  /// External follow state. When provided with [onToggleFollow],
  /// the tile uses callback mode instead of Riverpod mode.
  final bool? isFollowing;

  /// Callback to toggle follow state. When provided with [isFollowing],
  /// the tile uses callback mode instead of Riverpod mode.
  final VoidCallback? onToggleFollow;

  /// Whether the tile is using callback mode (BLoC integration).
  bool get _usesCallbackMode => isFollowing != null && onToggleFollow != null;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userProfileService = ref.watch(userProfileServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;

    return FutureBuilder(
      future: userProfileService.fetchProfile(pubkey),
      builder: (context, snapshot) {
        final profile = userProfileService.getCachedProfile(pubkey);

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              // Avatar
              GestureDetector(
                onTap: onTap,
                child: UserAvatar(imageUrl: profile?.picture, size: 48),
              ),
              const SizedBox(width: 12),

              // Name and details
              Expanded(
                child: GestureDetector(
                  onTap: onTap,
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
                      if (profile?.about != null && profile!.about!.isNotEmpty)
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
              ),

              // Follow button
              if (showFollowButton && !isCurrentUser) ...[
                const SizedBox(width: 12),
                _usesCallbackMode
                    ? _CallbackFollowButton(
                        isFollowing: isFollowing!,
                        onToggleFollow: onToggleFollow!,
                      )
                    : _RiverpodFollowButton(pubkey: pubkey),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Follow button that uses external callbacks (for BLoC integration).
class _CallbackFollowButton extends StatelessWidget {
  const _CallbackFollowButton({
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

/// Follow button that uses Riverpod providers (default mode).
class _RiverpodFollowButton extends ConsumerWidget {
  const _RiverpodFollowButton({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isFollowing = ref.watch(isFollowingProvider(pubkey));

    return SizedBox(
      height: 32,
      child: ElevatedButton(
        onPressed: () => _toggleFollow(context, ref, isFollowing),
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

  Future<void> _toggleFollow(
    BuildContext context,
    WidgetRef ref,
    bool isCurrentlyFollowing,
  ) async {
    await FollowActionsHelper.toggleFollow(
      ref: ref,
      context: context,
      pubkey: pubkey,
      isCurrentlyFollowing: isCurrentlyFollowing,
      contextName: 'UserProfileTile',
    );
  }
}
