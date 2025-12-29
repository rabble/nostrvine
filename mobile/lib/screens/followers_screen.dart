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
class FollowersScreen extends ConsumerWidget {
  const FollowersScreen({
    super.key,
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => FollowersBloc(
            followRepository: followRepository,
            nostrClient: nostrClient,
          )..add(FollowersListLoadRequested(pubkey)),
        ),
        BlocProvider(
          create: (_) => FollowingBloc(
            followRepository: followRepository,
            nostrClient: nostrClient,
            targetPubkey: nostrClient.publicKey,
          )..add(const FollowingListLoadRequested()),
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
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final appBarTitle = displayName?.isNotEmpty == true
        ? "$displayName's Followers"
        : 'Followers';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        title: Text(
          appBarTitle,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: BlocBuilder<FollowersBloc, FollowersState>(
        builder: (context, state) {
          return switch (state.status) {
            FollowersStatus.initial || FollowersStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            FollowersStatus.success => _FollowersListBody(
              followers: state.followersPubkeys,
              pubkey: pubkey,
            ),
            FollowersStatus.failure => const _FollowersErrorBody(),
          };
        },
      ),
    );
  }
}

class _FollowersListBody extends StatelessWidget {
  const _FollowersListBody({required this.followers, required this.pubkey});

  final List<String> followers;
  final String pubkey;

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) {
      return const _FollowersEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FollowersBloc>().add(FollowersListLoadRequested(pubkey));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: followers.length,
        itemBuilder: (context, index) {
          final userPubkey = followers[index];
          return BlocSelector<FollowingBloc, FollowingState, bool>(
            selector: (state) => state.isFollowing(userPubkey),
            builder: (context, isFollowing) {
              return UserProfileTile(
                pubkey: userPubkey,
                onTap: () => context.goProfile(userPubkey, 0),
                isFollowing: isFollowing,
                onToggleFollow: () {
                  context.read<FollowingBloc>().add(
                    FollowToggleRequested(userPubkey),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _FollowersEmptyState extends StatelessWidget {
  const _FollowersEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'No followers yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FollowersErrorBody extends StatelessWidget {
  const _FollowersErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Failed to load followers list',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              // We need to get pubkey from somewhere - using empty string as fallback
              // This should be improved by storing pubkey in BLoC state
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
