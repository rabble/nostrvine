// ABOUTME: Creates a VideoEventFilter for NSFW content filtering.
// ABOUTME: Bridges app-level ContentFilterService to repository-level filter.

import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/content_filter_service.dart';
import 'package:openvine/services/effective_content_labels.dart';
import 'package:openvine/services/moderation_label_service.dart';
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
VideoContentFilter createNsfwFilter(
  ContentFilterService contentFilterService, {
  ModerationLabelService? moderationLabelService,
}) {
  return (VideoEvent video) {
    // Check self-applied content-warning labels (NIP-32/NIP-36)
    final labels = _getContentLabels(
      video,
      moderationLabelService: moderationLabelService,
    );
    if (labels.isNotEmpty) {
      final pref = contentFilterService.getPreferenceForLabels(labels);
      if (pref == ContentFilterPreference.hide) return true;
    }

    // Also check ML-generated moderation labels from Funnelcake.
    // These only trigger "hide" (never "warn") because ML classifiers
    // are noisy and would otherwise block autoplay on ordinary videos.
    final modLabels = video.moderationLabels;
    if (modLabels.isNotEmpty) {
      // TODO(moderation-labels): Coordinate with Funnelcake server on
      // namespacing conventions for non-safety labels (e.g. topic:*, lang:*,
      // quality:*) so they can bypass this hide gate. Today any new ML label
      // the mobile client has not been updated to recognize will force-hide
      // every video carrying it, regardless of user preference. The
      // conservative default is correct for safety labels but is too broad
      // if the server starts emitting discovery/taxonomy labels in the same
      // field. Track at: TBD (open an issue when this PR lands).
      //
      // Conservative default: if the server tagged a video with a label
      // we don't recognize, treat it as a hide signal. The alternative —
      // silently showing the video — defeats the safety system whenever
      // the relay introduces a new label the client has not been updated
      // to understand.
      final hasUnknown = modLabels.any(
        (l) => ContentLabel.fromValue(l) == null,
      );
      if (hasUnknown) return true;

      final pref = contentFilterService.getPreferenceForLabels(modLabels);
      if (pref == ContentFilterPreference.hide) return true;
    }

    return false;
  };
}

/// Creates a [VideoWarningLabelsResolver] that returns matched labels whose
/// preference is [ContentFilterPreference.warn].
VideoWarningLabelsResolver createNsfwWarnLabels(
  ContentFilterService contentFilterService, {
  ModerationLabelService? moderationLabelService,
}) {
  return (VideoEvent video) {
    final labels = _getContentLabels(
      video,
      moderationLabelService: moderationLabelService,
    );
    if (labels.isEmpty) return const <String>[];

    return labels.where((value) {
      final label = ContentLabel.fromValue(value);
      return label != null &&
          contentFilterService.getPreference(label) ==
              ContentFilterPreference.warn;
    }).toList();
  };
}

/// Extracts content label values from a [VideoEvent].
///
/// Uses creator self-labels, trusted kind-1985 labels, and hashtag fallbacks.
List<String> _getContentLabels(
  VideoEvent video, {
  ModerationLabelService? moderationLabelService,
}) {
  final labels = <String>[
    ...resolveEffectiveContentLabels(
      video,
      moderationLabelService: moderationLabelService,
    ),
  ];

  // If content-warning labels exist but none are recognized categories,
  // treat as nudity (conservative default)
  if (labels.isNotEmpty &&
      labels.every((l) => ContentLabel.fromValue(l) == null)) {
    labels.add('nudity');
  }

  return labels;
}
