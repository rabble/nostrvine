import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:identity_verification_repository/identity_verification_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_links/profile_links_cubit.dart';
import 'package:openvine/blocs/profile_links/profile_links_state.dart';

class _MockRepo extends Mock implements IdentityVerificationRepository {}

void main() {
  group(ProfileLinksCubit, () {
    late IdentityVerificationRepository repo;
    const pubkey =
        'pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp';
    const githubClaim = NostrIdentityClaim(
      platform: IdentityPlatform.github,
      identity: 'rabble',
      proof: 'p',
    );

    setUp(() {
      repo = _MockRepo();
    });

    blocTest<ProfileLinksCubit, ProfileLinksState>(
      'emits ready with empty verifiedIdentities when claims is empty',
      build: () => ProfileLinksCubit(repository: repo),
      act: (cubit) => cubit.load(
        pubkey: pubkey,
        website: 'https://example.com',
        claims: const [],
      ),
      expect: () => [
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.ready)
            .having((s) => s.website, 'website', 'https://example.com')
            .having((s) => s.verifiedIdentities, 'verified', isEmpty),
      ],
    );

    blocTest<ProfileLinksCubit, ProfileLinksState>(
      'emits loading then ready with verified subset when claims provided',
      setUp: () {
        when(
          () => repo.verifyClaims(
            pubkey: pubkey,
            claims: any(named: 'claims'),
          ),
        ).thenAnswer((_) async => const [githubClaim]);
      },
      build: () => ProfileLinksCubit(repository: repo),
      act: (cubit) => cubit.load(
        pubkey: pubkey,
        website: null,
        claims: const [githubClaim],
      ),
      expect: () => [
        isA<ProfileLinksState>().having(
          (s) => s.status,
          'status',
          ProfileLinksStatus.loading,
        ),
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.ready)
            .having(
              (s) => s.verifiedIdentities,
              'verified',
              equals(const [VerifiedIdentity(claim: githubClaim)]),
            ),
      ],
    );

    blocTest<ProfileLinksCubit, ProfileLinksState>(
      'emits ready with empty verifiedIdentities when repo returns empty',
      setUp: () {
        when(
          () => repo.verifyClaims(
            pubkey: pubkey,
            claims: any(named: 'claims'),
          ),
        ).thenAnswer((_) async => const []);
      },
      build: () => ProfileLinksCubit(repository: repo),
      act: (cubit) => cubit.load(
        pubkey: pubkey,
        website: null,
        claims: const [githubClaim],
      ),
      expect: () => [
        isA<ProfileLinksState>().having(
          (s) => s.status,
          'status',
          ProfileLinksStatus.loading,
        ),
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.ready)
            .having((s) => s.verifiedIdentities, 'verified', isEmpty),
      ],
    );
  });
}
