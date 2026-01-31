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
class VideoClipEditorScreen extends ConsumerStatefulWidget {
  /// Creates a video editor screen.
  const VideoClipEditorScreen({
    super.key,
    this.draftId,
    this.fromLibrary = false,
  });

  /// Optional draft ID to load an existing draft.
  final String? draftId;

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  /// Route name for this screen.
  static const routeName = 'video-clip-editor';

  /// Path for this route.
  static const path = '/video-clip-editor';

  @override
  ConsumerState<VideoClipEditorScreen> createState() =>
      _VideoClipEditorScreenState();
}

class _VideoClipEditorScreenState extends ConsumerState<VideoClipEditorScreen> {
  late bool _isLoadingDraft = widget.draftId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      await ref
          .read(videoEditorProvider.notifier)
          .initialize(draftId: widget.draftId);

      setState(() {
        _isLoadingDraft = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final isProcessing = ref.watch(
      videoEditorProvider.select((p) => p.isProcessing),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: VineTheme.surfaceContainerHigh,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: PopScope(
        canPop: !isProcessing,
        child: SafeArea(
          child: Scaffold(
            resizeToAvoidBottomInset: false,
            backgroundColor: VineTheme.surfaceContainerHigh,
            body: _isLoadingDraft
                ? const Center(child: CircularProgressIndicator.adaptive())
                : Column(
                    children: [
                      /// Top bar
                      VideoClipEditorTopBar(fromLibrary: widget.fromLibrary),

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
