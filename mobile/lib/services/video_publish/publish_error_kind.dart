// ABOUTME: Stable, localizable classification of video-publish failures.
// ABOUTME: State/persistence carry the kind; the UI maps it to context.l10n.

/// Stable categories of video-publish failure.
///
/// A [PublishError] carries one of these instead of an English string, so the
/// UI can localize it via `PublishErrorKindL10n` and a persisted failure can be
/// re-localized in the reader's current locale on interrupted-draft resume.
///
/// The set mirrors the substring branches that previously lived in
/// `VideoPublishService._getUserFriendlyErrorMessage`, plus the direct
/// not-signed-in / no-retry / interrupted / generic cases.
enum PublishErrorKind {
  /// User is not authenticated (also `unauthorized` / 401).
  notSignedIn,

  /// No background upload available to retry.
  noRetry,

  /// No network connectivity (socket / DNS / host-lookup failures).
  noInternet,

  /// Server reachable-by-DNS but the connection was refused/reset/closed.
  serverUnreachable,

  /// The upload exceeded its time budget.
  timeout,

  /// The resumable upload session expired and must be restarted.
  uploadSessionExpired,

  /// TLS / certificate / handshake failure.
  tls,

  /// Media server returned 404 / not found. Carries `serverName`.
  serverNotFound,

  /// Payload too large (413).
  fileTooLarge,

  /// Media server returned 500 / internal error. Carries `serverName`.
  serverInternalError,

  /// Media server temporarily down (502/503). Carries `serverName`.
  serverDown,

  /// Too many uploads in a short window (HTTP 429 / rate limited).
  rateLimited,

  /// Upload forbidden (403).
  forbidden,

  /// A device/app permission was denied (distinct from server [forbidden]).
  permissionDenied,

  /// Local video file missing / path not found.
  fileNotFound,

  /// Not enough device storage.
  lowStorage,

  /// The device ran out of memory during upload (distinct from [lowStorage]
  /// disk space).
  outOfMemory,

  /// Video uploaded but the thumbnail could not be prepared.
  thumbnailFailed,

  /// Media uploaded but the Nostr event could not be published.
  nostrPublishFailed,

  /// Media uploaded but the relays answered that the selected sound is not
  /// cleared for reuse, so the post was withheld. Distinct from
  /// [nostrPublishFailed]: the network did its job, and retrying returns the
  /// same answer until the user picks a different sound. A consent check that
  /// could not run at all stays [nostrPublishFailed] — that one is retryable.
  audioReuseNotPermitted,

  /// A previous upload was interrupted (surfaced on resume).
  interrupted,

  /// The draft belongs to a different account than the one signed in now —
  /// the user switched accounts while the upload was in flight. Publishing
  /// would post the video under the wrong identity.
  accountChanged,

  /// Unclassified failure — generic "try again" copy.
  generic,
}
