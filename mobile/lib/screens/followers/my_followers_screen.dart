// ABOUTME: Screen displaying current user's followers list
// ABOUTME: Uses MyFollowersBloc for list + MyFollowingBloc for follow button state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

const _toggleFollowErrorMessage =
    'Failed to update follow status. Please try again.';

/// Page widget for displaying current user's followers list.
///
/// Creates both [MyFollowersBloc] (for the list) and [MyFollowingBloc]
/// (for follow button state - to show "follow back") and provides them.
class MyFollowersScreen extends ConsumerWidget {
  const MyFollowersScreen({required this.displayName, super.key});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => MyFollowersBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
          )..add(const MyFollowersListLoadRequested()),
        ),
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistRepository: blocklistRepository,
          )..add(const MyFollowingListLoadRequested()),
        ),
      ],
      child: _MyFollowersView(displayName: displayName),
    );
  }
}

class _MyFollowersView extends ConsumerWidget {
  const _MyFollowersView({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<MyFollowersBloc>().add(const MyFollowersBlocklistChanged());
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? "$displayName's Followers"
        : 'Followers';

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        titleWidget: FollowerCountTitle<MyFollowersBloc, MyFollowersState>(
          title: appBarTitle,
          selector: (state) => state.status == MyFollowersStatus.success
              ? state.followerCount
              : 0,
        ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: 'Back',
      ),
      body: MultiBlocListener(
        listeners: [
          BlocListener<MyFollowersBloc, MyFollowersState>(
            listener: (context, state) {
              if (state.status == MyFollowersStatus.success) {
                ScreenAnalyticsService().markDataLoaded(
                  'followers',
                  dataMetrics: {
                    'followers_count': state.followersPubkeys.length,
                  },
                );
              }
            },
          ),
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
        child: BlocBuilder<MyFollowersBloc, MyFollowersState>(
          builder: (context, state) {
            return switch (state.status) {
              MyFollowersStatus.initial || MyFollowersStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              MyFollowersStatus.success => _FollowersListBody(
                followers: state.followersPubkeys,
              ),
              MyFollowersStatus.failure => _FollowersErrorBody(
                onRetry: () {
                  context.read<MyFollowersBloc>().add(
                    const MyFollowersListLoadRequested(),
                  );
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
  const _FollowersListBody({required this.followers});

  final List<String> followers;

  @override
  Widget build(BuildContext context) {
    if (followers.isEmpty) {
      return const _FollowersEmptyState();
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<MyFollowersBloc>().add(
          const MyFollowersListLoadRequested(),
        );
      },
      child: ListView.builder(
        itemCount: followers.length,
        itemBuilder: (context, index) {
          final userPubkey = followers[index];
          // Use MyFollowingBloc to check if current user follows this follower
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
