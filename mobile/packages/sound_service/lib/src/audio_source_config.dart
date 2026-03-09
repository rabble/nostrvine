// ABOUTME: Library-agnostic audio source description.
// ABOUTME: Wraps URI, asset flag, and optional clip boundaries so consumers
// ABOUTME: never depend on just_audio types directly.

/// Describes an audio source without exposing any player-library types.
///
/// Use [AudioSourceConfig.network] for remote URLs, [AudioSourceConfig.asset]
/// for bundled Flutter assets, and [AudioSourceConfig.file] for local files.
/// Optional [start] and [end] boundaries restrict playback to a sub-range.
class AudioSourceConfig {
  /// Creates an [AudioSourceConfig] from a network URL.
  const AudioSourceConfig.network(
    this.uri, {
    this.start,
    this.end,
  }) : isAsset = false,
       isFile = false;

  /// Creates an [AudioSourceConfig] from a Flutter asset path.
  const AudioSourceConfig.asset(
    this.uri, {
    this.start,
    this.end,
  }) : isAsset = true,
       isFile = false;

  /// Creates an [AudioSourceConfig] from a local file path.
  const AudioSourceConfig.file(
    this.uri, {
    this.start,
    this.end,
  }) : isAsset = false,
       isFile = true;

  /// The URI, asset path, or file path of the audio.
  final String uri;

  /// Whether [uri] refers to a Flutter asset.
  final bool isAsset;

  /// Whether [uri] refers to a local file.
  final bool isFile;

  /// Optional start boundary for clipped playback.
  final Duration? start;

  /// Optional end boundary for clipped playback.
  final Duration? end;

  /// Whether this config describes a clipped sub-range.
  bool get isClipped => start != null || end != null;
}
