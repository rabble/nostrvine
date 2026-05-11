// ABOUTME: Tests for CollaboratorStatus enum and VideoCollaboratorStatus.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group(VideoCollaboratorStatus, () {
    const address = '34236:abc:vine-1';

    test('default statusByPubkey is empty', () {
      const status = VideoCollaboratorStatus(videoAddress: address);
      expect(status.statusByPubkey, isEmpty);
    });

    test('statusFor returns pending for absent pubkeys', () {
      const status = VideoCollaboratorStatus(videoAddress: address);
      expect(status.statusFor('missing'), equals(CollaboratorStatus.pending));
    });

    test('statusFor returns mapped value for present pubkeys', () {
      const status = VideoCollaboratorStatus(
        videoAddress: address,
        statusByPubkey: {
          'a': CollaboratorStatus.confirmed,
          'b': CollaboratorStatus.ignored,
        },
      );
      expect(status.statusFor('a'), equals(CollaboratorStatus.confirmed));
      expect(status.statusFor('b'), equals(CollaboratorStatus.ignored));
      expect(status.statusFor('c'), equals(CollaboratorStatus.pending));
    });

    test('copyWith replaces statusByPubkey while preserving address', () {
      const original = VideoCollaboratorStatus(
        videoAddress: address,
        statusByPubkey: {'a': CollaboratorStatus.pending},
      );
      final updated = original.copyWith(
        statusByPubkey: const {'a': CollaboratorStatus.confirmed},
      );
      expect(updated.videoAddress, equals(address));
      expect(
        updated.statusFor('a'),
        equals(CollaboratorStatus.confirmed),
      );
    });

    test('equality is structural on address and map content', () {
      const a = VideoCollaboratorStatus(
        videoAddress: address,
        statusByPubkey: {'p1': CollaboratorStatus.confirmed},
      );
      const b = VideoCollaboratorStatus(
        videoAddress: address,
        statusByPubkey: {'p1': CollaboratorStatus.confirmed},
      );
      const c = VideoCollaboratorStatus(
        videoAddress: address,
        statusByPubkey: {'p1': CollaboratorStatus.pending},
      );
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
