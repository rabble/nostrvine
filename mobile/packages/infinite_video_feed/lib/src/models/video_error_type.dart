/// Classifies a video playback failure into a displayable error category.
enum VideoErrorType {
  /// 401 Unauthorized — age-gated content.
  ageRestricted,

  /// 403 Forbidden — moderation-restricted content.
  forbidden,

  /// 404 Not Found — content is unavailable.
  notFound,

  /// Any other playback failure.
  generic,
}
