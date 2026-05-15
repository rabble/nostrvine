// ABOUTME: Screen wrapper for the full-screen video metadata edit flow.

import 'package:flutter/material.dart';
import 'package:models/models.dart' show VideoEvent;
import 'package:openvine/widgets/video_metadata/modes/edit/video_metadata_edit_stack.dart';

/// Screen entry-point for editing an already-published [VideoEvent].
///
/// TODO(#4390): Switch this route to an ID-based resolver so it can be
/// deep-linked and restored without relying on GoRouter [extra].
///
/// Navigate to this screen by pushing [path] with [extra] set to the
/// [VideoEvent] to edit:
/// ```dart
/// context.push(VideoMetadataEditScreen.path, extra: video);
/// ```
class VideoMetadataEditScreen extends StatelessWidget {
  static const routeName = 'video-edit';
  static const path = '/video-edit';

  const VideoMetadataEditScreen({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) => VideoMetadataEditStack(video: video);
}
