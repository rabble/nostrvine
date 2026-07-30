# Saved Sound Library Metadata Design

## Summary

Make the device-local sound library useful without requiring users to preview
every saved sound. Each saved sound becomes a versioned local record containing
the reusable audio value, source context, retained catalog tags, optional
personal organization, and compact visual-identification data.

Saving remains immediate and does not publish a Nostr event. After the sound is
saved, the same sound-detail or import surface offers optional fields for a
personal label and personal hashtags. The Library Sounds tab renders rich,
vertical cards with a source-video thumbnail when available, an audio waveform,
original-post context, an existing transcript when one exists, catalog tags,
and personal hashtags.

## Problem

The current library persists a list of `AudioEvent` values and primarily shows
each event's title and duration. Titles such as "Original sound" are not enough
to identify a sound later, so users must preview saved sounds one by one.

Useful context already exists in several places but is not retained by the
saved-sounds flow:

- The source `VideoEvent` can provide a title, post content, thumbnail,
  hashtags, categories, and existing caption data.
- `divine-sound-proxy` search results provide catalog tags.
- Users know why they saved a sound, but have nowhere to record a private label
  or organizational hashtags.
- Audio can be recognized visually from a compact waveform even when it is
  music and has no transcript.

## Goals

- Let a user recognize a saved sound without playing it.
- Keep saving immediate and non-blocking.
- Retain original-post title and description when available.
- Retain an existing source transcript without initiating transcription.
- Retain catalog tags supplied by `divine-sound-proxy`.
- Let the user add an optional private label and private hashtags.
- Show a source-video thumbnail when the sound came from a video.
- Show a compact waveform whenever readable audio is available.
- Search saved sounds across all useful metadata.
- Offer tappable personal-hashtag filters.
- Preserve existing saved libraries through app upgrades.
- Keep all new library organization device-local for this version.

## Non-Goals

- Publishing a Nostr kind-1063 event when a sound is saved.
- Uploading personal labels or personal hashtags.
- Syncing the sound library or its metadata across devices.
- Generating a transcript when the source post does not already have one.
- Reporting missing speech, captions, thumbnails, tags, or waveforms as errors.
- Adding a crowdsourced sound-label editing API to `divine-sound-proxy`.
- Changing the existing audio-reuse consent or video-publishing behavior.
- Making uninstall or operating-system "clear app data" preserve the library.

## Product Decisions

### Save First, Organize Second

Tapping "Use Sound" or completing an audio import saves the basic local record
first. The current surface then confirms that the sound is saved and reveals an
optional "Make it easy to find later" section with:

- `Your label`
- `Hashtags`
- `Not now`
- `Save details`

The fields do not block the initial save. The same editor is available later
from an "Add details" affordance or the saved card's overflow menu.

### Two Metadata Layers

Saved sounds distinguish shared source/catalog metadata from private
organization:

1. **Catalog context** is read-only in the saved library. It includes the
   source title, creator, original-post title/description, source-post hashtags
   and categories, and tags returned by `divine-sound-proxy`.
2. **Personal context** is editable and device-local. It includes the user's
   personal label and personal hashtags.

Both layers are searchable. Cards label the layers distinctly as "Sound tags"
and "Your tags" when both are present. Personal metadata is never sent to the
proxy, relays, analytics, logs, or published events.

### Transcript Policy

The library snapshots transcript text only when the source video already
provides captions through its existing caption data. VTT cue syntax and
duplicate overlapping cue text are converted to readable plain text before
persistence.

The library does not invoke on-device transcription, server transcription, or
retry/polling to create captions. If no transcript exists, the transcript
section is absent. Music, silence, unavailable captions, and caption-loading
failures are all normal no-transcript states.

### Visual Direction

The Sounds tab remains one vertical list; saved sounds are not presented in a
horizontally scrolling card rail.

Each rich card uses this hierarchy:

1. Source-video thumbnail and preview control, or a sound-only fallback.
2. Personal label when present; otherwise the best catalog/source title.
3. Compact waveform and duration.
4. Original-post title/description when present.
5. Existing transcript excerpt when present.
6. Personal hashtags and catalog tags, visibly distinguished.
7. Overflow actions for editing details and removing the sound.

The thumbnail comes from the source video. A local import, bundled sound, or
other source-less sound does not receive an invented thumbnail. It uses the
waveform and sound icon treatment instead.

The search field covers personal labels, personal hashtags, sound titles,
creators, original-post title/description, transcript text, and catalog tags.
Tappable personal-hashtag filters appear above the list. They wrap or use a
bounded "More" treatment rather than forcing the sound cards into horizontal
scrolling. Selecting a filter and entering search text applies both conditions.

## Data Model

Introduce an immutable local-library model rather than adding private library
state directly to `AudioEvent`.

```dart
class SavedSoundLibraryPayload {
  final int schemaVersion;
  final List<SavedSound> sounds;
}

class SavedSound {
  final AudioEvent audio;
  final DateTime savedAt;
  final String? personalLabel;
  final List<String> personalHashtags;
  final SavedSoundSourceContext? sourceContext;
  final List<String> catalogTags;
  final List<double> waveformSamples;
}

class SavedSoundSourceContext {
  final String? sourceVideoReference;
  final String? videoEventId;
  final String? creatorPubkey;
  final String? creatorName;
  final String? title;
  final String? description;
  final String? thumbnailUrl;
  final String? transcript;
  final List<String> hashtags;
  final List<String> categories;
}
```

Implementation may introduce small helper value types, but the serialized
semantics and these boundaries are required:

- `AudioEvent` continues to represent reusable/publishable audio semantics.
- `SavedSoundLibraryPayload.schemaVersion` versions the account bucket as a
  whole; individual records do not carry competing schema versions.
- `SavedSound` owns local-library persistence and private organization.
- Source snapshots are values, not live `VideoEvent` dependencies.
- `AudioExternalSource` gains a serialized `catalogTags` list so proxy tags
  survive API mapping and audio selection long enough to be copied into
  `SavedSound.catalogTags`.
- Waveform samples are a compact normalized amplitude series, not raw audio.

Personal hashtags are stored without a leading `#`, trimmed, compared
case-insensitively, and deduplicated. The UI renders the `#` prefix. Empty tags
are discarded. Catalog tags are normalized for matching without overwriting the
provider's visible wording when that wording is useful.

## Persistence And Migration

The library remains account-separated and device-local using the existing
saved-sounds account bucket behavior. The persisted payload gains an explicit
top-level schema version and serializes `SavedSound` records.

Migration from the current `List<AudioEvent>` format must:

1. Read and parse the legacy account bucket without mutating it.
2. Convert each valid `AudioEvent` into a `SavedSound` with empty optional
   metadata.
3. Write the new versioned payload to a new storage key.
4. Read the new payload back and validate that every migrated sound ID is
   present.
5. Only then retire the legacy account payload.

A failed or interrupted migration leaves the legacy payload available for a
later retry. Invalid individual entries are isolated so one malformed record
cannot erase valid saved sounds.

Account cleanup removes both legacy and current saved-sound storage keys while
the migration compatibility window exists.

Normal App Store and Play Store upgrades preserve application storage, so the
versioned record and migration protect the library across releases. Uninstall,
operating-system storage clearing, and device replacement remain destructive
because cross-device sync and backup are out of scope.

## Save And Enrichment Flow

### Immediate Save

The save operation creates and persists a `SavedSound` containing:

- the selected `AudioEvent`;
- `savedAt`;
- source context already available at the call site;
- proxy/catalog tags already available on the selected result.

The UI may confirm the save as soon as this durable write succeeds. Personal
details can be committed independently after that point.

### Best-Effort Enrichment

After the initial save, an enrichment operation may fill missing:

- source-video context resolved from the full source reference;
- thumbnail URL;
- readable transcript snapshot;
- compact waveform samples;
- duration when legacy/current audio metadata omitted it.

Enrichment updates the same `SavedSound` by full sound ID. It never creates a
duplicate record. It captures the account storage key before asynchronous work
so an account switch cannot write results into another account's library.

Source metadata is taken from an already-loaded `VideoEvent` when the save call
provides one. Otherwise, a repository lookup is attempted when only a source
reference is available. The full Nostr identifier is preserved throughout.

### Provider Results

`divine-sound-proxy` already returns `tags` for indexed and Freesound results,
and its indexed schema persists tags. Mobile's normalized response mapping must
retain those tags instead of dropping them.

Provider tags remain read-only catalog metadata. Saving a provider result
copies them into the saved record so search and display do not depend on a
future proxy response.

No proxy write endpoint is added. Crowdsourced or user-submitted catalog labels
would require a separate authenticated, moderated design.

## Component Boundaries

### Models

- Add `SavedSound` and `SavedSoundSourceContext` in the owning local/app layer,
  not to the public Nostr `AudioEvent` contract.
- Add serialized `catalogTags` to `AudioExternalSource` and populate it from
  the proxy response's existing `tags` array.

### Persistence Service

`SavedSoundsService` becomes responsible for versioned `SavedSound` records,
migration, replacement by full ID, removal, and corruption isolation. It
remains unaware of Flutter widgets.

### State Management

Introduce a saved-sounds Cubit/BLoC behind constructor-injected persistence and
enrichment collaborators. Expose operations for:

- immediate save;
- edit personal details;
- apply enrichment;
- remove;
- search/filter projection.

Async operations retain the current account-isolation guarantees.

### Enrichment

A focused enrichment collaborator resolves source context, parses existing VTT
content, and generates compact waveform samples. It depends on repositories and
audio utilities through constructor-injected interfaces. Persistence remains in
the repository/service layer rather than in widgets.

### UI

- A reusable saved-sound details editor is embedded in the sound-detail and
  import completion surfaces.
- The Sounds tab consumes `SavedSound` view data and renders rich cards.
- The audio picker/editor maps saved records back to their underlying
  `AudioEvent` values when selecting audio.
- Existing publishing code continues receiving `AudioEvent`; personal and
  catalog organization does not leak into publishing.

## Failure And Empty-State Behavior

- Initial persistence failure uses the existing save-failure treatment and does
  not falsely confirm success.
- Personal-detail persistence failure keeps the editor open and preserves the
  typed values for retry.
- Missing or failed source lookup hides unavailable source fields.
- Missing transcript hides the transcript section.
- Failed thumbnail loading shows the sound-only fallback.
- Failed waveform generation shows the standard sound icon/preview treatment.
- Missing proxy tags produce an empty catalog-tag list.
- A background enrichment failure does not roll back the already-saved sound or
  show a snackbar.
- Removing a sound removes its metadata and waveform in the same persisted
  operation.

## Accessibility And Localization

- Thumbnail and preview controls have distinct semantics; decorative waveform
  bars are excluded from accessibility traversal.
- Card semantics include the personal label or fallback title and duration.
- Personal and catalog hashtag chips expose their visible `#tag` text.
- All new user-facing copy is localized across every `app_*.arb` locale or
  explicitly handled through the repository's translation-debt mechanism.
- Copy stays direct: "Saved to your library," "Make it easy to find later,"
  "Your label," "Hashtags," "Not now," and "Save details."

## Testing

### Model And Persistence Tests

- Round-trip a complete `SavedSound`.
- Round-trip a source-less/imported saved sound.
- Normalize and deduplicate personal hashtags.
- Preserve proxy catalog tags through API mapping, audio selection
  serialization, save, and reload.
- Migrate existing `AudioEvent` lists without changing full IDs or order.
- Validate the new payload before retiring legacy storage.
- Retry after failed/interrupted migration.
- Skip one corrupt entry without dropping valid entries.
- Preserve per-account and anonymous-bucket isolation.
- Ensure account switches during enrichment cannot cross-write.
- Remove the audio, private metadata, source snapshot, and waveform together.

### Enrichment Tests

- Prefer an already-loaded source video over a fetch.
- Snapshot title, description, thumbnail, hashtags, and categories.
- Convert existing VTT cues to readable, deduplicated transcript text.
- Do not invoke transcription when captions are absent.
- Generate bounded normalized waveform samples.
- Treat missing audio, source lookup failure, caption failure, and waveform
  failure as optional-field absence.

### State Tests

- Confirm durable basic save before enrichment completes.
- Edit personal label and hashtags after saving.
- Apply enrichment to the existing full sound ID without duplication.
- Search every catalog and personal text field.
- Combine search text with a selected hashtag filter.
- Keep newest-saved-first ordering.

### Widget And Golden Tests

- Rich card with thumbnail, waveform, post context, transcript, and both tag
  layers.
- Music/source sound with no transcript.
- Imported/source-less sound with waveform and no thumbnail.
- Legacy saved sound with only fallback title/icon.
- Immediate saved confirmation followed by optional inline details.
- Add/edit details from an existing card.
- Wrapped/bounded hashtag filters with no horizontal sound-card rail.
- Thumbnail and waveform fallback states.
- Semantics for preview, details, tags, edit, and remove actions.

Run the focused service, provider/state, widget, localization, and golden checks
first, then `flutter analyze` and the broader affected Flutter suite before
publishing.

## Rollout

Ship as one focused mobile feature:

1. Add versioned records and safe legacy migration.
2. Retain proxy tags in mobile's normalized sound metadata.
3. Add immediate-save plus personal-details editing.
4. Add best-effort source/transcript/waveform enrichment.
5. Replace saved-sound rows with rich cards, expanded search, and hashtag
   filters.

No backend deployment is required for retaining the proxy's existing `tags`
field. If implementation reveals that a specific enabled provider omits tags,
that provider continues with an empty catalog-tag list rather than blocking the
mobile release.
