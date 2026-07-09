# Protected-minor key-export / import gate (mobile) — design

**Issue:** divinevideo/support-trust-safety#182 (protected-minor epic #173; app-side
follow-up to the #176 DM restriction merged as divine-mobile#5754).
**Pairs with:** support-trust-safety#183 (Keycast-side headless-signer containment).
#182 removes the raw-key escape path; #183 closes the headless-signer path. Neither
alone contains a custodial minor; together they do.
**Status:** Design approved (UI: locked card; gate: intent-named delegating provider).

## Goal

For a **protected minor** (13-15, keycast `verified_minor`), remove the two
first-class in-session affordances that hand over or swap the signing key:

- **nsec export** — the "Copy nsec" button.
- **key import / change** — pasting an nsec to swap the current account to a
  self-held key.

This is **friction for self-custody, not containment** — a determined user can
still sideload. Removing the easy path is the point. Custodial DM containment is
#183's job (Keycast server-side).

## Why these two, and why nothing else

An exhaustive sweep found exactly two user-reachable, in-session affordances that
(a) reveal/export the private key or (b) import/change the current account's
signing key — both on `mobile/lib/screens/key_management_screen.dart`:

- `_buildExportSection` → `authService.exportNsec()` copies the raw `nsec1…` to the
  clipboard. Gated today only on `canExportLocalNsec`, which returns `true` even for
  `divineOAuth` accounts holding a local key — so the export path is genuinely
  reachable, not incidental.
- `_buildImportSection` → `authService.importFromNsec()` replaces the active
  session's signing key with a pasted nsec. Ungated today for any authenticated
  account.

Out of scope (verified):

- `KeyImportScreen` (`/import-key`), connect-signer, Amber, NIP-07 — all pre-auth
  login flows; no authenticated protected-minor context, so a gate there is a no-op.
- `secure_account_screen.dart` — reads the nsec only to hand it to Keycast
  `headlessRegister` for email binding; never reveals it, and moves the account
  toward custody. Not an escape hatch, and unreachable by a verified minor.
- No QR-of-nsec, no seed/recovery-phrase, and no dev-options key reveal exist in the
  app.

## Gate signal — fail closed

Reuse the shipped fail-closed seam **`isDmRestrictedProvider`** (#176): protected →
restrict; unknown / cold-start-before-resolution / suppressed-check → restrict; only
a positive *not-protected* verdict (trusted-live or persisted) lifts it. This is the
correct posture here for the same reason as DMs — the restricted party can trivially
suppress the input that produces "unknown" (airplane mode, cleared storage, blocked
keycast domain, expired token), so "no answer" must hide the affordance, not reveal
it.

This deliberately **diverges from the issue's `isProtectedMinorProvider` mention**:
that seam fails *open* (right for #175's content lock, wrong here). The issue also
asks for "fail closed, consistent with the DM gate's posture" — only
`isDmRestrictedProvider` satisfies that.

Expose it under an intent-named passthrough so the call site documents its purpose
and the two conditions can diverge later without editing the screen:

```dart
/// Fail-closed gate for the #182 key-management affordances (nsec export +
/// key import/change). Deliberately the SAME fail-closed verdict as the #176
/// DM restriction: a protected minor — or any account whose protected-minor
/// status can't be positively cleared — is restricted.
final isKeyManagementRestrictedProvider =
    Provider<bool>((ref) => ref.watch(isDmRestrictedProvider));
```

## UI

`KeyManagementScreen` (a `ConsumerStatefulWidget`) watches
`isKeyManagementRestrictedProvider`. When restricted it replaces **both** the import
and export sections with a single locked info card, matching the existing
`_buildKeycastRemoteSigningInfo` info-card precedent on the same screen. The npub
display and the "what are Nostr keys" card stay — a protected minor can still see and
copy their **public** key, and the screen stays reachable from Settings and
profile-setup.

Copy (new l10n):

- title: "Your keys are managed by Divine"
- body: "To keep your account safe, key backup and importing a different key aren't
  available here."

## Scope decisions

- Gate **inside the screen**, not at the entry points — one place covers the Settings
  tile, the profile-setup "View your public key" link, and any deep link. The entry
  tile stays visible (the screen still serves the npub).
- No change to the login-flow import or the secure-account flow.

## Tests

- **provider unit test:** `isKeyManagementRestrictedProvider` mirrors
  `isDmRestrictedProvider` (both true and false).
- **widget test on `KeyManagementScreen`:**
  - restricted (protected minor): the locked card renders; the Copy-nsec button and
    the import field/button are absent.
  - not restricted (normal account, `canExportLocalNsec` true): Copy-nsec button and
    import section render; locked card absent.
- l10n: new keys added to `app_en.arb` with metadata and mirrored across all 18
  locales (matching #176); `arb_consistency_test` stays green.

## Threat model note

Consistent with the #176 spec's custodial-ceiling section: for a **custodial** minor
(Keycast holds the key), this gate is friction plus defense-in-depth, not containment
— Keycast's open headless API can still sign/encrypt for that account. Real custodial
containment is #183 (Keycast server-side). #182 removes the raw-key-escape path; the
two together close both the sideload-with-exported-key path and the headless-signer
path.
