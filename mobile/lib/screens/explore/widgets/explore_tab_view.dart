// ABOUTME: The explore grid TabBarView with its per-tab children and the
// ABOUTME: buffered-videos banner overlay.

import 'package:flutter/material.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/screens/apps/apps_directory_screen.dart';
import 'package:openvine/screens/explore/tabs/explore_lists_tab.dart';
import 'package:openvine/screens/explore/widgets/explore_buffered_videos_banner.dart';
import 'package:openvine/widgets/categories_tab.dart';
import 'package:openvine/widgets/classic_vines_tab.dart';
import 'package:openvine/widgets/for_you_tab.dart';
import 'package:openvine/widgets/new_videos_tab.dart';
import 'package:openvine/widgets/popular_videos_tab.dart';

/// The grid-mode tab content for the explore screen.
///
/// Children are ordered to match [tabsState.tabNames] and [controller]'s tab
/// count. The buffered-videos banner overlays only the New/Trending tabs.
class ExploreTabView extends StatelessWidget {
  /// Creates the explore tab view.
  const ExploreTabView({
    required this.controller,
    required this.tabsState,
    super.key,
  });

  /// Controller driving tab selection; must match [tabsState.tabCount].
  final TabController? controller;

  /// Current tab availability/order.
  final ExploreTabsState tabsState;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        TabBarView(
          controller: controller,
          children: [
            if (tabsState.classicsAvailable) const ClassicVinesTab(),
            // Feed tabs default to the ScreenAnalyticsService singleton when
            // not given one, so no instance needs threading through here.
            const NewVideosTab(),
            const PopularVideosTab(),
            const CategoriesTab(),
            if (tabsState.forYouAvailable) const ForYouTab(),
            const ExploreListsTab(),
            if (tabsState.appsAvailable)
              const AppsDirectoryScreen(embedded: true),
          ],
        ),
        // New videos banner only shows on the New Videos and Trending tabs.
        if (controller != null)
          AnimatedBuilder(
            animation: controller!,
            builder: (context, _) {
              final currentIndex = controller!.index;
              if (currentIndex == tabsState.newVideosIndex ||
                  currentIndex == tabsState.trendingIndex) {
                return const ExploreBufferedVideosBanner();
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
