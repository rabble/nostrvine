# Saved Sound Library Metadata Design

## Summary

Make the device-local sound library recognizable without previewing every
saved sound. Each saved sound becomes a local record that keeps the reusable
`AudioEvent` plus the context already available where the save happened:
source-video thumbnail, title, creator, description, catalog tags from
`divine-sound-proxy`, any already-available transcript, an optional waveform,
and private personal labels and hashtags.

Saving stays immediate and publishes nothing. Personal details autosave from
the save/import surface and remain editable later. The Library Sounds tab
renders a card with that context instead of a title-and-duration row.

## Problem

The library persists a `List<AudioEvent>` and shows title + duration. Titles
like "Original sound" are not identifying, so users preview saved sounds one
by one to find the one they want.

The context that would identify a sound already exists at the moment of
saving and is thrown away: the source `VideoEvent` (title, content, thumbnail,
creator), and the proxy's `tags` on external results.

## Goals

- Recognize a saved sound without playing it.
- Keep saving immediate and non-blocking.
- Retain source thumbnail, title, description, and creator when available.
- Snapshot a transcript only when embedded captions already exist.
- Show a compact waveform when best-effort extraction succeeds.
- Retain catalog tags supplied by `divine-sound-proxy`.
- Let the user add an optional personal label and private hashtags.
- Search saved sounds across those fields.
- Filter the library by tapping a personal hashtag.
- Preserve existing saved libraries through app upgrades.
- Keep everything device-local.

## Non-Goals

- Publishing any Nostr event when a sound is saved.
- Syncing the library or its metadata across devices.
- Background enrichment that fetches missing context after the save.
- Generating, requesting, or polling for a transcript.
- A crowdsourced label-editing API on `divine-sound-proxy`.
- Changing audio-reuse consent or video-publishing behavior.
- Surviving uninstall or OS "clear app data".

### Deliberate scope cuts

- Source context and transcripts are captured synchronously from data already
  in memory. There is no general fetch, retry, polling, or transcription
  pipeline.
- The only post-save work is optional waveform extraction using the app's
  existing media tooling. Failure is silent and leaves a complete saved sound.
- Hashtags are plain normalized strings, not a category taxonomy or nested
  collection system.

## Product Decisions

### Capture at save, don't enrich later

The save call site passes whatever context it has. `SoundDetailScreen`
already holds `sourceVideo`; the audio selection sheet holds the proxy
result with its tags. Whatever is missing at that moment stays missing —
no fetch, no retry, no polling. Absent context hides its section on the
card; it is never an error.

### Personal details

After the basic record is durably saved, the same surface reveals an optional
single-line `Your label` field and a hashtag entry field. Changes autosave
without a second confirmation action and never block the original save. The
same editor opens later from the card's overflow menu.

The label and personal hashtags are device-local and never sent to the proxy,
relays, analytics, logs, or published events.

### Catalog tags are read-only

Tags from `divine-sound-proxy` are copied into the record at save time so
display and search do not depend on a future proxy response. They are never
edited in the app and no proxy write endpoint is added.

### Card layout

The Sounds tab stays one vertical list — no horizontal card rail.

1. Source-video thumbnail, or the existing sound-icon treatment when there
   is no source video (imports, bundled sounds, failed thumbnail load).
2. Personal label when present, otherwise the best source/catalog title.
3. Duration and creator.
4. Source-post description when present.
5. Transcript excerpt when present.
6. Compact waveform when present.
7. Personal hashtags and catalog tags when present.
8. Overflow: edit personal details, remove.

Search covers the personal label, title, creator, description, and catalog
tags, personal hashtags, and transcript. Tapping a personal hashtag applies a
single filter above the same vertical list; cards never become a horizontal
rail.

## Data Model

A local record wrapping `AudioEvent` rather than adding library state to
`AudioEvent` itself.

```dart
class SavedSoundLibraryPayload {
  final int schemaVersion;
  final List<SavedSound> sounds;
}

class SavedSound {
  final AudioEvent audio;
  final DateTime? savedAt;
  final String? personalLabel;
  final List<String> personalHashtags;
  final SavedSoundSourceContext? sourceContext;
  final List<String> catalogTags;
  final List<double> waveformSamples;
}

class SavedSoundSourceContext {
  final String? videoEventId;
  final String? creatorPubkey;
  final String? creatorName;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? transcript;
}
```

Boundaries:

- `AudioEvent` keeps representing reusable/publishable audio semantics only.
- `schemaVersion` versions the account bucket as a whole; records carry no
  competing version.
- Source context is a value snapshot, not a live `VideoEvent` dependency.
- Legacy records have an unknown `savedAt`; new records always write it.
- Personal hashtags are trimmed, stripped of a leading `#`, compared
  case-insensitively, and deduplicated.
- Waveforms are downsampled before JSON persistence; raw decoder output is
  never stored.
- `AudioExternalSource` gains a serialized `catalogTags` list, populated
  from the proxy response's existing `tags` array, so tags survive API
  mapping and audio selection long enough to reach `SavedSound.catalogTags`.
- Full Nostr identifiers are stored untruncated.

## Persistence And Migration

The library stays account-separated and device-local on the existing
per-account key (`saved_reusable_sounds_<pubkeyHex>` / `_anon`). No new
storage key, no dual-key retirement dance.

The reader is tolerant of both shapes on that key:

- A bare JSON list → legacy `List<AudioEvent>`; each entry becomes a
  `SavedSound` with `savedAt` unknown and every optional field empty.
- An object with `schemaVersion` → the current payload.

The writer always emits the versioned object. So the first save (or label
edit) after upgrade rewrites the bucket in the new shape; until then the
legacy bytes stay readable and untouched. A malformed individual entry is
skipped, never fatal — the existing per-entry `try/catch` behavior.

The existing one-shot legacy device-wide bucket migration and its
process-wide claim guard are unchanged.

Account cleanup keeps removing the account's saved-sound key.

Store upgrades preserve app storage, so the library survives releases.
Uninstall, OS storage clearing, and device replacement remain destructive.

## Component Boundaries

### Models

`SavedSound` and `SavedSoundSourceContext` live in the app layer next to
`SavedSoundsService`, not in the public Nostr `AudioEvent` contract.
`catalogTags` is added to `AudioExternalSource` in `models`.

### Persistence

`SavedSoundsService` gains versioned `SavedSound` read/write and
replace-by-full-sound-id for metadata edits. It checks the boolean result from
`SharedPreferences.setString` and reports a failed write instead of claiming
success. It stays Flutter-free.

### State

Replace `SavedSoundsNotifier` with an app-scoped `SavedSoundsBloc`:

- load the current account bucket;
- save the basic record immediately;
- autosave label and personal hashtag edits by full sound ID;
- remove a record;
- compute search and hashtag filtering;
- run optional duration/waveform extraction after the durable basic save.

The BLoC is recreated when the account storage key changes. Each async
operation retains the storage key it started with, so an account switch cannot
write into or update the wrong bucket. The audio picker maps records back to
`AudioEvent`, so publishing code is unchanged.

### UI

- `SoundDetailScreen` passes its `sourceVideo` context on save and hosts the
  autosaving personal-details editor.
- The audio selection sheet passes the proxy result's catalog tags.
- `sounds_tab.dart` renders rich vertical cards, search, and tappable personal
  hashtag filters from BLoC state.
- New copy is localized; `app_en.arb` keys are mirrored or added to
  `_knownUntranslatedDebt`.

## Failure And Empty-State Behavior

- Save failure uses the existing save-failure treatment; no false success.
- Personal-detail save failure keeps the editor open with the typed value.
- Missing source context hides those card sections.
- Failed thumbnail load falls back to the sound-icon treatment.
- Missing proxy tags produce an empty list.
- Missing embedded captions produce no transcript section and no error.
- Failed waveform extraction produces no waveform and no error.
- Removing a sound removes its metadata in the same write.

## Accessibility

- Thumbnail and preview control have distinct semantics.
- Card semantics include the label-or-fallback title and duration.
- Tag chips expose their visible text.

## Testing

Persistence:

- Round-trip a full `SavedSound` and a source-less one.
- Read a legacy bare-list bucket as `SavedSound`s without changing full
  sound IDs or order, then rewrite it versioned on the next save.
- Skip one corrupt entry without dropping valid entries.
- Preserve proxy catalog tags through API mapping, audio selection
  serialization, save, and reload.
- Preserve per-account and anonymous-bucket isolation.

State:

- Save captures the passed source context and catalog tags.
- Edit label and hashtags by full sound ID without duplicating the record.
- Account switches recreate state and in-flight work cannot cross buckets.
- Search matches label, title, creator, description, transcript, personal
  hashtags, and catalog tags.
- Hashtag selection filters and clears predictably.
- Newest-saved-first ordering.

Widget / golden:

- Card with thumbnail, title, creator, description, transcript, waveform, and
  tags.
- Source-less card (icon fallback, no thumbnail).
- Music-only record with no transcript and no error state.
- Legacy record with only a fallback title.

Run the service, BLoC, widget, l10n, and golden checks first, then
`flutter analyze` and the broader affected suite before publishing.

## Rollout

One focused mobile PR:

1. Versioned `SavedSound` record with a tolerant legacy reader.
2. Retain proxy tags in mobile's normalized sound metadata.
3. Replace the Riverpod notifier with an account-scoped BLoC.
4. Capture already-present source context/transcript and run optional waveform
   extraction after save.
5. Add the autosaving label/hashtag editor.
6. Replace saved-sound rows with rich cards, expanded search, and hashtag
   filtering.

No backend change is needed — `divine-sound-proxy` already returns `tags`.
A provider that omits tags just yields an empty list.
