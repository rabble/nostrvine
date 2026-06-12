// ABOUTME: Tests for the deterministic seeded windowed jitter used to
// ABOUTME: add per-session freshness to For You ordering (#5027).

import 'package:flutter_test/flutter_test.dart';
import 'package:videos_repository/videos_repository.dart';

void main() {
  group('applyRecommendationSessionJitter', () {
    List<String> items(int count) =>
        List.generate(count, (index) => 'video-$index');

    test('is deterministic: same seed produces the same order', () {
      final input = items(23);

      final first = applyRecommendationSessionJitter(input, 'seed-a');
      final second = applyRecommendationSessionJitter(input, 'seed-a');

      expect(first, equals(second));
    });

    test('different seeds produce different orders', () {
      // Fixed seeds chosen so the orderings differ — no randomness in
      // the assertion itself (both calls are deterministic).
      final input = items(25);

      final orderA = applyRecommendationSessionJitter(input, 'seed-a');
      final orderB = applyRecommendationSessionJitter(input, 'seed-b');

      expect(orderA, isNot(equals(orderB)));
    });

    test('keeps every item within its original rank window', () {
      const windowSize = 4;
      final input = items(23);

      final jittered = applyRecommendationSessionJitter(
        input,
        'seed-a',
        windowSize: windowSize,
      );

      expect(jittered, hasLength(input.length));
      for (var start = 0; start < input.length; start += windowSize) {
        final end = start + windowSize > input.length
            ? input.length
            : start + windowSize;
        expect(
          jittered.sublist(start, end),
          unorderedEquals(input.sublist(start, end)),
          reason: 'window [$start, $end) must contain its original items',
        );
      }
    });

    test('a top-window item stays in the top window', () {
      final input = items(50);

      final jittered = applyRecommendationSessionJitter(input, 'seed-a');

      expect(
        jittered.take(5),
        unorderedEquals(input.take(5)),
        reason: 'a top-5 video must stay in the top 5',
      );
    });

    test(
      'prefix stability: longer list reproduces the shorter ordering for '
      'shared complete windows',
      () {
        final shorter = items(50);
        final longer = items(80);

        final jitteredShorter = applyRecommendationSessionJitter(
          shorter,
          'seed-a',
        );
        final jitteredLonger = applyRecommendationSessionJitter(
          longer,
          'seed-a',
        );

        expect(
          jitteredLonger.sublist(0, shorter.length),
          equals(jitteredShorter),
          reason:
              'limit-growth loadMore must keep the already-displayed '
              'prefix in the same order',
        );
      },
    );

    test('returns an empty list for empty input', () {
      expect(
        applyRecommendationSessionJitter(<String>[], 'seed-a'),
        isEmpty,
      );
    });

    test('handles a list shorter than the window', () {
      final input = items(3);

      final jittered = applyRecommendationSessionJitter(input, 'seed-a');

      expect(jittered, unorderedEquals(input));
    });

    test('returns a single-item list unchanged', () {
      expect(
        applyRecommendationSessionJitter(['only'], 'seed-a'),
        equals(['only']),
      );
    });

    test('does not mutate the input list', () {
      final input = items(12);
      final snapshot = List<String>.of(input);

      applyRecommendationSessionJitter(input, 'seed-a');

      expect(input, equals(snapshot));
    });

    test('windowSize of 1 is the identity ordering', () {
      final input = items(10);

      expect(
        applyRecommendationSessionJitter(input, 'seed-a', windowSize: 1),
        equals(input),
      );
    });
  });

  group('generateRecommendationSessionSeed', () {
    test('returns a non-empty seed', () {
      expect(generateRecommendationSessionSeed(), isNotEmpty);
    });
  });
}
