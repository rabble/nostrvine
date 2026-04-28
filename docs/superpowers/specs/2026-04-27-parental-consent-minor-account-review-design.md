Status: Historical

> Historical note
> Implementation design for a proposed feature. Validate against current code, legal guidance, and backend capabilities before shipping.

Validated against: `mobile/lib/router/app_router.dart`, `mobile/lib/services/auth_service.dart`, `mobile/lib/repositories/dm_repository.dart`, current inbox/report flows, and `docs/plans/2026-04-27-parental-consent-minor-account-review.md` on 2026-04-27.

# Parental Consent / Minor-Account Review Implementation Design

**Date:** 2026-04-27

## Goal

Implement the post-report moderation flow for accounts that may belong to minors.

This design covers:

- server-backed restriction state
- moderator-triggered case creation
- mobile router gating
- restricted-user UX
- moderation DM integration
- private evidence/support submission entry points

This design does **not** change initial onboarding.

## Product Rules Locked In

- Divine continues to use its current onboarding attestation that the user is over 16.
- This flow is triggered only after a user report and manual moderator action.
- Divine is not doing biometric age estimation, passive age inference, or mass-surveillance-style verification.
- This is a Divine-side product restriction, not a global Nostr identity ban.
- Users likely under 13 do not complete an in-app consent flow. Their parent or guardian must email support.
- This feature is named `Parental Consent / Minor-Account Review`, not `Age Verification`.

## Current Codebase Seams To Reuse

- Authentication state remains in [`mobile/lib/services/auth_service.dart`](</Users/lizsw/divine-mobile-u16exp/.worktrees/minor-account-review-flow/mobile/lib/services/auth_service.dart:63>).
- App routing and redirect behavior live in [`mobile/lib/router/app_router.dart`](</Users/lizsw/divine-mobile-u16exp/.worktrees/minor-account-review-flow/mobile/lib/router/app_router.dart:1>).
- DMs already flow through [`mobile/lib/repositories/dm_repository.dart`](</Users/lizsw/divine-mobile-u16exp/.worktrees/minor-account-review-flow/mobile/lib/repositories/dm_repository.dart:1>) and `dmRepositoryProvider`.
- The Divine moderation pubkey already exists via [`mobile/lib/services/moderation_label_service.dart`](</Users/lizsw/divine-mobile-u16exp/.worktrees/minor-account-review-flow/mobile/lib/services/moderation_label_service.dart:115>).
- Inbox and conversation routes already exist and can be reused for the moderation DM entry path.

## High-Level Architecture

### Source Of Truth

The backend is the source of truth for:

- whether an account is restricted
- the current minor-review case state
- what resolution path applies
- whether the user is cleared, denied, or needs follow-up

The mobile app should not infer restriction state from local storage or DM content.

### Separation Of Concerns

- `AuthState` continues to answer: is the user authenticated?
- `MinorAccountReviewStatus` answers: is the authenticated account restricted by Divine due to a minor-account review case?

This prevents auth logic from absorbing moderation/business rules.

## Backend Data Model

### Account Restriction

Add a server-backed restriction model keyed by account pubkey:

```json
{
  "pubkey": "<hex>",
  "status": "active | restricted_minor_review",
  "reason": "minor_account_review",
  "caseId": "mar_123",
  "updatedAt": "2026-04-27T18:00:00Z"
}
```

### Minor Review Case

Recommended case payload:

```json
{
  "id": "mar_123",
  "pubkey": "<hex>",
  "state": "restricted_pending_user_response",
  "suspectedAgeBand": "under_13 | age_13_15 | age_16_plus_claimed | unknown",
  "allowedResolution": "support_email_only | parent_video_or_email | support_review_only",
  "supportEmail": "support@divine.video",
  "moderationConversationPubkey": "<divine moderation hex pubkey>",
  "moderationConversationId": "<optional deterministic conversation id>",
  "instructions": {
    "title": "We need to review this account",
    "body": "..."
  },
  "evidence": {
    "videoSubmissionAllowed": true,
    "parentEmailAllowed": true
  },
  "timestamps": {
    "openedAt": "...",
    "lastUpdatedAt": "...",
    "expiresAt": "..."
  }
}
```

### Case States

Recommended canonical state machine:

- `open_reported`
- `under_moderator_review`
- `restricted_pending_user_response`
- `restricted_pending_parental_consent`
- `restricted_pending_support_email`
- `submitted_for_review`
- `needs_follow_up`
- `cleared`
- `denied_closed`

### Moderator Audit Fields

Every case transition should record:

- `actorId`
- `previousState`
- `newState`
- `reasonCode`
- `freeformNote`
- `timestamp`

## Backend API Surface

### 1. Get Current Account Review Status

`GET /v1/account/moderation-status`

Auth: current account auth

Response:

```json
{
  "restriction": {
    "status": "active"
  },
  "minorReviewCase": null
}
```

or:

```json
{
  "restriction": {
    "status": "restricted_minor_review",
    "caseId": "mar_123"
  },
  "minorReviewCase": {
    "...": "..."
  }
}
```

This should be fetched on authenticated app startup and refreshed when the app resumes.

### 2. Submit Private Video Evidence

Only needed if the product keeps the private video path for ages 13-15.

Suggested flow:

1. `POST /v1/minor-review-cases/:id/video-upload-session`
2. backend returns private upload target or short-lived credentials
3. app uploads directly to private storage
4. app finalizes with `POST /v1/minor-review-cases/:id/video-submissions`

Response should return the updated case state.

Do not create a public media URL or Nostr event.

### 3. Submit Parent Contact Email

`POST /v1/minor-review-cases/:id/parent-contact`

Payload:

```json
{
  "email": "parent@example.com"
}
```

This is for the 13-15 path if parent email is allowed as an alternative to video.

### 4. Refresh Case State

Either:

- poll `GET /v1/account/moderation-status`, or
- add a push/notification mechanism later

MVP should use polling on:

- app launch
- app resume
- successful submission completion
- manual "Check again" action on the restricted screen

## Mobile Domain Model

Create a dedicated domain model in the app for the server response.

Suggested types:

```dart
enum AccountRestrictionStatus {
  active,
  restrictedMinorReview,
}

enum MinorReviewCaseState {
  openReported,
  underModeratorReview,
  restrictedPendingUserResponse,
  restrictedPendingParentalConsent,
  restrictedPendingSupportEmail,
  submittedForReview,
  needsFollowUp,
  cleared,
  deniedClosed,
}

enum SuspectedAgeBand {
  under13,
  age13To15,
  age16PlusClaimed,
  unknown,
}

enum MinorReviewResolutionType {
  supportEmailOnly,
  parentVideoOrEmail,
  supportReviewOnly,
}
```

Suggested aggregate:

```dart
class MinorAccountReviewStatus {
  final AccountRestrictionStatus restrictionStatus;
  final MinorReviewCase? currentCase;
}
```

## Mobile Data Layer

### Repository

Add a dedicated repository:

`mobile/lib/repositories/minor_account_review_repository.dart`

Responsibilities:

- fetch moderation status
- create parent-contact submission
- create video-upload session and finalize submission
- expose a simple polling refresh API

Dependencies:

- authenticated HTTP client or existing REST client wiring
- current auth identity for request authorization

### Provider

Add a Riverpod provider:

`minorAccountReviewRepositoryProvider`

And a user-scoped status provider, for example:

`currentMinorAccountReviewStatusProvider`

This provider should:

- only resolve when `currentAuthStateProvider` is `authenticated`
- return `active` or the live restricted state
- refresh on explicit invalidation

## Router Integration

### New Route

Add a full-screen route outside the tab shell:

- `/account-review`

This route should push at the root level and suppress bottom navigation.

### Redirect Rules

Update the router redirect logic in [`mobile/lib/router/app_router.dart`](</Users/lizsw/divine-mobile-u16exp/.worktrees/minor-account-review-flow/mobile/lib/router/app_router.dart:1>) so that:

1. if unauthenticated, current auth rules continue unchanged
2. if authenticated and `restrictionStatus == restrictedMinorReview`:
   - redirect all non-exempt routes to `/account-review`
3. exempt routes should include only:
   - `/account-review`
   - moderation DM conversation route for the Divine moderation thread
   - support/help routes if needed

This must be a hard route gate, not just a disabled UI state.

### Exempt Navigation Surface

Restricted users should still be allowed to:

- open the moderation DM thread
- open support center
- sign out

Everything else should be blocked by routing or feature guards.

## Mobile Feature Structure

Do not reuse the current under-16 onboarding bloc directly.

Add a dedicated feature area, for example:

- `mobile/lib/features/minor_account_review/`

Suggested slices:

- `models/`
- `repository/` if colocated
- `blocs/`
- `screens/`
- `widgets/`

### Suggested Blocs/Cubits

#### `MinorAccountReviewCubit`

Responsibilities:

- load current case data
- refresh status
- expose loading / loaded / error states
- trigger "check again"

#### `MinorAccountReviewSubmissionCubit`

Responsibilities:

- handle parent email submission
- handle private video submission lifecycle if approved
- emit submission progress and result

Keep the read state and submission state separate so refresh and submission failures do not fight each other.

## Restricted User Screens

### 1. `MinorAccountReviewScreen`

Primary full-screen gate.

Shows:

- title and explanation from case instructions
- case ID
- current status
- what is blocked
- next action

Actions:

- `Continue`
- `Open moderation message`
- `Contact support`
- `Check again`
- `Log out`

### 2. `ParentContactScreen`

Used when the case allows a parent email path.

Fields:

- parent email

Behavior:

- submit to backend
- show confirmation state

### 3. `Under13SupportInstructionsScreen`

Used when `allowedResolution == supportEmailOnly`.

Shows:

- support email
- case ID
- simple instructions for the parent or guardian

No in-app upload or local video capture.

### 4. `PrivateConsentVideoScreen`

Only if the product keeps the 13-15 private video path.

Behavior:

- private capture flow
- no publishing tools
- no feed/editor metadata pipeline
- clear disclosure that the video is private and reviewed only by Divine moderators

### 5. Result/Status Blocks

In the main review screen or follow-up screens:

- `submitted_for_review`
- `needs_follow_up`
- `cleared`
- `denied_closed`

## DM Integration

When a moderator opens a case, the backend should send a DM from the Divine moderation account.

### Why Reuse DM

- current app already supports inbox and conversation flows
- moderation team already has a Divine moderation pubkey path
- restricted users should have one human-readable thread for follow-up

### Mobile Implementation

The app should not parse the DM as its source of truth.

Instead:

- use server case state for routing and UI
- use the DM as an accessible communication surface

To open the moderation thread from the restriction screen:

- compute or receive the moderation conversation ID
- route to the existing conversation page

If the backend does not provide `moderationConversationId`, the app can compute it deterministically using the current user's pubkey and the moderation pubkey, matching existing DM repository behavior.

## Existing Content Handling

Recommended MVP behavior:

- hide the restricted user's existing content from Divine-controlled feed, profile, search, and discovery surfaces while the case is open
- keep the data intact in the protocol layer; this is a Divine serving decision

Technical implication:

- backend or client-side feed filters need a way to suppress content from restricted accounts in Divine surfaces

This is larger than the mobile gate alone and should be coordinated with backend/moderation serving rules.

## Private Evidence Upload Design

If private video submission is included:

- do not use normal public video publishing
- do not create a kind 34236/34235 event
- do not upload to the user-visible media pipeline

Recommended implementation:

1. backend creates a case-bound upload session
2. app uploads directly to private object storage
3. backend stores a private evidence record
4. moderator tooling renders the video via short-lived signed URL

Suggested app service:

- `minor_account_review_upload_service.dart`

Reusing low-level upload utilities is fine, but the product path must stay fully separate from public publishing.

## Polling And Refresh Rules

MVP refresh behavior:

- fetch on authenticated startup
- refresh on app resume
- refresh after any successful submission
- manual "Check again" button

Optional background polling while on the review screen:

- every 30-60 seconds while visible

Do not spam the backend from every screen. Restrict polling to the review flow.

## Error Handling

### Status Fetch Fails

- if the app cannot fetch restriction state at startup, prefer a safe failure mode for users already known locally as restricted
- for MVP, if no local restricted marker exists, fall back to last successful status and retry on resume

Recommended optional local cache:

- store last known restriction status with timestamp
- use only for boot continuity, never as the long-term source of truth

### Submission Fails

- preserve the user on the review screen
- show actionable error
- do not clear the case state

### Moderation DM Missing

- the flow should still function without the DM
- the review screen remains the primary experience

## Analytics And Logging

Track at minimum:

- restriction gate shown
- review screen opened
- parent contact submitted
- private video submission started/completed
- check-again tapped
- moderation DM opened

Never log raw submitted evidence URLs or personal content.

## Testing Plan

### Unit Tests

- repository parsing for moderation status
- state mapping for each case state
- submission cubit success/failure

### Router Tests

- authenticated unrestricted user is not redirected
- restricted user is redirected to `/account-review`
- restricted user can open exempt routes only

### Widget Tests

- review screen renders correct CTA for each resolution type
- under-13 screen shows support email and case ID
- submission states show correct progress and errors

### Integration Tests

- case opens on server -> app redirects to restriction screen
- parent contact submission updates UI to submitted state
- case cleared on refresh -> app exits restriction flow

## Phased Delivery

### Phase 1: Read-Only Restriction Flow

- backend status endpoint
- app repository/provider
- router gate
- review screen
- moderation DM entry button

### Phase 2: Parent Contact Path

- parent email submission endpoint
- parent contact screen
- follow-up states

### Phase 3: Private Video Path

- private upload session
- private submission UI
- moderator evidence viewer integration

### Phase 4: Serving Enforcement Follow-Through

- suppress restricted accounts from Divine surfaces while open
- align backend moderation serving rules with the mobile restriction state

## Explicit Non-Goals

- replacing onboarding attestation
- building a global Nostr ban mechanism
- passive age estimation
- reporter-visible case outcome UI
- automated report-triggered restrictions
