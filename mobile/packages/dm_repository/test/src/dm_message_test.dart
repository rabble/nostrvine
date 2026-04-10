// ABOUTME: Unit tests for the DmMessage domain model.
// ABOUTME: Verifies equality, isSentBy, optional field defaults,
// ABOUTME: and Kind 15 file metadata support.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

void main() {
  group(DmMessage, () {
    const senderPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
    const otherPubkey =
        'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
    const messageId =
        '1111222233334444555566667777888899990000aaaabbbbccccddddeeeeffff';
    const conversationId =
        'aabbccdd11223344aabbccdd11223344aabbccdd11223344aabbccdd11223344';
    const giftWrapId =
        'ffff0000eeee1111dddd2222cccc3333bbbb4444aaaa555599998888777766660000';

    DmMessage createMessage({
      String id = messageId,
      String conversationId = conversationId,
      String senderPubkey = senderPubkey,
      String content = 'Hello, world!',
      int createdAt = 1700000000,
      String giftWrapId = giftWrapId,
      int messageKind = 14,
      String? replyToId,
      String? subject,
      DmFileMetadata? fileMetadata,
    }) {
      return DmMessage(
        id: id,
        conversationId: conversationId,
        senderPubkey: senderPubkey,
        content: content,
        createdAt: createdAt,
        giftWrapId: giftWrapId,
        messageKind: messageKind,
        replyToId: replyToId,
        subject: subject,
        fileMetadata: fileMetadata,
      );
    }

    group('equality', () {
      test('two identical instances are equal', () {
        final a = createMessage();
        final b = createMessage();

        expect(a, equals(b));
      });

      test('instances with different content are not equal', () {
        final a = createMessage();
        final b = createMessage(content: 'Goodbye, world!');

        expect(a, isNot(equals(b)));
      });

      test('instances with different messageKind are not equal', () {
        final a = createMessage();
        final b = createMessage(messageKind: 15);

        expect(a, isNot(equals(b)));
      });
    });

    group('isSentBy', () {
      test('returns true for matching pubkey', () {
        final message = createMessage();

        expect(message.isSentBy(senderPubkey), isTrue);
      });

      test('returns false for non-matching pubkey', () {
        final message = createMessage();

        expect(message.isSentBy(otherPubkey), isFalse);
      });
    });

    group('defaults', () {
      test('optional fields default to null', () {
        final message = createMessage();

        expect(message.replyToId, isNull);
        expect(message.subject, isNull);
        expect(message.fileMetadata, isNull);
      });

      test('messageKind defaults to 14', () {
        final message = createMessage();

        expect(message.messageKind, equals(14));
      });
    });

    group('isFileMessage', () {
      test('returns false for kind 14', () {
        final message = createMessage();

        expect(message.isFileMessage, isFalse);
      });

      test('returns true for kind 15', () {
        final message = createMessage(messageKind: 15);

        expect(message.isFileMessage, isTrue);
      });
    });
  });

  group(DmFileMetadata, () {
    const testKey =
        'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
    const testNonce = 'bbbbbbbbbbbbbbbbbbbbbbbbbb';
    const testHash =
        'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';

    DmFileMetadata createFileMetadata({
      String fileType = 'image/jpeg',
      String encryptionAlgorithm = 'aes-gcm',
      String decryptionKey = testKey,
      String decryptionNonce = testNonce,
      String fileHash = testHash,
      String? originalFileHash,
      int? fileSize,
      String? dimensions,
      String? blurhash,
      String? thumbnailUrl,
    }) {
      return DmFileMetadata(
        fileType: fileType,
        encryptionAlgorithm: encryptionAlgorithm,
        decryptionKey: decryptionKey,
        decryptionNonce: decryptionNonce,
        fileHash: fileHash,
        originalFileHash: originalFileHash,
        fileSize: fileSize,
        dimensions: dimensions,
        blurhash: blurhash,
        thumbnailUrl: thumbnailUrl,
      );
    }

    group('equality', () {
      test('two identical instances are equal', () {
        final a = createFileMetadata();
        final b = createFileMetadata();

        expect(a, equals(b));
      });

      test('instances with different fileType are not equal', () {
        final a = createFileMetadata();
        final b = createFileMetadata(fileType: 'video/mp4');

        expect(a, isNot(equals(b)));
      });
    });

    group('isImage', () {
      test('returns true for image/jpeg', () {
        expect(createFileMetadata().isImage, isTrue);
      });

      test('returns true for image/png', () {
        expect(createFileMetadata(fileType: 'image/png').isImage, isTrue);
      });

      test('returns false for video/mp4', () {
        expect(createFileMetadata(fileType: 'video/mp4').isImage, isFalse);
      });
    });

    group('isVideo', () {
      test('returns true for video/mp4', () {
        expect(createFileMetadata(fileType: 'video/mp4').isVideo, isTrue);
      });

      test('returns false for image/jpeg', () {
        expect(createFileMetadata().isVideo, isFalse);
      });
    });

    group('isAudio', () {
      test('returns true for audio/mpeg', () {
        expect(createFileMetadata(fileType: 'audio/mpeg').isAudio, isTrue);
      });

      test('returns false for image/jpeg', () {
        expect(createFileMetadata().isAudio, isFalse);
      });
    });

    group('optional fields', () {
      test('default to null', () {
        final metadata = createFileMetadata();

        expect(metadata.originalFileHash, isNull);
        expect(metadata.fileSize, isNull);
        expect(metadata.dimensions, isNull);
        expect(metadata.blurhash, isNull);
        expect(metadata.thumbnailUrl, isNull);
      });

      test('can be set', () {
        const testOriginalHash =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        final metadata = createFileMetadata(
          originalFileHash: testOriginalHash,
          fileSize: 1024,
          dimensions: '1920x1080',
          blurhash: 'LGF5]+Yk^6#M@-5c,1J5@[or[Q6.',
          thumbnailUrl: 'https://example.com/thumb.jpg',
        );

        expect(metadata.originalFileHash, equals(testOriginalHash));
        expect(metadata.fileSize, equals(1024));
        expect(metadata.dimensions, equals('1920x1080'));
        expect(metadata.blurhash, equals('LGF5]+Yk^6#M@-5c,1J5@[or[Q6.'));
        expect(
          metadata.thumbnailUrl,
          equals('https://example.com/thumb.jpg'),
        );
      });
    });
  });
}
