# Maestro E2E tests

End-to-end UI tests written with **Maestro**, driving a real build against
**STAGING**.

They exist for fast, high-signal regression detection on critical user flows.
They are not a replacement for unit or widget tests.

## What the smoke suite covers today

`suites/smoke.yaml` currently runs the account-management paths that pass end
to end today: `loginFreshInstall`, its `removeKeys` cleanup, and
`loginEmailPwd`. The social flows are held back because they cannot pass yet:

| Flow | Why it is out | Tracking |
|---|---|---|
| `likeFlow` | `videoUnlike` never completes; the liked video does not finish loading against live STAGING content | [#6949](https://github.com/divinevideo/divine-mobile/issues/6949) |
| `commentFlow` | `env`-vs-`output` bug and a disabled cleanup step | [#6952](https://github.com/divinevideo/divine-mobile/issues/6952) |
| `searchUserFlow` | needs a rewrite for the current search layout | [#6952](https://github.com/divinevideo/divine-mobile/issues/6952) |

So a green smoke run proves the harness, the build, account creation, cleanup,
and the sign-in path — not the social flows. Restore each flow in the PR that
fixes it, and put back the credentials it needs (`SEARCH_USER` for
`searchUserFlow`) in the same change.

The `e2e-smoke-ios` and `e2e-smoke-android` Codemagic workflows are
`triggering: events: []`, so nothing runs them automatically. They are manual
dispatches, and GitHub CI does not cover this lane at all.

## The recorder flows

Two of the recorder's five modes are covered, one flow each:

| Flow | Mode | Covers |
|---|---|---|
| `flows/captureModeFlow.yaml` | capture | open, drive the control rail, record a clip, delete it, close |
| `flows/lipSyncModeFlow.yaml` | lip-sync | open, drive the control rail, prove the shutter is gated on picking a sound, close |

Classic, stop-motion and upload are not covered yet.

Lip-sync is the short one on purpose. **Recording a lip-sync clip is out of
scope**: the shutter is gated on a selected sound, and picking one means
driving the audio sheet against whatever the relay is serving — the same
live-content dependency this file already names as the suite's main source of
flakiness. What `lipSyncModeAudioGate` covers instead is the gate, which is the
only behaviour lip-sync adds over capture.

Every file in both flows has been run green on a Galaxy SM-S942B. The lip-sync
tests were driven test-by-test against an already-signed-in app rather than
through `lipSyncModeFlow.yaml` end to end, because the device runs a German
system locale and `loginFreshInstall`'s `clearState` drops the per-app English
override mid-run (see step 0b). The login and `removeKeys` bookends of that
flow are the same ones `captureModeFlow` already runs.

Neither is in **`smoke.yaml`**, and both are deliberately off the iOS lane:

- **They need real camera hardware.** Without a camera the bloc never reports
  `isCameraInitialized`, the record button stays disabled, and the recording
  test hangs on its first wait. The lens switch in the shared rail needs one
  too. The iOS Simulator has no camera at all; an Android emulator's virtual
  scene camera is enough, and a device is best.
- **The `…Open` tests alone** — the chrome assertions — do pass without a
  camera, because the viewfinder falls back to a placeholder and every control
  still renders. So does `lipSyncModeAudioGate`, which is driven by the audio
  selection rather than the camera.

Run one against a booted Android emulator or a connected device:

```bash
maestro --device <serial> test e2e/maestro/flows/captureModeFlow.yaml
maestro --device <serial> test e2e/maestro/flows/lipSyncModeFlow.yaml
```

### Reading state off an icon-only control

`utils/driveCaptureRail.yaml` asserts the icon-only rail controls by their
Semantics `value` (`.*Square.*`, `.*3 seconds.*`, `.*Front camera.*`). That
works: Flutter folds `value` into the Android content description, and Maestro
matches against it — confirmed on device. Two things follow, both worth
knowing before writing more recorder selectors:

- **A selector may combine `id` with `text`**, and here it must: "Off" is the
  value of the flash control *and* the timer control — and, once its sheet is
  open, of the stabilization menu's own first row.
- **`selected: true` is readable too**, which is what `assertCaptureMode` and
  `assertLipSyncMode` use to prove the right mode is armed. The mode wheel
  renders an entry for every mode in every mode, so a bare
  `id: camera_mode_capture` would pass on the Upload tab just as happily.

### What the two viewfinders share, and what tells them apart

Lip-sync *is* the capture stack: same close, next, delete, library button,
record button, and the same five rail controls in the same order, because it
declares the same countdown-timer and stabilization support. The **only**
element that differs is the sound picker it puts in the top bar's center slot,
which capture mode leaves empty.

That makes the two asserts a subset trap. Assert only what each mode renders
and `assertCaptureMode` passes on the Lip Sync tab, because everything it
checks is there. So it asserts `audio_chip` *absent*, and that one line is what
keeps it honest. `video_editor_audio_chip_test.dart` pins the anchor itself at
the widget level.

Because the rail is shared, both modes also *drive* it with the same file —
`utils/driveCaptureRail.yaml`. Each mode's `…Controls` test is that util plus
its own mode assert. Modes that render a different set (stop-motion adds a
ghost-frame and grid toggle and drops timer and stabilization) will want their
own sequence rather than this one with parts skipped.

### Things the flows depend on that are easy to break by accident

Shared:

- **Camera and mic pre-granted.** Each flow relaunches with
  `permissions: all: allow` rather than tapping through the native dialog,
  whose buttons are OS-localized copy. Note the relaunch deliberately does
  *not* clear state: on Android `pm clear` wipes the encrypted preferences the
  Nostr key lives in and would sign the account back out mid-flow.
- **Hardware for two of the five rail controls.** Flash and stabilization are
  driven behind an `enabled: true` guard, because both are disabled outright
  when the active lens has no flash unit or reports a single stabilization
  mode. Where the feature is missing the block prints `SKIPPED` rather than
  failing — check the run output before reading a green run as full rail
  coverage. Both were exercised for real on the SM-S942B's back lens.
- **Everything the recorder persists, which is more than the mode.** Three
  preferences survive a run and each is asserted as a default somewhere:
  `camera_last_used_recorder_mode` (absent ⇒ Capture), `camera_last_used_lens`
  (absent ⇒ back, which the rail asserts first) and
  `camera_last_used_stabilization`. Run from the top this is handled —
  `loginFreshInstall`'s `clearState` wipes all three — but a standalone run
  inherits whatever the last session left. A phone whose last session used the
  front lens fails the rail on its first `.*Back camera.*`, and the two flows
  leave the mode key on different values, so a `captureModeFlow` run straight
  after a lip-sync one, skipping the login step, opens on the wrong mode. When
  iterating standalone, either reset the keys or start from a flow that clears
  state.
- **An empty session when the rail is driven.** The aspect-ratio control is
  disabled once the session holds a clip, because clips of mixed ratios cannot
  share an editor timeline. `captureModeControls` therefore runs before the
  recording tests; lip-sync gets this for free, since nothing in that flow
  records.

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

Lip-sync only:

- **Reaching the mode at all.** `openLipSyncMode` selects rather than asserts,
  because the recorder falls back to Capture whenever the persisted key is
  absent and so never opens here on its own. It walks the wheel one entry at a
  time: Lip Sync sits two places from Capture, and the wheel is a lazy
  `ListView` that only builds entries near the armed one.
- **No sound picked, ever.** Nothing in the flow selects one, which is what
  keeps `lipSyncModeAudioGate` meaningful and the aspect-ratio control enabled.
  The selection lives in the editor provider rather than a preference, so a
  relaunch clears it — but an iterating run that picked a sound by hand has to
  relaunch before the gate test means anything again.
- **The "add audio" snackbar is asserted by copy.** `DivineSnackbarContainer`
  takes no identifier, and adding one is a `divine_ui` change that drags that
  package's 100% coverage gate along with it — the same call `openRecorder`
  makes for the education sheet. It earns the copy dependency: without it the
  test only proves nothing happened, which is also what a dead button looks
  like. The two assertions in that test catch different failures and both are
  needed: the snackbar proves the gate *fired*, the still-visible
  `camera_close_button` proves no recording started behind it.

Account creation is a precondition, not part of what is tested. The recorder
route itself is public (`appRouterRedirect` exempts it), but the only way in is
the feed's camera button and the feed is not public.

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
| `SEARCH_USER` | `flows/searchUserFlow.yaml` — `fullRegression` only |
| `USER_KEYS`, `SEARCH_USER_ID`, `VIDEO_USER`, `VIDEO_DESCRIPTION`, `VIDEO_DATA`, `EXISTING_USERNAME` | `suites/fullRegression.yaml` |

Every entry point guards its own variables with `assertTrue`. A missing `-e`
resolves to the JavaScript value `undefined` rather than erroring, so without
that guard the suite would run against garbage and fail somewhere unrelated.

### 3. Run

```bash
# The smoke suite, as CI runs it
maestro test \
  -e USER_EMAIL=... -e USER_PWD=... \
  e2e/maestro/suites/smoke.yaml

# Or via the iOS helper, which boots a simulator and installs for you
MAESTRO_USER_EMAIL=... MAESTRO_USER_PWD=... \
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

Three traps worth knowing:

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

---

## Environments and test data

The flows run against shared STAGING infrastructure and depend on live
content: whichever video is newest in the New grid, a specific account
existing and ranking first in search. They also create a real account per run
and publish real likes and comments.

That is the suite's main source of flakiness and it is not fixable by
improving selectors. Treat an unexplained failure as possibly-data before
assuming a regression, and check the screenshot.

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
