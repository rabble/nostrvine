# SQLCipher at-rest encryption for the local DB (#570, finding C2)

Status: **device-QA gated before merge.** The full Dart implementation, the
native dependency swap, and unit tests for every host-testable property are
committed. What remains before merge is **on-device validation** (the encrypted
open, the in-place migration, and the iOS/macOS build configuration) — none of
it can be exercised in CI, which links plain sqlite3 and on which
`PRAGMA cipher_version` is empty. See the device-QA checklist at the bottom.

## Why

DMs (and the rest of the shared `divine_db.db`: drafts, pending uploads,
pending actions, outgoing DMs, reactions, reposts, notifications, bookmarks,
NIP-05 verifications) are stored **plaintext at rest** today. For a moderation
account holding reports about users, plaintext-at-rest is materially more
sensitive. Decision (#570): encrypt at rest before the T&S moderation launch.

## What is NOT in scope

- **Web / IndexedDB** (`connection_web.dart`): SQLCipher is native-only. Web
  at-rest encryption is deferred behind the OPFS migration (#373). The app
  guards encryption with `kIsWeb`; the web connection variants throw
  `UnsupportedError` and are never reached.
- **Backend D1 retention**: the backend stores DMs plaintext indefinitely in
  `dm_log` — a separate data-minimization item (tracked as #570 Decision 8).
- **The `cache_sync.db` cache**: it shares the SQLCipher runtime but is opened
  unkeyed (plaintext), which SQLCipher supports. Only `divine_db.db` is keyed.

## Committed in this PR (host-verified)

### Dependency swap — `mobile/pubspec.yaml`
- `sqlite3_flutter_libs ^0.5.40` → **`sqlcipher_flutter_libs ^0.6.8`**. The two
  cannot coexist (both ship a native sqlite3 that collides on iOS/macOS). 0.6.x
  is the SQLCipher build for the sqlite3 2.x family; **0.7.0+ is an EOL no-op**.
- Removed **`drift_flutter`** — it was unused (db_client opens `NativeDatabase`
  directly) and transitively pulled `sqlite3_flutter_libs` back in,
  reintroducing the collision.
- Added **`sqlite3`** as a direct dep so the Android library override
  (`package:sqlite3/open.dart`) is referenceable.

### db_client (`connection_native.dart` + web/stub variants)
- `formatCipherKeyPragma(rawKeyHex)` — builds the raw-key `PRAGMA key`. **The
  thrown `ArgumentError` never embeds the key** (fixes the #4945 review finding).
- `applyCipherKey(db, rawKeyHex)` — keys the connection and **fails closed**:
  if `PRAGMA cipher_version` is empty (SQLCipher not linked) it throws rather
  than silently writing plaintext.
- `openEncryptedConnection({rawKeyHex})` — keyed `NativeDatabase` for the app
  to inject the key into (db_client never reads the keystore).
- `migratePlaintextToEncrypted({rawKeyHex})` — one-time in-place rekey via
  `sqlcipher_export`, **safe by construction**: writes a side file, verifies it
  (key opens it; table/row counts match the source) before swapping, renames
  the plaintext original to a backup rather than deleting it, and leaves the
  source intact on any failure (retries next launch). Copies `user_version`
  (drift's schema version) explicitly, which `sqlcipher_export` does not.
  Wipe-and-resync is rejected: `divine_db.db` holds local-only data that cannot
  be re-fetched.
- `backUpAndRemoveSharedDatabase()` — used by the §6 key-loss recovery.

### App layer
- `lib/database/sqlcipher_runtime.dart` (+ `_io` / `_stub`) — conditional-import
  glue: on Android, `applyWorkaroundToOpenSqlCipherOnOldAndroidVersions()` +
  `open.overrideFor(OperatingSystem.android, openCipherOnAndroid)`; a runtime
  `isSqlCipherAvailable()` probe. No-op on web (no dart:ffi).
- `lib/services/database_encryption_bootstrap.dart` — reads/generates a 32-byte
  CSPRNG key in `flutter_secure_storage` (`db.cipher.key.v1`, 64 hex; never
  logged), forces the SQLCipher runtime, runs the migration, and resolves the
  key for the database provider. Throws if SQLCipher is not linked.
- `lib/providers/db_cipher_key_provider.dart` — `Provider<String?>` (null
  default → plaintext for web/tests), overridden in `main.dart`.
- `lib/providers/database_provider.dart` — opens an encrypted connection when a
  key is present, else the default connection.
- `lib/main.dart` — resolves the key before the `ProviderContainer`; on failure
  reports to Crashlytics and degrades to plaintext (the device-QA gate prevents
  an unencrypted build from shipping).

### §6 key-loss behavior (implemented; pending product signoff)
If the keystore is cleared (OS reset / restore without keychain migration), the
cipher key is gone and the encrypted DB is cryptographically unrecoverable. The
bootstrap detects this (freshly generated key + an existing encrypted DB),
**backs up the unrecoverable DB and recreates it under a new key** — DMs resync
from relays; other local-only data is preserved in the backup but unavailable
to the app without the lost key. This is the only possible recovery for an
unrecoverable DB, but the user-facing notice / exact UX **needs product
signoff** before merge.

## Device-QA-gated (NOT committed — must be done on real devices)

### iOS / macOS build configuration
- On Apple platforms `package:sqlite3` resolves to the SQLCipher pod **only
  when it is the sole sqlite3 provider** (now true after dropping
  `sqlite3_flutter_libs`). If a future pod links plain sqlite3, `PRAGMA key`
  silently no-ops. Mitigations to apply and verify on device:
  - Add `-framework SQLCipher` to **Other Linker Flags** in the Runner target,
    and ensure no `libsqlite3.dylib`/`.tbd` sits in *Link Binary With
    Libraries*.
  - A Podfile `post_install` that defines `SQLITE_HAS_CODEC=1` across pod build
    configurations (mirror the SQLCipher podspec) if any pod is found linking
    plain sqlite3.
- App Store **export compliance**: AES-256 at rest is standard crypto. Set
  `ITSAppUsesNonExemptEncryption` in `Info.plist` and confirm the exemption
  with the compliance owner.

These are intentionally not committed half-validated; the committed runtime
`cipher_version` fail-closed check is the safety net regardless of build config.

## Device-QA checklist (must pass before merge)
- [ ] iOS / Android / macOS build + launch with `sqlcipher_flutter_libs`.
- [ ] Fresh install: DB is created encrypted; `PRAGMA cipher_version` is
      non-empty; the file is not readable by plain `sqlite3`.
- [ ] Upgrade from a populated **plaintext** DB: migration runs once, all
      tables + row counts preserved, app fully functional, plaintext backup
      present until the first successful keyed open, then cleaned.
- [ ] Force-kill mid-migration → next launch recovers (plaintext intact,
      retried), no data loss.
- [ ] Key-loss path (clear keystore): DB is backed up + recreated, DMs resync,
      app does not brick. (Confirm the §6 UX with product first.)
- [ ] No measurable regression on cold-start DB open on a low-end device
      (SQLCipher adds ~5–15%).
- [ ] Key never appears in logs / Crashlytics / analytics.
