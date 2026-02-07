import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

class VideoEditorThumbnail extends ConsumerWidget {
  const VideoEditorThumbnail({
    required this.contentSize,
    this.isInitialized = false,
  });

  final bool isInitialized;
  final Size contentSize;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clip = ref.watch(clipManagerProvider.select((s) => s.clips.first));

    return AnimatedOpacity(
      duration: const Duration(milliseconds: 100),
      opacity: isInitialized ? 0.0 : 1.0,
      child: FittedBox(
        fit: .cover,
        child: clip.thumbnailPath != null
            ? Image.file(File(clip.thumbnailPath!))
            : SizedBox.fromSize(
                size: contentSize,
                child: const Center(
                  child: CircularProgressIndicator(color: VineTheme.primary),
                ),
              ),
      ),
    );
  }
}
