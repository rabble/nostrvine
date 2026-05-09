// ABOUTME: IdentityClaimsRepository — composes VerifierClient with NIP-39
// ABOUTME: i tag parsing off kind 0 events.

import 'package:verifier_client/verifier_client.dart';

/// Composes [VerifierClient] with NIP-39 `i` tag parsing off kind 0 events.
class IdentityClaimsRepository {
  /// Creates an [IdentityClaimsRepository] backed by [verifierClient].
  IdentityClaimsRepository({required VerifierClient verifierClient})
    : _verifierClient = verifierClient;

  final VerifierClient _verifierClient;

  /// Parses NIP-39 identity claims out of the given kind-0 event tag list.
  ///
  /// Filters to `['i', '<platform>:<identity>', '<proof>']` shape, skips
  /// malformed entries, dedupes case-insensitively on `<platform>:<identity>`
  /// (preferring the first occurrence — matches verifier UI behaviour at
  /// `divine-identify-verification-service/src/index.ts:1784`), caps at
  /// [VerifierClient.maxBatchSize] (10) so a single batch suffices.
  static List<IdentityClaim> parseClaims(
    String pubkey,
    List<List<String>> tags,
  ) {
    final seen = <String>{};
    final claims = <IdentityClaim>[];
    for (final tag in tags) {
      if (tag.isEmpty || tag[0] != 'i') continue;
      if (tag.length < 3) continue;
      final claimKey = tag[1];
      final colon = claimKey.indexOf(':');
      if (colon <= 0 || colon == claimKey.length - 1) continue;
      final platform = claimKey.substring(0, colon);
      final identity = claimKey.substring(colon + 1);
      final dedupeKey = '$platform:$identity'.toLowerCase();
      if (!seen.add(dedupeKey)) continue;
      claims.add(
        IdentityClaim(
          pubkey: pubkey,
          platform: platform,
          identity: identity,
          proof: tag[2],
        ),
      );
      if (claims.length >= VerifierClient.maxBatchSize) break;
    }
    return claims;
  }

  /// Parses claims from [tags] and asks the verifier to re-check them. Returns
  /// only the verified ones, preserving input order.
  ///
  /// Throws [VerifierClientException] subtypes — callers should catch and emit
  /// empty / failure state without surfacing the message.
  Future<List<IdentityClaim>> verifiedClaims({
    required String pubkey,
    required List<List<String>> tags,
  }) async {
    final claims = parseClaims(pubkey, tags);
    if (claims.isEmpty) return const [];
    final results = await _verifierClient.verifyBatch(claims);
    final verifiedKeys = <String>{
      for (final r in results)
        if (r.verified)
          '${r.platform.toLowerCase()}:${r.identity.toLowerCase()}',
    };
    return claims
        .where(
          (c) => verifiedKeys.contains(
            '${c.platform.toLowerCase()}:${c.identity.toLowerCase()}',
          ),
        )
        .toList();
  }
}
