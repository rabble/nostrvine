# Crossposting Settings Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship authenticated crossposter connection and posting-mode settings for every enabled platform returned by the service.

**Architecture:** Keep HTTP and bearer-token concerns in `CrosspostingApiClient`, join the three read endpoints in `CrosspostingRepository`, and keep all screen state in `CrosspostingSettingsCubit`. A Riverpod Page boundary injects the auth-sensitive repository into the Cubit; a small feature-owned OAuth launcher uses `flutter_web_auth_2` for `ASWebAuthenticationSession`/Custom Tabs and returns the callback to the compact View/Cubit flow.

**Tech Stack:** Flutter, Dart, flutter_bloc, Riverpod dependency injection, `http`, Keycast OAuth session, go_router, flutter_web_auth_2, ARB localization, mocktail, bloc_test.

---

### Task 0: Normalize the takeover worktree

**Files:**
- Restore to `HEAD`: `mobile/lib/main.dart`
- Restore to `HEAD`: `mobile/lib/services/deep_link_service.dart`
- Restore to `HEAD`: `mobile/lib/router/universal_link_resolver.dart`
- Restore to `HEAD`: `mobile/test/services/deep_link_service_test.dart`
- Restore to `HEAD`: `mobile/lib/providers/upload_media_providers.dart`
- Restore to `HEAD`: `mobile/lib/providers/upload_media_providers.g.dart`
- Restore to `HEAD`: unrelated deleted generated files reported by `git status --short`

- [ ] **Step 1: Confirm each takeover-only edit is superseded**

Compare each listed file to `HEAD`. Restore only the uncommitted crossposting global-deep-link/provider additions and generator deletions; keep the new client, Cubit, screen, tests, settings route, copy, and design/plan files as implementation inputs.

- [ ] **Step 2: Verify cleanup scope**

Run: `git diff -- mobile/lib/main.dart mobile/lib/services/deep_link_service.dart mobile/lib/router/universal_link_resolver.dart mobile/test/services/deep_link_service_test.dart mobile/lib/providers/upload_media_providers.dart mobile/lib/providers/upload_media_providers.g.dart`

Expected: no diff. `git status --short` has no deleted unrelated generated outputs.

### Task 1: Stabilize the authenticated crossposter API client

**Files:**
- Create: `mobile/lib/services/crossposting_api_client.dart`
- Test: `mobile/test/services/crossposting_api_client_test.dart`

- [ ] **Step 1: Complete failing contract tests**

Cover exact paths and payloads for `GET /platforms?format=json`, `GET /connections`, `POST /connections/{platform}/start`, `DELETE /connections/{platform}/{id}`, `GET /preferences`, and `PUT /preferences/{platform}`. Assert every endpoint sends `Authorization: Bearer <accessToken>` and JSON content type, plus unknown-platform tolerance, `needs_reauth`, `supportsAutomatic`, Unix expiry parsing, malformed JSON, non-HTTPS authorization URLs, timeouts, and `{error:{code,message}}` parsing.

```dart
expect(headers['Authorization'], 'Bearer session-access-token');
expect(body, jsonEncode({'mode': 'automatic'}));
expect(exception.kind, CrosspostingApiErrorKind.notConnected);
```

- [ ] **Step 2: Run the client test and confirm uncovered cases fail**

Run: `cd mobile && flutter test test/services/crossposting_api_client_test.dart`

Expected: FAIL from the `origin/main` baseline because the crossposter client does not exist.

- [ ] **Step 3: Complete the minimal client implementation**

Use `KeycastOAuth.getSessionOrRefresh()` for every call including `/platforms`, a 20-second timeout, safe JSON-envelope parsing, URL-encoded path segments, HTTPS-only authorization URLs, and a `close()` method for the owned `http.Client`.

```dart
Future<Map<String, String>> _authHeaders() async {
  final token = (await _oauthClient.getSessionOrRefresh())?.accessToken;
  if (token == null) throw const CrosspostingApiException.unauthorized();
  return {'Authorization': 'Bearer $token', 'Content-Type': 'application/json'};
}
```

- [ ] **Step 4: Re-run the client test**

Run: `cd mobile && flutter test test/services/crossposting_api_client_test.dart`

Expected: PASS.

### Task 2: Add the repository and dependency boundary

**Files:**
- Create: `mobile/lib/repositories/crossposting_repository.dart`
- Create: `mobile/lib/providers/crossposting_providers.dart`
- Test: `mobile/test/repositories/crossposting_repository_test.dart`

- [ ] **Step 1: Write failing repository join tests**

Assert that `loadSettings()` fetches platforms, connections, and preferences, filters disabled platforms, associates connection/preference records by platform, preserves `supportsAutomatic`, and defaults a missing preference to Off.

```dart
final settings = await repository.loadSettings();
expect(settings.map((item) => item.platform), [instagram, x]);
expect(settings.first.mode, CrosspostingMode.manual);
expect(settings.last.mode, CrosspostingMode.disabled);
```

- [ ] **Step 2: Run the repository test and confirm it fails**

Run: `cd mobile && flutter test test/repositories/crossposting_repository_test.dart`

Expected: FAIL because the repository does not exist.

- [ ] **Step 3: Implement the repository model and forwarding methods**

Add immutable `CrosspostingPlatformSettings` with `copyWith(mode:)`. Implement `loadSettings`, `startConnection`, `disconnect`, and `setMode`; only `loadSettings` contains join logic.

```dart
final platforms = await _client.getPlatforms();
final connections = await _client.getConnections();
final preferences = await _client.getPreferences();
```

Fetch sequentially because `KeycastOAuth.getSessionOrRefresh()` rotates refresh
tokens without in-flight serialization; concurrent authenticated calls could
race the same refresh token.

- [ ] **Step 4: Create plain Riverpod providers without generator coupling**

Use non-generated `Provider` declarations for the client and repository. Watch `oauthClientProvider`, close the client with `ref.onDispose`, and make the screen import this focused provider module. Do not modify `upload_media_providers.dart` or its generated output.

- [ ] **Step 5: Re-run repository and client tests**

Run: `cd mobile && flutter test test/services/crossposting_api_client_test.dart test/repositories/crossposting_repository_test.dart`

Expected: PASS.

### Task 3: Refactor the Cubit onto the repository and native OAuth result

**Files:**
- Create: `mobile/lib/blocs/crossposting_settings/crossposting_settings_cubit.dart`
- Create: `mobile/lib/blocs/crossposting_settings/crossposting_settings_state.dart`
- Create: `mobile/test/blocs/crossposting_settings/crossposting_settings_cubit_test.dart`

- [ ] **Step 1: Convert Cubit tests to a mocked repository**

Test load and quiet refresh, connect with `https://divine.video/app/callback`, browser-launch failure/cancellation, exact callback validation, callback-driven refresh, disconnect followed by reload, mode success, optimistic mode rollback on `not_connected`, and duplicate-action suppression. Negative callback cases reject HTTP, other Divine subdomains, the wrong path, and unknown `connection` values.

```dart
verify(() => repository.startConnection(
  CrosspostingPlatform.x,
  returnUrl: CrosspostingSettingsCubit.returnUrl,
)).called(1);
expect(cubit.state.callbackOutcome, CrosspostingCallbackOutcome.connected);
```

- [ ] **Step 2: Run the Cubit test and confirm the dependency mismatch fails**

Run: `cd mobile && flutter test test/blocs/crossposting_settings/crossposting_settings_cubit_test.dart`

Expected: FAIL from the `origin/main` baseline because the Cubit does not exist.

- [ ] **Step 3: Inject `CrosspostingRepository` and simplify state**

Replace `_fetchEntries()` with `repository.loadSettings()`. Inject a `Future<Uri?> Function(Uri)` OAuth launcher. Keep transient error enums, callback outcome/platform, and pending action/platform in Cubit state; use `CrosspostingPlatformSettings.copyWith(mode:)` for optimistic updates. A `null` callback means the user closed/canceled the browser and triggers a quiet refresh without an error snackbar.

- [ ] **Step 4: Re-run the Cubit test**

Run: `cd mobile && flutter test test/blocs/crossposting_settings/crossposting_settings_cubit_test.dart`

Expected: PASS.

### Task 4: Finish compact UI, native OAuth, navigation, and copy

**Files:**
- Modify: `mobile/lib/screens/settings/general_settings_screen.dart`
- Create: `mobile/lib/screens/settings/crossposting_settings_screen.dart`
- Create: `mobile/lib/features/crossposting/crossposting_oauth_launcher.dart`
- Modify: `mobile/lib/router/routes/settings_routes.dart`
- Modify: `mobile/lib/router/providers/page_context_provider.dart`
- Modify: `mobile/lib/providers/active_video_provider.dart`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/lib/l10n/app_en.arb`
- Modify: `mobile/test/l10n/arb_consistency_test.dart`
- Modify: every generated `mobile/lib/l10n/generated/app_localizations*.dart`
- Create: `mobile/test/features/crossposting/crossposting_oauth_launcher_test.dart`
- Test: `mobile/test/screens/settings/crossposting_settings_screen_test.dart`
- Modify: `mobile/test/router/route_coverage_test.dart`
- Create: `mobile/test/android/crossposting_callback_manifest_test.dart`

- [ ] **Step 1: Update UI, OAuth, route, and native-config tests**

Assert only enabled platforms appear; account/status and actions remain visible; disconnected/reauth rows have no mode selector; connected rows have a compact selector; only the selected Manual or Automatic explanation is visible; Automatic is absent when unsupported; changing mode calls the repository; callback results show localized feedback; app resume calls refresh; and zero enabled platforms shows localized empty-state copy. Separately assert the OAuth wrapper passes scheme `https`, host `divine.video`, and path `/app/callback`; cancellation returns `null`; `/crossposting-settings` has its own route context; and Android's callback activity is exported, auto-verified, and constrained to the exact HTTPS host/path.

```dart
expect(find.text(l10n.crosspostingModeManualSubtitle), findsOneWidget);
expect(find.text(l10n.crosspostingModeAutomaticSubtitle), findsNothing);
expect(parseKnownRoute('/crossposting-settings')?.type,
    RouteType.crosspostingSettings);
```

- [ ] **Step 2: Run focused tests and confirm failures**

Run: `cd mobile && flutter test test/features/crossposting/crossposting_oauth_launcher_test.dart test/screens/settings/crossposting_settings_screen_test.dart test/router/route_coverage_test.dart test/android/crossposting_callback_manifest_test.dart`

Expected: FAIL from the `origin/main` baseline because the screen, OAuth wrapper, native callback activity, route context, and empty state do not exist.

- [ ] **Step 3: Implement compact platform rows and lifecycle refresh**

Render a compact segmented selector for Off, Manual, and conditionally Automatic. Display only the selected non-Off explanatory line. Keep Connect/Reconnect/Disconnect visible, render localized empty-state copy for an empty enabled list, and use existing Divine theme/components. Wire `AppLifecycleListener.onResume` to `Cubit.refresh()` only when no action is pending.

- [ ] **Step 4: Implement the native OAuth wrapper and callback registration**

Call `FlutterWebAuth2.authenticate` with `callbackUrlScheme: 'https'` and `FlutterWebAuth2Options(httpsHost: 'divine.video', httpsPath: '/app/callback')`. Convert a platform `CANCELED` result to `null` and rethrow other failures. Register `com.linusu.flutter_web_auth_2.CallbackActivity` with `android:exported="true"`; give its intent filter `android:autoVerify="true"` and one HTTPS data element constrained to host `divine.video` and path `/app/callback`. Do not broaden the app's global deep-link parser or Keycast callback route.

- [ ] **Step 5: Model the settings route context**

Add `RouteType.crosspostingSettings`, recognize the exact one-segment `/crossposting-settings` shape in `parseKnownRoute`, return that type from `parseRoute`, and include it in route serialization and every exhaustive switch, including the non-video classification in `active_video_provider.dart`. Add a direct parser test so the route cannot silently fall back to home; `flutter analyze` verifies exhaustive-switch integration.

- [ ] **Step 6: Generate localization output and run consistency checks**

Run: `cd mobile && flutter gen-l10n && flutter test test/l10n/arb_consistency_test.dart`

Expected: generated localizations contain all new keys; consistency test PASS with the explicitly ratcheted untranslated-debt set.

- [ ] **Step 7: Re-run UI and callback tests**

Run: `cd mobile && flutter test test/features/crossposting/crossposting_oauth_launcher_test.dart test/screens/settings/crossposting_settings_screen_test.dart test/router/route_coverage_test.dart test/android/crossposting_callback_manifest_test.dart`

Expected: PASS.

### Task 5: Clean, verify, review, and publish

**Files:**
- Review every path in `git diff --name-status origin/main...HEAD` and `git status --short`
- Update: `mobile/scripts/baseline/untested_services.txt` only if the service-floor script requires a deterministic ratchet

- [ ] **Step 1: Format and inspect generated/artifact churn**

Run: `cd mobile && dart format lib/services/crossposting_api_client.dart lib/repositories/crossposting_repository.dart lib/providers/crossposting_providers.dart lib/features/crossposting lib/blocs/crossposting_settings test/services/crossposting_api_client_test.dart test/repositories/crossposting_repository_test.dart test/features/crossposting test/blocs/crossposting_settings test/screens/settings/crossposting_settings_screen_test.dart test/android/crossposting_callback_manifest_test.dart`

Run: `git status --short && git diff --check`

Expected: no deleted unrelated generated files, no `.superpowers/` artifact in the intended diff, and no whitespace errors.

- [ ] **Step 2: Run focused quality gates**

Run: `cd mobile && flutter test test/services/crossposting_api_client_test.dart test/repositories/crossposting_repository_test.dart test/features/crossposting/crossposting_oauth_launcher_test.dart test/blocs/crossposting_settings/crossposting_settings_cubit_test.dart test/screens/settings/crossposting_settings_screen_test.dart test/router/route_coverage_test.dart test/android/crossposting_callback_manifest_test.dart test/l10n/arb_consistency_test.dart`

Run: `bash mobile/scripts/check_untested_services_floor.sh`

Expected: PASS.

- [ ] **Step 3: Run broad static and visual verification**

Run: `cd mobile && flutter analyze`

Run: `cd mobile && scripts/golden.sh verify`

Expected: PASS, or update only directly affected goldens after visual inspection.

- [ ] **Step 4: Perform independent spec and code review**

Check every Build requirement, security of bearer handling and callback parsing, state rollback, auth-flip dependency wiring, localization coverage, and diff scope. Fix every evidence-backed finding and repeat affected tests.

- [ ] **Step 5: Commit, rebase, and reverify**

Stage only feature files, commit with Conventional Commit messages, fetch and rebase onto fresh `origin/main`, then rerun the focused tests and analyze before pushing with `--force-with-lease` only if the rebase changed published history.

- [ ] **Step 6: Open the PR and inspect checks**

Create a PR targeting `main` with title `feat(settings): add crossposting connections and modes`, summarize API/auth/UI/testing, and inspect GitHub checks and review feedback until the branch is ready for human review.
