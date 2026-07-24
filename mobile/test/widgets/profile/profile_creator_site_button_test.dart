// ABOUTME: Tests the prominent profile CTA for a creator's Divine Space site.
// ABOUTME: Covers deterministic URLs, dedup, shared-launcher routing, analytics.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/widgets/profile/profile_creator_site_button.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../helpers/url_launcher_test_double.dart';

const _testPubkey =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
const _testNpub =
    'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
const _testUrl = 'https://divine.space/$_testNpub';

class _RecordingAnalyticsSink implements AnalyticsEventSink {
  final List<({String name, Map<String, Object> parameters})> events = [];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

Widget _wrap({
  required bool isOwnProfile,
  required AnalyticsEventSink analytics,
  String userIdHex = _testPubkey,
}) => ProviderScope(
  overrides: [analyticsEventSinkProvider.overrideWithValue(analytics)],
  child: MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: ProfileCreatorSiteButton(
        userIdHex: userIdHex,
        isOwnProfile: isOwnProfile,
      ),
    ),
  ),
);

void main() {
  group('divineSpaceProfileUri', () {
    test('builds the expected npub profile URL', () {
      expect(divineSpaceProfileUri(_testPubkey), Uri.parse(_testUrl));
    });

    test('rejects malformed public keys', () {
      expect(divineSpaceProfileUri('not-a-pubkey'), isNull);
    });
  });

  group('isDivineSpaceProfileUrlForPubkey', () {
    test('accepts harmless scheme, host, and slash differences', () {
      expect(
        isDivineSpaceProfileUrlForPubkey(
          'HTTPS://DIVINE.SPACE/$_testNpub///',
          _testPubkey,
        ),
        isTrue,
      );
      expect(
        isDivineSpaceProfileUrlForPubkey(
          'divine.space/$_testNpub',
          _testPubkey,
        ),
        isTrue,
      );
    });

    test('keeps destinations that are not the exact generated profile', () {
      for (final rawUrl in [
        'https://www.divine.space/$_testNpub',
        'https://shop.divine.space/$_testNpub',
        'https://divine.space/$_testNpub?ref=profile',
        'https://divine.space/$_testNpub#shop',
        'https://divine.space:443/$_testNpub',
        'https://divine.space/npub1different',
      ]) {
        expect(
          isDivineSpaceProfileUrlForPubkey(rawUrl, _testPubkey),
          isFalse,
          reason: rawUrl,
        );
      }
    });
  });

  group(ProfileCreatorSiteButton, () {
    late UrlLauncherTestDouble launcher;
    late UrlLauncherPlatform originalLauncher;

    setUp(() {
      originalLauncher = UrlLauncherPlatform.instance;
      launcher = UrlLauncherTestDouble();
      UrlLauncherPlatform.instance = launcher;
    });

    tearDown(() {
      UrlLauncherPlatform.instance = originalLauncher;
    });

    testWidgets('renders as a compact pill carrying the Divine mark', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(isOwnProfile: false, analytics: _RecordingAnalyticsSink()),
      );

      // Sized to match the tip/support pill it sits beside.
      final button = tester.widget<DivineButton>(find.byType(DivineButton));
      expect(button.type, DivineButtonType.secondary);
      expect(button.size, DivineButtonSize.tiny);
      // The Divine mark distinguishes it from the generic globe on the Kind-0
      // website row below.
      expect(button.leadingIcon, DivineIconName.divineMark);
      expect(button.expanded, isFalse);
    });

    testWidgets('names the destination in the visitor label', (tester) async {
      await tester.pumpWidget(
        _wrap(isOwnProfile: false, analytics: _RecordingAnalyticsSink()),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileCreatorSiteVisitLabel), findsOneWidget);
      expect(find.text(l10n.profileCreatorSiteOwnLabel), findsNothing);

      // The visible label carries the accessible name — no separate
      // Semantics label to drift out of sync with the copy.
      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(l10n.profileCreatorSiteVisitLabel),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('claims the site as the viewer’s own on their profile', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(isOwnProfile: true, analytics: _RecordingAnalyticsSink()),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.profileCreatorSiteOwnLabel), findsOneWidget);

      final handle = tester.ensureSemantics();
      expect(
        find.bySemanticsLabel(l10n.profileCreatorSiteOwnLabel),
        findsWidgets,
      );
      handle.dispose();
    });

    testWidgets('launches the generated URL through the shared launcher', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(isOwnProfile: false, analytics: _RecordingAnalyticsSink()),
      );

      await tester.tap(find.byKey(const Key('profile-creator-site-button')));
      await tester.pumpAndSettle();

      // divine.space is a first-party trusted host, so the shared launcher
      // opens it directly (no confirmation dialog) in the external browser.
      expect(launcher.launched, hasLength(1));
      expect(launcher.launched.single.url, _testUrl);
      expect(launcher.launched.single.useExternalApplication, isTrue);
    });

    testWidgets('tracks the CTA tap with the profile ownership', (
      tester,
    ) async {
      final analytics = _RecordingAnalyticsSink();
      await tester.pumpWidget(_wrap(isOwnProfile: true, analytics: analytics));

      await tester.tap(find.byKey(const Key('profile-creator-site-button')));
      await tester.pumpAndSettle();

      expect(analytics.events, hasLength(1));
      expect(analytics.events.single.name, 'creator_site_cta_tapped');
      expect(analytics.events.single.parameters['is_own_profile'], isTrue);
    });

    testWidgets('does not expose a broken destination for an invalid key', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          isOwnProfile: false,
          analytics: _RecordingAnalyticsSink(),
          userIdHex: 'not-a-pubkey',
        ),
      );

      expect(
        find.byKey(const Key('profile-creator-site-button')),
        findsNothing,
      );
    });
  });
}
