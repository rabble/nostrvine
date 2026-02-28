// ABOUTME: Model representing a single sticker within a sticker pack.
// ABOUTME: Contains a shortcode (NIP-30 emoji name) and the image URL
// ABOUTME: hosted on a Blossom server.

import 'package:equatable/equatable.dart';

/// A single sticker from a sticker pack.
///
/// Maps to a single `emoji` tag in a Kind 30030 event:
/// `["emoji", shortcode, imageUrl]`
///
/// Used in comments as NIP-30 custom emoji: `:shortcode:` in content
/// with a corresponding `["emoji", shortcode, imageUrl]` tag.
class Sticker extends Equatable {
  /// Creates a new sticker.
  const Sticker({
    required this.shortcode,
    required this.imageUrl,
  });

  /// The emoji shortcode (e.g., "fire", "love").
  ///
  /// Used in NIP-30 syntax as `:shortcode:` in event content.
  final String shortcode;

  /// URL of the sticker image, typically hosted on a Blossom server.
  final String imageUrl;

  @override
  List<Object> get props => [shortcode, imageUrl];
}
