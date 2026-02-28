// ABOUTME: Custom exceptions for the sticker pack repository.
// ABOUTME: Provides typed exceptions for specific failure cases
// ABOUTME: to enable precise error handling by consumers.

/// Base exception for all sticker pack repository errors.
abstract class StickerPackRepositoryException implements Exception {
  /// Creates a new sticker pack repository exception.
  const StickerPackRepositoryException([this.message]);

  /// The error message.
  final String? message;

  @override
  String toString() {
    if (message != null) {
      return '$runtimeType: $message';
    }
    return runtimeType.toString();
  }
}

/// Exception thrown when loading sticker packs fails.
class LoadStickerPacksFailedException extends StickerPackRepositoryException {
  /// Creates a new load sticker packs failed exception.
  const LoadStickerPacksFailedException([super.message]);
}
