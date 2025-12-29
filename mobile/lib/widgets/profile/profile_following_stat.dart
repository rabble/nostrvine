// ABOUTME: Following stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the appropriate following BLoC based on pubkey.
class ProfileFollowingStat extends ConsumerWidget {
  const ProfileFollowingStat({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  /// The public key of the profile user whose following count to display.
  final String pubkey;

  /// The display name of the user for the following screen title.
  final String? displayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return BlocProvider(
        create: (_) =>
            MyFollowingBloc(followRepository: followRepository)
              ..add(const MyFollowingListLoadRequested()),
        child: _MyFollowingStatView(pubkey: pubkey, displayName: displayName),
      );
    } else {
      return BlocProvider(
        create: (_) =>
            OthersFollowingBloc(nostrClient: nostrClient)
              ..add(OthersFollowingListLoadRequested(pubkey)),
        child: _OthersFollowingStatView(
          pubkey: pubkey,
          displayName: displayName,
        ),
      );
    }
  }
}

/// View widget for current user's following stat.
class _MyFollowingStatView extends StatelessWidget {
  const _MyFollowingStatView({required this.pubkey, required this.displayName});

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyFollowingBloc, MyFollowingState>(
      builder: (context, state) {
        // MyFollowingBloc starts with success status (cached data)
        final isLoading = state.status == MyFollowingStatus.initial;

        return ProfileStatColumn(
          count: isLoading ? null : state.followingPubkeys.length,
          label: 'Following',
          isLoading: isLoading,
          onTap: () => context.push('/following/$pubkey', extra: displayName),
        );
      },
    );
  }
}

/// View widget for other user's following stat.
class _OthersFollowingStatView extends StatelessWidget {
  const _OthersFollowingStatView({
    required this.pubkey,
    required this.displayName,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OthersFollowingBloc, OthersFollowingState>(
      builder: (context, state) {
        final isLoading =
            state.status == OthersFollowingStatus.initial ||
            state.status == OthersFollowingStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.followingPubkeys.length,
          label: 'Following',
          isLoading: isLoading,
          onTap: () => context.push('/following/$pubkey', extra: displayName),
        );
      },
    );
  }
}
