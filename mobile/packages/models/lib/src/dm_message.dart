// ABOUTME: Domain model for a decrypted NIP-17 direct message.
// ABOUTME: Supports both Kind 14 (text) and Kind 15 (file) messages.

import 'package:equatable/equatable.dart';
import 'package:models/src/dm_shared_video_ref.dart';

/// A decrypted NIP-17 direct message.
///
/// Represents a single message in a conversation after the three-layer
/// gift-wrap decryption (kind 1059 → kind 13 → kind 14/15).
///
/// For text messages (kind 14), [content] holds the plaintext.
/// For file messages (kind 15), [content] holds the encrypted file URL
/// and file metadata is in the [fileMetadata] field.
class DmMessage extends Equatable {
  const DmMessage({
    required this.id,
    required this.conversationId,
    required this.senderPubkey,
    required this.content,
    required this.createdAt,
    required this.giftWrapId,
    this.messageKind = 14,
    this.replyToId,
    this.subject,
    this.tags = const [],
    this.fileMetadata,
    this.sharedVideoRef,
  });

  /// The rumor event ID (kind 14 or 15).
  final String id;

  /// Deterministic conversation ID (SHA-256 of sorted participant pubkeys).
  final String conversationId;

  /// Sender's public key.
  final String senderPubkey;

  /// For kind 14: decrypted plaintext content.
  /// For kind 15: the encrypted file URL.
  final String content;

  /// Message creation timestamp (Unix seconds).
  final int createdAt;

  /// The gift-wrap event ID (kind 1059) used for deduplication.
  final String giftWrapId;

  /// The inner event kind (14 = text, 15 = file).
  final int messageKind;

  /// Optional parent message ID for threaded replies.
  final String? replyToId;

  /// Optional conversation subject/title.
  final String? subject;

  /// Tags from the decrypted NIP-17 rumor event.
  final List<List<String>> tags;

  /// File metadata for kind 15 messages. Null for kind 14.
  final DmFileMetadata? fileMetadata;

  /// Structured reference to a video event cited via a NIP-18 `q` tag.
  ///
  /// Non-null when this message shares a video (e.g. a reel shared into the
  /// DM); lets the UI render a deterministic video card. Null for ordinary
  /// messages and for legacy URL-only shares.
  final DmSharedVideoRef? sharedVideoRef;

  /// Whether this is a file message (kind 15).
  bool get isFileMessage => messageKind == 15;

  /// Whether this message carries a structured shared-video reference.
  bool get hasSharedVideo => sharedVideoRef != null;

  /// Whether this message was sent by the given pubkey.
  bool isSentBy(String pubkey) => senderPubkey == pubkey;

  @override
  List<Object?> get props => [
    id,
    conversationId,
    senderPubkey,
    content,
    createdAt,
    giftWrapId,
    messageKind,
    replyToId,
    subject,
    tags,
    fileMetadata,
    sharedVideoRef,
  ];
}

/// Metadata for a Kind 15 encrypted file message.
///
/// Contains the decryption parameters and file information needed to
/// download, decrypt, and display an encrypted file attachment.
class DmFileMetadata extends Equatable {
  const DmFileMetadata({
    required this.fileType,
    required this.encryptionAlgorithm,
    required this.decryptionKey,
    required this.decryptionNonce,
    required this.fileHash,
    this.originalFileHash,
    this.fileSize,
    this.dimensions,
    this.blurhash,
    this.thumbnailUrl,
  });

  /// MIME type of the file before encryption (e.g. `image/jpeg`).
  final String fileType;

  /// Encryption algorithm used (e.g. `aes-gcm`).
  final String encryptionAlgorithm;

  /// Hex-encoded AES key for decryption.
  final String decryptionKey;

  /// Hex-encoded nonce/IV for decryption.
  final String decryptionNonce;

  /// SHA-256 hex hash of the encrypted file (for integrity verification).
  final String fileHash;

  /// SHA-256 hex hash of the original file before encryption.
  final String? originalFileHash;

  /// Size of the encrypted file in bytes.
  final int? fileSize;

  /// Dimensions in `<width>x<height>` format (for images/video).
  final String? dimensions;

  /// BlurHash string for image preview while loading.
  final String? blurhash;

  /// URL of an encrypted thumbnail (same key/nonce).
  final String? thumbnailUrl;

  /// Whether this is an image file.
  bool get isImage => fileType.startsWith('image/');

  /// Whether this is a video file.
  bool get isVideo => fileType.startsWith('video/');

  /// Whether this is an audio file.
  bool get isAudio => fileType.startsWith('audio/');

  @override
  List<Object?> get props => [
    fileType,
    encryptionAlgorithm,
    decryptionKey,
    decryptionNonce,
    fileHash,
    originalFileHash,
    fileSize,
    dimensions,
    blurhash,
    thumbnailUrl,
  ];
}
