import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/services/playback_source_registry.dart';

void main() {
  group(PlaybackSourceRegistry, () {
    late PlaybackSourceRegistry registry;

    setUp(() {
      registry = PlaybackSourceRegistry();
    });

    group('hasSources', () {
      test('returns false when nothing is registered', () {
        expect(registry.hasSources(0), isFalse);
      });

      test('returns false when an empty list is registered', () {
        registry.register(0, [], 0);
        expect(registry.hasSources(0), isFalse);
      });

      test('returns true after registering a non-empty list', () {
        registry.register(0, ['a', 'b'], 0);
        expect(registry.hasSources(0), isTrue);
      });
    });

    group('activeSourceFor', () {
      test('returns null when nothing is registered', () {
        expect(registry.activeSourceFor(0), isNull);
      });

      test('returns the source at the registered active index', () {
        registry.register(0, ['a', 'b', 'c'], 1);
        expect(registry.activeSourceFor(0), equals('b'));
      });

      test('returns null when the active index is out of range', () {
        registry.register(0, ['a'], 5);
        expect(registry.activeSourceFor(0), isNull);
      });
    });

    group('attemptFor', () {
      test('returns 0 when nothing is registered', () {
        expect(registry.attemptFor(0), equals(0));
      });

      test('returns the registered active index', () {
        registry.register(0, ['a', 'b'], 1);
        expect(registry.attemptFor(0), equals(1));
      });
    });

    group('advance', () {
      test('returns null when nothing is registered', () {
        expect(registry.advance(0), isNull);
      });

      test('returns null when the source list is empty', () {
        registry.register(0, [], 0);
        expect(registry.advance(0), isNull);
      });

      test('moves to the next source and returns it', () {
        registry.register(0, ['a', 'b', 'c'], 0);

        expect(registry.advance(0), equals('b'));
        expect(registry.attemptFor(0), equals(1));
        expect(registry.activeSourceFor(0), equals('b'));
      });

      test('returns null when the source list is exhausted', () {
        registry.register(0, ['a', 'b'], 1);

        expect(registry.advance(0), isNull);
        expect(registry.attemptFor(0), equals(1));
      });

      test('advances each index independently', () {
        registry
          ..register(0, ['a0', 'b0'], 0)
          ..register(1, ['a1', 'b1'], 0)
          ..advance(0);

        expect(registry.attemptFor(0), equals(1));
        expect(registry.attemptFor(1), equals(0));
      });
    });

    group('remove', () {
      test('forgets sources for the removed index only', () {
        registry
          ..register(0, ['a0'], 0)
          ..register(1, ['a1'], 0)
          ..remove(0);

        expect(registry.hasSources(0), isFalse);
        expect(registry.hasSources(1), isTrue);
      });
    });

    group('registerPrestart', () {
      test('hasSources returns true after prestart registration', () {
        registry.registerPrestart(0, ['a', 'b']);
        expect(registry.hasSources(0), isTrue);
      });

      test('advance returns sources[0] from prestart state', () {
        registry.registerPrestart(0, ['a', 'b']);
        expect(registry.advance(0), equals('a'));
      });

      test('advance returns null when prestart list is empty', () {
        registry.registerPrestart(0, []);
        expect(registry.advance(0), isNull);
      });

      test('activeSourceFor returns null in prestart state (no network '
          'source active yet)', () {
        registry.registerPrestart(0, ['a', 'b']);
        expect(registry.activeSourceFor(0), isNull);
      });
    });

    group('canAdvance', () {
      test('returns false when nothing is registered', () {
        expect(registry.canAdvance(0), isFalse);
      });

      test('returns false when an empty list is registered', () {
        registry.register(0, [], 0);
        expect(registry.canAdvance(0), isFalse);
      });

      test('returns true when there is a next source', () {
        registry.register(0, ['a', 'b'], 0);
        expect(registry.canAdvance(0), isTrue);
      });

      test('returns false when the source list is exhausted', () {
        registry.register(0, ['a', 'b'], 1);
        expect(registry.canAdvance(0), isFalse);
      });

      test('returns true from prestart state with non-empty list', () {
        registry.registerPrestart(0, ['a', 'b']);
        expect(registry.canAdvance(0), isTrue);
      });
    });

    group('clear', () {
      test('forgets every entry', () {
        registry
          ..register(0, ['a'], 0)
          ..register(1, ['b'], 0)
          ..clear();

        expect(registry.hasSources(0), isFalse);
        expect(registry.hasSources(1), isFalse);
      });
    });
  });
}
