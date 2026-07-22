// ABOUTME: Guards the native splash — pins the Android and iOS launch images to
// ABOUTME: the current Divine wordmark, Brand Green, and their density ladders.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/brand_silhouette.dart';

/// Vector source of the Divine wordmark. The launch images are raster cuts of
/// it, so a brand refresh has to move all of them together.
const _wordmarkAssetKey = 'assets/icon/logo.svg';

/// Retired cursive wordmark from the pre-refresh brand pack. Present only to
/// prove the silhouette check can tell a wrong wordmark apart from the right
/// one — without it, [_minWordmarkOverlap] could be meaninglessly low.
const _retiredWordmarkAssetKey = 'assets/icon/White cropped.png';

/// Overlap a launch image must reach against [_wordmarkAssetKey].
///
/// Measured on this set: Android buckets `0.910`–`0.980`, iOS `0.888`–`0.971`
/// (the 1x cut is only 196px wide, so it resamples the least faithfully).
/// Wrong artwork lands far below — retired cursive wordmark `0.235`, its
/// full brand-pack export `0.256`, the standalone mark `0.243`, the 3D app
/// icon `0.126`.
const _minWordmarkOverlap = 0.80;

/// Canvas the Android launch image occupies, in density-independent pixels.
/// Kept in sync with `scripts/generate_android_launch_images.dart`.
const _androidCanvasDp = 240;

const _androidBuckets = <String, double>{
  'mdpi': 1,
  'hdpi': 1.5,
  'xhdpi': 2,
  'xxhdpi': 3,
  'xxxhdpi': 4,
};

/// Point size `LaunchScreen.storyboard` pins the launch image view to.
const _iosWidthPt = 196;
const _iosHeightPt = 70;

const _iosScales = <String, int>{
  'LaunchImage.png': 1,
  'LaunchImage@2x.png': 2,
  'LaunchImage@3x.png': 3,
};

// Paths below are relative because `flutter test` runs with CWD = mobile/.
const _resDir = 'android/app/src/main/res';
const _imagesetDir = 'ios/Runner/Assets.xcassets/LaunchImage.imageset';
const _storyboardPath = 'ios/Runner/Base.lproj/LaunchScreen.storyboard';

String _androidLaunchImage(String bucket) =>
    '$_resDir/drawable-$bucket/launch_image.png';

Future<DecodedImage> _decodeFile(String path) async =>
    decodeRgba(await File(path).readAsBytes());

/// Colours of every fully-opaque pixel. Raw bytes are premultiplied, so
/// anti-aliased edges carry attenuated colour and are skipped.
Set<int> _solidColors(DecodedImage image) {
  final colors = <int>{};
  for (var i = 0; i < image.rgba.length; i += 4) {
    if (image.rgba[i + 3] != 255) continue;
    colors.add(
      (0xFF << 24) |
          (image.rgba[i] << 16) |
          (image.rgba[i + 1] << 8) |
          image.rgba[i + 2],
    );
  }
  return colors;
}

int _solidPixelCount(DecodedImage image) {
  var count = 0;
  for (var i = 0; i < image.rgba.length; i += 4) {
    if (image.rgba[i + 3] == 255) count++;
  }
  return count;
}

/// Distance from the canvas centre to the furthest visible pixel.
double _artworkRadius(DecodedImage image) {
  final centerX = (image.width - 1) / 2;
  final centerY = (image.height - 1) / 2;
  var radius = 0.0;
  for (var y = 0; y < image.height; y++) {
    for (var x = 0; x < image.width; x++) {
      if (image.rgba[(y * image.width + x) * 4 + 3] <= 128) continue;
      final distance = math.sqrt(
        math.pow(x - centerX, 2) + math.pow(y - centerY, 2),
      );
      if (distance > radius) radius = distance;
    }
  }
  return radius;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<bool> wordmark;

  setUpAll(() async {
    final svg = await File(_wordmarkAssetKey).readAsString();
    wordmark = normalizedSilhouette(await rasterizeSvg(svg));
  });

  group('Android launch image', () {
    test('ships one file per density bucket and nothing outside them', () {
      final shipped =
          Directory(_resDir)
              .listSync()
              .whereType<Directory>()
              .map((dir) => '${dir.path}/launch_image.png')
              .where((path) => File(path).existsSync())
              .toList()
            ..sort();
      expect(
        shipped,
        equals(
          _androidBuckets.keys.map(_androidLaunchImage).toList()..sort(),
        ),
        reason:
            'a copy in the unqualified drawable/ bucket is resolved as mdpi '
            'and would shadow nothing, while a missing bucket falls back to a '
            'file authored for another density',
      );
    });

    test(
      'sizes every bucket to the same ${_androidCanvasDp}dp canvas',
      () async {
        for (final entry in _androidBuckets.entries) {
          final image = await _decodeFile(_androidLaunchImage(entry.key));
          final expected = (_androidCanvasDp * entry.value).round();
          expect(
            [image.width, image.height],
            equals([expected, expected]),
            reason:
                'launch_background.xml centres this bitmap at its intrinsic '
                'size, so ${entry.key} must carry ${_androidCanvasDp}dp at '
                '${entry.value}x or the splash mark changes size per device',
          );
        }
      },
    );

    test('paints the mark in Brand Green', () async {
      for (final bucket in _androidBuckets.keys) {
        final image = await _decodeFile(_androidLaunchImage(bucket));
        expect(
          _solidPixelCount(image),
          greaterThan(1000),
          reason: '$bucket should have a solid mark body',
        );
        expect(
          _solidColors(image),
          equals({VineTheme.vineGreen.toARGB32()}),
          reason: '$bucket must be flat Brand Green, not a retired green',
        );
      }
    });

    test('keeps the mark inside the Android 12+ splash mask', () async {
      for (final bucket in _androidBuckets.keys) {
        final image = await _decodeFile(_androidLaunchImage(bucket));
        expect(
          _artworkRadius(image),
          lessThanOrEqualTo(image.width / 3),
          reason:
              'values-v31 sets windowSplashScreenAnimatedIcon, and Android '
              'clips it to a circle two thirds of the canvas wide — artwork '
              'outside that circle is cropped off the $bucket splash',
        );
      }
    });

    test('draws the current Divine wordmark', () async {
      for (final bucket in _androidBuckets.keys) {
        final image = await _decodeFile(_androidLaunchImage(bucket));
        expect(
          silhouetteOverlap(wordmark, normalizedSilhouette(image)),
          greaterThanOrEqualTo(_minWordmarkOverlap),
          reason: '$bucket no longer matches $_wordmarkAssetKey',
        );
      }
    });

    test('fills the splash with the app surface colour', () {
      final surface = VineTheme.surfaceBackground.toARGB32().toRadixString(16);
      final expected = '#${surface.substring(2).toUpperCase()}';
      for (final variant in ['values', 'values-night']) {
        final colors = File('$_resDir/$variant/colors.xml').readAsStringSync();
        expect(
          RegExp(
            '<color name="splash_background">([^<]+)</color>',
          ).firstMatch(colors)?.group(1)?.toUpperCase(),
          equals(expected),
          reason:
              '$variant/colors.xml must match VineTheme.surfaceBackground or '
              'the splash flashes a different colour into the first frame',
        );
      }
    });

    test('wires both splash paths to the launch image', () {
      for (final variant in ['drawable', 'drawable-v21']) {
        final layers = File(
          '$_resDir/$variant/launch_background.xml',
        ).readAsStringSync();
        expect(layers, contains('@color/splash_background'));
        expect(layers, contains('@drawable/launch_image'));
        expect(
          layers,
          contains('android:gravity="center"'),
          reason: 'a scaled bitmap would stretch the wordmark',
        );
      }
      String item(String name, String value) =>
          '<item name="android:$name">$value</item>';
      for (final variant in ['values-v31', 'values-night-v31']) {
        final styles = File('$_resDir/$variant/styles.xml').readAsStringSync();
        expect(
          styles,
          contains(
            item('windowSplashScreenAnimatedIcon', '@drawable/launch_image'),
          ),
        );
        expect(
          styles,
          contains(
            item('windowSplashScreenBackground', '@color/splash_background'),
          ),
        );
      }
    });
  });

  group('iOS launch image', () {
    test(
      'sizes every scale from one ${_iosWidthPt}x${_iosHeightPt}pt box',
      () async {
        final contents =
            jsonDecode(
                  File('$_imagesetDir/Contents.json').readAsStringSync(),
                )
                as Map<String, dynamic>;
        final declared = {
          for (final image in contents['images']! as List<dynamic>)
            (image as Map<String, dynamic>)['filename'] as String:
                image['scale'] as String,
        };
        expect(
          declared,
          equals(_iosScales.map((name, scale) => MapEntry(name, '${scale}x'))),
        );

        for (final entry in _iosScales.entries) {
          final image = await _decodeFile('$_imagesetDir/${entry.key}');
          expect(
            [image.width, image.height],
            equals([_iosWidthPt * entry.value, _iosHeightPt * entry.value]),
            reason:
                '${entry.key} must fill the storyboard image view exactly at '
                '${entry.value}x, or it renders soft on that device class',
          );
        }
      },
    );

    test('paints the mark in Brand Green', () async {
      for (final name in _iosScales.keys) {
        final image = await _decodeFile('$_imagesetDir/$name');
        expect(_solidPixelCount(image), greaterThan(1000));
        expect(
          _solidColors(image),
          equals({VineTheme.vineGreen.toARGB32()}),
          reason: '$name must be flat Brand Green, not a retired green',
        );
      }
    });

    test('draws the current Divine wordmark', () async {
      for (final name in _iosScales.keys) {
        final image = await _decodeFile('$_imagesetDir/$name');
        expect(
          silhouetteOverlap(wordmark, normalizedSilhouette(image)),
          greaterThanOrEqualTo(_minWordmarkOverlap),
          reason: '$name no longer matches $_wordmarkAssetKey',
        );
      }
    });

    test('backs the mark with the app surface colour', () {
      final storyboard = File(_storyboardPath).readAsStringSync();
      final match = RegExp(
        r'<color key="backgroundColor" red="([\d.]+)" green="([\d.]+)" '
        r'blue="([\d.]+)"',
      ).firstMatch(storyboard);
      expect(match, isNotNull, reason: 'storyboard lost its background colour');
      final channels = [
        for (var group = 1; group <= 3; group++)
          (double.parse(match!.group(group)!) * 255).round(),
      ];
      final surface = VineTheme.surfaceBackground.toARGB32();
      expect(
        channels,
        equals([
          (surface >> 16) & 0xFF,
          (surface >> 8) & 0xFF,
          surface & 0xFF,
        ]),
        reason:
            'the storyboard must match VineTheme.surfaceBackground so the '
            'splash does not flash a different colour into the first frame',
      );
    });

    test('declares the shipped image size', () {
      final storyboard = File(_storyboardPath).readAsStringSync();
      expect(
        storyboard,
        contains(
          '<image name="LaunchImage" width="$_iosWidthPt" '
          'height="$_iosHeightPt"/>',
        ),
        reason:
            'the storyboard resource stub must describe the 1x asset, so a '
            'reader is not told the launch image is a different shape',
      );
      expect(
        RegExp(
          r'constant="(\d+)" id="imageWidth"',
        ).firstMatch(storyboard)?.group(1),
        equals('$_iosWidthPt'),
      );
      expect(
        RegExp(
          r'constant="(\d+)" id="imageHeight"',
        ).firstMatch(storyboard)?.group(1),
        equals('$_iosHeightPt'),
      );
    });

    test('is the storyboard the launch surface points at', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();
      expect(
        plist,
        contains(
          '<key>UILaunchStoryboardName</key>\n\t<string>LaunchScreen</string>',
        ),
      );
    });
  });

  test('tells the retired cursive wordmark apart', () async {
    final retired = await _decodeFile(_retiredWordmarkAssetKey);
    expect(
      silhouetteOverlap(wordmark, normalizedSilhouette(retired)),
      lessThan(_minWordmarkOverlap),
      reason:
          'the launch-image checks above are only meaningful while a wrong '
          'wordmark scores below the threshold',
    );
  });
}
