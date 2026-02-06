import 'package:flutter/material.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:video_player/video_player.dart';

class VideoEditorPlayer extends StatelessWidget {
  const VideoEditorPlayer({
    super.key,
    required this.controller,
    required this.isPlayerReady,
  });

  final bool isPlayerReady;
  final VideoPlayerController? controller;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return ClipRRect(
          borderRadius: .all(.circular(32)),
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
                constraints: constraints,
              ),
            ],
          ),
        );
      },
    );
  }
}
