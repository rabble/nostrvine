# DM Chunk 5 — Isolate Decryption Spike Findings

Research-only investigation for Chunk 5 Task 15. Question: can NIP-17
gift-wrap decryption safely cross a Dart isolate boundary for this app's
signers?

## 1. Signer implementations found

Production `NostrSigner` implementers in the tree:

- `mobile/lib/services/auth_service_signer.dart:21` — `AuthServiceSigner`
  (the default local signer, wraps `SecureKeyContainer`).
- `mobile/packages/nostr_sdk/lib/signer/local_nostr_signer.dart:8` —
  `LocalNostrSigner` (pure nsec-in-memory signer from the SDK; used in
  tests/sandbox, not the main auth path).
- `mobile/packages/nostr_sdk/lib/signer/pubkey_only_nostr_signer.dart:4` —
  `PubkeyOnlyNostrSigner` (read-only, cannot decrypt).
- `mobile/packages/keycast_flutter/lib/src/rpc/keycast_rpc.dart:12` —
  `KeycastRpc` (remote RPC over network).
- `mobile/packages/nostr_sdk/lib/nip46/nostr_remote_signer.dart:33` —
  `NostrRemoteSigner` (NIP-46 bunker; remote).
- `mobile/packages/nostr_sdk/lib/nip55/android_nostr_signer.dart:27` —
  `AndroidNostrSigner` (Amber; platform channel).
- `mobile/packages/nostr_sdk/lib/nip07/nip07_signer.dart:12` — `NIP07Signer`
  (web extension; not in mobile runtime path).

Active selection in `lib/services/auth_service.dart:208`:
`rpcSigner => _amberSigner ?? _bunkerSigner ?? _keycastSigner`, falling back
to `AuthServiceSigner(keyContainer)` in `NostrServiceFactory.create`
(`lib/services/nostr_service_factory.dart:50`).

## 2. Local-key signer path

No direct getter, but the key IS reachable through a scoped callback.

`AuthServiceSigner` holds a `SecureKeyContainer?`. `SecureKeyContainer`
(`packages/nostr_key_manager/lib/src/secure_key_container.dart:147`) exposes:

```dart
T withPrivateKey<T>(T Function(String privateKeyHex) operation)
```

This is a **synchronous** callback returning `T` — we can extract the hex
string inside the callback on the main isolate, pass it to `compute()` as a
`String`, and run NIP-44 decrypt in the worker. The container itself is NOT
sendable (has `Finalizer`, `Uint8List` fields, dispose state), but the hex
string it yields IS.

The actual NIP-44 primitives used by `GiftWrapUtil.getRumorEvent`
(`packages/nostr_sdk/lib/nip59/gift_wrap_util.dart:12`) are both static and
pure-Dart:

- `NIP44V2.shareSecret(privateKeyHex, pubkey)` — ECDH, no I/O.
- `NIP44V2.decrypt(ciphertext, sharedKey)` — ChaCha20/HMAC, no I/O.

So a top-level `decryptGiftWrapBatch(List<Map> rawEvents, String privKeyHex)`
function can re-implement the two-stage unwrap (outer gift-wrap → seal →
rumor) entirely inside an isolate with no reference to `Nostr`, `NostrSigner`,
or `SecureKeyContainer`.

`LocalNostrSigner._privateKey` is a private field with no getter — if we
ever route through it directly we would need either a getter or to
instantiate from hex up front. Not an issue for the current app since
`AuthServiceSigner` is the production path.

## 3. Remote signer fallback (main-isolate only)

These MUST continue to decrypt on the main isolate — their `nip44Decrypt`
implementations cross a network or platform boundary:

- `KeycastRpc.nip44Decrypt` — JSON-RPC call to Keycast server
  (`keycast_flutter/lib/src/rpc/keycast_rpc.dart:96`).
- `NostrRemoteSigner` — NIP-46 relay roundtrip.
- `AndroidNostrSigner` — Amber platform channel + user prompt.

Isolate routing must gate on `signer is AuthServiceSigner &&
keyContainer?.hasPrivateKey == true`. Anything else falls back to the
existing `RumorDecryptor` typedef path.

## 4. Gift wrap serialization

`Event` has `factory Event.fromJson(Map<String, dynamic>)` at
`packages/nostr_sdk/lib/event.dart:46` and `Map<String, dynamic> toJson()`
at line 88. Round-tripping through JSON maps is already the wire format, so
batches can cross the isolate boundary as `List<Map<String, dynamic>>` in
and `List<Map<String, dynamic>>?` out (or null for failed decrypts). The
existing seal-pubkey-override logic in `getRumorEvent` (lines 45-53) is
trivially portable into a top-level helper.

## 5. Go/no-go recommendation

**GO (clean).** No source changes to signer classes are required. The plan
can add a pure-Dart top-level function, e.g.:

```dart
// lib/repositories/dm_isolate_decrypt.dart (new file, no edits to signers)
Future<List<Map<String, dynamic>?>> decryptGiftWrapBatch(
  ({List<Map<String, dynamic>> events, String privateKeyHex}) args,
) async { ... }
```

Call site in `DmRepository._handleGiftWrapEvent` (or a new batch handler):

```dart
if (_signer is AuthServiceSigner &&
    (_signer as AuthServiceSigner)._keyContainer?.hasPrivateKey == true) {
  final hex = (_signer as AuthServiceSigner)
      ._keyContainer!
      .withPrivateKey((k) => k); // sync extraction
  final rumors = await compute(decryptGiftWrapBatch,
      (events: rawEvents, privateKeyHex: hex));
  // ...
} else {
  // existing _rumorDecryptor path on main isolate
}
```

Minor caveat: `_keyContainer` is currently private on `AuthServiceSigner`.
Exposing a narrow accessor such as `bool get canDecryptInIsolate` plus
`T withPrivateKeyHex<T>(T Function(String) op)` on `AuthServiceSigner` keeps
the key scoped and avoids leaking the container itself. That is a ~6-line
addition to one file when Task 15 is implemented, NOT a spike blocker. The
existing `SecureKeyContainer.withPrivateKey` contract already assumes the
caller will briefly materialize the hex string, so this does not weaken the
current security posture.

Verdict: proceed with the isolate optimization as designed. Remote signers
(Amber / bunker / Keycast RPC) continue on the main isolate via the same
type guard.
