import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('FileMetadata.fromNIP92Tag', () {
    test('parses positional imeta metadata', () {
      final metadata = FileMetadata.fromNIP92Tag([
        'imeta',
        'url',
        'https://media.divine.video/image.jpg',
        'm',
        'image/jpeg',
        'dim',
        '720x1280',
        'thumb',
        'https://media.divine.video/thumb.jpg',
        'blurhash',
        'LKO2?U%2Tw=w]~RBVZRi};RPxuwH',
      ]);

      expect(metadata, isNotNull);
      expect(metadata!.url, equals('https://media.divine.video/image.jpg'));
      expect(metadata.m, equals('image/jpeg'));
      expect(metadata.dim, equals('720x1280'));
      expect(metadata.thumb, equals('https://media.divine.video/thumb.jpg'));
      expect(metadata.blurhash, equals('LKO2?U%2Tw=w]~RBVZRi};RPxuwH'));
    });

    test('preserves space-separated alt and summary values with spaces', () {
      final metadata = FileMetadata.fromNIP92Tag([
        'imeta',
        'url https://media.divine.video/image.jpg',
        'm image/jpeg',
        'alt A caption with spaces',
        'summary A longer summary with spaces',
      ]);

      expect(metadata, isNotNull);
      expect(metadata!.alt, equals('A caption with spaces'));
      expect(metadata.summary, equals('A longer summary with spaces'));
    });
  });
}
