# Environment / relay indicator line

Status: Implemented in PR #5253
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
- **Purple trigger:** the client's current **configured/outbox relay set**
  (`NostrClient.configuredRelays` = env relay + the user's NIP-65 relays),
  excluding relays every account is auto-seeded with for indexer lookup and DM
  reachability. Transient read/indexer relays (e.g. `purplepag.es`) do not
  trigger purple unless they are also genuinely user-chosen relays.
- **Style:** a 4px non-interactive line above the bottom navigation bar, with
  rounded top corners.

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

/// True if [configuredRelays] includes a relay the user added beyond the
/// Divine-operated relays, loopback, and the app's own [defaultRelayUrls].
bool usesUserChosenRelay(
  Iterable<String> configuredRelays, {
  required Iterable<String> defaultRelayUrls,
}) { ... }
```

Reuses the existing `isLoopbackHost` helper in the same file. The host list is
the set of `EnvironmentConfig.relayUrl` hosts across environments. The default
relay exclusion covers `EnvironmentConfig.indexerRelays` and
`IndexerRelayConfig.safeFallbackRelays`, so a fresh account seeded with app
plumbing does not show as user-chosen non-Divine relay use.

### 2. State — `environmentIndicatorColorProvider` → `Color?`

A Riverpod provider that returns the line color, or `null` when the line should
be hidden.

- `ref.watch(currentEnvironmentProvider)` — recompute on environment switch.
- `ref.watch(configuredRelayUrlsProvider)` — recompute when the configured
  relay set changes (add / remove / NIP-65 discovery). The provider is updated
  by `relaySetChangeBridge` from the current relay-status map keys, which are
  created from the configured relays and pruned on removal, so the
  always-mounted indicator does not initialize the Nostr client itself.

Logic:

```
final relays = ref.watch(configuredRelayUrlsProvider);
if (usesUserChosenRelay(relays, defaultRelayUrls: defaultRelayUrls)) {
  return <purple>;
}
if (!environment.isProduction) return Color(environment.indicatorColorValue);
return null; // production + Divine-only → hidden
```

Purple is a `VineTheme` purple (the same `accentPurple` the `local` environment
already uses) — no raw `Color(0x...)` literal in the widget.

### 3. Widget — `EnvironmentIndicatorLine` (ConsumerWidget)

```dart
final color = ref.watch(environmentIndicatorColorProvider);
if (color == null) return const SizedBox.shrink();
return ExcludeSemantics(
  child: SizedBox(
    height: 4,
    width: double.infinity,
    child: ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      child: ColoredBox(color: color),
    ),
  ),
);
```

Mounted in `lib/router/app_shell.dart`, full width, above the bottom navigation
bar. Excluded from semantics (decorative).

## Testing

- `relay_url_utils` unit tests: `isDivineHostedRelayUrl` true for each Divine
  host + loopback, false for `purplepag.es` / `wss://relay.nos.social` /
  malformed; `usesUserChosenRelay` true/false/default-relay cases.
- Provider tests (ProviderContainer with overrides): purple when configured
  relays include a user-chosen relay; environment color in non-production with
  Divine-only relays; null in production with Divine/default relays; purple
  clears after the user-chosen relay is removed.
- Widget test: renders a colored line of the provided color; renders nothing
  when the provider is null.

## Risk / rollback

Purely additive UI. In production with the default Divine relay only, the
provider returns null and nothing renders — no change to today's production
appearance. A production user with their own NIP-65 relays will see a thin
purple line (intended transparency).
