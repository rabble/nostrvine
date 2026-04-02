import 'dart:io';

import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// A single video clip within the multi-clip timeline.
///
/// [uri] is a file path, network URL, or any URI the native player can
/// resolve. [start] and [end] define the subrange of the source to play.
/// When [end] is `null`, the clip plays to the end of the source file.
///
/// For Flutter assets and in-memory bytes, use the async helpers
/// [VideoClip.asset] and [VideoClip.memory] which copy data to a temporary
/// file first.
class VideoClip {
  /// Creates a video clip from a file path or URI.
  const VideoClip({
    required this.uri,
    this.start = Duration.zero,
    this.end,
  });

  /// Creates a [VideoClip] from a local file path.
  const VideoClip.file(
    String path, {
    this.start = Duration.zero,
    this.end,
  }) : uri = path;

  /// Creates a [VideoClip] from a network URL.
  const VideoClip.network(
    String url, {
    this.start = Duration.zero,
    this.end,
  }) : uri = url;

  /// Creates a [VideoClip] from a Flutter asset.
  ///
  /// The asset is extracted into a temporary file because native players
  /// cannot read from the Flutter asset bundle directly.
  static Future<VideoClip> asset(
    String assetPath, {
    Duration start = Duration.zero,
    Duration? end,
    AssetBundle? bundle,
  }) async {
    final (data, dir) = await (
      (bundle ?? rootBundle).load(assetPath),
      getTemporaryDirectory(),
    ).wait;
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/divine_player_assets/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return VideoClip(uri: file.path, start: start, end: end);
  }

  /// Creates a [VideoClip] from in-memory bytes.
  ///
  /// The bytes are written to a temporary file because native players
  /// cannot play from memory directly.
  static Future<VideoClip> memory(
    Uint8List bytes, {
    required String fileName,
    Duration start = Duration.zero,
    Duration? end,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/divine_player_memory/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return VideoClip(uri: file.path, start: start, end: end);
  }

  /// File path, network URL, or platform URI of the video source.
  final String uri;

  /// Start position within the source video.
  final Duration start;

  /// End position within the source video.
  ///
  /// When `null`, the clip plays to the end of the source.
  final Duration? end;

  /// Serializes this clip for platform channel transport.
  Map<String, dynamic> toMap() {
    return {
      'uri': uri,
      'startMs': start.inMilliseconds,
      'endMs': end?.inMilliseconds,
    };
  }
}
