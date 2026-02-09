import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:video_player/video_player.dart';
import 'package:models/models.dart' as model show AspectRatio;

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
    final useFullSize =
        targetAspectRatio == .vertical && (kIsWeb || !Platform.isMacOS);

    final aspectRatio = useFullSize
        ? renderSize.aspectRatio
        : targetAspectRatio.value;

    return Center(
      child: ClipPath(
        clipper: _RoundedRectClipper(
          bodySize: bodySize,
          aspectRatio: originalAspectRatio,
          roundTopCorners: !useFullSize,
        ),
        child: AspectRatio(
          aspectRatio: aspectRatio,
          child: Stack(
            fit: .expand,
            children: [
              // Video layer
              if (isPlayerReady)
                FittedBox(
                  fit: .cover,
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
    required this.aspectRatio,
    required this.roundTopCorners,
  });

  final Size bodySize;
  final double aspectRatio;
  final bool roundTopCorners;

  @override
  Path getClip(Size size) {
    final radius = Radius.circular(32 * aspectRatio);
    return Path()..addRRect(
      .fromRectAndCorners(
        .fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: bodySize.width * aspectRatio,
          height: bodySize.height * aspectRatio,
        ),
        topLeft: roundTopCorners ? radius : .zero,
        topRight: roundTopCorners ? radius : .zero,
        bottomLeft: radius,
        bottomRight: radius,
      ),
    );
  }

  @override
  bool shouldReclip(_RoundedRectClipper oldClipper) =>
      bodySize != oldClipper.bodySize ||
      aspectRatio != oldClipper.aspectRatio ||
      roundTopCorners != oldClipper.roundTopCorners;
}
