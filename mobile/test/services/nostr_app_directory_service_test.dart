import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/nostr_app_directory_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('https://apps.divine.video/v1/apps'));
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

    test('fetchApprovedApps returns remote apps and caches them', () async {
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

      expect(apps, hasLength(1));
      expect(apps.single.id, '1');
      expect(apps.single.slug, 'primal');
      expect(apps.single.name, 'Primal');

      final cachedApps = await service.fetchApprovedApps(useCacheOnly: true);
      expect(cachedApps.map((app) => app.slug), ['primal']);
      verify(
        () => mockHttpClient.get(
          Uri.parse('https://apps.divine.video/v1/apps'),
          headers: any(named: 'headers'),
        ),
      ).called(1);
    });

    test(
      'fetchApprovedApps with useCacheOnly reads cached apps only',
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

        final apps = await service.fetchApprovedApps(useCacheOnly: true);

        expect(apps, hasLength(1));
        expect(apps.single.slug, 'yakihonne');
        verifyNever(
          () => mockHttpClient.get(
            Uri.parse('https://apps.divine.video/v1/apps'),
            headers: any(named: 'headers'),
          ),
        );
      },
    );

    test(
      'fetchApprovedApps falls back to cached apps when remote fetch fails',
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

        expect(apps, hasLength(1));
        expect(apps.single.slug, 'noauth');
      },
    );

    test(
      'fetchApprovedApps replaces cached apps so revoked entries disappear',
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
        final cachedApps = await service.fetchApprovedApps(useCacheOnly: true);

        expect(apps.map((app) => app.slug), ['keep-app']);
        expect(cachedApps.map((app) => app.slug), ['keep-app']);
      },
    );
  });
}

Map<String, dynamic> _appJson({
  required String slug,
  required String name,
  required String updatedAt,
}) {
  return {
    'id': slug == 'primal' ? 1 : 'app-$slug',
    'slug': slug,
    'name': name,
    'tagline': '$name on Nostr',
    'description': 'A vetted Nostr app called $name.',
    'icon_url': 'https://cdn.divine.video/$slug.png',
    'launch_url': 'https://$slug.example.com',
    'allowed_origins': ['https://$slug.example.com'],
    'allowed_methods': ['getPublicKey', 'signEvent'],
    'allowed_sign_event_kinds': [1, 7],
    'prompt_required_for': ['signEvent'],
    'status': 'approved',
    'sort_order': 1,
    'created_at': '2026-03-24T08:00:00Z',
    'updated_at': updatedAt,
  };
}
