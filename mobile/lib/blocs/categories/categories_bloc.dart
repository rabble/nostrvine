// ABOUTME: BLoC for fetching and managing video categories from Funnelcake API
// ABOUTME: Handles loading categories list and videos within a selected category

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/repositories/categories_repository.dart';

part 'categories_event.dart';
part 'categories_state.dart';

/// BLoC for video categories.
///
/// Fetches the category list via [CategoriesRepository] (which owns the
/// in-memory TTL cache) and manages loading videos for a selected category
/// with pagination.
class CategoriesBloc extends Bloc<CategoriesEvent, CategoriesState> {
  CategoriesBloc({
    required CategoriesRepository categoriesRepository,
    this.currentUserPubkey,
  }) : _categoriesRepository = categoriesRepository,
       _apiClient = categoriesRepository.apiClient,
       super(const CategoriesState()) {
    on<CategoriesLoadRequested>(_onLoadRequested);
    on<CategorySelected>(_onCategorySelected);
    on<CategoryVideosLoadMore>(_onLoadMore);
    on<CategoryVideosSortChanged>(_onSortChanged);
    on<CategoryDeselected>(_onDeselected);
  }

  final CategoriesRepository _categoriesRepository;
  final FunnelcakeApiClient _apiClient;
  final String? currentUserPubkey;

  Future<void> _onLoadRequested(
    CategoriesLoadRequested event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.categoriesStatus == CategoriesStatus.loading) return;

    emit(state.copyWith(categoriesStatus: CategoriesStatus.loading));

    try {
      final categories = await _categoriesRepository.getCategories();

      emit(
        state.copyWith(
          categoriesStatus: CategoriesStatus.loaded,
          categories: categories,
        ),
      );
    } on FunnelcakeException catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(categoriesStatus: CategoriesStatus.error));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(categoriesStatus: CategoriesStatus.error));
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
      await _loadVideosForSelection(
        emit: emit,
        category: event.category,
        sortOrder: state.sortOrder,
      );
    } on FunnelcakeException catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(videosStatus: CategoriesVideosStatus.error));
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(videosStatus: CategoriesVideosStatus.error));
    }
  }

  Future<void> _onLoadMore(
    CategoryVideosLoadMore event,
    Emitter<CategoriesState> emit,
  ) async {
    if (state.selectedCategory == null ||
        !state.hasMoreVideos ||
        state.isLoadingMore ||
        state.sortOrder == 'forYou') {
      return;
    }

    emit(state.copyWith(isLoadingMore: true));

    try {
      final lastVideo = state.videos.lastOrNull;
      final before = lastVideo?.createdAt;

      final videoStats = await _apiClient.getVideosByCategory(
        category: state.selectedCategory!.name,
        before: before,
        sort: _apiSortFor(state.sortOrder),
        platform: _platformFor(state.sortOrder),
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
      await _loadVideosForSelection(
        emit: emit,
        category: state.selectedCategory!,
        sortOrder: event.sort,
      );
    } catch (e, stackTrace) {
      addError(e, stackTrace);
      emit(state.copyWith(videosStatus: CategoriesVideosStatus.error));
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

  Future<void> _loadVideosForSelection({
    required Emitter<CategoriesState> emit,
    required VideoCategory category,
    required String sortOrder,
  }) async {
    if (sortOrder == 'forYou') {
      final recommendedVideos = await _loadRecommendedVideos(category);
      if (recommendedVideos.isNotEmpty) {
        emit(
          state.copyWith(
            videosStatus: CategoriesVideosStatus.loaded,
            videos: recommendedVideos,
            hasMoreVideos: false,
          ),
        );
        return;
      }

      final hotVideoStats = await _apiClient.getVideosByCategory(
        category: category.name,
      );
      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.loaded,
          videos: hotVideoStats.map((s) => s.toVideoEvent()).toList(),
          hasMoreVideos: false,
        ),
      );
      return;
    }

    final videoStats = await _apiClient.getVideosByCategory(
      category: category.name,
      sort: _apiSortFor(sortOrder),
      platform: _platformFor(sortOrder),
    );

    emit(
      state.copyWith(
        videosStatus: CategoriesVideosStatus.loaded,
        videos: videoStats.map((s) => s.toVideoEvent()).toList(),
        hasMoreVideos: videoStats.length >= 50,
      ),
    );
  }

  Future<List<VideoEvent>> _loadRecommendedVideos(
    VideoCategory category,
  ) async {
    final pubkey = currentUserPubkey;
    if (pubkey == null || pubkey.isEmpty) {
      return const [];
    }

    final response = await _apiClient.getRecommendations(
      pubkey: pubkey,
      category: category.name,
      limit: 50,
    );
    return response.videos.map((video) => video.toVideoEvent()).toList();
  }

  String _apiSortFor(String sortOrder) {
    return sortOrder == 'classic' ? 'loops' : sortOrder;
  }

  String? _platformFor(String sortOrder) {
    return sortOrder == 'classic' ? 'vine' : null;
  }
}
