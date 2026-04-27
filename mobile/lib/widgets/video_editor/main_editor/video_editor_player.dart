import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

class VideoEditorPlayer extends StatelessWidget {
  const VideoEditorPlayer({
    required this.controller,
    required this.targetAspectRatio,
    required this.originalAspectRatio,
    required this.bodySize,
    required this.renderSize,
    super.key,
  });

  final model.AspectRatio targetAspectRatio;
  final double originalAspectRatio;
  final DivineVideoPlayerController? controller;
  final Size bodySize;
  final Size renderSize;

  @override
  Widget build(BuildContext context) {
    final aspectRatio = targetAspectRatio.value;

    return ClipPath(
      clipper: _RoundedRectClipper(
        bodySize: bodySize,
        targetAspectRatio: targetAspectRatio.value,
        borderRadius: VideoEditorConstants.canvasRadius,
      ),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: DivineVideoPlayer(
          controller: controller,
          placeholder: VideoEditorThumbnail(contentSize: renderSize),
        ),
      ),
    );
  }
}

class _RoundedRectClipper extends CustomClipper<Path> {
  const _RoundedRectClipper({
    required this.bodySize,
    required this.targetAspectRatio,
    required this.borderRadius,
  });

  final Size bodySize;
  final double targetAspectRatio;
  final double borderRadius;

  @override
  Path getClip(Size size) {
    final clipSize = computeClipSize(
      widgetSize: size,
      bodySize: bodySize,
      targetAspectRatio: targetAspectRatio,
    );

    // Convert 32px screen radius to widget coordinates
    final radius = Radius.circular(
      borderRadius * clipSize.width / bodySize.width,
    );

    return Path()..addRRect(
      RRect.fromRectAndCorners(
        Rect.fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: clipSize.width,
          height: clipSize.height,
        ),
        topLeft: radius,
        topRight: radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
    );
  }

  @override
  bool shouldReclip(_RoundedRectClipper oldClipper) =>
      bodySize != oldClipper.bodySize ||
      targetAspectRatio != oldClipper.targetAspectRatio ||
      borderRadius != oldClipper.borderRadius;
}

/// Computes the clipped region for the video player.
///
/// Exposed for testing only.
@visibleForTesting
Size computeClipSize({
  required Size widgetSize,
  required Size bodySize,
  required double targetAspectRatio,
}) {
  if (widgetSize.aspectRatio > targetAspectRatio) {
    return Size(widgetSize.height * targetAspectRatio, widgetSize.height);
  }
  return Size(widgetSize.width, widgetSize.width / targetAspectRatio);
}
