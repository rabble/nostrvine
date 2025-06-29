// ABOUTME: Unified NostrService using nostr_sdk's RelayPool with full relay management
// ABOUTME: Combines best features of v1 and v2 - SDK reliability with custom relay management

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/relay/relay_status.dart' as sdk;
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nip94_metadata.dart';
import '../utils/unified_logger.dart';
import 'nostr_key_manager.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';

/// Relay connection status
enum RelayStatus { connected, connecting, disconnected }

/// Exception for NostrService errors
class NostrServiceException implements Exception {
  final String message;
  NostrServiceException(this.message);
  
  @override
  String toString() => 'NostrServiceException: $message';
}

/// Unified NostrService implementation using nostr_sdk
class NostrService extends ChangeNotifier implements INostrService {
  static const List<String> defaultRelays = [
    'wss://vine.hol.is',
  ];
  
  static const String _relaysPrefsKey = 'custom_relays';
  
  final NostrKeyManager _keyManager;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  
  Nostr? _nostrClient;
  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _connectedRelays = [];
  final List<String> _relays = []; // All configured relays
  final Map<String, Relay> _relayInstances = {}; // Keep relay instances for management
  
  // Track active subscriptions for cleanup
  final Map<String, String> _activeSubscriptions = {}; // Our ID -> SDK subscription ID
  
  NostrService(this._keyManager);
  
  // INostrService implementation
  @override
  bool get isInitialized => _isInitialized && !_isDisposed;
  
  @override
  bool get isDisposed => _isDisposed;
  
  @override
  List<String> get connectedRelays => List.unmodifiable(_connectedRelays);
  
  @override
  String? get publicKey => _isDisposed ? null : _keyManager.publicKey;
  
  @override
  bool get hasKeys => _isDisposed ? false : _keyManager.hasKeys;
  
  @override
  NostrKeyManager get keyManager => _keyManager;
  
  @override
  int get relayCount => _connectedRelays.length;
  
  @override
  int get connectedRelayCount => _connectedRelays.length;
  
  List<String> get relays => List.unmodifiable(_relays);
  Map<String, dynamic> get relayStatuses {
    final statuses = <String, dynamic>{};
    for (final url in _relays) {
      final relay = _relayInstances[url];
      if (relay != null) {
        statuses[url] = relay.relayStatus.connected == ClientConneccted.CONNECTED ? 'connected' : 'disconnected';
      } else {
        statuses[url] = 'disconnected';
      }
    }
    return statuses;
  }
  
  @override
  Future<void> initialize({List<String>? customRelays}) async {
    if (_isInitialized) {
      Log.warning('⚠️ NostrService already initialized', category: LogCategory.relay);
      return;
    }
    
    try {
      // Initialize connection service
      await _connectionService.initialize();
      
      // Check connectivity
      if (!_connectionService.isOnline) {
        Log.warning('⚠️ Device appears to be offline', category: LogCategory.relay);
        throw NostrServiceException('Device is offline');
      }
      
      // Initialize key manager
      if (!_keyManager.isInitialized) {
        await _keyManager.initialize();
      }
      
      // Ensure we have keys
      if (!_keyManager.hasKeys) {
        Log.info('🔑 No keys found, generating new identity...', category: LogCategory.auth);
        await _keyManager.generateKeys();
      }
      
      // Get private key for signer
      final keyPair = _keyManager.keyPair;
      if (keyPair == null) {
        throw NostrServiceException('Failed to get key pair');
      }
      final privateKey = keyPair.private;
      
      // Create signer
      final signer = LocalNostrSigner(privateKey);
      
      // Get public key
      final pubKey = await signer.getPublicKey();
      if (pubKey == null) {
        throw NostrServiceException('Failed to get public key from signer');
      }
      
      // Load saved relays from preferences
      final prefs = await SharedPreferences.getInstance();
      final savedRelays = prefs.getStringList(_relaysPrefsKey);
      
      // Use saved relays, custom relays, or default relays (in that order)
      final relaysToConnect = savedRelays ?? customRelays ?? defaultRelays;
      _relays.clear();
      _relays.addAll(relaysToConnect);
      
      // Notify listeners about relay list
      notifyListeners();
      
      // Create event filters (we'll handle subscriptions manually)
      final eventFilters = <EventFilter>[];
      
      // Initialize Nostr client with relay factory
      _nostrClient = Nostr(
        signer,
        pubKey,
        eventFilters,
        (url) => RelayBase(url, sdk.RelayStatus(url)),
        onNotice: (relayUrl, notice) {
          Log.info('📢 Notice from $relayUrl: $notice', category: LogCategory.relay);
        },
      );
      
      // Add relays - let SDK handle all connection management
      for (final relayUrl in relaysToConnect) {
        try {
          final relay = RelayBase(relayUrl, sdk.RelayStatus(relayUrl));
          final success = await _nostrClient!.addRelay(relay, autoSubscribe: true);
          if (success) {
            _connectedRelays.add(relayUrl);
            _relayInstances[relayUrl] = relay;
            Log.info('✅ Connected to relay: $relayUrl', category: LogCategory.relay);
          } else {
            Log.error('Failed to connect to relay: $relayUrl', name: 'NostrService', category: LogCategory.relay);
          }
        } catch (e) {
          Log.error('Error connecting to relay $relayUrl: $e', name: 'NostrService', category: LogCategory.relay);
        }
      }
      
      if (_connectedRelays.isEmpty) {
        throw NostrServiceException('Failed to connect to any relays');
      }
      
      // Give relays time to fully establish connection and complete AUTH
      await Future.delayed(const Duration(seconds: 3));
      
      // Log final relay states
      final relays = _nostrClient!.activeRelays();
      for (final relay in relays) {
        _relayInstances[relay.url] = relay;
        Log.debug('Post-AUTH relay status for ${relay.url}:', name: 'NostrService', category: LogCategory.relay);
        Log.info('  - Connected: ${relay.relayStatus.connected == ClientConneccted.CONNECTED}', name: 'NostrService', category: LogCategory.relay);
        Log.debug('  - Authed: ${relay.relayStatus.authed}', name: 'NostrService', category: LogCategory.relay);
        Log.debug('  - Read access: ${relay.relayStatus.readAccess}', name: 'NostrService', category: LogCategory.relay);
        Log.debug('  - Write access: ${relay.relayStatus.writeAccess}', name: 'NostrService', category: LogCategory.relay);
      }
      
      _isInitialized = true;
      Log.info('NostrService initialized with ${_connectedRelays.length} relays', name: 'NostrService', category: LogCategory.relay);
      notifyListeners();
      
    } catch (e) {
      Log.error('Failed to initialize NostrService: $e', name: 'NostrService', category: LogCategory.relay);
      rethrow;
    }
  }
  
  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false, // Not needed in v2 - SDK handles limits
  }) {
    if (!_isInitialized) {
      throw NostrServiceException('Nostr service not initialized');
    }
    
    // Convert our Filter objects to SDK filter format
    final sdkFilters = filters.map((filter) => filter.toJson()).toList();
    
    // Create stream controller for this subscription
    final controller = StreamController<Event>.broadcast();
    
    // Generate unique subscription ID with more entropy to prevent collisions
    final subscriptionId = '${DateTime.now().millisecondsSinceEpoch}_${DateTime.now().microsecond}_${Object().hashCode}';
    
    Log.debug('Creating subscription $subscriptionId with filters:', name: 'NostrService', category: LogCategory.relay);
    for (final filter in sdkFilters) {
      Log.debug('  - Filter: $filter', name: 'NostrService', category: LogCategory.relay);
    }
    
    // Create subscription using SDK
    final sdkSubId = _nostrClient!.subscribe(
      sdkFilters,
      (Event event) {
        Log.debug('� Received event in NostrServiceV2 callback: kind=${event.kind}, id=${event.id.substring(0, 8)}...', name: 'NostrService', category: LogCategory.relay);
        // Forward events to our stream
        controller.add(event);
      },
      id: subscriptionId,
    );
    
    // Also listen to the raw relay pool to see if events are coming in
    Log.debug('Checking relay pool state...', name: 'NostrService', category: LogCategory.relay);
    final relays = _nostrClient!.activeRelays();
    for (final relay in relays) {
      Log.info('  - Relay ${relay.url}: connected=${relay.relayStatus.connected == ClientConneccted.CONNECTED}, authed=${relay.relayStatus.authed}', name: 'NostrService', category: LogCategory.relay);
    }
    
    // Track subscription for cleanup
    _activeSubscriptions[subscriptionId] = sdkSubId;
    
    Log.info('Created subscription $subscriptionId (SDK ID: $sdkSubId) with ${filters.length} filters', name: 'NostrService', category: LogCategory.relay);
    
    // Handle stream cancellation
    controller.onCancel = () {
      final sdkId = _activeSubscriptions.remove(subscriptionId);
      if (sdkId != null) {
        _nostrClient?.unsubscribe(sdkId);
      }
    };
    
    return controller.stream;
  }
  
  @override
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    if (!_isInitialized || !hasKeys) {
      throw NostrServiceException('NostrService not initialized or no keys available');
    }
    
    try {
      // Sign and send event using SDK
      final sentEvent = await _nostrClient!.sendEvent(event);
      
      if (sentEvent != null) {
        // SDK doesn't provide per-relay results, so we'll assume success
        final results = <String, bool>{};
        final errors = <String, String>{};
        
        for (final relay in _connectedRelays) {
          results[relay] = true;
        }
        
        return NostrBroadcastResult(
          event: sentEvent,
          successCount: _connectedRelays.length,
          totalRelays: _connectedRelays.length,
          results: results,
          errors: errors,
        );
      } else {
        throw NostrServiceException('Failed to broadcast event');
      }
    } catch (e) {
      Log.error('Error broadcasting event: $e', name: 'NostrService', category: LogCategory.relay);
      rethrow;
    }
  }
  
  @override
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  }) async {
    if (!_isInitialized || !hasKeys) {
      throw NostrServiceException('NostrService not initialized or no keys available');
    }
    
    // Build tags for NIP-94 file metadata
    final tags = <List<String>>[];
    
    // Required tags
    tags.add(['url', metadata.url]);
    tags.add(['m', metadata.mimeType]);
    tags.add(['x', metadata.sha256Hash]);
    tags.add(['size', metadata.sizeBytes.toString()]);
    
    // Optional tags
    tags.add(['dim', metadata.dimensions]);
    if (metadata.blurhash != null) {
      tags.add(['blurhash', metadata.blurhash!]);
    }
    if (metadata.thumbnailUrl != null) {
      tags.add(['thumb', metadata.thumbnailUrl!]);
    }
    if (metadata.torrentHash != null) {
      tags.add(['i', metadata.torrentHash!]);
    }
    
    // Add hashtags
    for (final tag in hashtags) {
      if (tag.isNotEmpty) {
        tags.add(['t', tag.toLowerCase()]);
      }
    }
    
    // Create event
    final event = Event(
      publicKey!,
      1063, // NIP-94 file metadata
      tags,
      content,
    );
    
    return await broadcastEvent(event);
  }
  
  @override
  Future<NostrBroadcastResult> publishVideoEvent({
    required String videoUrl,
    required String content,
    String? title,
    String? thumbnailUrl,
    int? duration,
    String? dimensions,
    String? mimeType,
    String? sha256,
    int? fileSize,
    List<String> hashtags = const [],
  }) async {
    if (!_isInitialized || !hasKeys) {
      throw NostrServiceException('NostrService not initialized or no keys available');
    }
    
    // Build tags for NIP-71 video event
    final tags = <List<String>>[];
    
    // Required: video URL
    tags.add(['url', videoUrl]);
    
    // Optional metadata
    if (title != null && title.isNotEmpty) tags.add(['title', title]);
    if (thumbnailUrl != null && thumbnailUrl.isNotEmpty) tags.add(['thumb', thumbnailUrl]);
    if (duration != null) tags.add(['duration', duration.toString()]);
    if (dimensions != null && dimensions.isNotEmpty) tags.add(['dim', dimensions]);
    if (mimeType != null && mimeType.isNotEmpty) tags.add(['m', mimeType]);
    if (sha256 != null && sha256.isNotEmpty) tags.add(['x', sha256]);
    if (fileSize != null) tags.add(['size', fileSize.toString()]);
    
    // Add hashtags
    for (final tag in hashtags) {
      if (tag.isNotEmpty) {
        tags.add(['t', tag.toLowerCase()]);
      }
    }
    
    // Add client tag
    tags.add(['client', 'openvine']);
    
    // Create event
    final event = Event(
      publicKey!,
      22, // Kind 22 for short video (NIP-71)
      tags,
      content,
    );
    
    return await broadcastEvent(event);
  }
  
  /// Add a new relay
  Future<bool> addRelay(String relayUrl) async {
    if (_relays.contains(relayUrl)) {
      return true; // Already in list
    }
    
    try {
      Log.debug('� Adding new relay: $relayUrl', name: 'NostrService', category: LogCategory.relay);
      
      // Add to relay list and save
      _relays.add(relayUrl);
      await _saveRelays();
      
      // Let SDK handle the connection
      final relay = RelayBase(relayUrl, sdk.RelayStatus(relayUrl));
      final success = await _nostrClient!.addRelay(relay, autoSubscribe: true);
      
      if (success) {
        _relayInstances[relayUrl] = relay;
        _connectedRelays.add(relayUrl);
        notifyListeners();
        return true;
      } else {
        // Remove from lists if connection failed
        _relays.remove(relayUrl);
        await _saveRelays();
        return false;
      }
    } catch (e) {
      Log.error('Failed to add relay $relayUrl: $e', name: 'NostrService', category: LogCategory.relay);
      // Clean up on error
      _relays.remove(relayUrl);
      _relayInstances.remove(relayUrl);
      await _saveRelays();
      return false;
    }
  }
  
  /// Remove a relay
  Future<void> removeRelay(String relayUrl) async {
    try {
      // Remove from SDK
      if (_nostrClient != null) {
        _nostrClient!.removeRelay(relayUrl);
      }
      
      // Remove from our tracking
      _connectedRelays.remove(relayUrl);
      _relays.remove(relayUrl);
      _relayInstances.remove(relayUrl);
      
      // Save updated relay list
      await _saveRelays();
      
      if (!_isDisposed) {
        notifyListeners();
      }
      Log.info('� Disconnected from relay: $relayUrl', name: 'NostrService', category: LogCategory.relay);
    } catch (e) {
      Log.error('Error removing relay $relayUrl: $e', name: 'NostrService', category: LogCategory.relay);
    }
  }
  
  /// Get connection status for all relays
  Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    for (final relayUrl in _relays) {
      status[relayUrl] = _connectedRelays.contains(relayUrl);
    }
    return status;
  }
  
  /// Reconnect to all configured relays
  Future<void> reconnectAll() async {
    Log.debug('Reconnecting to all relays...', name: 'NostrService', category: LogCategory.relay);
    
    // Remove all existing relays
    for (final relayUrl in List<String>.from(_connectedRelays)) {
      await removeRelay(relayUrl);
    }
    
    // Re-add all configured relays
    for (final relayUrl in List<String>.from(_relays)) {
      await addRelay(relayUrl);
    }
  }
  
  /// Get connection status for debugging
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isInitialized': _isInitialized,
      'connectedRelays': _connectedRelays.length,
      'totalRelays': _relays.length,
      'connectionInfo': _connectionService.getConnectionInfo(),
    };
  }
  
  /// Get detailed relay status for debugging
  Map<String, dynamic> getDetailedRelayStatus() {
    final relayStatus = <String, Map<String, dynamic>>{};
    
    for (final relayUrl in _relays) {
      final isConnected = _connectedRelays.contains(relayUrl);
      final relay = _relayInstances[relayUrl];
      
      relayStatus[relayUrl] = {
        'connected': isConnected,
        'status': isConnected ? 'connected' : 'disconnected',
        'sdkConnected': relay?.relayStatus.connected == ClientConneccted.CONNECTED,
        'authed': relay?.relayStatus.authed ?? false,
        'readAccess': relay?.relayStatus.readAccess ?? false,
        'writeAccess': relay?.relayStatus.writeAccess ?? false,
      };
    }
    
    return {
      'relays': relayStatus,
      'summary': {
        'connected': _connectedRelays.length,
        'total': _relays.length,
      }
    };
  }
  
  /// Update relay statuses from SDK
  // ignore: unused_element
  void _updateRelayStatuses() {
    // Get active relays from SDK
    final activeRelays = _nostrClient!.activeRelays();
    
    // Update relay instances
    for (final relay in activeRelays) {
      if (_relays.contains(relay.url)) {
        _relayInstances[relay.url] = relay;
      }
    }
    
    notifyListeners();
  }
  
  /// Save relay list to preferences
  Future<void> _saveRelays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_relaysPrefsKey, _relays);
      Log.debug('� Saved ${_relays.length} relays to preferences', name: 'NostrService', category: LogCategory.relay);
    } catch (e) {
      Log.error('Failed to save relays: $e', name: 'NostrService', category: LogCategory.relay);
    }
  }
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    Log.debug('�️ Disposing NostrService v2', name: 'NostrService', category: LogCategory.relay);
    _isDisposed = true;
    
    // Cancel all active subscriptions
    for (final entry in _activeSubscriptions.entries) {
      _nostrClient?.unsubscribe(entry.value);
    }
    _activeSubscriptions.clear();
    
    // Clean up client (SDK handles relay disconnection)
    _nostrClient = null;
    _connectedRelays.clear();
    _relayInstances.clear();
    
    super.dispose();
  }
}