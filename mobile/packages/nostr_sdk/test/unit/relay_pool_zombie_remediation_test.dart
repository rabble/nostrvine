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

    test('on a multi-relay publish, a healthy sibling that merely lost the '
        'OK race to a faster relay is not force-cycled', () async {
      // The tracker resolves on the FIRST OK-true, so the sibling relay
      // lands in noResponseFrom after only the few-ms race window — far too
      // short for its silence to mean anything. Cycling it would tear down
      // a healthy inbox relay on every send.
      const siblingUrl = 'wss://inbox.example.com';
      final siblingFactory = _FakeChannelFactory();
      final sibling = RelayBase(
        siblingUrl,
        RelayStatus(siblingUrl),
        channelFactory: siblingFactory,
      );
      await nostr.relayPool.add(sibling);
      expect(siblingFactory.createdChannels, hasLength(1));

      final fastChannel = factory.createdChannels.single;
      final outcomeFuture = nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': 'zombie-event-id', 'kind': 14},
        ],
        eventId: 'zombie-event-id',
        eventKind: 14,
        targetRelays: [relayUrl, siblingUrl],
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);
      fastChannel.simulateMessage(
        jsonEncode(['OK', 'zombie-event-id', true, '']),
      );

      final outcome = await outcomeFuture;
      expect(outcome.confirmed, isTrue);
      expect(outcome.noResponseFrom, contains(siblingUrl));

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        siblingFactory.createdChannels,
        hasLength(1),
        reason:
            'a confirmed publish must not cycle the slower sibling relay '
            'that never got a chance to respond',
      );
      expect(factory.createdChannels, hasLength(1));
    });

    Future<PublishOutcome> publishWithId(String id) {
      return nostr.relayPool.sendEventAwaitOk(
        [
          'EVENT',
          {'id': id, 'kind': 14},
        ],
        eventId: id,
        eventKind: 14,
        targetRelays: [relayUrl],
        timeout: const Duration(milliseconds: 100),
      );
    }

    test('two consecutive silent OK timeouts within the cooldown trigger '
        'exactly one repair', () async {
      // A brownout relay — alive but answering slower than the OK window —
      // times out in silence on every publish and reads as silent each time.
      // The default per-relay cooldown must collapse the second timeout into
      // a no-op instead of force-cycling the connection again.
      final first = await publishWithId('brownout-1');
      expect(first.confirmed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason: 'the first silent timeout must repair the zombie socket',
      );

      final second = await publishWithId('brownout-2');
      expect(second.confirmed, isFalse);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        factory.createdChannels,
        hasLength(2),
        reason:
            'a second silent timeout inside the cooldown must not re-cycle '
            'the same relay',
      );
    });

    test(
      'a silent OK timeout after the cooldown elapses repairs again',
      () async {
        // Injecting a tiny cooldown lets the second timeout land after the
        // window has elapsed, so a genuinely still-zombie socket is repaired
        // again rather than being suppressed forever.
        nostr.relayPool.silentRepairCooldown = const Duration(milliseconds: 1);

        final first = await publishWithId('brownout-1');
        expect(first.confirmed, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(factory.createdChannels, hasLength(2));

        final second = await publishWithId('brownout-2');
        expect(second.confirmed, isFalse);
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          factory.createdChannels,
          hasLength(3),
          reason:
              'once the cooldown elapses a subsequent silent timeout must '
              'repair the relay again',
        );
      },
    );

    test('a pending one-shot query on a silent zombie relay is replayed on '
        'the fresh socket after force-reconnect', () async {
      // A one-shot query still awaiting EOSE when the socket goes zombie must
      // be re-issued on the fresh socket. Force-reconnect previously replayed
      // only long-running subscriptions, stranding the query until the
      // caller's own timeout instead of letting a fresh EOSE complete it.
      await nostr.relayPool.query(
        [
          Filter(kinds: const [0], authors: const ['abc'], limit: 1).toJson(),
        ],
        (_) {},
        id: 'pending-query-id',
      );
      final zombieChannel = factory.createdChannels.single;
      final queryReqs = zombieChannel.sentMessages
          .map((m) => jsonDecode(m as String) as List<dynamic>)
          .where((m) => m.first == 'REQ' && m[1] == 'pending-query-id')
          .toList();
      expect(queryReqs, hasLength(1));

      final outcome = await publishWithId('zombie-event-id');
      expect(outcome.confirmed, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(factory.createdChannels, hasLength(2));
      final freshChannel = factory.createdChannels.last;
      final replayedReqs = freshChannel.sentMessages
          .map((m) => jsonDecode(m as String) as List<dynamic>)
          .where((m) => m.first == 'REQ' && m[1] == 'pending-query-id')
          .toList();
      expect(
        replayedReqs,
        hasLength(1),
        reason:
            'a pending one-shot query must be replayed on the fresh socket '
            'so it can still EOSE',
      );
    });
  });
}
