// ABOUTME: State for ExploreTabsCubit: optional-tab availability plus derived
// ABOUTME: ordered tab names and name<->index conversion helpers.

part of 'explore_tabs_cubit.dart';

/// Internal tab name for the "For You" tab.
const exploreForYouTabName = 'for_you';

/// Public URL slug for the "For You" tab.
const exploreForYouTabSlug = 'for-you';

/// Default tab name selected when no other selection applies.
const exploreDefaultTabName = 'new';

/// Immutable explore tab configuration derived from feature availability.
class ExploreTabsState extends Equatable {
  /// Creates a tab state with the given optional-tab availability.
  const ExploreTabsState({
    this.classicsAvailable = false,
    this.forYouAvailable = false,
    this.appsAvailable = false,
  });

  /// Whether the Classics tab is shown.
  final bool classicsAvailable;

  /// Whether the For You tab is shown.
  final bool forYouAvailable;

  /// Whether the integrated Apps tab is shown.
  final bool appsAvailable;

  /// Ordered tab names based on current availability.
  ///
  /// Canonical order: `classics?`, `new`, `popular`, `categories`,
  /// `for_you?`, `lists`, `apps?`.
  List<String> get tabNames => [
    if (classicsAvailable) 'classics',
    'new',
    'popular',
    'categories',
    if (forYouAvailable) exploreForYouTabName,
    'lists',
    if (appsAvailable) 'apps',
  ];

  /// Number of visible tabs.
  int get tabCount => tabNames.length;

  /// Index of the New Videos tab.
  int get newVideosIndex => classicsAvailable ? 1 : 0;

  /// Index of the Trending (popular) tab.
  int get trendingIndex => classicsAvailable ? 2 : 1;

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
    return 'popular';
  }

  /// Returns a copy with the given availability overrides.
  ExploreTabsState copyWith({
    bool? classicsAvailable,
    bool? forYouAvailable,
    bool? appsAvailable,
  }) {
    return ExploreTabsState(
      classicsAvailable: classicsAvailable ?? this.classicsAvailable,
      forYouAvailable: forYouAvailable ?? this.forYouAvailable,
      appsAvailable: appsAvailable ?? this.appsAvailable,
    );
  }

  @override
  List<Object?> get props => [
    classicsAvailable,
    forYouAvailable,
    appsAvailable,
  ];
}
