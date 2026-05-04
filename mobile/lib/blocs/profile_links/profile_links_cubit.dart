// ABOUTME: Loads website + verified NIP-39 identities for a profile.
// ABOUTME: Calls IdentityVerificationRepository; failures emit empty list (silent).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:identity_verification_repository/identity_verification_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_links/profile_links_state.dart';

class ProfileLinksCubit extends Cubit<ProfileLinksState> {
  ProfileLinksCubit({required IdentityVerificationRepository repository})
    : _repository = repository,
      super(const ProfileLinksState());

  final IdentityVerificationRepository _repository;

  /// Loads links for a profile. Emits `loading` then `ready`. Errors are
  /// swallowed by the repository; this method does not throw.
  Future<void> load({
    required String pubkey,
    required String? website,
    required List<NostrIdentityClaim> claims,
  }) async {
    if (claims.isEmpty) {
      emit(
        state.copyWith(
          status: ProfileLinksStatus.ready,
          website: website,
          verifiedIdentities: const [],
        ),
      );
      return;
    }

    emit(
      state.copyWith(
        status: ProfileLinksStatus.loading,
        website: website,
      ),
    );

    final verified = await _repository.verifyClaims(
      pubkey: pubkey,
      claims: claims,
    );
    emit(
      state.copyWith(
        status: ProfileLinksStatus.ready,
        website: website,
        verifiedIdentities: verified
            .map((c) => VerifiedIdentity(claim: c))
            .toList(),
      ),
    );
  }
}
