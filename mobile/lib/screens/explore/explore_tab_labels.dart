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
  final sanitized = sanitizeFeaturedTabText(label);
  if (sanitized.isEmpty) return l10n.navExplore;
  return sanitized;
}

/// Collapses and clamps a server-supplied string bound for the tab bar.
///
/// Length alone does not bound a tab: `Tab` lays out at a fixed height, so a
/// label carrying newlines paints extra lines into a box that cannot grow, and
/// bidi overrides reorder glyphs across the whole bar. Neither is caught by a
/// grapheme count. Both fields on a featured tab are editorial copy authored
/// outside this repo, so both go through here.
///
/// Returns an empty string when nothing renderable survives.
String sanitizeFeaturedTabText(String raw) {
  final collapsed = raw
      .replaceAll(_featuredTabControlCharacters, ' ')
      .replaceAll(_repeatedWhitespace, ' ')
      .trim();
  if (collapsed.isEmpty) return '';
  final characters = collapsed.characters;
  if (characters.length <= featuredTabLabelMaxLength) return collapsed;
  return '${characters.take(featuredTabLabelMaxLength - 1).toString().trimRight()}…';
}

/// C0/C1 controls, line/paragraph separators, and bidi formatting overrides.
final _featuredTabControlCharacters = RegExp(
  '[\u0000-\u001f\u007f-\u009f\u2028\u2029'
  '\u200e\u200f\u202a-\u202e\u2066-\u2069]',
);

final _repeatedWhitespace = RegExp(r'\s+');
