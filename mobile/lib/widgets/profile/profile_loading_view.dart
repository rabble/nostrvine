// ABOUTME: Skeleton shell shown while a profile screen is resolving its
// ABOUTME: route context, profile, or video list — no text, no spinner.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

/// Skeleton placeholder shown before the real profile screen is ready.
///
/// Mimics the post-load layout (banner area, avatar, identity block,
/// stats row, action row, tab bar, video grid) so transitioning to the
/// real screen does not pop. Driven by a single top-level [Skeletonizer]
/// per the #4183 review: "configure once and the skeletonizer handles
/// the rest automatically."
class ProfileLoadingView extends StatelessWidget {
  const ProfileLoadingView({super.key});

  @override
  Widget build(BuildContext context) {
    return const Material(
      type: MaterialType.transparency,
      color: VineTheme.surfaceBackground,
      child: Skeletonizer(
        effect: vineSkeletonEffect,
        child: _ProfileShell(),
      ),
    );
  }
}

class _ProfileShell extends StatelessWidget {
  const _ProfileShell();

  static const _bannerHeight = 200.0;
  static const _avatarSize = 144.0;

  @override
  Widget build(BuildContext context) {
    final safeAreaTop = MediaQuery.paddingOf(context).top;

    return CustomScrollView(
      physics: const NeverScrollableScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: Stack(
            children: [
              const _BannerPlaceholder(height: _bannerHeight),
              Padding(
                padding: EdgeInsets.only(top: safeAreaTop),
                child: const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: 60),
                    Center(child: _AvatarPlaceholder(size: _avatarSize)),
                    SizedBox(height: 48),
                    _NamePlaceholder(),
                    SizedBox(height: 8),
                    _IdentifierPlaceholder(),
                    SizedBox(height: 24),
                    _StatsRowPlaceholder(),
                    SizedBox(height: 24),
                    _ActionRowPlaceholder(),
                    SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SliverToBoxAdapter(child: _TabBarPlaceholder()),
        const SliverToBoxAdapter(child: _VideoGridPlaceholder()),
      ],
    );
  }
}

class _BannerPlaceholder extends StatelessWidget {
  const _BannerPlaceholder({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: height,
      decoration: const BoxDecoration(color: VineTheme.containerLow),
    );
  }
}

class _AvatarPlaceholder extends StatelessWidget {
  const _AvatarPlaceholder({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: VineTheme.containerLow,
          borderRadius: BorderRadius.circular(56),
        ),
      ),
    );
  }
}

class _NamePlaceholder extends StatelessWidget {
  const _NamePlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 24,
      width: 180,
      decoration: BoxDecoration(
        color: VineTheme.containerLow,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _IdentifierPlaceholder extends StatelessWidget {
  const _IdentifierPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 16,
      width: 140,
      decoration: BoxDecoration(
        color: VineTheme.containerLow,
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

class _StatsRowPlaceholder extends StatelessWidget {
  const _StatsRowPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          4,
          (_) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 24,
                width: 40,
                decoration: BoxDecoration(
                  color: VineTheme.containerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                height: 14,
                width: 56,
                decoration: BoxDecoration(
                  color: VineTheme.containerLow,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionRowPlaceholder extends StatelessWidget {
  const _ActionRowPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: List.generate(
          3,
          (i) => Expanded(
            child: Padding(
              padding: EdgeInsets.only(left: i == 0 ? 0 : 8),
              child: Container(
                height: 44,
                decoration: BoxDecoration(
                  color: VineTheme.containerLow,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TabBarPlaceholder extends StatelessWidget {
  const _TabBarPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(
          5,
          (_) => Container(
            height: 28,
            width: 28,
            decoration: BoxDecoration(
              color: VineTheme.containerLow,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
      ),
    );
  }
}

class _VideoGridPlaceholder extends StatelessWidget {
  const _VideoGridPlaceholder();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 3,
      mainAxisSpacing: 2,
      crossAxisSpacing: 2,
      childAspectRatio: 0.66,
      children: List.generate(
        9,
        (_) => const DecoratedBox(
          decoration: BoxDecoration(color: VineTheme.containerLow),
        ),
      ),
    );
  }
}
