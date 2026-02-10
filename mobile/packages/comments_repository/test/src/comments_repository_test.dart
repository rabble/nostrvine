import 'package:comments_repository/comments_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class FakeEvent extends Fake implements Event {}

/// Kind 1111 is the NIP-22 comment kind for replying to non-Kind-1 events.
const int _commentKind = EventKind.comment;

/// Kind 5 is the NIP-09 deletion request kind.
const int _deletionKind = EventKind.eventDeletion;

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
        expect(result.comments, isEmpty);
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
        expect(result.comments.length, equals(1));
        expect(result.comments.first.content, equals('Great video!'));
        expect(result.comments.first.replyToEventId, isNull);
      });

      test('returns flat list with replies in chronological order', () async {
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
        expect(result.comments.length, equals(2));
        // Newest first (reply is newer)
        expect(result.comments.first.content, equals('Reply to parent'));
        expect(result.comments.first.replyToEventId, equals('comment1'));
        expect(result.comments.last.content, equals('Parent comment'));
      });

      test('sorts all comments chronologically (newest first)', () async {
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

        expect(result.comments.first.content, 'New comment');
        expect(result.comments.last.content, 'Old comment');
      });

      test('includes replies in chronological order with parent', () async {
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

        expect(result.comments.length, equals(3));
        // Chronological: newest first
        expect(result.comments[0].content, 'New reply');
        expect(result.comments[1].content, 'Old reply');
        expect(result.comments[2].content, 'Parent');
      });

      test(
        'includes orphan replies in flat list with replyTo reference',
        () async {
          // Orphan replies are just included in the flat list with
          // their replyToEventId
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

          // Orphan is in the flat list
          expect(result.comments.length, equals(1));
          expect(result.comments.first.content, 'Orphan reply');
          expect(result.comments.first.replyToEventId, 'nonexistent_parent');
        },
      );

      test(
        'queries by both E and A tags when rootAddressableId is provided',
        () async {
          const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => []);

          await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          );

          // Should make 2 calls: one for E tag, one for A tag
          final captured = verify(
            () => mockNostrClient.queryEvents(captureAny()),
          ).captured;

          expect(captured.length, equals(2));

          final filtersE = captured[0] as List<Filter>;
          expect(
            filtersE.first.uppercaseE,
            contains(testRootEventId),
          );

          final filtersA = captured[1] as List<Filter>;
          expect(
            filtersA.first.uppercaseA,
            contains(testAddressableId),
          );
        },
      );

      test(
        'deduplicates comments found by both E and A tag queries',
        () async {
          const testAddressableId = '34236:$testRootAuthorPubkey:video-dtag';

          final commentEvent = _createCommentEvent(
            id: 'comment1',
            content: 'Found by both queries',
            pubkey: testUserPubkey,
            rootEventId: testRootEventId,
            rootAuthorPubkey: testRootAuthorPubkey,
            rootEventKind: _testRootEventKind,
          );

          // Both queries return the same event
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [commentEvent]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootAddressableId: testAddressableId,
          );

          // Should be deduplicated to 1 comment
          expect(result.totalCount, equals(1));
          expect(result.comments.length, equals(1));
        },
      );

      test(
        'parses comment with only A tag (no E tag) from other clients',
        () async {
          // Some clients may only use A tag for addressable events
          final aTagOnlyComment = Event(
            testUserPubkey,
            _commentKind,
            <List<String>>[
              [
                'A',
                '34236:$testRootAuthorPubkey:video-dtag',
                '',
              ],
              ['K', _testRootEventKind.toString()],
              ['P', testRootAuthorPubkey],
              [
                'a',
                '34236:$testRootAuthorPubkey:video-dtag',
                '',
              ],
              ['k', _testRootEventKind.toString()],
              ['p', testRootAuthorPubkey],
            ],
            'A-tag only comment',
            createdAt: 1000,
          )..id = 'a_tag_comment';

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [aTagOnlyComment]);

          final result = await repository.loadComments(
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
          );

          expect(result.totalCount, equals(1));
          final comment = result.comments.first;
          expect(comment.content, equals('A-tag only comment'));
          // rootAuthorPubkey extracted from A tag addressable ID
          expect(comment.rootAuthorPubkey, equals(testRootAuthorPubkey));
          // Top-level comment (parent kind = root kind)
          expect(comment.replyToEventId, isNull);
        },
      );

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

      test('passes before parameter as until filter for pagination', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final beforeTime = DateTime.fromMillisecondsSinceEpoch(2000000000);
        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
          before: beforeTime,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        // `until` is in seconds (Nostr epoch), so divide milliseconds by 1000
        expect(filters.first.until, equals(2000000000 ~/ 1000));
      });

      test('does not include until filter when before is null', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        await repository.loadComments(
          rootEventId: testRootEventId,
          rootEventKind: _testRootEventKind,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;

        final filters = captured.first as List<Filter>;
        expect(filters.first.until, isNull);
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

      test(
        'posts top-level comment with A/a tags for addressable events',
        () async {
          Event? capturedEvent;
          const testAddressableId = '34236:$testRootAuthorPubkey:my-video-dtag';

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            return capturedEvent = inv.positionalArguments.first as Event;
          });

          await repository.postComment(
            content: 'Comment on addressable event',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            rootAddressableId: testAddressableId,
          );

          expect(capturedEvent, isNotNull);

          // Uppercase A tag = root scope (3 elements per NIP-22)
          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          expect(uppercaseATags.length, equals(1));
          expect(uppercaseATags.first.length, equals(3));
          expect(uppercaseATags.first[1], equals(testAddressableId));
          expect(uppercaseATags.first[2], equals(''));

          // Lowercase a tag = parent item (3 elements per NIP-22)
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();
          expect(lowercaseATags.length, equals(1));
          expect(lowercaseATags.first.length, equals(3));
          expect(lowercaseATags.first[1], equals(testAddressableId));
          expect(lowercaseATags.first[2], equals(''));
        },
      );

      test(
        'posts reply comment without lowercase a tag',
        () async {
          Event? capturedEvent;
          const testAddressableId = '34236:$testRootAuthorPubkey:my-video-dtag';
          const parentCommentId =
              'eeeeeeeeeeeeeeeeeeee'
              'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
              'eeeeeeeeeeee';
          const parentAuthorPubkey =
              'ffffffffffffffff'
              'ffffffffffffffffffffffffffffffff'
              'ffffffffffffffff';

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            return capturedEvent = inv.positionalArguments.first as Event;
          });

          await repository.postComment(
            content: 'Reply to comment',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
            rootAddressableId: testAddressableId,
            replyToEventId: parentCommentId,
            replyToAuthorPubkey: parentAuthorPubkey,
          );

          expect(capturedEvent, isNotNull);

          // Uppercase A tag should be present (root scope)
          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          expect(uppercaseATags.length, equals(1));

          // Lowercase a tag should NOT be present (reply parent is comment,
          // not addressable event)
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();
          expect(lowercaseATags, isEmpty);
        },
      );

      test(
        'does not include A/a tags when rootAddressableId is null',
        () async {
          Event? capturedEvent;

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            return capturedEvent = inv.positionalArguments.first as Event;
          });

          await repository.postComment(
            content: 'No addressable ID',
            rootEventId: testRootEventId,
            rootEventKind: _testRootEventKind,
            rootEventAuthorPubkey: testRootAuthorPubkey,
          );

          final uppercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'A')
              .toList();
          final lowercaseATags = capturedEvent!.tags
              .cast<List<dynamic>>()
              .where((t) => t[0] == 'a')
              .toList();

          expect(uppercaseATags, isEmpty);
          expect(lowercaseATags, isEmpty);
        },
      );

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

      test(
        'returns max of E and A tag counts when '
        'rootAddressableId provided',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          var callCount = 0;
          when(() => mockNostrClient.countEvents(any())).thenAnswer((_) async {
            callCount++;
            // First call (E tag) returns 5, second call (A tag) returns 8
            return CountResult(count: callCount == 1 ? 5 : 8);
          });

          final result = await repository.getCommentsCount(
            testRootEventId,
            rootAddressableId: testAddressableId,
          );

          // Should return the maximum of the two counts
          expect(result, equals(8));

          // Should make 2 calls
          verify(() => mockNostrClient.countEvents(any())).called(2);
        },
      );

      test(
        'returns E tag count when higher than A tag count',
        () async {
          const testAddressableId =
              '34236:$testRootAuthorPubkey'
              ':video-dtag';

          var callCount = 0;
          when(() => mockNostrClient.countEvents(any())).thenAnswer((_) async {
            callCount++;
            // First call (E tag) returns 10, second call (A tag) returns 3
            return CountResult(count: callCount == 1 ? 10 : 3);
          });

          final result = await repository.getCommentsCount(
            testRootEventId,
            rootAddressableId: testAddressableId,
          );

          expect(result, equals(10));
        },
      );

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

    group('deleteComment', () {
      const testCommentId =
          'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

      test('publishes deletion event with correct tags', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.deleteComment(commentId: testCommentId);

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(_deletionKind));

        // Check NIP-09 deletion tags
        final eTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'e')
            .toList();
        final kTags = capturedEvent!.tags
            .cast<List<dynamic>>()
            .where((t) => t[0] == 'k')
            .toList();

        expect(eTags.length, equals(1));
        expect(eTags.first[1], equals(testCommentId));
        expect(kTags.length, equals(1));
        expect(kTags.first[1], equals(_commentKind.toString()));
      });

      test('publishes deletion event with reason when provided', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer((inv) async {
          return capturedEvent = inv.positionalArguments.first as Event;
        });

        await repository.deleteComment(
          commentId: testCommentId,
          reason: 'Spam content',
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.content, equals('Spam content'));
      });

      test(
        'publishes deletion event with empty content when no reason',
        () async {
          Event? capturedEvent;

          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            inv,
          ) async {
            return capturedEvent = inv.positionalArguments.first as Event;
          });

          await repository.deleteComment(commentId: testCommentId);

          expect(capturedEvent, isNotNull);
          expect(capturedEvent!.content, isEmpty);
        },
      );

      test(
        'throws DeleteCommentFailedException when publish returns null',
        () async {
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => null);

          expect(
            () => repository.deleteComment(commentId: testCommentId),
            throwsA(isA<DeleteCommentFailedException>()),
          );
        },
      );

      test('throws DeleteCommentFailedException on exception', () async {
        when(
          () => mockNostrClient.publishEvent(any()),
        ).thenThrow(Exception('Network error'));

        expect(
          () => repository.deleteComment(commentId: testCommentId),
          throwsA(isA<DeleteCommentFailedException>()),
        );
      });

      test('rethrows DeleteCommentFailedException', () async {
        when(() => mockNostrClient.publishEvent(any())).thenThrow(
          const DeleteCommentFailedException('Custom error'),
        );

        expect(
          () => repository.deleteComment(commentId: testCommentId),
          throwsA(
            isA<DeleteCommentFailedException>().having(
              (e) => e.message,
              'message',
              'Custom error',
            ),
          ),
        );
      });
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
