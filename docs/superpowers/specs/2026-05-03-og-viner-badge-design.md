# OG Viner Badge Design

## Goal

Show a small "V" mark for accounts the app has learned are OG Viners, without adding per-user server checks or a manually maintained allowlist.

## Product Contract

The badge means: this app has learned from archive-backed data that the pubkey authored original Vine content.

The behavior is eventually consistent:

- If the app already knows a pubkey is an OG Viner, show the V.
- If the app does not know yet, show nothing.
- When archive-backed video data later proves a pubkey is an OG Viner, cache that positive result locally and update subscribed UI.
- Unknown is not negative. There is no "not OG Viner" cache.

The existing NIP-05 checkmark remains a separate verified-identity signal. The OG Viner V is an archive-history signal.

## Source Of Truth

Use archive-backed video data already loaded by the app. A `VideoEvent` with `isOriginalVine == true` is evidence for `video.pubkey` when the event comes through trusted archive/API paths such as the Classic Vines feed.

Do not call the server while rendering names. Do not maintain a hand-written allowlist.

## Architecture

Add a small local service that owns a positive-only set of known OG Viner pubkeys. It loads from `SharedPreferences` at startup, exposes synchronous membership checks, and notifies listeners when new pubkeys are learned.

Archive-backed providers call a batch method such as `markFromArchiveVideos(videos)` after they receive and filter classic Vine videos. Name and profile UI read the local cache only.

If the local set becomes too large for `SharedPreferences`, the service API can move to a Drift-backed table without changing the UI contract.

## UI

Add a reusable compact OG Viner badge and render it beside display names on the same surfaces that already show account identity signals, starting with `UserName`.

The badge should be small, stable, and non-blocking:

- render synchronously from local state
- no loading indicator
- no server request
- preserve existing name layout and truncation

## Error Handling

If the local cache cannot be decoded, start with an empty set and overwrite on the next successful discovery. A failed write should not block feed loading or name rendering.

## Testing

Cover:

- the cache loads existing positive pubkeys from `SharedPreferences`
- `markFromArchiveVideos` stores only videos with `isOriginalVine == true`
- duplicate discoveries do not rewrite or duplicate entries
- corrupt cache data falls back to empty
- `UserName` shows the V only for locally known OG Viner pubkeys
- no UI path performs a network lookup for the OG marker
