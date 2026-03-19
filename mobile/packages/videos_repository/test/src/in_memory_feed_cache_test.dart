import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group(InMemoryFeedCache, () {
    late InMemoryFeedCache cache;

    setUp(() {
      cache = InMemoryFeedCache();
    });

    HomeFeedResult createResult({int videoCount = 1}) {
      return HomeFeedResult(
        videos: List.generate(
          videoCount,
          (i) => VideoEvent(
            id: 'id_$i',
            pubkey: 'pubkey_$i',
            createdAt: 1000 + i,
            content: '',
            timestamp: DateTime.fromMillisecondsSinceEpoch(0),
          ),
        ),
      );
    }

    group('get', () {
      test('returns null when cache is empty', () {
        expect(cache.get('home'), isNull);
      });

      test('returns null for unknown key', () {
        cache.set('home', createResult());
        expect(cache.get('latest'), isNull);
      });
    });

    group('set', () {
      test('stores and retrieves result by key', () {
        final result = createResult(videoCount: 3);
        cache.set('home', result);

        expect(cache.get('home'), equals(result));
      });

      test('replaces previous entry for same key', () {
        final first = createResult();
        final second = createResult(videoCount: 2);

        cache
          ..set('home', first)
          ..set('home', second);

        expect(cache.get('home'), equals(second));
      });
    });

    group('remove', () {
      test('removes entry for given key', () {
        cache
          ..set('home', createResult())
          ..remove('home');

        expect(cache.get('home'), isNull);
      });

      test('does not affect other keys', () {
        final homeResult = createResult();
        final latestResult = createResult(videoCount: 2);

        cache
          ..set('home', homeResult)
          ..set('latest', latestResult)
          ..remove('home');

        expect(cache.get('home'), isNull);
        expect(cache.get('latest'), equals(latestResult));
      });
    });

    group('clear', () {
      test('removes all entries', () {
        cache
          ..set('home', createResult())
          ..set('latest', createResult())
          ..set('popular', createResult())
          ..clear();

        expect(cache.get('home'), isNull);
        expect(cache.get('latest'), isNull);
        expect(cache.get('popular'), isNull);
      });
    });
  });
}
