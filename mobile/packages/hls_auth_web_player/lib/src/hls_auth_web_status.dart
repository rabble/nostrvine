/// Playback status surfaced by the web player. The app layer maps these to
/// the existing `VideoPlaybackStatusCubit` / `PlaybackStatus` values.
enum HlsAuthWebPlaybackStatus {
  /// Controller was created but playback has not started.
  idle,

  /// Fetching or preparing the source.
  loading,

  /// Playback is ready. Media is either playing or paused.
  ready,

  /// The origin returned 401 / 403 and the viewer must verify to continue.
  requiresAuth,

  /// A non-auth failure occurred. The feed should skip or retry.
  failure,
}
