// ABOUTME: Tests for FeaturedTabVideosCubit paging and failure handling.
// ABOUTME: Server order must survive appending; the client never re-sorts.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/featured_tabs/featured_tab_surface_telemetry.dart';
import 'package:openvine/blocs/featured_tabs/featured_tab_videos_cubit.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

class _MockFeaturedTabsRepository extends Mock
    implements FeaturedTabsRepository {}

class _MockTelemetry extends Mock implements FeaturedTabSurfaceTelemetry {}

const _tabId = 'ft_a1b2c3d4';

VideoEvent _video(String id) => VideoEvent(
  id: id,
  pubkey: '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef',
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.utc(2026, 2, 15),
);

void main() {
  group(FeaturedTabVideosCubit, () {
    late _MockFeaturedTabsRepository repository;
    late _MockTelemetry telemetry;

    setUp(() {
      repository = _MockFeaturedTabsRepository();
      telemetry = _MockTelemetry();
      when(() => telemetry.start()).thenReturn(null);
      when(
        () => telemetry.completeLoaded(
          itemCount: any(named: 'itemCount'),
          hasMore: any(named: 'hasMore'),
        ),
      ).thenAnswer((_) async {});
      when(telemetry.completeFailure).thenAnswer((_) async {});
    });

    FeaturedTabVideosCubit buildCubit() => FeaturedTabVideosCubit(
      repository: repository,
      tabId: _tabId,
      telemetry: telemetry,
    );

    void stubPage(FeaturedTabVideosPage page, {String? cursor}) {
      when(
        () => repository.loadVideos(tabId: _tabId, cursor: cursor),
      ).thenAnswer((_) async => page);
    }

    void stubFailure({String? cursor}) {
      when(
        () => repository.loadVideos(tabId: _tabId, cursor: cursor),
      ).thenThrow(const FunnelcakeException('offline'));
    }

    group('load', () {
      blocTest<FeaturedTabVideosCubit, FeaturedTabVideosState>(
        'emits the first page in the order received',
        setUp: () => stubPage(
          FeaturedTabVideosPage(
            videos: [_video('curated'), _video('approved')],
            nextCursor: 'cursor-1',
            hasMore: true,
          ),
        ),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(
            cubit.state.videos.map((v) => v.id),
            equals(['curated', 'approved']),
          );
          expect(cubit.state.status, equals(FeaturedTabVideosStatus.ready));
          expect(cubit.state.hasMore, isTrue);
          expect(cubit.state.nextCursor, equals('cursor-1'));
        },
      );

      blocTest<FeaturedTabVideosCubit, FeaturedTabVideosState>(
        'reports an empty page as ready rather than failed',
        setUp: () => stubPage(const FeaturedTabVideosPage(videos: [])),
        build: buildCubit,
        act: (cubit) => cubit.load(),
        verify: (cubit) {
          expect(cubit.state.status, equals(FeaturedTabVideosStatus.ready));
          expect(cubit.state.isEmpty, isTrue);
        },
      );

      blocTest<FeaturedTabVideosCubit, FeaturedTabVideosState>(
        'emits failure and reports the error when the page request throws',
        setUp: stubFailure,
        build: buildCubit,
        act: (cubit) => cubit.load(),
        errors: () => [isA<FunnelcakeException>()],
        verify: (cubit) {
          expect(cubit.state.status, equals(FeaturedTabVideosStatus.failure));
        },
      );

      blocTest<FeaturedTabVideosCubit, FeaturedTabVideosState>(
        'replaces prior videos when reloaded',
        setUp: () => stubPage(FeaturedTabVideosPage(videos: [_video('first')])),
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          stubPage(FeaturedTabVideosPage(videos: [_video('second')]));
          await cubit.load();
        },
        verify: (cubit) {
          expect(cubit.state.videos.map((v) => v.id), equals(['second']));
        },
      );

      test('reports the loaded page to analytics', () async {
        stubPage(
          FeaturedTabVideosPage(
            videos: [_video('a')],
            hasMore: true,
            nextCursor: 'cursor-1',
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.load();

        verify(() => telemetry.start()).called(1);
        verify(
          () => telemetry.completeLoaded(itemCount: 1, hasMore: true),
        ).called(1);
      });

      test('reports a failed load to analytics', () async {
        stubFailure();
        final cubit = buildCubit();
        addTearDown(cubit.close);

        await cubit.load();

        verify(telemetry.completeFailure).called(1);
      });
    });

    group('loadMore', () {
      blocTest<FeaturedTabVideosCubit, FeaturedTabVideosState>(
        'appends the next page after the first',
        setUp: () {
          stubPage(
            FeaturedTabVideosPage(
              videos: [_video('page-1')],
              nextCursor: 'cursor-1',
              hasMore: true,
            ),
          );
          stubPage(
            FeaturedTabVideosPage(videos: [_video('page-2')]),
            cursor: 'cursor-1',
          );
        },
        build: buildCubit,
        act: (cubit) async {
          await cubit.load();
          await cubit.loadMore();
        },
        verify: (cubit) {
          expect(
            cubit.state.videos.map((v) => v.id),
            equals(['page-1', 'page-2']),
          );
          expect(cubit.state.hasMore, isFalse);
        },
      );

      test('does nothing when no further page exists', () async {
        stubPage(FeaturedTabVideosPage(videos: [_video('only')]));
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();
        clearInteractions(repository);

        await cubit.loadMore();

        verifyNever(
          () => repository.loadVideos(
            tabId: any(named: 'tabId'),
            cursor: any(named: 'cursor'),
          ),
        );
      });

      test('keeps the loaded page when the next page fails', () async {
        stubPage(
          FeaturedTabVideosPage(
            videos: [_video('page-1')],
            nextCursor: 'cursor-1',
            hasMore: true,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        stubFailure(cursor: 'cursor-1');
        await cubit.loadMore();

        expect(cubit.state.videos.map((v) => v.id), equals(['page-1']));
        expect(cubit.state.isLoadingMore, isFalse);
        expect(cubit.state.nextCursor, equals('cursor-1'));
      });

      test('can retry the next page after a failure', () async {
        stubPage(
          FeaturedTabVideosPage(
            videos: [_video('page-1')],
            nextCursor: 'cursor-1',
            hasMore: true,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        stubFailure(cursor: 'cursor-1');
        await cubit.loadMore();

        stubPage(
          FeaturedTabVideosPage(videos: [_video('page-2')]),
          cursor: 'cursor-1',
        );
        await cubit.loadMore();

        expect(
          cubit.state.videos.map((v) => v.id),
          equals(['page-1', 'page-2']),
        );
      });

      test(
        'can still page after a failed refresh over loaded content',
        () async {
          stubPage(
            FeaturedTabVideosPage(
              videos: [_video('page-1')],
              nextCursor: 'cursor-1',
              hasMore: true,
            ),
          );
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();

          stubFailure();
          await cubit.load();

          expect(cubit.state.videos.map((v) => v.id), equals(['page-1']));
          expect(cubit.state.status, equals(FeaturedTabVideosStatus.failure));
          expect(cubit.state.hasMore, isTrue);
          expect(cubit.state.nextCursor, equals('cursor-1'));

          stubPage(
            FeaturedTabVideosPage(videos: [_video('page-2')]),
            cursor: 'cursor-1',
          );
          await cubit.loadMore();

          expect(
            cubit.state.videos.map((v) => v.id),
            equals(['page-1', 'page-2']),
          );
        },
      );

      test(
        'discards a page whose list was replaced by a refresh mid-flight',
        () async {
          // The grid wires onLoadMore and onRefresh to the same cubit, so a
          // pull-to-refresh can land while a page request is still open.
          // Appending then would splice a page computed against the old cursor
          // onto the refreshed list and destroy the server's ordering.
          stubPage(
            FeaturedTabVideosPage(
              videos: [_video('old-1')],
              nextCursor: 'cursor-old',
              hasMore: true,
            ),
          );
          final cubit = buildCubit();
          addTearDown(cubit.close);
          await cubit.load();

          final pendingPage = Completer<FeaturedTabVideosPage>();
          when(
            () => repository.loadVideos(tabId: _tabId, cursor: 'cursor-old'),
          ).thenAnswer((_) => pendingPage.future);
          final paging = cubit.loadMore();

          stubPage(
            FeaturedTabVideosPage(
              videos: [_video('fresh-1')],
              nextCursor: 'cursor-fresh',
              hasMore: true,
            ),
          );
          await cubit.load();
          pendingPage.complete(
            FeaturedTabVideosPage(videos: [_video('old-2')]),
          );
          await paging;

          expect(cubit.state.videos.map((v) => v.id), equals(['fresh-1']));
          expect(cubit.state.nextCursor, equals('cursor-fresh'));
          expect(cubit.state.hasMore, isTrue);
        },
      );

      test('refuses to start while a refresh is in flight', () async {
        stubPage(
          FeaturedTabVideosPage(
            videos: [_video('page-1')],
            nextCursor: 'cursor-1',
            hasMore: true,
          ),
        );
        final cubit = buildCubit();
        addTearDown(cubit.close);
        await cubit.load();

        final pendingRefresh = Completer<FeaturedTabVideosPage>();
        when(
          () => repository.loadVideos(tabId: _tabId),
        ).thenAnswer((_) => pendingRefresh.future);
        final refreshing = cubit.load();

        await cubit.loadMore();

        verifyNever(
          () => repository.loadVideos(tabId: _tabId, cursor: 'cursor-1'),
        );
        expect(cubit.state.isLoadingMore, isFalse);

        pendingRefresh.complete(
          FeaturedTabVideosPage(videos: [_video('page-1')]),
        );
        await refreshing;
      });
    });
  });
}
