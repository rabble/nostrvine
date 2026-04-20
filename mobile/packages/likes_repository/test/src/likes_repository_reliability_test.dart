// ABOUTME: Verifies LikesRepository surfaces PublishOutcome + feedback on
// ABOUTME: the LikeFailed/UnlikeFailed exceptions and preserves the
// ABOUTME: optimistic rollback contract when the relay rejects.

import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:test/test.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockLikesLocalStorage extends Mock implements LikesLocalStorage {}

const _testUserPubkey =
    '82341f882b6eabcd2ba7f1ef90aad961cf074af15b9ef44a09f9d2a8fbfbe6a2';
const _testEventId =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _testAuthorPubkey =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _testReactionId =
    '3333333333333333333333333333333333333333333333333333333333333333';

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

PublishOutcome _permanent(String id) => PublishOutcome(
  eventId: id,
  acceptedBy: const {},
  rejectedBy: const {'wss://relay.example.com': 'blocked: spam'},
  noResponseFrom: const {},
);

void main() {
  late _MockNostrClient mockNostr;
  late _MockLikesLocalStorage mockStorage;

  setUpAll(() {
    registerFallbackValue(const RetryPolicy());
    registerFallbackValue(
      LikeRecord(
        targetEventId: _testEventId,
        reactionEventId: _testReactionId,
        createdAt: DateTime(2026),
      ),
    );
  });

  setUp(() {
    mockNostr = _MockNostrClient();
    mockStorage = _MockLikesLocalStorage();
    when(() => mockNostr.publicKey).thenReturn(_testUserPubkey);
    when(() => mockNostr.hasKeys).thenReturn(false);
    when(() => mockNostr.unsubscribe(any())).thenAnswer((_) async {});
    when(() => mockStorage.getAllLikeRecords()).thenAnswer((_) async => []);
    when(
      () => mockStorage.watchLikedEventIds(),
    ).thenAnswer((_) => Stream.value(<String>[]));
    when(() => mockStorage.isLiked(any())).thenAnswer((_) async => false);
    when(() => mockStorage.getLikeRecord(any())).thenAnswer((_) async => null);
    when(() => mockStorage.saveLikeRecord(any())).thenAnswer((_) async {});
    when(
      () => mockStorage.deleteLikeRecord(any()),
    ).thenAnswer((_) async => true);
  });

  group('LikesRepository publish reliability', () {
    test(
      'like succeeds on acceptedByAny → record saved, reaction id returned',
      () async {
        when(
          () => mockNostr.sendLikeAwaitOk(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            addressableId: any(named: 'addressableId'),
            targetKind: any(named: 'targetKind'),
            content: any(named: 'content'),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _accepted(_testReactionId));

        final repo = LikesRepository(
          nostrClient: mockNostr,
          localStorage: mockStorage,
        );

        final reactionId = await repo.likeEvent(
          eventId: _testEventId,
          authorPubkey: _testAuthorPubkey,
        );

        expect(reactionId, equals(_testReactionId));
        expect(await repo.isLiked(_testEventId), isTrue);
        verify(() => mockStorage.saveLikeRecord(any())).called(1);

        repo.dispose();
      },
    );

    test(
      'like transient failure → exception carries retryable feedback, '
      'no local record saved',
      () async {
        when(
          () => mockNostr.sendLikeAwaitOk(
            eventId: any(named: 'eventId'),
            authorPubkey: any(named: 'authorPubkey'),
            addressableId: any(named: 'addressableId'),
            targetKind: any(named: 'targetKind'),
            content: any(named: 'content'),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transient(_testReactionId));

        final repo = LikesRepository(
          nostrClient: mockNostr,
          localStorage: mockStorage,
        );

        try {
          await repo.likeEvent(
            eventId: _testEventId,
            authorPubkey: _testAuthorPubkey,
          );
          fail('expected LikeFailedException');
        } on LikeFailedException catch (e) {
          expect(e.outcome, isNotNull);
          expect(e.outcome!.acceptedByAny, isFalse);
          expect(e.outcome!.transientRelays, {'wss://relay.example.com'});
          expect(e.feedback, isNotNull);
          expect(e.feedback!.retryable, isTrue);
          expect(e.feedback!.messageKey, 'publish_no_relay_response');
        }

        // No optimistic cache write when we haven't accepted yet — the
        // repository doesn't insert into _likeRecords or save to storage.
        expect(await repo.isLiked(_testEventId), isFalse);
        verifyNever(() => mockStorage.saveLikeRecord(any()));

        repo.dispose();
      },
    );

    test(
      'unlike permanent rejection → exception carries non-retryable feedback, '
      'local record preserved',
      () async {
        // Seed the local cache so the repo has a record to unlike.
        when(() => mockStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            LikeRecord(
              targetEventId: _testEventId,
              reactionEventId: _testReactionId,
              createdAt: DateTime.now(),
            ),
          ],
        );
        when(
          () => mockNostr.deleteEventAwaitOk(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _permanent(_testReactionId));

        final repo = LikesRepository(
          nostrClient: mockNostr,
          localStorage: mockStorage,
        );
        await repo.isLiked(_testEventId); // trigger init

        try {
          await repo.unlikeEvent(_testEventId);
          fail('expected UnlikeFailedException');
        } on UnlikeFailedException catch (e) {
          expect(e.outcome, isNotNull);
          expect(e.outcome!.rejectedBy, isNotEmpty);
          expect(e.feedback!.retryable, isFalse);
          expect(e.feedback!.messageKey, 'publish_rejected_permanent');
          expect(e.feedback!.firstRejectionReason, 'blocked: spam');
        }

        // Contract: the like is still present locally when the relay
        // rejected the deletion so the UI can re-try without losing state.
        expect(await repo.isLiked(_testEventId), isTrue);
        verifyNever(() => mockStorage.deleteLikeRecord(_testEventId));

        repo.dispose();
      },
    );

    test(
      'unlike transient failure → exception carries retryable feedback',
      () async {
        when(() => mockStorage.getAllLikeRecords()).thenAnswer(
          (_) async => [
            LikeRecord(
              targetEventId: _testEventId,
              reactionEventId: _testReactionId,
              createdAt: DateTime.now(),
            ),
          ],
        );
        when(
          () => mockNostr.deleteEventAwaitOk(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => _transient(_testReactionId));

        final repo = LikesRepository(
          nostrClient: mockNostr,
          localStorage: mockStorage,
        );
        await repo.isLiked(_testEventId);

        try {
          await repo.unlikeEvent(_testEventId);
          fail('expected UnlikeFailedException');
        } on UnlikeFailedException catch (e) {
          expect(e.feedback!.retryable, isTrue);
          expect(e.feedback!.messageKey, 'publish_no_relay_response');
        }

        repo.dispose();
      },
    );
  });
}
