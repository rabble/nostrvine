# Delete-account identity + username confirmation

- **Date:** 2026-07-16
- **Issue:** [#6137](https://github.com/divinevideo/divine-mobile/issues/6137)
- **Status:** design approved, pending spec review

## Problem

"Delete Account and Data" (Nostr Settings → Danger Zone) permanently deletes
the **currently signed-in** account's content network-wide (NIP-09 kind 5 per
event + NIP-62 kind 62 vanish), reading `currentPublicKeyHex` in
`AccountDeletionService.deleteAccount()`. Nothing in the flow tells the user
*which* identity is about to be erased:

- The only account-identity surface is the root Settings header
  (`settings_screen.dart:202`, `_AccountHeaderProfile`). Delete Account and
  Data is two `push`es deeper, so that header is off-screen by the time the
  user is deciding.
- The final confirmation dialog (`showDeleteAllContentWarningDialog`,
  `delete_account_dialog.dart`) shows only generic copy plus a hardcoded
  "DELETE" field — no avatar, name, username, or npub.

With account switching (`FeatureFlag.accountSwitching`, shipped) or the same
login across similar-looking devices, a user can wipe the wrong identity off
the network in an irreversible action.

Separately, the account-deletion copy overstates what deletion guarantees.
The video-deletion flow already qualifies it correctly ("delete from Divine;
may still appear on other clients / relays may keep copies"); the
account-deletion strings promise "PERMANENTLY delete ALL content from Nostr
relays," which NIP-09/NIP-62 cannot guarantee for independent relays.

## Goals

1. On the final delete-confirmation surface, show which account is being
   deleted: avatar + display name + username (or shortened npub if none).
2. Make the confirmation account-specific: when the account has a username,
   require re-typing it; otherwise fall back to typing "DELETE".
3. Correct the deletion copy to match the app's existing (accurate)
   video-deletion convention.

## Non-goals (out of scope for this PR)

- Identity on the Nostr Settings danger-zone **tile** (a "should", not in the
  issue ACs).
- The parallel **Remove Keys** blind spot.
- Whether account deletion purges **Blossom media blobs** (accuracy nuance,
  flagged separately).
- The full-screen deletion redesign in #6127 — this hardens the current
  dialog; #6127 re-homes the same guarantee on its full-screen flow later.

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

The rich handle getters live on the **models** `UserProfile`
(`packages/models`), not `AuthService.currentProfile` (a thinner type). The
`_DeleteAccountTile` already has `ref`; it reads the rich profile via
`userProfileReactiveProvider(currentPublicKeyHex)` (same source as
`_AccountHeaderProfile`) and derives a plain value object passed into the
dialog:

- `displayName` = `UserProfile.bestDisplayName`
- `avatarUrl` = `UserProfile.picture`
- `identifierLine` = `UserProfile.displayNip05` (already renders Divine as
  `@name.divine.video` and external as `name@domain`) — or `NostrKeyUtils
  .truncateNpub(pubkey)` when `displayNip05` is null (same shortening the
  settings header uses)
- `requiredToken` = `displayNip05` when non-null, else `'DELETE'`
- `isUsernameConfirmation` = `displayNip05 != null`

This keeps the dialog free of Riverpod and trivially unit-testable. Deriving
display values from model getters (not inline widget logic) follows the
layering rules.

Confirmation uses the account's own **claimed** handle — it does not depend on
third-party NIP-05 network verification, since it is the user's own account.

**Fallback:** if the rich profile is not loaded when the dialog opens, use
`UserProfile.defaultDisplayNameFor(pubkey)` for the name +
`NostrKeyUtils.truncateNpub(pubkey)` for the identifier, and require
`'DELETE'`.

### Match normalization

- Username token: trim, lowercase, strip a single leading `@` on both the
  target and the input, then compare. So `@mjb.divine.video` and
  `mjb.divine.video` both pass; `mjb@nos.social` matches as-is.
- DELETE token: trim + uppercase compare to `DELETE` (unchanged from today).

A small pure helper (`_matchesRequiredToken(input, target, isUsername)`)
holds this so it can be tested directly.

### Copy (proposed — final wording subject to review)

Corrected to the video-flow convention (`videoGridDeleteConfirmMessage` /
`shareMenuDeleteWarning`):

- **Dialog warning body** (`deleteAccountFinalConfirmationBody`, repurposed):
  "This permanently deletes your account and all your content from Divine, and
  sends a deletion request to other Nostr relays. Some relays and clients may
  still keep copies."
- **Prompt, username case** (`deleteAccountConfirmUsernamePrompt`, new): "To
  confirm, type your username:"
- **Prompt, delete case** (`deleteAccountConfirmDeletePrompt`, new): "To
  confirm, type:"
- **Hint, username case** (`deleteAccountConfirmationHintUsername`, new): "Type
  your username"
- **Hint, delete case** (`deleteAccountConfirmationHint`, existing): "Type
  DELETE"
- **Tile subtitle** (`nostrSettingsDeleteAccountSubtitle`, repurposed — option
  B): "Permanently delete your account and content from Divine, and request
  removal from other Nostr relays. Some copies may remain."
- Title unchanged: "⚠️ Final Confirmation".

The monospace token (the username, or `DELETE`) is still shown as the explicit
"type this" target beneath the prompt.

### l10n

New keys added to `app_en.arb`, mirrored into every other `app_*.arb` locale
or added to `_knownUntranslatedDebt`, then `arb_consistency_test` run. The two
**repurposed** existing keys (`deleteAccountFinalConfirmationBody`,
`nostrSettingsDeleteAccountSubtitle`) are deliberate copy changes: their
already-translated locale values now trail the corrected English. The
consistency test only catches missing keys, not semantic drift, so this is
noted for translation follow-up (not silently shipped as an l10n side effect).

### Widget structure

Extract the dialog's content into a small private `StatefulWidget` that owns
the `TextEditingController` and match state, so it renders and tests without
`showDialog`. The public `showDeleteAllContentWarningDialog` gains the identity
value-object parameter and forwards it.

## Testing

Widget tests over three account shapes:

1. Divine username (`@name.divine.video`)
2. External username (`name@nos.social`)
3. No username → npub shown, `DELETE` required

Each asserts: (a) the correct identity block + token render; (b) confirm stays
disabled until the correct token is typed and enables on match
(case/`@`-insensitive for usernames); (c) the token derives from the active
account, not a constant. Plus a direct test of `_matchesRequiredToken`, and
l10n delegates on the test `MaterialApp`.

## Relationships

- **#6127** (reversible 28-day deletion) adopts this guarantee on its
  full-screen flow; this issue owns it independently and is backend-independent
  (that issue is blocked by divine-funnelcake#651).
- **#6126** (username revoke+burn) is a separate axis; no overlap.
