// ABOUTME: NostrService v2 using nostr_sdk's RelayPool instead of custom WebSocket
// ABOUTME: Eliminates dual subscription tracking and leverages SDK's battle-tested relay management

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/relay_base.dart';
import 'package:nostr_sdk/relay/relay_status.dart';
import 'package:nostr_sdk/relay/event_filter.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import '../models/nip94_metadata.dart';
import '../utils/unified_logger.dart';
import 'nostr_key_manager.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';

/// Exception for NostrService errors
class NostrServiceException implements Exception {
  final String message;
  NostrServiceException(this.message);
  
  @override
  String toString() => 'NostrServiceException: $message';
}

/// NostrService v2 implementation using nostr_sdk
class NostrServiceV2 extends ChangeNotifier implements INostrService {
  static const List<String> defaultRelays = [
    'wss://vine.hol.is',
  ];
  
  final NostrKeyManager _keyManager;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  
  Nostr? _nostrClient;
  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _connectedRelays = [];
  
  // Track active subscriptions for cleanup
  final Map<String, String> _activeSubscriptions = {}; // Our ID -> SDK subscription ID
  
  NostrServiceV2(this._keyManager);
  
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
      
      // Create event filters (we'll handle subscriptions manually)
      final eventFilters = <EventFilter>[];
      
      // Initialize Nostr client
      _nostrClient = Nostr(
        signer,
        pubKey,
        eventFilters,
        (relayUrl) => RelayBase(relayUrl, RelayStatus(relayUrl)),
        onNotice: (relayUrl, notice) {
          Log.info('📢 Notice from $relayUrl: $notice', category: LogCategory.relay);
        },
      );
      
      // Add relays
      final relaysToAdd = customRelays ?? defaultRelays;
      for (final relayUrl in relaysToAdd) {
        try {
          final relay = RelayBase(relayUrl, RelayStatus(relayUrl));
          
          // Add relay with autoSubscribe=true to apply existing subscriptions
          final success = await _nostrClient!.addRelay(relay, autoSubscribe: true);
          if (success) {
            _connectedRelays.add(relayUrl);
            Log.info('✅ Connected to relay: $relayUrl', category: LogCategory.relay);
            Log.debug('  - Status: ${relay.relayStatus.connected}', category: LogCategory.relay);
            Log.debug('  - Read access: ${relay.relayStatus.readAccess}', category: LogCategory.relay);
            Log.debug('  - Write access: ${relay.relayStatus.writeAccess}', category: LogCategory.relay);
          } else {
            debugPrint('❌ Failed to connect to relay: $relayUrl');
          }
        } catch (e) {
          debugPrint('❌ Error connecting to relay $relayUrl: $e');
        }
      }
      
      if (_connectedRelays.isEmpty) {
        throw NostrServiceException('Failed to connect to any relays');
      }
      
      // Give relays time to fully establish connection and complete AUTH
      await Future.delayed(const Duration(seconds: 3));
      
      // Verify relay is still connected after AUTH
      final relays = _nostrClient!.activeRelays();
      for (final relay in relays) {
        debugPrint('📡 Post-AUTH relay status for ${relay.url}:');
        debugPrint('  - Connected: ${relay.relayStatus.connected}');
        debugPrint('  - Authed: ${relay.relayStatus.authed}');
        debugPrint('  - Read access: ${relay.relayStatus.readAccess}');
        debugPrint('  - Write access: ${relay.relayStatus.writeAccess}');
      }
      
      _isInitialized = true;
      debugPrint('✅ NostrService v2 initialized with ${_connectedRelays.length} relays');
      notifyListeners();
      
    } catch (e) {
      debugPrint('❌ Failed to initialize NostrService: $e');
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
    
    debugPrint('📡 Creating subscription $subscriptionId with filters:');
    for (final filter in sdkFilters) {
      debugPrint('  - Filter: $filter');
    }
    
    // Create subscription using SDK
    final sdkSubId = _nostrClient!.subscribe(
      sdkFilters,
      (Event event) {
        debugPrint('📨 Received event in NostrServiceV2 callback: kind=${event.kind}, id=${event.id.substring(0, 8)}...');
        // Forward events to our stream
        controller.add(event);
      },
      id: subscriptionId,
    );
    
    // Also listen to the raw relay pool to see if events are coming in
    debugPrint('🔍 Checking relay pool state...');
    final relays = _nostrClient!.activeRelays();
    for (final relay in relays) {
      debugPrint('  - Relay ${relay.url}: connected=${relay.relayStatus.connected}, authed=${relay.relayStatus.authed}');
    }
    
    // Track subscription for cleanup
    _activeSubscriptions[subscriptionId] = sdkSubId;
    
    debugPrint('✅ Created subscription $subscriptionId (SDK ID: $sdkSubId) with ${filters.length} filters');
    
    // Handle stream cancellation
    controller.onCancel = () {
      final sdkId = _activeSubscriptions.remove(subscriptionId);
      if (sdkId != null) {
        _nostrClient?.unsubscribe(sdkId);
        debugPrint('🗑️ Cancelled subscription $subscriptionId');
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
      debugPrint('❌ Error broadcasting event: $e');
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
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    debugPrint('🗑️ Disposing NostrService v2');
    _isDisposed = true;
    
    // Cancel all active subscriptions
    for (final entry in _activeSubscriptions.entries) {
      _nostrClient?.unsubscribe(entry.value);
    }
    _activeSubscriptions.clear();
    
    // Clean up client (SDK handles relay disconnection)
    _nostrClient = null;
    _connectedRelays.clear();
    
    super.dispose();
  }
}