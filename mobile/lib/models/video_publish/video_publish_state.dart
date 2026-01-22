// ABOUTME: Enum representing the different states of the video publishing process
// ABOUTME: Tracks progress from initialization through upload to Nostr publication

/// States of the video publishing workflow.
///
/// Represents the sequential stages of publishing a video to the platform.
enum VideoPublishState {
  /// Initial state before publishing starts.
  idle,

  /// Initializing the publish process and validating data.
  initialize,

  /// Preparing video for upload (encoding, compressing, generating thumbnails).
  preparing,

  /// Actively uploading video to storage.
  uploading,

  /// Retrying a failed upload attempt.
  retryUpload,

  /// Publishing video metadata to Nostr network.
  publishToNostr,

  /// Video was successfully published.
  completed,

  /// An error occurred during the publishing process.
  error,
}
