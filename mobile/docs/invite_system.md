# Invite System

Last updated: 2026-03-06

## What this document captures

This records the current state of invite-code-related work across:

- the open GitHub issues
- the app code in this branch
- the current invite API spec
- the Figma auth designs

## Relevant open issues

Invite-code-related:

- `#1120` `[Feature] 1.12 Invite System`
  https://github.com/divinevideo/divine-mobile/issues/1120
- `#1121` `UI/ UX Figma screens for Invite system`
  https://github.com/divinevideo/divine-mobile/issues/1121
- `#1540` `[Feature] 1.13 Login screen flow`
  https://github.com/divinevideo/divine-mobile/issues/1540

Invite-by-name but not invite-code gating:

- `#1736` `feat: Invite collaborator to co-create videos`
  https://github.com/divinevideo/divine-mobile/issues/1736
- `#1823` `[Feature] 8.7 Collaborator`
  https://github.com/divinevideo/divine-mobile/issues/1823

## Main issue-tracker finding

`#1120` is stale relative to the repo's current invite spec.

The issue still describes the older faucet-style flow with endpoints like:

- `POST /request-invite`
- `POST /validate-invite`
- `POST /consume-invite`

The current repo spec in `INVITE_CODE_API.md` describes a newer model centered on:

- NIP-98 auth for invite consumption
- invite gating for new Nostr identity creation only
- bypass for existing Nostr users
- `POST /v1/consume-invite`
- `GET /v1/invite-status`
- `POST /v1/generate-invite`
- `POST /v1/validate`
- optional waitlist and buy flows

This means the tracker and the current proposed implementation model are not aligned yet.

## Current spec in the repo

Source:

- `mobile/docs/INVITE_CODE_API.md`

Key rules from that spec:

- Invites gate new Nostr identity creation only, not general app access.
- Existing Nostr users must bypass the invite gate.
- Importing an `nsec`, using bunker, Amber, or other signer-based flows should not require invite checks.
- Invite consumption should happen during identity creation, with the key generated in memory and only persisted after successful consume.
- Waitlist support is part of the documented API surface.

## Current invite server

Server docs provided:

- `/Users/rabble/code/divine/divine-invite-darshan/README.md`
- `/Users/rabble/code/divine/divine-invite-darshan/tLLM_CONTEXT.md`
- `/Users/rabble/code/divine/divine-invite-darshan/SYSTEM_OVERVIEW.md`

Server implementation summary:

- Repo: `divine-invite-darshan`
- Runtime: Fastly Compute
- Language: Rust/WASM
- Storage: Fastly KV store `invite_data`
- Config store: `invite_config`
- Domain: `invite.divine.video`

The server docs state that these are the live mobile-relevant routes:

- public:
  - `POST /v1/waitlist`
  - `POST /v1/validate`
  - `POST /v1/buy`
- user auth required:
  - `POST /v1/consume-invite`
  - `GET /v1/invite-status`
  - `POST /v1/generate-invite`
- admin auth required:
  - `POST /v1/admin/grant`
  - `POST /v1/admin/generate`
  - `POST /v1/admin/approve-waitlist`
  - `GET /v1/admin/tree`
  - `GET /v1/admin/user?pubkey=...`
  - `GET /v1/admin/waitlist`
  - `GET /v1/admin/stats`
  - `POST /v1/admin/revoke`

## Server-side invite lifecycle

From the server docs, a code can currently be created by four paths:

- admin generate
- user social generate
- waitlist approval
- Cashu buy

Server behavior that matters for the mobile client:

- `POST /v1/validate` is informational only and does not reserve a code.
- `POST /v1/consume-invite` is idempotent for the same `code + pubkey`.
- consuming the same claimed code as a different pubkey fails
- a user who already joined through one code cannot join later with another
- first-time successful consumers receive a default invite allocation of `5`
- `GET /v1/invite-status` returns allocation plus per-code claim metadata

## Server auth reality

The mobile invite spec describes NIP-98-oriented behavior, but the current server implementation is looser.

What the server currently accepts:

- kind `24242` auth events
- kind `27235` auth events
- valid Schnorr signatures
- recomputed event ID match
- optional `expiration` tag enforcement

What the server does not currently enforce:

- `u` tag must match request URL
- `method` tag must match HTTP method
- a separate short freshness window using `created_at`

Practical implication:

- The current invite server is not yet enforcing full request binding semantics that the mobile spec implies for NIP-98.
- If the mobile app assumes strict request-bound auth, server hardening still needs to happen.

## Server hardening gaps

The server docs explicitly call out these gaps:

- no explicit rate limiting
- no waitlist deduplication
- weak pubkey validation on some user input
- open CORS (`*`)
- Cashu buy flow does not verify proof state against the mint, only local replay prevention and amount checks

## Current app-state finding

The current app does not yet implement an invite-code flow.

Observed code paths:

- `mobile/lib/screens/auth/welcome_screen.dart`
- `mobile/lib/screens/auth/create_account_screen.dart`
- `mobile/lib/screens/auth/login_options_screen.dart`
- `mobile/lib/blocs/divine_auth/divine_auth_cubit.dart`

What exists today:

- Welcome screen with create-account and sign-in entry points.
- Email/password account creation flow.
- Existing Nostr identity entry points:
  - import key
  - signer app
  - Amber on Android
- Anonymous/skip-style path still exists in create-account flow.

What does not appear to exist yet:

- invite-code entry screen
- invite-code validation or consumption logic
- invite-gating state in auth cubit/bloc
- invite API client integration
- invalid / used / revoked / offline invite UX

## Product / architecture mismatch

There is a meaningful mismatch between the current app flow and the current invite spec:

- The current onboarding implementation is still strongly email/password-first.
- The invite spec assumes invites gate new Nostr identity creation.
- The app still exposes a skip/anonymous-style path, which conflicts with a strict invite gate unless that path is intentionally allowed.
- The live invite server supports both invite-code validation/consumption and a public waitlist path, which means the product needs to decide whether the app should lead with waitlist gating, true code entry, or both.

Before implementation, this should be clarified:

- Is invite gating intended to block all new account creation paths?
- Or only a new Nostr-keyed identity path?
- Does the current email/password flow remain the primary entry path, or does the auth flow need restructuring first?

## Cross-repo alignment notes

Things that are aligned across mobile docs and server docs:

- code format is `XXXX-YYYY`
- there is a public `POST /v1/validate`
- there is a `POST /v1/consume-invite`
- there is a `GET /v1/invite-status`
- there is a `POST /v1/generate-invite`
- successful first join grants a default allocation of `5`
- waitlist is part of the system, not just an optional idea

Things that are not fully aligned:

- mobile doc frames consume auth as NIP-98-style request-bound auth, but server currently accepts both `24242` and `27235` and does not bind `u` or `method`
- issue `#1120` still reflects an older faucet model
- current mobile app onboarding still does not match the invite lifecycle described by either the mobile spec or the server

## Figma findings

Auth epic file:

- https://www.figma.com/design/rp1DsDEUuCaicW0lk6I2aZ/UI-Design?node-id=1239-51544&m=dev

The auth epic contains invite-adjacent work, but not a full invite-code entry flow.

Confirmed relevant nodes:

- `6923:154766` `Blocked & No Invite`
  - private-beta blocker sheet
  - copy: "Divine is currently in private beta. Please join the waitlist and we'll notify you as soon as you can get access."
  - one `OK` action
- `6923:159338` waitlist success state
  - copy begins with "You're in!"
  - confirms updates will be sent to the user's email

Nearby auth nodes that are not invite-code entry:

- `6923:143626` verify email sheet
- `6923:154652` secure account sheet
- `6923:154538` complete profile sheet
- several unrelated trust/safety block and unblock sheets

## Main Figma finding

The current Figma work appears to cover:

- no-invite / private-beta blocker
- waitlist success

It does not appear to cover:

- enter invite code
- validate invite code
- invalid code state
- already used or revoked code state
- network failure / fail-closed state

## Figma copy note

The waitlist success copy currently includes a typo:

- "When we more invites codes are available"

Expected correction:

- "When more invite codes are available"

## Practical conclusion

What we currently have is enough to build a waitlist-gated private-beta blocker.

What we do not yet have is:

- a complete invite-code onboarding flow design
- an implemented mobile flow that matches the current invite server
- full auth-model alignment between the mobile spec and the invite server

## Likely next steps

1. Align product direction between `#1120`, the current auth flow, and `INVITE_CODE_API.md`.
2. Decide whether this branch is implementing:
   - waitlist/private-beta gating only, or
   - true invite-code gating
3. If true invite-code gating is intended, design the missing states:
   - code entry
   - valid
   - invalid
   - used/revoked
   - offline/fail-closed
4. Then wire the chosen flow into auth onboarding and remove or explicitly exempt conflicting paths.

## Mobile implementation status

Implemented in the `invite-code-gating` worktree:

- server-driven invite gate route before account creation
- protected `/welcome/create-account` route that redirects back to invite gate
  when invite approval is missing
- invite client for:
  - `GET /v1/client-config`
  - `POST /v1/validate`
  - `POST /v1/waitlist`
  - `POST /v1/consume-invite`
- Figma-aligned private-beta blocker and waitlist success screens
- invite-code entry screen with waitlist and support fallback
- invite deep-link parsing for `https://divine.video/invite/{code}` and
  `https://divine.video/invite?code=...`
- pre-consume wiring at the real onboarding seams:
  - anonymous/local key creation now consumes with a generated in-memory key
    before persisting it
  - Divine OAuth sign-in now consumes after code exchange and before
    `signInWithDivineOAuth`
  - email verification polling persists invite context across restarts and
    consumes before final sign-in
- auth bootstrap no longer auto-creates a fresh Nostr identity on install;
  fresh installs now stay unauthenticated until the invite/welcome flow runs
- invite-consume failures during account creation now route users back toward
  the invite gate with the code prefilled and recovery copy, instead of leaving
  them in generic auth-error dead ends

Product decisions now reflected in the mobile implementation:

- launch mode is server-switchable
- no-code users can join the waitlist
- existing Nostr identity paths still bypass the guard
- anonymous/no-backup account creation is also behind the guard
- current account creation flow is preserved after invite approval

## Remaining launch gap

The main remaining gap is server alignment, not the mobile flow shape.

What is implemented now:

- mobile validates invite codes before entering account creation
- mobile blocks direct route bypasses into the create-account screen
- mobile no longer auto-mints a new identity during auth initialization on
  fresh install
- mobile attempts invite consumption at the actual new-account seams for:
  - anonymous/local identity creation
  - `login.divine.video` / Divine OAuth login completion
  - email-verification completion after cold start or deep-link return
- mobile gives invite-specific recovery guidance when consume fails at those
  seams, including a path back to invite entry with waitlist/support fallback

What still depends on the server contract:

- stable `POST /v1/consume-invite` behavior and final error semantics
- confirmation that Keycast-created accounts should consume at post-exchange,
  pre-session setup on mobile
- operational handling for rare cases where invite consume succeeds but local
  secure-storage persistence fails immediately afterward
