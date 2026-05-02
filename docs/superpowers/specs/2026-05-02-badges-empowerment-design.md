Status: Approved

# Badge Empowerment Surface

**Date:** 2026-05-02
**Status:** Approved
**Repo:** divine-mobile

## Problem

Divine can already issue and manage NIP-58 badges through
`badges.divine.video`, but mobile users do not have a native place to answer
basic badge questions:

- Which badges have I been awarded?
- Which ones have I accepted onto my Nostr profile?
- Which awards have I issued?
- Did recipients accept the awards I issued?
- Where do I go for full badge creation, editing, and advanced relay tools?

The result is that badges exist, but the user is not yet empowered inside the
mobile app to understand or control them.

## Goals

- Add a native badge hub in Divine mobile.
- Show badges awarded to the current user.
- Show whether each awarded badge is accepted on the user's profile.
- Let the user accept a badge by publishing/updating their profile badge list.
- Let the user reject or hide a badge by removing it from profile badges and
  dismissing it locally.
- Show badges issued by the current user and whether recipients have accepted
  them.
- Open `https://badges.divine.video/me` inside the existing approved Nostr app
  sandbox with `window.nostr` injection.
- Keep badge protocol behavior aligned with current NIP-58.

## Non-Goals

- Do not build a full native badge definition editor in v1.
- Do not replace the existing `badges.divine.video` creation, edit, award, and
  relay-management workflows.
- Do not invent a public rejection event in v1.
- Do not inject `window.nostr` into arbitrary badge-related websites.
- Do not truncate Nostr IDs in code, logs, tests, analytics, or protocol
  handling.

## Protocol Baseline

Current NIP-58 uses:

- Badge Definition: kind `30009`
- Badge Award: kind `8`
- Profile Badges: kind `10008`
- Badge Set: kind `30008`

The older profile-badges shape using `30008` with `d=profile_badges` is
deprecated. Divine should read it as legacy compatibility where practical, but
new acceptance writes should publish kind `10008`.

Accepting a badge means adding an ordered `a`/`e` pair to the current user's
profile badges event, where the `a` tag references the badge definition and
the `e` tag references the award event. Rejecting in v1 means not displaying
the award on the user's profile and optionally remembering the dismissal
locally so it does not keep nagging the user.

## Native Badge Hub

Add a new full-screen `BadgesScreen` reachable from settings. The screen uses
tabs or segmented controls:

1. `Awarded`
2. `Issued`
3. `Manage`

### Awarded Tab

The awarded tab loads badge awards where the current user's pubkey appears in
the award event's `p` tags. Each row shows:

- badge image or fallback icon
- badge name
- issuer profile
- award date
- accepted/not accepted state
- actions: `Accept`, `Hide`, or `Remove`

`Accept` updates the latest profile badge list so the award appears on the
user's profile. `Hide` dismisses an unaccepted award locally. `Remove` removes
an accepted award from the profile badge list.

### Issued Tab

The issued tab loads badge award events authored by the current user. It
groups or lists awards by badge definition and recipient. Each recipient row
shows:

- recipient profile
- award date
- acceptance state when discoverable

Acceptance is derived by querying each recipient's latest profile badges event
and checking whether it contains the issued award event id paired with the
same badge definition coordinate.

To keep relay load bounded, v1 should cap issued-award recipient checks and
show a refresh action for deeper inspection.

### Manage Tab

The manage tab explains the native surface briefly and offers a primary action
to open the full badge app:

`Open Badge Studio`

This launches `https://badges.divine.video/me` in the existing
`NostrAppSandboxScreen` so the web app receives the same NIP-07 bridge,
origin checks, and permission prompts as other approved embedded Nostr apps.

## Embedded Badge App

Add `badges.divine.video` to the bundled vetted Nostr apps catalog so mobile
can launch the badge app even if the remote apps directory is unavailable.

The bundled app entry should:

- use origin `https://badges.divine.video`
- launch `https://badges.divine.video/me`
- allow `getPublicKey`, `getRelays`, `signEvent`, `nip44.encrypt`, and
  `nip44.decrypt`
- prompt for signing and encryption/decryption
- allow badge-related signing kinds:
  - `3` contact list updates used by the web app's follow flow
  - `8` badge awards
  - `10002` relay list updates
  - `10008` profile badge acceptance
  - `30008` badge sets and legacy compatibility
  - `30009` badge definitions

The existing sandbox should remain the enforcement point: origin allowlist,
method allowlist, event-kind allowlist, stored grants, runtime prompts, and
blocked off-origin navigation.

## Repository And BLoC Shape

Add badge-specific code in app-owned layers instead of overloading existing
profile or app-sandbox classes.

- `mobile/lib/services/badges/`
  - NIP-58 parsing helpers and repository.
- `mobile/lib/blocs/badges/`
  - Cubit/BLoC state for awarded, issued, and action progress.
- `mobile/lib/screens/badges/`
  - Page/View widgets for the native badge hub.

The repository depends on:

- `NostrClient` for relay queries and publishes
- `AuthService` for signing profile badge updates
- local storage for dismissed awards

The UI depends on BLoC state only, with Riverpod limited to dependency wiring
consistent with existing `app_providers.dart` patterns.

## Data Flow

### Load Awarded

1. Read the current user's pubkey.
2. Query kind `8` award events tagged with `#p=<current pubkey>`.
3. Query the user's latest profile badges events: current kind `10008` plus
   legacy kind `30008` with `d=profile_badges`.
4. Extract accepted `a`/`e` pairs.
5. Query needed badge definitions by `#a` coordinate or author/d-tag filters.
6. Merge into view models and mark accepted, hidden, or pending.

### Accept Award

1. Load the latest profile badges state.
2. Preserve existing accepted badge pairs.
3. Add the selected award's `a`/`e` pair if absent.
4. Sign a kind `10008` event with the updated ordered tags.
5. Publish it and refresh the badge state.

### Remove Accepted Award

1. Load the latest profile badges state.
2. Remove the matching `a`/`e` pair.
3. Sign and publish a replacement kind `10008` event.
4. Refresh the badge state.

### Hide Unaccepted Award

1. Store the award event id in a per-user dismissed set.
2. Recompute the awarded list without publishing.

### Load Issued

1. Query kind `8` events authored by the current user.
2. Extract recipient pubkeys from `p` tags.
3. Query each recipient's latest profile badge event, capped for v1.
4. Mark recipients accepted when their profile badge list references the award
   event id with the same badge definition coordinate.

## Error Handling

- If relay queries fail, show cached or partial results with a retry action.
- If signing returns null, keep the row state unchanged and show an error.
- If publishing fails, keep the row state unchanged and show an error.
- If badge definitions are missing, show award metadata with a generic badge
  icon and full coordinate available via overflow/copy.
- If the platform does not support embedded Nostr app sandboxing, hide or
  disable the full badge app launcher while leaving native badge lists usable.

## Testing Strategy

- Unit tests for NIP-58 parsing:
  - profile badge `a`/`e` pair extraction
  - legacy `30008` compatibility
  - malformed tags ignored safely
- Repository tests:
  - awarded list acceptance derivation
  - accept publishes kind `10008`
  - remove accepted badge preserves unrelated pairs
  - hide persists locally only
  - issued acceptance checks recipient profile badges
- Bridge package tests:
  - bundled badge app exists in cache-only directory results
  - badge app allows the required signing kinds
- Widget tests:
  - awarded tab empty/loading/error/content states
  - accepted, unaccepted, and hidden actions call the BLoC
  - manage tab opens the sandbox route with the badge app entry

## Rollout

V1 should prioritize the user's understanding and control:

1. Native badge hub and bundled badge app launcher.
2. Awarded badge accept/remove/hide.
3. Issued badge acceptance visibility with bounded recipient checks.
4. Later: profile badge preview on the public profile header, richer ordering,
   and deeper native editing only if the web badge studio proves insufficient.
