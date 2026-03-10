# E2E Integration Testing

End-to-end tests run the full app against a local Docker backend stack. They exercise real OAuth flows, relay subscriptions, and media uploads with no mocks.

---

## Infrastructure

### Local Docker Stack

Located in `local_stack/`. Services:

| Service | Host Port | Purpose |
|---------|-----------|---------|
| Keycast | 43000 | OAuth + NIP-46 signer |
| FunnelCake Relay | 47777 | Nostr relay (WebSocket) |
| FunnelCake API | 43001 | REST API |
| Blossom | 43003 | Media server |
| Postgres | 15432 | Keycast database |

### Commands

```bash
# From mobile/ directory:
mise run local_up        # Start Docker stack
mise run local_down      # Stop Docker stack
mise run local_reset     # Wipe data and restart
mise run local_status    # Check service health
mise run e2e_test        # Run all E2E tests with profiling
mise run e2e_test integration_test/auth/auth_journey_test.dart  # Single test
```

### Android Emulator

The emulator reaches the host via `10.0.2.2`. Port constants are defined in `lib/models/environment_config.dart` (`localHost`, `localKeycastPort`, etc.) and re-exported by `integration_test/helpers/constants.dart`.

---

## Test Framework

### Patrol

Tests use [Patrol](https://patrol.leancode.co/) for native UI automation. Patrol wraps Flutter's `integration_test` with the ability to handle permission dialogs, system back button, notifications, and share sheets.

```dart
patrolTest('my test', ($) async {
  final tester = $.tester;
  // Use tester for Flutter widget interactions
  // Use $ for native interactions (permissions, system UI)
});
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

The app has persistent polling timers (e.g. EmailVerificationCubit polls every 3s) that prevent `pumpAndSettle` from settling. Use `pumpUntilSettled` or manual pump loops:

```dart
// Wait for text to appear (polls every 250ms)
final found = await waitForText(tester, 'Welcome', maxSeconds: 15);

// Or manual pump loop
for (var i = 0; i < 60; i++) {
  await tester.pump(const Duration(milliseconds: 250));
  if (find.text('Welcome').evaluate().isNotEmpty) break;
}
```

---

## Test Helpers

All helpers are in `integration_test/helpers/`:

| File | Purpose |
|------|---------|
| `constants.dart` | Port constants (re-exports from environment_config) + `pgPort`, `appPackage` |
| `db_helpers.dart` | Direct Postgres queries: verification tokens, refresh tokens, user lookup |
| `http_helpers.dart` | Keycast API calls: verify email, forgot password |
| `navigation_helpers.dart` | UI interactions: register, login, tap tabs, wait for widgets |
| `relay_helpers.dart` | Publish Nostr events: kind 34236 videos, kind 0 profiles, blossom uploads |
| `test_setup.dart` | Error suppression, app launch, async error draining |

### Publishing Test Events

```dart
// Publish a video event to the local relay
final (eventId: id, pubkey: pub, privateKey: priv) =
    await publishTestVideoEvent(title: 'My Test Video');

// Publish a profile event
final (pubkey: pub, privateKey: priv) =
    await publishTestProfileEvent(name: 'testuser');
```

### Database Queries

```dart
// Get email verification token from keycast postgres
final token = await getVerificationToken('user@example.com');

// Consume all refresh tokens (for session expiry testing)
await consumeAllRefreshTokens(userPubkey);
```

---

## Test Organization

```
mobile/integration_test/
├── auth/                    # Auth journey tests (register, login, token refresh)
├── e2e/                     # Full app E2E tests (C2PA, video creation)
├── helpers/                 # Shared test utilities
├── lifecycle/               # App backgrounding/resume
├── video_recorder/          # Camera and recording tests
├── video_clip_editor/       # Video editor widget tests
├── *.dart                   # Feature-specific tests (report, block, etc.)
```

### Auth Tests

These are the core E2E tests that exercise the full OAuth flow against the local Docker stack:

- `auth_journey_test.dart` — Full registration → verification → forgot password → reset → login → app navigation
- `user_journey_test.dart` — Registration → verification → publish video → explore tabs
- `session_expiry_test.dart` — Token manipulation to force expired session UI
- `token_refresh_test.dart` — Real 15s TTL expiry, refresh rotation verification

---

## Writing New E2E Tests

1. **Use `patrolTest`** for all integration tests
2. **Import helpers** from `integration_test/helpers/`
3. **Use `launchAppGuarded`** to handle async relay errors
4. **Use polling loops** instead of `pumpAndSettle` when the app has active timers
5. **Clean up error handlers** at test end with `restoreErrorHandler` and `drainAsyncErrors`
6. **Use full Nostr IDs** — never truncate (project-wide rule)
7. **Run with LOCAL env**: tests are invoked with `--dart-define=DEFAULT_ENV=LOCAL`

---

## Log Profiling

Every test run captures merged Docker + Android logcat logs into `test_reports/`:

```bash
mise run e2e_test  # Produces test_reports/<timestamp>.jsonl
```

The JSONL report has entries from all services sorted by timestamp, useful for debugging client-server interactions.
