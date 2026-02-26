// ABOUTME: Creates a VideoEventFilter for NSFW content filtering.
// ABOUTME: Bridges app-level ContentFilterService to repository-level filter.

import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [VideoContentFilter] that filters NSFW content based on
/// per-category preferences from [contentFilterService].
///
/// Returns `true` (filter out) if any content label on the video maps to
/// [ContentFilterPreference.hide] in the user's preferences.
///
/// By default, adult categories (nudity, sexual, porn) are set to [hide],
/// so NSFW content is filtered unless the user explicitly changes preferences.
///
/// This allows the [VideosRepository] to filter NSFW content without
/// depending directly on app-level services.
VideoContentFilter createNsfwFilter(ContentFilterService contentFilterService) {
  return (VideoEvent video) {
    final labels = _getContentLabels(video);
    if (labels.isEmpty) return false;

    final preference = contentFilterService.getPreferenceForLabels(labels);
    return preference == ContentFilterPreference.hide;
  };
}

/// Extracts content label values from a [VideoEvent].
///
/// Uses the already-parsed [VideoEvent.contentWarningLabels] (from NIP-36
/// content-warning tags and NIP-32 label tags) plus NSFW/adult hashtags
/// mapped to the 'nudity' category.
List<String> _getContentLabels(VideoEvent video) {
  final labels = <String>[...video.contentWarningLabels];

  // If content-warning labels exist but none are recognized categories,
  // treat as nudity (conservative default)
  if (labels.isNotEmpty &&
      labels.every((l) => ContentLabel.fromValue(l) == null)) {
    labels.add('nudity');
  }

  // Check NSFW/adult hashtags — map to nudity category
  for (final hashtag in video.hashtags) {
    final lowerHashtag = hashtag.toLowerCase();
    if (lowerHashtag == 'nsfw' || lowerHashtag == 'adult') {
      if (!labels.contains('nudity')) {
        labels.add('nudity');
      }
    }
  }

  return labels;
}
