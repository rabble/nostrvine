# App Encryption Export Compliance

Status: Launch-critical
Validated against: `mobile/ios/Runner/Info.plist`, `mobile/pubspec.yaml`, `mobile/android/app/build.gradle.kts`, and current crypto-related dependencies on 2026-03-19.

## Submission Summary

- App name: `Divine`
- iOS bundle identifier: `co.openvine.app`
- Android application ID: `co.openvine.app`
- `ITSAppUsesNonExemptEncryption`: `false`

Divine uses publicly documented, standard cryptography for authentication, secure transport, secure local storage, and Nostr messaging features. It does not ship proprietary or custom cryptographic algorithms.

## Why The App Uses Encryption

Divine uses encryption for:

- HTTPS/TLS network transport
- Nostr event signing and identity keys
- encrypted Nostr messaging flows
- secure device storage of keys and credentials
- ProofMode and related authenticity features

These functions rely on standard, publicly available algorithms and libraries.

## Current Cryptography Categories

### Transport security

- TLS 1.2 / 1.3 over HTTPS
- standard exempt transport security

### Nostr identity and signing

- secp256k1-based key pairs and signatures
- standard public-key cryptography used by the Nostr ecosystem

### Encrypted messaging

- NIP-44 and legacy encrypted-message support via standard published algorithms

### Local secure storage

- iOS Keychain
- Android Keystore
- `flutter_secure_storage`

### Authenticity and proof features

- ProofMode-related signing and verification via standard open-source libraries

## Current Dependency Record

Relevant current app-level dependencies include:

- `nostr_sdk`
- `crypto`
- `flutter_secure_storage`
- `c2pa_flutter`
- `app_device_integrity`

If the crypto dependency set changes, re-validate this document before submission.

## Submission Guidance

The current repo truth supports answering export-compliance questions as:

- the app uses encryption: `Yes`
- the app uses only exempt or standard publicly available encryption: `Yes`
- non-exempt encryption declaration required in the binary: `No`

That is why `ITSAppUsesNonExemptEncryption` remains `false`.

## Re-Validation Checklist

- [ ] `mobile/ios/Runner/Info.plist` still contains `ITSAppUsesNonExemptEncryption = false`
- [ ] the app still relies only on standard published crypto primitives
- [ ] no proprietary or custom encryption implementation has been introduced
- [ ] App Store Connect answers match this document

## Related Docs

- [docs/APP_STORE_REVIEW_DOSSIER.md](/Users/lizsw/divine-mobile/docs/APP_STORE_REVIEW_DOSSIER.md)
- [mobile/docs/APPLE_REVIEW_RESPONSE.md](/Users/lizsw/divine-mobile/mobile/docs/APPLE_REVIEW_RESPONSE.md)
