// ABOUTME: Reusable tile widget for displaying user profile information in lists
// ABOUTME: Shows avatar, name, and follow button with tap handling for navigation

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/unfollow_confirmation_sheet.dart';

/// A tile widget for displaying user profile information in lists.
///
/// Uses callback mode for follow button behavior - the parent widget
/// controls the follow state via [isFollowing] and [onToggleFollow].
///
/// Set [showFollowButton] to false to hide the follow button entirely.
class UserProfileTile extends ConsumerWidget {
  const UserProfileTile({
    required this.pubkey,
    super.key,
    this.onTap,
    this.showFollowButton = true,
    this.isFollowing,
    this.onToggleFollow,
    this.index,
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

  /// Optional index for semantic labeling in lists (e.g., Maestro tests).
  final int? index;

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
        // Get display name or truncated npub (fallback for users without Kind 0)
        final truncatedNpub = NostrKeyUtils.truncateNpub(pubkey);
        final displayName =
            profile?.bestDisplayName ??
            UserProfile.defaultDisplayNameFor(pubkey);

        // Get unique identifier: NIP-05 if available, otherwise truncated npub
        final uniqueIdentifier = profile?.displayNip05?.isNotEmpty == true
            ? profile!.displayNip05!
            : truncatedNpub;

        return Semantics(
          identifier: 'user_profile_tile_$pubkey',
          label: displayName,
          container: true,
          child: GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Avatar with border (matching video player style)
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                        color: VineTheme.onSurfaceDisabled,
                      ),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child:
                          profile?.picture != null &&
                              profile!.picture!.isNotEmpty
                          ? CachedNetworkImage(
                              imageUrl: profile.picture!,
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                              cacheManager: openVineImageCache,
                              placeholder: (context, url) => Image.asset(
                                'assets/icon/acid_avatar.png',
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              ),
                              errorWidget: (context, url, error) => Image.asset(
                                'assets/icon/acid_avatar.png',
                                width: 46,
                                height: 46,
                                fit: BoxFit.cover,
                              ),
                            )
                          : Image.asset(
                              'assets/icon/acid_avatar.png',
                              width: 46,
                              height: 46,
                              fit: BoxFit.cover,
                            ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Name and unique identifier
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          style: VineTheme.titleSmallFont(
                            color: VineTheme.onSurface,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          uniqueIdentifier,
                          style: VineTheme.bodySmallFont(
                            color: VineTheme.onSurfaceVariant,
                          ),
                          maxLines: 1,
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
                      displayName: displayName,
                      index: index,
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
    required this.displayName,
    this.index,
  });

  final bool isFollowing;
  final VoidCallback onToggleFollow;
  final String displayName;
  final int? index;

  Future<void> _confirmUnfollow(BuildContext context) async {
    final result = await showUnfollowConfirmation(
      context,
      displayName: displayName,
    );

    if (result == true && context.mounted) {
      onToggleFollow();
    }
  }

  @override
  Widget build(BuildContext context) {
    final indexSuffix = index != null ? ' $index' : '';

    if (isFollowing) {
      // Following state: surfaceContainer bg, outlineMuted border, userMinus icon
      return Semantics(
        identifier: 'unfollow_user',
        label: 'Unfollow user$indexSuffix',
        button: true,
        child: GestureDetector(
          onTap: () => _confirmUnfollow(context),
          child: Container(
            width: 40,
            height: 40,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VineTheme.outlineMuted, width: 2),
            ),
            child: SvgPicture.asset(
              'assets/icon/userMinus.svg',
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                VineTheme.vineGreen,
                BlendMode.srcIn,
              ),
            ),
          ),
        ),
      );
    }

    // Follow state: vineGreen bg, userPlus icon
    return Semantics(
      identifier: 'follow_user',
      label: 'Follow user$indexSuffix',
      button: true,
      child: GestureDetector(
        onTap: onToggleFollow,
        child: Container(
          width: 40,
          height: 40,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: VineTheme.vineGreen,
            borderRadius: BorderRadius.circular(16),
          ),
          child: SvgPicture.asset(
            'assets/icon/userPlus.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              VineTheme.onPrimary,
              BlendMode.srcIn,
            ),
          ),
        ),
      ),
    );
  }
}
