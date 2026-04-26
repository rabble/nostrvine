# Subtitle Edit (Author-Only) — Design

**Date:** 2026-04-26
**Status:** Approved (brainstorm complete, awaiting plan)
**Owner:** rabble
**Out of scope for v1:** re-transcribe, timing edits, add/delete cues, collaborator editing, multi-language, preview-while-playing, viewer "report bad captions" flow

---

## Problem

Auto-generated VTT subtitles are sometimes wrong. Today the app reads VTT from three paths (REST embed → Blossom `/{sha256}/vtt` → Kind 39307) but exposes no way for the author to correct mistakes. We want a focused editor that lets a video's author fix the transcription text.

## Goal

Ship the smallest end-to-end editor that lets a signed-in author edit existing cue text on their own video and have those edits propagate to all read paths (Nostr relay, funnelcake REST embed, Blossom cache).

## Non-Goals

- **Re-transcribing audio.** Considered and deferred — model output is non-deterministic; user-controlled text edits give a better worst case.
- **Timing edits, splits, merges, add/delete cues.** Vines are short; word-level transcription timing is usually fine. Re-evaluate after v1 ships.
- **Collaborator editing.** Author can specify collaborators is a future ask. The Kind 39307 address includes the signer's pubkey, so collaborator edits break the video event's `text-track` pointer resolution. Deferred to v2 with a separate decision between NIP-26 delegation and an allowlist resolution model. See "v2 / Future Work" below.
- **Community / viewer-side correction.** Same reasoning.
- **Multi-language.** v1 edits the existing track only; we copy its language tag forward.
- **Live preview** of captions over the playing video inside the editor.

---

## User Experience

### Entry Point

- Visible only when `videoEvent.pubkey == currentUser.pubkey`.
- Two surfaces:
  1. **Overflow (3-dot) menu on the video** → "Edit captions" (primary, discoverable).
  2. **Long-press the CC button** → same destination (power-user shortcut).
- Hidden entirely for non-authors.

### Editor Screen

Full-screen page, dark mode (per `ui_theming.md`).

**App bar**
- Title: "Edit captions"
- Leading: discard (X) button
- Trailing: "Save" — disabled until state is dirty

**Body — two render modes**

1. **Cue list mode** (existing VTT parsed to ≥1 cue):
   - Scrollable list of cue rows.
   - Each row: timestamp range (read-only, `mm:ss.SSS – mm:ss.SSS`) above an editable `TextField` containing the cue's current text.
   - Soft per-cue length cap surfaced via helper text at 500 chars; hard cap at 2000 to keep WebVTT sane.

2. **Single-cue fallback** (existing VTT parses to 0 cues, or no VTT at all):
   - One textarea labelled "Captions for full video (0:00 – 0:0X)".
   - Saved as a single cue spanning `0 → videoEvent.duration` (or 6s if duration unknown).

### Save Flow

1. User taps Save.
2. Editor enters `saving` state; overlay disables further input.
3. Repository runs the dual-write sequence (see "Architecture").
4. **Success** → snackbar "Captions updated" → editor dismisses → subtitle provider invalidated → next render of the video shows new cues.
5. **Partial success** (relay ok, Blossom failed) → snackbar "Saved — may take a moment to appear everywhere." → editor dismisses. The funnelcake reindexer will heal the REST/Blossom paths on its own.
6. **Failure** (relay publish failed) → snackbar "Couldn't save captions. Try again." → editor stays open with edits intact and a Retry affordance.

### Discard Flow

- X button with no changes → dismiss immediately.
- X button with `isDirty` → confirm dialog "Discard changes?" → confirm dismisses, cancel returns to editor.

---

## Architecture

Layered per `architecture.md`: **UI → BLoC → Repository → Client.** New feature ⇒ BLoC (not Riverpod), per `state_management.md` migration policy.

### Components

| Layer | Component | Location | Responsibility |
|---|---|---|---|
| UI | `SubtitleEditorPage`, `SubtitleEditorView` | `mobile/lib/screens/subtitle_editor/` | Provides BLoC; renders cue list or single-cue fallback; dispatches edit/save/discard events |
| BLoC | `SubtitleEditorCubit`, `SubtitleEditorState` | `mobile/lib/screens/subtitle_editor/cubit/` | Holds `List<EditableCue>`, `status` enum, `isDirty`. No error strings in state — uses `addError` |
| Repository | `SubtitleEditRepository` | `mobile/packages/subtitle_repository/` (new package) | Orchestrates dual-write: build VTT → publish Kind 39307 → PUT Blossom → return composite result |
| Client | `BlossomVttClient` | `mobile/packages/subtitle_repository/lib/src/` | HTTP `PUT` to `media.divine.video/v1/{sha256}/vtt` with NIP-98 auth |
| Client | Kind 39307 publish path | Reuses existing `AuthService.createAndSignEvent` + `NostrClient.publish` | No new client; just a typed call site |
| Read | `subtitleCuesProvider` (existing) | `mobile/lib/providers/subtitle_providers.dart` | Unchanged; we only invalidate it after a successful save |

### State Shape

```dart
enum SubtitleEditorStatus { initial, loading, editing, saving, success, failure }

class EditableCue {
  final int startMs;        // immutable in v1
  final int endMs;          // immutable in v1
  final String text;        // mutable
}

class SubtitleEditorState {
  final SubtitleEditorStatus status;
  final List<EditableCue> cues;
  final List<EditableCue> originalCues;   // for dirty check + discard
  final String videoId;
  final String? sha256;
  final int videoDurationMs;
  final String language;                  // copied from existing track or 'en'

  bool get isDirty => !listEquals(cues, originalCues);
  bool get isFallbackMode => originalCues.length <= 1 && (originalCues.firstOrNull?.text.isEmpty ?? true);
}
```

Errors flow via `addError(e, stackTrace)` and surface as snackbars in the View. No error strings stored in state (project rule).

### Write Sequence (on Save)

```
1. vtt = SubtitleService.generateVtt(state.cues)
2. event = await authService.createAndSignEvent(
     kind: 39307,
     content: vtt,
     tags: [
       ["d",        "subtitles:${videoEvent.dTag}"],
       ["e",        videoEvent.id],
       ["a",        "34236:${videoEvent.pubkey}:${videoEvent.dTag}"],
       ["language", state.language],
       ["alt",      "Subtitle track"],
     ],
   )
3. await nostrClient.publish(event)              // MUST succeed
4. try {
     await blossomVttClient.put(sha256, vtt)     // best-effort
   } catch (e, s) {
     addError(e, s);                             // log, do not abort
     return SaveResult.partial;
   }
5. ref.invalidate(subtitleCuesProvider for videoId)
6. return SaveResult.full;
```

**Why relay-first, Blossom best-effort:** Kind 39307 is the signed source of truth. Funnelcake's reindexer will heal `text_track_content` on the REST fast path even if Blossom write fails. Worst case is a stale `/{sha256}/vtt` cache for a window — acceptable. Hard-failing the user on a cache miss is the wrong tradeoff.

**Why not reverse the order:** if we wrote to Blossom first and the relay publish then failed, the cache would carry edits not present in the signed source. Other clients reading from REST would see ghost edits.

---

## Backend Contract (Blossom Side)

Negotiated separately with the Blossom server work. The mobile client assumes:

```
PUT https://media.divine.video/v1/<sha256>/vtt
Headers:
  Authorization: Nostr <base64(NIP-98 event)>
  Content-Type: text/vtt
Body: <raw VTT bytes, UTF-8>
```

**Server MUST:**
- Verify NIP-98 event signature, method = `PUT`, URL = exact request URL.
- Verify the NIP-98 event's pubkey matches the author of the Kind 34236 video event whose URL contains this `<sha256>`.
- Replace the served VTT atomically; subsequent `GET /v1/<sha256>/vtt` returns the new content.

**Response codes:**

| Code | Meaning | Mobile handling |
|---|---|---|
| 200 | Success | Mark Blossom step complete |
| 400 | Malformed VTT | Treat as save failure; show generic error |
| 401 | Missing/invalid NIP-98 | Treat as save failure; log auth issue |
| 403 | NIP-98 pubkey != video author | Defense in depth — surface "You can only edit captions on your own videos" |
| 404 | Unknown sha256 | Treat as partial success (relay still wrote); log |
| 409 | Version conflict | Show non-destructive banner: "Captions changed elsewhere — reload?" Reload discards local edits |
| 5xx | Server error | Partial-success path; relay write already succeeded |

This contract section travels with the spec so the Blossom-side work can negotiate against it.

---

## Read Path

**Unchanged.** `subtitleCuesProvider` already implements REST embed → Blossom → Kind 39307 fallback. After a successful save, the editor calls `ref.invalidate()` on this provider for the affected `videoId`, triggering a refetch. Whichever path returns first wins; funnelcake reindex catches up the embedded path within seconds.

---

## Edge Cases

| Case | Behavior |
|---|---|
| Existing VTT parses to ≥1 cue | List view, edit per-cue text |
| Existing VTT parses to 0 cues (garbage / JSON / empty body) | Single-cue fallback, `0 → videoDuration`, empty text field |
| No VTT at all (404 + no Kind 39307 + no embed) | Single-cue fallback — author can author from scratch |
| Video has no `sha256` known to client | Disable entry point; editing requires a known content hash |
| User signs out mid-edit | Discard local state, dismiss editor (no orphan saves) |
| Relay publish succeeds, Blossom fails | Partial-success snackbar; editor dismisses; reindex heals REST path |
| Relay publish fails | Hard error; editor stays open with edits intact and Retry; do **not** call Blossom |
| Blossom returns 403 | "You can only edit captions on your own videos" — should not be reachable via UI |
| Blossom returns 409 | Non-destructive reload banner |
| Save tap with no changes | Save button disabled while not dirty; unreachable |
| Cue text exceeds soft cap (500 chars) | Helper text warns; hard cap 2000 |
| Video duration unknown | Use 6s default; surface tooltip |
| App backgrounded mid-save | In-flight HTTP completes; on resume we still invalidate provider. No user-visible difference |

---

## Testing

Per `testing.md`. Coverage target 100% on new files (per project CI policy).

| Layer | Tests |
|---|---|
| `SubtitleService` | **Existing** parse tests retained. **Add:** generate→parse round-trip, garbage-in-empty-cues, single-cue full-duration synthesis |
| `BlossomVttClient` | NIP-98 header construction, success / 400 / 401 / 403 / 404 / 409 / 5xx mapping. Mock `http.Client` |
| `SubtitleEditRepository` | Dual-write happy path; relay-failure-aborts-Blossom; Blossom-failure-returns-partial. All clients mocked |
| `SubtitleEditorCubit` | bloc_test: initial → editing on `CueTextChanged`, dirty flag transitions, saving → success / failure / partial transitions, discard-with-dirty fires confirmation event |
| `SubtitleEditorView` | Renders cues, save disabled until dirty, single-cue fallback when 0 cues, entry point hidden for non-author |
| Integration (E2E) | `integration_test/edit_captions_journey_test.dart`: register → publish video → open editor → change text → save → verify Kind 39307 on local relay carries new content. Uses local Docker stack per `e2e_testing.md` |

---

## Ship Checklist

1. Unit + bloc + widget tests pass at 100% coverage on new files.
2. New E2E test passes against `mise run e2e_test`.
3. Backend contract section above matches what the Blossom-side work actually ships (cross-check before merging).
4. Manual verification: edit a caption on your own video, observe new text on next play without app restart.
5. `flutter analyze lib test integration_test` clean.
6. Pre-commit and pre-push hooks pass (`mise run setup_hooks` if missing).

---

## v2 / Future Work (not in scope here, captured to keep options open)

- **Collaborator editing.** Two open primitives:
  - *NIP-26 delegated event signing.* Author signs a delegation token; collaborators sign Kind 39307 on the author's behalf so the address `39307:<author>:subtitles:<d-tag>` stays stable. Cleanest cryptographically but NIP-26 is rare in the wild and not implemented in this app today.
  - *Allowlist resolution.* Clients query Kind 39307 with the d-tag from author OR any listed editor pubkey, picking the most recent. Loses pointer simplicity but avoids NIP-26.
  - Pick one before shipping v2; both require Blossom server-side ACL changes the v1 server design should already accommodate.
- **Re-transcribe.** Server endpoint to re-run transcription with a different model or prompt; client triggers and polls.
- **Timing edits.** Per-cue start/end nudge, split, merge.
- **Add/delete cues.**
- **Multi-language tracks.** Author publishes multiple Kind 39307 events with different `language` tags; UI lets viewer pick.
- **Viewer "report bad captions"** signal that surfaces to the author.
