import 'package:nostr_sdk/nostr_sdk.dart';

/// {@template nostr_client_config}
/// Configuration for NostrClient initialization
/// {@endtemplate}
class NostrClientConfig {
  /// {@macro nostr_client_config}
  const NostrClientConfig({
    required this.signer,
    this.eventFilters = const [],
    this.onNotice,
    this.gatewayUrl,
    this.enableGateway = false,
    this.webSocketChannelFactory,
  });

  /// Signer for event signing - the single source of truth for the public key.
  ///
  /// The public key is derived from the signer via [NostrSigner.getPublicKey]
  final NostrSigner signer;

  /// Event filters for initial subscriptions
  final List<EventFilter> eventFilters;

  /// Callback for relay notices
  final void Function(String, String)? onNotice;

  /// Gateway URL (if using gateway)
  final String? gatewayUrl;

  /// Whether to enable gateway support
  final bool enableGateway;

  /// WebSocket channel factory for testing (optional)
  final WebSocketChannelFactory? webSocketChannelFactory;
}
