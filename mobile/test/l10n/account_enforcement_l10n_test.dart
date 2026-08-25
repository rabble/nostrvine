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

    test('unverified makes no good-standing claim', () {
      expect(
        l10n.accountEnforcementHeading(AccountEnforcementKind.unverified),
        isNot(contains('good standing')),
      );
      expect(
        l10n.accountEnforcementBody(AccountEnforcementKind.unverified),
        isNot(contains('no restrictions')),
      );
      expect(
        l10n.accountEnforcementHeading(AccountEnforcementKind.unverified),
        isNot(contains("can't verify")),
      );
    });
  });
}
