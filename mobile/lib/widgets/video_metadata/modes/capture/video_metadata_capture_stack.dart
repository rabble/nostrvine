import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';

class VideoMetadataCaptureStack extends StatelessWidget {
  const VideoMetadataCaptureStack({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VineTheme.surfaceContainerHigh,
      appBar: VideoMetadataCaptureAppBar(),
      body: Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  // Video preview at top
                  Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: VideoMetadataCaptureClipPreview(),
                  ),

                  // Form fields
                  VideoMetadataFormFields(),
                ],
              ),
            ),
          ),
          // Post button at bottom
          SafeArea(top: false, child: VideoMetadataCaptureBottomBar()),
        ],
      ),
    );
  }
}
