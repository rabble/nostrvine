# Environment / relay indicator line

Status: Approved (brainstorm) — pending implementation
Date: 2026-06-17

## Problem

There is no always-visible signal for two things a tester/user needs to know
at a glance:

1. Which non-production environment the app is pointed at (staging/poc/test/
   local).
2. Whether the client is configured to use relays **beyond Divine-hosted
   ones** (a user's own NIP-65 relays), i.e. content may flow to relays Divine
   does not operate.

Today only a top app-bar `EnvironmentBadge` exists, shown in non-production
only. There is no relay-awareness signal and no bottom indicator.

## Goal

A thin colored line pinned to the bottom edge of the app that:

- shows the **environment color** in any non-production environment, and
- shows **purple** whenever the configured relay set includes a non-Divine
  host (in any environment, production included).

Purple takes precedence when both conditions hold.

## Decisions (from brainstorm)

- **Visibility:** non-production **OR** using non-Divine relays. Hidden in
  production when on Divine-only relays.
- **Precedence:** purple wins over the environment color.
- **Purple trigger:** the client's **configured/outbox relay set**
  (`NostrClient.configuredRelays` = env relay + the user's NIP-65 relays).
  Transient read/indexer relays (e.g. `purplepag.es`) are not in this set and
  do not trigger purple.
- **Style:** a ~3px non-interactive line at the bottom edge.

## Non-goals

- No change to the existing top `EnvironmentBadge`.
- No tap/interaction on the line.
- No per-relay UI (that's the separate outbox-management feature).

## Design

### 1. Detection — `lib/utils/relay_url_utils.dart` (pure)

```dart
const _divineHostedRelayHosts = <String>{
  'relay.divine.video',
  'relay.staging.divine.video',
  'relay.poc.dvines.org',
  'relay.test.dvines.org',
};

/// True when [url]'s host is a Divine-operated relay host or a loopback host
/// (the `local` environment relay). Malformed URLs return false.
bool isDivineHostedRelayUrl(String url) {
  final host = Uri.tryParse(url)?.host.toLowerCase();
  if (host == null || host.isEmpty) return false;
  return _divineHostedRelayHosts.contains(host) || isLoopbackHost(host);
}

/// True if any relay in [configuredRelays] is not Divine-hosted.
bool hasNonDivineRelay(Iterable<String> configuredRelays) =>
    configuredRelays.any((url) => !isDivineHostedRelayUrl(url));
```

Reuses the existing `isLoopbackHost` helper in the same file. The host list is
the set of `EnvironmentConfig.relayUrl` hosts across environments; kept as a
const here (the util already owns `_divineRelayHost`).

### 2. State — `environmentIndicatorColorProvider` → `Color?`

A Riverpod provider (colocated with the widget or in `environment_provider`)
that returns the line color, or `null` when the line should be hidden.

- `ref.watch(currentEnvironmentProvider)` — recompute on environment switch.
- `ref.watch(relayStatisticsStreamProvider)` (or the equivalent relay-status
  stream provider) — recompute when the relay set changes (add / remove /
  NIP-65 discovery). The value is only used as a change trigger.
- Reads `nostrService.configuredRelays`.

Logic:

```
final relays = nostrService.configuredRelays;
if (hasNonDivineRelay(relays)) return <purple>;
if (!environment.isProduction) return Color(environment.indicatorColorValue);
return null; // production + Divine-only → hidden
```

Purple is a `VineTheme` purple (the same `accentPurple` the `local` environment
already uses) — no raw `Color(0x...)` literal in the widget.

### 3. Widget — `EnvironmentIndicatorLine` (ConsumerWidget)

```dart
final color = ref.watch(environmentIndicatorColorProvider);
if (color == null) return const SizedBox.shrink();
return Container(height: 3, width: double.infinity, color: color);
```

Mounted at the bottom edge of `lib/router/app_shell.dart`, full width, below
the bottom navigation bar and above the system home-indicator inset. Excluded
from semantics (decorative).

## Testing

- `relay_url_utils` unit tests: `isDivineHostedRelayUrl` true for each Divine
  host + loopback, false for `purplepag.es` / `wss://relay.nos.social` /
  malformed; `hasNonDivineRelay` true/false cases.
- Provider tests (ProviderContainer with overrides): purple when configured
  relays include a non-Divine host; environment color in non-production with
  Divine-only relays; null in production with Divine-only relays.
- Widget test: renders a 3px line of the provided color; renders
  `SizedBox.shrink` when the provider is null.

## Risk / rollback

Purely additive UI. In production with the default Divine relay only, the
provider returns null and nothing renders — no change to today's production
appearance. A production user with their own NIP-65 relays will see a thin
purple line (intended transparency).
