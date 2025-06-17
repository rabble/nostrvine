// ABOUTME: Web-compatible Nostr service that works around dart_nostr web limitations
// ABOUTME: Provides basic Nostr functionality for web platform until library supports web

import 'dart:async';
import 'dart:convert';
import 'dart:html' as html;
import 'package:dart_nostr/dart_nostr.dart';
import 'package:flutter/foundation.dart';
import '../models/nip94_metadata.dart';
import 'nostr_key_manager.dart';
import 'nostr_service_interface.dart';

/// Web-compatible wrapper for NostrEventsStream
class WebNostrEventsStream implements NostrEventsStream {
  final Stream<NostrEvent> _stream;
  final StreamController<NostrEvent> _controller;
  
  WebNostrEventsStream._(this._stream, this._controller);
  
  static WebNostrEventsStream create() {
    final controller = StreamController<NostrEvent>.broadcast();
    return WebNostrEventsStream._(controller.stream, controller);
  }
  
  @override
  Stream<NostrEvent> get stream => _stream;
  
  void addEvent(NostrEvent event) {
    _controller.add(event);
  }
  
  void addError(Object error) {
    _controller.addError(error);
  }
  
  void close() {
    _controller.close();
  }
}

/// Web-compatible Nostr service
class WebNostrService extends ChangeNotifier implements INostrService {
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
  final Map<String, html.WebSocket> _webSockets = {};
  final Map<String, WebNostrEventsStream> _activeStreams = {};
  
  WebNostrService(this._keyManager);
  
  // Getters
  bool get isInitialized => _isInitialized && !_isDisposed;
  bool get isDisposed => _isDisposed;
  List<String> get connectedRelays => List.unmodifiable(_connectedRelays);
  String? get publicKey => _isDisposed ? null : _keyManager.publicKey;
  bool get hasKeys => _isDisposed ? false : _keyManager.hasKeys;
  NostrKeyManager get keyManager => _keyManager;
  int get relayCount => _connectedRelays.length;
  int get connectedRelayCount => _connectedRelays.length;
  
  /// Initialize web-compatible Nostr service
  Future<void> initialize({
    List<String>? customRelays,
  }) async {
    if (_isDisposed) {
      throw Exception('Cannot initialize disposed WebNostrService');
    }
    
    try {
      debugPrint('🌐 Starting Web-compatible NostrService initialization...');
      debugPrint('📊 Platform: Web (using WebSocket directly)');
      
      // Initialize key manager if not already done
      if (!_keyManager.isInitialized) {
        debugPrint('🔑 Initializing key manager...');
        await _keyManager.initialize();
      } else {
        debugPrint('🔑 Key manager already initialized');
      }
      
      // Ensure we have keys (generate if needed)
      if (!_keyManager.hasKeys) {
        debugPrint('🔑 No keys found, generating new identity...');
        await _keyManager.generateKeys();
      } else {
        debugPrint('🔑 Keys available: ${_keyManager.publicKey?.substring(0, 8)}...');
      }
      
      // Connect to relays using native WebSocket
      final relaysToConnect = customRelays ?? defaultRelays;
      debugPrint('📡 Attempting to connect to ${relaysToConnect.length} relays using WebSocket:');
      for (int i = 0; i < relaysToConnect.length; i++) {
        debugPrint('  ${i + 1}. ${relaysToConnect[i]}');
      }
      
      // Connect to each relay
      await _connectToRelays(relaysToConnect);
      
      _isInitialized = true;
      notifyListeners();
      
      debugPrint('✅ Web NostrService initialization completed!');
      debugPrint('📊 Final status: ${_connectedRelays.length}/${relaysToConnect.length} relays connected');
      debugPrint('📡 Connected relays: ${_connectedRelays.join(', ')}');
      
      if (_connectedRelays.isEmpty) {
        debugPrint('⚠️ WARNING: No relays connected! This may be due to:');
        debugPrint('   1. CORS restrictions on relay servers');
        debugPrint('   2. WebSocket connection blocked by browser/network');
        debugPrint('   3. Relay servers temporarily unavailable');
        debugPrint('💡 For now, the app will work in offline mode');
      }
    } catch (e) {
      debugPrint('❌ Failed to initialize Web NostrService: $e');
      _isInitialized = false;
      rethrow;
    }
  }
  
  /// Connect to relays using native WebSocket
  Future<void> _connectToRelays(List<String> relayUrls) async {
    final futures = relayUrls.map((url) => _connectToRelay(url));
    await Future.wait(futures, eagerError: false);
    
    // Wait a bit for connections to establish
    await Future.delayed(const Duration(seconds: 2));
  }
  
  /// Connect to a single relay
  Future<void> _connectToRelay(String relayUrl) async {
    try {
      debugPrint('🔌 Connecting to $relayUrl...');
      
      final socket = html.WebSocket(relayUrl);
      _webSockets[relayUrl] = socket;
      
      socket.onOpen.listen((event) {
        if (!_connectedRelays.contains(relayUrl)) {
          _connectedRelays.add(relayUrl);
          notifyListeners();
        }
        debugPrint('✅ Connected to relay: $relayUrl (${_connectedRelays.length} total)');
      });
      
      socket.onError.listen((event) {
        debugPrint('❌ WebSocket error for $relayUrl: $event');
        _connectedRelays.remove(relayUrl);
        _webSockets.remove(relayUrl);
        notifyListeners();
      });
      
      socket.onClose.listen((event) {
        debugPrint('🔌 WebSocket closed for $relayUrl: ${event.reason}');
        _connectedRelays.remove(relayUrl);
        _webSockets.remove(relayUrl);
        notifyListeners();
      });
      
      socket.onMessage.listen((event) {
        debugPrint('📥 Message from $relayUrl: ${event.data}');
        _handleRelayMessage(relayUrl, event.data);
      });
      
    } catch (e) {
      debugPrint('❌ Failed to connect to $relayUrl: $e');
    }
  }
  
  /// Handle messages from relay
  void _handleRelayMessage(String relayUrl, dynamic data) {
    try {
      if (data is String) {
        final message = jsonDecode(data);
        debugPrint('📨 Relay message from $relayUrl: ${message.runtimeType}');
        
        // Handle different message types
        if (message is List && message.isNotEmpty) {
          final messageType = message[0];
          switch (messageType) {
            case 'EVENT':
              if (message.length >= 3) {
                _handleEventMessage(message[2]);
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
      debugPrint('⚠️ Error parsing relay message: $e');
    }
  }
  
  /// Handle event message
  void _handleEventMessage(Map<String, dynamic> eventData) {
    try {
      debugPrint('🎬 Received event: kind=${eventData['kind']}, id=${eventData['id']?.substring(0, 8)}...');
      
      // Create NostrEvent from the raw data
      final event = NostrEvent.fromMap(eventData);
      
      // Send to all active streams that might be interested
      for (final stream in _activeStreams.values) {
        stream.addEvent(event);
      }
      
      debugPrint('📤 Event forwarded to ${_activeStreams.length} active streams');
    } catch (e) {
      debugPrint('⚠️ Error handling event: $e');
      // Send error to all active streams
      for (final stream in _activeStreams.values) {
        stream.addError(e);
      }
    }
  }
  
  /// Subscribe to events (web-compatible implementation)
  NostrEventsStream subscribeToEvents({required List<NostrFilter> filters}) {
    debugPrint('🎥 Creating web-compatible event subscription...');
    
    // Create a web-compatible stream
    final stream = WebNostrEventsStream.create();
    final streamId = DateTime.now().millisecondsSinceEpoch.toString();
    _activeStreams[streamId] = stream;
    
    // Send subscription request to all connected relays
    if (_connectedRelays.isNotEmpty) {
      _sendSubscriptionRequest(filters);
      debugPrint('📡 Subscription request sent to ${_connectedRelays.length} relays');
    } else {
      debugPrint('⚠️ No connected relays - subscription won\'t receive events');
    }
    
    return stream;
  }
  
  /// Send subscription request to relays
  void _sendSubscriptionRequest(List<NostrFilter> filters) {
    if (_connectedRelays.isEmpty) {
      debugPrint('⚠️ No connected relays - cannot send subscription');
      return;
    }
    
    // Create REQ message
    final subscriptionId = DateTime.now().millisecondsSinceEpoch.toString();
    final reqMessage = ['REQ', subscriptionId];
    
    // Add filters
    for (final filter in filters) {
      final filterMap = <String, dynamic>{};
      
      if (filter.kinds != null && filter.kinds!.isNotEmpty) {
        filterMap['kinds'] = filter.kinds;
      }
      if (filter.authors != null && filter.authors!.isNotEmpty) {
        filterMap['authors'] = filter.authors;
      }
      if (filter.limit != null) {
        filterMap['limit'] = filter.limit;
      }
      
      reqMessage.add(filterMap);
    }
    
    final message = jsonEncode(reqMessage);
    debugPrint('📤 Sending subscription request: $message');
    
    // Send to all connected relays
    for (final socket in _webSockets.values) {
      if (socket.readyState == html.WebSocket.OPEN) {
        socket.send(message);
      }
    }
  }
  
  /// Broadcast event (basic implementation)
  Future<NostrBroadcastResult> broadcastEvent(NostrEvent event) async {
    if (!_isInitialized || !_keyManager.hasKeys) {
      throw Exception('WebNostrService not initialized or no keys available');
    }
    
    if (_connectedRelays.isEmpty) {
      // For web demo, return success even without relays
      debugPrint('⚠️ No relays connected - simulating local success');
      return NostrBroadcastResult(
        event: event,
        successCount: 0,
        totalRelays: 0,
        results: {},
        errors: {},
      );
    }
    
    try {
      final eventMessage = ['EVENT', event.toMap()];
      final message = jsonEncode(eventMessage);
      
      debugPrint('📤 Broadcasting event to ${_connectedRelays.length} relays');
      
      int successCount = 0;
      final results = <String, bool>{};
      final errors = <String, String>{};
      
      for (final relayUrl in _connectedRelays) {
        final socket = _webSockets[relayUrl];
        if (socket?.readyState == html.WebSocket.OPEN) {
          try {
            socket!.send(message);
            results[relayUrl] = true;
            successCount++;
          } catch (e) {
            results[relayUrl] = false;
            errors[relayUrl] = e.toString();
          }
        } else {
          results[relayUrl] = false;
          errors[relayUrl] = 'Socket not open';
        }
      }
      
      return NostrBroadcastResult(
        event: event,
        successCount: successCount,
        totalRelays: _connectedRelays.length,
        results: results,
        errors: errors,
      );
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
      throw Exception('Invalid NIP-94 metadata');
    }
    
    final event = metadata.toNostrEvent(
      keyPairs: _keyManager.keyPair!,
      content: content,
      hashtags: hashtags,
    );
    
    return await broadcastEvent(event);
  }
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    try {
      _isDisposed = true;
      
      // Close all WebSocket connections
      for (final socket in _webSockets.values) {
        socket.close();
      }
      _webSockets.clear();
      _connectedRelays.clear();
      _isInitialized = false;
      
      super.dispose();
      debugPrint('🗑️ WebNostrService disposed');
    } catch (e) {
      debugPrint('⚠️ Error disposing WebNostrService: $e');
    }
  }
}