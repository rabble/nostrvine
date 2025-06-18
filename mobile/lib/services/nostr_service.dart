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
import 'connection_status_service.dart';

/// Core service for Nostr protocol integration
class NostrService extends ChangeNotifier implements INostrService {
  static const List<String> defaultRelays = [
    'wss://relay.damus.io',
    'wss://nos.lol',
    'wss://relay.snort.social',
    // Removed 'wss://relay.current.fyi' - permanently offline causing SocketException flood
  ];
  
  final NostrKeyManager _keyManager;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  bool _isInitialized = false;
  bool _isDisposed = false;
  List<String> _connectedRelays = [];
  final Map<String, WebSocketChannel> _webSockets = {};
  final Map<String, StreamController<Event>> _eventControllers = {};
  final Map<String, int> _relayRetryCount = {};
  final Map<String, DateTime> _relayLastFailureTime = {};
  final Map<String, Duration> _relayBackoffDuration = {};
  Timer? _reconnectTimer;
  
  static const int _maxRetryAttempts = 8; // Increased to allow for longer backoff
  static const Duration _initialRetryDelay = Duration(seconds: 2);
  static const Duration _maxBackoffDuration = Duration(minutes: 30);
  
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
  @override
  Future<void> initialize({
    List<String>? customRelays,
  }) async {
    try {
      // Initialize connection status service
      await _connectionService.initialize();
      
      // Check if we're online before proceeding
      if (!_connectionService.isOnline) {
        debugPrint('⚠️ Device appears to be offline, will retry when connection is restored');
        _scheduleReconnect();
        throw NostrServiceException('Device is offline');
      }
      
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
            if (!_isDisposed) {
              notifyListeners();
            }
          }
          debugPrint('✅ Connected to relay: $relayUrl (${_connectedRelays.length}/${relaysToConnect.length})');
          
          // Listen for incoming messages
          webSocket.stream.listen(
            (data) => _handleRelayMessage(relayUrl, data),
            onError: (error) {
              debugPrint('❌ WebSocket error for $relayUrl: $error');
              _handleRelayDisconnection(relayUrl, error.toString());
            },
            onDone: () {
              debugPrint('🔌 Disconnected from relay: $relayUrl');
              _handleRelayDisconnection(relayUrl, 'Connection closed');
            },
          );
          
        } catch (e) {
          debugPrint('❌ Failed to connect to $relayUrl: $e');
          _relayRetryCount[relayUrl] = (_relayRetryCount[relayUrl] ?? 0) + 1;
          
          // Check if it's a connection issue
          if (_isConnectionError(e)) {
            debugPrint('🌐 Connection error detected for $relayUrl, will retry with backoff');
            _handleRelayConnectionFailure(relayUrl, e);
          }
        }
      }
      
      // Give connections time to establish
      await Future.delayed(const Duration(seconds: 2));
      debugPrint('📡 Relay initialization completed: ${_connectedRelays.length}/${relaysToConnect.length} connected');
      
      _isInitialized = true;
      if (!_isDisposed) {
        notifyListeners();
      }
      
      debugPrint('✅ Nostr service initialized with ${_connectedRelays.length} relays');
      
      // Start automatic reconnection monitoring
      _startReconnectionMonitoring();
    } catch (e) {
      debugPrint('❌ Failed to initialize Nostr service: $e');
      
      // Schedule retry if it's a connection issue
      if (_isConnectionError(e)) {
        _scheduleReconnect();
      }
      
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
  @override
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
  @override
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
  @override
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
      if (!_isDisposed) {
        notifyListeners();
      }
      
      // Listen for incoming messages
      webSocket.stream.listen(
        (data) => _handleRelayMessage(relayUrl, data),
        onError: (error) {
          debugPrint('❌ WebSocket error for $relayUrl: $error');
          _connectedRelays.remove(relayUrl);
          _webSockets.remove(relayUrl);
          if (!_isDisposed) {
            notifyListeners();
          }
        },
        onDone: () {
          debugPrint('🔌 Disconnected from relay: $relayUrl');
          _connectedRelays.remove(relayUrl);
          _webSockets.remove(relayUrl);
          if (!_isDisposed) {
            notifyListeners();
          }
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
      if (!_isDisposed) {
        notifyListeners();
      }
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
  /// Handle relay disconnection with retry logic
  void _handleRelayDisconnection(String relayUrl, String reason) {
    _connectedRelays.remove(relayUrl);
    _webSockets.remove(relayUrl);
    
    final retryCount = _relayRetryCount[relayUrl] ?? 0;
    _relayLastFailureTime[relayUrl] = DateTime.now();
    
    debugPrint('📉 Relay disconnected: $relayUrl ($reason) - retry count: $retryCount');
    
    if (!_isDisposed) {
      notifyListeners();
      
      // Schedule reconnection if we haven't exceeded max retries
      if (retryCount < _maxRetryAttempts) {
        _scheduleRelayReconnectWithBackoff(relayUrl);
      } else {
        debugPrint('⚠️ Max retry attempts reached for $relayUrl - backing off for ${_maxBackoffDuration.inMinutes} minutes');
        _scheduleRelayBackoffReset(relayUrl);
      }
    }
  }
  
  /// Check if an error is connection-related
  bool _isConnectionError(dynamic error) {
    final errorString = error.toString().toLowerCase();
    return errorString.contains('connection') ||
           errorString.contains('network') ||
           errorString.contains('socket') ||
           errorString.contains('timeout') ||
           errorString.contains('unreachable') ||
           errorString.contains('offline') ||
           errorString.contains('host lookup') ||
           errorString.contains('name resolution');
  }
  
  /// Schedule reconnection for a specific relay with exponential backoff
  void _scheduleRelayReconnectWithBackoff(String relayUrl) {
    final retryCount = _relayRetryCount[relayUrl] ?? 0;
    
    // Calculate exponential backoff delay
    final baseDelay = _initialRetryDelay.inMilliseconds;
    final backoffMs = (baseDelay * (1 << retryCount)).clamp(baseDelay, _maxBackoffDuration.inMilliseconds);
    final delay = Duration(milliseconds: backoffMs);
    
    _relayBackoffDuration[relayUrl] = delay;
    
    debugPrint('⏰ Scheduling reconnect for $relayUrl in ${delay.inSeconds}s (attempt ${retryCount + 1}, backoff: ${delay.inSeconds}s)');
    
    Timer(delay, () async {
      if (!_isDisposed && _connectionService.isOnline) {
        // Check if we should attempt reconnection (not in long backoff)
        if (_shouldAttemptReconnection(relayUrl)) {
          try {
            debugPrint('🔄 Attempting to reconnect to $relayUrl...');
            await _connectToRelay(relayUrl);
          } catch (e) {
            debugPrint('❌ Reconnection failed for $relayUrl: $e');
            _handleRelayConnectionFailure(relayUrl, e);
          }
        } else {
          debugPrint('⏸️ Skipping reconnection attempt for $relayUrl (in backoff period)');
        }
      }
    });
  }
  
  /// Schedule reset of relay retry count after max backoff period  
  void _scheduleRelayBackoffReset(String relayUrl) {
    Timer(_maxBackoffDuration, () {
      if (!_isDisposed) {
        debugPrint('🔄 Resetting retry count for $relayUrl after backoff period');
        _relayRetryCount[relayUrl] = 0;
        _relayBackoffDuration.remove(relayUrl);
        
        // Try reconnecting once more
        if (_connectionService.isOnline) {
          _scheduleRelayReconnectWithBackoff(relayUrl);
        }
      }
    });
  }
  
  /// Check if we should attempt reconnection to a relay
  bool _shouldAttemptReconnection(String relayUrl) {
    final lastFailure = _relayLastFailureTime[relayUrl];
    if (lastFailure == null) return true;
    
    final backoffDuration = _relayBackoffDuration[relayUrl] ?? _initialRetryDelay;
    final timeSinceFailure = DateTime.now().difference(lastFailure);
    
    return timeSinceFailure >= backoffDuration;
  }
  
  /// Handle relay connection failure and increment retry count
  void _handleRelayConnectionFailure(String relayUrl, dynamic error) {
    _relayRetryCount[relayUrl] = (_relayRetryCount[relayUrl] ?? 0) + 1;
    _relayLastFailureTime[relayUrl] = DateTime.now();
    
    final retryCount = _relayRetryCount[relayUrl]!;
    
    debugPrint('❌ Relay connection failed: $relayUrl (attempt $retryCount/$_maxRetryAttempts) - $error');
    
    if (retryCount < _maxRetryAttempts) {
      _scheduleRelayReconnectWithBackoff(relayUrl);
    } else {
      debugPrint('🚫 Relay $relayUrl marked as temporarily unavailable after $retryCount failures');
      _scheduleRelayBackoffReset(relayUrl);
    }
  }
  
  /// Connect to a single relay
  Future<void> _connectToRelay(String relayUrl) async {
    try {
      debugPrint('🔌 Connecting to $relayUrl...');
      
      // Simple connection - the WebSocket will handle its own timeout behavior
      final webSocket = WebSocketChannel.connect(Uri.parse(relayUrl));
      
      _webSockets[relayUrl] = webSocket;
      
      if (!_connectedRelays.contains(relayUrl)) {
        _connectedRelays.add(relayUrl);
        _relayRetryCount[relayUrl] = 0; // Reset retry count on successful connection
        _relayLastFailureTime.remove(relayUrl); // Clear failure time
        _relayBackoffDuration.remove(relayUrl); // Clear backoff duration
        
        if (!_isDisposed) {
          notifyListeners();
        }
      }
      
      debugPrint('✅ Connected to relay: $relayUrl');
      
      // Listen for incoming messages
      webSocket.stream.listen(
        (data) => _handleRelayMessage(relayUrl, data),
        onError: (error) {
          debugPrint('❌ WebSocket error for $relayUrl: $error');
          _handleRelayDisconnection(relayUrl, error.toString());
        },
        onDone: () {
          debugPrint('🔌 Disconnected from relay: $relayUrl');
          _handleRelayDisconnection(relayUrl, 'Connection closed');
        },
      );
    } catch (e) {
      debugPrint('❌ Failed to connect to $relayUrl: $e');
      _handleRelayConnectionFailure(relayUrl, e);
      rethrow;
    }
  }
  
  /// Schedule general reconnection
  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_connectionService.isOnline && !_isInitialized) {
        debugPrint('🔄 Connection restored, attempting to reinitialize...');
        timer.cancel();
        initialize();
      }
    });
  }
  
  /// Start monitoring connection and auto-reconnect
  void _startReconnectionMonitoring() {
    _connectionService.addListener(() {
      if (_connectionService.isOnline && _connectedRelays.isEmpty) {
        debugPrint('🌐 Connection restored, attempting to reconnect to relays...');
        _reconnectToAllRelays();
      }
    });
  }
  
  /// Reconnect to all relays
  Future<void> _reconnectToAllRelays() async {
    if (!_connectionService.isOnline) return;
    
    debugPrint('🔄 Reconnecting to all relays...');
    final relaysToReconnect = [...defaultRelays];
    
    for (final relayUrl in relaysToReconnect) {
      if (!_connectedRelays.contains(relayUrl)) {
        try {
          await _connectToRelay(relayUrl);
        } catch (e) {
          debugPrint('❌ Failed to reconnect to $relayUrl: $e');
        }
      }
    }
  }
  
  /// Get connection status for debugging
  Map<String, dynamic> getConnectionStatus() {
    return {
      'isInitialized': _isInitialized,
      'connectedRelays': _connectedRelays.length,
      'totalRelays': defaultRelays.length,
      'retryAttempts': Map.from(_relayRetryCount),
      'connectionInfo': _connectionService.getConnectionInfo(),
    };
  }
  
  /// Get detailed relay status for debugging
  Map<String, dynamic> getDetailedRelayStatus() {
    final relayStatus = <String, Map<String, dynamic>>{};
    
    for (final relayUrl in defaultRelays) {
      final retryCount = _relayRetryCount[relayUrl] ?? 0;
      final lastFailure = _relayLastFailureTime[relayUrl];
      final backoffDuration = _relayBackoffDuration[relayUrl];
      final isConnected = _connectedRelays.contains(relayUrl);
      
      relayStatus[relayUrl] = {
        'connected': isConnected,
        'retryCount': retryCount,
        'lastFailure': lastFailure?.toIso8601String(),
        'backoffDurationSeconds': backoffDuration?.inSeconds,
        'maxRetriesReached': retryCount >= _maxRetryAttempts,
        'canRetry': retryCount < _maxRetryAttempts && _shouldAttemptReconnection(relayUrl),
      };
    }
    
    return {
      'relays': relayStatus,
      'summary': {
        'connected': _connectedRelays.length,
        'total': defaultRelays.length,
        'failed': _relayRetryCount.length,
        'inBackoff': _relayBackoffDuration.length,
      }
    };
  }
  
  @override
  void dispose() {
    if (_isDisposed) return;
    
    try {
      _isDisposed = true;
      _reconnectTimer?.cancel();
      
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
      _relayRetryCount.clear();
      _relayLastFailureTime.clear();
      _relayBackoffDuration.clear();
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