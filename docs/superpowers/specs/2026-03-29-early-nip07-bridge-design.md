Status: Approved

# Early NIP-07 Bridge

**Date:** 2026-03-29
**Status:** Approved
**Repo:** divine-mobile

## Problem

Vetted third-party Nostr apps launched inside Divine do not reliably see `window.nostr` during their initial bootstrap. The current sandbox injects the bridge only after `onPageFinished`, so apps like Ditto can render a manual login path even though Divine already has an authenticated user and already allows silent identity reads for vetted origins.

## Goals

- Make `window.nostr` available before vetted app JavaScript checks for NIP-07 on first render.
- Preserve the existing permission model: silent `getPublicKey` and `getRelays`, prompt-backed signing and `nip44.*`.
- Keep the fix platform-aware instead of depending on per-app shims.

## Non-Goals

- Adding per-app login automation or app-specific DOM hacks.
- Changing bridge grant semantics for signing requests.
- Refactoring the broader apps router or permission UI.

## Solution Summary

Keep the current bridge API and audit policy, but move bridge installation earlier in the sandbox lifecycle.

On Apple platforms, use the underlying WebKit controller to register a document-start `WKUserScript` that installs the Divine NIP-07 shim before the vetted app's own JavaScript runs.

On Android and other non-WebKit paths, bootstrap the initial allowed document through `loadHtmlString` with the app URL as the base URL. That lets Divine rewrite the initial HTML so the bridge script appears ahead of the app bundles even though the platform WebView package does not expose a public document-start hook for custom scripts.

The existing late `runJavaScript` path remains as a safety net for already-loaded pages and bridge responses, but first-load availability comes from the earlier platform-specific setup.

## Testing

- Add focused sandbox widget tests that prove the initial document path changes from direct `loadRequest` to early bridge installation.
- Verify Android uses HTML bootstrap loading for the initial document.
- Verify the existing bridge message path still emits responses correctly.
