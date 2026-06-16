// ABOUTME: Helpers for resolving API base URLs from Nostr relay WebSocket URLs.
// ABOUTME: Keeps REST endpoints aligned with active relay configuration.

const _divineRelayHost = 'relay.divine.video';
const _divineApiBaseUrl = 'https://api.divine.video';

/// Hosts allowed to use cleartext (`ws://` / `http://`) schemes.
///
/// Mirrors the loopback allowlist enforced by `network_security_config.xml`
/// (Android), `NSAllowsLocalNetworking` (iOS/macOS), and the local Docker
/// stack address `localHost` from `mobile/lib/models/environment_config.dart`.
/// Any change here must be reflected in:
///
///  * `mobile/android/app/src/main/res/xml/network_security_config.xml`
///  * `mobile/packages/nostr_sdk/lib/nip46/nostr_remote_signer_info.dart`
///  * `mobile/packages/nostr_client/lib/src/relay_manager.dart`
const _loopbackHosts = <String>{'localhost', '127.0.0.1', '10.0.2.2', '::1'};

/// True if [host] is a recognized loopback address that may be reached over
/// cleartext (`ws://` / `http://`).
bool isLoopbackHost(String host) => _loopbackHosts.contains(host.toLowerCase());

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
/// host is rejected. This matches the acceptance rule enforced by
/// `RelayManager._normalizeUrl` in `nostr_client`, so the predicate doubles
/// as the upstream "is this URL a usable relay endpoint" check.
///
/// This predicate is the single source of truth for the application-layer
/// transport allowlist. The package layer (`nostr_sdk`, `nostr_client`)
/// duplicates this rule in-package because those packages cannot import from
/// `mobile/lib/`; any change here must be mirrored there.
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
