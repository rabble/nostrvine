// ABOUTME: Tests for the countable-but-flat ARB detector and its floor ratchet
// ABOUTME: (scripts/lib/countable_flat_arb_detector.dart, #3633).

import 'package:flutter_test/flutter_test.dart';

// ignore: avoid_relative_lib_imports, scripts are outside lib/ and not importable through package:openvine.
import '../../scripts/lib/countable_flat_arb_detector.dart';

/// Pins the detector semantics behind `check_countable_plural_floor.sh`.
///
/// The dangerous failure mode is not a missed offender — it is a FALSE one.
/// Roughly 40 of the flat keys in `app_en.arb` are units, percentages,
/// ordinals or ratios, and pluralizing any of them would be a bug, not a fix.
/// A detector that flags those would launder bad advice through CI, so the
/// exemptions below matter more than the detections.
void main() {
  group('findCountableFlatKeys', () {
    Map<String, dynamic> arb(
      String key,
      String value, {
      Map<String, dynamic>? placeholders,
    }) => {
      '@@locale': 'en',
      key: value,
      if (placeholders != null) '@$key': {'placeholders': placeholders},
    };

    test('flags an int-typed count with no plural', () {
      expect(
        findCountableFlatKeys(
          arb(
            'videoCount',
            '{count} videos',
            placeholders: {
              'count': {'type': 'int'},
            },
          ),
        ),
        ['videoCount'],
      );
    });

    test('flags a String-typed placeholder on a ...Count key', () {
      // The compact-display shape: typed String because the caller passes
      // "1.2K". Still a quantity, so it must carry a plural.
      expect(
        findCountableFlatKeys(
          arb(
            'analyticsViewsCount',
            '{count} views',
            placeholders: {
              'count': {'type': 'String'},
            },
          ),
        ),
        ['analyticsViewsCount'],
      );
    });

    test('exempts a key that already has plural arms', () {
      expect(
        findCountableFlatKeys(
          arb(
            'videoCount',
            '{count, plural, =1{{count} video} other{{count} videos}}',
            placeholders: {
              'count': {'type': 'int'},
            },
          ),
        ),
        isEmpty,
      );
    });

    test(
      'exempts a value that selects on one argument and displays another',
      () {
        // Design X: the plural is selected on `countValue`, but the displayed
        // token is the pre-formatted `count`. Requiring the selector to name the
        // countable placeholder would flag all eight of these.
        expect(
          findCountableFlatKeys(
            arb(
              'analyticsViewsCount',
              '{countValue, plural, =1{{count} view} other{{count} views}}',
              placeholders: {
                'countValue': {'type': 'int'},
                'count': {'type': 'String'},
              },
            ),
          ),
          isEmpty,
        );
      },
    );

    test('exempts a placeholder that is declared but never interpolated', () {
      expect(
        findCountableFlatKeys(
          arb(
            'someLabel',
            'No videos yet',
            placeholders: {
              'count': {'type': 'int'},
            },
          ),
        ),
        isEmpty,
      );
    });

    test('exempts a key with no placeholder metadata at all', () {
      expect(findCountableFlatKeys(arb('plainLabel', 'Videos')), isEmpty);
    });

    // The categories below are the whole reason the baseline exists. Each is a
    // real key shape from app_en.arb that must NEVER gain plural arms.
    test('does not flag a non-numeric placeholder', () {
      expect(
        findCountableFlatKeys(
          arb(
            'greeting',
            'Hi {name}',
            placeholders: {
              'name': {'type': 'String'},
            },
          ),
        ),
        isEmpty,
        reason: 'a String placeholder on a non-Count key is not a quantity',
      );
    });

    test('flags unit symbols, which the baseline must exempt by reason', () {
      // `{count}d ago` IS caught by the detector — units cannot be told apart
      // from quantities mechanically. That is precisely why every baseline
      // entry carries a '# reason' naming its category, and why the failure
      // message warns that pluralizing a unit is wrong.
      expect(
        findCountableFlatKeys(
          arb(
            'timeDaysAgo',
            '{count}d ago',
            placeholders: {
              'count': {'type': 'int'},
            },
          ),
        ),
        ['timeDaysAgo'],
        reason: 'documents that units are baseline-exempt, not detector-exempt',
      );
    });
  });
}
