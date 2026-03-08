// ABOUTME: Screen displaying another user's followers list
// ABOUTME: Uses OthersFollowersBloc for list + MyFollowingBloc for follow button state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

const _toggleFollowErrorMessage =
    'Failed to update follow status. Please try again.';

/// Page widget for displaying another user's followers list.
///
/// Creates both [OthersFollowersBloc] (for the list) and [MyFollowingBloc]
/// (for follow button state) and provides them to the view.
class OthersFollowersScreen extends ConsumerWidget {
  const OthersFollowersScreen({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistService = ref.watch(contentBlocklistServiceProvider);
    final nostrClient = ref.watch(nostrServiceProvider);

    // Show loading until NostrClient has keys
    if (followRepository == null) {
      return const BrandedLoadingScaffold();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => OthersFollowersBloc(
            followRepository: followRepository,
            contentBlocklistService: blocklistService,
            currentUserPubkey: nostrClient.publicKey,
          )..add(OthersFollowersListLoadRequested(pubkey)),
        ),
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistService: blocklistService,
          )..add(const MyFollowingListLoadRequested()),
        ),
      ],
      child: _OthersFollowersView(pubkey: pubkey, displayName: displayName),
    );
  }
}

class _OthersFollowersView extends ConsumerWidget {
  const _OthersFollowersView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<OthersFollowersBloc>().add(
        const OthersFollowersBlocklistChanged(),
      );
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? "$displayName's Followers"
        : 'Followers';

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        titleWidget:
            FollowerCountTitle<OthersFollowersBloc, OthersFollowersState>(
              title: appBarTitle,
              selector: (state) => state.status == OthersFollowersStatus.success
                  ? state.followersPubkeys.length
                  : 0,
            ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: 'Back',
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MyFollowingBloc, MyFollowingState>(
            listenWhen: (previous, current) =>
                current.status == MyFollowingStatus.toggleFailure &&
                previous.status != MyFollowingStatus.toggleFailure,
            listener: (context, state) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text(_toggleFollowErrorMessage)),
              );
            },
          ),
        ],
        child: BlocBuilder<OthersFollowersBloc, OthersFollowersState>(
          builder: (context, state) {
            return switch (state.status) {
              OthersFollowersStatus.initial || OthersFollowersStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              OthersFollowersStatus.success => _FollowersListBody(
                followers: state.followersPubkeys,
                targetPubkey: pubkey,
              ),
              OthersFollowersStatus.failure => _FollowersErrorBody(
                onRetry: () {
                  final targetPubkey = context
                      .read<OthersFollowersBloc>()
                      .state
                      .targetPubkey;
                  if (targetPubkey != null) {
                    context.read<OthersFollowersBloc>().add(
                      OthersFollowersListLoadRequested(targetPubkey),
                    );
                  }
                },
              ),
            };
          },
        ),
      ),
    );
  }
}

class _FollowersListBody extends StatelessWidget {
  const _FollowersListBody({
    required this.followers,
    required this.targetPubkey,
  });

  final List<String> followers;
  final String targetPubkey;

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) {
      return const _FollowersEmptyState();
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<OthersFollowersBloc>().add(
          OthersFollowersListLoadRequested(targetPubkey, forceRefresh: true),
        );
      },
      child: ListView.builder(
        itemCount: followers.length,
        itemBuilder: (context, index) {
          final userPubkey = followers[index];
          // Use MyFollowingBloc to check if current user follows this person
          return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
            selector: (state) => state.isFollowing(userPubkey),
            builder: (context, isFollowing) {
              return UserProfileTile(
                pubkey: userPubkey,
                onTap: () => context.pushOtherProfile(userPubkey),
                isFollowing: isFollowing,
                onToggleFollow: () {
                  context.read<MyFollowingBloc>().add(
                    MyFollowingToggleRequested(userPubkey),
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64, color: VineTheme.lightText),
          SizedBox(height: 16),
          Text(
            'No followers yet',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

class _FollowersErrorBody extends StatelessWidget {
  const _FollowersErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          const Text(
            'Failed to load followers list',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
