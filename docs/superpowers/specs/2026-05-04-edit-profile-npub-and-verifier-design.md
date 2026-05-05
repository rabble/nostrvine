---
issue: divinevideo/divine-mobile#3933
date: 2026-05-04
status: approved
---

# Edit profile npub demotion + external-account verifier — design

## Goal

Two related changes to the edit profile experience, tracked under issue #3933:

1. **Demote the user's npub** on edit profile so it stops dominating the form. Keep it
   reachable, but not as a labeled top-level field.
2. **Surface verified external accounts** (Twitter/X, GitHub, Bluesky, Mastodon, Telegram,
   Discord, TikTok, YouTube) on the user's profile. Provide an in-app webview entry point
   to `https://verifier.divine.video` for users to add new verifications.

The verifier service already exists (repo: `divine-identify-verification-service`). It
publishes NIP-39 `i` tags onto the user's kind 0 event using `['i', '<platform>:<identity>',
'<proof>']` to relays the mobile app already reads from (`wss://relay.divine.video`,
`wss://relay.damus.io`, `wss://relay.nostr.band`). It also exposes a public REST verification
API at `/verify` (batch) and `/verify/single`.

## Decisions

### Slicing
- One feature branch (`feat/3933-verified-accounts`), three small PRs landed in order:
  1. Demote npub on edit profile + add npub display block to key management.
  2. Read path: parse `i` tags off kind 0, verify via REST, render verified chips on profile.
  3. Write path: in-app WebView entry to verifier.divine.video + post-dismiss kind-0 refresh.

### npub destination
- Move the npub off the edit profile form entirely.
- Add a new "Your public key (npub)" display block at the top of the existing key management
  screen (`mobile/lib/screens/key_management_screen.dart`), which today only mentions the npub
  in helper copy and does not display it.
- Add a small secondary link "View your public key →" on edit profile that navigates to
  the key management screen.

### Verification source of truth
- Source of truth: NIP-39 `i` tags on kind 0 (claim) **plus** a re-verification call to
  the verifier REST API (proof). A claim alone is not trustworthy because anyone can put
  fake `i` tags on their own kind 0.
- Mobile uses the REST API only. No client-side caching, no retry, no rechecking — the
  verifier owns freshness via its Cloudflare KV cache. Mobile is a dumb client.

### Read-path UX
- Verified chips render under the bio on both own profile and other-profile views.
- Each chip = platform icon + handle, tappable → opens platform URL externally.
- v1: hide unverified `i` tags entirely. If the verifier returns failure or is unreachable,
  no chips render. Cleanest trust story; revisit if it feels too aggressive in practice.

### Write-path UX
- New "Get verified" CTA tile in a "Verified accounts" section on edit profile.
- Tapping launches the existing in-app WebView host pattern
  (`mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`) pointed at
  `https://verifier.divine.video`.
- Verifier handles login (shared `login.divine.video` session, browser signer, bunker, or
  NIP-46), platform proof, signing, and publishing the kind 0 update.
- On WebView dismiss, mobile dispatches a kind-0 refresh on `MyProfileBloc` so newly
  verified chips appear.

### Brand voice
- Echo verifier site copy: "Get verified", "Verified accounts", "Manage verified accounts".
- Avoid jargon: no "Identity attestation", no "External identity claims".

## Architecture

Layered per project rules (UI → BLoC → Repository → Client).

**Data layer (new):** `mobile/packages/verifier_client/`
- Thin Dart client over `https://verifier.divine.video`.
- `verifyBatch(List<IdentityClaim>) → List<VerificationResult>`.
- `verifySingle(IdentityClaim) → VerificationResult`.
- Returns success / failed / unknown per claim. No Nostr knowledge, no BLoC knowledge.

**Repository layer:** extend existing `mobile/packages/profile_repository`.
- New `IdentityClaim` model: `{platform, identity, proof}`.
- New `IdentityClaimsRepository`:
  - `parseClaims(Kind0Event) → List<IdentityClaim>` (filters `['i', '<platform>:<identity>',
    '<proof>']` tags, case-insensitive dedupe matching verifier's behavior at
    `divine-identify-verification-service/src/index.ts:1784`). Caps the batch at 10
    to match `MAX_BATCH_SIZE` in
    `divine-identify-verification-service/src/routes/verify.ts:12`.
  - `verifiedClaims(String pubkey, Kind0Event) → Future<List<IdentityClaim>>` — parses then
    forwards to the verifier client, returns only successes.

**BLoC layer:**
- `MyProfileBloc` and `OtherProfileBloc`: add `verifiedClaims: List<IdentityClaim>` to state
  and a `VerifiedClaimsRequested` event triggered when kind 0 loads. State uses the existing
  enum-status pattern; failures emit empty list (no error strings in state per project rules).
- `ProfileEditorBloc`: add `VerifierLaunchRequested` event that the UI maps to a route push,
  and a `VerifierWebViewDismissed` event that triggers a kind-0 refresh on `MyProfileBloc`
  via UI-level `BlocListener` (no BLoC-to-BLoC dispatch).

**UI:**
- `mobile/lib/screens/profile_setup_screen.dart` — remove labeled npub `TextFormField`
  (lines 721-759 on main). Add "Verified accounts" section between bio and remaining form,
  with existing chips inline + "Get verified" CTA tile. Add small "View your public key →"
  link.
- `mobile/lib/screens/key_management_screen.dart` — add npub display block at top:
  short label, monospace one-line truncated display, copy icon button.
- `mobile/lib/screens/other_profile_screen.dart` and own-profile widgets — add verified-chip
  row directly under bio. Use `DivineIcon` set where icons exist; fall back to a generic
  globe icon for unknown platforms.

## Data flow

### Read path
1. Profile load fetches kind 0 (existing).
2. `IdentityClaimsRepository.verifiedClaims(pubkey, kind0)` parses `i` tags then fires
   `POST verifier.divine.video/verify` with the batch.
3. BLoC emits verified-only list.
4. UI renders chips for verified entries; nothing while loading; nothing on error.

### Write path
1. User taps "Get verified" → `ProfileEditorBloc` emits `VerifierLaunchRequested`.
2. UI-level listener navigates to the WebView host at `https://verifier.divine.video`.
3. Verifier handles login, proof, sign, and publish to relays (NIP-39 `i` tag on kind 0).
4. WebView dismiss → UI emits `VerifierWebViewDismissed` → BLoC dispatches kind-0 refresh
   on `MyProfileBloc`.
5. Re-render picks up new chips.

## Error handling

- Verifier 4xx / 5xx / timeout / network failure → repository returns empty verified list.
  No error strings in state (project rule). BLoC reports error via `addError` for
  observability.
- Malformed `i` tags → parser skips silently.
- Tag count cap (10) before batch call, matching the verifier's
  server-side `MAX_BATCH_SIZE`.
- Unknown platform names → still sent to verifier (forwards-compatible: verifier may add
  platforms before mobile does); chips for unknown platforms render with the generic
  globe icon and the raw handle.

## Testing

- Unit: `IdentityClaimsRepository.parseClaims` — well-formed, malformed, duplicate tags,
  case-insensitive dedupe, 10-cap.
- Mock `VerifierClient`: success, 4xx, 5xx, timeout — all map to empty verified list
  without crash.
- BLoC tests: read happy path + verifier failure; write path (launch event +
  post-dismiss kind-0 refresh).
- Widget tests: edit-profile "Verified accounts" section + "View your public key" link;
  key-management npub block; profile chip row.
- Goldens: edit profile, key management, public profile (own + other) — three changed
  surfaces.

## Out of scope

- Verifying *other people's* external accounts (current user only in v1).
- NIP-05 username verification (already handled separately; closed PR/issues #1539, #420).
- Removal/revocation UX from inside Divine — handled by verifier.divine.video itself for v1.
- Building or deploying the verifier service.

## Open follow-ups

- "Look Up Someone" deeplink from a profile (lets a viewer re-verify a claim) — possible
  v2 if "trust but verify" surface is needed in-app.
- Local cache of verification results — only if v1 telemetry shows the verifier call is
  too chatty.
- "Couldn't verify" surfacing for unknown-state claims — only if v1 hide-on-failure feels
  too aggressive.

## References

- Issue: https://github.com/divinevideo/divine-mobile/issues/3933
- Verifier repo: `../divine-identify-verification-service` (Cloudflare Worker)
- Verifier README: `../divine-identify-verification-service/README.md`
- Verifier kind-0 publish path: `../divine-identify-verification-service/src/index.ts`
  lines 1747-1816 (`publishIdentityTagToNostr`).
- In-app WebView host pattern: `mobile/lib/screens/apps/nostr_app_sandbox_screen.dart`.
- Edit profile current state: `mobile/lib/screens/profile_setup_screen.dart` lines 721-759
  (npub `TextFormField` to remove).
