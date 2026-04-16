import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_image_editor/features/filter_editor/widgets/filter_generator.dart';

class VideoMetadataCapturePreviewThumbnail extends ConsumerStatefulWidget {
  const VideoMetadataCapturePreviewThumbnail({required this.clip, super.key});

  final DivineVideoClip clip;

  @override
  ConsumerState<VideoMetadataCapturePreviewThumbnail> createState() =>
      _VideoMetadataCapturePreviewThumbnailState();
}

class _VideoMetadataCapturePreviewThumbnailState
    extends ConsumerState<VideoMetadataCapturePreviewThumbnail> {
  static const _firstFrameSpan = Duration(milliseconds: 10);
  static const _switchDuration = Duration(milliseconds: 240);

  final ValueNotifier<Duration> _playTimeNotifier = ValueNotifier(.zero);

  @override
  void dispose() {
    _playTimeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final editingParameters = ref.watch(
      videoEditorProvider.select((s) => s.editorEditingParameters),
    );

    if (widget.clip.thumbnailPath == null) {
      return const Center(
        child: DivineIcon(
          icon: .warning,
          size: 32,
          color: VineTheme.lightText,
        ),
      );
    }

    final thumbnail = Image.file(File(widget.clip.thumbnailPath!), fit: .cover);

    return Stack(
      fit: .expand,
      children: [
        thumbnail,
        AnimatedSwitcher(
          duration: _switchDuration,
          child: editingParameters == null
              ? const SizedBox.shrink()
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final targetSize = constraints.biggest;
                    final bodySize = editingParameters.bodySize;
                    final hasValidBodySize =
                        bodySize != null &&
                        bodySize.width > 0 &&
                        bodySize.height > 0;
                    final sourceSize = hasValidBodySize ? bodySize : targetSize;
                    final scaleX = targetSize.width / sourceSize.width;
                    final scaleY = targetSize.height / sourceSize.height;
                    final sourceCenter = Offset(
                      sourceSize.width / 2,
                      sourceSize.height / 2,
                    );

                    return Stack(
                      alignment: .center,
                      fit: .expand,
                      children: [
                        ColorFilterGenerator(
                          playTimeNotifier: _playTimeNotifier,
                          filters: const [],
                          filterStates: editingParameters.filterStates,
                          tuneAdjustments: editingParameters.tuneAdjustments,
                          child: thumbnail,
                        ),

                        for (final item in editingParameters.capturedLayers)
                          if (item.layer.startTime == null ||
                              item.layer.startTime! < _firstFrameSpan)
                            Positioned(
                              left:
                                  (item.layer.offset.dx + sourceCenter.dx) *
                                  scaleX,
                              top:
                                  (item.layer.offset.dy + sourceCenter.dy) *
                                  scaleY,
                              child: FractionalTranslation(
                                translation: const Offset(-0.5, -0.5),
                                child: Image.memory(
                                  item.bytes,
                                  width: item.logicalSize.width * scaleX,
                                  height: item.logicalSize.height * scaleY,
                                ),
                              ),
                            ),
                      ],
                    );
                  },
                ),
        ),
      ],
    );
  }
}
