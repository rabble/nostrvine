// ABOUTME: Tests for the layer-direction ratchet (#7383)
// ABOUTME: Verifies pass, new/stale fail, fail-closed, the RoutePaths exemption, and the leaf invariant

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives `scripts/check_layer_direction.sh` against an isolated fixture tree
/// so the guard is verified without touching the real baseline.
void main() {
  group('layer_direction ratchet', () {
    late Directory tmp;
    late String scriptPath;
    late String baselinePath;

    File libFile(String path) => File('${tmp.path}/lib/$path');

    void write(String path, String contents) {
      libFile(path)
        ..createSync(recursive: true)
        ..writeAsStringSync(contents);
    }

    /// The leaf the guard's Rule 1 exemption depends on. Present by default so
    /// Rule 3 does not fire in tests that are about Rules 1 and 2.
    void writeLeaf({bool clean = true}) {
      write(
        'router/route_paths.dart',
        clean
            ? 'abstract final class RoutePaths {\n'
                  "  static const settings = '/settings';\n"
                  '}\n'
            : "import 'package:openvine/screens/settings_screen.dart';\n"
                  'abstract final class RoutePaths {}\n',
      );
    }

    ProcessResult run({bool update = false}) {
      return Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'LAYER_DIRECTION_LIB_DIR': '${tmp.path}/lib',
          'LAYER_DIRECTION_PATH_PREFIX': tmp.path,
          'LAYER_DIRECTION_BASELINE_FILE': baselinePath,
          // A ref that cannot resolve, so the growth check is exercised only
          // where a test opts into it below.
          'LAYER_DIRECTION_BASELINE_BASE_REF':
              'refs/heads/layer-direction-test-no-base-ref',
          'LAYER_DIRECTION_ALLOW_NO_BASE': '1',
          if (update) 'UPDATE_BASELINE': '1',
        },
      );
    }

    setUp(() {
      tmp = Directory.systemTemp.createTempSync('layer_direction_test');
      scriptPath = '${Directory.current.path}/scripts/check_layer_direction.sh';
      baselinePath = '${tmp.path}/baseline.txt';
      for (final dir in [
        'providers',
        'services',
        'repositories',
        'state',
        'router/providers',
      ]) {
        Directory('${tmp.path}/lib/$dir').createSync(recursive: true);
      }
      writeLeaf();
    });

    tearDown(() => tmp.deleteSync(recursive: true));

    test('passes when no lower-layer file imports the UI', () {
      write('providers/clean_provider.dart', "import 'dart:async';\n");
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(0), reason: result.stdout.toString());
      expect(result.stdout, contains('No new upward layer imports'));
    });

    test('fails on a NEW provider -> screen import', () {
      write(
        'providers/bad_provider.dart',
        "import 'package:openvine/screens/settings_screen.dart';\n",
      );
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('NEW upward import'));
      expect(result.stdout, contains('lib/providers/bad_provider.dart'));
    });

    test('fails on a NEW service -> widget import', () {
      write(
        'services/bad_service.dart',
        "import 'package:openvine/widgets/some_widget.dart';\n",
      );
      File(baselinePath).writeAsStringSync('');

      expect(run().exitCode, equals(1));
    });

    test('fails on a relative ../screens import', () {
      write(
        'providers/relative_provider.dart',
        "import '../screens/x.dart';\n",
      );
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('lib/providers/relative_provider.dart'));
    });

    test('a baselined violation passes', () {
      write(
        'providers/bad_provider.dart',
        "import 'package:openvine/screens/settings_screen.dart';\n",
      );
      File(
        baselinePath,
      ).writeAsStringSync('lib/providers/bad_provider.dart # legacy\n');

      expect(run().exitCode, equals(0));
    });

    test('fails STALE when a baselined file stops importing the UI', () {
      write('providers/fixed_provider.dart', "import 'dart:async';\n");
      File(
        baselinePath,
      ).writeAsStringSync('lib/providers/fixed_provider.dart\n');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('no longer import upward'));
      expect(result.stdout, contains('UPDATE_BASELINE=1'));
    });

    test('importing RoutePaths alone is exempt from Rule 1', () {
      write(
        'services/listener.dart',
        "import 'package:openvine/router/route_paths.dart';\n",
      );
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(0), reason: result.stdout.toString());
    });

    test('RoutePaths does not launder a second UI import in the same file', () {
      write(
        'services/listener.dart',
        "import 'package:openvine/router/route_paths.dart';\n"
            "import 'package:openvine/router/router.dart';\n",
      );
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('lib/services/listener.dart'));
    });

    test('fails when a route provider imports a screen (Rule 2)', () {
      write(
        'router/providers/redirect_provider.dart',
        "import 'package:openvine/screens/welcome_screen.dart';\n",
      );
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(
        result.stdout,
        contains('lib/router/providers/redirect_provider.dart'),
      );
    });

    test('fails when route_paths.dart stops being a leaf (Rule 3)', () {
      writeLeaf(clean: false);
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('must not import package:openvine'));
    });

    test('fails when route_paths.dart is missing entirely', () {
      libFile('router/route_paths.dart').deleteSync();
      File(baselinePath).writeAsStringSync('');

      final result = run();

      expect(result.exitCode, equals(1));
      expect(result.stdout, contains('is missing'));
    });

    test(
      'UPDATE_BASELINE records current violations and preserves reasons',
      () {
        write(
          'providers/bad_provider.dart',
          "import 'package:openvine/screens/settings_screen.dart';\n",
        );
        File(
          baselinePath,
        ).writeAsStringSync(
          'lib/providers/bad_provider.dart # keeps this note\n',
        );

        expect(run(update: true).exitCode, equals(0));

        final written = File(baselinePath).readAsStringSync();
        expect(written, contains('lib/providers/bad_provider.dart'));
        expect(written, contains('# keeps this note'));
        expect(run().exitCode, equals(0));
      },
    );

    test('fails closed when the base baseline cannot be loaded', () {
      // The growth ratchet is what stops a PR from adding a violation and
      // regenerating its way out of the failure. If the base baseline cannot
      // be read, the guard must fail rather than silently degrade to a
      // baseline-only check.
      write('providers/clean_provider.dart', "import 'dart:async';\n");
      File(baselinePath).writeAsStringSync('');

      final result = Process.runSync(
        'bash',
        [scriptPath],
        environment: {
          'LAYER_DIRECTION_LIB_DIR': '${tmp.path}/lib',
          'LAYER_DIRECTION_PATH_PREFIX': tmp.path,
          'LAYER_DIRECTION_BASELINE_FILE': baselinePath,
          'LAYER_DIRECTION_BASELINE_BASE_REF':
              'refs/heads/layer-direction-test-no-base-ref',
          'LAYER_DIRECTION_ALLOW_NO_BASE': '0',
        },
      );

      expect(result.exitCode, equals(1), reason: result.stdout.toString());
      expect(result.stdout, contains('failing closed'));
    });
  });
}
