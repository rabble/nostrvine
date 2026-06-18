// ABOUTME: Sticky, pinned profile tab bar with scroll-driven top inset.
// ABOUTME: Extracted from profile_grid.dart to keep that file focused (#4339).

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/widgets/profile/profile_cache_load_indicator.dart';

/// Sticky tab bar rendering the profile's [tabs] (5 on other profiles, 6 on
/// the own profile, which also shows Collabs).
class ProfileTabBar extends StatefulWidget {
  const ProfileTabBar({
    required this.controller,
    required this.scrollController,
    required this.tabs,
    required this.headerKey,
    required this.isRefreshing,
    super.key,
  });

  final TabController controller;
  final ScrollController? scrollController;
  final List<({String label, DivineIconName icon})> tabs;
  final GlobalKey headerKey;

  /// Whether to show the sticky cache-revalidation bar under the tabs.
  final bool isRefreshing;

  @override
  State<ProfileTabBar> createState() => _ProfileTabBarState();
}

class _ProfileTabBarState extends State<ProfileTabBar> {
  double _tabBarTopInset = 0;

  /// Cached safe area top. Refreshed in [didChangeDependencies] when the
  /// surrounding [MediaQuery] changes (rotation, multi-window resize).
  double _safeAreaTop = 0;

  @override
  void initState() {
    super.initState();
    widget.scrollController?.addListener(_onScroll);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _safeAreaTop = MediaQuery.paddingOf(context).top;
  }

  @override
  void didUpdateWidget(ProfileTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.scrollController != widget.scrollController) {
      oldWidget.scrollController?.removeListener(_onScroll);
      widget.scrollController?.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.scrollController?.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    // Re-measure every tick so that async header updates (profile data
    // arriving, _profileVisible flip) are always reflected in the trigger
    // threshold. findRenderObject().size is O(1) on a mounted widget.
    final headerHeight =
        (widget.headerKey.currentContext?.findRenderObject() as RenderBox?)
            ?.size
            .height;
    if (headerHeight == null || headerHeight == 0) return;

    final triggerScroll = headerHeight - _safeAreaTop;
    final offset = widget.scrollController?.offset ?? 0;

    // Outside the trigger zone the inset is either 0 (above) or the full
    // safe-area top (below). Skip the clamp/setState work when nothing
    // would change.
    if (offset <= triggerScroll) {
      if (_tabBarTopInset != 0) setState(() => _tabBarTopInset = 0);
      return;
    }
    if (offset >= triggerScroll + _safeAreaTop) {
      if (_tabBarTopInset != _safeAreaTop) {
        setState(() => _tabBarTopInset = _safeAreaTop);
      }
      return;
    }

    final newInset = offset - triggerScroll;
    if (newInset != _tabBarTopInset) {
      setState(() => _tabBarTopInset = newInset);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _SliverAppBarDelegate(
        topInset: _tabBarTopInset,
        isRefreshing: widget.isRefreshing,
        TabBar(
          controller: widget.controller,
          indicatorColor: VineTheme.tabIndicatorGreen,
          indicatorWeight: 4,
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: VineTheme.transparent,
          tabs: [
            for (var i = 0; i < widget.tabs.length; i++)
              _ProfileTab(
                label: widget.tabs[i].label,
                icon: widget.tabs[i].icon,
                isSelected: widget.controller.index == i,
              ),
          ],
        ),
      ),
    );
  }
}

/// Single icon tab for [ProfileTabBar].
class _ProfileTab extends StatelessWidget {
  const _ProfileTab({
    required this.label,
    required this.icon,
    required this.isSelected,
  });

  final String label;
  final DivineIconName icon;
  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    return Tab(
      icon: Semantics(
        label: label,
        child: SvgPicture.asset(
          icon.assetPath,
          width: 28,
          height: 28,
          colorFilter: ColorFilter.mode(
            isSelected ? VineTheme.whiteText : VineTheme.onSurfaceMuted,
            BlendMode.srcIn,
          ),
        ),
      ),
    );
  }
}

/// Sticky tab bar delegate.
///
/// Adds a [topInset] (typically the safe area top) so that when pinned
/// behind the status bar, the tab bar icons sit below the status bar
/// rather than behind it.
///
/// Also renders the 2px [VineTheme.outlineMuted] divider at the bottom of
/// the header. The rounded top corners of the tab content viewport are
/// applied separately, on the body's [ColoredBox] wrapper.
class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(
    this._tabBar, {
    required this.topInset,
    required this.isRefreshing,
  });

  final PreferredSizeWidget _tabBar;
  final double topInset;

  /// Whether to overlay the sticky cache-revalidation bar at the bottom edge.
  final bool isRefreshing;

  /// Height of the divider line painted between the tab bar and the tile
  /// grid.
  static const double _dividerHeight = 2;

  double get _totalExtent =>
      _tabBar.preferredSize.height + topInset + _dividerHeight;

  @override
  double get minExtent => _totalExtent;

  @override
  double get maxExtent => _totalExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) => DecoratedBox(
    decoration: const BoxDecoration(color: VineTheme.surfaceBackground),
    child: Stack(
      clipBehavior: .none,
      children: [
        Column(
          children: [
            Padding(
              padding: EdgeInsets.only(top: topInset),
              child: _tabBar,
            ),
            const ColoredBox(
              color: VineTheme.outlineMuted,
              child: SizedBox(height: _dividerHeight, width: double.infinity),
            ),
          ],
        ),
        // Overlaid on the bottom edge so showing/hiding it never changes the
        // header extent — the grid below does not jump.
        if (isRefreshing)
          const Positioned(
            left: 0,
            right: 0,
            bottom: -4,
            child: ProfileCacheLoadIndicator(),
          ),
      ],
    ),
  );

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) =>
      topInset != oldDelegate.topInset ||
      _tabBar != oldDelegate._tabBar ||
      isRefreshing != oldDelegate.isRefreshing;
}
