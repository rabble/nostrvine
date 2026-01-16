// ABOUTME: Share action button for video feed overlay.
// ABOUTME: Displays share icon with label, shows share menu bottom sheet.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/active_video_provider.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/circular_icon_button.dart';
import 'package:openvine/widgets/share_video_menu.dart';

/// Share action button with label for video overlay.
///
/// Shows a share icon that opens the share menu bottom sheet.
/// Pauses video while menu is open and resumes when closed.
class ShareActionButton extends ConsumerWidget {
  const ShareActionButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: 'share_button',
          container: true,
          explicitChildNodes: true,
          button: true,
          label: 'Share video',
          child: CircularIconButton(
            onPressed: () {
              Log.info(
                '📤 Share button tapped for ${video.id}',
                name: 'ShareActionButton',
                category: LogCategory.ui,
              );
              _showShareMenu(context, ref);
            },
            icon: const Icon(
              Icons.share_outlined,
              color: Colors.white,
              size: 32,
            ),
          ),
        ),
        const SizedBox(height: 0),
        const Text(
          'Share',
          style: TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(offset: Offset(0, 0), blurRadius: 6, color: Colors.black),
              Shadow(offset: Offset(1, 1), blurRadius: 3, color: Colors.black),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _showShareMenu(BuildContext context, WidgetRef ref) async {
    // Pause video before showing share menu
    bool wasPaused = false;
    try {
      final controllerParams = VideoControllerParams(
        videoId: video.id,
        videoUrl: video.videoUrl!,
        videoEvent: video,
      );
      final controller = ref.read(
        individualVideoControllerProvider(controllerParams),
      );
      if (controller.value.isInitialized && controller.value.isPlaying) {
        wasPaused = await safePause(controller, video.id);
        if (wasPaused) {
          Log.info(
            '🎬 Paused video for share menu',
            name: 'ShareActionButton',
            category: LogCategory.ui,
          );
        }
      }
    } catch (e) {
      final errorStr = e.toString().toLowerCase();
      if (!errorStr.contains('no active player') &&
          !errorStr.contains('disposed')) {
        Log.error(
          'Failed to pause video for share menu: $e',
          name: 'ShareActionButton',
          category: LogCategory.ui,
        );
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ShareVideoMenu(video: video),
    );

    // Resume video after share menu closes if it was playing
    if (wasPaused) {
      try {
        final controllerParams = VideoControllerParams(
          videoId: video.id,
          videoUrl: video.videoUrl!,
          videoEvent: video,
        );
        final controller = ref.read(
          individualVideoControllerProvider(controllerParams),
        );
        final stableId = video.vineId ?? video.id;
        final isActive = ref.read(isVideoActiveProvider(stableId));

        if (isActive &&
            controller.value.isInitialized &&
            !controller.value.isPlaying) {
          final resumed = await safePlay(controller, video.id);
          if (resumed) {
            Log.info(
              '🎬 Resumed video after share menu closed',
              name: 'ShareActionButton',
              category: LogCategory.ui,
            );
          }
        }
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (!errorStr.contains('no active player') &&
            !errorStr.contains('disposed')) {
          Log.error(
            'Failed to resume video after share menu: $e',
            name: 'ShareActionButton',
            category: LogCategory.ui,
          );
        }
      }
    }
  }
}
