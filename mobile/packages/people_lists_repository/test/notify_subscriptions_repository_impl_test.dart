// ABOUTME: Covers d=notify list read/publish, mutation serialization, and
// ABOUTME: that a failed publish leaves the snapshot revertible.

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:people_lists_repository/people_lists_repository.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const ownerPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const creatorA =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const creatorB =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

Event _notifyEvent(List<String> pubkeys, {int createdAt = 1710000000}) => Event(
  ownerPubkey,
  Nip51PeopleListCodec.kind,
  [
    ['d', Nip51PeopleListCodec.notifyDTag],
    ['title', 'Notify'],
    for (final p in pubkeys) ['p', p],
  ],
  '',
  createdAt: createdAt,
);

/// Member pubkeys carried on the event handed to `publishEvent`.
List<String> _publishedMembers(Event event) => event.tags
    .where((t) => t.length >= 2 && t[0] == 'p')
    .map((t) => t[1])
    .toList();

void main() {
  setUpAll(() {
    registerFallbackValue(_notifyEvent(const []));
    registerFallbackValue(<Filter>[]);
  });

  group(NotifySubscriptionsRepositoryImpl, () {
    late _MockNostrClient client;
    late NotifySubscriptionsRepositoryImpl repository;

    setUp(() {
      client = _MockNostrClient();
      repository = NotifySubscriptionsRepositoryImpl(nostrClient: client);
    });

    tearDown(() async {
      await repository.dispose();
    });

    void stubPublishSuccess() {
      when(() => client.publishEvent(any())).thenAnswer(
        (invocation) async => PublishSuccess(
          event: invocation.positionalArguments.first as Event,
        ),
      );
    }

    group('readSubscriptions', () {
      test('returns an empty set when the user has no notify list', () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          isEmpty,
        );
      });

      test('decodes members from the notify list event', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA, creatorB]),
          ],
        );

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA, creatorB}),
        );
      });

      test('keeps the newest generation when relays return several', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA, creatorB]),
            _notifyEvent([creatorA], createdAt: 1710000500),
          ],
        );

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );
      });

      test('returns empty rather than throwing when the read fails', () async {
        when(
          () => client.queryEvents(any()),
        ).thenThrow(StateError('relay down'));

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          isEmpty,
        );
      });
    });

    group('subscribe', () {
      test('publishes the full list including the new creator', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA]),
          ],
        );
        stubPublishSuccess();

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );

        expect(result.submitted, isTrue);
        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), containsAll([creatorA, creatorB]));
      });

      test('never truncates the creator pubkey', () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        stubPublishSuccess();

        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), equals([creatorA]));
        expect(creatorA, hasLength(64));
      });

      test('is a no-op when already subscribed', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA]),
          ],
        );

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });

      test('refuses to subscribe the owner to themselves', () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: ownerPubkey,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });

      test('leaves the snapshot unchanged when the publish fails', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA]),
          ],
        );
        when(
          () => client.publishEvent(any()),
        ).thenAnswer((_) async => const PublishFailed());

        final result = await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );

        expect(result.status, equals(PeopleListPublishStatus.failed));
        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
          reason: 'a failed publish must not leave optimistic state behind',
        );
      });
    });

    group('unsubscribe', () {
      test('publishes the list without the creator', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA, creatorB]),
          ],
        );
        stubPublishSuccess();

        final result = await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        expect(result.submitted, isTrue);
        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), equals([creatorB]));
      });

      test('publishes an empty list when the last bell is removed', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA]),
          ],
        );
        stubPublishSuccess();

        await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(_publishedMembers(published), isEmpty);
        expect(
          published.tags.any((t) => t.isNotEmpty && t[0] == 'd'),
          isTrue,
          reason: 'clearing the list must still be a valid d=notify event',
        );
      });

      test('is a no-op when not subscribed, so unfollow can call it '
          'unconditionally', () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);

        final result = await repository.unsubscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorA,
        );

        expect(result.status, equals(PeopleListPublishStatus.noop));
        verifyNever(() => client.publishEvent(any()));
      });
    });

    group('mutation serialization', () {
      test('concurrent subscribes both survive in the final list', () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        // A slow publish widens the window a naive implementation would race
        // in: both mutations would read the same empty base set.
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          );
        });

        await Future.wait([
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorB,
          ),
        ]);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA, creatorB}),
        );

        final published = verify(
          () => client.publishEvent(captureAny()),
        ).captured.cast<Event>();
        expect(published, hasLength(2));
        expect(
          _publishedMembers(published.last),
          containsAll([creatorA, creatorB]),
          reason: 'the second publish must build on the first, not clobber it',
        );
      });

      test('a rapid on/off/on sequence converges to on', () async {
        when(() => client.queryEvents(any())).thenAnswer((_) async => []);
        when(() => client.publishEvent(any())).thenAnswer((invocation) async {
          await Future<void>.delayed(const Duration(milliseconds: 10));
          return PublishSuccess(
            event: invocation.positionalArguments.first as Event,
          );
        });

        await Future.wait([
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
          repository.unsubscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
          repository.subscribe(
            ownerPubkey: ownerPubkey,
            creatorPubkey: creatorA,
          ),
        ]);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );
        // Each toggle must observe the previous one's result. Unserialized,
        // all three read the same empty base set, so the unsubscribe collapses
        // to a no-op and only two events are published.
        expect(
          verify(() => client.publishEvent(captureAny())).captured,
          hasLength(3),
        );
      });

      test(
        'a failed mutation does not abort the ones queued behind it',
        () async {
          when(() => client.queryEvents(any())).thenAnswer((_) async => []);
          var call = 0;
          when(() => client.publishEvent(any())).thenAnswer((invocation) async {
            call++;
            if (call == 1) throw StateError('relay rejected');
            return PublishSuccess(
              event: invocation.positionalArguments.first as Event,
            );
          });

          final results = await Future.wait([
            repository.subscribe(
              ownerPubkey: ownerPubkey,
              creatorPubkey: creatorA,
            ),
            repository.subscribe(
              ownerPubkey: ownerPubkey,
              creatorPubkey: creatorB,
            ),
          ]);

          expect(results.first.status, equals(PeopleListPublishStatus.failed));
          expect(results.last.submitted, isTrue);
          expect(
            await repository.readSubscriptions(ownerPubkey: ownerPubkey),
            equals({creatorB}),
          );
        },
      );

      test('steps created_at past the previous event so replacement is not '
          'a coin flip', () async {
        final nowSeconds =
            DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
        when(() => client.queryEvents(any())).thenAnswer(
          // A list published "in the future" relative to this device's clock.
          (_) async => [
            _notifyEvent([creatorA], createdAt: nowSeconds + 500),
          ],
        );
        stubPublishSuccess();

        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );

        final published =
            verify(() => client.publishEvent(captureAny())).captured.single
                as Event;
        expect(published.createdAt, greaterThan(nowSeconds + 500));
      });
    });

    group('refresh', () {
      test('replaces a stale snapshot and emits the new set', () async {
        var events = [
          _notifyEvent([creatorA]),
        ];
        when(() => client.queryEvents(any())).thenAnswer((_) async => events);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorA}),
        );

        // The list changed elsewhere — another device, or another client.
        events = [
          _notifyEvent([creatorB], createdAt: 1710000900),
        ];

        final emitted = <Set<String>>[];
        final subscription = repository
            .watchSubscriptions(ownerPubkey: ownerPubkey)
            .listen(emitted.add);
        addTearDown(subscription.cancel);

        await repository.refresh(ownerPubkey: ownerPubkey);
        await Future<void>.delayed(Duration.zero);

        expect(
          await repository.readSubscriptions(ownerPubkey: ownerPubkey),
          equals({creatorB}),
        );
        expect(emitted.last, equals({creatorB}));
      });
    });

    group('watchSubscriptions', () {
      test('emits the loaded set then each mutation', () async {
        when(
          () => client.queryEvents(any()),
        ).thenAnswer(
          (_) async => [
            _notifyEvent([creatorA]),
          ],
        );
        stubPublishSuccess();

        final emitted = <Set<String>>[];
        final subscription = repository
            .watchSubscriptions(ownerPubkey: ownerPubkey)
            .listen(emitted.add);
        addTearDown(subscription.cancel);

        await repository.readSubscriptions(ownerPubkey: ownerPubkey);
        await repository.subscribe(
          ownerPubkey: ownerPubkey,
          creatorPubkey: creatorB,
        );
        await Future<void>.delayed(Duration.zero);

        expect(emitted.last, equals({creatorA, creatorB}));
        expect(
          emitted,
          contains(equals({creatorA})),
          reason: 'a late listener must see the loaded set, not only changes',
        );
      });
    });
  });
}
