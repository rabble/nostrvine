// ABOUTME: Expanded video metadata bottom sheet opened by the more button.
// ABOUTME: Shows title, stats, creator, tags, collaborators, inspired by,
// ABOUTME: reposted by, and sounds sections. Read-only, no new BLoC needed.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_badges_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_sounds_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_stats_row.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_tags_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_user_chips.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_verification_section.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_reposters_cubit.dart';

/// Expanded metadata bottom sheet for a video.
///
/// Opened by the three-dot "more" button on the video overlay action column.
/// Uses [showVideoPausingVineBottomSheet] so video playback pauses while open.
///
/// All data is read-only from [VideoEvent] and the existing
/// [VideoInteractionsBloc] in the widget tree — no new BLoC is created.
///
/// Matches Figma node `12345:71362` ("metadata-expanded").
class MetadataExpandedSheet extends StatelessWidget {
  const MetadataExpandedSheet({required this.video, super.key});

  final VideoEvent video;

  /// Opens the metadata sheet for the given [video].
  ///
  /// Captures the [VideoInteractionsBloc] from the caller's [context] and
  /// re-provides it inside the modal, since [showModalBottomSheet] creates
  /// a separate widget tree without access to the video feed's providers.
  ///
  /// Creates a [VideoRepostersCubit] to fetch reposter pubkeys from the
  /// relay. The cubit is scoped to the modal and auto-closed on dismiss.
  static void show(BuildContext context, VideoEvent video) {
    final interactionsBloc = context.read<VideoInteractionsBloc>();
    final container = ProviderScope.containerOf(context, listen: false);
    final videoEventService = container.read(videoEventServiceProvider);

    context.showVideoPausingVineBottomSheet<void>(
      builder: (context) => MultiBlocProvider(
        providers: [
          BlocProvider<VideoInteractionsBloc>.value(
            value: interactionsBloc,
          ),
          BlocProvider<VideoRepostersCubit>(
            create: (_) => VideoRepostersCubit(
              videoEventService: videoEventService,
              videoId: video.id,
            ),
          ),
        ],
        child: MetadataExpandedSheet(video: video),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: VineTheme.surfaceBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            children: [
              const _DragHandle(),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    bottom: MediaQuery.paddingOf(context).bottom + 16,
                  ),
                  children: [
                    _TitleSection(video: video),
                    MetadataBadgesRow(video: video),
                    MetadataStatsRow(video: video),
                    MetadataVerificationSection(video: video),
                    MetadataCreatorSection(pubkey: video.pubkey),
                    MetadataTagsSection(video: video),
                    MetadataCollaboratorsSection(
                      collaboratorPubkeys: video.collaboratorPubkeys,
                    ),
                    MetadataInspiredBySection(video: video),
                    MetadataRepostedBySection(video: video),
                    MetadataSoundsSection(video: video),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Drag handle indicator at the top of the sheet.
///
/// Wraps the shared [VineBottomSheetDragHandle] with the padding specified
/// in the Figma spec (8px top, 20px bottom).
class _DragHandle extends StatelessWidget {
  const _DragHandle();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 8, bottom: 20),
      child: Center(child: VineBottomSheetDragHandle()),
    );
  }
}

/// Title and description section at the top of the sheet.
class _TitleSection extends StatelessWidget {
  const _TitleSection({required this.video});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final title = video.title;
    final description = video.content;
    final hasContent =
        (title != null && title.isNotEmpty) || description.isNotEmpty;

    if (!hasContent) return const SizedBox.shrink();

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: VineTheme.outlineDisabled),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 8,
          children: [
            if (title != null && title.isNotEmpty)
              Text(title, style: VineTheme.titleMediumFont()),
            if (description.isNotEmpty)
              Text(
                description,
                style: VineTheme.bodyLargeFont(
                  color: VineTheme.onSurfaceVariant,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
