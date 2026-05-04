// ABOUTME: State for ProfileLinksCubit — website + verified NIP-39 identities

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum ProfileLinksStatus { initial, loading, ready }

class VerifiedIdentity extends Equatable {
  const VerifiedIdentity({required this.claim});

  final NostrIdentityClaim claim;

  IdentityPlatform get platform => claim.platform;
  String get identity => claim.identity;
  Uri get profileUrl => claim.platform.canonicalProfileUrl(claim.identity);

  @override
  List<Object?> get props => [claim];
}

class ProfileLinksState extends Equatable {
  const ProfileLinksState({
    this.status = ProfileLinksStatus.initial,
    this.website,
    this.verifiedIdentities = const [],
  });

  final ProfileLinksStatus status;
  final String? website;
  final List<VerifiedIdentity> verifiedIdentities;

  ProfileLinksState copyWith({
    ProfileLinksStatus? status,
    String? website,
    List<VerifiedIdentity>? verifiedIdentities,
  }) => ProfileLinksState(
    status: status ?? this.status,
    website: website ?? this.website,
    verifiedIdentities: verifiedIdentities ?? this.verifiedIdentities,
  );

  @override
  List<Object?> get props => [status, website, verifiedIdentities];
}
