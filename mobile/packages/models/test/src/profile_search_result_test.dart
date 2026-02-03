// ABOUTME: Tests for ProfileSearchResult model.
// ABOUTME: Tests JSON parsing, field handling, and UserProfile conversion.

import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  group('ProfileSearchResult', () {
    const testPubkey =
        '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    group('constructor', () {
      test('creates instance with required fields', () {
        const result = ProfileSearchResult(pubkey: testPubkey);

        expect(result.pubkey, equals(testPubkey));
        expect(result.name, isNull);
        expect(result.displayName, isNull);
        expect(result.picture, isNull);
      });

      test('creates instance with all optional fields', () {
        final result = ProfileSearchResult(
          pubkey: testPubkey,
          name: 'testuser',
          displayName: 'Test User',
          about: 'A test profile',
          picture: 'https://example.com/avatar.jpg',
          banner: 'https://example.com/banner.jpg',
          nip05: 'testuser@example.com',
          lud16: 'testuser@getalby.com',
          website: 'https://example.com',
          createdAt: DateTime(2024),
          eventId: 'event123',
        );

        expect(result.name, equals('testuser'));
        expect(result.displayName, equals('Test User'));
        expect(result.about, equals('A test profile'));
        expect(result.picture, equals('https://example.com/avatar.jpg'));
        expect(result.banner, equals('https://example.com/banner.jpg'));
        expect(result.nip05, equals('testuser@example.com'));
        expect(result.lud16, equals('testuser@getalby.com'));
        expect(result.website, equals('https://example.com'));
        expect(result.createdAt, equals(DateTime(2024)));
        expect(result.eventId, equals('event123'));
      });
    });

    group('fromJson', () {
      test('parses basic JSON', () {
        final json = {
          'pubkey': testPubkey,
          'name': 'alice',
          'display_name': 'Alice Wonderland',
          'about': 'Down the rabbit hole',
          'picture': 'https://example.com/alice.jpg',
          'nip05': 'alice@example.com',
          'created_at': 1700000000,
          'event_id': 'eventabc',
        };

        final result = ProfileSearchResult.fromJson(json);

        expect(result.pubkey, equals(testPubkey));
        expect(result.name, equals('alice'));
        expect(result.displayName, equals('Alice Wonderland'));
        expect(result.about, equals('Down the rabbit hole'));
        expect(result.picture, equals('https://example.com/alice.jpg'));
        expect(result.nip05, equals('alice@example.com'));
        expect(result.eventId, equals('eventabc'));
      });

      test('parses pubkey as byte array (ASCII codes)', () {
        final json = {
          'pubkey': [97, 98, 99, 49, 50, 51], // 'abc123' as ASCII codes
          'name': 'testuser',
        };

        final result = ProfileSearchResult.fromJson(json);

        expect(result.pubkey, equals('abc123'));
      });

      test('parses event_id as byte array', () {
        final json = {
          'pubkey': testPubkey,
          'event_id': [101, 118, 101, 110, 116, 49], // 'event1' as ASCII codes
        };

        final result = ProfileSearchResult.fromJson(json);

        expect(result.eventId, equals('event1'));
      });

      test('parses id field as eventId fallback', () {
        final json = {
          'pubkey': testPubkey,
          'id': 'fallback-id',
        };

        final result = ProfileSearchResult.fromJson(json);

        expect(result.eventId, equals('fallback-id'));
      });

      test('parses created_at as Unix timestamp', () {
        final json = {
          'pubkey': testPubkey,
          'created_at': 1700000000,
        };

        final result = ProfileSearchResult.fromJson(json);

        expect(
          result.createdAt,
          equals(DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000)),
        );
      });

      test('parses created_at as ISO string', () {
        final json = {
          'pubkey': testPubkey,
          'created_at': '2024-01-15T12:00:00.000Z',
        };

        final result = ProfileSearchResult.fromJson(json);

        expect(result.createdAt?.year, equals(2024));
        expect(result.createdAt?.month, equals(1));
        expect(result.createdAt?.day, equals(15));
      });

      test('handles displayName variations', () {
        // display_name format
        final json1 = {
          'pubkey': testPubkey,
          'display_name': 'Display Name 1',
        };
        expect(
          ProfileSearchResult.fromJson(json1).displayName,
          equals('Display Name 1'),
        );

        // displayName format (camelCase)
        final json2 = {
          'pubkey': testPubkey,
          'displayName': 'Display Name 2',
        };
        expect(
          ProfileSearchResult.fromJson(json2).displayName,
          equals('Display Name 2'),
        );

        // display_name takes precedence
        final json3 = {
          'pubkey': testPubkey,
          'display_name': 'Preferred',
          'displayName': 'Fallback',
        };
        expect(
          ProfileSearchResult.fromJson(json3).displayName,
          equals('Preferred'),
        );
      });

      test('handles missing optional fields', () {
        final json = {'pubkey': testPubkey};

        final result = ProfileSearchResult.fromJson(json);

        expect(result.name, isNull);
        expect(result.displayName, isNull);
        expect(result.about, isNull);
        expect(result.picture, isNull);
        expect(result.banner, isNull);
        expect(result.nip05, isNull);
        expect(result.lud16, isNull);
        expect(result.website, isNull);
        expect(result.createdAt, isNull);
        expect(result.eventId, isNull);
      });

      test('handles null pubkey', () {
        final json = {'name': 'testuser'};

        final result = ProfileSearchResult.fromJson(json);

        expect(result.pubkey, equals(''));
      });
    });

    group('bestDisplayName', () {
      test('returns displayName when available', () {
        const result = ProfileSearchResult(
          pubkey: testPubkey,
          name: 'username',
          displayName: 'Display Name',
        );

        expect(result.bestDisplayName, equals('Display Name'));
      });

      test('falls back to name when displayName is null', () {
        const result = ProfileSearchResult(
          pubkey: testPubkey,
          name: 'username',
        );

        expect(result.bestDisplayName, equals('username'));
      });

      test('falls back to pubkey prefix when both are null', () {
        const result = ProfileSearchResult(pubkey: testPubkey);

        expect(result.bestDisplayName, equals('12345678'));
      });
    });

    group('toUserProfile', () {
      test('converts to UserProfile with all fields', () {
        final createdAt = DateTime(2024);
        final result = ProfileSearchResult(
          pubkey: testPubkey,
          name: 'alice',
          displayName: 'Alice Wonderland',
          about: 'Down the rabbit hole',
          picture: 'https://example.com/alice.jpg',
          banner: 'https://example.com/banner.jpg',
          website: 'https://example.com',
          nip05: 'alice@example.com',
          lud16: 'alice@getalby.com',
          createdAt: createdAt,
          eventId: 'event123',
        );

        final profile = result.toUserProfile();

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.name, equals('alice'));
        expect(profile.displayName, equals('Alice Wonderland'));
        expect(profile.about, equals('Down the rabbit hole'));
        expect(profile.picture, equals('https://example.com/alice.jpg'));
        expect(profile.banner, equals('https://example.com/banner.jpg'));
        expect(profile.website, equals('https://example.com'));
        expect(profile.nip05, equals('alice@example.com'));
        expect(profile.lud16, equals('alice@getalby.com'));
        expect(profile.createdAt, equals(createdAt));
        expect(profile.eventId, equals('event123'));
        expect(profile.rawData, equals(const <String, dynamic>{}));
      });

      test('uses DateTime.now() when createdAt is null', () {
        const result = ProfileSearchResult(pubkey: testPubkey);

        final before = DateTime.now();
        final profile = result.toUserProfile();
        final after = DateTime.now();

        expect(
          profile.createdAt.isAfter(
            before.subtract(const Duration(seconds: 1)),
          ),
          isTrue,
        );
        expect(
          profile.createdAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
      });

      test('uses empty string when eventId is null', () {
        const result = ProfileSearchResult(pubkey: testPubkey);

        final profile = result.toUserProfile();

        expect(profile.eventId, equals(''));
      });
    });

    group('equality', () {
      test('two instances with same pubkey are equal', () {
        const result1 = ProfileSearchResult(
          pubkey: testPubkey,
          name: 'name1',
          displayName: 'Display 1',
        );

        const result2 = ProfileSearchResult(
          pubkey: testPubkey,
          name: 'name2',
          displayName: 'Display 2',
        );

        expect(result1, equals(result2));
        expect(result1.hashCode, equals(result2.hashCode));
      });

      test('two instances with different pubkeys are not equal', () {
        const result1 = ProfileSearchResult(
          pubkey: 'pubkey1',
          name: 'name',
        );

        const result2 = ProfileSearchResult(
          pubkey: 'pubkey2',
          name: 'name',
        );

        expect(result1, isNot(equals(result2)));
      });
    });

    group('toString', () {
      test('returns formatted string with pubkey and name', () {
        const result = ProfileSearchResult(
          pubkey: testPubkey,
          displayName: 'Test User',
        );

        expect(
          result.toString(),
          equals('ProfileSearchResult(pubkey: $testPubkey, name: Test User)'),
        );
      });
    });
  });
}
