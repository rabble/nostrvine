import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('PoolConstants', () {
    test('maxConcurrentInitializations has expected value', () {
      expect(PoolConstants.maxConcurrentInitializations, 4);
    });

    test('distanceCancellationThreshold has expected value', () {
      expect(PoolConstants.distanceCancellationThreshold, 5);
    });
  });

  group('MemoryTierConfig', () {
    group('iOS thresholds', () {
      test('iPhoneHighMemoryGeneration has expected value', () {
        expect(MemoryTierConfig.iPhoneHighMemoryGeneration, 14);
      });

      test('iPhoneMediumMemoryGeneration has expected value', () {
        expect(MemoryTierConfig.iPhoneMediumMemoryGeneration, 11);
      });
    });

    group('Android thresholds', () {
      test('androidHighMemorySdk has expected value', () {
        expect(MemoryTierConfig.androidHighMemorySdk, 29);
      });

      test('androidMediumMemorySdk has expected value', () {
        expect(MemoryTierConfig.androidMediumMemorySdk, 26);
      });
    });

    group('Pool size configuration', () {
      test('lowMemoryPoolSize has expected value', () {
        expect(MemoryTierConfig.lowMemoryPoolSize, 2);
      });

      test('mediumMemoryPoolSize has expected value', () {
        expect(MemoryTierConfig.mediumMemoryPoolSize, 3);
      });

      test('highMemoryPoolSize has expected value', () {
        expect(MemoryTierConfig.highMemoryPoolSize, 4);
      });
    });
  });
}
