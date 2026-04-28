Status: Historical

> Historical note
> Planning document for a proposed feature. Preserve for implementation context, but validate against current code, policy, and legal guidance before shipping.

Validated against: `AGENTS.md`, `CONTRIBUTING.md`, current moderation docs, current DM/inbox architecture, and current under-16 prototype code on 2026-04-27.

# Parental Consent / Minor-Account Review Plan

## Goal

Design a post-report moderation flow for accounts that may belong to minors.

This plan does **not** change initial onboarding. Users will continue to attest during onboarding that they are over 16. This plan only covers the later moderation flow that can happen after a report and manual moderator review.

## Current Product Decision

- Feature name: `Parental Consent / Minor-Account Review`
- Trigger: a user report alleging the account holder appears under 16
- Action source: `manual moderator action only`
- Age policy:
  - `16+`: account may be restored after moderator review
  - `13-15`: account may be restored with parental consent
  - `<13`: no in-app consent resolution; parent or guardian must email support
- Verification posture:
  - Divine is **not** doing biometric age estimation or other mass-surveillance-style age verification
  - any submitted video is only evidence for human moderator review
- Protocol posture:
  - this restricts an `npub` inside Divine-controlled experiences only
  - this is not a global Nostr identity ban

## Non-Goals

- Replacing or expanding initial onboarding
- Global Nostr enforcement across third-party clients
- Automated report-triggered suspensions
- Biometric estimation, face analysis, or passive age inference
- Public posting of consent evidence

## Core User Story

1. A user reports another account as likely under 16.
2. A moderator reviews the report and decides whether to open a minor-account review case.
3. If the moderator opens a case, Divine restricts the reported account inside Divine-controlled surfaces.
4. Divine sends the restricted user a moderation DM and shows a hard in-app gate.
5. The user follows the case instructions:
   - if likely `13-15`, submit parental consent evidence privately or follow a parent contact path
   - if likely `<13`, have a parent or guardian email support with the case ID
   - if actually `16+`, follow the appeal/review path described in the moderation DM and case screen
6. A moderator reviews the submission and clears, denies, or requests follow-up.

## Restriction Semantics

When an account is placed into minor-account review, Divine should treat it as `restricted`, not `signed out`.

Recommended MVP behavior:

- Allowed:
  - sign in
  - view the restriction screen
  - read the Divine moderation DM thread
  - open support/help/legal screens
  - log out or switch accounts
- Blocked:
  - upload or publish content
  - record new content
  - comment
  - like, repost, or follow
  - start new DMs or respond to non-moderation conversations
  - edit profile

Open policy choice for MVP:

- Existing content during an open case:
  - preferred safer option: hide the user from Divine feed/profile/search surfaces while the case is open
  - lighter option: freeze new activity only and leave existing content visible

## Case State Machine

The server should own the case state, separate from `AuthState`.

Recommended states:

- `open_reported`
- `under_moderator_review`
- `restricted_pending_user_response`
- `restricted_pending_parental_consent`
- `restricted_pending_support_email`
- `submitted_for_review`
- `needs_follow_up`
- `cleared`
- `denied_closed`

Recommended account restriction status:

- `active`
- `restricted_minor_review`

The mobile app should read account restriction status from the backend and route accordingly.

## Moderator Entry Criteria

Since this is manual-only for MVP, moderator consistency matters more than automation.

Moderators should document the reason for opening a case, for example:

- reported content strongly suggests the account holder is under 16
- profile/about/copy strongly suggests the account holder is under 16
- direct admission in comments or DMs
- repeated independent reports that point to the same concern

Opening a case should require:

- a recorded reason
- the source report or source content reference
- the moderator ID in the audit log

## User Experience

### 1. Moderation DM

When a case opens, Divine sends a DM from the Divine moderation account with:

- plain-language explanation
- case ID
- what is currently restricted
- what the user can do next
- support contact information

This DM should not be the only notification surface.

### 2. Hard Restriction Gate

On next launch or refresh, the app should route the user to a full-screen restriction hub.

The restriction hub should explain:

- the account is under review
- this is a Divine safety restriction, not a global identity deletion
- what path applies next
- where to get help

Primary actions depend on the case path:

- `13-15`: start private parental consent submission or parent-contact path
- `<13`: show support email instructions and case ID
- `16+ claim`: show appeal/review instructions

### 3. Under-13 Path

No in-app consent resolution.

The screen and DM should instruct the user:

- have your parent or guardian email support
- include case ID
- explain what information support needs

## Evidence Handling

If the `13-15` path allows a private consent video, treat it as moderation evidence only.

Requirements:

- no public Nostr event
- no normal publishing flow
- no public Blossom/media URL
- private storage only
- short-lived signed reviewer links
- short retention window
- moderator-only access

Recommended minimum capture guidance:

- short script shown on screen
- clear case ID association
- user understands the video is private and for moderator review only

Recommended fallback path:

- allow a parent or guardian contact/support path in addition to video submission

## Moderator Tooling Requirements

The flow needs real internal tooling, even for MVP.

Minimum viable moderator tooling:

- case queue
- case detail view
- report/source context
- state transitions
- internal notes
- evidence viewer
- approve / deny / request follow-up actions
- audit log

Recommended sensitive-case safeguards:

- second reviewer for denials or ambiguous cases
- documented SOP for acceptable parental consent
- clear retention and deletion rules

## Mobile Architecture Direction

Recommended mobile design:

- keep `AuthState` focused on authentication
- add a separate server-backed restriction model
- add router gating based on restriction status
- create a dedicated feature flow for `Parental Consent / Minor-Account Review`
- do not reuse the current under-16 onboarding bloc as-is

The current under-16 prototype may still provide:

- copy ideas
- layout patterns
- camera/recording interaction ideas

But the new feature should be implemented as a distinct flow because:

- trigger is post-report, not onboarding
- policy is moderation-driven, not self-started
- routing and restriction semantics are different

## Suggested Implementation Phases

### Phase 1: Policy And Operations

- finalize allowed age bands
- finalize restriction semantics
- finalize under-13 support-email process
- finalize moderator SOP
- finalize evidence retention and deletion policy

### Phase 2: Backend And Moderator Foundations

- add case and restriction models
- add moderator queue and audit logging
- add support for moderation DM trigger
- add private evidence submission/review path if required

### Phase 3: Mobile Restriction Flow

- fetch server-backed restriction status
- route restricted users to a hard gate
- show moderation DM entry path
- implement the case hub and restricted-state UX

### Phase 4: Submission And Review UX

- implement private submission flow for the `13-15` path if approved
- implement parent-email instructions for the `<13` path
- implement follow-up and cleared/denied screens

## Open Questions

- Should existing content be hidden from Divine surfaces while a case is open?
- Should restricted users retain read-only feed access, or only case/support access?
- For `13-15`, is parent email alone acceptable, or is private video the primary path?
- What exactly counts as acceptable parental consent for moderator approval?
- What SLA does the moderation team commit to for review and follow-up?
- How long is evidence retained after `cleared` or `denied_closed`?
- What is the reminder and timeout policy for non-responsive users?

## Recommended Default Answers For MVP

- Manual moderator-created cases only
- Hard in-app gate plus moderation DM
- Separate restriction model from `AuthState`
- No public evidence posting
- `<13` resolved only through parent email to support
- Existing content hidden on Divine surfaces while the case is open
- Restricted users allowed only case/support access until resolution
