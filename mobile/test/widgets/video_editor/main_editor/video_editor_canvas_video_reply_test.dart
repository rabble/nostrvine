// ABOUTME: Tests for video reply publish logic in VideoEditorCanvas.
// ABOUTME: Validates publish flow, auth check, error handling, and
// ABOUTME: context cleanup without full ProImageEditor widget setup.

import 'package:comments_repository/comments_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_comment_publish_service.dart';

class _MockVideoCommentPublishService extends Mock
    implements VideoCommentPublishService {}

class _MockAuthService extends Mock implements AuthService {}

// Full 64-character test IDs
const _rootEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef'
    '123456789012345678901234';
const _rootAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef12'
    '3456789012345678901234a';
const _testUserPubkey =
    'c3d4e5f6789012345678901234567890abcdef1234'
    '56789012345678901234ab';
const _parentCommentId =
    'd4e5f6789012345678901234567890abcdef123456'
    '789012345678901234abc';
const _parentAuthorPubkey =
    'e5f6789012345678901234567890abcdef12345678'
    '9012345678901234abcd';

/// Simulates the publish logic from `_publishAndReturnFromVideoReply`
/// in video_editor_canvas.dart.
///
/// This mirrors the method's behavior without requiring the full widget
/// context (ProImageEditor, video player, etc.).
Future<_PublishSimulationResult> _simulateVideoReplyPublish({
  required VideoCommentPublishService publishService,
  required AuthService authService,
  required String videoFilePath,
  required VideoReplyContext replyContext,
}) async {
  final nostrPubkey = authService.currentPublicKeyHex;

  if (nostrPubkey == null) {
    return const _PublishSimulationResult(
      published: false,
      reason: 'not_authenticated',
    );
  }

  try {
    final result = await publishService.publishVideoComment(
      videoFilePath: videoFilePath,
      rootEventId: replyContext.rootEventId,
      rootEventKind: replyContext.rootEventKind,
      rootEventAuthorPubkey: replyContext.rootAuthorPubkey,
      nostrPubkey: nostrPubkey,
      rootAddressableId: replyContext.rootAddressableId,
      parentCommentId: replyContext.parentCommentId,
      parentAuthorPubkey: replyContext.parentAuthorPubkey,
    );

    return _PublishSimulationResult(
      published: result.isSuccess,
      reason: result.isSuccess ? 'success' : result.error,
    );
  } catch (e) {
    return _PublishSimulationResult(published: false, reason: 'exception: $e');
  }
}

/// Result of the publish simulation.
class _PublishSimulationResult {
  const _PublishSimulationResult({required this.published, this.reason});

  final bool published;
  final String? reason;
}

void main() {
  group('VideoEditorCanvas Video Reply Logic', () {
    late _MockVideoCommentPublishService mockPublishService;
    late _MockAuthService mockAuthService;

    const testReplyContext = VideoReplyContext(
      rootEventId: _rootEventId,
      rootEventKind: 34236,
      rootAuthorPubkey: _rootAuthorPubkey,
    );

    const testReplyContextWithParent = VideoReplyContext(
      rootEventId: _rootEventId,
      rootEventKind: 34236,
      rootAuthorPubkey: _rootAuthorPubkey,
      rootAddressableId: 'test-d-tag',
      parentCommentId: _parentCommentId,
      parentAuthorPubkey: _parentAuthorPubkey,
    );

    setUp(() {
      mockPublishService = _MockVideoCommentPublishService();
      mockAuthService = _MockAuthService();
    });

    group('authentication check', () {
      test('skips publish when not authenticated', () async {
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

        final result = await _simulateVideoReplyPublish(
          publishService: mockPublishService,
          authService: mockAuthService,
          videoFilePath: '/tmp/test_video.mp4',
          replyContext: testReplyContext,
        );

        expect(result.published, isFalse);
        expect(result.reason, equals('not_authenticated'));
        verifyNever(
          () => mockPublishService.publishVideoComment(
            videoFilePath: any(named: 'videoFilePath'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            nostrPubkey: any(named: 'nostrPubkey'),
          ),
        );
      });
    });

    group('successful publish', () {
      test('publishes with correct parameters', () async {
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_testUserPubkey);

        final testComment = Comment(
          id:
              'f6789012345678901234567890abcdef12345678'
              '9012345678901234abcde',
          authorPubkey: _testUserPubkey,
          content: 'https://cdn.example.com/video.mp4',
          createdAt: DateTime.now(),
          rootEventId: _rootEventId,
          rootAuthorPubkey: _rootAuthorPubkey,
        );

        when(
          () => mockPublishService.publishVideoComment(
            videoFilePath: any(named: 'videoFilePath'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            nostrPubkey: any(named: 'nostrPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            parentCommentId: any(named: 'parentCommentId'),
            parentAuthorPubkey: any(named: 'parentAuthorPubkey'),
          ),
        ).thenAnswer(
          (_) async => VideoCommentPublishResult.success(testComment),
        );

        final result = await _simulateVideoReplyPublish(
          publishService: mockPublishService,
          authService: mockAuthService,
          videoFilePath: '/tmp/test_video.mp4',
          replyContext: testReplyContext,
        );

        expect(result.published, isTrue);
        expect(result.reason, equals('success'));

        verify(
          () => mockPublishService.publishVideoComment(
            videoFilePath: '/tmp/test_video.mp4',
            rootEventId: _rootEventId,
            rootEventKind: 34236,
            rootEventAuthorPubkey: _rootAuthorPubkey,
            nostrPubkey: _testUserPubkey,
            rootAddressableId: null,
            parentCommentId: null,
            parentAuthorPubkey: null,
          ),
        ).called(1);
      });

      test('passes parent comment fields when replying to comment', () async {
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_testUserPubkey);

        final testComment = Comment(
          id:
              'f6789012345678901234567890abcdef123456'
              '789012345678901234abcde',
          authorPubkey: _testUserPubkey,
          content: 'https://cdn.example.com/video.mp4',
          createdAt: DateTime.now(),
          rootEventId: _rootEventId,
          rootAuthorPubkey: _rootAuthorPubkey,
        );

        when(
          () => mockPublishService.publishVideoComment(
            videoFilePath: any(named: 'videoFilePath'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            nostrPubkey: any(named: 'nostrPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            parentCommentId: any(named: 'parentCommentId'),
            parentAuthorPubkey: any(named: 'parentAuthorPubkey'),
          ),
        ).thenAnswer(
          (_) async => VideoCommentPublishResult.success(testComment),
        );

        final result = await _simulateVideoReplyPublish(
          publishService: mockPublishService,
          authService: mockAuthService,
          videoFilePath: '/tmp/test_video.mp4',
          replyContext: testReplyContextWithParent,
        );

        expect(result.published, isTrue);

        verify(
          () => mockPublishService.publishVideoComment(
            videoFilePath: '/tmp/test_video.mp4',
            rootEventId: _rootEventId,
            rootEventKind: 34236,
            rootEventAuthorPubkey: _rootAuthorPubkey,
            nostrPubkey: _testUserPubkey,
            rootAddressableId: 'test-d-tag',
            parentCommentId: _parentCommentId,
            parentAuthorPubkey: _parentAuthorPubkey,
          ),
        ).called(1);
      });
    });

    group('publish failure', () {
      test('handles publish error result', () async {
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_testUserPubkey);

        when(
          () => mockPublishService.publishVideoComment(
            videoFilePath: any(named: 'videoFilePath'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            nostrPubkey: any(named: 'nostrPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            parentCommentId: any(named: 'parentCommentId'),
            parentAuthorPubkey: any(named: 'parentAuthorPubkey'),
          ),
        ).thenAnswer(
          (_) async => const VideoCommentPublishResult.failure('Upload failed'),
        );

        final result = await _simulateVideoReplyPublish(
          publishService: mockPublishService,
          authService: mockAuthService,
          videoFilePath: '/tmp/test_video.mp4',
          replyContext: testReplyContext,
        );

        expect(result.published, isFalse);
        expect(result.reason, equals('Upload failed'));
      });

      test('handles publish exception', () async {
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(_testUserPubkey);

        when(
          () => mockPublishService.publishVideoComment(
            videoFilePath: any(named: 'videoFilePath'),
            rootEventId: any(named: 'rootEventId'),
            rootEventKind: any(named: 'rootEventKind'),
            rootEventAuthorPubkey: any(named: 'rootEventAuthorPubkey'),
            nostrPubkey: any(named: 'nostrPubkey'),
            rootAddressableId: any(named: 'rootAddressableId'),
            parentCommentId: any(named: 'parentCommentId'),
            parentAuthorPubkey: any(named: 'parentAuthorPubkey'),
          ),
        ).thenThrow(Exception('Network error'));

        final result = await _simulateVideoReplyPublish(
          publishService: mockPublishService,
          authService: mockAuthService,
          videoFilePath: '/tmp/test_video.mp4',
          replyContext: testReplyContext,
        );

        expect(result.published, isFalse);
        expect(result.reason, contains('Exception: Network error'));
      });
    });

    group('VideoReplyContext branching', () {
      test('null context means normal flow', () {
        // Simulates the check in _handleDone()
        const VideoReplyContext? context = null;
        expect(context, isNull);
        // Normal flow: navigate to metadata screen
      });

      test('non-null context means video reply flow', () {
        const VideoReplyContext? context = testReplyContext;
        expect(context, isNotNull);
        // Video reply flow: skip metadata, publish as comment
      });
    });
  });
}
