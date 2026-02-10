import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/video_editor_icon_button.dart';

class VideoClipEditorMoreButton extends ConsumerStatefulWidget {
  const VideoClipEditorMoreButton({super.key});

  @override
  ConsumerState<VideoClipEditorMoreButton> createState() =>
      _VideoEditorMoreButtonState();
}

class _VideoEditorMoreButtonState
    extends ConsumerState<VideoClipEditorMoreButton> {
  /// Gets the current clip index from the video editor.
  int get _currentClipIndex => ref.read(videoEditorProvider).currentClipIndex;

  /// Gets the current clip from the clip manager.
  RecordingClip get _currentClip {
    final clipManager = ref.read(clipManagerProvider.notifier);
    return clipManager.clips[_currentClipIndex];
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
    final isEditing = ref.read(videoEditorProvider).isEditing;

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
          iconPath: 'assets/icon/folder_open.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Add clip from Library',
          onTap: () => _pickFromLibrary(context),
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/save.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Save selected clip',
          onTap: _saveClipToLibrary,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/trash.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Delete clips & start over',
          onTap: _deleteAndStartOver,
          isDestructive: true,
        ),
      ],
    );
  }

  /// Shows options for clip editing mode: split, save, or delete current clip.
  Future<void> _openClipEditOptions() async {
    await VineBottomSheetActionMenu.show(
      context: context,
      options: [
        VineBottomSheetActionData(
          iconPath: 'assets/icon/trim.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Split clip',
          onTap: () =>
              ref.read(videoEditorProvider.notifier).splitSelectedClip(),
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/save.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Save clip',
          onTap: _saveClipToLibrary,
        ),
        VineBottomSheetActionData(
          iconPath: 'assets/icon/trash.svg',
          // TODO(l10n): Replace with context.l10n when localization is added.
          label: 'Delete clip',
          onTap: _removeClip,
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
  /// If no clips remain, navigates back to the previous screen.
  Future<void> _removeClip() async {
    final clipManager = ref.read(clipManagerProvider.notifier);
    final success = await clipManager.removeClipById(_currentClip.id);

    if (!success) {
      // TODO(l10n): Replace with context.l10n when localization is added.
      _showSnackBar(
        message: 'Failed to delete clip: Clip not found',
        isError: true,
      );
      return;
    }

    // Check if there are any clips left
    final remainingClips = ref.read(clipManagerProvider).clips;

    if (remainingClips.isEmpty) {
      // No clips left, navigate back
      context.pop();
    } else {
      // Update currentClipIndex if it's now out of bounds
      final videoEditor = ref.read(videoEditorProvider.notifier);
      final currentIndex = ref.read(videoEditorProvider).currentClipIndex;
      if (currentIndex >= remainingClips.length) {
        videoEditor.selectClipByIndex(remainingClips.length - 1);
      }
      videoEditor.stopClipEditing();
      // TODO(l10n): Replace with context.l10n when localization is added.
      _showSnackBar(message: 'Clip deleted');
    }
  }

  /// Shows a styled snackbar with the given message.
  void _showSnackBar({required String message, bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        padding: EdgeInsets.zero,
        backgroundColor: Colors.transparent,
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
    ref.read(selectedSoundProvider.notifier).clear();

    /// Navigate back to the video-recorder page.
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

    await VineBottomSheet.show(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      showHeaderDivider: false,
      body: const ClipLibraryScreen(selectionMode: true),
    );

    Log.info(
      '📹 Closed clip library',
      name: 'ClipManagerNotifier',
      category: .video,
    );
  }

  @override
  Widget build(BuildContext context) {
    return VideoEditorIconButton(
      backgroundColor: const Color(0x00000000),
      iconPath: 'assets/icon/more_horiz.svg',
      onTap: _showMoreOptions,
      // TODO(l10n): Replace with context.l10n when localization is added.
      semanticLabel: 'More options',
    );
  }
}
