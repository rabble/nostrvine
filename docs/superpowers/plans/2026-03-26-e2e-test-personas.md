# E2E Test Personas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add multi-relay local stack and user persona types so E2E tests catch bugs specific to Nostr-native users.

**Architecture:** Two relay_builder containers (indexer + external) join the existing FunnelCake relay. Seed script publishes type A (Divine) and type B (Nostr-native) user data across all three relays. Dart test helpers gain relay-parameterized publishing and persona registration wrappers. New E2E tests exercise both persona types.

**Tech Stack:** Docker Compose, Python (seed.py), Dart/Flutter (integration_test), relay_builder (verse-pbc), WebSocket (NIP-01), Nostr kinds 0/10002/34236

**Spec:** `docs/superpowers/specs/2026-03-26-e2e-test-personas-design.md`

---

### Task 0: Verify relay_builder image

**Files:** None (investigation only)

- [ ] **Step 1: Pull the relay_builder image**

```bash
docker pull ghcr.io/verse-pbc/relay_builder:latest
```

Expected: Image pulls successfully. If not, check https://github.com/verse-pbc/relay_builder/pkgs/container/relay_builder for available tags.

- [ ] **Step 2: Verify default port and shell support**

```bash
# Start a temporary container
docker run --rm -d --name rb-test ghcr.io/verse-pbc/relay_builder:latest
# Check what port it listens on
docker logs rb-test 2>&1 | head -20
# Check if bash or /dev/tcp is available for healthchecks
docker exec rb-test sh -c 'echo > /dev/tcp/localhost/7777' 2>&1 || echo "no /dev/tcp"
docker exec rb-test which wget curl 2>&1
docker stop rb-test
```

Record: (a) listening port, (b) healthcheck method that works. Update the plan if port is not 7777 or if healthcheck needs a different approach.

- [ ] **Step 3: Verify kind acceptance**

```bash
# Start relay_builder on a temp port
docker run --rm -d -p 48888:7777 --name rb-test ghcr.io/verse-pbc/relay_builder:latest
# Publish kind 10002
nak event --sec $(nak key generate) -k 10002 -t r="wss://test.example.com" -c '' ws://localhost:48888
# Publish kind 34236
nak event --sec $(nak key generate) -k 34236 -t d=test -t title="test video" -c '' ws://localhost:48888
# Publish kind 0
nak event --sec $(nak key generate) -k 0 -c '{"name":"test"}' ws://localhost:48888
docker stop rb-test
```

Expected: All three events accepted (no "blocked" or "rejected" messages). If kind 34236 requires specific tags, adjust.

- [ ] **Step 4: Document findings**

Update spec pre-implementation section with actual port, healthcheck command, and any quirks discovered. Proceed only if all three kinds are accepted.

---

### Task 1: Add relay containers to Docker Compose

**Files:**
- Modify: `local_stack/docker-compose.yml`

- [ ] **Step 1: Add relay-indexer and relay-external services**

Add after the blossom-proxy section, before the invite section. Use the port and healthcheck discovered in Task 0:

```yaml
  # ---------------------------------------------------------------------------
  # Indexer relay (stores kind 10002 + kind 0, simulates purplepag.es)
  # ---------------------------------------------------------------------------
  relay-indexer:
    image: ghcr.io/verse-pbc/relay_builder:latest
    pull_policy: always
    ports:
      - "47778:8080"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8080/health || exit 1"]
      interval: 3s
      timeout: 3s
      retries: 10

  # ---------------------------------------------------------------------------
  # External relay (stores kind 0 + videos for Nostr-native users, simulates damus)
  # ---------------------------------------------------------------------------
  relay-external:
    image: ghcr.io/verse-pbc/relay_builder:latest
    pull_policy: always
    ports:
      - "47779:8080"
    healthcheck:
      test: ["CMD-SHELL", "curl -sf http://localhost:8080/health || exit 1"]
      interval: 3s
      timeout: 3s
      retries: 10
```

Note: Replace healthcheck if Task 0 found `/dev/tcp` unsupported.

- [ ] **Step 2: Update e2e-seed dependencies and environment**

In the `e2e-seed` service, add to `depends_on`:

```yaml
      relay-indexer:
        condition: service_healthy
      relay-external:
        condition: service_healthy
```

Add to `environment`:

```yaml
      INDEXER_RELAY_URL: ws://relay-indexer:7777
      EXTERNAL_RELAY_URL: ws://relay-external:7777
      RELAY_PUBLIC_URL: ws://10.0.2.2:47777
      EXTERNAL_RELAY_PUBLIC_URL: ws://10.0.2.2:47779
```

- [ ] **Step 3: Verify stack starts**

```bash
cd local_stack && docker compose down && docker compose up -d
docker compose ps
```

Expected: All services including `relay-indexer` and `relay-external` show healthy.

- [ ] **Step 4: Verify new relays accept events**

```bash
nak event --sec $(nak key generate) -k 10002 -t r="wss://test.example.com" -c '' ws://localhost:47778
nak event --sec $(nak key generate) -k 0 -c '{"name":"test"}' ws://localhost:47779
```

Expected: Both accepted.

- [ ] **Step 5: Commit**

```bash
git add local_stack/docker-compose.yml
git commit -m "infra: add relay-indexer and relay-external to local stack"
```

---

### Task 2: Update environment config and constants

**Files:**
- Modify: `mobile/lib/models/environment_config.dart`
- Modify: `mobile/integration_test/helpers/constants.dart`
- Modify: `mobile/test/models/environment_config_test.dart`

- [ ] **Step 1: Add port constants to environment_config.dart**

After `localInvitePort`:

```dart
const localIndexerRelayPort = 47778;
const localExternalRelayPort = 47779;
```

- [ ] **Step 2: Change LOCAL indexerRelays to relay-indexer**

In `EnvironmentConfig.indexerRelays`:

```dart
if (environment == AppEnvironment.local) {
  return ['ws://$localHost:$localIndexerRelayPort'];
}
```

- [ ] **Step 3: Export new constants from integration test constants.dart**

Add to the `show` list:

```dart
export 'package:openvine/models/environment_config.dart'
    show
        localApiPort,
        localBlossomPort,
        localExternalRelayPort,
        localHost,
        localIndexerRelayPort,
        localInvitePort,
        localKeycastPort,
        localRelayPort;
```

- [ ] **Step 4: Update environment_config_test.dart**

Add a test for the new LOCAL indexerRelays value. Update any existing test that asserts on the LOCAL indexerRelays list.

- [ ] **Step 5: Run analyze and tests**

```bash
cd mobile && mise exec -- flutter analyze lib/models/environment_config.dart
cd mobile && mise exec -- flutter test test/models/environment_config_test.dart
```

Expected: No issues, all tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/models/environment_config.dart \
        mobile/integration_test/helpers/constants.dart \
        mobile/test/models/environment_config_test.dart
git commit -m "feat(config): add indexer and external relay ports for multi-relay E2E"
```

---

### Task 3: Parameterize relay_helpers.dart publishing

**Files:**
- Modify: `mobile/integration_test/helpers/relay_helpers.dart`

- [ ] **Step 1: Add relayPort parameter to _publishEvent()**

Change `_publishEvent` to accept an optional `relayPort`:

```dart
Future<String> _publishEvent(Event event, {int? relayPort}) async {
  final port = relayPort ?? localRelayPort;
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://$localHost:$port'),
  );
  // ... rest unchanged
}
```

- [ ] **Step 2: Add relayPort parameter to publishTestProfileEvent()**

```dart
Future<PublishedProfile> publishTestProfileEvent({
  required String name,
  String? displayName,
  String? about,
  String? privateKey,
  int? relayPort,
}) async {
  // ... existing code ...
  final eventId = await _publishEvent(event, relayPort: relayPort);
  // ...
}
```

- [ ] **Step 3: Add relayPort parameter to publishTestVideoEvent()**

```dart
Future<PublishedVideo> publishTestVideoEvent({
  required String title,
  String? privateKey,
  int? relayPort,
}) async {
  // ... existing code ...
  final eventId = await _publishEvent(event, relayPort: relayPort);
  // ...
}
```

- [ ] **Step 4: Add relayPort parameter to publishDeleteEvent()**

```dart
Future<String> publishDeleteEvent({
  required String eventId,
  required int kind,
  required String privateKey,
  int? relayPort,
}) async {
  // ... existing code ...
  final deletionId = await _publishEvent(deleteEvent, relayPort: relayPort);
  // ...
}
```

- [ ] **Step 5: Add relayPort parameter to queryRelay()**

```dart
Future<List<Event>> queryRelay(
  Map<String, dynamic> filter, {
  int? relayPort,
}) async {
  final port = relayPort ?? localRelayPort;
  final channel = WebSocketChannel.connect(
    Uri.parse('ws://$localHost:$port'),
  );
  // ... rest unchanged
}
```

- [ ] **Step 6: Run analyze**

```bash
cd mobile && mise exec -- flutter analyze integration_test/helpers/relay_helpers.dart
```

Expected: No issues.

- [ ] **Step 7: Commit**

```bash
git add mobile/integration_test/helpers/relay_helpers.dart
git commit -m "feat(e2e): parameterize relay port in publishing helpers"
```

---

### Task 4: Add kind 10002 publishing helper

**Files:**
- Modify: `mobile/integration_test/helpers/relay_helpers.dart`

- [ ] **Step 1: Add PublishedRelayList typedef**

After the existing typedefs:

```dart
/// Result of publishing a test relay list event.
typedef PublishedRelayList = ({String eventId, String pubkey, String privateKey});
```

- [ ] **Step 2: Add publishTestRelayListEvent()**

```dart
/// Publish a kind 10002 relay list event to the indexer relay.
///
/// Creates a new keypair (or uses [privateKey] if provided), builds a NIP-65
/// relay list event with the given relay URLs, signs it, and sends it to the
/// indexer relay.
///
/// [relayUrls] are the relay URLs to include in the `r` tags. These must be
/// emulator-accessible URLs (e.g., ws://10.0.2.2:47777), not Docker-internal.
///
/// Returns the event ID, pubkey, and private key.
Future<PublishedRelayList> publishTestRelayListEvent({
  required List<String> relayUrls,
  String? privateKey,
}) async {
  final privKey = privateKey ?? generatePrivateKey();
  final pubKey = getPublicKey(privKey);

  final tags = relayUrls.map((url) => ['r', url]).toList();

  final event = Event(pubKey, 10002, tags, '');
  event.sign(privKey);

  final eventId = await _publishEvent(
    event,
    relayPort: localIndexerRelayPort,
  );
  debugPrint('Published relay list event: $eventId (pubkey: $pubKey)');
  return (eventId: eventId, pubkey: pubKey, privateKey: privKey);
}
```

- [ ] **Step 3: Run analyze**

```bash
cd mobile && mise exec -- flutter analyze integration_test/helpers/relay_helpers.dart
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add mobile/integration_test/helpers/relay_helpers.dart
git commit -m "feat(e2e): add kind 10002 relay list publishing helper"
```

---

### Task 5: Add persona registration wrappers

**Files:**
- Modify: `mobile/integration_test/helpers/relay_helpers.dart`

- [ ] **Step 1: Add persona setup wrappers**

These wrappers seed relay presence for browsable users (not the logged-in user — Keycast manages that identity, and its private keys are KMS-encrypted in `personal_keys` and not extractable).

```dart
/// Set up a Type A (Divine) user's relay presence.
///
/// Publishes kind 10002 (relay list) to the indexer relay and kind 0
/// (profile) to both FunnelCake and the indexer relay.
///
/// Call this after Keycast registration to complete the persona setup.
Future<void> setupTypeAPresence({
  required String privateKey,
  required String name,
  String? displayName,
  String? about,
}) async {
  // Kind 10002 → indexer, listing both relays
  await publishTestRelayListEvent(
    relayUrls: [
      'ws://$localHost:$localRelayPort',
      'ws://$localHost:$localExternalRelayPort',
    ],
    privateKey: privateKey,
  );

  // Kind 0 → FunnelCake
  await publishTestProfileEvent(
    name: name,
    displayName: displayName,
    about: about,
    privateKey: privateKey,
  );

  // Kind 0 → indexer relay
  await publishTestProfileEvent(
    name: name,
    displayName: displayName,
    about: about,
    privateKey: privateKey,
    relayPort: localIndexerRelayPort,
  );
}

/// Set up a Type B (Nostr-native) user's relay presence.
///
/// Publishes kind 10002 (relay list) to the indexer relay and kind 0
/// (profile) to the external relay and indexer relay.
///
/// Call this after Keycast registration to complete the persona setup.
Future<void> setupTypeBPresence({
  required String privateKey,
  required String name,
  String? displayName,
  String? about,
}) async {
  // Kind 10002 → indexer, listing both relays
  await publishTestRelayListEvent(
    relayUrls: [
      'ws://$localHost:$localRelayPort',
      'ws://$localHost:$localExternalRelayPort',
    ],
    privateKey: privateKey,
  );

  // Kind 0 → external relay
  await publishTestProfileEvent(
    name: name,
    displayName: displayName,
    about: about,
    privateKey: privateKey,
    relayPort: localExternalRelayPort,
  );

  // Kind 0 → indexer relay
  await publishTestProfileEvent(
    name: name,
    displayName: displayName,
    about: about,
    privateKey: privateKey,
    relayPort: localIndexerRelayPort,
  );
}
```

- [ ] **Step 3: Run analyze**

```bash
cd mobile && mise exec -- flutter analyze integration_test/helpers/relay_helpers.dart
```

Expected: No issues.

- [ ] **Step 4: Commit**

```bash
git add mobile/integration_test/helpers/relay_helpers.dart
git commit -m "feat(e2e): add type A and type B persona setup wrappers"
```

---

### Task 6: Extend seed.py with multi-relay and kind 0 support

**Files:**
- Modify: `local_stack/seed/seed.py`

- [ ] **Step 1: Add new configuration constants**

After the existing config section:

```python
INDEXER_RELAY_URL = os.environ.get("INDEXER_RELAY_URL", "ws://relay-indexer:7777")
EXTERNAL_RELAY_URL = os.environ.get("EXTERNAL_RELAY_URL", "ws://relay-external:7777")
RELAY_PUBLIC_URL = os.environ.get("RELAY_PUBLIC_URL", "ws://10.0.2.2:47777")
EXTERNAL_RELAY_PUBLIC_URL = os.environ.get("EXTERNAL_RELAY_PUBLIC_URL", "ws://10.0.2.2:47779")

# Author type split: first half are Type A (Divine), second half Type B (Nostr-native)
NUM_TYPE_A = NUM_AUTHORS // 2  # 10
NUM_TYPE_B = NUM_AUTHORS - NUM_TYPE_A  # 10
```

- [ ] **Step 2: Add author_is_type_a() helper**

```python
def author_is_type_a(author_idx: int) -> bool:
    """Author 0..NUM_TYPE_A-1 are Type A (Divine), rest are Type B (Nostr-native)."""
    return author_idx < NUM_TYPE_A
```

- [ ] **Step 3: Add build_profile_event() function**

```python
def build_profile_event(
    author_privkey: bytes,
    author_pubkey: str,
    author_idx: int,
) -> dict:
    """Build and sign a kind 0 profile metadata event."""
    persona = "divine" if author_is_type_a(author_idx) else "nostr-native"
    name = f"e2e-{persona}-{author_idx}"
    content = json.dumps({
        "name": name,
        "display_name": f"E2E {persona.title()} User {author_idx}",
        "about": f"Test {persona} user for E2E persona testing",
    })
    event = {
        "kind": 0,
        "pubkey": author_pubkey,
        "created_at": int(time.time()),
        "content": content,
        "tags": [],
    }
    return sign_event(event, author_privkey)
```

- [ ] **Step 4: Add build_relay_list_event() function**

```python
def build_relay_list_event(
    author_privkey: bytes,
    author_pubkey: str,
) -> dict:
    """Build and sign a kind 10002 relay list event.

    Uses emulator-accessible public URLs, not Docker-internal hostnames.
    """
    event = {
        "kind": 10002,
        "pubkey": author_pubkey,
        "created_at": int(time.time()),
        "content": "",
        "tags": [
            ["r", RELAY_PUBLIC_URL],
            ["r", EXTERNAL_RELAY_PUBLIC_URL],
        ],
    }
    return sign_event(event, author_privkey)
```

- [ ] **Step 5: Add publish_events_to_relay() function**

Generalize `publish_events()` to accept a relay URL:

```python
def publish_events_to_relay(events: list[dict], relay_url: str) -> tuple[int, int]:
    """Publish events to the specified relay. Returns (ok_count, fail_count)."""
    ok_count = 0
    fail_count = 0

    with websockets.sync.client.connect(relay_url, close_timeout=10) as ws:
        for i, event in enumerate(events):
            msg = json.dumps(["EVENT", event])
            ws.send(msg)
            try:
                raw = ws.recv(timeout=10)
                response = json.loads(raw)
                if (
                    isinstance(response, list)
                    and len(response) >= 3
                    and response[0] == "OK"
                ):
                    if response[2]:
                        ok_count += 1
                    else:
                        fail_count += 1
                        reason = response[3] if len(response) > 3 else "unknown"
                        print(f"  REJECTED event {i}: {reason}", file=sys.stderr)
                else:
                    fail_count += 1
            except TimeoutError:
                fail_count += 1
                print(f"  Timeout on event {i}", file=sys.stderr)

    return ok_count, fail_count
```

Update the original `publish_events()` to delegate:

```python
def publish_events(events: list[dict]) -> tuple[int, int]:
    """Publish events to the FunnelCake relay."""
    return publish_events_to_relay(events, RELAY_URL)
```

- [ ] **Step 6: Update wait_for_services() to check all relays**

Add indexer and external relay checks:

```python
def wait_for_services(max_retries: int = 30, delay: float = 2.0) -> None:
    """Poll blossom and all relays until they respond, or exit."""
    # ... existing blossom and relay checks ...

    # Check indexer relay
    for attempt in range(max_retries):
        try:
            with websockets.sync.client.connect(INDEXER_RELAY_URL, close_timeout=3):
                pass
            print(f"  Indexer relay ready at {INDEXER_RELAY_URL}")
            break
        except (OSError, TimeoutError, websockets.exceptions.WebSocketException):
            if attempt == max_retries - 1:
                print(f"Indexer relay not ready after {max_retries} attempts", file=sys.stderr)
                sys.exit(1)
            time.sleep(delay)

    # Check external relay
    for attempt in range(max_retries):
        try:
            with websockets.sync.client.connect(EXTERNAL_RELAY_URL, close_timeout=3):
                pass
            print(f"  External relay ready at {EXTERNAL_RELAY_URL}")
            break
        except (OSError, TimeoutError, websockets.exceptions.WebSocketException):
            if attempt == max_retries - 1:
                print(f"External relay not ready after {max_retries} attempts", file=sys.stderr)
                sys.exit(1)
            time.sleep(delay)

    print("All services ready.")
```

- [ ] **Step 7: Update main() to publish profiles, relay lists, and route videos**

After building keypairs and before building video events, add profile and relay list publishing. Route video events based on author type:

```python
def main() -> None:
    # ... existing config print and wait_for_services() ...

    if check_already_seeded():
        print("Seed data already exists, skipping.")
        return

    # 1. Generate keypairs (unchanged)
    keypairs = [derive_keypair(i) for i in range(NUM_AUTHORS)]

    # 2. Publish kind 10002 relay list events (all authors → indexer)
    print(f"\nPublishing {NUM_AUTHORS} relay list events to indexer relay...")
    relay_list_events = []
    for i, (privkey, pubkey) in enumerate(keypairs):
        relay_list_events.append(build_relay_list_event(privkey, pubkey))
    ok, fail = publish_events_to_relay(relay_list_events, INDEXER_RELAY_URL)
    print(f"  Relay lists: {ok} ok, {fail} failed")

    # 3. Publish kind 0 profile events (routed by type)
    print(f"\nPublishing {NUM_AUTHORS} profile events...")
    indexer_profiles = []
    funnelcake_profiles = []
    external_profiles = []
    for i, (privkey, pubkey) in enumerate(keypairs):
        profile = build_profile_event(privkey, pubkey, i)
        indexer_profiles.append(profile)
        if author_is_type_a(i):
            funnelcake_profiles.append(profile)
        else:
            external_profiles.append(profile)

    ok, fail = publish_events_to_relay(indexer_profiles, INDEXER_RELAY_URL)
    print(f"  Indexer profiles: {ok} ok, {fail} failed")
    if funnelcake_profiles:
        ok, fail = publish_events_to_relay(funnelcake_profiles, RELAY_URL)
        print(f"  FunnelCake profiles: {ok} ok, {fail} failed")
    if external_profiles:
        ok, fail = publish_events_to_relay(external_profiles, EXTERNAL_RELAY_URL)
        print(f"  External profiles: {ok} ok, {fail} failed")

    # 4. Generate and upload videos (unchanged)
    # ...

    # 5. Build and route video events
    # Type A authors: all videos → FunnelCake
    # Type B authors: odd-indexed → external, even-indexed → FunnelCake
    funnelcake_events = []
    external_events = []
    for i in range(NUM_VIDEOS):
        author_idx = author_assignments[i]
        # ... build event as before ...
        if author_is_type_a(author_idx):
            funnelcake_events.append(event)
        elif i % 2 == 0:
            funnelcake_events.append(event)
        else:
            external_events.append(event)

    # 6. Publish video events
    print(f"\nPublishing {len(funnelcake_events)} videos to FunnelCake...")
    ok, fail = publish_events(funnelcake_events)
    print(f"  FunnelCake videos: {ok} ok, {fail} failed")
    if external_events:
        print(f"Publishing {len(external_events)} videos to external relay...")
        ok, fail = publish_events_to_relay(external_events, EXTERNAL_RELAY_URL)
        print(f"  External videos: {ok} ok, {fail} failed")
```

- [ ] **Step 8: Verify seed runs**

```bash
cd local_stack && docker compose down && docker compose up -d
# Wait for seed to complete
docker compose logs -f e2e-seed
```

Expected: Seed completes with profiles, relay lists, and videos published to all three relays.

- [ ] **Step 9: Verify events are queryable**

```bash
# Query indexer for kind 10002
nak req -k 10002 -l 3 ws://localhost:47778
# Query indexer for kind 0
nak req -k 0 -l 3 ws://localhost:47778
# Query external for kind 0 (type B profiles)
nak req -k 0 -l 3 ws://localhost:47779
# Query external for kind 34236 (type B videos)
nak req -k 34236 -l 3 ws://localhost:47779
# Query FunnelCake for kind 34236 (all type A + half type B videos)
nak req -k 34236 -l 3 ws://localhost:47777
```

Expected: Events returned from each relay matching the routing rules.

- [ ] **Step 10: Commit**

```bash
git add local_stack/seed/seed.py
git commit -m "feat(seed): multi-relay seeding with type A/B personas and kind 0/10002 events"
```

---

### Task 7: Add kind 7 reaction publishing helper

**Files:**
- Modify: `mobile/integration_test/helpers/relay_helpers.dart`

- [ ] **Step 1: Add publishTestReactionEvent()**

```dart
/// Publish a kind 7 reaction event to the specified relay.
///
/// Creates a reaction ("+") from [privateKey] targeting [targetEventId]
/// by [targetPubkey]. Used to seed notification data for testing.
Future<String> publishTestReactionEvent({
  required String targetEventId,
  required String targetPubkey,
  required String privateKey,
  int? relayPort,
}) async {
  final pubKey = getPublicKey(privateKey);

  final event = Event(pubKey, 7, [
    ['e', targetEventId],
    ['p', targetPubkey],
  ], '+');
  event.sign(privateKey);

  final eventId = await _publishEvent(event, relayPort: relayPort);
  debugPrint('Published reaction event: $eventId (target: $targetEventId)');
  return eventId;
}
```

- [ ] **Step 2: Run analyze**

```bash
cd mobile && mise exec -- flutter analyze integration_test/helpers/relay_helpers.dart
```

- [ ] **Step 3: Commit**

```bash
git add mobile/integration_test/helpers/relay_helpers.dart
git commit -m "feat(e2e): add kind 7 reaction publishing helper"
```

---

### Task 8: Write persona E2E tests

**Files:**
- Create: `mobile/integration_test/e2e/persona_test.dart`

**Important context:** Keycast is a NIP-46 remote signer. Private keys are KMS-encrypted in the `personal_keys` table and cannot be extracted. Therefore:
- The **logged-in user** is always a standard Keycast registration (as in today's tests).
- The **persona types** (A and B) are seeded *browsable* users with keypairs we generate and control.
- Tests verify the app can discover and display profiles/content from different relay configurations.

Read the existing test patterns in `integration_test/helpers/navigation_helpers.dart` for the actual registration and login helper signatures before writing tests. Use the same `launchAppGuarded` / `suppressSetStateErrors` / `restoreErrorHandler` / `drainAsyncErrors` pattern from existing tests.

- [ ] **Step 1: Create test file with imports and setup**

```dart
// ABOUTME: E2E tests for multi-relay user personas
// ABOUTME: Verifies that seeded Type A (Divine) and Type B (Nostr-native) users
// ABOUTME: are discoverable and displayable across different relay configurations

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:openvine/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../helpers/constants.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/relay_helpers.dart';
import '../helpers/test_setup.dart';
```

- [ ] **Step 2: Write test — browse Type B profile from external relay**

The logged-in user registers normally via Keycast. A Type B user is seeded with keypair we control: kind 10002 on indexer, kind 0 on external relay + indexer. Test navigates to the Type B user's profile and verifies it loads.

```dart
patrolTest(
  'can browse Type B (Nostr-native) profile from external relay',
  timeout: const Timeout(Duration(minutes: 5)),
  ($) async {
    final tester = $.tester;
    final originalOnError = suppressSetStateErrors();
    final originalErrorBuilder = saveErrorWidgetBuilder();

    launchAppGuarded(app.main);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Register and log in normally via Keycast
    // (Use existing helpers from navigation_helpers.dart — check actual
    // function signatures: navigateToCreateAccount, registerNewUser,
    // callVerifyEmail, loginWithCredentials, etc.)
    // ...registration flow...

    // Seed a Type B user with relay presence
    await setupTypeBPresence(
      privateKey: generatePrivateKey(),
      name: 'nostr-native-browse-test',
      displayName: 'Nostr Native Browse Test',
    );

    // Navigate to the seeded user's profile
    // (Use search, explore tab, or direct navigation depending on
    // available helpers. The seeded user should appear in explore
    // since their videos are on FunnelCake via the seed script.)

    // Verify profile metadata loaded from external relay
    final found = await waitForText(
      tester, 'Nostr Native Browse Test', maxSeconds: 15,
    );
    expect(found, isTrue);

    restoreErrorWidgetBuilder(originalErrorBuilder);
    restoreErrorHandler(originalOnError);
    drainAsyncErrors(tester);
  },
);
```

Note: Exact navigation depends on available helpers in `navigation_helpers.dart`. The implementer should read that file and adapt. The seeded Type B users from `seed.py` (Task 6) will have videos on FunnelCake, making them discoverable in the explore feed.

- [ ] **Step 3: Write test — Type B user's videos appear (mixed relays)**

Same registration pattern. Seed a Type B user with videos on both FunnelCake and external relay. Navigate to their profile, verify video count matches expected total from both relays.

```dart
patrolTest(
  'Type B profile shows videos from both FunnelCake and external relay',
  timeout: const Timeout(Duration(minutes: 5)),
  ($) async {
    final tester = $.tester;
    final originalOnError = suppressSetStateErrors();
    final originalErrorBuilder = saveErrorWidgetBuilder();

    launchAppGuarded(app.main);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ...registration flow (same as Step 2)...

    // Seed Type B user with videos on both relays
    final privKey = generatePrivateKey();
    await setupTypeBPresence(
      privateKey: privKey,
      name: 'nostr-native-videos-test',
      displayName: 'Multi-Relay Video User',
    );
    // Video on FunnelCake
    await publishTestVideoEvent(
      title: 'Divine upload',
      privateKey: privKey,
    );
    // Video on external relay
    await publishTestVideoEvent(
      title: 'External upload',
      privateKey: privKey,
      relayPort: localExternalRelayPort,
    );

    // Navigate to profile, verify videos from both relays appear
    // ...navigate to profile...
    // Assert at least 2 videos visible
    // (Exact finder depends on the profile grid widget)

    restoreErrorWidgetBuilder(originalErrorBuilder);
    restoreErrorHandler(originalOnError);
    drainAsyncErrors(tester);
  },
);
```

- [ ] **Step 4: Write regression test — notifications load for multi-relay user (PR #2463)**

Seed a Type B user with content on FunnelCake. Seed a kind 7 reaction targeting that content (also on FunnelCake, since notifications API only reads from FunnelCake). Register as a new user, navigate to notifications. Verify non-empty results — an empty list would indicate the notifications API hit the wrong relay (the PR #2463 bug).

```dart
patrolTest(
  'notifications load correctly for user with external relays (PR #2463 regression)',
  timeout: const Timeout(Duration(minutes: 5)),
  ($) async {
    final tester = $.tester;
    final originalOnError = suppressSetStateErrors();
    final originalErrorBuilder = saveErrorWidgetBuilder();

    launchAppGuarded(app.main);
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // ...registration flow...
    // After registration, get the logged-in user's pubkey from Keycast DB
    // final userPubkey = await getUserPubkeyByEmail(email);

    // Seed a video from the logged-in user on FunnelCake
    // (We can't sign as the logged-in user since Keycast holds the key.
    // Instead, use a seeded Type A user's reaction targeting content
    // the logged-in user can see in their notifications.)
    //
    // Alternative approach: seed a reaction from a generated keypair
    // targeting a video the logged-in user published during registration.
    // The exact approach depends on how the app populates notifications
    // for the logged-in user.

    // Verify notifications tab shows non-empty content
    // Navigate to notifications tab
    // Assert notification list is not empty
    // (An empty list with no error = PR #2463 bug: API hit wrong relay)

    restoreErrorWidgetBuilder(originalErrorBuilder);
    restoreErrorHandler(originalOnError);
    drainAsyncErrors(tester);
  },
);
```

Note: The notification regression test depends on how `resolveApiBaseUrlFromRelays()` resolves in LOCAL env after the indexerRelays change. The implementer should verify that `environmentConfig.apiBaseUrl` correctly points to FunnelCake's REST API for LOCAL env, since `relay.divine.video` (the production preferred host) never matches locally.

- [ ] **Step 5: Run the tests**

```bash
cd mobile && mise run e2e_test integration_test/e2e/persona_test.dart
```

Expected: All tests pass.

- [ ] **Step 6: Commit**

```bash
git add mobile/integration_test/e2e/persona_test.dart
git commit -m "test(e2e): add persona tests for cross-relay profile and content discovery"
```

---

### Task 9: End-to-end verification

**Files:** None (verification only)

- [ ] **Step 1: Reset and re-seed the local stack**

```bash
cd mobile && mise run local_reset
```

Wait for all services healthy and seed to complete.

- [ ] **Step 2: Run existing E2E tests to verify no regressions**

```bash
cd mobile && mise run e2e_test integration_test/auth/auth_journey_test.dart
```

Expected: Existing tests pass. The indexerRelays change should not break auth since the indexer relay accepts kind 10002 queries.

- [ ] **Step 3: Run persona tests**

```bash
cd mobile && mise run e2e_test integration_test/e2e/persona_test.dart
```

Expected: All persona tests pass.

- [ ] **Step 4: Verify relay discovery flow manually**

Check emulator logs for relay discovery hitting the indexer relay (47778) instead of FunnelCake (47777).

- [ ] **Step 5: Final commit if any fixups needed**

Stage only the specific files that were fixed, then commit:

```bash
git commit -m "fix(e2e): address test feedback from verification"
```
