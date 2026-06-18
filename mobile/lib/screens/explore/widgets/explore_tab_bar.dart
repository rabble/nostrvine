// ABOUTME: Scrollable explore tab bar with a right-edge fade gradient.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// The explore screen's scrollable tab bar.
///
/// Tab labels are derived from [tabsState] so the visible set matches the
/// [controller]'s tab count. [onTap] receives the tapped index.
class ExploreTabBar extends StatelessWidget {
  /// Creates the explore tab bar.
  const ExploreTabBar({
    required this.controller,
    required this.tabsState,
    required this.onTap,
    super.key,
  });

  /// Controller driving tab selection; must match [tabsState.tabCount].
  final TabController? controller;

  /// Current tab availability/order.
  final ExploreTabsState tabsState;

  /// Called with the tapped tab index.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Material is required for TabBar ink splashes; PointerInterceptor ensures
    // tabs receive taps on web.
    return PointerInterceptor(
      intercepting: kIsWeb,
      child: Material(
        color: VineTheme.transparent,
        child: Stack(
          children: [
            TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsetsDirectional.only(start: 16),
              indicatorColor: VineTheme.tabIndicatorGreen,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: VineTheme.transparent,
              labelColor: VineTheme.whiteText,
              unselectedLabelColor: VineTheme.onSurfaceMuted55,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: VineTheme.titleMediumFont(),
              unselectedLabelStyle: VineTheme.titleMediumFont(
                color: VineTheme.onSurfaceMuted55,
              ),
              onTap: onTap,
              tabs: [
                if (tabsState.classicsAvailable)
                  Tab(text: context.l10n.exploreTabClassics),
                Tab(text: context.l10n.exploreTabNew),
                Tab(text: context.l10n.exploreTabPopular),
                Tab(text: context.l10n.exploreTabCategories),
                if (tabsState.forYouAvailable)
                  Tab(text: context.l10n.exploreTabForYou),
                Tab(text: context.l10n.exploreTabLists),
                if (tabsState.appsAvailable)
                  Tab(text: context.l10n.exploreTabIntegratedApps),
              ],
            ),
            // Right-edge fade gradient shim
            const Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      colors: [
                        VineTheme.surfaceContainerHigh,
                        Color(0x00000A06),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
