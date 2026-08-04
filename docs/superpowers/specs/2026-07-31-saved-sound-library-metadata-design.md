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

Saving a sound and permitting remix are separate actions. Private/imported
audio remains embedded only in the user's video unless they explicitly enable
“Allow others to remix this sound.” Shared sounds carry public attribution,
labels, source, license, and immutable consent evidence without copying any
private library fields.

## Problem

The library persists a `List<AudioEvent>` and shows title + duration. Titles
like "Original sound" are not identifying, so users preview saved sounds one
by one to find the one they want.

The context that would identify a sound already exists at the moment of
saving and is thrown away: the source `VideoEvent` (title, content, thumbnail,
creator), and the proxy's `tags` on external results.

There is also a consent and credit failure in the publish path. A local import
is currently published as a reusable Kind 1063 whenever its video is
published, even when `allowAudioReuse` is false. The code also assumes a local
file is the user's own work, while public sound events do not consistently
retain or display the original creator, source, license, or useful labels.

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
- Keep all private library organization device-local.
- Never infer remix permission from saving, importing, or possessing a file.
- Publish a reusable Kind 1063 only after explicit remix consent.
- Preserve and display public creator/source/license attribution for shared
  sounds.
- Distinguish the credited creator from the account that shared the event.
- Preserve exact signed provenance without creating a circular event-ID
  dependency, while retaining the addressable video coordinate for current
  navigation.

## Non-Goals

- Publishing any Nostr event when a sound is saved.
- Syncing the library or its metadata across devices.
- Background enrichment that fetches missing context after the save.
- Generating, requesting, or polling for a transcript.
- A crowdsourced label-editing API on `divine-sound-proxy`.
- Inventing a new Nostr event kind for sounds.
- Treating a personal label or private hashtag as public attribution.
- Surviving uninstall or OS "clear app data".

### Deliberate scope cuts

- Source context and transcripts are captured synchronously from data already
  in memory. There is no general fetch, retry, polling, or transcription
  pipeline.
- The only post-save work is optional waveform extraction using the app's
  existing media tooling. Failure is silent and leaves a complete saved sound.
- Hashtags are plain normalized strings, not a category taxonomy or nested
  collection system.
- Public credit reuses Kind 1063, standard Nostr references, NIP-48 proxy
  references, and existing/common metadata tags. It does not introduce a new
  service or event kind.

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

### Saving is not remix consent

Adding a sound to the device library never publishes an event and never grants
other people permission to remix it. Publishing a video with original or
imported audio also does not create a Kind 1063 while “Allow others to remix
this sound” is off.

When the toggle is on:

- original user-created audio is credited to the publisher;
- an unattributed import requires either “I made this sound” or public
  creator/source credit;
- known provider/import attribution is prefilled;
- an existing Nostr sound keeps its original event and attribution and is
  never republished under the remixer;
- provider audio is eligible for further remix only when its normalized
  license permits derivatives.

The current assumption that a device-local import is necessarily owned by the
user is removed.

### Private organization and public attribution are separate

`personalLabel` and `personalHashtags` are private organizational data. They
never enter publisher parameters, drafts' public metadata, signed events,
logs, analytics, or public UI.

Public attribution is reviewed independently when remixing is enabled:

- public sound title;
- credited creator name;
- optional credited creator Nostr pubkey;
- source URL;
- license name and URL;
- explicitly public sound tags;
- whether the user confirmed they created the sound.

The publishing surface shows a final “Shared as” preview. Provider metadata is
read-only when it came from a trusted catalog response. Unknown imports cannot
be offered for remix until ownership or attribution is supplied.

### Public credit display

Shared sounds render the same public hierarchy in sound detail, feed audio
attribution, video metadata, and saved cards:

1. Sound title.
2. “By [credited creator].”
3. “Shared by [event publisher]” when the publisher and creator differ.
4. Provider/source and license.
5. Public sound tags.
6. “Remixing allowed” or “Credit only.”

Saved cards additionally show “Your label” and “Your tags” as a visibly
separate private layer.

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

class AudioShareAttribution {
  final String title;
  final String creatorName;
  final String? creatorPubkey;
  final String? sourceUrl;
  final String? licenseName;
  final String? licenseUrl;
  final List<String> publicTags;
  final bool confirmedOwnWork;
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
- `AudioShareAttribution` is public draft/publish state, not a field derived
  from `SavedSound.personalLabel` or `personalHashtags`.
- Public attribution is stored in the draft so autosave, reopening, background
  publishing, and retry use the exact values the user reviewed.

## Nostr Publication And Provenance

New reusable sound events continue to use Kind 1063. They include:

- NIP-94 file tags (`url`, `m`, `x`, and `size`) plus Divine's existing
  `duration` tag where available;
- an `a` tag containing the canonical addressable source-video coordinate
  `34236:<pubkey>:<d-tag>` plus relay hint;
- a `p` tag when the credited creator has a Nostr pubkey;
- `t` tags only for explicitly public sound labels;
- a NIP-48 `proxy` tag for provider-originated audio;
- `title`, `source`, and `license` metadata plus documented Divine
  `creator`, `creator_url`, and `license_url` extensions;
- `allow_audio_reuse=true`;
- a readable public description/credit in the event content.

The Kind 1063 `a` reference is primary for navigation because a Kind 34236
video is addressable and replaceable. The exact signed video event contains
the existing reverse `e` reference to the Kind 1063 audio event. The audio
cannot also `e`-reference that exact video: each immutable event ID would then
depend on the other, creating an impossible hash cycle.

Exact provenance is therefore the signed video event whose `e` tag references
the audio event and whose address matches the audio's source `a` coordinate.
Public credit and explicit consent are snapshotted into Kind 1063 so they
remain readable after source edits, unavailability, or deletion.

NIP-94 does not standardize artist or license attribution. Divine therefore
uses registered/common tags where they exist and clearly documented Divine
metadata for the remaining fields; the UI does not imply every Nostr client
will render those extensions.

For legacy Kind 1063 events without explicit consent, Divine queries signed
video events that reference the audio ID, keeps only candidates whose address
matches the audio's source `a` coordinate, and selects the earliest candidate
at or after the audio event's creation. That exact event must contain
`allow_audio_reuse=true`. If selection is ambiguous or evidence is missing,
remixing is unavailable. Absence of a consent tag no longer defaults to
permission.

Provider catalog audio is already public source material rather than a private
device import. When used in a published video, Divine creates a
credit-bearing bridged Kind 1063 with its NIP-48 `proxy`, creator, source, and
license metadata so the video can reference durable attribution. Trusted
catalog tags become its public `t` tags. The event is marked reusable only when
the normalized provider license permits derivatives and the publisher enables
remixing; otherwise it carries `allow_audio_reuse=false`. The video publisher
is shown as “Shared by,” never “By.”

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
`AudioEvent`.

### Publishing

The publish flow receives explicit `AudioShareAttribution` separately from the
saved-library record. The existing “Publish this sound” control becomes “Allow
others to remix this sound.”

- Toggle off: publish the video without creating a Kind 1063 for original or
  imported private audio. Provider audio still gets a credit-only bridged Kind
  1063 because omitting attribution is not acceptable.
- Toggle on: validate public attribution, publish Kind 1063 first, then
  reference it from the video.
- Existing Nostr sound: reference the original Kind 1063 without republishing.
- Provider sound: retain provider/source/license credit and permit further
  remix only when the normalized license allows derivatives and the user
  enables remixing.

If a user explicitly requested a reusable sound and Kind 1063 publication
fails, video publication stops in a retryable state. It must not silently post
without the sharing choice the user reviewed. When the toggle is off,
sound-sharing infrastructure cannot block original/private-import video
publication. Provider-credit publication remains required; its failure blocks
the video rather than publishing uncredited provider audio.

### UI

- `SoundDetailScreen` passes its `sourceVideo` context on save and hosts the
  autosaving personal-details editor.
- The audio selection sheet passes the proxy result's catalog tags.
- `sounds_tab.dart` renders rich vertical cards, search, and tappable personal
  hashtag filters from BLoC state.
- The publish metadata screen owns the inline public-credit editor and “Shared
  as” preview; no new dialog or bottom sheet is introduced.
- Feed attribution, video metadata, and sound detail share the same public
  credit presentation rules.
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
- Invalid public attribution prevents enabling remix and identifies the
  missing creator/source field inline.
- A license that forbids derivatives shows “Credit only” and disables further
  remix.
- Failure to publish an explicitly requested reusable Kind 1063 keeps the
  video retryable.
- Publishing original/private-import audio with remix disabled never fails
  because sound sharing is unavailable.
- Provider-credit event failure blocks publication instead of posting
  uncredited provider audio.

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
- Public credit with distinct creator and publisher.
- Provider/source/license attribution and public tags.
- “Remixing allowed” and “Credit only” states.

Publishing / protocol:

- Original and imported audio with remix off create no Kind 1063.
- Imported audio with remix on requires ownership confirmation or attribution.
- Existing Nostr audio is referenced and never republished under the remixer.
- Provider audio always publishes durable source, creator, license, and trusted
  catalog tags in a credit-bearing bridge; remix additionally respects
  `allowsDerivatives` and the user's toggle.
- New Kind 1063 events contain explicit consent, public tags, and addressable
  `a` provenance; the exact video event provides the reverse `e` reference.
- Legacy consent is verified from the exact signed video that references the
  audio and matches its address, and fails closed when unavailable.
- Private labels and personal hashtags never appear in publisher calls, signed
  tags/content, logs, analytics, or public widgets.
- Reusable Kind 1063 failure blocks a publish that explicitly requested sound
  sharing and remains retryable; a required provider credit-event failure also
  blocks rather than publishing uncredited audio.

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
7. Separate public `AudioShareAttribution` from private saved metadata.
8. Gate imported/original Kind 1063 publication on explicit consent.
9. Publish addressable provenance and verify the exact reverse video reference
   with public tags/credit.
10. Display consistent creator, sharer, source, license, and remix status.

No backend change is needed — `divine-sound-proxy` already returns `tags`.
A provider that omits tags just yields an empty list.
