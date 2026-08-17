// ABOUTME: Verifies a theme migration diff keeps dark mode pixel-identical by
// ABOUTME: pairing each removed color reference with its replacement per hunk.
//
// Usage (from mobile/):
//   dart run scripts/check_dark_value_parity.dart
//   dart run scripts/check_dark_value_parity.dart --base origin/main
//   dart run scripts/check_dark_value_parity.dart --diff /tmp/d.patch
//
// Why this exists
// ---------------
// The semantic-token migration (#6404) replaced ~450 files' worth of static
// `VineTheme.<constant>` references with `context.vineColors.<token>` lookups.
// The load-bearing claim is that dark mode is unchanged, which holds only if
// every replacement's DARK value equals the constant it replaced. Asserting
// that by reading the diff does not scale and does not survive the next pass;
// this checks it mechanically. It caught two real regressions on its first
// run: `invites_screen` had its Scaffold and AppBar backgrounds swapped by two
// passes landing on adjacent lines, and `outlinedDisabled` (#032017) vs
// `outlineDisabled` (#001A12) turned out to be two different constants that a
// mapping table had conflated, darkening five editor dividers.
//
// What it structurally CANNOT catch
// ---------------------------------
// It compares DARK values only, so any two tokens that share a dark value are
// interchangeable as far as it is concerned — picking one where the other
// belonged passes here and diverges only in light mode. That blind spot is not
// hypothetical: five token pairs collide in dark today, and the inventory is
// frozen in `packages/divine_ui/test/src/theme/vine_theme_light_palette_test.dart`
// so widening it has to be deliberate. It also cannot judge a replacement that
// is *new* colour rather than a substitution — an added line with no removed
// counterpart is reported as unpaired, not as correct.
//
// Exit codes: 0 clean, 1 mismatches found, 2 could not run.

import 'dart:io';

/// Material colors referenced by name from the theme file.
const _materialColors = <String, int>{
  'white': 0xFFFFFFFF,
  'black': 0xFF000000,
  'transparent': 0x00000000,
};

final _colorLiteral = RegExp(
  r'static const Color (\w+) = Color\(0x([0-9A-Fa-f]{8})\);',
);
final _colorAlias = RegExp(r'static const Color (\w+) = (\w+);');
final _colorMaterialAlias = RegExp(
  r'static const Color (\w+) = Colors\.(\w+);',
);
final _darkEntry = RegExp(r'^\s*(\w+):\s*(\w+),\s*$');
final _darkLiteralEntry = RegExp(
  r'^\s*(\w+):\s*Color\(0x([0-9A-Fa-f]{8})\),\s*$',
);

/// A `VineTheme.foo` constant or a `<something>.vineColors.foo` token.
final _reference = RegExp(
  r'VineTheme\.(\w+)'
  r'|(?:vineColors|colors|_colors|palette)\.(\w+)',
);

class ThemePalette {
  ThemePalette(this.constants, this.darkTokens);

  /// `VineTheme.<name>` → dark ARGB.
  final Map<String, int> constants;

  /// `<token>` on `VineTheme.darkColors` → dark ARGB.
  final Map<String, int> darkTokens;

  /// Resolves a reference to the dark ARGB it actually paints, applying any
  /// alpha the call site forces. Null when the name is something this checker
  /// cannot see (a local variable, a non-color static).
  int? resolve(Reference reference) {
    final base = reference.isToken
        ? darkTokens[reference.name]
        : constants[reference.name];
    if (base == null) return null;
    final alpha = reference.alphaOverride;
    if (alpha == null) return base;
    final channel = (alpha * 255).round().clamp(0, 255);
    return (base & 0x00FFFFFF) | (channel << 24);
  }
}

class Reference {
  Reference(this.name, {required this.isToken, this.alphaOverride});

  final String name;
  final bool isToken;

  /// Alpha the call site forces on the token via `.withValues(alpha: …)` or
  /// the legacy `.withOpacity(…)`. Two references that name different tokens
  /// still paint the same pixel when both end up at the same RGB and alpha,
  /// which is how most of this migration's "white at 25%" sites were rewritten.
  final double? alphaOverride;

  @override
  String toString() {
    final base = isToken ? 'vineColors.$name' : 'VineTheme.$name';
    return alphaOverride == null ? base : '$base@$alphaOverride';
  }
}

/// Parses the constants and the `darkColors` block out of the theme source.
ThemePalette parsePalette(String source) {
  final constants = <String, int>{};
  final aliases = <String, String>{};

  for (final line in source.split('\n')) {
    final literal = _colorLiteral.firstMatch(line);
    if (literal != null) {
      constants[literal.group(1)!] = int.parse(literal.group(2)!, radix: 16);
      continue;
    }
    final material = _colorMaterialAlias.firstMatch(line);
    if (material != null) {
      final value = _materialColors[material.group(2)!];
      if (value != null) constants[material.group(1)!] = value;
      continue;
    }
    final alias = _colorAlias.firstMatch(line);
    if (alias != null) aliases[alias.group(1)!] = alias.group(2)!;
  }

  // Aliases can chain (skeletonBase = iconButtonBackground); settle them.
  var changed = true;
  while (changed) {
    changed = false;
    aliases.forEach((name, target) {
      if (constants.containsKey(name)) return;
      final value = constants[target];
      if (value != null) {
        constants[name] = value;
        changed = true;
      }
    });
  }

  final darkTokens = <String, int>{};
  final start = source.indexOf('darkColors = VineThemeColors(');
  if (start >= 0) {
    final end = source.indexOf(');', start);
    for (final line in source.substring(start, end).split('\n')) {
      final literal = _darkLiteralEntry.firstMatch(line);
      if (literal != null) {
        darkTokens[literal.group(1)!] = int.parse(literal.group(2)!, radix: 16);
        continue;
      }
      final entry = _darkEntry.firstMatch(line);
      if (entry == null) continue;
      final value = constants[entry.group(2)!];
      if (value != null) darkTokens[entry.group(1)!] = value;
    }
  }

  return ThemePalette(constants, darkTokens);
}

final _alphaOverride = RegExp(
  r'\.with(?:Values\(\s*alpha:\s*|Opacity\()([0-9]*\.?[0-9]+)',
);

/// Every color reference in [text], in source order.
///
/// [text] is a whole diff side rather than a single line, so an alpha override
/// that the formatter wrapped onto the following line still binds to its
/// reference. An override binds to the last reference before it.
///
/// [known] is every identifier that names a color in either palette. Filtering
/// on it is what keeps `VineTheme.bodyMediumFont` — same shape, not a color —
/// out of the pairing, along with unrelated `colors.length`-style members.
List<Reference> referencesIn(String text, Set<String> known) {
  final matches = _reference.allMatches(text).toList();
  return [
    for (var i = 0; i < matches.length; i++)
      if (known.contains(matches[i].group(1) ?? matches[i].group(2)!))
        Reference(
          matches[i].group(1) ?? matches[i].group(2)!,
          isToken: matches[i].group(1) == null,
          alphaOverride: _alphaFor(
            text.substring(
              matches[i].end,
              i + 1 < matches.length ? matches[i + 1].start : text.length,
            ),
          ),
        ),
  ];
}

double? _alphaFor(String tail) {
  final match = _alphaOverride.firstMatch(tail);
  return match == null ? null : double.tryParse(match.group(1)!);
}

class Finding {
  Finding(this.file, this.hunk, this.message);

  final String file;
  final String hunk;
  final String message;

  @override
  String toString() => '$file $hunk\n    $message';
}

class Report {
  final List<Finding> mismatches = [];
  final List<Finding> unpaired = [];
  int compared = 0;

  /// Font call sites that gained an explicit color where they previously
  /// inherited `VineTheme.*Font`'s removed `whiteText` default.
  int defaultsMadeExplicit = 0;
}

/// Walks a unified diff, pairing removed references with added ones per hunk.
///
/// Pairing is by ORDER WITHIN THE HUNK rather than by line, so a replacement
/// that also reflows the line still pairs up. When the two sides carry a
/// different number of references the hunk is reported as unpaired instead of
/// guessed at — that is the shape a genuine addition or deletion takes.
Report analyzeDiff(
  String diff,
  ThemePalette palette, {
  ThemePalette? basePalette,
}) {
  // The removed side names constants as they existed BEFORE the diff — a
  // constant this PR deleted is only resolvable against the base theme.
  final before = basePalette ?? palette;
  final known = {
    ...palette.constants.keys,
    ...palette.darkTokens.keys,
    ...before.constants.keys,
    ...before.darkTokens.keys,
  };
  final report = Report();
  var file = '<unknown>';
  var hunk = '';
  var removedText = '';
  var addedText = '';

  void flush() {
    final removed = referencesIn(removedText, known);
    final added = referencesIn(addedText, known);
    // Both sides must carry a Font( for this to be a default-replacement: a
    // pure-addition hunk is new code, not a rewritten default, and pairing it
    // against whiteText invents a finding (a refactor that moves a styled
    // branch shows up exactly like that).
    final rewroteFontDefault =
        addedText.contains('Font(') && removedText.contains('Font(');
    removedText = '';
    addedText = '';
    if (removed.isEmpty && added.isEmpty) return;

    // The migration also removed VineTheme.*Font's `color` default, so a Font
    // call that names a color where it previously named none is a replacement
    // of that default. Its dark value has to equal the default's — whiteText.
    if (removed.isEmpty && rewroteFontDefault) {
      final wasImplicit = before.constants['whiteText'];
      for (final reference in added) {
        final now = palette.resolve(reference);
        if (wasImplicit == null || now == null) continue;
        report.defaultsMadeExplicit++;
        if (was_(wasImplicit, reference) != now) {
          report.mismatches.add(
            Finding(
              file,
              hunk,
              'implicit whiteText default (${_hex(wasImplicit)}) -> '
              '$reference (${_hex(now)})',
            ),
          );
        }
      }
      return;
    }

    if (removed.length != added.length) {
      if (removed.isNotEmpty || added.isNotEmpty) {
        report.unpaired.add(
          Finding(
            file,
            hunk,
            'removed ${removed.join(', ')} '
            'but added ${added.isEmpty ? '(nothing)' : added.join(', ')} '
            '— needs a human',
          ),
        );
      }
    } else {
      for (var i = 0; i < removed.length; i++) {
        final was = before.resolve(removed[i]);
        final now = palette.resolve(added[i]);
        if (was == null || now == null) {
          report.unpaired.add(
            Finding(
              file,
              hunk,
              '${removed[i]} -> ${added[i]} — '
              'could not resolve ${was == null ? removed[i] : added[i]}',
            ),
          );
          continue;
        }
        report.compared++;
        if (was != now) {
          report.mismatches.add(
            Finding(
              file,
              hunk,
              '${removed[i]} (${_hex(was)}) -> '
              '${added[i]} (${_hex(now)})',
            ),
          );
        }
      }
    }
  }

  for (final line in diff.split('\n')) {
    if (line.startsWith('+++ b/')) {
      flush();
      file = line.substring(6);
      continue;
    }
    if (line.startsWith('--- ') || line.startsWith('diff --git')) continue;
    if (line.startsWith('@@')) {
      flush();
      hunk = line.split('@@').length > 1 ? '@@${line.split('@@')[1]}@@' : line;
      continue;
    }
    if (line.startsWith('-')) {
      removedText += '${line.substring(1)}\n';
    } else if (line.startsWith('+')) {
      addedText += '${line.substring(1)}\n';
    }
  }
  flush();
  return report;
}

/// The implicit default carried the call site's own alpha override, if any.
int was_(int implicitDefault, Reference reference) {
  final alpha = reference.alphaOverride;
  if (alpha == null) return implicitDefault;
  final channel = (alpha * 255).round().clamp(0, 255);
  return (implicitDefault & 0x00FFFFFF) | (channel << 24);
}

String _hex(int argb) =>
    '#${argb.toRadixString(16).toUpperCase().padLeft(8, '0')}';

String _argument(List<String> args, String name) {
  final index = args.indexOf(name);
  return index >= 0 && index + 1 < args.length ? args[index + 1] : '';
}

void main(List<String> args) {
  final themeArgument = _argument(args, '--theme');
  final themePath = themeArgument.isEmpty
      ? 'packages/divine_ui/lib/src/theme/vine_theme.dart'
      : themeArgument;
  final themeFile = File(themePath);
  if (!themeFile.existsSync()) {
    stderr.writeln('Theme file not found: $themePath (run from mobile/)');
    exit(2);
  }
  final palette = parsePalette(themeFile.readAsStringSync());
  if (palette.darkTokens.isEmpty) {
    stderr.writeln('Could not parse darkColors out of $themePath');
    exit(2);
  }

  final baseArgument = _argument(args, '--base');
  final base = baseArgument.isEmpty ? 'origin/main' : baseArgument;

  final String diff;
  ThemePalette? basePalette;
  final diffArgument = _argument(args, '--diff');
  if (diffArgument.isNotEmpty) {
    diff = File(diffArgument).readAsStringSync();
  } else {
    // Three-dot isolates what this branch changed, and needs a merge base —
    // which a shallow clone (CI, and any `--depth` worktree) may not have.
    // Two-dot still runs there, but answers a different question: every
    // commit the base has and HEAD lacks reads as a removal, so unrelated
    // work gets paired against this branch's additions and reported as dark
    // mismatches. A guard that quietly returns wrong answers is worse than
    // one that refuses, so refuse.
    final mergeBase = Process.runSync('git', ['merge-base', base, 'HEAD']);
    // merge-base exits 1 for a genuine no-common-ancestor (the shallow
    // clone / unrelated-history case) and 128 for an error like a missing
    // or misspelled ref. Only the first is "no merge base" — sending an
    // unfetched origin/main to `git fetch --unshallow` points at a fix
    // that cannot work, so surface git's real error for the rest.
    if (mergeBase.exitCode == 1) {
      stderr.writeln(
        "No merge base between $base and HEAD, so this branch's own "
        'changes cannot be isolated.\n'
        'This is usually a shallow clone. Pick one:\n'
        '  git fetch --unshallow      then rerun\n'
        '  --base <branch-point-sha>  the commit this branch started from\n'
        '  --diff <patch>             a diff you produced yourself',
      );
      exit(2);
    }
    if (mergeBase.exitCode != 0) {
      stderr.writeln('git merge-base failed: ${mergeBase.stderr}');
      exit(2);
    }
    final result = Process.runSync('git', [
      'diff',
      '-U0',
      '$base...HEAD',
      '--',
      '*.dart',
    ]);
    if (result.exitCode != 0) {
      stderr.writeln('git diff failed: ${result.stderr}');
      exit(2);
    }
    diff = result.stdout as String;

    // Constants this branch deleted still have to resolve on the removed side.
    final baseTheme = Process.runSync('git', [
      'show',
      '$base:mobile/${themePath.replaceAll(r'\', '/')}',
    ]);
    if (baseTheme.exitCode == 0) {
      basePalette = parsePalette(baseTheme.stdout as String);
    } else {
      stdout.writeln(
        'NOTE: could not read the theme file at $base; constants this branch '
        'deleted will be reported as unresolvable.',
      );
    }
  }

  final report = analyzeDiff(diff, palette, basePalette: basePalette);

  for (final finding in report.unpaired) {
    stdout.writeln('SKIP $finding');
  }
  for (final finding in report.mismatches) {
    stdout.writeln('DARK MISMATCH $finding');
  }
  stdout.writeln(
    '\n${report.compared} replacement(s) compared, '
    '${report.defaultsMadeExplicit} removed Font default(s) made explicit, '
    '${report.mismatches.length} dark mismatch(es), '
    '${report.unpaired.length} left for manual review.',
  );
  if (report.mismatches.isNotEmpty) {
    stdout.writeln(
      'A mismatch means dark mode changed. Reported pairs with equal dark '
      'values can still be wrong in LIGHT mode — see the header comment.',
    );
    exit(1);
  }
}
