// ABOUTME: BadgeRecipientRow — the acceptance pill and its unknown state.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/screens/badges/widgets/badge_status_pill.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(BadgeRecipientRow, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpRow(WidgetTester tester, {required bool? isAccepted}) {
      return tester.pumpWidget(
        testProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BadgeRecipientRow(
                pubkey:
                    'a1b2c3d4e5f6789012345678901234567890abcdef'
                    '123456789012345678901234',
                isAccepted: isAccepted,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows the accepted pill when the award is pinned', (
      tester,
    ) async {
      await pumpRow(tester, isAccepted: true);

      expect(find.byType(BadgeStatusPill), findsOneWidget);
      expect(find.text(l10n.badgesRecipientAcceptedStatus), findsOneWidget);
    });

    testWidgets('shows the waiting pill when the award is not pinned', (
      tester,
    ) async {
      await pumpRow(tester, isAccepted: false);

      expect(find.text(l10n.badgesRecipientWaitingStatus), findsOneWidget);
    });

    testWidgets('claims no status when acceptance was not resolved', (
      tester,
    ) async {
      // Past the recipient-check limit the answer is unknown, and "Waiting
      // for recipient" would be a claim the repository never made.
      await pumpRow(tester, isAccepted: null);

      expect(find.byType(BadgeStatusPill), findsNothing);
    });
  });
}
