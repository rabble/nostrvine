# Security Issues

Issues related to hardcoded secrets, sensitive data exposure, secure storage, key handling, and production build safety.

Note: The project has strong security foundations. Nostr private keys use `flutter_secure_storage` with iOS Keychain / Android EncryptedSharedPreferences, `SecureKeyContainer` implements memory wiping with `Finalizer` and callback-scoped access, bug report sanitizer redacts nsec keys/passwords/tokens, and backend configs use `--dart-define` environment injection. These issues cover the remaining gaps.

---

### Private key escapes SecureKeyContainer into a local variable
**Problem**: `createAnonymousAccountFromKeyContainer` extracts the private key from the secure container into a `String?` local variable that persists on the heap beyond the callback scope.

**Evidence**: `mobile/lib/services/auth_service.dart` lines 940–949: `String? privateKeyHex;` followed by `keyContainer.withPrivateKey<void>((privateKey) { privateKeyHex = privateKey; });` then `await createAnonymousAccountFromPrivateKeyHex(privateKeyHex!);`. The `SecureKeyContainer.withPrivateKey` callback is designed to minimize key exposure time. Capturing the key into a closure variable bypasses this protection because the string remains in Dart heap memory indefinitely until GC collects it. `secure_key_container.dart` lines 145–146 explicitly documents that "the returned value must be used immediately and not stored."

**Done well**: `secure_key_container.dart` (lines 145–146) documents the correct callback-scoped pattern with memory wiping via `Finalizer`. Most other call sites follow this pattern correctly; this is an isolated escape.

**Impact**: Medium. In a memory dump or debugger session, the plaintext private key hex would be visible as a live Dart string object.

**Effort**: Low. Refactor to call `createAnonymousAccountFromPrivateKeyHex` inside the `withPrivateKey` callback, or pass the container directly to the downstream method.

**GitHub ticket**: TBD

---

### `getPrivateKeyForSigning` returns raw private key as String
**Problem**: `AuthService.getPrivateKeyForSigning()` returns the raw hex private key as a `String?`, meaning any caller holds the key in a Dart string with no lifecycle control.

**Evidence**: `mobile/lib/services/auth_service.dart` lines 3145–3161: the method calls `_keyStorage.withPrivateKey<String?>((privateKeyHex) => privateKeyHex, ...)` and returns the result. This pattern undermines the `SecureKeyContainer`'s design of minimizing key exposure time through callback-scoped access.

**Impact**: Medium. Callers receive the private key as a plain string that lives in Dart heap memory until garbage collected. If any code path stores the result in a field or variable, the key exposure window widens significantly.

**Effort**: Medium. Redesign to accept a callback (signing operation) rather than returning the raw key, consistent with the `withPrivateKey` pattern used elsewhere.

**GitHub ticket**: TBD

---

### All logs captured to in-memory buffer regardless of sensitivity
**Problem**: The `UnifiedLogger` captures all log messages to an in-memory ring buffer (50,000 entries) regardless of log level or category filtering. This buffer is used for bug reports.

**Evidence**: `mobile/packages/unified_logger/lib/src/unified_logger.dart` lines 174–188: `// CRITICAL: ALWAYS capture to memory regardless of category/level filtering`. The bug report sanitizer (`bug_report_config.dart` lines 39–49) does redact `nsec1...` patterns and passwords, which is good. However, hex private keys (64-char hex strings) are explicitly NOT redacted (comment: "We do NOT redact 64-char hex strings because that would redact public event IDs and pubkeys"). Any error path that includes a hex-format private key in an error message would pass through unsanitized to bug reports.

**Done well**: `bug_report_config.dart` (lines 39–49) already redacts `nsec1...` patterns, passwords, and tokens at report time. The sanitization infrastructure exists; the gap is pre-capture filtering for hex-format keys.

**Impact**: Medium. While the sanitizer catches nsec-format keys, the architecture creates risk for future regressions where hex-format private keys could leak into bug reports.

**Effort**: Medium. Add a pre-capture filter to `UnifiedLogger._log()` that scrubs known sensitive patterns before writing to the memory buffer, rather than relying solely on post-capture sanitization at report time.

**GitHub ticket**: TBD

