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
    this.eventVerifyWorkerSpawner,
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

  /// Optional spawner for the off-main relay-event verify isolate (#5863).
  ///
  /// When provided, `NostrClient.initialize` spawns it and wires it into the
  /// relay pool so inbound-event signature verification runs off the main
  /// isolate. When null (tests, web), verification runs inline on the main
  /// isolate exactly as before. The app passes `EventVerifyIsolate.spawn`.
  final EventVerifyWorkerSpawner? eventVerifyWorkerSpawner;
}
