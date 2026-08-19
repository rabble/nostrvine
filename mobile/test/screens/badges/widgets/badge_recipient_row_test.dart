// ABOUTME: BadgeRecipientRow — the acceptance pill, its unknown state, and
// ABOUTME: the issuer-only revoke action.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/badges/widgets/badge_recipient_row.dart';
import 'package:openvine/screens/badges/widgets/badge_status_pill.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(BadgeRecipientRow, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pumpRow(
      WidgetTester tester, {
      required bool? isAccepted,
      bool showRevokeAction = false,
      VoidCallback? onRevoke,
    }) {
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
                showRevokeAction: showRevokeAction,
                onRevoke: onRevoke,
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

    testWidgets('offers no revoke action by default', (tester) async {
      await pumpRow(tester, isAccepted: true);

      expect(
        find.bySemanticsLabel(l10n.badgeDetailRevokeAction),
        findsNothing,
      );
    });

    testWidgets('calls back when the issuer revokes the award', (tester) async {
      var revoked = 0;
      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        onRevoke: () => revoked++,
      );

      await tester.tap(find.bySemanticsLabel(l10n.badgeDetailRevokeAction));
      await tester.pump();

      expect(revoked, 1);
    });

    testWidgets('keeps the acceptance pill out of the revoke button', (
      tester,
    ) async {
      // DivineIconButton's own Semantics opens no container, so without a
      // boundary the pill merges in and the two are read as one control.
      await pumpRow(
        tester,
        isAccepted: true,
        showRevokeAction: true,
        onRevoke: () {},
      );

      expect(
        tester.getSemantics(find.byType(DivineIconButton)).label,
        l10n.badgeDetailRevokeAction,
      );
    });

    testWidgets('greys the revoke action out instead of removing it', (
      tester,
    ) async {
      // A row that loses its trailing button mid-flight reflows the whole
      // list; disabling keeps the layout still.
      await pumpRow(tester, isAccepted: true, showRevokeAction: true);

      expect(
        tester
            .widget<DivineIconButton>(find.byType(DivineIconButton))
            .onPressed,
        isNull,
      );
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
