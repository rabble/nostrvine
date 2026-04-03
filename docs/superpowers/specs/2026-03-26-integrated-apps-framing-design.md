Status: Approved

# Integrated Apps Framing

**Date:** 2026-03-26
**Status:** Approved
**Repo:** divine-mobile

## Problem

The current apps surface still reads too much like a generic embedded browser. Labels like `Apps`, `Launch URL`, and `Open In Sandbox` make the feature sound broader than it is, which is the opposite of what we want users and App Review to infer.

## Goals

- Make it obvious that this is a fixed set of approved third-party integrations.
- Prefer user-facing language that feels closer to Slack-style integrations than open web browsing.
- Remove browser-like and sandbox-heavy copy from the main launch flow.
- Keep the technical constraints intact: approved origins only, no arbitrary browsing, permissions stay scoped.

## Non-Goals

- Changing the actual bridge policy or navigation restrictions.
- Making the web build support these integrations.
- Building new review-only UI or an App Store review mode.

## Solution Summary

Reframe the feature as `Integrated Apps` throughout the mobile surface. The Explore top tab, Settings entry, directory screen, app detail screen, and loading/error states should all speak in terms of approved integrations rather than a browser sandbox.

The app detail screen should explicitly explain the boundary before launch: the app is approved, runs inside Divine, has scoped permissions, and cannot turn into arbitrary web browsing. This gives users a clear mental model and also makes the bounded nature of the feature legible during review.

## Copy Direction

- Primary label: `Integrated Apps`
- Settings subtitle: describe approved third-party apps that run inside Divine
- Directory empty state: refer to approved integrations, not a remote directory refresh
- App detail explainer: approved integration, limited access, reviewed capabilities
- Launch CTA: `Open Integration`
- Loading state: `Loading integration`
- Blocked navigation state: explain that Divine blocks navigation outside the approved integration

## Testing

- Widget tests for the Explore tab label and directory copy
- Widget tests for Settings copy
- Widget tests for app detail explainer and launch CTA
- Widget tests for the integration loading state and blocked-navigation copy
