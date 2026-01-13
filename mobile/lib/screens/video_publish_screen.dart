// ABOUTME: Video publish screen with video preview and controls
// ABOUTME: Allows users to preview and publish their edited video

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/video_publish/status/video_publish_upload_status.dart';
import 'package:openvine/widgets/video_publish/video_publish_bottom_bar.dart';
import 'package:openvine/widgets/video_publish/video_publish_top_bar.dart';

/// Video publish screen for previewing and publishing edited videos.
class VideoPublishScreen extends ConsumerWidget {
  /// Creates a video publish screen.
  const VideoPublishScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.black,
        statusBarIconBrightness: .light,
        statusBarBrightness: .dark,
      ),
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: .expand,
          children: [
            // Video preview
            // TODO(@hm21): Temporary "commented out" create PR with only new files
            // Align(child: VideoPublishVideoPreview()),

            // Top navigation
            Align(alignment: .topCenter, child: VideoPublishTopBar()),

            // Bottom controls
            Align(alignment: .bottomCenter, child: VideoPublishBottomBar()),

            // Upload status overlay
            VideoPublishUploadStatus(),
          ],
        ),
      ),
    );
  }
}
