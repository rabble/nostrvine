// ABOUTME: Relay & connection-status Riverpod providers split from app_providers.dart
// ABOUTME: Connection monitoring, relay capability, statistics, and the two app-shell
// ABOUTME: side-effect bridges that translate Nostr-relay state into local stats and resets

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nostr_client/nostr_client.dart'
    show NostrClient, RelayConnectionStatus, RelayState;
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/video_providers.dart';
import 'package:openvine/services/connection_status_service.dart';
import 'package:openvine/services/relay_capability_service.dart';
import 'package:openvine/services/relay_statistics_service.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:unified_logger/unified_logger.dart';

part 'relay_providers.g.dart';

/// Current configured relay URLs, including the environment default relay.
///
/// Updated by [relaySetChangeBridge] from the active relay status map so UI
/// that only needs the relay set can react without constructing its own client.
final configuredRelayUrlsProvider =
    NotifierProvider<ConfiguredRelayUrls, List<String>>(
      ConfiguredRelayUrls.new,
    );

class ConfiguredRelayUrls extends Notifier<List<String>> {
  @override
  List<String> build() => const <String>[];

  void setUrls(List<String> urls) {
    state = List.unmodifiable(urls);
  }
}

final _relaySetChangeCoordinatorProvider = Provider<_RelaySetChangeCoordinator>(
  (ref) {
    final coordinator = _RelaySetChangeCoordinator();
    ref.onDispose(coordinator.dispose);
    return coordinator;
  },
);

class _RelaySetChangeCoordinator {
  Timer? _debounceTimer;
  NostrClient? _activeClient;
  VideoEventService? _videoEventService;
  NostrInitializationInProgress? _initializationTracker;
  NostrClient? _intentSourceClient;
  NostrClient? _reconcilingClient;
  Set<String>? _targetRelaySet;
  var _resetRequired = false;
  var _disposed = false;

  void attach({
    required NostrClient client,
    required VideoEventService videoEventService,
    required NostrInitializationInProgress initializationTracker,
  }) {
    _activeClient = client;
    _videoEventService = videoEventService;
    _initializationTracker = initializationTracker;
  }

  bool isReconciling(NostrClient client) {
    return identical(_reconcilingClient, client);
  }

  bool isClientInitializing(NostrClient client) {
    return !client.isInitialized ||
        (_initializationTracker?.isClientInitializing(client) ?? false);
  }

  void recordMembershipChange({
    required NostrClient client,
    required Set<String> previousRelaySet,
    required Set<String> currentRelaySet,
    required bool changeRequiresReset,
  }) {
    if (_disposed || isReconciling(client)) return;

    if (!_resetRequired) {
      if (!changeRequiresReset) {
        Log.info(
          'Relay set change originated during active client initialization; '
          'skipping forced reconnect '
          '(relayCount=${currentRelaySet.length})',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
        return;
      }
      _resetRequired = true;
      _intentSourceClient = client;
      _targetRelaySet = Set.of(currentRelaySet);
    } else if (identical(_intentSourceClient, client)) {
      // Keep the latest complete target from the client where the reset intent
      // originated. Startup-stage changes from that same generation belong to
      // the batch but cannot clear its sticky reset requirement.
      _targetRelaySet = Set.of(currentRelaySet);
    } else if (changeRequiresReset) {
      // A real edit can race with replacement. Merge its delta into the target
      // retained from the previous generation instead of replacing that target
      // with the replacement's potentially stale startup snapshot.
      final target = _targetRelaySet ?? <String>{};
      target
        ..removeAll(previousRelaySet.difference(currentRelaySet))
        ..addAll(currentRelaySet.difference(previousRelaySet));
      _targetRelaySet = target;
    } else {
      // Ignore startup-only membership snapshots from a replacement client.
      // The retained target is reconciled onto it when the debounce fires.
      return;
    }

    _scheduleReset();
  }

  void _scheduleReset() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(seconds: 2), () {
      unawaited(_performReset());
    });
  }

  Future<void> _performReset() async {
    if (_disposed || !_resetRequired) return;

    final client = _activeClient;
    final videoEventService = _videoEventService;
    final targetRelaySet = _targetRelaySet;
    if (client == null || videoEventService == null || targetRelaySet == null) {
      return;
    }

    if (isClientInitializing(client)) {
      Log.info(
        'Active client initialization overlaps relay reset debounce; '
        'deferring forced reconnect (relayCount=${targetRelaySet.length})',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );
      _scheduleReset();
      return;
    }

    final sourceClient = _intentSourceClient;
    _resetRequired = false;
    _intentSourceClient = null;
    _targetRelaySet = null;
    _reconcilingClient = client;

    try {
      if (!identical(sourceClient, client)) {
        await _reconcileRelaySet(client, targetRelaySet);
      }

      Log.info(
        'Debounce elapsed - forcing WebSocket reconnection and feed reset',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );

      try {
        await client.forceReconnectAll();
        Log.info(
          'Successfully reconnected all relay WebSockets',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
      } catch (e) {
        Log.error(
          'Failed to reconnect relays: $e',
          name: 'RelaySetChangeBridge',
          category: LogCategory.relay,
        );
      }

      await videoEventService.resetAndResubscribeAll();
    } finally {
      if (identical(_reconcilingClient, client)) {
        _reconcilingClient = null;
      }
    }
  }

  Future<void> _reconcileRelaySet(
    NostrClient client,
    Set<String> targetRelaySet,
  ) async {
    try {
      final currentRelaySet = client.configuredRelays.toSet();
      final additions = targetRelaySet.difference(currentRelaySet).toList();
      final removals = currentRelaySet.difference(targetRelaySet).toList();

      if (additions.isNotEmpty) {
        await client.addRelays(additions);
      }
      for (final relay in removals) {
        await client.removeRelay(relay);
      }
    } catch (e) {
      Log.error(
        'Failed to reconcile replacement relay set: $e',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );
    }
  }

  void dispose() {
    _disposed = true;
    _debounceTimer?.cancel();
  }
}

/// Connection status service for monitoring network connectivity
@Riverpod(keepAlive: true)
ConnectionStatusService connectionStatusService(Ref ref) {
  final service = ConnectionStatusService();
  ref.onDispose(service.dispose);
  return service;
}

/// Relay capability service for detecting NIP-11 Divine extensions
@Riverpod(keepAlive: true)
RelayCapabilityService relayCapabilityService(Ref ref) {
  final service = RelayCapabilityService();
  ref.onDispose(service.dispose);
  return service;
}

/// Relay statistics service for tracking per-relay metrics
@Riverpod(keepAlive: true)
RelayStatisticsService relayStatisticsService(Ref ref) {
  final service = RelayStatisticsService();
  ref.onDispose(service.dispose);
  return service;
}

/// Stream provider for reactive relay statistics updates
/// Use this provider when you need UI to rebuild when statistics change
@riverpod
Stream<Map<String, RelayStatistics>> relayStatisticsStream(Ref ref) async* {
  final service = ref.watch(relayStatisticsServiceProvider);

  // Emit current state immediately
  yield service.getAllStatistics();

  // Create a stream controller to emit updates on notifyListeners
  final controller = StreamController<Map<String, RelayStatistics>>();

  void listener() {
    if (!controller.isClosed) {
      controller.add(service.getAllStatistics());
    }
  }

  service.addListener(listener);
  ref.onDispose(() {
    service.removeListener(listener);
    controller.close();
  });

  yield* controller.stream;
}

/// Bridge provider that connects NostrClient relay status updates to
/// RelayStatisticsService.
///
/// Tracks connection/disconnection events via the relay status stream and
/// periodically syncs per-relay SDK counters (events received, queries sent,
/// errors) so each relay displays its own real statistics.
///
/// Must be watched at app level to activate the bridge.
@Riverpod(keepAlive: true)
void relayStatisticsBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final statsService = ref.watch(relayStatisticsServiceProvider);

  // Track previous states to detect connection changes
  final Map<String, bool> previousStates = {};

  // Helper to process status updates (used for both initial state and stream)
  void processStatuses(Map<String, RelayConnectionStatus> statuses) {
    for (final entry in statuses.entries) {
      final url = entry.key;
      final status = entry.value;
      final wasConnected = previousStates[url] ?? false;
      final isConnected =
          status.isConnected || status.state == RelayState.authenticated;

      // Only record changes to avoid excessive updates
      if (isConnected && !wasConnected) {
        statsService.recordConnection(url);
      } else if (!isConnected && wasConnected) {
        statsService.recordDisconnection(url, reason: status.errorMessage);
      }

      previousStates[url] = isConnected;
    }

    // Prune entries for relays no longer in the status map
    previousStates.removeWhere((url, _) => !statuses.containsKey(url));
  }

  // Process current state immediately (relays may have connected before
  // the bridge started)
  processStatuses(nostrService.relayStatuses);

  // Listen to relay status stream for future connection changes
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  // Periodically sync per-relay SDK counters so each relay shows its own
  // real statistics (not identical values distributed from app-level totals).
  final syncTimer = Timer.periodic(const Duration(seconds: 3), (_) {
    final counters = nostrService.getRelayPoolCounters();
    for (final entry in counters.entries) {
      statsService.syncSdkCounters(
        entry.key,
        eventsReceived: entry.value.eventsReceived,
        queriesSent: entry.value.queriesSent,
        errors: entry.value.errors,
      );
    }
  });

  ref.onDispose(() {
    syncTimer.cancel();
    subscription.cancel();
  });
}

/// Bridge provider that detects when the configured relay set changes
/// (relays added or removed) and triggers a full feed reset+resubscribe.
/// Debounces for 2 seconds to collapse rapid add/remove operations.
/// Only reacts to set membership changes, not connection state flapping.
@Riverpod(keepAlive: true)
void relaySetChangeBridge(Ref ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  final videoEventService = ref.watch(videoEventServiceProvider);
  final coordinator = ref.watch(_relaySetChangeCoordinatorProvider);

  Set<String> previousRelaySet = nostrService.relayStatuses.keys.toSet();
  var disposed = false;
  final initializationTracker = ref.read(
    nostrInitializationInProgressProvider.notifier,
  );
  coordinator.attach(
    client: nostrService,
    videoEventService: videoEventService,
    initializationTracker: initializationTracker,
  );

  void processStatuses(Map<String, RelayConnectionStatus> statuses) {
    ref
        .read(configuredRelayUrlsProvider.notifier)
        .setUrls(statuses.keys.toList(growable: false));

    final currentRelaySet = statuses.keys.toSet();

    // Only trigger if the set of relay URLs has changed (not just status)
    if (!_setsEqual(currentRelaySet, previousRelaySet)) {
      Log.info(
        'Relay set changed: '
        '${previousRelaySet.length} -> ${currentRelaySet.length} relays',
        name: 'RelaySetChangeBridge',
        category: LogCategory.relay,
      );

      final priorRelaySet = previousRelaySet;
      previousRelaySet = currentRelaySet;

      if (coordinator.isReconciling(nostrService)) {
        return;
      }

      final changeRequiresReset = !coordinator.isClientInitializing(
        nostrService,
      );

      // Debounce: collapse rapid changes into a single reset
      coordinator.recordMembershipChange(
        client: nostrService,
        previousRelaySet: priorRelaySet,
        currentRelaySet: currentRelaySet,
        changeRequiresReset: changeRequiresReset,
      );
    }
  }

  // Publish the initial relay set after provider initialization. Riverpod
  // disallows mutating another provider while this bridge is building.
  Timer.run(() {
    if (disposed) return;
    ref
        .read(configuredRelayUrlsProvider.notifier)
        .setUrls(nostrService.relayStatuses.keys.toList(growable: false));
  });

  // Listen to relay status stream for future updates
  final subscription = nostrService.relayStatusStream.listen(processStatuses);

  ref.onDispose(() {
    disposed = true;
    subscription.cancel();
  });
}

/// Helper to compare two sets for equality
bool _setsEqual<T>(Set<T> a, Set<T> b) {
  if (a.length != b.length) return false;
  return a.containsAll(b);
}

/// Force-reconnects the relay pool whenever `connectivity_plus` reports the
/// network returning, so a pool that collapsed to zero connections during an
/// offline window self-heals app-wide — not only on an app-foreground
/// transition (#3161). Debounced so a burst of connectivity events collapses
/// into one reconnect. keepAlive with no UI consumer: read eagerly at app
/// shell startup so the subscription is wired.
final connectivityRelayReconnectProvider = Provider<void>((ref) {
  final nostrService = ref.watch(nostrServiceProvider);
  Timer? debounce;
  final subscription = Connectivity().onConnectivityChanged
      .where((results) => results.any((r) => r != ConnectivityResult.none))
      .listen((_) {
        debounce?.cancel();
        debounce = Timer(const Duration(seconds: 2), () async {
          try {
            await nostrService.forceReconnectAll();
            Log.info(
              'Reconnected relays after connectivity returned',
              name: 'ConnectivityRelayReconnect',
              category: LogCategory.relay,
            );
          } catch (e) {
            Log.error(
              'connectivity-triggered relay reconnect failed: $e',
              name: 'ConnectivityRelayReconnect',
              category: LogCategory.relay,
            );
          }
        });
      });
  ref.onDispose(() {
    debounce?.cancel();
    subscription.cancel();
  });
});
