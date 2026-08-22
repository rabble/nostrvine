# Pinned Videos on Divine Profiles

**Date:** 2026-08-23

**Status:** Research complete; recommended mobile design

## Executive Summary

Divine should let creators pin up to 12 of their videos to the beginning of
their mobile profile grid. A newly pinned video moves to the front. Within
Mobile, the grid and fullscreen player use the same resolved sequence. For a
given selected list event, Mobile preserves stored managed order among visible
candidates, but cross-relay and cross-client convergence is not guaranteed.

This is not a new Divine concept. Divine Web already shipped profile video pins
in commit
[`0058e2f5`](https://github.com/divinevideo/divine-web/commit/0058e2f51091501e0cf04fe3018f05fff0460eb9).
The mobile design should reuse that established event shape: a kind-`10001`
replaceable event containing kind-`34236` video `a` coordinates.

That event shape is a Divine convention, not standard NIP-51 semantics.
NIP-51 defines kind `10001` as a list of pinned kind-1 notes using `e` tags.
The distinction matters because other Nostr clients may ignore Divine's video
references, and Divine must preserve list data it does not manage.

The recommendation is deliberately small: one grid, one Pin/Unpin action, no
arranger screen, no separate pinned section, and no manual drag ordering.

The detailed evidence and engineering risk register are in the
[evidence appendix](2026-08-23-profile-pinning-order-evidence-audit.md).

## What Exists Today

### Divine Mobile

- The Videos tab is a three-column grid backed by `ProfileFeedCubit`.
- Published videos retain the profile feed's normal newest-first order.
- In-progress uploads appear first on the owner's profile.
- Tapping a tile opens the fullscreen profile feed.
- Long-pressing an owned tile opens the existing Edit/Delete action sheet.
- Mobile does not currently read, display, or publish profile video pins.

### Divine Web

Divine Web already:

- reads and writes kind `10001`;
- stores videos as kind-`34236` `a` coordinates;
- preserves unrelated public tags;
- displays pinned videos on profiles;
- exposes Pin and Unpin actions.

Web currently limits additions to three, appends new tags, and accepts
foreign-authored video coordinates. Mobile's recommended behavior differs:
12 creator-owned pins, with a new mobile pin inserted at the front. These
differences are documented rather than mistaken for Nostr requirements.

## Recommended Mobile Experience

### Viewer

Render one grid in this order:

```text
owner-only in-progress uploads
+ visible pinned videos in stored managed order
+ every remaining profile video in normal feed order
```

Pinned tiles show a small pin badge. There is no heading, separate section, or
layout break. The badge is not the only signal: accessibility semantics also
announce that the video is pinned and its position.

The fullscreen sequence must exactly match the published-video sequence shown
by the grid. Tapping any tile opens that tile at the corresponding index, and
pagination continues without re-sorting or dropping the pinned launch order.

### Creator

The existing long-press action sheet gains one action:

- `Pin to profile` for an eligible unpinned video;
- `Unpin from profile` for a pinned video.

Pin inserts the video's coordinate at the front of Divine Mobile's managed
sequence. Unpin removes every managed tag for that exact coordinate without
reordering the remaining entries; this prevents a duplicate stored tag from
making the video appear pinned again immediately.

Success and failure use localized snackbars and explicit screen-reader
announcements. A failed or unconfirmed publish leaves the local visible order
unchanged and offers retry.

### Eligibility

Mobile offers Pin only when all of these are true:

- the viewer owns the profile;
- the video is authored by that profile;
- the source event is kind `34236`;
- it has a nonempty addressable `d` value.

Legacy or non-addressable videos simply omit the Pin action. Mobile preserves
foreign-authored and malformed list data as unrelated data but does not display
or manage it.

### Loading

While the initial cached/relay snapshot is unresolved, show the Pin action as
disabled rather than guessing whether the video is already pinned or whether
the profile is at the cap. Unpin may be shown only when current cached state
already proves membership.

## Ordering and Cap Rules

Let `P` be the valid, owner-authored video coordinates in stored tag order and
`V` be the already-filtered profile video sequence.

1. De-duplicate `P`; first occurrence wins.
2. The first 12 coordinates in `P` are display candidates.
3. Resolve those candidates to canonical kind-`34236` events.
4. Omit candidates that are unavailable, deleted, blocked, expired, unplayable,
   or no longer authored by the owner.
5. Emit the visible candidates in `P` order.
6. Append every item from `V` not already emitted, preserving `V` order.
7. Keep transient uploads outside this published-video sequence and prefix them
   only in the owner's grid.

The cap counts every unique valid owner-authored coordinate in the stored list,
including references that are currently unavailable or hidden. This prevents a
temporarily invisible pin from allowing the stored list to grow without bound
and then reappear above the cap later.

For an imported list containing more than 12 managed coordinates:

- display from the first 12 candidates in stored order;
- preserve every stored tag and the opaque `content` value;
- allow Unpin for any coordinate whose video is available to the owner;
- reject new Pin actions until the managed count is below 12;
- never truncate the list as a side effect of an unrelated save.

These rules distinguish stored membership from an active displayed pin. A
coordinate anywhere in `P` is a stored member and therefore counts toward the
cap and offers Unpin to the owner. Only a visible video resolved from the first
12 candidates is an active displayed pin: it moves to the front and receives
the pin badge, pin-rank semantics, and pinned position. A stored overflow video
that also appears through `V` stays in its ordinary feed position without the
badge or pinned semantics, while still offering Unpin to remove the preserved
overflow entry.

Stored order is authoritative because list items have no individual pin
timestamps. A mobile Pin reliably moves that video to the front, but Mobile
cannot reconstruct a globally newest-first history for a list previously
written by Web or by multiple clients using different insertion rules.

## Nostr Representation

### Existing Divine convention

Use one current kind-`10001` replaceable event for each owner and store managed
videos as:

```text
["a", "34236:<author-pubkey>:<d-tag>"]
```

The full addressable coordinate survives a metadata replacement as long as the
author and `d` value remain unchanged. Event IDs and `stableId` are not suitable
stored identities for this feature.

### Standards boundary

[NIP-51](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md)
names kind `10001` **Pinned notes** and expects kind-1 `e` references. Divine's
kind-`34236` `a` tags are an extension already used by Divine Web.

[NIP-51](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/51.md#L9-L13)
also recommends appending new list items chronologically. Mobile deliberately
inserts a new pin at the front to implement the product behavior above. This is
a SHOULD-level interoperability deviation and must be documented as such.

[NIP-01](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/01.md#L78-L82)
defines `a` coordinates, while
[NIP-71](https://github.com/nostr-protocol/nips/blob/656cecc7c0a815b6a2b218d3b5d6f078b3f4dbab/71.md#L23-L32)
defines kind `34236` addressable short video.

### Lossless read-modify-write

Before Pin or Unpin, Mobile must read the current selected base event and:

- manage only valid kind-`34236` coordinates authored by the event owner;
- treat every exact duplicate of a managed coordinate as managed mutation data,
  removing all copies on Unpin while first occurrence wins for display;
- preserve every unrelated public tag exactly, including order and extra
  fields;
- preserve `content` byte-for-byte because it may contain encrypted private
  list items;
- publish a replacement only after a fully settled configured-relay read;
- update local visible state only after at least one relay returns `OK true`.

This does not make the read globally authoritative. A silent, unrelated, or
unqueried relay may hold a divergent event. `OK true` means a relay accepted the
write; it does not prove durable storage everywhere.

## Technical Design

```text
Profile UI
    ↓
ProfileFeedCubit
    ↓
ProfilePinsRepository + VideosRepository
    ↓
Nostr client and local cache
```

`ProfilePinsRepository` owns list parsing, cached snapshots, relay
revalidation/subscription, signing, lossless mutation, and publication. UI code
never constructs Nostr tags.

`ProfileFeedCubit` combines pin coordinates with the existing profile feed and
exposes one displayed sequence, pin membership, loading state, and mutation
outcomes. Every emit path and sequence comparison must use one centralized
base-to-displayed derivation; otherwise a cache, relay, enrichment, pagination,
or filter update can silently replace the pinned sequence with the base feed.

Keep the raw base feed, normally filtered base feed, and pin-augmented displayed
sequence separate. Pagination counts use the normally filtered base feed. The
Nostr `until` cursor uses the minimum `nostrCreatedAt` in `_unfilteredVideos`,
not `createdAt` and not the pin-augmented displayed sequence.

The published sequence actually rendered by the grid is authoritative for tap
index, prefetch, and the fullscreen seed. The tap handler must not substitute a
different Cubit list after grid-level upload/relay de-duplication. Thread the
exact addressable coordinate through the fullscreen route and BLoC.

Canonical replaceable-event selection must use `created_at` descending and
event ID ascending for ties. The current addressable-video resolver must select
the raw canonical winner before applying visibility filters; arrival order is
not a valid winner rule. Track raw-resolved coordinates separately from visible
results so a canonical-but-hidden event is not misclassified as missing and
reintroduced from Funnelcake fallback. Equivalently, canonicalize candidates
across sources before applying visibility exactly once.

The exact cache backend, package boundary, and same-event enrichment merge are
engineering choices, not product facts. They should follow the repository's
existing UI → BLoC → Repository → Client architecture and CI package rules.

## Failure and Concurrency

- Cached pins may render immediately and then revalidate.
- Missing payloads do not delete stored references.
- A stale asynchronous resolution result must not overwrite a newer snapshot.
- Filter-policy changes must re-resolve omitted pins or retain canonical raw
  winners below the visibility layer.
- A local mutation queue serializes one process but cannot prevent two devices
  from publishing competing replacements.
- Same-process replacement timestamps must advance beyond both the selected
  base and the last locally issued/accepted timestamp, without exceeding relay
  future-skew policy.
- Partial relay acceptance remains partial; Mobile does not claim durability or
  automatic repair across rejecting relays.

## Accessibility and Localization

- Add an approved pin SVG to Mobile's icon assets, expose it through a new
  `DivineIconName` mapping, and cover the mapping with the design-system icon
  test. Divine Web's Phosphor `PushPin` is the cross-client visual precedent;
  Mobile does not currently have a pin glyph or a Phosphor dependency.
- Exclude the decorative badge icon from duplicate semantics.
- Announce pinned state and position with one complete localized label.
- Announce Pin/Unpin success and failure with
  `SemanticsService.sendAnnouncement` in addition to the snackbar.
- Use full localization messages, including cap and retry text; do not assemble
  translated fragments.

## Acceptance Tests

The report recommends coverage for:

- stored pin order and first-occurrence de-duplication;
- first-12 display, imported oversize preservation, and the distinct overflow
  membership/action/badge behavior;
- owner-only eligibility and foreign-tag preservation;
- metadata replacement retaining a pin by coordinate;
- equal-timestamp replaceable-event tie handling;
- canonical raw winner selection before filtering;
- cache-first rendering followed by relay revalidation;
- stale resolution and subscription races;
- every Cubit update path retaining the centralized pin overlay;
- base-feed pagination unaffected by off-page pins and using the oldest raw
  `nostrCreatedAt` cursor;
- grid, prefetch, and fullscreen using the identical sequence;
- canonical-but-hidden coordinates not being reintroduced by fallback;
- failed/unconfirmed publish leaving local order unchanged with retry;
- loading, cap, and legacy-video action states;
- pin badge, semantics, announcements, and localized copy.

## Cross-Client Follow-Up

Mobile can ship this design without silently changing Divine Web, but the
report records existing Web differences and defects:

- Web caps additions at three while Mobile recommends 12.
- Web appends new pins while Mobile prepends.
- Web displays foreign-authored coordinates while Mobile omits them.
- Web Pin/Unpin currently replaces opaque `content` with an empty string.
- Web kind-10001 reads use `limit: 1` without the NIP-01 event-ID tie-break.

Those are separate cross-repo corrections. They should not be hidden inside a
Mobile change, but they matter if Divine wants identical behavior on every
client.

## Out of Scope

- Manual drag ordering or an arranger screen.
- A separate pinned section or section heading.
- Pinning another account's videos from Mobile.
- Reordering unpinned profile videos.
- Multiple named pin sets.
- Changing video metadata or deletion behavior.
- Implementing the Divine Web follow-up described above.
