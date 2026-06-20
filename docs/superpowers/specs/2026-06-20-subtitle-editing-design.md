# Creator Subtitle Editing & Republish-to-Blossom — Design

**Date:** 2026-06-20
**Status:** Approved design, pending implementation plan

## Problem

Subtitles on Divine videos are auto-generated server-side from the
uploaded video. They are frequently wrong, and creators currently have
no way to correct them. Creators need to edit the subtitle text and
publish the corrected version so viewers see it — both around the time
of publishing a new video and later on an already-published video.

## Decisions (locked)

| Decision | Choice |
|----------|--------|
| Editing model | **Text only** — edit cue text, timing stays fixed. |
| Storage target | **Both** — VTT blob in Blossom *and* a Kind 39307 Nostr subtitle event. |
| Entry points | **Both** at-publish and post-publish (they converge on one editor). |
| Languages | **Single (en)** for v1. |
| At-publish behavior | **Publish now, edit when ready** — never block publish on transcription. |
| Editing permission | **Author-only** in v1 (no collaborator editing). |
| Orchestration owner | **New `SubtitleRepository`** (Approach A). |

## What already exists (reused, not rebuilt)

- **VTT parse/generate:** `SubtitleService.parseVtt` / `generateVtt`
  (`mobile/lib/services/subtitle_service.dart`).
- **Triple-fetch display path:** `subtitleCuesProvider`
  (`mobile/lib/providers/subtitle_providers.dart`):
  1. embedded `textTrackContent` → parse directly,
  2. `sha256` → fetch Blossom `media.divine.video/{videoSha256}/vtt`
     (polls `202 Processing` up to ~15s),
  3. `textTrackRef` = `39307:<pubkey>:subtitles:<d-tag>` → relay query.
- **Subtitle display widgets:** `SubtitleCuePositionPill` / `_CaptionPill`
  (`mobile/lib/widgets/video_feed_item/subtitle_overlay.dart`), respecting
  the global `SubtitleVisibility` toggle.
- **Blossom generic upload:** `BlossomUploadService.uploadAudio` already
  takes an arbitrary `mimeType`, computes sha256
  (`HashUtil.sha256File`), PUTs to `{server}/upload`, returns
  `{ videoId: sha256, url: {server}/{sha256} }`. NIP-98 upload auth
  (kind 24242) is handled in `_uploadToServer`.
- **Addressable republish:** `VideoEventPublisher.republishWithSubtitles`
  (`mobile/lib/services/video_event_publisher.dart`) — strips old
  `text-track` tags, adds a new one, re-signs the kind-34236 event,
  optimistically updates local cache, publishes. **Currently has no
  production caller.**
- **Event signing/publishing:** `AuthService.createAndSignEvent({kind,
  content, tags, createdAt})` + the Nostr publish path.
- **Replacement pattern:** `VideoMetadataUpdateService` republishes
  addressable videos with `createdAt + 1` so relays treat it as a
  replacement while preserving chronological position.

## Architecture (UI → Cubit → Repository → Client)

### Client layer

- **`BlossomUploadService` — add `uploadSubtitleVtt`** (mirrors
  `uploadAudio`): accepts VTT bytes, `mimeType: 'text/vtt'`, returns the
  `BlossomUploadResult` (sha256 + canonical `{server}/{sha256}` URL).
  Blossom is content-addressed by sha256; MIME only sets the stored
  `Content-Type`.
- **`AuthService` / Nostr publish** — unchanged, used to sign & publish
  the kind-39307 event.

### Repository layer (new): `SubtitleRepository`

Owns all source-selection and publish composition (per
`architecture.md` — fallback/composition belongs here, never in the
Cubit/UI).

- `loadEditableCues(VideoEvent video)` → reuses the existing triple-fetch
  to return the current cues, or a **processing** signal when the
  auto-VTT isn't ready yet.
- `publishEditedSubtitles({video, cues, lang})`:
  1. `SubtitleService.generateVtt(cues)` → VTT string.
  2. Upload VTT to Blossom → `vttSha256` + canonical URL (the durable
     "to Blossom too" copy).
  3. Publish **kind 39307** event:
     - `content` = VTT text,
     - `d` = `subtitles:<videoDtag>` (per-video, addressable,
       replaceable on re-edit),
     - tags: `a` = `34236:<pubkey>:<videoDtag>` (video reference),
       Blossom URL, `m` = `text/vtt`, language.
  4. Republish the kind-34236 video via `republishWithSubtitles` with
     **two** `text-track` tags for real read-time redundancy:
     - `39307:<pubkey>:subtitles:<videoDtag>` (relay-queryable,
       replaceable — the consumer already resolves this), and
     - the Blossom canonical VTT URL (durable, CDN-served).
     The consumer tries them in order and falls back if one source is
     unavailable.
  5. Invalidate `subtitleCuesProvider` so the feed updates immediately.

Typed exceptions on failure; no user-facing strings (per
`error_handling.md` per-layer contract).

### Cubit layer (new): `SubtitleEditorCubit`

- **State:** status enum
  `{ loading, processing, ready, saving, success, failure }`,
  `List<EditableCue>` (fixed timestamp + editable text), `isDirty`.
  No error strings / exception objects in state; `addError` on failure.
- **Methods:** `load()`, `updateCueText(index, text)`, `save()`.
- All mutable data lives in state (no private mutable fields on the
  Cubit).

### UI layer (new): `SubtitleEditorScreen`

- Page/View split; **full-screen** (no new bottom sheet), dark-mode
  `VineTheme`.
- `ListView.builder` of cue rows: read-only timestamp label +
  editable text field (text-only; timing fixed).
- Live preview reusing `_CaptionPill` styling; honors the global
  subtitle toggle.
- Save enabled only when `isDirty`; `BlocListener` drives
  success/failure snackbars and a `SemanticsService.sendAnnouncement`
  on completion.
- All copy via `context.l10n`; new ARB keys added to `app_en.arb`.

### Entry points (both route into the one screen)

1. **Post-publish:** "Edit subtitles" action on the creator's **own**
   video, surfaced in the existing `video_metadata_edit_screen` /
   overflow, gated on `video.pubkey == myPubkey`.
2. **At-publish ("publish now, edit when ready"):** publishing is never
   blocked on transcription. After upload, once the auto-VTT is ready,
   the same own-video affordance activates (a "subtitles ready — review"
   badge/banner). No separate editor.

## Data flow (save)

```
SubtitleEditorScreen.save()
  → SubtitleEditorCubit.save()  (status: saving)
    → SubtitleRepository.publishEditedSubtitles(video, cues, lang)
        1. generateVtt(cues)
        2. Blossom.uploadSubtitleVtt(bytes, text/vtt) → vttSha256, url
        3. publish kind 39307 (d = subtitles:<videoDtag>, a, url, m, lang)
        4. republishWithSubtitles(video, ref=39307:pubkey:subtitles:<dtag>)
        5. invalidate subtitleCuesProvider
    → status: success | failure (addError)
  → BlocListener: snackbar + announcement; pop on success
```

## Re-edit semantics

Re-editing publishes a new kind-39307 with the **same** `d` tag and a
new kind-34236 video event (`createdAt + 1`); both replace by their
addressable key, so relays keep the latest. Viewers' `subtitleCuesProvider`
re-resolves to the newest 39307 content.

## Testing

- **`SubtitleRepository`:** VTT generated from edited cues; Blossom
  called with `text/vtt`; 39307 event has correct `d` =
  `subtitles:<videoDtag>` and `a`/url/`m`/lang tags; video republished
  with **both** text-track refs (39307 coords + Blossom URL); error
  paths translate to typed exceptions.
- **Consumer fallback:** `subtitleCuesProvider` resolves cues from the
  Blossom VTT URL when the 39307 relay query yields nothing (the
  redundancy guarantee).
- **`SubtitleEditorCubit`:** `blocTest` status transitions
  (load → processing/ready, save → saving → success/failure);
  `updateCueText` sets `isDirty`; `addError` on failure (no error
  strings in state).
- **`SubtitleEditorScreen`:** renders cues; editing a field updates
  state; save gated on `isDirty`; l10n delegates wired; assertions
  resolve strings from `AppLocalizations`.
- **`BlossomUploadService`:** new VTT path sets `Content-Type: text/vtt`
  and returns the sha256.
- **Ownership:** edit affordance shows only when `video.pubkey ==
  myPubkey`.

## Risks / open items for the plan

1. **HTTP text-track URL consumer support (now in scope).** Redundancy
   requires the consumer to fall back to the Blossom VTT URL when the
   39307 relay query fails. The 39307-coords path is confirmed in
   `subtitleCuesProvider`; a *plain HTTP* text-track URL path is **not**
   confirmed. The plan must verify it and, if missing, **add** an
   HTTP-URL branch to the triple-fetch so the second `text-track` tag is
   actually usable. This is required work for the chosen both-storage
   redundancy, not an optional extra.
2. **Processing state.** When the auto-VTT isn't ready at edit time, the
   editor shows a "transcription still processing" state with retry.
3. **Cache invalidation.** Ensure `subtitleCuesProvider` (and any
   feed-item cached `VideoEvent`) refreshes after republish so the new
   subtitles show without an app restart.
4. **d-tag derivation.** Confirm the canonical source of `<videoDtag>`
   on `VideoEvent` so the 39307 `d` and the `a`/`text-track` refs are
   consistent with what the consumer parses.

## Out of scope (v1)

- Editing cue **timing** (split/merge/add/delete cues, nudging times).
- **Multi-language** track management.
- **Collaborator** editing (author-only).
- Importing an external `.vtt`/`.srt` file.
