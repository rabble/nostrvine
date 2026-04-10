// ABOUTME: Follow button widget for profile page using BLoC pattern.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/unfollow_confirmation_sheet.dart';
import 'package:unified_logger/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
class FollowFromProfileButton extends ConsumerWidget {
  const FollowFromProfileButton({
    required this.pubkey,
    required this.displayName,
    super.key,
    this.onBlockedTap,
  });

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  /// The display name of the user (for unfollow confirmation).
  final String displayName;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrClient.publicKey;

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    // Watch blocklist to reactively update button state
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    final isBlocked = blocklistService.isBlocked(pubkey);
    final isBlockedByThem = blocklistService.hasBlockedUs(pubkey);

    return BlocProvider(
      create: (_) => MyFollowingBloc(
        followRepository: followRepository,
        contentBlocklistService: blocklistService,
      )..add(const MyFollowingListLoadRequested()),
      child: FollowFromProfileButtonView(
        pubkey: pubkey,
        displayName: displayName,
        currentUserPubkey: currentUserPubkey,
        isBlocked: isBlocked,
        isBlockedByThem: isBlockedByThem,
        onBlockedTap: onBlockedTap,
      ),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow button.
class FollowFromProfileButtonView extends StatelessWidget {
  @visibleForTesting
  const FollowFromProfileButtonView({
    required this.pubkey,
    required this.displayName,
    required this.currentUserPubkey,
    super.key,
    this.isBlocked = false,
    this.isBlockedByThem = false,
    this.onBlockedTap,
  });

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  /// The display name of the user (for unfollow confirmation).
  final String displayName;

  /// The current user's public key (used for optimistic follower count update).
  final String? currentUserPubkey;

  /// Whether the user is blocked by us.
  final bool isBlocked;

  /// Whether the user has blocked us (prevents following).
  final bool isBlockedByThem;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) {
    // If the other user has blocked us, hide the follow button entirely
    if (isBlockedByThem) {
      return const SizedBox.shrink();
    }

    // Show Blocked state if user is blocked by us
    if (isBlocked) {
      return OutlinedButton(
        onPressed: onBlockedTap,
        style: OutlinedButton.styleFrom(
          backgroundColor: VineTheme.errorContainer,
          disabledBackgroundColor: VineTheme.errorContainer,
          foregroundColor: VineTheme.error,
          disabledForegroundColor: VineTheme.error,
          side: const BorderSide(color: VineTheme.errorContainer, width: 2),
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SvgPicture.asset(
              DivineIconName.prohibit.assetPath,
              width: 24,
              height: 24,
              colorFilter: const ColorFilter.mode(
                VineTheme.error,
                BlendMode.srcIn,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Blocked',
              style: VineTheme.titleMediumFont(color: VineTheme.error),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
      selector: (state) => state.isFollowing(pubkey),
      builder: (context, isFollowing) {
        if (isFollowing) {
          return _FollowingButton(
            onPressed: () => _showUnfollowConfirmation(context),
          );
        }
        return _FollowButton(onPressed: () => _follow(context));
      },
    );
  }

  Future<void> _showUnfollowConfirmation(BuildContext context) async {
    final result = await showUnfollowConfirmation(
      context,
      displayName: displayName,
    );

    if (result == true && context.mounted) {
      _unfollow(context);
    }
  }

  void _follow(BuildContext context) {
    Log.info(
      'Profile follow button tapped for $pubkey',
      name: 'FollowFromProfileButton',
      category: LogCategory.ui,
    );

    // Follow in MyFollowingBloc
    context.read<MyFollowingBloc>().add(MyFollowingToggleRequested(pubkey));

    // Optimistically update the followers count in OthersFollowersBloc
    final othersFollowersBloc = context.read<OthersFollowersBloc?>();
    if (othersFollowersBloc != null && currentUserPubkey != null) {
      othersFollowersBloc.add(
        OthersFollowersIncrementRequested(currentUserPubkey!),
      );
    }
  }

  void _unfollow(BuildContext context) {
    Log.info(
      'Profile unfollow confirmed for $pubkey',
      name: 'FollowFromProfileButton',
      category: LogCategory.ui,
    );

    // Unfollow in MyFollowingBloc
    context.read<MyFollowingBloc>().add(MyFollowingToggleRequested(pubkey));

    // Optimistically update the followers count in OthersFollowersBloc
    final othersFollowersBloc = context.read<OthersFollowersBloc?>();
    if (othersFollowersBloc != null && currentUserPubkey != null) {
      othersFollowersBloc.add(
        OthersFollowersDecrementRequested(currentUserPubkey!),
      );
    }
  }
}

/// Button showing "Following" state with checkmark icon.
class _FollowingButton extends StatelessWidget {
  const _FollowingButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      expanded: true,
      type: .secondary,
      onPressed: onPressed,
      label: 'Following',
      leadingIcon: .userCheck,
    );
  }
}

/// Button showing "Follow" state with plus icon.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      onPressed: onPressed,
      expanded: true,
      leadingIcon: DivineIconName.userPlus,
      label: 'Follow',
    );
  }
}
