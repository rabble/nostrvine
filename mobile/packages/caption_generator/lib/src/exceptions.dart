// ABOUTME: Typed exceptions for caption generation failures.
// ABOUTME: Thrown by CaptionGenerator so callers can branch per failure mode.

/// Base type for all caption generation failures.
sealed class CaptionGenerationException implements Exception {
  const CaptionGenerationException(this.message, this._name);

  /// Human-readable description of the failure.
  final String message;

  /// Concrete type name for [toString]; runtimeType is not log-safe.
  final String _name;

  @override
  String toString() => '$_name: $message';
}

/// The audio file handed to the generator does not exist.
final class AudioFileNotFoundException extends CaptionGenerationException {
  /// Creates the exception for the missing [path].
  const AudioFileNotFoundException(String path)
    : super('Audio file not found: $path', 'AudioFileNotFoundException');
}

/// The audio file is not in a format the generator can read.
///
/// On Android the input must be a RIFF/WAVE file containing 16-bit integer or
/// 32-bit float PCM (what `pro_video_editor` audio extraction produces).
final class UnsupportedAudioFormatException extends CaptionGenerationException {
  /// Creates the exception with a [message] describing the offending format.
  const UnsupportedAudioFormatException(String message)
    : super(message, 'UnsupportedAudioFormatException');
}

/// Speech recognition is not authorized.
///
/// On Apple platforms the user denied (or the OS restricts) speech
/// recognition. On Android the platform recognizer reported insufficient
/// permissions — the `RECORD_AUDIO` grant it requires even for file input is
/// missing. Either way, prompt the user towards the system settings.
final class SpeechNotAuthorizedException extends CaptionGenerationException {
  /// Creates the exception.
  const SpeechNotAuthorizedException()
    : super(
        'Speech recognition is not authorized',
        'SpeechNotAuthorizedException',
      );
}

/// No speech recognizer is available for this device or locale.
///
/// On Apple platforms the locale may be unsupported or the recognizer
/// temporarily unavailable (e.g. offline without on-device assets). On
/// Android this covers devices below Android 14, devices without Google's
/// on-device recognition service, and missing language packs.
final class SpeechRecognizerUnavailableException
    extends CaptionGenerationException {
  /// Creates the exception with a [message] naming the unavailable
  /// device capability or locale.
  const SpeechRecognizerUnavailableException(String message)
    : super(message, 'SpeechRecognizerUnavailableException');
}

/// The platform recognizer failed for any other reason.
final class TranscriptionFailedException extends CaptionGenerationException {
  /// Creates the exception with a [message] and the underlying [cause].
  const TranscriptionFailedException(String message, {this.cause})
    : super(message, 'TranscriptionFailedException');

  /// The underlying platform error, when available.
  final Object? cause;

  @override
  String toString() {
    if (cause == null) return super.toString();
    return '$_name: $message (caused by: $cause)';
  }
}
