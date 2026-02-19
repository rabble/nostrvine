import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// 1×1 transparent PNG bytes (from Flutter's test suite).
final _transparentPng = Uint8List.fromList(const <int>[
  0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a, //
  0x00, 0x00, 0x00, 0x0d, 0x49, 0x48, 0x44, 0x52,
  0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1f, 0x15, 0xc4,
  0x89, 0x00, 0x00, 0x00, 0x0a, 0x49, 0x44, 0x41,
  0x54, 0x78, 0x9c, 0x63, 0x00, 0x01, 0x00, 0x00,
  0x05, 0x00, 0x01, 0x0d, 0x0a, 0x2d, 0xb4, 0x00,
  0x00, 0x00, 0x00, 0x49, 0x45, 0x4e, 0x44, 0xae,
  0x42, 0x60, 0x82,
]);

/// A test asset bundle that serves a transparent PNG for any asset request.
///
/// This allows [Image.asset] widgets to render in package tests where the
/// actual PNG files are not available (they live in the main app).
class _TestAssetBundle extends CachingAssetBundle {
  _TestAssetBundle() {
    // Build a manifest that includes every sticker asset path.
    final manifest = <String, List<Map<String, Object>>>{
      for (final sticker in DivineStickerName.values)
        sticker.assetPath: [
          <String, Object>{'asset': sticker.assetPath},
        ],
    };
    _manifest = const StandardMessageCodec().encodeMessage(manifest)!;
  }

  late final ByteData _manifest;
  final ByteData _imageData = ByteData.sublistView(_transparentPng);

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(_manifest);
    }
    return SynchronousFuture<ByteData>(_imageData);
  }
}

void main() {
  group(DivineStickerName, () {
    test('has 71 variants', () {
      expect(DivineStickerName.values.length, equals(71));
    });

    test('assetPath returns correct path', () {
      expect(
        DivineStickerName.boom.assetPath,
        equals('assets/stickers/boom.png'),
      );
    });

    test('assetPath returns correct path for multi-word name', () {
      expect(
        DivineStickerName.forgotPasswordAlt.assetPath,
        equals('assets/stickers/forgot_password_alt.png'),
      );
    });

    test('all variants have unique file names', () {
      final fileNames = DivineStickerName.values.map((s) => s.fileName).toSet();
      expect(fileNames.length, equals(DivineStickerName.values.length));
    });

    test('all file names use snake_case', () {
      for (final sticker in DivineStickerName.values) {
        expect(
          sticker.fileName,
          matches(RegExp(r'^[a-z0-9_]+$')),
          reason:
              '${sticker.name} fileName "${sticker.fileName}" '
              'is not snake_case',
        );
      }
    });
  });

  group(DivineSticker, () {
    late _TestAssetBundle bundle;

    setUp(() {
      bundle = _TestAssetBundle();
    });

    Widget buildSubject({
      DivineStickerName sticker = DivineStickerName.boom,
      double? size,
    }) {
      return MaterialApp(
        home: DefaultAssetBundle(
          bundle: bundle,
          child: size != null
              ? DivineSticker(sticker: sticker, size: size)
              : DivineSticker(sticker: sticker),
        ),
      );
    }

    testWidgets('renders an $Image widget', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('renders with default size', (tester) async {
      await tester.pumpWidget(buildSubject());

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, equals(132));
      expect(image.height, equals(132));
    });

    testWidgets('renders with custom size', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.sparkle, size: 64),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.width, equals(64));
      expect(image.height, equals(64));
    });

    testWidgets('uses BoxFit.contain', (tester) async {
      await tester.pumpWidget(
        buildSubject(sticker: DivineStickerName.heart),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, equals(BoxFit.contain));
    });

    testWidgets(
      'errorBuilder renders empty SizedBox on load failure',
      (tester) async {
        final brokenBundle = _BrokenAssetBundle();
        await tester.pumpWidget(
          MaterialApp(
            home: DefaultAssetBundle(
              bundle: brokenBundle,
              child: const DivineSticker(
                sticker: DivineStickerName.boom,
              ),
            ),
          ),
        );

        // Pump to trigger image decode failure and errorBuilder.
        await tester.pumpAndSettle();

        // The fallback SizedBox (132x132) should be rendered.
        final sizedBox = tester.widget<SizedBox>(
          find.byType(SizedBox).last,
        );
        expect(sizedBox.width, equals(132));
        expect(sizedBox.height, equals(132));
      },
    );
  });
}

/// An asset bundle that returns invalid image data to trigger
/// [Image.asset] errorBuilder.
class _BrokenAssetBundle extends CachingAssetBundle {
  _BrokenAssetBundle() {
    final manifest = <String, List<Map<String, Object>>>{
      for (final sticker in DivineStickerName.values)
        sticker.assetPath: [
          <String, Object>{'asset': sticker.assetPath},
        ],
    };
    _manifest = const StandardMessageCodec().encodeMessage(manifest)!;
  }

  late final ByteData _manifest;

  @override
  Future<ByteData> load(String key) {
    if (key == 'AssetManifest.bin') {
      return SynchronousFuture<ByteData>(_manifest);
    }
    // Return invalid bytes to trigger image decode failure.
    return SynchronousFuture<ByteData>(
      ByteData.sublistView(Uint8List.fromList([0, 0, 0])),
    );
  }
}
