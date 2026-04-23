// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/clip_editor/gallery/video_editor_clip_gallery.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_progress_bar.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_split_bar.dart';
import 'package:openvine/widgets/video_editor/clip_editor/video_clip_editor_top_bar.dart';

/// Video editor screen for editing recorded video clips.
class VideoClipEditorScreen extends ConsumerWidget {
  /// Creates a video editor screen.
  const VideoClipEditorScreen({required this.initialClips, super.key});

  final List<DivineVideoClip> initialClips;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isProcessing = ref.watch(
      videoEditorProvider.select((p) => p.isProcessing),
    );

    return BlocProvider(
      create: (_) {
        late final ClipEditorBloc bloc;
        bloc = ClipEditorBloc(
          onFinalClipInvalidated: () {
            final notifier = ref.read(videoEditorProvider.notifier);
            notifier.invalidateFinalRenderedClip();
          },
        )..add(ClipEditorInitialized(initialClips));

        return bloc;
      },
      child: ScaffoldMessenger(
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: VideoEditorConstants.uiOverlayStyle,
          child: PopScope(
            canPop: !isProcessing,
            child: Scaffold(
              resizeToAvoidBottomInset: false,
              backgroundColor: VineTheme.surfaceContainerHigh,
              body: SafeArea(
                child: Column(
                  children: [
                    /// Top bar
                    const VideoClipEditorTopBar(),

                    /// Main content area with clips
                    const Expanded(child: VideoEditorClipGallery()),

                    /// Progress or Split bar
                    Container(
                      height: 40,
                      padding: const .symmetric(horizontal: 16),
                      child:
                          BlocSelector<ClipEditorBloc, ClipEditorState, bool>(
                            selector: (state) => state.isEditing,
                            builder: (_, isEditing) {
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
        ),
      ),
    );
  }
}
