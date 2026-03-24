Status: Historical

> Historical note
> Preserved for context during the P1 documentation refresh. This file may reference deleted screens, older branding, or superseded implementation details. Start with docs/README.md and docs/archive/README.md for current guidance.

# Trusted Moderation Filters Design

## Goal

Make trusted kind-1985 content-warning labels participate in the same per-category
`Show / Warn / Hide` feed behavior as creator self-labels, while preserving the
existing distinction between:

- creator self-labels on `VideoEvent.contentWarningLabels`
- FunnelCake/server moderation labels on `VideoEvent.moderationLabels`
- trusted third-party labeler events stored in `ModerationLabelService`

Users must also be able to choose who their trusted moderators are. Existing
Divine and custom labeler controls remain the primary trust surface, and the
stubbed "People I follow" option becomes an optional additional trust source.

## Current Problem

The app already ingests trusted kind-1985 labels in
`mobile/lib/services/moderation_label_service.dart`, but feed filtering does not
use them. Feed filtering currently only consults:

- `video.contentWarningLabels` for creator self-labels
- `video.moderationLabels` for FunnelCake moderation labels

That means:

- trusted labeler warnings can influence badge/AI-status UI in some places
- the same trusted warnings do not currently drive feed warn overlays or hide
  behavior
- local draft files exist to bridge this gap, but they are out of sync with the
  current `main` branch and target APIs that no longer exist

## Design

### 1. Effective Warning Resolver

Introduce a focused helper responsible for computing the effective warning label
set for a `VideoEvent`. This helper will merge:

- creator self-labels from `video.contentWarningLabels`
- trusted kind-1985 labels matched by addressable `a` target
- trusted kind-1985 labels matched by event `e` target
- trusted kind-1985 labels matched by content hash `x` target
- trusted kind-1985 labels matched by account `p` target
- `#nsfw` / `#adult` hashtag fallback

This resolver becomes the single source for feed `warn` and `hide` decisions
when trusted moderators are enabled.

### 2. Preserve Model Semantics

Do not promote trusted third-party labels into `VideoEvent.contentWarningLabels`.
That field continues to mean creator-applied self-labels only.

Do not merge trusted labeler results into `VideoEvent.moderationLabels` either.
That field continues to mean FunnelCake/server moderation labels, which remain
hide-only because they are system-generated and may be noisy.

Instead, use the effective warning resolver only at the filtering boundary.

### 3. Matching Order and Replaceable Events

For replaceable video events, trusted label matching must prefer the full
addressable coordinate rather than bare `d` tags.

Matching order:

1. `a` / addressable id (`kind:pubkey:d-tag`)
2. `e` / event id
3. `x` / content hash
4. `p` / pubkey
5. hashtag fallback

This avoids false matches across different authors that happen to reuse the
same `d` tag value.

### 4. Trusted Moderator Selection

Use the existing `ModerationLabelService.subscribedLabelers` set as the source
of truth for explicit trusted moderators:

- Divine official labeler
- custom `npub` labelers added by the user

Extend the existing Safety & Privacy moderation-provider section so the current
"People I follow" stub becomes a persisted optional trust source. When enabled,
followed accounts who publish kind-1985 labels are treated as trusted
moderators for feed filtering.

Default trust model:

- Divine enabled
- custom labelers opt-in
- people-I-follow trust disabled by default

### 5. Filtering Behavior

Trusted kind-1985 content-warning labels should behave like creator self-labels
for feed decisions:

- `hide` removes the video from feeds
- `warn` keeps the video but triggers the warning overlay
- `show` leaves the video visible without an overlay

FunnelCake moderation labels remain separate and hide-only.

### 6. Boundaries to Update

Primary integration points:

- `mobile/lib/services/moderation_label_service.dart`
- `mobile/lib/services/video_event_service.dart`
- `mobile/lib/services/nsfw_content_filter.dart`
- `mobile/lib/screens/safety_settings_screen.dart`

Secondary support:

- app/provider wiring for the follow-derived trust toggle
- tests covering resolver logic, service behavior, and settings UI

## Error Handling

- Invalid or unknown label values should be normalized when possible and
  otherwise preserved only where the UI needs to show generic warning state.
- Missing `a`, `e`, `x`, or `p` tags should not cause failures; the resolver
  should simply skip unavailable match keys.
- Follow-derived trust must degrade safely when follow data is unavailable:
  only explicit subscribed labelers are trusted in that case.

## Testing Strategy

### Unit tests

- resolver merges self labels, trusted labeler labels, and hashtag fallback
- resolver prefers `a` matching for addressable videos
- resolver falls back to `e`, `x`, and `p` correctly
- unknown labels do not break filtering

### Service tests

- `VideoEventService.filterVideoList()` applies `warn` from trusted kind-1985
  labels
- `VideoEventService.filterVideoList()` hides videos from trusted kind-1985
  labels when preferences are `hide`
- `video.moderationLabels` remain hide-only
- self-label semantics remain unchanged

### UI/settings tests

- Safety Settings persists Divine/custom/follow-derived trust choices
- enabling "People I follow" changes the trusted moderation source set

## Non-Goals

- redesigning the Safety & Privacy UI
- changing the meaning of `contentWarningLabels`
- converting trusted labeler results into FunnelCake moderation labels
- adding a brand-new moderation data model if the current service can support
  the behavior with focused extensions
