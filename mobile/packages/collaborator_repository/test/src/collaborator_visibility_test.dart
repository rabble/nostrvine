// ABOUTME: Tests for CollaboratorVisibility view-model.

import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

const _creator =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _collab1 =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const _collab2 =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const _viewer =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';

void main() {
  group(CollaboratorVisibility, () {
    group('fallback', () {
      test('exposes raw tagged list unfiltered', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1, _collab2],
        );
        expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
      });

      test('isInviterView is always false', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1],
        );
        expect(vis.isInviterView, isFalse);
      });

      test('pendingCount is always zero', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1, _collab2],
        );
        expect(vis.pendingCount, equals(0));
      });

      test('isPendingForInviter is always false', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1],
        );
        expect(vis.isPendingForInviter(_collab1), isFalse);
      });

      test('statusFor returns pending for any pubkey', () {
        const vis = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1],
        );
        expect(vis.statusFor(_collab1), equals(CollaboratorStatus.pending));
        expect(vis.statusFor(_collab2), equals(CollaboratorStatus.pending));
      });
    });

    group('inviter view', () {
      test('isInviterView true when current user is the creator', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isTrue);
      });

      test('pending entries flagged as pending; confirmed are not', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.isPendingForInviter(_collab1), isTrue);
        expect(vis.isPendingForInviter(_collab2), isFalse);
      });

      test('missing entries default to pending', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.isPendingForInviter(_collab1), isTrue);
      });

      test('pendingCount counts pending entries only', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.pendingCount, equals(1));
      });

      test('visiblePubkeys returns all tagged when none ignored', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
      });
    });

    group('recipient view', () {
      test('isInviterView false when current user is a collaborator', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isFalse);
      });

      test('isPendingForInviter false for recipient view', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.pending,
          },
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
        );
        expect(vis.isPendingForInviter(_collab1), isFalse);
        expect(vis.isPendingForInviter(_collab2), isFalse);
      });

      test('current user filtered out when their status is ignored', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {_collab1: CollaboratorStatus.ignored},
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, equals([_collab2]));
      });

      test('current user not filtered out when their status is confirmed', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _collab1,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
      });

      test(
        'current user not filtered out when their status is missing (pending)',
        () {
          const vis = CollaboratorVisibility(
            taggedPubkeys: [_collab1, _collab2],
            statusByPubkey: {},
            currentUserPubkey: _collab1,
            creatorPubkey: _creator,
          );
          expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
        },
      );

      test(
        'another collaborator with ignored status is NOT filtered out '
        '(only current user is)',
        () {
          // `ignored` is local-only; another collaborator's `ignored` status
          // could only come from a different device. The fast-path map is
          // single-device, so this should never happen in practice — but the
          // contract is: only the current user's own ignore filters them out.
          const vis = CollaboratorVisibility(
            taggedPubkeys: [_collab1, _collab2],
            statusByPubkey: {_collab2: CollaboratorStatus.ignored},
            currentUserPubkey: _collab1,
            creatorPubkey: _creator,
          );
          expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
        },
      );
    });

    group('third-party view', () {
      test('isInviterView false', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.pending},
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
        );
        expect(vis.isInviterView, isFalse);
      });

      test('no decoration / no filtering applied', () {
        const vis = CollaboratorVisibility(
          taggedPubkeys: [_collab1, _collab2],
          statusByPubkey: {
            _collab1: CollaboratorStatus.pending,
            _collab2: CollaboratorStatus.confirmed,
          },
          currentUserPubkey: _viewer,
          creatorPubkey: _creator,
        );
        expect(vis.visiblePubkeys, equals([_collab1, _collab2]));
        expect(vis.pendingCount, equals(0));
        expect(vis.isPendingForInviter(_collab1), isFalse);
        expect(vis.isPendingForInviter(_collab2), isFalse);
      });
    });

    group('equality', () {
      test('two equivalent instances compare equal', () {
        const a = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        const b = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {_collab1: CollaboratorStatus.confirmed},
          currentUserPubkey: _creator,
          creatorPubkey: _creator,
        );
        expect(a, equals(b));
      });

      test('fallback and status-aware instances are unequal', () {
        const fallback = CollaboratorVisibility.fallback(
          taggedPubkeys: [_collab1],
        );
        const statusAware = CollaboratorVisibility(
          taggedPubkeys: [_collab1],
          statusByPubkey: {},
          currentUserPubkey: '',
          creatorPubkey: '',
        );
        expect(fallback, isNot(equals(statusAware)));
      });
    });
  });
}
