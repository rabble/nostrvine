// ABOUTME: Tracks video download bandwidth across playback sessions
// ABOUTME: Uses rolling average to recommend 720p vs 480p quality for HLS streams

import 'dart:collection';
import 'dart:developer' as developer;

import 'package:shared_preferences/shared_preferences.dart';

/// Quality recommendation based on measured bandwidth
enum VideoQuality {
  /// 720p - good connections (>2 Mbps effective)
  high,

  /// 480p - slow connections (<2 Mbps effective)
  low,
}

/// Tracks video download performance to recommend optimal quality.
///
/// Since videos are only 6 seconds, HLS adaptive bitrate doesn't have
/// time to adjust within a single video. Instead, we track performance
/// across videos and pick the right quality for the NEXT video.
///
/// Metrics tracked:
/// - Time to first frame (buffering latency)
/// - Estimated bandwidth based on video size and load time
class BandwidthTrackerService {
  BandwidthTrackerService._();

  static final BandwidthTrackerService _instance = BandwidthTrackerService._();
  static BandwidthTrackerService get instance => _instance;

  /// Rolling window of recent bandwidth samples (Mbps)
  final Queue<double> _bandwidthSamples = Queue();

  /// Maximum samples to keep
  static const int _maxSamples = 10;

  /// Threshold for switching to low quality (Mbps)
  /// 720p video at ~2-3 Mbps needs at least 2 Mbps to stream smoothly
  static const double _lowQualityThreshold = 2.0;

  /// Persisted quality preference key
  static const String _qualityPrefKey = 'video_quality_preference';

  /// User override (null = auto, otherwise forced quality)
  VideoQuality? _userOverride;

  /// Whether service is initialized
  bool _initialized = false;

  /// Initialize the service - loads persisted preferences
  Future<void> initialize() async {
    if (_initialized) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedQuality = prefs.getString(_qualityPrefKey);

      if (savedQuality == 'high') {
        _userOverride = VideoQuality.high;
      } else if (savedQuality == 'low') {
        _userOverride = VideoQuality.low;
      } else {
        _userOverride = null; // Auto mode
      }

      _initialized = true;
      _log('Initialized with quality preference: ${_userOverride ?? "auto"}');
    } catch (e) {
      _log('Failed to load quality preference: $e');
      _initialized = true;
    }
  }

  /// Record a bandwidth sample from video playback
  ///
  /// [videoSizeBytes] - Size of video file in bytes
  /// [loadTimeMs] - Time to load/buffer the video in milliseconds
  void recordSample({required int videoSizeBytes, required int loadTimeMs}) {
    if (loadTimeMs <= 0 || videoSizeBytes <= 0) return;

    // Calculate bandwidth in Mbps
    // bytes / ms = KB/s, convert to Mbps
    final bytesPerMs = videoSizeBytes / loadTimeMs;
    final mbps = (bytesPerMs * 1000 * 8) / (1024 * 1024);

    _bandwidthSamples.addLast(mbps);
    while (_bandwidthSamples.length > _maxSamples) {
      _bandwidthSamples.removeFirst();
    }

    _log(
      'Recorded bandwidth sample: ${mbps.toStringAsFixed(2)} Mbps '
      '(${_bandwidthSamples.length} samples)',
    );
  }

  /// Record time-to-first-frame as a proxy for connection quality
  ///
  /// [ttffMs] - Time from play request to first frame displayed
  void recordTimeToFirstFrame(int ttffMs) {
    // Estimate bandwidth from TTFF
    // Assume ~500KB needed for first frame, adjust based on TTFF
    // This is a rough heuristic but helps when we don't have file sizes
    if (ttffMs <= 0) return;

    // Fast TTFF (<500ms) = good connection (~4+ Mbps)
    // Medium TTFF (500-1500ms) = decent connection (~2-4 Mbps)
    // Slow TTFF (>1500ms) = slow connection (<2 Mbps)
    double estimatedMbps;
    if (ttffMs < 500) {
      estimatedMbps = 4.0;
    } else if (ttffMs < 1500) {
      estimatedMbps = 2.5;
    } else if (ttffMs < 3000) {
      estimatedMbps = 1.5;
    } else {
      estimatedMbps = 0.8;
    }

    _bandwidthSamples.addLast(estimatedMbps);
    while (_bandwidthSamples.length > _maxSamples) {
      _bandwidthSamples.removeFirst();
    }

    _log(
      'Recorded TTFF sample: ${ttffMs}ms -> ~${estimatedMbps.toStringAsFixed(1)} Mbps estimate',
    );
  }

  /// Get current average bandwidth estimate (Mbps)
  double get averageBandwidth {
    if (_bandwidthSamples.isEmpty) return 3.0; // Assume decent connection
    return _bandwidthSamples.reduce((a, b) => a + b) / _bandwidthSamples.length;
  }

  /// Get recommended quality based on measured bandwidth
  VideoQuality get recommendedQuality {
    // User override takes precedence
    if (_userOverride != null) {
      return _userOverride!;
    }

    // Auto mode - use measured bandwidth
    final avg = averageBandwidth;
    if (avg < _lowQualityThreshold) {
      return VideoQuality.low;
    }
    return VideoQuality.high;
  }

  /// Check if we should use 720p quality
  bool get shouldUseHighQuality => recommendedQuality == VideoQuality.high;

  /// Set user quality override
  ///
  /// [quality] - Forced quality, or null for auto mode
  Future<void> setQualityOverride(VideoQuality? quality) async {
    _userOverride = quality;

    try {
      final prefs = await SharedPreferences.getInstance();
      if (quality == null) {
        await prefs.remove(_qualityPrefKey);
        _log('Set quality preference: auto');
      } else {
        await prefs.setString(_qualityPrefKey, quality.name);
        _log('Set quality preference: ${quality.name}');
      }
    } catch (e) {
      _log('Failed to save quality preference: $e');
    }
  }

  /// Get current user override (null = auto mode)
  VideoQuality? get qualityOverride => _userOverride;

  /// Clear all samples (useful for testing or reset)
  void clearSamples() {
    _bandwidthSamples.clear();
    _log('Cleared bandwidth samples');
  }

  void _log(String message) {
    developer.log('[BandwidthTracker] $message');
  }
}

/// Singleton instance for easy access
final bandwidthTracker = BandwidthTrackerService.instance;
