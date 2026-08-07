// ABOUTME: State for ExploreTabsCubit: optional-tab availability plus derived
// ABOUTME: ordered tab names and name<->index conversion helpers.

part of 'explore_tabs_cubit.dart';

/// Internal tab name for the "For You" tab.
const exploreForYouTabName = 'for_you';

/// Public URL slug for the "For You" tab.
const exploreForYouTabSlug = 'for-you';

/// Default tab name selected when no other selection applies.
const exploreDefaultTabName = 'new';

/// Internal tab name for the Classics tab.
const exploreClassicsTabName = 'classics';

/// Internal tab name for the Trending tab.
const explorePopularTabName = 'popular';

/// Internal tab name for the Categories tab.
const exploreCategoriesTabName = 'categories';

/// Internal tab name for the Lists tab.
const exploreListsTabName = 'lists';

/// Internal tab name for the integrated Apps tab.
const exploreAppsTabName = 'apps';

/// Internal tab name for the server-configured featured tab.
///
/// Deliberately generic: no editorial name is compiled into the app, and
/// analytics keys off the configuration id rather than this constant.
const exploreFeaturedTabName = 'featured';

/// Immutable explore tab configuration derived from feature availability.
class ExploreTabsState extends Equatable {
  /// Creates a tab state with the given optional-tab availability.
  const ExploreTabsState({
    this.classicsAvailable = false,
    this.forYouAvailable = false,
    this.appsAvailable = false,
    this.featuredTab,
  });

  /// Whether the Classics tab is shown.
  final bool classicsAvailable;

  /// Whether the For You tab is shown.
  final bool forYouAvailable;

  /// Whether the integrated Apps tab is shown.
  final bool appsAvailable;

  /// Server-configured featured tab, or `null` when none should render.
  final FeaturedTabConfig? featuredTab;

  /// Ordered tab names based on current availability.
  ///
  /// Canonical order: `classics?`, `new`, `popular`, `categories`,
  /// `for_you?`, `lists`, `apps?`, with the configured `featured?` tab
  /// spliced in at its named anchor.
  List<String> get tabNames {
    final names = [
      if (classicsAvailable) exploreClassicsTabName,
      exploreDefaultTabName,
      explorePopularTabName,
      exploreCategoriesTabName,
      if (forYouAvailable) exploreForYouTabName,
      exploreListsTabName,
      if (appsAvailable) exploreAppsTabName,
    ];
    final featured = featuredTab;
    if (featured == null) return names;
    return names
      ..insert(_featuredInsertIndex(names, featured), exploreFeaturedTabName);
  }

  /// Resolves the featured tab's slot from its named anchor.
  ///
  /// Anchors are names, never indices, because the optional tabs above shift
  /// indices at runtime. An anchor naming an absent tab falls through to the
  /// end of the list rather than displacing an unrelated tab.
  static int _featuredInsertIndex(
    List<String> names,
    FeaturedTabConfig featured,
  ) {
    final after = featured.position.after;
    if (after != null) {
      final index = names.indexOf(after);
      if (index >= 0) return index + 1;
    }
    final before = featured.position.before;
    if (before != null) {
      final index = names.indexOf(before);
      if (index >= 0) return index;
    }
    return names.length;
  }

  /// Number of visible tabs.
  int get tabCount => tabNames.length;

  /// Index of the New Videos tab.
  int get newVideosIndex => indexForName(exploreDefaultTabName);

  /// Index of the Trending (popular) tab.
  int get trendingIndex => indexForName(explorePopularTabName);

  /// Resolves a tab [name] to its index, falling back to the default tab.
  int indexForName(String name) {
    final index = tabNames.indexOf(name);
    if (index >= 0) return index;
    final fallback = tabNames.indexOf(exploreDefaultTabName);
    return fallback >= 0 ? fallback : 0;
  }

  /// Resolves a tab [index] to its name, falling back to `popular`.
  String nameForIndex(int index) {
    final names = tabNames;
    if (index >= 0 && index < names.length) return names[index];
    return explorePopularTabName;
  }

  /// Returns a copy with the given availability overrides.
  ///
  /// [featuredTab] is passed through as-is, so a `null` clears the tab —
  /// that is how a server kill switch removes it.
  ExploreTabsState copyWith({
    bool? classicsAvailable,
    bool? forYouAvailable,
    bool? appsAvailable,
    FeaturedTabConfig? featuredTab,
  }) {
    return ExploreTabsState(
      classicsAvailable: classicsAvailable ?? this.classicsAvailable,
      forYouAvailable: forYouAvailable ?? this.forYouAvailable,
      appsAvailable: appsAvailable ?? this.appsAvailable,
      featuredTab: featuredTab,
    );
  }

  @override
  List<Object?> get props => [
    classicsAvailable,
    forYouAvailable,
    appsAvailable,
    featuredTab,
  ];
}
