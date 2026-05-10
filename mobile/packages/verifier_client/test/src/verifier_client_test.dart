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
          expect(
            req.url.toString(),
            equals('https://verifier.example/verify'),
          );
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
          expect(
            req.url.toString(),
            equals('https://verifier.example/verify'),
          );
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
  });
}
