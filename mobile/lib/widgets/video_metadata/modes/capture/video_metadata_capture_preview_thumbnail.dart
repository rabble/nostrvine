import 'dart:io';
import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_image_editor/features/filter_editor/widgets/filter_generator.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

class VideoMetadataCapturePreviewThumbnail extends ConsumerWidget {
  const VideoMetadataCapturePreviewThumbnail({
    required this.clip,
    super.key,
  });

  final DivineVideoClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editingParameters = ref.watch(
      videoEditorProvider.select((s) => s.editorEditingParameters),
    );

    if (clip.thumbnailPath == null) {
      return const Center(
        child: DivineIcon(
          icon: .warning,
          size: 32,
          color: VineTheme.lightText,
        ),
      );
    }

    final thumbnail = Image.file(
      File(clip.thumbnailPath!),
      fit: .cover,
    );

    return Stack(
      fit: .expand,
      children: [
        thumbnail,
        _EditedPreviewOverlay(
          editingParameters: editingParameters,
          thumbnail: thumbnail,
        ),
      ],
    );
  }
}

class _EditedPreviewOverlay extends StatefulWidget {
  const _EditedPreviewOverlay({
    required this.editingParameters,
    required this.thumbnail,
  });

  final CompleteParameters? editingParameters;
  final Widget thumbnail;

  @override
  State<_EditedPreviewOverlay> createState() => _EditedPreviewOverlayState();
}

class _EditedPreviewOverlayState extends State<_EditedPreviewOverlay> {
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
    final params = widget.editingParameters;

    return AnimatedSwitcher(
      duration: _switchDuration,
      child: params == null
          ? const SizedBox.shrink()
          : LayoutBuilder(
              builder: (context, constraints) {
                final targetSize = constraints.biggest;
                final bodySize = params.bodySize;
                final hasValidBodySize =
                    bodySize != null &&
                    bodySize.width > 0 &&
                    bodySize.height > 0;
                final sourceSize = hasValidBodySize ? bodySize : targetSize;
                final sourceCenter = Offset(
                  sourceSize.width / 2,
                  sourceSize.height / 2,
                );
                final fittedSizes = applyBoxFit(
                  BoxFit.cover,
                  sourceSize,
                  targetSize,
                );
                final sourceRect = Alignment.center.inscribe(
                  fittedSizes.source,
                  Offset.zero & sourceSize,
                );
                final destinationRect = Alignment.center.inscribe(
                  fittedSizes.destination,
                  Offset.zero & targetSize,
                );
                final coverScaleX = destinationRect.width / sourceRect.width;
                final coverScaleY = destinationRect.height / sourceRect.height;

                return Stack(
                  alignment: .center,
                  fit: .expand,
                  children: [
                    ColorFilterGenerator(
                      playTimeNotifier: _playTimeNotifier,
                      filters: const [],
                      filterStates: params.filterStates,
                      tuneAdjustments: params.tuneAdjustments,
                      child: widget.thumbnail,
                    ),
                    for (final item in params.capturedLayers)
                      if (item.layer.startTime == null ||
                          item.layer.startTime! < _firstFrameSpan)
                        _PositionedLayer(
                          bytes: item.bytes,
                          logicalSize: item.logicalSize,
                          layerOffset: item.layer.offset,
                          sourceCenter: sourceCenter,
                          sourceRect: sourceRect,
                          destinationRect: destinationRect,
                          coverScaleX: coverScaleX,
                          coverScaleY: coverScaleY,
                        ),
                  ],
                );
              },
            ),
    );
  }
}

class _PositionedLayer extends StatelessWidget {
  const _PositionedLayer({
    required this.bytes,
    required this.logicalSize,
    required this.layerOffset,
    required this.sourceCenter,
    required this.sourceRect,
    required this.destinationRect,
    required this.coverScaleX,
    required this.coverScaleY,
  });

  final Uint8List bytes;
  final Size logicalSize;
  final Offset layerOffset;
  final Offset sourceCenter;
  final Rect sourceRect;
  final Rect destinationRect;
  final double coverScaleX;
  final double coverScaleY;

  @override
  Widget build(BuildContext context) {
    final sourcePosition = Offset(
      layerOffset.dx + sourceCenter.dx,
      layerOffset.dy + sourceCenter.dy,
    );
    final destinationPosition = Offset(
      destinationRect.left +
          (sourcePosition.dx - sourceRect.left) * coverScaleX,
      destinationRect.top + (sourcePosition.dy - sourceRect.top) * coverScaleY,
    );

    return Positioned(
      left: destinationPosition.dx,
      top: destinationPosition.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Image.memory(
          bytes,
          width: logicalSize.width * coverScaleX,
          height: logicalSize.height * coverScaleY,
        ),
      ),
    );
  }
}
