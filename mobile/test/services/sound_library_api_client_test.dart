// ABOUTME: Tests for proxy-backed sound library search client.
// ABOUTME: Verifies provider discovery, search query encoding, and license metadata mapping.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/sound_library_api_client.dart';

void main() {
  group('SoundLibraryApiClient', () {
    test('loads visible providers', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          expect(request.method, equals('GET'));
          expect(request.url.path, equals('/api/sounds/providers'));
          return http.Response(
            jsonEncode([
              {'id': 'divine', 'label': 'Divine', 'enabled': true},
              {'id': 'nostr', 'label': 'Community', 'enabled': true},
            ]),
            200,
          );
        }),
      );

      final providers = await client.fetchProviders();

      expect(providers.map((provider) => provider.id), ['divine', 'nostr']);
      expect(providers.first.label, equals('Divine'));
      expect(providers.first.enabled, isTrue);
    });

    test(
      'searches sounds and preserves attribution license metadata',
      () async {
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            expect(request.method, equals('GET'));
            expect(request.url.path, equals('/api/sounds/search'));
            expect(request.url.queryParameters['q'], equals('crowd'));
            expect(
              request.url.queryParameters['provider'],
              equals('freesound'),
            );
            expect(request.url.queryParameters['page'], equals('2'));
            expect(request.url.queryParameters['page_size'], equals('25'));
            expect(request.url.queryParameters['license_type'], equals('cc0'));

            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 'freesound_502915',
                    'provider': 'freesound',
                    'providerId': '502915',
                    'title': 'Oh No No No Crowd',
                    'creator': 'ThePauny',
                    'source': 'ThePauny via Freesound',
                    'sourceUrl':
                        'https://freesound.org/people/ThePauny/sounds/502915/',
                    'license': {
                      'type': 'cc0',
                      'name': 'Creative Commons 0',
                      'url':
                          'https://creativecommons.org/publicdomain/zero/1.0/',
                      'requiresAttribution': false,
                      'allowsCommercialUse': true,
                      'allowsDerivatives': true,
                    },
                    'duration': 6,
                    'previewUrl':
                        'https://cdn.freesound.org/previews/502/502915.mp3',
                    'tags': ['crowd'],
                  },
                ],
                'count': 1,
                'nextPage': 3,
              }),
              200,
            );
          }),
        );

        final response = await client.search(
          query: 'crowd',
          provider: 'freesound',
          page: 2,
          pageSize: 25,
          licenseType: 'cc0',
        );

        expect(response.count, equals(1));
        expect(response.nextPage, equals(3));
        expect(response.sounds, hasLength(1));

        final sound = response.sounds.single;
        expect(sound.id, equals('freesound_502915'));
        expect(sound.url, contains('cdn.freesound.org'));
        expect(sound.duration, equals(6.0));
        expect(sound.source, equals('ThePauny via Freesound'));
        expect(sound.externalSource?.provider, equals('freesound'));
        expect(sound.externalSource?.providerSoundId, equals('502915'));
        expect(sound.externalSource?.license.type, equals('cc0'));
        expect(sound.externalSource?.license.requiresAttribution, isFalse);
        expect(sound.isExternalProviderSound, isTrue);
      },
    );

    test('throws stable exception for disabled providers', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'error': 'provider_disabled',
              'message': 'Freesound sound search is not available.',
              'provider': 'freesound',
            }),
            404,
          );
        }),
      );

      await expectLater(
        client.search(query: 'crowd', provider: 'freesound'),
        throwsA(
          isA<SoundLibraryApiException>()
              .having((error) => error.code, 'code', 'provider_disabled')
              .having((error) => error.statusCode, 'statusCode', 404),
        ),
      );
    });
  });
}
