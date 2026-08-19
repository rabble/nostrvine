// ABOUTME: Lists app_en.arb keys that look countable but carry no ICU plural.
// ABOUTME: A flat countable key still renders the number — it just stops
// ABOUTME: inflecting the noun, shipping text like "1 videos" (#3633).

import 'dart:convert';
import 'dart:io';

/// Matches an interpolation of [name], e.g. `{count}` or `{ count }`.
///
/// Deliberately does NOT match the selector form `{count, plural, ...}`: that
/// is the shape we are checking *for*, not an interpolation.
RegExp _interpolation(String name) =>
    RegExp(r'\{\s*' + RegExp.escape(name) + r'\s*\}');

final _pluralSelector = RegExp(r'\{\s*\w+\s*,\s*plural\s*,');

/// Whether [key] with a placeholder of [declaredType] reads as a quantity.
///
/// The numeric-type test is the reliable one. The name test exists because a
/// count can legitimately be typed `String` when the display value is
/// pre-formatted (`1.2K`); those keys select the plural on a sibling `int`
/// placeholder instead, and are named `...Count` by convention.
bool _looksCountable(String key, String? declaredType) =>
    declaredType == 'int' ||
    declaredType == 'num' ||
    declaredType == 'double' ||
    key.endsWith('Count');

/// Returns the sorted keys of [arb] that interpolate a countable placeholder
/// but express no ICU plural.
///
/// A key is exempt as soon as its value carries any `{x, plural, ...}`
/// selector — the selector need not be on the countable placeholder itself,
/// because a value can legitimately select on one argument while displaying
/// another (see `analyticsViewsCount`).
List<String> findCountableFlatKeys(Map<String, dynamic> arb) {
  final offenders = <String>[];

  for (final entry in arb.entries) {
    final key = entry.key;
    if (key.startsWith('@')) continue;
    final value = entry.value;
    if (value is! String) continue;
    if (_pluralSelector.hasMatch(value)) continue;

    final meta = arb['@$key'];
    final placeholders = meta is Map ? meta['placeholders'] : null;
    if (placeholders is! Map) continue;

    for (final ph in placeholders.entries) {
      final name = ph.key.toString();
      if (!_interpolation(name).hasMatch(value)) continue;
      final spec = ph.value;
      final type = (spec is Map ? spec['type'] : null)?.toString();
      if (_looksCountable(key, type)) {
        offenders.add(key);
        break;
      }
    }
  }

  return offenders..sort();
}

void main(List<String> args) {
  final detail = args.contains('--detail');
  final path = args.firstWhere(
    (a) => !a.startsWith('--'),
    orElse: () => 'lib/l10n/app_en.arb',
  );

  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('countable_flat_arb_detector: no such file: $path');
    exit(2);
  }

  final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  for (final key in findCountableFlatKeys(arb)) {
    stdout.writeln(detail ? '$key\t${arb[key]}' : key);
  }
}
