// ABOUTME: Persists developer video format selection to SharedPreferences
// ABOUTME: Used for A/B testing different server-side formats on real devices

import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// Video playback format selection for developer testing.
///
/// Each value maps to a divine-blossom URL endpoint. Use [hlsDefault] (or
/// null) for the production adaptive-bitrate path.
enum VideoPlaybackFormat {
  /// HLS with bandwidth tracker — production default
  hlsDefault,

  /// /{hash} — original upload (7–21 Mbps, blossom-compliant)
  raw,

  /// /{hash}/hls/master.m3u8 — adaptive HLS master playlist
  hlsMaster,

  /// /{hash}/hls/stream_720p.m3u8 — HLS 720p stream
  hls720p,

  /// /{hash}/hls/stream_480p.m3u8 — HLS 480p stream
  hls480p,

  /// /{hash}/720p — direct 720p .ts segment
  ts720p,

  /// /{hash}/480p — direct 480p .ts segment
  ts480p,

  /// /{hash}/720p.mp4 — MP4 720p (faststart, moov at front)
  mp4_720p,

  /// /{hash}/480p.mp4 — MP4 480p (faststart, moov at front)
  mp4_480p,
}

/// Persists and exposes the developer's video format selection.
class VideoFormatPreferenceService {
  VideoFormatPreferenceService._();

  static final VideoFormatPreferenceService _instance =
      VideoFormatPreferenceService._();
  static VideoFormatPreferenceService get instance => _instance;

  static const String _formatPrefKey = 'video_format_preference';

  VideoPlaybackFormat? _format;

  bool _initialized = false;

  /// Initialize the service — loads persisted format from SharedPreferences.
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString(_formatPrefKey);

      if (saved != null) {
        _format = VideoPlaybackFormat.values.firstWhere(
          (f) => f.name == saved,
          orElse: () => VideoPlaybackFormat.hlsDefault,
        );
      } else {
        _format = null; // Production default
      }

      _initialized = true;
      _log('Initialized with format: ${_format?.name ?? "production default"}');
    } catch (e) {
      _log('Failed to load format preference: $e');
      _initialized = true;
    }
  }

  /// Current format selection. Null means the production default (HLS with
  /// bandwidth tracker).
  VideoPlaybackFormat? get format => _format;

  /// Returns true when the selected format uses HLS delivery.
  bool get isHlsFormat {
    return _format == VideoPlaybackFormat.hlsDefault ||
        _format == VideoPlaybackFormat.hlsMaster ||
        _format == VideoPlaybackFormat.hls720p ||
        _format == VideoPlaybackFormat.hls480p;
  }

  /// Persist a format selection.
  ///
  /// Pass null to restore the production default.
  Future<void> setFormat(VideoPlaybackFormat? format) async {
    _format = format;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (format == null) {
        await prefs.remove(_formatPrefKey);
        _log('Set format preference: production default');
      } else {
        await prefs.setString(_formatPrefKey, format.name);
        _log('Set format preference: ${format.name}');
      }
    } catch (e) {
      _log('Failed to save format preference: $e');
    }
  }

  void _log(String message) {
    developer.log('[VideoFormatPreference] $message');
  }
}

/// Singleton instance for easy access
final VideoFormatPreferenceService videoFormatPreference =
    VideoFormatPreferenceService.instance;
