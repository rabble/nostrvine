import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';
import 'package:video_player/video_player.dart';

class VideoEditorPlayer extends ConsumerStatefulWidget {
  const VideoEditorPlayer({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  ConsumerState<VideoEditorPlayer> createState() => _VideoEditorPlayerState();
}

class _VideoEditorPlayerState extends ConsumerState<VideoEditorPlayer> {
  bool _isInitialized = false;

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
              if (_isInitialized)
                FittedBox(
                  fit: BoxFit.cover,
                  child: _VideoContent(controller: widget.controller),
                ),

              // Thumbnail layer with fade out
              VideoEditorThumbnail(
                isInitialized: _isInitialized,
                constraints: constraints,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _VideoContent extends StatelessWidget {
  const _VideoContent({required this.controller});

  final VideoPlayerController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.value.size;
    return SizedBox(
      width: size.width,
      height: size.height,
      child: VideoPlayer(controller),
    );
  }
}
