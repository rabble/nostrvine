// ABOUTME: Guards ICU plural arms against hardcoding a literal number.
// ABOUTME: A hardcoded digit renders the WRONG count wherever the arm can fire
// ABOUTME: for a value other than that digit (fr/am/pt at n=0, fil at most n).

import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart' as intl;
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Categories that `Intl.pluralLogic` resolves by exact value before consulting
/// the CLDR rule, and the value each one matches.
///
/// `gen-l10n` compiles ARB `=0`/`=1`/`=2` down to the `zero:`/`one:`/`two:`
/// arguments, so the ARB spelling of an arm does not change its behaviour —
/// only which argument it lands in.
const _exactValueArms = <String, String>{
  '=0': '0',
  'zero': '0',
  '=2': '2',
  'two': '2',
};

void main() {
  group('ICU plural arms', () {
    final arbFiles =
        Directory('lib/l10n')
            .listSync()
            .whereType<File>()
            .where((file) => file.path.endsWith('.arb'))
            .toList()
          ..sort((a, b) => a.path.compareTo(b.path));

    test('never hardcode a number in an arm that can fire for other counts', () {
      final offenders = <String>[];

      for (final file in arbFiles) {
        final locale = _localeOf(file);
        // Derived, not hardcoded: ask intl itself which counts reach `one` in
        // this locale. French/Amharic/Portuguese `one` covers {0, 1}; Filipino
        // `one` covers most integers. Anywhere else it is exactly {1}.
        final oneIsExact = _countsSelectingOne(locale).every((n) => n == 1);

        final arb = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        for (final entry in arb.entries) {
          if (entry.key.startsWith('@')) continue;
          final value = entry.value;
          if (value is! String) continue;

          for (final arm in _pluralArms(value)) {
            if (!RegExp(r'\d').hasMatch(arm.text)) continue;
            // Interpolating the placeholder is always safe.
            if (RegExp(r'\{\w+\}').hasMatch(arm.text)) continue;
            final digits = RegExp(
              r'\d+',
            ).allMatches(arm.text).map((m) => m[0]).toList();
            final exact = _exactValueArms[arm.category];
            if (exact != null && digits.length == 1 && digits.single == exact) {
              continue;
            }
            if ((arm.category == '=1' || arm.category == 'one') && oneIsExact) {
              continue;
            }
            offenders.add(
              '${file.path} :: ${entry.key} :: ${arm.category}{${arm.text}}',
            );
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason:
            'These ICU plural arms hardcode a number but can be selected for a '
            'different count, so they render a false number. Interpolate the '
            'placeholder instead — e.g. one{1 personne} -> one{{count} personne}.\n'
            '${offenders.join('\n')}',
      );
    });

    test('render the real count in every locale whose `one` is not exactly 1', () {
      // Regression pins for the four locales that were shipping wrong numbers.
      // fr/am/pt selected `one` at n=0; fil selects `one` for most integers.
      const cases = <String, List<int>>{
        'fr': [0, 2, 22],
        'am': [0, 2, 22],
        'pt': [0, 2, 22],
        'fil': [0, 2, 5, 22, 100],
      };

      for (final entry in cases.entries) {
        final l10n = lookupAppLocalizations(Locale(entry.key));
        for (final count in entry.value) {
          expect(
            l10n.listPersonCount(count),
            contains('$count'),
            reason:
                '${entry.key}: listPersonCount($count) must show $count, not a '
                'hardcoded 1 — got "${l10n.listPersonCount(count)}"',
          );
          expect(
            l10n.notificationsBadgeUnread(count),
            contains('$count'),
            reason:
                '${entry.key}: notificationsBadgeUnread($count) must show '
                '$count — got "${l10n.notificationsBadgeUnread(count)}"',
          );
        }
      }
    });
  });
}

String _localeOf(File file) {
  final name = file.uri.pathSegments.last; // app_<locale>.arb
  return name.substring('app_'.length, name.length - '.arb'.length);
}

/// The counts in 0..200 for which [locale] selects the `one` arm, given the
/// common `one` + `other` arm set. Probing the real [intl.Intl.pluralLogic]
/// keeps this test correct when the bundled CLDR data changes.
Iterable<int> _countsSelectingOne(String locale) sync* {
  for (var n = 0; n <= 200; n++) {
    final selected = intl.Intl.pluralLogic<String>(
      n,
      locale: locale,
      one: 'one',
      other: 'other',
    );
    if (selected == 'one') yield n;
  }
}

class _PluralArm {
  const _PluralArm(this.category, this.text);
  final String category;
  final String text;
}

/// Splits the first `{name, plural, ...}` block of [value] into its arms.
Iterable<_PluralArm> _pluralArms(String value) sync* {
  final header = RegExp(r'\{\s*\w+\s*,\s*plural\s*,').firstMatch(value);
  if (header == null) return;

  final body = value.substring(header.end);
  final armHead = RegExp(r'^\s*(=\d+|zero|one|two|few|many|other)\s*\{');
  var cursor = 0;
  while (cursor < body.length) {
    final head = armHead.firstMatch(body.substring(cursor));
    if (head == null) return;

    var index = cursor + head.end;
    final start = index;
    var depth = 1;
    while (index < body.length && depth > 0) {
      if (body[index] == '{') {
        depth++;
      } else if (body[index] == '}') {
        depth--;
      }
      index++;
    }
    yield _PluralArm(head.group(1)!, body.substring(start, index - 1));
    cursor = index;
  }
}
