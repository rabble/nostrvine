// ABOUTME: Core Nostr service for event broadcasting and relay management
// ABOUTME: Handles connection, authentication, and event publishing for NostrVine

import 'dart:async';
import 'dart:convert';
import 'package:nostr/nostr.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import '../models/nip94_metadata.dart';
import 'nostr_key_manager.dart';
import 'nostr_service_interface.dart';

/// Core service for Nostr protocol integration
class NostrService extends ChangeNotifier implements INostrService {
  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.snort.social', 
    'wss://relay.current.fyi',
  ];
  
  final NostrKeyManager _keyManager;
  bool _isInitialized = false;
  bool _isDisposed = false;
  List<String> _connectedRelays = [];
  final Map<String, WebSocketChannel> _webSockets = {};
  final Map<String, StreamController<Event>> _eventControllers = {};
  
  /// Create NostrService with a key manager
  NostrService(this._keyManager);
  
  // Getters
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
      
      // Connect to relays using web-compatible nostr package
      final relaysToConnect = customRelays ?? defaultRelays;
      debugPrint('📡 Attempting to connect to ${relaysToConnect.length} relays using web-compatible nostr package...');
      
      // Connect to each relay
      for (final relayUrl in relaysToConnect) {
        try {
          debugPrint('🔌 Connecting to $relayUrl...');
          final webSocket = WebSocketChannel.connect(Uri.parse(relayUrl));
          _webSockets[relayUrl] = webSocket;
          
          if (!_connectedRelays.contains(relayUrl)) {
            _connectedRelays.add(relayUrl);
            notifyListeners();
          }
          debugPrint('✅ Connected to relay: $relayUrl (${_connectedRelays.length}/${relaysToConnect.length})');
          
          // Listen for incoming messages
          webSocket.stream.listen(
            (data) => _handleRelayMessage(relayUrl, data),
            onError: (error) {
              debugPrint('❌ WebSocket error for $relayUrl: $error');
              _connectedRelays.remove(relayUrl);
              _webSockets.remove(relayUrl);
              notifyListeners();
            },
            onDone: () {
              debugPrint('🔌 Disconnected from relay: $relayUrl');
              _connectedRelays.remove(relayUrl);
              _webSockets.remove(relayUrl);
              notifyListeners();
            },
          );
          
        } catch (e) {
          debugPrint('❌ Failed to connect to $relayUrl: $e');
        }
      }
      
      // Give connections time to establish
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('📡 Relay initialization completed: ${_connectedRelays.length}/${relaysToConnect.length} connected');
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ Nostr service initialized with ${_connectedRelays.length} relays');
    } catch (e) {
      debugPrint('❌ Failed to initialize Nostr service: $e');
      rethrow;
    }
  }
  
  /// Handle incoming messages from relays
  void _handleRelayMessage(String relayUrl, dynamic data) {
    try {
      if (data is String) {
        final message = jsonDecode(data);
        if (message is List && message.isNotEmpty) {
          final messageType = message[0];
          switch (messageType) {
            case 'EVENT':
              if (message.length >= 3) {
                _handleEventMessage(message);
              }
              break;
            case 'EOSE':
              debugPrint('📄 End of stored events from $relayUrl');
              break;
            case 'OK':
              debugPrint('✅ Event published successfully to $relayUrl');
              break;
            case 'NOTICE':
              debugPrint('📢 Notice from $relayUrl: ${message.length > 1 ? message[1] : 'No message'}');
              break;
          }
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing message from $relayUrl: $e');
    }
  }
  
  /// Handle incoming event message
  void _handleEventMessage(List<dynamic> eventMessage) {
    try {
      final event = Event.deserialize(eventMessage);
      debugPrint('🎬 Received event: kind=${event.kind}, id=${event.id.substring(0, 8)}...');
      
      // Forward to all active event controllers
      for (final controller in _eventControllers.values) {
        if (!controller.isClosed) {
          controller.add(event);
        }
      }
    } catch (e) {
      debugPrint('⚠️ Error handling event: $e');
    }
  }
  
  /// Broadcast event to all connected relays
  Future<NostrBroadcastResult> broadcastEvent(Event event) async {
    if (!_isInitialized || !_keyManager.hasKeys) {
      throw NostrServiceException('Nostr service not initialized or no keys available');
    }
    
    if (_connectedRelays.isEmpty) {
      throw NostrServiceException('No connected relays available');
    }
    
    try {
      final results = <String, bool>{};
      final errors = <String, String>{};
      int successCount = 0;
      
      // Send event to each connected relay
      for (final relayUrl in _connectedRelays) {
        try {
          final webSocket = _webSockets[relayUrl];
          if (webSocket != null) {
            final eventMessage = ['EVENT', event.toJson()];
            webSocket.sink.add(jsonEncode(eventMessage));
            results[relayUrl] = true;
            successCount++;
          } else {
            results[relayUrl] = false;
            errors[relayUrl] = 'WebSocket not available';
          }
        } catch (e) {
          results[relayUrl] = false;
          errors[relayUrl] = e.toString();
        }
      }
      
      final broadcastResult = NostrBroadcastResult(
        event: event,
        successCount: successCount,
        totalRelays: _connectedRelays.length,
        results: results,
        errors: errors,
      );
      
      debugPrint('✅ Event broadcasted to $successCount/${_connectedRelays.length} relays');
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
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
  }) {
    if (!_isInitialized) {
      throw NostrServiceException('Nostr service not initialized');
    }
    
    // Create a subscription ID
    final subscriptionId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Create stream controller for this subscription
    final controller = StreamController<Event>.broadcast();
    _eventControllers[subscriptionId] = controller;
    
    // Send REQ message to all connected relays
    for (final relayUrl in _connectedRelays) {
      try {
        final webSocket = _webSockets[relayUrl];
        if (webSocket != null) {
          final reqMessage = ['REQ', subscriptionId, ...filters.map((f) => f.toJson())];
          webSocket.sink.add(jsonEncode(reqMessage));
          debugPrint('📡 Sent subscription request to $relayUrl');
        }
      } catch (e) {
        debugPrint('❌ Failed to send subscription to $relayUrl: $e');
      }
    }
    
    return controller.stream;
  }
  
  /// Add a new relay
  Future<bool> addRelay(String relayUrl) async {
    if (_connectedRelays.contains(relayUrl)) {
      return true; // Already connected
    }
    
    try {
      debugPrint('🔌 Adding new relay: $relayUrl');
      final webSocket = WebSocketChannel.connect(Uri.parse(relayUrl));
      _webSockets[relayUrl] = webSocket;
      
      _connectedRelays.add(relayUrl);
      notifyListeners();
      
      // Listen for incoming messages
      webSocket.stream.listen(
        (data) => _handleRelayMessage(relayUrl, data),
        onError: (error) {
          debugPrint('❌ WebSocket error for $relayUrl: $error');
          _connectedRelays.remove(relayUrl);
          _webSockets.remove(relayUrl);
          notifyListeners();
        },
        onDone: () {
          debugPrint('🔌 Disconnected from relay: $relayUrl');
          _connectedRelays.remove(relayUrl);
          _webSockets.remove(relayUrl);
          notifyListeners();
        },
      );
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to add relay $relayUrl: $e');
      return false;
    }
  }
  
  /// Remove a relay
  Future<void> removeRelay(String relayUrl) async {
    try {
      final webSocket = _webSockets[relayUrl];
      if (webSocket != null) {
        await webSocket.sink.close();
        _webSockets.remove(relayUrl);
      }
      _connectedRelays.remove(relayUrl);
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
      
      // Close existing connections
      for (final webSocket in _webSockets.values) {
        try {
          await webSocket.sink.close();
        } catch (e) {
          debugPrint('⚠️ Error closing websocket: $e');
        }
      }
      
      _connectedRelays.clear();
      _webSockets.clear();
      
      // Reconnect to all relays
      await initialize(customRelays: relaysToReconnect);
    } catch (e) {
      debugPrint('⚠️ Error during reconnection: $e');
    }
  }
  
  /// Dispose service and close all connections
  @override
  void dispose() {
    if (_isDisposed) return;
    
    try {
      _isDisposed = true;
      
      // Close all websocket connections
      for (final webSocket in _webSockets.values) {
        try {
          webSocket.sink.close();
        } catch (e) {
          debugPrint('⚠️ Error closing websocket: $e');
        }
      }
      
      // Close all event controllers
      for (final controller in _eventControllers.values) {
        try {
          controller.close();
        } catch (e) {
          debugPrint('⚠️ Error closing event controller: $e');
        }
      }
      
      _webSockets.clear();
      _eventControllers.clear();
      _connectedRelays.clear();
      _isInitialized = false;
      super.dispose();
      debugPrint('🗑️ NostrService disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing Nostr service: $e');
    }
  }
}

/// Exception thrown by Nostr service operations
class NostrServiceException implements Exception {
  final String message;
  
  const NostrServiceException(this.message);
  
  @override
  String toString() => 'NostrServiceException: $message';
}