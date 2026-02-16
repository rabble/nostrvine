// ABOUTME: Tests for VideoEvent parsing from Nostr events
// ABOUTME: Verifies divine.video schema and open protocol URL validation
// ignore_for_file: lines_longer_than_80_chars

import 'package:models/models.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:test/test.dart';

void main() {
  group('VideoEvent parsing from Nostr events', () {
    test('should parse streaming tag with HLS URL', () {
      // Arrange - create a Nostr event with streaming tag
      final nostrEvent = Event(
        '0f1e20e4f53b27b62a3eb4fe7eb454c6a4d1040abfa279e7bb4a5222723541c9',
        34236,
        [
          ['d', '5gITeYOlL7g'],
          ['title', 'A low quality edit with high quality content. ✨'],
          [
            'streaming',
            'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/manifest/video.m3u8',
            'hls',
          ],
          [
            'thumb',
            'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/thumbnails/thumbnail.jpg',
          ],
          [
            'preview',
            'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/thumbnails/thumbnail.gif',
          ],
          ['vine_id', '5gITeYOlL7g'],
          ['loops', '13565'],
          ['likes', '732'],
        ],
        'A low quality edit with high quality content. ✨',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(
        videoEvent.videoUrl,
        equals(
          'https://cdn.divine.video/cfd0c51a0db4c2a9ff23f9c5ada7db8b/manifest/video.m3u8',
        ),
      );
      expect(
        videoEvent.title,
        equals('A low quality edit with high quality content. ✨'),
      );
      expect(videoEvent.vineId, equals('5gITeYOlL7g'));
      expect(videoEvent.originalLoops, equals(13565));
      expect(videoEvent.originalLikes, equals(732));
    });

    test(
      'should NOT use preview GIF as thumbnail (uses static thumb instead)',
      () {
        // Arrange
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['thumb', 'https://example.com/static-thumbnail.jpg'],
            ['preview', 'https://example.com/animated-preview.gif'],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert - Should use static thumbnail, not GIF
        expect(
          videoEvent.thumbnailUrl,
          equals('https://example.com/static-thumbnail.jpg'),
        );
      },
    );

    test('should accept video URLs from any domain (open protocol)', () {
      // Arrange - test various domains that should all be accepted
      final domains = [
        'https://my-personal-server.com/video.mp4',
        'https://cdn.divine.video/path/video.m3u8',
        'https://random-cdn.xyz/stream.mpd',
        'https://192.168.1.100/local-video.webm',
        'https://example.onion/tor-video.mp4',
      ];

      for (final url in domains) {
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', url],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(
          videoEvent.videoUrl,
          equals(url),
          reason: 'Should accept video from $url (open protocol)',
        );
      }
    });

    test('should handle both d tag and vine_id tag for Vine ID', () {
      // Test with 'd' tag
      final eventWithDTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['d', 'vine-id-from-d-tag'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent1 = VideoEvent.fromNostrEvent(eventWithDTag);
      expect(videoEvent1.vineId, equals('vine-id-from-d-tag'));

      // Test with 'vine_id' tag
      final eventWithVineIdTag = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['vine_id', 'vine-id-from-vine-id-tag'],
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent2 = VideoEvent.fromNostrEvent(eventWithVineIdTag);
      expect(videoEvent2.vineId, equals('vine-id-from-vine-id-tag'));
    });

    test(
      'should parse imeta tag with blurhash from divine.video events (OLD FORMAT - space-separated)',
      () {
        // Arrange
        final nostrEvent = Event(
          '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
          34236,
          [
            ['url', 'https://cdn.divine.video/test/video.m3u8'],
            [
              'imeta',
              'url https://cdn.divine.video/test/video.mp4',
              'm video/mp4',
              'dim 480x480',
              'duration 6',
              'blurhash U~L;mea|M{t7WBj[j[ay~qoft7j[%MWBayj[',
              'image https://cdn.divine.video/test/thumbnail.jpg',
            ],
          ],
          'Test video',
          createdAt: 1757385263,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(
          videoEvent.blurhash,
          equals('U~L;mea|M{t7WBj[j[ay~qoft7j[%MWBayj['),
        );
        expect(videoEvent.dimensions, equals('480x480'));
        expect(videoEvent.duration, equals(6));
        expect(
          videoEvent.thumbnailUrl,
          equals('https://cdn.divine.video/test/thumbnail.jpg'),
        );
      },
    );

    test(
      'should parse imeta tag with blurhash (NEW FORMAT - positional key-value pairs)',
      () {
        // Arrange - This is the format used by newer divine.video events
        final nostrEvent = Event(
          '62054c6897d4971d03979196c0d7b6f54d501fed44cda0ce9d2bb88ff67992ba',
          34236,
          [
            ['d', 'iOr5DLaPr79'],
            [
              'imeta',
              'url',
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/play_240p.mp4',
              'm',
              'video/mp4',
              'image',
              'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
              'blurhash',
              'L9AAEz-o?^TK4.%gVs-o009F9E9F',
              'dim',
              '720x720',
              'x',
              '70c84853646e2e8f64ef07ebd5e5267329d21d194af1138a790cdb4463d1f0b7',
            ],
            ['title', 'jordan'],
          ],
          'jordan',
          createdAt: 1761378640,
        );

        // Act
        final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

        // Assert
        expect(videoEvent.blurhash, equals('L9AAEz-o?^TK4.%gVs-o009F9E9F'));
        expect(videoEvent.dimensions, equals('720x720'));
        expect(
          videoEvent.thumbnailUrl,
          equals(
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/thumbnail.jpg',
          ),
        );
        expect(
          videoEvent.videoUrl,
          equals(
            'https://stream.divine.video/fa4a90a3-6a30-4dc6-9b9d-3f78551c9053/play_240p.mp4',
          ),
        );
        expect(
          videoEvent.sha256,
          equals(
            '70c84853646e2e8f64ef07ebd5e5267329d21d194af1138a790cdb4463d1f0b7',
          ),
        );
        expect(videoEvent.mimeType, equals('video/mp4'));
      },
    );

    test('should not require specific file extensions for video URLs', () {
      // Arrange - URL without typical video extension
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'https://api.example.com/stream/12345'], // No file extension
        ],
        'Test video',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(
        videoEvent.videoUrl,
        equals('https://api.example.com/stream/12345'),
      );
    });

    test('should reject non-HTTP/HTTPS URLs', () {
      // Arrange
      final nostrEvent = Event(
        '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef',
        34236,
        [
          ['url', 'ftp://example.com/video.mp4'], // FTP protocol
        ],
        'Test video',
        createdAt: 1757385263,
      );

      // Act
      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      // Assert
      expect(videoEvent.videoUrl, isNull);
    });
  });

  group('VideoEvent collaborator parsing', () {
    const authorPubkey =
        'aaaa567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const collabPubkey1 =
        'bbbb567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const collabPubkey2 =
        'cccc567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    test('should parse p-tags as collaborators when different from author', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', collabPubkey1, 'wss://relay.divine.video'],
          ['p', collabPubkey2, 'wss://relay.divine.video'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, hasLength(2));
      expect(videoEvent.collaboratorPubkeys, contains(collabPubkey1));
      expect(videoEvent.collaboratorPubkeys, contains(collabPubkey2));
      expect(videoEvent.hasCollaborators, isTrue);
    });

    test('should not include author pubkey as collaborator', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', authorPubkey, 'wss://relay.divine.video'], // Author self-tag
          ['p', collabPubkey1, 'wss://relay.divine.video'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, hasLength(1));
      expect(videoEvent.collaboratorPubkeys, contains(collabPubkey1));
      expect(
        videoEvent.collaboratorPubkeys,
        isNot(contains(authorPubkey)),
      );
    });

    test('should deduplicate collaborator pubkeys', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', collabPubkey1, 'wss://relay.divine.video'],
          ['p', collabPubkey1, 'wss://relay.divine.video'], // Duplicate
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, hasLength(1));
    });

    test('should return empty collaborators when no p-tags', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, isEmpty);
      expect(videoEvent.hasCollaborators, isFalse);
    });

    test('should skip empty p-tag values', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['p', '', 'wss://relay.divine.video'], // Empty pubkey
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.collaboratorPubkeys, isEmpty);
    });
  });

  group('VideoEvent Inspired By parsing', () {
    const authorPubkey =
        'aaaa567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
    const creatorPubkey =
        'dddd567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';

    test('should parse a-tag as inspiredByVideo for Kind 34236 references', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'a',
            '34236:$creatorPubkey:test-d-tag',
            'wss://relay.divine.video',
            'mention',
          ],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNotNull);
      expect(
        videoEvent.inspiredByVideo!.addressableId,
        equals('34236:$creatorPubkey:test-d-tag'),
      );
      expect(
        videoEvent.inspiredByVideo!.relayUrl,
        equals('wss://relay.divine.video'),
      );
      expect(
        videoEvent.inspiredByVideo!.creatorPubkey,
        equals(creatorPubkey),
      );
      expect(videoEvent.inspiredByVideo!.dTag, equals('test-d-tag'));
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test('should ignore a-tag that does not start with 34236:', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          ['a', '30023:$creatorPubkey:some-article', 'wss://relay.example.com'],
        ],
        'Test video',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNull);
    });

    test('should parse NIP-27 nostr:npub in content as inspiredByNpub', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Great idea! Inspired by nostr:npub1abc123def456ghi789',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(
        videoEvent.inspiredByNpub,
        equals('npub1abc123def456ghi789'),
      );
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test('should not set inspiredByNpub when no nostr:npub in content', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'Just a regular description with no mentions',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByNpub, isNull);
    });

    test('should parse both a-tag and npub content together', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
          [
            'a',
            '34236:$creatorPubkey:test-d-tag',
            'wss://relay.divine.video',
          ],
        ],
        'Inspired by nostr:npub1xyz789abc',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNotNull);
      expect(videoEvent.inspiredByNpub, equals('npub1xyz789abc'));
      expect(videoEvent.hasInspiredBy, isTrue);
    });

    test('should not have inspiredBy when no a-tag or npub', () {
      final nostrEvent = Event(
        authorPubkey,
        34236,
        [
          ['url', 'https://example.com/video.mp4'],
        ],
        'No inspiration here',
        createdAt: 1757385263,
      );

      final videoEvent = VideoEvent.fromNostrEvent(nostrEvent);

      expect(videoEvent.inspiredByVideo, isNull);
      expect(videoEvent.inspiredByNpub, isNull);
      expect(videoEvent.hasInspiredBy, isFalse);
    });
  });

  group(InspiredByInfo, () {
    test('should parse creatorPubkey from addressableId', () {
      const info = InspiredByInfo(
        addressableId: '34236:abc123:my-video',
      );

      expect(info.creatorPubkey, equals('abc123'));
    });

    test('should parse dTag from addressableId', () {
      const info = InspiredByInfo(
        addressableId: '34236:abc123:my-video',
      );

      expect(info.dTag, equals('my-video'));
    });

    test('should handle addressableId with missing segments', () {
      const infoNoSegments = InspiredByInfo(addressableId: '34236');

      expect(infoNoSegments.creatorPubkey, isEmpty);
      expect(infoNoSegments.dTag, isEmpty);
    });

    test('should round-trip through JSON serialization', () {
      const original = InspiredByInfo(
        addressableId: '34236:abc123:my-video',
        relayUrl: 'wss://relay.divine.video',
      );

      final json = original.toJson();
      final restored = InspiredByInfo.fromJson(json);

      expect(restored.addressableId, equals(original.addressableId));
      expect(restored.relayUrl, equals(original.relayUrl));
      expect(restored, equals(original));
    });

    test('should serialize without relayUrl when null', () {
      const info = InspiredByInfo(addressableId: '34236:abc:vid');

      final json = info.toJson();

      expect(json.containsKey('relayUrl'), isFalse);
      expect(json['addressableId'], equals('34236:abc:vid'));
    });

    test('should implement equality based on addressableId', () {
      const info1 = InspiredByInfo(
        addressableId: '34236:abc:vid',
        relayUrl: 'wss://relay1.com',
      );
      const info2 = InspiredByInfo(
        addressableId: '34236:abc:vid',
        relayUrl: 'wss://relay2.com', // Different relay, same ID
      );
      const info3 = InspiredByInfo(
        addressableId: '34236:different:vid',
      );

      expect(info1, equals(info2));
      expect(info1, isNot(equals(info3)));
    });
  });
}
