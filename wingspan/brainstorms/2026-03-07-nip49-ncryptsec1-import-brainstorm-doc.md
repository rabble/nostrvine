---
date: 2026-03-07
topic: nip49-ncryptsec1-import
---

# NIP-49 ncryptsec1 Import Support

## What We're Building

Add support for importing a password-encrypted Nostr private key (`ncryptsec1`) in the `KeyImportScreen`. When a user pastes an `ncryptsec1` string, the screen expands inline to show a password field. On submit, the key is decrypted using the NIP-49 algorithm (scrypt + AES-256-GCM) and the recovered private key is imported through the existing `nsec` path.

This is general-purpose support — `ncryptsec1` is the standard portable encrypted key format across the Nostr ecosystem and Divine should accept it wherever `nsec` is accepted.

## Why This Approach

Three placement options were considered for the NIP-49 decryption logic:
1. **In `nostr_sdk`** alongside the existing `Nip19` class — chosen because all Nostr protocol encoding/decoding already lives there, and it avoids scattering protocol logic across packages.
2. In `nostr_key_manager` co-located with `SecureKeyStorage` — reasonable but mixes storage concerns with protocol decoding.
3. Via a pub.dev package — adds a dependency with uncertain maintenance.

For the UX, an inline password field (expanding `KeyImportScreen` when `ncryptsec1` is detected) was chosen over a modal/bottom sheet because it keeps the import flow on one screen, consistent with the existing text-field-first pattern.

## Key Decisions

- **Decryption in `nostr_sdk`**: Add `Nip49` class to `packages/nostr_sdk/lib/nip49/` with `decode(ncryptsec, password) → nsecHex` and `encode(nsecHex, password) → ncryptsec` (encode is useful for future backup export).
- **Inline UX in `KeyImportScreen`**: Detect `ncryptsec1` prefix on text change; conditionally show a password field below the key field. No new screen or route needed.
- **Auth pipeline**: Add `AuthService.importFromNcryptsec(ncryptsec, password)` that decrypts via `Nip49.decode()` then delegates to the existing `importFromNsec()` path. No changes needed in `SecureKeyStorage`.
- **Crypto dependencies**: NIP-49 requires scrypt (KDF) and AES-256-GCM. Dart's `pointycastle` package (already used in the project via `nostr_sdk`) provides both. No new packages needed.
- **Key security byte**: NIP-49 encodes a `key_security_byte` (0=unknown, 1=weak/cloned, 2=medium/hardware). We read it but do not surface it in the UI for now — it can be logged or stored as metadata in a follow-up.
- **Error handling**: Wrong password produces an AES-GCM auth tag failure. Show an inline error "Incorrect password" rather than a generic failure.

## Layers Touched

| Layer | Change |
|-------|--------|
| `nostr_sdk` (data) | New `Nip49` class: bech32 decode, scrypt KDF, AES-256-GCM decrypt/encrypt |
| `AuthService` (service) | New `importFromNcryptsec(ncryptsec, password)` method |
| `KeyImportScreen` (UI) | Detect `ncryptsec1` prefix, show password field inline, wire to new auth method |

## Open Questions

- Should we surface the `key_security_byte` anywhere in the UI (e.g. a warning if the key is marked as "weak/cloned")?
- Should we also add `ncryptsec1` **export** (backup) as part of this issue, or defer to a separate issue?
- Are there existing test fixtures (known ncryptsec1 vectors) from the NIP-49 spec we can use for unit tests?
