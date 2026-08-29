# Brainstorm: finishing the UploadManager decomposition scope (#6935)

Date: 2026-08-29
Seeded by: `tasks/findings_6935.md` (41 findings, all load-bearing hypotheses at 1.0)

## Problem Statement

#6935 asks for two **decisions**, not a predetermined refactor: (a) is the remaining
scope a package extraction, a smaller in-place decomposition, or an explicit rescope
of #4507's goal; and (b) should the pause/resume lifecycle be wired end-to-end or
removed. The investigation changed the premises under both questions, so the
decisions should be made against the evidence below rather than against #4507's
2-month-old framing.

## What changed under the original framing

1. **The in-place decomposition DID land and worked.** 2,889 → 1,684 lines (−41.7%)
   across #5569/#5574/#5589/#5601 in three days. Feature work then took it back to
   2,305 over eight weeks — entirely features, not re-tangling (F30).
2. **The re-inflation risk is already mitigated.** The god-file ratchet
   (`check_service_god_file_ceiling.sh`, #6932) landed **2026-08-12, after** the
   re-inflation window, and the file has been flat-to-declining since (2,317 → 2,305).
   The historical argument for "extract to a package so features can't pile back in"
   is now served by a cheaper, already-deployed mechanism (F31).
3. **#4507's justification for keeping pause/resume is false.** It said
   `UploadStatus.paused` "is rendered in the UI". Both display getters
   (`PendingUpload.statusText`, `.progressValue`) and `UploadProgressDialog` have
   **zero callers**; no pause affordance exists anywhere (F11).
4. **The blocker set grew, and 2 of #4507's 5 blockers are already port-solved.**
   10 → 13 app-layer imports since June. Crash reporting and thumbnails are already
   behind ports; `startUploadFromDraft` (160 lines) carries **8 of 9** remaining
   blockers on its own (F1, F32, F33).
5. **The Client tier is already packaged** — `blossom_upload_service` and
   `background_uploader` exist. Persistence, publishing and OS transfer are already
   out of `UploadManager` (F8, F37).
6. **The backend cannot support a true pause.** No server-side pause verb exists in
   either implementation; the session TTL is a hard **24 hours fixed at init**, never
   refreshed by chunk writes (F22, F38, F40, F41).

## Constraints

- `UI → BLoC/Cubit → Repository → Client`; repository packages take no Flutter deps
  (`.claude/rules/architecture.md`, #3338).
- `upload_manager.dart` is under a hard CI ceiling of **2317** lines with 12 lines of
  headroom; the broad file-size check is advisory and already satisfies AC5 (F7).
- `UploadStatus.paused` is a Hive-persisted enum case (`@HiveField(7)`) — removing it
  is a `data_foundation.md` migration decision (F18).
- Divine's resumable upload is a self-declared **Draft Divine Extension**, not a BUD;
  no NIP or BUD covers resumable/chunked/paused upload (F25, F27).
- Any pause UI would need copy in 22 locales.

## Prior Art

- #4507 (closed, partial): `lib/services/upload/` helpers — the pattern to preserve.
- Epic #4339 siblings #4506/#4508/#4510/#4512/#4515/#4516 all resolved as **in-place**
  splits, not package moves (F10).
- Closed issue #80 proposed adopting TUS; Divine built a custom control plane instead.

---

## Decision A — remaining scope

### A1. Full package extraction to `mobile/packages/upload_repository/`
Complete #4507's original goal: break the helper→god-file import cycle, port-invert
the remaining blockers, lift the core into a package with its own CI workflow.

**Layers:** Repository, Client. **Complexity: High.**

**Pros:** satisfies the original AC literally; own coverage gate; forces the
architecture boundary.

**Cons:** `startUploadFromDraft` reaches into `VideoEditorRenderService` (itself a
1,539-line baselined god file) and `StopMotionRenderService`; the editor decomposition
(#4513) is still open, so this is **blocked by another unfinished decomposition** (F9).
The blocker set grew +3 in two months, so a long-running extraction risks being stale
before it lands. Pays a large cost for a re-inflation guarantee the ratchet already
gives (F31).

**Does not handle:** the pause/resume decision; the editor chain it depends on.

### A2. Targeted in-place extraction of the draft-materialization cluster
Move the "produce a file from a draft" work out of `UploadManager` — stop-motion
materialization, multi-clip merge, metadata probe, temp-dir handling — into its own
app-layer collaborator, leaving `UploadManager` as pure upload orchestration.

**Layers:** Repository (service-layer). **Complexity: Medium.**

**Pros:** highest leverage available — kills **8 of 9** package blockers in one move
(F32); the extracted work is genuinely not upload orchestration; matches the epic's
shipped in-place pattern (F10); meaningfully shrinks the file under its ceiling; and
it is the natural **prerequisite** for A1 if the team ever wants the package.

**Cons:** does not produce a package, so #4507's literal AC stays unmet.

**Does not handle:** the remaining Flutter-plugin deps (`pro_video_editor`,
`path_provider`, `connectivity_plus`) that a pure-Dart package would also need gone.

### A3. Pure rescope — decide, document, close
Make no code change. Record that the Client tier is packaged, the in-place
decomposition landed, and the ratchet holds the line; rescope #4507's package goal as
explicitly not-planned.

**Layers:** none. **Complexity: Low.**

**Pros:** honest; costs nothing; the ratchet genuinely does prevent regrowth (F31).

**Cons:** leaves the import cycle (F34), ~105 lines of dead public surface (F35, F36),
and the editor coupling in place. The file stays 2,305 lines and hostile to review —
which is the user impact the issue actually names.

### A4. Structural cleanup + explicit deferral  ← *recommended*
Do the cheap, high-certainty structural work now — break the import cycle, delete the
provably dead surface, extract the draft materializer (A2) — and explicitly rescope the
`packages/upload_repository/` move as deferred behind the editor decomposition (#4513),
recorded on the issue rather than silently dropped.

**Layers:** Repository (service-layer). **Complexity: Medium.**

**Pros:** delivers every win that is available without touching the editor chain;
removes the back-edge that would block any future package lift; answers the issue's
"decide the scope" AC with a documented decision instead of an open question; keeps
each step independently revertable.

**Cons:** two-step story rather than one clean landing; someone must actually file/link
the deferral so it does not become another silently-dropped goal.

---

## Decision B — the pause/resume lifecycle

### B1. Delete the dead surface  ← *recommended*
Remove `pauseUpload`, `resumeUpload`, and the `UploadManager.retryUploadWithBackoff`
delegator, plus the two other provably-dead members; keep `UploadStatus.paused` as an
inert Hive tombstone; re-drive the cancel-race regression test without `resumeUpload`.

**Complexity: Low–Medium.**

**Pros:** the feature never shipped — its only caller ever was a demo file under
`lib/example/`, deleted 2025-07-23 (F13). #4507's stated reason to keep it is false
(F11). Deleting also **removes a latent defect**: with `paused` unwritable, the
`_pollUploadProgress` `case .paused:` that currently recurses forever (F15) becomes a
terminal branch rather than an infinite loop.

**Cons:** discards carefully-maintained code (F14) and costs a test rewiring, because
all three tests in `upload_manager_background_pause_test.dart` use `resumeUpload` as a
harness — including the one that guards the **production-wired** cancel race (F18).

**Open sub-decision:** `cancelUpload` is also production-dead but has a dedicated test
file and a mock, and cancellation is a far more plausible near-term product need than
pause. Recommend **keeping** it and flagging it separately rather than bundling it into
this deletion.

### B2. Wire pause/resume up end-to-end
Add the UI affordance, fix the blockers, ship it.

**Complexity: High.**

**Pros:** the service-layer machinery already exists and is race-guarded.

**Cons:** three hard gates before any button can ship — (1) Gap A: `_pollUploadProgress`
loops at 20 Hz forever on `paused`, with no timeout at any of five call sites (F15);
(2) Gap B: on the OS background leg a pause is a **restart from byte 0**, not a resume,
so pausing at 90% silently discards the transfer (F16) — a product decision, not a bug;
(3) the server gives a hard **24-hour** non-extendable ceiling and no pause verb (F40),
after which the session is `410 Gone`. Plus UI + 22 locales. Nobody has asked for this
in 13 months.

### B3. Delete only the provably-dead three; park pause/resume
Remove `recoverStuckUploadsForTest`, the `getNetworkTypeString` delegator, and the
`retryUploadWithBackoff` delegator (all zero callers *including tests*, so zero test
impact), and leave pause/resume pending an explicit product call.

**Complexity: Low.**

**Pros:** entirely safe; no test rewiring; strictly reduces surface.

**Cons:** leaves the issue's actual AC ("resolve the pause/resume decision") unresolved
— which is exactly how #4507 closed. Repeating that pattern is the failure mode #6935
was filed to correct.

---

## Recommendation

**A4 + B1.** The evidence supports resolving both questions now rather than deferring
again: the package move is blocked by work outside this issue's control and its main
benefit is already delivered by the ratchet, while pause/resume was never a shipped
feature and its stated justification does not hold. A4 delivers the real architectural
wins (cycle broken, editor coupling removed, dead surface gone) and leaves the package
move genuinely *possible* rather than merely aspirational; B1 closes the parked decision
and removes a latent infinite loop as a side effect.

**If the team disagrees on B**, B3 is the safe floor — but it should be taken knowingly,
because it reproduces #4507's outcome.

## Open Questions for /plan

- [ ] Keep or delete `cancelUpload` (production-dead, but has a dedicated test + mock
      and a plausible near-term product use)?
- [ ] Where does the extracted draft-materialization collaborator live — a new
      `lib/services/video_publish/` unit, or inside the video-editor service area?
- [ ] Tombstone vs full removal of `UploadStatus.paused` (`@HiveField(7)`).
- [ ] Which entry point re-drives the cancel-race test once `resumeUpload` is gone —
      `startUpload` or seeding `uploading` + `resumeInterruptedUpload`?

## Prerequisites

- [ ] Team sign-off on B (delete vs wire) — it is a product call, not a refactor call.
- [ ] Confirm the deferral of the package move is acceptable, and link it to #4513.

## Next Step

`/plan 6935` with A4 + B1, pending the two decisions above.

## Separately reportable gap found during this work

`local_stack` cannot exercise the resumable upload flow at all: there is no
data-plane service in `docker-compose.yml`, and `blossom-proxy/default.conf.template:4`
points `upload.divine.video` at the **control-plane** container. A well-formed
`POST /upload/init` therefore falls through to MinIO and returns a misleading
`BadRequest`. This is distinct from the known blossom-local blob-GET failure. Worth its
own issue.
