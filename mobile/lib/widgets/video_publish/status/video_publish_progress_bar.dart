import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:divine_ui/divine_ui.dart';

class VideoPublishProgressBar extends ConsumerWidget {
  const VideoPublishProgressBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(
      videoPublishProvider.select((s) => s.uploadProgress),
    );
    final percentage = (progress * 100).toStringAsFixed(0);

    return Column(
      spacing: 8,
      children: [
        ClipRRect(
          borderRadius: .circular(4),
          child: LinearProgressIndicator(
            value: progress,
            backgroundColor: const Color(0xFF424242),
            valueColor: const AlwaysStoppedAnimation<Color>(
              VineTheme.vineGreen,
            ),
            minHeight: 6,
          ),
        ),
        Text(
          '$percentage%',
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
      ],
    );
  }
}
