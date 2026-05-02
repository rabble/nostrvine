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
const _loopbackHosts = <String>{
  'localhost',
  '127.0.0.1',
  '10.0.2.2',
  '::1',
};

/// True if [host] is a recognized loopback address that may be reached over
/// cleartext (`ws://` / `http://`).
bool isLoopbackHost(String host) => _loopbackHosts.contains(host.toLowerCase());

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
/// arbitrary configured relay. If the pinned relay host is not configured, it
/// returns the provided environment fallback instead.
String resolvePinnedApiBaseUrlFromRelays({
  required List<String> configuredRelays,
  required String fallbackBaseUrl,
  String pinnedRelayHost = _divineRelayHost,
}) {
  final pinnedRelay = configuredRelays.where((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == pinnedRelayHost.toLowerCase();
  });

  if (pinnedRelay.isEmpty) {
    return fallbackBaseUrl;
  }

  return relayWsToHttpBase(pinnedRelay.first);
}
