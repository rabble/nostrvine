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
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/unfollow_confirmation_sheet.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
class FollowFromProfileButton extends ConsumerWidget {
  const FollowFromProfileButton({
    super.key,
    required this.pubkey,
    required this.displayName,
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

    // Don't show button until NostrClient has keys
    if (followRepository == null) {
      return const SizedBox.shrink();
    }

    // Watch blocklist version to trigger rebuilds when block/unblock occurs
    ref.watch(blocklistVersionProvider);

    // Watch blocklist to reactively update button state
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    final isBlocked = blocklistService.isBlocked(pubkey);

    return BlocProvider(
      create: (_) =>
          MyFollowingBloc(followRepository: followRepository)
            ..add(const MyFollowingListLoadRequested()),
      child: FollowFromProfileButtonView(
        pubkey: pubkey,
        displayName: displayName,
        currentUserPubkey: currentUserPubkey,
        isBlocked: isBlocked,
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
    this.isBlocked = false,
    this.onBlockedTap,
  });

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  /// The display name of the user (for unfollow confirmation).
  final String displayName;

  /// The current user's public key (used for optimistic follower count update).
  final String? currentUserPubkey;

  /// Whether the user is blocked.
  final bool isBlocked;

  /// Callback when the Blocked button is tapped.
  final VoidCallback? onBlockedTap;

  @override
  Widget build(BuildContext context) {
    // Show Blocked state if user is blocked
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
              'assets/icon/prohibit.svg',
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
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: VineTheme.surfaceContainer,
        foregroundColor: VineTheme.vineGreen,
        side: const BorderSide(color: VineTheme.outlineMuted, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icon/userCheck.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              VineTheme.vineGreen,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Following',
            style: VineTheme.titleMediumFont(color: VineTheme.vineGreen),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Button showing "Follow" state with plus icon.
class _FollowButton extends StatelessWidget {
  const _FollowButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.onPrimary,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SvgPicture.asset(
            'assets/icon/userPlus.svg',
            width: 24,
            height: 24,
            colorFilter: const ColorFilter.mode(
              VineTheme.onPrimary,
              BlendMode.srcIn,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Follow',
            style: VineTheme.titleMediumFont(color: VineTheme.onPrimary),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
