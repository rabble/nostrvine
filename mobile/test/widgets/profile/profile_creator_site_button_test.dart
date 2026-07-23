// ABOUTME: Tests the prominent profile CTA for a creator's Divine Space site.
// ABOUTME: Covers deterministic URLs, deduplication, launching, and failures.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/profile_creator_site_button.dart';
import 'package:url_launcher/url_launcher.dart';

const _testPubkey =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
const _testNpub =
    'npub180cvv07tjdrrgpa0j7j7tmnyl2yr6yr7l8j4s3evf6u64th6gkwsyjh6w6';
const _testUrl = 'https://divine.space/$_testNpub';

Widget _wrap({
  required bool isOwnProfile,
  CreatorSiteUrlLauncher? launcher,
  String userIdHex = _testPubkey,
}) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(
    body: ProfileCreatorSiteButton(
      userIdHex: userIdHex,
      isOwnProfile: isOwnProfile,
      launcher: launcher ?? (_, _) async => true,
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
    testWidgets('uses prominent design-system styling and visitor copy', (
      tester,
    ) async {
      await tester.pumpWidget(_wrap(isOwnProfile: false));

      expect(find.text('Visit creator site'), findsOneWidget);
      final button = tester.widget<DivineButton>(find.byType(DivineButton));
      expect(button.type, DivineButtonType.secondary);
      expect(button.size, DivineButtonSize.small);
      expect(button.leadingIcon, DivineIconName.globe);
      expect(button.expanded, isTrue);
    });

    testWidgets('uses owner-specific copy', (tester) async {
      await tester.pumpWidget(_wrap(isOwnProfile: true));

      expect(find.text('View your site'), findsOneWidget);
      expect(find.text('Visit creator site'), findsNothing);
    });

    testWidgets('opens the generated URL in the system browser', (
      tester,
    ) async {
      Uri? launchedUri;
      LaunchMode? launchMode;
      await tester.pumpWidget(
        _wrap(
          isOwnProfile: false,
          launcher: (uri, mode) async {
            launchedUri = uri;
            launchMode = mode;
            return true;
          },
        ),
      );

      await tester.tap(find.byKey(const Key('profile-creator-site-button')));
      await tester.pump();

      expect(launchedUri, Uri.parse(_testUrl));
      expect(launchMode, LaunchMode.externalApplication);
    });

    testWidgets('shows feedback when the system browser cannot open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          isOwnProfile: false,
          launcher: (_, _) async => false,
        ),
      );

      await tester.tap(find.byKey(const Key('profile-creator-site-button')));
      await tester.pump();

      expect(find.text("Couldn't open creator site"), findsOneWidget);
    });

    testWidgets('shows feedback when the launcher throws', (tester) async {
      await tester.pumpWidget(
        _wrap(
          isOwnProfile: false,
          launcher: (_, _) => throw StateError('launcher unavailable'),
        ),
      );

      await tester.tap(find.byKey(const Key('profile-creator-site-button')));
      await tester.pump();

      expect(find.text("Couldn't open creator site"), findsOneWidget);
    });

    testWidgets('does not expose a broken destination for an invalid key', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(isOwnProfile: false, userIdHex: 'not-a-pubkey'),
      );

      expect(
        find.byKey(const Key('profile-creator-site-button')),
        findsNothing,
      );
    });
  });
}
