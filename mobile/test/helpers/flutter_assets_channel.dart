// ABOUTME: Restores flutter_test's default `flutter/assets` handler after a
// ABOUTME: test mocks it, so the shared VGV isolate can still load assets.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Reinstalls flutter_test's built-in `flutter/assets` handler, mirroring the
/// private `mockFlutterAssets()` in `flutter_test/src/_binding_io.dart`.
///
/// A test that mocks `flutter/assets` MUST call this in teardown instead of
/// `setMockMessageHandler('flutter/assets', null)`. Under `flutter test` the
/// framework installs a default handler that serves the bundled assets from
/// `UNIT_TEST_ASSETS`; nulling it removes that handler entirely, so every
/// later suite in the shared `very_good --optimization` isolate loses asset
/// loading — the wordmark SVG (and any other `.svg`/`.png` asset) silently
/// fails to load and its `isImage` semantics node never appears.
/// `flutter/assets` is not one of the auto-healed shared channels, so nothing
/// else catches this.
void restoreFlutterAssetsDefaultHandler() {
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final assetFolder = Platform.environment['UNIT_TEST_ASSETS'];
  if (assetFolder == null) {
    // Plain `flutter test <file>` (no bundled `UNIT_TEST_ASSETS`): there is no
    // framework handler to restore, and removing the mock is the correct reset.
    messenger.setMockMessageHandler('flutter/assets', null);
    return;
  }
  final prefix = 'packages/${Platform.environment['APP_NAME']}/';
  messenger.setMockMessageHandler('flutter/assets', (ByteData? message) {
    var key = utf8.decode(message!.buffer.asUint8List());
    var asset = File(p.join(assetFolder, key));
    if (!asset.existsSync()) {
      // A package's own assets are requested with a package prefix; do the
      // same best-effort lookup the framework does.
      if (!key.startsWith(prefix)) return null;
      key = key.replaceFirst(prefix, '');
      asset = File(p.join(assetFolder, key));
      if (!asset.existsSync()) return null;
    }
    final encoded = Uint8List.fromList(asset.readAsBytesSync());
    return SynchronousFuture<ByteData>(encoded.buffer.asByteData());
  });
}
