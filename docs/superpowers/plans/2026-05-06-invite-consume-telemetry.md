# Invite Consume Telemetry Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Preserve original exception context through invite activation failures so we can diagnose why consume calls fail.

**Architecture:** Add an `Object? cause` field to `InviteApiException`, thread it through the five wrap/throw sites in `invite_api_client.dart`, and enhance log lines in both cubits to include the cause's `runtimeType`. No changes to classification, retry, or UI.

**Tech Stack:** Dart, Flutter BLoC, `invite_api_client` package

---

## File Structure

| File | Action | Responsibility |
|------|--------|---------------|
| `mobile/packages/invite_api_client/lib/src/invite_api_exception.dart` | Modify | Add `cause` field |
| `mobile/packages/invite_api_client/lib/src/invite_api_client.dart` | Modify | Thread `cause` at 5 wrap sites, add `_warningLogger` call |
| `mobile/lib/blocs/email_verification/email_verification_cubit.dart` | Modify | Enhance log line |
| `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart` | Modify | Enhance log line |
| `mobile/packages/invite_api_client/test/src/invite_api_exception_test.dart` | Create | Test `cause` field and `toString()` |
| `mobile/packages/invite_api_client/test/src/invite_api_client_test.dart` | Modify | Add `cause` assertions to existing error tests |

---

### Task 1: Add `cause` field to `InviteApiException`

**Files:**
- Modify: `mobile/packages/invite_api_client/lib/src/invite_api_exception.dart`
- Create: `mobile/packages/invite_api_client/test/src/invite_api_exception_test.dart`

- [ ] **Step 1: Write tests for the `cause` field**

Create `mobile/packages/invite_api_client/test/src/invite_api_exception_test.dart`:

```dart
import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:invite_api_client/invite_api_client.dart';

void main() {
  group('InviteApiException', () {
    test('cause defaults to null', () {
      const exception = InviteApiException('test error');
      expect(exception.cause, isNull);
    });

    test('preserves cause when provided', () {
      final cause = TimeoutException('timed out');
      final exception = InviteApiException(
        'Request failed',
        cause: cause,
      );
      expect(exception.cause, same(cause));
    });

    test('toString includes cause runtimeType when present', () {
      final exception = InviteApiException(
        'Request failed',
        code: InviteApiErrorCode.clientTimeout,
        cause: TimeoutException('timed out'),
      );
      final str = exception.toString();
      expect(str, contains('TimeoutException'));
    });

    test('toString omits cause when null', () {
      const exception = InviteApiException(
        'Request failed',
        code: InviteApiErrorCode.clientTimeout,
      );
      final str = exception.toString();
      expect(str, isNot(contains('cause')));
    });

    test('const constructor still works without cause', () {
      const exception = InviteApiException(
        'test',
        statusCode: 401,
        code: InviteApiErrorCode.authInvalid,
      );
      expect(exception.message, 'test');
      expect(exception.statusCode, 401);
      expect(exception.cause, isNull);
    });

    test('preserves SocketException as cause', () {
      const cause = SocketException('Connection refused');
      final exception = InviteApiException(
        'Network error',
        code: InviteApiErrorCode.clientNetworkError,
        cause: cause,
      );
      expect(exception.cause, isA<SocketException>());
      expect(exception.cause.toString(), contains('Connection refused'));
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run from `mobile/`:
```bash
cd mobile && flutter test packages/invite_api_client/test/src/invite_api_exception_test.dart
```
Expected: Compile error — `cause` parameter does not exist yet.

- [ ] **Step 3: Add `cause` field to `InviteApiException`**

Replace the full class in `mobile/packages/invite_api_client/lib/src/invite_api_exception.dart` (keep `InviteApiErrorCode` unchanged). The class becomes:

```dart
class InviteApiException implements Exception {
  const InviteApiException(
    this.message, {
    this.statusCode,
    this.responseBody,
    this.code,
    this.creatorSlug,
    this.creatorDisplayName,
    this.cause,
  });

  final String message;
  final int? statusCode;
  final String? responseBody;
  final String? code;
  final String? creatorSlug;
  final String? creatorDisplayName;
  final Object? cause;

  @override
  String toString() {
    final buffer = StringBuffer(
      'InviteApiException(message: $message, statusCode: $statusCode, '
      'code: $code',
    );
    if (cause != null) {
      buffer.write(', cause: ${cause.runtimeType}: $cause');
    }
    buffer.write(')');
    return buffer.toString();
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
cd mobile && flutter test packages/invite_api_client/test/src/invite_api_exception_test.dart
```
Expected: All 6 tests PASS.

- [ ] **Step 5: Run existing package tests to verify no regressions**

```bash
cd mobile && flutter test packages/invite_api_client/test/
```
Expected: All existing tests PASS (const constructors unaffected since `cause` defaults to null).

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/invite_api_client/lib/src/invite_api_exception.dart mobile/packages/invite_api_client/test/src/invite_api_exception_test.dart
git commit -m "feat(invites): add cause field to InviteApiException

Preserves the original exception through wrap sites so cubits can
log the underlying failure type. Part of #3795 telemetry work."
```

---

### Task 2: Thread `cause` through wrap sites

**Files:**
- Modify: `mobile/packages/invite_api_client/lib/src/invite_api_client.dart`
- Modify: `mobile/packages/invite_api_client/test/src/invite_api_client_test.dart`

- [ ] **Step 1: Add `cause` assertions to existing error tests**

In `mobile/packages/invite_api_client/test/src/invite_api_client_test.dart`, add `.having` matchers for `cause` to three existing tests:

**Test "surfaces validateCode timeout failures as InviteApiException"** (~line 179): add to the `throwsA` matcher chain:

```dart
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<TimeoutException>(),
                )
```

**Test "surfaces validateCode transport failures as InviteApiException"** (~line 211): add to the `throwsA` matcher chain:

```dart
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<SocketException>(),
                )
```

**Test "surfaces consumeInvite timeout failures with a structured code"** (~line 467): add to the `throwsA` matcher chain:

```dart
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<TimeoutException>(),
                )
```

**Test "surfaces consumeInvite network failures with a structured code"** (~line 499): add to the `throwsA` matcher chain:

```dart
                .having(
                  (error) => error.cause,
                  'cause',
                  isA<SocketException>(),
                )
```

**Test "surfaces invite signing failures with a structured auth code"** (~line 529): add to the `throwsA` matcher chain:

```dart
                .having(
                  (error) => error.cause,
                  'cause',
                  isNotNull,
                )
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd mobile && flutter test packages/invite_api_client/test/src/invite_api_client_test.dart
```
Expected: FAIL — `cause` is null because wrap sites don't pass it yet.

- [ ] **Step 3: Thread `cause` through `_wrapClientException`**

In `mobile/packages/invite_api_client/lib/src/invite_api_client.dart`, replace `_wrapClientException`:

```dart
  InviteApiException _wrapClientException({
    required Object error,
    required String timeoutMessage,
    required String failureMessage,
  }) {
    if (error is InviteApiException) return error;
    if (error is TimeoutException) {
      return InviteApiException(
        timeoutMessage,
        code: InviteApiErrorCode.clientTimeout,
        cause: error,
      );
    }

    final code = _isNetworkError(error)
        ? InviteApiErrorCode.clientNetworkError
        : InviteApiErrorCode.clientError;
    return InviteApiException('$failureMessage: $error', code: code, cause: error);
  }
```

- [ ] **Step 4: Thread `cause` through `consumeInviteWithKeyContainer` catch**

In the same file, replace the catch block in `consumeInviteWithKeyContainer`:

```dart
    } catch (error) {
      throw InviteApiException(
        'Failed to authenticate invite request: $error',
        code: InviteApiErrorCode.clientAuthFailed,
        cause: error,
      );
    }
```

- [ ] **Step 5: Thread `cause` through `consumeInviteWithSession` catch**

In the same file, replace the catch block in `consumeInviteWithSession`:

```dart
    } catch (error) {
      throw InviteApiException(
        'Failed to authenticate invite request: $error',
        code: InviteApiErrorCode.clientAuthFailed,
        cause: error,
      );
    }
```

- [ ] **Step 6: Thread `cause` through `_createAuthorizationHeader` catch**

In the same file, replace the final catch block in `_createAuthorizationHeader`:

```dart
    } catch (error) {
      throw InviteApiException(
        'Failed to authenticate invite request: $error',
        code: InviteApiErrorCode.clientAuthFailed,
        cause: error,
      );
    }
```

- [ ] **Step 7: Run tests to verify they pass**

```bash
cd mobile && flutter test packages/invite_api_client/test/
```
Expected: All tests PASS, including the new `cause` assertions.

- [ ] **Step 8: Commit**

```bash
git add mobile/packages/invite_api_client/lib/src/invite_api_client.dart mobile/packages/invite_api_client/test/src/invite_api_client_test.dart
git commit -m "feat(invites): thread cause through exception wrap sites

_wrapClientException, consumeInviteWithSession,
consumeInviteWithKeyContainer, and _createAuthorizationHeader now
preserve the original error as InviteApiException.cause. Part of
#3795 telemetry work."
```

---

### Task 3: Log signer stage failures via `_warningLogger`

**Files:**
- Modify: `mobile/packages/invite_api_client/lib/src/invite_api_client.dart`

- [ ] **Step 1: Add `_warningLogger` call to `_createAuthorizationHeader`**

In `mobile/packages/invite_api_client/lib/src/invite_api_client.dart`, in `_createAuthorizationHeader`, update the final catch block:

```dart
    } catch (error) {
      _warningLogger?.call(
        'Auth header construction failed: ${error.runtimeType}: $error',
      );
      throw InviteApiException(
        'Failed to authenticate invite request: $error',
        code: InviteApiErrorCode.clientAuthFailed,
        cause: error,
      );
    }
```

Note: The `_createAuthorizationHeader` catch block is only reachable when a signer's `getPublicKey()` or `signEvent()` throws a non-`InviteApiException` error (e.g., an RPC transport failure from `KeycastRpc`). This path is exercised in production by Keycast bunker relay failures but is difficult to unit test without mocking deep Keycast internals. The `_warningLogger` call lives next to the `throw` that IS tested by "surfaces invite signing failures with a structured auth code" — verified by code review.

- [ ] **Step 2: Run tests to verify no regressions**

```bash
cd mobile && flutter test packages/invite_api_client/test/
```
Expected: All tests PASS.

- [ ] **Step 3: Commit**

```bash
git add mobile/packages/invite_api_client/lib/src/invite_api_client.dart
git commit -m "feat(invites): log auth header construction failures

Calls _warningLogger before rethrowing so signer/RPC failures are
visible in production logs. Part of #3795 telemetry work."
```

---

### Task 4: Enhance cubit log lines with cause context

**Files:**
- Modify: `mobile/lib/blocs/email_verification/email_verification_cubit.dart`
- Modify: `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart`

- [ ] **Step 1: Enhance `EmailVerificationCubit` log line**

In `mobile/lib/blocs/email_verification/email_verification_cubit.dart`, in `_exchangeCodeAndLogin`, replace the `InviteApiException` catch block's log call:

```dart
      } on InviteApiException catch (e) {
        Log.error(
          'Invite activation failed: ${e.message} '
          '[code=${e.code}, status=${e.statusCode}, '
          'cause=${e.cause?.runtimeType}: ${e.cause}]',
          name: 'EmailVerificationCubit',
          category: LogCategory.auth,
        );
```

The rest of the catch block (lines saving `inviteCode`, calling `_cleanup()`, emitting state) stays unchanged.

- [ ] **Step 2: Enhance `DivineAuthCubit` log line**

In `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart`, in `_exchangeCodeAndLogin`, replace the `InviteApiException` catch block's log call:

```dart
    } on InviteApiException catch (e) {
      Log.error(
        'Invite activation failed: ${e.message} '
        '[code=${e.code}, status=${e.statusCode}, '
        'cause=${e.cause?.runtimeType}: ${e.cause}]',
        name: 'DivineAuthCubit',
        category: LogCategory.auth,
      );
```

The rest of the catch block (lines checking `current is DivineAuthFormState`, emitting state) stays unchanged.

- [ ] **Step 3: Run both cubit test suites**

```bash
cd mobile && flutter test test/blocs/email_verification/email_verification_cubit_test.dart test/blocs/divine_auth/divine_auth_cubit_test.dart
```
Expected: All tests PASS. Log output changes don't affect assertions (existing tests don't inspect log strings).

- [ ] **Step 4: Run full test suite**

```bash
cd mobile && flutter test
```
Expected: All tests PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/blocs/email_verification/email_verification_cubit.dart mobile/lib/blocs/divine_auth/divine_auth_cubit.dart
git commit -m "feat(invites): log original exception context on consume failure

Both cubits now log error code, HTTP status, and the original
exception type when invite activation fails. Part of #3795
telemetry work."
```

---

### Task 5: Final verification and cleanup

- [ ] **Step 1: Run full package and app test suites**

```bash
cd mobile && flutter test packages/invite_api_client/test/ && flutter test
```
Expected: All tests PASS.

- [ ] **Step 2: Run analyzer**

```bash
cd mobile && flutter analyze
```
Expected: No issues introduced by these changes.

- [ ] **Step 3: Verify const call sites still compile**

Grep to confirm all `const InviteApiException(...)` usages still exist and haven't been broken:

```bash
grep -rn "const InviteApiException" mobile/ --include="*.dart"
```
Expected: Same set of call sites as before (10 occurrences). None needed modification.
