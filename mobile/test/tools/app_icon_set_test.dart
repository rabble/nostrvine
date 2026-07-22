// ABOUTME: Guards that every generated launcher icon still derives from
// ABOUTME: assets/icon/app_icon.png, the browser favicon from the isolated
// ABOUTME: avatar, that the generator config points at both sources, and that
// ABOUTME: the flat colours shipped alongside them are still Brand Green.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:yaml/yaml.dart';

/// The single source of truth every launcher icon is generated from.
const _appIconSource = 'assets/icon/app_icon.png';

/// The source the browser-tab favicon is generated from: the isolated,
/// plate-free brand avatar the app icon is itself based on.
///
/// `flutter_launcher_icons` has no separate favicon setting — its `web:` block
/// rewrites [_faviconPath] from [_appIconSource] — so the favicon is written
/// afterwards by `scripts/generate_web_favicon.dart`. A regenerate that skips
/// that second step turns the browser tab favicon group red.
const _faviconSource = 'assets/icon/divine_icon_transparent.png';

const _faviconPath = 'web/favicon.png';

const _maskableIconPaths = [
  'web/icons/Icon-maskable-192.png',
  'web/icons/Icon-maskable-512.png',
];

const _androidColorsPath = 'android/app/src/main/res/values/colors.xml';

const _webManifestPath = 'web/manifest.json';

/// Brand Green as the icon generator spells it.
///
/// Sourced from the design system rather than hardcoded so a palette change
/// lands here as a failing icon config rather than a silent two-tone icon.
final _brandGreenHex =
    '#${VineTheme.vineGreen.toARGB32().toRadixString(16).substring(2).toUpperCase()}';

/// Edge of the square grid each icon is reduced to before comparison.
const _signatureExtent = 8;

/// Max mean absolute per-channel difference (0-255) between the source
/// signature and a generated icon's signature.
///
/// Generated icons are resamples of the same artwork, so the residual is pure
/// scaling error: measured 0.0 for the 1024px icons up to 12.4 for the 16px
/// ones. Artwork that is genuinely different lands far above — the retired
/// `old_app_icon.png` (also a green square with a white play mark) scores 39,
/// and the stock Flutter logo this guard was written for scores 104.
///
/// The favicon is measured against [_faviconSource] on the same scale and
/// lands at 1.3; the two sources are 102 apart.
const _maxSignatureDistance = 20.0;

/// Maskable icons must keep critical content inside the central 80% diameter.
const _maskableSafeRadiusFraction = 0.4;

const _brightForegroundThreshold = 200;

bool _isMaskableIcon(File file) => _maskableIconPaths.contains(file.path);

class _DecodedImage {
  const _DecodedImage({
    required this.width,
    required this.height,
    required this.rgba,
  });

  final int width;
  final int height;
  final Uint8List rgba;
}

Future<_DecodedImage> _decodeImage(File file) async {
  final codec = await ui.instantiateImageCodec(await file.readAsBytes());
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData();
  final decoded = _DecodedImage(
    width: image.width,
    height: image.height,
    rgba: data!.buffer.asUint8List(),
  );
  image.dispose();
  codec.dispose();
  return decoded;
}

/// Reduces [file] to a flat list of RGB values on a
/// [_signatureExtent]x[_signatureExtent] grid, composited over white.
///
/// Compositing keeps `remove_alpha_ios` output — flattened onto `#ffffff` by
/// the generator — comparable with the source's soft-alpha corners.
Future<Float64List> _signature(File file) async {
  final codec = await ui.instantiateImageCodec(
    await file.readAsBytes(),
    targetWidth: _signatureExtent,
    targetHeight: _signatureExtent,
  );
  final frame = await codec.getNextFrame();
  final image = frame.image;
  final data = await image.toByteData();
  image.dispose();
  codec.dispose();

  // toByteData returns premultiplied RGBA.
  final rgba = data!.buffer.asUint8List();
  final signature = Float64List(_signatureExtent * _signatureExtent * 3);
  for (var pixel = 0; pixel < _signatureExtent * _signatureExtent; pixel++) {
    final alpha = rgba[pixel * 4 + 3] / 255;
    for (var channel = 0; channel < 3; channel++) {
      signature[pixel * 3 + channel] =
          rgba[pixel * 4 + channel] + 255 * (1 - alpha);
    }
  }
  return signature;
}

double _distance(Float64List a, Float64List b) {
  var total = 0.0;
  for (var i = 0; i < a.length; i++) {
    total += (a[i] - b[i]).abs();
  }
  return total / a.length;
}

List<File> _pngsNamed(String directory, String prefix) {
  final dir = Directory(directory);
  if (!dir.existsSync()) return const [];
  return dir.listSync().whereType<File>().where((file) {
    final name = file.uri.pathSegments.last;
    return name.startsWith(prefix) && name.endsWith('.png');
  }).toList();
}

const _androidDensities = ['mdpi', 'hdpi', 'xhdpi', 'xxhdpi', 'xxxhdpi'];

/// Every generated icon, grouped by the platform that consumes it. All derive
/// from [_appIconSource] except web's [_faviconPath], which is a tab mark
/// rather than a launcher icon and comes from [_faviconSource].
///
/// `drawable-*/launch_image.png` sits beside `ic_launcher_foreground.png` but
/// is the wordmark splash, not a launcher icon — the name prefix excludes it.
Map<String, List<File>> _generatedIcons() => {
  'ios': _pngsNamed(
    'ios/Runner/Assets.xcassets/AppIcon.appiconset',
    'Icon-App-',
  ),
  'android': [
    for (final density in _androidDensities)
      ..._pngsNamed('android/app/src/main/res/mipmap-$density', 'ic_launcher'),
    for (final density in _androidDensities)
      ..._pngsNamed(
        'android/app/src/main/res/drawable-$density',
        'ic_launcher_foreground',
      ),
  ],
  'macos': _pngsNamed(
    'macos/Runner/Assets.xcassets/AppIcon.appiconset',
    'app_icon_',
  ),
  'web': [
    // Filtered on existence so a deleted favicon shrinks the count rather than
    // slipping through as a File handle pointing at nothing.
    ...[File(_faviconPath)].where((file) => file.existsSync()),
    ..._pngsNamed('web/icons', 'Icon-'),
  ],
};

void main() {
  // `instantiateImageCodec` needs the engine bindings; these are plain `test`
  // cases, so nothing else initializes them.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('generated launcher icon set', () {
    test('covers every platform the generator writes to', () {
      final icons = _generatedIcons();
      const expectedCounts = {'ios': 21, 'android': 10, 'macos': 7, 'web': 5};
      expectedCounts.forEach((platform, count) {
        expect(
          icons[platform],
          hasLength(count),
          reason:
              'the $platform launcher icon set changed size — regenerate with '
              '`dart run flutter_launcher_icons` and update the expected count',
        );
      });
    });

    test('every launcher icon is a resample of $_appIconSource', () async {
      final source = await _signature(File(_appIconSource));
      final stale = <String, double>{};
      for (final files in _generatedIcons().values) {
        for (final file in files) {
          // The favicon is plate-free artwork; covered by its own group below.
          // Maskable PWA icons are intentionally padded; covered by their own
          // safe-zone group below.
          if (file.path == _faviconPath || _isMaskableIcon(file)) continue;
          final distance = _distance(source, await _signature(file));
          if (distance > _maxSignatureDistance) {
            stale[file.path] = distance;
          }
        }
      }
      expect(
        stale,
        isEmpty,
        reason:
            'these launcher icons do not match $_appIconSource — regenerate '
            'with `dart run flutter_launcher_icons`: $stale',
      );
    });
  });

  group('web maskable launcher icons', () {
    test(
      'keep the bright foreground mark inside the maskable safe zone',
      () async {
        for (final path in _maskableIconPaths) {
          final file = File(path);
          expect(file.existsSync(), isTrue, reason: '$path is missing');

          final image = await _decodeImage(file);
          expect(image.width, image.height, reason: '$path must be square');

          final center = (image.width - 1) / 2;
          final safeRadius = image.width * _maskableSafeRadiusFraction;
          var brightForegroundPixels = 0;
          var clippedForegroundPixels = 0;

          for (var y = 0; y < image.height; y++) {
            for (var x = 0; x < image.width; x++) {
              final offset = (y * image.width + x) * 4;
              final red = image.rgba[offset];
              final green = image.rgba[offset + 1];
              final blue = image.rgba[offset + 2];
              final alpha = image.rgba[offset + 3];
              final isBrightForeground =
                  alpha > 0 &&
                  red > _brightForegroundThreshold &&
                  green > _brightForegroundThreshold &&
                  blue > _brightForegroundThreshold;
              if (!isBrightForeground) continue;

              brightForegroundPixels++;
              final distanceFromCenter = math.sqrt(
                math.pow(x - center, 2) + math.pow(y - center, 2),
              );
              if (distanceFromCenter > safeRadius) {
                clippedForegroundPixels++;
              }
            }
          }

          expect(
            brightForegroundPixels,
            greaterThan(0),
            reason: '$path has no detectable bright foreground mark',
          );
          expect(
            clippedForegroundPixels,
            isZero,
            reason:
                '$path has $clippedForegroundPixels bright foreground pixels '
                'outside the maskable safe zone',
          );
        }
      },
    );
  });

  group('browser tab favicon', () {
    test('is a resample of $_faviconSource', () async {
      final distance = _distance(
        await _signature(File(_faviconSource)),
        await _signature(File(_faviconPath)),
      );
      expect(
        distance,
        lessThan(_maxSignatureDistance),
        reason:
            '$_faviconPath does not match $_faviconSource (distance '
            '$distance). `dart run flutter_launcher_icons` overwrites it from '
            '$_appIconSource — follow it with '
            '`dart run scripts/generate_web_favicon.dart`',
      );
    });

    test('sources artwork distinct from $_appIconSource', () async {
      // Without this, replacing the avatar with a copy of the app icon would
      // leave the check above green while the tab silently regained the plate.
      final distance = _distance(
        await _signature(File(_appIconSource)),
        await _signature(File(_faviconSource)),
      );
      expect(
        distance,
        greaterThan(_maxSignatureDistance),
        reason:
            '$_faviconSource is no longer distinguishable from $_appIconSource '
            '(distance $distance), so the favicon guard cannot discriminate',
      );
    });
  });

  group('flutter_launcher_icons config', () {
    late YamlMap config;

    setUpAll(() {
      final pubspec =
          loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
      config = pubspec['flutter_launcher_icons'] as YamlMap;
    });

    test('every platform sources $_appIconSource', () {
      expect(config['image_path'], _appIconSource);
      expect(config['adaptive_icon_foreground'], _appIconSource);
      expect((config['macos'] as YamlMap)['image_path'], _appIconSource);
      // Web's image_path covers the PWA/home-screen icons only; the favicon it
      // also emits is replaced afterwards from $_faviconSource.
      expect((config['web'] as YamlMap)['image_path'], _appIconSource);
    });

    test('generates for every platform the app ships', () {
      expect(config['android'], isTrue);
      expect(config['ios'], isTrue);
      expect((config['macos'] as YamlMap)['generate'], isTrue);
      expect((config['web'] as YamlMap)['generate'], isTrue);
    });

    test('paints the flat icon surfaces in Brand Green', () {
      // The Android adaptive icon composites the app icon over this colour,
      // and the artwork's own plate is Brand Green — anything else shows as a
      // mismatched border once a launcher pans the two layers.
      expect(config['adaptive_icon_background'], _brandGreenHex);
      expect((config['web'] as YamlMap)['theme_color'], _brandGreenHex);
    });
  });

  group('generated brand colours', () {
    test('$_androidColorsPath carries the configured adaptive background', () {
      expect(
        File(_androidColorsPath).readAsStringSync(),
        contains(
          '<color name="ic_launcher_background">$_brandGreenHex</color>',
        ),
        reason:
            'the adaptive icon background drifted from $_brandGreenHex — '
            'regenerate with `dart run flutter_launcher_icons`',
      );
    });

    test('$_webManifestPath carries the configured theme colour', () {
      final manifest =
          jsonDecode(File(_webManifestPath).readAsStringSync())
              as Map<String, dynamic>;
      expect(
        manifest['theme_color'],
        _brandGreenHex,
        reason:
            'the PWA theme colour drifted from $_brandGreenHex — regenerate '
            'with `dart run flutter_launcher_icons`',
      );
    });
  });
}
