// ABOUTME: Categories discovery tab for the Explore screen.
// ABOUTME: Renders the redesigned pinned-first category list and navigates to category detail.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/categories/categories_bloc.dart';
import 'package:openvine/models/video_category.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/screens/category_gallery_screen.dart';
import 'package:openvine/widgets/categories/category_visuals.dart';

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
          return CategoriesDiscoveryView(
            state: state,
            onRetry: () {
              context.read<CategoriesBloc>().add(
                const CategoriesLoadRequested(),
              );
            },
            onCategoryTap: (category) {
              context.push(
                CategoryGalleryScreen.locationFor(category.name),
                extra: category,
              );
            },
          );
        },
      ),
    );
  }
}

class CategoriesDiscoveryView extends StatelessWidget {
  const CategoriesDiscoveryView({
    required this.state,
    required this.onCategoryTap,
    required this.onRetry,
    super.key,
  });

  final CategoriesState state;
  final ValueChanged<VideoCategory> onCategoryTap;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    switch (state.categoriesStatus) {
      case CategoriesStatus.loading:
        return const Center(child: CircularProgressIndicator());
      case CategoriesStatus.error:
        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load categories',
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ),
        );
      case CategoriesStatus.loaded:
        if (state.categories.isEmpty) {
          return const Center(
            child: Text(
              'No categories available',
              style: TextStyle(color: Colors.white70, fontSize: 16),
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          itemCount: state.categories.length,
          separatorBuilder: (_, index) => const SizedBox(height: 8),
          itemBuilder: (context, index) {
            final category = state.categories[index];
            return _CategoryTile(
              category: category,
              visuals: CategoryVisuals.forCategory(category, index),
              onTap: () => onCategoryTap(category),
            );
          },
        );
      case CategoriesStatus.initial:
        return const SizedBox.shrink();
    }
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.category,
    required this.visuals,
    required this.onTap,
  });

  final VideoCategory category;
  final CategoryVisuals visuals;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: category.displayName,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(24),
          child: Ink(
            height: 96,
            decoration: BoxDecoration(
              color: visuals.backgroundColor,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        category.displayName,
                        style: TextStyle(
                          color: visuals.foregroundColor,
                          fontSize: 24,
                          height: 32 / 24,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_formatCount(category.videoCount)} videos',
                        style: TextStyle(
                          color: visuals.foregroundColor.withValues(alpha: 0.9),
                          fontSize: 12,
                          height: 16 / 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Positioned(
                  right: 18,
                  top: 0,
                  bottom: 0,
                  child: IgnorePointer(
                    child: visuals.assetPath != null
                        ? Image.asset(
                            visuals.assetPath!,
                            height: 88,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) =>
                                _FallbackEmojiBadge(
                                  emoji: category.emoji,
                                  color: visuals.foregroundColor,
                                ),
                          )
                        : _FallbackEmojiBadge(
                            emoji: category.emoji,
                            color: visuals.foregroundColor,
                          ),
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

class _FallbackEmojiBadge extends StatelessWidget {
  const _FallbackEmojiBadge({required this.emoji, required this.color});

  final String emoji;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(emoji, style: const TextStyle(fontSize: 28)),
    );
  }
}

String _formatCount(int count) {
  if (count >= 1000) {
    final k = count / 1000;
    return '${k.toStringAsFixed(k.truncateToDouble() == k ? 0 : 1)}K';
  }
  return count.toString();
}
