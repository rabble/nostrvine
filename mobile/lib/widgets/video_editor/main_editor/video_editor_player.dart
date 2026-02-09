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
    required this.isPlayerReady,
    required this.bodySize,
    required this.renderSize,
  });

  final bool isPlayerReady;
  final model.AspectRatio targetAspectRatio;
  final VideoPlayerController? controller;
  final Size bodySize;
  final Size renderSize;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final aspectRatio =
            targetAspectRatio == .vertical && (kIsWeb || !Platform.isMacOS)
            ? constraints.biggest.aspectRatio
            : targetAspectRatio.value;
        print([
          'DEBUGX A',
          constraints.biggest,
          renderSize,
          '----',
          1 / constraints.biggest.aspectRatio,
          1 / aspectRatio,
          1 / renderSize.aspectRatio,
          1 / targetAspectRatio.value,
        ]);
        return Center(
          child: ClipPath(
            clipper: _RoundedRectClipper(
              bodySize: bodySize,
              aspectRatio: targetAspectRatio.value,
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
                    contentSize: constraints.biggest,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RoundedRectClipper extends CustomClipper<Path> {
  const _RoundedRectClipper({
    required this.bodySize,
    required this.aspectRatio,
  });

  final Size bodySize;
  final double aspectRatio;

  @override
  Path getClip(Size size) {
    return Path()..addRRect(
      .fromRectAndRadius(
        .fromCenter(
          center: Offset(size.width / 2, size.height / 2),
          width: bodySize.width * aspectRatio,
          height: bodySize.height * aspectRatio,
        ),
        .circular(32 * aspectRatio),
      ),
    );
  }

  @override
  bool shouldReclip(_RoundedRectClipper oldClipper) =>
      bodySize != oldClipper.bodySize || aspectRatio != oldClipper.aspectRatio;
}
