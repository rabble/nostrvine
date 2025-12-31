import 'dart:async';

import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class FakeEvent extends Fake implements Event {}

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Example kind for a video event (Kind 34236 for NIP-71).
const int _testRootEventKind = EventKind.videoVertical;

void main() {
  group('CommentsRepository', () {
    late MockNostrClient mockNostrClient;
    late CommentsRepository repository;

    const testRootEventId =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testRootAuthorPubkey =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testUserPubkey =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(FakeEvent());
    });

    setUp(() {
      mockNostrClient = MockNostrClient();
      when(() => mockNostrClient.publicKey).thenReturn(testUserPubkey);
      repository = CommentsRepository(nostrClient: mockNostrClient);
    });

    group('constructor', () {
      test('creates repository with nostrClient', () {
        final repo = CommentsRepository(nostrClient: mockNostrClient);
        expect(repo, isNotNull);
      });
    });

    group('loadComments', () {
      test('returns empty thread when no comments', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.isEmpty, isTrue);
        expect(result.totalCount, equals(0));
        expect(result.topLevelComments, isEmpty);
        expect(result.rootEventId, equals(testRootEventId));
      });

      test('returns thread with single top-level comment', () async {
        final commentEvent = _createCommentEvent(
          id: 'comment1',
          content: 'Great video!',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [commentEvent]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.isNotEmpty, isTrue);
        expect(result.totalCount, equals(1));
        expect(result.topLevelComments.length, equals(1));
        expect(
          result.topLevelComments.first.comment.content,
          equals('Great video!'),
        );
        expect(result.topLevelComments.first.replies, isEmpty);
      });

      test('returns threaded structure with replies', () async {
        final rootComment = _createCommentEvent(
          id: 'comment1',
          content: 'Parent comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        final replyComment = _createCommentEvent(
          id: 'comment2',
          content: 'Reply to parent',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'comment1',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [rootComment, replyComment]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.totalCount, equals(2));
        expect(result.topLevelComments.length, equals(1));
        expect(result.topLevelComments.first.replies.length, equals(1));
        expect(
          result.topLevelComments.first.replies.first.comment.content,
          equals('Reply to parent'),
        );
      });

      test('sorts top-level comments by newest first', () async {
        final oldComment = _createCommentEvent(
          id: 'comment1',
          content: 'Old comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        final newComment = _createCommentEvent(
          id: 'comment2',
          content: 'New comment',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          createdAt: 2000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [oldComment, newComment]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        expect(result.topLevelComments.first.comment.content, 'New comment');
        expect(result.topLevelComments.last.comment.content, 'Old comment');
      });

      test('sorts replies by oldest first', () async {
        final parentComment = _createCommentEvent(
          id: 'parent',
          content: 'Parent',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
        );

        final oldReply = _createCommentEvent(
          id: 'reply1',
          content: 'Old reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'parent',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 2000,
        );

        final newReply = _createCommentEvent(
          id: 'reply2',
          content: 'New reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'parent',
          replyToAuthorPubkey: testUserPubkey,
          createdAt: 3000,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [parentComment, newReply, oldReply]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        final replies = result.topLevelComments.first.replies;
        expect(replies.first.comment.content, 'Old reply');
        expect(replies.last.comment.content, 'New reply');
      });

      test('handles orphan replies with placeholder parent', () async {
        // A reply to a non-existent comment creates a placeholder parent
        final orphanReply = _createCommentEvent(
          id: 'orphan',
          content: 'Orphan reply',
          pubkey: testUserPubkey,
          rootEventId: testRootEventId,
          rootAuthorPubkey: testRootAuthorPubkey,
          rootEventKind: _testRootEventKind,
          replyToEventId: 'nonexistent_parent',
          replyToAuthorPubkey: testUserPubkey,
        );

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => [orphanReply]);

        final result = await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        // Placeholder parent is created at top level
        expect(result.topLevelComments.length, equals(1));
        expect(result.topLevelComments.first.isNotFound, isTrue);
        expect(result.topLevelComments.first.comment.id, 'nonexistent_parent');
        // Orphan reply is nested under placeholder
        expect(result.topLevelComments.first.replies.length, equals(1));
        expect(
          result.topLevelComments.first.replies.first.comment.content,
          'Orphan reply',
        );
      });

      test('throws LoadCommentsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          ),
          throwsA(isA<LoadCommentsFailedException>()),
        );
      });

      test('respects limit parameter', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          limit: 50,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.limit, equals(50));
      });
    });

    group('watchComments', () {
      test('returns stream that emits empty thread first', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        final stream = repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );
        final results = <CommentThread>[];
        final subscription = stream.listen(results.add);

        // Wait for initial empty state (startWith)
        await Future<void>.delayed(Duration.zero);
        expect(results.first.isEmpty, isTrue);
        expect(results.first.rootEventId, equals(testRootEventId));

        await subscription.cancel();
        await controller.close();
      });

      test('accumulates comments and rebuilds thread', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        final stream = repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );
        final results = <CommentThread>[];
        final subscription = stream.listen(results.add);

        // Wait for initial empty state
        await Future<void>.delayed(Duration.zero);

        // Add first comment
        controller.add(
          _createCommentEvent(
            id: 'comment1',
            content: 'First comment',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(results.last.totalCount, equals(1));

        // Add second comment
        controller.add(
          _createCommentEvent(
            id: 'comment2',
            content: 'Second comment',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
            createdAt: 2000,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(results.last.totalCount, equals(2));

        await subscription.cancel();
        await controller.close();
      });

      test('delegates to NostrClient.subscribe with correct filter', () async {
        final controller = StreamController<Event>.broadcast();

        when(
          () => mockNostrClient.subscribe(any()),
        ).thenAnswer((_) => controller.stream);

        repository.watchComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          limit: 50,
        );

        final captured = verify(
          () => mockNostrClient.subscribe(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, contains(_commentKind));
        expect(filters.first.uppercaseE, contains(testRootEventId));
        expect(filters.first.limit, equals(50));

        await controller.close();
      });
    });

    group('postComment', () {
      test('posts top-level comment with correct tags', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.postComment(
          content: 'Test comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(_commentKind));
        expect(capturedEvent!.content, equals('Test comment'));

        // Check NIP-22 tags
        // Uppercase tags = root scope
        final uppercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'E')
            .toList();
        final uppercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'K')
            .toList();
        final uppercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'P')
            .toList();

        // Lowercase tags = parent item (for top-level, same as root)
        final lowercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final lowercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();
        final lowercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'p')
            .toList();

        // Root scope tags
        expect(uppercaseETags.length, equals(1));
        expect(uppercaseETags.first[1], equals(testRootEventId));
        expect(uppercaseKTags.length, equals(1));
        expect(uppercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(uppercasePTags.length, equals(1));
        expect(uppercasePTags.first[1], equals(testRootAuthorPubkey));

        // Parent item tags (same as root for top-level)
        expect(lowercaseETags.length, equals(1));
        expect(lowercaseETags.first[1], equals(testRootEventId));
        expect(lowercaseKTags.length, equals(1));
        expect(lowercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(lowercasePTags.length, equals(1));
        expect(lowercasePTags.first[1], equals(testRootAuthorPubkey));
      });

      test('posts reply with correct tags', () async {
        Event? capturedEvent;
        const parentCommentId =
            'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee';
        const parentAuthorPubkey =
            'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.postComment(
          content: 'Reply comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
          replyToEventId: parentCommentId,
          replyToAuthorPubkey: parentAuthorPubkey,
        );

        expect(capturedEvent, isNotNull);

        // Check NIP-22 tags
        // Uppercase tags = root scope
        final uppercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'E')
            .toList();
        final uppercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'K')
            .toList();
        final uppercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'P')
            .toList();

        // Lowercase tags = parent item (for reply, parent comment)
        final lowercaseETags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final lowercaseKTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();
        final lowercasePTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'p')
            .toList();

        // Root scope tags (uppercase)
        expect(uppercaseETags.length, equals(1));
        expect(uppercaseETags.first[1], equals(testRootEventId));
        expect(uppercaseKTags.length, equals(1));
        expect(uppercaseKTags.first[1], equals(_testRootEventKind.toString()));
        expect(uppercasePTags.length, equals(1));
        expect(uppercasePTags.first[1], equals(testRootAuthorPubkey));

        // Parent item tags (lowercase) - point to parent comment
        expect(lowercaseETags.length, equals(1));
        expect(lowercaseETags.first[1], equals(parentCommentId));
        expect(lowercaseKTags.length, equals(1));
        expect(lowercaseKTags.first[1], equals(_commentKind.toString()));
        expect(lowercasePTags.length, equals(1));
        expect(lowercasePTags.first[1], equals(parentAuthorPubkey));
      });

      test('returns created Comment', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return inv.positionalArguments.first as Event
            ..id = 'created_event_id';
        });

        final result = await repository.postComment(
          content: 'Test comment',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(result.content, equals('Test comment'));
        expect(result.rootEventId, equals(testRootEventId));
        expect(result.rootAuthorPubkey, equals(testRootAuthorPubkey));
        expect(result.authorPubkey, equals(testUserPubkey));
      });

      test('throws InvalidCommentContentException for empty content', () async {
        expect(
          () => repository.postComment(
            content: '',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<InvalidCommentContentException>()),
        );
      });

      test(
        'throws InvalidCommentContentException for whitespace-only content',
        () async {
          expect(
            () => repository.postComment(
              content: '   ',
              rootEventId: testRootEventId,
              rootEventKind: _testRootEventKind,
              rootEventAuthorPubkey: testRootAuthorPubkey,
            ),
            throwsA(isA<InvalidCommentContentException>()),
          );
        },
      );

      test('trims content before posting', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.postComment(
          content: '  Trimmed content  ',
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          rootEventAuthorPubkey: testRootAuthorPubkey,
        );

        expect(capturedEvent!.content, equals('Trimmed content'));
      });

      test('throws PostCommentFailedException when publish fails', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenAnswer((_) async => null);

        expect(
          () => repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<PostCommentFailedException>()),
        );
      });

      test('throws PostCommentFailedException on exception', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.postComment(
            content: 'Test comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          ),
          throwsA(isA<PostCommentFailedException>()),
        );
      });
    });

    group('getCommentsCount', () {
      test('returns count from NIP-45', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 42),
        );

        final result = await repository.getCommentsCount(testRootEventId);

        expect(result, equals(42));
      });

      test('queries with correct filter', () async {
        when(() => mockNostrClient.countEvents(any())).thenAnswer(
          (_) async => const CountResult(count: 0),
        );

        await repository.getCommentsCount(testRootEventId);

        final captured = verify(
          () => mockNostrClient.countEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.kinds, contains(_commentKind));
        expect(filters.first.uppercaseE, contains(testRootEventId));
      });

      test('throws CountCommentsFailedException on error', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenThrow(Exception('Count failed'));

        expect(
          () => repository.getCommentsCount(testRootEventId),
          throwsA(isA<CountCommentsFailedException>()),
        );
      });
    });
  });

  group('Comment', () {
    test('relativeTime returns correct strings', () {
      final now = DateTime.now();

      expect(
        Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: now,
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ).relativeTime,
        equals('now'),
      );

      expect(
        Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: now.subtract(const Duration(minutes: 5)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ).relativeTime,
        equals('5m ago'),
      );

      expect(
        Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: now.subtract(const Duration(hours: 3)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ).relativeTime,
        equals('3h ago'),
      );

      expect(
        Comment(
          id: 'id',
          content: 'content',
          authorPubkey: 'author',
          createdAt: now.subtract(const Duration(days: 2)),
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ).relativeTime,
        equals('2d ago'),
      );
    });

    test('copyWith creates copy with updated fields', () {
      final original = Comment(
        id: 'id',
        content: 'content',
        authorPubkey: 'author',
        createdAt: DateTime(2024),
        rootEventId: 'root',
        rootAuthorPubkey: 'rootAuthor',
      );

      final copy = original.copyWith(content: 'new content');

      expect(copy.id, equals('id'));
      expect(copy.content, equals('new content'));
      expect(copy.authorPubkey, equals('author'));
    });

    test('equality works correctly', () {
      final comment1 = Comment(
        id: 'id',
        content: 'content',
        authorPubkey: 'author',
        createdAt: DateTime(2024),
        rootEventId: 'root',
        rootAuthorPubkey: 'rootAuthor',
      );

      final comment2 = Comment(
        id: 'id',
        content: 'content',
        authorPubkey: 'author',
        createdAt: DateTime(2024),
        rootEventId: 'root',
        rootAuthorPubkey: 'rootAuthor',
      );

      expect(comment1, equals(comment2));
    });
  });

  group('CommentNode', () {
    test('totalReplyCount returns correct count', () {
      final testTime = DateTime(2024);

      final leaf = CommentNode(
        comment: Comment(
          id: 'leaf',
          content: 'leaf',
          authorPubkey: 'author',
          createdAt: testTime,
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ),
      );

      final parent = CommentNode(
        comment: Comment(
          id: 'parent',
          content: 'parent',
          authorPubkey: 'author',
          createdAt: testTime,
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ),
        replies: [leaf],
      );

      final grandparent = CommentNode(
        comment: Comment(
          id: 'grandparent',
          content: 'grandparent',
          authorPubkey: 'author',
          createdAt: testTime,
          rootEventId: 'root',
          rootAuthorPubkey: 'rootAuthor',
        ),
        replies: [parent],
      );

      expect(leaf.totalReplyCount, equals(0));
      expect(parent.totalReplyCount, equals(1));
      expect(grandparent.totalReplyCount, equals(2));
    });
  });

  group('CommentThread', () {
    test('empty constructor creates empty thread', () {
      const thread = CommentThread.empty('rootId');

      expect(thread.isEmpty, isTrue);
      expect(thread.isNotEmpty, isFalse);
      expect(thread.totalCount, equals(0));
      expect(thread.topLevelComments, isEmpty);
      expect(thread.rootEventId, equals('rootId'));
    });

    test('getComment returns comment from cache', () {
      final comment = Comment(
        id: 'id',
        content: 'content',
        authorPubkey: 'author',
        createdAt: DateTime(2024),
        rootEventId: 'root',
        rootAuthorPubkey: 'rootAuthor',
      );

      final thread = CommentThread(
        rootEventId: 'root',
        totalCount: 1,
        commentCache: {'id': comment},
      );

      expect(thread.getComment('id'), equals(comment));
      expect(thread.getComment('nonexistent'), isNull);
    });
  });
}

/// Helper to create a NIP-22 comment event for testing.
Event _createCommentEvent({
  required String id,
  required String content,
  required String pubkey,
  required String rootEventId,
  required String rootAuthorPubkey,
  required int rootEventKind,
  String? replyToEventId,
  String? replyToAuthorPubkey,
  int createdAt = 1000,
}) {
  // NIP-22 tags:
  // Uppercase tags (E, K, P) = root scope
  // Lowercase tags (e, k, p) = parent item
  final tags = <List<String>>[
    // Root scope tags (uppercase) - always point to the original event
    ['E', rootEventId, '', rootAuthorPubkey],
    ['K', rootEventKind.toString()],
    ['P', rootAuthorPubkey],
    // Parent item tags (lowercase)
    if (replyToEventId != null && replyToAuthorPubkey != null) ...[
      // Replying to another comment
      ['e', replyToEventId, '', replyToAuthorPubkey],
      ['k', _commentKind.toString()],
      ['p', replyToAuthorPubkey],
    ] else ...[
      // Top-level comment - parent is the same as root
      ['e', rootEventId, '', rootAuthorPubkey],
      ['k', rootEventKind.toString()],
      ['p', rootAuthorPubkey],
    ],
  ];

  return Event(pubkey, _commentKind, tags, content, createdAt: createdAt)
    ..id = id;
}
