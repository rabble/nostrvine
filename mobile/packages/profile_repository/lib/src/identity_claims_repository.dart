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
    this.confirmedNegativeKeys = const {},
  });

  final List<IdentityClaim> verified;
  final bool rateLimited;

  /// Lowercased `platform:identity` keys the verifier explicitly judged
  /// negative with a non-rate-limited result. Honored even inside a
  /// rate-limited batch, where they must still drop their claim.
  final Set<String> confirmedNegativeKeys;
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
  /// bodies it never caches server-side, so a batch containing this prefix
  /// must not write new verdicts to the local snapshot — otherwise a
  /// rate-limit burst could overwrite real verdicts. (Per-claim confirmed
  /// negatives inside such a batch are conclusive and are still pruned.)
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
  /// Filters to `['i', '<platform>:<identity>', '<proof>']` shape and the
  /// verifier's request contract, skips malformed entries, dedupes
  /// case-insensitively on `<platform>:<identity>` (preferring the first
  /// valid occurrence — matches verifier UI behaviour at
  /// `divine-identify-verification-service/src/index.ts:1784`), caps valid
  /// claims at [VerifierClient.maxBatchSize] (10) so a single batch suffices.
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
      final claim = IdentityClaim(
        pubkey: pubkey,
        platform: platform,
        identity: identity,
        proof: tag[2],
      );
      if (!claim.isServerValid) continue;
      final dedupeKey = '$platform:$identity'.toLowerCase();
      if (!seen.add(dedupeKey)) continue;
      claims.add(claim);
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
  /// [renderedClaims] is the caller's currently-rendered last-known-good
  /// claim set. A rate-limited verifier outcome is inconclusive (the
  /// service never caches it server-side), so it must not clear chips the
  /// user can already see: any rendered or snapshot-cached claim still
  /// present in [freshTags] is preserved, matched per `platform:identity`
  /// case-insensitively (proof-agnostic, so a proof rotation coinciding
  /// with a rate-limit window keeps the chip). Only a per-claim confirmed
  /// negative verdict from a non-rate-limited result, or the claim's
  /// removal from the source tags, drops a claim from the result.
  ///
  /// Throws [VerifierClientException] subtypes on the verify path — callers
  /// should catch and keep the last-known-good claims rather than clearing
  /// them.
  Future<List<IdentityClaim>> resolveClaims({
    required String pubkey,
    required List<List<String>> freshTags,
    required CachedVerifiedClaims? cached,
    List<IdentityClaim> renderedClaims = const [],
  }) async {
    final freshClaims = parseClaims(pubkey, freshTags);
    if (cached != null && cached.isFresh) {
      final verifiedSet = cached.claims.toSet();
      if (freshClaims.every(verifiedSet.contains)) {
        return freshClaims;
      }
    }
    final outcome = await _verifyClaims(pubkey: pubkey, claims: freshClaims);
    if (outcome.rateLimited) {
      return _preserveKnownGoodClaims(
        freshClaims: freshClaims,
        knownGoodClaims: [...?cached?.claims, ...renderedClaims],
        outcome: outcome,
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
  /// rate-limit error (see [rateLimitErrorPrefix]) no new verdicts are
  /// written, so a rate-limit burst cannot overwrite real verdicts. The
  /// one exception: entries whose own result is a confirmed negative are
  /// pruned from the snapshot even in a rate-limited batch, so a negated
  /// claim cannot keep resurrecting from cache.
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
    final confirmedNegativeKeys = <String>{
      for (final r in results)
        if (!r.verified && !_isRateLimitResult(r))
          '${r.platform.toLowerCase()}:${r.identity.toLowerCase()}',
    };
    final verified = claims
        .where((c) => verifiedKeys.contains(_identityKeyOf(c)))
        .toList();
    final rateLimited = results.any(_isRateLimitResult);
    await _persistOutcome(
      pubkey: pubkey,
      results: results,
      verified: verified,
      rateLimited: rateLimited,
      confirmedNegativeKeys: confirmedNegativeKeys,
    );
    return _VerificationOutcome(
      verified: verified,
      rateLimited: rateLimited,
      confirmedNegativeKeys: confirmedNegativeKeys,
    );
  }

  /// Preservation for a rate-limited (inconclusive) batch: a fresh claim
  /// survives when its own result verified it, or when it was known-good
  /// (snapshot or rendered) and its own result was not a confirmed
  /// negative. Matching is per `platform:identity`, case-insensitive and
  /// proof-agnostic — the verifier judges identities, not proof strings,
  /// so a rotated proof must not silently drop a chip while the verdict
  /// is inconclusive.
  List<IdentityClaim> _preserveKnownGoodClaims({
    required List<IdentityClaim> freshClaims,
    required List<IdentityClaim> knownGoodClaims,
    required _VerificationOutcome outcome,
  }) {
    final knownGoodKeys = {
      for (final claim in knownGoodClaims) _identityKeyOf(claim),
    };
    final verifiedKeys = {
      for (final claim in outcome.verified) _identityKeyOf(claim),
    };
    return [
      for (final claim in freshClaims)
        if (verifiedKeys.contains(_identityKeyOf(claim)) ||
            (knownGoodKeys.contains(_identityKeyOf(claim)) &&
                !outcome.confirmedNegativeKeys.contains(
                  _identityKeyOf(claim),
                )))
          claim,
    ];
  }

  Future<void> _persistOutcome({
    required String pubkey,
    required List<VerificationResult> results,
    required List<IdentityClaim> verified,
    required bool rateLimited,
    required Set<String> confirmedNegativeKeys,
  }) async {
    final dao = _verificationsDao;
    if (dao == null) return;

    if (rateLimited) {
      // A rate-limited batch persists no new verdicts, but any per-claim
      // confirmed negative inside it is conclusive — prune those tuples
      // so a negated claim cannot resurrect from the snapshot through
      // the instant path or the fresh-and-covering skip.
      await _pruneConfirmedNegatives(dao, pubkey, confirmedNegativeKeys);
      return;
    }

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

  /// Removes snapshot entries whose `platform:identity` key received a
  /// confirmed (non-rate-limited) negative verdict. Rows that are missing
  /// or malformed are left alone — the read path already treats them as
  /// no-snapshot.
  Future<void> _pruneConfirmedNegatives(
    IdentityVerificationsDao dao,
    String pubkey,
    Set<String> confirmedNegativeKeys,
  ) async {
    if (confirmedNegativeKeys.isEmpty) return;
    final row = await dao.getVerification(pubkey);
    if (row == null) return;
    final List<Map<String, dynamic>> kept;
    try {
      final entries = (jsonDecode(row.verifiedClaimsJson) as List<dynamic>)
          .cast<Map<String, dynamic>>();
      kept = [
        for (final entry in entries)
          if (!confirmedNegativeKeys.contains(
            '${(entry['platform'] as String).toLowerCase()}'
            ':${(entry['identity'] as String).toLowerCase()}',
          ))
            entry,
      ];
      if (kept.length == entries.length) return;
    } on Object {
      return;
    }
    if (kept.isEmpty) {
      await dao.deleteVerification(pubkey);
    } else {
      await dao.upsertVerification(
        pubkey: pubkey,
        verifiedClaimsJson: jsonEncode(kept),
        checkedAtFloor: row.checkedAtFloor,
      );
    }
  }

  static bool _isRateLimitResult(VerificationResult result) =>
      !result.verified &&
      (result.error?.startsWith(rateLimitErrorPrefix) ?? false);

  /// Normalized comparison tuple for snapshot matching.
  static (String, String, String) _tupleOf(IdentityClaim claim) =>
      (claim.platform.toLowerCase(), claim.identity.toLowerCase(), claim.proof);

  /// Normalized `platform:identity` key — the granularity the verifier
  /// judges at (proofs are evidence, not identity).
  static String _identityKeyOf(IdentityClaim claim) =>
      '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}';

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
