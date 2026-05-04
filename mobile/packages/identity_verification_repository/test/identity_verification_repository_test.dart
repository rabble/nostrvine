import 'dart:async';

import 'package:identity_verification_client/identity_verification_client.dart';
import 'package:identity_verification_repository/identity_verification_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class _MockClient extends Mock implements IdentityVerificationClient {}

void main() {
  group(IdentityVerificationRepository, () {
    late IdentityVerificationClient client;
    late IdentityVerificationRepository repo;

    const pubkey =
        'pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp';
    const githubClaim = NostrIdentityClaim(
      platform: IdentityPlatform.github,
      identity: 'rabble',
      proof: 'https://gist',
    );
    const twitterClaim = NostrIdentityClaim(
      platform: IdentityPlatform.twitter,
      identity: 'rabble',
      proof: 'https://x',
    );

    setUp(() {
      client = _MockClient();
      repo = IdentityVerificationRepository(client: client);
    });

    test('returns verified subset from client', () async {
      when(
        () => client.verifyClaims(
          pubkey: pubkey,
          claims: any(named: 'claims'),
        ),
      ).thenAnswer((_) async => const [githubClaim]);

      final verified = await repo.verifyClaims(
        pubkey: pubkey,
        claims: const [githubClaim, twitterClaim],
      );

      expect(verified, equals(const [githubClaim]));
    });

    test('caches results for same (pubkey, claims)', () async {
      when(
        () => client.verifyClaims(
          pubkey: pubkey,
          claims: any(named: 'claims'),
        ),
      ).thenAnswer((_) async => const [githubClaim]);

      await repo.verifyClaims(pubkey: pubkey, claims: const [githubClaim]);
      await repo.verifyClaims(pubkey: pubkey, claims: const [githubClaim]);

      verify(
        () => client.verifyClaims(
          pubkey: pubkey,
          claims: any(named: 'claims'),
        ),
      ).called(1);
    });

    test('dedupes concurrent calls for same pubkey', () async {
      final completer = Completer<List<NostrIdentityClaim>>();
      when(
        () => client.verifyClaims(
          pubkey: pubkey,
          claims: any(named: 'claims'),
        ),
      ).thenAnswer((_) => completer.future);

      final f1 = repo.verifyClaims(pubkey: pubkey, claims: const [githubClaim]);
      final f2 = repo.verifyClaims(pubkey: pubkey, claims: const [githubClaim]);

      completer.complete(const [githubClaim]);
      final r1 = await f1;
      final r2 = await f2;

      expect(r1, equals(const [githubClaim]));
      expect(r2, equals(const [githubClaim]));
      verify(
        () => client.verifyClaims(
          pubkey: pubkey,
          claims: any(named: 'claims'),
        ),
      ).called(1);
    });

    test('returns empty when client throws', () async {
      when(
        () => client.verifyClaims(
          pubkey: pubkey,
          claims: any(named: 'claims'),
        ),
      ).thenThrow(IdentityVerificationException('boom'));

      final verified = await repo.verifyClaims(
        pubkey: pubkey,
        claims: const [githubClaim],
      );

      expect(verified, isEmpty);
    });

    test('returns empty for empty input without calling the client', () async {
      final verified = await repo.verifyClaims(
        pubkey: pubkey,
        claims: const [],
      );

      expect(verified, isEmpty);
      verifyNever(
        () => client.verifyClaims(
          pubkey: any(named: 'pubkey'),
          claims: any(named: 'claims'),
        ),
      );
    });
  });
}
