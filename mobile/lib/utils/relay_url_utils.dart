// ABOUTME: Helpers for resolving API base URLs from Nostr relay WebSocket URLs.
// ABOUTME: Keeps REST endpoints aligned with active relay configuration.

const _divineRelayHost = 'relay.divine.video';
const _divineApiBaseUrl = 'https://api.divine.video';

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
