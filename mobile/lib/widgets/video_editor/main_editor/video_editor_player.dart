import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/platform_io.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:video_player/video_player.dart';

class VideoEditorPlayer extends ConsumerStatefulWidget {
  const VideoEditorPlayer({super.key, required this.controller});

  final VideoPlayerController controller;

  @override
  ConsumerState<VideoEditorPlayer> createState() => _VideoEditorPlayerState();
}

class _VideoEditorPlayerState extends ConsumerState<VideoEditorPlayer> {
  bool _isInitialized = true;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return ClipRRect(
          borderRadius: const .all(.circular(32)),
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
              AnimatedOpacity(
                duration: const Duration(milliseconds: 100),
                opacity: _isInitialized ? 0.0 : 1.0,
                child: FittedBox(
                  fit: .cover,
                  child: _ThumbnailContent(constraints: constraints),
                ),
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

class _ThumbnailContent extends ConsumerWidget {
  const _ThumbnailContent({required this.constraints});

  final BoxConstraints constraints;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));

    if (clip.thumbnailPath != null) {
      return Image.file(File(clip.thumbnailPath!));
    }

    // Fallback loader
    return SizedBox.fromSize(
      size: constraints.biggest,
      child: const Center(
        child: CircularProgressIndicator(color: VineTheme.primary),
      ),
    );
  }
}
