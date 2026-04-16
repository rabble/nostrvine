# E2E Test Personas: Multi-Relay Local Stack

**Date:** 2026-03-26
**Status:** Draft
**Origin:** Oscar's proposal to catch profile-specific bugs (ref: PR #2463)

## Problem

The E2E test suite only exercises Divine-only users. Bugs that affect Nostr-native users — like the notifications API deriving its base URL from an arbitrary relay (PR #2463) — go undetected until manual testing or production reports surface them.

The local Docker stack has a single relay (FunnelCake), all seed data lives there, and `EnvironmentConfig.indexerRelays` for LOCAL points to FunnelCake. This doesn't reflect production, where users have relay lists spanning multiple relays and the app discovers them via dedicated indexers like purplepag.es.

## Solution

Add two relay_builder instances to the local stack (indexer + external relay), define two user persona types, seed data across all three relays, and write E2E tests that exercise both persona types as both logged-in users and browsed profiles.

## Architecture

### Relay Topology

| Container | Port | Image | Role |
|-----------|------|-------|------|
| funnelcake-relay | 47777 | funnelcake-relay | Divine relay (videos, notifications API, REST) |
| relay-indexer | 47778 | relay_builder | Stores kind 10002 + kind 0 (simulates purplepag.es) |
| relay-external | 47779 | relay_builder | Stores kind 0 + videos for Nostr-native users (simulates damus) |

FunnelCake rejects kind 10002 (`blocked: kind 10002 not in allowed list`) by design — it's a video-focused relay with a curated kind allowlist (migration 000015). This is correct and should not be changed.

### Pre-Implementation Verification

Before implementation, verify:
1. `ghcr.io/verse-pbc/relay_builder:latest` exists and is pullable
2. relay_builder's default listening port (check docs/code — assumed 7777)
3. relay_builder accepts arbitrary event kinds including 10002 and 34236 by default
4. relay_builder's Docker image supports bash or `/dev/tcp` for healthchecks (if Alpine/scratch, use `wget` or a WebSocket probe instead)

### Discovery Flow (matches production)

1. App queries **relay-indexer** (47778) for kind 10002 by pubkey
2. Kind 10002 event lists the user's write relays (FunnelCake, relay-external, or both)
3. App connects to those relays to fetch kind 0 profiles and content

### Environment Config Change

```dart
// LOCAL indexerRelays changes from:
return ['ws://$localHost:$localRelayPort'];        // FunnelCake (47777)
// to:
return ['ws://$localHost:$localIndexerRelayPort'];  // relay-indexer (47778)
```

New constants:
```dart
const localIndexerRelayPort = 47778;
const localExternalRelayPort = 47779;
```

## Persona Types

### Type A — Divine User

A user who registered via Divine. Their content lives on FunnelCake, but they have a relay list (kind 10002) that includes both relays, matching how the app configures relay lists for real Divine users.

| Event | Published to |
|-------|-------------|
| Kind 10002 (relay list) | relay-indexer |
| Kind 0 (profile) | FunnelCake + relay-indexer |
| Kind 34236 (videos) | FunnelCake only |

### Type B — Nostr-Native User

A user with an existing Nostr identity who joins Divine. Their profile originated on external relays. Some videos were published via other Nostr clients (on external relay), some via Divine (on FunnelCake).

| Event | Published to |
|-------|-------------|
| Kind 10002 (relay list) | relay-indexer |
| Kind 0 (profile) | relay-external + relay-indexer |
| Kind 34236 (videos) | ~half FunnelCake, ~half relay-external |

## Seed Data (seed.py)

### URL Translation: Docker-Internal vs Emulator-Accessible

The seed script runs inside Docker and connects to relays via internal hostnames (`ws://funnelcake-relay:7777`). But kind 10002 events contain relay URLs that the **app on the Android emulator** will use to connect. The emulator cannot resolve Docker-internal hostnames — it reaches the host via `10.0.2.2`.

This is the same pattern as the existing `BLOSSOM_PUBLIC_URL` (internal: `http://blossom:7676`, public: `http://10.0.2.2:43003`).

### New Environment Variables

```yaml
# Docker-internal URLs (for seed script to connect)
INDEXER_RELAY_URL: ws://relay-indexer:7777
EXTERNAL_RELAY_URL: ws://relay-external:7777

# Emulator-accessible URLs (for kind 10002 event content)
RELAY_PUBLIC_URL: ws://10.0.2.2:47777
EXTERNAL_RELAY_PUBLIC_URL: ws://10.0.2.2:47779
```

### New Capability: Kind 0 Profile Publishing

The current seed.py only publishes kind 34236 video events. It must be extended to also publish kind 0 (profile metadata) events for each author, routed to the appropriate relay(s) based on persona type.

### Author Distribution

- ~10 Type A authors (Divine users)
- ~10 Type B authors (Nostr-native users)
- Popular/regular split applied within each type (5 popular total, ~16 videos each)
- **Author 0 must be Type A** to keep the existing `check_already_seeded()` logic working (it queries FunnelCake for author 0's kind 34236 events)

The seed script opens three WebSocket connections and routes events to the appropriate relay(s) based on author type and event kind.

### Kind 10002 Event Format

Events use **emulator-accessible URLs**, not Docker-internal hostnames:

```json
{
  "kind": 10002,
  "tags": [
    ["r", "ws://10.0.2.2:47777"],
    ["r", "ws://10.0.2.2:47779"]
  ],
  "content": ""
}
```

Both type A and type B users list both relays in their kind 10002 to match realistic configurations. The difference is where their actual content lives.

## Dart Test Helpers

### New Constants (constants.dart)

```dart
const localIndexerRelayPort = 47778;
const localExternalRelayPort = 47779;
```

### Updated Core Function

The private `_publishEvent()` function in `relay_helpers.dart` is currently hardcoded to `ws://$localHost:$localRelayPort` (FunnelCake). It needs a `relayPort` parameter (defaulting to `localRelayPort`) so all publishing functions can target any relay.

### New Functions (relay_helpers.dart)

**`publishTestRelayListEvent()`** — publishes a kind 10002 event to the indexer relay with configurable `r` tags. Must use emulator-accessible URLs (`ws://$localHost:$localRelayPort`, `ws://$localHost:$localExternalRelayPort`) in the `r` tags.

**Extended `publishTestProfileEvent()`** — optional `relayPort` param to publish to either FunnelCake or external relay. Defaults to FunnelCake for backward compatibility.

**Extended `publishTestVideoEvent()`** — same `relayPort` extension.

### Persona Registration Wrappers

**`registerTypeAUser()`** — registers via Keycast, publishes kind 10002 to indexer listing both relays, publishes kind 0 to FunnelCake + indexer relay.

**`registerTypeBUser()`** — registers via Keycast, publishes kind 10002 to indexer listing both relays, publishes kind 0 to external relay + indexer relay, publishes some videos to external relay.

## E2E Test Cases

New file: `integration_test/e2e/persona_test.dart`

### Full Registration Tests (one per type)

- Register as type A, verify home feed loads with seeded content
- Register as type B, verify home feed loads (content from external relay)

### Browsing Tests (pre-seeded accounts)

- Logged in as type A, browse type B profile — verify metadata loads (kind 0 from external relay)
- Logged in as type A, browse type B profile — verify videos appear (mix of FunnelCake + external)
- Logged in as type B, browse type A profile — verify profile loads
- Logged in as type B, verify own profile displays correctly

### Regression Guard (PR #2463 bug class)

- Logged in as type B, seed a notification event (e.g., a kind 7 reaction from type A user targeting type B's content on FunnelCake), then verify notifications list shows **non-empty** results.

The key assertion is **non-empty notifications**, not just "no crash". The PR #2463 bug caused the notifications API to hit the wrong relay (which returns HTML, not JSON), resulting in silently empty notifications. A non-empty result proves the API hit FunnelCake correctly.

Note: `resolveApiBaseUrlFromRelays()` checks for `relay.divine.video` in production, which never matches in LOCAL env. The test should verify that the PR #2463 fix (fallback to `environmentConfig.apiBaseUrl`) works correctly for LOCAL env.

### Passive Coverage

Existing auth journey tests remain unchanged. The seeded explore feed now contains both user types, providing passive coverage without test changes.

## Docker Compose Changes

```yaml
relay-indexer:
  image: ghcr.io/verse-pbc/relay_builder:latest
  ports:
    - "47778:7777"
  healthcheck:
    # NOTE: verify relay_builder image supports this check.
    # If Alpine/scratch, use wget or a WebSocket probe instead.
    test: ["CMD-SHELL", "echo > /dev/tcp/localhost/7777"]
    interval: 3s
    timeout: 3s
    retries: 10

relay-external:
  image: ghcr.io/verse-pbc/relay_builder:latest
  ports:
    - "47779:7777"
  healthcheck:
    test: ["CMD-SHELL", "echo > /dev/tcp/localhost/7777"]
    interval: 3s
    timeout: 3s
    retries: 10
```

The `e2e-seed` container gains:
```yaml
depends_on:
  relay-indexer:
    condition: service_healthy
  relay-external:
    condition: service_healthy
environment:
  INDEXER_RELAY_URL: ws://relay-indexer:7777
  EXTERNAL_RELAY_URL: ws://relay-external:7777
  RELAY_PUBLIC_URL: ws://10.0.2.2:47777
  EXTERNAL_RELAY_PUBLIC_URL: ws://10.0.2.2:47779
```

Note: The existing `funnelcake-relay` dependency uses `condition: service_started` (not `service_healthy`) because seed.py has its own `wait_for_services()` polling. The new relays use `service_healthy` for consistency with other stack services, but seed.py's polling should also cover them as a safety net.

## Files Changed

| File | Change |
|------|--------|
| `local_stack/docker-compose.yml` | Add relay-indexer + relay-external containers, update e2e-seed deps/env |
| `local_stack/seed/seed.py` | Multi-relay seeding with kind 0 profiles, kind 10002 relay lists, type A/B author distribution |
| `mobile/lib/models/environment_config.dart` | New port constants, LOCAL indexerRelays points to relay-indexer |
| `mobile/integration_test/helpers/constants.dart` | New port constants |
| `mobile/integration_test/helpers/relay_helpers.dart` | Kind 10002 helper, relay-parameterized `_publishEvent()`, persona wrappers |
| `mobile/integration_test/e2e/persona_test.dart` | New test file with persona-specific E2E tests |

## Risks

- **relay_builder compatibility** — need to verify it accepts kind 34236 (video events) and kind 10002 without filtering. It should, since it's a general-purpose relay, but must be confirmed before implementation. Also verify default port and healthcheck support.
- **Seed script complexity** — three WebSocket connections, two URL namespaces (internal vs public), and routing logic. Mitigated by keeping the existing single-relay path as type A and adding type B on top. Author 0 stays type A to preserve `check_already_seeded()`.
- **Test flakiness** — external relay discovery adds network hops. Mitigated by generous timeouts and the polling pattern already used in E2E tests.
- **Dual indexer lists** — `RelayDiscoveryService.defaultIndexers` is a static fallback list that's overridden by `env.indexerRelays` via the provider. No code path bypasses the provider in production, but worth being aware of during implementation.
