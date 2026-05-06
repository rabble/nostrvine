// ABOUTME: Publishes recorded videos as NIP-22 comments with NIP-92 imeta metadata.
// ABOUTME: Uses Blossom upload output instead of creating a standalone video event.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:unified_logger/unified_logger.dart';

class VideoCommentPublishResult {
  const VideoCommentPublishResult.success(this.comment) : error = null;

  const VideoCommentPublishResult.failure(this.error) : comment = null;

  final Comment? comment;
  final String? error;

  bool get isSuccess => comment != null;
}

class VideoCommentPublishService {
  VideoCommentPublishService({
    required BlossomUploadService blossomUploadService,
    required CommentsRepository commentsRepository,
  }) : _blossomUploadService = blossomUploadService,
       _commentsRepository = commentsRepository;

  final BlossomUploadService _blossomUploadService;
  final CommentsRepository _commentsRepository;

  Future<VideoCommentPublishResult> publishVideoComment({
    required String videoFilePath,
    required String rootEventId,
    required int rootEventKind,
    required String rootEventAuthorPubkey,
    required String nostrPubkey,
    String content = '',
    String? rootAddressableId,
    String? parentCommentId,
    String? parentAuthorPubkey,
    void Function(double)? onProgress,
  }) async {
    try {
      final upload = await _blossomUploadService.uploadVideo(
        videoFile: File(videoFilePath),
        nostrPubkey: nostrPubkey,
        title: '',
        proofManifestJson: null,
        description: null,
        hashtags: null,
        onProgress: onProgress,
      );

      final videoUrl = upload.cdnUrl;
      if (!upload.success || videoUrl == null || videoUrl.isEmpty) {
        return VideoCommentPublishResult.failure(
          upload.errorMessage ?? 'Video upload failed',
        );
      }

      final imetaTag = _buildImetaTag(upload);
      final trimmedContent = content.trim();
      final commentContent = trimmedContent.isEmpty
          ? videoUrl
          : '$trimmedContent $videoUrl';

      final comment = await _commentsRepository.postComment(
        content: commentContent,
        rootEventId: rootEventId,
        rootEventKind: rootEventKind,
        rootEventAuthorPubkey: rootEventAuthorPubkey,
        rootAddressableId: rootAddressableId,
        replyToEventId: parentCommentId,
        replyToAuthorPubkey: parentAuthorPubkey,
        imetaTag: imetaTag,
      );

      return VideoCommentPublishResult.success(comment);
    } on Exception catch (error, stackTrace) {
      Log.error(
        'Failed to publish video comment: $error',
        name: 'VideoCommentPublishService',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      return VideoCommentPublishResult.failure(error.toString());
    }
  }

  List<String> _buildImetaTag(BlossomUploadResult upload) {
    final entries = <String>[];
    final videoUrl = upload.cdnUrl;
    if (videoUrl != null && videoUrl.isNotEmpty) entries.add('url $videoUrl');
    entries.add('m video/mp4');
    if (_isHttpUrl(upload.thumbnailUrl)) {
      entries.add('image ${upload.thumbnailUrl}');
    }
    if (upload.videoId != null && upload.videoId!.isNotEmpty) {
      entries.add('x ${upload.videoId}');
    }
    if (upload.blurhash != null && upload.blurhash!.isNotEmpty) {
      entries.add('blurhash ${upload.blurhash}');
    }
    return entries;
  }

  bool _isHttpUrl(String? url) =>
      url != null && (url.startsWith('https://') || url.startsWith('http://'));
}
