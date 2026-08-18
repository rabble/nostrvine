// ABOUTME: Tests the AccountEnforcementKind -> localized-copy mapping, and that
// ABOUTME: no enforcement state can borrow the good-standing copy.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/account_enforcement_l10n.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/account_enforcement_status.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('AccountEnforcementL10n', () {
    test('maps every kind to a non-empty heading and body', () {
      for (final kind in AccountEnforcementKind.values) {
        expect(
          l10n.accountEnforcementHeading(kind),
          isNotEmpty,
          reason: 'no heading for $kind',
        );
        expect(
          l10n.accountEnforcementBody(kind),
          isNotEmpty,
          reason: 'no body for $kind',
        );
      }
    });

    test('maps every kind to a distinct heading', () {
      final headings = AccountEnforcementKind.values
          .map(l10n.accountEnforcementHeading)
          .toList();

      expect(headings.toSet(), hasLength(headings.length));
    });

    test('unknown does not borrow the good-standing copy', () {
      // "We could not check" and "you are fine" are different claims. Letting
      // unknown fall through to the good-standing copy would reassure a
      // suspended user whose status fetch simply failed.
      expect(
        l10n.accountEnforcementHeading(AccountEnforcementKind.unknown),
        isNot(l10n.accountEnforcementHeading(AccountEnforcementKind.none)),
      );
      expect(
        l10n.accountEnforcementBody(AccountEnforcementKind.unknown),
        isNot(l10n.accountEnforcementBody(AccountEnforcementKind.none)),
      );
    });

    test('no enforced state renders the good-standing copy', () {
      final okHeading = l10n.accountEnforcementHeading(
        AccountEnforcementKind.none,
      );

      for (final kind in AccountEnforcementKind.values) {
        if (AccountEnforcementStatus(kind: kind).isEnforced) {
          expect(
            l10n.accountEnforcementHeading(kind),
            isNot(okHeading),
            reason: '$kind must not read as good standing',
          );
        }
      }
    });
  });
}
