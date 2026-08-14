// ABOUTME: Tests UserName NIP-05 display behavior
// ABOUTME: Ensures valid NIP-05 does not render a verification checkmark

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/nip05_verification_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/nip05_verification_service.dart';
import 'package:openvine/widgets/user_name.dart';

Finder _specialCheckmark() => find.byWidgetPredicate(
  (w) => w is DivineIcon && w.icon == DivineIconName.check,
);

void main() {
  const defaultPubkey =
      'abcdef0123456789abcdef0123456789abcdef0123456789abcdef0123456789';

  Widget buildSubject({
    String pubkey = defaultPubkey,
    String nip05 = 'alice@example.com',
  }) {
    return ProviderScope(
      overrides: [
        nip05VerificationProvider.overrideWith(
          (ref, pubkey) async => Nip05VerificationStatus.verified,
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: UserName.fromUserProfile(
              UserProfile(
                pubkey: pubkey,
                name: 'Alice',
                nip05: nip05,
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: 'kind0_event_id',
              ),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('does not show a checkmark for verified NIP-05', (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(_specialCheckmark(), findsNothing);
  });

  testWidgets('shows a checkmark for a Divine team pubkey', (tester) async {
    await tester.pumpWidget(buildSubject(pubkey: kDivineTeamPubkeys.first));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(_specialCheckmark(), findsOneWidget);
  });

  testWidgets('shows a checkmark for a grandfathered pubkey', (tester) async {
    await tester.pumpWidget(
      buildSubject(pubkey: kLegacyProfileCheckmarkPubkeys.first),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(_specialCheckmark(), findsOneWidget);
  });

  testWidgets('matches a Divine team pubkey case-insensitively', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildSubject(pubkey: kDivineTeamPubkeys.first.toUpperCase()),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(_specialCheckmark(), findsOneWidget);
  });

  testWidgets('does not show a checkmark for a divine.video NIP-05', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject(nip05: '_@rabble.divine.video'));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(_specialCheckmark(), findsNothing);
  });

  testWidgets('sanitizes embedded display name fallback while profile loads', (
    tester,
  ) async {
    final malformedName = String.fromCharCodes([0xD800, 0xD83D, 0xDE00]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          userProfileReactiveProvider(
            defaultPubkey,
          ).overrideWith((ref) => const Stream<UserProfile?>.empty()),
          nip05VerificationProvider.overrideWith(
            (ref, pubkey) async => Nip05VerificationStatus.none,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: UserName.fromPubKey(
              defaultPubkey,
              embeddedName: malformedName,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(tester.takeException(), isNull);
    expect(find.text('\uFFFD😀'), findsOneWidget);
  });
}
