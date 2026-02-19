// ABOUTME: Helpers for resolving API base URLs from Nostr relay WebSocket URLs.
// ABOUTME: Keeps REST endpoints aligned with active relay configuration.

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
  String preferredRelayHost = 'relay.divine.video',
}) {
  if (configuredRelays.isEmpty) return fallbackBaseUrl;

  final preferred = configuredRelays.where((url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    return host == preferredRelayHost.toLowerCase();
  });

  final selectedRelay = preferred.isNotEmpty
      ? preferred.first
      : configuredRelays.first;

  return relayWsToHttpBase(selectedRelay);
}
