// ABOUTME: Tests for RelayPool.sendAwaitOk — resolves when all targeted relays
// ABOUTME: have responded OK, sent a reject, or the timeout elapses.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nostr.dart';
import 'package:nostr_sdk/relay/relay.dart';
import 'package:nostr_sdk/relay/relay_pool.dart';
import 'package:nostr_sdk/relay/relay_status.dart';

class _MockNostr extends Mock implements Nostr {}

class _FakeRelay extends Fake implements Relay {
  _FakeRelay(this.url) : relayStatus = RelayStatus(url) {
    relayStatus.writeAccess = true;
  }

  @override
  final String url;

  @override
  final RelayStatus relayStatus;

  @override
  Function(Relay, List<dynamic>)? onMessage;

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool? forceSend,
    bool queueIfFailed = true,
    bool skipReconnect = false,
  }) async {
    return true;
  }
}

void main() {
  group('RelayPool.sendAwaitOk', () {
    late _MockNostr nostr;
    late RelayPool pool;
    late _FakeRelay relayA;
    late _FakeRelay relayB;

    setUp(() {
      nostr = _MockNostr();
      relayA = _FakeRelay('wss://a');
      relayB = _FakeRelay('wss://b');
      pool = RelayPool(nostr, const [], (addr) => _FakeRelay(addr))
        ..addRelay(relayA)
        ..addRelay(relayB);
    });

    // Valid 64-char hex Nostr pubkey.
    const testPubkey =
        '0000000000000000000000000000000000000000000000000000000000000001';

    Event signedEvent(String id) {
      final event = Event(testPubkey, EventKind.textNote, const [], 'hi')
        ..id = id
        ..sig = 'sig';
      return event;
    }

    test('resolves accepted when all relays send OK=true', () async {
      final event = signedEvent('a' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(seconds: 2),
      );

      // Let the send() call register the pending publish before we inject
      // OK frames.
      await Future<void>.delayed(Duration.zero);

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      pool.handleMessageForTesting(relayB, ['OK', event.id, true, 'accepted']);

      final outcome = await future;
      expect(outcome.eventId, event.id);
      expect(outcome.acceptedBy, {'wss://a', 'wss://b'});
      expect(outcome.rejectedBy, isEmpty);
      expect(outcome.noResponseFrom, isEmpty);
      expect(outcome.acceptedByAll, isTrue);
    });

    test('records per-relay rejection reason', () async {
      final event = signedEvent('b' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(seconds: 2),
      );
      await Future<void>.delayed(Duration.zero);

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      pool.handleMessageForTesting(
        relayB,
        ['OK', event.id, false, 'blocked: user'],
      );

      final outcome = await future;
      expect(outcome.acceptedBy, {'wss://a'});
      expect(outcome.rejectedBy, {'wss://b': 'blocked: user'});
      expect(outcome.noResponseFrom, isEmpty);
    });

    test('relays with no response land in noResponseFrom after timeout',
        () async {
      final event = signedEvent('c' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      // relayB silent.

      final outcome = await future;
      expect(outcome.acceptedBy, {'wss://a'});
      expect(outcome.rejectedBy, isEmpty);
      expect(outcome.noResponseFrom, {'wss://b'});
    });

    test('unrelated OK frames do not resolve the publish', () async {
      final event = signedEvent('d' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);

      pool.handleMessageForTesting(relayA, ['OK', 'z' * 64, true, '']);
      pool.handleMessageForTesting(relayB, ['OK', 'z' * 64, true, '']);

      final outcome = await future;
      expect(outcome.acceptedBy, isEmpty);
      expect(outcome.noResponseFrom, {'wss://a', 'wss://b'});
    });

    test('pending publish is cleaned up after resolution', () async {
      final event = signedEvent('e' * 64);

      final future = pool.sendAwaitOk(
        event,
        timeout: const Duration(milliseconds: 100),
      );
      await Future<void>.delayed(Duration.zero);

      pool.handleMessageForTesting(relayA, ['OK', event.id, true, '']);
      pool.handleMessageForTesting(relayB, ['OK', event.id, true, '']);

      await future;
      expect(pool.pendingPublishCountForTesting, 0);
    });
  });
}
