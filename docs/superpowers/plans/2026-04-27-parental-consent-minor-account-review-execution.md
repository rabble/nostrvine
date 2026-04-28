Status: Historical

> Historical note
> Execution plan for a proposed feature. Validate against current code, policy, and backend capabilities before implementation.

Validated against: `docs/plans/2026-04-27-parental-consent-minor-account-review.md`, `docs/superpowers/specs/2026-04-27-parental-consent-minor-account-review-design.md`, current router/auth/inbox architecture, and repository workflow rules on 2026-04-27.

# Parental Consent / Minor-Account Review Execution Plan

## Goal

Translate the approved design into an implementation sequence that can be executed across:

- backend
- moderator tooling
- mobile app

This plan covers only the post-report moderation flow.

## Scope Summary

- Manual moderator-created cases only
- Server-backed restriction status
- Hard mobile route gate for restricted accounts
- Moderation DM from Divine moderation account
- Parent email path
- Optional private video evidence path for ages 13-15
- Under-13 support-email-only path

## Recommended Delivery Order

1. Backend restriction and case read APIs
2. Mobile read-only restriction flow
3. Moderator workflow for state transitions
4. Parent email submission path
5. Private video path
6. Existing-content suppression across Divine surfaces

The key principle is: ship the smallest safe enforcement loop first, then add evidence collection.

## Phase 0: Product And Ops Lock

### Exit Criteria

- product signs off on restriction semantics
- moderation signs off on case states and SOP
- legal/privacy signs off on parent email and optional private video handling

### Decisions To Lock

- whether restricted users have any read-only feed access
- whether existing content is hidden while a case is open
- whether ages 13-15 support parent email, private video, or both
- evidence retention window
- no-response timeout and reminder policy

### Deliverables

- approved policy memo
- approved implementation design
- approved moderator SOP

## Phase 1: Backend Restriction And Case Read APIs

### Goal

Give the mobile app a server-backed source of truth for restriction status and current case details.

### Backend Tasks

1. Add account restriction data model.
2. Add minor review case data model.
3. Add audit log model for moderator state changes.
4. Implement `GET /v1/account/moderation-status`.
5. Ensure authenticated requests return current account restriction plus current case payload.

### Suggested Backend Response Contract

- `restriction.status`
- `restriction.caseId`
- `minorReviewCase.state`
- `minorReviewCase.suspectedAgeBand`
- `minorReviewCase.allowedResolution`
- `minorReviewCase.instructions`
- `minorReviewCase.supportEmail`
- `minorReviewCase.moderationConversationPubkey`
- optional `minorReviewCase.moderationConversationId`

### Mobile Tasks

Create:

- `mobile/lib/repositories/minor_account_review_repository.dart`
- `mobile/lib/models/minor_account_review_status.dart`
- `mobile/lib/models/minor_review_case.dart`

Update:

- `mobile/lib/providers/app_providers.dart`
- generated provider file if new Riverpod providers are added

### Verification

- backend contract test for authenticated active account
- backend contract test for restricted account
- mobile repository unit tests for both payloads

## Phase 2: Mobile Read-Only Restriction Flow

### Goal

When the backend marks an account as restricted, the app must immediately enforce the review flow.

### Mobile Tasks

Create:

- `mobile/lib/features/minor_account_review/`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_cubit.dart`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_state.dart`
- `mobile/lib/features/minor_account_review/screens/minor_account_review_screen.dart`
- `mobile/lib/features/minor_account_review/widgets/...`

Update router:

- `mobile/lib/router/app_router.dart`

Add route:

- `/account-review`

Add redirect logic:

- if authenticated and restricted, redirect to `/account-review`
- allow only exempt routes:
  - `/account-review`
  - moderation conversation
  - support/help routes

### UX Tasks

The first version of the screen should support:

- explanation copy
- case ID
- current case state
- support email
- open moderation message
- check again
- log out

### Verification

- router unit tests for redirect behavior
- widget tests for restricted screen state rendering
- integration test for server status -> app gate redirect

## Phase 3: Moderator Tooling And Manual Case Operations

### Goal

Support real moderator-driven case creation and resolution.

### Moderator Tooling Tasks

1. Add case queue view.
2. Add case detail screen.
3. Add actions:
   - open case
   - restrict account
   - request follow-up
   - clear
   - deny
4. Add required reason entry for opening a case.
5. Add audit log visibility.

### Backend Tasks

1. Add moderator-authenticated case transition endpoints.
2. Add notification trigger on case open.
3. Add DM trigger to Divine moderation account on case open.

### DM Integration Tasks

Reuse:

- moderation pubkey resolution already in mobile
- existing DM infrastructure

Backend or moderation tooling should send the initial message. The mobile app should not originate the moderation DM.

### Verification

- case open transition creates restriction
- case open transition triggers moderation DM
- case clear transition removes restriction
- audit log captures all state changes

## Phase 4: Parent Email Submission Path

### Goal

Provide the first user-response path without introducing private media handling yet.

### Backend Tasks

Implement:

- `POST /v1/minor-review-cases/:id/parent-contact`

Behavior:

- validate case is in a submission-allowed state
- store submitted parent email
- move case to `submitted_for_review` or a dedicated review-pending state
- append audit entry

### Mobile Tasks

Create:

- `mobile/lib/features/minor_account_review/screens/parent_contact_screen.dart`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_submission_cubit.dart`

Update:

- review screen CTA routing

### UX Rules

- under-13 users do not see this screen if policy says support email only
- 13-15 users can see this screen if email is an approved path

### Verification

- submission cubit unit tests
- widget tests for form validation and success/error
- integration test for submit -> status refresh -> submitted state

## Phase 5: Under-13 Support Email Path

### Goal

Handle likely under-13 cases without in-app consent capture.

### Backend Tasks

- include `allowedResolution = supportEmailOnly` in status response

### Mobile Tasks

Create:

- `mobile/lib/features/minor_account_review/screens/under13_support_instructions_screen.dart`

Behavior:

- show support email
- show case ID
- explain that a parent or guardian must contact Divine

### Verification

- widget tests for support instructions rendering
- router/CTA tests for under-13 state

## Phase 6: Private Video Evidence Path

### Goal

Add the optional 13-15 private video path after the basic restriction and parent-email flow already work.

### Backend Tasks

1. Add upload-session endpoint.
2. Add evidence-finalization endpoint.
3. Store private evidence records.
4. Expose reviewer access through moderator tooling using short-lived signed URLs.
5. Enforce retention and deletion policy.

### Mobile Tasks

Create:

- `mobile/lib/features/minor_account_review/screens/private_consent_video_screen.dart`
- `mobile/lib/features/minor_account_review/services/minor_account_review_upload_service.dart`

Potential reuse:

- low-level upload helpers
- camera capture infrastructure

Must not reuse:

- public publish flow
- public metadata/tagging flow
- normal video event creation

### UX Tasks

- disclosure that the video is private
- simple guided script
- submission progress
- success/failure state

### Verification

- upload service unit tests
- submission cubit tests
- end-to-end evidence upload flow test
- moderator viewer access test

## Phase 7: Existing-Content Suppression

### Goal

Make the case enforcement consistent beyond the mobile route gate.

### Backend Tasks

Decide and implement one of:

- server-side suppression of restricted accounts from Divine feed/search/profile APIs
- moderation-aware filtering in the app if backend cannot yet enforce it

### Mobile Tasks

If client-side filtering is needed temporarily:

- extend relevant feed/profile/search repositories or filters
- ensure restricted accounts are hidden in Divine surfaces

This should be coordinated carefully to avoid fragmented enforcement.

### Verification

- restricted account content absent from Divine feed/search/profile surfaces
- content returns when case is cleared if policy allows

## File-Level Mobile Execution Map

### New Files

- `mobile/lib/models/minor_account_review_status.dart`
- `mobile/lib/models/minor_review_case.dart`
- `mobile/lib/repositories/minor_account_review_repository.dart`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_cubit.dart`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_state.dart`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_submission_cubit.dart`
- `mobile/lib/features/minor_account_review/bloc/minor_account_review_submission_state.dart`
- `mobile/lib/features/minor_account_review/screens/minor_account_review_screen.dart`
- `mobile/lib/features/minor_account_review/screens/parent_contact_screen.dart`
- `mobile/lib/features/minor_account_review/screens/under13_support_instructions_screen.dart`
- `mobile/lib/features/minor_account_review/screens/private_consent_video_screen.dart` if approved
- `mobile/test/...` mirrors for all of the above

### Existing Files Likely To Change

- `mobile/lib/router/app_router.dart`
- `mobile/lib/providers/app_providers.dart`
- generated provider file if Riverpod wiring changes
- support/help route entry points if they need exemption during restriction

### Existing Systems To Reuse

- auth gating from `AuthService`
- DM conversation routing
- moderation pubkey resolution
- shared Divine UI components and `VineTheme`

## Testing Strategy By Layer

### Backend

- model tests
- auth tests
- contract tests
- state transition tests
- audit log tests

### Mobile Unit

- repository parsing
- cubit state transitions
- submission flows

### Mobile Widget

- review screen rendering per case state
- form validation
- CTA visibility by resolution type

### Mobile Integration

- active -> restricted redirect
- restricted -> submitted state
- restricted -> cleared unlock flow

## Rollout Strategy

### Rollout 1

- backend read APIs
- mobile route gate
- moderation DM
- support-only user experience

This gives you enforcement before evidence collection.

### Rollout 2

- parent email submission path

### Rollout 3

- private video path for 13-15 if still desired after operating the lighter version

### Rollout 4

- existing-content suppression across Divine surfaces if not already enforced server-side

## Risks To Watch

- mixing this flow into onboarding logic
- putting moderation state into `AuthState`
- public-media leakage from any private evidence path
- inconsistent restriction enforcement across routes and surfaces
- shipping mobile gating before moderators can actually clear or resolve cases

## Definition Of Done For MVP

- moderator can manually open a minor-account review case
- backend marks the account as restricted
- app redirects restricted account to a hard review gate
- user can read instructions, contact support, and open moderation DM
- under-13 path routes to parent-email support instructions
- moderation can clear the case and the app returns the user to normal flow

## Definition Of Done For Full Phase With Parent Email

- all MVP criteria
- 13-15 path can submit parent email through the app
- case moves to review-pending state
- moderator can approve, deny, or request follow-up

## Definition Of Done For Full Phase With Private Video

- all previous criteria
- 13-15 path can submit private video without entering the public publish pipeline
- moderator can review the evidence securely
- evidence is retained and deleted according to policy
