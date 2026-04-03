Status: Approved

# Ditto Starter App

**Date:** 2026-03-29
**Status:** Approved
**Repo:** divine-mobile

## Problem

The bundled vetted app catalog does not currently include `ditto.pub`, so Ditto is missing from the mobile integrations directory when the app falls back to its build-time starter list.

## Goals

- Add `ditto.pub` to the bundled starter app catalog used by mobile.
- Keep Ditto available even when the remote directory is empty or unavailable.
- Reuse the existing shared vetted permission defaults for third-party apps.

## Non-Goals

- Changing the Cloudflare worker seed manifests or admin bootstrap flow.
- Adding Ditto-specific bridge permissions or new allowed methods.
- Changing routing, cubits, or app detail UI behavior.

## Solution Summary

Add a new bundled Ditto entry to the mobile preloaded app list with `launchUrl: https://ditto.pub/`, the shared allowed methods, the shared prompt rules, and the next sort order after the existing starter apps.

Update the mobile directory service tests to lock the bundled fallback expectation so the starter list explicitly includes Ditto.

## Testing

- Focused Flutter test for the Nostr app directory service starter catalog and fallback behavior.
