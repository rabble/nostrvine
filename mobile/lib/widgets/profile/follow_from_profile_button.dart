// ABOUTME: Follow button widget for profile page using BLoC pattern.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
class FollowFromProfileButton extends ConsumerWidget {
  const FollowFromProfileButton({super.key, required this.pubkey});

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final currentUserPubkey = nostrClient.publicKey;

    return BlocProvider(
      create: (_) =>
          MyFollowingBloc(followRepository: followRepository)
            ..add(const MyFollowingListLoadRequested()),
      child: FollowFromProfileButtonView(
        pubkey: pubkey,
        currentUserPubkey: currentUserPubkey,
      ),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow button.
class FollowFromProfileButtonView extends StatelessWidget {
  @visibleForTesting
  const FollowFromProfileButtonView({
    required this.pubkey,
    required this.currentUserPubkey,
  });

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  /// The current user's public key (used for optimistic follower count update).
  final String? currentUserPubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
      selector: (state) => state.isFollowing(pubkey),
      builder: (context, isFollowing) {
        return isFollowing
            ? OutlinedButton(
                onPressed: () => _toggleFollow(context, isFollowing),
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
                onPressed: () => _toggleFollow(context, isFollowing),
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
    );
  }

  void _toggleFollow(BuildContext context, bool isCurrentlyFollowing) {
    Log.info(
      'Profile follow button tapped for $pubkey',
      name: 'FollowFromProfileButton',
      category: LogCategory.ui,
    );

    // Toggle follow in MyFollowingBloc
    context.read<MyFollowingBloc>().add(MyFollowingToggleRequested(pubkey));

    // Optimistically update the followers count in OthersFollowersBloc
    final othersFollowersBloc = context.read<OthersFollowersBloc?>();
    if (othersFollowersBloc != null && currentUserPubkey != null) {
      if (isCurrentlyFollowing) {
        // Unfollowing - decrement count
        othersFollowersBloc.add(
          OthersFollowersDecrementRequested(currentUserPubkey!),
        );
      } else {
        // Following - increment count
        othersFollowersBloc.add(
          OthersFollowersIncrementRequested(currentUserPubkey!),
        );
      }
    }
  }
}
