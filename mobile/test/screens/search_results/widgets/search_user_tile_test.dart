// ABOUTME: Widget tests for the search-result user tile's secondary line.
// ABOUTME: Pins video-count disambiguation over per-row NIP-05 verification.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/search_results/widgets/search_user_tile.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(SearchUserTile, () {
    UserProfile profileWith({Map<String, dynamic> rawData = const {}}) {
      return UserProfile(
        pubkey:
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        name: 'Lauren Test',
        nip05: '_@lauren.divine.video',
        rawData: rawData,
        createdAt: DateTime(2024),
        eventId: 'event1',
      );
    }

    Widget buildSubject(UserProfile profile) {
      return testProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: SearchUserTile(profile: profile)),
        ),
      );
    }

    testWidgets('shows the video count as the secondary line', (tester) async {
      await tester.pumpWidget(
        buildSubject(profileWith(rawData: const {'video_count': 18})),
      );

      // The count is the one piece of information that distinguishes twenty
      // same-named strangers; the claimed nip05 is server-broken junk (all
      // results share one identical verified handle) and must not outrank it.
      expect(find.text('18 videos'), findsOneWidget);
      expect(find.textContaining('_@lauren'), findsNothing);
    });

    testWidgets('singularizes one video', (tester) async {
      await tester.pumpWidget(
        buildSubject(profileWith(rawData: const {'video_count': 1})),
      );

      expect(find.text('1 video'), findsOneWidget);
    });

    testWidgets('falls back to the npub when the video count is unknown', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject(profileWith()));

      expect(find.textContaining('npub'), findsOneWidget);
      expect(find.textContaining('_@lauren'), findsNothing);
    });
  });
}
