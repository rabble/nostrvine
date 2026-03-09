// ABOUTME: Drafts tab widget for the clip library screen
// ABOUTME: Displays a list of saved video drafts with options to edit or delete

import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/library/empty_library_state.dart';

/// Tab widget displaying a list of saved drafts.
///
/// Uses [DraftsLibraryBloc] for state management and handles draft actions
/// (post, edit, delete) internally.
class DraftsTab extends ConsumerWidget {
  /// Creates a drafts tab.
  const DraftsTab({super.key});

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
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label: isSuccess ? 'Draft deleted' : 'Failed to delete draft',
            ),
          ),
        );
      },
      builder: (context, state) {
        return switch (state) {
          DraftsLibraryInitial() || DraftsLibraryLoading() => const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          ),
          DraftsLibraryError(:final message) => Center(
            child: Text(
              message,
              style: const TextStyle(color: VineTheme.error),
            ),
          ),
          DraftsLibraryLoaded(:final drafts) ||
          DraftsLibraryDraftDeleted(:final drafts) ||
          DraftsLibraryDeleteFailed(
            :final drafts,
          ) when drafts.isEmpty => const EmptyLibraryState(
            icon: DivineIconName.pencilSimple,
            // TODO(l10n): Replace with context.l10n when localization is
            // added.
            title: 'No Drafts Yet',
            // TODO(l10n): Replace with context.l10n when localization is
            // added.
            subtitle: 'Videos you save as draft will appear here',
          ),
          DraftsLibraryLoaded(:final drafts) ||
          DraftsLibraryDraftDeleted(:final drafts) ||
          DraftsLibraryDeleteFailed(:final drafts) => ListView.builder(
            itemCount: drafts.length,
            itemBuilder: (context, index) {
              final draft = drafts[index];
              return DraftListTile(
                draft: draft,
                onTap: () => _openDraft(context, ref, draft),
                onOpenMore: () => _openDraftOptions(context, ref, draft),
              );
            },
          ),
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
      title: DraftListTile(
        draft: draft,
        enableShrink: true,
      ),
      options: [
        VineBottomSheetActionData(
          iconPath: 'assets/icon/${DivineIconName.paperPlaneTilt.fileName}.svg',
          label: 'Post',
          onTap: () => _postDraft(context, ref, draft),
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/${DivineIconName.pencilSimple.fileName}.svg',
          label: 'Edit',
          onTap: () => _openDraft(context, ref, draft),
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/${DivineIconName.trash.fileName}.svg',
          label: 'Delete draft',
          isDestructive: true,
          onTap: () => _deleteDraft(context, draft),
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
      context.read<DraftsLibraryBloc>().add(
        const DraftsLibraryLoadRequested(),
      );
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
    await ref.read(videoPublishProvider.notifier).clearAll();

    if (!context.mounted) return;

    await context.push(
      '${VideoClipEditorScreen.path}/${draft.id}',
      extra: {'fromLibrary': true},
    );

    await ref.read(videoPublishProvider.notifier).clearAll();

    // Reload drafts after returning
    if (context.mounted) {
      context.read<DraftsLibraryBloc>().add(const DraftsLibraryLoadRequested());
    }
  }

  Future<void> _deleteDraft(
    BuildContext context,
    DivineVideoDraft draft,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Delete Draft',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'Are you sure you want to delete '
          '"${draft.title.isEmpty ? "Untitled" : draft.title}"?',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.error,
              foregroundColor: VineTheme.whiteText,
            ),
            child: const Text('Delete'),
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
    }
  }
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
      contentPadding: EdgeInsets.fromLTRB(enableShrink ? 0 : 16, 0, 10, 0),
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
        draft.title.isEmpty ? 'Untitled' : draft.title,
        style: VineTheme.titleSmallFont(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        DateFormat('EEEE, MMM d yyyy h:mm a').format(draft.lastModified),
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
