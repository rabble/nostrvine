# Local-First Divine OAuth Startup Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restore Divine OAuth users into the app immediately from matching local keys, move OAuth/Keycast recovery to a bounded background upgrade path, and stop blocking app viewing or optimistic social actions on remote signer availability.

**Architecture:** Keep `AuthState.authenticated` focused on local identity readiness and treat remote Keycast RPC access as a separate capability that can warm up after startup. `AuthService` should restore a same-pubkey local identity immediately, rebuild its `NostrIdentity` when RPC becomes available, and expose a small capability surface that providers can use to decide whether to publish now or queue optimistically. Welcome/account loading and startup metrics should also stop tying “ready” to slow cache or feed work.

**Tech Stack:** Flutter, Riverpod, BLoC, Drift, SharedPreferences, `flutter_secure_storage`, `keycast_flutter`, existing `PendingActionService`

---

## Read This First

- `mobile/lib/services/auth_service.dart`
- `mobile/lib/services/nostr_identity.dart`
- `mobile/lib/providers/app_providers.dart`
- `mobile/lib/blocs/welcome/welcome_bloc.dart`
- `mobile/lib/screens/auth/welcome_screen.dart`
- `mobile/lib/services/startup_performance_service.dart`
- `mobile/lib/main.dart`
- `mobile/packages/likes_repository/lib/src/likes_repository.dart`
- `mobile/packages/reposts_repository/lib/src/reposts_repository.dart`
- `mobile/lib/repositories/follow_repository.dart`
- `mobile/test/services/auth_service_expired_session_downgrade_test.dart`
- `mobile/test/services/auth_service_oauth_recovery_test.dart`
- `mobile/test/blocs/welcome/welcome_bloc_test.dart`
- `mobile/test/services/pending_action_service_test.dart`
- `mobile/test/startup/app_first_frame_startup_test.dart`
- `mobile/test/startup/app_startup_test.dart`

## File Structure

**Create**
- `mobile/lib/models/auth_rpc_capability.dart`
- `mobile/test/services/auth_service_local_first_startup_test.dart`
- `mobile/test/providers/auth_rpc_capability_provider_test.dart`

**Modify**
- `mobile/lib/services/auth_service.dart`
- `mobile/lib/services/nostr_identity.dart`
- `mobile/lib/providers/app_providers.dart`
- `mobile/lib/blocs/welcome/welcome_bloc.dart`
- `mobile/lib/blocs/welcome/welcome_event.dart`
- `mobile/lib/blocs/welcome/welcome_state.dart`
- `mobile/lib/screens/auth/welcome_screen.dart`
- `mobile/lib/services/startup_performance_service.dart`
- `mobile/lib/main.dart`
- `mobile/packages/likes_repository/lib/src/likes_repository.dart`
- `mobile/packages/reposts_repository/lib/src/reposts_repository.dart`
- `mobile/lib/repositories/follow_repository.dart`
- `mobile/test/services/auth_service_expired_session_downgrade_test.dart`
- `mobile/test/services/auth_service_oauth_recovery_test.dart`
- `mobile/test/blocs/welcome/welcome_bloc_test.dart`
- `mobile/test/startup/app_first_frame_startup_test.dart`
- `mobile/test/startup/app_startup_test.dart`
- `mobile/test/services/pending_action_service_test.dart`
- `mobile/lib/providers/app_providers.g.dart`

**Do Not Touch In This Workstream**
- Any livestream files under `mobile/lib/screens/live`, `mobile/lib/services/live_*`, `mobile/lib/providers/live_*`
- The `codex/live-spaces-v1` worktree or branch

## Chunk 1: Local-First Auth Core

### Task 1: Introduce explicit RPC capability state

**Files:**
- Create: `mobile/lib/models/auth_rpc_capability.dart`
- Modify: `mobile/lib/services/auth_service.dart`
- Modify: `mobile/lib/providers/app_providers.dart`
- Test: `mobile/test/providers/auth_rpc_capability_provider_test.dart`

- [ ] **Step 1: Write the failing provider/service tests**

```dart
test('divineOAuth local restore starts in upgrading state before RPC is ready', () async {
  expect(authService.authRpcCapability, AuthRpcCapability.upgrading);
});

test('provider exposes rpcReady after upgrade completes', () async {
  expect(container.read(currentAuthRpcCapabilityProvider), AuthRpcCapability.rpcReady);
});
```

- [ ] **Step 2: Run the new auth capability tests to verify they fail**

Run: `flutter test test/providers/auth_rpc_capability_provider_test.dart test/services/auth_service_local_first_startup_test.dart`

Expected: FAIL because `AuthRpcCapability` and `currentAuthRpcCapabilityProvider` do not exist yet.

- [ ] **Step 3: Add the capability model and provider**

```dart
enum AuthRpcCapability {
  unavailable,
  upgrading,
  rpcReady,
}
```

Implementation notes:
- Keep `AuthState` unchanged for router compatibility.
- Add `AuthRpcCapability _authRpcCapability` to `AuthService`.
- Add getter plus stream/broadcast updates alongside `authStateStream`.
- Add a Riverpod provider `currentAuthRpcCapabilityProvider`.

- [ ] **Step 4: Run the new auth capability tests to verify they pass**

Run: `flutter test test/providers/auth_rpc_capability_provider_test.dart test/services/auth_service_local_first_startup_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/models/auth_rpc_capability.dart mobile/lib/services/auth_service.dart mobile/lib/providers/app_providers.dart mobile/lib/providers/app_providers.g.dart mobile/test/providers/auth_rpc_capability_provider_test.dart mobile/test/services/auth_service_local_first_startup_test.dart
git commit -m "feat(auth): add rpc capability state"
```

### Task 2: Make Divine OAuth startup restore local identity first

**Files:**
- Modify: `mobile/lib/services/auth_service.dart`
- Modify: `mobile/lib/services/nostr_identity.dart`
- Test: `mobile/test/services/auth_service_local_first_startup_test.dart`
- Test: `mobile/test/services/auth_service_expired_session_downgrade_test.dart`
- Test: `mobile/test/services/auth_service_oauth_recovery_test.dart`

- [ ] **Step 1: Write the failing local-first startup tests**

```dart
test('matching local key authenticates before refresh completes', () async {
  await authService.initialize();
  expect(authService.authState, AuthState.authenticated);
  expect(authService.currentPublicKeyHex, matchingPubkey);
  expect(authService.authRpcCapability, AuthRpcCapability.upgrading);
});

test('refresh timeout does not block local authenticated startup', () async {
  when(() => mockOAuthClient.refreshSession()).thenAnswer((_) => Completer<KeycastSession?>().future);
  await authService.initialize();
  expect(authService.isAuthenticated, isTrue);
});
```

- [ ] **Step 2: Run the auth startup tests to verify they fail**

Run: `flutter test test/services/auth_service_local_first_startup_test.dart test/services/auth_service_expired_session_downgrade_test.dart test/services/auth_service_oauth_recovery_test.dart`

Expected: FAIL because `initialize()` still waits for refresh before using local keys.

- [ ] **Step 3: Refactor `divineOAuth` initialization into a local-first path**

Implementation requirements:
- Add a helper that loads:
  - archived/active `KeycastSession`
  - local `SecureKeyContainer`
  - a trusted target pubkey from session or archived auth record
- If local keys exist and match the Divine OAuth pubkey:
  - call `_setupUserSession(keyContainer, AuthenticationSource.divineOAuth)` immediately
  - set `AuthRpcCapability.upgrading` if RPC is not ready
  - start refresh in the background with a short timeout
- If refresh succeeds later:
  - build `_keycastSigner`
  - rebuild `_currentIdentity` to a `KeycastNostrIdentity`
  - set `AuthRpcCapability.rpcReady`
- If refresh fails:
  - preserve `AuthenticationSource.divineOAuth`
  - keep the local identity active
  - leave `hasExpiredOAuthSession` true for UI messaging
  - set capability back to `unavailable`
- If there is no local key and no usable RPC session:
  - preserve current unauthenticated fallback behavior

Concrete code shape to aim for:

```dart
Future<void> _initializeDivineOAuth() async {
  final session = await KeycastSession.load(_flutterSecureStorage);
  final localKey = await _keyStorage.getKeyContainer();
  final targetPubkey = session?.userPubkey ?? localKey?.publicKeyHex;

  if (_canUseLocalDivineIdentity(localKey, targetPubkey)) {
    _hasExpiredOAuthSession = session == null || !session.hasRpcAccess;
    _authRpcCapability = _hasExpiredOAuthSession
        ? AuthRpcCapability.upgrading
        : AuthRpcCapability.rpcReady;
    await _setupUserSession(localKey!, AuthenticationSource.divineOAuth);
    unawaited(_upgradeDivineRpcInBackground(session));
    return;
  }

  await _restoreDivineRpcOrFallbackUnauthenticated(session);
}
```

- [ ] **Step 4: Bound the refresh path**

Implementation requirements:
- Add an explicit timeout around `refreshSession()`.
- Log timeout distinctly from hard HTTP rejection.
- Never block `initialize()` on a long-running refresh once a valid local key has restored the session.

- [ ] **Step 5: Run the auth startup tests to verify they pass**

Run: `flutter test test/services/auth_service_local_first_startup_test.dart test/services/auth_service_expired_session_downgrade_test.dart test/services/auth_service_oauth_recovery_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/auth_service.dart mobile/lib/services/nostr_identity.dart mobile/test/services/auth_service_local_first_startup_test.dart mobile/test/services/auth_service_expired_session_downgrade_test.dart mobile/test/services/auth_service_oauth_recovery_test.dart
git commit -m "fix(auth): restore local divine identity before rpc refresh"
```

## Chunk 2: Non-Blocking Writes And Welcome Fast Path

### Task 3: Reuse pending-action queue while RPC is warming

**Files:**
- Modify: `mobile/lib/providers/app_providers.dart`
- Modify: `mobile/packages/likes_repository/lib/src/likes_repository.dart`
- Modify: `mobile/packages/reposts_repository/lib/src/reposts_repository.dart`
- Modify: `mobile/lib/repositories/follow_repository.dart`
- Test: `mobile/test/services/pending_action_service_test.dart`
- Test: `mobile/test/providers/auth_rpc_capability_provider_test.dart`

- [ ] **Step 1: Write the failing queueing tests**

```dart
test('likes queue when rpc is upgrading and no local signer is available', () async {
  expect(queuedActions.single.type, PendingActionType.like);
});

test('likes publish immediately when local signer exists even if rpc is upgrading', () async {
  expect(queuedActions, isEmpty);
  verify(() => mockNostrClient.sendReaction(...)).called(1);
});
```

- [ ] **Step 2: Run the queueing tests to verify they fail**

Run: `flutter test test/providers/auth_rpc_capability_provider_test.dart test/services/pending_action_service_test.dart`

Expected: FAIL because repositories only treat `offline` as queue-worthy.

- [ ] **Step 3: Add a single “can publish now” predicate in providers**

Implementation notes:
- Do not scatter `authRpcCapability` checks across UI code.
- In `app_providers.dart`, compute a predicate using:
  - `authService.currentIdentity`
  - whether the identity has a local signer/private key
  - `currentAuthRpcCapabilityProvider`
- Pass repository callbacks that queue when:
  - device is offline, or
  - the user is authenticated but currently pubkey-only / waiting on remote RPC

Recommended shape:

```dart
final canWriteNow = authService.canPublishNostrWritesNow;
final shouldQueueOptimisticWrite = !canWriteNow || !connectionStatus.isOnline;
```

- [ ] **Step 4: Keep scope tight**

Only wire this behavior for the action types that already have pending-action support:
- likes / unlikes
- reposts / unreposts
- follow / unfollow

Do not expand this plan slice into DM sending, profile edits, or video publishing.

- [ ] **Step 5: Run the queueing tests to verify they pass**

Run: `flutter test test/providers/auth_rpc_capability_provider_test.dart test/services/pending_action_service_test.dart mobile/packages/likes_repository/test/src/likes_repository_test.dart mobile/packages/reposts_repository/test/src/reposts_repository_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/providers/app_providers.dart mobile/lib/providers/app_providers.g.dart mobile/lib/repositories/follow_repository.dart mobile/packages/likes_repository/lib/src/likes_repository.dart mobile/packages/reposts_repository/lib/src/reposts_repository.dart mobile/test/providers/auth_rpc_capability_provider_test.dart mobile/test/services/pending_action_service_test.dart mobile/packages/likes_repository/test/src/likes_repository_test.dart mobile/packages/reposts_repository/test/src/reposts_repository_test.dart
git commit -m "fix(auth): queue optimistic social writes during rpc warmup"
```

### Task 4: Stop welcome screen from blocking on cached profile hydration

**Files:**
- Modify: `mobile/lib/blocs/welcome/welcome_bloc.dart`
- Modify: `mobile/lib/blocs/welcome/welcome_event.dart`
- Modify: `mobile/lib/blocs/welcome/welcome_state.dart`
- Modify: `mobile/lib/screens/auth/welcome_screen.dart`
- Test: `mobile/test/blocs/welcome/welcome_bloc_test.dart`

- [ ] **Step 1: Write the failing welcome fast-path tests**

```dart
blocTest<WelcomeBloc, WelcomeState>(
  'emits accounts immediately, then hydrates profiles later',
  expect: () => [
    const WelcomeState(
      status: WelcomeStatus.loaded,
      previousAccounts: [accountWithoutProfile],
    ),
    WelcomeState(
      status: WelcomeStatus.loaded,
      previousAccounts: [accountWithProfile],
    ),
  ],
);
```

- [ ] **Step 2: Run the welcome bloc tests to verify they fail**

Run: `flutter test test/blocs/welcome/welcome_bloc_test.dart`

Expected: FAIL because `WelcomeStarted` currently awaits every `getProfile()` before the first loaded state.

- [ ] **Step 3: Split account discovery from profile hydration**

Implementation requirements:
- Emit `WelcomeStatus.loaded` as soon as known accounts are known.
- Represent account rows with optional profile data that can be hydrated later.
- Load cached profiles in parallel with `Future.wait`.
- Ignore individual profile lookup failures and preserve the optimistic account list.

Recommended event/state shape:

```dart
final class WelcomeProfilesHydrated extends WelcomeEvent {
  const WelcomeProfilesHydrated(this.accounts);
  final List<PreviousAccount> accounts;
}
```

- [ ] **Step 4: Keep the screen stable while profiles hydrate**

Implementation notes:
- The returning-user layout should render immediately with fallback name/npub.
- Later hydrated profile data should update avatar/name without a full route reset.

- [ ] **Step 5: Run the welcome bloc tests to verify they pass**

Run: `flutter test test/blocs/welcome/welcome_bloc_test.dart test/screens/welcome_screen_test.dart`

Expected: PASS

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/blocs/welcome/welcome_bloc.dart mobile/lib/blocs/welcome/welcome_event.dart mobile/lib/blocs/welcome/welcome_state.dart mobile/lib/screens/auth/welcome_screen.dart mobile/test/blocs/welcome/welcome_bloc_test.dart mobile/test/screens/welcome_screen_test.dart
git commit -m "fix(auth): load welcome accounts before profile hydration"
```

## Chunk 3: Startup Metrics And Final Verification

### Task 5: Make startup metrics reflect first usable UI instead of home-feed readiness

**Files:**
- Modify: `mobile/lib/screens/auth/welcome_screen.dart`
- Modify: `mobile/lib/services/startup_performance_service.dart`
- Modify: `mobile/lib/main.dart`
- Test: `mobile/test/startup/app_first_frame_startup_test.dart`
- Test: `mobile/test/startup/app_startup_test.dart`

- [ ] **Step 1: Write the failing startup metric tests**

```dart
testWidgets('welcome marks startup ui-ready before deferred auth recovery finishes', (tester) async {
  expect(find.text('first-frame-shell'), findsOneWidget);
  expect(startupService.uiReadyTime, isNotNull);
});
```

- [ ] **Step 2: Run the startup tests to verify they fail**

Run: `flutter test test/startup/app_first_frame_startup_test.dart test/startup/app_startup_test.dart`

Expected: FAIL because UI-ready is only marked from `VideoFeedPage`.

- [ ] **Step 3: Add a dedicated auth-shell readiness marker**

Implementation notes:
- Add an idempotent `markAuthShellReady()` or broaden `markUIReady()` semantics in `StartupPerformanceService`.
- Call it from the welcome route once its first visible layout has rendered.
- Keep home-feed video readiness as a separate later metric; do not delete it.

- [ ] **Step 4: Run the startup tests to verify they pass**

Run: `flutter test test/startup/app_first_frame_startup_test.dart test/startup/app_startup_test.dart`

Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/screens/auth/welcome_screen.dart mobile/lib/services/startup_performance_service.dart mobile/lib/main.dart mobile/test/startup/app_first_frame_startup_test.dart mobile/test/startup/app_startup_test.dart
git commit -m "fix(startup): track auth shell readiness separately from feed load"
```

### Task 6: Broad verification and handoff

**Files:**
- Modify: none unless verification reveals gaps
- Test: all files touched above

- [ ] **Step 1: Run focused auth/startup verification**

Run:

```bash
flutter test test/services/auth_service_local_first_startup_test.dart \
  test/services/auth_service_expired_session_downgrade_test.dart \
  test/services/auth_service_oauth_recovery_test.dart \
  test/providers/auth_rpc_capability_provider_test.dart \
  test/blocs/welcome/welcome_bloc_test.dart \
  test/screens/welcome_screen_test.dart \
  test/services/pending_action_service_test.dart \
  test/startup/app_first_frame_startup_test.dart \
  test/startup/app_startup_test.dart
```

Expected: PASS

- [ ] **Step 2: Run package tests for queue-backed repositories**

Run:

```bash
cd mobile/packages/likes_repository && flutter test
cd /Users/rabble/code/divine/divine-mobile/.worktrees/auth-local-first-startup/mobile/packages/reposts_repository && flutter test
```

Expected: PASS

- [ ] **Step 3: Run analyzer for changed app/package surfaces**

Run:

```bash
flutter analyze lib test
cd mobile/packages/likes_repository && flutter analyze lib test
cd /Users/rabble/code/divine/divine-mobile/.worktrees/auth-local-first-startup/mobile/packages/reposts_repository && flutter analyze lib test
```

Expected: `No issues found!`

- [ ] **Step 4: Manual verification**

Manual checklist:
- Divine OAuth user with same-pubkey local key lands in app quickly even if network is slow.
- Feed/explore/profile browsing works while RPC is still warming.
- Like/follow/repost actions either publish immediately from local signer or queue optimistically during RPC warmup.
- Welcome screen shows returning accounts immediately and hydrates profile details later.
- Logs distinguish `auth shell ready` from `home feed video ready`.

- [ ] **Step 5: Final commit if verification required follow-up fixes**

```bash
git add <only-files-touched-by-verification-fixes>
git commit -m "test(auth): finish local-first startup verification"
```

## Notes For The Implementing Agent

- Do not solve this by simply shortening a timeout. The root problem is that `initialize()` currently treats remote RPC recovery as a prerequisite for usable identity.
- Do not overload `AuthState` with RPC sub-states unless router gating truly needs it. A separate RPC capability channel is safer and smaller.
- `KeycastNostrIdentity` already prefers local signing when a matching private key exists. Preserve that behavior and move the fix to startup ordering plus capability exposure.
- Keep `AuthenticationSource.divineOAuth` intact when falling back to local keys so the UI can still show session-expired messaging and recovery affordances.
- Do not entangle this work with livestream-specific code or the `codex/live-spaces-v1` branch.

Plan complete and saved to `docs/superpowers/plans/2026-04-09-local-first-auth-startup.md`. Ready to execute?
