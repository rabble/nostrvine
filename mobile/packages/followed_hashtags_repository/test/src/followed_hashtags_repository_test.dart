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
      'seeds following feed from profile when the feed key '
      'is absent on first open',
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

    test(
      'followingFeedHashtagLabelsStream emits updates',
      () async {
        final prefs = await SharedPreferences.getInstance();
        final repo = FollowedHashtagsRepository(prefs: prefs);
        await _afterRepoOpen();

        final emissions = <List<String>>[];
        final sub = repo.followingFeedHashtagLabelsStream.listen(emissions.add);

        await repo.addFollowingFeedHashtag('a');
        await repo.addFollowingFeedHashtag('b');
        await repo.removeFollowingFeedHashtag('a');

        expect(emissions.last, ['b']);
        expect(emissions, [
          <String>[],
          ['a'],
          ['a', 'b'],
          ['b'],
        ]);

        await sub.cancel();
        await repo.dispose();
      },
    );

    test('hasFollowingFeedHashtag normalizes and respects empties', () async {
      final prefs = await SharedPreferences.getInstance();
      final repo = FollowedHashtagsRepository(prefs: prefs);
      await _afterRepoOpen();

      expect(repo.hasFollowingFeedHashtag(''), isFalse);
      expect(repo.hasFollowingFeedHashtag('   '), isFalse);

      await repo.addFollowingFeedHashtag('#Tag');
      expect(repo.hasFollowingFeedHashtag('tag'), isTrue);
      expect(repo.hasFollowingFeedHashtag('#TAG'), isTrue);

      await repo.dispose();
    });

    group(
      'combined profile and feed list '
      '(separateFollowingFeedHashtagsEnabled: false)',
      () {
        test('bootstrap keeps feed aligned with profile', () async {
          SharedPreferences.setMockInitialValues({
            FollowedHashtagsRepository.preferencesKey: ['one', 'two'],
          });
          final prefs = await SharedPreferences.getInstance();
          final repo = FollowedHashtagsRepository(
            prefs: prefs,
            separateFollowingFeedHashtagsEnabled: false,
          );
          await _afterRepoOpen();

          expect(repo.profileSavedHashtags, ['one', 'two']);
          expect(repo.followingFeedHashtagLabels, ['one', 'two']);
          expect(
            prefs.getStringList(
              FollowedHashtagsRepository.followingFeedPreferencesKey,
            ),
            ['one', 'two'],
          );
          await repo.dispose();
        });

        test('addProfileSavedHashtag updates feed list', () async {
          final prefs = await SharedPreferences.getInstance();
          final repo = FollowedHashtagsRepository(
            prefs: prefs,
            separateFollowingFeedHashtagsEnabled: false,
          );
          await _afterRepoOpen();

          await repo.addProfileSavedHashtag('#new');

          expect(repo.profileSavedHashtags, ['new']);
          expect(repo.followingFeedHashtagLabels, ['new']);
          expect(
            prefs.getStringList(
              FollowedHashtagsRepository.followingFeedPreferencesKey,
            ),
            ['new'],
          );
          await repo.dispose();
        });

        test('removeProfileSavedHashtag updates feed list', () async {
          SharedPreferences.setMockInitialValues({
            FollowedHashtagsRepository.preferencesKey: ['x', 'y'],
          });
          final prefs = await SharedPreferences.getInstance();
          final repo = FollowedHashtagsRepository(
            prefs: prefs,
            separateFollowingFeedHashtagsEnabled: false,
          );
          await _afterRepoOpen();

          await repo.removeProfileSavedHashtag('x');

          expect(repo.profileSavedHashtags, ['y']);
          expect(repo.followingFeedHashtagLabels, ['y']);
          await repo.dispose();
        });

        test(
          'addFollowingFeedHashtag and removeFollowingFeedHashtag delegate '
          'to profile methods',
          () async {
            final prefs = await SharedPreferences.getInstance();
            final repo = FollowedHashtagsRepository(
              prefs: prefs,
              separateFollowingFeedHashtagsEnabled: false,
            );
            await _afterRepoOpen();

            await repo.addFollowingFeedHashtag('delegated');
            expect(repo.profileSavedHashtags, ['delegated']);
            expect(repo.followingFeedHashtagLabels, ['delegated']);

            await repo.removeFollowingFeedHashtag('delegated');
            expect(repo.profileSavedHashtags, isEmpty);
            expect(repo.followingFeedHashtagLabels, isEmpty);
            await repo.dispose();
          },
        );

        test('reloadFromPrefs syncs feed from profile', () async {
          SharedPreferences.setMockInitialValues({
            FollowedHashtagsRepository.preferencesKey: ['alpha'],
          });
          final prefs = await SharedPreferences.getInstance();
          final repo = FollowedHashtagsRepository(
            prefs: prefs,
            separateFollowingFeedHashtagsEnabled: false,
          );
          await _afterRepoOpen();

          await prefs.setStringList(FollowedHashtagsRepository.preferencesKey, [
            'beta',
          ]);
          await repo.reloadFromPrefs();

          expect(repo.profileSavedHashtags, ['beta']);
          expect(repo.followingFeedHashtagLabels, ['beta']);
          await repo.dispose();
        });
      },
    );

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
