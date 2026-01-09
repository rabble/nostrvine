// ABOUTME: Followers stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/my_followers/my_followers_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the appropriate followers BLoC based on pubkey.
class ProfileFollowersStat extends ConsumerWidget {
  const ProfileFollowersStat({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  /// The public key of the profile user whose followers count to display.
  final String pubkey;

  /// The display name of the user for the followers screen title.
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return BlocProvider(
        create: (_) =>
            MyFollowersBloc(followRepository: followRepository)
              ..add(const MyFollowersListLoadRequested()),
        child: _MyFollowersStatView(pubkey: pubkey, displayName: displayName),
      );
    } else {
      // Use the OthersFollowersBloc from parent context (provided by ProfileGridView)
      // This allows the follow button to update the count optimistically
      return _OthersFollowersStatView(pubkey: pubkey, displayName: displayName);
    }
  }
}

/// View widget for current user's followers stat.
class _MyFollowersStatView extends StatelessWidget {
  const _MyFollowersStatView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyFollowersBloc, MyFollowersState>(
      builder: (context, state) {
        final isLoading =
            state.status == MyFollowersStatus.initial ||
            state.status == MyFollowersStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.followersPubkeys.length,
          label: 'Followers',
          isLoading: isLoading,
          onTap: () => context.push('/followers/$pubkey', extra: displayName),
        );
      },
    );
  }
}

/// View widget for other user's followers stat.
class _OthersFollowersStatView extends StatelessWidget {
  const _OthersFollowersStatView({
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OthersFollowersBloc, OthersFollowersState>(
      builder: (context, state) {
        final isLoading =
            state.status == OthersFollowersStatus.initial ||
            state.status == OthersFollowersStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.followersPubkeys.length,
          label: 'Followers',
          isLoading: isLoading,
          onTap: () => context.push('/followers/$pubkey', extra: displayName),
        );
      },
    );
  }
}
