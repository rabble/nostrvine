// ABOUTME: Regression tests for the OK-timeout zombie-socket remediation in
// ABOUTME: RelayPool.sendEventAwaitOk (silent relay is force-reconnected).

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Sink that accepts every frame without erroring — the zombie-socket
/// behaviour: a half-open TCP connection buffers outbound bytes and
/// `sink.add` never throws.
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
    if (!_doneCompleter.isCompleted) {
      _doneCompleter.complete();
    }
  }

  @override
  Future<dynamic> get done => _doneCompleter.future;
}

class _FakeWebSocketChannel implements WebSocketChannel {
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
  Future<void> get ready => Future.value();

  @override
  dynamic noSuchMethod(Invocation invocation) {
    throw UnimplementedError('${invocation.memberName} not used in this test');
  }

  /// Simulate an inbound frame from the relay.
  void simulateMessage(String message) => _streamController.add(message);

  List<dynamic> get sentMessages => _sink.messages;
}

class _FakeChannelFactory implements WebSocketChannelFactory {
  final List<_FakeWebSocketChannel> createdChannels = [];

  @override
  WebSocketChannel create(Uri uri) {
    final channel = _FakeWebSocketChannel();
    createdChannels.add(channel);
    return channel;
  }
}

void main() {
  group('RelayPool zombie-socket remediation on OK timeout', () {
    const relayUrl = 'wss://relay.divine.video';
    late LocalNostrSigner signer;
    late Nostr nostr;
    late _FakeChannelFactory factory;
    late RelayBase relay;

    setUp(() async {
      signer = LocalNostrSigner(
        '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12',
      );
      nostr = Nostr(signer, [], (url) => RelayBase(url, RelayStatus(url)));
      await nostr.refreshPublicKey();
      factory = _FakeChannelFactory();
      relay = RelayBase(
        relayUrl,
        RelayStatus(relayUrl),
        channelFactory: factory,
      );
      await nostr.relayPool.add(relay);
    });

    Future<PublishOutcome> publishAwaitOk() {
      return nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'zombie-event-id', 'kind': 14},
        ],
        eventId: 'zombie-event-id',
        eventKind: 14,
        targetRelays: [relayUrl],
        timeout: const Duration(milliseconds: 100),
      );
    }

    test('a relay that accepts the frame but stays silent for the whole OK '
        'window is force-reconnected and its subscriptions re-sent', () async {
      // Live subscription established before the socket goes zombie.
      nostr.relayPool.subscribe([
        Filter(kinds: const [1059], limit: 1).toJson(),
      ], (_) {});
      expect(factory.createdChannels, hasLength(1));
      final zombieChannel = factory.createdChannels.single;
      final reqFrames = zombieChannel.sentMessages
          .map((m) => jsonDecode(m as String) as List<dynamic>)
          .where((m) => m.first == 'REQ')
          .toList();
      expect(reqFrames, hasLength(1));

      final outcome = await publishAwaitOk();

      // Frame was written, no OK of either polarity arrived.
      expect(outcome.confirmed, isFalse);
      expect(outcome.noResponseFrom, contains(relayUrl));

      // Remediation runs asynchronously after the outcome resolves: the
      // stale connection is cycled and the subscription re-established on
      // the fresh channel.
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'the silent zombie connection must be force-reconnected',
      );
      final freshChannel = factory.createdChannels.last;
      final replayedReqs = freshChannel.sentMessages
          .map((m) => jsonDecode(m as String) as List<dynamic>)
          .where((m) => m.first == 'REQ')
          .toList();
      expect(
        replayedReqs,
        hasLength(1),
        reason: 'live subscriptions must survive the forced reconnect',
      );
      expect(replayedReqs.single[1], equals(reqFrames.single[1]));
    });

    test('a relay that stays inbound-active during the OK window is left '
        'alone — silence discriminates zombie from slow', () async {
      final channel = factory.createdChannels.single;
      // Inbound traffic (an unrelated NOTICE) arrives right after the frame
      // is written — before the OK window can close, deterministically even
      // on a loaded test runner: the connection is alive, the relay just
      // did not OK this publish.
      final outcomeFuture = publishAwaitOk();
      await Future<void>.delayed(Duration.zero);
      channel.simulateMessage(jsonEncode(['NOTICE', 'busy']));

      final outcome = await outcomeFuture;
      expect(outcome.confirmed, isFalse);
      expect(outcome.noResponseFrom, contains(relayUrl));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(1),
        reason: 'an inbound-active connection must not be cycled',
      );
    });

    test('an OK true within the window confirms the publish and triggers no '
        'reconnect', () async {
      final channel = factory.createdChannels.single;
      final okTimer = Timer(const Duration(milliseconds: 20), () {
        channel.simulateMessage(
          jsonEncode(['OK', 'zombie-event-id', true, '']),
        );
      });
      addTearDown(okTimer.cancel);

      final outcome = await publishAwaitOk();
      expect(outcome.confirmed, isTrue);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(factory.createdChannels, hasLength(1));
    });
  });
}
