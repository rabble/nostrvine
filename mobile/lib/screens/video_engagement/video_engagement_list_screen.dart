// ABOUTME: Screen showing the list of users who liked or reposted a video.
// ABOUTME: Reached when the video owner taps the Like or Repost button on
// ABOUTME: their own video — replacing the toggle behavior with a list view.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_engagement/video_engagement_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/widgets/user_profile_tile.dart';

/// Page widget for the video engagement (likers / reposters) list.
class VideoEngagementListScreen extends ConsumerWidget {
  const VideoEngagementListScreen({
    required this.eventId,
    required this.type,
    super.key,
    this.addressableId,
  });

  /// Path under the video route. Concrete child paths are
  /// `likers` and `reposters`.
  static const path = ':eventId';
  static const likersSubPath = 'likers';
  static const repostersSubPath = 'reposters';

  /// Route name used for the likers list.
  static const likersRouteName = 'videoLikers';

  /// Route name used for the reposters list.
  static const repostersRouteName = 'videoReposters';

  /// Hex id of the target video event.
  final String eventId;

  /// Whether to render the likers list or the reposters list.
  final VideoEngagementType type;

  /// Optional `kind:pubkey:d-tag` for addressable video events. The list is
  /// merged across the `e` and `a` tags when this is provided.
  final String? addressableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.watch(likesRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);

    return BlocProvider<VideoEngagementBloc>(
      key: ValueKey((likesRepository, repostsRepository, eventId, type)),
      create: (_) => VideoEngagementBloc(
        eventId: eventId,
        type: type,
        likesRepository: likesRepository,
        repostsRepository: repostsRepository,
        addressableId: addressableId,
      )..add(const VideoEngagementLoadRequested()),
      child: const _VideoEngagementListView(),
    );
  }
}

class _VideoEngagementListView extends StatelessWidget {
  const _VideoEngagementListView();

  @override
  Widget build(BuildContext context) {
    final type = context.select(
      (VideoEngagementBloc bloc) => bloc.state.type,
    );
    final title = switch (type) {
      VideoEngagementType.likers => context.l10n.videoEngagementLikersTitle,
      VideoEngagementType.reposters =>
        context.l10n.videoEngagementRepostersTitle,
    };

    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        titleWidget: Text(title, style: VineTheme.titleMediumFont()),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).pop(),
        backButtonSemanticLabel: context.l10n.commonBack,
      ),
      body: BlocBuilder<VideoEngagementBloc, VideoEngagementState>(
        builder: (context, state) {
          return switch (state.status) {
            VideoEngagementStatus.initial ||
            VideoEngagementStatus.loading => const Center(
              child: CircularProgressIndicator(),
            ),
            VideoEngagementStatus.success when state.pubkeys.isEmpty =>
              _EngagementEmptyState(type: state.type),
            VideoEngagementStatus.success => _EngagementListBody(
              pubkeys: state.pubkeys,
            ),
            VideoEngagementStatus.failure => const _EngagementErrorBody(),
          };
        },
      ),
    );
  }
}

class _EngagementListBody extends StatelessWidget {
  const _EngagementListBody({required this.pubkeys});

  final List<String> pubkeys;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<VideoEngagementBloc>().add(
          const VideoEngagementLoadRequested(),
        );
      },
      child: ListView.builder(
        itemCount: pubkeys.length,
        itemBuilder: (context, index) {
          final pubkey = pubkeys[index];
          return UserProfileTile(
            pubkey: pubkey,
            onTap: () => context.pushOtherProfile(pubkey),
            showFollowButton: false,
            index: index,
          );
        },
      ),
    );
  }
}

class _EngagementEmptyState extends StatelessWidget {
  const _EngagementEmptyState({required this.type});

  final VideoEngagementType type;

  @override
  Widget build(BuildContext context) {
    final message = switch (type) {
      VideoEngagementType.likers => context.l10n.videoEngagementLikersEmpty,
      VideoEngagementType.reposters =>
        context.l10n.videoEngagementRepostersEmpty,
    };
    final icon = switch (type) {
      VideoEngagementType.likers => Icons.favorite_border,
      VideoEngagementType.reposters => Icons.repeat,
    };

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          Text(
            message,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
        ],
      ),
    );
  }
}

class _EngagementErrorBody extends StatelessWidget {
  const _EngagementErrorBody();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          Text(
            context.l10n.videoEngagementLoadFailed,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => context.read<VideoEngagementBloc>().add(
              const VideoEngagementLoadRequested(),
            ),
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
