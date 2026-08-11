# Maestro E2E tests

End-to-end UI tests written with **Maestro**, driving a real build against
**STAGING**.

They exist for fast, high-signal regression detection on critical user flows.
They are not a replacement for unit or widget tests.

## What the smoke suite covers today

`suites/smoke.yaml` runs the account-management paths — `loginFreshInstall`,
its `removeKeys` cleanup, and `loginEmailPwd` — plus all three social flows:
`likeFlow`, `commentFlow` (post a comment, delete it) and `searchUserFlow`
(find an account, open its profile, come back).

Nothing is held back any more. The last two were restored by
[#6952](https://github.com/divinevideo/divine-mobile/issues/6952) —
`commentFlow` had an `env`-vs-`output` bug and a disabled cleanup step, and
`searchUserFlow` needed a rewrite for the current search layout. Their
credentials (`SEARCH_USER` for `searchUserFlow`) must be present on the
runners.

### `likeFlow` was an app bug, not test data

`videoUnlike` used to hang, and the failure was filed as a test-data problem.
It was not. Unliking the only video in your own Liked feed makes the liked
grid's bloc re-emit an empty list into the still-open fullscreen route, and
the fullscreen screen rendered its loading placeholder for *any* empty list —
no timeout, no empty state, no error. Every action button left the tree, so
the flow's 15-second wait for the "Like video" label could never succeed.
Reproduced on device and fixed in
[#6949](https://github.com/divinevideo/divine-mobile/issues/6949); the feed
now settles on an explicit drained state carrying
`fullscreen_feed_empty`, which `assertVideoFeedDrained.yaml` asserts.

The lesson generalises: **before filing a Maestro failure as flaky data,
check whether the screen is stuck in a state the app has no exit from.**
A permanent loading placeholder looks exactly like slow live content.

The `e2e-smoke-ios` and `e2e-smoke-android` Codemagic workflows are
`triggering: events: []`, so nothing runs them automatically. They are manual
dispatches, and GitHub CI does not cover this lane at all.

## The recorder flows

Three of the recorder's five modes are covered, one flow each:

| Flow | Mode | Covers |
|---|---|---|
| `flows/captureModeFlow.yaml` | capture | open, drive the control rail, record a clip, delete it, close |
| `flows/lipSyncModeFlow.yaml` | lip-sync | open, drive the control rail, prove the shutter refuses without a sound and records with one, delete the clip, close |
| `flows/stopMotionModeFlow.yaml` | stop-motion | open, drive the control rail, shoot two stills, undo them, close |

Classic and upload are not covered yet.

The gate is lip-sync's own behaviour and it takes **both** shutter tests to
cover it. `lipSyncModeAudioGate` proves the shutter refuses with no sound
picked, which on its own is also what a permanently broken shutter does;
`lipSyncModeRecordClip` picks one and records against it. They run in that
order and cannot be swapped — the gate test needs the editor to hold no sound,
and the record test is what puts one there.

Picking a sound stays deterministic because the flow only ever touches the
picker's **Divine** tab, whose entries come from
`assets/sounds/sounds_manifest.json` and ship with the app. The Community tab
is the relay-backed one, and it is the live-content dependency this file names
elsewhere as the suite's main source of flakiness — no flow goes near it.

Every file in all three flows has been run green on a Galaxy SM-S942B. The
lip-sync and stop-motion tests were driven test-by-test against an
already-signed-in app rather than through their flow end to end, because the
device runs a German system locale and `loginFreshInstall`'s `clearState` drops
the per-app English override mid-run (see step 0b). The login and `removeKeys`
bookends of both flows are the same ones `captureModeFlow` already runs.

None of them is in **`smoke.yaml`**, and all three are deliberately off the iOS
lane:

- **They need real camera hardware.** Without a camera the bloc never reports
  `isCameraInitialized`, the record button stays disabled, and the recording
  and shutter tests hang on their first wait. The lens switch in the shared
  rail needs one too. The iOS Simulator has no camera at all; an Android
  emulator's virtual scene camera is enough, and a device is best.
- **The `…Open` tests alone** — the chrome assertions — do pass without a
  camera, because the viewfinder falls back to a placeholder and every control
  still renders. So does `lipSyncModeAudioGate`: the blocked shutter is
  rendered from the audio selection, not from the camera being ready.

Run one against a booted Android emulator or a connected device:

```bash
maestro --device <serial> test e2e/maestro/flows/captureModeFlow.yaml
maestro --device <serial> test e2e/maestro/flows/lipSyncModeFlow.yaml
maestro --device <serial> test e2e/maestro/flows/stopMotionModeFlow.yaml
```

### Reading state off an icon-only control

The cycling rail controls are asserted by their Semantics `value`
(`.*Square.*`, `.*3 seconds.*`, `.*Front camera.*`). That works: Flutter folds
`value` into the Android content description, and Maestro matches against it —
confirmed on device. Three things follow, all worth knowing before writing more
recorder selectors:

- **A selector may combine `id` with `text`**, and here it must: "Off" is the
  value of the flash control *and* the timer control — and, once its sheet is
  open, of the stabilization menu's own first row.
- **`selected: true` is readable too**, which is what `assertCaptureMode`,
  `assertLipSyncMode` and `assertStopMotionMode` use to prove the right mode is
  armed. The mode wheel renders an entry for every mode in every mode, so a
  bare `id: camera_mode_capture` would pass on the Upload tab just as happily.
- **`checked:` is how an on/off control reads.** The ghost-frame and grid
  toggles carry a Semantics `toggled` flag rather than a `value`, and Flutter
  maps that to the accessibility node's checked state, so
  `stopMotionModeControls` drives them with `checked: true` / `checked: false`.
  **Maestro does not print the flag in its run log** — the line reads
  `Assert that id: camera_ghost_frame_button is visible`, exactly as it would
  if the flag had been dropped, unlike `text:` and `enabled:` which both show
  up. It is genuinely applied: asserting `checked: true` against the toggle in
  its off state fails on device. Don't "fix" a `checked:` selector because the
  log looks bare; prove it with a deliberately-wrong assertion instead.

### What the three viewfinders share, and what tells them apart

All three *are* the capture stack: same close, next, delete, library button and
record button. Only the top bar's center slot and the control rail differ.

| | capture | lip-sync | stop-motion |
|---|---|---|---|
| `audio_chip` (center slot) | — | ✅ | — |
| `camera_stop_motion_budget` (center slot) | — | — | ✅ |
| `camera_flash_button` | ✅ | ✅ | ✅ |
| `camera_aspect_ratio_button` | ✅ | ✅ | ✅ |
| `camera_switch_camera_button` | ✅ | ✅ | ✅ |
| `camera_timer_button` | ✅ | ✅ | — |
| `camera_stabilization_button` | ✅ | ✅ | — |
| `camera_ghost_frame_button` | — | — | ✅ |
| `camera_grid_button` | — | — | ✅ |

Lip-sync and capture are the subset trap. Their rails are identical, so assert
only what each mode renders and `assertCaptureMode` passes on the Lip Sync tab,
because everything it checks is there. It asserts `audio_chip` *absent*, and
that one line is what keeps it honest. `video_editor_audio_chip_test.dart` pins
the anchor itself at the widget level.

Stop-motion is not that case, and its `assertNotVisible` block is there for a
different reason. Its rail and capture's are **disjoint**, not nested — capture
has timer and stabilization, stop-motion has ghost frame and grid — so each
assert already fails on the other's viewfinder on the rail alone. What settles
which viewfinder is up before either gets that far is the mode wheel's
`selected` state, asserted on the first line of all three files.

So the pairs those two asserts carry — `assertStopMotionMode` pinning timer and
stabilization absent, `assertCaptureMode` pinning ghost frame, grid and the
budget absent — are **leak guards**, not mode separators: they fail when a
control starts rendering in a mode that does not declare it, which nothing else
in the suite would catch. `video_recorder_capture_actions_test.dart` pins the
same split at the widget level.

Because flash, aspect ratio and the lens switch are unconditional, all three
modes *drive* them with the same three files — `utils/driveAspectRatioControl`,
`utils/driveLensControl`, `utils/driveFlashControl`. Capture and lip-sync wrap
those in `utils/driveCaptureRail.yaml`, which adds the timer and stabilization
controls they alone render; `stopMotionModeControls` calls the three directly
and adds ghost frame and grid. Each mode's `…Controls` test is a rail sequence
plus its own mode assert. A mode with yet another set composes the per-control
utils in its own order rather than skipping parts of someone else's.

### Things the flows depend on that are easy to break by accident

Shared:

- **Camera and mic pre-granted.** Each flow relaunches with
  `permissions: all: allow` rather than tapping through the native dialog,
  whose buttons are OS-localized copy. Note the relaunch deliberately does
  *not* clear state: on Android `pm clear` wipes the encrypted preferences the
  Nostr key lives in and would sign the account back out mid-flow.
- **Hardware for the guarded rail controls.** Flash (all three modes) and
  stabilization (capture and lip-sync) are driven behind an `enabled: true`
  guard, because both are disabled outright when the active lens has no flash
  unit or reports a single stabilization mode. Where the feature is missing the
  block prints `SKIPPED` rather than failing — check the run output before
  reading a green run as full rail coverage. Both were exercised for real on
  the SM-S942B's back lens.
- **Everything the recorder persists, which is more than the mode.** Four
  preferences survive a run and every one of them is asserted as a default
  somewhere: `camera_last_used_recorder_mode` (absent ⇒ Capture),
  `camera_last_used_lens` (absent ⇒ back, which the rail asserts first),
  `camera_last_used_stabilization` and `camera_grid_lines_enabled` (absent ⇒
  on, which `stopMotionModeControls` asserts first). Run from the top this is
  handled — `loginFreshInstall`'s `clearState` wipes all four — but a
  standalone run inherits whatever the last session left. A phone whose last
  session used the front lens fails the rail on its first `.*Back camera.*`,
  and the three flows leave the mode key on different values, so a
  `captureModeFlow` run straight after a lip-sync or stop-motion one, skipping
  the login step, opens on the wrong mode. When iterating standalone, either
  reset the keys or start from a flow that clears state.
- **An empty session when the rail is driven.** The aspect-ratio control is
  disabled once the session holds a clip, because clips of mixed ratios cannot
  share an editor timeline. `captureModeControls` therefore runs before the
  recording tests; lip-sync gets this for free, since nothing in that flow
  records. Stop-motion stills are not clips until the assemble, so its rail
  stays live mid-session — but `stopMotionModeControls` closes on its mode
  assert, which pins next and undo absent, so it needs the empty session
  anyway and the flow keeps the same order.

Capture only:

- **The recorder opening on Capture.** `openCaptureMode` asserts the mode
  rather than selecting it, so a standalone run against a device whose last
  session used another mode dies on `id: camera_mode_capture, selected` with no
  hint why. Reproduced on the iOS Simulator with the key left on `classic`.
  Selecting it there is not a one-liner: the wheel is a lazy `ListView`, so
  from Classic the Capture entry is not rendered at all.
- **Tap-to-toggle recording.** `HoldToRecordPreferenceService` defaults to
  false. On a device where a previous session turned hold-to-record on, the
  first tap does nothing and `captureModeRecordClip` fails on its wait.
  Stop-motion is immune: the record button disables long-press outright for any
  mode that captures stills.

Lip-sync only:

- **Reaching the mode at all.** `openLipSyncMode` selects rather than asserts,
  because the recorder falls back to Capture whenever the persisted key is
  absent and so never opens here on its own. It walks the wheel one entry at a
  time: Lip Sync sits two places from Capture, and the wheel is a lazy
  `ListView` that only builds entries near the armed one.
- **No sound picked before the gate test.** The selection lives in the editor
  provider rather than a preference, so a relaunch clears it — but an iterating
  run that already reached `lipSyncModeRecordClip`, or picked a sound by hand,
  has to relaunch before `lipSyncModeAudioGate` means anything again. Same for
  the rail: the aspect-ratio control is disabled once a clip exists, so
  `lipSyncModeControls` runs ahead of both.
- **The keyboard hides the confirm bar.** The picker's done button is anchored
  to the bottom of the sheet, so with the search keyboard up it is pushed off
  screen entirely. `lipSyncModeRecordClip` types its query and then calls
  `hideKeyboard` before touching the list. Skip that and the failure is a
  nasty one to read: the sound selects correctly, the tile turns green in the
  failure screenshot, and the run dies waiting on a button that is simply not
  in the hierarchy.
- **The sound is picked by title, from the manifest.** The test searches
  "Bruh Sound Effect" and asserts the title back off the first result, so a
  reordered or renamed manifest fails there rather than silently recording
  against a different sound. That title comes from the asset manifest, not
  l10n, so unlike the rest of the copy in this suite it reads the same in every
  locale. It is chosen for being 864ms — under the 6.3s maximum clip length, so
  confirming pops straight back instead of routing through the trim screen a
  longer sound would need.
- **The "add audio" snackbar is asserted by copy.** `DivineSnackbarContainer`
  takes no identifier, and adding one is a `divine_ui` change that drags that
  package's 100% coverage gate along with it — the same call `openRecorder`
  makes for the education sheet. It earns the copy dependency: without it the
  test only proves nothing happened, which is also what a dead button looks
  like. The two assertions in that test catch different failures and both are
  needed: the snackbar proves the gate *fired*, the still-visible
  `camera_close_button` proves no recording started behind it.

Stop-motion only:

- **Reaching the mode at all.** `openStopMotionMode` selects rather than
  asserts, for the same reason `openLipSyncMode` does. It taps the entry
  directly instead of hopping: Stop Motion sits next to Capture, so the lazy
  `ListView` has it built in both states this flow can arrive in. From Classic
  or Upload it would not be, same trap as everywhere else on this wheel.
- **The ghost-frame snackbar.** Each toggle raises a 4-second confirmation
  banner that floats over the bottom of the screen — the record and undo
  buttons included — so the controls test waits it out before handing over to
  the shutter test.
- **Undo leaving nothing behind.** Stills are written to the clip library as
  they are shot (the session is upserted on every frame, not on the assemble),
  so `stopMotionModeUndoFrame` is load-bearing teardown: undoing the last still
  is what drops the session's library row again.
- **Two stills, not one.** `stopMotionModeCaptureFrame` shoots twice and
  `stopMotionModeUndoFrame` undoes twice, with the first undo asserting the
  chrome is *still* up. That pairing is the only evidence the session
  accumulates rather than overwriting — shortening either test to one tap
  silently removes it. Verified the other way round on device: shoot once, undo
  once, and that assertion goes red.

Account creation is a precondition, not part of what is tested. The recorder
route itself is public (`appRouterRedirect` exempts it), but the only way in is
the feed's camera button and the feed is not public.

The stop-motion assemble step — "next", which collects the stills into a clip
and opens the editor — is out of scope on purpose: it leaves the recorder, and
the editor has no coverage to hand off to yet.

---

## Running them

Everything below runs from `mobile/`.

### 0. Install the CLI

```bash
curl -fsSL "https://get.maestro.mobile.dev" | bash
export PATH="$PATH:$HOME/.maestro/bin"
```

Not `brew install maestro`. That name resolves to an unrelated cask — "Maestro,
AI agent command center", ~680 MB — that installs a macOS app and no CLI, so
the next command still fails with `maestro: command not found`.

### 0b. Put the device's app UI in English

**The suite only runs against an English UI.** Not every selector is an id yet:
`loginFreshInstall` taps "Use Divine with no backup", `removeKeys` taps
"Cancel" / "Remove from device", `assertLogin` pins the three legal links. On a
German phone the app renders "Nutzungsbedingungen" and the run dies in the
first assert — which reads like a regression and isn't one.

CI runners are English, so this only bites locally — and locally it is
awkward, because the per-app override does not survive the suite:

```bash
# Android 13+, per app, without touching the system language:
adb shell cmd locale set-app-locales co.openvine.app --locales en-US
```

**`launchApp: clearState` wipes that again.** It runs `pm clear`, which drops
the package's locale override along with its data, so any flow that starts
from `loginFreshInstall` is back in the system language by its first assert.
On a non-English phone the options are a scratch flow that skips `clearState`,
or setting the system language. This is not a problem worth engineering around
— it disappears once the remaining copy selectors become identifiers.

### 1. Build the app

The environment is not optional: a PRODUCTION run would write test data to the
live relay. `fullRegression` additionally fails outright on a PRODUCTION build,
because `searchTags` asserts the `STG` badge.

```bash
# iOS Simulator
flutter build ios --simulator \
  --dart-define=DEFAULT_ENV=STAGING \
  --dart-define=GH_ACTIONS_PR_PREVIEW=true

# Android emulator
flutter build apk --debug \
  --dart-define=DEFAULT_ENV=STAGING \
  --dart-define=GH_ACTIONS_PR_PREVIEW=true
```

`GH_ACTIONS_PR_PREVIEW` is what opens the invite gate. Without it, account
creation stops at "Add your invite code" and every flow that signs up fails.
It sets `forceOpenOnboarding` on the invite client, so `getClientConfig()`
reports `OnboardingMode.open` and the gate self-redirects. The flag is named
for its original PR-preview use; it is not GitHub-Actions specific.

### 2. Supply credentials

Nothing is committed. CI reads these from the `maestro_e2e_credentials`
Codemagic group.

| Variable | Used by |
|---|---|
| `USER_EMAIL`, `USER_PWD` | `flows/loginEmailPwd.yaml` |
| `SEARCH_USER` | `flows/searchUserFlow.yaml` — an account that ranks in People results for its own name |
| `USER_KEYS`, `SEARCH_USER_ID`, `VIDEO_USER`, `VIDEO_DESCRIPTION`, `VIDEO_DATA`, `EXISTING_USERNAME` | `suites/fullRegression.yaml` |

Every entry point guards its own variables with `assertTrue`. A missing `-e`
resolves to the JavaScript value `undefined` rather than erroring, so without
that guard the suite would run against garbage and fail somewhere unrelated.

### 3. Run

```bash
# The smoke suite, as CI runs it
maestro test \
  -e USER_EMAIL=... -e USER_PWD=... -e SEARCH_USER=... \
  e2e/maestro/suites/smoke.yaml

# Or via the iOS helper, which boots a simulator and installs for you
MAESTRO_USER_EMAIL=... MAESTRO_USER_PWD=... MAESTRO_SEARCH_USER=... \
  bash e2e/maestro/scripts/ui_smoke_ios.sh
```

Pass `--device <udid>` when more than one simulator or emulator is running,
or Maestro may target a different one from the one you installed onto.

Failure artifacts — a screenshot and the command log — land in
`~/.maestro/tests/<timestamp>/`. Read the screenshot first; it is usually
faster than reasoning about the selector.

### Iterating

Most files under `tests/` and all of `asserts/` contain no `launchApp`, so
they run against whatever is already on screen. Get the app into position
once, then re-run a single assert in about three seconds instead of a
ten-minute flow. Please keep it that way — adding `launchApp` to an assert
breaks it for everyone.

---

## Layout

```
e2e/maestro
├── suites/    entry points (smoke, fullRegression)
├── flows/     multi-test journeys
├── tests/     single scenarios
├── asserts/   reusable screen assertions
├── utils/     navigation helpers
└── scripts/   runners and checks
```

`scripts/check_refs.sh` verifies every `runFlow:` path resolves,
case-sensitively. macOS is case-insensitive by default and the Android CI
runner is Linux, so a wrong-case reference passes locally and fails only in
CI. Run it after moving or renaming anything.

---

## Writing selectors

**Target `Semantics(identifier:)`, not copy.** The suite spent six months
broken because it asserted English strings that product and l10n moved on
from. Identifiers are snake_case and defined in
`mobile/lib/constants/semantic_ids.dart`; `divine_ui` components take a
`semanticIdentifier`.

If the element you need has no identifier, add one — that is a smaller change
than the assertion you would otherwise write, and it survives translation.

Four traps worth knowing:

- **Opacity 0 is invisible to Maestro, `IgnorePointer` is not.**
  `RenderOpacity`/`RenderAnimatedOpacity` drop their child from the semantics
  tree at `alpha == 0` (unless `alwaysIncludeSemantics`), so a faded-out
  control genuinely fails `assertVisible` — that is what the recorder's
  next/delete assertions rely on. A control that is only wrapped in
  `IgnorePointer` stays in the tree and will happily satisfy `assertVisible`
  while being untappable.
- **`TabBar` composes a compound label.** A tab reads as `"New\nTab 2 of 6"`,
  and Maestro matches the whole label, so a bare `New` does not match. Use a
  prefix (`New.*`) or the tab's identifier — never the `Tab N of M` count,
  which varies with feature flags and with whose profile you are on.
- **`env` is read-only inside `evalScript`.** Write to `output.*` and read it
  back as `${output.NAME}`; `${NAME}` still resolves to the `env` default.
  An empty default is worse than a wrong one: an empty pattern matches an
  empty-text node, so the assertion passes and proves nothing.
- **Matching is whole-label, case-insensitive, and `.` crosses newlines.**
  A row that merges several `Text`s exposes one label
  (`"Now\n • \nYou\nGreat vine"`), so `assertVisible: Great vine` fails
  where `text: ".*Great vine"` passes. Measured on Maestro 2.1.0.

---

## Environments and test data

The flows run against shared STAGING infrastructure. What each one actually
depends on, and how much of that is real:

| Dependency | Where | Still a risk? |
|---|---|---|
| "whichever video is newest in the New grid" | `videoLike`, `commentVideo` | Yes, but only that it is **playable**. Nothing asserts which video it is. |
| "the account has exactly one liked video" | `videoUnlike` | No. `loginFreshInstall` creates the account, so it starts at zero likes and `videoLike` adds exactly one. |
| a specific account existing and ranking first in search | `searchUserFlow` | Yes — and it also taps a hardcoded `point: 50%,32%`, which is the more fragile half. [#6952](https://github.com/divinevideo/divine-mobile/issues/6952) |
| a real comment left on a stranger's video | `commentFlow` | Yes — its `deleteComment` cleanup is commented out, so every run leaves one behind. [#6952](https://github.com/divinevideo/divine-mobile/issues/6952) |

Accounts and likes are self-owned: each run creates its own account and
`removeKeys` tears it down, so those are not shared-state coupling.

Treat an unexplained failure as possibly-data *after* ruling out a stuck
screen, not before — and check the screenshot either way.

`commentFlow` deletes the comment it posts, but that only cleans the
poster's view: measured on 2026-08-10, the app publishes a valid kind 5,
the STAGING relay stores it, and the relay keeps serving the deleted
kind 1111 to everyone else. Each run therefore still leaves a visible
comment on whichever video is first in the New grid.

`tests/removeKeys.yaml` is the teardown of every smoke flow and is what makes
runs repeatable: the Nostr key lives in the iOS keychain and survives both
`launchApp: clearState` and a full app uninstall, so if teardown does not run,
the next run starts already signed in.

---

## Ownership

Owned by QA. Developers are encouraged to run them locally, report failures,
and propose improvements. Because they act as release alarms, change flows
deliberately — and when navigation changes intentionally, update the affected
flows in the same PR.
