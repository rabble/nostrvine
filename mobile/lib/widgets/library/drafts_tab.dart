// ABOUTME: Drafts tab widget for the clip library screen
// ABOUTME: Displays a list of saved video drafts with options to edit or delete

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';
import 'package:unified_logger/unified_logger.dart';

/// Tab widget displaying a list of saved drafts.
///
/// Uses [DraftsLibraryBloc] for state management and handles draft actions
/// (post, edit, delete) internally.
class DraftsTab extends ConsumerWidget {
  /// Creates a drafts tab.
  const DraftsTab({
    required this.showRecordButton,
    this.showAutosavedDraft = true,
    super.key,
  });

  final bool showRecordButton;

  /// Whether to include the autosaved draft in the list.
  final bool showAutosavedDraft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return BlocConsumer<DraftsLibraryBloc, DraftsLibraryState>(
      listenWhen: (previous, current) =>
          current is DraftsLibraryDraftDeleted ||
          current is DraftsLibraryDeleteFailed,
      listener: (context, state) {
        final isSuccess = state is DraftsLibraryDraftDeleted;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VineTheme.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label: isSuccess
                  ? context.l10n.libraryDraftDeletedSnackbar
                  : context.l10n.libraryDraftDeleteFailedSnackbar,
            ),
          ),
        );
      },
      builder: (context, state) {
        return switch (state) {
          DraftsLibraryInitial() || DraftsLibraryLoading() => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          DraftsLibraryError() => Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    context.l10n.libraryCouldNotLoadDrafts,
                    textAlign: TextAlign.center,
                    style: VineTheme.titleMediumFont(),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.libraryOpenErrorDescription,
                    textAlign: TextAlign.center,
                    style: VineTheme.bodyLargeFont(
                      color: VineTheme.secondaryText,
                    ),
                  ),
                  const SizedBox(height: 24),
                  DivineButton(
                    label: context.l10n.searchTryAgain,
                    type: DivineButtonType.secondary,
                    onPressed: () => context.read<DraftsLibraryBloc>().add(
                      const DraftsLibraryLoadRequested(),
                    ),
                  ),
                ],
              ),
            ),
          ),
          DraftsLibraryLoaded(:final drafts) ||
          DraftsLibraryDraftDeleted(:final drafts) ||
          DraftsLibraryDeleteFailed(:final drafts) => () {
            final filtered = showAutosavedDraft
                ? drafts
                : drafts
                      .where((d) => d.id != VideoEditorConstants.autoSaveId)
                      .toList();
            if (filtered.isEmpty) {
              return EmptyLibraryState(
                showRecordButton: showRecordButton,
                icon: DivineIconName.pencilSimple,
                title: context.l10n.libraryNoDraftsYetTitle,
                subtitle: context.l10n.libraryNoDraftsYetSubtitle,
              );
            }
            return ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                final draft = filtered[index];
                return DraftListTile(
                  draft: draft,
                  onTap: () => _openDraft(context, ref, draft),
                  onOpenMore: () => _openDraftOptions(context, ref, draft),
                );
              },
            );
          }(),
        };
      },
    );
  }

  Future<void> _openDraftOptions(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    await VineBottomSheetActionMenu.show(
      context: context,
      title: DraftListTile(draft: draft, enableShrink: true),
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.paperPlaneTilt.assetPath,
          label: context.l10n.libraryDraftActionPost,
          onTap: () => _postDraft(context, ref, draft),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.pencilSimple.assetPath,
          label: context.l10n.libraryDraftActionEdit,
          onTap: () => _openDraft(context, ref, draft),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.trash.assetPath,
          label: context.l10n.libraryDraftActionDelete,
          isDestructive: true,
          onTap: () => _deleteDraft(context, ref, draft),
        ),
      ],
    );
  }

  Future<void> _postDraft(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    Log.info(
      '📚 Post draft: ${draft.id}',
      name: 'DraftsTab',
      category: LogCategory.video,
    );
    await ref.read(videoPublishProvider.notifier).publishVideo(context, draft);

    // Reload drafts to reflect deletion (handled by publishVideo)
    if (context.mounted) {
      context.read<DraftsLibraryBloc>().add(const DraftsLibraryLoadRequested());
    }
  }

  Future<void> _openDraft(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    Log.info(
      '📚 Opening draft: ${draft.id}',
      name: 'DraftsTab',
      category: LogCategory.video,
    );

    await ref
        .read(videoPublishProvider.notifier)
        .clearAll(keepAutosavedDraft: true);

    if (!context.mounted) return;

    await context.push(
      '${VideoEditorScreen.path}/${draft.id}',
      extra: {'fromLibrary': true},
    );

    await ref
        .read(videoPublishProvider.notifier)
        .clearAll(keepAutosavedDraft: true);

    // Reload drafts after returning
    if (context.mounted) {
      context.read<DraftsLibraryBloc>().add(const DraftsLibraryLoadRequested());
    }
  }

  Future<void> _deleteDraft(
    BuildContext context,
    WidgetRef ref,
    DivineVideoDraft draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: Text(
          context.l10n.libraryDeleteDraftTitle,
          style: VineTheme.titleSmallFont(),
        ),
        content: Text(
          context.l10n.libraryDeleteDraftMessage(
            draft.title.isEmpty ? context.l10n.draftUntitled : draft.title,
          ),
          style: VineTheme.bodyMediumFont(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              context.l10n.commonCancel,
              style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.error,
              foregroundColor: VineTheme.whiteText,
            ),
            child: Text(context.l10n.commonDelete),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      Log.info(
        '📚 Deleting draft: ${draft.id}',
        name: 'DraftsTab',
        category: LogCategory.video,
      );
      context.read<DraftsLibraryBloc>().add(
        DraftsLibraryDeleteRequested(draft.id),
      );
      if (draft.id == VideoEditorConstants.autoSaveId) {
        unawaited(
          ref
              .read(videoPublishProvider.notifier)
              .clearAll(keepAutosavedDraft: true),
        );
      }
    }
  }
}

String _formatDraftSubtitle(BuildContext context, DateTime lastModified) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final date = DateFormat.yMMMEd(locale).format(lastModified);
  final time = MaterialLocalizations.of(context).formatTimeOfDay(
    TimeOfDay.fromDateTime(lastModified),
    alwaysUse24HourFormat: MediaQuery.of(context).alwaysUse24HourFormat,
  );
  return '$date $time';
}

/// List tile widget displaying a single draft.
class DraftListTile extends StatelessWidget {
  /// Creates a draft list tile.
  const DraftListTile({
    required this.draft,
    this.onTap,
    this.onOpenMore,
    this.enableShrink = false,
    super.key,
  });

  /// The draft to display.
  final DivineVideoDraft draft;

  /// Callback when the tile is tapped.
  final VoidCallback? onTap;

  /// Callback when more options button is tapped.
  final VoidCallback? onOpenMore;

  /// Whether to enable compact mode for bottom sheet usage.
  final bool enableShrink;

  @override
  Widget build(BuildContext context) {
    final thumbnailPath = draft.clips.firstOrNull?.thumbnailPath;
    final thumbnailExists =
        thumbnailPath != null && File(thumbnailPath).existsSync();

    return ListTile(
      onTap: onTap,
      minTileHeight: enableShrink ? null : 72,
      contentPadding: EdgeInsetsDirectional.fromSTEB(
        enableShrink ? 0 : 16,
        0,
        10,
        0,
      ),
      leading: Container(
        width: 40,
        height: 40,
        decoration: ShapeDecoration(
          image: thumbnailExists
              ? DecorationImage(
                  image: FileImage(File(thumbnailPath)),
                  fit: BoxFit.cover,
                )
              : null,
          color: thumbnailExists ? null : VineTheme.cardBackground,
          shape: RoundedRectangleBorder(
            side: const BorderSide(color: VineTheme.onSurfaceDisabled),
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: thumbnailExists
            ? null
            : const DivineIcon(
                icon: DivineIconName.filmSlate,
                color: VineTheme.secondaryText,
                size: 20,
              ),
      ),
      title: Text(
        draft.title.isEmpty ? context.l10n.draftUntitled : draft.title,
        style: VineTheme.titleSmallFont(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        _formatDraftSubtitle(context, draft.lastModified),
        style: VineTheme.bodySmallFont(),
      ),
      trailing: onOpenMore == null
          ? null
          : IconButton(
              onPressed: onOpenMore,
              icon: const DivineIcon(
                icon: DivineIconName.dotsThreeVertical,
                color: VineTheme.onSurface,
                size: 28,
              ),
            ),
    );
  }
}
