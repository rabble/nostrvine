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

### New Environment Variables

```yaml
INDEXER_RELAY_URL: ws://relay-indexer:7777
EXTERNAL_RELAY_URL: ws://relay-external:7777
```

### Author Distribution

- ~10 Type A authors (Divine users)
- ~10 Type B authors (Nostr-native users)
- Popular/regular split applied within each type (5 popular total, ~16 videos each)

The seed script opens three WebSocket connections and routes events to the appropriate relay(s) based on author type and event kind.

### Kind 10002 Event Format

```json
{
  "kind": 10002,
  "tags": [
    ["r", "ws://funnelcake-relay:7777"],
    ["r", "ws://relay-external:7777"]
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

### New Functions (relay_helpers.dart)

**`publishTestRelayListEvent()`** — publishes a kind 10002 event to the indexer relay with configurable `r` tags.

**Extended `publishTestProfileEvent()`** — optional `relayPort` param to publish to either FunnelCake or external relay. Defaults to FunnelCake for backward compatibility.

**Extended `publishTestVideoEvent()`** — same `relayPort` extension.

### Persona Registration Wrappers

**`registerTypeAUser()`** — registers via Keycast, publishes kind 10002 to indexer listing both relays, publishes kind 0 to FunnelCake.

**`registerTypeBUser()`** — registers via Keycast, publishes kind 10002 to indexer listing both relays, publishes kind 0 to external relay, publishes some videos to external relay.

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

### Regression Guard

- Logged in as type B, verify notifications load (API should hit FunnelCake, not external relay — the PR #2463 bug class)

### Passive Coverage

Existing auth journey tests remain unchanged. The seeded explore feed now contains both user types, providing passive coverage without test changes.

## Docker Compose Changes

```yaml
relay-indexer:
  image: ghcr.io/verse-pbc/relay_builder:latest
  ports:
    - "47778:7777"
  healthcheck:
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
```

## Files Changed

| File | Change |
|------|--------|
| `local_stack/docker-compose.yml` | Add relay-indexer + relay-external containers, update e2e-seed deps/env |
| `local_stack/seed/seed.py` | Multi-relay seeding with type A/B author distribution |
| `mobile/lib/models/environment_config.dart` | New port constants, LOCAL indexerRelays points to relay-indexer |
| `mobile/integration_test/helpers/constants.dart` | New port constants |
| `mobile/integration_test/helpers/relay_helpers.dart` | Kind 10002 helper, relay-parameterized publishing, persona wrappers |
| `mobile/integration_test/e2e/persona_test.dart` | New test file with persona-specific E2E tests |

## Risks

- **relay_builder compatibility** — need to verify it accepts kind 34236 (video events) without issues. It should, since it's a general-purpose relay with no kind filtering.
- **Seed script complexity** — three WebSocket connections and routing logic. Mitigated by keeping the existing single-relay path as type A and adding type B on top.
- **Test flakiness** — external relay discovery adds network hops. Mitigated by generous timeouts and the polling pattern already used in E2E tests.
