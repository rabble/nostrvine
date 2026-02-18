import 'dart:math';

import 'package:flutter/material.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/extensions/aspect_ratio_extensions.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:video_player/video_player.dart';

class VideoEditorPlayer extends StatelessWidget {
  const VideoEditorPlayer({
    super.key,
    required this.controller,
    required this.targetAspectRatio,
    required this.originalAspectRatio,
    required this.isPlayerReady,
    required this.bodySize,
    required this.renderSize,
  });

  final bool isPlayerReady;
  final model.AspectRatio targetAspectRatio;
  final double originalAspectRatio;
  final VideoPlayerController? controller;
  final Size bodySize;
  final Size renderSize;

  @override
  Widget build(BuildContext context) {
    final useFullSize = targetAspectRatio.useFullScreenForSize(bodySize);
    final aspectRatio = useFullSize
        ? renderSize.aspectRatio
        : targetAspectRatio.value;

    return Center(
      child: ClipPath(
        clipper: _RoundedRectClipper(
          bodySize: bodySize,
          enableFullScreen: useFullSize,
        ),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Video layer
              if (isPlayerReady)
                FittedBox(
                  fit: .contain,
                  child: SizedBox(
                    width: controller!.value.size.width,
                    height: controller!.value.size.height,
                    child: VideoPlayer(controller!),
                  ),
                ),

              // Thumbnail layer with fade out
              VideoEditorThumbnail(
                isInitialized: isPlayerReady,
                contentSize: renderSize,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoundedRectClipper extends CustomClipper<Path> {
  const _RoundedRectClipper({
    required this.bodySize,
    required this.enableFullScreen,
  });

  final Size bodySize;
  final bool enableFullScreen;

  @override
  Path getClip(Size size) {
    final Size clipSize;

    if (enableFullScreen) {
      // BoxFit.cover: the visible area is bodySize, scaled to widget coordinates.
      // Calculate the scale that FittedBox.cover applies to make size cover bodySize.
      final scale = max(
        bodySize.width / size.width,
        bodySize.height / size.height,
      );
      // The visible region in widget coordinates
      clipSize = bodySize / scale;
    } else {
      // BoxFit.contain: the AspectRatio widget already has correct proportions,
      // just use its full size
      clipSize = size;
    }

    // Convert 32px screen radius to widget coordinates
    final radius = Radius.circular(32 * clipSize.width / bodySize.width);

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
      enableFullScreen != oldClipper.enableFullScreen;
}
