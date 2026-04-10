import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoClipEditorMoreButton extends ConsumerStatefulWidget {
  const VideoClipEditorMoreButton({super.key});

  @override
  ConsumerState<VideoClipEditorMoreButton> createState() =>
      _VideoEditorMoreButtonState();
}

class _VideoEditorMoreButtonState
    extends ConsumerState<VideoClipEditorMoreButton> {
  /// Gets the current clip index from the clip editor bloc.
  int get _currentClipIndex =>
      context.read<ClipEditorBloc>().state.currentClipIndex;

  /// Gets the current clip from the BLoC's local clip list.
  DivineVideoClip get _currentClip {
    final state = context.read<ClipEditorBloc>().state;
    return state.clips[_currentClipIndex];
  }

  /// Show the more options bottom sheet.
  ///
  /// Displays additional editor options like save to drafts, clip library, etc.
  Future<void> _showMoreOptions() async {
    Log.debug(
      '⚙️ Showing more options sheet',
      name: 'VideoEditorNotifier',
      category: .video,
    );
    final isEditing = context.read<ClipEditorBloc>().state.isEditing;

    if (isEditing) {
      await _openClipEditOptions();
    } else {
      await _openOverviewOptions();
    }
  }

  /// Shows options for the overview mode: add clip, save clip, delete all.
  Future<void> _openOverviewOptions() async {
    await VineBottomSheetActionMenu.show(
      context: context,
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.folderOpen.assetPath,
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Add clip from Library',
          onTap: () => _pickFromLibrary(context),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.save.assetPath,
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Save selected clip',
          onTap: _saveClipToLibrary,
        ),
      ],
    );
  }

  /// Shows options for clip editing mode: split, save, or delete current clip.
  Future<void> _openClipEditOptions() async {
    final clips = context.read<ClipEditorBloc>().state.clips;
    final isLastClip = clips.length <= 1;

    await VineBottomSheetActionMenu.show(
      context: context,
      options: [
        VineBottomSheetActionData(
          iconPath: DivineIconName.scissors.assetPath,
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Split clip',
          onTap: () => context.read<ClipEditorBloc>().add(
            const ClipEditorSplitRequested(),
          ),
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.save.assetPath,
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Save clip',
          onTap: _saveClipToLibrary,
        ),
        VineBottomSheetActionData(
          iconPath: DivineIconName.trash.assetPath,
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Delete clip',
          onTap: isLastClip ? null : _removeClip,
          isDestructive: true,
        ),
      ],
    );
  }

  /// Saves the current clip to the device's clip library.
  Future<void> _saveClipToLibrary() async {
    final clipManager = ref.read(clipManagerProvider.notifier);
    final success = await clipManager.saveClipToLibrary(_currentClip);

    if (!mounted) return;

    // TODO(l10n): Replace with context.l10n when localization is added.
    _showSnackBar(
      message: success ? 'Clip saved to library' : 'Failed to save clip',
      isError: !success,
    );
  }

  /// Removes the current clip from the timeline.
  ///
  /// If only one clip remains, navigates back to the previous screen.
  void _removeClip() {
    final bloc = context.read<ClipEditorBloc>();
    final clips = bloc.state.clips;
    final clipId = _currentClip.id;

    if (clips.length <= 1) {
      // Last clip — navigate back to the video recorder.
      _deleteAndStartOver();
      return;
    }

    bloc.add(ClipEditorClipRemoved(clipId));

    // Adjust index if it would be out of bounds after removal.
    final currentIndex = bloc.state.currentClipIndex;
    if (currentIndex >= clips.length - 1) {
      bloc.add(ClipEditorClipSelected(clips.length - 2));
    }
    bloc.add(const ClipEditorEditingStopped());
    // TODO(l10n): Replace with context.l10n when localization is added.
    _showSnackBar(message: 'Clip deleted');
  }

  /// Shows a styled snackbar with the given message.
  void _showSnackBar({required String message, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: VineTheme.transparent,
        elevation: 0,
        behavior: .floating,
        duration: Duration(seconds: isError ? 3 : 2),
        content: DivineSnackbarContainer(label: message, error: isError),
      ),
    );
  }

  /// Deletes all clips and starts over.
  Future<void> _deleteAndStartOver() async {
    ref.read(videoRecorderProvider.notifier).reset();
    ref.read(videoEditorProvider.notifier).reset();
    ref.read(videoPublishProvider.notifier).reset();
    ref.read(clipManagerProvider.notifier).clearAll();

    /// Navigate back to the video-recorder page.
    // TODO(hm21): reimplement after design decision is done
    // if we go back to camera and also clean all clips or not.
    // if (mounted) {
    //   Navigator.of(
    //     context,
    //   ).popUntil(
    //     (route) =>
    //         route.settings.name == VideoRecorderScreen.routeName ||
    //         route.settings.name == LibraryScreen.draftsRouteName ||
    //         route.settings.name == LibraryScreen.clipsRouteName,
    //   );
    // }
    context.pop();
  }

  /// Opens the clip library screen in selection mode.
  ///
  /// Shows a modal bottom sheet with the clip library. When a clip is selected,
  /// it is imported into the current editing session.
  Future<void> _pickFromLibrary(BuildContext context) async {
    Log.info(
      '📹 Opening clip library in selection mode',
      name: 'ClipManagerNotifier',
      category: .video,
    );

    final bloc = context.read<ClipEditorBloc>();
    final selectedClips = await VineBottomSheet.show<List<DivineVideoClip>>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      showHeaderDivider: false,
      body: LibraryScreen(
        selectionMode: true,
        editorClips: bloc.state.clips,
      ),
    );

    if (selectedClips == null || selectedClips.isEmpty || !context.mounted) {
      return;
    }

    final currentCount = bloc.state.clips.length;

    for (var i = 0; i < selectedClips.length; i++) {
      final clip = selectedClips[i];
      final newClip = DivineVideoClip(
        id: 'clip_${DateTime.now().millisecondsSinceEpoch}_$i',
        video: clip.video,
        duration: clip.duration,
        recordedAt: DateTime.now(),
        thumbnailPath: clip.thumbnailPath,
        targetAspectRatio: clip.targetAspectRatio,
        originalAspectRatio: clip.targetAspectRatio.value,
        lensMetadata: clip.lensMetadata,
        ghostFramePath: clip.ghostFramePath,
        thumbnailTimestamp: clip.thumbnailTimestamp,
      );
      bloc.add(
        ClipEditorClipInserted(index: currentCount + i, clip: newClip),
      );
    }

    Log.info(
      '📹 Added ${selectedClips.length} clips from library',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoEditorIconButton(
      backgroundColor: VineTheme.transparent,
      icon: .moreHoriz,
      onTap: _showMoreOptions,
      // TODO(l10n): Replace with context.l10n when localization is added.
      semanticLabel: 'More options',
    );
  }
}
