// ABOUTME: IdentityClaim model — a single platform attestation request.
// ABOUTME: Mirrors the verifier service's VerifyClaim payload shape.

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A single claim that a Nostr pubkey owns an external identity on a
/// supported platform.
///
/// Mirrors the verifier service's `VerifyClaim` shape in
/// `divine-identify-verification-service/src/types.ts`.
@immutable
class IdentityClaim extends Equatable {
  /// Creates an [IdentityClaim] for [pubkey] on [platform] with [identity]
  /// and [proof].
  const IdentityClaim({
    required this.pubkey,
    required this.platform,
    required this.identity,
    required this.proof,
  });

  /// 64-character lowercase hex pubkey.
  final String pubkey;

  /// Platform identifier — one of `github | twitter | mastodon |
  /// telegram | bluesky | discord | youtube | tiktok` at the time of
  /// writing. Forward-compatible: the verifier may add platforms.
  final String platform;

  /// Platform-specific user identifier (handle, account ID).
  final String identity;

  /// Proof material (URL, post ID, OAuth token reference, …) — opaque
  /// to mobile.
  final String proof;

  /// Serializes this claim to the verifier API JSON shape.
  Map<String, dynamic> toJson() => <String, dynamic>{
    'pubkey': pubkey,
    'platform': platform,
    'identity': identity,
    'proof': proof,
  };

  @override
  List<Object?> get props => [pubkey, platform, identity, proof];
}
