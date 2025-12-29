// ABOUTME: Follow button widget for profile page using BLoC pattern.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page widget that creates the [FollowingBloc] and provides it to the view.
class FollowFromProfileButton extends ConsumerWidget {
  const FollowFromProfileButton({super.key, required this.pubkey});

  /// The public key of the profile user to follow/unfollow.
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    // Don't show follow button for own profile
    if (nostrClient.publicKey == pubkey) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) => FollowingBloc(
        followRepository: followRepository,
        nostrClient: nostrClient,
        targetPubkey: nostrClient.publicKey,
      )..add(const FollowingListLoadRequested()),
      child: FollowFromProfileButtonView(pubkey: pubkey),
    );
  }
}

/// View widget that consumes [FollowingBloc] state and renders the follow button.
class FollowFromProfileButtonView extends StatelessWidget {
  @visibleForTesting
  const FollowFromProfileButtonView({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FollowingBloc, FollowingState, bool>(
      selector: (state) => state.isFollowing(pubkey),
      builder: (context, isFollowing) {
        return isFollowing
            ? OutlinedButton(
                onPressed: () => _toggleFollow(context),
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
                onPressed: () => _toggleFollow(context),
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

  void _toggleFollow(BuildContext context) {
    Log.info(
      'Profile follow button tapped for $pubkey',
      name: 'FollowFromProfileButton',
      category: LogCategory.ui,
    );
    context.read<FollowingBloc>().add(FollowToggleRequested(pubkey));
  }
}
