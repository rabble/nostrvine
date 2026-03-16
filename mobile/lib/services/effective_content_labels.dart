import 'package:models/models.dart';
import 'package:openvine/services/moderation_label_service.dart';

/// Builds the effective moderation label set for a [VideoEvent].
///
/// Sources are merged in this order:
/// - creator self-labels already present on the video
/// - trusted kind-1985 labels by addressable id (`a` target)
/// - trusted kind-1985 labels by event id (`e` target)
/// - trusted kind-1985 labels by content hash (`x` target)
/// - trusted kind-1985 account labels by pubkey (`p` target)
/// - `#nsfw` / `#adult` hashtag fallback
List<String> resolveEffectiveContentLabels(
  VideoEvent video, {
  ModerationLabelService? moderationLabelService,
}) {
  final labels = <String>[];

  void addLabel(String? value) {
    final normalized = normalizeModerationLabelValue(value);
    if (normalized == null || labels.contains(normalized)) {
      return;
    }
    labels.add(normalized);
  }

  for (final label in video.contentWarningLabels) {
    addLabel(label);
  }

  if (moderationLabelService != null) {
    final addressableId = video.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      for (final label
          in moderationLabelService.getContentWarningsByAddressableId(
            addressableId,
          )) {
        addLabel(label.labelValue);
      }
    }

    for (final label in moderationLabelService.getContentWarnings(video.id)) {
      addLabel(label.labelValue);
    }

    final sha256 = video.sha256;
    if (sha256 != null && sha256.isNotEmpty) {
      for (final label in moderationLabelService.getContentWarningsByHash(
        sha256,
      )) {
        addLabel(label.labelValue);
      }
    }

    for (final label in moderationLabelService.getLabelsForPubkey(
      video.pubkey,
    )) {
      addLabel(label.labelValue);
    }
  }

  for (final hashtag in video.hashtags) {
    final normalized = hashtag.trim().toLowerCase();
    if (normalized == 'nsfw' || normalized == 'adult') {
      addLabel('nudity');
    }
  }

  return labels;
}

/// Normalizes a moderation label value while preserving unknown labels.
///
/// Unknown values are kept so downstream callers can decide whether to surface
/// a generic warning or ignore the label for preference resolution.
String? normalizeModerationLabelValue(String? value) {
  final normalized = value?.trim().toLowerCase();
  if (normalized == null || normalized.isEmpty) {
    return null;
  }

  switch (normalized) {
    case 'nsfw':
      return 'nudity';
    case 'explicit':
      return 'porn';
    case 'pornography':
      return 'porn';
    case 'graphic-violence':
    case 'gore':
      return 'graphic-media';
    default:
      return normalized;
  }
}
