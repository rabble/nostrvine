// ABOUTME: Screen displaying current user's following list
// ABOUTME: Uses MyFollowingBloc for reactive updates via repository

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:openvine/services/screen_analytics_service.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget for displaying current user's following list.
///
/// Creates [MyFollowingBloc] and provides it to the view.
class MyFollowingScreen extends ConsumerWidget {
  const MyFollowingScreen({super.key, required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);

    // Show loading until NostrClient has keys
    if (followRepository == null) {
      return const BrandedLoadingScaffold();
    }

    return BlocProvider(
      create: (_) =>
          MyFollowingBloc(followRepository: followRepository)
            ..add(const MyFollowingListLoadRequested()),
      child: _MyFollowingView(displayName: displayName),
    );
  }
}

class _MyFollowingView extends StatelessWidget {
  const _MyFollowingView({required this.displayName});

  final String? displayName;

  @override
  Widget build(BuildContext context) {
    final appBarTitle = displayName?.isNotEmpty == true
        ? "$displayName's Following"
        : 'Following';

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: 72,
        leadingWidth: 80,
        centerTitle: false,
        titleSpacing: 0,
        backgroundColor: VineTheme.navGreen,
        leading: IconButton(
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(),
          icon: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: VineTheme.iconButtonBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: SvgPicture.asset(
              'assets/icon/CaretLeft.svg',
              width: 32,
              height: 32,
              colorFilter: const ColorFilter.mode(
                Colors.white,
                BlendMode.srcIn,
              ),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(),
          tooltip: 'Back',
        ),
        title: FollowerCountTitle<MyFollowingBloc, MyFollowingState>(
          title: appBarTitle,
          selector: (state) => state.status == MyFollowingStatus.success
              ? state.followingPubkeys.length
              : 0,
        ),
      ),
      body: BlocConsumer<MyFollowingBloc, MyFollowingState>(
        listener: (context, state) {
          if (state.status == MyFollowingStatus.success) {
            ScreenAnalyticsService().markDataLoaded(
              'following',
              dataMetrics: {'following_count': state.followingPubkeys.length},
            );
          }
        },
        builder: (context, state) {
          return switch (state.status) {
            MyFollowingStatus.initial => const Center(
              child: CircularProgressIndicator(),
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
  const _FollowingErrorBody({required this.onRetry});

  final VoidCallback onRetry;

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
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
