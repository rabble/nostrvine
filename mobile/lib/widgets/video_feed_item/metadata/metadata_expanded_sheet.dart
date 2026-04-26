// ABOUTME: Expanded video metadata bottom sheet opened by the more button.
// ABOUTME: Shows title, stats, creator, tags, collaborators, inspired by,
// ABOUTME: reposted by, and sounds sections. Read-only, no new BLoC needed.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/clickable_hashtag_text.dart';
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
/// Uses [showVideoPausingVineBottomSheet] with `showHeader: false` so the
/// title scrolls with the content rather than being pinned in a header bar.
///
/// All data is read-only from [VideoEvent] and the existing
/// [VideoInteractionsBloc] in the widget tree — no new BLoC is created.
///
/// Matches Figma node `12345:71362` ("metadata-expanded").
class MetadataExpandedSheet extends StatelessWidget {
  @visibleForTesting
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
      showHeader: false,
      initialChildSize: 0.7,
      buildScrollBody: (scrollController) => MultiBlocProvider(
        providers: [
          BlocProvider<VideoInteractionsBloc>.value(value: interactionsBloc),
          BlocProvider<VideoRepostersCubit>(
            create: (_) => VideoRepostersCubit(
              videoEventService: videoEventService,
              videoId: video.id,
            ),
          ),
        ],
        child: _MetadataContent(
          video: video,
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _MetadataContent(video: video);
  }
}

/// Scrollable content for the metadata sheet.
///
/// When used inside [MetadataExpandedSheet.show], receives a
/// [scrollController] from [VineBottomSheet]'s [DraggableScrollableSheet].
/// When used directly in tests, scrolls freely without a controller.
class _MetadataContent extends StatelessWidget {
  const _MetadataContent({required this.video, this.scrollController});

  final VideoEvent video;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) {
    return ListView(
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
        const _CaptionsSettingSection(),
      ],
    );
  }
}

/// Global captions preference row for the metadata sheet.
class _CaptionsSettingSection extends ConsumerWidget {
  const _CaptionsSettingSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final captionsEnabled = ref.watch(subtitleVisibilityProvider);
    final l10n = context.l10n;

    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: VineTheme.outlineDisabled)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Align(
          alignment: Alignment.centerRight,
          child: Semantics(
            button: true,
            toggled: captionsEnabled,
            label: captionsEnabled
                ? l10n.metadataCaptionsEnabledSemantics
                : l10n.metadataCaptionsDisabledSemantics,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.metadataCaptionsLabel,
                  style: VineTheme.titleSmallFont(),
                ),
                const SizedBox(width: 8),
                Switch(
                  value: captionsEnabled,
                  activeThumbColor: VineTheme.whiteText,
                  activeTrackColor: VineTheme.vineGreen,
                  inactiveThumbColor: VineTheme.whiteText,
                  inactiveTrackColor: VineTheme.surfaceContainer,
                  onChanged: (value) {
                    ref
                        .read(subtitleVisibilityProvider.notifier)
                        .setEnabled(value);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
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
        border: Border(bottom: BorderSide(color: VineTheme.outlineDisabled)),
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
              ClickableHashtagText(
                text: description,
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
