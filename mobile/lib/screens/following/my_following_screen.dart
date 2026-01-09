// ABOUTME: Screen displaying current user's following list
// ABOUTME: Uses MyFollowingBloc for reactive updates via repository

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
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
      body: BlocBuilder<MyFollowingBloc, MyFollowingState>(
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
      onRefresh: () async {
        context.read<MyFollowingBloc>().add(
          const MyFollowingListLoadRequested(),
        );
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: following.length,
        itemBuilder: (context, index) {
          final userPubkey = following[index];
          return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
            selector: (state) => state.isFollowing(userPubkey),
            builder: (context, isFollowing) {
              return UserProfileTile(
                pubkey: userPubkey,
                onTap: () => context.goProfile(userPubkey, 0),
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
