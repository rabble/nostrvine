// ABOUTME: Follow button widget for video overlay using BLoC pattern.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/follow/following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Page widget that creates the [FollowingBloc] and provides it to the view.
///
/// Follows the VGV Page/View pattern:
/// - Page: Creates and provides BLoC with dependencies
/// - View: Consumes BLoC state and renders UI
class VideoFollowButton extends ConsumerWidget {
  const VideoFollowButton({super.key, required this.pubkey});

  /// The public key of the video author to follow/unfollow.
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    // Don't show follow button for own videos
    if (currentUserPubkey == pubkey) {
      return const SizedBox.shrink();
    }

    return BlocProvider(
      create: (_) => FollowingBloc(
        followRepository: followRepository,
        nostrClient: nostrClient,
        authService: authService,
      )..add(FollowingListLoadRequested(currentUserPubkey ?? '')),
      child: _VideoFollowButtonView(pubkey: pubkey),
    );
  }
}

/// View widget that consumes [FollowingBloc] state and renders the follow button.
class _VideoFollowButtonView extends StatelessWidget {
  const _VideoFollowButtonView({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<FollowingBloc, FollowingState, bool>(
      selector: (state) => state.isFollowing(pubkey),
      builder: (context, isFollowing) {
        return GestureDetector(
          onTap: () {
            Log.info(
              'Follow button tapped for $pubkey',
              name: 'VideoFollowButton',
              category: LogCategory.ui,
            );
            context.read<FollowingBloc>().add(FollowToggleRequested(pubkey));
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: (isFollowing ? Colors.grey[800] : VineTheme.vineGreen)
                  ?.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: (isFollowing ? Colors.grey[600] : VineTheme.vineGreen)
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
