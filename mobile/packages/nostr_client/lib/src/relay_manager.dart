// ABOUTME: Manages relay configuration, connections, and status for the app.
// ABOUTME: Wraps RelayPool to provide persistence, status streams, clean API.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:meta/meta.dart';
import 'package:nostr_client/src/models/relay_connection_status.dart';
import 'package:nostr_client/src/models/relay_manager_config.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';

/// {@template relay_manager}
/// Manages relay configuration and connection status.
///
/// Provides:
/// - Configured vs connected relay distinction
/// - Persistence of relay configuration
/// - Reactive status streams for UI binding
/// - Default relay handling
///
/// This class wraps [RelayPool] from nostr_sdk and adds app-level
/// functionality like persistence and reactive status updates.
/// {@endtemplate}
class RelayManager {
  /// {@macro relay_manager}
  RelayManager({
    required RelayManagerConfig config,
    required RelayPool relayPool,
    @visibleForTesting Relay Function(String url)? relayFactory,
  }) : _config = config,
       _relayPool = relayPool,
       _relayFactory = relayFactory;

  /// Known-dead relays that should never be added.
  ///
  /// These relays have DNS failures or are permanently offline.
  /// Adding them causes connection errors and degrades UX.
  /// Users may have these in their NIP-65 relay lists, so we filter them out.
  static const Set<String> _blockedRelayHosts = {
    'index.coracle.social', // DNS dead since ~2024
  };

  /// Check if a relay URL is blocked
  static bool _isBlockedRelay(String url) {
    try {
      final uri = Uri.parse(url);
      return _blockedRelayHosts.contains(uri.host);
    } on FormatException {
      return false;
    }
  }

  final RelayManagerConfig _config;
  final RelayPool _relayPool;
  final Relay Function(String url)? _relayFactory;

  /// Configured relay URLs (user's list, persisted)
  final List<String> _configuredRelays = [];

  /// Status for each relay
  final Map<String, RelayConnectionStatus> _relayStatuses = {};

  /// Stream controller for status updates
  final _statusController =
      StreamController<Map<String, RelayConnectionStatus>>.broadcast();

  /// Timer for periodic status polling
  Timer? _statusPollTimer;

  /// Whether the manager has been initialized
  bool _initialized = false;

  // ---------------------------------------------------------------------------
  // Public Getters
  // ---------------------------------------------------------------------------

  /// The default relay URL that cannot be removed
  String get defaultRelayUrl => _config.defaultRelayUrl;

  /// List of relay URLs the user has configured (including default)
  List<String> get configuredRelays => List.unmodifiable(_configuredRelays);

  /// List of relay URLs currently connected
  ///
  /// Uses the internal status tracking which is updated synchronously after
  /// successful connection
  List<String> get connectedRelays {
    return _configuredRelays.where((url) {
      final status = _relayStatuses[url];
      return status != null && status.isConnected;
    }).toList();
  }

  /// Number of configured relays
  int get configuredRelayCount => _configuredRelays.length;

  /// Number of connected relays
  int get connectedRelayCount => connectedRelays.length;

  /// Whether at least one relay is connected
  bool get hasConnectedRelay => connectedRelayCount > 0;

  /// Stream of relay status updates for UI binding
  Stream<Map<String, RelayConnectionStatus>> get statusStream =>
      _statusController.stream;

  /// Current status map (snapshot)
  Map<String, RelayConnectionStatus> get currentStatuses =>
      Map.unmodifiable(_relayStatuses);

  /// Whether the manager has been initialized
  bool get isInitialized => _initialized;

  // ---------------------------------------------------------------------------
  // Initialization
  // ---------------------------------------------------------------------------

  /// Initialize the relay manager
  ///
  /// Loads persisted relay configuration and connects to all configured relays.
  /// If no relays are persisted, uses the default relay.
  Future<void> initialize() async {
    if (_initialized) {
      _log('Already initialized');
      return;
    }

    _log('Initializing RelayManager');

    // Load persisted relays
    final storage = _config.storage;
    if (storage != null) {
      final savedRelays = await storage.loadRelays();
      // Normalize loaded relays and filter out blocked/duplicate relays
      var blockedCount = 0;
      for (final url in savedRelays) {
        final normalized = _normalizeUrl(url);
        if (normalized == null) continue;
        if (_isBlockedRelay(normalized)) {
          blockedCount++;
          continue;
        }
        if (!_configuredRelays.contains(normalized)) {
          _configuredRelays.add(normalized);
        }
      }
      if (blockedCount > 0) {
        _log('Filtered $blockedCount blocked relays from storage');
        // Persist the filtered list so blocked relays are permanently removed
        await storage.saveRelays(_configuredRelays);
        _log('Saved filtered relay list to storage');
      }
      _log('Loaded ${_configuredRelays.length} relays from storage');
    }

    // Ensure default relay is always included
    // (uses normalized URL for comparison)
    final normalizedDefault = _normalizeUrl(_config.defaultRelayUrl);
    if (normalizedDefault != null &&
        !_configuredRelays.contains(normalizedDefault)) {
      _configuredRelays.insert(0, normalizedDefault);
      _log('Added default relay: $normalizedDefault');
    }

    // Initialize status for all configured relays
    for (final url in _configuredRelays) {
      _relayStatuses[url] = RelayConnectionStatus.disconnected(
        url,
        isDefault: url == normalizedDefault,
      );
    }

    // Connect to all configured relays
    await _connectToConfiguredRelays();

    // Start status polling
    _startStatusPolling();

    _initialized = true;
    _notifyStatusChange();
    _log('RelayManager initialized with ${_configuredRelays.length} relays');
  }

  // ---------------------------------------------------------------------------
  // Relay Management
  // ---------------------------------------------------------------------------

  /// Add a relay to the configuration and connect to it
  ///
  /// Returns true if the relay was added and connected successfully.
  /// Returns false if the relay URL is invalid, blocked, or already configured.
  Future<bool> addRelay(String url) async {
    final normalizedUrl = _normalizeUrl(url);

    if (normalizedUrl == null) {
      _log('Invalid relay URL: $url');
      return false;
    }

    // Block known-dead relays
    if (_isBlockedRelay(normalizedUrl)) {
      _log('Blocked dead relay: $normalizedUrl');
      return false;
    }

    if (_configuredRelays.contains(normalizedUrl)) {
      _log('Relay already configured: $normalizedUrl');
      return false;
    }

    _log('Adding relay: $normalizedUrl');

    // Add to configured list
    _configuredRelays.add(normalizedUrl);

    // Initialize status
    _relayStatuses[normalizedUrl] = RelayConnectionStatus.connecting(
      normalizedUrl,
    );
    _notifyStatusChange();

    // Connect to the relay
    final success = await _connectToRelay(normalizedUrl);

    // Update status based on connection result
    if (success) {
      _updateRelayStatus(normalizedUrl, RelayState.connected);
    } else {
      _updateRelayStatus(
        normalizedUrl,
        RelayState.error,
        errorMessage: 'Failed to connect',
      );
    }
    _notifyStatusChange();

    // Persist configuration
    await _saveConfiguration();

    return success;
  }

  /// Remove a relay from the configuration
  ///
  /// Returns true if the relay was removed.
  /// Returns false if the relay URL is invalid or not configured.
  Future<bool> removeRelay(String url) async {
    final normalizedUrl = _normalizeUrl(url);

    if (normalizedUrl == null) {
      _log('Invalid relay URL: $url');
      return false;
    }

    if (!_configuredRelays.contains(normalizedUrl)) {
      _log('Relay not configured: $normalizedUrl');
      return false;
    }

    _log('Removing relay: $normalizedUrl');

    // Disconnect from the relay
    _relayPool.remove(normalizedUrl);

    // Remove from configured list and statuses
    _configuredRelays.remove(normalizedUrl);
    _relayStatuses.remove(normalizedUrl);

    // Persist configuration
    await _saveConfiguration();

    _notifyStatusChange();
    return true;
  }

  /// Check if a relay URL is configured
  bool isRelayConfigured(String url) {
    final normalizedUrl = _normalizeUrl(url);
    return normalizedUrl != null && _configuredRelays.contains(normalizedUrl);
  }

  /// Check if a relay is currently connected
  bool isRelayConnected(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) return false;

    final status = _relayStatuses[normalizedUrl];
    return status?.isConnected ?? false;
  }

  /// Get the status of a specific relay
  RelayConnectionStatus? getRelayStatus(String url) {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null) return null;
    return _relayStatuses[normalizedUrl];
  }

  // ---------------------------------------------------------------------------
  // Per-Relay SDK Counters
  // ---------------------------------------------------------------------------

  /// Returns per-relay counters from the SDK's [RelayStatus].
  ///
  /// These are the actual per-relay statistics tracked by the SDK:
  /// - `eventsReceived`: events received from this specific relay
  /// - `queriesSent`: queries/subscriptions sent to this specific relay
  /// - `errors`: error count for this specific relay
  Map<String, ({int eventsReceived, int queriesSent, int errors})>
  getRelayPoolCounters() {
    final result =
        <String, ({int eventsReceived, int queriesSent, int errors})>{};
    for (final url in _configuredRelays) {
      final relay = _relayPool.getRelay(url);
      if (relay != null) {
        result[url] = (
          eventsReceived: relay.relayStatus.noteReceived,
          queriesSent: relay.relayStatus.queryNum,
          errors: relay.relayStatus.error,
        );
      }
    }
    return result;
  }

  // ---------------------------------------------------------------------------
  // Reconnection
  // ---------------------------------------------------------------------------

  /// Retry connecting to all disconnected relays.
  ///
  /// Also checks for idle/dead connections (those that appear connected but
  /// haven't received messages recently) and disconnects them first.
  Future<void> retryDisconnectedRelays() async {
    _log('Retrying disconnected relays');

    // First, check health of all "connected" relays to detect dead connections
    _checkRelayHealth();

    final disconnected = _configuredRelays.where((url) {
      final status = _relayStatuses[url];
      return status != null && !status.isConnected;
    }).toList();

    for (final url in disconnected) {
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    for (final url in disconnected) {
      final success = await _connectToRelay(url);
      if (success) {
        _updateRelayStatus(url, RelayState.connected);
      } else {
        _updateRelayStatus(
          url,
          RelayState.error,
          errorMessage: 'Reconnection failed',
        );
      }
    }

    _notifyStatusChange();
  }

  /// Check health of all connected relays and disconnect any that are idle.
  ///
  /// This detects "zombie" connections that appear connected but have actually
  /// died silently (common with WebSockets after ~2 minutes of idle time).
  void _checkRelayHealth() {
    for (final url in _configuredRelays) {
      final relay = _relayPool.getRelay(url);
      if (relay == null) continue;

      // Check if the relay supports health checks (RelayBase)
      if (relay is RelayBase) {
        final healthy = relay.checkHealth();
        if (!healthy) {
          _log('Relay $url failed health check, marking as disconnected');
          _updateRelayStatus(url, RelayState.disconnected);
        }
      }
    }
  }

  /// Force reconnect all relays (disconnect first, then reconnect)
  ///
  /// Use this when WebSocket connections may have been silently dropped
  /// (e.g., after app backgrounding).
  Future<void> forceReconnectAll() async {
    _log('Force reconnecting all relays');

    // Create a copy to avoid concurrent modification during async iteration
    final relaysToReconnect = List<String>.from(_configuredRelays);

    // First disconnect all
    for (final url in relaysToReconnect) {
      _relayPool.remove(url);
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    // Then reconnect all
    for (final url in relaysToReconnect) {
      final success = await _connectToRelay(url);
      if (success) {
        _updateRelayStatus(url, RelayState.connected);
        _log('Force reconnected to $url');
      } else {
        _updateRelayStatus(
          url,
          RelayState.error,
          errorMessage: 'Force reconnection failed',
        );
        _log('Force reconnection failed for $url');
      }
    }

    _notifyStatusChange();
  }

  /// Reconnect to a specific relay
  Future<bool> reconnectRelay(String url) async {
    final normalizedUrl = _normalizeUrl(url);
    if (normalizedUrl == null || !_configuredRelays.contains(normalizedUrl)) {
      return false;
    }

    _log('Reconnecting to relay: $normalizedUrl');
    _updateRelayStatus(normalizedUrl, RelayState.connecting);
    _notifyStatusChange();

    // Disconnect first
    _relayPool.remove(normalizedUrl);

    // Reconnect
    final success = await _connectToRelay(normalizedUrl);

    if (success) {
      _updateRelayStatus(normalizedUrl, RelayState.connected);
    } else {
      _updateRelayStatus(
        normalizedUrl,
        RelayState.error,
        errorMessage: 'Reconnection failed',
      );
    }

    _notifyStatusChange();
    return success;
  }

  // ---------------------------------------------------------------------------
  // Disposal
  // ---------------------------------------------------------------------------

  /// Dispose of resources
  Future<void> dispose() async {
    _log('Disposing RelayManager');
    _statusPollTimer?.cancel();
    _statusPollTimer = null;
    await _statusController.close();
    _initialized = false;
  }

  // ---------------------------------------------------------------------------
  // Private Methods
  // ---------------------------------------------------------------------------

  Future<void> _connectToConfiguredRelays() async {
    // Create a copy to avoid concurrent modification during async iteration
    final relaysToConnect = List<String>.from(_configuredRelays);

    for (final url in relaysToConnect) {
      _updateRelayStatus(url, RelayState.connecting);
    }
    _notifyStatusChange();

    // Connect to all relays in PARALLEL instead of sequential.
    // This reduces startup from O(n * timeout) to O(max timeout).
    final results = await Future.wait(
      relaysToConnect.map((url) async {
        final success = await _connectToRelay(url);
        return MapEntry(url, success);
      }),
    );

    // Update statuses based on results
    for (final entry in results) {
      if (entry.value) {
        _updateRelayStatus(entry.key, RelayState.connected);
      } else {
        _updateRelayStatus(
          entry.key,
          RelayState.error,
          errorMessage: 'Failed to connect',
        );
      }
    }
    _notifyStatusChange();
  }

  Future<bool> _connectToRelay(String url) async {
    try {
      // Create relay instance
      Relay relay;
      if (_relayFactory != null) {
        relay = _relayFactory(url);
      } else {
        relay = RelayBase(
          url,
          RelayStatus(url),
          channelFactory: _config.webSocketChannelFactory,
        );
      }

      // Remove the old (possibly dead) relay from the pool first so that
      // add() doesn't short-circuit on a duplicate URL. Without this,
      // a stale relay object stays in the pool and no events flow through.
      _relayPool.remove(url);

      // Add to pool and connect – autoSubscribe ensures any active
      // subscriptions are resent to the newly connected relay so that
      // queries (e.g. follower counts) don't silently miss data.
      final success = await _relayPool.add(relay, autoSubscribe: true);
      _log('Connect to $url: ${success ? 'success' : 'failed'}');
      return success;
    } on Exception catch (e) {
      _log('Error connecting to $url: $e');
      return false;
    }
  }

  void _updateRelayStatus(
    String url,
    RelayState state, {
    String? errorMessage,
  }) {
    final current = _relayStatuses[url];
    if (current == null) return;

    final isError = state == RelayState.error;
    final newErrorCount = isError ? current.errorCount + 1 : 0;

    final lastConnected = state == RelayState.connected
        ? DateTime.now()
        : current.lastConnectedAt;

    _relayStatuses[url] = current.copyWith(
      state: state,
      errorCount: newErrorCount,
      errorMessage: errorMessage,
      lastConnectedAt: lastConnected,
      lastErrorAt: isError ? DateTime.now() : current.lastErrorAt,
    );
  }

  void _startStatusPolling() {
    _statusPollTimer?.cancel();
    _statusPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _syncStatusFromRelayPool();
    });
  }

  void _syncStatusFromRelayPool() {
    var changed = false;

    for (final url in _configuredRelays) {
      final relay = _relayPool.getRelay(url);
      final currentStatus = _relayStatuses[url];

      if (currentStatus == null) continue;

      RelayState newState;
      if (relay == null) {
        newState = RelayState.disconnected;
      } else {
        final connected = relay.relayStatus.connected;
        final authed = relay.relayStatus.authed;

        if (connected == ClientConnected.connected) {
          newState = authed ? RelayState.authenticated : RelayState.connected;
        } else if (connected == ClientConnected.connecting) {
          newState = RelayState.connecting;
        } else {
          newState = RelayState.disconnected;
        }
      }

      if (currentStatus.state != newState) {
        final isNowConnected =
            newState == RelayState.connected ||
            newState == RelayState.authenticated;
        final lastConnected = isNowConnected
            ? DateTime.now()
            : currentStatus.lastConnectedAt;

        _relayStatuses[url] = currentStatus.copyWith(
          state: newState,
          lastConnectedAt: lastConnected,
        );
        changed = true;
      }
    }

    if (changed) {
      _notifyStatusChange();
    }
  }

  void _notifyStatusChange() {
    if (!_statusController.isClosed) {
      _statusController.add(Map.from(_relayStatuses));
    }
  }

  Future<void> _saveConfiguration() async {
    final storage = _config.storage;
    if (storage != null) {
      await storage.saveRelays(_configuredRelays);
      _log('Saved ${_configuredRelays.length} relays to storage');
    }
  }

  String? _normalizeUrl(String url) {
    var normalized = url.trim();

    // Ensure wss:// prefix
    if (!normalized.startsWith('wss://') && !normalized.startsWith('ws://')) {
      normalized = 'wss://$normalized';
    }

    // Remove trailing slash
    if (normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }

    // Basic validation
    try {
      final uri = Uri.parse(normalized);
      if (uri.host.isEmpty) return null;
      return normalized;
    } on FormatException {
      return null;
    }
  }

  void _log(String message) {
    developer.log('[RelayManager] $message');
  }
}
