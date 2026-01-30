import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('StickerData', () {
    const description = 'Happy emoji';
    const networkUrl = 'https://example.com/sticker.png';
    const assetPath = 'assets/stickers/happy.png';
    const tags = ['happy', 'emoji', 'smile'];

    group('constructor', () {
      test('creates instance with networkUrl', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
        );

        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
        expect(stickerData.networkUrl, networkUrl);
        expect(stickerData.assetPath, isNull);
      });

      test('creates instance with assetPath', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          assetPath: assetPath,
        );

        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
        expect(stickerData.networkUrl, isNull);
        expect(stickerData.assetPath, assetPath);
      });

      test('creates instance with both networkUrl and assetPath', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
        );

        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
        expect(stickerData.networkUrl, networkUrl);
        expect(stickerData.assetPath, assetPath);
      });
    });

    group('StickerData.network', () {
      test('creates instance with networkUrl', () {
        const stickerData = StickerData.network(
          networkUrl,
          description: description,
          tags: tags,
        );

        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
        expect(stickerData.networkUrl, networkUrl);
        expect(stickerData.assetPath, isNull);
      });

      test('has same props as StickerData with same networkUrl', () {
        const fromFactory = StickerData.network(
          networkUrl,
          description: description,
          tags: tags,
        );
        const fromConstructor = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
        );

        expect(fromFactory.props, equals(fromConstructor.props));
      });
    });

    group('StickerData.asset', () {
      test('creates instance with assetPath', () {
        const stickerData = StickerData.asset(
          assetPath,
          description: description,
          tags: tags,
        );

        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
        expect(stickerData.networkUrl, isNull);
        expect(stickerData.assetPath, assetPath);
      });

      test('has same props as StickerData with same assetPath', () {
        const fromFactory = StickerData.asset(
          assetPath,
          description: description,
          tags: tags,
        );
        const fromConstructor = StickerData(
          description: description,
          tags: tags,
          assetPath: assetPath,
        );

        expect(fromFactory.props, equals(fromConstructor.props));
      });
    });

    group('copyWith', () {
      const original = StickerData(
        description: description,
        tags: tags,
        networkUrl: networkUrl,
        assetPath: assetPath,
      );

      test('returns same values when no arguments provided', () {
        final copy = original.copyWith();

        expect(copy.description, original.description);
        expect(copy.tags, original.tags);
        expect(copy.networkUrl, original.networkUrl);
        expect(copy.assetPath, original.assetPath);
      });

      test('updates description when provided', () {
        final copy = original.copyWith(description: 'New description');

        expect(copy.description, 'New description');
        expect(copy.tags, original.tags);
        expect(copy.networkUrl, original.networkUrl);
        expect(copy.assetPath, original.assetPath);
      });

      test('updates tags when provided', () {
        final copy = original.copyWith(tags: ['new', 'tags']);

        expect(copy.description, original.description);
        expect(copy.tags, ['new', 'tags']);
        expect(copy.networkUrl, original.networkUrl);
        expect(copy.assetPath, original.assetPath);
      });

      test('updates networkUrl when provided', () {
        final copy = original.copyWith(networkUrl: 'https://new-url.com');

        expect(copy.description, original.description);
        expect(copy.tags, original.tags);
        expect(copy.networkUrl, 'https://new-url.com');
        expect(copy.assetPath, original.assetPath);
      });

      test('updates assetPath when provided', () {
        final copy = original.copyWith(assetPath: 'assets/new.png');

        expect(copy.description, original.description);
        expect(copy.tags, original.tags);
        expect(copy.networkUrl, original.networkUrl);
        expect(copy.assetPath, 'assets/new.png');
      });

      test('updates all fields when provided', () {
        final copy = original.copyWith(
          description: 'Updated',
          tags: ['updated'],
          networkUrl: 'https://updated.com',
          assetPath: 'assets/updated.png',
        );

        expect(copy.description, 'Updated');
        expect(copy.tags, ['updated']);
        expect(copy.networkUrl, 'https://updated.com');
        expect(copy.assetPath, 'assets/updated.png');
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
        );

        expect(stickerData1, equals(stickerData2));
      });

      test('two instances with different description are not equal', () {
        const stickerData1 = StickerData(description: description, tags: tags);
        const stickerData2 = StickerData(description: 'Other', tags: tags);

        expect(stickerData1, isNot(equals(stickerData2)));
      });

      test('two instances with different tags are not equal', () {
        const stickerData1 = StickerData(description: description, tags: tags);
        const stickerData2 = StickerData(
          description: description,
          tags: ['other'],
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });

      test('two instances with different networkUrl are not equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: tags,
          networkUrl: 'https://other.com',
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });

      test('two instances with different assetPath are not equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          assetPath: assetPath,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: tags,
          assetPath: 'assets/other.png',
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });
    });

    group('props', () {
      test('contains all properties', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
        );

        expect(stickerData.props, [networkUrl, assetPath, description, tags]);
      });

      test('contains null values when not provided', () {
        const stickerData = StickerData(description: description, tags: tags);

        expect(stickerData.props, [null, null, description, tags]);
      });
    });

    group('fromJson', () {
      test('creates instance with all fields', () {
        final json = {
          'networkUrl': networkUrl,
          'assetPath': assetPath,
          'description': description,
          'tags': tags,
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.networkUrl, networkUrl);
        expect(stickerData.assetPath, assetPath);
        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
      });

      test('creates instance with only required fields', () {
        final json = {
          'description': description,
          'tags': tags,
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.networkUrl, isNull);
        expect(stickerData.assetPath, isNull);
        expect(stickerData.description, description);
        expect(stickerData.tags, tags);
      });

      test('creates instance with networkUrl only', () {
        final json = {
          'networkUrl': networkUrl,
          'description': description,
          'tags': tags,
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.networkUrl, networkUrl);
        expect(stickerData.assetPath, isNull);
      });

      test('creates instance with assetPath only', () {
        final json = {
          'assetPath': assetPath,
          'description': description,
          'tags': tags,
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.networkUrl, isNull);
        expect(stickerData.assetPath, assetPath);
      });

      test('handles empty tags list', () {
        final json = {
          'description': description,
          'tags': <String>[],
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.tags, isEmpty);
      });
    });

    group('toJson', () {
      test('returns map with all fields', () {
        const stickerData = StickerData(
          networkUrl: networkUrl,
          assetPath: assetPath,
          description: description,
          tags: tags,
        );

        final json = stickerData.toJson();

        expect(json, {
          'networkUrl': networkUrl,
          'assetPath': assetPath,
          'description': description,
          'tags': tags,
        });
      });

      test('omits null networkUrl', () {
        const stickerData = StickerData(
          assetPath: assetPath,
          description: description,
          tags: tags,
        );

        final json = stickerData.toJson();

        expect(json.containsKey('networkUrl'), isFalse);
        expect(json, {
          'assetPath': assetPath,
          'description': description,
          'tags': tags,
        });
      });

      test('omits null assetPath', () {
        const stickerData = StickerData(
          networkUrl: networkUrl,
          description: description,
          tags: tags,
        );

        final json = stickerData.toJson();

        expect(json.containsKey('assetPath'), isFalse);
        expect(json, {
          'networkUrl': networkUrl,
          'description': description,
          'tags': tags,
        });
      });

      test('omits both optional fields when null', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
        );

        final json = stickerData.toJson();

        expect(json.containsKey('networkUrl'), isFalse);
        expect(json.containsKey('assetPath'), isFalse);
        expect(json, {
          'description': description,
          'tags': tags,
        });
      });
    });

    group('fromJson/toJson roundtrip', () {
      test('preserves all fields', () {
        const original = StickerData(
          networkUrl: networkUrl,
          assetPath: assetPath,
          description: description,
          tags: tags,
        );

        final json = original.toJson();
        final restored = StickerData.fromJson(json);

        expect(restored, equals(original));
      });

      test('preserves instance with only required fields', () {
        const original = StickerData(
          description: description,
          tags: tags,
        );

        final json = original.toJson();
        final restored = StickerData.fromJson(json);

        expect(restored, equals(original));
      });
    });
  });
}
