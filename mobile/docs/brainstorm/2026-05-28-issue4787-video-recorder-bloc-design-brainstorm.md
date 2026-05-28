# Brainstorm: WS-2 PR1 — `VideoRecorderBloc` core design

Date: 2026-05-28

## Problem Statement

`mobile/lib/providers/video_recorder_provider.dart` (1,409 LOC) is the
last big-provider migration for #4744. The plan calls for 3 PRs:
PR 1 (Cubit core, additive), PR 2 (widget consumers, ~19 files),
PR 3 (delete provider).

PR 1 is structurally bigger than the other lane PRs because the
provider has cross-cutting integrations the prior settings cubits
didn't: BuildContext-taking navigation methods, `ref.read` crossings
into other Riverpod-owned services, lifecycle observer callbacks from
the camera service, and 8 mutable instance fields that need to move
into state. This doc resolves the design questions so PR 1 can be
implemented as a careful line-by-line port rather than a redesign.

## Constraints

- `state_management.md`: no Flutter SDK dependency from BLoCs — no
  `BuildContext`, no `Navigator`, no `WidgetsBinding`. Navigation calls
  must move to the View layer.
- `state_management.md`: no mutable instance variables on a BLoC —
  the 8 fields the provider holds (`_baseZoomLevel`, `_isDestroyed`,
  `_snappedTo1x`, `_lastRawZoom`, `_snapTime`, `_isStartingRecording`,
  `_isStoppingRecording`, `_remoteRecordControlEnabled`) move into
  state.
- R1 risk (recording-race): `startRecording` / `stopRecording` need
  `transformer: sequential()` — that's a Bloc (not Cubit) feature, so
  the class is a Bloc with events.
- "No half-finished refactors": PR 1 ships a complete Bloc with all
  events handled, even though widgets won't switch until PR 2.

## Prior Art

- `tasks/plan_4744.md` §4 WS-2 — the 3-PR plan.
- `mobile/lib/providers/video_recorder_provider.dart` — the provider
  being ported. 1,409 LOC.
- `mobile/lib/models/video_recorder/video_recorder_provider_state.dart`
  — the existing state model (148 LOC).
- `mobile/lib/models/video_recorder/video_recorder_state.dart` — the
  recording-lifecycle enum (idle / recording / error). **Name clash
  with the obvious bloc-state class name — see Decision D1 below.**
- Cubit / Bloc templates from this session: #4791 (subscribing on
  stream), #4794 (`Future<Result>`-return transients), #4795 (action-
  result enum), #4798 (lifecycle mixin stays in View). All apply.

## Design Decisions

### D1. State class naming (name clash)

Problem: the existing model `VideoRecorderState` is an enum (recording
lifecycle: `idle / recording / error`). The natural Bloc state class
name `VideoRecorderState` clashes.

Pick: **`VideoRecorderBlocState`** for the new class. File name
`lib/blocs/video_recorder/video_recorder_bloc_state.dart`. The enum
keeps its name and import.

### D2. `BuildContext`-taking navigation methods

Provider has 3 methods that take `BuildContext` and call `context.pop()`
/ `context.push(...)`:

- `closeVideoRecorder(BuildContext)` — pop or go-home.
- `openVideoEditor(BuildContext)` — navigate to VideoEditor /
  VideoMetadata depending on `recorderMode.hasVideoEditor`.
- `openLibrary(BuildContext)` — navigate to library.

Pick: **Drop from Bloc surface entirely.** These move to top-level
helper functions in `video_recorder_screen.dart` (the eventual Page
after WS-2 PR2's Page/View split). Widgets that currently call
`ref.read(videoRecorderProvider.notifier).closeVideoRecorder(context)`
will (in PR 2) call `closeVideoRecorder(context)` directly.

For `openVideoEditor`, the helper reads `recorderMode.hasVideoEditor`
from the cubit state and the optional `videoEditorProvider.notifier`
side-effect (`startRenderVideo()`) stays in the helper as a Riverpod
call. The View has both ref + bloc, so this is the cleanest split.

### D3. `ref.read` crossings into other providers

Provider does `ref.read(...)` on:

- `videoEditorProvider` — for `selectedSound != null` and for
  `notifier.startRenderVideo()`.
- `clipManagerProvider` (and `.notifier`) — for clip duration tracking
  on start/stop, addClip, saveClipToLibrary, updateClipDuration,
  updateThumbnail, updateGhostFrame.
- `sharedPreferencesProvider` — for `_kLastUsedCameraLensKey` +
  `kLastUsedRecorderModeKey` persistence.

Pick: **Two injection patterns based on usage:**

1. **Snapshot-callable typedefs** for read-only point-in-time checks.
   `VideoEditorSelectedSoundLookup = bool Function()` returning
   `selectedSound != null`. Page wires
   `() => ref.read(videoEditorProvider).selectedSound != null`.

2. **Service reference injection** for mutating actions on a
   long-lived notifier. `ClipManagerActions` typedef exposes the
   subset of methods the cubit calls (`startRecording`, `stopRecording`,
   `remainingDuration`, `addClip`, `saveClipToLibrary`,
   `updateClipDuration`, `updateThumbnail`, `updateGhostFrame`,
   `clips`, `resetRecording`). Page wires
   `ref.read(clipManagerProvider.notifier)` and passes it (or an
   adapter). `SharedPreferences` is passed directly (already a
   first-class object).

This keeps the bloc free of Riverpod imports.

### D4. `CameraService` callback wiring

Provider sets 3 callbacks on the camera service:

- `onUpdateState({forceCameraRebuild})` — service-driven state
  refresh.
- `onAutoStopped(EditorVideo)` — service detected max-duration hit.
- `onRemoteRecordTrigger` — volume / Bluetooth media button.

Pick: **Cubit sets these callbacks in its constructor (or first event
handler) after the service is injected.** Each callback does
`add(...)` with the appropriate event:

- `onUpdateState` → `add(VideoRecorderCameraStateRefreshed(...))`
- `onAutoStopped` → `add(VideoRecorderStopRequested(result))`
- `onRemoteRecordTrigger` → `add(VideoRecorderToggleRecordingRequested())`

This converts callback-driven side effects into events, which is the
canonical Bloc pattern. Cancel + null-out in `close()`.

### D5. `ref.onDispose` cleanup

Provider does `ref.onDispose(async { ... })` with 4 cleanup paths:
focus timer, audio playback service dispose, camera service dispose,
`_isDestroyed = true` flag.

Pick: **`Cubit.close()` override.** Set `state.copyWith(isDestroyed:
true)` first, then run the 4 cleanups in order. The focus timer
(originally a `Timer? _focusPointTimer` instance field) becomes a
non-state instance field that's an OK exception to "no mutable
instance vars" because it's strictly cleanup-only (not part of state
identity, not read by handlers as logic input — same exception
already noted in the rule book for stream subscriptions).

### D6. `transformer: sequential()` scope

Pick: **Apply to `startRecording` and `stopRecording` events only.**
The other events (set zoom, toggle flash, set aspect ratio, etc.) are
fine concurrent.

### D7. Snap-to-1.0x detent logic

The pinch-to-zoom snap-to-1x state machine reads 3 instance fields
(`_snappedTo1x`, `_lastRawZoom`, `_snapTime`) inside
`handleScaleStart` and `handleScaleUpdate`.

Pick: **All 3 fields move into state.** The handler emits new state
with updated detent bookkeeping. `DateTime.now()` calls stay inside
the handler (testable via a clock injection if needed, but not for
PR 1).

### D8. Async chained operations in `stopRecording`

The provider's `stopRecording` does:
1. Stop the camera service
2. Disable wakelock
3. Update clip manager
4. Add clip
5. Save clip (fire-and-forget initial save)
6. Read video metadata via `ProVideoEditor`
7. Generate thumbnail
8. Generate ghost frame
9. Re-save clip with enriched metadata
10. Cleanup work-copy file

Pick: **Port verbatim** — the sequence is correctness-critical (the
file-swap race comment at L853 is a documented hazard). Don't try to
optimize or parallelize. Wrap the whole flow in a single event handler
under `sequential()`.

## Implementation Sequence

For the next session:

1. **State class** (`video_recorder_bloc_state.dart`) — port
   `VideoRecorderProviderState`'s 17 fields + add 8 ex-instance fields
   per D7. `copyWith` with `clearXxx` flags for nullable fields.
   `Equatable` + props.

2. **Events** (`video_recorder_event.dart`) — sealed class with one
   event per provider public method (minus the 3 navigation methods
   per D2). ~25 events. Each event captures its parameters.

3. **Bloc** (`video_recorder_bloc.dart`) — constructor takes
   `CameraServiceFactory`, `CountdownSoundServiceFactory`,
   `AudioPlaybackServiceFactory`, `VideoEditorSelectedSoundLookup`,
   `ClipManagerActions`, `SharedPreferences`, `VideoThumbnailService`
   (or factory). Register handlers via `on<Event>(handler,
   transformer: sequential())` only for start/stop; concurrent for
   the rest. `close()` runs the D5 cleanup.

4. **Tests** — focused on the R1 risk + state class basics. At
   minimum:
   - State class `props` / `copyWith` round-trip.
   - `sequential()` ordering under simultaneous Start + Stop events
     (one of the original concurrency hazards).
   - `Start` happy path (mock camera service returns success).
   - `Stop` happy path (mock camera service returns a recorded video).
   - `Start` rejected when canRecord is false.
   - `Stop` short-circuit when already stopping.

5. **PR notes** — document the 8 design decisions inline so reviewers
   can map back to this brainstorm.

## Estimated Scope

- State class: ~250 LOC (with copyWith + props for 25 fields).
- Events: ~150 LOC sealed class.
- Bloc: ~700-900 LOC (faithful port of all handlers).
- Tests: ~300 LOC.
- **Total: ~1400-1600 LOC** of new code. Plus ~30 minutes of
  cross-checking the original provider's flow line-by-line.

## Risks

- **R1 (recording race)** — mitigated by D6 (sequential), D7 (state-
  resident flags), and porting `stopRecording` verbatim per D8. Tests
  pin the ordering invariant.
- **R2 (callback adapter leaks)** — `add(...)` from inside a service
  callback runs on whatever isolate / async zone the service uses.
  Bloc's event queue is safe across isolates but D4 should be
  verified by a unit test that fires the camera callback and asserts
  the expected event is emitted.
- **R3 (close-during-async)** — every `await` inside a handler should
  be followed by `if (state.isDestroyed) return;` or `if (isClosed)
  return;`. The provider's `_isDestroyed` checks port directly.

## Next Step

`/plan tasks/plan_4787.md` (or similar) — produce the implementation
spec with this brainstorm baked in. Then implement in a single focused
session.
