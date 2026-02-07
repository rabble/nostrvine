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
  });

  final bool isPlayerReady;
  final model.AspectRatio targetAspectRatio;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        final aspectRatio =
            targetAspectRatio == .vertical && (kIsWeb || !Platform.isMacOS)
            ? constraints.biggest.aspectRatio
            : targetAspectRatio.value;

        return Center(
          child: ClipRRect(
            borderRadius: .all(.circular(32)),
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
