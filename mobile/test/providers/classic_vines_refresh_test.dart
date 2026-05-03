// ABOUTME: Tests ClassicVines refresh recovery after transient API failures
// ABOUTME: Verifies refresh does not strand the feed without existing data

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/classic_vines_provider.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/og_viner_cache_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:riverpod/riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _TestFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => true;
}

Completer<bool>? _loadingAvailabilityCompleter;

class _LoadingFunnelcakeAvailable extends FunnelcakeAvailable {
  @override
  Future<bool> build() async => _loadingAvailabilityCompleter!.future;
}

void main() {
  group(ClassicVinesFeed, () {
    late _MockFunnelcakeApiClient mockFunnelcakeClient;
    late _MockVideoEventService mockVideoEventService;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late SharedPreferences sharedPreferences;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      sharedPreferences = await SharedPreferences.getInstance();

      mockFunnelcakeClient = _MockFunnelcakeApiClient();
      mockVideoEventService = _MockVideoEventService();
      mockBlocklistRepository = _MockContentBlocklistRepository();

      when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
      when(() => mockVideoEventService.discoveryVideos).thenReturn(const []);
      when(
        () => mockVideoEventService.filterVideoList(any()),
      ).thenAnswer((invocation) {
        return invocation.positionalArguments.first as List<VideoEvent>;
      });
      when(
        () => mockBlocklistRepository.shouldFilterFromFeeds(any()),
      ).thenReturn(false);
    });

    ProviderContainer createContainer() {
      return ProviderContainer(
        overrides: [
          appReadyProvider.overrideWithValue(true),
          sharedPreferencesProvider.overrideWithValue(sharedPreferences),
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          videoEventServiceProvider.overrideWithValue(mockVideoEventService),
          contentBlocklistRepositoryProvider.overrideWithValue(
            mockBlocklistRepository,
          ),
          funnelcakeAvailableProvider.overrideWith(
            _TestFunnelcakeAvailable.new,
          ),
        ],
      );
    }

    test(
      'loads a random page-aligned classics page within the top classics',
      () async {
        final offsets = <int>[];
        final limits = <int>[];
        when(
          () => mockFunnelcakeClient.getClassicVines(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((invocation) async {
          limits.add(invocation.namedArguments[#limit] as int);
          offsets.add(invocation.namedArguments[#offset] as int);
          return [_videoStats('classic-${offsets.length}')];
        });

        for (var i = 0; i < 12; i++) {
          final container = createContainer();
          addTearDown(container.dispose);

          await container.read(funnelcakeAvailableProvider.future);
          await container.read(classicVinesFeedProvider.future);
        }

        expect(offsets, hasLength(12));
        expect(offsets, everyElement(inInclusiveRange(0, 400)));
        expect(
          offsets,
          everyElement(predicate<int>((offset) => offset % 50 == 0)),
        );
        expect(offsets.toSet(), hasLength(greaterThan(1)));
        expect(limits, everyElement(lessThanOrEqualTo(50)));
      },
    );

    test('caches OG Viner pubkeys from loaded archive videos', () async {
      when(
        () =>
            mockFunnelcakeClient.getClassicVines(offset: any(named: 'offset')),
      ).thenAnswer((_) async {
        return [
          _videoStats(
            'classic-og',
            pubkey:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            isOriginalVine: true,
          ),
        ];
      });

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      await container.read(classicVinesFeedProvider.future);
      await Future<void>.delayed(Duration.zero);

      final cache = container.read(ogVinerCacheServiceProvider);
      expect(
        cache.isOgViner(
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
        ),
        isTrue,
      );
    });

    test('refresh selects a fresh random classics page', () async {
      final offsets = <int>[];
      when(
        () => mockFunnelcakeClient.getClassicVines(
          offset: any(named: 'offset'),
        ),
      ).thenAnswer((invocation) async {
        offsets.add(invocation.namedArguments[#offset] as int);
        return [_videoStats('classic-${offsets.length}')];
      });

      final container = createContainer();
      addTearDown(container.dispose);

      await container.read(funnelcakeAvailableProvider.future);
      await container.read(classicVinesFeedProvider.future);
      for (var i = 0; i < 12; i++) {
        await container.read(classicVinesFeedProvider.notifier).refresh();
      }

      expect(offsets, hasLength(13));
      expect(offsets, everyElement(inInclusiveRange(0, 400)));
      expect(
        offsets,
        everyElement(predicate<int>((offset) => offset % 50 == 0)),
      );
      expect(offsets.toSet(), hasLength(greaterThan(1)));
    });

    test(
      'tries the next classics page when the first page has no videos',
      () async {
        final offsets = <int>[];
        when(
          () => mockFunnelcakeClient.getClassicVines(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((invocation) async {
          final offset = invocation.namedArguments[#offset] as int;
          offsets.add(offset);
          if (offsets.length == 1) {
            return const [];
          }
          return [_videoStats('classic-recovered')];
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final state = await container.read(classicVinesFeedProvider.future);

        expect(state.videos.map((video) => video.id), ['classic-recovered']);
        expect(offsets, hasLength(2));
        expect(offsets[1], offsets[0] + 50);
      },
    );

    test(
      'retries the first classics page after a transient API error',
      () async {
        final offsets = <int>[];
        var calls = 0;
        when(
          () => mockFunnelcakeClient.getClassicVines(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((invocation) async {
          calls++;
          final offset = invocation.namedArguments[#offset] as int;
          offsets.add(offset);
          if (calls == 1) {
            throw Exception('network unavailable');
          }
          return [_videoStats('classic-retry')];
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final state = await container.read(classicVinesFeedProvider.future);

        expect(state.videos.map((video) => video.id), ['classic-retry']);
        expect(offsets, hasLength(2));
        expect(offsets[1], offsets[0]);
      },
    );

    test(
      'preserves existing videos with an error when refresh API fails',
      () async {
        var calls = 0;
        when(
          () => mockFunnelcakeClient.getClassicVines(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return [_videoStats('classic-initial')];
          }
          throw Exception('server unavailable');
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'classic-initial',
        ]);

        await container.read(classicVinesFeedProvider.notifier).refresh();

        final asyncState = container.read(classicVinesFeedProvider);
        expect(asyncState.hasError, isFalse);

        final refreshedState = asyncState.value!;
        expect(refreshedState.videos.map((video) => video.id), [
          'classic-initial',
        ]);
        expect(refreshedState.isRefreshing, isFalse);
        expect(refreshedState.error, contains('server unavailable'));
      },
    );

    test(
      'preserves existing videos when refresh API returns an empty page',
      () async {
        var calls = 0;
        when(
          () => mockFunnelcakeClient.getClassicVines(
            offset: any(named: 'offset'),
          ),
        ).thenAnswer((_) async {
          calls++;
          if (calls == 1) {
            return [_videoStats('classic-initial')];
          }
          return const [];
        });

        final container = createContainer();
        addTearDown(container.dispose);

        await container.read(funnelcakeAvailableProvider.future);
        final initialState = await container.read(
          classicVinesFeedProvider.future,
        );
        expect(initialState.videos.map((video) => video.id), [
          'classic-initial',
        ]);

        await container.read(classicVinesFeedProvider.notifier).refresh();

        final refreshedState = container.read(classicVinesFeedProvider).value!;
        expect(refreshedState.videos.map((video) => video.id), [
          'classic-initial',
        ]);
        expect(refreshedState.isRefreshing, isFalse);
        expect(refreshedState.error, contains('returned no videos'));
      },
    );

    test('stays loading while funnelcake availability is still resolving', () {
      _loadingAvailabilityCompleter = Completer<bool>();

      final container = ProviderContainer(
        overrides: [
          funnelcakeAvailableProvider.overrideWith(
            _LoadingFunnelcakeAvailable.new,
          ),
        ],
      );
      addTearDown(() {
        _loadingAvailabilityCompleter = null;
        container.dispose();
      });

      expect(container.read(classicVinesAvailableProvider).isLoading, isTrue);
    });
  });
}

VideoStats _videoStats(
  String id, {
  String? pubkey,
  bool isOriginalVine = false,
}) {
  return VideoStats(
    id: id,
    pubkey: pubkey ?? 'author-$id',
    createdAt: DateTime(2026, 3, 17),
    kind: 34236,
    dTag: id,
    title: id,
    thumbnail: 'https://example.com/$id.jpg',
    videoUrl: 'https://example.com/$id.mp4',
    reactions: 0,
    comments: 0,
    reposts: 0,
    engagementScore: 0,
    loops: 100,
    rawTags: isOriginalVine ? const {'platform': 'vine'} : const {},
  );
}
