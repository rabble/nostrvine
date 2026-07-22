// ABOUTME: Guards the branded loading spinner — pins the sprite sheet to the
// ABOUTME: current Divine brand mark and to the frame count the slicer assumes.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Source of truth for the standalone brand mark, also shipped as
/// `DivineIconName.divineMark`. The sprite sheet is its animated white
/// derivative, so a brand refresh has to move both together.
const _markAssetKey = 'assets/icon/divine_mark.svg';

/// Pinned as a literal rather than read from [BrandedLoadingIndicator] so a
/// rename of the constant's target is a test failure, not a silent redirect.
const _spriteAssetKey = 'assets/loading-brand-sprite.png';

/// Resolution the two silhouettes are compared at, after each is cropped to
/// its own bounding box and scaled to fit. Comparing normalised shapes keeps
/// the check about the mark's geometry rather than its padding or export size.
const _compareBox = 192;

/// Overlap the mark's rest pose must reach in the sprite sheet.
///
/// Measured against this sheet: best frame `0.982`, mid-flap frames bottom out
/// at `0.647` (the wings move, so only the rest pose matches). Wrong-mark
/// candidates all land far below — 3D mascot `0.803`, current 3D app icon
/// `0.477`, retired `old_app_icon.png` `0.335`, cursive wordmark `0.195`.
const _minMarkOverlap = 0.90;

typedef _Decoded = ({int width, int height, Uint8List rgba});

Future<_Decoded> _decodeRgba(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
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

/// Rasterises [_markAssetKey] into an RGBA buffer of [size] square.
Future<_Decoded> _rasterizeMark(String svg, int size) async {
  final picture = await vg.loadPicture(SvgStringLoader(svg), null);
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder)
    ..scale(size / picture.size.width, size / picture.size.height)
    ..drawPicture(picture.picture);
  final image = await recorder.endRecording().toImage(size, size);
  final data = await image.toByteData();
  final result = (
    width: size,
    height: size,
    rgba: data!.buffer.asUint8List(),
  );
  image.dispose();
  picture.picture.dispose();
  return result;
}

/// Coverage mask of the visible artwork, cropped to its bounding box and
/// area-resampled into a centred [_compareBox] square so two exports of the
/// same shape line up regardless of their source resolution or margins.
List<bool> _normalizedSilhouette(_Decoded image) {
  bool opaqueAt(int x, int y) =>
      image.rgba[(y * image.width + x) * 4 + 3] > 128;

  var minX = image.width;
  var minY = image.height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (!opaqueAt(x, y)) continue;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
    }
  }
  if (maxX < 0) return List<bool>.filled(_compareBox * _compareBox, false);

  final boxWidth = maxX - minX + 1;
  final boxHeight = maxY - minY + 1;
  final scale = _compareBox / (boxWidth > boxHeight ? boxWidth : boxHeight);
  final targetWidth = (boxWidth * scale).round().clamp(1, _compareBox);
  final targetHeight = (boxHeight * scale).round().clamp(1, _compareBox);
  final offsetX = (_compareBox - targetWidth) ~/ 2;
  final offsetY = (_compareBox - targetHeight) ~/ 2;

  final mask = List<bool>.filled(_compareBox * _compareBox, false);
  for (var ty = 0; ty < targetHeight; ty++) {
    final y0 = minY + (ty * boxHeight / targetHeight).floor();
    final y1 = minY + ((ty + 1) * boxHeight / targetHeight).ceil();
    for (var tx = 0; tx < targetWidth; tx++) {
      final x0 = minX + (tx * boxWidth / targetWidth).floor();
      final x1 = minX + ((tx + 1) * boxWidth / targetWidth).ceil();
      var covered = 0;
      var total = 0;
      for (var y = y0; y < y1 && y <= maxY; y++) {
        for (var x = x0; x < x1 && x <= maxX; x++) {
          total++;
          if (opaqueAt(x, y)) covered++;
        }
      }
      if (total > 0 && covered * 2 >= total) {
        mask[(ty + offsetY) * _compareBox + tx + offsetX] = true;
      }
    }
  }
  return mask;
}

/// Intersection over union — 1.0 for identical silhouettes, 0.0 for disjoint.
double _overlap(List<bool> a, List<bool> b) {
  var intersection = 0;
  var union = 0;
  for (var i = 0; i < a.length; i++) {
    if (a[i] && b[i]) intersection++;
    if (a[i] || b[i]) union++;
  }
  return union == 0 ? 0 : intersection / union;
}

/// Extracts frame [index] of the vertically stacked sheet.
_Decoded _frameAt(_Decoded sheet, int index) {
  final size = sheet.width;
  final frame = Uint8List(size * size * 4);
  final start = index * size * size * 4;
  frame.setRange(0, frame.length, sheet.rgba, start);
  return (width: size, height: size, rgba: frame);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(BrandedLoadingIndicator, () {
    testWidgets('renders the branded sprite sheet', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandedLoadingIndicator())),
      );

      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, equals(_spriteAssetKey));
      expect(BrandedLoadingIndicator.spriteAsset, equals(_spriteAssetKey));
    });

    testWidgets('advances through the sheet while loading', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: BrandedLoadingIndicator())),
      );

      // Storage index 13 is the matrix's y translation — how far up the sheet
      // has been scrolled to expose the current frame.
      double spriteY() => tester
          .widget<Transform>(
            find.descendant(
              of: find.byType(BrandedLoadingIndicator),
              matching: find.byType(Transform),
            ),
          )
          .transform
          .storage[13];

      final atStart = spriteY();
      // A third of the way through the 1800ms cycle: several frames on.
      await tester.pump(const Duration(milliseconds: 600));
      expect(spriteY(), isNot(equals(atStart)));

      // Still cycling two periods later — a loading spinner must not stall.
      await tester.pump(const Duration(milliseconds: 3000));
      final afterTwoCycles = spriteY();
      await tester.pump(const Duration(milliseconds: 600));
      expect(spriteY(), isNot(equals(afterTwoCycles)));

      // Leaves no live ticker behind for the merged VGV isolate.
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    });
  });

  group('sprite sheet asset', () {
    late _Decoded sheet;

    // `flutter test` runs with CWD = package root (mobile/).
    setUpAll(() async {
      sheet = await _decodeRgba(await File(_spriteAssetKey).readAsBytes());
    });

    test('stacks exactly frameCount square frames', () {
      expect(
        sheet.height,
        equals(sheet.width * BrandedLoadingIndicator.frameCount),
        reason:
            'the slicer steps by one frame width; a sheet with a different '
            'frame count would be sliced mid-frame',
      );
    });

    test('draws the mark in pure white on transparency', () {
      var solid = 0;
      var sumR = 0;
      var sumG = 0;
      var sumB = 0;
      var transparent = 0;
      for (var i = 0; i < sheet.rgba.length; i += 4) {
        final alpha = sheet.rgba[i + 3];
        if (alpha == 0) transparent++;
        // Only fully-opaque pixels: rawRgba is premultiplied, so anti-aliased
        // edges carry attenuated colour that would drag the average down.
        if (alpha != 255) continue;
        solid++;
        sumR += sheet.rgba[i];
        sumG += sheet.rgba[i + 1];
        sumB += sheet.rgba[i + 2];
      }

      expect(solid, greaterThan(1000), reason: 'mark should have a body');
      expect(
        transparent,
        greaterThan(solid),
        reason: 'the mark sits on transparency, not a baked-in backdrop',
      );
      // Divine is dark-mode only, so the spinner ships pre-coloured white for
      // contrast. The retired brand pack is cream (blue channel ~234).
      expect(sumR / solid, greaterThan(250));
      expect(sumG / solid, greaterThan(250));
      expect(sumB / solid, greaterThan(250));
    });

    test('animates the current Divine brand mark', () async {
      final mark = _normalizedSilhouette(
        await _rasterizeMark(
          await File(_markAssetKey).readAsString(),
          sheet.width,
        ),
      );

      var best = 0.0;
      var bestFrame = -1;
      for (var i = 0; i < BrandedLoadingIndicator.frameCount; i++) {
        final score = _overlap(mark, _normalizedSilhouette(_frameAt(sheet, i)));
        if (score > best) {
          best = score;
          bestFrame = i;
        }
      }

      // Only the rest pose lines up — the wings move through the cycle.
      expect(
        best,
        greaterThanOrEqualTo(_minMarkOverlap),
        reason:
            'no frame matches $_markAssetKey (best was frame $bestFrame at '
            '${best.toStringAsFixed(3)}); the spinner and the brand mark have '
            'drifted apart',
      );
    });
  });
}
