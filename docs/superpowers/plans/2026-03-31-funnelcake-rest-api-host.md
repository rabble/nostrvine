# Funnelcake REST API Host Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Send Funnelcake REST requests to `https://api.divine.video` without changing websocket/Nostr relay hosts.

**Architecture:** Keep websocket relay configuration untouched in `EnvironmentConfig.relayUrl`, but make Funnelcake REST resolution explicit in the production environment fallback and in the helper that derives REST hosts from configured relay URLs. Cover the behavior with small focused tests first.

**Tech Stack:** Flutter, Dart, flutter_test

---

## Chunk 1: Reproduce The REST Host Mismatch

### Task 1: Add failing tests for the production REST host

**Files:**
- Modify: `mobile/test/models/environment_config_test.dart`
- Create: `mobile/test/utils/relay_url_utils_test.dart`
- Test: `mobile/test/models/environment_config_test.dart`
- Test: `mobile/test/utils/relay_url_utils_test.dart`

- [ ] **Step 1: Write the failing tests**

```dart
expect(config.apiBaseUrl, 'https://api.divine.video');
expect(
  resolveApiBaseUrlFromRelays(
    configuredRelays: ['wss://relay.divine.video'],
    fallbackBaseUrl: 'https://api.divine.video',
  ),
  'https://api.divine.video',
);
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/models/environment_config_test.dart test/utils/relay_url_utils_test.dart`
Expected: FAIL because production and relay-derived Funnelcake URLs still point
to `https://relay.divine.video`

## Chunk 2: Point Funnelcake REST At The API Host

### Task 2: Implement the minimal REST host change

**Files:**
- Modify: `mobile/lib/models/environment_config.dart`
- Modify: `mobile/lib/utils/relay_url_utils.dart`
- Modify: `mobile/test/models/environment_config_test.dart`
- Create: `mobile/test/utils/relay_url_utils_test.dart`

- [ ] **Step 3: Write minimal implementation**

```dart
// Return https://api.divine.video for production Funnelcake REST traffic and
// special-case relay.divine.video in the Funnelcake URL resolver.
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/models/environment_config_test.dart test/utils/relay_url_utils_test.dart`
Expected: PASS

### Task 3: Re-run dependent provider coverage

**Files:**
- Modify: `mobile/lib/models/environment_config.dart`
- Modify: `mobile/lib/utils/relay_url_utils.dart`
- Test: `mobile/test/providers/funnelcake_available_provider_test.dart`
- Test: `mobile/test/providers/relay_notification_api_service_provider_test.dart`

- [ ] **Step 5: Run targeted verification**

Run: `flutter test test/providers/funnelcake_available_provider_test.dart test/providers/relay_notification_api_service_provider_test.dart`
Expected: PASS

- [ ] **Step 6: Review diff and commit**

```bash
git add docs/superpowers/specs/2026-03-31-funnelcake-rest-api-host-design.md \
        docs/superpowers/plans/2026-03-31-funnelcake-rest-api-host.md \
        mobile/lib/models/environment_config.dart \
        mobile/lib/utils/relay_url_utils.dart \
        mobile/test/models/environment_config_test.dart \
        mobile/test/utils/relay_url_utils_test.dart
git commit -m "fix(funnelcake): send rest requests to api.divine.video"
```
