// ABOUTME: Navigation helper to open the metadata edit screen for a video.
// ABOUTME: Preserves edit navigation after deleting the legacy share menu.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/screens/video_metadata/video_metadata_edit_screen.dart';

/// Public helper to show the edit screen for a video from anywhere.
void showEditDialogForVideo(BuildContext context, VideoEvent video) {
  context.push(VideoMetadataEditScreen.pathFor(video.id), extra: video);
}
