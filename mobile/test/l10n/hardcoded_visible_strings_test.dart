// ABOUTME: Guards high-visibility screens against regressions to hardcoded English.
// ABOUTME: Complements widget tests where full screen setup is too expensive.

import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('hardcoded visible strings', () {
    test('Explore search and category counts use l10n keys', () {
      final exploreSource = File(
        'lib/screens/explore_screen.dart',
      ).readAsStringSync();
      final categoriesSource = File(
        'lib/widgets/categories_tab.dart',
      ).readAsStringSync();

      expect(exploreSource, isNot(contains("hintText: 'Search...'")));
      expect(exploreSource, contains('context.l10n.exploreSearchHint'));

      expect(categoriesSource, isNot(contains("videos'")));
      expect(categoriesSource, contains('context.l10n.categoryVideoCount'));
    });

    test('Explore-adjacent cards and search use localized counts', () {
      final listCardSource = File(
        'lib/widgets/list_card.dart',
      ).readAsStringSync();
      final discoverListsSource = File(
        'lib/screens/discover_lists_screen.dart',
      ).readAsStringSync();
      final curatedListFeedSource = File(
        'lib/screens/curated_list_feed_screen.dart',
      ).readAsStringSync();
      final soundTileSource = File(
        'lib/widgets/sound_tile.dart',
      ).readAsStringSync();
      final searchAppBarSource = File(
        'lib/screens/search_results/widgets/search_results_app_bar.dart',
      ).readAsStringSync();

      expect(listCardSource, isNot(contains("'person' : 'people'")));
      expect(listCardSource, isNot(contains("'video' : 'videos'")));
      expect(listCardSource, contains('context.l10n.listPersonCount'));
      expect(listCardSource, contains('context.l10n.listVideoCount'));

      expect(discoverListsSource, isNot(contains("'video' : 'videos'")));
      expect(discoverListsSource, contains('context.l10n.listVideoCount'));

      expect(curatedListFeedSource, isNot(contains("'video' : 'videos'")));
      expect(curatedListFeedSource, contains('context.l10n.listVideoCount'));

      expect(soundTileSource, isNot(contains("'1 video'")));
      expect(soundTileSource, isNot(contains(r"'$videoCount videos'")));
      expect(soundTileSource, contains('context.l10n.soundVideoCount'));

      expect(searchAppBarSource, isNot(contains("hintText: 'Search...'")));
      expect(searchAppBarSource, contains('context.l10n.exploreSearchHint'));
    });
  });
}
