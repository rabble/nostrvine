# Divine Live Server Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a dedicated Rust/Axum service in `../divine-live-server` on `live.api.divine.video` that verifies NIP-98 auth, persists live room/session state, mints LiveKit Cloud tokens, and handles replay webhooks for the mobile live feature.

**Architecture:** Create a standalone live control-plane service with a small Axum router, Postgres persistence through `sqlx`, a NIP-98 verifier for caller identity, a LiveKit Cloud integration layer for token minting and webhook verification, and route handlers that keep Nostr as the public source of truth while enforcing server-authoritative media permissions.

**Tech Stack:** Rust, Axum, Tokio, SQLx + Postgres, Serde, Chrono or Time, JsonWebToken signing, HMAC/SHA256, Tracing, Tower HTTP, and `axum-test` or `tower::ServiceExt` for route tests.

---

## Scope Split

This plan covers only the new backend repo `../divine-live-server`.

Do not mix in:

- mobile `LIVE_API_URL` client wiring
- mobile host promote/demote follow-up calls
- any `divine-funnelcake` changes

Those are separate implementation plans once the server contract exists.

## File Structure

Target repo root: `/Users/rabble/code/divine/divine-live-server`

Planned layout:

- `Cargo.toml`
  - crate manifest and dependency list
- `.gitignore`
  - Rust, env, and local db artifacts
- `.env.example`
  - required runtime variables
- `README.md`
  - local dev and endpoint overview
- `src/lib.rs`
  - top-level module exports
- `src/main.rs`
  - binary entrypoint and server boot
- `src/app.rs`
  - Axum router assembly
- `src/config.rs`
  - env parsing and typed config
- `src/error.rs`
  - app error type and JSON error responses
- `src/state.rs`
  - shared app state wiring
- `src/auth/mod.rs`
  - auth module exports
- `src/auth/nip98.rs`
  - NIP-98 verification and caller extraction
- `src/db/mod.rs`
  - pool creation and DB helpers
- `src/db/models.rs`
  - database-facing structs
- `src/repos/host_allowlist.rs`
  - host allowlist queries
- `src/repos/live_rooms.rs`
  - room draft persistence
- `src/repos/live_sessions.rs`
  - session lifecycle persistence
- `src/repos/live_roles.rs`
  - speaker-role grant persistence
- `src/livekit/mod.rs`
  - LiveKit integration exports
- `src/livekit/tokens.rs`
  - role-based token minting
- `src/livekit/webhooks.rs`
  - webhook signature verification and parsing
- `src/routes/health.rs`
  - `/health`
- `src/routes/live_rooms.rs`
  - room draft, session start/end, join, role grants, replay lookup
- `src/routes/live_webhooks.rs`
  - LiveKit webhook endpoint
- `migrations/0001_init.sql`
  - initial schema
- `tests/health_routes.rs`
  - app smoke test
- `tests/nip98_auth.rs`
  - NIP-98 verification coverage
- `tests/live_rooms_routes.rs`
  - room draft, start, end coverage
- `tests/live_join_routes.rs`
  - join and role grant coverage
- `tests/live_webhooks.rs`
  - replay webhook coverage

## Chunk 1: Service Foundation

### Task 1: Scaffold The New Repo

**Files:**
- Create: `../divine-live-server/Cargo.toml`
- Create: `../divine-live-server/.gitignore`
- Create: `../divine-live-server/.env.example`
- Create: `../divine-live-server/README.md`
- Create: `../divine-live-server/src/lib.rs`
- Create: `../divine-live-server/src/main.rs`
- Create: `../divine-live-server/src/app.rs`
- Create: `../divine-live-server/src/routes/health.rs`
- Test: `../divine-live-server/tests/health_routes.rs`

- [ ] **Step 1: Write the failing health-route test**

Create `tests/health_routes.rs` with a single smoke test that builds the app and expects:

- `GET /health`
- status `200 OK`
- JSON body containing `{"status":"ok"}`

- [ ] **Step 2: Run the health test to verify it fails**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test health_routes -- --nocapture
```

Expected: fail because the repo and app modules do not exist yet.

- [ ] **Step 3: Create the repo skeleton and minimal app**

Create the new crate, add Axum/Tokio/Serde/Tracing dependencies, and implement:

- `main.rs` booting an Axum server
- `app.rs` returning a router
- `routes/health.rs` returning `200` with a minimal JSON payload

- [ ] **Step 4: Run the health test to verify it passes**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test health_routes -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit the scaffold**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add .
git commit -m "chore(live): scaffold divine live server"
```

### Task 2: Add Typed Config, Shared State, And Error Responses

**Files:**
- Create: `../divine-live-server/src/config.rs`
- Create: `../divine-live-server/src/error.rs`
- Create: `../divine-live-server/src/state.rs`
- Modify: `../divine-live-server/src/app.rs`
- Modify: `../divine-live-server/src/main.rs`
- Test: `../divine-live-server/tests/health_routes.rs`

- [ ] **Step 1: Extend the failing health test to cover config-backed app state**

Add assertions that the app can be constructed from a config object and that health output includes environment-safe metadata such as service name and version without exposing secrets.

- [ ] **Step 2: Run the test to verify it fails**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test health_routes -- --nocapture
```

Expected: fail because config/state/error wiring does not exist.

- [ ] **Step 3: Implement config, state, and JSON error primitives**

Add:

- typed config loader for `LIVE_SERVER_PUBLIC_URL`, `DATABASE_URL`, `LIVEKIT_URL`, `LIVEKIT_API_KEY`, `LIVEKIT_API_SECRET`, and `LIVEKIT_WEBHOOK_SECRET`
- app state wrapper with config and placeholder db/livekit handles
- JSON error response type with stable `error` and `message` fields

- [ ] **Step 4: Re-run the health test**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test health_routes -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add src/config.rs src/error.rs src/state.rs src/app.rs src/main.rs tests/health_routes.rs .env.example README.md
git commit -m "feat(live): add config and app state foundation"
```

### Task 3: Implement NIP-98 Verification

**Files:**
- Create: `../divine-live-server/src/auth/mod.rs`
- Create: `../divine-live-server/src/auth/nip98.rs`
- Modify: `../divine-live-server/src/app.rs`
- Test: `../divine-live-server/tests/nip98_auth.rs`

- [ ] **Step 1: Write failing NIP-98 tests**

Cover these cases in `tests/nip98_auth.rs`:

- valid `Authorization: Nostr ...` header is accepted
- stale auth event is rejected
- wrong `u` tag URL is rejected
- wrong method tag is rejected
- wrong payload hash is rejected
- malformed base64 payload is rejected

- [ ] **Step 2: Run the NIP-98 tests to verify they fail**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test nip98_auth -- --nocapture
```

Expected: fail because no verifier exists.

- [ ] **Step 3: Implement the verifier**

Use existing Divine patterns as references:

- `mobile/lib/services/nip98_auth_service.dart`
- `divine-funnelcake/crates/api/src/management.rs`
- `divine-upload-server/src/main.rs`

Implement:

- header parsing
- base64 decode
- Nostr auth event decode
- event kind and timestamp checks
- exact URL and method validation
- optional payload hash validation
- signature validation
- extracted caller pubkey result

- [ ] **Step 4: Re-run the NIP-98 tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test nip98_auth -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add src/auth src/app.rs tests/nip98_auth.rs
git commit -m "feat(live): add NIP-98 request verification"
```

### Task 4: Add Postgres Schema And Repository Layer

**Files:**
- Create: `../divine-live-server/migrations/0001_init.sql`
- Create: `../divine-live-server/src/db/mod.rs`
- Create: `../divine-live-server/src/db/models.rs`
- Create: `../divine-live-server/src/repos/host_allowlist.rs`
- Create: `../divine-live-server/src/repos/live_rooms.rs`
- Create: `../divine-live-server/src/repos/live_sessions.rs`
- Create: `../divine-live-server/src/repos/live_roles.rs`
- Modify: `../divine-live-server/src/state.rs`
- Test: `../divine-live-server/tests/live_rooms_routes.rs`

- [ ] **Step 1: Write failing repository tests**

Add coverage for:

- host allowlist lookup
- room draft insert and fetch
- session insert and active-session lookup
- speaker role grant upsert and revoke

Prefer `#[sqlx::test]` or the repo’s chosen isolated Postgres test harness.

- [ ] **Step 2: Run the repository tests to verify they fail**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test live_rooms_repo -- --nocapture
```

Expected: fail because no schema or repos exist.

- [ ] **Step 3: Implement the initial schema and repos**

Create durable tables for:

- `host_allowlist`
- `live_rooms`
- `live_sessions`
- `live_room_roles`

Wire a `sqlx::PgPool` into shared state and implement focused query methods instead of route-layer SQL.

- [ ] **Step 4: Re-run the repository tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test live_rooms_repo -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add migrations src/db src/repos src/state.rs tests/live_rooms_routes.rs
git commit -m "feat(live): add live persistence layer"
```

## Chunk 2: Live Lifecycle And LiveKit Integration

### Task 5: Implement Room Draft, Session Start, And Session End Routes

**Files:**
- Create: `../divine-live-server/src/routes/live_rooms.rs`
- Modify: `../divine-live-server/src/app.rs`
- Test: `../divine-live-server/tests/live_rooms_routes.rs`

- [ ] **Step 1: Write failing route tests**

Cover:

- allowlisted host can create room draft
- non-allowlisted signer gets `403`
- room host can start session
- second active session attempt gets `409`
- room host can end session
- stranger cannot end session

- [ ] **Step 2: Run the live room route tests to verify they fail**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_rooms_routes -- --nocapture
```

Expected: fail because the routes do not exist.

- [ ] **Step 3: Implement the room and session lifecycle handlers**

Use the NIP-98 verifier for caller identity and the repo layer for persistence. Keep handlers thin:

- parse request
- verify caller
- authorize caller
- call repo methods
- return JSON

- [ ] **Step 4: Re-run the route tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_rooms_routes -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add src/routes/live_rooms.rs src/app.rs tests/live_rooms_routes.rs
git commit -m "feat(live): add room and session lifecycle routes"
```

### Task 6: Add LiveKit Token Minting And Join Authorization

**Files:**
- Create: `../divine-live-server/src/livekit/mod.rs`
- Create: `../divine-live-server/src/livekit/tokens.rs`
- Modify: `../divine-live-server/src/routes/live_rooms.rs`
- Test: `../divine-live-server/tests/live_join_routes.rs`

- [ ] **Step 1: Write failing join-route tests**

Cover:

- any valid signer can join a public active room as audience
- host gets a publish-capable token
- unauthorized host request gets `403`
- unauthorized speaker request gets `403`
- granted speaker gets a publish-capable token
- inactive room join gets `409`

- [ ] **Step 2: Run the join-route tests to verify they fail**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_join_routes -- --nocapture
```

Expected: fail because token minting and join authorization are missing.

- [ ] **Step 3: Implement the LiveKit token service**

Add a focused wrapper that:

- reads LiveKit URL/key/secret from config
- mints role-specific tokens
- returns `token`, `roomName`, `participantIdentity`, `serverUrl`, `canPublish`, and `expiresAt`

Implement join authorization against:

- active session state
- room host ownership
- `live_room_roles` for speakers

- [ ] **Step 4: Re-run the join-route tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_join_routes -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add src/livekit src/routes/live_rooms.rs tests/live_join_routes.rs
git commit -m "feat(live): add role-based LiveKit join tokens"
```

### Task 7: Add Speaker Role Grant Route

**Files:**
- Modify: `../divine-live-server/src/routes/live_rooms.rs`
- Modify: `../divine-live-server/src/repos/live_roles.rs`
- Test: `../divine-live-server/tests/live_join_routes.rs`

- [ ] **Step 1: Extend the join-route test suite with role-grant failures first**

Cover:

- host can grant `speaker`
- host can demote back to `audience`
- stranger cannot change another participant's role
- host cannot grant unsupported roles

- [ ] **Step 2: Run the role-grant tests to verify they fail**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_join_routes role_grant -- --nocapture
```

Expected: fail because the route and repo method do not exist.

- [ ] **Step 3: Implement the role-grant route**

Add `PUT /v1/live/rooms/:roomId/participants/:pubkey/role` with:

- NIP-98 auth
- host-only authorization
- `speaker` and `audience` only
- upsert or revoke semantics in `live_room_roles`

- [ ] **Step 4: Re-run the role-grant tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_join_routes role_grant -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add src/routes/live_rooms.rs src/repos/live_roles.rs tests/live_join_routes.rs
git commit -m "feat(live): add speaker role grant route"
```

### Task 8: Add Replay Lookup And LiveKit Webhook Handling

**Files:**
- Create: `../divine-live-server/src/livekit/webhooks.rs`
- Create: `../divine-live-server/src/routes/live_webhooks.rs`
- Modify: `../divine-live-server/src/routes/live_rooms.rs`
- Modify: `../divine-live-server/src/app.rs`
- Modify: `../divine-live-server/src/repos/live_sessions.rs`
- Test: `../divine-live-server/tests/live_webhooks.rs`

- [ ] **Step 1: Write failing webhook and replay tests**

Cover:

- invalid webhook signature gets rejected
- valid replay-ready webhook updates session recording state
- `GET /v1/live/rooms/:roomId/recording` returns `404` or `204` when missing
- replay-ready session returns `200` with `status` and `playbackUrl`

- [ ] **Step 2: Run the webhook tests to verify they fail**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_webhooks -- --nocapture
```

Expected: fail because webhook verification and replay lookup are missing.

- [ ] **Step 3: Implement webhook verification and replay persistence**

Implement:

- HMAC or the official LiveKit webhook verification flow
- parsing for the initial room/session and recording-ready events needed by the spec
- persistence of `recording_status` and `recording_playback_url`
- public replay lookup route

- [ ] **Step 4: Re-run the webhook tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test live_webhooks -- --nocapture
```

Expected: pass.

- [ ] **Step 5: Commit**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add src/livekit/webhooks.rs src/routes/live_webhooks.rs src/routes/live_rooms.rs src/app.rs src/repos/live_sessions.rs tests/live_webhooks.rs
git commit -m "feat(live): add replay webhook handling"
```

### Task 9: Add Final Service Hardening And Developer Docs

**Files:**
- Modify: `../divine-live-server/README.md`
- Modify: `../divine-live-server/.env.example`
- Modify: `../divine-live-server/src/routes/health.rs`
- Test: `../divine-live-server/tests/health_routes.rs`

- [ ] **Step 1: Extend the health and smoke docs expectations**

Document:

- required env vars
- local Postgres boot requirements
- local run command
- example NIP-98 curl flow for create room and join

Update the health test if the response shape changes.

- [ ] **Step 2: Run the focused smoke tests**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo test --test health_routes -- --nocapture
cargo test --test live_rooms_routes -- --nocapture
cargo test --test live_join_routes -- --nocapture
cargo test --test live_webhooks -- --nocapture
```

Expected: all pass.

- [ ] **Step 3: Run the full verification set**

Run:

```bash
cd /Users/rabble/code/divine/divine-live-server
cargo fmt --all --check
cargo clippy --all-targets --all-features -- -D warnings
cargo test --all-targets
```

Expected:

- `cargo fmt` clean
- `clippy` clean
- full test suite green

- [ ] **Step 4: Commit the hardening pass**

```bash
cd /Users/rabble/code/divine/divine-live-server
git add README.md .env.example src/routes/health.rs tests/health_routes.rs
git commit -m "docs(live): document divine live server setup"
```

## Execution Notes

- Use Rust/Axum patterns already present in `divine-upload-server` and `divine-funnelcake` instead of inventing a new framework
- Prefer copying proven NIP-98 verification behavior from existing Divine services over writing a bespoke variant from scratch
- Keep route handlers small; push persistence and LiveKit concerns into focused modules
- Do not leak LiveKit secrets or raw auth headers in logs
- Keep the service contract aligned with `docs/superpowers/specs/2026-04-08-divine-live-server-design.md`

## Out Of Scope For This Plan

- mobile `LIVE_API_URL` wiring
- mobile host role-grant API calls
- `divine-funnelcake` relay changes
- self-hosted LiveKit

