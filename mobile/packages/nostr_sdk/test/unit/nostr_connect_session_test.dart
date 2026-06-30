// ABOUTME: Unit tests for NostrConnectSession class
// ABOUTME: Tests state machine transitions and URL generation

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:nostr_sdk/nip46/nostr_remote_response.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('NostrRemoteSignerInfo nostrconnect:// support', () {
    test('isNostrConnectUrl returns true for nostrconnect:// URLs', () {
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl('nostrconnect://abc123'),
        isTrue,
      );
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl(
          'nostrconnect://abc?relay=wss://relay.example.com',
        ),
        isTrue,
      );
    });

    test('isNostrConnectUrl returns false for bunker:// URLs', () {
      expect(
        NostrRemoteSignerInfo.isNostrConnectUrl('bunker://abc123'),
        isFalse,
      );
    });

    test('isNostrConnectUrl returns false for null', () {
      expect(NostrRemoteSignerInfo.isNostrConnectUrl(null), isFalse);
    });

    test('isNostrConnectUrl returns false for empty string', () {
      expect(NostrRemoteSignerInfo.isNostrConnectUrl(''), isFalse);
    });

    test(
      'generateNostrConnectUrl creates valid info with ephemeral keypair',
      () {
        final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
          relays: ['wss://relay.example.com'],
          appName: 'TestApp',
          appUrl: 'https://test.com',
        );

        // Should have client pubkey (64 hex chars)
        expect(info.clientPubkey, isNotNull);
        expect(info.clientPubkey!.length, equals(64));
        expect(
          RegExp(r'^[0-9a-f]+$').hasMatch(info.clientPubkey!),
          isTrue,
          reason: 'clientPubkey should be hex',
        );

        // Should have nsec
        expect(info.nsec, isNotNull);
        expect(info.nsec!.startsWith('nsec1'), isTrue);

        // Should have secret (16 hex chars = 8 bytes)
        expect(info.optionalSecret, isNotNull);
        expect(info.optionalSecret!.length, equals(16));

        // Should be marked as client-initiated
        expect(info.isClientInitiated, isTrue);

        // Should have relays
        expect(info.relays, equals(['wss://relay.example.com']));

        // Should have app info
        expect(info.appName, equals('TestApp'));
        expect(info.appUrl, equals('https://test.com'));

        // remoteSignerPubkey should be empty (unknown until bunker responds)
        expect(info.remoteSignerPubkey, isEmpty);
      },
    );

    test('generateNostrConnectUrl creates unique keypairs each time', () {
      final info1 = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );
      final info2 = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      expect(info1.clientPubkey, isNot(equals(info2.clientPubkey)));
      expect(info1.nsec, isNot(equals(info2.nsec)));
      expect(info1.optionalSecret, isNot(equals(info2.optionalSecret)));
    });

    test('toNostrConnectUrl generates valid URL', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com', 'wss://relay2.example.com'],
        appName: 'TestApp',
        appUrl: 'https://test.com',
      );

      final url = info.toNostrConnectUrl();

      // Should start with nostrconnect://
      expect(url.startsWith('nostrconnect://'), isTrue);

      // Should contain client pubkey as host
      expect(url.contains(info.clientPubkey!), isTrue);

      // Should contain relays
      expect(url.contains('relay='), isTrue);
      expect(
        url.contains(Uri.encodeComponent('wss://relay.example.com')),
        isTrue,
      );
      expect(
        url.contains(Uri.encodeComponent('wss://relay2.example.com')),
        isTrue,
      );

      // Should contain secret
      expect(url.contains('secret='), isTrue);
      expect(url.contains(info.optionalSecret!), isTrue);

      // Should contain app name and url as separate params (per NIP-46)
      expect(url.contains('name='), isTrue);
      expect(url.contains('TestApp'), isTrue);
      expect(url.contains('url='), isTrue);

      // Should contain perms
      expect(url.contains('perms='), isTrue);
      expect(url.contains('sign_event'), isTrue);
    });

    test('toNostrConnectUrl throws if clientPubkey is missing', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'abc',
        relays: ['wss://relay.example.com'],
        optionalSecret: 'secret123',
        // clientPubkey is null
      );

      expect(() => info.toNostrConnectUrl(), throwsA(isA<StateError>()));
    });

    test('toNostrConnectUrl throws if secret is missing', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: '',
        relays: ['wss://relay.example.com'],
        clientPubkey: 'abc123',
        // optionalSecret is null
      );

      expect(() => info.toNostrConnectUrl(), throwsA(isA<StateError>()));
    });

    test('toNostrConnectUrl with custom permissions', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(permissions: 'sign_event:0');

      expect(url.contains('perms=sign_event%3A0'), isTrue);
    });

    test('toNostrConnectUrl includes callback when provided', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(callback: 'divine');

      expect(url.contains('callback=divine'), isTrue);
    });

    test('toNostrConnectUrl URL-encodes callback value', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(
        callback: 'https://example.com/callback',
      );

      expect(
        url.contains(
          'callback=${Uri.encodeComponent("https://example.com/callback")}',
        ),
        isTrue,
      );
      // Should not contain the raw unencoded URL
      expect(url.contains('callback=https://example.com/callback'), isFalse);
    });

    test('toNostrConnectUrl omits callback when null', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl();

      expect(url.contains('callback'), isFalse);
    });

    test('toNostrConnectUrl omits callback when empty', () {
      final info = NostrRemoteSignerInfo.generateNostrConnectUrl(
        relays: ['wss://relay.example.com'],
      );

      final url = info.toNostrConnectUrl(callback: '');

      expect(url.contains('callback'), isFalse);
    });
  });

  group('NostrConnectSession', () {
    test('initial state is idle', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      expect(session.state, equals(NostrConnectState.idle));
      expect(session.connectUrl, isNull);
      expect(session.info, isNull);

      session.dispose();
    });

    test('cancel from idle state transitions to cancelled', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      session.cancel();

      expect(session.state, equals(NostrConnectState.cancelled));

      session.dispose();
    });

    test('state stream emits state changes', () async {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      final states = <NostrConnectState>[];
      final subscription = session.stateStream.listen(states.add);

      session.cancel();

      // Give time for stream to emit
      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(states, contains(NostrConnectState.cancelled));

      await subscription.cancel();
      session.dispose();
    });

    test('waitForConnection throws if not in listening state', () {
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      expect(() => session.waitForConnection(), throwsA(isA<StateError>()));

      session.dispose();
    });

    test('start throws if already started', () {
      // Test that start() can only be called from idle state
      // We use cancel() to transition out of idle state without any network calls
      final session = NostrConnectSession(relays: ['wss://relay.example.com']);

      // Verify initial state
      expect(session.state, equals(NostrConnectState.idle));

      // Cancel transitions from idle to cancelled
      session.cancel();
      expect(session.state, equals(NostrConnectState.cancelled));

      // Now start() should throw because we're not in idle state
      expect(
        () => session.start(),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('already started'),
          ),
        ),
      );

      session.dispose();
    });

    test('addRelay dedupes configured and connected relays', () async {
      final primaryRelay = await _TestRelayServer.start();
      final callbackRelay = await _TestRelayServer.start();
      addTearDown(primaryRelay.close);
      addTearDown(callbackRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();
      expect(primaryRelay.connectionCount, equals(1));

      await session.addRelay(primaryRelay.url);
      expect(
        primaryRelay.connectionCount,
        equals(1),
        reason: 'configured relays should not be added a second time',
      );

      await session.addRelay(callbackRelay.url);
      expect(callbackRelay.connectionCount, equals(1));

      await session.addRelay(callbackRelay.url);
      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'already-connected callback relays should be deduped',
      );
    });

    test('addRelay is a no-op unless the session is listening', () async {
      final callbackRelay = await _TestRelayServer.start();
      addTearDown(callbackRelay.close);

      final idleSession = NostrConnectSession(relays: ['ws://127.0.0.1:9']);
      addTearDown(idleSession.dispose);

      await idleSession.addRelay(callbackRelay.url);
      expect(callbackRelay.connectionCount, equals(0));

      idleSession.cancel();
      await idleSession.addRelay(callbackRelay.url);
      expect(callbackRelay.connectionCount, equals(0));
    });

    test('addRelay excludes relays whose connect returns false', () async {
      final primaryRelay = await _TestRelayServer.start();
      final failedPort = await _unusedLoopbackPort();
      final callbackUrl = 'ws://127.0.0.1:$failedPort';
      addTearDown(primaryRelay.close);

      final session = NostrConnectSession(relays: [primaryRelay.url]);
      addTearDown(session.dispose);

      await session.start();
      await session.addRelay(callbackUrl);

      final callbackRelay = await _TestRelayServer.start(port: failedPort);
      addTearDown(callbackRelay.close);

      await session.addRelay(callbackUrl);
      expect(
        callbackRelay.connectionCount,
        equals(1),
        reason: 'failed relay attempts must not be retained as connected',
      );
    });

    test(
      'addRelay excludes relays whose connect times out',
      () async {
        final primaryRelay = await _TestRelayServer.start();
        final blackhole = await _BlackholeServer.start();
        final callbackUrl = blackhole.url;
        addTearDown(primaryRelay.close);
        addTearDown(blackhole.close);

        final session = NostrConnectSession(relays: [primaryRelay.url]);
        addTearDown(session.dispose);

        await session.start();
        await session.addRelay(callbackUrl);

        final failedPort = blackhole.port;
        await blackhole.close();
        final callbackRelay = await _TestRelayServer.start(port: failedPort);
        addTearDown(callbackRelay.close);

        await session.addRelay(callbackUrl);
        expect(
          callbackRelay.connectionCount,
          equals(1),
          reason: 'timed-out relay attempts must not be retained as connected',
        );
      },
      timeout: const Timeout(Duration(seconds: 20)),
    );
  });

  group('NostrConnectState enum', () {
    test('all states are defined', () {
      expect(NostrConnectState.values, hasLength(7));
      expect(NostrConnectState.values, contains(NostrConnectState.idle));
      expect(NostrConnectState.values, contains(NostrConnectState.generating));
      expect(NostrConnectState.values, contains(NostrConnectState.listening));
      expect(NostrConnectState.values, contains(NostrConnectState.connected));
      expect(NostrConnectState.values, contains(NostrConnectState.timeout));
      expect(NostrConnectState.values, contains(NostrConnectState.cancelled));
      expect(NostrConnectState.values, contains(NostrConnectState.error));
    });
  });

  group('NostrConnectResult', () {
    test('stores all required fields', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'bunker123',
        relays: ['wss://relay.example.com'],
        isClientInitiated: true,
      );

      final result = NostrConnectResult(
        remoteSignerPubkey: 'bunker123',
        userPubkey: 'user456',
        info: info,
      );

      expect(result.remoteSignerPubkey, equals('bunker123'));
      expect(result.userPubkey, equals('user456'));
      expect(result.info, equals(info));
    });

    test('userPubkey can be null', () {
      final info = NostrRemoteSignerInfo(
        remoteSignerPubkey: 'bunker123',
        relays: ['wss://relay.example.com'],
      );

      final result = NostrConnectResult(
        remoteSignerPubkey: 'bunker123',
        userPubkey: null,
        info: info,
      );

      expect(result.userPubkey, isNull);
    });
  });

  group('validateConnectResponse', () {
    NostrRemoteResponse buildResponse(String result, {String? error}) {
      return NostrRemoteResponse('req-id', result, error: error);
    }

    test('returns match when response.result equals the secret exactly', () {
      final validation = validateConnectResponse(
        response: buildResponse('s3cret'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.match));
    });

    test(
      'returns ignore when response.result is "ack" (bunker:// flow token)',
      () {
        final validation = validateConnectResponse(
          response: buildResponse('ack'),
          expectedSecret: 's3cret',
        );
        expect(validation, equals(NostrConnectResponseValidation.ignore));
      },
    );

    test('returns ignore when response.result is "connect"', () {
      final validation = validateConnectResponse(
        response: buildResponse('connect'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns ignore on any other non-matching result', () {
      final validation = validateConnectResponse(
        response: buildResponse('attacker-guess'),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns ignore on an empty result string', () {
      final validation = validateConnectResponse(
        response: buildResponse(''),
        expectedSecret: 's3cret',
      );
      expect(validation, equals(NostrConnectResponseValidation.ignore));
    });

    test('returns rejectedByBunker when response.error is non-empty', () {
      final validation = validateConnectResponse(
        response: buildResponse('', error: 'user denied'),
        expectedSecret: 's3cret',
      );
      expect(
        validation,
        equals(NostrConnectResponseValidation.rejectedByBunker),
      );
    });

    test('returns rejectedByBunker even when result happens to match — '
        'an explicit error must always win', () {
      final validation = validateConnectResponse(
        response: buildResponse('s3cret', error: 'user denied'),
        expectedSecret: 's3cret',
      );
      expect(
        validation,
        equals(NostrConnectResponseValidation.rejectedByBunker),
      );
    });

    test('returns rejectedByBunker for auth_url challenge responses', () {
      final validation = validateConnectResponse(
        response: buildResponse(
          'auth_url',
          error: 'https://example.com/approve?token=untrusted',
        ),
        expectedSecret: 's3cret',
      );
      expect(
        validation,
        equals(NostrConnectResponseValidation.rejectedByBunker),
      );
    });

    test('returns invalidSession when expectedSecret is null', () {
      final validation = validateConnectResponse(
        response: buildResponse('anything'),
        expectedSecret: null,
      );
      expect(validation, equals(NostrConnectResponseValidation.invalidSession));
    });

    test('returns invalidSession when expectedSecret is empty', () {
      final validation = validateConnectResponse(
        response: buildResponse('anything'),
        expectedSecret: '',
      );
      expect(validation, equals(NostrConnectResponseValidation.invalidSession));
    });

    test(
      'returns ignore on equal-length secret with one differing character '
      '(constant-time compare path runs to end without short-circuiting)',
      () {
        final validation = validateConnectResponse(
          response: buildResponse('s3cretA'),
          expectedSecret: 's3cretB',
        );
        expect(validation, equals(NostrConnectResponseValidation.ignore));
      },
    );
  });

  group('terminal failure reasons and log redaction', () {
    test(
      'never logs the matched secret while handling a successful response',
      () async {
        final relay = await _TestRelayServer.start();
        addTearDown(relay.close);

        final logs = <String>[];
        final session = NostrConnectSession(
          relays: [relay.url],
          logger: logs.add,
        );
        addTearDown(session.dispose);

        await session.start();
        final info = session.info!;
        final secret = info.optionalSecret!;
        // The connect URL legitimately carries the secret and is logged at
        // start(); drop those lines so the assertion only covers RESPONSE
        // handling — the surface the #3760 redaction contract guards.
        logs.clear();

        final wait = session.waitForConnection(
          timeout: const Duration(seconds: 5),
        );
        relay.push([
          'EVENT',
          'sub',
          await _encryptedResponseEvent(
            clientPubkey: info.clientPubkey!,
            result: secret,
          ),
        ]);
        final result = await wait;

        expect(result, isNotNull, reason: 'a matching secret should connect');
        expect(session.state, equals(NostrConnectState.connected));
        // Guard the guard: the response-handling path must actually route
        // through the injected logger, or the redaction assertion below
        // passes vacuously. This `Decrypted response` line is precisely
        // where `response.result` (== the secret on a match) would most
        // plausibly be interpolated by a future edit, so it must be one of
        // the lines `logs` captures.
        expect(
          logs.any((line) => line.contains('Decrypted response')),
          isTrue,
          reason:
              '_handleResponse must log via the injected logger so the '
              'secret-redaction assertion covers the response path',
        );
        expect(
          logs.where((line) => line.contains(secret)),
          isEmpty,
          reason: 'the matched secret must never reach the logs',
        );
      },
    );

    test(
      'logs neither the response result nor the expected secret on a mismatch',
      () async {
        final relay = await _TestRelayServer.start();
        addTearDown(relay.close);

        final logs = <String>[];
        final session = NostrConnectSession(
          relays: [relay.url],
          logger: logs.add,
        );
        addTearDown(session.dispose);

        await session.start();
        final info = session.info!;
        final secret = info.optionalSecret!;
        const junkResult = 'junk-result-value-should-never-be-logged';
        logs.clear();

        unawaited(
          session.waitForConnection(timeout: const Duration(seconds: 5)),
        );
        relay.push([
          'EVENT',
          'sub',
          await _encryptedResponseEvent(
            clientPubkey: info.clientPubkey!,
            result: junkResult,
          ),
        ]);
        await Future<void>.delayed(const Duration(milliseconds: 50));

        // Guard the guard: prove the mismatch path actually ran through the
        // injected logger so the redaction assertion below is not vacuous.
        expect(
          logs.any((line) => line.contains('Decrypted response')),
          isTrue,
          reason:
              '_handleResponse must log via the injected logger so the '
              'redaction assertion covers the mismatch path',
        );
        expect(
          logs.where(
            (line) => line.contains(junkResult) || line.contains(secret),
          ),
          isEmpty,
          reason: 'neither the result nor the expected secret may be logged',
        );
      },
    );

    test('reports bunkerRejected when the signer returns an error', () async {
      final relay = await _TestRelayServer.start();
      addTearDown(relay.close);

      final session = NostrConnectSession(relays: [relay.url]);
      addTearDown(session.dispose);

      await session.start();
      final info = session.info!;

      final wait = session.waitForConnection(
        timeout: const Duration(seconds: 5),
      );
      relay.push([
        'EVENT',
        'sub',
        await _encryptedResponseEvent(
          clientPubkey: info.clientPubkey!,
          result: '',
          error: 'user rejected',
        ),
      ]);
      final result = await wait;

      expect(result, isNull);
      expect(session.state, equals(NostrConnectState.error));
      expect(
        session.failureReason,
        equals(NostrConnectFailureReason.bunkerRejected),
      );
    });

    test('reports startFailed when no relay can be reached', () async {
      final deadPort = await _unusedLoopbackPort();
      final session = NostrConnectSession(relays: ['ws://127.0.0.1:$deadPort']);
      addTearDown(session.dispose);

      await expectLater(session.start(), throwsA(isA<StateError>()));

      expect(session.state, equals(NostrConnectState.error));
      expect(
        session.failureReason,
        equals(NostrConnectFailureReason.startFailed),
      );
    });
  });
}

/// Builds a NIP-44-encrypted kind-24133 response event addressed to
/// [clientPubkey], as a `nostrconnect://` signer would send it. The signer
/// keypair is ephemeral; [Event.fromJson] does not verify signatures, so the
/// event is left unsigned.
Future<Map<String, dynamic>> _encryptedResponseEvent({
  required String clientPubkey,
  required String result,
  String? error,
}) async {
  final signer = LocalNostrSigner(generatePrivateKey());
  final remoteSignerPubkey = (await signer.getPublicKey())!;
  final response = NostrRemoteResponse('test-request-id', result, error: error);
  final ciphertext = (await response.encrypt(signer, clientPubkey))!;
  return Event(remoteSignerPubkey, EventKind.nostrRemoteSigning, [
    ['p', clientPubkey],
  ], ciphertext).toJson();
}

Future<int> _unusedLoopbackPort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = socket.port;
  await socket.close();
  return port;
}

class _TestRelayServer {
  _TestRelayServer._(this._server) {
    _requests = _server.listen(_handleRequest);
  }

  final HttpServer _server;
  final _sockets = <WebSocket>[];
  late final StreamSubscription<HttpRequest> _requests;
  int connectionCount = 0;
  bool _closed = false;

  String get url => 'ws://127.0.0.1:${_server.port}';

  /// Sends a relay message (e.g. `['EVENT', subId, eventJson]`) to every
  /// connected client. The session ignores the subscription id, so any value
  /// works.
  void push(Object message) {
    final text = jsonEncode(message);
    for (final socket in _sockets) {
      socket.add(text);
    }
  }

  static Future<_TestRelayServer> start({int? port}) async {
    final server = await HttpServer.bind(
      InternetAddress.loopbackIPv4,
      port ?? 0,
    );
    return _TestRelayServer._(server);
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }

    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    connectionCount += 1;
    socket.listen((_) {});
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in _sockets) {
      await socket.close();
    }
    await _requests.cancel();
    await _server.close(force: true);
  }
}

class _BlackholeServer {
  _BlackholeServer._(this._server) {
    _requests = _server.listen((socket) {
      _sockets.add(socket);
    });
  }

  final ServerSocket _server;
  final _sockets = <Socket>[];
  late final StreamSubscription<Socket> _requests;
  bool _closed = false;

  int get port => _server.port;
  String get url => 'ws://127.0.0.1:$port';

  static Future<_BlackholeServer> start() async {
    final server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    return _BlackholeServer._(server);
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    for (final socket in _sockets) {
      socket.destroy();
    }
    await _requests.cancel();
    await _server.close();
  }
}
