import 'dart:convert';

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('UserProfile', () {
    const testPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const testEventId =
        'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';
    final testCreatedAt = DateTime(2024);

    group('constructor', () {
      test('creates profile with required fields', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.rawData, isEmpty);
        expect(profile.createdAt, equals(testCreatedAt));
        expect(profile.eventId, equals(testEventId));
      });

      test('creates profile with all fields', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
          banner: 'https://example.com/banner.png',
          website: 'https://example.com',
          nip05: 'test@example.com',
          lud16: 'test@wallet.com',
          lud06: 'lnurl1234',
        );

        expect(profile.name, equals('testname'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.about, equals('Test bio'));
        expect(profile.picture, equals('https://example.com/avatar.png'));
        expect(profile.banner, equals('https://example.com/banner.png'));
        expect(profile.website, equals('https://example.com'));
        expect(profile.nip05, equals('test@example.com'));
        expect(profile.lud16, equals('test@wallet.com'));
        expect(profile.lud06, equals('lnurl1234'));
      });
    });

    group('fromNostrEvent', () {
      test('parses valid kind 0 event', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          <List<dynamic>>[],
          jsonEncode({
            'name': 'testname',
            'display_name': 'Test User',
            'about': 'Test bio',
            'picture': 'https://example.com/avatar.png',
            'banner': 'https://example.com/banner.png',
            'website': 'https://example.com',
            'nip05': 'test@example.com',
            'lud16': 'test@wallet.com',
            'lud06': 'lnurl1234',
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.eventId, equals(testEventId));
        expect(profile.name, equals('testname'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.about, equals('Test bio'));
        expect(profile.picture, equals('https://example.com/avatar.png'));
        expect(profile.banner, equals('https://example.com/banner.png'));
        expect(profile.website, equals('https://example.com'));
        expect(profile.nip05, equals('test@example.com'));
        expect(profile.lud16, equals('test@wallet.com'));
        expect(profile.lud06, equals('lnurl1234'));
      });

      test('handles displayName key variations', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          <List<dynamic>>[],
          jsonEncode({'displayName': 'Alt Display Name'}),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.displayName, equals('Alt Display Name'));
      });

      test('prefers display_name over displayName', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          <List<dynamic>>[],
          jsonEncode({
            'display_name': 'Preferred Name',
            'displayName': 'Alt Name',
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.displayName, equals('Preferred Name'));
      });

      test('throws ArgumentError for non-kind-0 events', () {
        final event = Event(
          testPubkey,
          EventKind.textNote,
          <List<dynamic>>[],
          'text note content',
          createdAt: 1704067200,
        );

        expect(
          () => UserProfile.fromNostrEvent(event),
          throwsA(isA<ArgumentError>()),
        );
      });

      test('handles invalid JSON content', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          <List<dynamic>>[],
          'invalid json {',
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.rawData, isEmpty);
        expect(profile.name, isNull);
        expect(profile.displayName, isNull);
      });

      test('preserves rawData', () {
        final event = Event(
          testPubkey,
          EventKind.metadata,
          <List<dynamic>>[],
          jsonEncode({
            'name': 'Test',
            'custom_field': 'custom_value',
            'nested': {'key': 'value'},
          }),
          createdAt: 1704067200,
        )..id = testEventId;

        final profile = UserProfile.fromNostrEvent(event);

        expect(profile.rawData['custom_field'], equals('custom_value'));
        expect(profile.rawData['nested'], equals({'key': 'value'}));
      });
    });

    group('fromJson', () {
      test('parses JSON correctly', () {
        final json = {
          'pubkey': testPubkey,
          'name': 'testname',
          'display_name': 'Test User',
          'about': 'Test bio',
          'picture': 'https://example.com/avatar.png',
          'banner': 'https://example.com/banner.png',
          'website': 'https://example.com',
          'nip05': 'test@example.com',
          'lud16': 'test@wallet.com',
          'lud06': 'lnurl1234',
          'raw_data': {'custom': 'data'},
          'created_at': testCreatedAt.millisecondsSinceEpoch,
          'event_id': testEventId,
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.pubkey, equals(testPubkey));
        expect(profile.name, equals('testname'));
        expect(profile.displayName, equals('Test User'));
        expect(profile.about, equals('Test bio'));
        expect(profile.picture, equals('https://example.com/avatar.png'));
        expect(profile.rawData, equals({'custom': 'data'}));
        expect(profile.createdAt, equals(testCreatedAt));
        expect(profile.eventId, equals(testEventId));
      });

      test('handles missing raw_data', () {
        final json = {
          'pubkey': testPubkey,
          'created_at': testCreatedAt.millisecondsSinceEpoch,
          'event_id': testEventId,
        };

        final profile = UserProfile.fromJson(json);

        expect(profile.rawData, isEmpty);
      });
    });

    group('toJson', () {
      test('serializes all fields', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
          banner: 'https://example.com/banner.png',
          website: 'https://example.com',
          nip05: 'test@example.com',
          lud16: 'test@wallet.com',
          lud06: 'lnurl1234',
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final json = profile.toJson();

        expect(json['pubkey'], equals(testPubkey));
        expect(json['name'], equals('testname'));
        expect(json['display_name'], equals('Test User'));
        expect(json['about'], equals('Test bio'));
        expect(json['picture'], equals('https://example.com/avatar.png'));
        expect(json['banner'], equals('https://example.com/banner.png'));
        expect(json['website'], equals('https://example.com'));
        expect(json['nip05'], equals('test@example.com'));
        expect(json['lud16'], equals('test@wallet.com'));
        expect(json['lud06'], equals('lnurl1234'));
        expect(json['raw_data'], equals({'custom': 'data'}));
        expect(
          json['created_at'],
          equals(testCreatedAt.millisecondsSinceEpoch),
        );
        expect(json['event_id'], equals(testEventId));
      });

      test('round-trips correctly', () {
        final original = UserProfile(
          pubkey: testPubkey,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final json = original.toJson();
        final restored = UserProfile.fromJson(json);

        expect(restored.pubkey, equals(original.pubkey));
        expect(restored.name, equals(original.name));
        expect(restored.displayName, equals(original.displayName));
        expect(restored.about, equals(original.about));
        expect(restored.picture, equals(original.picture));
        expect(restored.rawData, equals(original.rawData));
        expect(restored.createdAt, equals(original.createdAt));
        expect(restored.eventId, equals(original.eventId));
      });
    });

    group('bestDisplayName', () {
      test('returns displayName when available', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'Display Name',
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('Display Name'));
      });

      test('falls back to name when displayName is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('username'));
      });

      test('falls back to name when displayName is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: '',
          name: 'username',
        );

        expect(profile.bestDisplayName, equals('username'));
      });

      test('falls back to truncated pubkey when no names available', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final expectedName =
            '${testPubkey.substring(0, 8)}...'
            '${testPubkey.substring(testPubkey.length - 6)}';
        expect(profile.bestDisplayName, equals(expectedName));
      });

      test('returns full pubkey when pubkey is short', () {
        const shortPubkey = 'short123';
        final profile = UserProfile(
          pubkey: shortPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.bestDisplayName, equals(shortPubkey));
      });
    });

    group('computed properties', () {
      test('shortPubkey returns full pubkey', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.shortPubkey, equals(testPubkey));
      });

      test('hasBasicInfo returns true when name is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'testname',
        );

        expect(profile.hasBasicInfo, isTrue);
      });

      test('hasBasicInfo returns true when displayName is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'Display Name',
        );

        expect(profile.hasBasicInfo, isTrue);
      });

      test('hasBasicInfo returns true when picture is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          picture: 'https://example.com/avatar.png',
        );

        expect(profile.hasBasicInfo, isTrue);
      });

      test('hasBasicInfo returns false when nothing is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasBasicInfo, isFalse);
      });

      test('hasAvatar returns true when picture is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          picture: 'https://example.com/avatar.png',
        );

        expect(profile.hasAvatar, isTrue);
      });

      test('hasAvatar returns false when picture is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasAvatar, isFalse);
      });

      test('hasAvatar returns false when picture is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          picture: '',
        );

        expect(profile.hasAvatar, isFalse);
      });

      test('hasBio returns true when about is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          about: 'Test bio',
        );

        expect(profile.hasBio, isTrue);
      });

      test('hasBio returns false when about is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasBio, isFalse);
      });

      test('hasNip05 returns true when nip05 is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'test@example.com',
        );

        expect(profile.hasNip05, isTrue);
      });

      test('hasNip05 returns false when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasNip05, isFalse);
      });

      test('hasLightning returns true when lud16 is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud16: 'test@wallet.com',
        );

        expect(profile.hasLightning, isTrue);
      });

      test('hasLightning returns true when lud06 is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud06: 'lnurl1234',
        );

        expect(profile.hasLightning, isTrue);
      });

      test('hasLightning returns false when neither is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.hasLightning, isFalse);
      });

      test('lightningAddress prefers lud16', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud16: 'test@wallet.com',
          lud06: 'lnurl1234',
        );

        expect(profile.lightningAddress, equals('test@wallet.com'));
      });

      test('lightningAddress falls back to lud06', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          lud06: 'lnurl1234',
        );

        expect(profile.lightningAddress, equals('lnurl1234'));
      });

      test('lightningAddress returns null when neither is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.lightningAddress, isNull);
      });
    });

    group('vine-specific properties', () {
      test('vineUsername returns value from rawData', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_username': 'vineuser'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineUsername, equals('vineuser'));
      });

      test('vineUsername returns null when not present', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineUsername, isNull);
      });

      test('vineVerified returns true when set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_verified': true},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineVerified, isTrue);
      });

      test('vineVerified returns false when not set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineVerified, isFalse);
      });

      test('vineFollowers returns int value', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_followers': 1000},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineFollowers, equals(1000));
      });

      test('vineFollowers parses string value', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_followers': '500'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineFollowers, equals(500));
      });

      test('vineFollowers returns null when not present', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineFollowers, isNull);
      });

      test('vineLoops returns int value', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_loops': 5000},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineLoops, equals(5000));
      });

      test('vineLoops parses string value', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_loops': '2500'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.vineLoops, equals(2500));
      });

      test('isVineImport returns true when vineUsername is set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'vine_username': 'vineuser'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.isVineImport, isTrue);
      });

      test('isVineImport returns false when vineUsername is not set', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.isVineImport, isFalse);
      });

      test('location returns value from rawData', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {'location': 'New York'},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.location, equals('New York'));
      });
    });

    group('divineUsername', () {
      test('extracts username from subdomain format _@user.divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '_@alice.divine.video',
        );

        expect(profile.divineUsername, equals('alice'));
      });

      test('extracts username from legacy format user@divine.video', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'bob@divine.video',
        );

        expect(profile.divineUsername, equals('bob'));
      });

      test('extracts username from legacy format user@openvine.co', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'charlie@openvine.co',
        );

        expect(profile.divineUsername, equals('charlie'));
      });

      test('returns null for non-divine NIP-05', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: 'user@example.com',
        );

        expect(profile.divineUsername, isNull);
      });

      test('returns null when nip05 is null', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile.divineUsername, isNull);
      });

      test('returns null when nip05 is empty', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          nip05: '',
        );

        expect(profile.divineUsername, isNull);
      });
    });

    group('copyWith', () {
      test('creates copy with updated fields', () {
        final original = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'original',
          displayName: 'Original Name',
        );

        final copy = original.copyWith(
          displayName: 'Updated Name',
          about: 'New bio',
        );

        expect(copy.pubkey, equals(testPubkey));
        expect(copy.name, equals('original'));
        expect(copy.displayName, equals('Updated Name'));
        expect(copy.about, equals('New bio'));
        expect(copy.createdAt, equals(testCreatedAt));
        expect(copy.eventId, equals(testEventId));
      });

      test('preserves original values when not specified', () {
        final original = UserProfile(
          pubkey: testPubkey,
          rawData: const {'custom': 'data'},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'testname',
          displayName: 'Test User',
          about: 'Test bio',
          picture: 'https://example.com/avatar.png',
        );

        final copy = original.copyWith(name: 'newname');

        expect(copy.name, equals('newname'));
        expect(copy.displayName, equals('Test User'));
        expect(copy.about, equals('Test bio'));
        expect(copy.picture, equals('https://example.com/avatar.png'));
        expect(copy.rawData, equals({'custom': 'data'}));
      });
    });

    group('equality', () {
      test('profiles with same pubkey and eventId are equal', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          name: 'name1',
        );

        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {'other': 'data'},
          createdAt: DateTime(2025),
          eventId: testEventId,
          name: 'name2',
        );

        expect(profile1, equals(profile2));
      });

      test('profiles with different pubkeys are not equal', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final profile2 = UserProfile(
          pubkey: 'different_pubkey',
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        expect(profile1, isNot(equals(profile2)));
      });

      test('profiles with different eventIds are not equal', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: 'different_event_id',
        );

        expect(profile1, isNot(equals(profile2)));
      });

      test('hashCode is consistent with equality', () {
        final profile1 = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
        );

        final profile2 = UserProfile(
          pubkey: testPubkey,
          rawData: const {'different': 'data'},
          createdAt: DateTime(2025),
          eventId: testEventId,
        );

        expect(profile1.hashCode, equals(profile2.hashCode));
      });
    });

    group('toString', () {
      test('returns formatted string', () {
        final profile = UserProfile(
          pubkey: testPubkey,
          rawData: const {},
          createdAt: testCreatedAt,
          eventId: testEventId,
          displayName: 'Test User',
          picture: 'https://example.com/avatar.png',
        );

        final result = profile.toString();

        expect(result, contains('UserProfile'));
        expect(result, contains(testPubkey));
        expect(result, contains('Test User'));
        expect(result, contains('hasAvatar: true'));
      });
    });
  });
}
