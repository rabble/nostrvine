Status: Approved

# Five Bundled Starter Apps

**Date:** 2026-03-29
**Status:** Approved
**Repo:** divine-mobile

## Problem

The bundled vetted app catalog is missing five approved third-party apps that should be available directly from the mobile build even when the remote directory is empty or unavailable.

## Goals

- Add `Agora`, `Treasures`, `Blobbi`, `Espy`, and `Jumble` to the bundled mobile starter catalog.
- Keep the change mobile-only, with no worker or bootstrap endpoint changes.
- Reuse the existing shared vetted permission defaults used by the other starter apps.

## Non-Goals

- Changing the remote worker seed manifests.
- Introducing app-specific bridge policies or prompts.
- Changing app routing, cubits, or UI behavior outside the starter catalog contents.

## Solution Summary

Add five new entries to the bundled starter app list in `mobile/lib/services/preloaded_nostr_apps.dart`:

- `agora` -> `https://agora.spot/`
- `treasures` -> `https://treasures.to/`
- `blobbi` -> `https://www.blobbi.pet/`
- `espy` -> `https://espy.you/`
- `jumble` -> `https://jumble.social/`

Each entry will use the shared allowed methods, prompt rules, and signable kinds already used by the existing vetted apps. The names and copy should follow the sites’ current branding where available, with a short inferred brand line for Blobbi because its landing page exposes only the app name.

Update the mobile directory service tests so the bundled fallback starter list includes all five slugs and explicitly verifies the new entries’ names, launch URLs, and allowed origins.

## Testing

- Focused Flutter test for `NostrAppDirectoryService` bundled starter behavior.
