import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:videos_repository/videos_repository.dart';

class MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('VideosRepository', () {
    late MockNostrClient mockNostrClient;
    late VideosRepository repository;

    setUp(() {
      mockNostrClient = MockNostrClient();
      repository = VideosRepository(nostrClient: mockNostrClient);
    });

    setUpAll(() {
      registerFallbackValue(<Filter>[]);
    });

    test('can be instantiated', () {
      expect(repository, isNotNull);
    });

    group('getNewVideos', () {
      test('returns empty list when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getNewVideos();

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter for video kind', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        await repository.getNewVideos(limit: 10);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        const until = 1704067200; // 2024-01-01 00:00:00 UTC
        await repository.getNewVideos(until: until);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms valid events to VideoEvents', () async {
        final event = _createVideoEvent(
          id: 'test-id-123',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('test-id-123'));
        expect(result.first.videoUrl, equals('https://example.com/video.mp4'));
      });

      test('filters out videos without valid URL', () async {
        final validEvent = _createVideoEvent(
          id: 'valid-id',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );
        final invalidEvent = _createVideoEvent(
          id: 'invalid-id',
          pubkey: 'test-pubkey',
          videoUrl: null,
          createdAt: 1704067201,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [validEvent, invalidEvent],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(1));
        expect(result.first.id, equals('valid-id'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'test-pubkey',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [olderEvent, newerEvent],
        );

        final result = await repository.getNewVideos();

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });
    });

    group('getHomeFeedVideos', () {
      test('returns empty list when authors is empty', () async {
        final result = await repository.getHomeFeedVideos(authors: []);

        expect(result, isEmpty);
        verifyNever(() => mockNostrClient.queryEvents(any()));
      });

      test('returns empty list when no events found', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['pubkey1', 'pubkey2'],
        );

        expect(result, isEmpty);
        verify(() => mockNostrClient.queryEvents(any())).called(1);
      });

      test('queries with correct filter including authors', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        final authors = ['pubkey1', 'pubkey2'];
        await repository.getHomeFeedVideos(authors: authors, limit: 10);

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters, hasLength(1));
        expect(filters.first.kinds, contains(EventKind.videoVertical));
        expect(filters.first.authors, equals(authors));
        expect(filters.first.limit, equals(10));
      });

      test('passes until parameter for pagination', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => <Event>[],
        );

        const until = 1704067200;
        await repository.getHomeFeedVideos(
          authors: ['pubkey1'],
          until: until,
        );

        final captured = verify(
          () => mockNostrClient.queryEvents(captureAny()),
        ).captured;
        final filters = captured.first as List<Filter>;

        expect(filters.first.until, equals(until));
      });

      test('transforms and filters events correctly', () async {
        final event = _createVideoEvent(
          id: 'home-video-123',
          pubkey: 'followed-user',
          videoUrl: 'https://example.com/video.mp4',
          createdAt: 1704067200,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [event],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['followed-user'],
        );

        expect(result, hasLength(1));
        expect(result.first.id, equals('home-video-123'));
        expect(result.first.pubkey, equals('followed-user'));
      });

      test('sorts videos by creation time (newest first)', () async {
        final olderEvent = _createVideoEvent(
          id: 'older',
          pubkey: 'user1',
          videoUrl: 'https://example.com/old.mp4',
          createdAt: 1704067200,
        );
        final newerEvent = _createVideoEvent(
          id: 'newer',
          pubkey: 'user2',
          videoUrl: 'https://example.com/new.mp4',
          createdAt: 1704153600,
        );

        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [olderEvent, newerEvent],
        );

        final result = await repository.getHomeFeedVideos(
          authors: ['user1', 'user2'],
        );

        expect(result, hasLength(2));
        expect(result.first.id, equals('newer'));
        expect(result.last.id, equals('older'));
      });
    });

    group('getPopularVideos', () {
      group('NIP-50 server-side sorting', () {
        test('tries NIP-50 query first with sort:hot', () async {
          final event = _createVideoEvent(
            id: 'popular-video',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          final result = await repository.getPopularVideos();

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: captureAny(named: 'useCache'),
            ),
          ).captured;
          final filters = captured[0] as List<Filter>;
          final useCache = captured[1] as bool;

          expect(filters.first.search, equals('sort:hot'));
          expect(
            filters.first.limit,
            equals(5),
          ); // Default limit, not multiplied
          expect(useCache, isFalse);
          expect(result, hasLength(1));
        });

        test('uses exact limit for NIP-50 query (no multiplier)', () async {
          final event = _createVideoEvent(
            id: 'video-1',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          await repository.getPopularVideos(limit: 10);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;
          final filters = captured.first as List<Filter>;

          expect(filters.first.limit, equals(10));
        });

        test('passes until parameter to NIP-50 query', () async {
          final event = _createVideoEvent(
            id: 'video-1',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/video.mp4',
            createdAt: 1704067200,
          );

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => [event]);

          const until = 1704067200;
          await repository.getPopularVideos(until: until);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;
          final filters = captured.first as List<Filter>;

          expect(filters.first.until, equals(until));
        });

        test('returns NIP-50 results without client-side sorting', () async {
          // NIP-50 results come pre-sorted from relay
          final events = [
            _createVideoEvent(
              id: 'relay-sorted-1',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video1.mp4',
              createdAt: 1704067200,
              loops: 10, // Lower loops but relay says it's #1
            ),
            _createVideoEvent(
              id: 'relay-sorted-2',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video2.mp4',
              createdAt: 1704067201,
              loops: 1000, // Higher loops but relay says it's #2
            ),
          ];

          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => events);

          final result = await repository.getPopularVideos(limit: 2);

          // Should preserve relay order, not re-sort by loops
          expect(result, hasLength(2));
          expect(result.first.id, equals('relay-sorted-1'));
          expect(result.last.id, equals('relay-sorted-2'));

          // Only one query should be made (no fallback)
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(1);
        });
      });

      group('fallback to client-side sorting', () {
        test('falls back when NIP-50 returns empty', () async {
          // First call (NIP-50) returns empty
          // Second call (fallback) returns events
          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return [
              _createVideoEvent(
                id: 'fallback-video',
                pubkey: 'test-pubkey',
                videoUrl: 'https://example.com/video.mp4',
                createdAt: 1704067200,
              ),
            ];
          });

          final result = await repository.getPopularVideos();

          expect(result, hasLength(1));
          expect(result.first.id, equals('fallback-video'));
          verify(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).called(2);
        });

        test('fallback fetches more events than limit for sorting', () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos();

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;

          // First call: NIP-50 with exact limit
          final nip50Filters = captured[0] as List<Filter>;
          expect(nip50Filters.first.limit, equals(5));
          expect(nip50Filters.first.search, equals('sort:hot'));

          // Second call: fallback with multiplied limit
          // captured[1] contains filters from second call
          // (only filters are captured)
          final fallbackFilters = captured[1] as List<Filter>;
          expect(fallbackFilters.first.limit, equals(20)); // 5 * 4
          expect(fallbackFilters.first.search, isNull);
        });

        test('fallback respects custom fetch multiplier', () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          await repository.getPopularVideos(fetchMultiplier: 2);

          final captured = verify(
            () => mockNostrClient.queryEvents(
              captureAny(),
              useCache: any(named: 'useCache'),
            ),
          ).captured;

          // Second call: fallback with multiplied limit
          // captured[1] contains filters from second call
          // (only filters are captured)
          final fallbackFilters = captured[1] as List<Filter>;
          expect(fallbackFilters.first.limit, equals(10)); // 5 * 2
        });

        test('fallback sorts by engagement score (highest first)', () async {
          final lowEngagement = _createVideoEvent(
            id: 'low',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/low.mp4',
            createdAt: 1704067200,
            loops: 10,
          );
          final highEngagement = _createVideoEvent(
            id: 'high',
            pubkey: 'test-pubkey',
            videoUrl: 'https://example.com/high.mp4',
            createdAt: 1704067201,
            loops: 1000,
          );

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return [lowEngagement, highEngagement];
          });

          final result = await repository.getPopularVideos(limit: 2);

          expect(result, hasLength(2));
          expect(result.first.id, equals('high'));
          expect(result.last.id, equals('low'));
        });

        test('fallback returns only requested limit after sorting', () async {
          final events = List.generate(
            10,
            (i) => _createVideoEvent(
              id: 'video-$i',
              pubkey: 'test-pubkey',
              videoUrl: 'https://example.com/video$i.mp4',
              createdAt: 1704067200 + i,
              loops: i * 100,
            ),
          );

          var callCount = 0;
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async {
            callCount++;
            if (callCount == 1) return <Event>[]; // NIP-50 empty
            return events;
          });

          final result = await repository.getPopularVideos(limit: 3);

          expect(result, hasLength(3));
        });
      });

      test(
        'returns empty list when both NIP-50 and fallback return empty',
        () async {
          when(
            () => mockNostrClient.queryEvents(
              any(),
              useCache: any(named: 'useCache'),
            ),
          ).thenAnswer((_) async => <Event>[]);

          final result = await repository.getPopularVideos();

          expect(result, isEmpty);
        },
      );
    });
  });
}

/// Creates a mock video event for testing.
Event _createVideoEvent({
  required String id,
  required String pubkey,
  required String? videoUrl,
  required int createdAt,
  int? loops,
}) {
  final tags = <List<String>>[
    if (videoUrl != null) ['url', videoUrl],
    if (loops != null) ['loops', loops.toString()],
    ['d', id], // Required for addressable events
  ];

  return Event.fromJson({
    'id': id,
    'pubkey': pubkey,
    'created_at': createdAt,
    'kind': EventKind.videoVertical,
    'tags': tags,
    'content': '',
    'sig': '',
  });
}
