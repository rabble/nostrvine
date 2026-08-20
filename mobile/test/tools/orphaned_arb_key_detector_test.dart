// ABOUTME: Tests for the orphaned-ARB-key detector and its floor ratchet
// ABOUTME: (scripts/lib/orphaned_arb_key_detector.dart, #3630).

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/orphaned_arb_key_detector.dart';

/// Pins the detector semantics behind `check_orphaned_arb_key_floor.sh`.
///
/// The dangerous direction here is UNDER-reporting. A false orphan is caught in
/// seconds — delete the key, gen-l10n drops the getter, and the call site stops
/// compiling. A missed orphan is invisible: the key silently rides into 21
/// locales and stays there. That asymmetry is why the detector reads an
/// analyzer AST instead of grepping, and most of the cases below are "this
/// looks like a reference but is not".
void main() {
  group('collectCodeIdentifiers', () {
    test('collects a plain member access', () {
      expect(
        collectCodeIdentifiers('void f(c) => c.l10n.exampleOrphanKey;'),
        containsAll(['l10n', 'exampleOrphanKey']),
      );
    });

    test('ignores a name that appears only in a line comment', () {
      expect(
        collectCodeIdentifiers('// TODO wire up exampleOrphanKey\nvoid f() {}'),
        isNot(contains('exampleOrphanKey')),
      );
    });

    test('ignores a name that appears only in a doc comment', () {
      expect(
        collectCodeIdentifiers('/// Renders [exampleOrphanKey].\nvoid f() {}'),
        isNot(contains('exampleOrphanKey')),
      );
    });

    test('ignores a name that appears only in a block comment', () {
      expect(
        collectCodeIdentifiers('/* exampleOrphanKey */ void f() {}'),
        isNot(contains('exampleOrphanKey')),
      );
    });

    test('ignores a name that appears only inside a string literal', () {
      expect(
        collectCodeIdentifiers("void f() => log('exampleOrphanKey');"),
        isNot(contains('exampleOrphanKey')),
      );
    });

    test('collects a name inside a string interpolation', () {
      // `'${l10n.exampleOrphanKey}'` is a real render, so it must keep the key alive.
      expect(
        collectCodeIdentifiers(
          r"String f(l10n) => '${l10n.exampleOrphanKey}';",
        ),
        contains('exampleOrphanKey'),
      );
    });

    test('ignores an unrelated enum constant declaration of the same name', () {
      // The real `uploadFailed` case, kept verbatim: NotificationType in
      // lib/services/notification_service.dart declares a constant spelled
      // like an ARB key and nothing reads it. A grep called the key live; the
      // parser exposes a declaration name as a Token, not an identifier, so
      // only a real USE counts.
      expect(
        collectCodeIdentifiers('enum NotificationType { uploadFailed }'),
        isNot(contains('uploadFailed')),
      );
    });

    test('collects a use of that same enum constant', () {
      expect(
        collectCodeIdentifiers('final t = NotificationType.uploadFailed;'),
        contains('uploadFailed'),
      );
    });

    test('collects a nullable AppLocalizations.of call site', () {
      expect(
        collectCodeIdentifiers(
          'String f(c) => AppLocalizations.of(c)!.exampleOrphanKey;',
        ),
        contains('exampleOrphanKey'),
      );
    });

    test('returns an empty set for source that does not parse', () {
      // Over-reporting is the safe direction: a broken file is a pre-existing
      // `flutter analyze` failure, and the baseline review catches the noise.
      expect(collectCodeIdentifiers('class {{{'), isEmpty);
    });
  });

  group('findOrphanedArbKeys', () {
    test('reports a key nothing references', () {
      expect(
        findOrphanedArbKeys(
          arb: {'@@locale': 'en', 'exampleOrphanKey': 'Example'},
          referenced: <String>{},
        ),
        ['exampleOrphanKey'],
      );
    });

    test('does not report a referenced key', () {
      expect(
        findOrphanedArbKeys(
          arb: {'@@locale': 'en', 'exampleOrphanKey': 'Example'},
          referenced: {'exampleOrphanKey'},
        ),
        isEmpty,
      );
    });

    test('never reports @-metadata or the @@locale header', () {
      expect(
        findOrphanedArbKeys(
          arb: {
            '@@locale': 'en',
            'exampleOrphanKey': 'Example',
            '@exampleOrphanKey': {'description': 'Example description'},
          },
          referenced: {'exampleOrphanKey'},
        ),
        isEmpty,
      );
    });

    test('returns keys sorted, so the baseline diff stays stable', () {
      expect(
        findOrphanedArbKeys(
          arb: {'zulu': 'Z', 'alpha': 'A', 'mike': 'M'},
          referenced: <String>{},
        ),
        ['alpha', 'mike', 'zulu'],
      );
    });
  });
}
