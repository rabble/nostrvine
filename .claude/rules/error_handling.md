# Error Handling

---

## Documentation

### Document When Calls May Throw
Document exceptions in function documentation to help callers handle errors properly:

**Good:**
```dart
/// Permanently deletes an account with the given [name].
///
/// Throws:
///
/// * [UnauthorizedException] if the active role is not [Role.admin], since only
///   admins are authorized to delete accounts.
/// * [NetworkException] if the server is unreachable.
void deleteAccount(String name) {
  if (activeRole != Role.admin) {
    throw UnauthorizedException('Only admin can delete account');
  }
  // ...
}
```

**Bad:**
```dart
/// Permanently deletes an account with the given [name].
void deleteAccount(String name) {
  if (activeRole != Role.admin) {
    throw UnauthorizedException('Only admin can delete account');
    // Caller has no idea this can throw!
  }
}
```

### Document No-Operations
When code intentionally does nothing, document why:

**Good:**
```dart
class BluetoothProcessor extends NetworkProcessor {
  @override
  void abort() {
    // Intentional no-op: Bluetooth has no resources to clean on abort.
  }
}
```

**Bad:**
```dart
class BluetoothProcessor extends NetworkProcessor {
  @override
  void abort() {}  // Did someone forget to implement this?
}
```

---

## Custom Exceptions

### Use Descriptive Exception Classes
Create specific exceptions rather than using generic `Exception`:

**Good:**
```dart
class UnauthorizedException implements Exception {
  UnauthorizedException(this.message);
  final String message;

  @override
  String toString() => 'UnauthorizedException: $message';
}

class NetworkException implements Exception {
  NetworkException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => 'NetworkException($statusCode): $message';
}

// Usage
void deleteAccount(String name) {
  if (activeRole != Role.admin) {
    throw UnauthorizedException('Only admin can delete account');
  }
}

void main() {
  try {
    deleteAccount('user');
  } on UnauthorizedException catch (e) {
    // Handle unauthorized specifically
  } on NetworkException catch (e) {
    // Handle network issues
  }
}
```

**Bad:**
```dart
void deleteAccount(String name) {
  if (activeRole != Role.admin) {
    throw Exception('Only admin can delete account');  // Too generic!
  }
}

void main() {
  try {
    deleteAccount('user');
  } on Exception catch (e) {
    // Catches everything - no granular handling possible
  }
}
```

---

## Reportable errors and Crashlytics

A project-wide `BlocObserver` (`DivineBlocObserver`) writes every Bloc/Cubit
error to the unified log. Forwarding to **Crashlytics** is gated on the
error implementing `ReportableError` — without that gate, expected domain
errors (network timeouts, "no public key yet" during cold start, 4xx
responses, validation failures) flood the dashboard and drown the real
bugs.

**Default**: an error is NOT reportable. Wrap with `Reportable(e, context:
'<callsite>')` only when the matrix below says YES.

### Decision matrix

| Category | Reportable? | Why |
|---|---|---|
| Network / IO (timeout, dropped connection, DNS) | NO | Expected on flaky networks. Surface via UI status enum. |
| API / domain (4xx, server validation) | NO | Expected, often user-input-driven. |
| Auth / session (token expired, signed out) | NO | Expected during cold start and after logout. |
| Form / business-rule validation | NO | Surface in UI. |
| `StateError`, `TypeError`, `RangeError` | YES | Programming-invariant violation. |
| Project-owned `*InvariantException` types | YES | Domain code intentionally signaling impossibility. |
| When in doubt | NO | Better to under-report and migrate later than flood. |

### Migration recipe

If the matrix says YES, wrap the inner error at the `addError` call site:

```dart
} catch (e, stackTrace) {
  Log.error('Foo failed', name: 'FooBloc', error: e, stackTrace: stackTrace);
  addError(Reportable(e, context: '_onFooSubmitted'), stackTrace);
  emit(state.copyWith(status: FooStatus.failure));
}
```

Important: anything that reaches the generic `catch (e, stackTrace)` block is
being implicitly classified as reportable. If you add a new expected/domain
failure path that should stay out of Crashlytics, add a specific
`on FooException catch` handler above the generic catch and handle it there.

`Reportable<T>` is an `Exception` (via the `ReportableError` marker), so
existing `errors: () => [isA<Exception>()]` `blocTest` assertions stay
green. Tests that pin a specific inner type — e.g. `isA<StateError>()` —
need to update after migration. Note that inside a `catch (e, st)` block
`e` is statically `Object`, so `Reportable(e, ...)` infers
`Reportable<Object>`. Assert on the unwrap rather than the generic:

```dart
errors: () => [
  isA<Reportable<Object>>().having(
    (r) => r.unwrap(),
    'unwrap',
    isA<StateError>(),
  ),
],
```

`Reportable.toString()` uses `error.runtimeType` rather than the static
`T`, so Crashlytics still groups by the actual inner type even when
`T == Object`.

### Naming `context` identifiers

The `context` parameter is a free-form `String?` — same shape as
`Log.error(name: 'XxxBloc')` used elsewhere in the codebase. For a single
migrated site in a feature, a string literal at the call site is fine:

```dart
addError(Reportable(e, context: '_publishLike'), stackTrace);
```

Once a feature accumulates **2+ migrated sites**, lift the identifiers
into a per-feature constants class colocated with the bloc:

```dart
abstract class VideoInteractionsReportableSites {
  static const publishLike = '_publishLike';
  static const publishRepost = '_publishRepost';
}

addError(
  Reportable(e, context: VideoInteractionsReportableSites.publishLike),
  stackTrace,
);
```

Class naming: `<FeatureNoun>ReportableSites`. Members are
`static const String`.

Per-feature constants (rather than a global enum) keep PR-stack
parallelism — each feature-area migration PR edits only its own constants
file, not a shared hot-spot. Crashlytics groups by `error.runtimeType`
and the observer's `Bloc.addError $runtimeType` reason; `context` is
supplementary triage text, not a dashboard branching key, so the
typed-vs-string choice is a call-site discoverability decision rather
than a dashboard-taxonomy decision.

### PII

`Reportable.toString()` strips Nostr `npub1…` and `nsec1…` identifiers
before they reach Crashlytics. Other Nostr-format references (`note1`,
`nevent1`, `nprofile1`) encode pointers, not secrets, and are
intentionally left intact for triage value — call sites that need to
redact those should do so explicitly before constructing the error
message.

If you opt a project-owned exception in by `implements ReportableError`
directly (skipping the `Reportable` wrapper), the marker bypasses the
sanitizer. Make sure your `toString()` does not embed `npub` / `nsec`
strings, or wrap the throw with `Reportable` at the boundary instead.

---

## Error Handling Patterns

### Try-Catch Best Practices

```dart
// Catch specific exceptions first
try {
  await api.fetchData();
} on NetworkException catch (e) {
  // Handle network errors
  _showNetworkError(e.message);
} on UnauthorizedException catch (e) {
  // Handle auth errors
  _redirectToLogin();
} catch (e, stackTrace) {
  // Log unexpected errors
  _logError(e, stackTrace);
  rethrow;  // Or handle gracefully
}
```

### In BLoC/Cubit
```dart
Future<void> _onLoadData(
  LoadData event,
  Emitter<DataState> emit,
) async {
  emit(DataLoading());
  try {
    final data = await _repository.fetchData();
    emit(DataSuccess(data));
  } on NetworkException catch (e, stackTrace) {
    addError(e, stackTrace);
    emit(DataFailure('Network error: ${e.message}'));
  } catch (e, stackTrace) {
    addError(e, stackTrace);
    emit(DataFailure('Unexpected error'));
  }
}
```

---

## Security Essentials

### Never Ship Sensitive Keys
API keys in frontend code are ALWAYS vulnerable to extraction:

```dart
// NEVER do this
const apiKey = 'sk-secret-key-123';  // Extractable via reverse engineering!

// Instead: Use a backend proxy for sensitive APIs
```

### Secure Storage
Use platform-specific secure storage for sensitive data:

```dart
// Use flutter_secure_storage for credentials
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final storage = FlutterSecureStorage();
await storage.write(key: 'token', value: accessToken);
final token = await storage.read(key: 'token');
```

### Input Validation
Validate all user input before processing:

```dart
// Use packages like formz for validation
class Email extends FormzInput<String, EmailValidationError> {
  const Email.pure() : super.pure('');
  const Email.dirty([super.value = '']) : super.dirty();

  @override
  EmailValidationError? validator(String value) {
    return value.contains('@') ? null : EmailValidationError.invalid;
  }
}
```

### HTTPS Only
- Always use SSL/TLS for data transmission
- Consider certificate pinning for sensitive apps
- Never transmit sensitive data via SMS or push notifications

### Principle of Least Privilege
Only request permissions that are absolutely necessary for the app to function.

---

## Logging Errors

Use structured logging for errors:

```dart
import 'dart:developer' as developer;

try {
  await api.fetchData();
} catch (e, stackTrace) {
  developer.log(
    'Failed to fetch data',
    name: 'app.network',
    level: 1000,  // SEVERE
    error: e,
    stackTrace: stackTrace,
  );
  rethrow;
}
```

For production, integrate with error reporting services (Sentry, Crashlytics, etc.).
