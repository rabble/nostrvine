// ABOUTME: Tests for TopHashtagsService JSON loading, search, and fallbacks.
// ABOUTME: Uses the forTesting ctor to inject a fake asset loader (no DI statics).

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/top_hashtags_service.dart';

const _fakeJson = '''
{"hashtags":[
  {"rank":1,"hashtag":"funny","count":100,"percentage":10.0},
  {"rank":2,"hashtag":"fun","count":90,"percentage":9.0},
  {"rank":3,"hashtag":"music","count":80,"percentage":8.0}
]}''';

void main() {
  group(TopHashtagsService, () {
    TopHashtagsService build({String json = _fakeJson}) =>
        TopHashtagsService.forTesting(loadAssetString: (_) async => json);

    test('getTopHashtags returns bundled defaults before loading', () {
      final service = build();

      expect(service.isLoaded, isFalse);
      expect(
        service.getTopHashtags(limit: 3),
        equals(TopHashtagsService.defaultHashtags.take(3)),
      );
    });

    test('loadTopHashtags parses the asset and marks loaded', () async {
      final service = build();

      await service.loadTopHashtags();

      expect(service.isLoaded, isTrue);
      expect(service.getTopHashtags(limit: 2), equals(['funny', 'fun']));
    });

    test('searchHashtags ranks exact before prefix matches', () async {
      final service = build();
      await service.loadTopHashtags();

      expect(service.searchHashtags('fun'), equals(['fun', 'funny']));
    });

    test('loadTopHashtags is idempotent', () async {
      var calls = 0;
      final service = TopHashtagsService.forTesting(
        loadAssetString: (_) async {
          calls++;
          return _fakeJson;
        },
      );

      await service.loadTopHashtags();
      await service.loadTopHashtags();

      expect(calls, equals(1));
    });
  });
}
