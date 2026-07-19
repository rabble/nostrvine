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

class _VerificationOutcome {
  const _VerificationOutcome({
    required this.verified,
    required this.rateLimited,
  });

  final List<IdentityClaim> verified;
  final bool rateLimited;
}

/// Composes [VerifierClient] with NIP-39 `i` tag parsing off identity
/// events (kind 10011, with kind-0 tags as the legacy fallback) and a
/// persistent verified-claims cache.
class IdentityClaimsRepository {
  /// Creates an [IdentityClaimsRepository] backed by [verifierClient].
  ///
  /// [identityVerificationsDao] enables the persistent verdict cache;
  /// when null, [cachedVerifiedClaims] returns null and [resolveClaims]
  /// skips persistence on its verify path.
  IdentityClaimsRepository({
    required VerifierClient verifierClient,
    IdentityVerificationsDao? identityVerificationsDao,
  }) : _verifierClient = verifierClient,
       _verificationsDao = identityVerificationsDao;

  /// Client-side freshness window for verified verdicts, anchored on the
  /// verifier's `checked_at`. Mirrors the service's KV TTL for verified
  /// results (divine-identify-verification-service/src/utils/cache.ts:4).
  static const Duration verifiedTtl = Duration(hours: 24);

  /// Prefix of the verifier's rate-limit rejection message
  /// (divine-identify-verification-service/src/routes/verify.ts:59-81). The
  /// verifier returns rate-limit rejections as HTTP-200 `verified: false`
  /// bodies it never caches server-side, so any result carrying this prefix
  /// must leave the local snapshot untouched — otherwise a rate-limit burst
  /// could overwrite real verdicts.
  ///
  /// [VerificationResult.error] is documented as a free-form, non-stable
  /// string, so this is a best-effort prefix match; a stable server-side
  /// rate-limit flag would remove the fragility entirely.
  static const String rateLimitErrorPrefix = 'Rate limit exceeded';

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

  /// Resolves the claims to render for [pubkey] from the freshest claim
  /// source [freshTags], reusing the instant-path snapshot [cached] already
  /// read via [cachedVerifiedClaims].
  ///
  /// This owns the stale-while-revalidate decision (kept here, not in the
  /// blocs, per architecture.md's repository-owns-source-selection rule):
  /// when [cached] is fresh and already covers every current claim, the
  /// verifier is skipped and the parsed fresh claims are returned as-is.
  /// Otherwise the claims are re-verified against the service, which also
  /// refreshes the persistent snapshot. The source tags are parsed exactly
  /// once regardless of which branch is taken.
  ///
  /// Throws [VerifierClientException] subtypes on the verify path — callers
  /// should catch and keep the last-known-good claims rather than clearing
  /// them.
  Future<List<IdentityClaim>> resolveClaims({
    required String pubkey,
    required List<List<String>> freshTags,
    required CachedVerifiedClaims? cached,
  }) async {
    final freshClaims = parseClaims(pubkey, freshTags);
    if (cached != null && cached.isFresh) {
      final verifiedSet = cached.claims.toSet();
      if (freshClaims.every(verifiedSet.contains)) {
        return freshClaims;
      }
    }
    final outcome = await _verifyClaims(pubkey: pubkey, claims: freshClaims);
    if (outcome.rateLimited && cached != null && cached.claims.isNotEmpty) {
      return _preserveCachedCurrentClaims(
        freshClaims: freshClaims,
        cachedClaims: cached.claims,
        verifiedClaims: outcome.verified,
      );
    }
    return outcome.verified;
  }

  /// Asks the verifier to re-check [claims] and returns only the verified
  /// ones, preserving input order.
  ///
  /// On success the persistent snapshot for [pubkey] is updated: verified
  /// tuples are stored with the batch's minimum `checked_at`; a
  /// zero-verified response deletes the snapshot. Only positive verdicts
  /// are ever persisted — and when any result carries the verifier's
  /// rate-limit error (see [rateLimitErrorPrefix]) the snapshot is left
  /// untouched so a rate-limit burst cannot overwrite real verdicts.
  ///
  /// Throws [VerifierClientException] subtypes.
  Future<_VerificationOutcome> _verifyClaims({
    required String pubkey,
    required List<IdentityClaim> claims,
  }) async {
    if (claims.isEmpty) {
      return const _VerificationOutcome(verified: [], rateLimited: false);
    }
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
    final rateLimited = _isRateLimited(results);
    await _persistOutcome(
      pubkey: pubkey,
      results: results,
      verified: verified,
      rateLimited: rateLimited,
    );
    return _VerificationOutcome(verified: verified, rateLimited: rateLimited);
  }

  List<IdentityClaim> _preserveCachedCurrentClaims({
    required List<IdentityClaim> freshClaims,
    required List<IdentityClaim> cachedClaims,
    required List<IdentityClaim> verifiedClaims,
  }) {
    final cachedTuples = {for (final claim in cachedClaims) _tupleOf(claim)};
    final verifiedTuples = {
      for (final claim in verifiedClaims) _tupleOf(claim),
    };
    return [
      for (final claim in freshClaims)
        if (verifiedTuples.contains(_tupleOf(claim)) ||
            cachedTuples.contains(_tupleOf(claim)))
          claim,
    ];
  }

  Future<void> _persistOutcome({
    required String pubkey,
    required List<VerificationResult> results,
    required List<IdentityClaim> verified,
    required bool rateLimited,
  }) async {
    final dao = _verificationsDao;
    if (dao == null) return;

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

  bool _isRateLimited(List<VerificationResult> results) {
    return results.any(
      (r) =>
          !r.verified && (r.error?.startsWith(rateLimitErrorPrefix) ?? false),
    );
  }

  /// Normalized comparison tuple for snapshot matching.
  static (String, String, String) _tupleOf(IdentityClaim claim) =>
      (claim.platform.toLowerCase(), claim.identity.toLowerCase(), claim.proof);

  /// Decodes a stored snapshot into comparison tuples; null when malformed
  /// or wrong-shaped.
  ///
  /// Catches [Object] (not just [Exception]): a valid-JSON-but-wrong-shape
  /// row throws a [TypeError] (an [Error]) on the casts, which must still
  /// uphold the null-when-malformed contract rather than escaping to a
  /// reportable crash.
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
    } on Object {
      return null;
    }
  }
}
