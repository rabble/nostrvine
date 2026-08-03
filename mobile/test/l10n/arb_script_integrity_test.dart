// ABOUTME: Tests that each ARB locale uses only the scripts its language needs.
// ABOUTME: Catches homoglyph contamination and wrong-language text in copy.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// Scripts each shipped locale is allowed to use in message values.
///
/// Latin is allowed everywhere because product nouns (`Divine`, `Nostr`,
/// `NIP-09`) and placeholder names stay in Latin in every language. Anything
/// outside a locale's set is either a homoglyph or text from the wrong
/// language, both of which render as plausible-looking but wrong copy.
const _allowedScripts = <String, Set<String>>{
  'am': {'ETHIOPIC'},
  'ar': {'ARABIC'},
  'bg': {'CYRILLIC'},
  'de': {},
  'en': {},
  'es': {},
  'fil': {},
  'fr': {},
  'id': {},
  'it': {},
  'ja': {'HIRAGANA', 'KATAKANA', 'CJK'},
  'ko': {'HANGUL', 'CJK'},
  'ms': {},
  'nl': {},
  'pl': {},
  'pt': {},
  'ro': {},
  'sv': {},
  'tr': {},
  'ur': {'ARABIC'},
  'vi': {},
  'zh': {'CJK'},
};

void main() {
  group('ARB script integrity', () {
    test('every locale uses only the scripts its language needs', () {
      final arbFiles =
          Directory('lib/l10n')
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      expect(arbFiles, isNotEmpty, reason: 'no ARB files found');

      for (final file in arbFiles) {
        final code = _localeCodeOf(file);

        final allowed = _allowedScripts[code];
        expect(
          allowed,
          isNotNull,
          reason:
              'app_$code.arb ships a locale with no entry in _allowedScripts; '
              'add the scripts it needs so its copy is covered by this guard',
        );

        final arb = (jsonDecode(file.readAsStringSync()) as Map)
            .cast<String, Object?>();

        for (final entry in arb.entries) {
          if (entry.key.startsWith('@')) continue;
          final value = entry.value;
          if (value is! String) continue;

          for (final rune in value.runes) {
            final script = _scriptOf(rune);
            if (script == null || script == 'LATIN') continue;
            if (allowed!.contains(script)) continue;

            fail(
              '${file.path} uses $script character '
              'U+${rune.toRadixString(16).toUpperCase().padLeft(4, '0')} '
              '(${String.fromCharCode(rune)}) in ${entry.key}; '
              '$code allows ${allowed.isEmpty ? 'Latin only' : allowed}',
            );
          }
        }
      }
    });
  });
}

String _localeCodeOf(File file) {
  return file.uri.pathSegments.last
      .replaceFirst('app_', '')
      .replaceFirst('.arb', '');
}

/// Script family of [rune], or `null` for digits, punctuation, and symbols,
/// which carry no script and are legal in every locale.
String? _scriptOf(int rune) {
  const ranges = <(int, int, String)>[
    (0x0041, 0x024F, 'LATIN'),
    (0x1E00, 0x1EFF, 'LATIN'),
    (0x0370, 0x03FF, 'GREEK'),
    (0x0400, 0x04FF, 'CYRILLIC'),
    (0x0500, 0x052F, 'CYRILLIC'),
    (0x0590, 0x05FF, 'HEBREW'),
    (0x0600, 0x06FF, 'ARABIC'),
    (0x0750, 0x077F, 'ARABIC'),
    (0xFB50, 0xFDFF, 'ARABIC'),
    (0xFE70, 0xFEFF, 'ARABIC'),
    (0x1200, 0x137F, 'ETHIOPIC'),
    (0x0E00, 0x0E7F, 'THAI'),
    (0x0900, 0x097F, 'DEVANAGARI'),
    (0x3040, 0x309F, 'HIRAGANA'),
    (0x30A0, 0x30FF, 'KATAKANA'),
    (0x3400, 0x4DBF, 'CJK'),
    (0x4E00, 0x9FFF, 'CJK'),
    (0xF900, 0xFAFF, 'CJK'),
    (0x3000, 0x303F, 'CJK'),
    (0xAC00, 0xD7AF, 'HANGUL'),
    (0x1100, 0x11FF, 'HANGUL'),
    (0x3130, 0x318F, 'HANGUL'),
  ];

  for (final (start, end, script) in ranges) {
    if (rune >= start && rune <= end) return script;
  }
  return null;
}
