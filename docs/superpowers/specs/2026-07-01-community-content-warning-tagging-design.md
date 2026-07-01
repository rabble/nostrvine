# Community-driven content-warning tagging (mobile slice)

Issue: divinevideo/divine-mobile#4771 — part of epic #5177.
Status: design approved (decisions confirmed with Matt 2026-07-01).

## Problem

Creators sometimes fail to label sensitive content (e.g. "Gambling").
We want viewers to be able to suggest and effectively vote on
content-warning tags for a video, and — once enough independent people
agree — surface a content warning for that video to everyone, without
waiting on the creator.

The issue as filed describes an end-to-end system: viewer suggestions,
threshold-based **auto-application** of the tag to the video, and
**moderation strikes / account blocking** for creators who repeatedly
mislabel. Two of those three pieces (authoritative aggregation +
auto-apply, and strikes/blocking) can only be done by an authoritative
server-side actor — a mobile client cannot rewrite another user's
kind 34236 event, and client-side "auto-apply" would be unauthenticated
and trivially forged.

## Scope

**In scope (this PR — the mobile-ownable slice):**

1. A distinct "Help classify this" affordance letting a viewer suggest
   one or more content-warning labels for a video.
2. Publishing that suggestion as a NIP-32 kind 1985 label event
   targeting the video (`content-warning` namespace).
3. Reading **all-author** kind 1985 content-warning labels for a video,
   counting distinct **Divine-identity** authors per label, and
   surfacing labels that cross a display threshold.
4. Folding community-crossed-threshold labels into the existing
   `ContentWarning` overlay, tagged as community-sourced.

**Out of scope (separate backend issue, to be filed under #5177 and
assigned to @mbradley):**

- Authoritative server-side vote aggregation.
- Auto-applying the tag to the video event.
- Moderation strikes / warnings / account blocking for repeat
  mislabeling.

The client-side display threshold is intentionally a **local, advisory
signal** that degrades gracefully: when the backend later does
authoritative aggregation with stronger identity/anti-abuse signals,
the client can defer to it.

## Key decisions (confirmed)

- **Who counts as "community":** distinct pubkeys that resolve to a
  **Divine NIP-05 identity** via the public, no-auth, CORS-enabled
  name-server endpoint `GET https://api.divine.video/by-pubkey/<hex>`
  (`found: true`). This is the only authoritative, client-checkable
  "real Divine user" signal — keycast membership is not publicly
  queryable, the NIP-89 client tag is spoofable, and the relay does not
  gate writes by membership. Anyone can still *publish* a kind 1985
  label (the relay is open); we only control which authors we *count*.
- **Threshold:** a video shows a community content warning for a label
  once **>= 3 distinct Divine-identity authors** have suggested that
  label. Named constant `CommunityContentWarningConstants.displayThreshold`.
- **Display:** community-crossed-threshold labels feed the existing
  `ContentWarning` blur overlay + "View Anyway" flow, but carry a
  `community` provenance so the UI can label them honestly as
  community-suggested (vs creator self-label / trusted labeler).
- **Entry point:** a distinct "Help classify this" action, separate
  from the existing Report action.

## Architecture (UI -> BLoC -> Repository -> Client)

### Client / data layer

- **Divine identity check.** Extend `ProfileRepository` (already the
  name-server client, hosts `claimUsername`) with
  `Future<bool> hasDivineIdentity(String pubkey)` backed by
  `GET /by-pubkey/<hex>`. Results are cached with the **same 24h TTL**
  the existing moderation NIP-05 resolution uses
  (`ModerationLabelService._resolvedPubkeyTtl = Duration(hours: 24)`) —
  reuse that constant / value rather than inventing a new window, so the
  app has one consistent "how long a NIP-05-derived identity
  determination is trusted" threshold. Prefer the existing NIP-05
  verification infra (`nip05_verification_service.dart`) over a bespoke
  path where it fits.

  **Alignment with #4948 (moderation-pubkey trust model, still open).**
  That issue flags that Divine's NIP-05 resolution is an *unpinned*
  HTTPS GET of our own `nostr.json`, so a DNS/TLS/endpoint compromise of
  our own domain could redirect NIP-05-derived trust for up to the 24h
  window. Our `by-pubkey` check rides the same surface, but at **lower
  stakes**: a compromise here inflates community vote counts and could
  trigger **false-positive content warnings** (mitigated by "View
  Anyway" and the advisory nature of the client threshold), not the
  redirection of report DMs that #4948 is concerned with. This feature
  therefore proceeds on NIP-05 `by-pubkey` without preempting #4948 —
  but by routing through shared NIP-05 infra and the shared 24h TTL,
  whatever trust posture #4948 lands on (mismatch logging, pinning,
  etc.) applies uniformly here without a second migration.
- **Kind 1985 querying.** Reuse `NostrClient.queryEvents` with
  `Filter(kinds: [1985], e: [videoId])` and
  `Filter(kinds: [1985], a: [addressableId])` to fetch all-author
  content-warning labels for a video. (Existing `moderation_label_service`
  only filters by *author*; community aggregation filters by *target*.)
- **Publishing.** Reuse `NostrClient` event publishing to emit the
  kind 1985 suggestion.

### Repository layer

New `CommunityContentLabelRepository` (pure Dart, in
`mobile/lib/...` or a package if reuse emerges — start in `lib`):

- `Future<Set<String>> communityLabelsForVideo(VideoEvent video)` —
  queries kind 1985 events targeting the video, parses
  `['L','content-warning']` + `['l', <label>, 'content-warning']`,
  groups by normalized label value, counts **distinct author pubkeys
  that pass `hasDivineIdentity`**, and returns the set of labels whose
  distinct-Divine-author count `>= displayThreshold`.
- `Future<void> suggestLabels({required VideoEvent video, required Set<ContentLabel> labels})`
  — publishes a kind 1985 event with tags:
  `["L","content-warning"]`, one `["l", value, "content-warning"]` per
  label, `["e", video.id, <relayHint>]`, `["a", video.addressableId]`
  (when addressable), `["p", video.pubkey]`.
- `Future<Set<String>> myExistingSuggestions(VideoEvent video, String myPubkey)`
  — labels the current user already suggested, so the UI can show an
  "already suggested" state (NIP-32 has no un-vote; suggestions are
  additive within a session).

Fallback/aggregation/dedup logic lives **here**, never in the BLoC/UI.
Owns the error contract per `error_handling.md` (typed exceptions /
documented sentinels; reporter-port for Crashlytics if it lands in a
pure-Dart package).

### Business logic layer

- `CommunitySuggestCubit` (screen-scoped) drives the "Help classify"
  flow: holds selected labels, a `status` enum
  (`initial | submitting | success | failure`), and the
  already-suggested set. No error strings in state; uses `addError`.
- Community-derived labels for **display** are surfaced by extending
  `resolveEffectiveContentLabels` to accept community labels and tag
  their provenance. Aggregation is async (network), so the caller
  (feed item's existing content-warning resolution path) fetches the
  community set via the repository and passes it in — the resolver
  stays synchronous and pure.

### Presentation layer

- **"Help classify this"** entry point: a distinct action (icon +
  label) in the video overflow/actions area, opening a full-screen or
  bottom-sheet label selector reusing the creator
  `content_warning_selector` multi-select pattern (dark-mode,
  `VineTheme`, `DivineIcon`, l10n copy). Wrapped in `Semantics`.
- **Display:** the existing `ContentWarning` / `VideoContentWarning`
  widgets render the merged label set. Add a provenance line/chip
  ("Suggested by the community") when the surfaced label is
  community-sourced.

## Data flow

```
Viewer taps "Help classify this"
  -> CommunitySuggestCubit (selected labels)
  -> CommunityContentLabelRepository.suggestLabels(...)
  -> NostrClient publishes kind 1985 (content-warning namespace)

Feed renders a video
  -> CommunityContentLabelRepository.communityLabelsForVideo(video)
       - queryEvents kind 1985 by #e / #a
       - group by label, count distinct authors where hasDivineIdentity
       - keep labels with count >= displayThreshold
  -> resolveEffectiveContentLabels(video, community: <set>, ...)
  -> ContentWarning overlay (blur + View Anyway), tagged community
```

## Error handling

- Identity/label network failures are **expected** (flaky network) and
  are NOT reportable to Crashlytics (per the decision matrix in
  `error_handling.md`). A failed community-label fetch resolves to "no
  community labels" (video shows without the community warning) rather
  than surfacing an error — graceful degradation; the authoritative
  creator/trusted-labeler warnings are unaffected.
- Suggestion publish failure surfaces via the cubit `failure` status ->
  UI snackbar (l10n), with `addError` for logging (not Crashlytics
  unless it's a programming invariant).

## Testing

- `CommunityContentLabelRepository`: unit tests for aggregation
  (distinct-author counting, threshold boundary at 2 vs 3, non-Divine
  authors excluded, duplicate author counted once, label
  normalization), publish tag construction, and network-failure
  degradation. Mock `NostrClient` + `ProfileRepository`.
- `hasDivineIdentity`: found / not-found / network-error / cache-hit.
- `CommunitySuggestCubit`: `blocTest` per event — select, submit
  success, submit failure (asserts `addError`), already-suggested.
- Widget tests: selector renders labels, submit dispatches, disabled
  state when nothing selected; `ContentWarning` shows the community
  provenance chip when community-sourced. l10n delegates on all pumped
  `MaterialApp`s.
- Goldens for the selector + the community-tagged warning where the
  existing suite has goldens for these widgets.

## Anti-abuse notes (documented limits of the mobile slice)

- Divine-identity gating raises the cost of brigading (need 3+ real
  Divine identities) but is not a full anti-abuse system — a determined
  actor with multiple Divine identities can still push a label past the
  client threshold. This is acceptable for an **advisory** client-side
  warning and is explicitly the backend issue's job to harden
  (reputation, rate limits, moderator confirmation).
- The client cannot remove/authoritatively-clear a community label;
  false positives are mitigated by "View Anyway" and by the backend
  eventually owning authoritative state.

## Follow-up (backend issue to file)

Draft issue for the relay/moderation stack:
authoritative kind 1985 aggregation, threshold auto-apply of the tag,
and creator strike/blocking accounting — with stronger identity and
anti-abuse signals than the client can enforce. Assign to @mbradley,
link under epic #5177, and cross-reference #4771.
