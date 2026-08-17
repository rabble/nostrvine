// ABOUTME: Tests the theme-migration guard that pins dark values across a diff.
// ABOUTME: Pins pairing, alpha-override equivalence, and the Font-default class.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

/// Drives `scripts/check_dark_value_parity.dart` against synthetic diffs.
///
/// The guard's whole job is to answer "did dark mode change?" without a human
/// reading 450 files, so what matters is that an unequal replacement fails,
/// that the equivalences the migration actually relied on (an alpha override
/// rewritten as a token that bakes the same alpha in) do NOT fail, and that
/// identifiers which merely look like colors never enter the pairing.
void main() {
  group('check_dark_value_parity.dart', () {
    late Directory sandbox;
    late String scriptPath;
    late String themePath;

    // A miniature VineTheme: two literals, one alias, one Colors.* alias, and
    // a darkColors block wiring tokens onto them.
    const themeSource = '''
class VineTheme {
  static const Color whiteText = Colors.white;
  static const Color backgroundColor = Color(0xFF000000);
  static const Color navGreen = Color(0xFF00150D);
  static const Color iconButtonBackground = Color(0xFF032017);
  static const Color skeletonBase = iconButtonBackground;
  static const Color onSurfaceDisabled = Color(0x40FFFFFF);

  static TextStyle bodyMediumFont({Color? color}) => const TextStyle();

  static const VineThemeColors darkColors = VineThemeColors(
    primaryText: whiteText,
    surface: navGreen,
    skeleton: skeletonBase,
    disabled: onSurfaceDisabled,
    background: backgroundColor,
  );
}
''';

    ProcessResult run(String diff) {
      final diffFile = File(p.join(sandbox.path, 'change.patch'))
        ..writeAsStringSync(diff);
      return Process.runSync('dart', [
        'run',
        scriptPath,
        '--theme',
        themePath,
        '--diff',
        diffFile.path,
      ], workingDirectory: sandbox.path);
    }

    void git(List<String> arguments) {
      final res = Process.runSync(
        'git',
        arguments,
        workingDirectory: sandbox.path,
      );
      expect(res.exitCode, 0, reason: 'git ${arguments.join(' ')}');
    }

    /// Commits a `main` root in the sandbox so a base ref exists to diff from.
    void initRepo() {
      git(['init', '--initial-branch=main']);
      git(['config', 'user.email', 'test@example.com']);
      git(['config', 'user.name', 'Test']);
      File(p.join(sandbox.path, 'a.dart')).writeAsStringSync('// base\n');
      git(['add', '.']);
      git(['commit', '-m', 'base']);
    }

    setUp(() {
      sandbox = Directory.systemTemp.createTempSync('dark_parity_');
      themePath = p.join(sandbox.path, 'vine_theme.dart');
      File(themePath).writeAsStringSync(themeSource);
      scriptPath = File(
        p.join('scripts', 'check_dark_value_parity.dart'),
      ).absolute.path;
    });

    tearDown(() {
      if (sandbox.existsSync()) sandbox.deleteSync(recursive: true);
    });

    test('accepts a replacement whose dark value is unchanged', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      color: VineTheme.navGreen,
+      color: context.vineColors.surface,
''');

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('1 replacement(s) compared'));
      expect(res.stdout, contains('0 dark mismatch(es)'));
    });

    test('fails a replacement that changes the dark value', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      color: VineTheme.backgroundColor,
+      color: context.vineColors.surface,
''');

      expect(res.exitCode, 1);
      expect(res.stdout, contains('DARK MISMATCH'));
      expect(res.stdout, contains('lib/a.dart'));
      expect(res.stdout, contains('#FF000000'));
      expect(res.stdout, contains('#FF00150D'));
    });

    test('treats a baked-in alpha as equal to an explicit override', () {
      // The shape the migration used everywhere: white-at-25% rewritten as the
      // token that already carries that alpha.
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      color: VineTheme.whiteText.withValues(alpha: 0.25),
+      color: context.vineColors.disabled,
''');

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('0 dark mismatch(es)'));
    });

    test('binds an alpha override wrapped onto the next line', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10,3 @@
-      color: VineTheme.onSurfaceDisabled,
+      color: (style.foregroundColor ?? context.vineColors.primaryText)
+          .withValues(alpha: 0.25),
''');

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('1 replacement(s) compared'));
    });

    test('resolves aliases, including chained ones', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      color: VineTheme.iconButtonBackground,
+      color: context.vineColors.skeleton,
''');

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('1 replacement(s) compared'));
    });

    test('never mistakes a Font helper for a color', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      style: VineTheme.bodyMediumFont(),
+      style: VineTheme.bodyMediumFont(color: context.vineColors.primaryText),
''');

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(
        res.stdout,
        isNot(contains('bodyMediumFont')),
        reason: 'A Font helper is not a color and must not enter the pairing.',
      );
    });

    test('checks a Font call that replaced the removed whiteText default', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      style: VineTheme.bodyMediumFont(),
+      style: VineTheme.bodyMediumFont(color: context.vineColors.primaryText),
''');

      expect(res.exitCode, 0, reason: res.stdout.toString());
      expect(res.stdout, contains('1 removed Font default(s) made explicit'));
    });

    test('fails a Font default replaced by a different dark value', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10 +10 @@
-      style: VineTheme.bodyMediumFont(),
+      style: VineTheme.bodyMediumFont(color: context.vineColors.disabled),
''');

      expect(res.exitCode, 1);
      expect(res.stdout, contains('implicit whiteText default'));
    });

    test('reports an unbalanced hunk instead of guessing', () {
      final res = run('''
+++ b/lib/a.dart
@@ -10,2 +10 @@
-      color: VineTheme.navGreen,
-      shadowColor: VineTheme.backgroundColor,
+      color: context.vineColors.surface,
''');

      expect(res.exitCode, 0, reason: 'unpaired is a warning, not a failure');
      expect(res.stdout, contains('SKIP'));
      expect(res.stdout, contains('needs a human'));
      expect(res.stdout, contains('1 left for manual review'));
    });

    test('fails closed when the theme file is missing', () {
      final res = Process.runSync('dart', [
        'run',
        scriptPath,
        '--theme',
        p.join(sandbox.path, 'nope.dart'),
        '--diff',
        p.join(sandbox.path, 'nope.patch'),
      ], workingDirectory: sandbox.path);

      expect(res.exitCode, 2);
      expect(res.stderr, contains('Theme file not found'));
    });

    // A shallow clone has no merge base with its own base ref. The guard used
    // to fall back to a two-dot diff there, which reads every commit the base
    // has and HEAD lacks as a removal — pairing unrelated work against this
    // branch's additions and reporting confident, wrong DARK MISMATCH lines.
    // Two orphan roots reproduce "no merge base" without a shallow fixture.
    test('refuses to guess when the base shares no history with HEAD', () {
      initRepo();

      git(['checkout', '--orphan', 'unrelated']);
      File(p.join(sandbox.path, 'a.dart')).writeAsStringSync('// other\n');
      git(['add', '.']);
      git(['commit', '-m', 'unrelated root']);

      final res = Process.runSync('dart', [
        'run',
        scriptPath,
        '--theme',
        themePath,
        '--base',
        'main',
      ], workingDirectory: sandbox.path);

      expect(res.exitCode, 2);
      expect(res.stderr, contains('No merge base between main and HEAD'));
      expect(res.stderr, contains('git fetch --unshallow'));
      expect(res.stdout, isNot(contains('DARK MISMATCH')));
    });

    // A missing or misspelled base ref is a different failure than a missing
    // merge base: git merge-base exits 128, not 1. Blaming a shallow clone
    // and suggesting `git fetch --unshallow` sends the reader after a fix
    // that cannot resolve a ref that was never there. Surface git's error.
    test('surfaces the git error when the base ref does not exist', () {
      initRepo();

      final res = Process.runSync('dart', [
        'run',
        scriptPath,
        '--theme',
        themePath,
        '--base',
        'no-such-ref',
      ], workingDirectory: sandbox.path);

      expect(res.exitCode, 2);
      expect(res.stderr, contains('git merge-base failed'));
      expect(res.stderr, isNot(contains('shallow clone')));
    });
  });
}
