import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide NostrAppDirectoryEntry;
import 'package:nostr_app_bridge_repository/nostr_app_bridge_repository.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/user_list_service.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockNostrAppDirectoryService extends Mock
    implements NostrAppDirectoryService {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true;
}

class _FakeCuratedListsState extends CuratedListsState {
  @override
  CuratedListService? get service => null;

  @override
  Future<List<CuratedList>> build() async => const [];
}

void main() {
  setUpAll(() {
    registerFallbackValue(SubscriptionType.discovery);
    registerFallbackValue(() {});
  });

  testWidgets(
    'ExploreScreen includes the Integrated Apps tab and embedded directory',
    (
      tester,
    ) async {
      final directoryService = _MockNostrAppDirectoryService();
      final videoEventService = _MockVideoEventService();

      // ignore: unnecessary_lambdas
      when(() => directoryService.fetchApprovedApps()).thenAnswer(
        _fetchApprovedAppsAnswer,
      );
      when(
        () => videoEventService.addVideoUpdateListener(any()),
      ).thenReturn(() {});
      when(() => videoEventService.filterVideoList(any())).thenAnswer(
        (invocation) =>
            invocation.positionalArguments.first as List<VideoEvent>,
      );
      when(() => videoEventService.discoveryVideos).thenReturn([]);
      when(() => videoEventService.popularNowVideos).thenReturn([]);
      when(() => videoEventService.isSubscribed(any())).thenReturn(false);
      // ignore: invalid_use_of_protected_member
      when(() => videoEventService.hasListeners).thenReturn(false);

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
            ),
            forceExploreTabNameProvider.overrideWith((ref) => 'apps'),
            exploreTabVideosProvider.overrideWith((ref) => null),
            classicVinesAvailableProvider.overrideWith((ref) async => false),
            forYouAvailableProvider.overrideWithValue(false),
            allListsProvider.overrideWith(
              (ref) async => (
                userLists: <UserList>[],
                curatedLists: <CuratedList>[],
              ),
            ),
            curatedListsStateProvider.overrideWith(_FakeCuratedListsState.new),
            nostrAppDirectoryServiceProvider.overrideWithValue(
              directoryService,
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ExploreScreen())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Integrated Apps'), findsOneWidget);
      expect(find.text('Primal'), findsOneWidget);
      expect(find.text('Fast Nostr feeds and messages'), findsOneWidget);
    },
  );
}

Future<List<NostrAppDirectoryEntry>> _fetchApprovedAppsAnswer(
  Invocation _,
) async => [_fixtureApp()];

NostrAppDirectoryEntry _fixtureApp() {
  return NostrAppDirectoryEntry(
    id: 'app-primal',
    slug: 'primal',
    name: 'Primal',
    tagline: 'Fast Nostr feeds and messages',
    description: 'A vetted Nostr client for timelines and DMs.',
    iconUrl: 'https://cdn.divine.video/primal.png',
    launchUrl: 'https://primal.net',
    allowedOrigins: const ['https://primal.net'],
    allowedMethods: const ['getPublicKey', 'signEvent'],
    allowedSignEventKinds: const [1, 7],
    promptRequiredFor: const ['signEvent'],
    status: 'approved',
    sortOrder: 1,
    createdAt: DateTime.parse('2026-03-24T08:00:00Z'),
    updatedAt: DateTime.parse('2026-03-25T08:00:00Z'),
  );
}
