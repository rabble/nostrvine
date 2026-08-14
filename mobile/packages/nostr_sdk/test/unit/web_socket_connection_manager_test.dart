// ABOUTME: Unit tests for WebSocketConnectionManager.
// ABOUTME: Tests connection lifecycle and on-demand reconnection logic.

import 'dart:async';

import 'package:nostr_sdk/relay/web_socket_connection_manager.dart';
import 'package:test/test.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Mock WebSocket sink for testing
class MockWebSocketSink implements WebSocketSink {
  final List<dynamic> messages = [];
  bool closed = false;
  int? closeCode;
  String? closeReason;
  final Completer<void> _doneCompleter = Completer<void>();

  /// When set, [close] does not finish until this completer completes.
  Completer<void>? closeGate;

  @override
  void add(dynamic data) {
    if (closed) throw StateError('Sink is closed');
    messages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future addStream(Stream stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future close([int? closeCode, String? closeReason]) async {
    this.closeCode = closeCode;
    this.closeReason = closeReason;
    final gate = closeGate;
    if (gate != null) await gate.future;
    closed = true;
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future get done => _doneCompleter.future;
}

/// Mock WebSocket channel for testing
class MockWebSocketChannel implements WebSocketChannel {
  MockWebSocketChannel({Future<void>? readyFuture})
    : _readyFuture = readyFuture ?? Future.value();

  final MockWebSocketSink _sink = MockWebSocketSink();
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();
  final Future<void> _readyFuture;
  int? _closeCode;

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream get stream => _streamController.stream;

  @override
  int? get closeCode => _closeCode;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready => _readyFuture;

  // StreamChannel interface methods - use noSuchMethod for unneeded methods
  @override
  dynamic noSuchMethod(Invocation invocation) {
    // These methods are not used in tests
    throw UnimplementedError(
      '${invocation.memberName} not implemented in mock',
    );
  }

  /// Simulate receiving a message from the server
  void simulateMessage(dynamic message) {
    _streamController.add(message);
  }

  /// Simulate an error from the server
  void simulateError(Object error) {
    _streamController.addError(error);
  }

  /// Simulate the connection being closed by the server
  void simulateClose() {
    _closeCode = 1000;
    _streamController.close();
  }

  /// Holds [sink]'s close in flight until the returned completer completes.
  ///
  /// A real close is a network round trip that can outlive a reconnect; the
  /// mock otherwise finishes it synchronously, which hides ordering bugs.
  Completer<void> blockClose() {
    final gate = Completer<void>();
    _sink.closeGate = gate;
    return gate;
  }

  List<dynamic> get sentMessages => _sink.messages;
  bool get isClosed => _sink.closed;
}

/// Mock factory that returns controllable mock channels
class MockWebSocketChannelFactory implements WebSocketChannelFactory {
  final List<MockWebSocketChannel> createdChannels = [];
  bool shouldFail = false;
  String? failureMessage;

  /// When set, the channel's `ready` future completes with this error
  /// instead of succeeding. Simulates DNS/TLS handshake failures.
  Object? readyError;

  @override
  WebSocketChannel create(Uri uri) {
    if (shouldFail) {
      throw Exception(failureMessage ?? 'Connection failed');
    }
    final channel = MockWebSocketChannel(
      readyFuture: readyError != null
          ? Future.error(readyError!)
          : Future.value(),
    );
    createdChannels.add(channel);
    return channel;
  }

  MockWebSocketChannel? get lastChannel =>
      createdChannels.isNotEmpty ? createdChannels.last : null;

  void reset() {
    createdChannels.clear();
    shouldFail = false;
    failureMessage = null;
    readyError = null;
  }
}

void main() {
  group('WebSocketConnectionManager', () {
    late MockWebSocketChannelFactory mockFactory;
    late WebSocketConnectionManager manager;
    late List<String> logMessages;

    setUp(() {
      mockFactory = MockWebSocketChannelFactory();
      logMessages = [];
      manager = WebSocketConnectionManager(
        url: 'wss://test.relay.com',
        channelFactory: mockFactory,
        logger: (msg) => logMessages.add(msg),
        config: const WebSocketConfig(
          maxReconnectAttempts: 3,
          baseReconnectDelay: Duration(milliseconds: 10),
          maxReconnectDelay: Duration(milliseconds: 100),
          connectionTimeout: Duration(milliseconds: 500),
        ),
      );
    });

    tearDown(() async {
      await manager.dispose();
    });

    group('connection', () {
      test('connects successfully', () async {
        final result = await manager.connect();

        expect(result, isTrue);
        expect(manager.state, equals(ConnectionState.connected));
        expect(manager.isConnected, isTrue);
        expect(mockFactory.createdChannels.length, equals(1));
      });

      test('emits state changes on connect', () async {
        final states = <ConnectionState>[];
        manager.stateStream.listen(states.add);

        await manager.connect();
        await Future.delayed(Duration.zero);

        expect(states, contains(ConnectionState.connecting));
        expect(states, contains(ConnectionState.connected));
      });

      test('rejects invalid URL scheme', () async {
        final badManager = WebSocketConnectionManager(
          url: 'http://invalid.com',
          channelFactory: mockFactory,
          logger: (msg) => logMessages.add(msg),
        );

        final result = await badManager.connect();

        expect(result, isFalse);
        expect(badManager.state, equals(ConnectionState.disconnected));

        await badManager.dispose();
      });

      test('returns true if already connected', () async {
        await manager.connect();

        final result = await manager.connect();

        expect(result, isTrue);
        expect(mockFactory.createdChannels.length, equals(1));
      });

      test('handles connection failure', () async {
        mockFactory.shouldFail = true;
        mockFactory.failureMessage = 'Network error';

        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        final result = await manager.connect();

        expect(result, isFalse);
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(errors, isNotEmpty);
      });

      test('handles DNS lookup failure via ready', () async {
        mockFactory.readyError = WebSocketChannelException(
          'SocketException: Failed host lookup: '
          "'relay.divine.video'",
        );

        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        final result = await manager.connect();
        // Allow broadcast stream event to propagate
        await Future<void>.delayed(Duration.zero);

        expect(result, isFalse);
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(errors, isNotEmpty);
        expect(errors.first, contains('Connection failed'));
      });

      test('handles connection timeout via ready', () async {
        // Create a ready future that never completes
        final neverCompleter = Completer<void>();
        mockFactory.readyError = null;

        // Override the factory to use a channel with a never-completing ready
        final slowFactory = _SlowReadyFactory(neverCompleter.future);
        final slowManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: slowFactory,
          logger: (msg) => logMessages.add(msg),
          config: const WebSocketConfig(
            connectionTimeout: Duration(milliseconds: 100),
          ),
        );

        final errors = <String>[];
        slowManager.errorStream.listen(errors.add);

        final result = await slowManager.connect();

        expect(result, isFalse);
        expect(slowManager.state, equals(ConnectionState.disconnected));
        expect(errors, isNotEmpty);
        expect(errors.first, contains('timed out'));

        await slowManager.dispose();
      });
    });

    group('disconnection', () {
      test('disconnects cleanly', () async {
        await manager.connect();

        await manager.disconnect();

        expect(manager.state, equals(ConnectionState.disconnected));
        expect(manager.isConnected, isFalse);
        expect(mockFactory.lastChannel!.isClosed, isTrue);
      });

      test('emits disconnected state', () async {
        await manager.connect();

        final states = <ConnectionState>[];
        manager.stateStream.listen(states.add);

        await manager.disconnect();
        await Future.delayed(Duration.zero);

        expect(states, contains(ConnectionState.disconnected));
      });

      test('stays disconnected when relay closes connection', () async {
        await manager.connect();

        mockFactory.lastChannel!.simulateClose();
        await Future.delayed(const Duration(milliseconds: 50));

        // Should stay disconnected - no automatic reconnect
        expect(manager.state, equals(ConnectionState.disconnected));
        expect(mockFactory.createdChannels.length, equals(1));
      });
    });

    // The idle heartbeat and checkHealth() tear down a *live* socket, unlike
    // the stream-error/stream-done paths where the transport is already gone.
    // Dropping the channel reference without closing the sink strands an open
    // connection the manager no longer has a handle to.
    group('idle disconnect', () {
      test('closes the channel sink when the heartbeat forces a '
          'disconnect', () async {
        final factory = MockWebSocketChannelFactory();
        final idleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            heartbeatInterval: Duration(milliseconds: 20),
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(idleManager.dispose);

        await idleManager.connect();
        final idleChannel = factory.lastChannel!;
        expect(idleChannel.isClosed, isFalse);

        await Future<void>.delayed(const Duration(milliseconds: 120));

        expect(idleManager.state, equals(ConnectionState.disconnected));
        expect(idleChannel.isClosed, isTrue);
      });

      test('closes the channel sink when checkHealth finds a stale '
          'connection', () async {
        final factory = MockWebSocketChannelFactory();
        final staleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            // No heartbeat timer: checkHealth is the only disconnect trigger.
            heartbeatInterval: Duration.zero,
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(staleManager.dispose);

        await staleManager.connect();
        final staleChannel = factory.lastChannel!;
        await Future<void>.delayed(const Duration(milliseconds: 30));

        expect(staleManager.checkHealth(), isFalse);
        await Future<void>.delayed(Duration.zero);

        expect(staleManager.state, equals(ConnectionState.disconnected));
        expect(staleChannel.isClosed, isTrue);
      });

      test('reconnects onto a usable fresh channel after an idle '
          'disconnect', () async {
        final factory = MockWebSocketChannelFactory();
        final staleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            baseReconnectDelay: Duration(milliseconds: 10),
            heartbeatInterval: Duration.zero,
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(staleManager.dispose);

        await staleManager.connect();
        final staleChannel = factory.lastChannel!;
        await Future<void>.delayed(const Duration(milliseconds: 30));
        staleManager.checkHealth();

        final sent = await staleManager.send('["REQ","sub1",{}]');

        // Exactly one live socket per cycle: the idle one is closed and the
        // fresh one still works.
        expect(sent, isTrue);
        expect(staleChannel.isClosed, isTrue);
        expect(factory.createdChannels, hasLength(2));
        final freshChannel = factory.lastChannel!;
        expect(freshChannel, isNot(same(staleChannel)));
        expect(freshChannel.isClosed, isFalse);
        expect(freshChannel.sentMessages, contains('["REQ","sub1",{}]'));
      });

      test('keeps the reconnected channel when a slow close lands '
          'late', () async {
        final factory = MockWebSocketChannelFactory();
        final staleManager = WebSocketConnectionManager(
          url: 'wss://test.relay.com',
          channelFactory: factory,
          logger: logMessages.add,
          config: const WebSocketConfig(
            baseReconnectDelay: Duration(milliseconds: 10),
            heartbeatInterval: Duration.zero,
            idleTimeout: Duration(milliseconds: 10),
          ),
        );
        addTearDown(staleManager.dispose);

        await staleManager.connect();
        final staleChannel = factory.lastChannel!;
        final closeGate = staleChannel.blockClose();
        await Future<void>.delayed(const Duration(milliseconds: 30));
        staleManager.checkHealth();

        expect(await staleManager.send('["REQ","sub1",{}]'), isTrue);
        final freshChannel = factory.lastChannel!;

        closeGate.complete();
        await Future<void>.delayed(Duration.zero);

        // The late close must not detach the channel it never owned, or the
        // manager reports connected while every send drops on the floor.
        expect(staleChannel.isClosed, isTrue);
        expect(staleManager.isConnected, isTrue);
        expect(await staleManager.send('["REQ","sub2",{}]'), isTrue);
        expect(freshChannel.sentMessages, contains('["REQ","sub2",{}]'));
      });
    });

    group('messaging', () {
      test('receives messages', () async {
        await manager.connect();

        final messages = <String>[];
        manager.messageStream.listen(messages.add);

        mockFactory.lastChannel!.simulateMessage('["EVENT", "sub1", {}]');
        await Future.delayed(Duration.zero);

        expect(messages, equals(['["EVENT", "sub1", {}]']));
      });

      test('sends messages when connected', () async {
        await manager.connect();

        final result = await manager.send('["REQ", "sub1", {}]');

        expect(result, isTrue);
        expect(
          mockFactory.lastChannel!.sentMessages,
          contains('["REQ", "sub1", {}]'),
        );
      });

      test('sendJson encodes and sends', () async {
        await manager.connect();

        final result = await manager.sendJson(['REQ', 'sub1', {}]);

        expect(result, isTrue);
        expect(
          mockFactory.lastChannel!.sentMessages.last,
          equals('["REQ","sub1",{}]'),
        );
      });

      test('sendJson reports unencodable payloads without sending', () async {
        await manager.connect();
        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        final result = await manager.sendJson(Object());
        await Future.delayed(Duration.zero);

        expect(result, isFalse);
        expect(mockFactory.lastChannel!.sentMessages, isEmpty);
        expect(errors, hasLength(1));
        expect(errors.single, startsWith('JSON encode error:'));
        expect(
          logMessages.any((m) => m.startsWith('JSON encode error:')),
          isTrue,
        );
      });
    });

    group('on-demand reconnection', () {
      test('send reconnects when disconnected', () async {
        // Start disconnected
        expect(manager.state, equals(ConnectionState.disconnected));

        final result = await manager.send('["REQ", "sub1", {}]');

        expect(result, isTrue);
        expect(manager.state, equals(ConnectionState.connected));
        expect(mockFactory.createdChannels.length, equals(1));
        expect(
          mockFactory.lastChannel!.sentMessages,
          contains('["REQ", "sub1", {}]'),
        );
      });

      test('send waits when connecting', () async {
        // Start a connection
        final connectFuture = manager.connect();

        // Immediately try to send
        final sendFuture = manager.send('["REQ", "sub1", {}]');

        // Both should complete successfully
        await connectFuture;
        final result = await sendFuture;

        expect(result, isTrue);
        expect(mockFactory.createdChannels.length, equals(1));
      });

      test('send fails after max reconnect attempts', () async {
        mockFactory.shouldFail = true;

        final result = await manager.send('test');

        expect(result, isFalse);
        expect(manager.reconnectAttempts, equals(3));
        expect(
          logMessages.any((m) => m.contains('Max reconnect attempts')),
          isTrue,
        );
      });

      test('send with skipReconnect returns false when disconnected', () async {
        // Manager starts disconnected — skipReconnect should return
        // false immediately without attempting to create a connection.
        final result = await manager.send('test', skipReconnect: true);

        expect(result, isFalse);
        expect(mockFactory.createdChannels, isEmpty);
        expect(logMessages.any((m) => m.contains('skipReconnect')), isTrue);
      });

      test(
        'sendJson with skipReconnect returns false when disconnected',
        () async {
          final result = await manager.sendJson([
            'REQ',
            'sub1',
            {},
          ], skipReconnect: true);

          expect(result, isFalse);
          expect(mockFactory.createdChannels, isEmpty);
        },
      );

      test('sendJson reconnects when disconnected', () async {
        final result = await manager.sendJson(['REQ', 'sub1', {}]);

        expect(result, isTrue);
        expect(manager.state, equals(ConnectionState.connected));
      });

      test('resetReconnection clears attempt counter', () async {
        mockFactory.shouldFail = true;
        await manager.send('test');

        manager.resetReconnection();

        expect(manager.reconnectAttempts, equals(0));
      });

      test('reconnect forces immediate reconnection', () async {
        await manager.connect();
        final firstChannel = mockFactory.lastChannel;

        await manager.reconnect();

        expect(mockFactory.createdChannels.length, equals(2));
        expect(mockFactory.lastChannel, isNot(equals(firstChannel)));
        expect(manager.isConnected, isTrue);
      });

      test('does not reconnect after explicit disconnect', () async {
        await manager.connect();
        await manager.disconnect();

        // send should fail without reconnecting after explicit disconnect
        final result = await manager.send('test');

        expect(result, isFalse);
        expect(mockFactory.createdChannels.length, equals(1));
      });
    });

    group('error handling', () {
      test('emits errors on stream error', () async {
        await manager.connect();

        final errors = <String>[];
        manager.errorStream.listen(errors.add);

        mockFactory.lastChannel!.simulateError('Test error');
        await Future.delayed(Duration.zero);

        expect(errors, isNotEmpty);
      });

      test('disconnects on stream error', () async {
        await manager.connect();

        mockFactory.lastChannel!.simulateError('Test error');
        await Future.delayed(const Duration(milliseconds: 10));

        // Should be disconnected (no automatic reconnect)
        expect(manager.state, equals(ConnectionState.disconnected));
      });
    });

    group('dispose', () {
      test('cleans up resources', () async {
        await manager.connect();

        await manager.dispose();

        expect(manager.state, equals(ConnectionState.disconnected));
        expect(mockFactory.lastChannel!.isClosed, isTrue);
      });

      test('closes streams', () async {
        await manager.connect();

        var stateStreamClosed = false;
        manager.stateStream.listen(
          (_) {},
          onDone: () => stateStreamClosed = true,
        );

        await manager.dispose();
        await Future.delayed(Duration.zero);

        expect(stateStreamClosed, isTrue);
      });
    });
  });
}

/// Factory that creates channels with a custom ready future (e.g. one that
/// never completes, for testing connection timeout).
class _SlowReadyFactory implements WebSocketChannelFactory {
  _SlowReadyFactory(this._readyFuture);

  final Future<void> _readyFuture;

  @override
  WebSocketChannel create(Uri uri) {
    return MockWebSocketChannel(readyFuture: _readyFuture);
  }
}
