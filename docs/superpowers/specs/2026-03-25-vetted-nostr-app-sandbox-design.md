Status: Approved

# Vetted Nostr App Sandbox And Directory

**Date:** 2026-03-25
**Status:** Approved
**Repo:** divine-mobile

## Problem

Divine already supports third-party signing through Amber, manual `bunker://` URLs, and `nostrconnect://` QR flows, but those paths still force users through signer-specific setup and, in the bunker case, copy/paste of a magic string. That is workable for power users and unacceptable for a curated app-store-style experience.

We want a Divine-controlled sandbox where vetted third-party Nostr apps can run on their own domains, receive a `window.nostr` bridge inside Divine, and use the user's signer without adding bespoke Divine login support. At the same time, Divine must keep the actual signer authority native, block navigation outside approved origins, remember user grants, and retain the ability to track requested signing activity without leaking message contents or keys.

## Goals

- Replace bunker copy/paste for approved partner apps with an in-app sandbox.
- Keep third-party apps on their own domains instead of requiring them to host on Divine.
- Inject `window.nostr` only for allowlisted origins inside Divine.
- Gate methods and event kinds per vetted app manifest.
- Persist user approvals per app/origin/capability until revoked.
- Track bridge usage and signing decisions in a sanitized audit trail.
- Use Cloudflare as source of truth for the app directory and admin workflow.

## Non-Goals

- Universal `window.nostr` injection for arbitrary websites.
- Exporting private keys or handing raw signer secrets to page JavaScript.
- Supporting the full browser-extension ecosystem in v1.
- Replacing existing bunker / `login.divine.video` flows for non-vetted apps.
- Allowing off-origin navigation while keeping bridge access alive.

## Solution Summary

Build two tightly related pieces:

1. A Cloudflare-backed app directory and admin system.
2. A Divine mobile sandbox runtime that consumes approved manifests and injects a narrow `window.nostr` bridge into vetted apps.

Cloudflare is the source of truth from day one. The mobile app does not ship a hardcoded list beyond local fallback cache behavior. Vetted apps stay on third-party domains, but only exact allowlisted origins get bridge access, and only inside Divine's sandbox browser.

## Proposed Repo Layout

The existing `website/` directory is a legacy static site and should not become the home for admin/API code by accretion. New Cloudflare work should be isolated:

- `website/apps-directory-worker/`
  Cloudflare Worker API, D1 schema, manifest validation, audit ingestion, public directory endpoints.
- `website/apps-admin/`
  Cloudflare-hosted admin console for managing app manifests and reviewing audit activity.
- `mobile/lib/models/nostr_app_directory_entry.dart`
  Typed mobile model for approved app manifests.
- `mobile/lib/services/nostr_app_directory_service.dart`
  Fetch/cache/revocation handling for directory manifests.
- `mobile/lib/services/nostr_app_sandbox_*`
  Policy, bridge dispatch, grant storage, audit logging.
- `mobile/lib/screens/apps/`
  Directory, detail, sandbox browser, and permission surfaces.

## Cloudflare Directory System

### Admin domain

- Admin UI host: `https://apps.admin.divine.video`
- Public directory API host: `https://apps.divine.video`

The domains may be served by the same Worker deployment behind different routes, but the trust model is cleaner if the public directory and admin UI remain logically separate.

### Source of truth

Cloudflare Worker + D1 is the canonical manifest store.

Each app record stores:

- `id`
- `slug`
- `name`
- `tagline`
- `description`
- `icon_url`
- `launch_url`
- `allowed_origins[]`
- `allowed_methods[]`
- `allowed_sign_event_kinds[]`
- `prompt_required_for[]`
- `status` (`draft`, `approved`, `revoked`)
- `sort_order`
- `created_at`
- `updated_at`
- `manifest_json`

The worker publishes a sanitized approved-only directory snapshot for mobile consumption.

### Suggested D1 tables

`sandbox_apps`
- metadata columns plus canonical manifest JSON

`sandbox_audit_events`
- `id`
- `app_id`
- `origin`
- `user_pubkey`
- `method`
- `event_kind`
- `decision` (`allowed`, `denied`, `prompt_allowed`, `prompt_denied`, `blocked`)
- `error_code`
- `created_at`

### Public API

- `GET /v1/apps`
  returns approved apps for the mobile directory
- `GET /v1/apps/:slug`
  returns a single approved manifest

### Admin API

- `GET /v1/admin/apps`
- `POST /v1/admin/apps`
- `PUT /v1/admin/apps/:id`
- `POST /v1/admin/apps/:id/approve`
- `POST /v1/admin/apps/:id/revoke`
- `GET /v1/admin/audit-events`

### Admin auth

Use Cloudflare Access for human admin access. The admin UI and write endpoints are protected by Access, and the worker trusts Access-authenticated identity headers for operator actions. This avoids inventing a separate admin login flow inside this project.

### Mobile audit auth

Use existing NIP-98 signing from Divine mobile for audit ingestion. Audit upload requests are signed by the currently active Divine signer, so the worker can bind audit events to the authenticated Nostr user without adding another client credential system.

### Audit privacy rule

The audit stream records request metadata only. It must never persist:

- private keys
- bunker secrets
- decrypted plaintext
- encrypted message contents
- raw event content bodies unless explicitly justified later

For `signEvent`, v1 records event kind and app/origin/decision only.

## Mobile App Directory

### Entry point

Add an `Apps` entry under Settings for v1. This keeps the information architecture contained while the sandbox matures.

### Directory behavior

- Fetch approved manifests from `apps.divine.video`
- Cache the last successful directory snapshot locally
- Render app list, app detail, and launch action from manifest data
- If network fetch fails, show cached apps only
- If an app is revoked on refresh, remove launch access immediately

### Manifest caching

- Use a local cache for the public directory snapshot
- Cache is keyed by manifest `updated_at` / ETag semantics where available
- Stale cache is acceptable for browse-only fallback, but revoked apps must be disabled on next successful refresh

## Mobile Sandbox Browser

### Boundary

The sandbox is a dedicated in-app browser screen, not a general-purpose WebView used across the app.

### Core rules

- Only exact allowlisted origins for the selected app may load with bridge access
- Off-origin navigation is blocked, not externalized
- Bridge injection happens only after the top-level origin is verified
- The bridge is never injected into arbitrary URLs or generic external browsing
- Unvetted apps continue using `login.divine.video` / bunker outside this sandbox

### Platform scope

V1 targets Android and iOS first. Unsupported platforms can show a disabled state rather than a partial implementation.

## `window.nostr` Bridge Contract

### V1 methods

Expose a narrow surface:

- `getPublicKey`
- `signEvent`
- `nip44.encrypt`
- `nip44.decrypt`

Everything else returns a deterministic unsupported-method error.

### Dispatch model

- JavaScript shim forwards calls to native via WebView JavaScript channels
- Native validates app manifest + current origin + persisted grant + runtime prompt requirement
- Native uses existing Divine signer infrastructure to execute allowed operations
- JavaScript receives a structured success or error response

### `signEvent` policy

`signEvent` is checked against:

- app-level method allowlist
- event-kind allowlist declared in manifest
- runtime prompt requirement if configured for the app/kind

An approved app for basic posting should not be able to sign arbitrary event kinds.

## Permissions And Grants

### Model

Persist grants per:

- `user_pubkey`
- `app_id`
- `origin`
- `capability`

### Prompting

Use a hybrid model:

- low-risk methods may auto-allow if the manifest permits them
- privileged methods prompt at runtime
- approved grants are remembered until revoked

### User control

Add a settings surface for:

- viewing granted apps
- revoking stored permissions
- clearing cached sandbox data

## Audit Model

### Local

Divine keeps a local audit history for recent sandbox actions and upload retry queue state.

### Remote

Divine uploads sanitized audit events to the directory worker using NIP-98 auth.

Events include:

- app id
- origin
- method
- event kind if relevant
- decision
- timestamp
- error code if any

## Security Model

- Native signer remains the authority; page JavaScript never receives keys.
- Bridge injection is origin-gated and app-scoped.
- Off-origin navigation is blocked.
- Revoked manifests disable bridge access after refresh.
- Unsupported methods fail closed.
- Audit payloads never include message plaintext or ciphertext.
- The generic bunker / `login.divine.video` path remains available outside the sandbox for non-vetted apps.

## Failure Handling

### Directory unavailable

- Show cached approved apps
- Disable apps that have never been cached successfully

### Manifest revoked

- Remove or disable launch access on next directory refresh
- Drop bridge access for the revoked app immediately once the new manifest is loaded

### Incompatible partner app

- Return predictable bridge errors
- Keep the failure scoped to that app
- Use audit data to identify which unsupported method or kind caused the break

### Unsupported platform

- Show a clear unavailable state instead of a broken browser

## Rollout

### Phase 1

- Cloudflare worker API and D1 schema
- Admin console
- Mobile directory list/detail UI
- Sandbox browser
- V1 bridge methods
- Grants and audit plumbing

### Phase 2

- Better grant management UI
- Expanded compatibility methods only when justified by partner app demand
- Stronger per-app sandbox isolation if needed

## Testing Strategy

- Worker unit tests for manifest validation, status filtering, admin auth gates, and audit ingestion
- Admin UI tests for CRUD and revoke flows
- Mobile service tests for directory cache, policy decisions, grants, and audit upload
- Mobile widget tests for directory UI and permission prompts
- Mobile integration tests for origin allowlist enforcement and bridge injection lifecycle

## Open Questions Deferred On Purpose

These are intentionally deferred from v1 implementation details:

- the exact default prompt matrix per method/kind
- whether more NIP-07-compatible methods are required after first partner trials
- whether audit visibility should remain internal-only or also surface user-facing history beyond basic settings

They should not block the first end-to-end slice.
