# Plan: NIP-49 ncryptsec1 Import Support

**Type**: Feature
**Complexity**: Medium
**Brainstorm doc**: `wingspan/brainstorms/2026-03-07-nip49-ncryptsec1-import-brainstorm-doc.md`

---

## Issue Summary

Add support for importing a password-encrypted Nostr private key (`ncryptsec1`, NIP-49) in the `KeyImportScreen`. When the user pastes an `ncryptsec1` string, a password field appears inline. On submit, the app decrypts via scrypt + XChaCha20-Poly1305, then imports the recovered private key through the existing `nsec` path.

> **Note**: NIP-49 uses **XChaCha20-Poly1305** (not AES-256-GCM). The nonce is 24 bytes.

---

## Architecture Design

- **New packages needed**: None — `pointycastle` (scrypt) and `cryptography` (XChaCha20-Poly1305) are already `nostr_sdk` dependencies
- **Layers affected**: `nostr_sdk` package (data), `AuthService` (service), `KeyImportScreen` (UI)
- **Data flow**: UI captures `(ncryptsec, password)` → `AuthService.importFromNcryptsec()` → `Nip49.decode()` in `nostr_sdk` → hex private key → existing `AuthService.importFromHex()` path
- **Nostr spec**: NIP-49 payload is 91 bytes: `VERSION(1) + LOG_N(1) + SALT(16) + NONCE(24) + KEY_SECURITY_BYTE(1) + CIPHERTEXT(48)`, bech32-encoded with HRP `ncryptsec`

---

## Affected Files

| File | Action | Description |
|------|--------|-------------|
| `mobile/packages/nostr_sdk/lib/nip19/hrps.dart` | Modify | Add `ncryptsec` HRP constant |
| `mobile/packages/nostr_sdk/lib/nip49/nip49.dart` | Create | `Nip49` class with `decode()`, `encode()`, and `isEncryptedKey()` |
| `mobile/packages/nostr_sdk/lib/nostr_sdk.dart` | Modify | Export `nip49/nip49.dart` |
| `mobile/lib/services/auth_service.dart` | Modify | Add `importFromNcryptsec(ncryptsec, password)` |
| `mobile/lib/screens/key_import_screen.dart` | Modify | Detect `ncryptsec1`, show inline password field |
| `mobile/packages/nostr_sdk/test/unit/nip49_test.dart` | Create | Decrypt spec test vector, error cases |
| `mobile/test/screens/key_import_screen_test.dart` | Create | Password field visibility, import flow |

---

## Implementation Steps

### Step 1: [nostr_sdk] Add `ncryptsec` HRP constant

- File: `mobile/packages/nostr_sdk/lib/nip19/hrps.dart`
- Add: `static const String encryptedPrivateKey = 'ncryptsec';`
- Why: Centralises all HRP constants; used in `Nip49` for bech32 decode

### Step 2: [nostr_sdk] Create `Nip49` class

- File: `mobile/packages/nostr_sdk/lib/nip49/nip49.dart`

Methods:

**`static bool isEncryptedKey(String s)`**
- Returns `s.startsWith('ncryptsec1')`

**`static Future<String> decode(String ncryptsec, String password)`**
- Bech32-decode the string (91-byte payload)
- Parse: `version[0]`, `logN[1]`, `salt[2..17]`, `nonce[18..41]`, `keySecurityByte[42]`, `ciphertext[43..90]`
- Derive 32-byte symmetric key: `scrypt(password_utf8, salt, N=2^logN, r=8, p=1)` using `pointycastle`
- Decrypt: `XChaCha20-Poly1305(ciphertext, nonce, key, aad=[keySecurityByte])` using `cryptography`
- Return `HEX.encode(plaintext)` — the 32-byte raw private key as hex
- Throw `Nip49Exception` on wrong password (Poly1305 auth failure) or bad format
- Add comment: NFKC unicode normalization is required by spec for non-ASCII passwords but not yet implemented

**`static Future<String> encode(String privateKeyHex, String password, {int logN = 16})`**
- Inverse of decode (useful for future backup/export feature)

NIP-49 payload structure (91 bytes total):
```
[0]      VERSION_NUMBER = 0x02
[1]      LOG_N
[2..17]  SALT (16 bytes)
[18..41] NONCE (24 bytes)
[42]     KEY_SECURITY_BYTE (ASSOCIATED_DATA)
[43..90] CIPHERTEXT (32 bytes plaintext + 16 bytes Poly1305 tag = 48 bytes)
```

### Step 3: [nostr_sdk] Export `Nip49`

- File: `mobile/packages/nostr_sdk/lib/nostr_sdk.dart`
- Add: `export 'nip49/nip49.dart';`

### Step 4: [AuthService] Add `importFromNcryptsec`

- File: `mobile/lib/services/auth_service.dart`
- Add after `importFromNsec` (around line 1636):

```dart
/// Import identity from an ncryptsec1 encrypted private key (NIP-49).
///
/// Decrypts [ncryptsec] with [password] using scrypt + XChaCha20-Poly1305,
/// then imports the recovered private key via [importFromHex].
///
/// Throws:
/// - [Nip49Exception] if the password is incorrect or the format is invalid.
Future<AuthResult> importFromNcryptsec(String ncryptsec, String password)
```

- Calls `Nip49.decode(ncryptsec, password)` to get hex private key
- Delegates to existing `importFromHex(hexKey)`
- Catches `Nip49Exception` and returns `AuthResult.failure('Incorrect password')`

### Step 5: [UI] Update `KeyImportScreen`

- File: `mobile/lib/screens/key_import_screen.dart`
- Add state variables: `final _passwordController = TextEditingController()` and `bool _isEncryptedKey = false`
- Key field `onChanged`: add `setState(() => _isEncryptedKey = Nip49.isEncryptedKey(value.trim()))`
- In `build`: when `_isEncryptedKey` is true, show a `DivineAuthTextField` (obscured) for the password below the key field
- Update `_validateKey`:
  - Accept `ncryptsec1` prefix as a valid key format
  - When `_isEncryptedKey`, validate that password is non-empty
  - Remove the rejection of strings that don't start with `nsec` or aren't 64 chars (add `ncryptsec1` as a third valid format)
- Update `_importKey`: add branch `else if (Nip49.isEncryptedKey(keyText))` → `authService.importFromNcryptsec(keyText, _passwordController.text)`
- In `dispose`: add `_passwordController.dispose()`
- In the success handler: add `_passwordController.clear()`

---

## Testing Strategy

### `mobile/packages/nostr_sdk/test/unit/nip49_test.dart`

Use the official NIP-49 test vector:
- Input: `ncryptsec1qgg9947rlpvqu76pj5ecreduf9jxhselq2nae2kghhvd5g7dgjtcxfqtd67p9m0w57lspw8gsq6yphnm8623nsl8xn9j4jdzz84zm3frztj3z7s35vpzmqf6ksu8r89qk5z2zxfmu5gv8th8wclt0h4p`
- Password: `nostr`, log_n: 16
- Expected hex: `3501454135014541350145413501453fefb02227e449e57cf4d3a3ce05378683`

Test cases:
- `decode()` with correct password returns expected hex (spec test vector)
- `decode()` with wrong password throws `Nip49Exception`
- `decode()` with non-ncryptsec1 string throws
- `isEncryptedKey()` returns true for `ncryptsec1...`
- `isEncryptedKey()` returns false for `nsec1...`, hex, `bunker://`
- Round-trip: `encode()` then `decode()` returns original private key

### `mobile/test/screens/key_import_screen_test.dart`

Test cases:
- Password field is not visible on initial render
- Password field appears when `ncryptsec1...` is entered in key field
- Password field disappears when key field is changed to `nsec1...`
- Tapping import with ncryptsec1 + password calls `authService.importFromNcryptsec`
- Error shown when import returns failure (wrong password)

---

## Risks and Considerations

- **scrypt performance**: log_n=18 requires ~256 MiB and can take seconds. The `cryptography_flutter` package offloads to a platform thread. The existing `_isImporting` spinner already covers the loading state.
- **Bech32 length**: `ncryptsec1` strings are ~163 characters. Verify that `bech32` ^0.2.2 doesn't enforce the 90-char RFC limit — the existing NIP-19 `nprofile`/`nevent` usage (which exceed 90 chars) suggests it does not.
- **NFKC unicode normalization**: The spec requires passwords to be NFKC-normalized. Dart has no built-in support. For pure ASCII passwords this is a no-op; document the limitation.
- **Key security byte**: NIP-49 encodes whether the key was handled insecurely. We read it but don't surface it in the UI — future improvement.
