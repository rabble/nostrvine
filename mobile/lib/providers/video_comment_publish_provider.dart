// ABOUTME: Riverpod provider for VideoCommentPublishService.
// ABOUTME: Composes BlossomUploadService + CommentsRepository dependencies.

import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/video_comment_publish_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'video_comment_publish_provider.g.dart';

/// Provider for [VideoCommentPublishService].
///
/// Composes [BlossomUploadService] and [CommentsRepository]
/// to enable uploading and posting video comments.
@Riverpod(keepAlive: true)
VideoCommentPublishService videoCommentPublishService(Ref ref) {
  final blossomService = ref.watch(blossomUploadServiceProvider);
  final commentsRepo = ref.watch(commentsRepositoryProvider);

  return VideoCommentPublishService(
    blossomUploadService: blossomService,
    commentsRepository: commentsRepo,
  );
}
