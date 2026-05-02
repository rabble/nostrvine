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

    test('PR-touched support and profile surfaces avoid hardcoded English', () {
      final bugReportSource = File(
        'lib/widgets/bug_report_dialog.dart',
      ).readAsStringSync();
      final featureRequestSource = File(
        'lib/widgets/feature_request_dialog.dart',
      ).readAsStringSync();
      final profileSetupSource = File(
        'lib/screens/profile_setup_screen.dart',
      ).readAsStringSync();
      final categoryGallerySource = File(
        'lib/screens/category_gallery_screen.dart',
      ).readAsStringSync();
      final contentWarningSource = File(
        'lib/widgets/content_warning.dart',
      ).readAsStringSync();
      final discoverListsSource = File(
        'lib/screens/discover_lists_screen.dart',
      ).readAsStringSync();
      final appsPermissionsSource = File(
        'lib/screens/apps/apps_permissions_screen.dart',
      ).readAsStringSync();
      final curatedListFeedSource = File(
        'lib/screens/curated_list_feed_screen.dart',
      ).readAsStringSync();
      final myFollowersSource = File(
        'lib/screens/followers/my_followers_screen.dart',
      ).readAsStringSync();
      final otherFollowersSource = File(
        'lib/screens/followers/others_followers_screen.dart',
      ).readAsStringSync();
      final myFollowingSource = File(
        'lib/screens/following/my_following_screen.dart',
      ).readAsStringSync();
      final otherFollowingSource = File(
        'lib/screens/following/others_following_screen.dart',
      ).readAsStringSync();
      final hashtagSearchSource = File(
        'lib/widgets/hashtag_search_view.dart',
      ).readAsStringSync();

      for (final source in [bugReportSource, featureRequestSource]) {
        expect(source, isNot(contains("label: 'Subject *'")));
        expect(source, isNot(contains("helper: 'Required'")));
      }
      expect(bugReportSource, contains('context.l10n.supportReportBug'));
      expect(
        featureRequestSource,
        contains('context.l10n.supportRequestFeature'),
      );

      expect(
        profileSetupSource,
        isNot(contains("hintText: 'Tell people about yourself...'")),
      );
      expect(profileSetupSource, isNot(contains("hintText: 'username'")));
      expect(profileSetupSource, isNot(contains("label: 'Got it'")));
      expect(profileSetupSource, isNot(contains("'Username (Optional)'")));
      expect(
        profileSetupSource,
        isNot(contains("'Profile Color (Optional)'")),
      );
      expect(profileSetupSource, isNot(contains("'Checking availability...'")));
      expect(profileSetupSource, isNot(contains("'Username available!'")));
      expect(profileSetupSource, isNot(contains("'Username already taken'")));
      expect(profileSetupSource, isNot(contains("'Username is reserved'")));
      expect(profileSetupSource, isNot(contains("'Contact support'")));
      expect(
        profileSetupSource,
        isNot(contains("'This username is no longer available'")),
      );
      expect(profileSetupSource, contains('context.l10n.profileSetupBioHint'));
      expect(profileSetupSource, contains('profileSetupUsernameHint'));
      expect(profileSetupSource, contains('profileSetupUsernameLabel'));
      expect(profileSetupSource, contains('profileSetupUsernameChecking'));

      expect(categoryGallerySource, isNot(contains("'Hot'")));
      expect(categoryGallerySource, isNot(contains("'For You'")));
      expect(
        categoryGallerySource,
        contains('categoryGallerySortHot'),
      );

      expect(
        contentWarningSource,
        isNot(contains("tooltip: 'Report Content'")),
      );
      expect(contentWarningSource, isNot(contains("tooltip: 'Block User'")));
      expect(contentWarningSource, isNot(contains("'Content Blocked'")));
      expect(
        contentWarningSource,
        isNot(contains("'Sensitive Content'")),
      );
      expect(contentWarningSource, contains('contentWarningBlockedTitle'));
      expect(
        contentWarningSource,
        contains('contentWarningSensitiveContent'),
      );

      expect(discoverListsSource, isNot(contains("title: 'Discover Lists'")));
      expect(
        discoverListsSource,
        isNot(contains("'Discovering public lists...'")),
      );
      expect(discoverListsSource, isNot(contains("'Failed to load lists'")));
      expect(discoverListsSource, isNot(contains("'No public lists found'")));
      expect(
        discoverListsSource,
        isNot(contains("'Check back later for new lists'")),
      );
      expect(
        discoverListsSource,
        contains('context.l10n.discoverListsTitle'),
      );
      expect(discoverListsSource, contains('discoverListsFailedToLoad'));
      expect(discoverListsSource, contains('discoverListsLoading'));

      expect(
        curatedListFeedSource,
        isNot(contains("'No videos in this list'")),
      );
      expect(
        curatedListFeedSource,
        isNot(contains("'Add some videos to get started'")),
      );
      expect(curatedListFeedSource, isNot(contains("'Loading videos...'")));
      expect(curatedListFeedSource, isNot(contains("'Failed to load list'")));
      expect(curatedListFeedSource, isNot(contains("'No videos available'")));
      expect(curatedListFeedSource, isNot(contains("'Video not available'")));
      expect(curatedListFeedSource, contains('curatedListEmptyTitle'));
      expect(curatedListFeedSource, contains('curatedListLoadingVideos'));

      expect(
        appsPermissionsSource,
        isNot(contains("title: 'Integration Permissions'")),
      );
      expect(
        appsPermissionsSource,
        isNot(contains("'No saved integration permissions'")),
      );
      expect(
        appsPermissionsSource,
        isNot(
          contains(
            "'Approved integrations will appear here after you remember an access approval.'",
          ),
        ),
      );
      expect(
        appsPermissionsSource,
        contains('context.l10n.appsPermissionsTitle'),
      );
      expect(appsPermissionsSource, contains('appsPermissionsEmptyTitle'));

      for (final source in [myFollowersSource, otherFollowersSource]) {
        expect(source, isNot(contains("'No followers yet'")));
        expect(source, contains('followersEmptyTitle'));
      }

      for (final source in [myFollowingSource, otherFollowingSource]) {
        expect(source, isNot(contains("'Not following anyone yet'")));
        expect(source, contains('followingEmptyTitle'));
      }

      expect(hashtagSearchSource, isNot(contains("'No hashtags found for")));
      expect(hashtagSearchSource, isNot(contains("'Search failed'")));
      expect(hashtagSearchSource, contains('hashtagSearchNoResults'));
      expect(hashtagSearchSource, contains('hashtagSearchFailed'));
    });
  });
}
