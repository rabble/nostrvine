// ABOUTME: Tests for proxy-backed sound library search client.
// ABOUTME: Covers provider discovery, search encoding, malformed-row errors.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

void main() {
  group(SoundLibraryApiClient, () {
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

    test(
      'malformed row surfaces as SoundLibraryApiException, not TypeError',
      () async {
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    // Missing required string fields: id is int.
                    'id': 12345,
                    'provider': null,
                    'providerId': '502915',
                    'previewUrl': 'https://cdn.example.com/p.mp3',
                    'license': {
                      'type': 'cc0',
                      'name': 'Creative Commons 0',
                      'url': 'https://example.com/license',
                      'allowsCommercialUse': true,
                      'allowsDerivatives': true,
                      'requiresAttribution': false,
                    },
                  },
                ],
                'count': 1,
              }),
              200,
            );
          }),
        );

        await expectLater(
          client.search(query: 'broken', provider: 'freesound'),
          throwsA(isA<SoundLibraryApiException>()),
        );
      },
    );

    test(
      'row with missing license surfaces as SoundLibraryApiException',
      () async {
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 'freesound_1',
                    'provider': 'freesound',
                    'providerId': '1',
                    'previewUrl': 'https://cdn.example.com/p.mp3',
                    // license absent
                  },
                ],
                'count': 1,
              }),
              200,
            );
          }),
        );

        await expectLater(
          client.search(query: 'noLicense', provider: 'freesound'),
          throwsA(
            isA<SoundLibraryApiException>().having(
              (e) => e.message,
              'message',
              contains('license'),
            ),
          ),
        );
      },
    );

    test('uses default http.Client and timeout when none provided', () {
      // Construct without httpClient/timeout to exercise the default
      // branch in the constructor (line 166 in the source).
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
      );
      expect(client, isA<SoundLibraryApiClient>());
    });

    test('wraps network failures in SoundLibraryApiException', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          throw http.ClientException('connection refused', request.url);
        }),
      );

      await expectLater(
        client.fetchProviders(),
        throwsA(
          isA<SoundLibraryApiException>().having(
            (e) => e.message,
            'message',
            contains('network error'),
          ),
        ),
      );
    });

    test('wraps non-JSON success body in SoundLibraryApiException', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response('<html>oops</html>', 200);
        }),
      );

      await expectLater(
        client.fetchProviders(),
        throwsA(
          isA<SoundLibraryApiException>()
              .having((e) => e.message, 'message', contains('not valid JSON'))
              .having((e) => e.statusCode, 'statusCode', 200),
        ),
      );
    });

    test(
      'falls back to generic error message when error body is not JSON',
      () async {
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            return http.Response('<html>Internal Server Error</html>', 500);
          }),
        );

        await expectLater(
          client.search(query: 'anything'),
          throwsA(
            isA<SoundLibraryApiException>()
                .having(
                  (e) => e.message,
                  'message',
                  'Sound library request '
                      'failed',
                )
                .having((e) => e.statusCode, 'statusCode', 500)
                .having((e) => e.code, 'code', isNull),
          ),
        );
      },
    );

    test(
      'falls back to generic error message when error body is JSON array',
      () async {
        // Drives _tryDecodeError's "decoded is not Map" branch (returns null
        // without throwing), and then the no-decoded-body fallback in
        // _exceptionFromResponse.
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            return http.Response(jsonEncode(['not', 'a', 'map']), 502);
          }),
        );

        await expectLater(
          client.search(query: 'anything'),
          throwsA(
            isA<SoundLibraryApiException>()
                .having((e) => e.statusCode, 'statusCode', 502)
                .having((e) => e.code, 'code', isNull),
          ),
        );
      },
    );

    test('rejects empty query before issuing a request', () async {
      var called = false;
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          called = true;
          return http.Response('', 200);
        }),
      );

      await expectLater(
        client.search(query: '   '),
        throwsA(
          isA<SoundLibraryApiException>().having(
            (e) => e.code,
            'code',
            'invalid_query',
          ),
        ),
      );
      expect(called, isFalse);
    });

    test(
      'surfaces TypeError from license parsing as SoundLibraryApiException',
      () async {
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode({
                'results': [
                  {
                    'id': 'freesound_1',
                    'provider': 'freesound',
                    'providerId': '1',
                    'previewUrl': 'https://cdn.example.com/p.mp3',
                    // license is a Map but missing required string fields,
                    // so AudioLicenseMetadata.fromJson throws TypeError.
                    'license': <String, dynamic>{},
                  },
                ],
                'count': 1,
              }),
              200,
            );
          }),
        );

        await expectLater(
          client.search(query: 'broken', provider: 'freesound'),
          throwsA(
            isA<SoundLibraryApiException>()
                .having(
                  (e) => e.message,
                  'message',
                  contains('invalid license metadata'),
                )
                .having((e) => e.provider, 'provider', 'freesound'),
          ),
        );
      },
    );

    test('labels openverse provider in returned AudioEvent', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'id': 'openverse_42',
                  'provider': 'openverse',
                  'providerId': '42',
                  'previewUrl': 'https://example.com/openverse.mp3',
                  'license': {
                    'type': 'cc0',
                    'name': 'Creative Commons 0',
                    'url': 'https://creativecommons.org/publicdomain/zero/1.0/',
                    'requiresAttribution': false,
                    'allowsCommercialUse': true,
                    'allowsDerivatives': true,
                  },
                },
              ],
              'count': 1,
            }),
            200,
          );
        }),
      );

      final response = await client.search(
        query: 'anything',
        provider: 'openverse',
      );
      expect(response.sounds.single.externalSource?.providerName, 'Openverse');
    });

    test('falls back count to sounds length when count is absent', () async {
      // Drives the `count: decoded['count'] as int? ?? sounds.length` fallback.
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'results': <dynamic>[]}), 200);
        }),
      );
      final response = await client.search(query: 'empty');
      expect(response.count, equals(0));
      expect(response.nextPage, isNull);
    });

    test('treats non-object decoded JSON as invalid search response', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode(['not', 'a', 'map']), 200);
        }),
      );
      await expectLater(
        client.search(query: 'anything'),
        throwsA(
          isA<SoundLibraryApiException>().having(
            (e) => e.message,
            'message',
            'Search response was invalid',
          ),
        ),
      );
    });

    test('treats missing results array as invalid search response', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'count': 0}), 200);
        }),
      );
      await expectLater(
        client.search(query: 'anything'),
        throwsA(
          isA<SoundLibraryApiException>().having(
            (e) => e.message,
            'message',
            'Search response was invalid',
          ),
        ),
      );
    });

    test('treats non-list provider response as invalid', () async {
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          return http.Response(jsonEncode({'oops': true}), 200);
        }),
      );
      await expectLater(
        client.fetchProviders(),
        throwsA(
          isA<SoundLibraryApiException>().having(
            (e) => e.message,
            'message',
            contains('invalid'),
          ),
        ),
      );
    });

    test(
      'rejects provider entries that are missing id or label',
      () async {
        final client = SoundLibraryApiClient(
          baseUri: Uri.parse('https://api.divine.video'),
          httpClient: MockClient((request) async {
            return http.Response(
              jsonEncode([
                {'id': 'divine'}, // missing label
              ]),
              200,
            );
          }),
        );
        await expectLater(
          client.fetchProviders(),
          throwsA(isA<SoundLibraryApiException>()),
        );
      },
    );

    test('omits license_type query param when blank', () async {
      Uri? observed;
      final client = SoundLibraryApiClient(
        baseUri: Uri.parse('https://api.divine.video'),
        httpClient: MockClient((request) async {
          observed = request.url;
          return http.Response(
            jsonEncode({'results': <dynamic>[], 'count': 0}),
            200,
          );
        }),
      );
      await client.search(query: 'q', licenseType: '   ');
      expect(observed!.queryParameters.containsKey('license_type'), isFalse);
    });
  });

  group(SoundLibraryProviderInfo, () {
    test('value equality and hashCode match for identical fields', () {
      const a = SoundLibraryProviderInfo(
        id: 'divine',
        label: 'Divine',
        enabled: true,
      );
      const b = SoundLibraryProviderInfo(
        id: 'divine',
        label: 'Divine',
        enabled: true,
      );
      const different = SoundLibraryProviderInfo(
        id: 'divine',
        label: 'Divine',
        enabled: false,
      );
      const differentLabel = SoundLibraryProviderInfo(
        id: 'divine',
        label: 'Other',
        enabled: true,
      );
      const differentId = SoundLibraryProviderInfo(
        id: 'other',
        label: 'Divine',
        enabled: true,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(different)));
      expect(a, isNot(equals(differentLabel)));
      expect(a, isNot(equals(differentId)));
      // Exercise the `other is SoundLibraryProviderInfo` guard branch.
      // ignore: unrelated_type_equality_checks
      expect(a == 'divine', isFalse);
    });

    test('enabled defaults to false when missing from JSON', () {
      final parsed = SoundLibraryProviderInfo.fromJson(const {
        'id': 'x',
        'label': 'X',
      });
      expect(parsed.enabled, isFalse);
    });
  });

  group(SoundLibrarySearchRequest, () {
    test('value equality and hashCode match for identical fields', () {
      const a = SoundLibrarySearchRequest(query: 'q', licenseType: 'cc0');
      const b = SoundLibrarySearchRequest(query: 'q', licenseType: 'cc0');
      const differentQuery = SoundLibrarySearchRequest(
        query: 'other',
        licenseType: 'cc0',
      );
      const differentProvider = SoundLibrarySearchRequest(
        query: 'q',
        provider: 'nostr',
        licenseType: 'cc0',
      );
      const differentPage = SoundLibrarySearchRequest(
        query: 'q',
        page: 2,
        licenseType: 'cc0',
      );
      const differentPageSize = SoundLibrarySearchRequest(
        query: 'q',
        pageSize: 25,
        licenseType: 'cc0',
      );
      const differentLicense = SoundLibrarySearchRequest(query: 'q');

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(differentQuery)));
      expect(a, isNot(equals(differentProvider)));
      expect(a, isNot(equals(differentPage)));
      expect(a, isNot(equals(differentPageSize)));
      expect(a, isNot(equals(differentLicense)));
      // Exercise the `other is SoundLibrarySearchRequest` guard branch.
      // ignore: unrelated_type_equality_checks
      expect(a == 'q', isFalse);
    });
  });

  group(SoundLibraryApiException, () {
    test('toString includes message and status code', () {
      const exception = SoundLibraryApiException(
        'boom',
        statusCode: 503,
      );
      expect(exception.toString(), 'SoundLibraryApiException: boom (503)');
    });

    test('toString reports "no status" when statusCode is null', () {
      const exception = SoundLibraryApiException('boom');
      expect(
        exception.toString(),
        'SoundLibraryApiException: boom (no status)',
      );
    });
  });
}
