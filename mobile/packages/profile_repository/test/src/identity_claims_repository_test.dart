// ABOUTME: Tests for IdentityClaimsRepository — parseClaims, verifiedClaims,
// ABOUTME: and the persistent verified-claims cache (#3936).

import 'package:db_client/db_client.dart' hide Filter;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' hide VerificationResult;
import 'package:profile_repository/profile_repository.dart';

class _MockVerifierClient extends Mock implements VerifierClient {}

class _MockIdentityVerificationsDao extends Mock
    implements IdentityVerificationsDao {}

const _pubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';

int _nowSeconds() => DateTime.now().millisecondsSinceEpoch ~/ 1000;

IdentityVerificationRow _row({
  required String claimsJson,
  required int checkedAtFloor,
}) {
  return IdentityVerificationRow(
    pubkey: _pubkey,
    verifiedClaimsJson: claimsJson,
    checkedAtFloor: checkedAtFloor,
  );
}

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

  group('IdentityClaimsRepository.cachedVerifiedClaims', () {
    late _MockVerifierClient client;
    late _MockIdentityVerificationsDao dao;
    late IdentityClaimsRepository repo;

    const snapshotJson =
        '[{"platform":"github","identity":"octocat","proof":"a"}]';

    setUp(() {
      client = _MockVerifierClient();
      dao = _MockIdentityVerificationsDao();
      repo = IdentityClaimsRepository(
        verifierClient: client,
        identityVerificationsDao: dao,
      );
    });

    test('returns null when no DAO is wired', () async {
      final bare = IdentityClaimsRepository(verifierClient: client);
      expect(
        await bare.cachedVerifiedClaims(pubkey: _pubkey, tags: const []),
        isNull,
      );
    });

    test('returns null when no snapshot row exists', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer((_) async => null);
      expect(
        await repo.cachedVerifiedClaims(pubkey: _pubkey, tags: const []),
        isNull,
      );
    });

    test('returns null when the stored snapshot is corrupt', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async => _row(claimsJson: 'not json', checkedAtFloor: 1),
      );
      expect(
        await repo.cachedVerifiedClaims(pubkey: _pubkey, tags: const []),
        isNull,
      );
    });

    test(
      'intersects current claims with the snapshot — case-insensitive '
      'platform/identity, exact proof',
      () async {
        when(() => dao.getVerification(_pubkey)).thenAnswer(
          (_) async => _row(
            claimsJson: snapshotJson,
            checkedAtFloor: _nowSeconds(),
          ),
        );
        final cached = await repo.cachedVerifiedClaims(
          pubkey: _pubkey,
          tags: [
            ['i', 'GitHub:Octocat', 'a'],
            ['i', 'twitter:unverified', 'b'],
          ],
        );
        expect(cached, isNotNull);
        expect(cached!.claims, hasLength(1));
        expect(cached.claims.single.platform, equals('GitHub'));
        expect(cached.isFresh, isTrue);
      },
    );

    test('a rotated proof misses the snapshot', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async => _row(
          claimsJson: snapshotJson,
          checkedAtFloor: _nowSeconds(),
        ),
      );
      final cached = await repo.cachedVerifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:octocat', 'rotated-proof'],
        ],
      );
      expect(cached!.claims, isEmpty);
    });

    test('is stale once checkedAtFloor is older than the 24h TTL', () async {
      when(() => dao.getVerification(_pubkey)).thenAnswer(
        (_) async => _row(
          claimsJson: snapshotJson,
          checkedAtFloor: _nowSeconds() - 25 * 3600,
        ),
      );
      final cached = await repo.cachedVerifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:octocat', 'a'],
        ],
      );
      expect(cached!.claims, hasLength(1));
      expect(cached.isFresh, isFalse);
    });
  });

  group('IdentityClaimsRepository.verifiedClaims persistence', () {
    late _MockVerifierClient client;
    late _MockIdentityVerificationsDao dao;
    late IdentityClaimsRepository repo;

    setUp(() {
      client = _MockVerifierClient();
      dao = _MockIdentityVerificationsDao();
      repo = IdentityClaimsRepository(
        verifierClient: client,
        identityVerificationsDao: dao,
      );
      when(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      ).thenAnswer((_) async {});
      when(() => dao.deleteVerification(any())).thenAnswer((_) async => 1);
    });

    test(
      'persists verified tuples with the minimum checked_at as floor',
      () async {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 500,
              cached: true,
            ),
            VerificationResult(
              platform: 'telegram',
              identity: 'octo',
              verified: true,
              checkedAt: 300,
              cached: false,
            ),
            VerificationResult(
              platform: 'twitter',
              identity: 'fake',
              verified: false,
              checkedAt: 900,
              cached: false,
              error: 'Post not found',
            ),
          ],
        );

        await repo.verifiedClaims(
          pubkey: _pubkey,
          tags: [
            ['i', 'github:octocat', 'a'],
            ['i', 'telegram:octo', 'b'],
            ['i', 'twitter:fake', 'c'],
          ],
        );

        final captured =
            verify(
                  () => dao.upsertVerification(
                    pubkey: _pubkey,
                    verifiedClaimsJson: captureAny(
                      named: 'verifiedClaimsJson',
                    ),
                    checkedAtFloor: 300,
                  ),
                ).captured.single
                as String;
        expect(captured, contains('"github"'));
        expect(captured, contains('"telegram"'));
        expect(captured, isNot(contains('"twitter"')));
        verifyNever(() => dao.deleteVerification(any()));
      },
    );

    test('deletes the snapshot when the verifier confirms none', () async {
      when(() => client.verifyBatch(any())).thenAnswer(
        (_) async => const [
          VerificationResult(
            platform: 'github',
            identity: 'octocat',
            verified: false,
            checkedAt: 500,
            cached: false,
            error: 'Gist not found',
          ),
        ],
      );

      await repo.verifiedClaims(
        pubkey: _pubkey,
        tags: [
          ['i', 'github:octocat', 'a'],
        ],
      );

      verify(() => dao.deleteVerification(_pubkey)).called(1);
      verifyNever(
        () => dao.upsertVerification(
          pubkey: any(named: 'pubkey'),
          verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
          checkedAtFloor: any(named: 'checkedAtFloor'),
        ),
      );
    });

    test(
      'leaves the snapshot untouched when any result is rate-limited',
      () async {
        when(() => client.verifyBatch(any())).thenAnswer(
          (_) async => const [
            VerificationResult(
              platform: 'github',
              identity: 'octocat',
              verified: true,
              checkedAt: 500,
              cached: true,
            ),
            VerificationResult(
              platform: 'twitter',
              identity: 'octo',
              verified: false,
              checkedAt: 900,
              cached: false,
              error: 'Rate limit exceeded for this pubkey',
            ),
          ],
        );

        final result = await repo.verifiedClaims(
          pubkey: _pubkey,
          tags: [
            ['i', 'github:octocat', 'a'],
            ['i', 'twitter:octo', 'b'],
          ],
        );

        expect(result, hasLength(1));
        verifyNever(
          () => dao.upsertVerification(
            pubkey: any(named: 'pubkey'),
            verifiedClaimsJson: any(named: 'verifiedClaimsJson'),
            checkedAtFloor: any(named: 'checkedAtFloor'),
          ),
        );
        verifyNever(() => dao.deleteVerification(any()));
      },
    );
  });
}
