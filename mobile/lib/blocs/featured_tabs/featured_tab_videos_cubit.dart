// ABOUTME: Cubit paging one featured tab's videos through the repository.
// ABOUTME: Preserves server order; no client-side sorting or filtering.

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/featured_tabs/featured_tab_surface_telemetry.dart';
import 'package:openvine/repositories/featured_tabs_repository.dart';

part 'featured_tab_videos_state.dart';

/// Loads and pages the videos for a single featured tab.
///
/// The tab is addressed by its opaque configuration id; this cubit never
/// learns which hashtag backs it. Pages are appended in arrival order so the
/// server's curated-then-approved ordering survives to the grid.
class FeaturedTabVideosCubit extends Cubit<FeaturedTabVideosState> {
  /// Creates a cubit paging the tab identified by [tabId].
  FeaturedTabVideosCubit({
    required FeaturedTabsRepository repository,
    required String tabId,
    FeaturedTabSurfaceTelemetry? telemetry,
  }) : _repository = repository,
       _tabId = tabId,
       _telemetry = telemetry ?? FeaturedTabSurfaceTelemetry(configId: tabId),
       super(const FeaturedTabVideosState());

  final FeaturedTabsRepository _repository;
  final String _tabId;
  final FeaturedTabSurfaceTelemetry _telemetry;

  /// Loads the first page, replacing anything already loaded.
  Future<void> load() async {
    if (isClosed) return;
    _telemetry.start();
    emit(state.copyWith(status: FeaturedTabVideosStatus.loading));

    try {
      final page = await _repository.loadVideos(tabId: _tabId);
      if (isClosed) return;
      emit(
        FeaturedTabVideosState(
          status: FeaturedTabVideosStatus.ready,
          videos: page.videos,
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
      await _telemetry.completeLoaded(
        itemCount: page.videos.length,
        hasMore: page.hasMore,
      );
    } on FunnelcakeException catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(state.copyWith(status: FeaturedTabVideosStatus.failure));
      await _telemetry.completeFailure();
    }
  }

  /// Appends the next page, if one exists and none is already in flight.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (isClosed || state.isLoadingMore || !state.hasMore || cursor == null) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));

    try {
      final page = await _repository.loadVideos(tabId: _tabId, cursor: cursor);
      if (isClosed) return;
      emit(
        FeaturedTabVideosState(
          status: FeaturedTabVideosStatus.ready,
          videos: [...state.videos, ...page.videos],
          nextCursor: page.nextCursor,
          hasMore: page.hasMore,
        ),
      );
    } on FunnelcakeException catch (e, stackTrace) {
      if (isClosed) return;
      addError(e, stackTrace);
      emit(state.copyWith(isLoadingMore: false));
    }
  }
}
