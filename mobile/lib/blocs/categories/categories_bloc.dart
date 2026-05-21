// ABOUTME: BLoC for fetching and managing video categories from Funnelcake API
// ABOUTME: Handles loading categories list and videos within a selected category

import 'package:categories_repository/categories_repository.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';

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
    ContentBlocklistRepository? contentBlocklistRepository,
    this.currentUserPubkey,
  }) : _categoriesRepository = categoriesRepository,
       _blocklistRepository = contentBlocklistRepository,
       super(const CategoriesState()) {
    on<CategoriesLoadRequested>(_onLoadRequested);
    on<CategorySelected>(_onCategorySelected);
    on<CategoryVideosLoadMore>(_onLoadMore);
    on<CategoryVideosSortChanged>(_onSortChanged);
    on<CategoryDeselected>(_onDeselected);
    on<CategoriesBlocklistChanged>(_onBlocklistChanged);
  }

  final CategoriesRepository _categoriesRepository;
  final ContentBlocklistRepository? _blocklistRepository;
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

      final page = await _categoriesRepository.getVideosForCategory(
        category: state.selectedCategory!.name,
        before: before,
        sort: _apiSortFor(state.sortOrder),
        platform: _platformFor(state.sortOrder),
      );

      // Deduplicate
      final existingIds = state.videos.map((v) => v.id).toSet();
      final uniqueNew = page.videos
          .where((v) => !existingIds.contains(v.id))
          .toList();

      emit(
        state.copyWith(
          videos: [...state.videos, ...uniqueNew],
          hasMoreVideos: page.hasMore,
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

      final hotVideosPage = await _categoriesRepository.getVideosForCategory(
        category: category.name,
      );
      emit(
        state.copyWith(
          videosStatus: CategoriesVideosStatus.loaded,
          videos: hotVideosPage.videos,
          hasMoreVideos: false,
        ),
      );
      return;
    }

    final page = await _categoriesRepository.getVideosForCategory(
      category: category.name,
      sort: _apiSortFor(sortOrder),
      platform: _platformFor(sortOrder),
    );

    emit(
      state.copyWith(
        videosStatus: CategoriesVideosStatus.loaded,
        videos: page.videos,
        hasMoreVideos: page.hasMore,
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

    return _categoriesRepository.getRecommendedVideos(
      pubkey: pubkey,
      category: category.name,
    );
  }

  void _onBlocklistChanged(
    CategoriesBlocklistChanged event,
    Emitter<CategoriesState> emit,
  ) {
    final pubkey = event.blockedPubkey;
    if (pubkey != null) {
      final filtered = state.videos.where((v) => v.pubkey != pubkey).toList();
      if (filtered.length != state.videos.length) {
        emit(state.copyWith(videos: filtered));
      }
      return;
    }

    final service = _blocklistRepository;
    if (service == null) return;

    final filtered = service.filterContent<VideoEvent>(
      state.videos,
      (video) => video.pubkey,
    );
    if (filtered.length != state.videos.length) {
      emit(state.copyWith(videos: filtered));
    }
  }

  String _apiSortFor(String sortOrder) {
    return sortOrder == 'classic' ? 'loops' : sortOrder;
  }

  String? _platformFor(String sortOrder) {
    return sortOrder == 'classic' ? 'vine' : null;
  }
}
