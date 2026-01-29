import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('PoolStatus', () {
    group('Constructor', () {
      test('creates with all required fields', () {
        const status = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.availablePlayers, 2);
        expect(status.inUsePlayers, 3);
        expect(status.totalPlayers, 5);
        expect(status.maxPoolSize, 3);
        expect(status.maxTotalPlayers, 7);
        expect(status.activeLeaseCount, 3);
        expect(status.registeredFeedCount, 1);
        expect(status.isMemoryConstrained, false);
      });

      test('all fields are accessible', () {
        const status = PoolStatus(
          availablePlayers: 1,
          inUsePlayers: 4,
          totalPlayers: 5,
          maxPoolSize: 2,
          maxTotalPlayers: 6,
          activeLeaseCount: 4,
          registeredFeedCount: 2,
          isMemoryConstrained: true,
        );

        expect(status.availablePlayers, isA<int>());
        expect(status.inUsePlayers, isA<int>());
        expect(status.totalPlayers, isA<int>());
        expect(status.maxPoolSize, isA<int>());
        expect(status.maxTotalPlayers, isA<int>());
        expect(status.activeLeaseCount, isA<int>());
        expect(status.registeredFeedCount, isA<int>());
        expect(status.isMemoryConstrained, isA<bool>());
      });
    });

    group('utilizationPercent', () {
      test('returns 0.0 when maxTotalPlayers is 0', () {
        const status = PoolStatus(
          availablePlayers: 0,
          inUsePlayers: 0,
          totalPlayers: 0,
          maxPoolSize: 0,
          maxTotalPlayers: 0,
          activeLeaseCount: 0,
          registeredFeedCount: 0,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 0.0);
      });

      test('returns correct percentage for partial utilization', () {
        const status = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 10,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 0.3);
      });

      test('returns 0.5 when half utilized', () {
        const status = PoolStatus(
          availablePlayers: 1,
          inUsePlayers: 5,
          totalPlayers: 6,
          maxPoolSize: 3,
          maxTotalPlayers: 10,
          activeLeaseCount: 5,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 0.5);
      });

      test('returns 1.0 when fully utilized', () {
        const status = PoolStatus(
          availablePlayers: 0,
          inUsePlayers: 7,
          totalPlayers: 7,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 7,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 1.0);
      });
    });

    group('isNearCapacity', () {
      test('returns false when utilization is 80% or less', () {
        const status = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 8,
          totalPlayers: 10,
          maxPoolSize: 3,
          maxTotalPlayers: 10,
          activeLeaseCount: 8,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 0.8);
        expect(status.isNearCapacity, false);
      });

      test('returns true when utilization exceeds 80%', () {
        const status = PoolStatus(
          availablePlayers: 1,
          inUsePlayers: 9,
          totalPlayers: 10,
          maxPoolSize: 3,
          maxTotalPlayers: 10,
          activeLeaseCount: 9,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 0.9);
        expect(status.isNearCapacity, true);
      });

      test('returns false when utilization is well below 80%', () {
        const status = PoolStatus(
          availablePlayers: 5,
          inUsePlayers: 2,
          totalPlayers: 7,
          maxPoolSize: 5,
          maxTotalPlayers: 10,
          activeLeaseCount: 2,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.utilizationPercent, 0.2);
        expect(status.isNearCapacity, false);
      });
    });

    group('isAtCapacity', () {
      test('returns false when inUsePlayers is less than maxTotalPlayers', () {
        const status = PoolStatus(
          availablePlayers: 1,
          inUsePlayers: 6,
          totalPlayers: 7,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 6,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.isAtCapacity, false);
      });

      test('returns true when inUsePlayers equals maxTotalPlayers', () {
        const status = PoolStatus(
          availablePlayers: 0,
          inUsePlayers: 7,
          totalPlayers: 7,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 7,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.isAtCapacity, true);
      });

      test('returns true when inUsePlayers exceeds maxTotalPlayers', () {
        const status = PoolStatus(
          availablePlayers: 0,
          inUsePlayers: 8,
          totalPlayers: 8,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 8,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status.isAtCapacity, true);
      });
    });

    group('equality', () {
      test('equals identical instance', () {
        const status = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status, equals(status));
      });

      test('equals equivalent instance', () {
        const status1 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        const status2 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status1, equals(status2));
      });

      test('not equals when availablePlayers differs', () {
        const status1 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        const status2 = PoolStatus(
          availablePlayers: 1,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status1, isNot(equals(status2)));
      });

      test('not equals when isMemoryConstrained differs', () {
        const status1 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        const status2 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: true,
        );

        expect(status1, isNot(equals(status2)));
      });

      test('hashCode matches for equal instances', () {
        const status1 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        const status2 = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        expect(status1.hashCode, equals(status2.hashCode));
      });
    });

    group('toString', () {
      test('includes all relevant fields', () {
        const status = PoolStatus(
          availablePlayers: 2,
          inUsePlayers: 3,
          totalPlayers: 5,
          maxPoolSize: 3,
          maxTotalPlayers: 7,
          activeLeaseCount: 3,
          registeredFeedCount: 1,
          isMemoryConstrained: false,
        );

        final string = status.toString();

        expect(string, contains('available: 2'));
        expect(string, contains('inUse: 3'));
        expect(string, contains('total: 5'));
        expect(string, contains('leases: 3'));
        expect(string, contains('feeds: 1'));
        expect(string, contains('memoryConstrained: false'));
      });
    });
  });
}
