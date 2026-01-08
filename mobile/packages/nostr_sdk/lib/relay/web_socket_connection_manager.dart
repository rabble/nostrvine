// ABOUTME: Manages WebSocket connections with on-demand reconnection.
// ABOUTME: Single responsibility class for WebSocket lifecycle, designed for testability.

import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import 'package:web_socket_channel/web_socket_channel.dart';

/// Connection state for the WebSocket
enum ConnectionState { disconnected, connecting, connected }

/// Configuration for WebSocket connection behavior
class WebSocketConfig {
  /// Maximum number of reconnection attempts before giving up
  final int maxReconnectAttempts;

  /// Base delay for exponential backoff (doubles each attempt)
  final Duration baseReconnectDelay;

  /// Maximum delay between reconnection attempts
  final Duration maxReconnectDelay;

  /// Timeout for initial connection attempt
  final Duration connectionTimeout;

  /// Interval for heartbeat checks (0 to disable)
  ///
  /// When enabled, the connection manager periodically checks if the
  /// connection appears idle (no messages received). If idle for longer
  /// than [idleTimeout], the connection is considered dead and will be
  /// disconnected.
  final Duration heartbeatInterval;

  /// Maximum time without receiving a message before connection is
  /// considered dead
  ///
  /// Only applies when [heartbeatInterval] is non-zero.
  /// Set to Duration.zero to disable idle detection.
  final Duration idleTimeout;

  const WebSocketConfig({
    this.maxReconnectAttempts = 10,
    this.baseReconnectDelay = const Duration(seconds: 2),
    this.maxReconnectDelay = const Duration(minutes: 5),
    this.connectionTimeout = const Duration(seconds: 30),
    this.heartbeatInterval = const Duration(seconds: 30),
    this.idleTimeout = const Duration(seconds: 90),
  });

  /// Default configuration
  static const WebSocketConfig defaultConfig = WebSocketConfig();
}

/// Factory for creating WebSocket channels, injectable for testing
abstract class WebSocketChannelFactory {
  WebSocketChannel create(Uri uri);
}

/// Default factory using web_socket_channel
class DefaultWebSocketChannelFactory implements WebSocketChannelFactory {
  const DefaultWebSocketChannelFactory();

  @override
  WebSocketChannel create(Uri uri) {
    return WebSocketChannel.connect(uri);
  }
}

/// {@template web_socket_connection_manager}
/// Manages a single WebSocket connection with on-demand reconnection and
/// idle detection.
///
/// Reconnects automatically when:
/// - Sending a message while disconnected (triggers reconnect attempt)
/// - Connection is lost while active (stream error/done)
///
/// Idle Detection (heartbeat):
/// - Tracks when the last message was received
/// - Periodically checks if connection has been idle beyond [idleTimeout]
/// - Forces disconnect when idle, enabling reconnection on next send
/// - Configure via [WebSocketConfig.heartbeatInterval] and [idleTimeout]
///
/// Designed for testability with:
/// - Injectable WebSocketChannelFactory for mocking
/// - Stream-based state and message notifications
/// - Configurable timeouts and retry behavior
/// - Clear separation from protocol-specific logic
/// {@endtemplate}
class WebSocketConnectionManager {
  /// {@macro web_socket_connection_manager}
  WebSocketConnectionManager({
    required this.url,
    this.config = WebSocketConfig.defaultConfig,
    WebSocketChannelFactory? channelFactory,
    void Function(String)? logger,
  }) : _channelFactory =
           channelFactory ?? const DefaultWebSocketChannelFactory(),
       log = logger ?? _defaultLog;

  final String url;
  final WebSocketConfig config;
  final WebSocketChannelFactory _channelFactory;

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;

  // State management
  ConnectionState _state = ConnectionState.disconnected;
  int _reconnectAttempts = 0;
  bool _shouldReconnect = true;

  // Timers
  Timer? _reconnectTimer;
  Timer? _heartbeatTimer;

  // Activity tracking for idle detection
  DateTime? _lastActivityAt;

  // Stream controllers for external consumers
  final _stateController = StreamController<ConnectionState>.broadcast();
  final _messageController = StreamController<String>.broadcast();
  final _errorController = StreamController<String>.broadcast();

  /// Stream of connection state changes
  Stream<ConnectionState> get stateStream => _stateController.stream;

  /// Stream of received messages (raw strings)
  Stream<String> get messageStream => _messageController.stream;

  /// Stream of error messages
  Stream<String> get errorStream => _errorController.stream;

  /// Current connection state
  ConnectionState get state => _state;

  /// Whether currently connected
  bool get isConnected => _state == ConnectionState.connected;

  /// Number of reconnection attempts made
  int get reconnectAttempts => _reconnectAttempts;

  /// When the last message was received (or connection established)
  DateTime? get lastActivityAt => _lastActivityAt;

  /// Duration since last activity (or null if never connected)
  Duration? get idleDuration {
    if (_lastActivityAt == null) return null;
    return DateTime.now().difference(_lastActivityAt!);
  }

  /// Whether the connection appears idle (no activity beyond timeout)
  bool get isIdle {
    if (_state != ConnectionState.connected) return false;
    if (config.idleTimeout == Duration.zero) return false;
    final idle = idleDuration;
    if (idle == null) return false;
    return idle > config.idleTimeout;
  }

  /// Logger function, can be overridden for testing
  void Function(String message) log;

  static void _defaultLog(String message) {
    developer.log('[WebSocketConnectionManager] $message');
  }

  /// Connect to the WebSocket server
  Future<bool> connect() async {
    if (_state == ConnectionState.connected) {
      log('Already connected to $url');
      return true;
    }

    if (_state == ConnectionState.connecting) {
      log('Already connecting to $url');
      return false;
    }

    _shouldReconnect = true;
    return _doConnect();
  }

  Future<bool> _doConnect() async {
    _setState(ConnectionState.connecting);

    try {
      final uri = Uri.parse(url);
      if (uri.scheme != 'ws' && uri.scheme != 'wss') {
        throw ArgumentError('Invalid WebSocket URL scheme: ${uri.scheme}');
      }

      log('Connecting to $url');
      _channel = _channelFactory.create(uri);

      // Set up message listener
      _channelSubscription = _channel!.stream.listen(
        _onMessage,
        onError: _onStreamError,
        onDone: _onStreamDone,
        cancelOnError: false,
      );

      _setState(ConnectionState.connected);
      _reconnectAttempts = 0;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;

      // Track connection time as initial activity
      _lastActivityAt = DateTime.now();

      // Start heartbeat timer if configured
      _startHeartbeat();

      log('Connected to $url');

      return true;
    } catch (e) {
      log('Connection failed: $e');
      _errorController.add('Connection failed: $e');
      _setState(ConnectionState.disconnected);
      return false;
    }
  }

  void _onMessage(dynamic message) {
    _lastActivityAt = DateTime.now();
    if (message is String) {
      _messageController.add(message);
    } else {
      _messageController.add(message.toString());
    }
  }

  void _onStreamError(dynamic error) {
    log('Stream error: $error');
    _errorController.add('Stream error: $error');
    _handleDisconnect();
  }

  void _onStreamDone() {
    log('Stream closed by remote');
    _handleDisconnect();
  }

  void _handleDisconnect() {
    _stopHeartbeat();
    _channelSubscription?.cancel();
    _channelSubscription = null;
    _channel = null;

    _setState(ConnectionState.disconnected);
    // No automatic reconnection - reconnect happens on-demand when sending
  }

  /// Disconnect from the WebSocket server
  Future<void> disconnect() async {
    _shouldReconnect = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _stopHeartbeat();

    await _closeChannel();
    _setState(ConnectionState.disconnected);
    log('Disconnected from $url');
  }

  Future<void> _closeChannel() async {
    _channelSubscription?.cancel();
    _channelSubscription = null;

    if (_channel != null) {
      try {
        await _channel!.sink.close();
      } catch (e) {
        log('Error closing channel: $e');
      }
      _channel = null;
    }
  }

  /// Send a message through the WebSocket.
  ///
  /// If disconnected, attempts to reconnect first.
  /// Returns true if message was sent, false if send failed.
  Future<bool> send(String message) async {
    // Try to reconnect if disconnected
    if (_state == ConnectionState.disconnected) {
      log('Disconnected, attempting reconnect before send');
      final connected = await _tryReconnect();
      if (!connected) {
        log('Reconnect failed, cannot send');
        return false;
      }
    }

    // Wait if currently connecting
    if (_state == ConnectionState.connecting) {
      log('Connecting, waiting before send');
      final connected = await _waitForConnection();
      if (!connected) {
        log('Connection failed, cannot send');
        return false;
      }
    }

    return _doSend(message);
  }

  /// Send a message synchronously (no reconnection attempt).
  ///
  /// Returns true if message was sent, false if not connected.

  bool _doSend(String message) {
    if (_channel == null) return false;

    try {
      _channel!.sink.add(message);
      return true;
    } catch (e) {
      log('Send error: $e');
      _errorController.add('Send error: $e');
      _handleDisconnect();
      return false;
    }
  }

  /// Send a JSON-encodable message asynchronously (with reconnection)
  Future<bool> sendJson(dynamic data) async {
    try {
      final encoded = jsonEncode(data);
      return send(encoded);
    } catch (e) {
      log('JSON encode error: $e');
      _errorController.add('JSON encode error: $e');
      return false;
    }
  }

  /// Send a JSON-encodable message synchronously (no reconnection)

  // --- Reconnection ---

  Future<bool> _tryReconnect() async {
    while (_shouldReconnect && _state == ConnectionState.disconnected) {
      if (_reconnectAttempts >= config.maxReconnectAttempts) {
        log('Max reconnect attempts reached for $url');
        _errorController.add('Max reconnect attempts reached');
        return false;
      }

      // Exponential backoff: base * 2^attempts, capped at max
      final delayMs =
          (config.baseReconnectDelay.inMilliseconds *
                  (1 << _reconnectAttempts.clamp(0, 8)))
              .clamp(0, config.maxReconnectDelay.inMilliseconds);
      final delay = Duration(milliseconds: delayMs);

      _reconnectAttempts++;
      log(
        'Reconnecting in ${delay.inSeconds}s (attempt $_reconnectAttempts/${config.maxReconnectAttempts})',
      );

      await Future<void>.delayed(delay);

      if (!_shouldReconnect) return false;

      final connected = await _doConnect();
      if (connected) return true;
    }

    return _state == ConnectionState.connected;
  }

  Future<bool> _waitForConnection() async {
    // Wait up to connectionTimeout for connection to complete
    final completer = Completer<bool>();
    StreamSubscription<ConnectionState>? sub;

    sub = stateStream.listen((state) {
      if (state == ConnectionState.connected) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(true);
      } else if (state == ConnectionState.disconnected) {
        sub?.cancel();
        if (!completer.isCompleted) completer.complete(false);
      }
    });

    // Also check current state
    if (_state == ConnectionState.connected) {
      sub.cancel();
      return true;
    }

    final result = await completer.future.timeout(
      config.connectionTimeout,
      onTimeout: () {
        sub?.cancel();
        return false;
      },
    );

    return result;
  }

  /// Reset reconnection state, allowing fresh attempts
  void resetReconnection() {
    _reconnectAttempts = 0;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Force immediate reconnection, resetting backoff
  Future<bool> reconnect() async {
    resetReconnection();
    _shouldReconnect = true;
    await _closeChannel();
    _setState(ConnectionState.disconnected);
    return _doConnect();
  }

  // --- Heartbeat / Idle Detection ---

  void _startHeartbeat() {
    if (config.heartbeatInterval == Duration.zero) return;

    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(config.heartbeatInterval, (_) {
      _onHeartbeat();
    });
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  void _onHeartbeat() {
    if (_state != ConnectionState.connected) return;
    if (config.idleTimeout == Duration.zero) return;

    final idle = idleDuration;
    if (idle != null && idle > config.idleTimeout) {
      log(
        'Connection idle for ${idle.inSeconds}s (timeout: '
        '${config.idleTimeout.inSeconds}s), forcing disconnect',
      );
      _handleDisconnect();
    }
  }

  /// Check if the connection is healthy and force disconnect if idle.
  ///
  /// Returns true if the connection is healthy (connected and not idle),
  /// false if disconnected or was disconnected due to idle timeout.
  bool checkHealth() {
    if (_state != ConnectionState.connected) return false;

    if (isIdle) {
      log('Health check failed: connection idle, forcing disconnect');
      _handleDisconnect();
      return false;
    }

    return true;
  }

  // --- State management ---

  void _setState(ConnectionState newState) {
    if (_state != newState) {
      _state = newState;
      _stateController.add(newState);
    }
  }

  /// Dispose of resources
  Future<void> dispose() async {
    await disconnect();
    await _stateController.close();
    await _messageController.close();
    await _errorController.close();
  }
}
