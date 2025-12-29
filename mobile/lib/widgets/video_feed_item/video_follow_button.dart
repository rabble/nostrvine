// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
class VideoFollowButton extends ConsumerWidget {
  const VideoFollowButton({super.key, required this.pubkey});

  /// The public key of the video author to follow/unfollow.
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    // Don't show follow button for own videos
    if (nostrClient.publicKey == pubkey) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) =>
          MyFollowingBloc(followRepository: followRepository)
            ..add(const MyFollowingListLoadRequested()),
      child: VideoFollowButtonView(pubkey: pubkey),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow button.
class VideoFollowButtonView extends StatelessWidget {
  @visibleForTesting
  const VideoFollowButtonView({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<
      MyFollowingBloc,
      MyFollowingState,
      ({bool isFollowing, bool isReady})
    >(
      selector: (state) => (
        isFollowing: state.isFollowing(pubkey),
        isReady: state.status == MyFollowingStatus.success,
      ),
      builder: (context, data) {
        // Don't show button until status is success to prevent flash on Home feed
        if (!data.isReady) {
          return const SizedBox.shrink();
        }

        final isFollowing = data.isFollowing;
        return GestureDetector(
          onTap: () {
            Log.info(
              'Follow button tapped for $pubkey',
              name: 'VideoFollowButton',
              category: LogCategory.ui,
            );
            context.read<MyFollowingBloc>().add(
              MyFollowingToggleRequested(pubkey),
            );
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
                width: 1,
              ),
            ),
            child: Text(
              isFollowing ? 'Following' : 'Follow',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        );
      },
    );
  }
}
