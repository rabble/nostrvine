import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(
      Uri.parse('https://apps.divine.video/v1/apps'),
    );
    registerFallbackValue(<String, String>{});
  });

  group('NostrAppDirectoryService', () {
    late SharedPreferences sharedPreferences;
    late _MockHttpClient mockHttpClient;
    late NostrAppDirectoryService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();
      mockHttpClient = _MockHttpClient();
      service = NostrAppDirectoryService(
        sharedPreferences: sharedPreferences,
        client: mockHttpClient,
        baseUrl: 'https://apps.divine.video',
      );
    });

    test(
      'fetchApprovedApps returns remote apps and caches them',
      () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                _appJson(
                  slug: 'primal',
                  name: 'Primal',
                  updatedAt: '2026-03-25T10:00:00Z',
                ),
              ],
            }),
            200,
          ),
        );

        final apps = await service.fetchApprovedApps();

        expect(apps, hasLength(_starterSlugs.length));
        expect(
          apps.where((app) => app.slug == 'primal').single.id,
          '1',
        );
        expect(
          apps.where((app) => app.slug == 'primal').single.name,
          'Primal',
        );

        final cachedApps = await service.fetchApprovedApps(
          useCacheOnly: true,
        );
        expect(
          cachedApps.map((app) => app.slug),
          _starterSlugs,
        );
        verify(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        ).called(1);
      },
    );

    test(
      'fetchApprovedApps with useCacheOnly returns bundled '
      'starter apps when cache is empty',
      () async {
        final apps = await service.fetchApprovedApps(
          useCacheOnly: true,
        );

        expect(apps.map((app) => app.slug), _starterSlugs);
        verifyNever(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        );
      },
    );

    test(
      'fetchApprovedApps with useCacheOnly includes the bundled Ditto app',
      () async {
        final apps = await service.fetchApprovedApps(useCacheOnly: true);
        final ditto = apps.where((app) => app.slug == 'ditto').single;

        expect(ditto.name, 'ditto.pub');
        expect(ditto.launchUrl, 'https://ditto.pub/');
        expect(ditto.allowedOrigins, ['https://ditto.pub']);
      },
    );

    test(
      'fetchApprovedApps with useCacheOnly includes the new '
      'bundled starter apps',
      () async {
        final apps = await service.fetchApprovedApps(useCacheOnly: true);

        _expectBundledApp(
          apps: apps,
          slug: 'agora',
          name: 'Agora',
          launchUrl: 'https://agora.spot/',
          allowedOrigin: 'https://agora.spot',
        );
        _expectBundledApp(
          apps: apps,
          slug: 'treasures',
          name: 'Treasures',
          launchUrl: 'https://treasures.to/',
          allowedOrigin: 'https://treasures.to',
        );
        _expectBundledApp(
          apps: apps,
          slug: 'blobbi',
          name: 'Blobbi',
          launchUrl: 'https://www.blobbi.pet/',
          allowedOrigin: 'https://www.blobbi.pet',
        );
        _expectBundledApp(
          apps: apps,
          slug: 'espy',
          name: 'Espy',
          launchUrl: 'https://espy.you/',
          allowedOrigin: 'https://espy.you',
        );
        _expectBundledApp(
          apps: apps,
          slug: 'jumble',
          name: 'Jumble',
          launchUrl: 'https://jumble.social/',
          allowedOrigin: 'https://jumble.social',
        );
        _expectBundledApp(
          apps: apps,
          slug: 'divine-space',
          name: 'divine.space',
          launchUrl: 'https://divine.space/',
          allowedOrigin: 'https://divine.space',
        );
      },
    );

    test(
      'fetchApprovedApps with useCacheOnly includes Divine Badges '
      'with NIP-58 signing permissions',
      () async {
        final apps = await service.fetchApprovedApps(useCacheOnly: true);
        final badges = apps.where((app) => app.slug == 'badges').single;

        expect(badges.name, 'Divine Badges');
        expect(badges.launchUrl, 'https://badges.divine.video/me');
        expect(badges.allowedOrigins, ['https://badges.divine.video']);
        expect(
          badges.allowedMethods,
          ['getPublicKey', 'getRelays', 'signEvent'],
        );
        expect(
          badges.allowedSignEventKinds,
          [3, 8, 10002, 10008, 30008, 30009],
        );
        expect(badges.promptRequiredFor, ['signEvent']);
        expect(badges.autoLoginScript, contains('dbdg_session'));
      },
    );

    test(
      'fetchApprovedApps with useCacheOnly reads cached apps '
      'only',
      () async {
        await sharedPreferences.setString(
          'nostr_app_directory_cache',
          jsonEncode([
            _appJson(
              slug: 'yakihonne',
              name: 'YakiHonne',
              updatedAt: '2026-03-25T09:00:00Z',
            ),
          ]),
        );

        final apps = await service.fetchApprovedApps(
          useCacheOnly: true,
        );

        expect(apps, hasLength(_starterSlugs.length));
        expect(
          apps.where((app) => app.slug == 'yakihonne').single.name,
          'YakiHonne',
        );
        verifyNever(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        );
      },
    );

    test(
      'fetchApprovedApps returns bundled starter apps when '
      'remote directory is empty',
      () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({'items': <Object>[]}),
            200,
          ),
        );

        final apps = await service.fetchApprovedApps();

        expect(apps.map((app) => app.slug), _starterSlugs);
      },
    );

    test(
      'fetchApprovedApps lets the remote directory hide a '
      'bundled starter app',
      () async {
        when(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                _appJson(
                  slug: 'primal',
                  name: 'Primal',
                  updatedAt: '2026-03-25T10:00:00Z',
                  status: 'revoked',
                ),
              ],
            }),
            200,
          ),
        );

        final apps = await service.fetchApprovedApps();

        expect(
          apps.any((app) => app.slug == 'primal'),
          isFalse,
        );
      },
    );

    test(
      'fetchApprovedApps falls back to cached apps when '
      'remote fetch fails',
      () async {
        await sharedPreferences.setString(
          'nostr_app_directory_cache',
          jsonEncode([
            _appJson(
              slug: 'noauth',
              name: 'noauth',
              updatedAt: '2026-03-25T08:00:00Z',
            ),
          ]),
        );

        when(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        ).thenThrow(Exception('network down'));

        final apps = await service.fetchApprovedApps();

        expect(apps, hasLength(_starterSlugs.length + 1));
        expect(
          apps.any((app) => app.slug == 'noauth'),
          isTrue,
        );
      },
    );

    test(
      'fetchApprovedApps replaces cached apps so revoked '
      'entries disappear',
      () async {
        await sharedPreferences.setString(
          'nostr_app_directory_cache',
          jsonEncode([
            _appJson(
              slug: 'old-app',
              name: 'Old App',
              updatedAt: '2026-03-24T08:00:00Z',
            ),
            _appJson(
              slug: 'keep-app',
              name: 'Keep App',
              updatedAt: '2026-03-24T08:00:00Z',
            ),
          ]),
        );

        when(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'items': [
                _appJson(
                  slug: 'keep-app',
                  name: 'Keep App',
                  updatedAt: '2026-03-25T12:00:00Z',
                ),
              ],
            }),
            200,
          ),
        );

        final apps = await service.fetchApprovedApps();
        final cachedApps = await service.fetchApprovedApps(
          useCacheOnly: true,
        );

        expect(apps, hasLength(_starterSlugs.length + 1));
        expect(
          cachedApps,
          hasLength(_starterSlugs.length + 1),
        );
        expect(
          apps.any((app) => app.slug == 'keep-app'),
          isTrue,
        );
        expect(
          cachedApps.any((app) => app.slug == 'keep-app'),
          isTrue,
        );
        expect(
          apps.any((app) => app.slug == 'old-app'),
          isFalse,
        );
        expect(
          cachedApps.any((app) => app.slug == 'old-app'),
          isFalse,
        );
      },
    );
  });
}

const List<String> _starterSlugs = [
  'flotilla',
  'habla',
  'zap-stream',
  'primal',
  'yakihonne',
  'shopstr',
  'nostrnests',
  'ditto',
  'agora',
  'treasures',
  'blobbi',
  'espy',
  'jumble',
  'divine-space',
  'badges',
];

void _expectBundledApp({
  required Iterable<NostrAppDirectoryEntry> apps,
  required String slug,
  required String name,
  required String launchUrl,
  required String allowedOrigin,
}) {
  final app = apps.where((entry) => entry.slug == slug).single;
  expect(app.name, name);
  expect(app.launchUrl, launchUrl);
  expect(app.allowedOrigins, [allowedOrigin]);
}

Map<String, dynamic> _appJson({
  required String slug,
  required String name,
  required String updatedAt,
  int? sortOrder,
  String status = 'approved',
}) {
  final launchUrl = _launchUrlForSlug(slug);
  return {
    'id': slug == 'primal' ? 1 : 'app-$slug',
    'slug': slug,
    'name': name,
    'tagline': '$name on Nostr',
    'description': 'A vetted Nostr app called $name.',
    'icon_url': 'https://cdn.divine.video/$slug.png',
    'launch_url': launchUrl,
    'allowed_origins': [Uri.parse(launchUrl).origin],
    'allowed_methods': ['getPublicKey', 'signEvent'],
    'allowed_sign_event_kinds': [1, 7],
    'prompt_required_for': ['signEvent'],
    'status': status,
    'sort_order': sortOrder ?? _sortOrderBySlug[slug] ?? 100,
    'created_at': '2026-03-24T08:00:00Z',
    'updated_at': updatedAt,
  };
}

String _launchUrlForSlug(String slug) => switch (slug) {
  'flotilla' => 'https://app.flotilla.social/',
  'habla' => 'https://habla.news/',
  'zap-stream' => 'https://zap.stream/',
  'primal' => 'https://primal.net/',
  'yakihonne' => 'https://yakihonne.com/',
  'shopstr' => 'https://shopstr.store/',
  'nostrnests' => 'https://nostrnests.com/',
  'ditto' => 'https://ditto.pub/',
  _ => 'https://$slug.example.com',
};

const Map<String, int> _sortOrderBySlug = {
  'flotilla': 1,
  'habla': 2,
  'zap-stream': 3,
  'primal': 4,
  'yakihonne': 5,
  'shopstr': 6,
  'nostrnests': 7,
  'ditto': 8,
};
