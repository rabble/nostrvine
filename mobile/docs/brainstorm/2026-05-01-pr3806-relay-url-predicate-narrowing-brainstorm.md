# Brainstorm: PR #3806 review — narrow `isRelayUrlAllowed` to WebSocket-only

Date: 2026-05-01

Trigger: review `pullrequestreview-4212556361` on PR #3806
(`fix/3362-reject-insecure-relay-schemes`).

## Problem Statement

Reviewer requested changes for two related issues, both rooted in the
same predicate:

1. **Blocking — discovery layer (`relay_discovery_service.dart:382` and
   `:453`).** NIP-65 parsing and the cache reader both gate on
   `isRelayUrlAllowed`, but that predicate also accepts `https://anyhost`
   and `http://<loopback>` to keep NIP-11 capability fetches behind one
   gate. NIP-65 only ever publishes WebSocket relay URLs. A
   `["r", "https://relay.example.com"]` tag is currently kept by the
   parser, makes `RelayDiscoveryResult.hasRelays == true`, suppresses
   the safe-fallback bootstrap (#2931), and then fails downstream when
   `RelayManager._normalizeUrl` rejects it — leaving the user with no
   relays and broken NIP-17 DMs.
2. **Follow-up — settings UX (`relay_settings_screen.dart:870`).** The
   form's prefix gate now accepts `https://` and `http://`, then
   `isRelayUrlAllowed` lets `https://anyhost` through. Submission hits
   `RelayManager._normalizeUrl`, which only accepts `wss://` or loopback
   `ws://`, returns null → `addRelay` returns `false` → user sees only
   the generic `relaySettingsFailedToAddRelay` message. The form's
   accepted-shape contract drifted from the manager's contract.

## Constraints

- Three packages mirror this rule: `mobile/lib`, `nostr_sdk`,
  `nostr_client`. The dartdoc on the canonical helper mandates that any
  change be reflected in the mirrors. Today the package mirrors are
  already WS-only — only the canonical version is broader.
- `code_style.md` "Reuse Before Writing" — avoid adding parallel
  predicates encoding the same rule.
- `localization.md` — error copy in `app_en.arb` / `app_es.arb` is
  locked. Reusing existing keys is preferred over adding new ones.
- PR is on a clean fix branch with self-review already addressed; the
  change for this review needs to stay scoped.

## Prior Art

- `mobile/lib/utils/relay_url_utils.dart:39` — canonical
  `isRelayUrlAllowed`. Currently accepts `wss://anyhost`,
  `https://anyhost`, `ws://<loopback>`, `http://<loopback>`.
- `mobile/packages/nostr_client/lib/src/relay_manager.dart:653` —
  `_normalizeUrl`, the de-facto canonical "is this a usable relay
  endpoint" rule. Already WS-only.
- `mobile/packages/nostr_sdk/lib/nip46/nostr_remote_signer_info.dart` —
  `parseBunkerUrl`. Already WS-only loopback gate.
- Caller inventory of `isRelayUrlAllowed`:
  - `relay_settings_screen.dart:882` — user input → wants relay-URL.
  - `relay_discovery_service.dart:382` and `:453` — NIP-65 → wants
    relay-URL.
  - `relay_capability_service.dart:153` — parameter is `relayWsUrl`;
    service does `replaceFirst('wss://', 'https://')`. Input is always
    WS form → wants relay-URL.
- `RelayCapabilityService.getRelayCapabilities` callers
  (`relay_settings_screen._fetchCapabilities` and
  `video_filter_builder.dart:136`) both pass relay URLs originating
  from `RelayManager.configuredRelays`. **No production caller passes
  an HTTP form to `isRelayUrlAllowed` today.**
- Self-review #158c705 already addressed the empty-host UX, the
  storage self-heal on next boot, and the loopback-set drift sentinels.
  This review's findings are independent of those.

## Approaches Explored

### Approach A — Tighten the canonical predicate to WS-only

**Description:** Drop the `https`/`http` branch from
`isRelayUrlAllowed`. The predicate's accepted shapes become
`wss://anyhost` or `ws://<loopback>` — semantically identical to
`RelayManager._normalizeUrl`. Update the dartdoc, fix call sites that
relied on the broader behavior (none in production, only the test
suite), and surface `https://`/`http://` settings input as
"malformed-URL" (existing key, reviewer's suggestion).

**Layers affected:** utils, screen UI, discovery service (no logic
change, only test additions), capability service (comment update),
tests.

**Pros:**
- Single source of truth stays single. Three predicates (canonical,
  manager normalize, package mirrors) collapse onto one rule.
- Removes a class of "URL passes the gate but won't actually work"
  bugs at the discovery + settings boundary.
- Smallest sustained API surface.
- Capability service's defense-in-depth strictly tightens.

**Cons:**
- Diverges from reviewer's stated framing (they read the predicate's
  breadth as intentional).
- Three test files need invert/add updates.

**Risks / Unknowns:**
- Low. No production caller passes an HTTP form; tightening only
  changes behavior for inputs that were already broken downstream.
- Naming: `isRelayUrlAllowed` becomes a strictly-relay-URL gate, which
  matches the function name better than it does today.

**Complexity:** Low. ~5-line predicate change, ~4-line settings-screen
prefix change, three test files updated, one capability-service
comment.

### Approach B — Split into two predicates (reviewer's literal suggestion)

**Description:** Keep `isRelayUrlAllowed` exactly as it is (transport-
allowed: wss any, https any, loopback ws, loopback http). Add a
stricter `isWebSocketRelayUrl` (wss any, loopback ws). Use the stricter
one in NIP-65 parsing, settings input, capability service.

**Layers affected:** utils (new public API), screen UI, discovery
service, capability service, tests.

**Pros:**
- Matches reviewer's mental model and review wording verbatim
  ("a stricter WebSocket-only predicate").
- Existing tests on the broader predicate stay green.
- Notionally future-proofs an HTTP-form input use case.

**Cons:**
- Adds an API with no current caller for the broader predicate (every
  site uses the stricter one). YAGNI smell.
- The package mirrors stay at one predicate; the canonical version
  grows a second — three files now encode adjacent rules.
- Naming risk: `isRelayUrlAllowed` becomes "allows things that aren't
  relays," which a future reviewer is likely to flag.

**Risks / Unknowns:**
- Low correctness risk; medium long-term clarity risk.

**Complexity:** Low–Medium. New public predicate + 3-4 call site
updates + new tests on two predicates.

### Approach C — Local helper at each call site

**Description:** Keep `isRelayUrlAllowed` exactly as is. In
`relay_discovery_service.dart`, add a private `_isWsRelayUrl(url)`. In
`relay_settings_screen.dart`, drop `https://`/`http://` from the
prefix gate.

**Layers affected:** screen UI, discovery service, tests.

**Pros:**
- Smallest possible diff. No mirrored-package implications. No public
  API surface change.

**Cons:**
- Duplicates predicate intent: a "WS-only" rule defined inline in
  `relay_discovery_service.dart` parallel to `_normalizeUrl`'s rule in
  `relay_manager.dart` and `isRelayUrlAllowed` in utils. Violates
  "Reuse Before Writing."
- Doesn't address the root cause: the canonical predicate still drifts
  from the de-facto contract enforced by `_normalizeUrl`.

**Risks / Unknowns:**
- High maintenance smell. The next reader is left wondering why
  discovery felt the need for a local override.

**Complexity:** Low for the patch, Medium for long-term cost.

## Recommendation

**Approach A.** The looseness in `isRelayUrlAllowed` was added on the
assumption that some site would pass HTTP form into it; the call graph
confirms no site does. Tightening the canonical predicate to match
`RelayManager._normalizeUrl`'s actual acceptance rule eliminates a
pre-existing semantic drift, removes a real downstream bug
(NIP-65 → fallback-suppression → broken DMs), and is the smallest
*sustained* API surface. The reviewer's literal framing prefers
Approach B, but the framing is based on the dartdoc, not the actual
call graph — addressing the drift is the more honest fix.

If the reviewer pushes back on A in the reply thread, **Approach B is
acceptable**; the code-correctness outcome is the same and only the
API shape differs. The reply should propose A as the primary direction
and offer B as a fallback.

**Reject Approach C** — it leaves three predicates encoding the same
rule across three files, all subtly different. That's the maintenance
shape `code_style.md` explicitly warns against.

## Open Questions for /plan

- [ ] Does the reviewer accept Approach A's framing in the reply
      thread, or do they want Approach B literally? Decide before
      committing.
- [ ] Should `RelayManager._normalizeUrl`'s loopback predicate also
      import the canonical helper, or stay duplicated per the existing
      dartdoc cross-reference comment? **Out of scope for this review
      fix** — flag as a follow-up.

## Prerequisites

None. This is a self-contained code + test change on the existing PR
branch.

## Next Step

Reply to both PR review threads stating the chosen direction
(Approach A), then implement directly. The change is small enough
that a separate `/plan` is overkill — this brainstorm captures the
rationale and concrete delta below.

### Concrete delta if Approach A

1. `mobile/lib/utils/relay_url_utils.dart`:
   - Lines 30-33: rewrite dartdoc to drop "or `https://`" / "or
     `http://`".
   - Line 43-44: collapse to `if (scheme == 'wss') return true;` and
     `if (scheme == 'ws') return isLoopbackHost(uri.host);`. Drop
     `https`/`http` branches.
2. `mobile/lib/screens/relay_settings_screen.dart`:
   - Lines 870-873: drop the two `!relayUrl.startsWith('https://')`
     and `!relayUrl.startsWith('http://')` clauses. Comment at
     866-869 simplifies — `relaySettingsInvalidUrl` now covers wrong
     scheme too.
3. `mobile/lib/services/relay_capability_service.dart`:
   - Lines 148-152: comment simplifies — predicate is a strict
     WS-form gate. Behavior unchanged for valid callers.
4. `mobile/lib/services/relay_discovery_service.dart`:
   - No code change. Comment at line 381 is already correct.
5. Tests:
   - `mobile/test/utils/relay_url_utils_test.dart`: invert assertions
     at lines 47-51; add explicit "rejects https://anyhost" and
     "rejects http://anyhost" cases.
   - `mobile/test/services/relay_discovery_service_test.dart`: add to
     the `parseRelayListFromJson (#3362 ...)` group: drop
     `https://relay.example.com`, drop `http://localhost:47777` (NIP-65
     should not advertise these as relays).
   - `mobile/test/services/relay_capability_service_test.dart`: add
     `refuses NIP-11 fetch when input is https://` and the http analog.
   - `mobile/test/screens/relay_settings_screen_layout_test.dart`: add
     `rejects https:// URL with invalid-URL snackbar` and the http
     analog. Assert `find.text(l10n.relaySettingsInvalidUrl)` and
     `verifyNever(addRelay)`.
6. Cross-package mirrors: **no change.** Already WS-only; tightening
   the canonical version brings the dartdoc cross-references into
   agreement.
