// ABOUTME: Top overlay actions for the video editor with close and done buttons.
// ABOUTME: Hides when the music sub-editor is open.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:unified_logger/unified_logger.dart';

/// Top action bar for the video editor.
///
/// Displays close, undo, redo, audio, and done buttons. Uses [BlocSelector] to
/// reactively enable/disable undo and redo based on editor state.
class VideoEditorMainOverlayActions extends StatelessWidget {
  const VideoEditorMainOverlayActions({super.key});

  @override
  Widget build(BuildContext context) {
    final isHidden = context.select(
      (VideoEditorMainBloc b) => b.state.openSubEditor == .music,
    );

    return IgnorePointer(
      ignoring: isHidden,
      child: AnimatedOpacity(
        opacity: isHidden ? 0 : 1,
        duration: const Duration(milliseconds: 200),
        child: const Stack(
          fit: .expand,
          children: [
            Align(alignment: .topCenter, child: _TopActions()),
            Align(alignment: .bottomCenter, child: _BottomActions()),
          ],
        ),
      ),
    );
  }
}

/// Top row actions: close, audio chip, and done buttons.
class _TopActions extends ConsumerWidget {
  const _TopActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scope = VideoEditorScope.of(context);
    // Uses `read` because `draftId` is set once during `initialize()` and
    // does not change during the editor session.
    final isAutosavedDraft = ref.watch(
      videoEditorProvider.select((s) => s.isAutosavedDraft),
    );

    return PopScope(
      canPop: !isAutosavedDraft,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && isAutosavedDraft) {
          _onClosePressed(
            context: context,
            ref: ref,
            closeSubEditor: scope.editor?.closeSubEditor,
          );
        }
      },
      child: VideoEditorToolbar(
        closeIcon: .caretLeft,
        doneIcon: .arrowRight,
        onClose: () {
          if (isAutosavedDraft) {
            _onClosePressed(
              context: context,
              ref: ref,
              closeSubEditor: scope.editor?.closeSubEditor,
            );
          } else {
            context.pop();
          }
        },
        onDone: () => scope.editor?.doneEditing(),
      ),
    );
  }

  void _onClosePressed({
    required BuildContext context,
    required WidgetRef ref,
    required VoidCallback? closeSubEditor,
  }) {
    final bloc = context.read<VideoEditorMainBloc>();
    if (bloc.state.isSubEditorOpen) {
      closeSubEditor?.call();
      return;
    }

    final hasBeenEdited = ref
        .read(videoEditorProvider.notifier)
        .getActiveDraft()
        .hasBeenEdited;

    if (!hasBeenEdited) {
      context.pop();
      return;
    }

    VineBottomSheetPrompt.show(
      context: context,
      sticker: .videoClapBoard,
      title: context.l10n.videoEditorSaveDraftTitle,
      subtitle: context.l10n.videoEditorSaveDraftSubtitle,
      primaryButtonText: context.l10n.videoEditorSaveDraftButton,
      secondaryButtonText: context.l10n.videoEditorDiscardChangesButton,
      tertiaryButtonText: context.l10n.videoEditorKeepEditingButton,
      onPrimaryPressed: () => _onSaveDraftPressed(context: context, ref: ref),
      onSecondaryPressed: () => _onDiscardPressed(context: context, ref: ref),
      onTertiaryPressed: context.pop,
    );
  }

  Future<void> _onSaveDraftPressed({
    required BuildContext context,
    required WidgetRef ref,
  }) async {
    var draftSaved = true;
    try {
      // Save the draft to the library.
      final draftSuccess = await ref
          .read(videoEditorProvider.notifier)
          .saveAsDraft(enforceCreateNewDraft: true);
      if (!draftSuccess) {
        throw StateError('Failed to save draft');
      }
    } catch (e, stackTrace) {
      Log.error(
        'Failed to save: $e',
        name: 'VideoMetadataCaptureBottomBar',
        category: LogCategory.video,
        error: e,
        stackTrace: stackTrace,
      );
      draftSaved = false;
    }
    if (!context.mounted) return;

    if (draftSaved) {
      // Success: close prompt + close editor.
      context.pop();
      context.pop();
    } else {
      // Failure: close only prompt and keep editor open.
      context.pop();
    }

    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.showSnackBar(
      DivineSnackbarContainer.snackBar(
        draftSaved
            ? context.l10n.videoMetadataSavedToLibrarySnackbar
            : context.l10n.videoMetadataFailedToSaveSnackbar,
      ),
    );
  }

  void _onDiscardPressed({
    required BuildContext context,
    required WidgetRef ref,
  }) {
    ref.read(videoPublishProvider.notifier).clearAll();
    context.pop();
    context.pop();
  }
}

class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final isTimelineHiddenByUser = context.select(
      (VideoEditorMainBloc b) => b.state.isTimelineHiddenByUser,
    );

    return Semantics(
      label: isTimelineHiddenByUser
          ? context.l10n.videoEditorShowTimelineSemanticLabel
          : context.l10n.videoEditorHideTimelineSemanticLabel,
      button: true,
      child: Padding(
        padding: const .only(bottom: 8),
        child: DivineIconButton(
          icon: isTimelineHiddenByUser ? .caretUp : .caretDown,
          onPressed: () => context.read<VideoEditorMainBloc>().add(
            const VideoEditorTimelineVisibilityToggled(),
          ),
          size: .small,
          type: .ghostSecondary,
        ),
      ),
    );
  }
}
