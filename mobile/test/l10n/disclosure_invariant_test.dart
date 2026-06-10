// ABOUTME: Pins the content-policy disclosure invariant: the app must never
// ABOUTME: tell a user they have been blocked or muted by another user.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Phrases that would reveal a block/mute relationship to the blocked user.
///
/// The disclosure invariant (see
/// `docs/superpowers/specs/2026-04-23-content-policy-layer-design.md`)
/// requires plausible deniability: gating is *absence* of content or
/// affordances, never an explanation. Copy about the user's own blocks
/// ("Blocked users", "Block user", "You blocked …") is fine — these
/// patterns target the other direction only.
final _forbiddenPatterns = [
  RegExp('blocked you', caseSensitive: false),
  RegExp('blocks you', caseSensitive: false),
  RegExp('has blocked', caseSensitive: false),
  RegExp('blocked by', caseSensitive: false),
  RegExp('muted you', caseSensitive: false),
  RegExp('mutes you', caseSensitive: false),
  RegExp('not accepting', caseSensitive: false),
];

/// Matches single- or double-quoted Dart string literals on one line.
/// Applied per line (comment lines excluded) so apostrophes in doc
/// comments cannot open a phantom multi-line "literal".
final _stringLiteral = RegExp(
  "'(?:[^'\\\\\\n]|\\\\.)*'|\"(?:[^\"\\\\\\n]|\\\\.)*\"",
);

List<String> _violationsIn(String content, {required bool literalsOnly}) {
  if (!literalsOnly) {
    return [
      for (final pattern in _forbiddenPatterns)
        if (pattern.hasMatch(content)) 'matches "${pattern.pattern}"',
    ];
  }
  final violations = <String>[];
  final lines = content.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (line.trimLeft().startsWith('//')) continue;
    for (final literal in _stringLiteral.allMatches(line)) {
      final haystack = literal.group(0)!;
      for (final pattern in _forbiddenPatterns) {
        if (pattern.hasMatch(haystack)) {
          violations.add(
            'line ${i + 1}: $haystack matches "${pattern.pattern}"',
          );
        }
      }
    }
  }
  return violations;
}

List<String> _violationsInArbFile(File file) {
  final arb = (jsonDecode(file.readAsStringSync()) as Map)
      .cast<String, Object?>();
  final violations = <String>[];

  for (final entry in arb.entries) {
    final value = entry.value;
    if (entry.key.startsWith('@') || value is! String) continue;

    for (final violation in _violationsIn(
      value,
      literalsOnly: false,
    )) {
      violations.add('${entry.key}: $violation');
    }
  }

  return violations;
}

void main() {
  group('disclosure invariant', () {
    test('localized copy never reveals a block/mute relationship', () {
      final arbFiles = Directory('lib/l10n')
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.arb'))
          .toList();
      expect(arbFiles, isNotEmpty, reason: 'expected ARB files in lib/l10n');

      final violations = <String>[
        for (final file in arbFiles)
          for (final v in _violationsInArbFile(file)) '${file.path}: $v',
      ];

      expect(
        violations,
        isEmpty,
        reason:
            'User-facing copy must never disclose that someone blocked or '
            'muted the user. Gate with absence, not explanation.',
      );
    });

    test(
      'hardcoded string literals never reveal a block/mute relationship',
      () {
        final dartFiles = Directory('lib')
            .listSync(recursive: true)
            .whereType<File>()
            .where(
              (f) =>
                  f.path.endsWith('.dart') &&
                  !f.path.contains('l10n/generated') &&
                  !f.path.endsWith('.g.dart') &&
                  !f.path.endsWith('.freezed.dart'),
            )
            .toList();
        expect(dartFiles, isNotEmpty, reason: 'expected Dart files in lib/');

        final violations = <String>[
          for (final file in dartFiles)
            for (final v in _violationsIn(
              file.readAsStringSync(),
              literalsOnly: true,
            ))
              '${file.path}: $v',
        ];

        expect(
          violations,
          isEmpty,
          reason:
              'String literals must never disclose that someone blocked or '
              'muted the user — not in copy, logs, or analytics labels. '
              'Gate with absence, not explanation.',
        );
      },
    );
  });
}
