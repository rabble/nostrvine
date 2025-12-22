// ABOUTME: Screen displaying list of users who follow the profile being viewed
// ABOUTME: Uses BLoC pattern with Page/View separation

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/followers/followers_bloc.dart';
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget that creates the BLoCs and provides them to the view.
///
/// Follows the VGV Page/View pattern:
/// - Page: Creates and provides BLoCs with dependencies
/// - View: Consumes BLoC state and renders UI
class FollowersScreen extends ConsumerWidget {
  const FollowersScreen({
    super.key,
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;

    return MultiBlocProvider(
      providers: [
        // FollowersBloc for fetching the followers list
        BlocProvider(
          create: (_) => FollowersBloc(
            followRepository: followRepository,
            nostrClient: nostrClient,
          )..add(FollowersListLoadRequested(pubkey)),
        ),
        // FollowingBloc for tracking current user's following state
        BlocProvider(
          create: (_) => FollowingBloc(
            followRepository: followRepository,
            nostrClient: nostrClient,
            authService: authService,
          )..add(FollowingListLoadRequested(currentUserPubkey ?? '')),
        ),
      ],
      child: _FollowersScreenView(pubkey: pubkey, displayName: displayName),
    );
  }
}

/// View widget that consumes BLoC state and renders the followers list.
class _FollowersScreenView extends StatelessWidget {
  const _FollowersScreenView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String displayName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: Colors.white,
        title: Text(
          "$displayName's Followers",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: BlocBuilder<FollowersBloc, FollowersState>(
        builder: (context, state) {
          return switch (state.status) {
            FollowersStatus.initial || FollowersStatus.loading => const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
            FollowersStatus.failure => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 48),
                  const SizedBox(height: 16),
                  const Text(
                    'Failed to load followers',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<FollowersBloc>().add(
                        FollowersListLoadRequested(pubkey),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VineTheme.vineGreen,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            FollowersStatus.success =>
              state.followersPubkeys.isEmpty
                  ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.people_outline,
                            color: Colors.grey,
                            size: 48,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No followers yet',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: state.followersPubkeys.length,
                      itemBuilder: (context, index) {
                        final followerPubkey = state.followersPubkeys[index];
                        return BlocSelector<
                          FollowingBloc,
                          FollowingState,
                          bool
                        >(
                          selector: (followingState) =>
                              followingState.isFollowing(followerPubkey),
                          builder: (context, isFollowing) {
                            return UserProfileTile(
                              pubkey: followerPubkey,
                              onTap: () => context.goProfile(followerPubkey, 0),
                              isFollowing: isFollowing,
                              onToggleFollow: () {
                                context.read<FollowingBloc>().add(
                                  FollowToggleRequested(followerPubkey),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
          };
        },
      ),
    );
  }
}
