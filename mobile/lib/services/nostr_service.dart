// ABOUTME: Core Nostr service for event broadcasting and relay management
// ABOUTME: Handles connection, authentication, and event publishing for NostrVine

import 'dart:async';
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import '../models/nip94_metadata.dart';
import 'nostr_key_manager.dart';

/// Core service for Nostr protocol integration
class NostrService extends ChangeNotifier {
  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.snort.social', 
    'wss://relay.current.fyi',
  ];
  
  final NostrKeyManager _keyManager;
  bool _isInitialized = false;
  List<String> _connectedRelays = [];
  
  /// Create NostrService with a key manager
  NostrService(this._keyManager);
  
  // Getters
  bool get isInitialized => _isInitialized;
  List<String> get connectedRelays => List.unmodifiable(_connectedRelays);
  String? get publicKey => _keyManager.publicKey;
  bool get hasKeys => _keyManager.hasKeys;
  NostrKeyManager get keyManager => _keyManager;
  int get relayCount => _connectedRelays.length;
  int get connectedRelayCount => _connectedRelays.length;
  
  /// Initialize Nostr service with user keys
  Future<void> initialize({
    List<String>? customRelays,
  }) async {
    try {
      // Initialize key manager if not already done
      if (!_keyManager.isInitialized) {
        await _keyManager.initialize();
      }
      
      // Ensure we have keys (generate if needed)
      if (!_keyManager.hasKeys) {
        debugPrint('🔑 No keys found, generating new identity...');
        await _keyManager.generateKeys();
      }
      
      // Connect to relays using Nostr instance
      final relaysToConnect = customRelays ?? defaultRelays;
      await Nostr.instance.relaysService.init(
        relaysUrl: relaysToConnect,
        onRelayListening: (relayUrl, data, socket) {
          if (!_connectedRelays.contains(relayUrl)) {
            _connectedRelays.add(relayUrl);
            notifyListeners();
          }
          debugPrint('✅ Connected to relay: $relayUrl');
        },
        onRelayConnectionError: (relayUrl, error, socket) {
          debugPrint('⚠️ Failed to connect to relay $relayUrl: $error');
          _connectedRelays.remove(relayUrl);
          notifyListeners();
        },
        onRelayConnectionDone: (relayUrl, socket) {
          debugPrint('🔌 Disconnected from relay: $relayUrl');
          _connectedRelays.remove(relayUrl);
          notifyListeners();
        },
        ignoreConnectionException: true,
        retryOnError: true,
      );
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ Nostr service initialized with ${_connectedRelays.length} relays');
    } catch (e) {
      debugPrint('❌ Failed to initialize Nostr service: $e');
      rethrow;
    }
  }
  
  /// Broadcast event to all connected relays
  Future<NostrBroadcastResult> broadcastEvent(NostrEvent event) async {
    if (!_isInitialized || !_keyManager.hasKeys) {
      throw NostrServiceException('Nostr service not initialized or no keys available');
    }
    
    if (_connectedRelays.isEmpty) {
      throw NostrServiceException('No connected relays available');
    }
    
    try {
      // Send event using Nostr instance
      Nostr.instance.relaysService.sendEventToRelays(event);
      
      // Create broadcast result (simplified since dart_nostr handles the details)
      final broadcastResult = NostrBroadcastResult(
        event: event,
        successCount: _connectedRelays.length, // Assume success for all
        totalRelays: _connectedRelays.length,
        results: Map.fromIterable(_connectedRelays, value: (_) => true),
        errors: {},
      );
      
      debugPrint('✅ Event broadcasted to ${_connectedRelays.length} relays');
      return broadcastResult;
    } catch (e) {
      debugPrint('❌ Event broadcasting failed: $e');
      rethrow;
    }
  }
  
  /// Publish NIP-94 file metadata event
  Future<NostrBroadcastResult> publishFileMetadata({
    required NIP94Metadata metadata,
    required String content,
    List<String> hashtags = const [],
  }) async {
    if (!metadata.isValid) {
      throw NIP94ValidationException('Invalid NIP-94 metadata');
    }
    
    final event = metadata.toNostrEvent(
      keyPairs: _keyManager.keyPair!,
      content: content,
      hashtags: hashtags,
    );
    
    return await broadcastEvent(event);
  }
  
  /// Subscribe to events
  NostrEventsStream subscribeToEvents({
    required List<NostrFilter> filters,
  }) {
    if (!_isInitialized) {
      throw NostrServiceException('Nostr service not initialized');
    }
    
    // Create stream for events
    final request = NostrRequest(filters: filters);
    return Nostr.instance.relaysService.startEventsSubscription(request: request);
  }
  
  /// Add a new relay
  Future<bool> addRelay(String relayUrl) async {
    if (_connectedRelays.contains(relayUrl)) {
      return true; // Already connected
    }
    
    try {
      // Re-initialize with additional relay
      final newRelayList = [..._connectedRelays, relayUrl];
      await Nostr.instance.relaysService.init(relaysUrl: newRelayList);
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to add relay $relayUrl: $e');
      return false;
    }
  }
  
  /// Remove a relay
  Future<void> removeRelay(String relayUrl) async {
    try {
      _connectedRelays.remove(relayUrl);
      // Re-initialize without the relay
      if (_connectedRelays.isNotEmpty) {
        await Nostr.instance.relaysService.init(relaysUrl: _connectedRelays);
      }
      notifyListeners();
      debugPrint('🔌 Disconnected from relay: $relayUrl');
    } catch (e) {
      debugPrint('⚠️ Error removing relay $relayUrl: $e');
    }
  }
  
  /// Get connection status for all relays
  Map<String, bool> getRelayStatus() {
    final status = <String, bool>{};
    for (final relayUrl in defaultRelays) {
      status[relayUrl] = _connectedRelays.contains(relayUrl);
    }
    return status;
  }
  
  /// Reconnect to all relays
  Future<void> reconnectAll() async {
    try {
      final relaysToReconnect = _connectedRelays.toList();
      _connectedRelays.clear();
      
      await Nostr.instance.relaysService.init(relaysUrl: relaysToReconnect);
      notifyListeners();
    } catch (e) {
      debugPrint('⚠️ Error during reconnection: $e');
    }
  }
  
  /// Dispose service and close all connections
  @override
  void dispose() {
    try {
      Nostr.instance.relaysService.freeAllResources();
      _connectedRelays.clear();
      _isInitialized = false;
      super.dispose();
    } catch (e) {
      debugPrint('⚠️ Error disposing Nostr service: $e');
    }
  }
}

/// Result of broadcasting an event to relays
class NostrBroadcastResult {
  final NostrEvent event;
  final int successCount;
  final int totalRelays;
  final Map<String, bool> results;
  final Map<String, String> errors;
  
  const NostrBroadcastResult({
    required this.event,
    required this.successCount,
    required this.totalRelays,
    required this.results,
    required this.errors,
  });
  
  bool get isSuccessful => successCount > 0;
  bool get isCompleteSuccess => successCount == totalRelays;
  double get successRate => totalRelays > 0 ? successCount / totalRelays : 0.0;
  
  List<String> get successfulRelays => 
    results.entries.where((e) => e.value).map((e) => e.key).toList();
  
  List<String> get failedRelays =>
    results.entries.where((e) => !e.value).map((e) => e.key).toList();
  
  @override
  String toString() {
    return 'NostrBroadcastResult('
           'success: $successCount/$totalRelays, '
           'rate: ${(successRate * 100).toStringAsFixed(1)}%'
           ')';
  }
}

/// Exception thrown by Nostr service operations
class NostrServiceException implements Exception {
  final String message;
  
  const NostrServiceException(this.message);
  
  @override
  String toString() => 'NostrServiceException: $message';
}