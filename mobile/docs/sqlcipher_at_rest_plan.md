# SQLCipher at-rest encryption for the local DB (#570, finding C2)

Status: **device-QA-gated draft.** This PR commits only the pure,
unit-tested key-pragma helper (`formatCipherKeyPragma`,
`connection_native.dart`). The native-lib swap, the app-layer key
bootstrap, the connection wiring, and the one-time plaintext→encrypted
migration are specified here and must be **validated on real devices**
before they land — they cannot be exercised in CI (the host test VM uses
`NativeDatabase.memory()` and never loads the SQLCipher native libraries).

## Why

DMs (and the rest of the shared `divine_db.db`: drafts, pending uploads,
pending actions, outgoing DMs, reactions, reposts, notifications,
bookmarks, NIP-05 verifications) are stored **plaintext at rest** today
(`connection_native.dart` opens a plain `NativeDatabase`; `db_client`
has no SQLCipher). For a moderation account holding reports about users,
plaintext-at-rest is materially more sensitive. Decision (#570): encrypt
at rest before the T&S moderation launch.

## What is NOT in scope

- **Web / IndexedDB** (`connection_web.dart`): SQLCipher is native-only.
  Web at-rest encryption is deferred behind the existing OPFS migration
  (`#373`). Desktop/macOS **is** covered by `sqlcipher_flutter_libs`.
- **Backend D1 retention**: the backend stores DMs plaintext indefinitely
  in `dm_log` — a separate data-minimization item (tracked separately).

## Implementation steps

### 1. Native lib swap (build-config; device QA)
`mobile/pubspec.yaml:293` — replace `sqlite3_flutter_libs: ^0.5.40` with
`sqlcipher_flutter_libs: ^0.5.x` (same simolus3 family). Both `db_client`
and `cache_sync` resolve `package:sqlite3` to the cipher build, so one
lib covers both. Run `flutter pub get`; commit the `pubspec.lock` delta.
**QA: full device builds on iOS, Android, and macOS** — this changes the
linked SQLite for the whole app.

### 2. Key bootstrap (app layer)
New `mobile/lib/services/database_encryption_bootstrap.dart`:
- Call `sqlcipher_flutter_libs`' `applyWorkaroundToOpenSqlite3OnOldAndroidVersions()`
  and `open.overrideForAll(openCipherOnAndroid())` (per the package docs)
  so `package:sqlite3` binds the cipher build **before** the first
  `AppDatabase()` open.
- Read-or-generate a **32-byte CSPRNG** key in `flutter_secure_storage`
  under `db.cipher.key.v1`, hex-encoded (64 chars). Generate once; never
  log it; never derive it from anything guessable.

### 3. Key custody respects the layer boundary
`db_client` stays low-level and must **not** import
`flutter_secure_storage`. The app reads the key and **injects** it.
Add `openEncryptedConnection({required String rawKeyHex})` to the three
connection variants:
- `connection_native.dart` (real): `NativeDatabase(file, setup: (raw) =>
  raw.execute(formatCipherKeyPragma(rawKeyHex)))` — `formatCipherKeyPragma`
  is the helper committed in this PR.
- `connection_web.dart` (delegate-and-ignore — no native cipher on web).
- `connection_stub.dart` (throw `UnsupportedError`).

### 4. Provider wiring
- `dbCipherKeyProvider` seeded at app root via
  `ProviderScope(overrides: [dbCipherKeyProvider.overrideWithValue(key)])`
  after the bootstrap resolves the key.
- `database_provider.dart` opens `AppDatabase(openEncryptedConnection(
  rawKeyHex: ref.watch(dbCipherKeyProvider)))`.

### 5. One-time in-place migration (the dangerous part — device QA)
**Recommended: in-place rekey via `sqlcipher_export`, NOT wipe-and-resync.**
Rationale: the DM store is **not** standalone — it shares `divine_db.db`
with drafts, pending uploads, pending publishes, etc. Wipe-and-resync
would re-fetch DMs from relays via `DmSyncState` but **permanently
destroy** all other local-only rows — unacceptable.

Safe-by-construction sequence (gate one-time by bumping `dbCacheVersion`
2→3, reusing the existing version-file mechanism in
`connection_native.dart`):

1. Detect a **plaintext** `divine_db.db` (open with no key / probe
   `PRAGMA cipher_version`).
2. `ATTACH DATABASE '<new>.enc' AS encrypted KEY "x'<key>'";`
3. `SELECT sqlcipher_export('encrypted');`
4. `DETACH DATABASE encrypted;`
5. **Verify** the encrypted file opens with the key and the expected
   tables/row-counts match the plaintext source.
6. **Only then** atomically swap (reuse the existing rename +
   `_moveSidecars` sidecar handling), keeping the plaintext file as a
   timestamped backup until the next successful launch.
7. On **any** failure at steps 2–6: keep using the plaintext DB, report
   to Crashlytics, and retry next launch. Never delete the source before
   the encrypted copy is verified.

### 6. Open product decision (key loss)
`flutter_secure_storage` can be cleared (OS keystore reset, restore to a
new device without keychain migration). If the key is lost, the encrypted
DB is unrecoverable. Decide: **wipe-and-resync DMs** (acceptable — they
re-fetch from relays) vs **block**. Recommended: on
"key missing but encrypted DB present", wipe + resync (DMs only) and
regenerate the key, surfacing a one-time notice. This is a product call.

## Device-QA checklist (must pass before un-drafting)
- [ ] iOS / Android / macOS build + launch with `sqlcipher_flutter_libs`.
- [ ] Fresh install: DB is created encrypted; `PRAGMA cipher_version`
      is non-empty; the file is not readable by plain `sqlite3`.
- [ ] Upgrade from a populated **plaintext** DB: migration runs once,
      all tables + row counts preserved, app fully functional, plaintext
      backup present then cleaned on next launch.
- [ ] Force-kill mid-migration → next launch recovers (plaintext intact,
      retried), no data loss.
- [ ] Key-loss path (clear keystore): chosen recovery behavior (§6) works
      and does not brick the app.
- [ ] No measurable regression on cold-start DB open on a low-end device
      (SQLCipher adds ~5–15%).
- [ ] Key never appears in logs / Crashlytics.

## Committed in this PR
- `formatCipherKeyPragma(rawKeyHex)` + 5 unit tests — the raw-key PRAGMA
  builder used by step 3. Pure and testable; the rest is device-QA-gated.
