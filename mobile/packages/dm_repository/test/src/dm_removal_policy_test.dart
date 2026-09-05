// ABOUTME: Coverage for the injected conversation-removal policy (#8391) — the
// ABOUTME: repository-level guard that stops any caller destroying a protected
// ABOUTME: thread, which #8302 had guarded in one cubit only.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';

class _MockNostrClient extends Mock implements NostrClient {}

const _owner =
    '1111111111111111111111111111111111111111111111111111111111111111';
const _protectedPeer =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _ordinaryPeer =
    '3333333333333333333333333333333333333333333333333333333333333333';
const _otherPeer =
    '4444444444444444444444444444444444444444444444444444444444444444';

bool _protectsTheProtectedPeer(String pubkeyHex) => pubkeyHex == _protectedPeer;

void main() {
  group('DmRepository removal policy', () {
    late AppDatabase db;
    late ConversationsDao conversationsDao;
    late DirectMessagesDao messagesDao;

    setUp(() {
      db = AppDatabase.test(NativeDatabase.memory());
      conversationsDao = ConversationsDao(db);
      messagesDao = DirectMessagesDao(db);
    });

    tearDown(() => db.close());

    DmRepository buildRepository({
      DmConversationRemovalPolicy? removalPolicy,
      String owner = _owner,
    }) => DmRepository(
      nostrClient: _MockNostrClient(),
      directMessagesDao: messagesDao,
      conversationsDao: conversationsDao,
      removedConversationsDao: db.removedConversationsDao,
      userPubkey: owner,
      removalPolicy: removalPolicy,
    );

    Future<String> seedConversation(
      List<String> participants, {
      String owner = _owner,
    }) async {
      final conversationId = DmRepository.computeConversationId(participants);
      await conversationsDao.upsertConversation(
        id: conversationId,
        participantPubkeys: '["${participants.join('","')}"]',
        isGroup: participants.length > 2,
        createdAt: 1700000000,
        ownerPubkey: owner,
      );
      return conversationId;
    }

    group('removeConversation', () {
      test('refuses a protected peer and leaves the row on disk', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _protectedPeer]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.refused));
        expect(await repository.getConversation(conversationId), isNotNull);
      });

      test('removes an ordinary conversation', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _ordinaryPeer]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
        expect(await repository.getConversation(conversationId), isNull);
      });

      test('refuses a group that merely includes a protected peer', () async {
        // `.any`, never `.first` — a group has more than one peer, and the
        // protected one need not be the first (#8302 review, 739349d45).
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([
          _owner,
          _ordinaryPeer,
          _protectedPeer,
        ]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.refused));
        expect(await repository.getConversation(conversationId), isNotNull);
      });

      test('excludes self, so a protected account can clear its own '
          'threads', () async {
        // Signed in AS the protected identity: its own threads stay removable.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
          owner: _protectedPeer,
        );
        final conversationId = await seedConversation([
          _protectedPeer,
          _ordinaryPeer,
        ], owner: _protectedPeer);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
      });

      test('fails open for a conversation that is not on disk', () async {
        // A stale id must never become an undeletable row.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );

        final outcome = await repository.removeConversation('no-such-id');

        expect(outcome, equals(ConversationRemovalOutcome.removed));
      });

      test('removes a protected peer when no policy is injected', () async {
        // The default is permissive, so a fixture wiring nothing behaves
        // exactly as it did before the policy existed.
        final repository = buildRepository();
        final conversationId = await seedConversation([_owner, _protectedPeer]);

        final outcome = await repository.removeConversation(conversationId);

        expect(outcome, equals(ConversationRemovalOutcome.removed));
        expect(await repository.getConversation(conversationId), isNull);
      });
    });

    group('removeConversations', () {
      test('sweeps the ordinary rows and keeps the protected one', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);
        final ordinaryId = await seedConversation([_owner, _ordinaryPeer]);
        final otherId = await seedConversation([_owner, _otherPeer]);
        const missingId = 'missing-conversation';

        final outcome = await repository.removeConversations([
          protectedId,
          ordinaryId,
          otherId,
          missingId,
        ]);

        expect(outcome.removed, equals(2));
        expect(outcome.refused, equals(1));
        expect(await repository.getConversation(protectedId), isNotNull);
        expect(await repository.getConversation(ordinaryId), isNull);
        expect(await repository.getConversation(otherId), isNull);
      });

      test('reports the refusal when every row is protected', () async {
        // The path that read as a broken button before #8347: nothing to
        // remove, so the caller needs a signal rather than silence.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);

        final outcome = await repository.removeConversations([protectedId]);

        expect(outcome.removed, equals(0));
        expect(outcome.refused, equals(1));
        expect(await repository.getConversation(protectedId), isNotNull);
      });

      test('returns zero counts for an empty list', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );

        final outcome = await repository.removeConversations([]);

        expect(outcome.removed, equals(0));
        expect(outcome.refused, equals(0));
      });
    });

    group('removal tombstones', () {
      Future<int?> tombstoneFor(String conversationId) =>
          db.removedConversationsDao.removedAtFor(
            conversationId: conversationId,
            ownerPubkey: _owner,
          );

      test('records a tombstone for a conversation that IS on disk', () async {
        // The control. Suppression of replayed history is the whole point of
        // the marker, so the absent-row tests below only mean something if
        // this one proves the present-row path still writes it.
        final repository = buildRepository();
        final conversationId = await seedConversation([_owner, _ordinaryPeer]);

        await repository.removeConversation(conversationId);

        expect(await tombstoneFor(conversationId), isNotNull);
      });

      test(
        'writes NO tombstone for a conversation that is not on disk',
        () async {
          // #7850. The guard fails open on a missing row so a stale id never
          // becomes undeletable — but the tombstone used to be written anyway,
          // and ingest drops every message at or before `removedAt`. A
          // moderation notice's created_at is always in the past, so one marker
          // for an id this device never held suppressed that notice on every
          // future relay replay, permanently and silently.
          //
          // Nothing local was removed, so there is no local history to
          // suppress.
          final repository = buildRepository(
            removalPolicy: _protectsTheProtectedPeer,
          );
          const absentId = 'conversation-this-device-never-had';

          final outcome = await repository.removeConversation(absentId);

          expect(outcome, equals(ConversationRemovalOutcome.removed));
          expect(await tombstoneFor(absentId), isNull);
        },
      );

      test('writes no tombstone for the absent members of a batch', () async {
        // `removeConversations` collects ids when the list renders and acts on
        // them later, so a row that disappears in between reaches the batch
        // absent. That is the reachable form of the single-path bug above.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final ordinaryId = await seedConversation([_owner, _ordinaryPeer]);
        const absentId = 'vanished-between-render-and-tap';

        final outcome = await repository.removeConversations([
          ordinaryId,
          absentId,
        ]);

        expect(outcome.removed, equals(1));
        expect(outcome.refused, equals(0));
        expect(await tombstoneFor(ordinaryId), isNotNull);
        expect(await tombstoneFor(absentId), isNull);
      });

      test('writes no tombstone for a refused conversation', () async {
        // A refusal deletes nothing, so it must also suppress nothing.
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final protectedId = await seedConversation([_owner, _protectedPeer]);

        await repository.removeConversation(protectedId);

        expect(await tombstoneFor(protectedId), isNull);
      });
    });

    group('isRemovalProtected', () {
      test('answers for a peer the policy protects', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _protectedPeer]);
        final conversation = await repository.getConversation(conversationId);

        expect(repository.isRemovalProtected(conversation!), isTrue);
      });

      test('answers false for an ordinary peer', () async {
        final repository = buildRepository(
          removalPolicy: _protectsTheProtectedPeer,
        );
        final conversationId = await seedConversation([_owner, _ordinaryPeer]);
        final conversation = await repository.getConversation(conversationId);

        expect(repository.isRemovalProtected(conversation!), isFalse);
      });
    });
  });
}
