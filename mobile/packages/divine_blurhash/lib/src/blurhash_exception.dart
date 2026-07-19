/// Thrown by `decodeBlurHash` when a hash string is malformed — too short,
/// contains a non-base83 character, or its length does not match the
/// component count declared in its size flag.
class BlurHashDecodeException implements Exception {
  /// Creates a [BlurHashDecodeException] with a human-readable [message].
  const BlurHashDecodeException(this.message);

  /// Describes why the hash could not be decoded.
  final String message;

  @override
  String toString() => 'BlurHashDecodeException: $message';
}
