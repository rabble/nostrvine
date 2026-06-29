// ABOUTME: Tests for StickerRepository — composing the structural manifest with
// ABOUTME: only the active locale's strings (plus the English fallback).

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/repositories/sticker_repository.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._assets);

  final Map<String, String> _assets;

  @override
  Future<ByteData> load(String key) async {
    final value = _assets[key];
    if (value == null) {
      throw FlutterError('Unable to load asset: $key');
    }
    return ByteData.view(Uint8List.fromList(utf8.encode(value)).buffer);
  }
}

void main() {
  const manifestPath = 'assets/stickers/stickers.json';
  const enPath = 'assets/stickers/i18n/en.json';
  const dePath = 'assets/stickers/i18n/de.json';

  const manifest = '''
[
  {"assetPath": "assets/stickers/heart.svg", "tags": ["heart", "love"]},
  {"networkUrl": "https://example.com/star.png", "tags": ["star"]}
]
''';
  const enStrings = '''
{
  "assets/stickers/heart.svg": "Heart",
  "https://example.com/star.png": "Star"
}
''';
  const deStrings = '''
{
  "assets/stickers/heart.svg": "Herz",
  "https://example.com/star.png": "Stern"
}
''';

  StickerRepository buildRepository(Map<String, String> assets) =>
      StickerRepository(assetBundle: _FakeAssetBundle(assets));

  group(StickerRepository, () {
    group('loadStickers', () {
      test('resolves the requested locale and the English fallback', () async {
        final repository = buildRepository({
          manifestPath: manifest,
          enPath: enStrings,
          dePath: deStrings,
        });

        final stickers = await repository.loadStickers('de');

        expect(stickers, hasLength(2));
        expect(
          stickers.first.description,
          const LocalizedText({'en': 'Heart', 'de': 'Herz'}),
        );
        expect(stickers.first.description.resolve('de'), 'Herz');
        expect(stickers.first.description.resolve('fr'), 'Heart');
      });

      test('loads only English when the locale is English', () async {
        final repository = buildRepository({
          manifestPath: manifest,
          enPath: enStrings,
          dePath: deStrings,
        });

        final stickers = await repository.loadStickers('en');

        expect(
          stickers.first.description,
          const LocalizedText({'en': 'Heart'}),
        );
      });

      test('falls back to English when the locale file is missing', () async {
        final repository = buildRepository({
          manifestPath: manifest,
          enPath: enStrings,
        });

        final stickers = await repository.loadStickers('fr');

        expect(
          stickers.first.description,
          const LocalizedText({'en': 'Heart'}),
        );
      });

      test('keys network stickers by their network URL', () async {
        final repository = buildRepository({
          manifestPath: manifest,
          enPath: enStrings,
          dePath: deStrings,
        });

        final stickers = await repository.loadStickers('de');

        expect(stickers[1].networkUrl, 'https://example.com/star.png');
        expect(
          stickers[1].description,
          const LocalizedText({'en': 'Star', 'de': 'Stern'}),
        );
      });

      test('preserves tags and assigns the fallback pack', () async {
        final repository = buildRepository({
          manifestPath: manifest,
          enPath: enStrings,
        });

        final stickers = await repository.loadStickers('en');

        expect(stickers.first.tags, ['heart', 'love']);
        expect(stickers.first.packData, StickerPackData.fallback);
      });

      test('throws when the structural manifest is missing', () {
        final repository = buildRepository({enPath: enStrings});

        expect(repository.loadStickers('en'), throwsA(isA<FlutterError>()));
      });

      test('throws when the manifest JSON is malformed', () {
        final repository = buildRepository({
          manifestPath: 'not valid json {',
          enPath: enStrings,
        });

        expect(
          repository.loadStickers('en'),
          throwsA(isA<FormatException>()),
        );
      });
    });
  });
}
