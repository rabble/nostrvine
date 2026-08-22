# Profile Pinning Evidence Audit

**Date:** 2026-08-23

**Status:** Complete; implementation remains paused pending four edge-case
decisions and a corrected implementation plan

## Why this audit exists

This audit separates four different kinds of statement that had been mixed
together in the design and implementation plan:

1. behavior already shipped by a Divine client;
2. behavior required or recommended by a Nostr NIP;
3. behavior verified in the current mobile and relay code;
4. new product or implementation choices that still require a decision.

The implementation plan dated 2026-08-23 must not be executed as written. It
contains protocol, pagination, resolution, fullscreen, accessibility, and CI
errors listed below.

## Sources checked

- [NIP-01](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md)
  at nostr-protocol/nips commit
  `656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab`.
- [NIP-51](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md)
  at the same commit.
- [NIP-71](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/71.md)
  at the same commit.
- `divine-mobile` `origin/main` at
  `c6b70eb57cba372e04e9bfc978618aa826b2f629`.
- `divine-web` `origin/main` at
  `bdc66278cd385df52a20576a28ee0ac05969e31a`.
- `divine-funnelcake` `origin/main` at
  `7350a0e020208c13cb179742f175f2bea6e42f71`.
- The shared `divine-context` checkout. It was on a non-default branch, so it
  was read but treated as potentially stale and was not modified.

## Established Divine behavior

Divine Web already implements profile video pins. Commit
[`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9)
(`feat: pinned videos on user profiles (#140)`, authored by Rabble on
2026-03-01) is the cross-client precedent:

- `divine-web/src/hooks/usePinnedVideos.ts` reads and writes kind `10001`.
- Video identities are kind-`34236` `a` coordinates.
- New pins are appended to the stored tag list.
- The web limit is three pins.
- The parser accepts values beginning with `34236:` regardless of whether the
  video author is the pin-list owner. It does not strictly validate the pubkey
  or `d` value.
- Other tags are retained during pin and unpin, but both mutations replace
  `content` with an empty string. That can erase private list items stored there.

Current Divine Web behavior includes one later improvement and two remaining
risks:

- Commit
  [`e74b6b04`](https://github.com/divinevideo/divine-web/commit/e74b6b042eb976600683ee830360cfa27592cfbb)
  added deterministic newest-event selection for each video coordinate.
- Kind-10001 reads still query with `limit: 1` and compare only timestamps, so
  they have the same equal-timestamp winner defect found in the mobile plan.
- The owned-profile unpin lookup keys by `d` value alone. Two authors using the
  same `d` value can select the wrong foreign-authored coordinate.

This makes kind `10001` plus kind-`34236` `a` tags an existing Divine
convention. It does not make that combination standard NIP-51 behavior.

The current Funnelcake code policy auto-allows the NIP-01 replaceable range
`10000..19999` and addressable range `30000..39999` unless a NIP-86
`disallowkind` record explicitly blocks the kind. That policy landed in commit
[`7dcb41c6`](https://github.com/divinevideo/divine-funnelcake/commit/7dcb41c6e5e3f112ff699901743fbe5291c7e647)
on 2026-07-29. An older Divine Web issue reporting that kind `10001` was
rejected by `relay.divine.video` predates this policy and is not a description
of the current relay code. Code policy alone does not prove the current
production `disallowed_kinds` state.

## Primary Nostr findings

### Kind 10001 is standardized for pinned notes, not addressable videos

NIP-51 names kind `10001` **Pinned notes** and expects `e` tags that reference
kind-1 notes. NIP-51's general list mechanism permits list items in tags, but it
does not standardize kind-`34236` `a` tags inside kind `10001`.

The Divine representation must therefore be described as an existing Divine
extension to the kind-10001 list, with the interoperability consequence that a
generic NIP-51 client may ignore the video `a` tags.

### Addressable video coordinates are the correct stable reference

NIP-01 defines an `a` reference as `kind:pubkey:d-tag`. NIP-71 defines kind
`34236` as addressable short-form video. The coordinate remains stable across a
replacement only while the author pubkey and `d` value remain unchanged.

The codec must require an exact 64-character lowercase hexadecimal pubkey.
Mobile must also require a nonempty `d` value because the current
`VideoEvent.addressableId` and `getVideosByAddressableIds` paths reject an empty
value; that is a current-mobile compatibility rule rather than explicit NIP-71
normative language. `AId.fromString` rejoins colons in a `d` value but does not
enforce these validity rules.

### NIP-51 recommends chronological storage order

NIP-51 says clients SHOULD append new list items so the stored order remains
chronological. The approved mobile design instead prepends and displays newest
pin first. That is a deliberate SHOULD-level interoperability deviation, not a
claim about standard NIP-51 behavior. Divine Web currently appends. Both clients
preserve stored tag order, but render different subsets; among coordinates both
display, order follows the stored sequence. A pin action inserts at opposite
ends. A Web-written or mixed-client list has no per-item timestamps, so mobile
cannot reconstruct a globally newest-first chronology.

### Replaceable winners need a complete comparator

For equal `created_at` values, NIP-01 says the event with the lexicographically
lowest event ID should be retained. The current mobile Nostr client reapplies
`limit: 1` after sorting only by timestamp. A kind-10001 query with `limit: 1`
can therefore discard the expected winner before a repository applies the ID
tie-break.

With the current client, the pin repository must query without `limit: 1` and
select by:

```text
created_at descending, then event ID ascending
```

Alternatively, `_mergeEvents` must first be corrected to apply the same
tie-break before limiting. The comparator must also guard live subscription
updates.

## Current mobile findings

### Verified foundations

- `ProfileFeedCubit` owns the canonical newest-first base sequence in
  `_unfilteredVideos` (`mobile/lib/blocs/profile_feed/profile_feed_cubit.dart:125-132`).
- `VideoEvent.addressableId` produces the full kind-`34236` coordinate.
- `VideoEvent.stableId` is not a global pin identity because it omits the
  author when a `vineId` exists
  (`mobile/packages/models/lib/src/video_event.dart:1085-1088,1359-1375`).
- `VideosRepository.getVideosByAddressableIds` batches 20 coordinates, so 12
  unique pins fit in one relay batch. Funnelcake fallback and hydration can
  still cause additional requests
  (`mobile/packages/videos_repository/lib/src/videos_repository.dart:1469-1582`).
- The current grid prefixes owner-only upload placeholders ahead of published
  videos (`mobile/lib/widgets/profile/profile_videos_grid.dart:277-349`).
- The current fullscreen catch-up merge sorts newest-first and therefore
  destroys a pinned launch order
  (`mobile/lib/widgets/profile/profile_video_feed_view.dart:113-153`).

### Correctness defects in the implementation plan

An interrupted, uncommitted Task 1 slice is present in the worktree. Its pure
orderer re-filters the authoritative base feed and lets one input overwrite the
other without coordinate-level version reconciliation; its tests encode those
defects. It must be corrected rather than committed as-is.

1. **Pagination uses the wrong sequence.** The plan would add off-page pins to
   `state.videos`, but existing backfill counts and the Nostr fallback cursor
   use that rendered list. An old pin can move the cursor backwards and skip
   ordinary profile pages. The Nostr `until` cursor must use
   `_unfilteredVideos`; initial backfill progress must use the normally filtered
   base feed, such as `_applyFeedFilters(_unfilteredVideos).length`. Neither may
   use pin-augmented `state.videos`
   (`profile_feed_cubit.dart:404-460,510-516,727-744`).
2. **The pure ordering function drops valid base-feed entries.** The proposed
   function filters every base-feed video by owner and visibility. The approved
   ordering rule says to validate resolved pins and then append the existing
   authoritative base sequence unchanged, minus exact duplicates.
3. **Overlapping copies are not reconciled.** When both inputs contain one
   coordinate, neither the feed nor separately resolved copy should win by input
   position. Different event IDs require NIP-01 winner selection by
   `nostrCreatedAt` descending then event ID ascending. Same-event enrichment
   precedence and merging are implementation policy that the corrected plan
   must state and test explicitly. Preserve the authoritative base sequence
   position.
4. **Video replacement resolution is nondeterministic.** Mobile's
   `getVideosByAddressableIds` currently lets arrival order choose between
   multiple versions of one coordinate. It must select the raw NIP-01 winner by
   timestamp/ID before parsing and visibility filtering; otherwise an older
   playable version can incorrectly replace a newer filtered version
   (`videos_repository.dart:1529-1558`).
5. **`restartable()` is not enough.** Cancelling a Bloc handler does not cancel
   its underlying resolver future. A generation guard or `emit.isDone` check
   is required before a stale result mutates pin state.
6. **Fullscreen takeover is under-specified.** Seeing the tapped coordinate in
   a live page does not prove the live sequence has reconciled the displayed
   launch sequence. Switching at that point can drop or reorder seed videos.
7. **Exact identity is not threaded end to end.** The plan omits
   `FullscreenFeedBloc` and its tests from the new addressable-coordinate path.
8. **Publish language overclaims certainty.** A fully settled query covers the
   configured relay fan-out, not every relay. `OK true` means accepted for
   writing, not durable. A lost `OK` can leave the remote outcome unknown.
   Failed mutations may keep local visible order unchanged; they cannot
   guarantee the previous order is still live everywhere.
9. **Accessibility contradicts repository policy.** The plan says to rely on a
   snackbar alone. `.claude/rules/accessibility.md` requires
   `SemanticsService.sendAnnouncement` for snackbars and asynchronous visible
   changes.
10. **The new package list is incomplete.** A new repository package also
    requires `analysis_options.yaml`, a package CI workflow, a measured package
    coverage-floor entry, and the package CI/coverage floor checks.
11. **The analyzer command is invalid.** The supported command is
    `cd mobile && flutter analyze`, without positional directories.
12. **Mutation serialization is only process-local.** A future chain can order
    one app process, but two devices or Web and mobile can read the same base and
    publish competing replacements. New events normally need
    `max(now, selectedBase.createdAt + 1,
    lastLocallyIssuedOrAcceptedCreatedAt + 1)` for same-process ordering, because
    the next configured-relay read may not return the process's last accepted
    write. The repository must fail or defer safely if that timestamp exceeds
    the relay's accepted future-skew boundary. Cross-device writes still follow
    NIP-01 replaceable-winner behavior.
13. **Filter changes cannot restore a pin omitted during resolution.** The
    current addressable resolver filters block, deletion, transport, expiry,
    and content policy before returning. The existing filter-change handler
    re-filters without refetching. The corrected design must either re-resolve
    missing coordinates when filter policy changes or retain canonical raw
    winners below the Cubit visibility layer.
14. **A nonnull `addressableId` does not prove kind 34236.** The model getter
    hardcodes `34236` for any nonempty addressable `d` value. Pin eligibility
    must also require the source `eventKind` to be the addressable short-video
    kind; a nonnull coordinate alone is insufficient.

## Approved mobile decisions and known divergence

The user-approved mobile spec remains authoritative for product behavior:

- mobile prepends new pins and displays newest pin first;
- mobile caps creator-managed pins at 12;
- mobile manages and displays only owner-authored video coordinates;
- foreign and otherwise unrelated tags remain preserved as unrelated data.

The evidence audit does not revoke those choices. It records their consequences:
Divine Web currently appends, limits adding at three, and displays
foreign-authored coordinates. Web will read more than three but refuses another
addition whenever the list already contains at least three video tags. Any Web
convergence is separate cross-repo work, not a hidden prerequisite of this
mobile task.

## Product decisions still required

### 1. Web-written or mixed-client order

Both clients preserve stored tag order for the coordinate subset they display,
but mobile prepends while Web appends. Without per-item timestamps, mobile
cannot infer a global pin chronology for an existing Web-written or mixed-client
sequence. Decide whether to treat stored order as authoritative while
guaranteeing only that a mobile pin moves to the front, or choose a cross-client
migration/protocol rule.

### 2. Cap counting and imported lists over 12

The original plan invented a first-12 display and mutation policy. Open Nostr
data can exceed a local creator cap, so the reader still needs explicit
display, preserve, unpin, and add behavior for imported lists over 12. The same
decision must say whether valid but unresolved or hidden references count
toward the creator cap.

### 3. Pin action while the first snapshot loads

The approved spec disables Pin at the cap but does not choose hide, disable, or
explanatory feedback before the first cache/relay snapshot establishes current
membership and count.

### 4. Legacy or non-addressable video action

The storage model requires an addressable coordinate, but the approved spec does
not choose whether the owner sheet hides Pin, disables it, or explains why it
is unavailable for a legacy/non-addressable video. Eligibility must use the
source event kind plus a nonempty `d` value, not `addressableId != null` alone.

## Implementation choices, not product facts

The following may be reasonable, but they must be justified as implementation
choices rather than described as user-approved behavior:

- SharedPreferences as the cache backend;
- caching the complete selected raw event;
- inserting rewritten managed tags at the first managed-tag slot;
- preserving extra fields on surviving managed tags;
- serializing mutations per owner;
- the exact cache backend, schema, expiry, and corruption behavior;
- the exact mutation result enums and retry state shape;
- exact semantics wording and whether it includes overall position, pin rank,
  or total pin count.

The Phosphor `PushPin` glyph has a current Divine Web precedent. Reusing it in
mobile is a cross-client design-system proposal, not a Nostr requirement.

## Evidence matrix

| Claim | Evidence | Verdict | Required treatment |
|---|---|---|---|
| Kind `10001` standardizes pinned kind-1 notes with `e` tags | [NIP-51 lines 19-29](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L19-L29) | Verified NIP fact | Describe video `a` tags as a Divine extension. |
| NIP-51 recommends append order | [NIP-51 lines 9-13](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L9-L13) | Verified SHOULD-level recommendation | Keep approved mobile prepend, but document the deviation. |
| Kind `34236` is addressable short video | [NIP-71 lines 23-32](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/71.md#L23-L32) | Verified NIP fact | Use full `a` coordinates; qualify stability by unchanged author and `d`. |
| Equal-timestamp replaceable winner uses lower event ID | [NIP-01 lines 97-103](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L97-L103) | Verified SHOULD-level rule | Fix limiting/selection in reads and subscriptions. |
| Divine already uses kind `10001` plus video `a` tags | Divine Web commit [`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9) | Verified Divine precedent | Cite it; do not call it standard NIP-51. |
| Current relay code accepts replaceable-range kinds automatically | Funnelcake commit [`7dcb41c6`](https://github.com/divinevideo/divine-funnelcake/commit/7dcb41c6e5e3f112ff699901743fbe5291c7e647), `crates/relay/src/relay.rs:2159-2208` | Verified code policy, not production state | Qualify explicit disallow override. |
| `limit: 1` can hide the expected tie winner | `mobile/packages/nostr_client/lib/src/nostr_client.dart:1865-1912` | Verified current defect | Query without the limit or fix the client comparator first. |
| Pin display ordering can corrupt pagination boundaries | `mobile/lib/blocs/profile_feed/profile_feed_cubit.dart:404-460,510-516` | Verified current integration risk | Use raw base feed for cursors and normally filtered base feed for visible backfill counts; never use pin-augmented state. |
| Addressable resolution is arrival-order dependent | `mobile/packages/videos_repository/lib/src/videos_repository.dart:1529-1558` | Verified current defect | Select the raw winner before parsing/filtering. |
| Snackbar-only announcement violates repo policy | `.claude/rules/accessibility.md:83-111` | Verified policy conflict | Use `SemanticsService.sendAnnouncement` and test it. |
| `e` identifies an event and `a` identifies an addressable coordinate | [NIP-01 lines 78-82](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L78-L82) | Verified NIP fact | Store full kind/pubkey/`d` coordinates for replaceable videos. |
| NIP-51 public items live in tags and private items may live in encrypted `content` | [NIP-51 lines 9-13](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L9-L13) | Verified NIP fact | Preserve selected-base unrelated tags and `content` byte-for-byte. |
| `OK true` means accepted by that relay, not durable everywhere | [NIP-01 lines 156-168](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L156-L168), `mobile/packages/nostr_client/lib/src/nostr_client.dart:742-761` | Verified protocol/client fact | Gate local progress on `acceptedByAny`; never tell the user it is durably saved. |
| Full settlement covers the configured query fan-out, not every relay | `mobile/packages/nostr_client/lib/src/nostr_client.dart:847-872` | Verified current client scope | Say “fully settled configured-relay read,” not “authoritative global read.” |
| Same-second replacement writes need monotonic time, subject to relay future-skew rejection | [NIP-01 lines 97-103](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L97-L103), `mobile/lib/utils/nostr_replacement_timestamp.dart:7-16`, current Funnelcake `crates/relay/src/relay.rs:1989` | Verified integration constraint | Floor against the selected base and the process-local last issued/accepted time; otherwise fail/defer safely. |
| Web pin mutations erase opaque `content` | Divine Web `src/hooks/usePinnedVideos.ts:101-108,143-152` at pinned `origin/main` | Verified current Web defect | Do not copy this behavior into mobile; track Web correction separately. |
| Web kind-10001 reads limit before applying the ID tie-break | Divine Web `src/hooks/usePinnedVideos.ts:41-51,73-84,131-141` at pinned `origin/main` | Verified current Web defect | Record cross-client divergence; Web correction is separate scope. |
| Filter changes do not re-resolve omitted pins | `mobile/lib/blocs/profile_feed/profile_feed_cubit.dart:671-678`, `mobile/packages/videos_repository/lib/src/videos_repository.dart:1688-1730` | Verified current integration risk | Re-resolve on filter-policy changes or retain canonical raw winners below visibility filtering. |
| `addressableId` alone does not prove source kind 34236 | `mobile/packages/models/lib/src/video_event.dart:528-531,812,1359-1368` | Verified model limitation | Check `eventKind` and nonempty `d` for pin eligibility. |
