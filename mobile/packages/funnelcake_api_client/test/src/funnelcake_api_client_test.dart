// ABOUTME: Tests for FunnelcakeApiClient HTTP client.
// ABOUTME: Tests API calls, error handling, and edge cases.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class MockHttpClient extends Mock implements http.Client {}

class FakeUri extends Fake implements Uri {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeUri());
  });

  group('FunnelcakeApiClient', () {
    late MockHttpClient mockHttpClient;
    late FunnelcakeApiClient client;

    const testBaseUrl = 'https://api.example.com';
    const testPubkey =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    setUp(() {
      mockHttpClient = MockHttpClient();
      client = FunnelcakeApiClient(
        baseUrl: testBaseUrl,
        httpClient: mockHttpClient,
      );
    });

    tearDown(() {
      client.dispose();
    });

    group('constructor', () {
      test('can be instantiated with required parameters', () {
        final apiClient = FunnelcakeApiClient(baseUrl: testBaseUrl);
        expect(apiClient, isNotNull);
        apiClient.dispose();
      });

      test('removes trailing slash from baseUrl', () {
        final apiClient = FunnelcakeApiClient(
          baseUrl: '$testBaseUrl/',
          httpClient: mockHttpClient,
        );
        expect(apiClient.baseUrl, equals(testBaseUrl));
        apiClient.dispose();
      });

      test('preserves baseUrl without trailing slash', () {
        expect(client.baseUrl, equals(testBaseUrl));
      });
    });

    group('isAvailable', () {
      test('returns true when baseUrl is configured', () {
        expect(client.isAvailable, isTrue);
      });

      test('returns false when baseUrl is empty', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );
        expect(emptyClient.isAvailable, isFalse);
        emptyClient.dispose();
      });
    });

    group('getVideosByAuthor', () {
      const validResponseBody =
          '''
[
  {
    "id": "abc123def456",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test-video-1",
    "title": "Test Video",
    "content": "A test video description",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 100,
    "comments": 10,
    "reposts": 5,
    "engagement_score": 115
  }
]
''';

      test('returns videos on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(validResponseBody, 200),
        );

        final videos = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(videos, hasLength(1));
        expect(videos.first.id, equals('abc123def456'));
        expect(videos.first.pubkey, equals(testPubkey));
        expect(videos.first.title, equals('Test Video'));
        expect(videos.first.reactions, equals(100));
      });

      test('constructs correct URL with default limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.getVideosByAuthor(pubkey: testPubkey);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/users/$testPubkey/videos'));
        expect(uri.queryParameters['limit'], equals('50'));
      });

      test('constructs correct URL with custom limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.getVideosByAuthor(pubkey: testPubkey, limit: 100);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('100'));
      });

      test('includes before parameter when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.getVideosByAuthor(
          pubkey: testPubkey,
          before: 1700000000,
        );

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['before'], equals('1700000000'));
      });

      test('sends correct headers', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.getVideosByAuthor(pubkey: testPubkey);

        verify(
          () => mockHttpClient.get(
            any(),
            headers: {
              'Accept': 'application/json',
              'User-Agent': 'OpenVine-Mobile/1.0',
            },
          ),
        ).called(1);
      });

      test('filters out videos with empty id', () async {
        const responseWithEmptyId =
            '''
[
  {
    "id": "",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid Video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "https://example.com/video.mp4",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(responseWithEmptyId, 200),
        );

        final videos = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(videos, isEmpty);
      });

      test('filters out videos with empty videoUrl', () async {
        const responseWithEmptyUrl =
            '''
[
  {
    "id": "abc123",
    "pubkey": "$testPubkey",
    "created_at": 1700000000,
    "kind": 34236,
    "d_tag": "test",
    "title": "Invalid Video",
    "thumbnail": "https://example.com/thumb.jpg",
    "video_url": "",
    "reactions": 0,
    "comments": 0,
    "reposts": 0,
    "engagement_score": 0
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(responseWithEmptyUrl, 200),
        );

        final videos = await client.getVideosByAuthor(pubkey: testPubkey);

        expect(videos, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.getVideosByAuthor(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when pubkey is empty', () {
        expect(
          () => client.getVideosByAuthor(pubkey: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Pubkey cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeNotFoundException on 404', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('Not found', 404),
        );

        expect(
          () => client.getVideosByAuthor(pubkey: testPubkey),
          throwsA(isA<FunnelcakeNotFoundException>()),
        );
      });

      test(
        'throws FunnelcakeApiException on other error status codes',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('Internal Server Error', 500),
          );

          expect(
            () => client.getVideosByAuthor(pubkey: testPubkey),
            throwsA(
              isA<FunnelcakeApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                equals(500),
              ),
            ),
          );
        },
      );

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => throw TimeoutException('Request timed out'),
        );

        expect(
          () => client.getVideosByAuthor(pubkey: testPubkey),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.getVideosByAuthor(pubkey: testPubkey),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to fetch author videos'),
            ),
          ),
        );
      });
    });

    group('searchProfiles', () {
      const validProfileResponse =
          '''
[
  {
    "pubkey": "$testPubkey",
    "name": "testuser",
    "display_name": "Test User",
    "about": "A test profile",
    "picture": "https://example.com/avatar.jpg",
    "nip05": "testuser@example.com",
    "created_at": 1700000000,
    "event_id": "event123"
  }
]
''';

      test('returns profiles on successful response', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(validProfileResponse, 200),
        );

        final profiles = await client.searchProfiles(query: 'test');

        expect(profiles, hasLength(1));
        expect(profiles.first.pubkey, equals(testPubkey));
        expect(profiles.first.name, equals('testuser'));
        expect(profiles.first.displayName, equals('Test User'));
        expect(profiles.first.nip05, equals('testuser@example.com'));
      });

      test('constructs correct URL with default limit', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.path, equals('/api/search/profiles'));
        expect(uri.queryParameters['q'], equals('test'));
        expect(uri.queryParameters['limit'], equals('50'));
        expect(uri.queryParameters.containsKey('offset'), isFalse);
      });

      test('constructs correct URL with custom limit and offset', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: 'test', limit: 25, offset: 10);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['limit'], equals('25'));
        expect(uri.queryParameters['offset'], equals('10'));
      });

      test('trims whitespace from query', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: '  test  ');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['q'], equals('test'));
      });

      test('filters out profiles with empty pubkey', () async {
        const responseWithEmptyPubkey = '''
[
  {
    "pubkey": "",
    "name": "invalid",
    "display_name": "Invalid User"
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(responseWithEmptyPubkey, 200),
        );

        final profiles = await client.searchProfiles(query: 'test');

        expect(profiles, isEmpty);
      });

      test('throws FunnelcakeNotConfiguredException when not available', () {
        final emptyClient = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: mockHttpClient,
        );

        expect(
          () => emptyClient.searchProfiles(query: 'test'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );

        emptyClient.dispose();
      });

      test('throws FunnelcakeException when query is empty', () {
        expect(
          () => client.searchProfiles(query: ''),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Search query cannot be empty'),
            ),
          ),
        );
      });

      test('throws FunnelcakeException when query is only whitespace', () {
        expect(
          () => client.searchProfiles(query: '   '),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Search query cannot be empty'),
            ),
          ),
        );
      });

      test(
        'throws FunnelcakeApiException on error status codes',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('Internal Server Error', 500),
          );

          expect(
            () => client.searchProfiles(query: 'test'),
            throwsA(
              isA<FunnelcakeApiException>().having(
                (e) => e.statusCode,
                'statusCode',
                equals(500),
              ),
            ),
          );
        },
      );

      test('throws FunnelcakeTimeoutException on timeout', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => throw TimeoutException('Request timed out'),
        );

        expect(
          () => client.searchProfiles(query: 'test'),
          throwsA(isA<FunnelcakeTimeoutException>()),
        );
      });

      test('throws FunnelcakeException on network error', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenThrow(Exception('Network error'));

        expect(
          () => client.searchProfiles(query: 'test'),
          throwsA(
            isA<FunnelcakeException>().having(
              (e) => e.message,
              'message',
              contains('Failed to search profiles'),
            ),
          ),
        );
      });

      test('includes sort_by query param when provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: 'test', sortBy: 'followers');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['sort_by'], equals('followers'));
      });

      test('includes has_videos query param when true', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: 'test', hasVideos: true);

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters['has_videos'], equals('true'));
      });

      test('omits has_videos when false (default)', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('has_videos'), isFalse);
      });

      test('omits sort_by when not provided', () async {
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response('[]', 200),
        );

        await client.searchProfiles(query: 'test');

        final captured = verify(
          () =>
              mockHttpClient.get(captureAny(), headers: any(named: 'headers')),
        ).captured;

        final uri = captured.first as Uri;
        expect(uri.queryParameters.containsKey('sort_by'), isFalse);
      });

      test(
        'constructs URL with all params',
        () async {
          when(
            () => mockHttpClient.get(any(), headers: any(named: 'headers')),
          ).thenAnswer(
            (_) async => http.Response('[]', 200),
          );

          await client.searchProfiles(
            query: 'test',
            limit: 25,
            offset: 50,
            sortBy: 'followers',
            hasVideos: true,
          );

          final captured = verify(
            () => mockHttpClient.get(
              captureAny(),
              headers: any(named: 'headers'),
            ),
          ).captured;

          final uri = captured.first as Uri;
          expect(uri.queryParameters['q'], equals('test'));
          expect(uri.queryParameters['limit'], equals('25'));
          expect(uri.queryParameters['offset'], equals('50'));
          expect(uri.queryParameters['sort_by'], equals('followers'));
          expect(uri.queryParameters['has_videos'], equals('true'));
        },
      );

      test('handles pubkey as byte array', () async {
        // Funnelcake sometimes returns IDs as ASCII byte arrays
        const byteArrayResponse = '''
[
  {
    "pubkey": [49, 50, 51, 52, 53, 54, 55, 56],
    "name": "testuser"
  }
]
''';
        when(
          () => mockHttpClient.get(any(), headers: any(named: 'headers')),
        ).thenAnswer(
          (_) async => http.Response(byteArrayResponse, 200),
        );

        final profiles = await client.searchProfiles(query: 'test');

        expect(profiles, hasLength(1));
        expect(profiles.first.pubkey, equals('12345678'));
      });
    });

    group('dispose', () {
      test('does not close externally provided httpClient', () {
        client.dispose();

        verifyNever(() => mockHttpClient.close());
      });

      test('closes internally created httpClient', () {
        // Create client without providing httpClient
        final internalClient = FunnelcakeApiClient(baseUrl: testBaseUrl);
        // We can't verify the internal client is closed, but we can verify
        // the method doesn't throw
        expect(internalClient.dispose, returnsNormally);
      });
    });
  });

  group('Exceptions', () {
    test('FunnelcakeException has correct toString', () {
      const exception = FunnelcakeException('Test error');
      expect(exception.toString(), equals('FunnelcakeException: Test error'));
    });

    test('FunnelcakeNotConfiguredException has correct message', () {
      const exception = FunnelcakeNotConfiguredException();
      expect(exception.message, equals('Funnelcake API not configured'));
    });

    test('FunnelcakeApiException includes status code', () {
      const exception = FunnelcakeApiException(
        message: 'Test error',
        statusCode: 500,
        url: 'https://example.com',
      );
      expect(exception.statusCode, equals(500));
      expect(exception.url, equals('https://example.com'));
      expect(
        exception.toString(),
        equals('FunnelcakeApiException: Test error (status: 500)'),
      );
    });

    test('FunnelcakeNotFoundException has correct resource message', () {
      final exception = FunnelcakeNotFoundException(
        resource: 'Video',
        url: 'https://example.com',
      );
      expect(exception.message, equals('Video not found'));
      expect(exception.statusCode, equals(404));
    });

    test('FunnelcakeTimeoutException includes URL when provided', () {
      const exceptionWithUrl = FunnelcakeTimeoutException(
        'https://example.com',
      );
      expect(
        exceptionWithUrl.message,
        equals('Request timed out for https://example.com'),
      );

      const exceptionWithoutUrl = FunnelcakeTimeoutException();
      expect(exceptionWithoutUrl.message, equals('Request timed out'));
    });
  });
}
