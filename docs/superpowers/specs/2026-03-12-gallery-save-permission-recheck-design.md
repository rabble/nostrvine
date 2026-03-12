# Gallery Save Permission Recheck Design

## Goal

Fix the gallery save/export flow so it does not report permission denied when the OS permission prompt was just accepted but the immediate request result is stale.

## Problem

`GallerySaveService._checkPermission()` currently:

1. Checks gallery status.
2. If status is `canRequest`, calls `requestGalleryPermission()`.
3. Trusts the direct return value from `requestGalleryPermission()`.

On iOS, the permission plugin can briefly report a non-granted result immediately after the user accepts the prompt. That makes the save flow incorrectly return `GallerySavePermissionDenied()` even though a follow-up status check would report `granted`.

## Scope

This change is limited to the save/export permission path in `mobile/lib/services/gallery_save_service.dart`.

It does not change:

- camera entry permission gating
- permission model types
- settings UX
- gallery save result types

## Design

Keep the existing save flow and permission abstraction. Change `_checkPermission()` so that when the initial status is `canRequest`, the service:

1. calls `requestGalleryPermission()`
2. if that direct result is `granted`, proceed as today
3. otherwise immediately calls `checkGalleryStatus()` again
4. proceeds if the follow-up status is `granted`
5. only returns `GallerySavePermissionDenied()` if the follow-up status is still non-granted

This keeps the logic local to the save flow, avoids retrying the entire save operation, and minimizes surface area.

## Testing

Add a regression test in `mobile/test/services/gallery_save_service_test.dart` that proves:

- the initial status is `canRequest`
- the request result is still non-granted
- the follow-up status check returns `granted`
- the service no longer returns `GallerySavePermissionDenied()`

Use a real temp file so the permission logic is exercised instead of failing early on a missing path.
