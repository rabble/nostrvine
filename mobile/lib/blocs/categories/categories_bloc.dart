// ABOUTME: BLoC for fetching and managing video categories from Funnelcake API
// ABOUTME: Handles loading categories list and videos within a selected category

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/models/video_category.dart';

part 'categories_event.dart';
part 'categories_state.dart';

/// BLoC for video categories.
///
/// Fetches category list from the Funnelcake REST API and manages
/// loading videos for a selected category with pagination.
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc({required FunnelcakeApiClient funnelcakeApiClient})
    : _apiClient = funnelcakeApiClient,
      super(const CategoriesState()) {
    on<CategoriesLoadRequested>(_onLoadRequested);
    on<CategorySelected>(_onCategorySelected);
    on<CategoryVideosLoadMore>(_onLoadMore);
    on<CategoryVideosSortChanged>(_onSortChanged);
    on<CategoryDeselected>(_onDeselected);
  }

  final FunnelcakeApiClient _apiClient;

  Future<void> _onLoadRequested(
    CategoriesLoadRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.categoriesStatus == CategoriesStatus.loading) return;

    emit(state.copyWith(categoriesStatus: CategoriesStatus.loading));

    try {
      final categoriesJson = await _apiClient.getCategories(limit: 100);
      final categories = categoriesJson
          .map(VideoCategory.fromJson)
          .where((c) => c.name.isNotEmpty && c.videoCount > 0)
          .toList();
      final indexedCategories = categories.indexed.toList()
        ..sort((left, right) {
          final featuredComparison = left.$2.featuredRank.compareTo(
            right.$2.featuredRank,
          );
          if (featuredComparison != 0) {
            return featuredComparison;
          }
          return left.$1.compareTo(right.$1);
        });
      final orderedCategories = indexedCategories
          .map((entry) => entry.$2)
          .toList();

      emit(
        state.copyWith(
          categoriesStatus: CategoriesStatus.loaded,
          categories: orderedCategories,
        ),
      );
    } on FunnelcakeException catch (e) {
      emit(
        state.copyWith(
          categoriesStatus: CategoriesStatus.error,
          errorMessage: e.toString(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          categoriesStatus: CategoriesStatus.error,
          errorMessage: 'Failed to load categories: $e',
        ),
      );
    }
  }

  Future<void> _onCategorySelected(
    CategorySelected event,
    Emitter<CategoriesState> emit,
  ) async {
    emit(
      state.copyWith(
        selectedCategory: event.category,
        videosStatus: CategoriesVideosStatus.loading,
        videos: const [],
        hasMoreVideos: true,
      ),
    );

    try {
      final isClassic = state.sortOrder == 'classic';
      final videoStats = await _apiClient.getVideosByCategory(
        category: event.category.name,
        sort: isClassic ? 'loops' : state.sortOrder,
        platform: isClassic ? 'vine' : null,
      );

      final videos = videoStats.map((s) => s.toVideoEvent()).toList();

      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.loaded,
          videos: videos,
          hasMoreVideos: videoStats.length >= 50,
        ),
      );
    } on FunnelcakeException catch (e) {
      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.error,
          errorMessage: e.toString(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.error,
          errorMessage: 'Failed to load category videos: $e',
        ),
      );
    }
  }

  Future<void> _onLoadMore(
    CategoryVideosLoadMore event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.selectedCategory == null ||
        !state.hasMoreVideos ||
        state.isLoadingMore) {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final lastVideo = state.videos.lastOrNull;
      final before = lastVideo?.createdAt;

      final isClassic = state.sortOrder == 'classic';
      final videoStats = await _apiClient.getVideosByCategory(
        category: state.selectedCategory!.name,
        before: before,
        sort: isClassic ? 'loops' : state.sortOrder,
        platform: isClassic ? 'vine' : null,
      );

      final newVideos = videoStats.map((s) => s.toVideoEvent()).toList();

      // Deduplicate
      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNew = newVideos
          .where((v) => !existingIds.contains(v.id))
          .toList();

      emit(
        state.copyWith(
          videos: [...state.videos, ...uniqueNew],
          hasMoreVideos: videoStats.length >= 50,
          isLoadingMore: false,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isLoadingMore: false));
    }
  }

  Future<void> _onSortChanged(
    CategoryVideosSortChanged event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.selectedCategory == null || state.sortOrder == event.sort) {
      return;
    }

    emit(
      state.copyWith(
        sortOrder: event.sort,
        videosStatus: CategoriesVideosStatus.loading,
        videos: const [],
      ),
    );

    try {
      final isClassic = event.sort == 'classic';
      final videoStats = await _apiClient.getVideosByCategory(
        category: state.selectedCategory!.name,
        sort: isClassic ? 'loops' : event.sort,
        platform: isClassic ? 'vine' : null,
      );

      final videos = videoStats.map((s) => s.toVideoEvent()).toList();

      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.loaded,
          videos: videos,
          hasMoreVideos: videoStats.length >= 50,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.error,
          errorMessage: 'Failed to load videos: $e',
        ),
      );
    }
  }

  void _onDeselected(CategoryDeselected event, Emitter<CategoriesState> emit) {
    emit(
      state.copyWith(
        clearSelectedCategory: true,
        videosStatus: CategoriesVideosStatus.initial,
        videos: const [],
      ),
    );
  }
}
