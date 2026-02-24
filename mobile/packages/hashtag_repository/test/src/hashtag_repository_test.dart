// ABOUTME: Tests for HashtagRepository.
// ABOUTME: Tests delegation to FunnelcakeApiClient and exception propagation.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:mocktail/mocktail.dart';
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
  });
}
