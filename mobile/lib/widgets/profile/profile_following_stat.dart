// ABOUTME: Following stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the [FollowingBloc] and provides it to the view.
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

    return BlocProvider(
      create: (_) => FollowingBloc(
        followRepository: followRepository,
        nostrClient: nostrClient,
        targetPubkey: pubkey,
      )..add(const FollowingListLoadRequested()),
      child: ProfileFollowingStatView(pubkey: pubkey, displayName: displayName),
    );
  }
}

/// View widget that consumes [FollowingBloc] state and renders the stat column.
class ProfileFollowingStatView extends StatelessWidget {
  const ProfileFollowingStatView({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowingBloc, FollowingState>(
      builder: (context, state) {
        final isLoading =
            state.status == FollowingStatus.initial ||
            state.status == FollowingStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.followingPubkeys.length,
          label: 'Following',
          isLoading: isLoading,
          onTap: () => _navigateToFollowing(context),
        );
      },
    );
  }

  void _navigateToFollowing(BuildContext context) {
    context.push('/following/$pubkey', extra: displayName);
  }
}
