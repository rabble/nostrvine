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

  FeedAspectRatioPreference get preference => _preference;

  Future<void> setPreference(FeedAspectRatioPreference preference) async {
    if (_preference == preference) return;
    _preference = preference;
    await _prefs.setString(_prefsKey, preference.name);
    notifyListeners();
  }

  bool shouldHideVideo(VideoEvent video) {
    if (_preference != FeedAspectRatioPreference.squareOnly) return false;
    final width = video.width;
    final height = video.height;
    if (width == null || height == null || width <= 0 || height <= 0) {
      return false;
    }
    return width != height;
  }
}
