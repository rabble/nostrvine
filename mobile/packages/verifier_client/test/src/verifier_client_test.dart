// ABOUTME: VerifierClient tests — batch + single + error mapping + caps.

import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';
import 'package:verifier_client/verifier_client.dart';

const _hex = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

IdentityClaim _claim({String platform = 'github'}) => IdentityClaim(
  pubkey: _hex,
  platform: platform,
  identity: 'octocat',
  proof: 'abc',
);

void main() {
  group(VerifierClient, () {
    group('verifyBatch', () {
      test('returns parsed results on 200', () async {
        final mock = MockClient((req) async {
          expect(req.method, equals('POST'));
          expect(req.url.toString(), equals('https://verifier.example/verify'));
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['claims'] as List, hasLength(1));
          return http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'octocat',
                  'verified': true,
                  'checked_at': 1,
                  'cached': true,
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        final results = await client.verifyBatch([_claim()]);
        expect(results, hasLength(1));
        expect(results.single.verified, isTrue);
      });

      test('returns empty list when given empty input', () async {
        final mock = MockClient((req) async {
          fail('client should not hit the network for an empty batch');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        expect(await client.verifyBatch(const []), isEmpty);
      });

      test('throws VerifierApiException on 4xx', () async {
        final mock = MockClient((_) async => http.Response('bad', 400));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('throws VerifierApiException on 429', () async {
        final mock = MockClient((_) async => http.Response('rl', 429));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(
            isA<VerifierApiException>().having(
              (e) => e.statusCode,
              'statusCode',
              429,
            ),
          ),
        );
      });

      test('throws VerifierApiException on 5xx', () async {
        final mock = MockClient((_) async => http.Response('boom', 500));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifyBatch([_claim()]),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('rejects batches over the server cap', () async {
        final mock = MockClient((_) async {
          fail('client should reject before hitting the network');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        final tooMany = List<IdentityClaim>.generate(11, (_) => _claim());
        await expectLater(
          () => client.verifyBatch(tooMany),
          throwsArgumentError,
        );
      });

      test('strips trailing slash from baseUrl', () async {
        final mock = MockClient((req) async {
          expect(req.url.toString(), equals('https://verifier.example/verify'));
          return http.Response(
            jsonEncode(<String, dynamic>{'results': <Object?>[]}),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example/',
          httpClient: mock,
        );
        await client.verifyBatch([_claim()]);
      });
    });

    group('verifySingle', () {
      test('posts a flat object to /verify/single', () async {
        final mock = MockClient((req) async {
          expect(
            req.url.toString(),
            equals('https://verifier.example/verify/single'),
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['platform'], equals('github'));
          expect(body['pubkey'], equals(_hex));
          return http.Response(
            jsonEncode({
              'platform': 'github',
              'identity': 'octocat',
              'verified': true,
              'checked_at': 1,
              'cached': true,
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        final result = await client.verifySingle(_claim());
        expect(result.verified, isTrue);
      });

      test('throws VerifierApiException on non-2xx', () async {
        final mock = MockClient((_) async => http.Response('boom', 503));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifySingle(_claim()),
          throwsA(isA<VerifierApiException>()),
        );
      });

      test('maps ClientException to VerifierNetworkException', () async {
        final mock = MockClient((_) async {
          throw http.ClientException('boom');
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );
        await expectLater(
          () => client.verifySingle(_claim()),
          throwsA(isA<VerifierNetworkException>()),
        );
      });
    });

    group('fetchPlatforms', () {
      test('parses the platform map into entries', () async {
        final mock = MockClient((req) async {
          expect(req.method, equals('GET'));
          expect(
            req.url.toString(),
            equals('https://verifier.example/platforms'),
          );
          return http.Response(
            jsonEncode({
              'platforms': {
                'github': {'label': 'GitHub', 'supported': true},
                'discord': {'label': 'Discord', 'supported': false},
              },
            }),
            200,
          );
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        final platforms = await client.fetchPlatforms();

        expect(platforms, hasLength(2));
        final github = platforms.firstWhere((p) => p.key == 'github');
        expect(github.label, equals('GitHub'));
        expect(github.supported, isTrue);
        expect(github.supportsOAuth, isFalse);
        expect(
          platforms.firstWhere((p) => p.key == 'discord').supported,
          isFalse,
        );
      });

      test('returns an empty list when the response carries no map', () async {
        final mock = MockClient(
          (_) async => http.Response(jsonEncode(<String, dynamic>{}), 200),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        expect(await client.fetchPlatforms(), isEmpty);
      });

      test('maps a non-2xx response to VerifierApiException', () async {
        final mock = MockClient((_) async => http.Response('nope', 500));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        await expectLater(
          client.fetchPlatforms,
          throwsA(isA<VerifierApiException>()),
        );
      });
    });

    group('oauthStartUri', () {
      test('builds the start URL with pubkey and return URL', () {
        final client = VerifierClient(baseUrl: 'https://verifier.example');

        final uri = client.oauthStartUri(
          platform: 'twitter',
          pubkey: _hex,
          returnUrl: 'https://divine.video/app/callback',
        );

        expect(uri.path, equals('/auth/twitter/start'));
        expect(uri.queryParameters['pubkey'], equals(_hex));
        expect(
          uri.queryParameters['return_url'],
          equals('https://divine.video/app/callback'),
        );
        expect(uri.queryParameters.containsKey('handle'), isFalse);
      });

      test('passes the bluesky handle through, trimmed', () {
        final client = VerifierClient(baseUrl: 'https://verifier.example');

        final uri = client.oauthStartUri(
          platform: 'bluesky',
          pubkey: _hex,
          returnUrl: 'https://divine.video/app/callback',
          handle: '  alice.bsky.social ',
        );

        expect(uri.queryParameters['handle'], equals('alice.bsky.social'));
      });

      test('rejects a platform without an OAuth flow', () {
        final client = VerifierClient(baseUrl: 'https://verifier.example');

        expect(
          () => client.oauthStartUri(
            platform: 'github',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
          ),
          throwsArgumentError,
        );
      });

      test('rejects bluesky without a handle', () {
        final client = VerifierClient(baseUrl: 'https://verifier.example');

        expect(
          () => client.oauthStartUri(
            platform: 'bluesky',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
            handle: '   ',
          ),
          throwsArgumentError,
        );
      });
    });

    group('resolveOAuthLaunchUri', () {
      test(
        'returns the provider URL the start endpoint redirects to',
        () async {
          var starts = 0;
          final mock = MockClient((req) async {
            starts++;
            expect(req.url.path, equals('/auth/twitter/start'));
            return http.Response(
              '',
              302,
              headers: {'location': 'https://x.com/i/oauth2/authorize?state=s'},
            );
          });
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: mock,
          );

          expect(
            await client.resolveOAuthLaunchUri(
              platform: 'twitter',
              pubkey: _hex,
              returnUrl: 'https://divine.video/app/callback',
            ),
            equals(Uri.parse('https://x.com/i/oauth2/authorize?state=s')),
          );
          // Each start mints server-side OAuth state and, for Bluesky, pushes a
          // PAR to the user's PDS. One tap has to cost exactly one.
          expect(starts, equals(1));
        },
      );

      test('resolves a relative Location against the start URL', () async {
        final mock = MockClient(
          (_) async =>
              http.Response('', 302, headers: {'location': '/auth/retry'}),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        expect(
          await client.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
          ),
          equals(Uri.parse('https://verifier.example/auth/retry')),
        );
      });

      test('reports unavailable on the service 503', () async {
        final mock = MockClient(
          (_) async =>
              http.Response('{"error":"Twitter OAuth not configured"}', 503),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        expect(
          await client.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
          ),
          isNull,
        );
      });

      test('reports unavailable on a redirect with no Location', () async {
        final mock = MockClient((_) async => http.Response('', 302));
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        expect(
          await client.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
          ),
          isNull,
        );
      });

      test('refuses a Location that is not https', () async {
        final mock = MockClient(
          (_) async => http.Response(
            '',
            302,
            headers: {'location': 'javascript:alert(1)'},
          ),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        expect(
          await client.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
          ),
          isNull,
        );
      });

      test(
        'falls back to the start URL when the request never lands',
        () async {
          final mock = MockClient((_) async {
            throw http.ClientException('offline');
          });
          final client = VerifierClient(
            baseUrl: 'https://verifier.example',
            httpClient: mock,
          );

          final uri = await client.resolveOAuthLaunchUri(
            platform: 'twitter',
            pubkey: _hex,
            returnUrl: 'https://divine.video/app/callback',
          );

          expect(uri?.path, equals('/auth/twitter/start'));
          expect(uri?.queryParameters['pubkey'], equals(_hex));
        },
      );
    });

    group('revokeOAuth', () {
      test('posts the claim and the NIP-98 event', () async {
        var called = false;
        final mock = MockClient((req) async {
          called = true;
          expect(req.method, equals('POST'));
          expect(
            req.url.toString(),
            equals('https://verifier.example/auth/oauth/revoke'),
          );
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          expect(body['platform'], equals('twitter'));
          expect(body['identity'], equals('jack'));
          expect(body['pubkey'], equals(_hex));
          expect(
            (body['event']! as Map<String, dynamic>)['kind'],
            equals(27235),
          );
          return http.Response(jsonEncode({'revoked': true}), 200);
        });
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        await client.revokeOAuth(
          platform: 'twitter',
          identity: 'jack',
          pubkey: _hex,
          nip98Event: const {'kind': 27235},
        );

        expect(called, isTrue);
      });

      test('surfaces a rejected revoke as VerifierApiException', () async {
        final mock = MockClient(
          (_) async => http.Response('{"error":"nope"}', 401),
        );
        final client = VerifierClient(
          baseUrl: 'https://verifier.example',
          httpClient: mock,
        );

        await expectLater(
          () => client.revokeOAuth(
            platform: 'twitter',
            identity: 'jack',
            pubkey: _hex,
            nip98Event: const {'kind': 27235},
          ),
          throwsA(isA<VerifierApiException>()),
        );
      });
    });

    test('oauthRevokeUrl matches the URL revokeOAuth posts to', () {
      final client = VerifierClient(baseUrl: 'https://verifier.example/');

      expect(
        client.oauthRevokeUrl,
        equals('https://verifier.example/auth/oauth/revoke'),
      );
    });
  });
}
