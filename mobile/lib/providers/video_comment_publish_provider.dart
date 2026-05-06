// ABOUTME: Provider for the service that publishes video comment replies.
// ABOUTME: Keeps upload and comment repository wiring out of UI widgets.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_comment_publish_service.dart';

final videoCommentPublishServiceProvider = Provider<VideoCommentPublishService>(
  (ref) => VideoCommentPublishService(
    blossomUploadService: ref.watch(blossomUploadServiceProvider),
    commentsRepository: ref.watch(commentsRepositoryProvider),
  ),
);
