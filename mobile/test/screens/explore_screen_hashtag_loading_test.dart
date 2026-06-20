// ABOUTME: Tests for hashtag loading and display in ExploreScreen Trending tab
// ABOUTME: Verifies hashtags load quickly from JSON and display immediately after loading

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/top_hashtags_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late String bundledTopHashtagsJson;
  late TopHashtagsService service;

  setUpAll(() {
    bundledTopHashtagsJson = File(
      'assets/top_1000_hashtags.json',
    ).readAsStringSync();
  });

  group('TopHashtagsService Performance Tests', () {
    setUp(() {
      service = TopHashtagsService.forTesting(
        loadAssetString: (_) async => bundledTopHashtagsJson,
      );
    });

    test('Hashtags load quickly from JSON asset (< 200ms)', () async {
      // Start timing hashtag load
      final startTime = DateTime.now();

      // Load hashtags from JSON
      await service.loadTopHashtags();

      final loadDuration = DateTime.now().difference(startTime);

      // CRITICAL: Hashtag loading should be FAST (< 200ms for JSON file read)
      expect(
        loadDuration.inMilliseconds,
        lessThan(200),
        reason: 'Hashtags should load from JSON file in under 200ms',
      );

      // Verify hashtags are loaded in service
      expect(service.isLoaded, isTrue);
      expect(service.topHashtags.length, greaterThan(0));
    });

    test('TopHashtagsService loads hashtags only once (idempotent)', () async {
      // First load
      await service.loadTopHashtags();
      final firstLoadCount = service.topHashtags.length;
      expect(firstLoadCount, greaterThan(0), reason: 'Should load hashtags');

      // Second load (should skip - already loaded)
      await service.loadTopHashtags();
      final secondLoadCount = service.topHashtags.length;

      // Verify service doesn't reload unnecessarily
      expect(secondLoadCount, equals(firstLoadCount));
      expect(service.isLoaded, isTrue);
    });

    test('getTopHashtags returns requested number of hashtags', () async {
      await service.loadTopHashtags();

      // Test various limits
      final top10 = service.getTopHashtags(limit: 10);
      expect(top10.length, equals(10));

      final top50 = service.getTopHashtags();
      expect(top50.length, equals(50));

      final top100 = service.getTopHashtags(limit: 100);
      expect(top100.length, equals(100));
    });

    test(
      'bundled popular hashtags use current API-derived suggestions',
      () async {
        await service.loadTopHashtags();

        final topHashtags = service.getTopHashtags(limit: 5);

        expect(topHashtags, equals(['funny', 'comedy', 'lol', 'viral', 'fyp']));
        expect(topHashtags, isNot(contains('vine')));
      },
    );

    test('getTopHashtags returns fallback defaults before loading', () {
      final hashtags = service.getTopHashtags(limit: 20);

      expect(hashtags, equals(TopHashtagsService.defaultHashtags));
    });

    test('searchHashtags finds exact matches', () async {
      await service.loadTopHashtags();

      // Search for common hashtag (from bundled popular hashtag list)
      final results = service.searchHashtags('funny', limit: 10);

      expect(results, isNotEmpty, reason: 'Should find funny hashtag');
      expect(results.first.toLowerCase(), contains('funny'));
    });

    test('searchHashtags finds prefix matches', () async {
      await service.loadTopHashtags();

      // Search with prefix (from bundled popular hashtag list)
      final results = service.searchHashtags('fun', limit: 10);

      expect(
        results,
        isNotEmpty,
        reason: 'Should find hashtags starting with fun',
      );
    });

    test('searchHashtags is case insensitive', () async {
      await service.loadTopHashtags();

      final lowercase = service.searchHashtags('funny', limit: 10);
      final uppercase = service.searchHashtags('FUNNY', limit: 10);
      final mixedcase = service.searchHashtags('FuNnY', limit: 10);

      // All should return same results
      expect(lowercase, isNotEmpty);
      expect(uppercase, equals(lowercase));
      expect(mixedcase, equals(lowercase));
    });
  });
}
