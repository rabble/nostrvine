// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'relay_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Connection status service for monitoring network connectivity

@ProviderFor(connectionStatusService)
const connectionStatusServiceProvider = ConnectionStatusServiceProvider._();

/// Connection status service for monitoring network connectivity

final class ConnectionStatusServiceProvider
    extends
        $FunctionalProvider<
          ConnectionStatusService,
          ConnectionStatusService,
          ConnectionStatusService
        >
    with $Provider<ConnectionStatusService> {
  /// Connection status service for monitoring network connectivity
  const ConnectionStatusServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'connectionStatusServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$connectionStatusServiceHash();

  @$internal
  @override
  $ProviderElement<ConnectionStatusService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  ConnectionStatusService create(Ref ref) {
    return connectionStatusService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ConnectionStatusService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ConnectionStatusService>(value),
    );
  }
}

String _$connectionStatusServiceHash() =>
    r'30fc9602e77f81edd6e26b19f6e36e0c82a02353';

/// Relay capability service for detecting NIP-11 Divine extensions

@ProviderFor(relayCapabilityService)
const relayCapabilityServiceProvider = RelayCapabilityServiceProvider._();

/// Relay capability service for detecting NIP-11 Divine extensions

final class RelayCapabilityServiceProvider
    extends
        $FunctionalProvider<
          RelayCapabilityService,
          RelayCapabilityService,
          RelayCapabilityService
        >
    with $Provider<RelayCapabilityService> {
  /// Relay capability service for detecting NIP-11 Divine extensions
  const RelayCapabilityServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayCapabilityServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayCapabilityServiceHash();

  @$internal
  @override
  $ProviderElement<RelayCapabilityService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayCapabilityService create(Ref ref) {
    return relayCapabilityService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayCapabilityService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayCapabilityService>(value),
    );
  }
}

String _$relayCapabilityServiceHash() =>
    r'99f5caa2c958c29928c911ef3c747961279ce8cc';

/// Relay statistics service for tracking per-relay metrics

@ProviderFor(relayStatisticsService)
const relayStatisticsServiceProvider = RelayStatisticsServiceProvider._();

/// Relay statistics service for tracking per-relay metrics

final class RelayStatisticsServiceProvider
    extends
        $FunctionalProvider<
          RelayStatisticsService,
          RelayStatisticsService,
          RelayStatisticsService
        >
    with $Provider<RelayStatisticsService> {
  /// Relay statistics service for tracking per-relay metrics
  const RelayStatisticsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayStatisticsServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayStatisticsServiceHash();

  @$internal
  @override
  $ProviderElement<RelayStatisticsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  RelayStatisticsService create(Ref ref) {
    return relayStatisticsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(RelayStatisticsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<RelayStatisticsService>(value),
    );
  }
}

String _$relayStatisticsServiceHash() =>
    r'3343641d19897bc7431645b760b90f115afc827d';

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change

@ProviderFor(relayStatisticsStream)
const relayStatisticsStreamProvider = RelayStatisticsStreamProvider._();

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change

final class RelayStatisticsStreamProvider
    extends
        $FunctionalProvider<
          AsyncValue<Map<String, RelayStatistics>>,
          Map<String, RelayStatistics>,
          Stream<Map<String, RelayStatistics>>
        >
    with
        $FutureModifier<Map<String, RelayStatistics>>,
        $StreamProvider<Map<String, RelayStatistics>> {
  /// Stream provider for reactive relay statistics updates
  /// Use this provider when you need UI to rebuild when statistics change
  const RelayStatisticsStreamProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayStatisticsStreamProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayStatisticsStreamHash();

  @$internal
  @override
  $StreamProviderElement<Map<String, RelayStatistics>> $createElement(
    $ProviderPointer pointer,
  ) => $StreamProviderElement(pointer);

  @override
  Stream<Map<String, RelayStatistics>> create(Ref ref) {
    return relayStatisticsStream(ref);
  }
}

String _$relayStatisticsStreamHash() =>
    r'0ab9617467aabccc62b36b0de4d79a0ce9d01c5e';

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Must be watched at app level to activate the bridge.

@ProviderFor(relayStatisticsBridge)
const relayStatisticsBridgeProvider = RelayStatisticsBridgeProvider._();

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Must be watched at app level to activate the bridge.

final class RelayStatisticsBridgeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Bridge provider that connects NostrClient relay status updates to
  /// RelayStatisticsService.
  ///
  /// Tracks connection/disconnection events via the relay status stream and
  /// periodically syncs per-relay SDK counters (events received, queries sent,
  /// errors) so each relay displays its own real statistics.
  ///
  /// Must be watched at app level to activate the bridge.
  const RelayStatisticsBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relayStatisticsBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relayStatisticsBridgeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return relayStatisticsBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$relayStatisticsBridgeHash() =>
    r'4c105f2e370e769b48b77ac90ca08bca6f95a385';

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.

@ProviderFor(relaySetChangeBridge)
const relaySetChangeBridgeProvider = RelaySetChangeBridgeProvider._();

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.

final class RelaySetChangeBridgeProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Bridge provider that detects when the configured relay set changes
  /// (relays added or removed) and triggers a full feed reset+resubscribe.
  /// Debounces for 2 seconds to collapse rapid add/remove operations.
  /// Only reacts to set membership changes, not connection state flapping.
  const RelaySetChangeBridgeProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'relaySetChangeBridgeProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$relaySetChangeBridgeHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return relaySetChangeBridge(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$relaySetChangeBridgeHash() =>
    r'a7a24101b27fb9a1722c4e22982bb63ec89c1adb';
