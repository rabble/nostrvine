// ABOUTME: Tests legacy and current following-list cache record decoding.
// ABOUTME: Pins the shared persistence contract used by app bootstrap code.

import 'package:follow_repository/follow_repository.dart';
import 'package:test/test.dart';

void main() {
  group('FollowingCacheRecord', () {
    test('reads the legacy bare-array format', () {
      final record = FollowingCacheRecord.decode('["alice","bob"]');

      expect(record.pubkeys, ['alice', 'bob']);
      expect(record.createdAt, isNull);
      expect(record.eventId, isNull);
      expect(record.needsMigration, isTrue);
    });

    test('round-trips the versioned format', () {
      final encoded = FollowingCacheRecord(
        pubkeys: const ['alice', 'bob'],
        createdAt: 1234,
        eventId: 'event-id',
      ).encode();

      final record = FollowingCacheRecord.decode(encoded);
      expect(record.pubkeys, ['alice', 'bob']);
      expect(record.createdAt, 1234);
      expect(record.eventId, 'event-id');
      expect(record.needsMigration, isFalse);
    });

    test('rejects an object without pubkeys', () {
      expect(
        () => FollowingCacheRecord.decode('{"v":2}'),
        throwsFormatException,
      );
    });
  });
}
