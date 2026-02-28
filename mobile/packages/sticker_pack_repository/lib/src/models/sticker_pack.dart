// ABOUTME: Model representing a curated sticker pack (Kind 30030 emoji set).
// ABOUTME: Contains pack metadata and a list of Sticker models parsed from
// ABOUTME: emoji tags in the Nostr event.

import 'package:equatable/equatable.dart';
import 'package:sticker_pack_repository/src/models/sticker.dart';

/// A sticker pack parsed from a Kind 30030 addressable event (NIP-51).
///
/// Each pack is published by Divine's pubkey and contains:
/// - A `d` tag as the unique identifier
/// - A `title` tag for the human-readable name
/// - An optional `image` tag for the pack thumbnail
/// - Multiple `emoji` tags, each defining a sticker
class StickerPack extends Equatable {
  /// Creates a new sticker pack.
  const StickerPack({
    required this.id,
    required this.title,
    required this.stickers,
    required this.authorPubkey,
    this.imageUrl,
  });

  /// Unique identifier from the `d` tag of the Kind 30030 event.
  final String id;

  /// Human-readable title from the `title` tag.
  final String title;

  /// Optional pack thumbnail URL from the `image` tag.
  final String? imageUrl;

  /// Stickers in this pack, parsed from `emoji` tags.
  final List<Sticker> stickers;

  /// Public key of the pack author (hex format).
  final String authorPubkey;

  @override
  List<Object?> get props => [id, title, imageUrl, stickers, authorPubkey];
}
