import 'package:flutter_test/flutter_test.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

void main() {
  group(VideoPoolConfig, () {
    group('constructor', () {
      test('creates with default values', () {
        const config = VideoPoolConfig();

        expect(config.maxPlayers, equals(5));
        expect(config.preloadAhead, equals(2));
        expect(config.preloadBehind, equals(1));
        expect(config.mediaSourceResolver, isNull);
        expect(config.onVideoReady, isNull);
        expect(config.positionCallback, isNull);
        expect(
          config.positionCallbackInterval,
          equals(const Duration(milliseconds: 200)),
        );
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

      test('can be created as const when no hooks are provided', () {
        const config1 = VideoPoolConfig();
        const config2 = VideoPoolConfig();

        expect(identical(config1, config2), isTrue);
      });

      test('accepts custom mediaSourceResolver', () {
        String? resolver(VideoItem video) => '/cached/${video.id}';

        final config = VideoPoolConfig(mediaSourceResolver: resolver);

        expect(config.mediaSourceResolver, equals(resolver));
      });

      test('accepts custom onVideoReady', () {
        void callback(int index, Player player) {}

        final config = VideoPoolConfig(onVideoReady: callback);

        expect(config.onVideoReady, equals(callback));
      });

      test('accepts custom positionCallback', () {
        void callback(int index, Duration position) {}

        final config = VideoPoolConfig(positionCallback: callback);

        expect(config.positionCallback, equals(callback));
      });

      test('accepts custom positionCallbackInterval', () {
        const config = VideoPoolConfig(
          positionCallbackInterval: Duration(seconds: 1),
        );

        expect(
          config.positionCallbackInterval,
          equals(const Duration(seconds: 1)),
        );
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
      test('configs with same default values are equal', () {
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

      test('configs with different mediaSourceResolver are not equal', () {
        String? resolverA(VideoItem video) => '/a/${video.id}';
        String? resolverB(VideoItem video) => '/b/${video.id}';

        final config1 = VideoPoolConfig(mediaSourceResolver: resolverA);
        final config2 = VideoPoolConfig(mediaSourceResolver: resolverB);

        expect(config1, isNot(equals(config2)));
      });

      test('configs with same mediaSourceResolver are equal', () {
        String? resolver(VideoItem video) => '/cached/${video.id}';

        final config1 = VideoPoolConfig(mediaSourceResolver: resolver);
        final config2 = VideoPoolConfig(mediaSourceResolver: resolver);

        expect(config1, equals(config2));
      });

      test('configs with different onVideoReady are not equal', () {
        void callbackA(int index, Player player) {}
        void callbackB(int index, Player player) {}

        final config1 = VideoPoolConfig(onVideoReady: callbackA);
        final config2 = VideoPoolConfig(onVideoReady: callbackB);

        expect(config1, isNot(equals(config2)));
      });

      test('configs with different positionCallback are not equal', () {
        void callbackA(int index, Duration position) {}
        void callbackB(int index, Duration position) {}

        final config1 = VideoPoolConfig(positionCallback: callbackA);
        final config2 = VideoPoolConfig(positionCallback: callbackB);

        expect(config1, isNot(equals(config2)));
      });

      test(
        'configs with different positionCallbackInterval are not equal',
        () {
          const config1 = VideoPoolConfig();
          const config2 = VideoPoolConfig(
            positionCallbackInterval: Duration(seconds: 1),
          );

          expect(config1, isNot(equals(config2)));
        },
      );
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

      test('different hooks produce different hashCode', () {
        String? resolver(VideoItem video) => '/cached/${video.id}';

        const config1 = VideoPoolConfig();
        final config2 = VideoPoolConfig(mediaSourceResolver: resolver);

        expect(config1.hashCode, isNot(equals(config2.hashCode)));
      });
    });

    group('hooks', () {
      test('mediaSourceResolver is invoked with correct video', () {
        const video = VideoItem(id: 'test-id', url: 'https://example.com');
        String? resolver(VideoItem v) => '/cached/${v.id}';

        final config = VideoPoolConfig(mediaSourceResolver: resolver);

        expect(config.mediaSourceResolver!(video), equals('/cached/test-id'));
      });

      test('mediaSourceResolver can return null', () {
        const video = VideoItem(id: 'test-id', url: 'https://example.com');
        String? resolver(VideoItem v) => null;

        final config = VideoPoolConfig(mediaSourceResolver: resolver);

        expect(config.mediaSourceResolver!(video), isNull);
      });

      test('positionCallback is invoked with index and position', () {
        int? capturedIndex;
        Duration? capturedPosition;

        void callback(int index, Duration position) {
          capturedIndex = index;
          capturedPosition = position;
        }

        final config = VideoPoolConfig(positionCallback: callback);
        config.positionCallback!(3, const Duration(seconds: 5));

        expect(capturedIndex, equals(3));
        expect(capturedPosition, equals(const Duration(seconds: 5)));
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
