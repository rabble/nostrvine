// ABOUTME: Widget tests for VerifiedAccountChip — render + tap launches URL.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/verified_account_chip.dart';
import 'package:profile_repository/profile_repository.dart';

const _hex64 =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: Center(child: child)),
);

void main() {
  group(VerifiedAccountChip, () {
    testWidgets('renders platform and identity text', (tester) async {
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
            launcher: (_) async => true,
          ),
        ),
      );
      await tester.pump();
      expect(find.textContaining('github'), findsOneWidget);
      expect(find.textContaining('octocat'), findsOneWidget);
    });

    testWidgets('taps launch a github URL for github claims', (tester) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'github',
              identity: 'octocat',
              proof: 'abc',
            ),
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(launched.toString(), equals('https://github.com/octocat'));
    });

    testWidgets('mastodon claims route through verifier lookup', (
      tester,
    ) async {
      Uri? launched;
      await tester.pumpWidget(
        _wrap(
          VerifiedAccountChip(
            claim: const IdentityClaim(
              pubkey: _hex64,
              platform: 'mastodon',
              identity: 'fosstodon.org/@alice',
              proof: 'abc',
            ),
            launcher: (uri) async {
              launched = uri;
              return true;
            },
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byType(InkWell));
      await tester.pumpAndSettle();
      expect(launched, isNotNull);
      expect(launched!.host, equals('verifier.divine.video'));
      expect(launched!.queryParameters['platform'], equals('mastodon'));
      expect(
        launched!.queryParameters['identity'],
        equals('fosstodon.org/@alice'),
      );
    });
  });
}
