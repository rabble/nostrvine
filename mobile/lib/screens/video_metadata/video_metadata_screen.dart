// ABOUTME: Video metadata editing screen for post details, title, description,
// ABOUTME: tags and expiration with updated visual hierarchy

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/providers/video_recorder_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_stack.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_stack.dart';

/// Screen for editing video metadata including title, description, tags, and
/// expiration settings.
class VideoMetadataScreen extends ConsumerStatefulWidget {
  /// Creates a video metadata editing screen.
  const VideoMetadataScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'video-metadata';

  /// Path for this route.
  static const path = '/video-metadata';

  @override
  ConsumerState<VideoMetadataScreen> createState() =>
      _VideoMetadataScreenState();
}

class _VideoMetadataScreenState extends ConsumerState<VideoMetadataScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      // Clear any stale error/completed state from a previous publish attempt
      // so the overlay doesn't block the new publish flow.
      ref.read(videoPublishProvider.notifier).clearError();
    });
  }

  @override
  Widget build(BuildContext context) {
    final recorderMode = ref.watch(
      videoRecorderProvider.select((s) => s.recorderMode),
    );

    // Cancel video render when user navigates back
    return PopScope(
      onPopInvokedWithResult: (didPop, result) {
        unawaited(ref.read(videoEditorProvider.notifier).cancelRenderVideo());
      },
      // Dismiss keyboard when tapping outside input fields
      child: GestureDetector(
        onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
        child: switch (recorderMode) {
          .capture => const VideoMetadataCaptureStack(),
          .classic => const VideoMetadataClassicStack(),
          // Deliberately unreachable: upload mode has no record button, so no
          // clips can be created and the user cannot navigate to the metadata
          // screen while in this mode. Required only for switch exhaustiveness.
          .upload => const SizedBox.shrink(),
        },
      ),
    );
  }
}
