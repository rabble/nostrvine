# Provider-Backed Sound Library Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the first provider-backed sound library slice: new `divine-sound-proxy` service, `divine-router` path split, and mobile model/client support for normalized provider sound metadata.

**Architecture:** Mobile calls `https://api.divine.video/api/sounds/*`. `divine-router` routes that prefix to `divine-sound-proxy`; all other API paths keep going to Funnelcake. The sound proxy exposes provider discovery and normalized sound search, with external providers disabled until credentials/terms are configured.

**Tech Stack:** Fastly Compute Rust, Flutter/Dart, `http`, existing `models` package, existing Riverpod provider patterns.

---

### Task 1: Scaffold `divine-sound-proxy`

**Files:**
- Create repo: `/Users/rabble/code/divine/divine-sound-proxy`
- Create: `Cargo.toml`
- Create: `fastly.toml`
- Create: `src/main.rs`
- Create: `src/lib.rs`
- Create: `README.md`

- [ ] **Step 1: Write failing Rust tests for provider config and disabled providers**

Add tests in `src/lib.rs` covering:

```rust
assert_eq!(Provider::parse("divine"), Some(Provider::Divine));
assert_eq!(Provider::parse("freesound"), Some(Provider::Freesound));
assert!(SearchParams::parse("/api/sounds/search?q=snare&page_size=500").is_ok());
assert_eq!(normalize_page_size(Some("500")), 50);
assert!(provider_enabled(Provider::Freesound, &ProviderFlags::default()) == false);
```

- [ ] **Step 2: Run red test**

Run: `cargo test`

Expected: fails because the repo/types do not exist yet.

- [ ] **Step 3: Implement minimal service library**

Implement `Provider`, `ProviderFlags`, `SearchParams`, license normalization, JSON response structs, and provider-disabled responses. External providers return `provider_disabled` until enabled. `divine` and `nostr` return empty normalized result lists in this first slice.

- [ ] **Step 4: Run green test**

Run: `cargo test`

Expected: all proxy unit tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add Cargo.toml fastly.toml src/main.rs src/lib.rs README.md
git commit -m "feat: scaffold sound proxy"
```

### Task 2: Route `/api/sounds/*` in `divine-router`

**Files:**
- Modify: `/Users/rabble/code/divine/divine-router/.worktrees/sound-library-route/src/main.rs`
- Modify: `/Users/rabble/code/divine/divine-router/.worktrees/sound-library-route/fastly.toml`

- [ ] **Step 1: Write failing router tests**

Add tests proving:

```rust
assert_eq!(backend_for_system_request("api", "/api/sounds/search"), SOUND_PROXY_BACKEND);
assert_eq!(backend_for_system_request("api", "/api/search"), FUNNELCAKE_API_BACKEND);
```

- [ ] **Step 2: Run red test**

Run: `cargo test`

Expected: fails because `SOUND_PROXY_BACKEND` and `backend_for_system_request` do not exist.

- [ ] **Step 3: Implement router branch**

Add `SOUND_PROXY_BACKEND`, host header mapping, Fastly backend entries, and a helper that routes `api.divine.video/api/sounds/*` to the sound proxy while preserving existing Funnelcake routing for other API paths.

- [ ] **Step 4: Run green test**

Run: `cargo test`

Expected: all router tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add src/main.rs fastly.toml
git commit -m "feat: route sound library api"
```

### Task 3: Add mobile sound metadata models

**Files:**
- Modify: `mobile/packages/models/lib/src/audio_event.dart`
- Test: `mobile/packages/models/test/src/audio_event_test.dart`

- [ ] **Step 1: Write failing model tests**

Add tests proving `AudioEvent.fromJson` and `toJson` preserve provider, provider ID, source URL, and normalized license metadata.

- [ ] **Step 2: Run red test**

Run: `cd mobile/packages/models && dart test test/src/audio_event_test.dart`

Expected: fails because external source fields do not exist.

- [ ] **Step 3: Implement minimal model fields**

Add `AudioExternalSource` and `AudioLicenseMetadata` value types plus optional `externalSource` on `AudioEvent`. Include JSON serialization, `copyWith`, and equality-sensitive fields only if needed for existing behavior.

- [ ] **Step 4: Run green test**

Run: `cd mobile/packages/models && dart test test/src/audio_event_test.dart`

Expected: all model tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add mobile/packages/models/lib/src/audio_event.dart mobile/packages/models/test/src/audio_event_test.dart
git commit -m "feat(models): preserve external sound attribution"
```

### Task 4: Add mobile sound library client

**Files:**
- Create: `mobile/lib/services/sound_library_api_client.dart`
- Create: `mobile/test/services/sound_library_api_client_test.dart`

- [ ] **Step 1: Write failing client tests**

Add tests for:

```dart
// Maps normalized /api/sounds/search JSON into AudioEvent.
// Sends provider, query, page, page_size, and license_type query parameters.
// Throws a stable exception on provider_disabled or rate_limited.
```

- [ ] **Step 2: Run red test**

Run: `cd mobile && flutter test test/services/sound_library_api_client_test.dart`

Expected: fails because the client does not exist.

- [ ] **Step 3: Implement minimal client**

Use package `http`, inject `http.Client` and base URI, and map normalized API JSON into `AudioEvent.externalSource`.

- [ ] **Step 4: Run green test**

Run: `cd mobile && flutter test test/services/sound_library_api_client_test.dart`

Expected: all client tests pass.

- [ ] **Step 5: Commit**

Run:

```bash
git add mobile/lib/services/sound_library_api_client.dart mobile/test/services/sound_library_api_client_test.dart
git commit -m "feat(audio): add sound library api client"
```

### Task 5: Final verification

- [ ] **Step 1: Run focused tests**

Run:

```bash
(cd /Users/rabble/code/divine/divine-sound-proxy && cargo test)
(cd /Users/rabble/code/divine/divine-router/.worktrees/sound-library-route && cargo test)
(cd /Users/rabble/code/divine/divine-mobile/.worktrees/freesound-audio-hook/mobile/packages/models && dart test test/src/audio_event_test.dart)
(cd /Users/rabble/code/divine/divine-mobile/.worktrees/freesound-audio-hook/mobile && flutter test test/services/sound_library_api_client_test.dart)
```

- [ ] **Step 2: Check workspace state**

Run:

```bash
git status --short
```

Expected: each worktree is clean except intentional branch-ahead commits.
