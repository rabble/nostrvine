// ABOUTME: Service for uploading and publishing video comment replies.
// ABOUTME: Orchestrates Blossom upload → imeta tag build → comment posting.

import 'dart:io';

import 'package:comments_repository/comments_repository.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Result of a video comment publish operation.
class VideoCommentPublishResult {
  /// Creates a successful result.
  const VideoCommentPublishResult.success(this.comment) : error = null;

  /// Creates a failed result.
  const VideoCommentPublishResult.failure(this.error) : comment = null;

  /// The published comment, if successful.
  final Comment? comment;

  /// The error message, if failed.
  final String? error;

  /// Whether the publish was successful.
  bool get isSuccess => comment != null;
}

/// Service that orchestrates uploading a video to Blossom
/// and posting it as a NIP-22 comment with NIP-92 imeta metadata.
///
/// This is separate from [VideoPublishService] which creates
/// Kind 34236 video events with d-tags and NIP-71 structure.
class VideoCommentPublishService {
  /// Creates a new video comment publish service.
  VideoCommentPublishService({
    required BlossomUploadService blossomUploadService,
    required CommentsRepository commentsRepository,
  }) : _blossomUploadService = blossomUploadService,
       _commentsRepository = commentsRepository;

  final BlossomUploadService _blossomUploadService;
  final CommentsRepository _commentsRepository;

  /// Uploads a video file and posts it as a comment.
  ///
  /// Flow: upload video to Blossom → build NIP-92 imeta tag →
  /// post Kind 1111 comment via CommentsRepository.
  ///
  /// Parameters:
  /// - [videoFilePath]: Path to the video file to upload
  /// - [content]: Optional text content for the comment
  /// - [rootEventId]: The root event being replied to
  /// - [rootEventKind]: Kind of the root event
  /// - [rootEventAuthorPubkey]: Author of the root event
  /// - [nostrPubkey]: Current user's pubkey for Blossom auth
  /// - [rootAddressableId]: Optional addressable ID for the root
  /// - [parentCommentId]: Optional parent comment ID for threading
  /// - [parentAuthorPubkey]: Optional parent comment author
  /// - [onProgress]: Optional upload progress callback (0.0-1.0)
  ///
  /// Returns a [VideoCommentPublishResult] with the comment or error.
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
      // 1. Upload video to Blossom
      Log.info(
        'Uploading video comment to Blossom',
        name: 'VideoCommentPublishService',
      );

      final uploadResult = await _blossomUploadService.uploadVideo(
        videoFile: File(videoFilePath),
        nostrPubkey: nostrPubkey,
        title: '',
        proofManifestJson: null,
        description: null,
        hashtags: null,
        onProgress: onProgress,
      );

      if (!uploadResult.success || uploadResult.cdnUrl == null) {
        final errorMsg = uploadResult.errorMessage ?? 'Upload failed';
        Log.error(
          'Blossom upload failed: $errorMsg',
          name: 'VideoCommentPublishService',
        );
        return VideoCommentPublishResult.failure(errorMsg);
      }

      // 2. Build NIP-92 imeta tag entries
      final imetaTag = _buildImetaTag(uploadResult);

      // 3. Build content: include video URL per NIP-92 spec
      final videoUrl = uploadResult.cdnUrl!;
      final commentContent = content.isEmpty ? videoUrl : '$content $videoUrl';

      // 4. Post the comment with imeta tag
      Log.info(
        'Posting video comment to Nostr',
        name: 'VideoCommentPublishService',
      );

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

      Log.info(
        'Video comment published successfully: '
        '${comment.id}',
        name: 'VideoCommentPublishService',
      );

      return VideoCommentPublishResult.success(comment);
    } on Exception catch (e) {
      Log.error(
        'Failed to publish video comment: $e',
        name: 'VideoCommentPublishService',
      );
      return VideoCommentPublishResult.failure(
        'Failed to publish video comment: $e',
      );
    }
  }

  /// Builds NIP-92 imeta tag entries from a Blossom upload result.
  List<String> _buildImetaTag(BlossomUploadResult upload) {
    final entries = <String>[];

    // Primary video URL
    final videoUrl = upload.cdnUrl;
    if (videoUrl != null) {
      entries.add('url $videoUrl');
    }

    // MIME type
    entries.add('m video/mp4');

    // Thumbnail
    if (upload.thumbnailUrl != null && _isHttpUrl(upload.thumbnailUrl)) {
      entries.add('image ${upload.thumbnailUrl}');
    }

    // SHA-256 hash (videoId is the hash)
    if (upload.videoId != null) {
      entries.add('x ${upload.videoId}');
    }

    return entries;
  }

  bool _isHttpUrl(String? url) =>
      url != null && (url.startsWith('https://') || url.startsWith('http://'));
}
