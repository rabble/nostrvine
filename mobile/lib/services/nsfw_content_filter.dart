// ABOUTME: Creates a VideoEventFilter for NSFW content filtering.
// ABOUTME: Bridges app-level AgeVerificationService to repository-level filter.

import 'package:models/models.dart';
import 'package:openvine/services/age_verification_service.dart';
import 'package:videos_repository/videos_repository.dart';

/// Creates a [VideoContentFilter] that filters NSFW content based on user
/// preferences from [ageVerificationService].
///
/// Returns `true` (filter out) if:
/// - User preference is [AdultContentPreference.neverShow] AND
/// - Video contains NSFW content (content-warning tag or #nsfw/#adult hashtag)
///
/// This allows the [VideosRepository] to filter NSFW content without
/// depending directly on app-level services.
VideoContentFilter createNsfwFilter(
  AgeVerificationService ageVerificationService,
) {
  return (VideoEvent video) {
    // Only filter if user has chosen to never show adult content
    if (!ageVerificationService.shouldHideAdultContent) {
      return false;
    }

    // Check if video is NSFW
    return _isNsfwContent(video);
  };
}

/// Checks if a [VideoEvent] contains NSFW/adult content.
///
/// Returns `true` if the video has:
/// - A `content-warning` tag
/// - A `#nsfw` or `#adult` hashtag
bool _isNsfwContent(VideoEvent video) {
  // Check for NSFW or adult hashtags
  for (final hashtag in video.hashtags) {
    final lowerHashtag = hashtag.toLowerCase();
    if (lowerHashtag == 'nsfw' || lowerHashtag == 'adult') {
      return true;
    }
  }

  // Check for content-warning in rawTags
  if (video.rawTags.containsKey('content-warning')) {
    return true;
  }

  return false;
}
