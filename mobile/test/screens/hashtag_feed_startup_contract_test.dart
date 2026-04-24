import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
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

  group('HashtagFeedScreen startup contract', () {
    late _MockHashtagService mockHashtagService;
    late _MockFunnelcakeApiClient mockFunnelcakeApiClient;

    setUp(() {
      mockHashtagService = _MockHashtagService();
      mockFunnelcakeApiClient = _MockFunnelcakeApiClient();

      when(() => mockHashtagService.getVideosByHashtags(any())).thenReturn([]);
    });

    Future<void> pumpHashtagFeed(WidgetTester tester, String hashtag) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final followedRepo = FollowedHashtagsRepository(
        prefs: prefs,
        profileStorageKey: 'hashtag_feed_startup_contract_profile',
        followingFeedStorageKey: 'hashtag_feed_startup_contract_feed',
      );
      addTearDown(() async {
        await followedRepo.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hashtagServiceProvider.overrideWith((ref) => mockHashtagService),
            funnelcakeApiClientProvider.overrideWithValue(
              mockFunnelcakeApiClient,
            ),
            followedHashtagsRepositoryProvider.overrideWithValue(followedRepo),
          ],
          child: MaterialApp(
            locale: const Locale('en'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: HashtagFeedScreen(hashtag: hashtag),
          ),
        ),
      );
    }

    testWidgets(
      'keeps loading until the initial source answers, then shows empty state even if websocket subscribe hangs',
      (tester) async {
        final subscribeCompleter = Completer<void>();
        final trendingCompleter = Completer<List<VideoStats>>();
        final classicCompleter = Completer<List<VideoStats>>();
        addTearDown(() {
          if (!subscribeCompleter.isCompleted) {
            subscribeCompleter.complete();
          }
          if (!trendingCompleter.isCompleted) {
            trendingCompleter.complete(const []);
          }
          if (!classicCompleter.isCompleted) {
            classicCompleter.complete(const []);
          }
        });

        when(() => mockFunnelcakeApiClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeApiClient.getVideosByHashtag(
            hashtag: any(named: 'hashtag'),
          ),
        ).thenAnswer((_) => trendingCompleter.future);
        when(
          () => mockFunnelcakeApiClient.getClassicVideosByHashtag(
            hashtag: any(named: 'hashtag'),
          ),
        ).thenAnswer((_) => classicCompleter.future);
        when(
          () => mockHashtagService.subscribeToHashtagVideos(
            any(),
            limit: any(named: 'limit'),
            until: any(named: 'until'),
          ),
        ).thenAnswer((_) => subscribeCompleter.future);

        await pumpHashtagFeed(tester, 'nostr');

        expect(find.text('Loading videos about #nostr...'), findsOneWidget);

        await tester.pump();
        await tester.pump();

        expect(find.text('Loading videos about #nostr...'), findsOneWidget);
        expect(find.text('No videos found for #nostr'), findsNothing);

        trendingCompleter.complete(const []);
        classicCompleter.complete(const []);

        await tester.pump();
        await tester.pump();

        expect(find.text('Loading videos about #nostr...'), findsNothing);
        expect(find.text('No videos found for #nostr'), findsOneWidget);
      },
    );
  });
}
