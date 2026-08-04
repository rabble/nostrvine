// ABOUTME: Shared localized labels for canonical Explore tab names.
// ABOUTME: Keeps tab bar and feed-mode shell titles in sync.

import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Returns the localized display label for an Explore tab [name].
///
/// The shell uses a little more context for video mode ("New Videos",
/// "Trending") while the tab bar keeps the shorter tab copy ("New", "Popular").
String labelForExploreTabName(
  AppLocalizations l10n,
  String name, {
  bool shellTitle = false,
}) => switch (name) {
  exploreClassicsTabName =>
    shellTitle ? l10n.navExploreClassics : l10n.exploreTabClassics,
  exploreDefaultTabName =>
    shellTitle ? l10n.navExploreNewVideos : l10n.exploreTabNew,
  explorePopularTabName =>
    shellTitle ? l10n.navExploreTrending : l10n.exploreTabPopular,
  exploreCategoriesTabName => l10n.exploreTabCategories,
  exploreForYouTabName =>
    shellTitle ? l10n.navExploreForYou : l10n.exploreTabForYou,
  exploreListsTabName =>
    shellTitle ? l10n.navExploreLists : l10n.exploreTabLists,
  exploreAppsTabName => l10n.exploreTabIntegratedApps,
  _ => l10n.navExplore,
};
