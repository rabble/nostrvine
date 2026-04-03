Status: Approved

# Apps Explore Tab And Directory Bootstrap

**Date:** 2026-03-25
**Status:** Approved
**Repo:** divine-mobile

## Problem

The sandbox PR made vetted apps reachable from Settings, but that buries the feature in a secondary surface and makes the app list feel optional instead of first-class. At the same time, we need a repeatable way to publish the first batch of vetted apps without hardcoding them into Flutter.

## Goals

- Make `Apps` visible as a top tab inside Explore.
- Keep the worker as the source of truth for the app list.
- Add a repo-owned bootstrap path for the initial vetted app manifests.
- Preserve the standalone `/apps` route as a fallback surface.

## Non-Goals

- Making the sandbox work on Flutter web or Chrome.
- Hardcoding vetted app metadata into the mobile client.
- Building a full polished admin workflow in this slice.

## Solution Summary

Add `Apps` as the last Explore top tab so the existing saved explore tab indices remain stable. Reuse the current `AppsDirectoryScreen` in two modes: standalone for `/apps`, and embedded inside Explore without its own scaffold or back button.

The Settings `Apps` tile should no longer push `/apps`. It should send the user to Explore with the forced tab name set to `apps`. The direct `/apps` route stays available for fallback navigation, tests, and future deep links.

For catalog data, add repo-owned manifest fixtures under the worker package plus a small import/upsert path for admins. The listed apps are stored as manifests that the worker validates and serves through `GET /v1/apps`, not Flutter constants.

## App Directory Bootstrap

Store one manifest per vetted app in the worker package so the initial catalog is auditable in git. The first batch is:

- `app.flotilla.social`
- `habla.news`
- `zap.stream`
- `primal.net`
- `yakihonne.com`
- `shopstr.store`
- `nostrnests.com`

Use one shared initial policy:

- `allowed_methods`: `getPublicKey`, `signEvent`, `nip44.encrypt`, `nip44.decrypt`
- `prompt_required_for`: `signEvent`, `nip44.encrypt`, `nip44.decrypt`
- `allowed_sign_event_kinds`: narrow starter set for common client behavior only

The exact signable kinds should stay conservative in this slice and can widen later per app as compatibility work proves it necessary.

## Testing

- Widget tests for embedded `AppsDirectoryScreen`.
- Explore screen tests that assert the `Apps` tab is present and routable.
- Settings navigation tests that assert `Apps` jumps to Explore with `forceExploreTabNameProvider = 'apps'`.
- Worker tests that validate the seeded manifests parse cleanly and surface through the existing directory APIs/import utilities.
