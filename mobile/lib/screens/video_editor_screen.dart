// ABOUTME: Video editor screen for adding text overlays and sound to recorded videos
// ABOUTME: Dark-themed interface with video preview, text editing, and sound selection

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_editor/gallery/video_editor_clip_gallery.dart';
import 'package:openvine/widgets/video_editor/video_editor_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/video_editor_processing_overlay.dart';
import 'package:openvine/widgets/video_editor/video_editor_progress_bar.dart';
import 'package:openvine/widgets/video_editor/video_editor_split_bar.dart';
import 'package:openvine/widgets/video_editor/video_editor_top_bar.dart';

/// Video editor screen for editing recorded video clips.
class VideoEditorScreen extends ConsumerStatefulWidget {
  /// Creates a video editor screen.
  const VideoEditorScreen({super.key, this.draftId, this.fromLibrary = false});

  /// Optional draft ID to load an existing draft.
  final String? draftId;

  /// Whether the editor was opened from the clip library.
  final bool fromLibrary;

  /// Route name for this screen.
  static const routeName = 'video-editor';

  /// Path for this route.
  static const path = '/video-editor';

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  late bool _isLoadingDraft = widget.draftId != null;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref
          .read(videoEditorProvider.notifier)
          .initialize(draftId: widget.draftId);
      if (!mounted) return;

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
    const backgroundColor = Color(0xFF000A06);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: const SystemUiOverlayStyle(
        statusBarColor: backgroundColor,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: PopScope(
        canPop: !isProcessing,
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: backgroundColor,
          body: _isLoadingDraft
              ? const Center(child: CircularProgressIndicator.adaptive())
              : Stack(
                  children: [
                    SafeArea(
                      child: Column(
                        children: [
                          /// Top bar
                          VideoEditorTopBar(fromLibrary: widget.fromLibrary),

                          /// Main content area with clips
                          const Expanded(child: VideoEditorClipGallery()),

                          /// Progress or Split bar
                          Consumer(
                            builder: (_, ref, _) {
                              final isEditing = ref.watch(
                                videoEditorProvider.select((p) => p.isEditing),
                              );

                              return Container(
                                height: 40,
                                padding: const .symmetric(horizontal: 16),
                                child: isEditing
                                    ? const VideoEditorSplitBar()
                                    : const VideoProgressBar(),
                              );
                            },
                          ),

                          /// Bottom bar
                          const VideoEditorBottomBar(),
                        ],
                      ),
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: isProcessing
                          ? const VideoEditorProcessingOverlay()
                          : const SizedBox.shrink(),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
