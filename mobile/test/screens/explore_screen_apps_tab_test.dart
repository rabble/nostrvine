import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/for_you_provider.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:openvine/services/video_event_service.dart';

import '../helpers/test_provider_overrides.dart';

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

  late _MockVideoEventService videoEventService;

  setUp(() {
    videoEventService = _MockVideoEventService();

    when(
      () => videoEventService.addVideoUpdateListener(any()),
    ).thenReturn(() {});
    when(() => videoEventService.filterVideoList(any())).thenAnswer(
      (invocation) => invocation.positionalArguments.first as List<VideoEvent>,
    );
    when(() => videoEventService.discoveryVideos).thenReturn([]);
    when(() => videoEventService.popularNowVideos).thenReturn([]);
    when(() => videoEventService.isSubscribed(any())).thenReturn(false);
    // ignore: invalid_use_of_protected_member
    when(() => videoEventService.hasListeners).thenReturn(false);
  });

  testWidgets(
    'ExploreScreen shows Integrated Apps tab when feature flag is enabled',
    (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
            classicVinesAvailableProvider.overrideWith(
              (ref) async => false,
            ),
            forYouAvailableProvider.overrideWithValue(false),
            allListsProvider.overrideWith(
              (ref) async => (
                userLists: <UserList>[],
                curatedLists: <CuratedList>[],
              ),
            ),
            curatedListsStateProvider.overrideWith(
              _FakeCuratedListsState.new,
            ),
            isFeatureEnabledProvider(
              FeatureFlag.integratedApps,
            ).overrideWithValue(true),
          ],
          child: const MaterialApp(home: Scaffold(body: ExploreScreen())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Integrated Apps'), findsOneWidget);
    },
  );

  testWidgets(
    'ExploreScreen hides Integrated Apps tab when feature flag is disabled',
    (tester) async {
      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: [
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
            videoEventServiceProvider.overrideWithValue(videoEventService),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
            classicVinesAvailableProvider.overrideWith(
              (ref) async => false,
            ),
            forYouAvailableProvider.overrideWithValue(false),
            allListsProvider.overrideWith(
              (ref) async => (
                userLists: <UserList>[],
                curatedLists: <CuratedList>[],
              ),
            ),
            curatedListsStateProvider.overrideWith(
              _FakeCuratedListsState.new,
            ),
            isFeatureEnabledProvider(
              FeatureFlag.integratedApps,
            ).overrideWithValue(false),
          ],
          child: const MaterialApp(home: Scaffold(body: ExploreScreen())),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Integrated Apps'), findsNothing);
    },
  );
}
