import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/classic/video_metadata_classic_preview_thumbnail.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';

class VideoMetadataClassicStack extends StatelessWidget {
  const VideoMetadataClassicStack({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: VineTheme.surfaceContainerHigh,
      appBar: VideoMetadataClassicAppBar(),
      body: Column(
        spacing: 12,
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: .only(top: 12),
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                spacing: 16,
                children: [
                  VideoMetadataClassicPreviewThumbnail(),
                  VideoMetadataFormFields(
                    enableTags: false,
                    enableExpiration: false,
                    enableContentWarning: false,
                    enableCollaborators: false,
                    enableInspiredBy: false,
                  ),
                ],
              ),
            ),
          ),
          SafeArea(top: false, child: VideoMetadataClassicBottomBar()),
        ],
      ),
    );
  }
}
