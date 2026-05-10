// ABOUTME: Widget tests for VerifiedAccountsRow — empty + multi-chip rendering.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/verified_account_chip.dart';
import 'package:openvine/widgets/profile/verified_accounts_row.dart';
import 'package:profile_repository/profile_repository.dart';

const _hex64 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group(VerifiedAccountsRow, () {
    testWidgets('renders no chips when claims is empty', (tester) async {
      await tester.pumpWidget(
        _wrap(const VerifiedAccountsRow(claims: [])),
      );
      await tester.pump();
      expect(find.byType(VerifiedAccountChip), findsNothing);
    });

    testWidgets('renders one chip per claim', (tester) async {
      await tester.pumpWidget(
        _wrap(
          const VerifiedAccountsRow(
            claims: [
              IdentityClaim(
                pubkey: _hex64,
                platform: 'github',
                identity: 'octocat',
                proof: 'abc',
              ),
              IdentityClaim(
                pubkey: _hex64,
                platform: 'twitter',
                identity: 'elon',
                proof: 'def',
              ),
            ],
          ),
        ),
      );
      await tester.pump();
      expect(find.byType(VerifiedAccountChip), findsNWidgets(2));
    });
  });
}
