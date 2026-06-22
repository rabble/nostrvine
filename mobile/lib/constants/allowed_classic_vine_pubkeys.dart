// ABOUTME: Curated recovered-Vine account allowlist for the baseline serving policy.
// ABOUTME: Values must be lowercase 64-character Nostr hex pubkeys.

/// Recovered classic Vine accounts that Divine may serve without ProofMode
/// certification.
///
/// Keep this list in canonical hex form. Human-facing npubs or account labels
/// can live in review notes, but enforcement should compare only pubkeys from
/// `VideoEvent.pubkey`.
const allowedClassicVinePubkeys = <String>{};
