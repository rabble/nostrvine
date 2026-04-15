// ABOUTME: Dedicated category gallery screen with visible sort controls.
// ABOUTME: Preserves category context and opens the pooled fullscreen feed.

import 'dart:async';
import 'dart:math' as math;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_category_name.dart';
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
                    contextTitle: localizedCategoryName(
                      context.l10n,
                      widget.category.name,
                    ),
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
        minimum: const EdgeInsets.only(top: 24),
        child: SizedBox(
          height: 108,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _CategoryHeaderActionButton(
                    decorationKey: const Key('category-header-back-button'),
                    icon: DivineIconName.caretLeft,
                    onPressed: onBack,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 18),
                    child: Text(
                      localizedCategoryName(context.l10n, category.name),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VineTheme.titleMediumFont().copyWith(
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _CategoryHeaderMascotSlot(visuals: visuals),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _CategoryHeaderActionButton(
                    decorationKey: const Key('category-header-filter-button'),
                    icon: DivineIconName.funnelSimple,
                    semanticLabel: 'Category sort options',
                    onPressed: () async {
                      final selected = await _showCategorySortSheet(
                        context: context,
                        selectedValue: selectedSort,
                      );
                      if (selected != null && selected != selectedSort) {
                        onSortChanged(selected);
                      }
                    },
                  ),
                ),
              ],
            ),
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

const _categoryHeaderActionFill = Color(0xFF3E0C1F);
const _categoryHeaderActionBorder = Color(0x40FFFFFF);
const _categorySortDivider = Color(0xFF001A12);
const _categoryActionShadows = <BoxShadow>[
  BoxShadow(
    color: Color(0x1A000000),
    offset: Offset(0.4, 0.4),
    blurRadius: 0.6,
  ),
  BoxShadow(color: Color(0x1A000000), offset: Offset(1, 1), blurRadius: 1),
];

Future<String?> _showCategorySortSheet({
  required BuildContext context,
  required String selectedValue,
}) {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: VineTheme.transparent,
    barrierColor: VineTheme.scrim65,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _CategorySortSheet(selectedValue: selectedValue);
    },
  );
}

class _CategoryHeaderActionButton extends StatelessWidget {
  const _CategoryHeaderActionButton({
    required this.decorationKey,
    required this.icon,
    required this.onPressed,
    this.semanticLabel,
  });

  final Key decorationKey;
  final DivineIconName icon;
  final VoidCallback onPressed;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel,
      button: true,
      child: Material(
        color: VineTheme.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: DecoratedBox(
            key: decorationKey,
            decoration: BoxDecoration(
              color: _categoryHeaderActionFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _categoryHeaderActionBorder, width: 2),
              boxShadow: _categoryActionShadows,
            ),
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: DivineIcon(icon: icon, color: VineTheme.onSurface),
            ),
          ),
        ),
      ),
    );
  }
}

class _CategoryHeaderMascotSlot extends StatelessWidget {
  const _CategoryHeaderMascotSlot({required this.visuals});

  final CategoryVisuals visuals;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      key: const Key('category-header-mascot-slot'),
      width: 149,
      height: 90,
      child: visuals.assetPath == null
          ? const SizedBox.shrink()
          : OverflowBox(
              maxWidth: 149,
              maxHeight: 132,
              alignment: Alignment.topCenter,
              child: Transform.translate(
                offset: const Offset(0, -12),
                child: Transform.rotate(
                  angle: 8 * math.pi / 180,
                  child: SvgPicture.asset(
                    visuals.assetPath!,
                    height: 104,
                    width: 132,
                  ),
                ),
              ),
            ),
    );
  }
}

class _CategorySortSheet extends StatelessWidget {
  const _CategorySortSheet({required this.selectedValue});

  final String selectedValue;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        key: const Key('category-sort-sheet'),
        decoration: const BoxDecoration(
          color: VineTheme.navGreen,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 32,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: _categorySortDivider)),
              ),
              child: Center(
                child: Container(
                  key: const Key('category-sort-sheet-handle'),
                  width: 64,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final option in _categorySortOptions)
                    _CategorySortSheetOption(
                      option: option,
                      isSelected: option.value == selectedValue,
                      onTap: () => Navigator.of(context).pop(option.value),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategorySortSheetOption extends StatelessWidget {
  const _CategorySortSheetOption({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final VineBottomSheetSelectionOptionData option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: VineTheme.transparent,
      child: InkWell(
        onTap: onTap,
        child: DecoratedBox(
          key: Key('category-sort-option-${option.value}'),
          decoration: BoxDecoration(
            color: isSelected
                ? VineTheme.iconButtonBackground
                : VineTheme.navGreen,
            border: const Border(
              bottom: BorderSide(color: _categorySortDivider),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
            child: Row(
              children: [
                Expanded(
                  child: Text(option.label, style: VineTheme.titleMediumFont()),
                ),
                if (isSelected)
                  const DivineIcon(
                    icon: DivineIconName.check,
                    color: VineTheme.vineGreen,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
