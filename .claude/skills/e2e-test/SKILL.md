---
name: e2e-test
description: |
  Run and debug E2E integration tests against the local Docker stack.
  Covers emulator setup, stack management, test execution, log capture,
  and common failure patterns. Use when running E2E tests, debugging
  test failures, or setting up the local test infrastructure.
author: Claude Code
version: 1.0.0
---

# E2E Integration Testing

End-to-end tests run the full app against a local Docker backend stack.
They exercise real OAuth flows, relay subscriptions, and media uploads
with no mocks.

## Quick Start

```bash
cd mobile/
mise run local_up        # Start Docker stack
mise run e2e_test        # Run all E2E tests with profiling
mise run e2e_test integration_test/auth/auth_journey_test.dart  # Single test
mise run local_down      # Stop Docker stack
mise run local_reset     # Wipe data and restart
mise run local_status    # Check service health
```

**Always use `mise run e2e_test`** — it handles `local_up`, log profiling,
and merged timeline reports. Never call `patrol test` directly.

## Local Docker Stack

Located in `local_stack/`. Services:

| Service | Host Port | Purpose |
|---------|-----------|---------|
| Keycast | 43000 | OAuth + NIP-46 signer |
| FunnelCake Relay | 47777 | Nostr relay (WebSocket) |
| FunnelCake API | 43001 | REST API |
| Blossom | 43003 | Media server |
| Postgres | 15432 | Keycast database |

All GHCR images are **public** — no Docker login needed. If pulls fail with
`denied`, check if you have a stale `docker login ghcr.io` session. A stale
token causes Docker to send bad credentials instead of falling back to
anonymous access. Fix: `docker logout ghcr.io`.

### Stack Won't Start

If `mise run local_up` fails on image pulls:
```bash
# Use cached images, skip pulling
COMPOSE_FILE=../local_stack/docker-compose.yml docker compose up -d --pull=missing
```

Then run the test script directly:
```bash
bash ../local_stack/profile.sh integration_test/auth/
```

## Android Emulator

### Setup

The emulator reaches the host via `10.0.2.2`. Port constants are in
`lib/models/environment_config.dart` and re-exported by
`integration_test/helpers/constants.dart`.

### Linux / Hyprland Launch

```bash
DISPLAY=:1 ANDROID_AVD_HOME=/home/daniel/.config/.android/avd \
  emulator -avd Medium_Phone_API_36.1 -gpu host -no-snapshot-load
```

Always use `-gpu host` for video rendering (swiftshader can't render
media_kit frames).

### Storage Issues

Repeated APK installs fill `/data`. Symptoms: `INSTALL_FAILED_INSUFFICIENT_STORAGE`
or 0 tests discovered with Gradle exit code 1.

```bash
# Check space
adb shell df -h /data

# Free space
adb shell pm trim-caches 1G

# Nuclear option: wipe emulator
emulator -avd <name> -gpu host -wipe-data
```

### Logcat Buffer

Default 256KB is too small — auth flow logs rotate before critical phases.

```bash
adb logcat -G 16M          # Increase to 16MB
adb logcat -c              # Clear before test run
adb logcat -d | grep 'flutter.*\[AUTH\]'  # Capture auth flow
```

Filter by PID to isolate test cases (each patrolTest runs in a new process):
```bash
adb logcat -d | grep '<PID>.*flutter.*\[AUTH\]' | grep -v 'Router redirect'
```

## Test Framework

### Patrol

Tests use Patrol for native UI automation. Patrol wraps Flutter's
`integration_test` with the ability to handle permission dialogs,
system back button, notifications, and share sheets.

```dart
patrolTest('my test', ($) async {
  final tester = $.tester;
  // Use tester for Flutter widget interactions
  // Use $ for native interactions (permissions, system UI)
});
```

### Patrol Test Bundling (False Positives)

Patrol bundles ALL test files in a directory into one APK. Each test file
runs in a separate instrumentation process. When test B runs, test A's
code is in the bundle but "not requested" — Patrol marks it `[E]`.

**These are false positives, not real failures.** Only trust the `✅`/`❌`
final status lines from the test runner. The logcat will show:
```
registered test "foo_test ..." was not matched by requested test "bar_test ..."
```

### App Launch Pattern

Use `launchAppGuarded` from `test_setup.dart` to catch async relay errors:

```dart
final originalOnError = suppressSetStateErrors();
final originalErrorBuilder = saveErrorWidgetBuilder();

launchAppGuarded(app.main);
await tester.pumpAndSettle(const Duration(seconds: 3));

// ... test body ...

restoreErrorWidgetBuilder(originalErrorBuilder);
restoreErrorHandler(originalOnError);
drainAsyncErrors(tester);
```

### Polling Instead of pumpAndSettle

The app has persistent polling timers that prevent `pumpAndSettle` from
settling. Use manual pump loops:

```dart
for (var i = 0; i < 60; i++) {
  await tester.pump(const Duration(milliseconds: 250));
  if (find.text('Welcome').evaluate().isNotEmpty) break;
}
```

## Common Pitfalls

### Async Publish → Relay Query

Video publishing is async — the UI navigates to profile before the blossom
upload and relay publish complete. Always poll the relay:

```dart
var events = <Event>[];
for (var i = 0; i < 120; i++) {
  await tester.pump(const Duration(milliseconds: 500));
  events = await queryRelay(filter);
  if (events.isNotEmpty) break;
}
```

### Onboarding Sheets Blocking UI

New features may add bottom sheets that cover buttons the test needs.
Dismiss them before proceeding:

```dart
for (var i = 0; i < 20; i++) {
  await tester.pump(const Duration(milliseconds: 250));
  final gotIt = find.text('Got it!');
  if (gotIt.evaluate().isNotEmpty) {
    await tester.tap(gotIt);
    await tester.pump(const Duration(milliseconds: 500));
    break;
  }
}
```

### Riverpod Provider Init Crashes

If a provider uses `requireIdentity` or similar non-nullable getters, it
crashes during cold start (before auth) and Riverpod caches the error
permanently. Use nullable access (`currentIdentity`) in providers and
handle null. The error looks like:

```
ProviderException: Tried to use a provider that is in error state.
Bad state: requireIdentity called with no active NostrIdentity.
```

### Material Widget Ancestor

`TextField` requires a `Material` ancestor. If a widget is used in an
overlay or transition context without `Scaffold`, wrap it:

```dart
Material(
  color: Colors.transparent,
  child: TextField(...),
)
```

## Test Helpers

All helpers are in `integration_test/helpers/`:

| File | Purpose |
|------|---------|
| `constants.dart` | Port constants + `pgPort`, `appPackage` |
| `db_helpers.dart` | Postgres queries: verification tokens, refresh tokens |
| `http_helpers.dart` | Keycast API: verify email, forgot password |
| `navigation_helpers.dart` | UI interactions: register, login, tap tabs, wait for widgets |
| `relay_helpers.dart` | Publish Nostr events: kind 34236 videos, kind 0 profiles |
| `test_setup.dart` | Error suppression, app launch, async error draining |

## Debugging

```bash
# Service logs
docker compose -f local_stack/docker-compose.yml logs keycast --tail=50
docker compose -f local_stack/docker-compose.yml logs funnelcake-relay --tail=50
docker compose -f local_stack/docker-compose.yml logs blossom --tail=50

# Check blossom for actual uploads (not just health checks)
docker compose -f local_stack/docker-compose.yml logs blossom | grep -v 'path=/'

# Auth flow trace
adb logcat -d | grep 'flutter.*\[AUTH\]' | grep -v 'Router redirect'

# Test reports (merged Docker + logcat timeline)
ls mobile/test_reports/*.jsonl
```
