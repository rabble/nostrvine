---
name: e2e-test
description: |
  Run and debug Flutter E2E integration tests that exercise the real
  app against a local Docker backend (no mocks). Use when running
  E2E tests, debugging failures, or working on the local harness.
author: Claude Code
version: 1.1.0
---

# E2E Integration Testing

Goal: run the real app against a real local backend, end-to-end.
OAuth, relay subscriptions, and media uploads all hit local Docker
services — no mocks anywhere. Tests live in
`mobile/integration_test/`, backend in `local_stack/`.

## Run a test

Two terminals, from `mobile/`:

```bash
# Terminal 1 — emulator
mise run emulator

# Terminal 2 — tests
mise run e2e_test                                              # All auth tests
mise run e2e_test integration_test/auth/auth_journey_test.dart # Single test
```

`e2e_test` brings up the Docker stack, runs patrol, captures a
merged docker+logcat+app timeline at `test_reports/*.jsonl`, and
prints the native test XML path + failure excerpts when the APK
fails to install. **Never call `patrol test` directly** — you'll
lose the timeline and the diagnostics.

## Stack

| Service | Port | Purpose |
|---|---|---|
| Keycast | 43000 | OAuth + NIP-46 signer |
| FunnelCake Relay | 47777 | Nostr relay |
| FunnelCake API | 43001 | REST API |
| Blossom | 43003 | Media server |
| Postgres | 15432 | Keycast DB |

```bash
mise run local_up         # Start (auto-runs local_setup on fresh worktrees)
mise run local_up_cached  # Same, but reuse cached images (offline / rate-limited)
mise run local_down       # Stop
mise run local_reset      # Wipe data + restart
mise run local_status     # Health
```

If `local_up` fails only at `e2e-seed` and the services your test
actually needs are healthy (auth tests don't need the indexer),
bypass the seed:

```bash
bash ../local_stack/profile.sh integration_test/<your_test>.dart
```

## Emulator

```bash
mise run emulator           # Normal launch (auto-detects DISPLAY)
mise run emulator_headless  # Offscreen, no window
mise run emulator_wipe      # -wipe-data (storage exhausted)
```

Override AVD: `AVD_NAME=<name> mise run emulator`. Always uses
`-gpu host` — swiftshader can't render media_kit frames.

Skip the per-run reinstall with `PATROL_NO_UNINSTALL=true mise run
e2e_test ...` when iterating fast and the APK hasn't changed.
Stale-state debugging cost is yours.

Buffer auth-flow logs: `adb logcat -G 16M` (default 256 KB rotates
mid-flow).

## Patterns

### Launching the app

`pumpAndSettle` hangs because of persistent polling timers. Use
`launchAppGuarded` (from `test_setup.dart`) with error suppression
and a manual pump loop:

```dart
final originalOnError = suppressSetStateErrors();
final originalErrorBuilder = saveErrorWidgetBuilder();
launchAppGuarded(app.main);

for (var i = 0; i < 60; i++) {
  await tester.pump(const Duration(milliseconds: 250));
  if (find.text('Welcome').evaluate().isNotEmpty) break;
}

restoreErrorWidgetBuilder(originalErrorBuilder);
restoreErrorHandler(originalOnError);
drainAsyncErrors(tester);
```

### Async publish → relay query

UI navigates before publish/upload completes. Poll the relay:

```dart
for (var i = 0; i < 120; i++) {
  await tester.pump(const Duration(milliseconds: 500));
  events = await queryRelay(filter);
  if (events.isNotEmpty) break;
}
```

### Onboarding sheets blocking UI

New bottom sheets may cover the target widget:

```dart
for (var i = 0; i < 20; i++) {
  await tester.pump(const Duration(milliseconds: 250));
  final gotIt = find.text('Got it!');
  if (gotIt.evaluate().isNotEmpty) {
    await tester.tap(gotIt);
    break;
  }
}
```

### Patrol false positives

Patrol bundles every file in a target dir into one APK. When file B
runs, file A shows up as "not requested" `[E]` markers in logcat.
Trust only the final `✅`/`❌` lines.

### Provider error caching

Providers using `requireIdentity` (or similar non-nullable getters)
crash during cold start and Riverpod caches the error forever. Use
the nullable accessor (`currentIdentity`) and handle null.

### Material ancestor

`TextField` in an overlay/transition without `Scaffold` needs:

```dart
Material(color: Colors.transparent, child: TextField(...))
```

## Helpers

`integration_test/helpers/`:

- `test_setup.dart` — `launchAppGuarded`, error suppression, async-error drain
- `navigation_helpers.dart` — register, login, tap tabs, wait for widgets
- `relay_helpers.dart` — publish/query Nostr events
- `db_helpers.dart` — Postgres (verification tokens, refresh tokens)
- `http_helpers.dart` — Keycast API (verify email, forgot password)
- `constants.dart` — ports + `appPackage`

## Debugging

```bash
# Service logs
docker compose -f local_stack/docker-compose.yml logs keycast --tail=50
docker compose -f local_stack/docker-compose.yml logs blossom | grep -v 'path=/'

# Auth trace
adb logcat -d | grep 'flutter.*\[AUTH\]' | grep -v 'Router redirect'

# Last merged timeline
ls mobile/test_reports/*.jsonl
```

If patrol reports `Total: 0` with Gradle exit 1, the runner
auto-prints the native test XML path + failure excerpts — that's
an APK install failure, not a missing test. Free space with
`adb shell pm trim-caches 1G` or `mise run emulator_wipe`.
