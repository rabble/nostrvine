// ABOUTME: Persists the feed video-shape viewing preference.
// ABOUTME: Provides filtering logic for square-only vs square-and-portrait feeds.

import 'package:flutter/foundation.dart';
import 'package:models/models.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum FeedAspectRatioPreference { squareAndPortrait, squareOnly }

class FeedAspectRatioPreferenceService extends ChangeNotifier {
  FeedAspectRatioPreferenceService(this._prefs) {
    _preference = FeedAspectRatioPreference.values.firstWhere(
      (value) => value.name == _prefs.getString(_prefsKey),
      orElse: () => FeedAspectRatioPreference.squareAndPortrait,
    );
  }

  static const _prefsKey = 'feed_aspect_ratio_preference';

  final SharedPreferences _prefs;
  late FeedAspectRatioPreference _preference;

  /// Whether each video is non-square, recovered from real dimensions resolved
  /// at render time (a loaded thumbnail or decoded video frame). The backend
  /// often omits `dim` metadata, so this is the only signal the square-only
  /// filter has for those rows until the dimensions arrive (#3882).
  final Map<String, bool> _renderedNonSquareById = {};

  /// Bumps whenever a freshly rendered video is learned to be non-square while
  /// the square-only preference is active, so feed lists can re-filter in place
  /// without re-fetching.
  final ValueNotifier<int> renderedDimensionsRevision = ValueNotifier<int>(0);

  FeedAspectRatioPreference get preference => _preference;

  Future<void> setPreference(FeedAspectRatioPreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    await _prefs.setString(_prefsKey, preference.name);
    notifyListeners();
  }

  /// Records real dimensions recovered while rendering [videoId] so a row whose
  /// metadata omits dimensions can still be judged by [shouldHideVideo]. No-op
  /// when the size is unusable or already known.
  void recordRenderedDimensions(String videoId, int width, int height) {
    if (width <= 0 || height <= 0) return;
    final isNonSquare = width != height;
    if (_renderedNonSquareById[videoId] == isNonSquare) return;
    _renderedNonSquareById[videoId] = isNonSquare;
    if (isNonSquare && _preference == FeedAspectRatioPreference.squareOnly) {
      renderedDimensionsRevision.value++;
    }
  }

  bool shouldHideVideo(VideoEvent video) {
    if (_preference != FeedAspectRatioPreference.squareOnly) return false;
    final width = video.width;
    final height = video.height;
    if (width != null && height != null && width > 0 && height > 0) {
      return width != height;
    }
    return _renderedNonSquareById[video.id] ?? false;
  }

  @override
  void dispose() {
    renderedDimensionsRevision.dispose();
    super.dispose();
  }
}
