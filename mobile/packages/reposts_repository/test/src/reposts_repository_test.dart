import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

class MockNostrClient extends Mock implements NostrClient {}

class MockRepostsLocalStorage extends Mock implements RepostsLocalStorage {}

class MockEvent extends Mock implements Event {}

class FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeEvent());
    registerFallbackValue(
      RepostRecord(
        addressableId: 'addressableId',
        repostEventId: 'repostEventId',
        originalAuthorPubkey: 'originalAuthorPubkey',
        createdAt: DateTime.now(),
      ),
    );
    registerFallbackValue(<Filter>[]);
  });

  group('RepostsRepository', () {
    late MockNostrClient mockNostrClient;
    late MockRepostsLocalStorage mockLocalStorage;

    const testPubkey =
        'test_pubkey_hex_64_chars_'
        '00000000000000000000000000000000000000';
    const testEventId =
        'test_event_id_64_chars_00'
        '000000000000000000000000000000000000000';
    const testAddressableId = '34236:author_pubkey:test-dtag';
    const testAuthorPubkey = 'author_pubkey';
    const testRepostEventId =
        'repost_event_id_64_chars_'
        '000000000000000000000000000000000000000';

    Event createMockEvent({
      required String id,
      required int kind,
      required int createdAt,
      List<List<String>> tags = const [],
    }) {
      final event = MockEvent();
      when(() => event.id).thenReturn(id);
      when(() => event.kind).thenReturn(kind);
      when(() => event.createdAt).thenReturn(createdAt);
      when(() => event.tags).thenReturn(tags);
      when(() => event.pubkey).thenReturn(testPubkey);
      when(() => event.content).thenReturn('');
      when(() => event.sig).thenReturn('');
      return event;
    }

    setUp(() {
      mockNostrClient = MockNostrClient();
      mockLocalStorage = MockRepostsLocalStorage();

      when(() => mockNostrClient.publicKey).thenReturn(testPubkey);

      // Default sendGenericRepost mock - returns a valid event
      when(
        () => mockNostrClient.sendGenericRepost(
          addressableId: any(named: 'addressableId'),
          targetKind: any(named: 'targetKind'),
          authorPubkey: any(named: 'authorPubkey'),
          content: any(named: 'content'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => createMockEvent(
          id: testRepostEventId,
          kind: EventKind.genericRepost,
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          tags: [
            ['k', '${EventKind.videoVertical}'],
            ['a', testAddressableId],
            ['p', testAuthorPubkey],
          ],
        ),
      );

      // Default local storage mocks
      when(
        () => mockLocalStorage.getAllRepostRecords(),
      ).thenAnswer((_) async => []);
      when(
        () => mockLocalStorage.saveRepostRecord(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.saveRepostRecordsBatch(any()),
      ).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.deleteRepostRecord(any()),
      ).thenAnswer((_) async => true);
      when(() => mockLocalStorage.clearAll()).thenAnswer((_) async {});
      when(
        () => mockLocalStorage.isReposted(any()),
      ).thenAnswer((_) async => false);
      when(
        () => mockLocalStorage.getRepostRecord(any()),
      ).thenAnswer((_) async => null);
      when(
        () => mockLocalStorage.watchRepostedAddressableIds(),
      ).thenAnswer((_) => Stream.value({}));
    });

    group('constructor', () {
      test('can be instantiated with required parameters', () {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );
        expect(repository, isNotNull);
      });

      test('can be instantiated with all parameters', () {
        final authController = StreamController<bool>();
        addTearDown(authController.close);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          authStateStream: authController.stream,
          isAuthenticated: true,
        );
        expect(repository, isNotNull);
        expect(repository.isAuthenticated, isTrue);
      });

      test('subscribes to auth state stream when provided', () async {
        final authController = StreamController<bool>.broadcast();
        addTearDown(authController.close);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          authStateStream: authController.stream,
        );

        expect(repository.isAuthenticated, isFalse);

        authController.add(true);
        await Future<void>.delayed(Duration.zero);
        expect(repository.isAuthenticated, isTrue);
      });
    });

    group('isRepostedSync', () {
      test('returns false for non-reposted video', () {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );
        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('returns true for reposted video in cache', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);
      });
    });

    group('isReposted', () {
      test('returns false for non-reposted video', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );
        expect(await repository.isReposted(testAddressableId), isFalse);
      });

      test('returns true after reposting', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(await repository.isReposted(testAddressableId), isTrue);
      });

      test('initializes from local storage', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => [record]);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        expect(await repository.isReposted(testAddressableId), isTrue);
      });
    });

    group('getRepostedAddressableIds', () {
      test('returns empty set when no reposts', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );
        expect(await repository.getRepostedAddressableIds(), isEmpty);
      });

      test('returns set of reposted IDs', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final ids = await repository.getRepostedAddressableIds();
        expect(ids, contains(testAddressableId));
        expect(ids.length, equals(1));
      });
    });

    group('getOrderedRepostedAddressableIds', () {
      test('returns empty list when no reposts', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );
        expect(await repository.getOrderedRepostedAddressableIds(), isEmpty);
      });

      test('returns IDs ordered by recency (most recent first)', () async {
        final now = DateTime.now();
        final records = [
          RepostRecord(
            addressableId: '34236:author1:video1',
            repostEventId: 'event1',
            originalAuthorPubkey: 'author1',
            createdAt: now.subtract(const Duration(days: 2)),
          ),
          RepostRecord(
            addressableId: '34236:author2:video2',
            repostEventId: 'event2',
            originalAuthorPubkey: 'author2',
            createdAt: now.subtract(const Duration(days: 1)),
          ),
          RepostRecord(
            addressableId: '34236:author3:video3',
            repostEventId: 'event3',
            originalAuthorPubkey: 'author3',
            createdAt: now,
          ),
        ];

        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => records);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final orderedIds = await repository.getOrderedRepostedAddressableIds();

        expect(orderedIds, hasLength(3));
        expect(orderedIds[0], equals('34236:author3:video3'));
        expect(orderedIds[1], equals('34236:author2:video2'));
        expect(orderedIds[2], equals('34236:author1:video1'));
      });
    });

    group('repostVideo', () {
      test('creates and publishes Kind 16 event', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final eventId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testRepostEventId));

        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('saves repost record to local storage', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        verify(() => mockLocalStorage.saveRepostRecord(any())).called(1);
      });

      test('throws AlreadyRepostedException when already reposted', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.repostVideo(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<AlreadyRepostedException>()),
        );
      });

      test(
        'throws RepostFailedException when sendGenericRepost fails',
        () async {
          when(
            () => mockNostrClient.sendGenericRepost(
              addressableId: any(named: 'addressableId'),
              targetKind: any(named: 'targetKind'),
              authorPubkey: any(named: 'authorPubkey'),
              content: any(named: 'content'),
              tempRelays: any(named: 'tempRelays'),
              targetRelays: any(named: 'targetRelays'),
            ),
          ).thenAnswer((_) async => null);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
          );

          expect(
            () => repository.repostVideo(
              addressableId: testAddressableId,
              originalAuthorPubkey: testAuthorPubkey,
            ),
            throwsA(isA<RepostFailedException>()),
          );
        },
      );
    });

    group('unrepostVideo', () {
      test('publishes deletion event and removes record', () async {
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        await repository.unrepostVideo(testAddressableId);

        expect(repository.isRepostedSync(testAddressableId), isFalse);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
        verify(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        ).called(1);
      });

      test('throws NotRepostedException when not reposted', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        expect(
          () => repository.unrepostVideo(testAddressableId),
          throwsA(isA<NotRepostedException>()),
        );
      });

      test('checks local storage when not in cache', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).thenAnswer((_) async => record);
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.unrepostVideo(testAddressableId);

        verify(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).called(1);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
      });

      test('throws UnrepostFailedException when deletion fails', () async {
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.unrepostVideo(testAddressableId),
          throwsA(isA<UnrepostFailedException>()),
        );
      });
    });

    group('toggleRepost', () {
      test('reposts when not reposted and returns true', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final result = await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(result, isTrue);
        expect(repository.isRepostedSync(testAddressableId), isTrue);
      });

      test('unreposts when reposted and returns false', () async {
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final result = await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(result, isFalse);
        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('checks local storage for repost status', () async {
        when(
          () => mockLocalStorage.isReposted(testAddressableId),
        ).thenAnswer((_) async => false);
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.toggleRepost(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        verify(() => mockLocalStorage.isReposted(testAddressableId)).called(1);
      });
    });

    group('getRepostCount', () {
      test('queries relays for repost count', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer(
          (_) async => const CountResult(count: 42),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(42));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('returns zero when no reposts exist', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer(
          (_) async => const CountResult(count: 0),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final count = await repository.getRepostCount(testAddressableId);

        expect(count, equals(0));
      });
    });

    group('getRepostCountByEventId', () {
      test('queries relays for repost count using event ID', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer(
          (_) async => const CountResult(count: 15),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final count = await repository.getRepostCountByEventId(testEventId);

        expect(count, equals(15));
        verify(() => mockNostrClient.countEvents(any())).called(1);
      });

      test('returns zero when no reposts exist', () async {
        when(
          () => mockNostrClient.countEvents(any()),
        ).thenAnswer(
          (_) async => const CountResult(count: 0),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final count = await repository.getRepostCountByEventId(testEventId);

        expect(count, equals(0));
      });
    });

    group('getRepostRecord', () {
      test('returns null when not reposted', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        expect(await repository.getRepostRecord(testAddressableId), isNull);
      });

      test('returns record when reposted', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        final record = await repository.getRepostRecord(testAddressableId);
        expect(record, isNotNull);
        expect(record!.addressableId, equals(testAddressableId));
        expect(record.repostEventId, equals(testRepostEventId));
        expect(record.originalAuthorPubkey, equals(testAuthorPubkey));
      });
    });

    group('syncUserReposts', () {
      test('loads from local storage first', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => []);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.syncUserReposts();

        verify(() => mockLocalStorage.getAllRepostRecords()).called(1);
      });

      test('fetches from relays and updates local storage', () async {
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['k', '34236'],
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReposts();

        expect(result.orderedAddressableIds, contains('34236:author1:video1'));
        verify(() => mockLocalStorage.saveRepostRecordsBatch(any())).called(1);
      });

      test('returns cached data when relay fetch fails', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getAllRepostRecords(),
        ).thenAnswer((_) async => [record]);
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final result = await repository.syncUserReposts();

        expect(result.orderedAddressableIds, contains(testAddressableId));
      });

      test(
        'throws SyncFailedException when no local data and relay fails',
        () async {
          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenThrow(Exception('Network error'));

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          expect(
            repository.syncUserReposts,
            throwsA(isA<SyncFailedException>()),
          );
        },
      );

      test(
        'updates existing record when newer version found from relay',
        () async {
          final oldTimestamp = DateTime.now().subtract(const Duration(days: 2));
          final newTimestamp = DateTime.now();

          final existingRecord = RepostRecord(
            addressableId: '34236:author1:video1',
            repostEventId: 'old_event_id',
            originalAuthorPubkey: 'author1',
            createdAt: oldTimestamp,
          );

          when(
            () => mockLocalStorage.getAllRepostRecords(),
          ).thenAnswer((_) async => [existingRecord]);

          final newEvent = createMockEvent(
            id: 'new_event_id',
            kind: 16,
            createdAt: newTimestamp.millisecondsSinceEpoch ~/ 1000,
            tags: [
              ['k', '34236'],
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          );

          when(
            () => mockNostrClient.queryEvents(any()),
          ).thenAnswer((_) async => [newEvent]);

          final repository = RepostsRepository(
            nostrClient: mockNostrClient,
            localStorage: mockLocalStorage,
          );

          final result = await repository.syncUserReposts();

          expect(
            result.orderedAddressableIds,
            contains('34236:author1:video1'),
          );
          expect(
            result.addressableIdToRepostId['34236:author1:video1'],
            equals('new_event_id'),
          );
          verify(
            () => mockLocalStorage.saveRepostRecordsBatch(any()),
          ).called(1);
        },
      );
    });

    group('fetchUserReposts', () {
      test('fetches reposts for any user pubkey', () async {
        const otherUserPubkey =
            'other_user_pubkey_64_chars_'
            '0000000000000000000000000000000000000';
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
          createMockEvent(
            id: 'event2',
            kind: 16,
            createdAt: now - 100,
            tags: [
              ['a', '34236:author2:video2'],
              ['p', 'author2'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final reposts = await repository.fetchUserReposts(otherUserPubkey);

        expect(reposts, hasLength(2));
        expect(reposts[0], equals('34236:author1:video1'));
        expect(reposts[1], equals('34236:author2:video2'));
      });

      test('deduplicates reposts', () async {
        const otherUserPubkey = 'other_user_pubkey';
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
          createMockEvent(
            id: 'event2',
            kind: 16,
            createdAt: now - 100,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final reposts = await repository.fetchUserReposts(otherUserPubkey);

        expect(reposts, hasLength(1));
      });

      test('throws FetchRepostsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        expect(
          () => repository.fetchUserReposts('some_pubkey'),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });
    });

    group('fetchUserRepostRecords', () {
      test('returns full RepostRecord objects', () async {
        const otherUserPubkey = 'other_user_pubkey';
        final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        final events = [
          createMockEvent(
            id: 'event1',
            kind: 16,
            createdAt: now,
            tags: [
              ['a', '34236:author1:video1'],
              ['p', 'author1'],
            ],
          ),
        ];

        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenAnswer((_) async => events);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final records = await repository.fetchUserRepostRecords(
          otherUserPubkey,
        );

        expect(records, hasLength(1));
        expect(records[0].addressableId, equals('34236:author1:video1'));
        expect(records[0].repostEventId, equals('event1'));
        expect(records[0].originalAuthorPubkey, equals('author1'));
      });

      test('throws FetchRepostsFailedException on error', () async {
        when(
          () => mockNostrClient.queryEvents(any()),
        ).thenThrow(Exception('Network error'));

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        expect(
          () => repository.fetchUserRepostRecords('some_pubkey'),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });
    });

    group('clearCache', () {
      test('clears in-memory cache', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        await repository.clearCache();

        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('clears local storage', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.clearCache();

        verify(() => mockLocalStorage.clearAll()).called(1);
      });
    });

    group('watchRepostedAddressableIds', () {
      test('returns internal stream when no local storage', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        final stream = repository.watchRepostedAddressableIds();
        expect(stream, isA<Stream<Set<String>>>());

        final emittedValues = <Set<String>>[];
        final subscription = stream.listen(emittedValues.add);

        await Future<void>.delayed(Duration.zero);
        expect(emittedValues.last, isEmpty);

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        await Future<void>.delayed(Duration.zero);
        expect(emittedValues.last, contains(testAddressableId));

        await subscription.cancel();
      });

      test('delegates to local storage when available', () {
        final storageStream = Stream.value(<String>{'test-id'});
        when(
          () => mockLocalStorage.watchRepostedAddressableIds(),
        ).thenAnswer((_) => storageStream);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final stream = repository.watchRepostedAddressableIds();

        expect(stream, equals(storageStream));
        verify(() => mockLocalStorage.watchRepostedAddressableIds()).called(1);
      });
    });

    group('auth state changes', () {
      test('clears cache when user logs out', () async {
        final authController = StreamController<bool>.broadcast();
        addTearDown(authController.close);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          authStateStream: authController.stream,
          isAuthenticated: true,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        authController.add(false);
        await Future<void>.delayed(const Duration(milliseconds: 10));

        expect(repository.isRepostedSync(testAddressableId), isFalse);
      });

      test('ignores duplicate auth state', () async {
        final authController = StreamController<bool>.broadcast();
        addTearDown(authController.close);

        authController.add(true);
        await Future<void>.delayed(Duration.zero);

        verifyNever(() => mockLocalStorage.clearAll());
      });
    });

    group('dispose', () {
      test('cancels auth subscription and closes stream controller', () async {
        final authController = StreamController<bool>.broadcast();

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          authStateStream: authController.stream,
        );

        // Ensure stream is active
        final stream = repository.watchRepostedAddressableIds();
        final subscription = stream.listen((_) {});

        // Dispose should complete without error
        repository.dispose();

        // After dispose, sending to auth controller should not affect
        // repository
        authController.add(true);
        await Future<void>.delayed(Duration.zero);

        await subscription.cancel();
        await authController.close();
      });

      test('can be called safely without auth stream', () {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        // Should not throw when no auth subscription exists
        expect(repository.dispose, returnsNormally);
      });
    });

    group('offline queuing', () {
      test('repostVideo queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required bool isRepost,
                required String addressableId,
                required String originalAuthorPubkey,
                String? eventId,
              }) async {
                queuedAction = {
                  'isRepost': isRepost,
                  'addressableId': addressableId,
                  'originalAuthorPubkey': originalAuthorPubkey,
                  'eventId': eventId,
                };
              },
        );

        final eventId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, startsWith('pending_repost_'));
        expect(queuedAction['isRepost'], isTrue);
        expect(queuedAction['addressableId'], equals(testAddressableId));
        expect(queuedAction['originalAuthorPubkey'], equals(testAuthorPubkey));

        // Should still show as reposted locally
        expect(repository.isRepostedSync(testAddressableId), isTrue);

        // Should save to local storage
        verify(() => mockLocalStorage.saveRepostRecord(any())).called(1);
      });

      test('unrepostVideo queues action when offline', () async {
        var queuedAction = <String, dynamic>{};

        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        // First repost while online
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(repository.isRepostedSync(testAddressableId), isTrue);

        // Now create a new repository with offline callbacks
        final offlineRepository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required bool isRepost,
                required String addressableId,
                required String originalAuthorPubkey,
                String? eventId,
              }) async {
                queuedAction = {
                  'isRepost': isRepost,
                  'addressableId': addressableId,
                  'originalAuthorPubkey': originalAuthorPubkey,
                };
              },
        );

        // Add the existing repost record to the new repository
        await offlineRepository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Now unrepost while offline
        await offlineRepository.unrepostVideo(testAddressableId);

        expect(queuedAction['isRepost'], isFalse);
        expect(queuedAction['addressableId'], equals(testAddressableId));

        // Should no longer show as reposted locally
        expect(offlineRepository.isRepostedSync(testAddressableId), isFalse);
      });
    });

    group('executeRepostAction', () {
      test('publishes repost directly to relays', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        final eventId = await repository.executeRepostAction(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(eventId, equals(testRepostEventId));

        verify(
          () => mockNostrClient.sendGenericRepost(
            addressableId: testAddressableId,
            targetKind: EventKind.videoVertical,
            authorPubkey: testAuthorPubkey,
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      });

      test('updates placeholder record with real event ID', () async {
        // First create a pending repost (simulating offline queue)
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required bool isRepost,
                required String addressableId,
                required String originalAuthorPubkey,
                String? eventId,
              }) async {},
        );

        final placeholderId = await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(placeholderId, startsWith('pending_repost_'));

        // Now execute the real action (simulating sync)
        final realEventId = await repository.executeRepostAction(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(realEventId, equals(testRepostEventId));

        // Verify local storage was updated
        verify(() => mockLocalStorage.saveRepostRecord(any())).called(2);
      });

      test('throws RepostFailedException when publish fails', () async {
        when(
          () => mockNostrClient.sendGenericRepost(
            addressableId: any(named: 'addressableId'),
            targetKind: any(named: 'targetKind'),
            authorPubkey: any(named: 'authorPubkey'),
            content: any(named: 'content'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
        );

        expect(
          () => repository.executeRepostAction(
            addressableId: testAddressableId,
            originalAuthorPubkey: testAuthorPubkey,
          ),
          throwsA(isA<RepostFailedException>()),
        );
      });
    });

    group('executeUnrepostAction', () {
      test('publishes deletion directly to relays', () async {
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        // First repost
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Now execute unrepost directly
        await repository.executeUnrepostAction(testAddressableId);

        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
        verify(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        ).called(1);
      });

      test('skips deletion for pending reposts', () async {
        // Create a pending repost (offline)
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
          isOnline: () => false,
          queueOfflineAction:
              ({
                required bool isRepost,
                required String addressableId,
                required String originalAuthorPubkey,
                String? eventId,
              }) async {},
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        // Execute unrepost - should not call deleteEvent since never synced
        await repository.executeUnrepostAction(testAddressableId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verify(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        ).called(1);
      });

      test('does nothing when no record exists', () async {
        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        // Should not throw, just return
        await repository.executeUnrepostAction(testAddressableId);

        verifyNever(() => mockNostrClient.deleteEvent(any()));
        verifyNever(
          () => mockLocalStorage.deleteRepostRecord(testAddressableId),
        );
      });

      test('throws UnrepostFailedException when deletion fails', () async {
        when(
          () => mockNostrClient.deleteEvent(any()),
        ).thenAnswer((_) async => null);

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.repostVideo(
          addressableId: testAddressableId,
          originalAuthorPubkey: testAuthorPubkey,
        );

        expect(
          () => repository.executeUnrepostAction(testAddressableId),
          throwsA(isA<UnrepostFailedException>()),
        );
      });

      test('falls back to local storage when not in cache', () async {
        final record = RepostRecord(
          addressableId: testAddressableId,
          repostEventId: testRepostEventId,
          originalAuthorPubkey: testAuthorPubkey,
          createdAt: DateTime.now(),
        );

        when(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).thenAnswer((_) async => record);
        when(() => mockNostrClient.deleteEvent(any())).thenAnswer(
          (_) async => createMockEvent(
            id: 'deletion_event_id',
            kind: 5,
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        final repository = RepostsRepository(
          nostrClient: mockNostrClient,
          localStorage: mockLocalStorage,
        );

        await repository.executeUnrepostAction(testAddressableId);

        verify(
          () => mockLocalStorage.getRepostRecord(testAddressableId),
        ).called(1);
        verify(() => mockNostrClient.deleteEvent(testRepostEventId)).called(1);
      });
    });
  });
}
