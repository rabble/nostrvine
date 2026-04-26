# Settings Taxonomy Design

Status: Proposed
Date: 2026-04-26

## Context

The current settings hub exposes `Content Preferences` and `Moderation Controls`
as separate top-level destinations. That split is becoming too narrow for the
next set of settings work: Bluesky publishing, third-party validators, feed
format preferences, closed captions, and other app-wide behavior do not fit
cleanly into either content preferences or moderation.

At the same time, content filtering and moderation should stay easy to find.
Users need one clear place for controls that affect what content is shown,
warned, hidden, blocked, or trusted.

## Decision

Move toward two clearer top-level settings destinations:

- `General Settings`: app behavior, integrations, accessibility defaults, and
  creator or playback preferences that change how Divine behaves for the user.
- `Content & Safety`: content filtering, moderation, age gates, blocked people,
  and trust controls that affect what the user allows or avoids.

Rule of thumb:

- If the setting changes how the app behaves for me, it belongs in
  `General Settings`.
- If the setting changes what content, accounts, or moderation signals I allow,
  it belongs in `Content & Safety`.

## Proposed Settings Hub

The main Settings screen should stay short and navigational:

- `General Settings`
- `Content & Safety`
- `Notifications`
- `Creator Analytics`
- `Support Center`
- `Nostr Settings`

Feature-gated destinations such as Bluesky should move inside the appropriate
section instead of adding more top-level rows over time.

## General Settings

General Settings should group app-wide behavior into sections:

### Integrations

- Bluesky publishing
- Approved third-party app connections
- Third-party validators, proof providers, or attestors when the user is
  connecting and managing them as services

Third-party validators belong here by default because the primary user action is
connecting or managing a service. If a validator's output later controls feed
filtering, blocking, or moderation decisions, the consuming policy should also
surface in `Content & Safety`.

### Viewing

- Closed captions default on/off
- Feed format preference: square videos only, or square and portrait videos
- Playback defaults that affect how video is presented

### Creating

- Audio reuse preference
- Default recording aspect ratio if we add one
- Audio input device selection on platforms where it applies
- Publishing preferences that are not safety policy

### App

- App language
- Experimental features, if they are not already scoped to Nostr settings
- Other general app behavior preferences

## Content & Safety

Content & Safety should group controls that decide what content or people the
user allows:

### What You See

- Content filters with per-category show, warn, or filter-out controls
- Adult content age gate and adult-category lock state
- Divine-hosted-only video filter, because it restricts visible media sources

### Moderation

- Divine moderation provider
- People-I-follow moderation signals
- Custom moderation labelers
- Future threshold-based or provider-based moderation policies

### People

- Blocked users
- Future muted accounts, muted words, or report history if implemented

### What You Publish

- Account content labels
- Other self-labeling controls that affect how the user's own content is
  classified for viewers

## Implementation Shape

Keep the implementation incremental:

1. Add a new `GeneralSettingsScreen` route and move existing app-behavior rows
   there without changing their underlying services.
2. Rename or replace the top-level `Content Preferences` and `Moderation
   Controls` entries with `Content & Safety`.
3. Fold the existing content filters route and safety settings route into the
   `Content & Safety` hierarchy, preserving direct routes where other screens
   already link to them.
4. Move Bluesky publishing into `General Settings` while keeping its existing
   route and feature flag.
5. Add new settings for captions and feed format using small, focused
   preference services rather than expanding unrelated moderation services.

Existing routes should remain as compatibility paths until all internal links
and deep links are migrated.

## Testing

Focused tests should cover:

- The Settings hub shows the new top-level destinations.
- General Settings routes to Bluesky publishing when the feature is enabled.
- General Settings exposes captions and feed format preferences once those
  controls exist.
- Content & Safety exposes content filters, age gate, moderation providers, and
  blocked users.
- Existing direct navigation to content filters still works from video warning
  affordances.

Visual or golden tests are only needed if the layout changes beyond list
composition and route labels.

## Out Of Scope

- Redesigning individual setting controls.
- Changing moderation policy behavior.
- Implementing third-party validator protocol support.
- Changing video recording aspect-ratio behavior.
- Changing subtitle fetching or rendering.
