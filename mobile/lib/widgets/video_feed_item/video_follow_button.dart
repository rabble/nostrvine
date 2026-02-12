// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Circular 20x20 button positioned near author avatar.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
///
/// Uses StatefulConsumerWidget to avoid unnecessary rebuilds - the follow
/// repository and nostr client are read once during initState, not on every
/// build. The BLoC is created once and reused.
class VideoFollowButton extends ConsumerStatefulWidget {
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
  ConsumerState<VideoFollowButton> createState() => _VideoFollowButtonState();
}

class _VideoFollowButtonState extends ConsumerState<VideoFollowButton> {
  MyFollowingBloc? _bloc;
  bool _isOwnVideo = false;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializeButton();
  }

  void _initializeButton() {
    // Use read() to get values once, not watch() which causes rebuilds
    final followRepository = ref.read(followRepositoryProvider);
    final nostrClient = ref.read(nostrServiceProvider);

    // Check if this is the user's own video (read once, never changes)
    _isOwnVideo = nostrClient.publicKey == widget.pubkey;

    // Only create BLoC if we actually need to show the button
    if (followRepository != null && !_isOwnVideo) {
      // Check if already following and should hide
      final isFollowing = followRepository.isFollowing(widget.pubkey);
      if (!(widget.hideIfFollowing && isFollowing)) {
        _bloc = MyFollowingBloc(followRepository: followRepository)
          ..add(const MyFollowingListLoadRequested());
      }
    }

    _isInitialized = true;
  }

  @override
  void dispose() {
    _bloc?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fast path: not initialized yet
    if (!_isInitialized) {
      return const SizedBox.shrink();
    }

    // Fast path: own video - never show follow button
    if (_isOwnVideo) {
      return const SizedBox.shrink();
    }

    // Fast path: no repository available
    final followRepository = ref.read(followRepositoryProvider);
    if (followRepository == null) {
      return const SizedBox.shrink();
    }

    // Check current follow state for hide logic
    // Use read() since we only need the value, not reactivity here
    // The BlocSelector below handles reactivity for the actual button
    if (widget.hideIfFollowing) {
      final isFollowing = followRepository.isFollowing(widget.pubkey);
      if (isFollowing) {
        return const SizedBox.shrink();
      }
    }

    // No BLoC means we determined early we don't need to show
    if (_bloc == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider.value(
      value: _bloc!,
      child: VideoFollowButtonView(
        pubkey: widget.pubkey,
        hideIfFollowing: widget.hideIfFollowing,
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
        return Semantics(
          identifier: 'follow_button',
          label: isFollowing ? 'Following' : 'Follow',
          button: true,
          child: GestureDetector(
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
          ),
        );
      },
    );
  }
}
