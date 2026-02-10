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
