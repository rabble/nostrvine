# Delete-account identity + username confirmation

- **Date:** 2026-07-16 (revised 2026-07-17 after adversarial spec review)
- **Issue:** [#6137](https://github.com/divinevideo/divine-mobile/issues/6137)
- **Status:** design approved, pending spec review

## Problem

"Delete Account and Data" (Nostr Settings → Danger Zone) permanently deletes
the **currently signed-in** account's content network-wide (NIP-09 kind 5 per
event + NIP-62 kind 62 vanish), reading `currentPublicKeyHex` in
`AccountDeletionService.deleteAccount()`. Nothing in the flow tells the user
*which* identity is about to be erased:

- The only account-identity surface is the root Settings header
  (`settings_screen.dart`, `_AccountHeaderProfile`). Delete Account and Data is
  two `push`es deeper, so that header is off-screen by the time the user is
  deciding.
- The final confirmation dialog (`showDeleteAllContentWarningDialog`,
  `delete_account_dialog.dart`) shows only generic copy plus a hardcoded
  "DELETE" field — no avatar, name, username, or npub.

With account switching (`FeatureFlag.accountSwitching`, shipped) or the same
login across similar-looking devices, a user can wipe the wrong identity off
the network in an irreversible action.

**Identifier availability (verified):** the **npub is synchronous**
(`authService.currentNpub`) — the account is always identifiable. The friendly
identity (display name, avatar) and the **username/handle** come only from the
rich `models.UserProfile`, loaded async via `userProfileReactiveProvider`
(an `AsyncValue<UserProfile?>`). `authService.currentProfile` is a *thin* type
that is only ever constructed with `npub`/`publicKeyHex`/`displayName` and
**never carries `nip05`** — so it is not a handle source.

Separately, the account-deletion copy overstates what deletion guarantees. The
video-deletion flow already qualifies it correctly ("delete from Divine; may
still appear on other clients / relays may keep copies"); the account-deletion
strings promise "PERMANENTLY delete ALL content from Nostr relays," which
NIP-09/NIP-62 cannot guarantee for independent relays.

## Decisions (from review walkthrough)

- **Q1 — username-not-loaded → resolve first (A).** Because the handle is only
  available async, on tap we resolve the rich profile before opening the dialog
  (brief spinner), so the strong username gate is reliable even right after an
  account switch. Only a genuinely unloadable profile degrades to npub + DELETE.
- **Q2 — bind the deletion to the confirmed account (B).** Capture the pubkey at
  dialog-open; thread it through so the identity shown, the token required, and
  the deletion target are one captured pubkey. `deleteAccount` verifies the
  current account still matches and **aborts on mismatch** (you can only sign as
  the current account, so binding = verify-and-abort, not delete-another).
- **Q3 — token = NIP-05 handle only; no `vine_username` tier (A).** Rationale is
  *not* "narrow edge case" (unverified): the identity **display** is the
  load-bearing safety win, the type-to-confirm token is secondary, and a legacy
  `vine_username` is a poor confirmation token even when present. Handle-less
  accounts (including Vine imports without a claimed handle) get DELETE, still
  showing their npub.

## Goals

1. On the final delete-confirmation surface, show which account is being
   deleted: avatar + display name + username (or shortened npub if none).
2. Make the confirmation account-specific: when the account has a username,
   require re-typing it; otherwise fall back to typing "DELETE".
3. Correct the deletion copy to match the app's accurate video-deletion
   convention.
4. Bind the deletion to the exact account the user confirmed (Q2).

## Non-goals (out of scope for this PR)

- Identity on the Nostr Settings danger-zone **tile** (a "should", not in the
  issue ACs).
- The parallel **Remove Keys** blind spot.
- Whether account deletion purges **Blossom media blobs** (accuracy nuance,
  flagged separately).
- The full-screen deletion redesign in #6127 — this hardens the current dialog;
  #6127 re-homes the same guarantee on its full-screen flow later.

> Scope note: Q2 adds a small guard inside `AccountDeletionService`, so this PR
> is *dialog-plus-a-deletion-service-check*, not strictly dialog-only.

## Design

### Surface

Enhance the existing `showDeleteAllContentWarningDialog` rather than
introducing a new full-screen route. The flow already uses a dialog, so this
stays within the repo's "don't introduce new dialogs" convention, ships the
safety fix now, and keeps the change small. The confirmation *logic* persists
even when #6127 later swaps the *surface*.

### Terminology

The identifier is technically a NIP-05; the UI calls it a **username** for
usability (matching `profileSetupUsernameLabel` = "Username (Optional)"). This
applies to both a Divine handle and an external one. "NIP-05" stays out of
user-facing copy and lives only in code/comments.

### Identity + token derivation

The rich handle getters live on `models.UserProfile`, read via
`userProfileReactiveProvider(pubkey)`. Use the **claimed** handle — do **not**
gate on `nip05VerificationProvider`. The correct in-repo precedent is
`_AccountSwitchTile` (`profile?.displayNip05 ?? NostrKeyUtils.truncateNpub(
pubkey)`), *not* `_AccountHeaderProfile` (which gates on verification and would
show npub for an unverified-but-claimed handle, mismatching the required token).

The `_DeleteAccountTile` has `ref` and `currentPublicKeyHex`. It captures the
pubkey once and derives a plain value object passed into the dialog:

- `pubkey` (drives the avatar `placeholderSeed`, and is the bound deletion
  target — Q2)
- `displayName` = `UserProfile.bestDisplayName`
- `avatarUrl` = `UserProfile.picture`
- `identifierLine` = `UserProfile.displayNip05` (renders Divine as
  `@name.divine.video`, external as `name@domain`) — or
  `NostrKeyUtils.truncateNpub(pubkey)` when null
- `requiredToken` = `displayNip05` when non-null, else `'DELETE'`
- `isUsernameConfirmation` = `displayNip05 != null`

Deriving display values from model getters (not inline widget logic) follows
the layering rules. The dialog stays free of Riverpod and is unit-testable.

**Shown == typed == accepted (invariant).** The identity block, the monospace
"type this" target, and the matcher all use the **same** value — the **full**
`displayNip05` form (`@mjb.divine.video` for Divine, `mjb@nos.social` for
external). We do **not** use the short/bare form (`@mjb`, `mjb`) anywhere: the
user types exactly the identifier shown. High friction (typing the full handle)
is appropriate for a delete-everything gate, and one rule covers Divine and
external handles uniformly. The token covers **any** NIP-05 handle; scoping it
to Divine-only was considered and dropped (the "give up your @divine.video
username" concern is separate work, #6126).

### Resolve-before-confirm (Q1)

`userProfileReactiveProvider` is async; `.value` can be null at tap time. On
tapping Delete Account and Data, `_DeleteAccountTile` waits for the provider to
resolve to a loaded profile behind a brief progress overlay — reusing the
existing `_ProgressOverlay` pattern in `nostr_settings_screen.dart` — then opens
the dialog with the resolved identity. The wait is **bounded** (a short timeout,
constant in the tile): if the profile is already cached the overlay is
imperceptible; if it genuinely can't resolve in time, fall back to
`bestDisplayName`/`truncateNpub` + `requiredToken = 'DELETE'` rather than
hanging. The exact resolve mechanism (e.g. `ref.read(provider.future)` vs
listening for the first non-loading `AsyncValue`) is a plan-level detail to
verify against the provider's actual type.

### Account binding (Q2)

The captured `pubkey` is passed through `executeAccountDeletion` into
`AccountDeletionService.deleteAccount(expectedPubkey: ...)`. At execution the
service compares `expectedPubkey` against the live `currentPublicKeyHex`; on
mismatch it **aborts and returns a failure result** (surfaced via the existing
error snackbar) rather than deleting. This is additive to the existing method;
its one production caller and tests are updated.

### Match normalization

- Username token: trim, lowercase, strip a single leading `@` on both target and
  input, then compare (so `@mjb.divine.video` and `mjb.divine.video` both pass;
  `mjb@nos.social` matches as-is). The two leniencies (`@`-optional,
  case-insensitive) are the *only* ones — a bare/short form (`mjb`, `@mjb`) does
  **not** match a Divine handle. The user types the full identifier shown.
- DELETE token: trim + uppercase compare to `DELETE` (unchanged from today).

A small pure helper (`matchesRequiredToken(input, target, {isUsername})`) holds
this so it is tested directly.

### Copy (proposed — final wording subject to review)

Corrected to the video-flow convention (`videoGridDeleteConfirmMessage` /
`shareMenuDeleteWarning`):

- **Warning body:** "This permanently deletes your account and all your content
  from Divine, and sends a deletion request to other Nostr relays. Some relays
  and clients may still keep copies."
- **Prompt, username case:** "To confirm, type your username:"
- **Prompt, delete case:** "To confirm, type:"
- **Hint, username case:** "Type your username"
- **Hint, delete case:** "Type DELETE" (existing key)
- **Tile subtitle:** "Permanently delete your account and content from Divine,
  and request removal from other Nostr relays. Some copies may remain."
- Title unchanged: "⚠️ Final Confirmation".

The monospace token (the username, or `DELETE`) is still shown as the explicit
"type this" target beneath the prompt.

### l10n

The existing `deleteAccountFinalConfirmationBody` is currently the **prompt**
("…type:"), not a generic body. Repurposing it into a warning paragraph would
leave every translated locale rendering a *prompt* in the *warning* slot. So:

- **Retire** `deleteAccountFinalConfirmationBody` (remove from every
  `app_*.arb`).
- **Add** new keys: `deleteAccountWarningBody`,
  `deleteAccountConfirmUsernamePrompt`, `deleteAccountConfirmDeletePrompt`,
  `deleteAccountConfirmationHintUsername`. Keep `deleteAccountConfirmationHint`.
- **Repurpose** `nostrSettingsDeleteAccountSubtitle` in place (deliberate copy
  change — its translations now trail corrected English; noted for translation
  follow-up, since the consistency test only catches missing keys).

New English-only keys are added to `_knownUntranslatedDebt` (or mirrored), then
`arb_consistency_test` is run.

### Widget structure

Extract the dialog's content into a small private `StatefulWidget` that owns the
`TextEditingController` and match state (the existing dialog already uses this
shape via `StatefulBuilder`), so it renders and tests without `showDialog`. The
public `showDeleteAllContentWarningDialog` gains a **required** identity
value-object parameter.

Extract the identity block (avatar + name + handle/npub) into a small private
`_DeleteIdentityHeader` stateless widget composing `UserAvatar` +
`bestDisplayName` + `identifierLine`, so it is reused and testable rather than
inlined.

Import note: `nostr_settings_screen.dart` imports the thin `UserProfile` from
`auth_service.dart`; adding `package:models/models.dart` requires
`hide UserProfile` (mirroring `settings_screen.dart`) or a prefix.

## Testing

- **Dialog widget tests** over three account shapes — Divine username
  (`@name.divine.video`), external username (`name@nos.social`), no username
  (npub shown, `DELETE` required) — each asserting: correct identity block +
  token render; confirm disabled until the correct token is typed and enabled on
  match (case/`@`-insensitive for usernames); token derives from the active
  account, not a constant.
- **Match helper** unit test (`matchesRequiredToken`).
- **Resolve-before-confirm (Q1):** the tile opens the dialog with the loaded
  identity; the not-loaded path resolves then shows, and the genuinely-unloadable
  path degrades to npub + DELETE.
- **Account binding (Q2):** `deleteAccount` aborts and returns failure when
  `expectedPubkey != currentPublicKeyHex`, and proceeds when they match.
- **Update the existing** `delete_account_dialog_test.dart` (and the one
  production caller) for the new required parameter.
- l10n delegates on every test `MaterialApp`.

## Relationships

- **#6127** (reversible 28-day deletion) adopts this guarantee on its
  full-screen flow; this issue owns it independently and is backend-independent
  (that issue is blocked by divine-funnelcake#651).
- **#6126 / PR #6138** (opt-in @divine.video username burn on delete) is a
  separate *feature axis* but shares the **same delete-modal code** — #6138
  rewrites `showDeleteAllContentWarningDialog` and `executeAccountDeletion`.
  Sequencing (decided): #6138 lands first, then this work rebases onto it and
  re-derives against the merged dialog. The two designs fuse: identity block +
  username gate (this) alongside the burn checkbox (#6138); `executeAccountDeletion`
  combines burn-first (#6138) with the confirmed-pubkey verify-and-abort (this).
