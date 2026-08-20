// ABOUTME: Tests for the orphaned-ARB-key detector and its floor ratchet
// ABOUTME: (scripts/lib/orphaned_arb_key_detector.dart, #3630).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/orphaned_arb_key_detector.dart';

/// Pins the detector semantics behind `check_orphaned_arb_key_floor.sh`.
///
/// Two failure directions, both cheap to reintroduce:
///
/// UNDER-reporting is invisible — a missed orphan rides into 21 locales and
/// stays. That is why comments, string bodies and same-named locals do not
/// count.
///
/// OVER-reporting is loud but expensive to debug, and this detector has two
/// live landmines for it. Both were measured against the real tree: dropping
/// the `AppLocalizations`-extension case reports 51 live keys as dead, and
/// dropping [MethodInvocation] reports 316. Each has a test below; if one goes
/// red, restore the visitor rather than the expectation.
void main() {
  group('collectCodeIdentifiers', () {
    test('collects a plain member access', () {
      expect(
        collectCodeIdentifiers('void f(c) => c.l10n.exampleOrphanKey;'),
        contains('exampleOrphanKey'),
      );
    });

    test('collects a call on a target, because placeholders make a method', () {
      // A key with placeholders generates `String fooCount(int n)`, so it is a
      // MethodInvocation and never reaches visitPropertyAccess. Dropping this
      // visitor reports all 316 parameterized keys in the app as orphaned.
      expect(
        collectCodeIdentifiers('String f(l10n) => l10n.exampleCountKey(3);'),
        contains('exampleCountKey'),
      );
    });

    test('ignores a bare identifier that is just a local of the same name', () {
      // The real `profileRefresh` case: a local Completer in profile_grid.dart
      // shares the ARB key's name. Counting every identifier — the obvious
      // implementation — makes the whole detector a lower bound, because any
      // key colliding with an ordinary Dart name can never be flagged.
      expect(
        collectCodeIdentifiers(
          'void f() { final exampleOrphanKey = Object(); print(exampleOrphanKey); }',
        ),
        isNot(contains('exampleOrphanKey')),
      );
    });

    test('collects an implicit-this reference inside an AppLocalizations '
        'extension', () {
      // lib/l10n/publish_error_kind_l10n.dart and its two siblings dispatch an
      // enum to a message with implicit `this` (`return publishErrorTimeout;`).
      // 51 live keys reach the UI only this way; without this case a
      // member-access-only collector calls every one of them dead.
      expect(
        collectCodeIdentifiers('''
extension PublishErrorKindL10n on AppLocalizations {
  String message(Object kind) => exampleOrphanKey;
}
'''),
        contains('exampleOrphanKey'),
      );
    });

    test('does not extend implicit-this to an extension on another type', () {
      expect(
        collectCodeIdentifiers('''
extension SomethingElse on BuildContext {
  String get thing => exampleOrphanKey;
}
'''),
        isNot(contains('exampleOrphanKey')),
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

  group('scan scope', () {
    test('defaults to lib/ only, so a test cannot vouch for a key', () {
      // The detector's roots default to ['lib']. Counting test/ hid 9
      // product-orphans, four of them propped up by
      // `expect(find.text(l10n.x), findsNothing)` — a test asserting the
      // string is NOT on screen, which is evidence the key is dead. Widening
      // this back to test/ silently re-hides them, so the default is pinned.
      final source = File(
        'scripts/lib/orphaned_arb_key_detector.dart',
      ).readAsStringSync();
      expect(source, contains("const ['lib']"));
      expect(source, isNot(contains("'test', 'integration_test'")));
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
