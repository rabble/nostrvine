# Protected-minor adult-content lock (mobile) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Lock adult content off for protected minors and remove the self-attestation bypass, driven by a persisted, fail-safe protected-minor signal, through the single `AgeVerificationService.isAdultContentVerified` choke point.

**Architecture:** A new `ProtectedMinorStickyStore` persists last-known protected status per account and backs the shared `isProtectedMinorProvider` seam with the decided fail-safe machine (sticky, lifts only on a positive not-a-minor signal). `AgeVerificationService` consults that signal and forces adult content off + blocks the self-attestation path, which cascades to every consumer. Safety Settings shows the adult toggle disabled for protected minors.

**Tech Stack:** Flutter, Riverpod (plain providers — no codegen change), flutter_bloc, SharedPreferences, mocktail, flutter_test.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-07-01-protected-minor-content-lock-design.md`.
- Fail-safe posture (verbatim from #175): once confirmed a protected minor, treat as protected at cold start and offline; lift only on a positive not-a-minor signal (`ProtectedMinorStatusKind.notProtected`); never weaken for a keycast fetch error/unknown; never guess "minor" for an unconfirmed account.
- Mobile only (web parity is #453).
- Tests run from `~/code/divine-mobile/mobile`: `flutter test test/<path>`.
- No riverpod codegen change (new provider is a plain `Provider`), so no `build_runner`. Task 3 adds one l10n string, requiring `flutter gen-l10n` and committing generated files.
- Existing behavior for non-protected accounts must be unchanged (the `isProtectedMinor` callback defaults to `() => false`).

---

### Task 1: `ProtectedMinorStickyStore` + seam wiring (the fail-safe)

**Files:**
- Create: `mobile/lib/services/protected_minor_sticky_store.dart`
- Modify: `mobile/lib/providers/protected_minor_providers.dart` (add store provider; upgrade `isProtectedMinorProvider` to be sticky-backed)
- Test: `mobile/test/services/protected_minor_sticky_store_test.dart`

**Interfaces:**
- Produces: `ProtectedMinorStickyStore({required SharedPreferences prefs})` with `bool isProtectedMinorFor(String? pubkey)` and `Future<void> applyLiveStatus(String? pubkey, ProtectedMinorStatus status)`; `protectedMinorStickyStoreProvider` (Provider); upgraded `isProtectedMinorProvider` (Provider<bool>).
- Consumes: `ProtectedMinorStatus` / `ProtectedMinorStatusKind` (`models/protected_minor_status.dart`), `sharedPreferencesProvider`, `protectedMinorStatusProvider`, `currentAuthStateProvider`, `authServiceProvider`.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/services/protected_minor_sticky_store_test.dart`:

```dart
// ABOUTME: Unit tests for ProtectedMinorStickyStore — the persisted fail-safe
// ABOUTME: state machine backing the protected-minor seam (#175).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/protected_minor_status.dart';
import 'package:openvine/services/protected_minor_sticky_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const pubkey = 'a' * 64;
  const otherPubkey = 'b' * 64;

  late SharedPreferences prefs;
  late ProtectedMinorStickyStore store;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    store = ProtectedMinorStickyStore(prefs: prefs);
  });

  test('unconfirmed account is not protected', () {
    expect(store.isProtectedMinorFor(pubkey), false);
    expect(store.isProtectedMinorFor(null), false);
  });

  test('confirmed protected persists true', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    expect(store.isProtectedMinorFor(pubkey), true);
  });

  test('confirmed not-protected lifts to false (positive signal)', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.notProtected());
    expect(store.isProtectedMinorFor(pubkey), false);
  });

  test('unknown status retains last-known (sticky, never weakens)', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.unknown());
    expect(store.isProtectedMinorFor(pubkey), true);
  });

  test('is per-account', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    expect(store.isProtectedMinorFor(otherPubkey), false);
  });

  test('null pubkey never persists', () async {
    await store.applyLiveStatus(null, ProtectedMinorStatus.protected());
    expect(store.isProtectedMinorFor(null), false);
  });

  test('persists across instances (cold-start read)', () async {
    await store.applyLiveStatus(pubkey, ProtectedMinorStatus.protected());
    final fresh = ProtectedMinorStickyStore(prefs: prefs);
    expect(fresh.isProtectedMinorFor(pubkey), true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/services/protected_minor_sticky_store_test.dart`
Expected: FAIL to compile — `protected_minor_sticky_store.dart` does not exist.

- [ ] **Step 3: Write the minimal implementation**

Create `mobile/lib/services/protected_minor_sticky_store.dart`:

```dart
// ABOUTME: Persists last-known protected-minor status per account and applies
// ABOUTME: the #175 fail-safe machine (sticky; lifts only on a positive signal).

import 'package:openvine/models/protected_minor_status.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Durable, per-account last-known protected-minor state.
///
/// Reads/writes a synchronous [SharedPreferences] snapshot so the value is
/// valid at cold start (local, no network). The fail-safe machine only ever
/// lifts protection on a confirmed not-a-minor signal; unknown/error is sticky.
class ProtectedMinorStickyStore {
  ProtectedMinorStickyStore({required SharedPreferences prefs}) : _prefs = prefs;

  final SharedPreferences _prefs;

  static String _key(String pubkey) => 'protected_minor_sticky_$pubkey';

  /// Last-known protected status for [pubkey]. Null/unconfirmed -> false.
  bool isProtectedMinorFor(String? pubkey) =>
      pubkey != null && (_prefs.getBool(_key(pubkey)) ?? false);

  /// Apply a live keycast status: confirmed protected -> persist true;
  /// confirmed not-protected -> persist false; unknown -> retain.
  Future<void> applyLiveStatus(
    String? pubkey,
    ProtectedMinorStatus status,
  ) async {
    if (pubkey == null) return;
    switch (status.kind) {
      case ProtectedMinorStatusKind.protected:
        await _prefs.setBool(_key(pubkey), true);
      case ProtectedMinorStatusKind.notProtected:
        await _prefs.setBool(_key(pubkey), false);
      case ProtectedMinorStatusKind.unknown:
        break;
    }
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/services/protected_minor_sticky_store_test.dart`
Expected: PASS (7 tests).

- [ ] **Step 5: Wire the store into the seam**

In `mobile/lib/providers/protected_minor_providers.dart`, add imports for `sharedPreferencesProvider` (already imported), `auth_providers.dart` (already imported), the store, and `protected_minor_status.dart` (already imported). Add the store provider and replace `isProtectedMinorProvider`:

```dart
/// Persisted last-known protected-minor state (fail-safe backing, #175).
final protectedMinorStickyStoreProvider = Provider<ProtectedMinorStickyStore>((
  ref,
) {
  return ProtectedMinorStickyStore(prefs: ref.watch(sharedPreferencesProvider));
});
```

Replace the existing `isProtectedMinorProvider` body with the sticky-backed, race-free version:

```dart
/// Effective protected-minor seam for the protections (#175/#176), fail-safe.
///
/// Effective value is the live status when known, else the persisted
/// last-known (sticky). A live status is also persisted for the next cold
/// start. Unknown/error never weakens protection.
final isProtectedMinorProvider = Provider<bool>((ref) {
  ref.watch(currentAuthStateProvider); // reactivity on account changes
  final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
  final store = ref.watch(protectedMinorStickyStoreProvider);
  final live = ref.watch(protectedMinorStatusProvider).value;

  if (live != null) {
    // Persist for future cold starts (fire-and-forget).
    store.applyLiveStatus(pubkey, live);
    if (live.kind == ProtectedMinorStatusKind.protected) return true;
    if (live.kind == ProtectedMinorStatusKind.notProtected) return false;
  }
  // Unknown / no live result yet -> last-known persisted value (sticky).
  return store.isProtectedMinorFor(pubkey);
});
```

Add the import at the top of the file: `import 'package:openvine/services/protected_minor_sticky_store.dart';`

- [ ] **Step 6: Verify the provider file compiles + existing seam tests pass**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/providers/protected_minor_providers_test.dart`
Expected: PASS (existing tests still green; the seam now sticky-backed). If an existing test asserted `isProtectedMinorProvider` on a bare fake without `sharedPreferencesProvider`/`authServiceProvider` overrides, add `sharedPreferencesProvider.overrideWithValue(await SharedPreferences.getInstance())` (with `SharedPreferences.setMockInitialValues({})`) to that test's `ProviderContainer` overrides.

- [ ] **Step 7: Commit**

```bash
cd ~/code/divine-mobile
git add mobile/lib/services/protected_minor_sticky_store.dart mobile/test/services/protected_minor_sticky_store_test.dart mobile/lib/providers/protected_minor_providers.dart
git commit -m "feat(minor-safety): persisted fail-safe protected-minor sticky store backing the seam (#175)"
```

---

### Task 2: `AgeVerificationService` choke point

**Files:**
- Modify: `mobile/lib/services/age_verification_service.dart`
- Modify: `mobile/lib/providers/moderation_providers.dart` (wire the callback in `ageVerificationService`)
- Test: `mobile/test/services/age_verification_protected_minor_test.dart`

**Interfaces:**
- Consumes: `isProtectedMinorProvider` (Task 1).
- Produces: `AgeVerificationService({bool Function()? isProtectedMinor})` where `isAdultContentVerified`, `verifyAdultContentAccess`, `setAdultContentVerified` respect the protected-minor signal.

- [ ] **Step 1: Write the failing test**

Create `mobile/test/services/age_verification_protected_minor_test.dart`:

```dart
// ABOUTME: Verifies the protected-minor lock on AgeVerificationService — the
// ABOUTME: single choke point that forces adult content off for #175.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('isAdultContentVerified is false for a protected minor even if stored true', () async {
    final service = AgeVerificationService(isProtectedMinor: () => true);
    await service.initialize();
    await service.setAdultContentVerified(true); // must be rejected below
    expect(service.isAdultContentVerified, false);
  });

  test('setAdultContentVerified(true) is rejected for a protected minor', () async {
    var protected = true;
    final service = AgeVerificationService(isProtectedMinor: () => protected);
    await service.initialize();
    await service.setAdultContentVerified(true);
    // Even after lifting the protection, nothing was persisted as true.
    protected = false;
    expect(service.isAdultContentVerified, false);
  });

  test('non-protected account behaves normally', () async {
    final service = AgeVerificationService(isProtectedMinor: () => false);
    await service.initialize();
    await service.setAdultContentVerified(true);
    expect(service.isAdultContentVerified, true);
  });

  test('defaults to not-protected when no callback supplied', () async {
    final service = AgeVerificationService();
    await service.initialize();
    await service.setAdultContentVerified(true);
    expect(service.isAdultContentVerified, true);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/services/age_verification_protected_minor_test.dart`
Expected: FAIL — the `isProtectedMinor` named param does not exist / lock not enforced.

- [ ] **Step 3: Write the minimal implementation**

In `mobile/lib/services/age_verification_service.dart`, add the constructor + field and guard the three members. Change the class opening from `class AgeVerificationService {` and the first fields to:

```dart
class AgeVerificationService {
  AgeVerificationService({bool Function()? isProtectedMinor})
    : _isProtectedMinor = isProtectedMinor ?? _notProtected;

  static bool _notProtected() => false;

  final bool Function() _isProtectedMinor;
```

Change the getter:

```dart
  bool get isAdultContentVerified =>
      !_isProtectedMinor() && (_isAdultContentVerified ?? false);
```

At the top of `verifyAdultContentAccess`, before `checkAdultContentVerification`:

```dart
  Future<bool> verifyAdultContentAccess(BuildContext context) async {
    // Protected minors can never unlock adult content; no dialog.
    if (_isProtectedMinor()) return false;
    // First check if already verified
    if (await checkAdultContentVerification()) {
```

At the top of `setAdultContentVerified`:

```dart
  Future<void> setAdultContentVerified(bool verified) async {
    if (verified && _isProtectedMinor()) {
      Log.warning(
        'Blocked adult-content verification for a protected minor',
        name: 'AgeVerificationService',
        category: LogCategory.system,
      );
      return;
    }
    try {
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/services/age_verification_protected_minor_test.dart test/services/age_verification_service_test.dart`
Expected: PASS (new file + existing age_verification tests still green).

- [ ] **Step 5: Wire the callback in the provider**

In `mobile/lib/providers/moderation_providers.dart`, change the `ageVerificationService` provider body:

```dart
AgeVerificationService ageVerificationService(Ref ref) {
  final service = AgeVerificationService(
    isProtectedMinor: () => ref.read(isProtectedMinorProvider),
  );
  service.initialize(); // Initialize asynchronously
  return service;
}
```

Add the import at the top of `moderation_providers.dart`: `import 'package:openvine/providers/protected_minor_providers.dart';` (only if not already present). This is a body change to a codegen provider — no `build_runner` needed (signature unchanged).

- [ ] **Step 6: Verify the wider content-filter path still compiles + passes**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/services/content_filter_service_test.dart`
Expected: PASS (ContentFilterService reads the getter; unaffected for non-protected).

- [ ] **Step 7: Commit**

```bash
cd ~/code/divine-mobile
git add mobile/lib/services/age_verification_service.dart mobile/lib/providers/moderation_providers.dart mobile/test/services/age_verification_protected_minor_test.dart
git commit -m "feat(minor-safety): force adult content off + block self-attestation for protected minors (#175)"
```

---

### Task 3: Safety Settings locked affordance

**Files:**
- Modify: `mobile/lib/blocs/safety_settings/safety_settings_state.dart` (add `isAdultContentLocked`)
- Modify: `mobile/lib/blocs/safety_settings/safety_settings_cubit.dart` (constructor param + load + guard)
- Modify: `mobile/lib/screens/safety_settings_screen.dart` (compute lock, pass to cubit, disable tile)
- Modify: `mobile/lib/l10n/app_en.arb` (one string) then run `flutter gen-l10n`
- Test: `mobile/test/blocs/safety_settings/safety_settings_cubit_test.dart` (extend)

**Interfaces:**
- Consumes: `isProtectedMinorProvider` (Task 1).
- Produces: `SafetySettingsState.isAdultContentLocked`; `SafetySettingsCubit(... , bool isAdultContentLocked = false)`.

- [ ] **Step 1: Write the failing test**

Add to `mobile/test/blocs/safety_settings/safety_settings_cubit_test.dart` (inside `main()`'s group; the `setUp` already stubs the 7 services — construct the cubit with the new named arg). Add these tests:

```dart
    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'load() surfaces isAdultContentLocked for a protected minor',
      build: () => SafetySettingsCubit(
        ageVerificationService: ageService,
        contentFilterService: filterService,
        videoEventService: videoEventService,
        divineHostFilterService: divineHostFilterService,
        moderationLabelService: moderationLabelService,
        followRepository: followRepository,
        contentBlocklistRepository: blocklistRepository,
        isAdultContentLocked: true,
      ),
      act: (cubit) => cubit.load(),
      expect: () => [
        isA<SafetySettingsState>().having(
          (s) => s.status,
          'status',
          SafetySettingsStatus.loading,
        ),
        isA<SafetySettingsState>()
            .having((s) => s.status, 'status', SafetySettingsStatus.ready)
            .having((s) => s.isAdultContentLocked, 'locked', true),
      ],
    );

    blocTest<SafetySettingsCubit, SafetySettingsState>(
      'setAgeVerified is a no-op when adult content is locked',
      build: () => SafetySettingsCubit(
        ageVerificationService: ageService,
        contentFilterService: filterService,
        videoEventService: videoEventService,
        divineHostFilterService: divineHostFilterService,
        moderationLabelService: moderationLabelService,
        followRepository: followRepository,
        contentBlocklistRepository: blocklistRepository,
        isAdultContentLocked: true,
      ),
      act: (cubit) => cubit.setAgeVerified(true),
      verify: (_) {
        verifyNever(() => ageService.setAdultContentVerified(true));
      },
    );
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/blocs/safety_settings/safety_settings_cubit_test.dart`
Expected: FAIL — `isAdultContentLocked` named arg and state field do not exist.

- [ ] **Step 3: Add the state field**

In `mobile/lib/blocs/safety_settings/safety_settings_state.dart`, add `this.isAdultContentLocked = false` to the constructor, `final bool isAdultContentLocked;`, the `copyWith` param + assignment, and add it to `props`. Full field additions:

Constructor param line (after `this.isAgeVerified = false,`): `this.isAdultContentLocked = false,`
Field (after `final bool isAgeVerified;`): `final bool isAdultContentLocked;`
copyWith param (after `bool? isAgeVerified,`): `bool? isAdultContentLocked,`
copyWith body (after `isAgeVerified: isAgeVerified ?? this.isAgeVerified,`): `isAdultContentLocked: isAdultContentLocked ?? this.isAdultContentLocked,`
props (after `isAgeVerified,`): `isAdultContentLocked,`

- [ ] **Step 4: Add the cubit param + guard**

In `mobile/lib/blocs/safety_settings/safety_settings_cubit.dart`:

Add constructor named param (after `required ContentBlocklistRepository contentBlocklistRepository,`): `bool isAdultContentLocked = false,`
Add to initializer list (after `_contentBlocklistRepository = contentBlocklistRepository,`): `_isAdultContentLocked = isAdultContentLocked,`
Add field (with the other finals): `final bool _isAdultContentLocked;`

In `load()`, add `isAdultContentLocked: _isAdultContentLocked,` to the ready-state `copyWith`.

In `setAgeVerified`, guard at the top:

```dart
  Future<void> setAgeVerified(bool value) async {
    if (_isAdultContentLocked) return; // protected minors cannot toggle
    await _ageVerificationService.setAdultContentVerified(value);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd ~/code/divine-mobile/mobile && flutter test test/blocs/safety_settings/safety_settings_cubit_test.dart`
Expected: PASS (new + existing cubit tests green).

- [ ] **Step 6: Add the l10n string + wire the screen**

In `mobile/lib/l10n/app_en.arb`, after the `safetySettingsAgeRequired` entry add:

```json
  "safetySettingsAgeLockedForMinor": "Locked for your account",
  "@safetySettingsAgeLockedForMinor": {
    "description": "Subtitle shown on the disabled adult-content toggle for protected minors"
  },
```

Run: `cd ~/code/divine-mobile/mobile && flutter gen-l10n`

In `mobile/lib/screens/safety_settings_screen.dart`:
- In `build`, add: `final isAdultContentLocked = ref.watch(isProtectedMinorProvider);` (import `protected_minor_providers.dart` if needed).
- Pass `isAdultContentLocked: isAdultContentLocked,` to the `SafetySettingsCubit(...)` create call, and add `isAdultContentLocked` to the `ValueKey((...))` tuple so the cubit reloads if it flips.
- Change `_AgeVerificationTile` to read the lock and disable:

```dart
class _AgeVerificationTile extends StatelessWidget {
  const _AgeVerificationTile();

  @override
  Widget build(BuildContext context) {
    final isAgeVerified = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isAgeVerified,
    );
    final isLocked = context.select(
      (SafetySettingsCubit cubit) => cubit.state.isAdultContentLocked,
    );
    return CheckboxListTile(
      value: isLocked ? false : isAgeVerified,
      onChanged: isLocked
          ? null
          : (value) {
              if (value != null) {
                context.read<SafetySettingsCubit>().setAgeVerified(value);
              }
            },
      title: Text(
        context.l10n.safetySettingsAgeConfirmation,
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        isLocked
            ? context.l10n.safetySettingsAgeLockedForMinor
            : context.l10n.safetySettingsAgeRequired,
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      activeColor: VineTheme.vineGreen,
      checkColor: VineTheme.backgroundColor,
      controlAffinity: ListTileControlAffinity.leading,
    );
  }
}
```

- [ ] **Step 7: Widget test for the disabled tile**

Add to `mobile/test/screens/safety_settings_screen_test.dart` a focused test that pumps the screen (or `SafetySettingsView`) with a `SafetySettingsCubit` whose state has `isAdultContentLocked: true`, and asserts the adult `CheckboxListTile` has `onChanged == null` (disabled) and shows the locked subtitle. Follow the existing test-harness pattern in that file for providing the cubit/state. Expected: PASS.

- [ ] **Step 8: Run the touched suites + analyzer**

Run:
```
cd ~/code/divine-mobile/mobile
flutter analyze lib/services/protected_minor_sticky_store.dart lib/services/age_verification_service.dart lib/blocs/safety_settings lib/screens/safety_settings_screen.dart lib/providers/protected_minor_providers.dart lib/providers/moderation_providers.dart
flutter test test/services/protected_minor_sticky_store_test.dart test/services/age_verification_protected_minor_test.dart test/services/age_verification_service_test.dart test/services/content_filter_service_test.dart test/blocs/safety_settings/safety_settings_cubit_test.dart test/screens/safety_settings_screen_test.dart
```
Expected: analyzer clean; all tests PASS.

- [ ] **Step 9: Commit**

```bash
cd ~/code/divine-mobile
git add mobile/lib/blocs/safety_settings mobile/lib/screens/safety_settings_screen.dart mobile/lib/l10n mobile/test/blocs/safety_settings/safety_settings_cubit_test.dart mobile/test/screens/safety_settings_screen_test.dart
git commit -m "feat(minor-safety): disable the adult-content toggle for protected minors (#175)"
```

---

## Self-Review

**Spec coverage:** Unit 1 sticky store + seam (Task 1) ✔; Unit 2 choke point on `isAdultContentVerified` + `verifyAdultContentAccess` + `setAdultContentVerified` (Task 2) ✔; Unit 3 disabled toggle + cubit guard (Task 3) ✔; fail-safe machine (protected→persist, notProtected→lift, unknown→retain, per-account, cold-start) tested in Task 1 ✔; non-protected unchanged (default `() => false`) tested in Task 2 ✔. Scope mobile-only ✔.

**Placeholder scan:** none — every code step carries real code. Task 3 Step 7 references the existing screen-test harness rather than inventing one; that's a deliberate "follow the file's pattern" instruction, not a placeholder for logic.

**Type consistency:** `ProtectedMinorStickyStore({required SharedPreferences prefs})`, `isProtectedMinorFor(String?)`, `applyLiveStatus(String?, ProtectedMinorStatus)`, `AgeVerificationService({bool Function()? isProtectedMinor})`, `SafetySettingsState.isAdultContentLocked`, `SafetySettingsCubit(..., bool isAdultContentLocked = false)`, `isProtectedMinorProvider` (Provider<bool>) — all consistent across tasks and match the real APIs verified in the codebase (`ProtectedMinorStatusKind`, `currentAuthStateProvider`, `authServiceProvider.currentPublicKeyHex`, `sharedPreferencesProvider`).
