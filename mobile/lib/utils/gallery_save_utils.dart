import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/services/video_editor/stop_motion_render_service.dart';
import 'package:openvine/widgets/gallery_permission_sheet.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show RenderCanceledException;

/// Saves the final rendered video to the device gallery.
///
/// When gallery permission is denied and the user has not previously
/// opted out, a bottom sheet is shown offering to open Settings or
/// dismiss forever. If the user opens Settings and comes back, the
/// save is retried once.
Future<void> saveToGallery(BuildContext context, WidgetRef ref) async {
  // User opted out of gallery saves permanently.
  if (await isGalleryPermissionDismissedForever()) return;

  final finalRenderedClip = ref.read(videoEditorProvider).finalRenderedClip;
  if (finalRenderedClip == null) return;

  DivineVideoClip? materialized;
  try {
    // Stop-motion clips render their mp4 on demand; a normal clip passes through.
    try {
      materialized = await StopMotionRenderService.materialize(
        finalRenderedClip,
      );
    } on RenderCanceledException {
      return;
    }
    if (materialized == null || !context.mounted) return;
    final video = materialized.requireVideo;

    final gallerySaveService = ref.read(gallerySaveServiceProvider);
    final result = await gallerySaveService.saveVideoToGallery(video);

    if (result is! GallerySavePermissionDenied || !context.mounted) {
      return;
    }

    // Permission denied — show an actionable sheet instead of a snackbar.
    final permissionsService = ref.read(permissionsServiceProvider);
    final choice = await showGalleryPermissionSheet(
      context,
      permissionsService: permissionsService,
    );

    if (choice == GalleryPermissionChoice.openedSettings ||
        choice == GalleryPermissionChoice.granted) {
      // Retry once — the user may have just granted access.
      await gallerySaveService.saveVideoToGallery(video);
    }
  } finally {
    await StopMotionRenderService.cleanupMaterializedOutput(
      sourceClip: finalRenderedClip,
      materializedClip: materialized,
    );
  }
}
