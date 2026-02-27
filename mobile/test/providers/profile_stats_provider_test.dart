import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/profile_stats_provider.dart';

const _testPubkey =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

void main() {
  group('ProfileStatsProvider', () {
    group('Utility Methods', () {
      test('should format counts correctly', () {
        expect(formatProfileStatsCount(0), '0');
        expect(formatProfileStatsCount(999), '999');
        expect(formatProfileStatsCount(1000), '1k');
        expect(formatProfileStatsCount(1500), '1.5k');
        expect(formatProfileStatsCount(1000000), '1M');
        expect(formatProfileStatsCount(2500000), '2.5M');
        expect(formatProfileStatsCount(1000000000), '1B');
        expect(formatProfileStatsCount(3200000000), '3.2B');
      });
    });

    group('ProfileStats Model', () {
      test('should create ProfileStats correctly', () {
        final stats = ProfileStats(
          pubkey: _testPubkey,
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        expect(stats.videoCount, 25);
        expect(stats.totalLikes, 500);
        expect(stats.followers, 100);
        expect(stats.following, 50);
        expect(stats.totalViews, 1000);
      });

      test('should copy ProfileStats with changes', () {
        final original = ProfileStats(
          pubkey: _testPubkey,
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        final updated = original.copyWith(videoCount: 30, totalLikes: 600);

        expect(updated.videoCount, 30);
        expect(updated.totalLikes, 600);
        expect(updated.followers, 100); // Unchanged
        expect(updated.following, 50); // Unchanged
        expect(updated.totalViews, 1000); // Unchanged
      });

      test('should have meaningful toString', () {
        final stats = ProfileStats(
          pubkey: _testPubkey,
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        final string = stats.toString();
        expect(string, contains('25'));
        expect(string, contains('500'));
        expect(string, contains('100'));
        expect(string, contains('50'));
        expect(string, contains('1000'));
      });
    });
  });
}
