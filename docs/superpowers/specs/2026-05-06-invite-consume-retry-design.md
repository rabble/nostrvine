# Invite Consume Retry Design

Status: Current
Validated against: `invite_api_client`, `EmailVerificationCubit`, `DivineAuthCubit` on 2026-05-06.

PR 2 of 3 for #3795. Adds automatic retry on transient consume failures across all three invite activation paths.

## Problem

After Keycast registration burns the user's email, invite consumption on darshan can fail due to NIP-98 clock skew, network errors, or transient server issues. The user sees an error screen with no recourse. PR 1 added telemetry to identify failure causes. This PR retries consumption automatically before surfacing errors.

## Approach

Retry the `consumeInviteWithSession` / `consumeInviteWithKeyContainer` call up to 3 times on retryable errors. Each retry generates a fresh NIP-98 timestamp via `_createAuthorizationHeader` (which uses `DateTime.now()`), addressing the clock-skew case. Retries are invisible to the user.

For session-based paths, persist the `KeycastSession` to FlutterSecureStorage immediately after token exchange, before consume. This ensures the session survives even if all retries fail.

## Retryable vs Terminal

Use `InviteErrorUtils.classify()` to decide. Two reasons are retryable:

- **`temporary`**: timeout, network error, HTTP 429, 5xx, `storage_error`, `internal_error`, `client_timeout`, `client_network_error`
- **`authFailure`**: `auth_required`, `auth_invalid`, `auth_expired`, `auth_invalid_binding`, `client_auth_failed` (clock skew lives here)

Terminal (no retry): `alreadyUsed`, `invalid`, `creatorFull`, `unknown`.

Including `authFailure` as retryable is the key bet. Clock skew causes stale NIP-98 timestamps, and a fresh retry fixes that. PR 3 tightens this classification based on telemetry data from PR 1.

## Retry Shape

All three consume paths get the same logic:

- 3 attempts max, 2-second delay between retries
- On retryable error: log warning with attempt number, delay, retry
- On terminal error: rethrow immediately
- On last attempt failure: rethrow (caller handles error state as before)
- Retries are invisible to the user (no UI changes)

Worst case the user waits ~6 seconds (attempt 1 + 2s + attempt 2 + 2s + attempt 3) before seeing an error. In the success case, most retries resolve on attempt 2.

## Three Consume Paths

| Path | Cubit | Method | Signer | Session persistence |
|------|-------|--------|--------|---------------------|
| Post-email-verification | `EmailVerificationCubit` | `consumeInviteWithSession` | `KeycastRpc` | Save before consume |
| Direct sign-in | `DivineAuthCubit._exchangeCodeAndLogin` | `consumeInviteWithSession` | `KeycastRpc` | Save before consume |
| Anonymous skip | `DivineAuthCubit.skipWithAnonymousAccount` | `consumeInviteWithKeyContainer` | `LocalNostrSigner` | Not needed (key in memory) |

## Shared Retry Helper

Extract retry logic to a helper in `invite_error_utils.dart` rather than duplicating the loop in three places:

```dart
static Future<InviteConsumeResult> retryConsume({
  required Future<InviteConsumeResult> Function() consume,
  required void Function(String message) log,
  int maxAttempts = 3,
  Duration delay = const Duration(seconds: 2),
})
```

The helper:
1. Calls `consume()`
2. On `InviteApiException`, classifies via `InviteErrorUtils.classify()`
3. If retryable and not last attempt: log, delay, retry
4. If terminal or last attempt: rethrow

Both cubits call this wrapper around their `consumeInviteWith*` call.

## Existing 409 Retry Loop

`EmailVerificationCubit._consumeInviteWithSessionIfNeeded` has a 409-only retry loop (3 attempts, 500ms delay). The broader retry **replaces** this. The 409 case is subsumed: a 409 without `user_already_joined` error code classifies as `temporary` via status code fallback in `InviteErrorUtils.classify()`.

The method simplifies to a single `retryConsume()` call, removing the manual loop.

`DivineAuthCubit._consumeInviteWithSessionIfNeeded` has no retry today. It gains retry via the same `retryConsume()` wrapper.

## Session Preservation

`KeycastSession` already has `save()`, `load()`, and `clear()` methods using FlutterSecureStorage (key: `keycast_session`). No new persistence code needed.

In both session-based paths, add `await session.save()` immediately after `KeycastSession.fromTokenResponse(tokenResponse)` and before calling consume. This ensures the session is recoverable if all retries fail. The session is later used by `signInWithDivineOAuth()` regardless, so persisting it early has no downside.

For the anonymous path, the `SecureKeyContainer` is already held in memory for the duration of the try block. Retries reuse it directly. No persistence needed because no Keycast registration has occurred.

## Files Changed

| File | Change |
|------|--------|
| `mobile/lib/utils/invite_error_utils.dart` | Add `isRetryable()` and `retryConsume()` static methods |
| `mobile/lib/blocs/email_verification/email_verification_cubit.dart` | Replace 409 loop with `retryConsume()`, add `session.save()`, remove `_maxConsumeRetries` and `_consumeRetryDelay` constants |
| `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart` | Wrap both consume calls with `retryConsume()`, add `session.save()` in `_exchangeCodeAndLogin` |

No changes to `invite_api_client`. Retry is at the cubit layer, not the HTTP client layer.

## What This Does NOT Do

- No silent sign-in fallback after exhausting retries
- No UI changes (error states and messages unchanged)
- No error classification changes (PR 3 scope)
- No retry button (retries are automatic and invisible)
- No persistence for the anonymous path key container

## Testing

- Unit test `isRetryable()` for each `InviteActivationFailureReason`
- Unit test `retryConsume()`: retries on retryable error, stops on terminal, respects max attempts, rethrows on final failure
- Update `EmailVerificationCubit` tests to verify retry behavior replaces 409 loop
- Update `DivineAuthCubit` tests to verify retry on both session and anonymous paths
- Verify `session.save()` is called before consume in session-based paths
