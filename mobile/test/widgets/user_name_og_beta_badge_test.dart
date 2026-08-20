// ABOUTME: Tests UserName OG Beta Tester badge display from the frozen roster.
// ABOUTME: Pins roster membership and OG Viner precedence at the render site.

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/og_beta_testers.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/og_viner_cache_service.dart';
import 'package:openvine/widgets/og_beta_badge.dart';
import 'package:openvine/widgets/og_viner_badge.dart';
import 'package:openvine/widgets/user_name.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final rosterPubkey = ogBetaTesterPubkeys.first;
  const strangerPubkey =
      'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';

  Future<Widget> buildSubject({
    required String pubkey,
    bool cachedOgViner = false,
    bool showProfileBadges = true,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (cachedOgViner) ogVinerPubkeysCacheKey: jsonEncode([pubkey]),
    });
    final prefs = await SharedPreferences.getInstance();

    return ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Center(
            child: UserName.fromUserProfile(
              showProfileBadges: showProfileBadges,
              UserProfile(
                pubkey: pubkey,
                name: 'Alice',
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

  testWidgets('shows OG Beta Tester badge for a roster pubkey', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(await buildSubject(pubkey: rosterPubkey));
    await tester.pump();
    final l10n = lookupAppLocalizations(const Locale('en'));
    final data = tester
        .getSemantics(find.byType(OgBetaBadge))
        .getSemanticsData();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('OG'), findsOneWidget);
    expect(data.label, l10n.ogBetaTesterBadgeLabel);
    expect(data.hasAction(ui.SemanticsAction.tap), isFalse);
    handle.dispose();
  });

  testWidgets('hides the badge for a pubkey off the roster', (tester) async {
    await tester.pumpWidget(await buildSubject(pubkey: strangerPubkey));
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(OgBetaBadge), findsNothing);
  });

  testWidgets('does not open explanation sheet when tapped inline', (
    tester,
  ) async {
    await tester.pumpWidget(await buildSubject(pubkey: rosterPubkey));
    await tester.pump();
    final l10n = lookupAppLocalizations(const Locale('en'));

    await tester.tap(find.text('OG'));
    await tester.pumpAndSettle();

    expect(find.text(l10n.profileBadgeOgBetaTesterBody), findsNothing);
    expect(find.text(l10n.commonClose), findsNothing);
  });

  testWidgets('hides the badge when showProfileBadges is false', (
    tester,
  ) async {
    // The profile header passes false and renders its own full-size,
    // tappable explanation button instead of the inline chit.
    await tester.pumpWidget(
      await buildSubject(pubkey: rosterPubkey, showProfileBadges: false),
    );
    await tester.pump();

    expect(find.text('Alice'), findsOneWidget);
    expect(find.byType(OgBetaBadge), findsNothing);
  });

  testWidgets('yields to the OG Viner badge so only one chit renders', (
    tester,
  ) async {
    await tester.pumpWidget(
      await buildSubject(pubkey: rosterPubkey, cachedOgViner: true),
    );
    await tester.pump();

    expect(find.byType(OgVinerBadge), findsOneWidget);
    expect(find.byType(OgBetaBadge), findsNothing);
  });
}
