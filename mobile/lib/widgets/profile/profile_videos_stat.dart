// ABOUTME: Videos stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/my_videos_count/my_videos_count_bloc.dart';
import 'package:openvine/blocs/others_videos_count/others_videos_count_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the appropriate videos count BLoC based on pubkey.
///
/// Follows the same pattern as [ProfileFollowersStat].
/// For current user: creates [MyVideosCountBloc] with real-time subscription.
/// For other users: creates [OthersVideosCountBloc] with one-time fetch.
class ProfileVideosStat extends ConsumerWidget {
  const ProfileVideosStat({required this.pubkey, super.key});

  /// The public key of the profile user whose video count to display.
  final String pubkey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videosRepository = ref.watch(videosRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return BlocProvider(
        create: (_) =>
            MyVideosCountBloc(videosRepository: videosRepository)
              ..add(const MyVideosCountStarted()),
        child: const _MyVideosStatView(),
      );
    } else {
      return BlocProvider(
        create: (_) =>
            OthersVideosCountBloc(videosRepository: videosRepository)
              ..add(OthersVideosCountLoadRequested(pubkey)),
        child: const _OthersVideosStatView(),
      );
    }
  }
}

/// View widget for current user's videos stat.
class _MyVideosStatView extends StatelessWidget {
  const _MyVideosStatView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyVideosCountBloc, MyVideosCountState>(
      builder: (context, state) {
        final isLoading =
            state.status == MyVideosCountStatus.initial ||
            state.status == MyVideosCountStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.count,
          label: 'Videos',
          isLoading: isLoading,
          onTap: null, // Videos aren't tappable
        );
      },
    );
  }
}

/// View widget for other user's videos stat.
class _OthersVideosStatView extends StatelessWidget {
  const _OthersVideosStatView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<OthersVideosCountBloc, OthersVideosCountState>(
      builder: (context, state) {
        final isLoading =
            state.status == OthersVideosCountStatus.initial ||
            state.status == OthersVideosCountStatus.loading;

        return ProfileStatColumn(
          count: isLoading ? null : state.count,
          label: 'Videos',
          isLoading: isLoading,
          onTap: null, // Videos aren't tappable
        );
      },
    );
  }
}
