// ABOUTME: Tests public sound credit stored with a video draft.
// ABOUTME: Proves normalization and validation stay separate from private library data.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/audio_share_attribution.dart';

void main() {
  group(AudioShareAttribution, () {
    test('round-trips complete public attribution and normalized tags', () {
      const attribution = AudioShareAttribution(
        title: 'Street rain',
        creatorName: 'Alice',
        creatorPubkey: 'full-pubkey',
        creatorUrl: 'https://example.com/alice',
        sourceUrl: 'https://example.com/source',
        licenseName: 'CC BY 4.0',
        licenseUrl: 'https://creativecommons.org/licenses/by/4.0/',
        publicTags: [' Field Recording ', '#RAIN', 'rain'],
        confirmedOwnWork: false,
      );

      final restored = AudioShareAttribution.fromJson(attribution.toJson());

      expect(restored, attribution.copyWith());
      expect(restored.publicTags, ['field recording', 'rain']);
      expect(restored.isValid, isTrue);
      expect(restored.toJson(), isNot(contains('personalHashtags')));
      expect(restored.toJson(), isNot(contains('personalLabel')));
    });

    test('owned sound requires a title and defaults creator to publisher', () {
      final valid = AudioShareAttribution.forOwnedSound(
        title: 'My loop',
        publisherName: 'Rabble',
        publisherPubkey: 'full-pubkey',
      );
      final invalid = AudioShareAttribution.forOwnedSound(
        title: ' ',
        publisherName: 'Rabble',
        publisherPubkey: 'full-pubkey',
      );

      expect(valid.creatorName, 'Rabble');
      expect(valid.confirmedOwnWork, isTrue);
      expect(valid.isValid, isTrue);
      expect(invalid.isValid, isFalse);
    });

    test('external import requires creator and source URL', () {
      const valid = AudioShareAttribution(
        title: 'Found sound',
        creatorName: 'Original artist',
        sourceUrl: 'https://example.com/source',
        publicTags: [],
        confirmedOwnWork: false,
      );
      const missingSource = AudioShareAttribution(
        title: 'Found sound',
        creatorName: 'Original artist',
        publicTags: [],
        confirmedOwnWork: false,
      );

      expect(valid.isValid, isTrue);
      expect(missingSource.isValid, isFalse);
    });
  });
}
