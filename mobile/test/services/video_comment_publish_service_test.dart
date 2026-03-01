// ABOUTME: Tests for VideoCommentPublishService.
// ABOUTME: Validates video upload → imeta tag build → comment posting flow.

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/blossom_upload_service.dart';
import 'package:openvine/services/video_comment_publish_service.dart';

class _MockBlossomUploadService extends Mock implements BlossomUploadService {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

void main() {
  group(VideoCommentPublishService, () {
    late _MockBlossomUploadService mockBlossomService;
    late _MockCommentsRepository mockCommentsRepo;
    late VideoCommentPublishService service;

    const testRootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testRootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb'
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testUserPubkey =
        'cccccccccccccccccccccccccccccccccc'
        'cccccccccccccccccccccccccccccc';
    const testRootEventKind = 34236;

    setUp(() {
      mockBlossomService = _MockBlossomUploadService();
      mockCommentsRepo = _MockCommentsRepository();
      service = VideoCommentPublishService(
        blossomUploadService: mockBlossomService,
        commentsRepository: mockCommentsRepo,
      );
    });

    group('publishVideoComment', () {
      test('uploads video and posts comment on success', () async {
        when(
          () => mockBlossomService.uploadVideo(
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
            videoId: 'abc123hash',
            fallbackUrl: 'https://cdn.example.com/video.mp4',
            thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
          ),
        );

        when(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).thenAnswer(
          (_) async => Comment(
            id: 'comment_event_id',
            content: 'https://cdn.example.com/video.mp4',
            authorPubkey: testUserPubkey,
            createdAt: DateTime(2024),
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            videoUrl: 'https://cdn.example.com/video.mp4',
          ),
        );

        final result = await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
        );

        expect(result.isSuccess, isTrue);
        expect(result.comment, isNotNull);
        expect(result.comment!.hasVideo, isTrue);

        verify(
          () => mockBlossomService.uploadVideo(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            proofManifestJson: any(named: 'proofManifestJson'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            onProgress: any(named: 'onProgress'),
          ),
        ).called(1);

        verify(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).called(1);
      });

      test('returns failure when upload fails', () async {
        when(
          () => mockBlossomService.uploadVideo(
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
            errorMessage: 'Server unavailable',
          ),
        );

        final result = await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('Server unavailable'));

        verifyNever(
          () => mockCommentsRepo.postComment(
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

      test('returns failure when upload has no URL', () async {
        when(
          () => mockBlossomService.uploadVideo(
            videoFile: any(named: 'videoFile'),
            nostrPubkey: any(named: 'nostrPubkey'),
            title: any(named: 'title'),
            proofManifestJson: any(named: 'proofManifestJson'),
            description: any(named: 'description'),
            hashtags: any(named: 'hashtags'),
            onProgress: any(named: 'onProgress'),
          ),
        ).thenAnswer(
          (_) async => const BlossomUploadResult(success: true),
        );

        final result = await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, equals('Upload failed'));
      });

      test('includes text content with video URL', () async {
        when(
          () => mockBlossomService.uploadVideo(
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
            fallbackUrl: 'https://cdn.example.com/video.mp4',
          ),
        );

        when(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).thenAnswer(
          (_) async => Comment(
            id: 'comment_event_id',
            content:
                'Check this! '
                'https://cdn.example.com/video.mp4',
            authorPubkey: testUserPubkey,
            createdAt: DateTime(2024),
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
          ),
        );

        await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          content: 'Check this!',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
        );

        final captured = verify(
          () => mockCommentsRepo.postComment(
            content: captureAny(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).captured;

        expect(
          captured.first,
          equals(
            'Check this! '
            'https://cdn.example.com/video.mp4',
          ),
        );
      });

      test('passes imeta tag with correct entries', () async {
        when(
          () => mockBlossomService.uploadVideo(
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
            videoId: 'sha256hash',
            fallbackUrl: 'https://cdn.example.com/video.mp4',
            thumbnailUrl: 'https://cdn.example.com/thumb.jpg',
          ),
        );

        when(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).thenAnswer(
          (_) async => Comment(
            id: 'comment_event_id',
            content: 'https://cdn.example.com/video.mp4',
            authorPubkey: testUserPubkey,
            createdAt: DateTime(2024),
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
          ),
        );

        await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
        );

        final captured = verify(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: captureAny(named: 'imetaTag'),
          ),
        ).captured;

        final imetaTag = captured.first as List<String>;
        expect(
          imetaTag,
          contains('url https://cdn.example.com/video.mp4'),
        );
        expect(imetaTag, contains('m video/mp4'));
        expect(
          imetaTag,
          contains(
            'image '
            'https://cdn.example.com/thumb.jpg',
          ),
        );
        expect(imetaTag, contains('x sha256hash'));
      });

      test('returns failure when postComment throws', () async {
        when(
          () => mockBlossomService.uploadVideo(
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
            fallbackUrl: 'https://cdn.example.com/video.mp4',
          ),
        );

        when(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).thenThrow(
          const PostCommentFailedException('Network error'),
        );

        final result = await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
        );

        expect(result.isSuccess, isFalse);
        expect(result.error, isNotNull);
      });

      test('passes threading parameters for replies', () async {
        const parentCommentId =
            'dddddddddddddddddddddddddddddddd'
            'dddddddddddddddddddddddddddddd';
        const parentAuthorPubkey =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeee';

        when(
          () => mockBlossomService.uploadVideo(
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
            fallbackUrl: 'https://cdn.example.com/video.mp4',
          ),
        );

        when(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: any(named: 'replyToEventId'),
            replyToAuthorPubkey: any(named: 'replyToAuthorPubkey'),
            imetaTag: any(named: 'imetaTag'),
          ),
        ).thenAnswer(
          (_) async => Comment(
            id: 'reply_comment_id',
            content: 'https://cdn.example.com/video.mp4',
            authorPubkey: testUserPubkey,
            createdAt: DateTime(2024),
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            replyToEventId: parentCommentId,
            replyToAuthorPubkey: parentAuthorPubkey,
          ),
        );

        await service.publishVideoComment(
          videoFilePath: '/tmp/test_video.mp4',
          rootEventId: testRootEventId,
          rootEventKind: testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          nostrPubkey: testUserPubkey,
          parentCommentId: parentCommentId,
          parentAuthorPubkey: parentAuthorPubkey,
        );

        verify(
          () => mockCommentsRepo.postComment(
            content: any(named: 'content'),
            rootEventId: testRootEventId,
            rootEventKind: testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            rootAddressableId: any(named: 'rootAddressableId'),
            replyToEventId: parentCommentId,
            replyToAuthorPubkey: parentAuthorPubkey,
            imetaTag: any(named: 'imetaTag'),
          ),
        ).called(1);
      });
    });

    group(VideoCommentPublishResult, () {
      test('success result has comment', () {
        final comment = Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: DateTime(2024),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        );

        final result = VideoCommentPublishResult.success(comment);

        expect(result.isSuccess, isTrue);
        expect(result.comment, equals(comment));
        expect(result.error, isNull);
      });

      test('failure result has error', () {
        const result = VideoCommentPublishResult.failure(
          'Something went wrong',
        );

        expect(result.isSuccess, isFalse);
        expect(result.comment, isNull);
        expect(
          result.error,
          equals('Something went wrong'),
        );
      });
    });
  });
}
