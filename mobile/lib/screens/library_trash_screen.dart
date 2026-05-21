// ABOUTME: Trash bin screen for soft-deleted clips with restore + purge actions
// ABOUTME: Loads trashed clips on entry and lets the user restore or delete now.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/clips_library/clips_library_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';

/// Screen showing clips that have been soft-deleted and are awaiting
/// 30-day auto-purge. The user can [Restore] a clip back to the
/// library or [Delete now] to skip the retention window.
class LibraryTrashScreen extends StatefulWidget {
  const LibraryTrashScreen({super.key});

  @override
  State<LibraryTrashScreen> createState() => _LibraryTrashScreenState();
}

class _LibraryTrashScreenState extends State<LibraryTrashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<ClipsLibraryBloc>().add(
        const ClipsLibraryTrashLoadRequested(),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VineTheme.surfaceBackground,
      appBar: DiVineAppBar(
        title: context.l10n.libraryTrashTitle,
        backgroundColor: VineTheme.surfaceBackground,
        surfaceTintColor: VineTheme.transparent,
        shape: const Border(
          bottom: BorderSide(color: VineTheme.outlineDisabled),
        ),
        showBackButton: true,
        onBackPressed: () => Navigator.of(context).maybePop(),
        customActions: const [_EmptyTrashAction()],
      ),
      body: SafeArea(
        child: BlocBuilder<ClipsLibraryBloc, ClipsLibraryState>(
          buildWhen: (prev, curr) =>
              prev.trashedClips != curr.trashedClips ||
              prev.status != curr.status,
          builder: (context, state) {
            if (state.status == ClipsLibraryStatus.trashLoading &&
                state.trashedClips.isEmpty) {
              return const Center(child: BrandedLoadingIndicator(size: 60));
            }
            if (state.trashedClips.isEmpty) {
              return EmptyLibraryState(
                icon: DivineIconName.trash,
                title: context.l10n.libraryTrashEmptyTitle,
                subtitle: context.l10n.libraryTrashEmptySubtitle,
                showRecordButton: false,
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: state.trashedClips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) =>
                  _TrashedClipTile(clip: state.trashedClips[index]),
            );
          },
        ),
      ),
    );
  }
}

class _EmptyTrashAction extends StatelessWidget {
  const _EmptyTrashAction();

  @override
  Widget build(BuildContext context) {
    return BlocSelector<ClipsLibraryBloc, ClipsLibraryState, int>(
      selector: (state) => state.trashedClips.length,
      builder: (context, trashedCount) {
        final hasTrashed = trashedCount > 0;
        if (!hasTrashed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Center(
            child: DivineButton(
              size: DivineButtonSize.small,
              type: DivineButtonType.secondary,
              label: context.l10n.libraryTrashEmptyAllLabel,
              onPressed: () =>
                  _confirmEmptyTrash(context, trashedCount: trashedCount),
            ),
          ),
        );
      },
    );
  }

  Future<void> _confirmEmptyTrash(
    BuildContext context, {
    required int trashedCount,
  }) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryTrashEmptyConfirmTitle,
      subtitle: context.l10n.libraryTrashEmptyConfirmMessage(trashedCount),
      additionalText: context.l10n.libraryDeleteClipsWarning,
      primaryButtonText: context.l10n.libraryDeleteConfirm,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true || !context.mounted) return;
    context.read<ClipsLibraryBloc>().add(const ClipsLibraryEmptyTrash());
  }
}

class _TrashedClipTile extends StatelessWidget {
  const _TrashedClipTile({required this.clip});

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: VineTheme.surfaceContainerHigh,
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          spacing: 12,
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                child: VideoClipThumbnailCard(
                  clip: clip,
                  showSelectionIndicator: false,
                ),
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  Text(
                    '${clip.duration.inSeconds}s',
                    style: VineTheme.titleSmallFont(),
                  ),
                  Text(
                    context.l10n.libraryTrashAutoDeletes(_daysUntilPurge(clip)),
                    style: VineTheme.bodyMediumFont(
                      color: VineTheme.secondaryText,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                DivineButton(
                  size: DivineButtonSize.small,
                  type: DivineButtonType.secondary,
                  label: context.l10n.libraryTrashRestoreLabel,
                  onPressed: () => context.read<ClipsLibraryBloc>().add(
                    ClipsLibraryRestoreClips({clip.id}),
                  ),
                ),
                DivineButton(
                  size: DivineButtonSize.small,
                  type: DivineButtonType.error,
                  label: context.l10n.libraryTrashDeleteNowLabel,
                  onPressed: () => _confirmHardDelete(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Whole days remaining until the 30-day purge sweep hard-deletes
  /// [clip]. Returns 0 for clips already past the cutoff (the next purge
  /// run will catch them). Trashed rows are expected to carry `deletedAt`;
  /// debug builds assert that invariant and release builds degrade to 0.
  int _daysUntilPurge(DivineVideoClip clip) {
    final deletedAt = clip.deletedAt;
    assert(deletedAt != null, 'Trashed clip must have deletedAt');
    if (deletedAt == null) return 0;
    final cutoff = deletedAt.add(ClipLibraryService.trashRetention);
    final remaining = cutoff.difference(DateTime.now());
    if (remaining <= Duration.zero) return 0;
    return (remaining.inSeconds / Duration.secondsPerDay).ceil();
  }

  Future<void> _confirmHardDelete(BuildContext context) async {
    final confirmed = await VineBottomSheetPrompt.show<bool>(
      context: context,
      sticker: .alert,
      title: context.l10n.libraryTrashDeleteConfirmTitle,
      subtitle: context.l10n.libraryTrashDeleteConfirmMessage,
      additionalText: context.l10n.libraryDeleteClipsWarning,
      primaryButtonText: context.l10n.libraryDeleteConfirm,
      secondaryButtonText: context.l10n.commonCancel,
      onPrimaryPressed: () => Navigator.of(context).pop(true),
      onSecondaryPressed: () => Navigator.of(context).pop(false),
    );

    if (confirmed != true || !context.mounted) return;
    context.read<ClipsLibraryBloc>().add(ClipsLibraryHardDeleteClip(clip));
  }
}
