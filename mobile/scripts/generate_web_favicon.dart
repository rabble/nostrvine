// ABOUTME: Regenerates the web icon files flutter_launcher_icons cannot model:
// ABOUTME: a plate-free favicon and padded maskable launcher icons.
//
// USAGE: dart run scripts/generate_web_favicon.dart
//
// Run this AFTER `dart run flutter_launcher_icons`. That tool's `web:` block
// has no separate favicon setting and writes the maskable icons with no safe
// zone padding, so this script has to run second to win.

// ignore_for_file: avoid_print

import 'dart:io';

import 'package:image/image.dart';

/// Isolated (plate-free) brand avatar, per `VISUAL_IDENTITY.md` § Avatars.
///
/// A browser tab sits on the page chrome rather than on a launcher plate, so
/// it takes the avatar instead of the green-plated app icon — matching how
/// divine.video renders its own tab.
const faviconSource = 'assets/icon/divine_icon_transparent.png';

const faviconOutput = 'web/favicon.png';

const appIconSource = 'assets/icon/app_icon.png';

const maskableOutputs = {
  192: 'web/icons/Icon-maskable-192.png',
  512: 'web/icons/Icon-maskable-512.png',
};

final brandGreen = ColorRgb8(0x27, 0xC5, 0x8B);

/// Divides evenly by 16, 32 and 48, so every tab size a browser asks for is a
/// clean downscale of the one file.
const faviconExtent = 96;

/// Matches the native adaptive icon foreground inset in
/// `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`.
const maskableInsetFraction = 0.16;

void main() {
  final faviconSourceImage = _readSquarePng(faviconSource, 'favicon');
  final appIconSourceImage = _readSquarePng(appIconSource, 'maskable icon');
  if (faviconSourceImage == null || appIconSourceImage == null) {
    exitCode = 1;
    return;
  }

  _writeFavicon(faviconSourceImage);
  _writeMaskableIcons(appIconSourceImage);
}

Image? _readSquarePng(String path, String label) {
  final source = decodePng(File(path).readAsBytesSync());
  if (source == null) {
    stderr.writeln('Could not decode $path');
    return null;
  }

  // Squaring a non-square source would silently squash the mark, and the
  // 8x8 signature the icon guard compares on normalises aspect away.
  if (source.width != source.height) {
    stderr.writeln(
      '$path is ${source.width}x${source.height}; the $label needs a square '
      'source',
    );
    return null;
  }

  return source;
}

void _writeFavicon(Image source) {
  // Matches flutter_launcher_icons' own downscale filter so the favicon and
  // the launcher icons resample identically.
  final favicon = copyResize(
    source,
    width: faviconExtent,
    height: faviconExtent,
    interpolation: Interpolation.average,
  );

  File(faviconOutput).writeAsBytesSync(encodePng(favicon));
  print(
    'Wrote $faviconOutput (${faviconExtent}x$faviconExtent) '
    'from $faviconSource',
  );
}

void _writeMaskableIcons(Image source) {
  for (final entry in maskableOutputs.entries) {
    final extent = entry.key;
    final foregroundExtent = (extent * (1 - maskableInsetFraction * 2)).round();
    final foreground = copyResize(
      source,
      width: foregroundExtent,
      height: foregroundExtent,
      interpolation: Interpolation.average,
    );
    final icon = Image(width: extent, height: extent);
    fill(icon, color: brandGreen);
    compositeImage(
      icon,
      foreground,
      dstX: ((extent - foregroundExtent) / 2).round(),
      dstY: ((extent - foregroundExtent) / 2).round(),
    );

    File(entry.value).writeAsBytesSync(encodePng(icon));
    print(
      'Wrote ${entry.value} (${extent}x$extent) from $appIconSource '
      'with ${(maskableInsetFraction * 100).round()}% inset',
    );
  }
}
