import 'package:models/models.dart';
import 'package:test/test.dart';

// 64-char hex pubkeys for tests.
const _pubkeyAlice =
    'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
const _pubkeyBob =
    '1122334411223344112233441122334411223344112233441122334411223344';

void main() {
  group('ActorInfo', () {
    test('equality works', () {
      const actor1 = ActorInfo(
        pubkey: _pubkeyAlice,
        displayName: 'alice',
        pictureUrl: 'https://example.com/avatar.jpg',
      );
      const actor2 = ActorInfo(
        pubkey: _pubkeyAlice,
        displayName: 'alice',
        pictureUrl: 'https://example.com/avatar.jpg',
      );

      expect(actor1, equals(actor2));
    });

    test('inequality when pubkey differs', () {
      const actor1 = ActorInfo(
        pubkey: _pubkeyAlice,
        displayName: 'alice',
      );
      const actor2 = ActorInfo(
        pubkey: _pubkeyBob,
        displayName: 'alice',
      );

      expect(actor1, isNot(equals(actor2)));
    });

    test('handles null pictureUrl', () {
      const actor = ActorInfo(
        pubkey: _pubkeyAlice,
        displayName: 'alice',
      );

      expect(actor.pictureUrl, isNull);
    });
  });
}
