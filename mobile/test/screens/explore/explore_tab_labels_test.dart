// ABOUTME: Tests for featured tab label resolution and defensive clamping.
// ABOUTME: The label is server-supplied, so it is treated as untrusted.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
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
  });
}
