import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/notification_preferences.dart';

void main() {
  group(NotificationPreferences, () {
    test('defaults all preferences to true', () {
      const prefs = NotificationPreferences();
      expect(prefs.likesEnabled, isTrue);
      expect(prefs.commentsEnabled, isTrue);
      expect(prefs.followsEnabled, isTrue);
      expect(prefs.mentionsEnabled, isTrue);
      expect(prefs.repostsEnabled, isTrue);
    });

    group('toKindsList', () {
      test('returns all kinds when all enabled', () {
        const prefs = NotificationPreferences();
        expect(prefs.toKindsList(), equals([1, 3, 7, 16]));
      });

      test('excludes kind 7 when likes disabled', () {
        const prefs = NotificationPreferences(likesEnabled: false);
        expect(prefs.toKindsList(), isNot(contains(7)));
      });

      test('returns empty when all disabled', () {
        const prefs = NotificationPreferences(
          likesEnabled: false,
          commentsEnabled: false,
          followsEnabled: false,
          mentionsEnabled: false,
          repostsEnabled: false,
        );
        expect(prefs.toKindsList(), isEmpty);
      });
    });

    group('fromKindsList', () {
      test('creates preferences from kinds list', () {
        final prefs = NotificationPreferences.fromKindsList(const [7, 3]);
        expect(prefs.likesEnabled, isTrue);
        expect(prefs.commentsEnabled, isFalse);
        expect(prefs.followsEnabled, isTrue);
        expect(prefs.mentionsEnabled, isFalse);
        expect(prefs.repostsEnabled, isFalse);
      });

      test('creates all-enabled from full kinds list', () {
        final prefs = NotificationPreferences.fromKindsList(const [
          1,
          3,
          7,
          16,
        ]);
        expect(prefs.likesEnabled, isTrue);
        expect(prefs.commentsEnabled, isTrue);
        expect(prefs.followsEnabled, isTrue);
        expect(prefs.mentionsEnabled, isTrue);
        expect(prefs.repostsEnabled, isTrue);
      });
    });

    group('toJson / fromJson', () {
      test('round-trips correctly', () {
        const original = NotificationPreferences(
          commentsEnabled: false,
          mentionsEnabled: false,
        );
        final json = original.toJson();
        final restored = NotificationPreferences.fromJson(json);
        expect(restored, equals(original));
      });
    });

    test('equality works via Equatable', () {
      const a = NotificationPreferences(likesEnabled: false);
      const b = NotificationPreferences(likesEnabled: false);
      const c = NotificationPreferences();
      expect(a, equals(b));
      expect(a, isNot(equals(c)));
    });
  });
}
