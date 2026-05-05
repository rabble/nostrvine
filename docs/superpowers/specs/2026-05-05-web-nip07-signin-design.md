# Web NIP-07 Sign-in

## Goal

Let web users sign in to the Divine web app using a NIP-07 browser extension
(Alby, nos2x, Nostore, etc.) — the standard `window.nostr` interface for
Nostr key custody in the browser.

## Why

NIP-07 is the most ergonomic Nostr login on the web: the extension already
holds the user's keys, and any compatible site can request a pubkey and sign
events without ever touching the secret. Today the welcome screen offers
email/password, key import, and "Connect with a signer app" (NIP-46), but no
NIP-07 path. Users with an extension installed end up either pasting an nsec
or running through a NIP-46 round-trip they don't need.

## Non-goals

- Native (mobile) NIP-07 — only meaningful on the web build.
- Replacing or deprecating any existing sign-in option.
- Reworking `WebAuthScreen` (currently dead code, not routed). Out of scope;
  leave as-is.
- Per-call permission UI inside Divine — the extension owns its own UX for
  approving signs/encrypts.

## Existing landscape

Two external-signer flows already exist and define the pattern this design
follows:

- **Amber (NIP-55, Android):** `AuthService.connectWithAmber()` →
  `_setupUserSession(SecureKeyContainer.fromPublicKey(pubkey),
  AuthenticationSource.amber)` → `_buildIdentity()` returns
  `AmberNostrIdentity` which delegates `signEvent`/encrypt/decrypt to a
  remote `NostrSigner`.
- **Bunker (NIP-46):** `AuthService.connectWithBunker(bunkerUrl)` → same
  `_setupUserSession` shape with `AuthenticationSource.bunker` →
  `BunkerNostrIdentity`.

Both store a pub-key-only `SecureKeyContainer`, return null from
`signCanonicalPayload` (they have no local private key), and have their
signer lifecycle managed by `AuthService`.

There is partial NIP-07 scaffolding already:

- `lib/services/nip07_service.dart` — singleton with `connect()`, `signEvent`,
  `encryptMessage`, `decryptMessage`. Methods exist but the underlying
  interop (`nip07_interop.dart`) is a non-functional stub: its `_nostr`
  getter always returns `null`, even on web.
- `lib/services/web_auth_service.dart` + `lib/screens/web_auth_screen.dart`
  — a parallel auth path. The screen is dead code (no router entry). We
  will not extend it.

## Approach

Mirror the Amber / Bunker pattern end-to-end so NIP-07 sits alongside them
as a first-class signer the rest of the app already understands.

### 1. Real `window.nostr` interop

Replace the stub `lib/services/nip07_interop.dart` with a conditional-import
pair:

- `nip07_interop_stub.dart` — non-web; `isNip07Available => false`.
- `nip07_interop_web.dart` — uses `dart:js_interop` to expose
  `window.nostr` as an `extension type`. Implements:
  - `getPublicKey(): Future<String>`
  - `signEvent(Map<String, dynamic>): Future<Map<String, dynamic>>`
  - `nip04?.encrypt(pubkey, plaintext)` / `decrypt(...)`
  - `nip44?.encrypt(pubkey, plaintext)` / `decrypt(...)`
  - `getRelays()` — best-effort, optional

`nip07_interop.dart` becomes a thin file that does
`export 'nip07_interop_stub.dart' if (dart.library.js_interop)
'nip07_interop_web.dart';`. `Nip07Service` keeps its current shape; only the
backing implementation becomes real. The current `Nip07Service` already has
the right error mapping (`Nip07Exception` for user-rejected, etc.), so
fixing the interop unblocks it.

### 2. New auth source

Add `AuthenticationSource.nip07` (code: `'nip07'`) to
`lib/models/authentication_source.dart`. Cover the new variant in every
exhaustive switch on `AuthenticationSource` (notably `_setupUserSession`
cleanup logic and the startup restore logic in `AuthService.initialize`).

### 3. New identity

Add `Nip07NostrIdentity` to `lib/services/nostr_identity.dart`. It wraps
`Nip07Service` and implements `NostrSigner`:

- `signEvent` → `Nip07Service.signEvent` (returns the signed event map
  re-wrapped as a `nostr_sdk.Event`).
- `encrypt` / `decrypt` → `Nip07Service.encryptMessage` /
  `decryptMessage`. **If the extension does not expose `nip04`, fail with
  a clear error** (`Nip07Exception` with code `NIP04_UNSUPPORTED`). No
  silent fallback — there is no private key locally and pretending
  otherwise would corrupt DMs.
- `nip44Encrypt` / `nip44Decrypt` — same shape; fail clearly if the
  extension lacks `nip44`. (Plumbing through `Nip07Service` — currently
  it only exposes `nip04`; we add `nip44Encrypt/Decrypt` methods.)
- `signCanonicalPayload` → returns `null` (mirrors Bunker/Amber — no
  local key for deterministic schnorr).
- `close()` → no-op; lifecycle is managed by `AuthService`.

### 4. AuthService entry point

Add to `lib/services/auth_service.dart`:

- `Future<AuthResult> connectWithNip07()` — modelled on
  `connectWithAmber`. Steps:
  1. Guard: `kIsWeb` and `Nip07Service().isAvailable`. Otherwise
     `AuthResult.failure('No NIP-07 extension found...')`.
  2. `_setAuthState(AuthState.authenticating)`.
  3. `final result = await Nip07Service().connect()` — surfaces
     extension-rejected / invalid-pubkey errors.
  4. On success: `_nip07Service = Nip07Service()` is stashed in a new
     `Nip07Service? _nip07Service` field on `AuthService` (parallel to
     `_amberSigner` / `_bunkerSigner`).
  5. `_setupUserSession(SecureKeyContainer.fromPublicKey(pubkey),
     AuthenticationSource.nip07)`.
- `_buildIdentity()`: insert a `_nip07Service != null` branch above the
  Bunker branch (any external signer wins over local). Returns
  `Nip07NostrIdentity(pubkey: pubkey, nip07Service: _nip07Service!)`.
- `_setupUserSession`: on auth-source change, clear stale `_nip07Service`
  the same way it clears stale `_amberSigner` / `_bunkerSigner`.

### 5. Session restoration

NIP-07 extensions remember per-origin grants, so we can silently re-hydrate
a session at startup:

- In `AuthService.initialize`, when the persisted auth source is `nip07`:
  on web, call `Nip07Service().connect()` (which calls
  `getPublicKey()`). If the returned pubkey matches the stored pubkey, set
  up the session as in step 4. If it doesn't match (user changed
  identities in the extension) or the extension is absent, fall through
  to unauthenticated state and clear the stored auth source.
- On non-web, `nip07` source is invalid → fall back to unauthenticated
  and clear.

### 6. UI

In `lib/screens/auth/login_options_screen.dart`, add one button:

```
DivineButton(
  type: .secondary,
  expanded: true,
  label: 'Sign in with browser extension',
  onPressed: ...
)
```

Visibility: `if (kIsWeb && Nip07Service().isAvailable)`. Slot it after
"Connect with a signer app" and before the Android-only Amber button. On
press, await `authService.connectWithNip07()` and on success
`context.go('/')`; on failure show a snackbar with the error message
(matches the Amber path).

**Detection timing decision:** check on button press only — no polling.
If `window.nostr` is not present at first render, the button is hidden;
on a slow-injecting extension the user can refresh. Polling adds rebuild
churn for marginal benefit.

Update `_showInfoSheet` to add a "Browser Extension" entry describing
what it is and listing Alby / nos2x as common options.

### 7. Tests

- **Unit:** `Nip07Service` already has a singleton; introduce a
  testable seam by accepting the underlying interop via constructor in
  a tested code path, or test `connectWithNip07` against a fake
  `Nip07Service` that exposes `connect()` and `signEvent()`. Cover:
  - extension-not-found returns `AuthResult.failure`
  - successful pubkey is stored and identity becomes `Nip07NostrIdentity`
  - subsequent auth (e.g. `connectWithAmber`) clears `_nip07Service`
  - `_buildIdentity()` returns `Nip07NostrIdentity` when source is nip07
- **Identity:** `Nip07NostrIdentity` delegates `signEvent`/encrypt/
  decrypt to its service, returns `null` from `signCanonicalPayload`,
  and surfaces a meaningful error when nip04/nip44 are absent.
- **Widget:** `LoginOptionsScreen` shows the new button on web when
  available, hides it otherwise, and routes through `connectWithNip07`
  on tap.

## Risk and rollback

- **Self-contained:** new auth source, new identity class, one new
  button. Other auth sources are untouched.
- **Web-only:** non-web builds keep using the stub interop and the
  button is gated on `kIsWeb`.
- **Rollback:** revert the PR. No data migration, no schema change, no
  protocol change. Existing sessions (Amber/Bunker/Email/Key Import)
  are unaffected.

## Out of scope (follow-ups)

- Replacing the `WebAuthScreen` with an integrated path that uses the
  same flow — currently dead code; if revived, should also go through
  `AuthService` rather than the parallel `WebAuthService`.
- Auto-detecting and offering NIP-07 on the welcome screen above email
  (a "use what's already there" pattern). Worth doing later, but not as
  part of this change.
- Surfacing extension-provided relays (`getRelays()`) into the user's
  relay set.
