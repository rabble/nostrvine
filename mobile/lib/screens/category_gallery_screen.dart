// ABOUTME: Dedicated category gallery screen with visible sort controls.
// ABOUTME: Preserves category context and opens the pooled fullscreen feed.

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:rxdart/rxdart.dart';

class CategoryGalleryScreen extends ConsumerStatefulWidget {
  const CategoryGalleryScreen({required this.category, super.key});

  static const routeName = 'category-gallery';
  static const path = '/categories/:categoryName';

  static String locationFor(String categoryName) {
    return '/categories/${Uri.encodeComponent(categoryName)}';
  }

  final VideoCategory category;

  @override
  ConsumerState<CategoryGalleryScreen> createState() =>
      _CategoryGalleryScreenState();
}

class _CategoryGalleryScreenState extends ConsumerState<CategoryGalleryScreen> {
  final StreamController<List<VideoEvent>> _videosStreamController =
      StreamController<List<VideoEvent>>.broadcast();

  @override
  void dispose() {
    _videosStreamController.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final categoriesRepository = ref.watch(categoriesRepositoryProvider);
    final currentUserPubkey = ref
        .watch(authServiceProvider)
        .currentPublicKeyHex;

    return BlocProvider(
      create: (_) => CategoriesBloc(
        categoriesRepository: categoriesRepository,
        currentUserPubkey: currentUserPubkey,
      )..add(CategorySelected(widget.category)),
      child: BlocListener<CategoriesBloc, CategoriesState>(
        listenWhen: (previous, current) => previous.videos != current.videos,
        listener: (_, state) {
          _videosStreamController.add(state.videos);
        },
        child: BlocBuilder<CategoriesBloc, CategoriesState>(
          builder: (context, state) {
            return CategoryGalleryView(
              category: widget.category,
              state: state,
              onBack: context.pop,
              onRetry: () {
                context.read<CategoriesBloc>().add(
                  CategorySelected(widget.category),
                );
              },
              onSortChanged: (sort) {
                context.read<CategoriesBloc>().add(
                  CategoryVideosSortChanged(sort),
                );
              },
              onRefresh: () async {
                context.read<CategoriesBloc>().add(
                  CategorySelected(widget.category),
                );
              },
              onLoadMore: () async {
                context.read<CategoriesBloc>().add(
                  const CategoryVideosLoadMore(),
                );
              },
              onVideoTap: (videos, index) {
                context.push(
                  PooledFullscreenVideoFeedScreen.path,
                  extra: PooledFullscreenVideoFeedArgs(
                    videosStream: _videosStreamController.stream.startWith(
                      videos,
                    ),
                    initialIndex: index,
                    onLoadMore: () {
                      context.read<CategoriesBloc>().add(
                        const CategoryVideosLoadMore(),
                      );
                    },
                    contextTitle: widget.category.displayName,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class CategoryGalleryView extends StatelessWidget {
  const CategoryGalleryView({
    required this.category,
    required this.state,
    required this.onBack,
    required this.onRetry,
    required this.onSortChanged,
    required this.onVideoTap,
    required this.onLoadMore,
    required this.onRefresh,
    this.galleryOverride,
    super.key,
  });

  final VideoCategory category;
  final CategoriesState state;
  final VoidCallback onBack;
  final VoidCallback onRetry;
  final ValueChanged<String> onSortChanged;
  final void Function(List<VideoEvent> videos, int index) onVideoTap;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget? galleryOverride;

  @override
  Widget build(BuildContext context) {
    final visuals = CategoryVisuals.forCategory(category, 0);

    return ColoredBox(
      color: VineTheme.surfaceContainerHigh,
      child: Column(
        children: [
          _CategoryGalleryHeader(
            category: category,
            visuals: visuals,
            selectedSort: state.sortOrder,
            onBack: onBack,
            onSortChanged: onSortChanged,
          ),
          Expanded(
            child: _CategoryGalleryBody(
              state: state,
              onRetry: onRetry,
              onVideoTap: onVideoTap,
              onLoadMore: onLoadMore,
              onRefresh: onRefresh,
              galleryOverride: galleryOverride,
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryGalleryBody extends StatelessWidget {
  const _CategoryGalleryBody({
    required this.state,
    required this.onRetry,
    required this.onVideoTap,
    required this.onLoadMore,
    required this.onRefresh,
    this.galleryOverride,
  });

  final CategoriesState state;
  final VoidCallback onRetry;
  final void Function(List<VideoEvent>, int) onVideoTap;
  final Future<void> Function() onLoadMore;
  final Future<void> Function() onRefresh;
  final Widget? galleryOverride;

  @override
  Widget build(BuildContext context) {
    switch (state.videosStatus) {
      case CategoriesVideosStatus.initial:
      case CategoriesVideosStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CategoriesVideosStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load videos',
                style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        );
      case CategoriesVideosStatus.loaded:
        if (state.videos.isEmpty && galleryOverride == null) {
          return const Center(
            child: Text(
              'No videos in this category',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
            ),
          );
        }

        return galleryOverride ??
            ComposableVideoGrid(
              videos: state.videos,
              onVideoTap: onVideoTap,
              useMasonryLayout: true,
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
              onLoadMore: onLoadMore,
              onRefresh: onRefresh,
              isLoadingMore: state.isLoadingMore,
              hasMoreContent: state.hasMoreVideos,
            );
    }
  }
}

class _CategoryGalleryHeader extends StatelessWidget {
  const _CategoryGalleryHeader({
    required this.category,
    required this.visuals,
    required this.selectedSort,
    required this.onBack,
    required this.onSortChanged,
  });

  final VideoCategory category;
  final CategoryVisuals visuals;
  final String selectedSort;
  final VoidCallback onBack;
  final ValueChanged<String> onSortChanged;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: VineTheme.navGreen,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 108,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              if (visuals.assetPath != null)
                Positioned(
                  top: -18,
                  right: 56,
                  child: Image.asset(
                    visuals.assetPath!,
                    height: 104,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const SizedBox.shrink(),
                  ),
                ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      DivineIconButton(
                        icon: DivineIconName.caretLeft,
                        type: DivineIconButtonType.secondary,
                        size: DivineIconButtonSize.small,
                        onPressed: onBack,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          category.displayName,
                          style: VineTheme.titleMediumFont().copyWith(
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      DivineIconButton(
                        icon: DivineIconName.slidersHorizontal,
                        type: DivineIconButtonType.secondary,
                        size: DivineIconButtonSize.small,
                        semanticLabel: 'Category sort options',
                        onPressed: () async {
                          final selected =
                              await VineBottomSheetSelectionMenu.show(
                                context: context,
                                selectedValue: selectedSort,
                                options: _categorySortOptions,
                              );
                          if (selected != null && selected != selectedSort) {
                            onSortChanged(selected);
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

const _categorySortOptions = <VineBottomSheetSelectionOptionData>[
  VineBottomSheetSelectionOptionData(label: 'Hot', value: 'trending'),
  VineBottomSheetSelectionOptionData(label: 'New', value: 'timestamp'),
  VineBottomSheetSelectionOptionData(label: 'Classic', value: 'classic'),
  VineBottomSheetSelectionOptionData(label: 'For You', value: 'forYou'),
];
