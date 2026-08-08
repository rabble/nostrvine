// ABOUTME: Shared localized labels for canonical Explore tab names.
// ABOUTME: Keeps tab bar and feed-mode shell titles in sync.

import 'package:characters/characters.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Longest featured-tab label the tab bar will render.
///
/// The label is server-supplied and not authored in this repo, so it is
/// treated as untrusted for layout purposes and clamped before it reaches
/// the scrollable tab bar.
const featuredTabLabelMaxLength = 24;

/// Returns the localized display label for an Explore tab [name].
///
/// The shell uses a little more context for video mode ("New Videos",
/// "Trending") while the tab bar keeps the shorter tab copy ("New", "Popular").
///
/// The featured tab is the one deliberate exception to
/// `.claude/rules/localization.md`: its copy is editorial, scheduled
/// server-side, and cannot live in the ARB files. [featuredTab] carries a
/// locale map with a required `default` entry, which is how it stays
/// translatable, and [localeCode] selects from it.
String labelForExploreTabName(
  AppLocalizations l10n,
  String name, {
  bool shellTitle = false,
  FeaturedTabConfig? featuredTab,
  String? localeCode,
}) => switch (name) {
  exploreFeaturedTabName => _clampFeaturedLabel(
    featuredTab?.labelFor(localeCode ?? l10n.localeName) ?? '',
    l10n,
  ),
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

/// Clamps a server-supplied label so an unexpected length cannot stretch the
/// tab bar, falling back to the generic Explore noun when it is unusable.
String _clampFeaturedLabel(String label, AppLocalizations l10n) {
  final trimmed = label.trim();
  if (trimmed.isEmpty) return l10n.navExplore;
  final characters = trimmed.characters;
  if (characters.length <= featuredTabLabelMaxLength) return trimmed;
  return '${characters.take(featuredTabLabelMaxLength - 1).toString().trimRight()}…';
}
