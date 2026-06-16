# Relay environment isolation

Status: Approved (brainstorm) — pending implementation
Date: 2026-06-17

## Problem

When the app is set to a non-production environment (staging / poc / test /
local) and the user records a video, the event is published to the
**production** relay (`wss://relay.divine.video`).

### Root cause

The `NostrClient` is seeded with the environment relay **plus** the user's
NIP-65 (kind 10002) relay list, which is added unconditionally with no
environment filtering:

- `lib/services/nostr_service_factory.dart` seeds `defaultRelayUrl =
  environmentConfig.relayUrl` (correct).
- `lib/providers/nostr_client_provider.dart` adds `authService.userRelays`
  (the user's kind 10002 list) via `client.addRelays(...)` in `build()`, on
  auth-state change, and via the discovered-relays callback. A kind:10002
  bootstrap publisher adds more.
- A production account's kind 10002 list contains `wss://relay.divine.video`,
  so a staging session connects to staging **and** production.
- Video publish (`video_event_publisher.dart`) calls publish with no
  `targetRelays`, fanning out to **all** connected relays → the event lands on
  production.
- `environment_service.dart` clears the persisted `configured_relays` on
  switch, but `authService.userRelays` is never cleared, so the production
  relay is re-added every session.

This affects every publish (likes, comments, profile, kind 10002) and
subscriptions — not just video.

## Goal

In non-production environments, the app must connect to and publish on **only
the environment relay host** — never production, never public indexers.
Production behavior is unchanged.

## Non-goals (deferred to the outbox-relay management feature)

- Any relay-management UI changes.
- Per-user override of the lock (e.g. a tester opting a specific relay in).
- NIP-65 read/write (inbox/outbox) markers or publishing kind 10002 from a
  management screen.

## Design

The enforcement lives centrally in `RelayManager` (one source of truth). It is
expressed declaratively, not as an injected closure: the only two cases are
"allow all" (production) and "lock to one host" (non-production), so a single
nullable host field is exactly enough.

### 1. `allowedRelayHost` on `RelayManagerConfig` + `isRelayAllowed` on `RelayManager`

Add one optional field to `RelayManagerConfig`
(`packages/nostr_client/lib/src/models/relay_manager_config.dart`), threaded
through `copyWith`:

```dart
/// When set, only relays whose host equals this value are admitted.
/// Null means no restriction (default — production behavior).
final String? allowedRelayHost;
```

`RelayManager` (`packages/nostr_client/lib/src/relay_manager.dart`) exposes one
public check that is the single source of truth for the rule:

```dart
bool isRelayAllowed(String url) {
  final normalized = _normalizeUrl(url);
  if (normalized == null) return false;
  final host = _config.allowedRelayHost;
  if (host == null) return true;
  return Uri.parse(normalized).host == host;
}
```

It is consulted (alongside the existing `_isBlockedRelay` dead-relay check) at
every admission point:

- the storage-load filter in `initialize()` — drops a persisted production
  relay on the next staging launch (re-save already happens there today),
- the default-relay insert,
- `addRelay()` and `addRelays()`.

`removeRelay()` is unaffected. This single chokepoint covers the env relay,
user NIP-65 relays, the discovered-relays callback, and the kind:10002
bootstrap — no per-call-site filtering in `nostr_client_provider`.

### 2. Temp-relay filtering in `NostrClient`

`targetRelays` / `tempRelays` are passed below `RelayManager` straight into the
nostr_sdk send/query path, so they bypass the admission points above.
`NostrClient` (`packages/nostr_client/lib/src/nostr_client.dart`) filters them
with the **same** `RelayManager.isRelayAllowed` — not a second copy of the rule
— before handing them to the SDK in `publishEvent`, `publishEventAwaitOk`, and
`queryEvents`. A single private helper (`_allowedRelays(List<String>?)`) is
applied at those call sites.

### 3. Wiring — `nostr_service_factory`

The factory holds `environmentConfig`, so it sets the field:

- **Production** (`environmentConfig.isProduction`) → `allowedRelayHost: null`
  (no restriction; unchanged).
- **Non-production** → `allowedRelayHost: Uri.parse(environmentConfig.relayUrl).host`
  (e.g. `relay.staging.divine.video`; `10.0.2.2` for local — host-based, not
  host:port). Production `relay.divine.video` and public indexer relays are
  rejected.

### 4. Adjacent fix — `RelaySettingsCubit.restoreDefaultRelay()`

Currently adds the hardcoded `AppConstants.defaultRelayUrl` (production), which
the predicate would now reject on staging (surfacing as `failed`). Point it at
the manager's env-aware default relay instead so "restore" works in every
environment.

## Testing

`nostr_client` package (strict tests):

- `RelayManager.isRelayAllowed`: with `allowedRelayHost` set, returns `false`
  for a different host (production) and `true` for the env host; with it null,
  returns `true` for any valid relay.
- `RelayManager`: with `allowedRelayHost` set, `addRelay(production)` →
  `false`; `addRelay(envHost)` → `true`; `initialize()` filters a persisted
  production relay out of storage and re-saves; the default-relay insert still
  works; `removeRelay` unaffected.
- `NostrClient`: `publishEvent` / `publishEventAwaitOk` / `queryEvents` drop
  `targetRelays` / `tempRelays` that fail `isRelayAllowed` before reaching the
  SDK.

App layer:

- `nostr_service_factory`: production builds a null/allow-all predicate;
  staging builds a predicate that rejects production and accepts the staging
  host.
- Isolation behavior: after a production NIP-65 relay is offered in a staging
  session, `configuredRelays` contains only the env host.
- `RelaySettingsCubit.restoreDefaultRelay()` restores the env relay (not
  production) under a non-production config.

## Consequences

- On staging/poc/test, NIP-50 search and profile/NIP-65 discovery that rely on
  external relays (`purplepag.es`, `user.kindpag.es`, `relay.nos.social`) stop
  returning results, because those hosts are now rejected. This is the intended
  meaning of "lock fully to env host"; the env relay must serve whatever a
  tester needs, or the tester uses the per-user override from the follow-up
  feature.

## Risk / rollback

`allowedRelayHost` defaults to null (no restriction), so production is
byte-for-byte unchanged. The blast radius is non-production sessions only. If
the lock proves too strict for staging, the follow-up outbox-management feature
introduces the explicit per-user override.
