// ABOUTME: Unit tests for DbVideoLocalStorage implementation.
// ABOUTME: Tests the db_client-backed local storage for video events.

import 'dart:async';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrEventsDao extends Mock implements NostrEventsDao {}

void main() {
  group('DbVideoLocalStorage', () {
    late MockNostrEventsDao mockDao;
    late DbVideoLocalStorage storage;

    /// Valid 64-char hex IDs for testing
    const testEventId1 =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testEventId2 =
        'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testPubkey1 =
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
    const testPubkey2 =
        'fedcba9876543210fedcba9876543210fedcba9876543210fedcba9876543210';

    /// Video event kind (NIP-71)
    const videoKind = 34236;

    /// Create a test video event
    Event createTestEvent({
      String? id,
      String? pubkey,
      int? createdAt,
    }) {
      final event =
          Event(
              pubkey ?? testPubkey1,
              videoKind,
              [
                ['d', 'test-vine-id'],
                ['url', 'https://example.com/video.mp4'],
                ['t', 'test'],
              ],
              'Test video',
              createdAt:
                  createdAt ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
            )
            // Set id manually for testing
            ..id = id ?? testEventId1
            ..sig = 'test-signature';
      return event;
    }

    setUpAll(() {
      registerFallbackValue(createTestEvent());
      registerFallbackValue(<Event>[]);
      registerFallbackValue(Filter(kinds: [videoKind]));
    });

    setUp(() {
      mockDao = MockNostrEventsDao();
      storage = DbVideoLocalStorage(dao: mockDao);
    });

    group('constructor', () {
      test('creates storage with dao', () {
        final storage = DbVideoLocalStorage(dao: mockDao);
        expect(storage, isNotNull);
      });
    });

    group('saveEvent', () {
      test('calls dao.upsertEvent', () async {
        when(() => mockDao.upsertEvent(any())).thenAnswer((_) async {});

        final event = createTestEvent();
        await storage.saveEvent(event);

        verify(() => mockDao.upsertEvent(event)).called(1);
      });
    });

    group('saveEventsBatch', () {
      test('calls dao.upsertEventsBatch', () async {
        when(() => mockDao.upsertEventsBatch(any())).thenAnswer((_) async {});

        final events = [
          createTestEvent(id: testEventId1),
          createTestEvent(id: testEventId2),
        ];

        await storage.saveEventsBatch(events);

        verify(() => mockDao.upsertEventsBatch(events)).called(1);
      });

      test('does not call dao when events list is empty', () async {
        await storage.saveEventsBatch([]);

        verifyNever(() => mockDao.upsertEventsBatch(any()));
      });
    });

    group('getEventById', () {
      test('returns event when found', () async {
        final event = createTestEvent();
        when(() => mockDao.getEventById(any())).thenAnswer((_) async => event);

        final result = await storage.getEventById(testEventId1);

        expect(result, equals(event));
        verify(() => mockDao.getEventById(testEventId1)).called(1);
      });

      test('returns null when not found', () async {
        when(() => mockDao.getEventById(any())).thenAnswer((_) async => null);

        final result = await storage.getEventById(testEventId1);

        expect(result, isNull);
      });
    });

    group('getEventsByIds', () {
      test('returns events matching IDs', () async {
        final events = [
          createTestEvent(id: testEventId1),
          createTestEvent(id: testEventId2),
        ];

        when(
          () => mockDao.getEventsByFilter(any()),
        ).thenAnswer((_) async => events);

        final result = await storage.getEventsByIds([
          testEventId1,
          testEventId2,
        ]);

        expect(result.length, equals(2));
        verify(() => mockDao.getEventsByFilter(any())).called(1);
      });

      test('returns empty list for empty IDs', () async {
        final result = await storage.getEventsByIds([]);

        expect(result, isEmpty);
        verifyNever(() => mockDao.getEventsByFilter(any()));
      });
    });

    group('getEventsByAuthors', () {
      test('returns events from specified authors', () async {
        final events = [
          createTestEvent(pubkey: testPubkey1),
          createTestEvent(pubkey: testPubkey2),
        ];

        when(
          () => mockDao.getEventsByFilter(any()),
        ).thenAnswer((_) async => events);

        final result = await storage.getEventsByAuthors(
          authors: [testPubkey1, testPubkey2],
        );

        expect(result.length, equals(2));

        // Verify filter was created with correct authors
        final captured = verify(
          () => mockDao.getEventsByFilter(captureAny()),
        ).captured;
        final filter = captured.first as Filter;
        expect(filter.authors, containsAll([testPubkey1, testPubkey2]));
        expect(filter.kinds, contains(videoKind));
        expect(filter.limit, equals(50));
      });

      test('respects limit and until parameters', () async {
        when(
          () => mockDao.getEventsByFilter(any()),
        ).thenAnswer((_) async => []);

        await storage.getEventsByAuthors(
          authors: [testPubkey1],
          limit: 25,
          until: 1700000000,
        );

        final captured = verify(
          () => mockDao.getEventsByFilter(captureAny()),
        ).captured;
        final filter = captured.first as Filter;
        expect(filter.limit, equals(25));
        expect(filter.until, equals(1700000000));
      });

      test('returns empty list for empty authors', () async {
        final result = await storage.getEventsByAuthors(authors: []);

        expect(result, isEmpty);
        verifyNever(() => mockDao.getEventsByFilter(any()));
      });
    });

    group('getAllEvents', () {
      test('returns all video events', () async {
        final events = [
          createTestEvent(id: testEventId1),
          createTestEvent(id: testEventId2),
        ];

        when(
          () => mockDao.getEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).thenAnswer((_) async => events);

        final result = await storage.getAllEvents();

        expect(result.length, equals(2));
        verify(
          () => mockDao.getEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).called(1);
      });

      test('passes sortBy parameter to dao', () async {
        when(
          () => mockDao.getEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).thenAnswer((_) async => []);

        await storage.getAllEvents(sortBy: 'loop_count');

        verify(
          () => mockDao.getEventsByFilter(any(), sortBy: 'loop_count'),
        ).called(1);
      });

      test('respects limit and until parameters', () async {
        when(
          () => mockDao.getEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).thenAnswer((_) async => []);

        await storage.getAllEvents(
          limit: 100,
          until: 1700000000,
        );

        final captured = verify(
          () => mockDao.getEventsByFilter(
            captureAny(),
            sortBy: any(named: 'sortBy'),
          ),
        ).captured;
        final filter = captured.first as Filter;
        expect(filter.limit, equals(100));
        expect(filter.until, equals(1700000000));
      });
    });

    group('getEventsByHashtags', () {
      test('returns events matching hashtags', () async {
        final events = [createTestEvent()];

        when(
          () => mockDao.getEventsByFilter(any()),
        ).thenAnswer((_) async => events);

        final result = await storage.getEventsByHashtags(
          hashtags: ['test', 'flutter'],
        );

        expect(result.length, equals(1));

        final captured = verify(
          () => mockDao.getEventsByFilter(captureAny()),
        ).captured;
        final filter = captured.first as Filter;
        expect(filter.t, containsAll(['test', 'flutter']));
        expect(filter.kinds, contains(videoKind));
      });

      test('returns empty list for empty hashtags', () async {
        final result = await storage.getEventsByHashtags(hashtags: []);

        expect(result, isEmpty);
        verifyNever(() => mockDao.getEventsByFilter(any()));
      });
    });

    group('watchEventsByAuthors', () {
      test('returns stream from dao', () async {
        final controller = StreamController<List<Event>>();
        when(
          () => mockDao.watchEventsByFilter(any()),
        ).thenAnswer((_) => controller.stream);

        final stream = storage.watchEventsByAuthors(authors: [testPubkey1]);

        final event1 = createTestEvent(id: testEventId1);
        final event2 = createTestEvent(id: testEventId2);

        controller
          ..add([event1])
          ..add([event1, event2]);

        final emissions = await stream.take(2).toList();

        expect(emissions[0].length, equals(1));
        expect(emissions[1].length, equals(2));

        verify(() => mockDao.watchEventsByFilter(any())).called(1);

        await controller.close();
      });

      test('returns empty stream for empty authors', () async {
        final stream = storage.watchEventsByAuthors(authors: []);

        final events = await stream.first;
        expect(events, isEmpty);

        verifyNever(() => mockDao.watchEventsByFilter(any()));
      });
    });

    group('watchAllEvents', () {
      test('returns stream from dao', () async {
        final controller = StreamController<List<Event>>();
        when(
          () =>
              mockDao.watchEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).thenAnswer((_) => controller.stream);

        final stream = storage.watchAllEvents();

        final event = createTestEvent();
        controller.add([event]);

        final emissions = await stream.take(1).toList();

        expect(emissions[0].length, equals(1));

        verify(
          () =>
              mockDao.watchEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).called(1);

        await controller.close();
      });

      test('passes sortBy parameter to dao', () {
        final controller = StreamController<List<Event>>.broadcast();
        when(
          () =>
              mockDao.watchEventsByFilter(any(), sortBy: any(named: 'sortBy')),
        ).thenAnswer((_) => controller.stream);

        // Just verify the call is made with correct parameters
        // Don't await anything to avoid timeout
        storage.watchAllEvents(sortBy: 'likes');

        verify(
          () => mockDao.watchEventsByFilter(any(), sortBy: 'likes'),
        ).called(1);

        unawaited(controller.close());
      });
    });

    group('deleteEvent', () {
      test('returns true when deletion succeeds', () async {
        when(
          () => mockDao.deleteEventById(any()),
        ).thenAnswer((_) async => true);

        final result = await storage.deleteEvent(testEventId1);

        expect(result, isTrue);
        verify(() => mockDao.deleteEventById(testEventId1)).called(1);
      });

      test('returns false when event not found', () async {
        when(
          () => mockDao.deleteEventById(any()),
        ).thenAnswer((_) async => false);

        final result = await storage.deleteEvent(testEventId1);

        expect(result, isFalse);
      });
    });

    group('deleteEventsByIds', () {
      test('returns count of deleted events', () async {
        when(() => mockDao.deleteEventsByIds(any())).thenAnswer((_) async => 2);

        final result = await storage.deleteEventsByIds([
          testEventId1,
          testEventId2,
        ]);

        expect(result, equals(2));
        verify(
          () => mockDao.deleteEventsByIds([testEventId1, testEventId2]),
        ).called(1);
      });

      test('returns 0 for empty IDs list', () async {
        final result = await storage.deleteEventsByIds([]);

        expect(result, equals(0));
        verifyNever(() => mockDao.deleteEventsByIds(any()));
      });
    });

    group('clearAll', () {
      test('calls dao.deleteEventsByKind with video kind', () async {
        when(
          () => mockDao.deleteEventsByKind(any()),
        ).thenAnswer((_) async => 10);

        await storage.clearAll();

        verify(() => mockDao.deleteEventsByKind(videoKind)).called(1);
      });
    });

    group('getEventCount', () {
      test('returns count from dao', () async {
        when(() => mockDao.getEventCount()).thenAnswer((_) async => 42);

        final result = await storage.getEventCount();

        expect(result, equals(42));
        verify(() => mockDao.getEventCount()).called(1);
      });
    });
  });
}
