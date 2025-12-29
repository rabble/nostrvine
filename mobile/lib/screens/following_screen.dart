// ABOUTME: Screen displaying list of users followed by the profile being viewed
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget that creates the [FollowingBloc] and provides it to the view.
class FollowingPage extends ConsumerWidget {
  const FollowingPage({
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

    return BlocProvider(
      create: (_) => FollowingBloc(
        followRepository: followRepository,
        nostrClient: nostrClient,
        targetPubkey: pubkey,
      )..add(const FollowingListLoadRequested()),
      child: FollowingView(pubkey: pubkey, displayName: displayName),
    );
  }
}

/// View widget that consumes [FollowingBloc] state and renders the UI.
///
/// Stateless widget that uses [BlocBuilder] to react to state changes.
class FollowingView extends StatelessWidget {
  const FollowingView({
    super.key,
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final appBarTitle = displayName?.isNotEmpty == true
        ? "$displayName's Following"
        : 'Following';

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
      body: BlocBuilder<FollowingBloc, FollowingState>(
        builder: (context, state) {
          return switch (state.status) {
            FollowingStatus.initial || FollowingStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            FollowingStatus.success => _FollowingListBody(
              following: state.followingPubkeys,
              pubkey: pubkey,
            ),
            FollowingStatus.failure => const _FollowingErrorBody(),
          };
        },
      ),
    );
  }
}

class _FollowingListBody extends StatelessWidget {
  const _FollowingListBody({required this.following, required this.pubkey});

  final List<String> following;
  final String pubkey;

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return const _FollowingEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<FollowingBloc>().add(const FollowingListLoadRequested());
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: following.length,
        itemBuilder: (context, index) {
          final userPubkey = following[index];
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

class _FollowingEmptyState extends StatelessWidget {
  const _FollowingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.person_add_outlined, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Not following anyone yet',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FollowingErrorBody extends StatelessWidget {
  const _FollowingErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          Text(
            'Failed to load following list',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              context.read<FollowingBloc>().add(
                const FollowingListLoadRequested(),
              );
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
