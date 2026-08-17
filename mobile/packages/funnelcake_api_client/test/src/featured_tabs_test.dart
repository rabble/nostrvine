// ABOUTME: Tests for featured hashtag tab config and video fetching.
// ABOUTME: Covers locale fallback, window checks, ordering, and pagination.

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

class _FakeUri extends Fake implements Uri {}

const _testBaseUrl = 'https://api.example.com';
const _pubkey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

String _videoJson(String id, String dTag) =>
    '''
{
  "id": "$id",
  "pubkey": "$_pubkey",
  "created_at": 1700000000,
  "kind": 34236,
  "d_tag": "$dTag",
  "title": "Test Video",
  "thumbnail": "https://example.com/thumb.jpg",
  "video_url": "https://example.com/video.mp4",
  "reactions": 1,
  "comments": 2,
  "reposts": 3,
  "engagement_score": 6
}''';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeUri());
  });

  group(FeaturedTabConfig, () {
    test('resolves the exact locale when present', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'label': {'default': 'Fallback', 'es': 'Destacado'},
      });

      expect(tab.labelFor('es'), equals('Destacado'));
    });

    test('falls back to default for a locale absent from the map', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'label': {'default': 'Fallback', 'es': 'Destacado'},
      });

      expect(tab.labelFor('ja'), equals('Fallback'));
    });

    test('falls back to the base language for a regional locale', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'label': {'default': 'Fallback', 'pt': 'Destaque'},
      });

      expect(tab.labelFor('pt-BR'), equals('Destaque'));
    });

    test('returns an empty label when the map carries no usable entry', () {
      final tab = FeaturedTabConfig.fromJson(const {'id': 'ft_a1b2c3d4'});

      expect(tab.labelFor('en'), isEmpty);
    });

    test('reads a bare string sponsor name as the default entry', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'disclosure_label': 'Acme Bikes',
      });

      expect(tab.sponsorNameFor('en'), equals('Acme Bikes'));
      expect(tab.isSponsored, isTrue);
    });

    test('reads a per-locale sponsor name', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'disclosure_label': {'default': 'Acme Bikes', 'pt': 'Acme Bicicletas'},
      });

      expect(tab.sponsorNameFor('pt-BR'), equals('Acme Bicicletas'));
    });

    test('is unsponsored when the server sends a null sponsor name', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'disclosure_label': null,
      });

      expect(tab.sponsorNameFor('en'), isNull);
      expect(tab.isSponsored, isFalse);
    });

    test('is unsponsored when the server omits the key entirely', () {
      // What an older backend returns, before the sponsorship fields ship.
      final tab = FeaturedTabConfig.fromJson(const {'id': 'ft_a1b2c3d4'});

      expect(tab.sponsorNameFor('en'), isNull);
      expect(tab.isSponsored, isFalse);
    });

    test('is unsponsored when the sponsor name is an empty string', () {
      // Funnelcake normalises empty to null on write, but a sponsored tab
      // with nobody to credit cannot be disclosed and must not be styled as
      // one, so the client does not depend on that normalisation.
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'disclosure_label': '',
      });

      expect(tab.isSponsored, isFalse);
    });

    test('reads a bare string pill label as the default entry', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'pill_label': 'Skate Week',
      });

      expect(tab.pillLabelFor('en'), equals('Skate Week'));
    });

    test('returns a null pill label when the server omits it', () {
      final tab = FeaturedTabConfig.fromJson(const {'id': 'ft_a1b2c3d4'});

      expect(tab.pillLabelFor('en'), isNull);
    });

    test('ignores the position object entirely', () {
      // Placement is fixed on mobile so it cannot drift from web, and the
      // payload carries per-platform anchors that need not name a tab this
      // client has. Parsing it at all would be dead weight.
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'position': {
          'web': {'after': 'classics'},
        },
      });

      expect(tab.id, equals('ft_a1b2c3d4'));
    });

    test('is outside the window before it starts', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'starts_at': '2026-02-01T00:00:00Z',
        'ends_at': '2026-03-01T00:00:00Z',
      });

      expect(tab.isWithinWindow(DateTime.utc(2026, 1, 31)), isFalse);
    });

    test('is inside the window between its bounds', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'starts_at': '2026-02-01T00:00:00Z',
        'ends_at': '2026-03-01T00:00:00Z',
      });

      expect(tab.isWithinWindow(DateTime.utc(2026, 2, 15)), isTrue);
    });

    test('is outside the window at the exclusive end bound', () {
      final tab = FeaturedTabConfig.fromJson(const {
        'id': 'ft_a1b2c3d4',
        'starts_at': '2026-02-01T00:00:00Z',
        'ends_at': '2026-03-01T00:00:00Z',
      });

      expect(tab.isWithinWindow(DateTime.utc(2026, 3)), isFalse);
    });

    test('treats a missing bound as unbounded', () {
      final tab = FeaturedTabConfig.fromJson(const {'id': 'ft_a1b2c3d4'});

      expect(tab.isWithinWindow(DateTime.utc(2026, 2, 15)), isTrue);
    });

    test('drops tabs whose id is missing', () {
      final response = FeaturedTabsResponse.fromJson(const {
        'featured_tabs': [
          {'slug': 'no-id'},
          {'id': 'ft_a1b2c3d4'},
        ],
      });

      expect(response.tabs.map((t) => t.id), equals(['ft_a1b2c3d4']));
    });

    test('uses the server poll interval', () {
      final response = FeaturedTabsResponse.fromJson(const {
        'poll_interval_seconds': 120,
        'featured_tabs': <dynamic>[],
      });

      expect(response.pollInterval, equals(const Duration(seconds: 120)));
    });

    test('clamps a too-fast server poll interval', () {
      final response = FeaturedTabsResponse.fromJson(const {
        'poll_interval_seconds': 1,
        'featured_tabs': <dynamic>[],
      });

      expect(
        response.pollInterval,
        equals(FeaturedTabsResponse.minPollInterval),
      );
    });

    test('clamps a too-slow server poll interval', () {
      final response = FeaturedTabsResponse.fromJson(const {
        'poll_interval_seconds': 86400,
        'featured_tabs': <dynamic>[],
      });

      expect(
        response.pollInterval,
        equals(FeaturedTabsResponse.maxPollInterval),
      );
    });

    test('falls back to the default interval when the server sends zero', () {
      final response = FeaturedTabsResponse.fromJson(const {
        'poll_interval_seconds': 0,
        'featured_tabs': <dynamic>[],
      });

      expect(
        response.pollInterval,
        equals(FeaturedTabsResponse.defaultPollInterval),
      );
    });
  });

  group('FunnelcakeApiClient featured tabs', () {
    late _MockHttpClient httpClient;
    late FunnelcakeApiClient client;

    setUp(() {
      httpClient = _MockHttpClient();
      client = FunnelcakeApiClient(
        baseUrl: _testBaseUrl,
        httpClient: httpClient,
      );
    });

    tearDown(() => client.dispose());

    void stubGet(String body, {int statusCode = 200}) {
      when(
        () => httpClient.get(any(), headers: any(named: 'headers')),
      ).thenAnswer((_) async => http.Response(body, statusCode));
    }

    group('getFeaturedTabs', () {
      test('parses the config envelope', () async {
        stubGet('''
{
  "poll_interval_seconds": 300,
  "featured_tabs": [
    {
      "id": "ft_a1b2c3d4",
      "slug": "seasonal-theme",
      "label": {"default": "Seasonal Theme"},
      "position": {"mobile": {"after": "popular"}},
      "starts_at": "2026-01-01T00:00:00Z",
      "ends_at": "2026-02-01T00:00:00Z",
      "enabled": true,
      "visible_to_minors": false,
      "disclosure_label": null,
      "has_content": true
    }
  ]
}''');

        final response = await client.getFeaturedTabs();

        expect(response.pollInterval, equals(const Duration(minutes: 5)));
        expect(response.tabs, hasLength(1));
        expect(response.tabs.single.id, equals('ft_a1b2c3d4'));
        expect(response.tabs.single.slug, equals('seasonal-theme'));
        expect(response.tabs.single.hasContent, isTrue);
      });

      test('requests the public featured tabs path', () async {
        stubGet('{"featured_tabs": []}');

        await client.getFeaturedTabs();

        final uri =
            verify(
                  () => httpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/api/featured-tabs'));
      });

      test('returns no tabs when the server sends an empty array', () async {
        stubGet('{"poll_interval_seconds": 300, "featured_tabs": []}');

        final response = await client.getFeaturedTabs();

        expect(response.tabs, isEmpty);
      });

      test('throws $FunnelcakeApiException on a non-success status', () async {
        stubGet('', statusCode: 503);

        expect(
          client.getFeaturedTabs(),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws $FunnelcakeException on a non-object body', () async {
        stubGet('[]');

        expect(client.getFeaturedTabs(), throwsA(isA<FunnelcakeException>()));
      });

      test('throws when the API is not configured', () async {
        final unconfigured = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: httpClient,
        );
        addTearDown(unconfigured.dispose);

        expect(
          unconfigured.getFeaturedTabs(),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );
      });
    });

    group('getFeaturedTabVideos', () {
      test('preserves the server order', () async {
        stubGet('''
{
  "data": [${_videoJson('bbb', 'second')}, ${_videoJson('aaa', 'first')}],
  "pagination": {"has_more": false, "next_cursor": null}
}''');

        final response = await client.getFeaturedTabVideos(id: 'ft_a1b2c3d4');

        expect(response.videos.map((v) => v.id), equals(['bbb', 'aaa']));
      });

      test('exposes the pagination envelope', () async {
        stubGet('''
{
  "data": [${_videoJson('aaa', 'first')}],
  "pagination": {"has_more": true, "next_cursor": "opaque-cursor"}
}''');

        final response = await client.getFeaturedTabVideos(id: 'ft_a1b2c3d4');

        expect(response.hasMore, isTrue);
        expect(response.nextCursor, equals('opaque-cursor'));
      });

      test('requests the tab-scoped videos path with limit', () async {
        stubGet('{"data": [], "pagination": {"has_more": false}}');

        await client.getFeaturedTabVideos(id: 'ft_a1b2c3d4', limit: 40);

        final uri =
            verify(
                  () => httpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.path, equals('/api/featured-tabs/ft_a1b2c3d4/videos'));
        expect(uri.queryParameters['limit'], equals('40'));
        expect(uri.queryParameters.containsKey('cursor'), isFalse);
      });

      test('forwards a non-empty cursor', () async {
        stubGet('{"data": [], "pagination": {"has_more": false}}');

        await client.getFeaturedTabVideos(
          id: 'ft_a1b2c3d4',
          cursor: 'opaque-cursor',
        );

        final uri =
            verify(
                  () => httpClient.get(
                    captureAny(),
                    headers: any(named: 'headers'),
                  ),
                ).captured.single
                as Uri;
        expect(uri.queryParameters['cursor'], equals('opaque-cursor'));
      });

      test('returns an empty page for a retired tab id', () async {
        stubGet('{"data": [], "pagination": {"has_more": false}}');

        final response = await client.getFeaturedTabVideos(id: 'ft_a1b2c3d4');

        expect(response.videos, isEmpty);
        expect(response.hasMore, isFalse);
      });

      test('drops entries with no playable video url', () async {
        stubGet('''
{
  "data": [
    {
      "id": "aaa",
      "pubkey": "$_pubkey",
      "created_at": 1700000000,
      "kind": 34236,
      "d_tag": "first",
      "title": "No URL",
      "thumbnail": "https://example.com/thumb.jpg",
      "video_url": "",
      "reactions": 0,
      "comments": 0,
      "reposts": 0,
      "engagement_score": 0
    }
  ],
  "pagination": {"has_more": false}
}''');

        final response = await client.getFeaturedTabVideos(id: 'ft_a1b2c3d4');

        expect(response.videos, isEmpty);
      });

      test('throws $FunnelcakeApiException on a non-success status', () async {
        stubGet('', statusCode: 500);

        expect(
          client.getFeaturedTabVideos(id: 'ft_a1b2c3d4'),
          throwsA(isA<FunnelcakeApiException>()),
        );
      });

      test('throws when the API is not configured', () async {
        final unconfigured = FunnelcakeApiClient(
          baseUrl: '',
          httpClient: httpClient,
        );
        addTearDown(unconfigured.dispose);

        expect(
          unconfigured.getFeaturedTabVideos(id: 'ft_a1b2c3d4'),
          throwsA(isA<FunnelcakeNotConfiguredException>()),
        );
      });
    });
  });
}
