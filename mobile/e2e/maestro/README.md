# Maestro E2E tests

End-to-end UI tests written with **Maestro**, driving a real build against
**STAGING**.

They exist for fast, high-signal regression detection on critical user flows.
They are not a replacement for unit or widget tests, and they do not cover
camera or recording.

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

---

## Running them

Everything below runs from `mobile/`.

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

Two traps worth knowing:

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
