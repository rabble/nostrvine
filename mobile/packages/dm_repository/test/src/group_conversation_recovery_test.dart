// ABOUTME: Unit coverage for the pure reconstruction and attestation rules the
// ABOUTME: #8407 group-conversation recovery pass applies.

import 'dart:convert';

import 'package:dm_repository/src/group_conversation_recovery.dart';
import 'package:flutter_test/flutter_test.dart';

const _me = '1111111111111111111111111111111111111111111111111111111111111111';
const _alice =
    '2222222222222222222222222222222222222222222222222222222222222222';
const _bob = '3333333333333333333333333333333333333333333333333333333333333333';

String _tags(List<String> pubkeys, {String? replyTo, String? subject}) =>
    jsonEncode([
      for (final pk in pubkeys) ['p', pk],
      if (replyTo != null) ['e', replyTo],
      if (subject != null) ['subject', subject],
    ]);

RecoveryMessageFacts _facts({
  required String id,
  required String sender,
  required List<String> pTags,
  String? replyToId,
  String? subject,
  int createdAt = 0,
}) => RecoveryMessageFacts(
  id: id,
  senderPubkey: sender,
  participants: reconstructParticipants(
    _tags(pTags, replyTo: replyToId, subject: subject),
    sender,
  ),
  replyToId: replyToId,
  subject: subject,
  createdAt: createdAt,
);

void main() {
  group('reconstructParticipants', () {
    test('unions the p tags with the sender, per NIP-17', () {
      expect(
        reconstructParticipants(_tags([_me, _bob]), _alice),
        equals({_me, _alice, _bob}),
      );
    });

    test('recovers the sender the group rumor deliberately omits', () {
      // buildGroupRumor never p-tags the sender, so the tags alone are always
      // short exactly one member — Alice appears only because she sent it.
      expect(_tags([_me, _bob]).contains(_alice), isFalse);
      expect(
        reconstructParticipants(_tags([_me, _bob]), _alice),
        contains(_alice),
      );
    });

    test('a 1:1 message reconstructs to exactly the pair', () {
      expect(
        reconstructParticipants(_tags([_me]), _alice),
        equals({_me, _alice}),
      );
    });

    test('null, empty and malformed tags leave only the sender', () {
      for (final tags in <String?>[null, '', 'not json', '{"not":"a list"}']) {
        expect(
          reconstructParticipants(tags, _alice),
          equals({_alice}),
          reason: 'a row that names no room must not widen one',
        );
      }
    });

    test('ignores malformed and non-p entries without throwing', () {
      expect(
        reconstructParticipants(
          jsonEncode([
            ['p'],
            ['p', 42],
            ['e', 'abc'],
            ['p', _bob],
          ]),
          _alice,
        ),
        equals({_bob, _alice}),
      );
    });
  });

  group('canonicalParticipantKey', () {
    test('is order independent', () {
      expect(
        canonicalParticipantKey([_bob, _me, _alice]),
        equals(canonicalParticipantKey([_alice, _bob, _me])),
      );
    });

    test('dedupes equal sets that Set equality would not', () {
      // Dart Set has no value equality: {a,b} != {a,b} as map keys. This is
      // the bug the key exists to prevent.
      expect(<Set<String>>{
        {_me, _alice},
        {_me, _alice},
      }, hasLength(2));
      expect(<String>{
        canonicalParticipantKey({_me, _alice}),
        canonicalParticipantKey({_me, _alice}),
      }, hasLength(1));
    });
  });

  group('bucketByRoom', () {
    test('separates the 1:1 rows from the widened ones', () {
      final buckets = bucketByRoom([
        _facts(id: 'd1', sender: _alice, pTags: [_me]),
        _facts(id: 'g1', sender: _alice, pTags: [_me, _bob]),
        _facts(id: 'g2', sender: _bob, pTags: [_me, _alice]),
      ]);

      expect(buckets, hasLength(2));
      expect(
        buckets[canonicalParticipantKey([_me, _alice])]!.map((m) => m.id),
        equals(['d1']),
      );
      expect(
        buckets[canonicalParticipantKey([_me, _alice, _bob])]!.map((m) => m.id),
        equals(['g1', 'g2']),
      );
    });
  });

  group('isAttestedGroup', () {
    test('attests a room two different people spoke in', () {
      final bucket = [
        _facts(id: 'g1', sender: _alice, pTags: [_me, _bob]),
        _facts(id: 'g2', sender: _bob, pTags: [_me, _alice]),
      ];
      expect(isAttestedGroup(bucket, _roomsOf(bucket)), isTrue);
    });

    test('REFUSES a single-sender room, even with no reply-mention shape', () {
      // Indistinguishable from a mention-widened 1:1 whose widening message
      // simply is not a reply, so there is no `e` tag to veto on. Skipped
      // rather than guessed: a wrong restore is a visible phantom thread,
      // while a skip leaves the thread exactly as the user already sees it.
      final bucket = [
        _facts(id: 'g1', sender: _alice, pTags: [_me, _bob]),
      ];
      expect(isAttestedGroup(bucket, _roomsOf(bucket)), isFalse);
    });

    test('REFUSES a widened reply whose parent is no longer on disk', () {
      // The `e`-tag veto cannot fire without a resolvable parent, so the
      // sender count is the only thing between this and a phantom.
      final orphan = _facts(
        id: 'g1',
        sender: _alice,
        pTags: [_me, _bob],
        replyToId: 'purged',
      );
      expect(isAttestedGroup([orphan], _roomsOf([orphan])), isFalse);
    });

    test('REFUSES the reply-mention shape #2740 describes', () {
      // i2 replies to a 1:1 message and merely mentions Bob. Recovering this
      // would recreate exactly the duplicate conversation #2741 removed.
      final oneToOne = _facts(id: 'i1', sender: _alice, pTags: [_me]);
      final widened = _facts(
        id: 'i2',
        sender: _alice,
        pTags: [_me, _bob],
        replyToId: 'i1',
      );
      final rooms = _roomsOf([oneToOne, widened]);

      expect(isAttestedGroup([widened], rooms), isFalse);
    });

    test('still attests a group reply that stays inside its own room', () {
      final first = _facts(id: 'g1', sender: _alice, pTags: [_me, _bob]);
      final reply = _facts(
        id: 'g2',
        sender: _bob,
        pTags: [_me, _alice],
        replyToId: 'g1',
      );
      final rooms = _roomsOf([first, reply]);

      expect(isAttestedGroup([first, reply], rooms), isTrue);
    });

    test('the e-tag veto still applies even when two senders spoke', () {
      // Belt and braces: the sender count says yes, the reply shape says the
      // widening is a mention. The veto wins.
      final plain = _facts(id: 'p1', sender: _alice, pTags: [_me]);
      final a = _facts(
        id: 'm1',
        sender: _alice,
        pTags: [_me, _bob],
        replyToId: 'p1',
      );
      final b = _facts(id: 'm2', sender: _bob, pTags: [_me, _alice]);
      final rooms = _roomsOf([plain, a, b]);

      expect(isAttestedGroup([a, b], rooms), isFalse);
    });

    test('an unresolvable reply parent does not veto a two-sender room', () {
      final a = _facts(
        id: 'g1',
        sender: _alice,
        pTags: [_me, _bob],
        replyToId: 'gone',
      );
      final b = _facts(id: 'g2', sender: _bob, pTags: [_me, _alice]);
      expect(isAttestedGroup([a, b], _roomsOf([a, b])), isTrue);
    });

    test('an empty bucket is never attested', () {
      expect(isAttestedGroup(const [], const {}), isFalse);
    });
  });

  group('newestSubject', () {
    test('takes the newest subject, per NIP-17', () {
      final bucket = [
        _facts(
          id: 'g1',
          sender: _alice,
          pTags: [_me, _bob],
          subject: 'Weekend trip',
          createdAt: 10,
        ),
        _facts(
          id: 'g2',
          sender: _bob,
          pTags: [_me, _alice],
          subject: 'Weekend trip v2',
          createdAt: 20,
        ),
        _facts(id: 'g3', sender: _bob, pTags: [_me, _alice], createdAt: 30),
      ];
      expect(newestSubject(bucket), equals('Weekend trip v2'));
    });

    test('returns null when nothing carries one', () {
      expect(
        newestSubject([
          _facts(id: 'g1', sender: _alice, pTags: [_me, _bob]),
        ]),
        isNull,
      );
    });
  });
}

Map<String, Set<String>> _roomsOf(List<RecoveryMessageFacts> messages) => {
  for (final m in messages) m.id: m.participants,
};
