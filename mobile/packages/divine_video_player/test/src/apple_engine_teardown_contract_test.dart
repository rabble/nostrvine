import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// These assertions guard the Apple-side fix for the "zombie CADisplayLink"
/// crash (#5371): a `FlutterEngine` torn down without routing through the Dart
/// `dispose`/`disposeAll` channel must still invalidate its own players'
/// frame drivers, and must do so without tearing down another engine's
/// players. The native player has no host-side Swift test harness (it links
/// Flutter), so the contract is asserted against the source like the sibling
/// threading contract test.
void main() {
  group('Apple native player engine-teardown contract', () {
    test("disposes this engine's players on FlutterEngine detach", () {
      final source = _pluginSourceFile().readAsStringSync();

      expect(
        source,
        contains(
          'public func detachFromEngine(for registrar: FlutterPluginRegistrar)',
        ),
        reason:
            'A FlutterEngine teardown that bypasses the Dart dispose channel '
            '(OOM reclaim, destroyContext, multi-engine teardown) must reach '
            'the plugin so the CADisplayLink can be invalidated.',
      );
      expect(
        source,
        contains('PlayerRegistry.shared.disposeOwned(by: self)'),
        reason:
            "Detach must dispose this engine's players so their display "
            'links stop firing textureFrameAvailable into the freed shell.',
      );
      expect(
        source,
        contains('NotificationCenter.default.removeObserver(self)'),
        reason:
            "Detach must drop this engine's lifecycle observers so a stray "
            'foreground notification cannot resume a torn-down engine.',
      );
    });

    test('scopes teardown to the detaching engine', () {
      final source = _pluginSourceFile().readAsStringSync();

      expect(
        source,
        contains('func disposeOwned(by owner: DivineVideoPlayerPlugin)'),
        reason:
            'PlayerRegistry.shared is process-wide and shared with the FCM '
            'background isolate; teardown must be scoped per owning engine, '
            'never a blanket disposeAll on detach.',
      );
      expect(
        source,
        contains('owner: DivineVideoPlayerPlugin'),
        reason: 'Each player must record the engine that created it.',
      );
      expect(
        source,
        contains('PlayerRegistry.shared.set(instance, for: id, owner: self)'),
        reason:
            'create must record the receiving plugin (engine) as the owner so '
            "detach can identify this engine's players.",
      );
      expect(
        source,
        contains('ObjectIdentifier(owner)'),
        reason: 'Ownership is matched by object identity of the owning plugin.',
      );
    });

    test('guards resume against a disposed texture output', () {
      final source = _textureOutputSourceFile().readAsStringSync();

      expect(
        source,
        contains('guard !isDisposed else { return }'),
        reason:
            'resumeFrameDelivery must no-op once the output is disposed so a '
            'foreground notification racing a teardown-driven dispose cannot '
            're-arm delivery on an unregistered texture.',
      );
      expect(
        source,
        contains('isDisposed = true'),
        reason: 'dispose() must mark the output disposed for the resume guard.',
      );
    });
  });
}

/// The iOS and macOS players share a single Darwin source tree
/// (`darwin/divine_video_player/Sources/`), so the contract is asserted once.
File _pluginSourceFile() => _resolve('DivineVideoPlayerPlugin.swift');

File _textureOutputSourceFile() => _resolve('VideoTextureOutput.swift');

File _resolve(String fileName) {
  final packageRelative = File(
    'darwin/divine_video_player/Sources/divine_video_player/$fileName',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/divine_video_player/'
    'darwin/divine_video_player/Sources/divine_video_player/$fileName',
  );
}
