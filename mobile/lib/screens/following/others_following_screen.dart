// ABOUTME: Screen displaying another user's following list
// ABOUTME: Uses OthersFollowingBloc for list + MyFollowingBloc for follow button state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/profile/follower_count_title.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

const _toggleFollowErrorMessage =
    'Failed to update follow status. Please try again.';

/// Page widget for displaying another user's following list.
///
/// Creates both [OthersFollowingBloc] (for the list) and [MyFollowingBloc]
/// (for follow button state) and provides them to the view.
class OthersFollowingScreen extends ConsumerWidget {
  const OthersFollowingScreen({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final blocklistService = ref.watch(contentBlocklistServiceProvider);

    // Show loading until NostrClient has keys
    if (followRepository == null) {
      return const BrandedLoadingScaffold();
    }

    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => OthersFollowingBloc(
            nostrClient: nostrClient,
            contentBlocklistService: blocklistService,
            currentUserPubkey: nostrClient.publicKey,
          )..add(OthersFollowingListLoadRequested(pubkey)),
        ),
        BlocProvider(
          create: (_) => MyFollowingBloc(
            followRepository: followRepository,
            contentBlocklistService: blocklistService,
          )..add(const MyFollowingListLoadRequested()),
        ),
      ],
      child: _OthersFollowingView(pubkey: pubkey, displayName: displayName),
    );
  }
}

class _OthersFollowingView extends ConsumerWidget {
  const _OthersFollowingView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<OthersFollowingBloc>().add(
        const OthersFollowingBlocklistChanged(),
      );
    });

    final appBarTitle = displayName?.isNotEmpty == true
        ? "$displayName's Following"
        : 'Following';

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        titleWidget:
            FollowerCountTitle<OthersFollowingBloc, OthersFollowingState>(
              title: appBarTitle,
              selector: (state) => state.status == OthersFollowingStatus.success
                  ? state.followingPubkeys.length
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
        child: BlocBuilder<OthersFollowingBloc, OthersFollowingState>(
          builder: (context, state) {
            return switch (state.status) {
              OthersFollowingStatus.initial || OthersFollowingStatus.loading =>
                const Center(child: CircularProgressIndicator()),
              OthersFollowingStatus.success => _FollowingListBody(
                following: state.followingPubkeys,
                targetPubkey: pubkey,
              ),
              OthersFollowingStatus.failure => _FollowingErrorBody(
                onRetry: () {
                  final targetPubkey = context
                      .read<OthersFollowingBloc>()
                      .state
                      .targetPubkey;
                  if (targetPubkey != null) {
                    context.read<OthersFollowingBloc>().add(
                      OthersFollowingListLoadRequested(targetPubkey),
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

class _FollowingListBody extends StatelessWidget {
  const _FollowingListBody({
    required this.following,
    required this.targetPubkey,
  });

  final List<String> following;
  final String targetPubkey;

  @override
  Widget build(BuildContext context) {
    if (following.isEmpty) {
      return const _FollowingEmptyState();
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<OthersFollowingBloc>().add(
          OthersFollowingListLoadRequested(targetPubkey),
        );
      },
      child: ListView.builder(
        itemCount: following.length,
        itemBuilder: (context, index) {
          final userPubkey = following[index];
          // Use MyFollowingBloc to check if current user follows this person
          return BlocSelector<MyFollowingBloc, MyFollowingState, bool>(
            selector: (state) => state.isFollowing(userPubkey),
            builder: (context, isFollowing) {
              return UserProfileTile(
                pubkey: userPubkey,
                onTap: () => context.pushOtherProfile(userPubkey),
                isFollowing: isFollowing,
                index: index,
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
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.person_add_outlined,
            size: 64,
            color: VineTheme.lightText,
          ),
          SizedBox(height: 16),
          Text(
            'Not following anyone yet',
            style: TextStyle(
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
          const Icon(
            Icons.error_outline,
            size: 64,
            color: VineTheme.lightText,
          ),
          const SizedBox(height: 16),
          const Text(
            'Failed to load following list',
            style: TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 8),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
