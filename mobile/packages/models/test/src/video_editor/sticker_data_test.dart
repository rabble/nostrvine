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
          packData: StickerPackData.fallback,
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
          packData: StickerPackData.fallback,
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
          packData: StickerPackData.fallback,
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
          packData: StickerPackData.fallback,
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
          packData: StickerPackData.fallback,
        );
        const fromConstructor = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          packData: StickerPackData.fallback,
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
          packData: StickerPackData.fallback,
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
          packData: StickerPackData.fallback,
        );
        const fromConstructor = StickerData(
          description: description,
          tags: tags,
          assetPath: assetPath,
          packData: StickerPackData.fallback,
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
        packData: StickerPackData.fallback,
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

      test('updates packData when provided', () {
        const newPackData = StickerPackData(
          packId: 'new',
          packName: 'New Pack',
        );
        final copy = original.copyWith(packData: newPackData);

        expect(copy.packData, equals(newPackData));
        expect(copy.description, original.description);
      });

      test('updates all fields when provided', () {
        final copy = original.copyWith(
          description: 'Updated',
          tags: ['updated'],
          networkUrl: 'https://updated.com',
          assetPath: 'assets/updated.png',
          packData: const StickerPackData(packId: 'x', packName: 'X'),
        );

        expect(copy.description, 'Updated');
        expect(copy.tags, ['updated']);
        expect(copy.networkUrl, 'https://updated.com');
        expect(copy.assetPath, 'assets/updated.png');
        expect(
          copy.packData,
          const StickerPackData(packId: 'x', packName: 'X'),
        );
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
          packData: StickerPackData.fallback,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
          packData: StickerPackData.fallback,
        );

        expect(stickerData1, equals(stickerData2));
      });

      test('two instances with different description are not equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );
        const stickerData2 = StickerData(
          description: 'Other',
          tags: tags,
          packData: StickerPackData.fallback,
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });

      test('two instances with different tags are not equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: ['other'],
          packData: StickerPackData.fallback,
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });

      test('two instances with different networkUrl are not equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          packData: StickerPackData.fallback,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: tags,
          networkUrl: 'https://other.com',
          packData: StickerPackData.fallback,
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });

      test('two instances with different assetPath are not equal', () {
        const stickerData1 = StickerData(
          description: description,
          tags: tags,
          assetPath: assetPath,
          packData: StickerPackData.fallback,
        );
        const stickerData2 = StickerData(
          description: description,
          tags: tags,
          assetPath: 'assets/other.png',
          packData: StickerPackData.fallback,
        );

        expect(stickerData1, isNot(equals(stickerData2)));
      });
    });

    group('props', () {
      test('contains all properties when all fields are set', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          networkUrl: networkUrl,
          assetPath: assetPath,
          packData: StickerPackData.fallback,
        );

        expect(
          stickerData.props,
          [networkUrl, assetPath, description, tags, StickerPackData.fallback],
        );
      });

      test('excludes null optional fields from props', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );

        // ?networkUrl and ?assetPath omit null values from the list
        expect(
          stickerData.props,
          [description, tags, StickerPackData.fallback],
        );
      });
    });

    group('layerName', () {
      test('returns description only when packName is empty', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData(packId: 'id', packName: ''),
        );

        expect(stickerData.layerName, equals(description));
      });

      test('returns description with packName when packName is not empty', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData(packId: 'id', packName: 'My Pack'),
        );

        expect(stickerData.layerName, equals('$description ∙ My Pack'));
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

      test('deserializes packData when present', () {
        final json = {
          'description': description,
          'tags': tags,
          'packData': {'packId': 'pack1', 'packName': 'My Pack'},
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.packData.packId, 'pack1');
        expect(stickerData.packData.packName, 'My Pack');
      });

      test('falls back to empty StickerPackData when packData is absent', () {
        final json = {
          'description': description,
          'tags': tags,
        };

        final stickerData = StickerData.fromJson(json);

        expect(stickerData.packData.packId, '');
        expect(stickerData.packData.packName, '');
      });
    });

    group('toJson', () {
      test('returns map with all fields', () {
        const stickerData = StickerData(
          networkUrl: networkUrl,
          assetPath: assetPath,
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );

        final json = stickerData.toJson();

        expect(json, {
          'networkUrl': networkUrl,
          'assetPath': assetPath,
          'description': description,
          'tags': tags,
          'packData': StickerPackData.fallback.toJson(),
        });
      });

      test('omits null networkUrl', () {
        const stickerData = StickerData(
          assetPath: assetPath,
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );

        final json = stickerData.toJson();

        expect(json.containsKey('networkUrl'), isFalse);
        expect(json, {
          'assetPath': assetPath,
          'description': description,
          'tags': tags,
          'packData': StickerPackData.fallback.toJson(),
        });
      });

      test('omits null assetPath', () {
        const stickerData = StickerData(
          networkUrl: networkUrl,
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );

        final json = stickerData.toJson();

        expect(json.containsKey('assetPath'), isFalse);
        expect(json, {
          'networkUrl': networkUrl,
          'description': description,
          'tags': tags,
          'packData': StickerPackData.fallback.toJson(),
        });
      });

      test('omits both optional fields when null', () {
        const stickerData = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );

        final json = stickerData.toJson();

        expect(json.containsKey('networkUrl'), isFalse);
        expect(json.containsKey('assetPath'), isFalse);
        expect(json, {
          'description': description,
          'tags': tags,
          'packData': StickerPackData.fallback.toJson(),
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
          packData: StickerPackData.fallback,
        );

        final json = original.toJson();
        final restored = StickerData.fromJson(json);

        expect(restored, equals(original));
      });

      test('preserves instance with only required fields', () {
        const original = StickerData(
          description: description,
          tags: tags,
          packData: StickerPackData.fallback,
        );

        final json = original.toJson();
        final restored = StickerData.fromJson(json);

        expect(restored, equals(original));
      });
    });
  });

  group('StickerPackData', () {
    const packId = 'pack1';
    const packName = 'My Pack';

    group('constructor', () {
      test('creates instance with required fields', () {
        const packData = StickerPackData(packId: packId, packName: packName);

        expect(packData.packId, packId);
        expect(packData.packName, packName);
      });
    });

    group('fallback', () {
      test('has expected packId and packName', () {
        expect(StickerPackData.fallback.packId, 'diVine');
        expect(StickerPackData.fallback.packName, 'Divine Originals');
      });
    });

    group('fromJson', () {
      test('creates instance from json map', () {
        final json = {'packId': packId, 'packName': packName};

        final packData = StickerPackData.fromJson(json);

        expect(packData.packId, packId);
        expect(packData.packName, packName);
      });
    });

    group('copyWith', () {
      const original = StickerPackData(packId: packId, packName: packName);

      test('returns same values when no arguments provided', () {
        final copy = original.copyWith();

        expect(copy.packId, original.packId);
        expect(copy.packName, original.packName);
      });

      test('updates packId when provided', () {
        final copy = original.copyWith(packId: 'new-id');

        expect(copy.packId, 'new-id');
        expect(copy.packName, original.packName);
      });

      test('updates packName when provided', () {
        final copy = original.copyWith(packName: 'New Name');

        expect(copy.packId, original.packId);
        expect(copy.packName, 'New Name');
      });
    });

    group('toJson', () {
      test('returns map with all fields', () {
        const packData = StickerPackData(packId: packId, packName: packName);

        expect(packData.toJson(), {'packId': packId, 'packName': packName});
      });
    });

    group('fromJson/toJson roundtrip', () {
      test('preserves all fields', () {
        const original = StickerPackData(packId: packId, packName: packName);

        final restored = StickerPackData.fromJson(original.toJson());

        expect(restored, equals(original));
      });
    });

    group('equality', () {
      test('two instances with same values are equal', () {
        const a = StickerPackData(packId: packId, packName: packName);
        const b = StickerPackData(packId: packId, packName: packName);

        expect(a, equals(b));
      });

      test('two instances with different packId are not equal', () {
        const a = StickerPackData(packId: 'a', packName: packName);
        const b = StickerPackData(packId: 'b', packName: packName);

        expect(a, isNot(equals(b)));
      });

      test('two instances with different packName are not equal', () {
        const a = StickerPackData(packId: packId, packName: 'A');
        const b = StickerPackData(packId: packId, packName: 'B');

        expect(a, isNot(equals(b)));
      });
    });

    group('props', () {
      test('contains packId and packName', () {
        const packData = StickerPackData(packId: packId, packName: packName);

        expect(packData.props, [packId, packName]);
      });
    });
  });
}
