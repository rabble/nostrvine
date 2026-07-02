# Protected-minor adult-content lock (mobile) — design

**Issue:** divinevideo/support-trust-safety#175 (part of the protected-minor epic #173; consumes the #174 seam, merged as divine-mobile#5708)
**Date:** 2026-07-01
**Status:** design approved, ready for implementation plan

## Problem

For a protected minor (an approved 13-15 account), adult content must be locked off and the minor must be unable to turn it on. Today the lock exists but is trivially bypassable: `ContentFilterService` keeps adult categories at `hide` only while `AgeVerificationService.isAdultContentVerified` is false, and any user flips that true by tapping "Are you 18+?" in the self-attestation dialog (`verifyAdultContentAccess`). A teen just taps yes.

This drives the lock from the protected-minor state instead, and removes the self-attestation escape for flagged minors.

## Key insight: one choke point

Every adult-content decision funnels through a single getter, `AgeVerificationService.isAdultContentVerified`:
- `ContentFilterService.getPreference` / `setPreference` — settings lock
- `media_auth_interceptor` — playback gate (and it triggers the self-attestation dialog)
- `safety_settings_cubit` — the settings toggle
- `individual_video_providers`, `pooled_age_restricted_retry` — playback retry paths

Making that one getter protected-minor-aware locks all paths at once. (Approved: single-getter choke point.)

## Design

Three units.

### Unit 1 — Sticky protected-minor state (the decided fail-safe)

The #174 seam (`protectedMinorStatusProvider` / `isProtectedMinorProvider`) is async and evaluates to `false` at cold start until a network read resolves. #175's decided fail-safe requires an account, once confirmed a protected minor, to be treated as protected immediately at cold start and offline, lifting only on a positive "no longer a minor" signal.

New `ProtectedMinorStickyStore` (service, `mobile/lib/services/protected_minor_sticky_store.dart`):
- Persists last-known protected status **per account** in `SharedPreferences`, key `protected_minor_sticky_<pubkey>`.
- `bool get isProtectedMinor` — synchronous, backed by an in-memory value loaded at init (local read only, no network), so it is valid at cold start.
- `Future<void> loadForAccount(String? pubkey)` — loads the persisted value for the current account into memory (call on init and on account switch). Null/unknown pubkey → `false`.
- `Future<void> applyLiveStatus(ProtectedMinorStatus status)` — the fail-safe state machine, keyed off `ProtectedMinorStatusKind`:
  - `kind == protected` → persist + cache `true`.
  - `kind == notProtected` (the only confirmed not-a-minor response; `isKnown && !isProtectedMinor`) → persist + cache `false` (the age-up / revocation lift).
  - `kind == unknown` (fetch failed/unavailable) → **no change** (sticky; retain last-known).

Wiring: `protectedMinorStickyStoreProvider` (keepAlive). A sync provider/listener watches `protectedMinorStatusProvider` (the #174 live fetch) and the current pubkey, and pushes resolved statuses into `applyLiveStatus`. This reuses #174's fetch rather than duplicating it.

The shared seam `isProtectedMinorProvider` is upgraded to read the sticky store, so the fail-safe posture backs the seam itself (benefiting #176 later too). This supersedes #174's detection-only "fail open on error" note, exactly as the #175 issue states.

We do not special-case keycast downtime: a keycast outage never weakens protection, and we never guess "minor" for an account we have not confirmed (an account never once confirmed simply stays unprotected).

### Unit 2 — The choke point (`AgeVerificationService`)

`AgeVerificationService` gains an injected `bool Function() isProtectedMinor` (named param, defaults to `() => false` so existing constructor calls and tests are unaffected):
- `isAdultContentVerified` → returns `false` when `isProtectedMinor()`, regardless of the stored self-attestation bool.
- `verifyAdultContentAccess(context)` → returns `false` immediately when `isProtectedMinor()`, without showing the dialog.
- `setAdultContentVerified(value)` → when `value == true && isProtectedMinor()`, reject (log + return without persisting). Setting `false` is always allowed (more restrictive).

Wired in `moderation_providers.dart`: `AgeVerificationService(isProtectedMinor: () => ref.read(protectedMinorStickyStoreProvider).isProtectedMinor)`. Because `ContentFilterService`, `media_auth_interceptor`, and the cubits all consult this getter, they inherit the lock with no changes.

### Unit 3 — Settings affordance (`safety_settings`)

`SafetySettingsState` gains `isAdultContentLocked` (bool). `SafetySettingsCubit.load()` sets it from the sticky store; `setAgeVerified` is a guarded no-op when locked (defense in depth; the service already blocks). `safety_settings_screen` renders the adult-content toggle **visible but disabled**, with a short explanation line ("Locked for your account") so the minor sees the protection exists rather than a silently dead toggle. (Approved UX.)

## Scope

Mobile only. Web (#453) is a separate stub, blocked on web#456 merging. This PR is the divine-mobile describing task for #175.

## Testing

- **Sticky store (unit):** persist-true on confirmed-protected; lift-to-false on confirmed-not-protected; retain on unknown/error; per-pubkey isolation; sync `isProtectedMinor` reflects the persisted value after `loadForAccount` (cold-start behavior).
- **AgeVerificationService (unit):** `isAdultContentVerified` false when protected even with the stored bool true; `verifyAdultContentAccess` returns false and shows no dialog when protected; `setAdultContentVerified(true)` rejected when protected; all three behave normally when not protected.
- **ContentFilterService (unit/integration):** adult categories resolve to `hide` and `setPreference` to non-hide is rejected when protected (through the overridden getter).
- **SafetySettingsCubit (unit):** `state.isAdultContentLocked` true when protected; `setAgeVerified(true)` is a no-op when locked.
- **Widget (light):** the adult-content toggle renders disabled when locked. (One focused widget test; UI-render coverage kept minimal per testing philosophy.)

## Acceptance

A protected-minor account cannot view adult content (categories forced `hide`, playback gate closed) and cannot enable the adult-content toggle (the self-attestation bypass is unavailable), including at cold start and offline once the account has been confirmed a protected minor.
