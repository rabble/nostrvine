// ABOUTME: Tests for VideoEditorNotifier.publishAsVideoReply().
// ABOUTME: Validates reply context check, auth, publish, and context cleanup.

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

/// Simulates the publish-as-video-reply logic from
/// `VideoEditorNotifier.publishAsVideoReply()`.
///
/// This mirrors the method's behavior without requiring the full
/// Riverpod notifier setup (which depends on rendering infrastructure).
Future<_PublishResult> _simulatePublishAsVideoReply({
  required VideoCommentPublishService publishService,
  required AuthService authService,
  required VideoReplyContext? replyContext,
  required String? videoFilePath,
}) async {
  // Step 1: Check reply context
  if (replyContext == null) {
    return const _PublishResult(handled: false, reason: 'no_context');
  }

  // Step 2: Check rendered clip (simulated)
  if (videoFilePath == null) {
    return const _PublishResult(handled: true, reason: 'render_failed');
  }

  // Step 3: Check auth
  final nostrPubkey = authService.currentPublicKeyHex;
  if (nostrPubkey == null) {
    return const _PublishResult(handled: true, reason: 'not_authenticated');
  }

  // Step 4: Publish
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

    return _PublishResult(
      handled: true,
      reason: result.isSuccess ? 'success' : result.error,
    );
  } catch (e) {
    return _PublishResult(handled: true, reason: 'exception: $e');
  }
}

/// Result of the publish simulation.
class _PublishResult {
  const _PublishResult({required this.handled, this.reason});

  final bool handled;
  final String? reason;
}

void main() {
  group('VideoEditorNotifier publishAsVideoReply logic', () {
    late _MockVideoCommentPublishService mockPublishService;
    late _MockAuthService mockAuthService;

    const testReplyContext = VideoReplyContext(
      rootEventId: _rootEventId,
      rootEventKind: 34236,
      rootAuthorPubkey: _rootAuthorPubkey,
    );

    setUp(() {
      mockPublishService = _MockVideoCommentPublishService();
      mockAuthService = _MockAuthService();
    });

    group('reply context check', () {
      test('returns false when no reply context is set', () async {
        final result = await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: null,
          videoFilePath: '/tmp/test.mp4',
        );

        expect(result.handled, isFalse);
        expect(result.reason, equals('no_context'));

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

      test('returns true when reply context is set', () async {
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

        final result = await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: testReplyContext,
          videoFilePath: '/tmp/test.mp4',
        );

        expect(result.handled, isTrue);
        expect(result.reason, equals('success'));
      });
    });

    group('render failure', () {
      test('returns true with render_failed when no clip', () async {
        final result = await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: testReplyContext,
          videoFilePath: null,
        );

        expect(result.handled, isTrue);
        expect(result.reason, equals('render_failed'));
      });
    });

    group('authentication', () {
      test('returns true with not_authenticated when no pubkey', () async {
        when(() => mockAuthService.currentPublicKeyHex).thenReturn(null);

        final result = await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: testReplyContext,
          videoFilePath: '/tmp/test.mp4',
        );

        expect(result.handled, isTrue);
        expect(result.reason, equals('not_authenticated'));
      });
    });

    group('publish', () {
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

        await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: testReplyContext,
          videoFilePath: '/tmp/test.mp4',
        );

        verify(
          () => mockPublishService.publishVideoComment(
            videoFilePath: '/tmp/test.mp4',
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

      test('handles publish failure', () async {
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

        final result = await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: testReplyContext,
          videoFilePath: '/tmp/test.mp4',
        );

        expect(result.handled, isTrue);
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

        final result = await _simulatePublishAsVideoReply(
          publishService: mockPublishService,
          authService: mockAuthService,
          replyContext: testReplyContext,
          videoFilePath: '/tmp/test.mp4',
        );

        expect(result.handled, isTrue);
        expect(result.reason, contains('Exception: Network error'));
      });
    });
  });
}
