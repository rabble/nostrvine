// ABOUTME: Tests for VideoPoolConfig model
// ABOUTME: Validates default values, custom config, assertions, and equality

import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group('VideoPoolConfig', () {
    group('constructor', () {
      test('creates with default values', () {
        const config = VideoPoolConfig();

        expect(config.maxPlayers, equals(5));
        expect(config.preloadAhead, equals(2));
        expect(config.preloadBehind, equals(1));
      });

      test('accepts custom maxPlayers', () {
        const config = VideoPoolConfig(maxPlayers: 10);

        expect(config.maxPlayers, equals(10));
        expect(config.preloadAhead, equals(2));
        expect(config.preloadBehind, equals(1));
      });

      test('accepts custom preloadAhead', () {
        const config = VideoPoolConfig(preloadAhead: 5);

        expect(config.maxPlayers, equals(5));
        expect(config.preloadAhead, equals(5));
        expect(config.preloadBehind, equals(1));
      });

      test('accepts custom preloadBehind', () {
        const config = VideoPoolConfig(preloadBehind: 3);

        expect(config.maxPlayers, equals(5));
        expect(config.preloadAhead, equals(2));
        expect(config.preloadBehind, equals(3));
      });

      test('accepts all custom values', () {
        const config = VideoPoolConfig(
          maxPlayers: 8,
          preloadAhead: 4,
          preloadBehind: 2,
        );

        expect(config.maxPlayers, equals(8));
        expect(config.preloadAhead, equals(4));
        expect(config.preloadBehind, equals(2));
      });

      test('allows maxPlayers of 1', () {
        const config = VideoPoolConfig(maxPlayers: 1);

        expect(config.maxPlayers, equals(1));
      });

      test('allows preloadAhead of 0', () {
        const config = VideoPoolConfig(preloadAhead: 0);

        expect(config.preloadAhead, equals(0));
      });

      test('allows preloadBehind of 0', () {
        const config = VideoPoolConfig(preloadBehind: 0);

        expect(config.preloadBehind, equals(0));
      });

      test('can be created as const', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig();

        expect(identical(config1, config2), isTrue);
      });
    });

    group('assertions', () {
      test('throws when maxPlayers is 0', () {
        expect(
          () => VideoPoolConfig(maxPlayers: 0),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when maxPlayers is negative', () {
        expect(
          () => VideoPoolConfig(maxPlayers: -1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when preloadAhead is negative', () {
        expect(
          () => VideoPoolConfig(preloadAhead: -1),
          throwsA(isA<AssertionError>()),
        );
      });

      test('throws when preloadBehind is negative', () {
        expect(
          () => VideoPoolConfig(preloadBehind: -1),
          throwsA(isA<AssertionError>()),
        );
      });
    });

    group('equality', () {
      test('configs with same values are equal', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig();

        expect(config1, equals(config2));
      });

      test('configs with different maxPlayers are not equal', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig(maxPlayers: 10);

        expect(config1, isNot(equals(config2)));
      });

      test('configs with different preloadAhead are not equal', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig(preloadAhead: 4);

        expect(config1, isNot(equals(config2)));
      });

      test('configs with different preloadBehind are not equal', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig(preloadBehind: 3);

        expect(config1, isNot(equals(config2)));
      });

      test('identical configs are equal', () {
        const config = VideoPoolConfig();

        expect(config, equals(config));
      });

      test('handles Object comparison', () {
        const config = VideoPoolConfig();
        const Object otherObject = 'not a config';

        expect(config == otherObject, isFalse);
      });
    });

    group('hashCode', () {
      test('same values produce same hashCode', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig();

        expect(config1.hashCode, equals(config2.hashCode));
      });

      test('different values produce different hashCode', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig(maxPlayers: 10);

        expect(config1.hashCode, isNot(equals(config2.hashCode)));
      });

      test('hashCode is consistent', () {
        const config = VideoPoolConfig();

        final hashCode1 = config.hashCode;
        final hashCode2 = config.hashCode;
        final hashCode3 = config.hashCode;

        expect(hashCode1, equals(hashCode2));
        expect(hashCode2, equals(hashCode3));
      });
    });

    group('immutability', () {
      test('is immutable', () {
        const config = VideoPoolConfig();

        expect(config.maxPlayers, equals(5));
        expect(config.preloadAhead, equals(2));
        expect(config.preloadBehind, equals(1));
      });
    });
  });
}
