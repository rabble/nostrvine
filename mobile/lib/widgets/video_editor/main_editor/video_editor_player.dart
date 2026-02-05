import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_thumbnail.dart';

class VideoEditorPlayer extends ConsumerStatefulWidget {
  const VideoEditorPlayer({
    super.key,
    required this.player,
    required this.videoController,
  });

  final Player player;
  final VideoController videoController;

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
                  child: Video(controller: widget.videoController),
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
