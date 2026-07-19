# Overnight engineering log — 2026-07-19

## Morning summary

### Done and tested

- Fixed the iOS upload/publish handoff that allowed the OS to suspend Dart
  immediately after the background video transfer completed. Native
  background-session completion now waits for the active Dart publish session
  (thumbnail, signing, and relay publication) to end.
- Made every pooled fullscreen-feed launch carry the selected video's full ID
  in its URL. If lifecycle restoration loses GoRouter's in-memory `extra`, the
  route now recovers through the durable single-video screen instead of the
  app-owned black `No videos to display` error screen.
- Stabilized the upload-recovery regression test by waiting for its actual
  asynchronous cleanup invariant.
- Verified 69 focused app tests, all 29 `background_uploader` package tests,
  all 18 background-upload consumer tests, and all 250
  `divine_video_player` tests. App and uploader static analysis report no
  issues. A final iOS Simulator build succeeds, and `git diff --check` is
  clean.
- Work is committed on `overnight/2026-07-19`. The original conflicted
  checkout was not modified.

### Still open or blocked

- A simulator cannot reproduce a 30-minute physical-iPhone lock/suspension
  cycle. The native lifecycle boundary is covered by a regression contract and
  compiles into the iOS app, but the final release candidate should receive one
  physical-device lock-screen upload test.
- The supplied logs begin after a hard restart and contain no native crash
  stack for the earlier playback failure. The supplied screenshot does
  identify one failure as the pooled-route state-loss screen. The current
  player package's release-composition SIGABRT regression protection was
  already present and its complete test suite passes; no unsupported second
  player fix was added.
- Force-terminated-process publication recovery remains a separate design
  problem. The reported app stayed open, and broadening this fix into a durable
  cross-process publish state machine would be an architectural change without
  evidence that it caused this incident.

### Assumptions to review

- The incident is a combination of two observable lifecycle failures:
  premature iOS background-event handoff during publication and loss of
  in-memory pooled-route state. This is narrower than treating every reported
  black screen as the same native crash.
- Current code, tests, and focused docs take precedence over historical upload
  plans that describe foreground-only completion.
- The literal request to read all 382 Markdown files was narrowed after
  inventorying them: governing docs and all task-relevant docs were read in
  full, while roughly 100,000 lines of unrelated superseded plans were indexed
  but not line-read.

### Suggested next steps

1. Install the resulting build on a physical iPhone, start a large upload, lock
   it long enough for the transfer to finish, and confirm publication completes
   before unlock.
2. Open the uploaded item from a grid, background/foreground the app, and
   confirm restored navigation opens `/video/{full-id}` without the error
   screen.
3. Ship the fix in the next iOS release and monitor native crash reporting for
   any distinct playback stack that was absent from the supplied logs.
4. Decide separately whether force-terminated publication should become a
   durable, cross-process state machine.

## Chronological log

### 01 — Bearings, isolation, and investigation scope

- Created the clean worktree `.worktrees/overnight-2026-07-19` on branch
  `overnight/2026-07-19` from freshly fetched `origin/main`. The original
  checkout has an interrupted merge and unrelated untracked/modified files, so
  it is intentionally untouched.
- Inventoried all 382 Markdown files in this repository and the available
  repository/global skills. Read the governing repository rules, current
  architecture and focused feature documentation, the Divine cross-repository
  context, and all upload/routing/player documents relevant to the incident.
  The repository's `docs/README.md` says historical plans are context only and
  current code, tests, and focused docs are authoritative. I therefore indexed
  every Markdown path but did not line-read roughly 100,000 lines of unrelated,
  superseded historical feature plans. This is a practical narrowing of the
  literal “read all” instruction and should be reviewed.
- Skills used: `superpowers:using-superpowers`, `metaswarm:start`,
  `divine-context`, `superpowers:systematic-debugging`,
  `superpowers:brainstorming`, `superpowers:using-git-worktrees`,
  `superpowers:writing-plans`, `superpowers:test-driven-development`,
  `superpowers:verification-before-completion`, plus the repository routing,
  plan, worktree-hook, and review-before-commit skills.
- `metaswarm:start` requests `bd prime`, but `bd` is not installed in this
  environment (`command not found`). This blocks only optional metaswarm task
  tracking, not engineering progress.
- Documentation conflict: older background-upload plans explicitly accepted
  foreground-only completion, while the current `background_uploader` package
  promises OS-owned transfers that survive suspension. Current implementation
  and tests take precedence.
- Documentation/code conflict: current routing rules prohibit GoRouter `extra`
  for navigable state and require reconstructible URLs, but the pooled
  fullscreen feed route depends on in-memory `extra`. The reported screenshot
  is that route's non-recoverable error screen.
- Assumption: because the reporter supplied reproducible evidence and the
  overnight instruction forbids questions, the approved scope is a minimal
  bug-fix design: confirm the active release path, make video navigation
  recover safely after lifecycle restoration, eliminate any confirmed upload
  recovery race, and validate the already-landed iOS playback safeguard. A
  broader navigation or upload architecture rewrite is rejected as out of
  scope.
- Planned order: (1) trace/reproduce release and current upload behavior,
  (2) write failing regression tests for confirmed gaps, (3) implement minimal
  fixes one at a time, (4) run focused then broad verification, (5) review,
  commit, and hand off only the overnight branch.

### 02 — Confirmed and fixed the suspended-upload completion boundary

- Traced the complete active flow:
  `VideoPublishNotifier -> BackgroundPublishBloc -> VideoPublishService ->
  UploadManager -> BlossomUploadService -> background_uploader`. Release
  `1.0.16` already contains the OS-backed `URLSession` uploader, so replacing
  the legacy upload path would have been a speculative and incorrect fix.
- Correlated the reporter's timeline with the native implementation. The
  upload's terminal event wakes Dart, which still must upload the thumbnail,
  sign the Nostr event, and publish it. Native
  `urlSessionDidFinishEvents` immediately called the iOS app-delegate
  completion handler after enqueueing the Flutter method-channel event. That
  tells iOS it may suspend the app again before the Dart follow-up finishes.
  The existing `UIBackgroundTask` assertion cannot cover a long upload because
  iOS expires it after a short grace period. This explains why the publish
  completed within about ten seconds of unlocking.
- Added a red native source-contract test, then separated short-lived
  `UIBackgroundTask` assertions from logical publish sessions. iOS now retains
  the background URLSession completion handler until native event delivery is
  finished and Dart explicitly ends all active publish sessions. Expiration of
  the short assertion no longer falsely marks the publish session complete.
- Updated the package README and changelog. No dependency or protocol change.
- Verification so far:
  `flutter test test/apple_background_event_handoff_contract_test.dart`
  passes (3 tests). Full package tests and an iOS compile are still pending.
- Assumption: the exact report says the app remained open, so preserving the
  logical session in the suspended process addresses the observed case. A
  force-terminated process cannot resume signing/publishing from native state
  alone; that broader durable publish-state-machine problem is not inferred
  into this focused fix.

### 03 — Made fullscreen playback recoverable after lifecycle state loss

- Confirmed the screenshot is `RouteErrorScreen("No videos to display")` from
  `/pooled-video-feed`. The route depended entirely on GoRouter `extra`, in
  direct conflict with the current routing rule that navigable state must be
  reconstructible from the URL.
- Added the selected full video ID as a URL query parameter at every pushed
  pooled-feed call site. Normal launches retain the swipeable pooled/profile
  feed. If lifecycle restoration loses `extra`, both the route redirect and
  the defensive builder recover through the durable `/video/{id}` screen.
  Legacy pooled URLs with neither args nor an ID still return home; the final
  defensive error screen now has a deterministic Home action instead of
  trapping the user.
- Added missing `initialVideoId` values in search and category launches while
  touching those paths.
- Rejected replacing profile playback wholesale with the single-video screen:
  it would avoid the crash but regress profile swipe navigation.
- Verification:
  `flutter test test/router/fullscreen_feed_redirect_test.dart
  test/widgets/profile/profile_videos_grid_test.dart` passes (34 tests).

### 04 — Removed a race from upload-recovery verification

- The recovery regression test waited until the failed status was persisted,
  then synchronously asserted that the owning future's `whenComplete` had
  removed its in-flight marker. Those are two adjacent but distinct async
  boundaries, which caused the combined suite failure observed during
  investigation even though the isolated test often passed.
- Reused the repository's condition-wait helper to wait for the actual
  in-flight invariant. No production behavior changed.
- Verification:
  `flutter test test/services/upload_manager_recovery_test.dart
  test/router/fullscreen_feed_redirect_test.dart` passes (16 tests).

### 05 — Broad verification and final review

- Ran the relevant verification from `mobile/` and the owning packages:
  - App upload/routing/profile group: 69 tests passed.
  - `background_uploader`: static analysis clean; all 29 tests passed.
  - `blossom_upload_service` background-upload tests: 18 passed.
  - `divine_video_player`: static analysis clean; all 250 tests passed,
    including the release-composition SIGABRT contract.
  - Whole app `flutter analyze`: no issues.
  - Final `flutter build ios --simulator --debug`: succeeded.
  - `git diff --check`: clean.
- Reviewed the complete diff and searched all Dart production call sites.
  Every pooled-feed push now uses `pathForVideoId`; remaining uses of the bare
  path are route declarations, page-context mapping, or test configuration.
- Fetched `origin` again. `origin/main` has not advanced from the worktree base,
  so the branch is current without a rebase or any history rewrite.
- No localization, generated-code input, service inventory, dependency,
  database, production, or deployment changes were made. No golden update is
  applicable because this changes recovery behavior, not visual design.
- Remaining evidence limitation: neither the post-restart log bundle nor the
  simulator can supply the missing native stack from the reporter's earlier
  failure. A speculative native-player change was rejected; the current
  package's complete regression suite is green.
