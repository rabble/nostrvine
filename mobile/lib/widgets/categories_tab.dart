// ABOUTME: Categories tab widget for the Explore screen
// ABOUTME: Shows a grid of category cards, tapping opens category video feed

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/feed/pooled_fullscreen_video_feed_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/composable_video_grid.dart';
import 'package:rxdart/rxdart.dart';

/// Tab widget displaying video categories in a grid.
///
/// When a category is selected, shows videos within that category.
/// Provides its own [CategoriesBloc] using the Funnelcake API client.
class CategoriesTab extends ConsumerWidget {
  const CategoriesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apiClient = ref.watch(funnelcakeApiClientProvider);

    return BlocProvider(
      create: (_) =>
          CategoriesBloc(funnelcakeApiClient: apiClient)
            ..add(const CategoriesLoadRequested()),
      child: BlocBuilder<CategoriesBloc, CategoriesState>(
        builder: (context, state) {
          if (state.selectedCategory != null) {
            return _CategoryVideoView(
              category: state.selectedCategory!,
              state: state,
            );
          }

          return _CategoriesGridView(state: state);
        },
      ),
    );
  }
}

class _CategoriesGridView extends StatelessWidget {
  const _CategoriesGridView({required this.state});

  final CategoriesState state;

  @override
  Widget build(BuildContext context) {
    if (state.categoriesStatus == CategoriesStatus.loading) {
      return const Center(child: BrandedLoadingIndicator());
    }

    if (state.categoriesStatus == CategoriesStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load categories',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<CategoriesBloc>().add(
                  const CategoriesLoadRequested(),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: VineTheme.backgroundColor),
              ),
            ),
          ],
        ),
      );
    }

    if (state.categories.isEmpty) {
      return const Center(
        child: Text(
          'No categories available',
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
        ),
      );
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        context.read<CategoriesBloc>().add(const CategoriesLoadRequested());
      },
      child: GridView.builder(
        padding: const EdgeInsets.all(12),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 3,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 0.95,
        ),
        itemCount: state.categories.length,
        itemBuilder: (context, index) {
          final category = state.categories[index];
          return _CategoryCard(category: category);
        },
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.category});

  final VideoCategory category;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        context.read<CategoriesBloc>().add(CategorySelected(category));
      },
      child: Container(
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: VineTheme.onSurfaceMuted.withValues(alpha: 0.2),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(category.emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(height: 6),
            Text(
              category.displayName,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${_formatCount(category.videoCount)} videos',
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _formatCount(int count) {
    if (count >= 1000) {
      final k = count / 1000;
      return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
    }
    return count.toString();
  }
}

class _CategoryVideoView extends StatefulWidget {
  const _CategoryVideoView({required this.category, required this.state});

  final VideoCategory category;
  final CategoriesState state;

  @override
  State<_CategoryVideoView> createState() => _CategoryVideoViewState();
}

class _CategoryVideoViewState extends State<_CategoryVideoView> {
  final StreamController<List<VideoEvent>> _videosStreamController =
      StreamController<List<VideoEvent>>.broadcast();

  @override
  void dispose() {
    _videosStreamController.close();
    super.dispose();
  }

  @override
  void didUpdateWidget(_CategoryVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.state.videos != oldWidget.state.videos &&
        widget.state.videos.isNotEmpty) {
      _videosStreamController.add(widget.state.videos);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _CategoryHeader(
          category: widget.category,
          sortOrder: widget.state.sortOrder,
        ),
        Expanded(child: _buildContent(context)),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (widget.state.videosStatus == CategoriesVideosStatus.loading) {
      return const Center(child: BrandedLoadingIndicator());
    }

    if (widget.state.videosStatus == CategoriesVideosStatus.error) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Could not load videos',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                context.read<CategoriesBloc>().add(
                  CategorySelected(widget.category),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
              ),
              child: const Text(
                'Retry',
                style: TextStyle(color: VineTheme.backgroundColor),
              ),
            ),
          ],
        ),
      );
    }

    if (widget.state.videos.isEmpty) {
      return const Center(
        child: Text(
          'No videos in this category',
          style: TextStyle(color: VineTheme.secondaryText, fontSize: 16),
        ),
      );
    }

    return ComposableVideoGrid(
      videos: widget.state.videos,
      onVideoTap: (videos, index) {
        context.push(
          PooledFullscreenVideoFeedScreen.path,
          extra: PooledFullscreenVideoFeedArgs(
            videosStream: _videosStreamController.stream.startWith(videos),
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
      useMasonryLayout: true,
      onLoadMore: () async {
        context.read<CategoriesBloc>().add(const CategoryVideosLoadMore());
      },
      isLoadingMore: widget.state.isLoadingMore,
      hasMoreContent: widget.state.hasMoreVideos,
      onRefresh: () async {
        context.read<CategoriesBloc>().add(CategorySelected(widget.category));
      },
    );
  }
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.category, required this.sortOrder});

  final VideoCategory category;
  final String sortOrder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: VineTheme.backgroundColor,
      child: Row(
        children: [
          GestureDetector(
            onTap: () {
              context.read<CategoriesBloc>().add(const CategoryDeselected());
            },
            child: const Icon(
              Icons.arrow_back_ios,
              color: VineTheme.whiteText,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          Text(category.emoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              category.displayName,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          _SortDropdown(currentSort: sortOrder),
        ],
      ),
    );
  }
}

class _SortDropdown extends StatelessWidget {
  const _SortDropdown({required this.currentSort});

  final String currentSort;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (sort) {
        context.read<CategoriesBloc>().add(CategoryVideosSortChanged(sort));
      },
      color: VineTheme.cardBackground,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _sortLabel(currentSort),
              style: const TextStyle(color: VineTheme.whiteText, fontSize: 13),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.arrow_drop_down,
              color: VineTheme.whiteText,
              size: 18,
            ),
          ],
        ),
      ),
      itemBuilder: (context) => [
        _sortMenuItem('trending', 'Hot'),
        _sortMenuItem('timestamp', 'New'),
        _sortMenuItem('classic', 'Classic'),
      ],
    );
  }

  PopupMenuItem<String> _sortMenuItem(String value, String label) {
    return PopupMenuItem<String>(
      value: value,
      child: Row(
        children: [
          if (currentSort == value)
            const Icon(Icons.check, color: VineTheme.vineGreen, size: 18)
          else
            const SizedBox(width: 18),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: VineTheme.whiteText)),
        ],
      ),
    );
  }

  static String _sortLabel(String sort) {
    switch (sort) {
      case 'trending':
        return 'Hot';
      case 'timestamp':
        return 'New';
      case 'classic':
        return 'Classic';
      default:
        return 'Hot';
    }
  }
}
