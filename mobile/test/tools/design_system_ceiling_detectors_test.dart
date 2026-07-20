// ABOUTME: Tests for the four design-system drift ratchets (#6145) and the
// ABOUTME: shared Dart code-only filter their detectors run on first.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Drives the design-system ceiling ratchets against an isolated temp tree so
/// the detector semantics (#6145, epic #4339) are pinned without touching the
/// real baselines. The bash scripts are the source of truth; this test pins the
/// contract they promise in their headers — in particular that comments and
/// string literals never count, and that generic call sites do.
void main() {
  // Per-ratchet wiring: script name plus the env-var prefix it reads.
  const ratchets = <String, String>{
    'check_raw_textstyle_ceiling.sh': 'RAW_TEXTSTYLE',
    'check_raw_colors_ceiling.sh': 'RAW_COLORS',
    'check_material_button_ceiling.sh': 'MATERIAL_BUTTON',
    'check_raw_dialog_ceiling.sh': 'RAW_DIALOG',
  };

  // A code snippet that must count exactly once under the named ratchet.
  const oneRealMatch = <String, String>{
    'check_raw_textstyle_ceiling.sh': 'const s = TextStyle(fontSize: 12);',
    'check_raw_colors_ceiling.sh': 'const c = Color(0xFF00FF00);',
    'check_material_button_ceiling.sh':
        'final b = IconButton(onPressed: null);',
    'check_raw_dialog_ceiling.sh': 'final d = showDialog<void>(context: c);',
  };

  // Detector tokens embedded in places that must NEVER count: a trailing
  // comment, a block comment, and a string literal.
  const hidden = <String, List<String>>{
    'check_raw_textstyle_ceiling.sh': [
      'final a = 1; // migrated from TextStyle( to VineTheme',
      '/* legacy TextStyle( note\n   spanning lines */',
      "final m = 'TextStyle( appears in this log line';",
    ],
    'check_raw_colors_ceiling.sh': [
      'final a = 1; // was Color( before the VineTheme pass',
      '/* Color( in a block comment */',
      "final m = 'Colors.red is not a real usage';",
    ],
    'check_material_button_ceiling.sh': [
      'final a = 1; // replaced the ElevatedButton( here',
      '/* IconButton( in a block comment */',
      "final m = 'ElevatedButton( in a log string';",
    ],
    'check_raw_dialog_ceiling.sh': [
      'final a = 1; // replaced showDialog( with a full-screen flow',
      '/* showModalBottomSheet( in a block comment */',
      "final m = 'showDialog was skipped';",
    ],
  };

  late Directory tmp;
  late String baselinePath;

  File libFile(String name) => File('${tmp.path}/lib/$name');

  ProcessResult run(String script, String prefix, {bool update = false}) {
    return Process.runSync(
      'bash',
      [File('scripts/$script').absolute.path],
      environment: {
        '${prefix}_SCAN_DIR': '${tmp.path}/lib',
        '${prefix}_PATH_PREFIX': tmp.path,
        '${prefix}_BASELINE_FILE': baselinePath,
        '${prefix}_BASELINE_REPO_PATH': 'does/not/exist/baseline.txt',
        '${prefix}_BASELINE_BASE_REF': 'HEAD',
        if (update) 'UPDATE_BASELINE': '1',
      },
    );
  }

  List<String> baselineRows() => File(
    baselinePath,
  ).readAsLinesSync().where((l) => l.isNotEmpty && !l.startsWith('#')).toList();

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('ds_ceiling_test');
    Directory('${tmp.path}/lib').createSync(recursive: true);
    baselinePath = '${tmp.path}/baseline.txt';
  });

  tearDown(() {
    if (tmp.existsSync()) tmp.deleteSync(recursive: true);
  });

  group('design-system ceiling detectors', () {
    ratchets.forEach((script, prefix) {
      group(script, () {
        test('counts a real match once', () {
          libFile('a.dart').writeAsStringSync('${oneRealMatch[script]}\n');

          final res = run(script, prefix, update: true);
          expect(res.exitCode, 0, reason: res.stderr.toString());
          expect(baselineRows(), hasLength(1));
          expect(baselineRows().single, endsWith('\t1'));
        });

        test('ignores comments and string literals entirely', () {
          libFile(
            'a.dart',
          ).writeAsStringSync('${hidden[script]!.join('\n')}\n');

          final res = run(script, prefix, update: true);
          expect(res.exitCode, 0, reason: res.stderr.toString());
          expect(
            baselineRows(),
            isEmpty,
            reason: 'comment/string occurrences must not be counted',
          );
        });

        test('a benign comment or log string cannot trip GROWTH', () {
          libFile('a.dart').writeAsStringSync('${oneRealMatch[script]}\n');
          expect(run(script, prefix, update: true).exitCode, 0);

          // Same real usage, now surrounded by prose mentioning the token.
          libFile('a.dart').writeAsStringSync(
            '${oneRealMatch[script]}\n${hidden[script]!.join('\n')}\n',
          );

          final res = run(script, prefix);
          expect(
            res.exitCode,
            0,
            reason: 'false GROWTH from comments/strings: ${res.stdout}',
          );
        });

        test('real growth past the ceiling still fails', () {
          libFile('a.dart').writeAsStringSync('${oneRealMatch[script]}\n');
          expect(run(script, prefix, update: true).exitCode, 0);

          libFile('a.dart').writeAsStringSync(
            '${oneRealMatch[script]}\n${oneRealMatch[script]}\n',
          );

          final res = run(script, prefix);
          expect(res.exitCode, 1);
          expect(res.stdout, contains('GREW past the frozen ceiling'));
        });
      });
    });

    test('material-button detector catches generic and FAB call sites', () {
      libFile('a.dart').writeAsStringSync('''
final a = PopupMenuButton<String>(itemBuilder: (_) => []);
final b = FloatingActionButton(onPressed: null);
final c = FilledButton.tonalIcon(onPressed: null);
final d = DropdownButton<int>(items: const []);
''');

      final res = run(
        'check_material_button_ceiling.sh',
        'MATERIAL_BUTTON',
        update: true,
      );
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows().single, endsWith('\t4'));
    });

    test('material-button detector skips sanctioned divine_ui widgets', () {
      libFile('a.dart').writeAsStringSync('''
final a = DivineIconButton(onPressed: null);
final b = RoundedIconButton(onPressed: null);
final c = AuthBackButton(onPressed: null);
final d = ElevatedButton.styleFrom(backgroundColor: null);
''');

      final res = run(
        'check_material_button_ceiling.sh',
        'MATERIAL_BUTTON',
        update: true,
      );
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows(), isEmpty);
    });

    test('dialog detector catches modal Route constructions', () {
      libFile('a.dart').writeAsStringSync('''
final r = DialogRoute<void>(context: c, builder: (_) => const Text('x'));
final s = ModalBottomSheetRoute<void>(builder: (_) => const Text('y'));
''');

      final res = run(
        'check_raw_dialog_ceiling.sh',
        'RAW_DIALOG',
        update: true,
      );
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows().single, endsWith('\t2'));
    });

    test('dialog detector skips wrapper names and full-screen helpers', () {
      libFile('a.dart').writeAsStringSync('''
void showForgotPasswordDialog() {}
final p = showLicensePage(context: c);
''');

      final res = run(
        'check_raw_dialog_ceiling.sh',
        'RAW_DIALOG',
        update: true,
      );
      expect(res.exitCode, 0, reason: res.stderr.toString());
      expect(baselineRows(), isEmpty);
    });
  });

  group('dart_code_only.awk', () {
    // Runs the shared filter over [source] and returns its output.
    String filter(String source) {
      final f = File('${tmp.path}/lib/in.dart')..writeAsStringSync(source);
      final res = Process.runSync(
        'awk',
        ['-f', File('scripts/lib/dart_code_only.awk').absolute.path, f.path],
      );
      expect(res.exitCode, 0, reason: res.stderr.toString());
      return res.stdout as String;
    }

    test('keeps code that follows a URL on the same line', () {
      // A naive `sed 's|//.*||'` truncates at the URL's `//` and silently drops
      // the real TextStyle( — an undercount that would let drift through.
      final out = filter(
        "Text('https://divine.video', style: TextStyle(fontSize: 12));\n",
      );
      expect(out, contains('TextStyle('));
    });

    test('does not treat a // inside a string as a comment', () {
      final out = filter("if (uri.path.startsWith('//')) return Color(0);\n");
      expect(out, contains('Color('));
    });

    test('preserves interpolated expressions', () {
      final out = filter("final s = 'c=\${Colors.red}';\n");
      expect(out, contains('Colors.red'));
    });

    test('strips raw and triple-quoted string bodies', () {
      final out = filter('''
final r = r'raw showDialog( text';
final t = """
  ElevatedButton( inside a triple-quoted string
""";
''');
      expect(out, isNot(contains('showDialog(')));
      expect(out, isNot(contains('ElevatedButton(')));
    });

    test('strips nested block comments', () {
      final out = filter('/* outer /* inner TextStyle( */ still comment */\n');
      expect(out, isNot(contains('TextStyle(')));
    });
  });
}
