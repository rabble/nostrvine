// ABOUTME: Followers stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/followers/followers_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/followers_screen.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the [FollowersBloc] and provides it to the view.
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

    return BlocProvider(
      create: (_) => FollowersBloc(
        followRepository: followRepository,
        nostrClient: nostrClient,
      )..add(FollowersListLoadRequested(pubkey)),
      child: ProfileFollowersStatView(pubkey: pubkey, displayName: displayName),
    );
  }
}

/// View widget that consumes [FollowersBloc] state and renders the stat column.
class ProfileFollowersStatView extends StatelessWidget {
  const ProfileFollowersStatView({
    required this.pubkey,
    required this.displayName,
    super.key,
  });

  final String pubkey;
  final String? displayName;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<FollowersBloc, FollowersState>(
      builder: (context, state) {
        final isLoading =
            state.status == FollowersStatus.initial ||
            state.status == FollowersStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.followersPubkeys.length,
          label: 'Followers',
          isLoading: isLoading,
          onTap: () => _navigateToFollowers(context),
        );
      },
    );
  }

  void _navigateToFollowers(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (context) =>
            FollowersScreen(pubkey: pubkey, displayName: displayName),
      ),
    );
  }
}
