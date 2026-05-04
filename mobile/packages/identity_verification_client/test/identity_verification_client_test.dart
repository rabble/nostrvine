import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:identity_verification_client/identity_verification_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(IdentityVerificationClient, () {
    late http.Client httpClient;
    late IdentityVerificationClient client;

    final baseUri = Uri.parse('https://verifier.example');
    final pubkey = 'p' * 64;

    setUp(() {
      httpClient = _MockHttpClient();
      client = IdentityVerificationClient(
        baseUri: baseUri,
        httpClient: httpClient,
      );
      registerFallbackValue(Uri.parse('https://x'));
      registerFallbackValue(<String, String>{});
    });

    group('verifyClaims', () {
      test('returns verified subset on 200', () async {
        const claims = [
          NostrIdentityClaim(
            platform: IdentityPlatform.github,
            identity: 'rabble',
            proof: 'https://gist.github.com/abc',
          ),
          NostrIdentityClaim(
            platform: IdentityPlatform.twitter,
            identity: 'rabble',
            proof: 'https://x.com/rabble/status/123',
          ),
        ];
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'rabble',
                  'verified': true,
                },
                {
                  'platform': 'twitter',
                  'identity': 'rabble',
                  'verified': false,
                },
              ],
            }),
            200,
          ),
        );

        final verified = await client.verifyClaims(
          pubkey: pubkey,
          claims: claims,
        );

        expect(verified, hasLength(1));
        expect(verified.single.platform, equals(IdentityPlatform.github));
      });

      test(
        'returns empty list when claims is empty (no network call)',
        () async {
          final verified = await client.verifyClaims(
            pubkey: pubkey,
            claims: const [],
          );
          expect(verified, isEmpty);
          verifyNever(
            () => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            ),
          );
        },
      );

      test('throws IdentityVerificationException on non-2xx', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer((_) async => http.Response('boom', 503));

        expect(
          () => client.verifyClaims(
            pubkey: pubkey,
            claims: const [
              NostrIdentityClaim(
                platform: IdentityPlatform.github,
                identity: 'r',
                proof: 'p',
              ),
            ],
          ),
          throwsA(isA<IdentityVerificationException>()),
        );
      });

      test('wraps network error in IdentityVerificationException', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenThrow(const SocketException('offline'));

        expect(
          () => client.verifyClaims(
            pubkey: pubkey,
            claims: const [
              NostrIdentityClaim(
                platform: IdentityPlatform.github,
                identity: 'r',
                proof: 'p',
              ),
            ],
          ),
          throwsA(isA<IdentityVerificationException>()),
        );
      });

      test('drops verified results with unknown platform name', () async {
        when(
          () => httpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          ),
        ).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'rabble',
                  'verified': true,
                },
                {
                  'platform': 'unknownplatform',
                  'identity': 'x',
                  'verified': true,
                },
              ],
            }),
            200,
          ),
        );

        final verified = await client.verifyClaims(
          pubkey: pubkey,
          claims: const [
            NostrIdentityClaim(
              platform: IdentityPlatform.github,
              identity: 'rabble',
              proof: 'p',
            ),
          ],
        );
        expect(verified, hasLength(1));
      });
    });
  });
}
