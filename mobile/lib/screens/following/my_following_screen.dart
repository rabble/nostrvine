// ABOUTME: Screen displaying current user's following list
// ABOUTME: Uses MyFollowingBloc for reactive updates via repository

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/features/people_lists/models/people_list_entry_point.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget for displaying current user's following list.
///
/// Creates [MyFollowingBloc] and provides it to the view.
class MyFollowingScreen extends ConsumerWidget {
  const MyFollowingScreen({required this.displayName, super.key});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);

    return BlocProvider(
      create: (_) => MyFollowingBloc(
        followRepository: followRepository,
        contentBlocklistRepository: blocklistRepository,
      )..add(const MyFollowingListLoadRequested()),
      child: _MyFollowingView(displayName: displayName),
    );
  }
}

class _MyFollowingView extends ConsumerWidget {
  const _MyFollowingView({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<MyFollowingBloc>().add(const MyFollowingBlocklistChanged());
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? context.l10n.followingTitleForName(displayName!)
        : context.l10n.followingTitle;

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        titleWidget: FollowerCountTitle<MyFollowingBloc, MyFollowingState>(
          title: appBarTitle,
          selector: (state) => state.status == MyFollowingStatus.success
              ? state.followingPubkeys.length
              : 0,
        ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: BlocConsumer<MyFollowingBloc, MyFollowingState>(
        listenWhen: (previous, current) =>
            (current.status == MyFollowingStatus.success &&
                previous.status != MyFollowingStatus.success) ||
            (current.status == MyFollowingStatus.toggleFailure &&
                previous.status != MyFollowingStatus.toggleFailure),
        listener: (context, state) {
          if (state.status == MyFollowingStatus.success) {
            ScreenAnalyticsService().markDataLoaded(
              'following',
              dataMetrics: {'following_count': state.followingPubkeys.length},
            );
          }
          if (state.status == MyFollowingStatus.toggleFailure) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(context.l10n.followersUpdateFollowFailed),
              ),
            );
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            MyFollowingStatus.initial => const Center(
              child: CircularProgressIndicator(),
            ),
            MyFollowingStatus.toggleFailure => _FollowingListBody(
              following: state.followingPubkeys,
            ),
            MyFollowingStatus.success => _FollowingListBody(
              following: state.followingPubkeys,
            ),
            MyFollowingStatus.failure => _FollowingErrorBody(
              onRetry: () {
                context.read<MyFollowingBloc>().add(
                  const MyFollowingListLoadRequested(),
                );
              },
            ),
          };
        },
      ),
    );
  }
}

class _FollowingListBody extends StatelessWidget {
  const _FollowingListBody({required this.following});

  final List<String> following;

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return const _FollowingEmptyState();
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<MyFollowingBloc>().add(
          const MyFollowingListLoadRequested(),
        );
      },
      child: ListView.builder(
        itemCount: following.length,
        itemBuilder: (context, index) {
          final userPubkey = following[index];
          return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
            selector: (state) => state.isFollowing(userPubkey),
            builder: (context, isFollowing) {
              return UserProfileTile(
                pubkey: userPubkey,
                onTap: () => context.pushOtherProfile(userPubkey),
                isFollowing: isFollowing,
                index: index,
                addToListEntryPoint: PeopleListEntryPoint.followingList,
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

class _FollowingEmptyState extends StatelessWidget {
  const _FollowingEmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.person_add_outlined,
            size: 64,
            color: VineTheme.lightText,
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.followingEmptyTitle,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }
}

class _FollowingErrorBody extends StatelessWidget {
  const _FollowingErrorBody({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          Text(
            context.l10n.followingFailedToLoadList,
            style: const TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: Text(context.l10n.commonRetry)),
        ],
      ),
    );
  }
}
