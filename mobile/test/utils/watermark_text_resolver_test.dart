import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/utils/watermark_text_resolver.dart';

void main() {
  UserProfile buildProfile({String? displayName, String? name, String? nip05}) {
    return UserProfile(
      pubkey: 'a' * 64,
      rawData: const {},
      createdAt: DateTime(2026),
      eventId: 'event-id',
      displayName: displayName,
      name: name,
      nip05: nip05,
    );
  }

  group('resolveWatermarkText', () {
    test('prefers displayed divine.video NIP-05', () {
      final profile = buildProfile(
        displayName: 'Jack and Jack',
        nip05: '_@jackandjackofficial.divine.video',
      );

      expect(
        resolveWatermarkText(profile: profile),
        '@jackandjackofficial.divine.video',
      );
    });

    test('preserves external NIP-05 exactly', () {
      final profile = buildProfile(
        displayName: 'Alice',
        nip05: 'alice@example.com',
      );

      expect(resolveWatermarkText(profile: profile), 'alice@example.com');
    });

    test('falls back to profile display name with a leading at-sign', () {
      final profile = buildProfile(displayName: 'Jack and Jack');

      expect(resolveWatermarkText(profile: profile), '@Jack and Jack');
    });

    test('falls back to author name when profile has no usable identity', () {
      final profile = buildProfile();

      expect(
        resolveWatermarkText(
          profile: profile,
          fallbackAuthorName: 'Creator Name',
        ),
        '@Creator Name',
      );
    });

    test('falls back to Divine when no profile or author name exists', () {
      expect(resolveWatermarkText(), '@Divine');
    });
  });
}
