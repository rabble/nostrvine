// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Circular 20x20 button positioned near the author avatar.
// ABOUTME: Only rendered when the viewer is NOT following the author; once
// ABOUTME: following, the button disappears entirely (no "following" state).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:unified_logger/unified_logger.dart';

/// Page widget that creates the [MyFollowingBloc] and provides it to the view.
///
/// Uses StatefulConsumerWidget to avoid unnecessary rebuilds - the follow
/// repository and nostr client are read once during initState, not on every
/// build. The BLoC is created once and reused.
///
/// The button is only shown for videos authored by someone the viewer does
/// not yet follow. Once the viewer follows the author, the button hides for
/// good.
class VideoFollowButton extends ConsumerStatefulWidget {
  const VideoFollowButton({required this.pubkey, super.key});

  /// The public key of the video author to follow.
  final String pubkey;

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
    final blocklistRepository = ref.read(contentBlocklistRepositoryProvider);

    // Check if this is the user's own video (read once, never changes)
    _isOwnVideo = nostrClient.publicKey == widget.pubkey;

    // Only create the BLoC when we might need to show the button: neither
    // the viewer's own video nor an author they already follow.
    if (!_isOwnVideo && !followRepository.isFollowing(widget.pubkey)) {
      _bloc = MyFollowingBloc(
        followRepository: followRepository,
        contentBlocklistRepository: blocklistRepository,
      )..add(const MyFollowingListLoadRequested());
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
    // Fast path: not initialized yet, viewer's own video, or already
    // following — never render the button.
    if (!_isInitialized || _isOwnVideo || _bloc == null) {
      return const SizedBox.shrink();
    }

    return BlocProvider.value(
      value: _bloc!,
      child: VideoFollowButtonView(pubkey: widget.pubkey),
    );
  }
}

/// View widget that consumes [MyFollowingBloc] state and renders the follow
/// button. Hides itself entirely once the viewer is following the author.
class VideoFollowButtonView extends StatelessWidget {
  @visibleForTesting
  const VideoFollowButtonView({required this.pubkey, super.key});

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
        isReady:
            state.status == MyFollowingStatus.success ||
            state.status == MyFollowingStatus.toggleFailure,
      ),
      builder: (context, data) {
        // Do not render until the following list has loaded to avoid a
        // flash of the button for authors the viewer already follows.
        if (!data.isReady) {
          return const SizedBox.shrink();
        }

        // Hide permanently once following — no "following" affordance.
        if (data.isFollowing) {
          return const SizedBox.shrink();
        }

        return Semantics(
          identifier: 'follow_button',
          label: context.l10n.videoFollowButtonFollow,
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
              decoration: const BoxDecoration(
                color: VineTheme.cameraButtonGreen,
                shape: BoxShape.circle,
                boxShadow: VineTheme.buttonBoxShadows,
              ),
              child: const Center(
                child: DivineIcon(
                  icon: DivineIconName.follow,
                  size: 13,
                  color: VineTheme.whiteText,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
