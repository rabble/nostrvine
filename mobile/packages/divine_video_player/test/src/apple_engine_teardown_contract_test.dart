import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// These assertions guard the Apple-side fix for the "zombie CADisplayLink"
/// crash (#5371) and the multi-engine registration hardening that followed
/// (#5397): a `FlutterEngine` torn down without routing through the Dart
/// `dispose`/`disposeAll` channel must still invalidate its own players'
/// frame drivers, must do so without tearing down another engine's players,
/// and must source the messenger / texture registry from the engine that
/// received the call — never a process-wide static overwritten by the latest
/// engine to register. The native player has no host-side Swift test harness
/// (it links Flutter), so the contract is asserted against the source like
/// the sibling threading contract test.
void main() {
  group('Apple native player engine-teardown contract', () {
    test("disposes this engine's players on FlutterEngine detach", () {
      final detach = _detachBody();

      expect(
        _pluginSource(),
        contains(
          'public func detachFromEngine(for registrar: FlutterPluginRegistrar)',
        ),
        reason:
            'A FlutterEngine teardown that bypasses the Dart dispose channel '
            '(OOM reclaim, destroyContext, multi-engine teardown) must reach '
            'the plugin so the CADisplayLink can be invalidated.',
      );
      expect(
        detach,
        contains('PlayerRegistry.shared.disposeForEngine(messenger)'),
        reason:
            "Detach must dispose only this engine's players so their display "
            'links stop firing textureFrameAvailable into the freed shell.',
      );
      expect(
        detach,
        isNot(contains('disposeAll')),
        reason:
            'Detach must never blanket-dispose: a process-wide disposeAll '
            "would tear down a second live engine's players.",
      );
      expect(
        detach,
        contains('NotificationCenter.default.removeObserver(self)'),
        reason:
            "Detach must drop this engine's lifecycle observers so a stray "
            'foreground notification cannot resume a torn-down engine.',
      );
    });

    test('scopes teardown to the engine that owns the players', () {
      final source = _pluginSource();

      expect(
        source,
        contains('func disposeForEngine(_ messenger: FlutterBinaryMessenger)'),
        reason:
            'PlayerRegistry.shared is process-wide and shared with the FCM '
            'background isolate; teardown must be scoped per owning engine, '
            'never a blanket disposeAll on detach or register.',
      );
      expect(
        source,
        contains('engine messenger: FlutterBinaryMessenger'),
        reason:
            'Each player must record the engine (its binary messenger) that '
            'created it.',
      );
      expect(
        source,
        contains(
          'PlayerRegistry.shared.set(instance, for: id, engine: messenger)',
        ),
        reason:
            'create must record the receiving engine as the owner so detach '
            "and hot-restart register can identify this engine's players.",
      );
      expect(
        source,
        contains('ObjectIdentifier(messenger as AnyObject)'),
        reason:
            'Ownership is matched by object identity of the engine messenger, '
            'which is stable across that engine, including hot restart.',
      );
    });

    test(
      'player creation uses the receiving instance registrar, not a static',
      () {
        final source = _pluginSource();

        expect(
          source,
          isNot(contains('static var registrar')),
          reason:
              'A process-wide static registrar is overwritten by the last '
              'engine to register; player creation would then use the wrong '
              "engine's messenger / texture registry. See #5397.",
        );
        expect(
          source,
          contains('private var registrar: FlutterPluginRegistrar?'),
          reason:
              'The registrar must be per plugin instance so each engine keeps '
              'its own messenger / texture registry.',
        );
        expect(
          _createBody(),
          contains('let registrar = self.registrar'),
          reason:
              'create must use the registrar of the plugin instance that '
              'received the method call — the engine the Dart side is talking '
              'to — not a static last-writer-wins registrar.',
        );
      },
    );

    test(
      'scopes hot-restart register-time cleanup to the registering engine',
      () {
        final register = _registerBody();

        expect(
          register,
          contains('PlayerRegistry.shared.disposeForEngine(messenger)'),
          reason:
              'Hot restart re-calls register on the same engine; cleanup must '
              "dispose only that engine's previous-run players.",
        );
        expect(
          register,
          isNot(contains('disposeAll')),
          reason:
              'A process-wide disposeAll at register would free a second live '
              "engine's players when the FCM background isolate registers "
              'after the UI engine created players. See #5397.',
        );
      },
    );

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

String _pluginSource() => _pluginSourceFile().readAsStringSync();

/// Slices the `register(with:)` body, which runs from the function signature
/// up to the first app-lifecycle selector that follows it.
String _registerBody() => _slice(
  _pluginSource(),
  'public static func register(with registrar:',
  '@objc private func appWillResignActive',
);

/// Slices the `detachFromEngine(for:)` body, up to the `handle` method.
String _detachBody() => _slice(
  _pluginSource(),
  'public func detachFromEngine(for registrar:',
  'public func handle(',
);

/// Slices the `create` switch case, up to the `dispose` case.
String _createBody() =>
    _slice(_pluginSource(), 'case "create":', 'case "dispose":');

String _slice(String source, String start, String end) {
  final from = source.indexOf(start);
  final to = source.indexOf(end, from);
  expect(from, isNonNegative, reason: 'expected to find "$start" in source');
  expect(to, greaterThan(from), reason: 'expected "$end" after "$start"');
  return source.substring(from, to);
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
