import 'package:flutter/material.dart';
import 'package:openvine/models/video_publish/video_publish_state.dart';
import 'package:divine_ui/divine_ui.dart';

class VideoPublishStatusIcon extends StatelessWidget {
  const VideoPublishStatusIcon({super.key, required this.publishState});

  final VideoPublishState publishState;

  @override
  Widget build(BuildContext context) {
    switch (publishState) {
      case .error:
        return const Icon(Icons.error_outline, color: Colors.red, size: 48);
      case .completed:
        return const Icon(
          Icons.check_circle,
          color: VineTheme.vineGreen,
          size: 48,
        );
      case .uploading:
      case .retryUpload:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(VineTheme.vineGreen),
          ),
        );
      case .publishToNostr:
        return const Icon(
          Icons.cloud_upload,
          color: VineTheme.vineGreen,
          size: 48,
        );
      case .idle:
      case .initialize:
      case .preparing:
        return const SizedBox(
          width: 48,
          height: 48,
          child: CircularProgressIndicator(
            strokeWidth: 4,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        );
    }
  }
}
