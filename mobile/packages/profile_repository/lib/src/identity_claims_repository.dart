// ABOUTME: IdentityClaimsRepository — composes VerifierClient with NIP-39
// ABOUTME: i tag parsing, a verified-claims cache (#3936) and the kind-10011
// ABOUTME: write path that links and unlinks accounts.

import 'dart:convert';
import 'dart:math';

import 'package:db_client/db_client.dart' hide Filter;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart' show Event, Filter;
import 'package:profile_repository/src/identity_event_selection.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:verifier_client/verifier_client.dart';

/// Signs an event on behalf of the current user.
///
/// Returns null when the signer refuses or is unavailable. Mirrors the
/// `AuthService.createAndSignEvent` shape the app wires in.
typedef IdentityEventSigner =
    Future<Event?> Function({
      required int kind,
      required String content,
      required List<List<String>> tags,
    });

/// The claims already on the identity event could not be read, so a write
/// would have replaced them with an incomplete set.
///
/// Recoverable and worth retrying: it means the relays did not answer, not
/// that anything is wrong with the claim being written.
class IdentityClaimReadException implements Exception {
  /// Creates an [IdentityClaimReadException].
  const IdentityClaimReadException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'IdentityClaimReadException: $message';
}

/// The identity event could not be published to any relay.
class IdentityClaimPublishException implements Exception {
  /// Creates an [IdentityClaimPublishException].
  const IdentityClaimPublishException(this.message);

  /// Human-readable description of the failure.
  final String message;

  @override
  String toString() => 'IdentityClaimPublishException: $message';
}

/// Every claim on a profile's identity event, with the verifier's verdict.
///
/// Unlike the rendering paths, this keeps unverified claims: the surface that
/// manages links has to show the one that stopped verifying.
class IdentityClaimStatus {
  /// Creates an [IdentityClaimStatus].
  const IdentityClaimStatus({
    required this.claims,
    required this.verifiedKeys,
    required this.verifierReachable,
  });

  /// Every claim on the identity event, in tag order.
  final List<IdentityClaim> claims;

  /// Lowercased `platform:identity` keys the verifier confirmed.
  final Set<String> verifiedKeys;

  /// False when the verifier could not be reached, so [verifiedKeys] is empty
  /// for lack of an answer rather than for lack of verified claims. UI should
  /// say "could not check" rather than "not verified".
  final bool verifierReachable;

  /// Whether [claim] carries a positive verdict.
  bool isVerified(IdentityClaim claim) => verifiedKeys.contains(
    '${claim.platform.toLowerCase()}:${claim.identity.toLowerCase()}',
  );
}

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
  ///
  /// [nostrClient] and [signEvent] enable the write path ([publishClaim] /
  /// [removeClaim]); without both, those methods throw [StateError]. Read-only
  /// consumers — every profile that only renders someone else's chips — keep
  /// constructing this without them. [identityEventsDao] lets a completed
  /// write refresh the local `i` tag cache so the new link renders without
  /// waiting on a relay reread.
  IdentityClaimsRepository({
    required VerifierClient verifierClient,
    IdentityVerificationsDao? identityVerificationsDao,
    NostrClient? nostrClient,
    IdentityEventSigner? signEvent,
    IdentityEventsDao? identityEventsDao,
  }) : _verifierClient = verifierClient,
       _verificationsDao = identityVerificationsDao,
       _nostrClient = nostrClient,
       _signEvent = signEvent,
       _identityEventsDao = identityEventsDao;

  /// Event kind carrying NIP-39 identity claims since the 2026-02 spec
  /// revision. Kind-0 `i` tags are the legacy source for profiles that
  /// predate it, and are carried forward on the first write.
  static const int identityEventKind = 10011;

  /// NIP-98 HTTP auth event kind, used to prove ownership when asking the
  /// verifier to drop a cached OAuth verification.
  static const int _nip98EventKind = 27235;

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
  final NostrClient? _nostrClient;
  final IdentityEventSigner? _signEvent;
  final IdentityEventsDao? _identityEventsDao;

  /// Tags this instance last published per pubkey.
  ///
  /// A relay confirms a write before it necessarily serves it back, so two
  /// links added in quick succession would each read a base that predates the
  /// other and publish it away. What this device published is the one thing
  /// it can be sure of, so it is merged over a read that has not caught up.
  final Map<String, List<List<String>>> _lastPublishedTags = {};

  /// Claim keys this instance last unlinked per pubkey.
  ///
  /// The mirror image of [_lastPublishedTags]: without it, merging a stale
  /// read back in would resurrect the claim that was just removed.
  final Map<String, Set<String>> _lastRemovedKeys = {};

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

  /// Reads the claims currently on [pubkey]'s identity event, verified or
  /// not.
  ///
  /// The rendering paths deliberately surface only verified claims; the
  /// manage-your-links surface needs the unverified ones too, since a claim
  /// that stopped verifying is exactly the one a user came to fix.
  ///
  /// Throws [StateError] if the repository was built without write
  /// dependencies — this reads through the same uncached relay query the
  /// write path builds on.
  Future<List<IdentityClaim>> currentClaims(String pubkey) async {
    return parseClaims(
      pubkey,
      await _currentIdentityTags(pubkey, forWrite: false),
    );
  }

  /// Reads [pubkey]'s claims together with the verifier's verdict on each.
  ///
  /// A verifier that cannot be reached is not a failure here: the links are
  /// the user's own data and stay visible, flagged as unchecked through
  /// [IdentityClaimStatus.verifierReachable]. Only the relay read can throw.
  ///
  /// Throws [StateError] if the repository was built without write
  /// dependencies.
  Future<IdentityClaimStatus> claimsWithVerdicts(String pubkey) async {
    final tags = await _currentIdentityTags(pubkey, forWrite: false);
    final claims = parseClaims(pubkey, tags);
    try {
      final verified = await resolveClaims(
        pubkey: pubkey,
        freshTags: tags,
        cached: await cachedVerifiedClaims(pubkey: pubkey, tags: tags),
      );
      return IdentityClaimStatus(
        claims: claims,
        verifiedKeys: {for (final claim in verified) _identityKeyOf(claim)},
        verifierReachable: true,
      );
    } on VerifierClientException {
      return IdentityClaimStatus(
        claims: claims,
        verifiedKeys: const {},
        verifierReachable: false,
      );
    }
  }

  /// Asks the verifier to check one claim, before it exists on any event.
  ///
  /// Deliberately does not touch the verdict snapshot: the claim is not on
  /// the identity event yet, and caching a verdict for a link that is never
  /// published would leave a snapshot entry nothing can ever match.
  ///
  /// Throws [VerifierClientException] subtypes.
  Future<VerificationResult> verifyClaim(IdentityClaim claim) {
    return _verifierClient.verifySingle(claim);
  }

  /// Lists the platforms the verifier currently accepts claims for.
  ///
  /// Platforms the service reports as unsupported are dropped: offering one
  /// leads to a link that can never verify.
  ///
  /// Throws [VerifierClientException] subtypes.
  Future<List<VerifierPlatform>> supportedPlatforms() async {
    final platforms = await _verifierClient.fetchPlatforms();
    return platforms.where((platform) => platform.supported).toList();
  }

  /// Whether this verifier deployment can start [platform]'s OAuth flow.
  ///
  /// See `VerifierClient.isOAuthConfigured` — a platform with an OAuth route
  /// still needs its credentials configured server-side.
  Future<bool> canStartOAuth({
    required String platform,
    required String pubkey,
    required String returnUrl,
    String? handle,
  }) {
    return _verifierClient.isOAuthConfigured(
      platform: platform,
      pubkey: pubkey,
      returnUrl: returnUrl,
      handle: handle,
    );
  }

  /// Builds the verifier URL that starts [platform]'s OAuth flow.
  ///
  /// See `VerifierClient.oauthStartUri` for the contract, including which
  /// return URLs the service accepts.
  Uri oauthStartUri({
    required String platform,
    required String pubkey,
    required String returnUrl,
    String? handle,
  }) {
    return _verifierClient.oauthStartUri(
      platform: platform,
      pubkey: pubkey,
      returnUrl: returnUrl,
      handle: handle,
    );
  }

  /// Links [claim] by writing it into the signer's kind-10011 identity event,
  /// and returns the `i` tags the published event carries.
  ///
  /// Any existing claim for the same `platform:identity` is replaced — that
  /// is how a re-link with a fresh proof updates in place. Every other tag on
  /// the event is carried through untouched, including claims for platforms
  /// this app does not know about: the event is the user's, and a client that
  /// cannot render a tag has no business dropping it. A profile whose claims
  /// still live in kind-0 tags has them carried into this first kind-10011
  /// write, matching what the verifier's web UI does.
  ///
  /// This publishes what it is told to. Confirming the claim with the
  /// verifier first is the caller's job — an unverified `i` tag is valid
  /// NIP-39 and simply renders unverified.
  ///
  /// Throws:
  ///
  /// * [StateError] if the repository was built without write dependencies.
  /// * [IdentityClaimPublishException] if the event cannot be signed, or no
  ///   relay confirms it.
  Future<List<List<String>>> publishClaim(IdentityClaim claim) async {
    final current = await _currentIdentityTags(claim.pubkey, forWrite: true);
    final key = _identityKeyOf(claim);
    // Linking again undoes an earlier unlink from this session.
    _lastRemovedKeys[claim.pubkey]?.remove(key);
    return _publishIdentityTags(claim.pubkey, [
      for (final tag in current)
        if (_tagIdentityKey(tag) != key) tag,
      ['i', '${claim.platform}:${claim.identity}', claim.proof],
    ]);
  }

  /// Unlinks the claim matching [claim]'s `platform:identity` and returns the
  /// `i` tags left on the event.
  ///
  /// Proof-agnostic, so a claim whose proof was rotated elsewhere is still
  /// removed. When the claim is not on the event, nothing is published and
  /// the current tags are returned unchanged — re-publishing an identical
  /// event would only churn relays.
  ///
  /// An OAuth-linked claim also asks the verifier to drop its cached OAuth
  /// verification, so re-linking asks the provider again instead of passing
  /// on a 24-hour-old login. That call is best-effort: the tag is already
  /// gone, which is what the user asked for, and a verifier that refuses the
  /// revoke must not turn a completed unlink into an error.
  ///
  /// Throws the same exceptions as [publishClaim].
  Future<List<List<String>>> removeClaim(IdentityClaim claim) async {
    final current = await _currentIdentityTags(claim.pubkey, forWrite: true);
    final key = _identityKeyOf(claim);
    final next = [
      for (final tag in current)
        if (_tagIdentityKey(tag) != key) tag,
    ];
    if (next.length == current.length) return current;
    final published = await _publishIdentityTags(claim.pubkey, next);
    (_lastRemovedKeys[claim.pubkey] ??= <String>{}).add(key);
    await _revokeOAuthLink(claim);
    return published;
  }

  /// Drops the verifier's cached OAuth verification for [claim].
  ///
  /// No-op unless the claim was actually OAuth-linked. Never throws.
  Future<void> _revokeOAuthLink(IdentityClaim claim) async {
    if (claim.proof != IdentityClaim.oauthProof) return;
    if (!VerifierPlatform.oauthPlatforms.contains(claim.platform)) return;

    try {
      final url = _verifierClient.oauthRevokeUrl;
      final event = await _writeDeps().sign(
        kind: _nip98EventKind,
        content: '',
        tags: [
          ['u', url],
          ['method', 'POST'],
        ],
      );
      if (event == null) return;
      await _verifierClient.revokeOAuth(
        platform: claim.platform,
        identity: claim.identity,
        pubkey: claim.pubkey,
        nip98Event: event.toJson(),
      );
    } on Object catch (e) {
      Log.warning(
        'Verifier OAuth revoke failed for ${claim.platform}: $e',
        name: 'IdentityClaimsRepository',
      );
    }
  }

  /// Reads the `i` tags the next write must build on.
  ///
  /// Uncached on purpose: the event is about to be replaced wholesale, and a
  /// stale read would silently drop a claim linked on another device.
  /// Reads the `i` tags currently on [pubkey]'s identity event.
  ///
  /// [forWrite] decides what an unanswered read means. The query cannot say
  /// whether an empty result is "no claims yet" or "no relay answered", and
  /// the two need opposite handling:
  ///
  /// * Writing replaces the whole event, so publishing over an unanswered read
  ///   would silently unlink everything else, and would make a removal a no-op
  ///   that still reports success. There the local snapshot is treated as
  ///   evidence the read was incomplete, and the write is refused.
  /// * Reading has nothing to lose by showing the last known good set, and
  ///   everything to lose by blanking the screen — a list that empties itself
  ///   on a relay hiccup reads as "my links are gone".
  Future<List<List<String>>> _currentIdentityTags(
    String pubkey, {
    required bool forWrite,
  }) async {
    final client = _writeDeps().client;
    // An OAuth link sends the app to the browser and back, and the relay pool
    // does not survive that round trip. Reading against a pool that has not
    // reconnected yet returns nothing, which on the write path is refused as
    // an incomplete read — so the first attempt after returning would always
    // fail and the second would work. Reconnect first, exactly as the publish
    // path already does before sending.
    if (client.connectedRelays.isEmpty) {
      await client.retryDisconnectedRelays();
    }
    // With no relay connected, "the query returned nothing" carries no
    // information at all — and a write acts on it by replacing the whole
    // event. Refusing here is the only check that does not depend on local
    // evidence being present, which is what makes it the one that holds on a
    // device that has never completed a read.
    if (forWrite && client.connectedRelays.isEmpty) {
      throw const IdentityClaimReadException(
        'No relay is connected, so the current links cannot be read',
      );
    }
    final identityEvent = await _newestEventOfKind(
      client,
      pubkey,
      identityEventKind,
    );
    if (identityEvent != null) {
      final tags = _mergeWithLastPublished(
        pubkey,
        identityTagsOf(identityEvent.tags),
      );
      Log.info(
        'Identity event for $pubkey carries ${tags.length} claim tag(s)',
        name: 'IdentityClaimsRepository',
      );
      await _cacheIdentityTags(pubkey, tags);
      return tags;
    }

    final legacyEvent = await _newestEventOfKind(client, pubkey, 0);
    if (legacyEvent != null) {
      final tags = identityTagsOf(legacyEvent.tags);
      Log.info(
        'No kind-$identityEventKind event for $pubkey; kind-0 carries '
        '${tags.length} claim tag(s)',
        name: 'IdentityClaimsRepository',
      );
      return tags;
    }

    final cached = await _cachedIdentityTags(pubkey);
    Log.warning(
      'No identity event returned for $pubkey; snapshot has '
      '${cached?.length ?? 0} claim tag(s)',
      name: 'IdentityClaimsRepository',
    );
    if (cached == null || cached.isEmpty) {
      // The identity snapshot can be absent on a device that has never
      // completed a read. The verdict snapshot is written by a different code
      // path, so it is a second, independent witness that this profile does
      // have claims worth not overwriting.
      if (forWrite && await _hasVerdictSnapshot(pubkey)) {
        throw const IdentityClaimReadException(
          'Relays returned no identity event, but verified claims are on '
          'record for this profile — refusing to publish over them',
        );
      }
      return const [];
    }
    if (forWrite) {
      throw const IdentityClaimReadException(
        'Relays returned no identity event, but this profile is known to have '
        'claims — refusing to publish over them',
      );
    }
    return cached;
  }

  /// Whether the verdict snapshot has ever recorded a verified claim here.
  Future<bool> _hasVerdictSnapshot(String pubkey) async {
    final dao = _verificationsDao;
    if (dao == null) return false;
    try {
      final row = await dao.getVerification(pubkey);
      if (row == null) return false;
      return _decodeSnapshot(row.verifiedClaimsJson)?.isNotEmpty ?? false;
    } on Object catch (e) {
      Log.warning(
        'Verdict snapshot read failed for $pubkey: $e',
        name: 'IdentityClaimsRepository',
      );
      return false;
    }
  }

  /// Last known `i` tags from the local snapshot, or null when there is none
  /// or it cannot be read.
  ///
  /// Any source kind counts: a kind-0 row still proves the profile had claims,
  /// which is all this is asked for.
  Future<List<List<String>>?> _cachedIdentityTags(String pubkey) async {
    final dao = _identityEventsDao;
    if (dao == null) return null;
    try {
      final row = await dao.getEvent(pubkey);
      if (row == null) return null;
      final decoded = jsonDecode(row.tagsJson) as List<dynamic>;
      return [
        for (final tag in decoded)
          (tag as List<dynamic>).map((value) => value as String).toList(),
      ];
    } on Object catch (e) {
      Log.warning(
        'Identity-tags snapshot read failed for $pubkey: $e',
        name: 'IdentityClaimsRepository',
      );
      return null;
    }
  }

  Future<Event?> _newestEventOfKind(
    NostrClient client,
    String pubkey,
    int kind,
  ) async {
    final events = await client.queryEvents([
      Filter(kinds: [kind], authors: [pubkey], limit: 5),
    ], useCache: false);
    return newestIdentityEvent(
      events.where((e) => e.kind == kind).toList(),
    );
  }

  Future<List<List<String>>> _publishIdentityTags(
    String pubkey,
    List<List<String>> tags,
  ) async {
    final deps = _writeDeps();
    final event = await deps.sign(
      kind: identityEventKind,
      content: '',
      tags: tags,
    );
    if (event == null) {
      throw const IdentityClaimPublishException(
        'Could not sign the identity event',
      );
    }

    final outcome = await deps.client.publishEventAwaitOk(event);
    if (outcome.failed) {
      throw IdentityClaimPublishException(
        'No relay confirmed the identity event: ${outcome.summary}',
      );
    }

    await _cacheIdentityTags(pubkey, tags);
    _lastPublishedTags[pubkey] = tags;
    return tags;
  }

  /// Adds back any claim this device published that [relayTags] does not carry
  /// yet, so a relay that has not caught up cannot make the next write drop it.
  List<List<String>> _mergeWithLastPublished(
    String pubkey,
    List<List<String>> relayTags,
  ) {
    final published = _lastPublishedTags[pubkey];
    if (published == null) return relayTags;

    final removed = _lastRemovedKeys[pubkey] ?? const <String>{};
    final kept = [
      for (final tag in relayTags)
        if (!removed.contains(_tagIdentityKey(tag))) tag,
    ];
    final present = {for (final tag in kept) _tagIdentityKey(tag)};
    final missing = [
      for (final tag in published)
        if (!present.contains(_tagIdentityKey(tag))) tag,
    ];
    if (missing.isEmpty && kept.length == relayTags.length) return relayTags;

    Log.warning(
      'Relay read for $pubkey lags this device: re-adding ${missing.length} '
      'published claim(s), dropping ${relayTags.length - kept.length} removed',
      name: 'IdentityClaimsRepository',
    );
    return [...kept, ...missing];
  }

  /// Mirrors the published tags into the local identity cache so the new
  /// link renders immediately. Best-effort: a storage failure must not turn
  /// a landed publish into a thrown one.
  Future<void> _cacheIdentityTags(
    String pubkey,
    List<List<String>> tags,
  ) async {
    try {
      await _identityEventsDao?.upsertEvent(
        pubkey: pubkey,
        tagsJson: jsonEncode(tags),
        sourceKind: identityEventKind,
      );
    } on Object catch (e) {
      Log.warning(
        'Identity-tags cache write after publish failed for $pubkey: $e',
        name: 'IdentityClaimsRepository',
      );
    }
  }

  ({NostrClient client, IdentityEventSigner sign}) _writeDeps() {
    final client = _nostrClient;
    final sign = _signEvent;
    if (client == null || sign == null) {
      throw StateError(
        'IdentityClaimsRepository was built without a NostrClient and signer, '
        'so it cannot write identity claims',
      );
    }
    return (client: client, sign: sign);
  }

  /// Normalized `platform:identity` key of a raw `i` tag.
  static String _tagIdentityKey(List<String> tag) => tag[1].toLowerCase();

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
