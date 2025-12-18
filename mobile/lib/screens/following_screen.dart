// ABOUTME: Screen displaying list of users followed by the profile being viewed
// ABOUTME: Shows user profiles with follow/unfollow buttons and navigation to their profiles

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/following_list_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

class FollowingScreen extends ConsumerWidget {
  const FollowingScreen({
    super.key,
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followingAsync = ref.watch(followingListProvider(pubkey));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        foregroundColor: VineTheme.whiteText,
        title: Text(
          "$displayName's Following",
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      body: followingAsync.when(
        data: (following) =>
            _FollowingListBody(following: following, pubkey: pubkey),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => _FollowingErrorBody(pubkey: pubkey),
      ),
    );
  }
}

class _FollowingListBody extends ConsumerWidget {
  const _FollowingListBody({required this.following, required this.pubkey});

  final List<String> following;
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (following.isEmpty) {
      return const _FollowingEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(followingListProvider(pubkey));
      },
      child: ListView.builder(
        itemCount: following.length,
        itemBuilder: (context, index) {
          final userPubkey = following[index];
          return UserProfileTile(
            pubkey: userPubkey,
            onTap: () => context.goProfile(userPubkey, 0),
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

class _FollowingErrorBody extends ConsumerWidget {
  const _FollowingErrorBody({required this.pubkey});

  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              ref.invalidate(followingListProvider(pubkey));
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
}
