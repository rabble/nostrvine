// ABOUTME: Comprehensive tests for NIP-94 metadata model
// ABOUTME: Tests metadata validation, Nostr event generation, and JSON serialization

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr/nostr.dart';
import '../../lib/models/nip94_metadata.dart';

void main() {
  group('NIP94Metadata', () {
    const testUrl = 'https://nostrvine-backend.workers.dev/files/test.gif';
    const testHash = 'a1b2c3d4e5f67890123456789012345678901234567890123456789012345678';
    const testMimeType = 'image/gif';
    const testSize = 1024 * 1024; // 1MB
    const testDimensions = '320x240';
    
    late NIP94Metadata validMetadata;
    
    setUp(() {
      validMetadata = NIP94Metadata(
        url: testUrl,
        mimeType: testMimeType,
        sha256Hash: testHash,
        sizeBytes: testSize,
        dimensions: testDimensions,
        blurhash: 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
        altText: 'A test vine GIF',
        summary: 'Test vine content',
        durationMs: 6000,
        fps: 5.0,
        createdAt: DateTime(2024, 1, 1, 12, 0, 0),
      );
    });
    
    group('Creation and Validation', () {
      test('should create valid metadata with all fields', () {
        expect(validMetadata.url, equals(testUrl));
        expect(validMetadata.mimeType, equals(testMimeType));
        expect(validMetadata.sha256Hash, equals(testHash));
        expect(validMetadata.sizeBytes, equals(testSize));
        expect(validMetadata.dimensions, equals(testDimensions));
        expect(validMetadata.isValid, isTrue);
      });
      
      test('should validate required fields correctly', () {
        expect(validMetadata.isValid, isTrue);
        
        // Test invalid cases
        final invalidUrl = validMetadata.copyWith(url: '');
        expect(invalidUrl.isValid, isFalse);
        
        final invalidHash = validMetadata.copyWith(sha256Hash: 'invalid');
        expect(invalidHash.isValid, isFalse);
        
        final invalidSize = validMetadata.copyWith(sizeBytes: 0);
        expect(invalidSize.isValid, isFalse);
        
        final invalidDimensions = validMetadata.copyWith(dimensions: 'invalid');
        expect(invalidDimensions.isValid, isFalse);
      });
      
      test('should create from GIF result correctly', () {
        final metadata = NIP94Metadata.fromGifResult(
          url: testUrl,
          sha256Hash: testHash,
          width: 320,
          height: 240,
          sizeBytes: testSize,
          summary: 'Test summary',
          altText: 'Test alt text',
          durationMs: 6000,
          fps: 5.0,
        );
        
        expect(metadata.url, equals(testUrl));
        expect(metadata.mimeType, equals('image/gif'));
        expect(metadata.width, equals(320));
        expect(metadata.height, equals(240));
        expect(metadata.summary, equals('Test summary'));
        expect(metadata.isGif, isTrue);
        expect(metadata.isVideo, isFalse);
      });
    });
    
    group('Computed Properties', () {
      test('should extract width and height from dimensions', () {
        expect(validMetadata.width, equals(320));
        expect(validMetadata.height, equals(240));
      });
      
      test('should calculate file size in MB', () {
        expect(validMetadata.fileSizeMB, equals(1.0));
      });
      
      test('should convert duration to seconds', () {
        expect(validMetadata.durationSeconds, equals(6.0));
      });
      
      test('should identify file types correctly', () {
        expect(validMetadata.isGif, isTrue);
        expect(validMetadata.isVideo, isFalse);
        
        final videoMetadata = validMetadata.copyWith(mimeType: 'video/mp4');
        expect(videoMetadata.isGif, isFalse);
        expect(videoMetadata.isVideo, isTrue);
      });
    });
    
    group('JSON Serialization', () {
      test('should serialize to JSON correctly', () {
        final json = validMetadata.toJson();
        
        expect(json['url'], equals(testUrl));
        expect(json['mime_type'], equals(testMimeType));
        expect(json['sha256'], equals(testHash));
        expect(json['size'], equals(testSize));
        expect(json['dimensions'], equals(testDimensions));
        expect(json['blurhash'], equals('LEHV6nWB2yk8pyo0adR*.7kCMdnj'));
        expect(json['alt_text'], equals('A test vine GIF'));
        expect(json['summary'], equals('Test vine content'));
        expect(json['duration_ms'], equals(6000));
        expect(json['fps'], equals(5.0));
        expect(json['created_at'], isA<String>());
      });
      
      test('should deserialize from JSON correctly', () {
        final json = {
          'url': testUrl,
          'mime_type': testMimeType,
          'sha256': testHash,
          'size': testSize,
          'dimensions': testDimensions,
          'blurhash': 'LEHV6nWB2yk8pyo0adR*.7kCMdnj',
          'alt_text': 'A test vine GIF',
          'summary': 'Test vine content',
          'duration_ms': 6000,
          'fps': 5.0,
          'created_at': '2024-01-01T12:00:00.000',
        };
        
        final metadata = NIP94Metadata.fromJson(json);
        
        expect(metadata.url, equals(testUrl));
        expect(metadata.mimeType, equals(testMimeType));
        expect(metadata.sha256Hash, equals(testHash));
        expect(metadata.sizeBytes, equals(testSize));
        expect(metadata.dimensions, equals(testDimensions));
        expect(metadata.blurhash, equals('LEHV6nWB2yk8pyo0adR*.7kCMdnj'));
        expect(metadata.altText, equals('A test vine GIF'));
        expect(metadata.summary, equals('Test vine content'));
        expect(metadata.durationMs, equals(6000));
        expect(metadata.fps, equals(5.0));
        expect(metadata.createdAt, isA<DateTime>());
      });
      
      test('should handle optional fields in JSON', () {
        final minimalJson = {
          'url': testUrl,
          'mime_type': testMimeType,
          'sha256': testHash,
          'size': testSize,
          'dimensions': testDimensions,
        };
        
        final metadata = NIP94Metadata.fromJson(minimalJson);
        
        expect(metadata.url, equals(testUrl));
        expect(metadata.blurhash, isNull);
        expect(metadata.altText, isNull);
        expect(metadata.summary, isNull);
        expect(metadata.durationMs, isNull);
        expect(metadata.fps, isNull);
        expect(metadata.isValid, isTrue);
      });
    });
    
    group('Nostr Event Generation', () {
      test('should generate valid NIP-94 event', () {
        // Create a test key pair
        final testKeyPairs = Keychain.generate();
        const testContent = 'Check out my vine!';
        const testHashtags = ['nostr', 'vine', 'gif'];
        
        final event = validMetadata.toNostrEvent(
          keyPairs: testKeyPairs,
          content: testContent,
          hashtags: testHashtags,
        );
        
        expect(event.kind, equals(1063)); // NIP-94 kind
        expect(event.pubkey, isA<String>());
        expect(event.pubkey.length, equals(64)); // Public key should be 64 hex chars
        expect(event.content, equals(testContent));
        expect(event.createdAt, isA<int>());
        
        // Check required tags
        final tags = event.tags;
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'url' && tag[1] == testUrl), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'm' && tag[1] == testMimeType), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'x' && tag[1] == testHash), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'size' && tag[1] == testSize.toString()), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'dim' && tag[1] == testDimensions), isTrue);
        
        // Check optional tags
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'blurhash' && tag[1] == 'LEHV6nWB2yk8pyo0adR*.7kCMdnj'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'alt' && tag[1] == 'A test vine GIF'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'summary' && tag[1] == 'Test vine content'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'duration' && tag[1] == '6.0'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'fps' && tag[1] == '5.0'), isTrue);
        
        // Check hashtags
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 't' && tag[1] == 'nostr'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 't' && tag[1] == 'vine'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 't' && tag[1] == 'gif'), isTrue);
      });
      
      test('should generate minimal event without optional fields', () {
        final minimalMetadata = NIP94Metadata(
          url: testUrl,
          mimeType: testMimeType,
          sha256Hash: testHash,
          sizeBytes: testSize,
          dimensions: testDimensions,
        );
        
        final testKeyPairs = Keychain.generate();
        
        final event = minimalMetadata.toNostrEvent(
          keyPairs: testKeyPairs,
          content: 'Minimal vine',
        );
        
        expect(event.kind, equals(1063));
        expect(event.pubkey, isA<String>());
        expect(event.pubkey.length, equals(64));
        expect(event.content, equals('Minimal vine'));
        
        // Should have required tags only
        final tags = event.tags;
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'url' && tag[1] == testUrl), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'm' && tag[1] == testMimeType), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'x' && tag[1] == testHash), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'size' && tag[1] == testSize.toString()), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'dim' && tag[1] == testDimensions), isTrue);
        
        // Should not have optional tags
        expect(tags.any((tag) => tag[0] == 'blurhash'), isFalse);
        expect(tags.any((tag) => tag[0] == 'alt'), isFalse);
        expect(tags.any((tag) => tag[0] == 'summary'), isFalse);
      });
      
      test('should handle additional custom tags', () {
        final testKeyPairs = Keychain.generate();
        const additionalTags = ['custom:value', 'type:vine'];
        
        final event = validMetadata.toNostrEvent(
          keyPairs: testKeyPairs,
          content: 'Custom tags test',
          customTags: additionalTags,
        );
        
        final tags = event.tags;
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'custom' && tag[1] == 'value'), isTrue);
        expect(tags.any((tag) => tag.length >= 2 && tag[0] == 'type' && tag[1] == 'vine'), isTrue);
      });
    });
    
    group('Equality and Hashing', () {
      test('should implement equality correctly', () {
        final metadata1 = NIP94Metadata(
          url: testUrl,
          mimeType: testMimeType,
          sha256Hash: testHash,
          sizeBytes: testSize,
          dimensions: testDimensions,
        );
        
        final metadata2 = NIP94Metadata(
          url: testUrl,
          mimeType: testMimeType,
          sha256Hash: testHash,
          sizeBytes: testSize,
          dimensions: testDimensions,
        );
        
        final metadata3 = metadata1.copyWith(url: 'different-url');
        
        expect(metadata1, equals(metadata2));
        expect(metadata1, isNot(equals(metadata3)));
        expect(metadata1.hashCode, equals(metadata2.hashCode));
      });
    });
    
    group('Copy and Modification', () {
      test('should copy with modified fields', () {
        const newUrl = 'https://different.com/file.gif';
        final copied = validMetadata.copyWith(url: newUrl);
        
        expect(copied.url, equals(newUrl));
        expect(copied.mimeType, equals(validMetadata.mimeType));
        expect(copied.sha256Hash, equals(validMetadata.sha256Hash));
        expect(copied != validMetadata, isTrue);
      });
    });
    
    group('String Representation', () {
      test('should provide meaningful string representation', () {
        final str = validMetadata.toString();
        
        expect(str, contains('NIP94Metadata'));
        expect(str, contains(testUrl));
        expect(str, contains(testMimeType));
        expect(str, contains('1.00MB'));
        expect(str, contains(testDimensions));
        expect(str, contains(testHash.substring(0, 8)));
      });
    });
    
    group('Validation Exceptions', () {
      test('should throw validation exception for invalid metadata', () {
        expect(
          () => throw const NIP94ValidationException('Invalid metadata'),
          throwsA(isA<NIP94ValidationException>()),
        );
        
        final exception = NIP94ValidationException('Test error');
        expect(exception.message, equals('Test error'));
        expect(exception.toString(), contains('NIP94ValidationException'));
      });
    });
  });
}