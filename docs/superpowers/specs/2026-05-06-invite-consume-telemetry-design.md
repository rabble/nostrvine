# Invite Consume Telemetry Design

**Goal:** Preserve original exception context through invite activation failures so we can diagnose why consume calls fail and make informed decisions about retry behavior.

**Background:** When `consumeInviteWithSession` fails, the original exception (signer RPC failure, network error, timeout, etc.) is flattened into a generic `InviteApiException` string before the cubit sees it. This makes it impossible to distinguish transient signer failures from permanent errors, blocking informed retry logic. See [#3795](https://github.com/divinevideo/divine-mobile/issues/3795) -- Liz's comment recommends telemetry as the first PR before session preservation or classification changes.

**Scope:** Observability only. No changes to error classification, retry behavior, or UI.

---

## Changes

### 1. Add `cause` field to `InviteApiException`

**File:** `mobile/packages/invite_api_client/lib/src/invite_api_exception.dart`

Add an optional `Object? cause` field that carries the original exception. This follows the Dart convention used by `FormatException` and `HttpException`.

Update `toString()` to include the cause's `runtimeType` when present.

The constructor gains a named `cause` parameter. All existing call sites pass `null` implicitly (no breaking change).

### 2. Thread `cause` through wrap sites in `invite_api_client.dart`

**File:** `mobile/packages/invite_api_client/lib/src/invite_api_client.dart`

The following wrap/throw sites already have the original error in scope. Pass it as `cause`:

| Location | Current behavior | Change |
|----------|-----------------|--------|
| `_wrapClientException` (TimeoutException branch) | Discards original | Pass `error` as `cause` |
| `_wrapClientException` (network/generic branch) | Embeds in message string | Pass `error` as `cause` |
| `_createAuthorizationHeader` final catch block | Embeds in message string | Pass `error` as `cause` |
| `consumeInviteWithSession` catch block | Discards original | Pass `error` as `cause` |
| `consumeInviteWithKeyContainer` catch block | Discards original | Pass `error` as `cause` |

`_requestFailed` does NOT need `cause` -- it wraps HTTP responses, not exceptions.

### 3. Log original exception context before classification

**Files:**
- `mobile/lib/blocs/email_verification/email_verification_cubit.dart` -- `_exchangeCodeAndLogin` InviteApiException catch block
- `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart` -- `_exchangeCodeAndLogin` InviteApiException catch block

Enhance existing `Log.error` calls to include structured fields:

```dart
Log.error(
  'Invite activation failed: ${e.message} '
  '[code=${e.code}, status=${e.statusCode}, '
  'cause=${e.cause?.runtimeType}: ${e.cause}]',
  name: '...',
  category: LogCategory.auth,
);
```

This logs: the error code (for classification), the HTTP status (for server errors), and the original exception type + message (for signer/network/timeout diagnosis).

### 4. Log signer stage failures in `_createAuthorizationHeader`

**File:** `mobile/packages/invite_api_client/lib/src/invite_api_client.dart`

The auth header construction has three distinct failure points: `getPublicKey()`, `signEvent()`, and event serialization. The existing catch block at line ~435 flattens all three into `"Failed to authenticate invite request: $error"`.

Add the `_warningLogger` call before rethrowing to capture which stage failed:

```dart
_warningLogger?.call(
  'Auth header construction failed: ${error.runtimeType}: $error',
);
```

This uses the existing `_warningLogger` callback (already wired to `Log.warning` in production) without adding a direct logging dependency to the API client package.

---

## What this enables

After this PR ships and runs in production for a release cycle, we'll have data to answer:

- What fraction of consume failures are signer RPC errors vs network vs timeout vs auth rejection?
- Are `unknown`-classified failures actually a specific typed exception we should handle?
- Is retry worthwhile, and for which failure types?

That data informs PR 2 (session preservation + consume retry) and PR 3 (classification tightening).

---

## Testing

- Unit test: `InviteApiException` with `cause` field roundtrips correctly, `toString()` includes cause type
- Unit test: `_wrapClientException` preserves cause for TimeoutException, network errors, and generic errors
- Existing cubit tests continue to pass (cause is optional, defaults to null)
- No new UI tests needed (no UI changes)

## References

- [#3795](https://github.com/divinevideo/divine-mobile/issues/3795) -- Liz's recommended PR sequence
- [#3860](https://github.com/divinevideo/divine-mobile/pull/3860) -- Error classification improvement (already merged)
