// ABOUTME: Bottom sheet for video editor options.
// ABOUTME: Provides actions to add clips from library, save to drafts, or delete all clips.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/bottom_sheet_list_tile.dart';

/// Bottom sheet for video editor more options.
///
/// Allows users to add clips from library, save to drafts, or delete all clips.
class VideoEditorClipEditMoreSheet extends ConsumerStatefulWidget {
  /// Creates a video editor more options sheet.
  const VideoEditorClipEditMoreSheet({super.key});

  @override
  ConsumerState<VideoEditorClipEditMoreSheet> createState() =>
      _VideoEditorMoreSheetState();
}

class _VideoEditorMoreSheetState
    extends ConsumerState<VideoEditorClipEditMoreSheet> {
  /// Gets the current clip index from the video editor.
  int get _currentClipIndex => ref.read(videoEditorProvider).currentClipIndex;

  /// Gets the current clip from the clip manager.
  RecordingClip get _currentClip {
    final clipManager = ref.read(clipManagerProvider.notifier);
    return clipManager.clips[_currentClipIndex];
  }

  Future<void> _saveClipToLibrary() async {
    final clipManager = ref.read(clipManagerProvider.notifier);
    final success = await clipManager.saveClipToLibrary(_currentClip);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // TODO(l10n): Replace with context.l10n when localization is added.
          content: Text('Clip saved to library'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // TODO(l10n): Replace with context.l10n when localization is added.
          content: Text('Failed to save clip'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFFF44336),
        ),
      );
    }
  }

  Future<void> _removeClip() async {
    final clipManager = ref.read(clipManagerProvider.notifier);
    final success = clipManager.removeClipById(_currentClip.id);

    if (!success) {
      // Clip not found
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // TODO(l10n): Replace with context.l10n when localization is added.
          content: Text('Failed to delete clip: Clip not found'),
          duration: Duration(seconds: 3),
          backgroundColor: Color(0xFFF44336),
        ),
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
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          // TODO(l10n): Replace with context.l10n when localization is added.
          content: Text('Clip deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: .min,
        spacing: 24,
        children: [
          const Padding(
            padding: .only(top: 8),
            child: VineBottomSheetDragHandle(),
          ),
          SingleChildScrollView(
            child: Column(
              mainAxisSize: .min,
              children: [
                BottomSheetListTile(
                  iconPath: 'assets/icon/trim.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  title: 'Split clip',
                  onTap: () => ref
                      .read(videoEditorProvider.notifier)
                      .splitSelectedClip(),
                ),
                BottomSheetListTile(
                  iconPath: 'assets/icon/save.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  title: 'Save clip',
                  onTap: _saveClipToLibrary,
                ),
                BottomSheetListTile(
                  iconPath: 'assets/icon/trash.svg',
                  // TODO(l10n): Replace with context.l10n when localization is added.
                  title: 'Delete clip',
                  onTap: _removeClip,
                  color: const Color(0xFFF44336),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
