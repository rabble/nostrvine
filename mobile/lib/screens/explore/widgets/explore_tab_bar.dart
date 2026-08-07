// ABOUTME: Scrollable explore tab bar with a right-edge fade gradient.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';
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
  final TabController controller;

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
              labelColor: context.vineColors.primaryText,
              unselectedLabelColor: context.vineColors.onSurfaceMuted,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              unselectedLabelStyle: VineTheme.titleMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              onTap: onTap,
              tabs: [
                for (final name in tabsState.tabNames)
                  Tab(
                    child: _ExploreTabLabel(
                      name: name,
                      featuredTab: tabsState.featuredTab,
                    ),
                  ),
              ],
            ),
            // Right-edge fade gradient shim
            Positioned(
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
                      // Both stops are the same surface at different alpha.
                      // Fading to a hardcoded transparent *black* instead
                      // muddies the midpoint once the surface is light.
                      colors: [
                        context.vineColors.surfaceContainerHigh,
                        context.vineColors.surfaceContainerHigh.withValues(
                          alpha: 0,
                        ),
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

/// One tab's label, with the featured tab's optional disclosure marker.
///
/// The marker exists so a labeling requirement discovered mid-campaign can be
/// met by configuration rather than an app store review cycle. It renders
/// only when the server supplies one.
class _ExploreTabLabel extends StatelessWidget {
  const _ExploreTabLabel({required this.name, this.featuredTab});

  final String name;
  final FeaturedTabConfig? featuredTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.vineColors;
    final label = labelForExploreTabName(l10n, name, featuredTab: featuredTab);
    final disclosure = name == exploreFeaturedTabName
        ? featuredTab?.disclosureLabelFor(l10n.localeName)
        : null;

    if (disclosure == null) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 4,
      children: [
        Text(label),
        Text(
          disclosure,
          style: VineTheme.labelSmallFont(color: colors.onSurfaceMuted),
        ),
      ],
    );
  }
}
