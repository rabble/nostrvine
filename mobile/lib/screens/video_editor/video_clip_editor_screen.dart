// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_clip_editor/gallery/video_editor_clip_gallery.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_bottom_bar.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_progress_bar.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_split_bar.dart';
import 'package:openvine/widgets/video_clip_editor/video_clip_editor_top_bar.dart';

/// Video editor screen for editing recorded video clips.
class VideoClipEditorScreen extends ConsumerWidget {
  /// Creates a video editor screen.
  const VideoClipEditorScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = ref.watch(
      videoEditorProvider.select((p) => p.isProcessing),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: VineTheme.surfaceContainerHigh,
        systemNavigationBarColor: VineTheme.surfaceContainerHigh,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: PopScope(
        canPop: !isProcessing,
        child: SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: VineTheme.surfaceContainerHigh,
            body: Column(
              children: [
                /// Top bar
                const VideoClipEditorTopBar(),

                /// Main content area with clips
                const Expanded(child: VideoEditorClipGallery()),

                /// Progress or Split bar
                Container(
                  height: 40,
                  padding: const .symmetric(horizontal: 16),
                  child: Consumer(
                    builder: (_, ref, _) {
                      final isEditing = ref.watch(
                        videoEditorProvider.select((p) => p.isEditing),
                      );

                      return isEditing
                          ? const VideoClipEditorSplitBar()
                          : const VideoClipEditorProgressBar();
                    },
                  ),
                ),

                /// Bottom bar
                const VideoClipEditorBottomBar(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
