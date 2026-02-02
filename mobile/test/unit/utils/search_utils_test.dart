// ABOUTME: Unit tests for SearchUtils fuzzy matching functionality
// ABOUTME: Verifies tokenized search works for user profiles and videos

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/user_profile.dart';
import 'package:openvine/utils/search_utils.dart';

void main() {
  group('SearchUtils.tokenize', () {
    test('tokenizes simple string', () {
      expect(SearchUtils.tokenize('hello world'), ['hello', 'world']);
    });

    test('handles underscores', () {
      expect(SearchUtils.tokenize('hello_world'), ['hello', 'world']);
    });

    test('handles camelCase', () {
      expect(SearchUtils.tokenize('helloWorld'), ['hello', 'world']);
    });

    test('handles mixed case with spaces', () {
      expect(SearchUtils.tokenize('Rafa Kiuei'), ['rafa', 'kiuei']);
    });

    test('handles empty string', () {
      expect(SearchUtils.tokenize(''), []);
    });

    test('handles extra whitespace', () {
      expect(SearchUtils.tokenize('  hello   world  '), ['hello', 'world']);
    });
  });

  group('SearchUtils.tokenMatch', () {
    test('returns 1.0 for exact match', () {
      expect(SearchUtils.tokenMatch('rafa', 'rafa'), 1.0);
    });

    test('returns 0.95 for prefix match', () {
      expect(SearchUtils.tokenMatch('raf', 'rafa'), 0.95);
    });

    test('returns 0.85 for substring match', () {
      expect(SearchUtils.tokenMatch('afa', 'rafa'), 0.85);
    });

    test('matches tokenized query against target', () {
      // "rafa kiuei" should match "Rafa Kiuei" with high score
      final score = SearchUtils.tokenMatch('rafa kiuei', 'Rafa Kiuei');
      expect(score, greaterThan(0.6));
    });

    test('partial token match returns lower score', () {
      // "rafa" should partially match "Rafa Kiuei"
      final score = SearchUtils.tokenMatch('rafa', 'Rafa Kiuei');
      expect(score, greaterThan(0.3));
    });

    test('returns 0 for no match', () {
      expect(SearchUtils.tokenMatch('xyz', 'rafa'), 0.0);
    });
  });

  group('SearchUtils.matchProfile', () {
    final testProfile = UserProfile(
      pubkey: 'abc123def456',
      displayName: 'Rafa Kiuei',
      name: 'rafakiuei',
      nip05: 'rafa@example.com',
      rawData: const {},
      createdAt: DateTime.now(),
      eventId: 'event123',
    );

    test('matches display name exactly', () {
      final match = SearchUtils.matchProfile('Rafa Kiuei', testProfile);
      expect(match, isNotNull);
      expect(match!.score, equals(1.0));
      expect(match.matchedField, equals('displayName'));
    });

    test('matches display name with different spacing', () {
      final match = SearchUtils.matchProfile('rafa kiuei', testProfile);
      expect(match, isNotNull);
      expect(match!.score, greaterThan(0.8));
    });

    test('matches partial display name', () {
      final match = SearchUtils.matchProfile('rafa', testProfile);
      expect(match, isNotNull);
      expect(match!.score, greaterThan(0.3));
    });

    test('matches username', () {
      final match = SearchUtils.matchProfile('rafakiuei', testProfile);
      expect(match, isNotNull);
      expect(match!.score, greaterThan(0.8));
    });

    test('matches NIP-05 username', () {
      // Create a profile where nip05 is the best match
      final nip05Profile = UserProfile(
        pubkey: 'abc123def456',
        displayName: null,
        name: null,
        nip05: 'rafa@example.com',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event123',
      );
      final match = SearchUtils.matchProfile('rafa', nip05Profile);
      expect(match, isNotNull);
      expect(match!.score, greaterThan(0.3));
      expect(match.matchedField, equals('nip05'));
    });

    test('returns null for no match', () {
      final match = SearchUtils.matchProfile('xyz123', testProfile);
      expect(match, isNull);
    });
  });

  group('SearchUtils.searchProfiles', () {
    final profiles = [
      UserProfile(
        pubkey: 'pub1',
        displayName: 'Rafa Kiuei',
        name: 'rafakiuei',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event1',
      ),
      UserProfile(
        pubkey: 'pub2',
        displayName: 'Aleb Wkeys',
        name: 'alebwkeys',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event2',
      ),
      UserProfile(
        pubkey: 'pub3',
        displayName: 'Santiago Android',
        name: 'santiagoandroid',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event3',
      ),
      UserProfile(
        pubkey: 'pub4',
        displayName: 'Rabble',
        name: 'rabble',
        rawData: const {},
        createdAt: DateTime.now(),
        eventId: 'event4',
      ),
    ];

    test('finds exact match', () {
      final results = SearchUtils.searchProfiles('rabble', profiles);
      expect(results.length, greaterThan(0));
      expect(results.first.pubkey, equals('pub4'));
    });

    test('finds with different spacing - rafa kiuei', () {
      final results = SearchUtils.searchProfiles('rafa kiuei', profiles);
      expect(results.length, greaterThan(0));
      expect(results.first.pubkey, equals('pub1'));
    });

    test('finds with different spacing - aleb wkeys', () {
      final results = SearchUtils.searchProfiles('aleb wkeys', profiles);
      expect(results.length, greaterThan(0));
      expect(results.first.pubkey, equals('pub2'));
    });

    test('finds with different spacing - santiago android', () {
      final results = SearchUtils.searchProfiles('santiago android', profiles);
      expect(results.length, greaterThan(0));
      expect(results.first.pubkey, equals('pub3'));
    });

    test('returns empty for no matches', () {
      final results = SearchUtils.searchProfiles('zzz999', profiles);
      expect(results, isEmpty);
    });

    test('respects limit parameter', () {
      final results = SearchUtils.searchProfiles('a', profiles, limit: 2);
      expect(results.length, lessThanOrEqualTo(2));
    });

    test('sorts by relevance score', () {
      final results = SearchUtils.searchProfiles('rab', profiles);
      // "Rabble" should be first as it's the best match for "rab"
      if (results.isNotEmpty) {
        expect(results.first.pubkey, equals('pub4'));
      }
    });
  });

  group('SearchUtils.matchVideo', () {
    test('matches title with high score', () {
      final score = SearchUtils.matchVideo(
        query: 'bitcoin',
        title: 'My Bitcoin Video',
        content: 'Some content',
        hashtags: ['crypto'],
      );
      expect(score, greaterThan(0.5));
    });

    test('matches hashtag exactly', () {
      final score = SearchUtils.matchVideo(
        query: 'bitcoin',
        title: 'Some video',
        content: 'Some content',
        hashtags: ['bitcoin', 'crypto'],
      );
      expect(score, equals(0.95));
    });

    test('matches hashtag with # prefix', () {
      final score = SearchUtils.matchVideo(
        query: '#bitcoin',
        title: 'Some video',
        content: 'Some content',
        hashtags: ['bitcoin', 'crypto'],
      );
      expect(score, equals(0.95));
    });

    test('matches content with lower score', () {
      final score = SearchUtils.matchVideo(
        query: 'interesting',
        title: 'Some video',
        content: 'This is interesting content',
        hashtags: [],
      );
      expect(score, greaterThan(0.3));
      expect(score, lessThan(0.9));
    });

    test('matches creator name with lowest score', () {
      final score = SearchUtils.matchVideo(
        query: 'rabble',
        title: 'Some video',
        content: 'Some content',
        hashtags: [],
        creatorName: 'Rabble',
      );
      expect(score, greaterThan(0.3));
      expect(score, lessThan(0.7));
    });

    test('returns 0 for no match', () {
      final score = SearchUtils.matchVideo(
        query: 'xyz999',
        title: 'Some video',
        content: 'Some content',
        hashtags: ['tag1'],
      );
      expect(score, equals(0.0));
    });
  });
}
