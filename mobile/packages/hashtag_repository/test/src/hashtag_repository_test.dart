// ABOUTME: Tests for HashtagRepository.
// ABOUTME: Tests delegation to FunnelcakeApiClient and exception propagation.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group(HashtagRepository, () {
    late _MockFunnelcakeApiClient mockClient;
    late HashtagRepository repository;

    setUp(() {
      mockClient = _MockFunnelcakeApiClient();
      repository = HashtagRepository(funnelcakeApiClient: mockClient);
    });

    group('searchHashtags', () {
      test(
        'delegates to FunnelcakeApiClient with correct parameters',
        () async {
          when(
            () => mockClient.searchHashtags(
              query: 'bitcoin',
            ),
          ).thenAnswer((_) async => ['bitcoin', 'bitcoinmining']);

          final results = await repository.searchHashtags(query: 'bitcoin');

          expect(results, equals(['bitcoin', 'bitcoinmining']));
          verify(
            () => mockClient.searchHashtags(query: 'bitcoin'),
          ).called(1);
        },
      );

      test('passes custom limit to client', () async {
        when(
          () => mockClient.searchHashtags(
            query: 'nostr',
            limit: 50,
          ),
        ).thenAnswer((_) async => ['nostr']);

        final results = await repository.searchHashtags(
          query: 'nostr',
          limit: 50,
        );

        expect(results, equals(['nostr']));
        verify(
          () => mockClient.searchHashtags(query: 'nostr', limit: 50),
        ).called(1);
      });

      test('passes null query to client', () async {
        when(
          () => mockClient.searchHashtags(),
        ).thenAnswer((_) async => ['trending1', 'trending2']);

        final results = await repository.searchHashtags();

        expect(results, equals(['trending1', 'trending2']));
        verify(() => mockClient.searchHashtags()).called(1);
      });

      test('returns empty list when client returns empty', () async {
        when(
          () => mockClient.searchHashtags(query: 'zzzzz'),
        ).thenAnswer((_) async => []);

        final results = await repository.searchHashtags(query: 'zzzzz');

        expect(results, isEmpty);
      });

      test('propagates FunnelcakeNotConfiguredException', () {
        when(
          () => mockClient.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        expect(
          () => repository.searchHashtags(query: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );
      });

      test('propagates FunnelcakeApiException', () {
        when(
          () => mockClient.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/hashtags',
          ),
        );

        expect(
          () => repository.searchHashtags(query: 'test'),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('propagates FunnelcakeTimeoutException', () {
        when(
          () => mockClient.searchHashtags(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeTimeoutException());

        expect(
          () => repository.searchHashtags(query: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('fetchTrendingHashtags', () {
      test(
        'delegates to FunnelcakeApiClient with correct parameters',
        () async {
          final trendingHashtags = [
            const TrendingHashtag(
              tag: 'bitcoin',
              videoCount: 42,
              uniqueCreators: 10,
              totalLoops: 1000,
            ),
            const TrendingHashtag(
              tag: 'nostr',
              videoCount: 30,
              uniqueCreators: 8,
              totalLoops: 500,
            ),
          ];

          when(
            () => mockClient.fetchTrendingHashtags(),
          ).thenAnswer((_) async => trendingHashtags);

          final results = await repository.fetchTrendingHashtags();

          expect(results, equals(trendingHashtags));
          verify(() => mockClient.fetchTrendingHashtags()).called(1);
        },
      );

      test('passes custom limit to client', () async {
        when(
          () => mockClient.fetchTrendingHashtags(limit: 50),
        ).thenAnswer(
          (_) async => [
            const TrendingHashtag(
              tag: 'bitcoin',
              videoCount: 42,
              uniqueCreators: 10,
              totalLoops: 1000,
            ),
          ],
        );

        final results = await repository.fetchTrendingHashtags(limit: 50);

        expect(results, hasLength(1));
        verify(() => mockClient.fetchTrendingHashtags(limit: 50)).called(1);
      });

      test('returns empty list when client returns empty', () async {
        when(
          () => mockClient.fetchTrendingHashtags(),
        ).thenAnswer((_) async => []);

        final results = await repository.fetchTrendingHashtags();

        expect(results, isEmpty);
      });

      test('propagates FunnelcakeNotConfiguredException', () {
        when(
          () => mockClient.fetchTrendingHashtags(
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeNotConfiguredException());

        expect(
          () => repository.fetchTrendingHashtags(),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );
      });

      test('propagates FunnelcakeApiException', () {
        when(
          () => mockClient.fetchTrendingHashtags(
            limit: any(named: 'limit'),
          ),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 500,
            url: 'https://example.com/api/hashtags/trending',
          ),
        );

        expect(
          () => repository.fetchTrendingHashtags(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(500),
            ),
          ),
        );
      });

      test('propagates FunnelcakeTimeoutException', () {
        when(
          () => mockClient.fetchTrendingHashtags(
            limit: any(named: 'limit'),
          ),
        ).thenThrow(const FunnelcakeTimeoutException());

        expect(
          () => repository.fetchTrendingHashtags(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });

    group('getTrendingHashtags', () {
      late HashtagRepository cachingRepository;

      setUp(() {
        cachingRepository = HashtagRepository(
          funnelcakeApiClient: mockClient,
        );
      });

      test('fetches from client on cache miss', () async {
        final trendingHashtags = [
          const TrendingHashtag(
            tag: 'bitcoin',
            videoCount: 42,
            uniqueCreators: 10,
            totalLoops: 1000,
          ),
        ];
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenAnswer((_) async => trendingHashtags);

        final results = await cachingRepository.getTrendingHashtags();

        expect(results, equals(trendingHashtags));
        verify(
          () => mockClient.fetchTrendingHashtags(),
        ).called(1);
      });

      test(
        'returns cached result on second call without force refresh',
        () async {
          final trendingHashtags = [
            const TrendingHashtag(
              tag: 'nostr',
              videoCount: 30,
              uniqueCreators: 8,
              totalLoops: 500,
            ),
          ];
          when(
            () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
          ).thenAnswer((_) async => trendingHashtags);

          await cachingRepository.getTrendingHashtags();
          final secondResult = await cachingRepository.getTrendingHashtags();

          expect(secondResult, equals(trendingHashtags));
          // Client called only once; second call served from cache.
          verify(
            () => mockClient.fetchTrendingHashtags(),
          ).called(1);
        },
      );

      test('bypasses cache when forceRefresh is true', () async {
        final firstBatch = [
          const TrendingHashtag(
            tag: 'vine',
            videoCount: 10,
            uniqueCreators: 3,
            totalLoops: 100,
          ),
        ];
        final secondBatch = [
          const TrendingHashtag(
            tag: 'openvine',
            videoCount: 20,
            uniqueCreators: 5,
            totalLoops: 200,
          ),
        ];
        var callCount = 0;
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenAnswer((_) async {
          callCount++;
          return callCount == 1 ? firstBatch : secondBatch;
        });

        await cachingRepository.getTrendingHashtags();
        final refreshed = await cachingRepository.getTrendingHashtags(
          forceRefresh: true,
        );

        expect(refreshed, equals(secondBatch));
        verify(
          () => mockClient.fetchTrendingHashtags(),
        ).called(2);
      });

      test('cache expires after cacheDuration', () async {
        final expiredRepository = HashtagRepository(
          funnelcakeApiClient: mockClient,
          cacheDuration: Duration.zero,
        );
        final hashtags = [
          const TrendingHashtag(
            tag: 'bitcoin',
            videoCount: 42,
            uniqueCreators: 10,
            totalLoops: 1000,
          ),
        ];
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenAnswer((_) async => hashtags);

        await expiredRepository.getTrendingHashtags();
        await expiredRepository.getTrendingHashtags();

        // With Duration.zero the cache is always stale, so client is called
        // twice.
        verify(
          () => mockClient.fetchTrendingHashtags(),
        ).called(2);
      });

      test('passes custom limit to client', () async {
        when(
          () => mockClient.fetchTrendingHashtags(limit: 50),
        ).thenAnswer((_) async => []);

        await cachingRepository.getTrendingHashtags(limit: 50);

        verify(() => mockClient.fetchTrendingHashtags(limit: 50)).called(1);
      });

      test(
        'returns default hashtags when API is not configured',
        () async {
          when(
            () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
          ).thenThrow(const FunnelcakeNotConfiguredException());

          final results = await cachingRepository.getTrendingHashtags();

          expect(results, isNotEmpty);
          expect(results.first, isA<TrendingHashtag>());
          // Does not throw — callers always get a usable list.
        },
      );

      test(
        'default hashtags respect the limit parameter',
        () async {
          when(
            () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
          ).thenThrow(const FunnelcakeNotConfiguredException());

          final results = await cachingRepository.getTrendingHashtags(limit: 5);

          expect(results, hasLength(5));
        },
      );

      test('propagates FunnelcakeApiException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(
          const FunnelcakeApiException(
            message: 'Server error',
            statusCode: 503,
            url: 'https://example.com/api/hashtags',
          ),
        );

        expect(
          () => cachingRepository.getTrendingHashtags(),
          throwsA(
            isA<FunnelcakeApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              equals(503),
            ),
          ),
        );
      });

      test('propagates FunnelcakeTimeoutException', () {
        when(
          () => mockClient.fetchTrendingHashtags(limit: any(named: 'limit')),
        ).thenThrow(const FunnelcakeTimeoutException());

        expect(
          () => cachingRepository.getTrendingHashtags(),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });
    });
  });
}
