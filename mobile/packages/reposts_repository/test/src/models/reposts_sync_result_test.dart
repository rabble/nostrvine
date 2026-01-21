// Not needed rules for test code.
// ignore_for_file: prefer_const_literals_to_create_immutables
// ignore_for_file: prefer_const_constructors

import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

void main() {
  group('RepostsSyncResult', () {
    test('creates instance with required fields', () {
      final result = RepostsSyncResult(
        orderedAddressableIds: ['id1', 'id2'],
        addressableIdToRepostId: {'id1': 'event1', 'id2': 'event2'},
      );

      expect(result.orderedAddressableIds, equals(['id1', 'id2']));
      expect(result.addressableIdToRepostId['id1'], equals('event1'));
      expect(result.count, equals(2));
      expect(result.isEmpty, isFalse);
    });

    test('empty constructor creates empty result', () {
      const result = RepostsSyncResult.empty();

      expect(result.orderedAddressableIds, isEmpty);
      expect(result.addressableIdToRepostId, isEmpty);
      expect(result.count, equals(0));
      expect(result.isEmpty, isTrue);
    });

    test('equality works correctly', () {
      final result1 = RepostsSyncResult(
        orderedAddressableIds: ['id1', 'id2'],
        addressableIdToRepostId: {'id1': 'event1', 'id2': 'event2'},
      );
      final result2 = RepostsSyncResult(
        orderedAddressableIds: ['id1', 'id2'],
        addressableIdToRepostId: {'id1': 'event1', 'id2': 'event2'},
      );
      final result3 = RepostsSyncResult(
        orderedAddressableIds: ['id1'],
        addressableIdToRepostId: {'id1': 'event1'},
      );

      expect(result1, equals(result2));
      expect(result1, isNot(equals(result3)));
    });
  });
}
