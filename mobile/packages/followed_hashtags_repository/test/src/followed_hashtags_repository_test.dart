// ABOUTME: Unit tests for FollowedHashtagsRepository (profile + following feed)

import 'package:flutter_test/flutter_test.dart';
import 'package:followed_hashtags_repository/followed_hashtags_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [FollowedHashtagsRepository] loads from prefs in an async [Future] started
/// from the constructor; drain the microtask queue before reading state.
Future<void> _afterRepoOpen() => pumpEventQueue();

void main() {
  group('FollowedHashtagsRepository', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('loads empty when unset', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      await _afterRepoOpen();

      expect(repo.profileSavedHashtags, isEmpty);
      expect(repo.followingFeedHashtagLabels, isEmpty);
      expect(repo.hasProfileSavedHashtag('#vine'), isFalse);
    });

    test(
      'seeds following feed from profile when the feed key is absent on first open',
      () async {
        SharedPreferences.setMockInitialValues({
          FollowedHashtagsRepository.preferencesKey: ['alpha', 'beta'],
        });
        final prefs = await SharedPreferences.getInstance();
        final repo = FollowedHashtagsRepository(prefs: prefs);
        await _afterRepoOpen();

        expect(repo.profileSavedHashtags, ['alpha', 'beta']);
        expect(
          repo.followingFeedHashtagLabels,
          ['alpha', 'beta'],
          reason: 'first write copies profile into the new feed list key',
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
        await _afterRepoOpen();

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
        await _afterRepoOpen();

        await repo.addFollowingFeedHashtag('home');

        expect(repo.followingFeedHashtagLabels, ['home']);
        expect(repo.profileSavedHashtags, isEmpty);
        await repo.dispose();
      },
    );

    test('add is idempotent for profile', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      await _afterRepoOpen();

      await repo.addProfileSavedHashtag('nostr');
      await repo.addProfileSavedHashtag('#nostr');

      expect(repo.profileSavedHashtags, ['nostr']);
      await repo.dispose();
    });

    test('removeProfileSavedHashtag', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      await _afterRepoOpen();

      await repo.addProfileSavedHashtag('a');
      await repo.addProfileSavedHashtag('b');
      await repo.removeProfileSavedHashtag('#A');

      expect(repo.profileSavedHashtags, ['b']);
      await repo.dispose();
    });

    test('profileSavedHashtagsStream emits updates', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      await _afterRepoOpen();

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
      await _afterRepoOpen();

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
      await _afterRepoOpen();

      expect(custom.profileSavedHashtags, ['c']);
      expect(custom.followingFeedHashtagLabels, ['cf']);
      expect(def.profileSavedHashtags, ['d']);
      expect(def.followingFeedHashtagLabels, ['df']);

      await custom.dispose();
      await def.dispose();
    });
  });
}
