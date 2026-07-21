// ABOUTME: Unit tests for WatermarkImageGenerator — guards the refreshed Divine
// ABOUTME: wordmark asset and its bottom-right composition into export overlays.

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/watermark_image_generator.dart';

const _wordmarkAssetKey = 'assets/icon/divine_wordmark.png';

/// Mocks `flutter/assets` so [rootBundle] serves [bytes] for the wordmark path,
/// mirroring the deterministic asset-loading pattern in
/// `seed_media_preload_service_test.dart` (safe under the merged VGV isolate).
void _mockWordmarkAsset(Uint8List bytes) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (ByteData? message) async {
        if (message == null) return null;
        final assetName = utf8.decode(message.buffer.asUint8List());
        if (assetName == _wordmarkAssetKey) {
          return ByteData.sublistView(bytes);
        }
        return null;
      });
}

void _clearAssetMock() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}

/// Installs an asset handler that returns `null` for every key, so
/// [rootBundle] cannot resolve the wordmark and `load` throws. (Merely
/// clearing the mock lets `flutter test` fall back to the real bundled asset.)
void _mockAssetMissing() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler(
        'flutter/assets',
        (ByteData? message) async => null,
      );
}

Future<({int width, int height, Uint8List rgba})> _decodeRgba(
  Uint8List png,
) async {
  final codec = await ui.instantiateImageCodec(png);
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData();
  final result = (
    width: image.width,
    height: image.height,
    rgba: data!.buffer.asUint8List(),
  );
  image.dispose();
  codec.dispose();
  return result;
}

int _alphaAt(Uint8List rgba, int width, int x, int y) =>
    rgba[(y * width + x) * 4 + 3];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(WatermarkImageGenerator, () {
    late Uint8List wordmarkBytes;

    setUpAll(() async {
      // flutter test runs with CWD = package root (mobile/).
      wordmarkBytes = await File(_wordmarkAssetKey).readAsBytes();
    });

    setUp(() {
      rootBundle.clear();
      _clearAssetMock();
      _mockWordmarkAsset(wordmarkBytes);
    });

    tearDown(() {
      rootBundle.clear();
      _clearAssetMock();
    });

    test(
      'bundled wordmark asset is a pure-white mark (not the retired cream)',
      () async {
        final decoded = await _decodeRgba(wordmarkBytes);

        // Only fully-opaque pixels: rawRgba bytes are premultiplied, so
        // anti-aliased edge pixels carry attenuated colour and would skew the
        // average. Interior stroke pixels are the mark's true colour.
        var solid = 0;
        var sumR = 0;
        var sumG = 0;
        var sumB = 0;
        for (var i = 0; i < decoded.rgba.length; i += 4) {
          if (decoded.rgba[i + 3] == 255) {
            solid++;
            sumR += decoded.rgba[i];
            sumG += decoded.rgba[i + 1];
            sumB += decoded.rgba[i + 2];
          }
        }

        expect(
          solid,
          greaterThan(500),
          reason: 'mark should have opaque body pixels',
        );
        // Retired mark averaged (245,246,234) — a warm cream (blue ≈ 234).
        // The refreshed mark is pure white; every channel average is ~255.
        expect(sumR / solid, greaterThan(250));
        expect(sumG / solid, greaterThan(250));
        expect(
          sumB / solid,
          greaterThan(250),
          reason: 'blue channel distinguishes white (255) from cream (234)',
        );
      },
    );

    test(
      'generates a full-frame overlay with the mark drawn bottom-right only',
      () async {
        const width = 400;
        const height = 700;

        final png = await WatermarkImageGenerator.generateWatermark(
          videoWidth: width,
          videoHeight: height,
          watermarkText: '@divine.video',
        );
        expect(png, isNotEmpty);

        final decoded = await _decodeRgba(png);
        expect(decoded.width, width);
        expect(decoded.height, height);

        // The mark + identity block sits in the bottom-right corner, so the
        // top half of the frame must be fully transparent.
        for (final y in [10, 80, height ~/ 3, height ~/ 2 - 20]) {
          for (final x in [10, width ~/ 2, width - 10]) {
            expect(
              _alphaAt(decoded.rgba, decoded.width, x, y),
              0,
              reason: 'expected transparent overlay at ($x,$y)',
            );
          }
        }

        // The bottom-right region must contain rendered (non-transparent)
        // pixels from the wordmark / identity text.
        var drawn = 0;
        for (var y = height - 90; y < height; y++) {
          for (var x = width ~/ 2; x < width; x++) {
            if (_alphaAt(decoded.rgba, decoded.width, x, y) > 0) drawn++;
          }
        }
        expect(
          drawn,
          greaterThan(0),
          reason: 'wordmark + identity should render in the bottom-right',
        );
      },
    );

    test(
      'throws WatermarkGenerationException when the asset cannot load',
      () async {
        rootBundle.clear();
        _mockAssetMissing();

        await expectLater(
          WatermarkImageGenerator.generateWatermark(
            videoWidth: 400,
            videoHeight: 700,
            watermarkText: '@divine.video',
          ),
          throwsA(isA<WatermarkGenerationException>()),
        );
      },
    );
  });
}
