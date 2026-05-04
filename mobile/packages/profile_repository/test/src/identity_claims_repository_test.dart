// ABOUTME: Tests for IdentityClaimsRepository — parseClaims + verifiedClaims.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:profile_repository/profile_repository.dart';

class _MockVerifierClient extends Mock implements VerifierClient {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  setUpAll(() {
    registerFallbackValue(<IdentityClaim>[]);
  });

  group('IdentityClaimsRepository.parseClaims', () {
    test('extracts well-formed i tags', () {
      final tags = [
        ['i', 'github:octocat', 'abc'],
        ['i', 'twitter:elon', 'def'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(2));
      expect(claims.first.platform, equals('github'));
      expect(claims.first.identity, equals('octocat'));
      expect(claims.first.proof, equals('abc'));
    });

    test('skips tags whose name is not "i"', () {
      final tags = [
        ['p', 'somepubkey'],
        ['i', 'github:octocat', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(_pubkey, tags),
        hasLength(1),
      );
    });

    test('skips i tags without a platform:identity prefix', () {
      final tags = [
        ['i', 'no_colon_here', 'abc'],
        ['i', '', 'abc'],
        ['i', ':no_platform', 'abc'],
        ['i', 'no_identity:', 'abc'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), isEmpty);
    });

    test('skips i tags missing a proof', () {
      final tags = [
        ['i', 'github:octocat'],
      ];
      expect(IdentityClaimsRepository.parseClaims(_pubkey, tags), isEmpty);
    });

    test('skips empty tag entries', () {
      final tags = [
        <String>[],
        ['i', 'github:octocat', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(_pubkey, tags),
        hasLength(1),
      );
    });

    test('dedupes by case-insensitive platform:identity, keeping first', () {
      final tags = [
        ['i', 'GitHub:Octocat', 'first'],
        ['i', 'github:octocat', 'second'],
      ];
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(1));
      expect(claims.single.proof, equals('first'));
    });

    test('caps the result at 10 to match server MAX_BATCH_SIZE', () {
      final tags = List<List<String>>.generate(
        15,
        (i) => ['i', 'github:user$i', 'p$i'],
      );
      final claims = IdentityClaimsRepository.parseClaims(_pubkey, tags);
      expect(claims, hasLength(10));
    });

    test('attaches the pubkey to each claim', () {
      final tags = [
        ['i', 'github:octocat', 'abc'],
      ];
      expect(
        IdentityClaimsRepository.parseClaims(_pubkey, tags).single.pubkey,
        equals(_pubkey),
      );
    });
  });

  group('IdentityClaimsRepository.verifiedClaims', () {
    late _MockVerifierClient client;
    late IdentityClaimsRepository repo;

    setUp(() {
      client = _MockVerifierClient();
      repo = IdentityClaimsRepository(verifierClient: client);
    });

    test('returns only claims the verifier confirmed', () async {
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: true,
          ),
          VerificationResult(
            platform: 'twitter',
            identity: 'fake',
            verified: false,
            checkedAt: 1,
            cached: false,
          ),
        ],
      );
      final result = await repo.verifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:octocat', 'a'],
          ['i', 'twitter:fake', 'b'],
        ],
      );
      expect(result, hasLength(1));
      expect(result.single.platform, equals('github'));
    });

    test('returns empty when there are no i tags', () async {
      final result = await repo.verifiedClaims(
        pubkey: _pubkey,
        tags: const [
          ['p', 'someone'],
        ],
      );
      expect(result, isEmpty);
      verifyNever(() => client.verifyBatch(any()));
    });

    test('case-insensitively matches verifier results to claims', () async {
      // Verifier returns lowercase platform/identity even if claim used
      // mixed case.
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: true,
            checkedAt: 1,
            cached: true,
          ),
        ],
      );
      final result = await repo.verifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'GitHub:Octocat', 'a'],
        ],
      );
      expect(result, hasLength(1));
      expect(result.single.platform, equals('GitHub'));
      expect(result.single.identity, equals('Octocat'));
    });

    test('propagates VerifierApiException', () async {
      when(() => client.verifyBatch(any())).thenThrow(
        const VerifierApiException(500, 'boom'),
      );
      await expectLater(
        () => repo.verifiedClaims(
          pubkey: _pubkey,
          tags: [
            ['i', 'github:octocat', 'abc'],
          ],
        ),
        throwsA(isA<VerifierApiException>()),
      );
    });
  });
}
