import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/recording_clip.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:pro_image_editor/features/filter_editor/widgets/filter_generator.dart';

class VideoMetadataPreviewThumbnail extends ConsumerWidget {
  const VideoMetadataPreviewThumbnail({required this.clip});

  final RecordingClip clip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editingParameters = ref.watch(
      videoEditorProvider.select((s) => s.editorEditingParameters),
    );

    if (clip.thumbnailPath == null) {
      return const Center(
        child: Icon(Icons.broken_image, size: 32, color: Colors.grey),
      );
    }

    final thumbnail = Image.file(File(clip.thumbnailPath!), fit: .cover);

    if (editingParameters == null) {
      return thumbnail;
    }

    return Stack(
      alignment: .center,
      fit: .expand,
      children: [
        ColorFilterGenerator(
          filters: editingParameters.colorFilters,
          tuneAdjustments: const [],
          child: thumbnail,
        ),
        // Overlay the layers
        if (editingParameters.image.isNotEmpty)
          Image.memory(editingParameters.image, fit: .cover),
      ],
    );
  }
}
