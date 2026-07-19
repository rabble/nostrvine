// ABOUTME: IdentityClaimsRepository — composes VerifierClient with NIP-39
// ABOUTME: i tag parsing and a persistent verified-claims cache (#3936).

import 'dart:convert';
import 'dart:math';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:verifier_client/verifier_client.dart';

/// Verified claims read from the persistent snapshot cache.
class CachedVerifiedClaims {
  /// Creates a [CachedVerifiedClaims].
  const CachedVerifiedClaims({required this.claims, required this.isFresh});

  /// The subset of the profile's current claims that the snapshot has a
  /// positive verdict for (full-tuple match including proof).
  final List<IdentityClaim> claims;

  /// Whether the snapshot is within the verifier's 24h verified TTL
  /// (anchored on the verifier's own `checked_at`).
  final bool isFresh;
}

/// Composes [VerifierClient] with NIP-39 `i` tag parsing off identity
/// events (kind 10011, with kind-0 tags as the legacy fallback) and a
/// persistent verified-claims cache.
class IdentityClaimsRepository {
  /// Creates an [IdentityClaimsRepository] backed by [verifierClient].
  ///
  /// [identityVerificationsDao] enables the persistent verdict cache;
  /// when null, [cachedVerifiedClaims] returns null and [verifiedClaims]
  /// skips persistence.
  IdentityClaimsRepository({
    required VerifierClient verifierClient,
    IdentityVerificationsDao? identityVerificationsDao,
  }) : _verifierClient = verifierClient,
       _verificationsDao = identityVerificationsDao;

  /// Client-side freshness window for verified verdicts, anchored on the
  /// verifier's `checked_at`. Mirrors the service's KV TTL for verified
  /// results (divine-identify-verification-service/src/utils/cache.ts:4).
  static const Duration verifiedTtl = Duration(hours: 24);

  final VerifierClient _verifierClient;
  final IdentityVerificationsDao? _verificationsDao;

  /// Parses NIP-39 identity claims out of the given identity-event tag
  /// list (kind 10011, or kind 0 for pre-migration profiles).
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

  /// Returns the persisted verified subset of the claims in [tags], with a
  /// freshness flag — without hitting the network.
  ///
  /// Matching is a full-tuple intersection: platform and identity compare
  /// case-insensitively, proof compares exactly. A rotated proof therefore
  /// misses the snapshot and re-verifies instead of serving a stale
  /// verdict; removed claims are filtered out by the intersection.
  ///
  /// Returns null when no snapshot exists for [pubkey], the stored row is
  /// corrupt, or no DAO is wired.
  Future<CachedVerifiedClaims?> cachedVerifiedClaims({
    required String pubkey,
    required List<List<String>> tags,
  }) async {
    final dao = _verificationsDao;
    if (dao == null) return null;
    final row = await dao.getVerification(pubkey);
    if (row == null) return null;
    final snapshot = _decodeSnapshot(row.verifiedClaimsJson);
    if (snapshot == null) return null;

    final claims = parseClaims(pubkey, tags);
    final verified = claims
        .where((c) => snapshot.contains(_tupleOf(c)))
        .toList();
    final nowSeconds = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final isFresh = nowSeconds < row.checkedAtFloor + verifiedTtl.inSeconds;
    return CachedVerifiedClaims(claims: verified, isFresh: isFresh);
  }

  /// Parses claims from [tags] and asks the verifier to re-check them.
  /// Returns only the verified ones, preserving input order.
  ///
  /// On success the persistent snapshot for [pubkey] is updated: verified
  /// tuples are stored with the batch's minimum `checked_at`; a
  /// zero-verified response deletes the snapshot. Only positive verdicts
  /// are ever persisted — and when any result carries the verifier's
  /// rate-limit error (an HTTP-200 `verified: false` the server itself
  /// never caches, divine-identify-verification-service/src/routes/
  /// verify.ts:59-81), the snapshot is left untouched so a rate-limit
  /// burst cannot overwrite real verdicts.
  ///
  /// Throws [VerifierClientException] subtypes — callers should catch and
  /// keep the last-known-good claims rather than clearing them.
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
    final verified = claims
        .where(
          (c) => verifiedKeys.contains(
            '${c.platform.toLowerCase()}:${c.identity.toLowerCase()}',
          ),
        )
        .toList();
    await _persistOutcome(pubkey: pubkey, results: results, verified: verified);
    return verified;
  }

  Future<void> _persistOutcome({
    required String pubkey,
    required List<VerificationResult> results,
    required List<IdentityClaim> verified,
  }) async {
    final dao = _verificationsDao;
    if (dao == null) return;

    final rateLimited = results.any(
      (r) =>
          !r.verified && (r.error?.startsWith('Rate limit exceeded') ?? false),
    );
    if (rateLimited) return;

    if (verified.isEmpty) {
      await dao.deleteVerification(pubkey);
      return;
    }

    final checkedAtFloor = results
        .where((r) => r.verified)
        .map((r) => r.checkedAt)
        .reduce(min);
    await dao.upsertVerification(
      pubkey: pubkey,
      verifiedClaimsJson: jsonEncode([
        for (final c in verified)
          {'platform': c.platform, 'identity': c.identity, 'proof': c.proof},
      ]),
      checkedAtFloor: checkedAtFloor,
    );
  }

  /// Normalized comparison tuple for snapshot matching.
  static (String, String, String) _tupleOf(IdentityClaim claim) => (
    claim.platform.toLowerCase(),
    claim.identity.toLowerCase(),
    claim.proof,
  );

  /// Decodes a stored snapshot into comparison tuples; null when malformed.
  static Set<(String, String, String)>? _decodeSnapshot(String json) {
    try {
      final decoded = jsonDecode(json) as List<dynamic>;
      return {
        for (final entry in decoded.cast<Map<String, dynamic>>())
          (
            (entry['platform'] as String).toLowerCase(),
            (entry['identity'] as String).toLowerCase(),
            entry['proof'] as String,
          ),
      };
    } on Exception {
      return null;
    }
  }
}
