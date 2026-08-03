// ABOUTME: Helpers for resolving API base URLs from Nostr relay WebSocket URLs.
// ABOUTME: Keeps REST endpoints aligned with active relay configuration.

import 'package:nostr_client/nostr_client.dart' as nostr_client;
import 'package:nostr_sdk/nostr_sdk.dart' as nostr_sdk;

const _divineRelayHost = 'relay.divine.video';
const _divineApiBaseUrl = 'https://api.divine.video';

/// True if [host] is a recognized loopback address that may be reached over
/// cleartext (`ws://` / `http://`).
///
/// Delegates to the package-level source of truth in `nostr_sdk`; native
/// cleartext transport config must mirror that predicate.
bool isLoopbackHost(String host) => nostr_sdk.isLoopbackHost(host);

/// Relay hosts operated by Divine across all environments.
///
/// Matches the `EnvironmentConfig.relayUrl` hosts. Loopback (the `local`
/// environment relay) is covered separately via [isLoopbackHost].
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
///
/// Every account — including a brand-new one — is auto-seeded with NIP-65
/// indexer relays and DM-reachability fallback relays. Those are app plumbing,
/// not relays the user chose, so they must be passed in via [defaultRelayUrls]
/// and excluded; otherwise a fresh Divine-only account would falsely register
/// as "using non-Divine relays".
bool usesUserChosenRelay(
  Iterable<String> configuredRelays, {
  required Iterable<String> defaultRelayUrls,
}) {
  final allowedHosts = <String>{
    ..._divineHostedRelayHosts,
    for (final url in defaultRelayUrls)
      if (Uri.tryParse(url)?.host.toLowerCase() case final String host
          when host.isNotEmpty)
        host,
  };
  return configuredRelays.any((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;
    if (allowedHosts.contains(host) || isLoopbackHost(host)) return false;
    return true;
  });
}

/// True if [url] is a relay URL the app is allowed to connect to.
///
/// Nostr relays speak WebSocket only — `wss://` is accepted for any host,
/// and `ws://` is accepted only for a recognized loopback host. Any other
/// scheme (`https://`, `http://`, `ftp://`, …), a malformed URL, or a missing
/// host is rejected. Unlike `normalizeRelayUrl` in `nostr_client`, this
/// requires an explicit scheme and rejects bare hosts because it validates
/// user/app-layer input before the connection layer canonicalizes identity.
///
/// This predicate is the single source of truth for the application-layer
/// relay URL allowlist. The loopback host predicate itself lives in
/// `nostr_sdk` so package-layer callers can share it without importing app
/// code.
bool isRelayUrlAllowed(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || !uri.hasAuthority || uri.host.isEmpty) return false;
  // `wss://http://x` parses as host=`http` and path=`//x`; reject so a
  // mis-nested URL in a NIP-65 tag or capability-service input cannot
  // pass the allowlist and target the wrong host downstream.
  if (uri.path.startsWith('//')) return false;
  final scheme = uri.scheme.toLowerCase();
  if (scheme == 'wss') return true;
  if (scheme == 'ws') return isLoopbackHost(uri.host);
  return false;
}

/// Normalizes a relay URL for identity comparison in UI state.
///
/// Delegates to the connection-layer normalizer so Settings identity checks
/// cannot drift from persisted relay identity.
String? normalizeRelayUrlForComparison(String url) =>
    nostr_client.normalizeRelayUrl(url);

/// True when [a] and [b] identify the same relay endpoint.
bool relayUrlsEquivalent(String a, String b) {
  final normalizedA = normalizeRelayUrlForComparison(a);
  final normalizedB = normalizeRelayUrlForComparison(b);
  return normalizedA != null &&
      normalizedB != null &&
      normalizedA == normalizedB;
}

/// Convert a relay WebSocket URL to an HTTP(S) base URL.
///
/// Examples:
/// - `wss://relay.divine.video` -> `https://relay.divine.video`
/// - `ws://localhost:8080` -> `http://localhost:8080`
String relayWsToHttpBase(String relayUrl) {
  if (relayUrl.startsWith('wss://')) {
    return relayUrl.replaceFirst('wss://', 'https://');
  }
  if (relayUrl.startsWith('ws://')) {
    return relayUrl.replaceFirst('ws://', 'http://');
  }
  return relayUrl;
}

/// Resolve the REST API base URL from configured relays with fallback.
///
/// Selection order:
/// 1) `preferredRelayHost` if present in configured relays (default: relay.divine.video)
/// 2) first configured relay
/// 3) provided `fallbackBaseUrl` (usually environment config)
String resolveApiBaseUrlFromRelays({
  required List<String> configuredRelays,
  required String fallbackBaseUrl,
  String preferredRelayHost = _divineRelayHost,
}) {
  if (configuredRelays.isEmpty) return fallbackBaseUrl;

  final preferred = configuredRelays.where((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == preferredRelayHost.toLowerCase();
  });

  final selectedRelay = preferred.isNotEmpty
      ? preferred.first
      : configuredRelays.first;

  final selectedHost = Uri.tryParse(selectedRelay)?.host.toLowerCase();
  if (selectedHost == _divineRelayHost) {
    return _divineApiBaseUrl;
  }

  return relayWsToHttpBase(selectedRelay);
}

/// Resolve a pinned REST API base URL from configured relays.
///
/// Unlike [resolveApiBaseUrlFromRelays], this never falls through to an
/// arbitrary configured relay. If the environment fallback host is configured,
/// that host wins first so staging/local builds do not drift to a persisted
/// production relay. If neither the fallback host nor pinned relay host is
/// configured, it returns the provided environment fallback instead.
String resolvePinnedApiBaseUrlFromRelays({
  required List<String> configuredRelays,
  required String fallbackBaseUrl,
  String pinnedRelayHost = _divineRelayHost,
}) {
  final fallbackHost = Uri.tryParse(fallbackBaseUrl)?.host.toLowerCase();
  if (fallbackHost != null && fallbackHost.isNotEmpty) {
    final fallbackRelay = configuredRelays.where((url) {
      final host = Uri.tryParse(url)?.host.toLowerCase();
      return host == fallbackHost;
    });
    if (fallbackRelay.isNotEmpty) {
      return relayWsToHttpBase(fallbackRelay.first);
    }
  }

  final pinnedRelay = configuredRelays.where((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == pinnedRelayHost.toLowerCase();
  });

  if (pinnedRelay.isEmpty) {
    return fallbackBaseUrl;
  }

  return relayWsToHttpBase(pinnedRelay.first);
}
