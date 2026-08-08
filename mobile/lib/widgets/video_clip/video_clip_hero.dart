// ABOUTME: Shared Hero helpers for video clip grid-to-preview transitions
// ABOUTME: Keeps tags and decorative fallback thumbnails consistent

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

String videoClipPreviewHeroTag(String clipId) => 'Video-Clip-Preview-$clipId';

class VideoClipThumbnailPlaceholder extends StatelessWidget {
  const VideoClipThumbnailPlaceholder({super.key});

  @override
  Widget build(BuildContext context) {
    return DivineIcon(
      icon: DivineIconName.videoCamera,
      color: context.vineColors.mutedText,
      size: 32,
    );
  }
}
