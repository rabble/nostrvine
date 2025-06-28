// ABOUTME: Core Nostr service for event broadcasting and relay management
// ABOUTME: Handles connection, authentication, and event publishing for OpenVine

import 'dart:async';
import 'dart:convert';
import 'dart:collection';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/nip94_metadata.dart';
import 'nostr_key_manager.dart';
import 'nostr_service_interface.dart';
import 'connection_status_service.dart';

/// Relay connection status
enum RelayStatus { connected, connecting, disconnected }

/// Core service for Nostr protocol integration
class NostrService extends ChangeNotifier implements INostrService {
  static const List<String> defaultRelays = [
    'wss://vine.hol.is',
  ];
  
  static const String _relaysPrefsKey = 'custom_relays';
  
  final NostrKeyManager _keyManager;
  final ConnectionStatusService _connectionService = ConnectionStatusService();
  bool _isInitialized = false;
  bool _isDisposed = false;
  final List<String> _connectedRelays = [];
  final List<String> _relays = []; // All configured relays
  final Map<String, RelayStatus> _relayStatuses = {}; // Status tracking
  final Map<String, WebSocketChannel> _webSockets = {};
  final Map<String, StreamController<Event>> _eventControllers = {};
  final Map<String, int> _relayRetryCount = {};
  final Map<String, DateTime> _relayLastFailureTime = {};
  final Map<String, Duration> _relayBackoffDuration = {};
  Timer? _reconnectTimer;
  
  // Event deduplication to prevent infinite rebuild loops
  final LinkedHashSet<String> _seenEventIds = LinkedHashSet<String>();
  static const int _maxSeenEventIds = 5000; // Keep track of recent event IDs
  
  // Duplicate event aggregation for logging
  int _duplicateEventCount = 0;
  DateTime? _lastDuplicateLogTime;
  
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
  List<String> get relays => List.unmodifiable(_relays);
  Map<String, RelayStatus> get relayStatuses => Map.unmodifiable(_relayStatuses);
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
      
      // Load saved relays from preferences
      final prefs = await SharedPreferences.getInstance();
      final savedRelays = prefs.getStringList(_relaysPrefsKey);
      
      // Use saved relays, custom relays, or default relays (in that order)
      final relaysToConnect = savedRelays ?? customRelays ?? defaultRelays;
      _relays.clear();
      _relays.addAll(relaysToConnect);
      
      // Initialize relay statuses
      for (final relay in _relays) {
        _relayStatuses[relay] = RelayStatus.disconnected;
      }
      
      debugPrint('📡 Attempting to connect to ${relaysToConnect.length} relays using web-compatible nostr package...');
      
      // Connect to each relay
      for (final relayUrl in relaysToConnect) {
        try {
          _relayStatuses[relayUrl] = RelayStatus.connecting;
          notifyListeners();
          
          final webSocket = WebSocketChannel.connect(Uri.parse(relayUrl));
          _webSockets[relayUrl] = webSocket;
          
          if (!_connectedRelays.contains(relayUrl)) {
            _connectedRelays.add(relayUrl);
            _relayStatuses[relayUrl] = RelayStatus.connected;
            if (!_isDisposed) {
              notifyListeners();
            }
          }
          
          // Listen for incoming messages
          webSocket.stream.listen(
            (data) => _handleRelayMessage(relayUrl, data),
            onError: (error) => _handleRelayDisconnection(relayUrl, error.toString()),
            onDone: () => _handleRelayDisconnection(relayUrl, 'Connection closed'),
          );
          
        } catch (e) {
          _relayRetryCount[relayUrl] = (_relayRetryCount[relayUrl] ?? 0) + 1;
          
          // Check if it's a connection issue
          if (_isConnectionError(e)) {
            _handleRelayConnectionFailure(relayUrl, e);
          }
        }
      }
      
      // Give connections time to establish
      await Future.delayed(const Duration(seconds: 2));
      
      _isInitialized = true;
      if (!_isDisposed) {
        notifyListeners();
      }
      
      
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
        // Parse JSON message manually since nostr_sdk doesn't expose Message class
      final jsonData = jsonDecode(data);
      final messageType = jsonData[0] as String;
      switch (messageType.toLowerCase()) {
        case 'event':
          // Parse EVENT message: ["EVENT", subscriptionId, eventObject]
          if (jsonData.length >= 3) {
            try {
              final eventData = jsonData[2] as Map<String, dynamic>;
              final event = Event.fromJson(eventData);
              _handleEventMessage(event);
            } catch (e) {
              debugPrint('⚠️ Error parsing EVENT: $e');
            }
          }
          break;
        case 'eose':
          debugPrint('📄 End of stored events from $relayUrl');
          break;
        case 'ok':
          debugPrint('✅ Event published successfully to $relayUrl');
          break;
        case 'notice':
          // For NOTICE messages: ["NOTICE", message]
          final noticeMessage = jsonData.length > 1 ? jsonData[1] : 'Unknown notice';
          debugPrint('📢 Notice from $relayUrl: $noticeMessage');
          break;
        case 'auth':
          // Handle NIP-42 AUTH challenge: ["AUTH", challenge]
          if (jsonData.length >= 2) {
            final challenge = jsonData[1] as String;
            debugPrint('🔐 AUTH challenge from $relayUrl: $challenge');
            _handleAuthChallenge(relayUrl, challenge);
          }
          break;
      }
      }
    } catch (e) {
      debugPrint('⚠️ Error parsing message from $relayUrl: $e');
    }
  }
  
  /// Handle incoming event message
  void _handleEventMessage(Event event) {
    try {
      // Check for duplicate events to prevent infinite rebuild loops
      if (_seenEventIds.contains(event.id)) {
        _duplicateEventCount++;
        _logDuplicateEventsAggregated();
        return;
      }
      
      // Add to seen events and manage memory
      _seenEventIds.add(event.id);
      if (_seenEventIds.length > _maxSeenEventIds) {
        // Remove oldest event ID to prevent unbounded memory growth
        _seenEventIds.remove(_seenEventIds.first);
      }
      
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
  
  /// Handle NIP-42 AUTH challenge from relay
  void _handleAuthChallenge(String relayUrl, String challenge) async {
    try {
      if (!_keyManager.hasKeys) {
        debugPrint('❌ Cannot authenticate - no keys available');
        return;
      }
      
      // Create AUTH event (kind 22242) according to NIP-42
      final authEvent = await _createAuthEvent(relayUrl, challenge);
      
      if (authEvent != null) {
        // Send AUTH response to the specific relay
        final authMessage = jsonEncode(['AUTH', authEvent.toJson()]);
        final webSocket = _webSockets[relayUrl];
        
        if (webSocket != null) {
          webSocket.sink.add(authMessage);
          debugPrint('🔐 Sent AUTH response to $relayUrl');
        } else {
          debugPrint('❌ WebSocket not available for AUTH response to $relayUrl');
        }
      }
    } catch (e) {
      debugPrint('❌ Error handling AUTH challenge: $e');
    }
  }
  
  /// Create NIP-42 AUTH event
  Future<Event?> _createAuthEvent(String relayUrl, String challenge) async {
    try {
      if (!_keyManager.hasKeys || _keyManager.keyPair == null) {
        return null;
      }
      
      // Create AUTH event according to NIP-42
      final tags = [
        ['relay', relayUrl],
        ['challenge', challenge],
      ];
      
      // Create the event with kind 22242 (AUTH)
      final event = Event(
        _keyManager.publicKey!, // public key
        22242, // NIP-42 AUTH event kind
        tags,
        '', // empty content for AUTH events
      );
      
      // Sign the event with private key
      event.sign(_keyManager.keyPair!.private);
      
      debugPrint('🔐 Created AUTH event for $relayUrl');
      return event;
    } catch (e) {
      debugPrint('❌ Error creating AUTH event: $e');
      return null;
    }
  }
  
  /// Log duplicate events in an aggregated manner to reduce noise
  void _logDuplicateEventsAggregated() {
    final now = DateTime.now();
    
    // Log aggregated duplicates every 30 seconds or every 50 duplicates
    if (_lastDuplicateLogTime == null || 
        now.difference(_lastDuplicateLogTime!).inSeconds >= 30 ||
        _duplicateEventCount % 50 == 0) {
      
      if (_duplicateEventCount > 0) {
        debugPrint('⏩ Skipped $_duplicateEventCount duplicate events in last ${_lastDuplicateLogTime != null ? now.difference(_lastDuplicateLogTime!).inSeconds : 0}s');
      }
      
      _lastDuplicateLogTime = now;
      _duplicateEventCount = 0;
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
      
      // Send event to each connected relay using manual JSON serialization
      final eventMessage = jsonEncode(['EVENT', event.toJson()]);
      
      for (final relayUrl in _connectedRelays) {
        try {
          final webSocket = _webSockets[relayUrl];
          if (webSocket != null) {
            webSocket.sink.add(eventMessage);
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
    
    // Convert Keychain to SimpleKeyPair for compatibility
    final simpleKeyPair = SimpleKeyPair(
      public: _keyManager.keyPair!.public,
      private: _keyManager.keyPair!.private,
    );
    
    final event = metadata.toNostrEvent(
      keyPairs: simpleKeyPair,
      content: content,
      hashtags: hashtags,
    );
    
    return await broadcastEvent(event);
  }
  
  /// Publish a NIP-71 short video event (kind 22)
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

    try {
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
      
      // Create the event using nostr_sdk Event constructor
      final createdAt = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final event = Event(
        _keyManager.keyPair!.public,
        22,
        tags,
        content,
        createdAt: createdAt,
      );
      
      // Sign the event
      event.sign(_keyManager.keyPair!.private);
      
      debugPrint('🎬 Created Kind 22 video event: ${event.id}');
      debugPrint('📹 Video URL: $videoUrl');
      if (title != null) debugPrint('📝 Title: $title');
      if (thumbnailUrl != null) debugPrint('🖼️ Thumbnail: $thumbnailUrl');
      
      // Broadcast to relays
      return await broadcastEvent(event);
      
    } catch (e) {
      debugPrint('❌ Failed to publish video event: $e');
      rethrow;
    }
  }
  
  // Subscription management for deduplication
  final Map<String, StreamController<Event>> _sharedSubscriptions = {};
  final Map<String, int> _subscriptionRefCounts = {};
  
  // Connection throttling to prevent relay overload
  static const int _maxConcurrentSubscriptions = 15; // Increased for profile screens
  static const Duration _subscriptionDelay = Duration(milliseconds: 100);
  static const Duration _subscriptionTimeout = Duration(minutes: 5); // Shorter timeout for faster cleanup
  
  // Track subscription creation times for automatic cleanup
  final Map<String, DateTime> _subscriptionTimes = {};
  
  /// Subscribe to events with automatic deduplication
  @override
  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
  }) {
    if (!_isInitialized) {
      throw NostrServiceException('Nostr service not initialized');
    }
    
    // Check current active subscriptions to prevent relay overload
    if (_eventControllers.length >= _maxConcurrentSubscriptions) {
      debugPrint('🚫 BLOCKING: Too many active subscriptions (${_eventControllers.length}/$_maxConcurrentSubscriptions)');
      throw NostrServiceException('Too many concurrent subscriptions - relay protection active');
    }
    
    if (_eventControllers.length >= (_maxConcurrentSubscriptions * 0.75)) {
      debugPrint('⚠️ WARNING: ${_eventControllers.length}/$_maxConcurrentSubscriptions active subscriptions - approaching limit');
      // Force cleanup when approaching limit
      _cleanupOldSubscriptions();
    }
    
    // Create filter signature for deduplication
    final filterSignature = _createFilterSignature(filters);
    
    // Check if we already have a subscription for this exact filter
    if (_sharedSubscriptions.containsKey(filterSignature)) {
      _subscriptionRefCounts[filterSignature] = (_subscriptionRefCounts[filterSignature] ?? 0) + 1;
      return _sharedSubscriptions[filterSignature]!.stream;
    }
    
    // Create a unique subscription ID with microseconds for uniqueness
    final now = DateTime.now();
    final subscriptionId = '${now.millisecondsSinceEpoch}_${now.microsecond}';
    
    // Create stream controller for this subscription
    final controller = StreamController<Event>.broadcast(
      onCancel: () {
        // Decrease reference count and close if no more references
        _decreaseSubscriptionRef(filterSignature, subscriptionId);
      },
    );
    
    _eventControllers[subscriptionId] = controller;
    _sharedSubscriptions[filterSignature] = controller;
    _subscriptionRefCounts[filterSignature] = 1;
    _subscriptionTimes[subscriptionId] = DateTime.now();
    
    // Clean up old subscriptions periodically
    _cleanupOldSubscriptions();
    
    // Send REQ message to all connected relays using manual JSON serialization
    final reqFilters = filters.map((f) => f.toJson()).toList();
    final reqMessage = jsonEncode(['REQ', subscriptionId, ...reqFilters]);
    
    // Send requests with throttling to prevent overwhelming relays
    _sendRequestsWithThrottling(reqMessage, subscriptionId);
    
    
    return controller.stream;
  }
  
  /// Create a unique signature for filter deduplication
  String _createFilterSignature(List<Filter> filters) {
    final signature = filters.map((f) => f.toJson().toString()).join('|');
    return signature.hashCode.toString();
  }
  
  /// Decrease subscription reference count and clean up if needed
  void _decreaseSubscriptionRef(String filterSignature, String subscriptionId) {
    final refCount = (_subscriptionRefCounts[filterSignature] ?? 1) - 1;
    
    if (refCount <= 0) {
      debugPrint('🔐 Closing shared subscription: $filterSignature');
      _closeSubscription(subscriptionId);
      _sharedSubscriptions.remove(filterSignature);
      _subscriptionRefCounts.remove(filterSignature);
    } else {
      _subscriptionRefCounts[filterSignature] = refCount;
    }
  }
  
  /// Clean up old subscriptions to prevent accumulation
  void _cleanupOldSubscriptions() {
    final now = DateTime.now();
    final expiredSubscriptions = <String>[];
    
    for (final entry in _subscriptionTimes.entries) {
      final subscriptionId = entry.key;
      final createdAt = entry.value;
      
      if (now.difference(createdAt) > _subscriptionTimeout) {
        expiredSubscriptions.add(subscriptionId);
      }
    }
    
    for (final subscriptionId in expiredSubscriptions) {
      _closeSubscription(subscriptionId);
      _subscriptionTimes.remove(subscriptionId);
    }
  }
  
  /// Send requests to relays with throttling to prevent overwhelming
  void _sendRequestsWithThrottling(String reqMessage, String subscriptionId) {
    
    // Send to relays with staggered timing
    for (int i = 0; i < _connectedRelays.length; i++) {
      final relayUrl = _connectedRelays[i];
      
      // Use timer to stagger requests
      Timer(Duration(milliseconds: i * _subscriptionDelay.inMilliseconds), () {
        try {
          final webSocket = _webSockets[relayUrl];
          if (webSocket != null) {
            webSocket.sink.add(reqMessage);
          }
        } catch (e) {
          debugPrint('❌ Failed to send subscription to $relayUrl: $e');
        }
      });
    }
  }
  
  /// Close a specific subscription by sending CLOSE messages to all relays
  void _closeSubscription(String subscriptionId) {
    
    // Send CLOSE message to all connected relays using manual JSON serialization
    final closeMessage = jsonEncode(['CLOSE', subscriptionId]);
    
    for (final relayUrl in _connectedRelays) {
      try {
        final webSocket = _webSockets[relayUrl];
        if (webSocket != null) {
          webSocket.sink.add(closeMessage);
        }
      } catch (e) {
        debugPrint('❌ Failed to send CLOSE to $relayUrl: $e');
      }
    }
    
    // Clean up the controller and timing info
    _eventControllers.remove(subscriptionId);
    _subscriptionTimes.remove(subscriptionId);
  }
  
  /// Add a new relay
  Future<bool> addRelay(String relayUrl) async {
    if (_relays.contains(relayUrl)) {
      return true; // Already in list
    }
    
    try {
      debugPrint('🔌 Adding new relay: $relayUrl');
      
      // Add to relay list and save
      _relays.add(relayUrl);
      await _saveRelays();
      
      // Initialize status and try to connect
      _relayStatuses[relayUrl] = RelayStatus.connecting;
      notifyListeners();
      
      final webSocket = WebSocketChannel.connect(Uri.parse(relayUrl));
      _webSockets[relayUrl] = webSocket;
      
      _connectedRelays.add(relayUrl);
      _relayStatuses[relayUrl] = RelayStatus.connected;
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
          _relayStatuses[relayUrl] = RelayStatus.disconnected;
          if (!_isDisposed) {
            notifyListeners();
          }
        },
        onDone: () {
          debugPrint('🔌 Disconnected from relay: $relayUrl');
          _connectedRelays.remove(relayUrl);
          _webSockets.remove(relayUrl);
          _relayStatuses[relayUrl] = RelayStatus.disconnected;
          if (!_isDisposed) {
            notifyListeners();
          }
        },
      );
      
      return true;
    } catch (e) {
      debugPrint('⚠️ Failed to add relay $relayUrl: $e');
      _relayStatuses[relayUrl] = RelayStatus.disconnected;
      notifyListeners();
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
      _relays.remove(relayUrl);
      _relayStatuses.remove(relayUrl);
      
      // Save updated relay list
      await _saveRelays();
      
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
  
  /// Dispose service and close all connections
  /// Handle relay disconnection with retry logic
  void _handleRelayDisconnection(String relayUrl, String reason) {
    _connectedRelays.remove(relayUrl);
    _webSockets.remove(relayUrl);
    _relayStatuses[relayUrl] = RelayStatus.disconnected;
    
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
      
      // For vine.hol.is, proactively send client info for smoother auth
      if (relayUrl.contains('vine.hol.is')) {
        debugPrint('🔐 Preparing for potential AUTH with vine.hol.is');
        // The relay will send an AUTH challenge if needed
      }
      
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
  
  /// Save relay list to preferences
  Future<void> _saveRelays() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList(_relaysPrefsKey, _relays);
      debugPrint('💾 Saved ${_relays.length} relays to preferences');
    } catch (e) {
      debugPrint('❌ Failed to save relays: $e');
    }
  }
  
  /// Reconnect to all configured relays
  Future<void> reconnectAll() async {
    debugPrint('🔄 Reconnecting to all relays...');
    
    // Close existing connections
    for (final relayUrl in List<String>.from(_connectedRelays)) {
      try {
        final webSocket = _webSockets[relayUrl];
        if (webSocket != null) {
          await webSocket.sink.close();
        }
        _webSockets.remove(relayUrl);
        _connectedRelays.remove(relayUrl);
        _relayStatuses[relayUrl] = RelayStatus.disconnected;
      } catch (e) {
        debugPrint('⚠️ Error closing connection to $relayUrl: $e');
      }
    }
    
    notifyListeners();
    
    // Reconnect to all relays
    for (final relayUrl in _relays) {
      try {
        _relayStatuses[relayUrl] = RelayStatus.connecting;
        notifyListeners();
        
        final webSocket = WebSocketChannel.connect(Uri.parse(relayUrl));
        _webSockets[relayUrl] = webSocket;
        
        _connectedRelays.add(relayUrl);
        _relayStatuses[relayUrl] = RelayStatus.connected;
        notifyListeners();
        
        // Listen for incoming messages
        webSocket.stream.listen(
          (data) => _handleRelayMessage(relayUrl, data),
          onError: (error) => _handleRelayDisconnection(relayUrl, error.toString()),
          onDone: () => _handleRelayDisconnection(relayUrl, 'Connection closed'),
        );
      } catch (e) {
        debugPrint('❌ Failed to reconnect to $relayUrl: $e');
        _relayStatuses[relayUrl] = RelayStatus.disconnected;
        _handleRelayConnectionFailure(relayUrl, e);
      }
    }
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
      _relays.clear();
      _relayStatuses.clear();
      _relayRetryCount.clear();
      _relayLastFailureTime.clear();
      _relayBackoffDuration.clear();
      _seenEventIds.clear();
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