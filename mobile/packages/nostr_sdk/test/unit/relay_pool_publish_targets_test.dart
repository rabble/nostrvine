// ABOUTME: Regression tests for which relays count as publish targets.
// ABOUTME: A configured-but-disconnected relay must not inflate the denominator.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class _BufferingSink implements WebSocketSink {
  final List<dynamic> messages = [];
  bool closed = false;
  final Completer<void> _doneCompleter = Completer<void>();

  @override
  void add(dynamic data) {
    if (closed) throw StateError('Sink is closed');
    messages.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<dynamic> addStream(Stream<dynamic> stream) async {
    await for (final data in stream) {
      add(data);
    }
  }

  @override
  Future<dynamic> close([int? closeCode, String? closeReason]) async {
    closed = true;
    if (!_doneCompleter.isCompleted) _doneCompleter.complete();
  }

  @override
  Future<dynamic> get done => _doneCompleter.future;
}

class _FakeWebSocketChannel implements WebSocketChannel {
  _FakeWebSocketChannel({this.failReady = false, this.readyDelay});

  /// When true, `ready` rejects — the shape of a relay that is configured but
  /// currently unreachable, which is what `RelayBase.connect()` reports as a
  /// failed connect.
  final bool failReady;

  /// How long the handshake takes. While it is outstanding the relay is not
  /// yet connected, so it is not a *counted* target — but `send` still waits
  /// it out and writes, so it can still answer.
  final Duration? readyDelay;

  final _BufferingSink _sink = _BufferingSink();
  final StreamController<dynamic> _streamController =
      StreamController<dynamic>.broadcast();

  @override
  WebSocketSink get sink => _sink;

  @override
  Stream<dynamic> get stream => _streamController.stream;

  @override
  int? get closeCode => null;

  @override
  String? get closeReason => null;

  @override
  String? get protocol => null;

  @override
  Future<void> get ready {
    if (failReady) return Future<void>.error(StateError('unreachable'));
    final delay = readyDelay;
    return delay == null ? Future.value() : Future<void>.delayed(delay);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} not used in this test');
  }

  void simulateMessage(String message) => _streamController.add(message);

  List<dynamic> get sentMessages => _sink.messages;
}

class _FakeChannelFactory implements WebSocketChannelFactory {
  _FakeChannelFactory({this.failReady = false, this.readyDelay});

  final bool failReady;
  final Duration? readyDelay;
  final List<_FakeWebSocketChannel> createdChannels = [];

  @override
  WebSocketChannel create(Uri uri) {
    final channel = _FakeWebSocketChannel(
      failReady: failReady,
      readyDelay: readyDelay,
    );
    createdChannels.add(channel);
    return channel;
  }
}

void main() {
  group('RelayPool publish targets', () {
    const liveUrl = 'wss://relay.divine.video';
    const downUrl = 'wss://relay.offline.example';
    const eventId = 'target-denominator-event-id';

    late LocalNostrSigner signer;
    late Nostr nostr;
    late _FakeChannelFactory liveFactory;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();

      liveFactory = _FakeChannelFactory();
      await nostr.relayPool.add(
        RelayBase(liveUrl, RelayStatus(liveUrl), channelFactory: liveFactory),
      );

      // Configured, write-enabled, but the socket never comes up. `add()`
      // keeps it in the pool even when connect() fails, which is exactly the
      // steady state on mobile when one of the user's relays is down.
      await nostr.relayPool.add(
        RelayBase(
          downUrl,
          RelayStatus(downUrl),
          channelFactory: _FakeChannelFactory(failReady: true),
        ),
      );
    });

    /// Answers `OK true` from the live relay as soon as its EVENT lands.
    void acceptFromLiveRelay() {
      final channel = liveFactory.createdChannels.single;
      Timer.run(() {
        final sawEvent = channel.sentMessages.any((m) {
          final frame = jsonDecode(m as String) as List<dynamic>;
          return frame.first == 'EVENT';
        });
        if (sawEvent) {
          channel.simulateMessage(jsonEncode(['OK', eventId, true, '']));
        }
      });
    }

    test(
      'a configured relay that never connected is not a publish target',
      () async {
        acceptFromLiveRelay();

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          eventKind: 5,
          timeout: const Duration(milliseconds: 400),
        );

        expect(outcome.acceptedBy, equals([liveUrl]));
        expect(
          outcome.unreachableTargets,
          isEmpty,
          reason:
              'a relay that was never connected was never a target, so it '
              'cannot be an unreachable one',
        );
        expect(outcome.targetCount, equals(1));
        expect(
          outcome.acceptedByAll,
          isTrue,
          reason:
              'every relay this publish could reach accepted it, so the '
              'outcome must not read as partial',
        );
      },
    );

    test(
      'an explicitly targeted relay is reported unreachable, not dropped',
      () async {
        acceptFromLiveRelay();

        // Naming relays is the caller asserting intent — the kind:10002
        // bootstrap does this so it can tell an unreached indexer from a
        // refusing one. Silently shrinking the denominator would destroy
        // exactly the signal it publishes for.
        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 10002},
          ],
          eventId: eventId,
          eventKind: 10002,
          targetRelays: const [liveUrl, downUrl],
          timeout: const Duration(milliseconds: 400),
        );

        expect(outcome.acceptedBy, equals([liveUrl]));
        expect(outcome.unreachableTargets, equals([downUrl]));
        expect(outcome.targetCount, equals(2));
        expect(outcome.acceptedByAll, isFalse);
      },
    );

    test('the disconnected relay still cannot speak for the publish', () async {
      acceptFromLiveRelay();

      final outcome = await nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': eventId, 'kind': 5},
        ],
        eventId: eventId,
        eventKind: 5,
        timeout: const Duration(milliseconds: 400),
      );

      expect(outcome.acceptedBy, isNot(contains(downUrl)));
      expect(outcome.rejectedBy.keys, isNot(contains(downUrl)));
      expect(outcome.noResponseFrom, isNot(contains(downUrl)));
    });
  });

  group('RelayPool publish targets while relays are still connecting', () {
    const fastUrl = 'wss://relay.fast.example';
    const slowUrl = 'wss://relay.slow.example';
    const eventId = 'still-connecting-event-id';

    test(
      'counts an OK from a relay whose handshake was still in flight',
      () async {
        final signer = LocalNostrSigner(
          '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
        );
        final nostr = Nostr(
          signer,
          [],
          (url) => RelayBase(url, RelayStatus(url)),
        );
        await nostr.refreshPublicKey();

        // Both relays are healthy; both handshakes are simply still in flight
        // when the publish starts — the ordinary shape right after launch or a
        // connectivity flap, where `relayStatus.connected` has not caught up
        // with the socket yet. The fast one lands and answers while the
        // sequential fan-out is still waiting on the slow one, so its OK
        // arrives before the fan-out reports which relays it wrote to.
        final fastFactory = _FakeChannelFactory(
          readyDelay: const Duration(milliseconds: 30),
        );
        unawaited(
          nostr.relayPool.add(
            RelayBase(
              fastUrl,
              RelayStatus(fastUrl),
              channelFactory: fastFactory,
            ),
          ),
        );
        unawaited(
          nostr.relayPool.add(
            RelayBase(
              slowUrl,
              RelayStatus(slowUrl),
              channelFactory: _FakeChannelFactory(
                readyDelay: const Duration(milliseconds: 800),
              ),
            ),
          ),
        );

        Timer.periodic(const Duration(milliseconds: 5), (timer) {
          if (fastFactory.createdChannels.isEmpty) return;
          final channel = fastFactory.createdChannels.single;
          final sawEvent = channel.sentMessages.any((m) {
            final frame = jsonDecode(m as String) as List<dynamic>;
            return frame.first == 'EVENT';
          });
          if (!sawEvent) return;
          timer.cancel();
          channel.simulateMessage(jsonEncode(['OK', eventId, true, '']));
        });

        final outcome = await nostr.relayPool.sendEventAwaitOk(
          [
            'EVENT',
            {'id': eventId, 'kind': 5},
          ],
          eventId: eventId,
          eventKind: 5,
          timeout: const Duration(seconds: 3),
        );

        expect(
          outcome.acceptedBy,
          contains(fastUrl),
          reason:
              'the relay answered OK true, so it must be allowed to speak for '
              'the publish however unconnected it looked when targets were '
              'resolved — discarding the answer turns a confirmed publish into '
              'a failed one',
        );
        expect(outcome.failed, isFalse);
      },
    );
  });
}
