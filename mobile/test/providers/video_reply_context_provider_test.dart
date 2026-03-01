// ABOUTME: Tests for VideoReplyContextNotifier provider.
// ABOUTME: Verifies setContext, clear, and initial null state.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_reply_context.dart';
import 'package:openvine/providers/video_reply_context_provider.dart';

// Full 64-character test IDs
const _rootEventId =
    'a1b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234';
const _rootAuthorPubkey =
    'b2c3d4e5f6789012345678901234567890abcdef123456789012345678901234a';

void main() {
  group('VideoReplyContextNotifier', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('initial state is null', () {
      final context = container.read(videoReplyContextProvider);
      expect(context, isNull);
    });

    test('setContext updates state', () {
      const replyContext = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      container
          .read(videoReplyContextProvider.notifier)
          .setContext(replyContext);

      final result = container.read(videoReplyContextProvider);
      expect(result, equals(replyContext));
    });

    test('setContext with all fields', () {
      const replyContext = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
        rootAddressableId: 'test-d-tag',
        parentCommentId:
            'parent-comment-id-0000000000000000000000000'
            '0000000000000000000000000000000000000',
        parentAuthorPubkey:
            'parent-author-000000000000000000000000000'
            '000000000000000000000000000000000',
      );

      container
          .read(videoReplyContextProvider.notifier)
          .setContext(replyContext);

      final result = container.read(videoReplyContextProvider);
      expect(result, equals(replyContext));
      expect(result!.rootAddressableId, equals('test-d-tag'));
      expect(result.parentCommentId, isNotNull);
      expect(result.parentAuthorPubkey, isNotNull);
    });

    test('clear resets state to null', () {
      const replyContext = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      container
          .read(videoReplyContextProvider.notifier)
          .setContext(replyContext);

      // Verify it was set
      expect(container.read(videoReplyContextProvider), isNotNull);

      container.read(videoReplyContextProvider.notifier).clear();

      expect(container.read(videoReplyContextProvider), isNull);
    });

    test('setContext replaces previous context', () {
      const context1 = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );
      const context2 = VideoReplyContext(
        rootEventId: _rootAuthorPubkey,
        rootEventKind: 1111,
        rootAuthorPubkey: _rootEventId,
      );

      final notifier = container.read(videoReplyContextProvider.notifier);

      notifier.setContext(context1);
      expect(container.read(videoReplyContextProvider), equals(context1));

      notifier.setContext(context2);
      expect(container.read(videoReplyContextProvider), equals(context2));
    });

    test('clear on already null state is no-op', () {
      // Should not throw
      container.read(videoReplyContextProvider.notifier).clear();
      expect(container.read(videoReplyContextProvider), isNull);
    });

    test('provider is keepAlive', () {
      const replyContext = VideoReplyContext(
        rootEventId: _rootEventId,
        rootEventKind: 34236,
        rootAuthorPubkey: _rootAuthorPubkey,
      );

      container
          .read(videoReplyContextProvider.notifier)
          .setContext(replyContext);

      // State persists across reads (keepAlive behavior)
      final result1 = container.read(videoReplyContextProvider);
      final result2 = container.read(videoReplyContextProvider);
      expect(result1, equals(result2));
      expect(result1, equals(replyContext));
    });
  });
}
