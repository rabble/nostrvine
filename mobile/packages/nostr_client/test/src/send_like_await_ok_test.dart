// ABOUTME: Tests for NostrClient.sendLikeAwaitOk, .sendRepostAwaitOk,
// ABOUTME: .sendGenericRepostAwaitOk, and .deleteEventAwaitOk — the
// ABOUTME: publishEventWithRetry-aware variants used by repositories.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

class _MockNostr extends Mock implements Nostr {}

class _MockRelayManager extends Mock implements RelayManager {}

class _FakeEvent extends Fake implements Event {}

const _testPublicKey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
const _testAuthorPubkey =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _testEventId =
    '2222222222222222222222222222222222222222222222222222222222222222';

PublishOutcome _accepted(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {'wss://relay.example.com'},
  rejectedBy: const {},
  noResponseFrom: const {},
);

PublishOutcome _transient(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {},
  rejectedBy: const {},
  noResponseFrom: const {'wss://relay.example.com'},
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(const Duration(seconds: 15));
  });

  group('NostrClient.sendLikeAwaitOk', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUp(() {
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();
      when(() => mockNostr.publicKey).thenReturn(_testPublicKey);
      when(() => mockNostr.close()).thenReturn(null);
      when(() => mockRelayManager.dispose()).thenAnswer((_) async {});
      when(
        () => mockRelayManager.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );
    });

    tearDown(() {
      reset(mockNostr);
      reset(mockRelayManager);
    });

    test(
      'builds reaction event with e, p tags and returns outcome',
      () async {
        Event? sentEvent;
        when(
          () => mockNostr.sendEventAwaitOk(
            any(),
            timeout: any(named: 'timeout'),
            tempRelays: any(named: 'tempRelays'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((invocation) async {
          sentEvent = invocation.positionalArguments[0] as Event;
          return _accepted(sentEvent!.id);
        });

        final outcome = await client.sendLikeAwaitOk(
          eventId: _testEventId,
          authorPubkey: _testAuthorPubkey,
        );

        expect(outcome.acceptedByAny, isTrue);
        expect(sentEvent, isNotNull);
        expect(sentEvent!.kind, EventKind.reaction);
        expect(sentEvent!.content, '+');
        expect(
          sentEvent!.tags,
          containsAll(<List<String>>[
            ['e', _testEventId],
            ['p', _testAuthorPubkey],
          ]),
        );
        // No a / k tags when addressableId + targetKind omitted.
        expect(
          sentEvent!.tags.where((t) => t.isNotEmpty && t[0] == 'a'),
          isEmpty,
        );
        expect(
          sentEvent!.tags.where((t) => t.isNotEmpty && t[0] == 'k'),
          isEmpty,
        );
      },
    );

    test('includes a + k tags when addressable/kind provided', () async {
      Event? sentEvent;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        sentEvent = invocation.positionalArguments[0] as Event;
        return _accepted(sentEvent!.id);
      });

      await client.sendLikeAwaitOk(
        eventId: _testEventId,
        authorPubkey: _testAuthorPubkey,
        addressableId: '34236:$_testAuthorPubkey:video-d-tag',
        targetKind: 34236,
      );

      expect(sentEvent, isNotNull);
      expect(
        sentEvent!.tags,
        containsAll(<List<String>>[
          ['a', '34236:$_testAuthorPubkey:video-d-tag'],
          ['k', '34236'],
        ]),
      );
    });

    test('passes through custom content (downvote)', () async {
      Event? sentEvent;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        sentEvent = invocation.positionalArguments[0] as Event;
        return _accepted(sentEvent!.id);
      });

      await client.sendLikeAwaitOk(
        eventId: _testEventId,
        authorPubkey: _testAuthorPubkey,
        content: '-',
      );

      expect(sentEvent!.content, '-');
    });

    test('transient outcome passes through unchanged', () async {
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (invocation) async =>
            _transient((invocation.positionalArguments[0] as Event).id),
      );

      final outcome = await client.sendLikeAwaitOk(
        eventId: _testEventId,
        authorPubkey: _testAuthorPubkey,
      );

      expect(outcome.acceptedByAny, isFalse);
      expect(outcome.transientRelays, {'wss://relay.example.com'});
    });

    test('with retry policy, retries transient relays', () async {
      var callCount = 0;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        callCount++;
        final id = (invocation.positionalArguments[0] as Event).id;
        if (callCount == 1) return _transient(id);
        return _accepted(id);
      });

      final outcome = await client.sendLikeAwaitOk(
        eventId: _testEventId,
        authorPubkey: _testAuthorPubkey,
        policy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 1),
        ),
      );

      expect(outcome.acceptedByAny, isTrue);
      expect(callCount, 2);
    });
  });

  group('NostrClient.sendRepostAwaitOk', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUp(() {
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();
      when(() => mockNostr.publicKey).thenReturn(_testPublicKey);
      when(() => mockNostr.close()).thenReturn(null);
      when(() => mockRelayManager.dispose()).thenAnswer((_) async {});
      when(
        () => mockRelayManager.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );
    });

    tearDown(() {
      reset(mockNostr);
      reset(mockRelayManager);
    });

    test('builds kind 6 repost with e tag and returns outcome', () async {
      Event? sentEvent;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        sentEvent = invocation.positionalArguments[0] as Event;
        return _accepted(sentEvent!.id);
      });

      final outcome = await client.sendRepostAwaitOk(
        eventId: _testEventId,
      );

      expect(outcome.acceptedByAny, isTrue);
      expect(sentEvent!.kind, EventKind.repost);
      expect(sentEvent!.tags, [
        ['e', _testEventId],
      ]);
      expect(sentEvent!.content, '');
    });

    test('includes relay hint as third element of e tag when set', () async {
      Event? sentEvent;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        sentEvent = invocation.positionalArguments[0] as Event;
        return _accepted(sentEvent!.id);
      });

      await client.sendRepostAwaitOk(
        eventId: _testEventId,
        relayHint: 'wss://hint.example.com',
      );

      expect(sentEvent!.tags, [
        ['e', _testEventId, 'wss://hint.example.com'],
      ]);
    });
  });

  group('NostrClient.sendGenericRepostAwaitOk', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUp(() {
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();
      when(() => mockNostr.publicKey).thenReturn(_testPublicKey);
      when(() => mockNostr.close()).thenReturn(null);
      when(() => mockRelayManager.dispose()).thenAnswer((_) async {});
      when(
        () => mockRelayManager.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );
    });

    tearDown(() {
      reset(mockNostr);
      reset(mockRelayManager);
    });

    test('builds kind 16 generic repost with a, k, p, and e tags', () async {
      Event? sentEvent;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        sentEvent = invocation.positionalArguments[0] as Event;
        return _accepted(sentEvent!.id);
      });

      const addressableId = '34236:$_testAuthorPubkey:video-d-tag';
      final outcome = await client.sendGenericRepostAwaitOk(
        addressableId: addressableId,
        targetKind: 34236,
        authorPubkey: _testAuthorPubkey,
        eventId: _testEventId,
      );

      expect(outcome.acceptedByAny, isTrue);
      expect(sentEvent!.kind, EventKind.genericRepost);
      expect(sentEvent!.content, '');
      expect(
        sentEvent!.tags,
        [
          ['k', '34236'],
          ['a', addressableId],
          ['p', _testAuthorPubkey],
          ['e', _testEventId],
        ],
      );
    });
  });

  group('NostrClient.deleteEventAwaitOk', () {
    late _MockNostr mockNostr;
    late _MockRelayManager mockRelayManager;
    late NostrClient client;

    setUp(() {
      mockNostr = _MockNostr();
      mockRelayManager = _MockRelayManager();
      when(() => mockNostr.publicKey).thenReturn(_testPublicKey);
      when(() => mockNostr.close()).thenReturn(null);
      when(() => mockRelayManager.dispose()).thenAnswer((_) async {});
      when(
        () => mockRelayManager.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
      client = NostrClient.forTesting(
        nostr: mockNostr,
        relayManager: mockRelayManager,
      );
    });

    tearDown(() {
      reset(mockNostr);
      reset(mockRelayManager);
    });

    test('builds kind 5 event with e tag and "delete" content', () async {
      Event? sentEvent;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        sentEvent = invocation.positionalArguments[0] as Event;
        return _accepted(sentEvent!.id);
      });

      final outcome = await client.deleteEventAwaitOk(_testEventId);

      expect(outcome.acceptedByAny, isTrue);
      expect(sentEvent!.kind, EventKind.eventDeletion);
      expect(sentEvent!.content, 'delete');
      expect(sentEvent!.tags, [
        ['e', _testEventId],
      ]);
    });

    test('propagates transient outcome to caller', () async {
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (invocation) async =>
            _transient((invocation.positionalArguments[0] as Event).id),
      );

      final outcome = await client.deleteEventAwaitOk(_testEventId);

      expect(outcome.failed, isTrue);
      expect(outcome.transientRelays, {'wss://relay.example.com'});
    });

    test('with retry policy, retries transient relays', () async {
      var callCount = 0;
      when(
        () => mockNostr.sendEventAwaitOk(
          any(),
          timeout: any(named: 'timeout'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((invocation) async {
        callCount++;
        final id = (invocation.positionalArguments[0] as Event).id;
        if (callCount == 1) return _transient(id);
        return _accepted(id);
      });

      final outcome = await client.deleteEventAwaitOk(
        _testEventId,
        policy: const RetryPolicy(
          maxAttempts: 2,
          baseDelay: Duration(milliseconds: 1),
        ),
      );

      expect(outcome.acceptedByAny, isTrue);
      expect(callCount, 2);
    });
  });
}
