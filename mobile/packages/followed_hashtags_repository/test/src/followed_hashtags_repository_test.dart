// ABOUTME: Unit tests for FollowedHashtagsRepository (profile + following feed)

import 'package:flutter_test/flutter_test.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FollowedHashtagsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads empty when unset', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);

      expect(repo.profileSavedHashtags, isEmpty);
      expect(repo.followingFeedHashtagLabels, isEmpty);
      expect(repo.hasProfileSavedHashtag('#vine'), isFalse);
    });

    test(
      'migrates legacy profile-only data into the feed list on first open',
      () async {
        SharedPreferences.setMockInitialValues({
          FollowedHashtagsRepository.preferencesKey: ['alpha', 'beta'],
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = FollowedHashtagsRepository(prefs: prefs);

        expect(repo.profileSavedHashtags, ['alpha', 'beta']);
        expect(
          repo.followingFeedHashtagLabels,
          ['alpha', 'beta'],
          reason: 'feed key is seeded from profile for upgrade compatibility',
        );
        expect(
          prefs.getStringList(
            FollowedHashtagsRepository.followingFeedPreferencesKey,
          ),
          ['alpha', 'beta'],
        );
        await repo.dispose();
      },
    );

    test(
      'addProfileSavedHashtag only updates profile in separate mode',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = FollowedHashtagsRepository(prefs: prefs);

        await repo.addProfileSavedHashtag('  #Vine  ');

        expect(repo.profileSavedHashtags, ['vine']);
        expect(
          repo.followingFeedHashtagLabels,
          isEmpty,
          reason:
              'feed is independent when separateFollowingFeedHashtagsEnabled',
        );
        expect(
          prefs.getStringList(FollowedHashtagsRepository.preferencesKey),
          ['vine'],
        );
        await repo.dispose();
      },
    );

    test(
      'addFollowingFeedHashtag only updates following feed in separate mode',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = FollowedHashtagsRepository(prefs: prefs);

        await repo.addFollowingFeedHashtag('home');

        expect(repo.followingFeedHashtagLabels, ['home']);
        expect(repo.profileSavedHashtags, isEmpty);
        await repo.dispose();
      },
    );

    test(
      'addFollowedHashtag alias only touches profile in separate mode',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = FollowedHashtagsRepository(prefs: prefs);
        await repo.addFollowedHashtag('alias');
        expect(repo.profileSavedHashtags, ['alias']);
        expect(repo.followingFeedHashtagLabels, isEmpty);
        await repo.dispose();
      },
    );

    test('add is idempotent for profile', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);

      await repo.addProfileSavedHashtag('nostr');
      await repo.addProfileSavedHashtag('#nostr');

      expect(repo.profileSavedHashtags, ['nostr']);
      await repo.dispose();
    });

    test('removeProfileSavedHashtag', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);

      await repo.addProfileSavedHashtag('a');
      await repo.addProfileSavedHashtag('b');
      await repo.removeProfileSavedHashtag('#A');

      expect(repo.profileSavedHashtags, ['b']);
      await repo.dispose();
    });

    test('profileSavedHashtagsStream emits updates', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);

      final emissions = <List<String>>[];
      final sub = repo.profileSavedHashtagsStream.listen(emissions.add);

      await repo.addProfileSavedHashtag('x');
      await repo.addProfileSavedHashtag('y');
      await repo.removeProfileSavedHashtag('x');

      expect(repo.profileSavedHashtags, ['y']);
      expect(emissions.last, ['y']);
      expect(emissions, [
        <String>[],
        ['x'],
        ['x', 'y'],
        ['y'],
      ]);

      await sub.cancel();
      await repo.dispose();
    });

    test('reloadFromPrefs picks up external pref changes', () async {
      SharedPreferences.setMockInitialValues({
        FollowedHashtagsRepository.preferencesKey: ['remote'],
        FollowedHashtagsRepository.followingFeedPreferencesKey: ['f'],
      });
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);

      expect(repo.profileSavedHashtags, ['remote']);
      expect(repo.followingFeedHashtagLabels, ['f']);

      await prefs.setStringList(FollowedHashtagsRepository.preferencesKey, [
        'one',
        'two',
      ]);
      await prefs.setStringList(
        FollowedHashtagsRepository.followingFeedPreferencesKey,
        ['f'],
      );
      await repo.reloadFromPrefs();

      expect(repo.profileSavedHashtags, ['one', 'two']);
      await repo.dispose();
    });

    test('custom storage keys are isolated from defaults', () async {
      SharedPreferences.setMockInitialValues({
        'custom_profile': ['c'],
        'custom_feed': ['cf'],
        FollowedHashtagsRepository.preferencesKey: ['d'],
        FollowedHashtagsRepository.followingFeedPreferencesKey: ['df'],
      });
      final prefs = await SharedPreferences.getInstance();
      final custom = FollowedHashtagsRepository(
        prefs: prefs,
        profileStorageKey: 'custom_profile',
        followingFeedStorageKey: 'custom_feed',
      );
      final def = FollowedHashtagsRepository(prefs: prefs);

      expect(custom.profileSavedHashtags, ['c']);
      expect(custom.followingFeedHashtagLabels, ['cf']);
      expect(def.profileSavedHashtags, ['d']);
      expect(def.followingFeedHashtagLabels, ['df']);

      await custom.dispose();
      await def.dispose();
    });
  });
}
