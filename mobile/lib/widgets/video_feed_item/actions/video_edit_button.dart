// ABOUTME: Edit button for video feed overlay.
// ABOUTME: Only shown for owned videos when feature flag is enabled.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/share_video_menu.dart';

/// Edit button shown only for owned videos when feature flag is enabled.
///
/// This widget checks:
/// 1. Feature flag `enableVideoEditorV1` is enabled
/// 2. Current user owns the video
///
/// If both conditions are met, displays an edit button that opens the
/// video edit dialog.
class VideoEditButton extends ConsumerWidget {
  const VideoEditButton({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Check feature flag
    final featureFlagService = ref.watch(featureFlagServiceProvider);
    final isEditorEnabled = featureFlagService.isEnabled(
      FeatureFlag.enableVideoEditorV1,
    );

    if (!isEditorEnabled) {
      return const SizedBox.shrink();
    }

    // Check ownership
    final authService = ref.watch(authServiceProvider);
    final currentUserPubkey = authService.currentPublicKeyHex;
    final isOwnVideo =
        currentUserPubkey != null && currentUserPubkey == video.pubkey;

    if (!isOwnVideo) {
      return const SizedBox.shrink();
    }

    // Show edit button
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 16),
        IconButton(
          onPressed: () {
            Log.info(
              '✏️ Edit button tapped for ${video.id}',
              name: 'VideoEditButton',
              category: LogCategory.ui,
            );

            // Show edit dialog directly (works on all platforms)
            showEditDialogForVideo(context, video);
          },
          tooltip: 'Edit video',
          icon: const Icon(Icons.edit, color: Colors.white, size: 32),
        ),
      ],
    );
  }
}
