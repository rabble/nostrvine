// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Circular 20x20 button positioned near author avatar.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
class VideoFollowButton extends ConsumerWidget {
  const VideoFollowButton({
    super.key,
    required this.pubkey,
    this.hideIfFollowing = false,
  });

  /// The public key of the video author to follow/unfollow.
  final String pubkey;

  /// When true, hides the button entirely if already following.
  /// Useful for Home feed (all videos are from followed users) and
  /// Profile views of followed users.
  final bool hideIfFollowing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    // Don't show follow button for own videos
    if (nostrClient.publicKey == pubkey) {
      return const SizedBox.shrink();
    }

    // Check follow state directly from repository for immediate hide
    // This avoids race conditions with BLoC initialization
    final isFollowing = followRepository.isFollowing(pubkey);
    Log.debug(
      '🔘 VideoFollowButton: pubkey=$pubkey, hideIfFollowing=$hideIfFollowing, isFollowing=$isFollowing, followingCount=${followRepository.followingCount}',
      name: 'VideoFollowButton',
      category: LogCategory.ui,
    );
    if (hideIfFollowing && isFollowing) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) =>
          MyFollowingBloc(followRepository: followRepository)
            ..add(const MyFollowingListLoadRequested()),
      child: VideoFollowButtonView(
        pubkey: pubkey,
        hideIfFollowing: hideIfFollowing,
      ),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow button.
class VideoFollowButtonView extends StatelessWidget {
  @visibleForTesting
  const VideoFollowButtonView({
    required this.pubkey,
    this.hideIfFollowing = false,
  });

  final String pubkey;
  final bool hideIfFollowing;

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

        // Hide button entirely if already following and hideIfFollowing is true
        if (hideIfFollowing && isFollowing) {
          return const SizedBox.shrink();
        }
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
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: isFollowing ? Colors.white : VineTheme.cameraButtonGreen,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: SvgPicture.asset(
                isFollowing
                    ? 'assets/icon/Icon-Following.svg'
                    : 'assets/icon/Icon-Follow.svg',
                width: 13,
                height: 13,
                colorFilter: isFollowing
                    ? null // Icon-Following.svg has its own green color
                    : const ColorFilter.mode(Colors.white, BlendMode.srcIn),
              ),
            ),
          ),
        );
      },
    );
  }
}
