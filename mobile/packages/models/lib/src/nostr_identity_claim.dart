// ABOUTME: NIP-39 external identity claim parsed from a kind-0 ["i", ...] tag

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/src/identity_platform.dart';

/// A NIP-39 external identity claim.
///
/// Represented in a kind-0 event as
/// `["i", "<platform>:<identity>", "<proof>"]`.
///
/// A claim is *not* the same as a verified identity. Verification is
/// performed separately by `IdentityVerificationRepository`.
@immutable
class NostrIdentityClaim extends Equatable {
  const NostrIdentityClaim({
    required this.platform,
    required this.identity,
    required this.proof,
  });

  /// Parses a single NIP-39 `i` tag. Returns `null` if [tag] is not a
  /// valid `i` tag, references an unknown platform, or has an empty
  /// identity portion.
  static NostrIdentityClaim? fromTag(List<String> tag) {
    if (tag.length < 2 || tag[0] != 'i') return null;
    final value = tag[1];
    final colonIndex = value.indexOf(':');
    if (colonIndex <= 0 || colonIndex == value.length - 1) return null;
    final platform = IdentityPlatform.fromTagPrefix(
      value.substring(0, colonIndex),
    );
    if (platform == null) return null;
    final identity = value.substring(colonIndex + 1);
    if (identity.isEmpty) return null;
    final proof = tag.length >= 3 ? tag[2] : '';
    return NostrIdentityClaim(
      platform: platform,
      identity: identity,
      proof: proof,
    );
  }

  final IdentityPlatform platform;
  final String identity;
  final String proof;

  /// Serialises this claim back to a NIP-39 `i` tag. Always emits a
  /// 3-element list — the proof slot is empty when no proof is set.
  List<String> toTag() => ['i', '${platform.name}:$identity', proof];

  @override
  List<Object?> get props => [platform, identity, proof];
}
