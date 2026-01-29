import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoPoolConfig', () {
    group('Constructor', () {
      test('creates with default values', () {
        const config = VideoPoolConfig();

        expect(config.preloadAhead, 2);
        expect(config.preloadBehind, 1);
        expect(config.maxActivePlayers, 5);
        expect(config.poolSize, 3);
        expect(config.preloadDebounceDelay, const Duration(milliseconds: 150));
        expect(config.maxRetryAttempts, 3);
        expect(config.initialRetryDelay, const Duration(milliseconds: 500));
        expect(config.maxRetryDelay, const Duration(seconds: 8));
        expect(config.retryBackoffMultiplier, 2.0);
        expect(config.enableAutoRetry, true);
      });

      test('creates with custom values', () {
        const config = VideoPoolConfig(
          preloadAhead: 3,
          preloadBehind: 2,
          maxActivePlayers: 10,
          poolSize: 5,
          preloadDebounceDelay: Duration(milliseconds: 200),
          maxRetryAttempts: 5,
          initialRetryDelay: Duration(seconds: 1),
          maxRetryDelay: Duration(seconds: 30),
          retryBackoffMultiplier: 3.0,
          enableAutoRetry: false,
        );

        expect(config.preloadAhead, 3);
        expect(config.preloadBehind, 2);
        expect(config.maxActivePlayers, 10);
        expect(config.poolSize, 5);
        expect(config.preloadDebounceDelay, const Duration(milliseconds: 200));
        expect(config.maxRetryAttempts, 5);
        expect(config.initialRetryDelay, const Duration(seconds: 1));
        expect(config.maxRetryDelay, const Duration(seconds: 30));
        expect(config.retryBackoffMultiplier, 3.0);
        expect(config.enableAutoRetry, false);
      });
    });

    group('forTier factory', () {
      test('creates low tier config with correct values', () {
        final config = VideoPoolConfig.forTier(MemoryTier.low);

        expect(config.poolSize, MemoryTierConfig.lowMemoryPoolSize);
        expect(config.preloadAhead, MemoryTierConfig.lowMemoryPreloadAhead);
        expect(
          config.maxActivePlayers,
          MemoryTierConfig.lowMemoryMaxActivePlayers,
        );
      });

      test('creates medium tier config with default values', () {
        final config = VideoPoolConfig.forTier(MemoryTier.medium);

        // Medium tier uses default VideoPoolConfig values
        expect(config.poolSize, 3);
        expect(config.preloadAhead, 2);
        expect(config.preloadBehind, 1);
        expect(config.maxActivePlayers, 5);
      });

      test('creates high tier config with correct values', () {
        final config = VideoPoolConfig.forTier(MemoryTier.high);

        expect(config.poolSize, MemoryTierConfig.highMemoryPoolSize);
        expect(config.preloadAhead, MemoryTierConfig.highMemoryPreloadAhead);
        expect(config.preloadBehind, MemoryTierConfig.highMemoryPreloadBehind);
        expect(
          config.maxActivePlayers,
          MemoryTierConfig.highMemoryMaxActivePlayers,
        );
      });
    });

    group('copyWith', () {
      test('copies with no changes', () {
        const original = VideoPoolConfig(
          preloadAhead: 3,
          preloadBehind: 2,
          maxActivePlayers: 7,
          poolSize: 4,
        );

        final copy = original.copyWith();

        expect(copy.preloadAhead, original.preloadAhead);
        expect(copy.preloadBehind, original.preloadBehind);
        expect(copy.maxActivePlayers, original.maxActivePlayers);
        expect(copy.poolSize, original.poolSize);
        expect(copy, equals(original));
      });

      test('copies with single field changed', () {
        const original = VideoPoolConfig();

        final copy = original.copyWith(preloadAhead: 5);

        expect(copy.preloadAhead, 5);
        expect(copy.preloadBehind, original.preloadBehind);
        expect(copy.maxActivePlayers, original.maxActivePlayers);
        expect(copy.poolSize, original.poolSize);
      });

      test('copies with multiple fields changed', () {
        const original = VideoPoolConfig();

        final copy = original.copyWith(
          preloadAhead: 4,
          preloadBehind: 3,
          maxActivePlayers: 10,
          poolSize: 6,
        );

        expect(copy.preloadAhead, 4);
        expect(copy.preloadBehind, 3);
        expect(copy.maxActivePlayers, 10);
        expect(copy.poolSize, 6);
      });

      test('preserves unchanged fields', () {
        const original = VideoPoolConfig(
          preloadAhead: 3,
          preloadBehind: 2,
          maxActivePlayers: 8,
          poolSize: 4,
          maxRetryAttempts: 5,
          enableAutoRetry: false,
        );

        final copy = original.copyWith(preloadAhead: 1);

        expect(copy.preloadBehind, original.preloadBehind);
        expect(copy.maxActivePlayers, original.maxActivePlayers);
        expect(copy.poolSize, original.poolSize);
        expect(copy.maxRetryAttempts, original.maxRetryAttempts);
        expect(copy.enableAutoRetry, original.enableAutoRetry);
      });

      test('copies retry configuration fields', () {
        const original = VideoPoolConfig();

        final copy = original.copyWith(
          maxRetryAttempts: 10,
          initialRetryDelay: const Duration(seconds: 2),
          maxRetryDelay: const Duration(minutes: 1),
          retryBackoffMultiplier: 1.5,
          enableAutoRetry: false,
        );

        expect(copy.maxRetryAttempts, 10);
        expect(copy.initialRetryDelay, const Duration(seconds: 2));
        expect(copy.maxRetryDelay, const Duration(minutes: 1));
        expect(copy.retryBackoffMultiplier, 1.5);
        expect(copy.enableAutoRetry, false);
      });
    });

    group('equality', () {
      test('equals identical instance', () {
        const config = VideoPoolConfig();

        expect(config, equals(config));
      });

      test('equals equivalent instance', () {
        const config1 = VideoPoolConfig(preloadAhead: 3, poolSize: 3);
        const config2 = VideoPoolConfig(preloadAhead: 3, poolSize: 3);

        expect(config1, equals(config2));
      });

      test('not equals when preloadAhead differs', () {
        const config1 = VideoPoolConfig(preloadAhead: 2);
        const config2 = VideoPoolConfig(preloadAhead: 3);

        expect(config1, isNot(equals(config2)));
      });

      test('not equals when enableAutoRetry differs', () {
        const config1 = VideoPoolConfig(enableAutoRetry: true);
        const config2 = VideoPoolConfig(enableAutoRetry: false);

        expect(config1, isNot(equals(config2)));
      });

      test('hashCode consistent with equality', () {
        const config1 = VideoPoolConfig(preloadAhead: 3, poolSize: 3);
        const config2 = VideoPoolConfig(preloadAhead: 3, poolSize: 3);

        expect(config1.hashCode, equals(config2.hashCode));
      });
    });
  });

  group('MemoryTierConfig constants', () {
    test('iOS thresholds are defined', () {
      expect(MemoryTierConfig.iPhoneHighMemoryGeneration, 14);
      expect(MemoryTierConfig.iPhoneMediumMemoryGeneration, 11);
    });

    test('Android thresholds are defined', () {
      expect(MemoryTierConfig.androidHighMemorySdk, 29);
      expect(MemoryTierConfig.androidMediumMemorySdk, 26);
    });

    test('pool sizes increase by tier', () {
      expect(
        MemoryTierConfig.lowMemoryPoolSize,
        lessThan(MemoryTierConfig.mediumMemoryPoolSize),
      );
      expect(
        MemoryTierConfig.mediumMemoryPoolSize,
        lessThan(MemoryTierConfig.highMemoryPoolSize),
      );
    });

    test('preload ahead increases by tier', () {
      expect(
        MemoryTierConfig.lowMemoryPreloadAhead,
        lessThan(MemoryTierConfig.mediumMemoryPreloadAhead),
      );
      expect(
        MemoryTierConfig.mediumMemoryPreloadAhead,
        lessThan(MemoryTierConfig.highMemoryPreloadAhead),
      );
    });

    test('max active players increases by tier', () {
      expect(
        MemoryTierConfig.lowMemoryMaxActivePlayers,
        lessThan(MemoryTierConfig.mediumMemoryMaxActivePlayers),
      );
      expect(
        MemoryTierConfig.mediumMemoryMaxActivePlayers,
        lessThan(MemoryTierConfig.highMemoryMaxActivePlayers),
      );
    });
  });
}
