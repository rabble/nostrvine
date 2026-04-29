// ABOUTME: Plan #1602 alignment §6 — More menu, save/remove, feed action, a11y
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/hashtag_feed_screen.dart';
import 'package:openvine/services/hashtag_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockHashtagService extends Mock implements HashtagService {}

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(<String>[]);
  });

  group('HashtagFeedScreen plan §6 (More / a11y)', () {
    late _MockHashtagService mockHashtag;
    late _MockFunnelcakeApiClient mockFunnelcake;
    late FollowedHashtagsRepository repo;

    Future<void> pumpScreen(
      WidgetTester tester, {
      bool embedded = false,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      mockHashtag = _MockHashtagService();
      mockFunnelcake = _MockFunnelcakeApiClient();
      repo = FollowedHashtagsRepository(
        prefs: prefs,
        profileStorageKey: 'test_profile_hashtags_1602_6',
        followingFeedStorageKey: 'test_feed_hashtags_1602_6',
      );
      addTearDown(() async {
        await repo.dispose();
      });

      when(() => mockHashtag.getVideosByHashtags(any())).thenReturn([]);
      when(() => mockFunnelcake.isAvailable).thenReturn(false);
      when(
        () => mockHashtag.subscribeToHashtagVideos(
          any(),
          limit: any(named: 'limit'),
          until: any(named: 'until'),
        ),
      ).thenAnswer((_) async {});

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hashtagServiceProvider.overrideWith((ref) => mockHashtag),
            funnelcakeApiClientProvider.overrideWithValue(mockFunnelcake),
            followedHashtagsRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HashtagFeedScreen(hashtag: 'plan6test', embedded: embedded),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('More button exposes a11y label matching copy', (tester) async {
      await pumpScreen(tester);
      expect(find.bySemanticsLabel('Hashtag options'), findsOneWidget);
    });

    testWidgets('More menu shows save and add-to-feed when tag not saved', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Hashtag options'));
      await tester.pumpAndSettle();

      expect(find.text('Save'), findsOneWidget);
      expect(find.text('Add to my feeds'), findsOneWidget);
    });

    testWidgets('Save persists tag and shows remove on next open', (
      tester,
    ) async {
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Hashtag options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(repo.hasProfileSavedHashtag('plan6test'), isTrue);
      expect(find.text('Saved to your profile'), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 2500));
      await tester.tap(find.bySemanticsLabel('Hashtag options'));
      await tester.pumpAndSettle();

      expect(find.text('Remove from saved tags'), findsOneWidget);
    });

    testWidgets('Add to my feeds sets feed list', (tester) async {
      await pumpScreen(tester);
      await tester.tap(find.bySemanticsLabel('Hashtag options'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Add to my feeds'));
      await tester.pumpAndSettle();

      expect(repo.hasFollowingFeedHashtag('plan6test'), isTrue);
      expect(find.text('Added to my feeds'), findsOneWidget);
    });

    testWidgets('embedded toolbar uses same a11y label for More', (
      tester,
    ) async {
      await pumpScreen(tester, embedded: true);
      expect(find.bySemanticsLabel('Hashtag options'), findsOneWidget);
    });
  });
}
