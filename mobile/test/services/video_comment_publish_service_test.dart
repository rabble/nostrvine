// ABOUTME: Tests publishing recorded clips as NIP-22 video comments.
// ABOUTME: Verifies Blossom upload output is forwarded as NIP-92 imeta.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/video_comment_publish_service.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  late _MockBlossomUploadService blossomUploadService;
  late _MockCommentsRepository commentsRepository;
  late VideoCommentPublishService service;

  setUpAll(() {
    registerFallbackValue(File('/tmp/video-reply.mp4'));
  });

  setUp(() {
    blossomUploadService = _MockBlossomUploadService();
    commentsRepository = _MockCommentsRepository();
    service = VideoCommentPublishService(
      blossomUploadService: blossomUploadService,
      commentsRepository: commentsRepository,
    );
  });

  test(
    'publishes uploaded clip as a video comment with imeta metadata',
    () async {
      final postedComment = Comment(
        id: 'comment-id',
        content: 'https://cdn.divine.video/reply.mp4',
        authorPubkey: 'b' * 64,
        createdAt: DateTime.utc(2026),
        rootEventId: 'root-event-id',
        rootAuthorPubkey: 'a' * 64,
        replyToEventId: 'parent-comment-id',
        replyToAuthorPubkey: 'c' * 64,
        videoUrl: 'https://cdn.divine.video/reply.mp4',
        thumbnailUrl: 'https://cdn.divine.video/reply.jpg',
        videoBlurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
      );

      when(
        () => blossomUploadService.uploadVideo(
          videoFile: any(named: 'videoFile'),
          nostrPubkey: any(named: 'nostrPubkey'),
          title: any(named: 'title'),
          proofManifestJson: any(named: 'proofManifestJson'),
          description: any(named: 'description'),
          hashtags: any(named: 'hashtags'),
          onProgress: any(named: 'onProgress'),
        ),
      ).thenAnswer(
        (_) async => const BlossomUploadResult(
          success: true,
          videoId: 'video-sha256',
          fallbackUrl: 'https://cdn.divine.video/reply.mp4',
          thumbnailUrl: 'https://cdn.divine.video/reply.jpg',
          blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        ),
      );
      when(
        () => commentsRepository.postComment(
          content: any(named: 'content'),
          rootEventId: any(named: 'rootEventId'),
          rootEventKind: any(named: 'rootEventKind'),
          rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
          rootAddressableId: any(named: 'rootAddressableId'),
          replyToEventId: any(named: 'replyToEventId'),
          replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
          imetaTag: any(named: 'imetaTag'),
        ),
      ).thenAnswer((_) async => postedComment);

      final result = await service.publishVideoComment(
        videoFilePath: '/tmp/video-reply.mp4',
        rootEventId: 'root-event-id',
        rootEventKind: 22,
        rootEventAuthorPubkey: 'a' * 64,
        nostrPubkey: 'b' * 64,
        rootAddressableId: '22:pubkey:identifier',
        parentCommentId: 'parent-comment-id',
        parentAuthorPubkey: 'c' * 64,
      );

      expect(result.isSuccess, isTrue);
      expect(result.comment, postedComment);
      verify(
        () => commentsRepository.postComment(
          content: 'https://cdn.divine.video/reply.mp4',
          rootEventId: 'root-event-id',
          rootEventKind: 22,
          rootEventAuthorPubkey: 'a' * 64,
          rootAddressableId: '22:pubkey:identifier',
          replyToEventId: 'parent-comment-id',
          replyToAuthorPubkey: 'c' * 64,
          imetaTag: [
            'url https://cdn.divine.video/reply.mp4',
            'm video/mp4',
            'image https://cdn.divine.video/reply.jpg',
            'x video-sha256',
            'blurhash LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          ],
        ),
      ).called(1);
    },
  );

  test('returns failure without posting when Blossom upload fails', () async {
    when(
      () => blossomUploadService.uploadVideo(
        videoFile: any(named: 'videoFile'),
        nostrPubkey: any(named: 'nostrPubkey'),
        title: any(named: 'title'),
        proofManifestJson: any(named: 'proofManifestJson'),
        description: any(named: 'description'),
        hashtags: any(named: 'hashtags'),
        onProgress: any(named: 'onProgress'),
      ),
    ).thenAnswer(
      (_) async => const BlossomUploadResult(
        success: false,
        errorMessage: 'no upload',
      ),
    );

    final result = await service.publishVideoComment(
      videoFilePath: '/tmp/video-reply.mp4',
      rootEventId: 'root-event-id',
      rootEventKind: 22,
      rootEventAuthorPubkey: 'a' * 64,
      nostrPubkey: 'b' * 64,
    );

    expect(result.isSuccess, isFalse);
    expect(result.error, 'no upload');
    verifyNever(
      () => commentsRepository.postComment(
        content: any(named: 'content'),
        rootEventId: any(named: 'rootEventId'),
        rootEventKind: any(named: 'rootEventKind'),
        rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
        rootAddressableId: any(named: 'rootAddressableId'),
        replyToEventId: any(named: 'replyToEventId'),
        replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
        imetaTag: any(named: 'imetaTag'),
      ),
    );
  });
}
