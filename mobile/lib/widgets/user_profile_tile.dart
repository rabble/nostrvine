// ABOUTME: Reusable tile widget for displaying user profile information in lists
// ABOUTME: Shows avatar, name, and follow button with tap handling for navigation

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/features/people_lists/view/add_to_people_lists_sheet.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/unfollow_confirmation_sheet.dart';
import 'package:openvine/widgets/user_avatar.dart';

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
    this.addToListEntryPoint = PeopleListEntryPoint.followersList,
    this.padding = const EdgeInsets.all(16),
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

  /// Which entry point to attribute the "Add to list" action to when the
  /// profile-list-features flag is on. Defaults to followers-list context.
  final PeopleListEntryPoint addToListEntryPoint;

  /// Inset around the row.
  ///
  /// Defaults to the list-row inset used by the follower, following, and
  /// engagement lists, whose scroll views add no padding of their own.
  /// Surfaces that already pad their container — the badge screens — pass a
  /// zero start inset so the avatar is not indented twice.
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileReactiveProvider(pubkey)).value;
    final authService = ref.watch(authServiceProvider);
    final isCurrentUser = pubkey == authService.currentPublicKeyHex;
    final profileListFeaturesEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.profileListFeatures),
    );
    // curatedLists is the master switch for people lists; profileListFeatures
    // only adds this surface on top of it. Without both, tapping would
    // construct the lazily-registered PeopleListsBloc for a disabled feature.
    final curatedListsEnabled = ref.watch(
      isFeatureEnabledProvider(FeatureFlag.curatedLists),
    );
    final showAddToList =
        profileListFeaturesEnabled && curatedListsEnabled && !isCurrentUser;

    // Get display name or truncated npub (fallback for users without Kind 0)
    final truncatedNpub = NostrKeyUtils.truncateNpub(pubkey);
    final displayName =
        profile?.bestDisplayName ?? UserProfile.defaultDisplayNameFor(pubkey);

    final claimedNip05 = profile?.shortDisplayNip05;
    final verificationStatus = claimedNip05 != null && claimedNip05.isNotEmpty
        ? ref
              .watch(nip05VerificationProvider(pubkey))
              .whenOrNull(data: (status) => status)
        : null;
    final hasVerifiedNip05 =
        verificationStatus == Nip05VerificationStatus.verified;

    // Only show NIP-05 when verification succeeds; otherwise show npub.
    final uniqueIdentifier = hasVerifiedNip05 && claimedNip05 != null
        ? claimedNip05
        : truncatedNpub;

    return Semantics(
      identifier: 'user_profile_tile_$pubkey',
      label: displayName,
      container: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: padding,
          child: Row(
            children: [
              // Avatar with border (matching video player style)
              UserAvatar(
                imageUrl: profile?.picture,
                name: displayName,
                placeholderSeed: pubkey,
                size: 48,
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
                        color: context.vineColors.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      uniqueIdentifier,
                      style: VineTheme.bodySmallFont(
                        color: context.vineColors.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Add-to-list action (curated lists feature)
              if (showAddToList) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: DivineIcon(
                    icon: DivineIconName.listPlus,
                    color: context.vineColors.onSurfaceVariant,
                  ),
                  color: context.vineColors.onSurfaceVariant,
                  tooltip: context.l10n.peopleListsAddToList,
                  onPressed: () => AddToPeopleListsSheet.show(
                    context,
                    pubkey: pubkey,
                    entryPoint: addToListEntryPoint,
                  ),
                ),
              ],

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

    // Both states map onto a design-system button: `secondary` already is the
    // surface-container fill with a muted border and a green icon, and
    // `primary` at `small` is the 40px green chip inside a 48px tap target.
    if (isFollowing) {
      return DivineIconButton(
        icon: .userMinus,
        type: .secondary,
        semanticIdentifier: 'unfollow_user',
        semanticLabel: 'Unfollow user$indexSuffix',
        onPressed: () => _confirmUnfollow(context),
      );
    }

    return DivineIconButton(
      icon: .userPlus,
      size: .small,
      semanticIdentifier: 'follow_user',
      semanticLabel: 'Follow user$indexSuffix',
      onPressed: onToggleFollow,
    );
  }
}
