// ABOUTME: Following stat column widget using BLoC for reactive updates.
// ABOUTME: Uses Page/View pattern - Page creates BLoC, View consumes it.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_following/others_following_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/widgets/profile/profile_stats_row_widget.dart';

/// Page widget that creates the appropriate following BLoC based on pubkey.
class ProfileFollowingStat extends ConsumerWidget {
  const ProfileFollowingStat({
    required this.pubkey,
    required this.displayName,
    this.initialCount,
    this.isLoading = false,
    super.key,
  });

  /// The public key of the profile user whose following count to display.
  final String pubkey;

  /// The display name of the user for the following screen title.
  final String? displayName;

  /// Initial count from profile data, shown while the BLoC loads.
  final int? initialCount;

  /// Whether the parent stats row is still showing its skeleton placeholder.
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final followRepository = ref.watch(followRepositoryProvider);
    final nostrClient = ref.watch(nostrServiceProvider);
    final blocklistRepository = ref.watch(contentBlocklistRepositoryProvider);
    final isCurrentUser = pubkey == nostrClient.publicKey;

    if (isCurrentUser) {
      return BlocProvider(
        key: ValueKey((followRepository, blocklistRepository)),
        create: (_) => MyFollowingBloc(
          followRepository: followRepository,
          contentBlocklistRepository: blocklistRepository,
        )..add(const MyFollowingListLoadRequested()),
        child: _MyFollowingStatView(
          pubkey: pubkey,
          displayName: displayName,
          initialCount: initialCount,
          isLoading: isLoading,
        ),
      );
    } else {
      return BlocProvider(
        key: ValueKey((followRepository, blocklistRepository, nostrClient)),
        create: (_) => OthersFollowingBloc(
          followRepository: followRepository,
          contentBlocklistRepository: blocklistRepository,
          currentUserPubkey: nostrClient.publicKey,
        )..add(OthersFollowingListLoadRequested(pubkey)),
        child: _OthersFollowingStatView(
          pubkey: pubkey,
          displayName: displayName,
          initialCount: initialCount,
          isLoading: isLoading,
        ),
      );
    }
  }
}

/// View widget for current user's following stat.
class _MyFollowingStatView extends ConsumerWidget {
  const _MyFollowingStatView({
    required this.pubkey,
    required this.displayName,
    this.initialCount,
    this.isLoading = false,
  });

  final String pubkey;
  final String? displayName;
  final int? initialCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<MyFollowingBloc>().add(const MyFollowingBlocklistChanged());
    });

    return BlocBuilder<MyFollowingBloc, MyFollowingState>(
      builder: (context, state) {
        // MyFollowingBloc starts with success status (cached data)
        final isBlocLoading = state.status == MyFollowingStatus.initial;

        return ProfileStatColumn(
          count: isBlocLoading ? initialCount : state.displayFollowingCount,
          label: context.l10n.profileFollowingStatLabel,
          isLoading: isBlocLoading && (isLoading || initialCount == null),
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(pubkey),
            extra: displayName,
          ),
        );
      },
    );
  }
}

/// View widget for other user's following stat.
class _OthersFollowingStatView extends ConsumerWidget {
  const _OthersFollowingStatView({
    required this.pubkey,
    required this.displayName,
    this.initialCount,
    this.isLoading = false,
  });

  final String pubkey;
  final String? displayName;
  final int? initialCount;
  final bool isLoading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.listen(blocklistVersionProvider, (_, _) {
      context.read<OthersFollowingBloc>().add(
        const OthersFollowingBlocklistChanged(),
      );
    });

    return BlocBuilder<OthersFollowingBloc, OthersFollowingState>(
      builder: (context, state) {
        final isBlocLoading = state.status == OthersFollowingStatus.initial;

        return ProfileStatColumn(
          count: isBlocLoading ? initialCount : state.displayFollowingCount,
          label: context.l10n.profileFollowingStatLabel,
          isLoading: isBlocLoading && (isLoading || initialCount == null),
          onTap: () => context.push(
            FollowingScreenRouter.pathForPubkey(pubkey),
            extra: displayName,
          ),
        );
      },
    );
  }
}
