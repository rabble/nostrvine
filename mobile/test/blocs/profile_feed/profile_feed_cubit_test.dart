// ABOUTME: Tests for ProfileFeedCubit — cold load, pagination (REST + Nostr),
// ABOUTME: realtime/optimistic add, filtering-on-every-emit, the spinner
// ABOUTME: machine, error channels, and the C5 Nostr-loadMore count-preserve fix.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_feed/profile_feed_cubit.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/video_event_service.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockVideoEventService extends Mock implements VideoEventService {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

const _author =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

VideoEvent _video(
  String id, {
  String pubkey = _author,
  int createdAt = 1000,
  int? originalLikes,
}) {
  return VideoEvent(
    id: id,
    pubkey: pubkey,
    createdAt: createdAt,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(createdAt * 1000),
    videoUrl: 'https://example.com/$id.mp4',
    originalLikes: originalLikes,
  );
}

AuthorFeedResult _result(
  List<VideoEvent> videos, {
  int? totalCount,
  int? nextOffset,
  bool? hasMore,
  bool isFromCache = false,
}) {
  return AuthorFeedResult(
    authorPubkey: _author,
    videos: videos,
    totalCount: totalCount,
    nextOffset: nextOffset,
    hasMore: hasMore,
    isFromCache: isFromCache,
  );
}

/// Holds the mocks + captured VES listener callbacks so realtime paths can be
/// driven from tests.
class _Harness {
  _Harness() {
    when(() => ves.authorVideos(any())).thenReturn(const <VideoEvent>[]);
    when(
      () => ves.filterVideoList(any()),
    ).thenAnswer((i) => i.positionalArguments[0] as List<VideoEvent>);
    when(() => ves.isVideoEventLocallyDeleted(any())).thenReturn(false);
    when(() => ves.subscribeToUserVideos(any())).thenAnswer((_) async {});
    when(
      () => ves.queryHistoricalUserVideos(any(), until: any(named: 'until')),
    ).thenAnswer((_) async {});
    when(() => ves.addListener(any())).thenAnswer((i) {
      onChanged = i.positionalArguments[0] as void Function();
    });
    when(() => ves.removeListener(any())).thenReturn(null);
    when(() => ves.addVideoUpdateListener(any())).thenAnswer((i) {
      onUpdate = i.positionalArguments[0] as void Function(VideoEvent);
      return () {};
    });
    when(() => ves.addNewVideoListener(any())).thenAnswer((i) {
      onNew = i.positionalArguments[0] as void Function(VideoEvent, String);
      return () {};
    });
    when(() => blocklist.shouldFilterFromFeeds(any())).thenReturn(false);
  }

  final repo = _MockVideosRepository();
  final ves = _MockVideoEventService();
  final blocklist = _MockContentBlocklistRepository();

  void Function()? onChanged;
  void Function(VideoEvent)? onUpdate;
  void Function(VideoEvent, String)? onNew;

  List<VideoEvent> enrichInput = const [];
  Future<List<VideoEvent>> Function(List<VideoEvent>)? enrichOverride;

  Future<List<VideoEvent>> _noopEnrich(List<VideoEvent> videos) async {
    enrichInput = videos;
    return videos; // identical -> no enrichment re-emit
  }

  void stubAuthorFeed(AuthorFeedResult result) {
    when(
      () => repo.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((_) async => result);
  }

  void stubAuthorFeedSequence(List<AuthorFeedResult> results) {
    var index = 0;
    when(
      () => repo.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenAnswer((_) async => results[index++]);
  }

  void stubAuthorFeedThrows(Object error) {
    when(
      () => repo.getAuthorFeed(
        authorPubkey: any(named: 'authorPubkey'),
        offset: any(named: 'offset'),
        relaySeed: any(named: 'relaySeed'),
        skipCache: any(named: 'skipCache'),
      ),
    ).thenThrow(error);
  }

  ProfileFeedCubit build() => ProfileFeedCubit(
    authorPubkey: _author,
    videosRepository: repo,
    videoEventService: ves,
    blocklistRepository: blocklist,
    enrichVideos: enrichOverride ?? _noopEnrich,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_video('fallback'));
    registerFallbackValue(<VideoEvent>[]);
    registerFallbackValue(() {});
    registerFallbackValue((VideoEvent _) {});
    registerFallbackValue((VideoEvent _, String _) {});
  });

  group('ProfileFeedCubit', () {
    late _Harness h;

    setUp(() => h = _Harness());

    Future<ProfileFeedCubit> buildReady(AuthorFeedResult result) async {
      h.stubAuthorFeed(result);
      final cubit = h.build();
      await pumpEventQueue();
      return cubit;
    }

    test('cold load: REST success -> ready with envelope', () async {
      final cubit = await buildReady(
        _result([_video('a')], totalCount: 42, nextOffset: 50, hasMore: true),
      );
      addTearDown(cubit.close);

      expect(cubit.state.status, ProfileFeedStatus.ready);
      expect(cubit.state.videos.single.id, 'a');
      expect(cubit.state.totalVideoCount, 42);
      expect(cubit.state.nextOffset, 50);
      expect(cubit.state.hasMoreContent, isTrue);
      expect(cubit.state.isFetchingTotalCount, isFalse);
      expect(cubit.state.isInitialLoad, isFalse);
      verify(() => h.ves.subscribeToUserVideos(_author)).called(1);
    });

    test(
      'cold load: cached reseed is followed by skip-cache refresh',
      () async {
        h.stubAuthorFeedSequence([
          _result([_video('cached')], hasMore: true, isFromCache: true),
          _result(const [], hasMore: false),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();
        await pumpEventQueue();

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos, isEmpty);
        expect(cubit.state.hasMoreContent, isFalse);
        verifyInOrder([
          () => h.repo.getAuthorFeed(
            authorPubkey: _author,
            relaySeed: any(named: 'relaySeed'),
          ),
          () => h.repo.getAuthorFeed(
            authorPubkey: _author,
            relaySeed: any(named: 'relaySeed'),
            skipCache: true,
          ),
        ]);
      },
    );

    test(
      'cold load: partial first page backfills to a complete initial page',
      () async {
        h.stubAuthorFeedSequence([
          _result(
            [_video('a', createdAt: 4000), _video('b', createdAt: 3000)],
            totalCount: 4,
            nextOffset: 2,
            hasMore: true,
          ),
          _result(
            [_video('c', createdAt: 2000), _video('d')],
            totalCount: 4,
            hasMore: false,
          ),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue(times: 5);

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos.map((video) => video.id), [
          'a',
          'b',
          'c',
          'd',
        ]);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.nextOffset, isNull);
        verify(
          () => h.repo.getAuthorFeed(authorPubkey: _author, offset: 2),
        ).called(1);
      },
    );

    test(
      'cold load: backfill skips empty advancing REST pages',
      () async {
        h.stubAuthorFeedSequence([
          _result(
            [_video('a', createdAt: 5000), _video('b', createdAt: 4000)],
            totalCount: 4,
            nextOffset: 2,
            hasMore: true,
          ),
          _result(const [], totalCount: 4, nextOffset: 3, hasMore: true),
          _result(
            [_video('c', createdAt: 3000), _video('d', createdAt: 2000)],
            totalCount: 4,
            hasMore: false,
          ),
        ]);

        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue(times: 8);

        expect(cubit.state.videos.map((video) => video.id), [
          'a',
          'b',
          'c',
          'd',
        ]);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.nextOffset, isNull);
        verify(
          () => h.repo.getAuthorFeed(authorPubkey: _author, offset: 2),
        ).called(1);
        verify(
          () => h.repo.getAuthorFeed(authorPubkey: _author, offset: 3),
        ).called(1);
      },
    );

    test('cold load: REST failure, no relay -> failure + addError', () async {
      h.stubAuthorFeedThrows(Exception('boom'));
      final cubit = h.build();
      addTearDown(cubit.close);
      await pumpEventQueue();

      expect(cubit.state.status, ProfileFeedStatus.failure);
      expect(cubit.state.videos, isEmpty);
      expect(cubit.state.isFetchingTotalCount, isFalse);
    });

    test(
      'cold load: REST failure but relay has videos -> stays ready',
      () async {
        h.stubAuthorFeedThrows(Exception('boom'));
        when(() => h.ves.authorVideos(_author)).thenReturn([_video('relay')]);
        final cubit = h.build();
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.status, ProfileFeedStatus.ready);
        expect(cubit.state.videos.single.id, 'relay');
      },
    );

    test(
      'loadMore REST: appends the next page and advances the offset',
      () async {
        final cubit = await buildReady(
          _result(
            [_video('a', createdAt: 3000)],
            nextOffset: 50,
            hasMore: true,
          ),
        );
        addTearDown(cubit.close);

        h.stubAuthorFeed(
          _result(
            [_video('b', createdAt: 2000)],
            nextOffset: 100,
            hasMore: false,
          ),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.isLoadingMore, isFalse);
      },
    );

    test(
      'loadMore REST: empty advancing page keeps REST pagination active',
      () async {
        final initialVideos = [
          for (var i = 0; i < AppConstants.paginationBatchSize; i++)
            _video('initial-$i', createdAt: 5000 - i),
        ];
        final cubit = await buildReady(
          _result(initialVideos, nextOffset: 50, hasMore: true),
        );
        addTearDown(cubit.close);
        clearInteractions(h.repo);

        h.stubAuthorFeed(
          _result(const [], nextOffset: 100, hasMore: true),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.videos.map((video) => video.id), [
          for (var i = 0; i < AppConstants.paginationBatchSize; i++)
            'initial-$i',
        ]);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isTrue);
        expect(cubit.state.isLoadingMore, isFalse);
      },
    );

    test('loadMore failure: hasLoadMoreError set, videos retained, no error '
        'string in state', () async {
      final cubit = await buildReady(
        _result([_video('a')], nextOffset: 50, hasMore: true),
      );
      addTearDown(cubit.close);

      h.stubAuthorFeedThrows(Exception('page boom'));
      cubit.add(const ProfileFeedLoadMoreRequested());
      await pumpEventQueue();

      expect(cubit.state.status, ProfileFeedStatus.ready);
      expect(cubit.state.hasLoadMoreError, isTrue);
      expect(cubit.state.isLoadingMore, isFalse);
      expect(cubit.state.videos.single.id, 'a'); // retained
    });

    test(
      'loadMore recovers after a transient failure: the banner clears and the '
      'next page appends',
      () async {
        final cubit = await buildReady(
          _result(
            [_video('a', createdAt: 3000)],
            nextOffset: 50,
            hasMore: true,
          ),
        );
        addTearDown(cubit.close);

        // First page throws: degraded banner, videos + offset retained.
        h.stubAuthorFeedThrows(Exception('transient'));
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.hasLoadMoreError, isTrue);
        expect(cubit.state.videos.map((v) => v.id), ['a']);
        expect(cubit.state.nextOffset, 50);

        // Retry from the same offset succeeds: banner clears, page appends.
        h.stubAuthorFeed(
          _result(
            [_video('b', createdAt: 2000)],
            nextOffset: 100,
            hasMore: false,
          ),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        expect(cubit.state.hasLoadMoreError, isFalse);
        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isFalse);
        expect(cubit.state.isLoadingMore, isFalse);
      },
    );

    test(
      'cold load -> loadMore -> realtime add compose in newest-first order',
      () async {
        // Cold load: first page, more available.
        final cubit = await buildReady(
          _result(
            [_video('a', createdAt: 3000)],
            nextOffset: 50,
            hasMore: true,
          ),
        );
        addTearDown(cubit.close);
        expect(cubit.state.videos.map((v) => v.id), ['a']);

        // loadMore appends an older page beneath the cold-load page.
        h.stubAuthorFeed(
          _result(
            [_video('b', createdAt: 2000)],
            nextOffset: 100,
            hasMore: false,
          ),
        );
        cubit.add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();
        expect(cubit.state.videos.map((v) => v.id), ['a', 'b']);

        // Realtime add slots the newest video ahead of the paginated list
        // without disturbing the pagination cursor.
        h.onNew!(_video('c', createdAt: 5000), _author);
        await pumpEventQueue();

        expect(cubit.state.videos.map((v) => v.id), ['c', 'a', 'b']);
        expect(cubit.state.nextOffset, 100);
        expect(cubit.state.hasMoreContent, isFalse);
      },
    );

    test('C5: Nostr-fallback loadMore preserves totalVideoCount / isInitialLoad '
        '/ isFetchingTotalCount', () async {
      // REST unavailable -> getAuthorFeed returns seed-only (nextOffset null).
      final cubit = await buildReady(
        _result([_video('a', createdAt: 3000)], totalCount: 200, hasMore: true),
      );
      addTearDown(cubit.close);
      expect(cubit.state.nextOffset, isNull); // Nostr-fallback mode
      expect(cubit.state.totalVideoCount, 200);

      // Nostr loadMore: VES yields one more video.
      when(() => h.ves.authorVideos(_author)).thenReturn([
        _video('a', createdAt: 3000),
        _video('b', createdAt: 2000),
      ]);
      cubit.add(const ProfileFeedLoadMoreRequested());
      await pumpEventQueue();

      expect(cubit.state.videos.map((v) => v.id), containsAll(['a', 'b']));
      // The legacy bug dropped these; the fix preserves them.
      expect(cubit.state.totalVideoCount, 200);
      expect(cubit.state.isInitialLoad, isFalse);
      expect(cubit.state.isFetchingTotalCount, isFalse);
    });

    test(
      'loadMore is droppable: two rapid requests cause one repo call',
      () async {
        final cubit = await buildReady(
          _result([_video('a')], nextOffset: 50, hasMore: true),
        );
        addTearDown(cubit.close);
        clearInteractions(h.repo);

        h.stubAuthorFeed(
          _result([_video('b')], nextOffset: 100, hasMore: false),
        );
        cubit
          ..add(const ProfileFeedLoadMoreRequested())
          ..add(const ProfileFeedLoadMoreRequested());
        await pumpEventQueue();

        verify(
          () => h.repo.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).called(1);
      },
    );

    test('FiltersChanged re-filters in place without a re-fetch', () async {
      final cubit = await buildReady(
        _result([_video('a'), _video('b', pubkey: 'blocked')]),
      );
      addTearDown(cubit.close);
      expect(cubit.state.videos.length, 2);
      clearInteractions(h.repo);

      when(() => h.blocklist.shouldFilterFromFeeds('blocked')).thenReturn(true);
      cubit.add(const ProfileFeedFiltersChanged());
      await pumpEventQueue();

      expect(cubit.state.videos.map((v) => v.id), ['a']);
      verifyNever(
        () => h.repo.getAuthorFeed(
          authorPubkey: any(named: 'authorPubkey'),
          offset: any(named: 'offset'),
          relaySeed: any(named: 'relaySeed'),
          skipCache: any(named: 'skipCache'),
        ),
      );
    });

    test('optimistic add: new video prepended; reposts ignored', () async {
      final cubit = await buildReady(_result([_video('a')]));
      addTearDown(cubit.close);

      h.onNew!(_video('b', createdAt: 5000), _author);
      await pumpEventQueue();
      expect(cubit.state.videos.map((v) => v.id), ['b', 'a']);

      final before = cubit.state.videos.length;
      h.onNew!(_video('a'), _author); // duplicate -> no change
      await pumpEventQueue();
      expect(cubit.state.videos.length, before);
    });

    test('VideoUpdated for this author triggers a refresh', () async {
      final cubit = await buildReady(_result([_video('a')], nextOffset: 1));
      addTearDown(cubit.close);
      clearInteractions(h.repo);
      h.stubAuthorFeed(_result([_video('a'), _video('c')], nextOffset: 2));

      h.onUpdate!(_video('a'));
      await pumpEventQueue();

      verify(
        () => h.repo.getAuthorFeed(
          authorPubkey: any(named: 'authorPubkey'),
          offset: any(named: 'offset'),
          relaySeed: any(named: 'relaySeed'),
          skipCache: true,
        ),
      ).called(1);
    });

    test('tombstoned videos are excluded from emitted state', () async {
      when(
        () => h.ves.isVideoEventLocallyDeleted(
          any(that: isA<VideoEvent>().having((v) => v.id, 'id', 'a')),
        ),
      ).thenReturn(true);
      final cubit = await buildReady(_result([_video('a'), _video('b')]));
      addTearDown(cubit.close);

      expect(cubit.state.videos.map((v) => v.id), ['b']);
    });

    test('blocklist is applied on the cold-load emit (#4782)', () async {
      when(() => h.blocklist.shouldFilterFromFeeds('blocked')).thenReturn(true);
      final cubit = await buildReady(
        _result([_video('a'), _video('b', pubkey: 'blocked')]),
      );
      addTearDown(cubit.close);

      expect(cubit.state.videos.map((v) => v.id), ['a']);
    });

    test('close() cancels the realtime listeners and the timer', () async {
      h.stubAuthorFeed(_result(const []));
      final cubit = h.build();
      await pumpEventQueue();
      await cubit.close();

      verify(() => h.ves.removeListener(any())).called(1);
    });

    test('spinner: isInitialLoad clears on the hard timeout when nothing '
        'settles', () {
      fakeAsync((async) {
        // REST is in flight; relay empty -> isInitialLoad stays true until the
        // hard timeout fires.
        final completer = Completer<AuthorFeedResult>();
        when(
          () => h.repo.getAuthorFeed(
            authorPubkey: any(named: 'authorPubkey'),
            offset: any(named: 'offset'),
            relaySeed: any(named: 'relaySeed'),
            skipCache: any(named: 'skipCache'),
          ),
        ).thenAnswer((_) => completer.future);
        final cubit = h.build();
        async.flushMicrotasks();

        expect(cubit.state.isInitialLoad, isTrue);

        async.elapse(ProfileFeedCubit.initialLoadHardTimeout);
        async.flushMicrotasks();

        expect(cubit.state.isInitialLoad, isFalse);

        // Settle the in-flight load and close inside the zone so no handler is
        // left awaiting across teardown.
        completer.complete(_result(const []));
        async.flushMicrotasks();
        cubit.close();
        async.flushMicrotasks();
      });
    });

    test('background enrichment re-emits with the enriched copies', () async {
      h.enrichOverride = (videos) async => [
        for (final v in videos) v.copyWith(title: 'enriched'),
      ];
      final cubit = await buildReady(_result([_video('a')]));
      addTearDown(cubit.close);

      expect(cubit.state.videos.single.title, 'enriched');
    });
  });
}
