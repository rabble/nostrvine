// ABOUTME: Skeleton loader with shimmer animation for comments loading state
// ABOUTME: Uses skeletonizer package for Material 3-style loading placeholder

import 'package:flutter/material.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton loader for comments loading state
/// Shows multiple placeholder items with shimmer (gradient sweep) animation
class CommentsSkeletonLoader extends StatelessWidget {
  const CommentsSkeletonLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'comments_loading_indicator',
      label: 'Loading comments',
      child: Skeletonizer(
        enabled: true,
        effect: ShimmerEffect(
          baseColor: VineTheme.iconButtonBackground,
          highlightColor: VineTheme.iconButtonBackground.withValues(
            alpha: VineTheme.iconButtonBackground.a * 0.6,
          ),
          duration: const Duration(milliseconds: 1500),
        ),
        child: ListView.builder(
          padding: EdgeInsets.zero,
          itemCount: 6,
          itemBuilder: (context, index) => const _CommentSkeletonItem(),
        ),
      ),
    );
  }
}

/// Single comment skeleton placeholder item
/// Shows avatar and text lines mimicking actual comment structure from Figma
/// Total height: 156px per Figma specification
class _CommentSkeletonItem extends StatelessWidget {
  const _CommentSkeletonItem();

  // Surface container color from Figma (green tint)
  static const _surfaceColor = VineTheme.outlinedDisabled;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: SizedBox(
        height: 156,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.leaf(
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Skeleton.leaf(
                  child: Container(
                    width: 124,
                    height: 20,
                    margin: const EdgeInsets.only(top: 8),
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Skeleton.leaf(
                  child: Container(
                    width: 315,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Skeleton.leaf(
                  child: Container(
                    width: 262,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Skeleton.leaf(
              child: Container(
                width: 124,
                height: 16,
                decoration: BoxDecoration(
                  color: _surfaceColor,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
