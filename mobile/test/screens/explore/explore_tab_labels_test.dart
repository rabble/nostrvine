// ABOUTME: Regression tests for shared Explore tab label resolution.
// ABOUTME: Covers shell titles plus the server-supplied featured tab label.

import 'package:flutter/widgets.dart';
import 'package:characters/characters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/generated/app_localizations_en.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';

FeaturedTabConfig _featured(Map<String, String> label) {
  return FeaturedTabConfig(
    id: 'ft_a1b2c3d4',
    slug: 'featured-slug',
    label: label,
    startsAt: null,
    endsAt: null,
    enabled: true,
    hasContent: true,
  );
}

void main() {
  group('labelForExploreTabName', () {
    final l10n = AppLocalizationsEn();

    test('returns tab-bar labels for every canonical tab name', () {
      const state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      );

      expect(
        state.tabNames.map((name) => labelForExploreTabName(l10n, name)),
        const [
          'Classics',
          'New',
          'Popular',
          'Categories',
          'For You',
          'Lists',
          'Integrated Apps',
        ],
      );
    });

    test('returns feed-mode shell titles for every canonical tab name', () {
      const state = ExploreTabsState(
        classicsAvailable: true,
        forYouAvailable: true,
        appsAvailable: true,
      );

      expect(
        state.tabNames.map(
          (name) => labelForExploreTabName(l10n, name, shellTitle: true),
        ),
        const [
          'Classics',
          'New Videos',
          'Trending',
          'Categories',
          'For You',
          'Lists',
          'Integrated Apps',
        ],
      );
    });
  });

  group('labelForExploreTabName featured tab', () {
    late AppLocalizations en;

    setUp(() {
      en = lookupAppLocalizations(const Locale('en'));
    });

    test('uses the locale entry matching the active locale', () {
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured(const {'default': 'Fallback', 'en': 'Picked'}),
      );

      expect(label, equals('Picked'));
    });

    test('falls back to the default entry for an absent locale', () {
      final label = labelForExploreTabName(
        lookupAppLocalizations(const Locale('ja')),
        exploreFeaturedTabName,
        featuredTab: _featured(const {'default': 'Fallback', 'en': 'Picked'}),
      );

      expect(label, equals('Fallback'));
    });

    test('truncates a label longer than the tab bar allows', () {
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured({'default': 'x' * 200}),
      );

      expect(label.length, equals(featuredTabLabelMaxLength));
      expect(label, endsWith('…'));
    });

    test('truncates a label without splitting compound emoji', () {
      const family = '👨‍👩‍👧‍👦';
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured({'default': family * 40}),
      );

      expect(label, startsWith(family));
      expect(label, isNot(contains('�')));
      expect(label, endsWith('…'));
    });

    test('keeps a label at exactly the limit intact', () {
      final exact = 'x' * featuredTabLabelMaxLength;
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured({'default': exact}),
      );

      expect(label, equals(exact));
    });

    test('falls back to the generic noun when the map is unusable', () {
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured(const {}),
      );

      expect(label, equals(en.navExplore));
    });

    test('falls back to the generic noun when no config is supplied', () {
      final label = labelForExploreTabName(en, exploreFeaturedTabName);

      expect(label, equals(en.navExplore));
    });

    test('leaves the compiled tab labels untouched', () {
      expect(
        labelForExploreTabName(en, exploreListsTabName),
        equals(en.exploreTabLists),
      );
    });

    test('collapses newlines that a grapheme count would let through', () {
      // Tab lays out at a fixed height, so extra lines overflow the bar even
      // though four graphemes are well inside the clamp.
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured(const {'default': 'a\nb\nc\nd'}),
      );

      expect(label, equals('a b c d'));
    });

    test('strips bidi overrides from a server label', () {
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured(const {'default': 'Spot\u202elight'}),
      );

      expect(label, equals('Spot light'));
      expect(label.contains('\u202e'), isFalse);
    });

    test('falls back to the generic noun for control-only copy', () {
      final label = labelForExploreTabName(
        en,
        exploreFeaturedTabName,
        featuredTab: _featured(const {'default': '\n\u202e\t'}),
      );

      expect(label, equals(en.navExplore));
    });
  });

  group('sanitizeFeaturedTabText', () {
    test('clamps an overlong disclosure marker', () {
      final sanitized = sanitizeFeaturedTabText('x' * 80);

      expect(sanitized.characters.length, equals(featuredTabLabelMaxLength));
      expect(sanitized.endsWith('…'), isTrue);
    });

    test('keeps a short marker verbatim', () {
      expect(sanitizeFeaturedTabText('  Ad  '), equals('Ad'));
    });

    test('returns empty when nothing renderable survives', () {
      expect(sanitizeFeaturedTabText('\n\t '), isEmpty);
    });
  });
}
