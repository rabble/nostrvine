import 'dart:math';

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
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
    final useFullSize = targetAspectRatio.useFullScreenForSize(bodySize);
    final aspectRatio = useFullSize
        ? renderSize.aspectRatio
        : targetAspectRatio.value;

    return ClipPath(
      clipper: _RoundedRectClipper(
        bodySize: bodySize,
        enableFullScreen: useFullSize,
        targetAspectRatio: targetAspectRatio.value,
        borderRadius: targetAspectRatio == .square ? 0 : 32,
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
    required this.enableFullScreen,
    required this.targetAspectRatio,
    required this.borderRadius,
  });

  final Size bodySize;
  final bool enableFullScreen;
  final double targetAspectRatio;
  final double borderRadius;

  @override
  Path getClip(Size size) {
    final clipSize = computeClipSize(
      widgetSize: size,
      bodySize: bodySize,
      enableFullScreen: enableFullScreen,
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
        topLeft: enableFullScreen ? Radius.zero : radius,
        topRight: enableFullScreen ? Radius.zero : radius,
        bottomLeft: radius,
        bottomRight: radius,
      ),
    );
  }

  @override
  bool shouldReclip(_RoundedRectClipper oldClipper) =>
      bodySize != oldClipper.bodySize ||
      enableFullScreen != oldClipper.enableFullScreen ||
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
  required bool enableFullScreen,
  required double targetAspectRatio,
}) {
  if (enableFullScreen) {
    final scale = max(
      bodySize.width / widgetSize.width,
      bodySize.height / widgetSize.height,
    );
    return bodySize / scale;
  }
  if (widgetSize.aspectRatio > targetAspectRatio) {
    return Size(widgetSize.height * targetAspectRatio, widgetSize.height);
  }
  return Size(widgetSize.width, widgetSize.width / targetAspectRatio);
}
