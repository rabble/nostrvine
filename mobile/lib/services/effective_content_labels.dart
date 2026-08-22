import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/moderation_label_service.dart';

/// Content-warning labels separated by who applied them.
typedef EffectiveContentLabelSources = ({
  List<String> creator,
  List<String> trusted,
});

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
  final sources = resolveEffectiveContentLabelSources(
    video,
    moderationLabelService: moderationLabelService,
  );
  return {...sources.creator, ...sources.trusted}.toList();
}

/// Resolves labels without losing whether the creator or a trusted labeler
/// applied them.
EffectiveContentLabelSources resolveEffectiveContentLabelSources(
  VideoEvent video, {
  ModerationLabelService? moderationLabelService,
}) {
  final creator = <String>[];
  final trusted = <String>[];

  void addLabel(List<String> target, String? value) {
    final normalized = normalizeModerationLabelValue(value);
    if (normalized == null || target.contains(normalized)) {
      return;
    }
    target.add(normalized);
  }

  for (final label in video.contentWarningLabels) {
    addLabel(creator, label);
  }

  if (moderationLabelService != null) {
    final addressableId = video.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      for (final label
          in moderationLabelService.getContentWarningsByAddressableId(
            addressableId,
          )) {
        addLabel(trusted, label.labelValue);
      }
    }

    for (final label in moderationLabelService.getContentWarnings(video.id)) {
      addLabel(trusted, label.labelValue);
    }

    final sha256 = video.sha256;
    if (sha256 != null && sha256.isNotEmpty) {
      for (final label in moderationLabelService.getContentWarningsByHash(
        sha256,
      )) {
        addLabel(trusted, label.labelValue);
      }
    }

    for (final label in moderationLabelService.getLabelsForPubkey(
      video.pubkey,
    )) {
      addLabel(trusted, label.labelValue);
    }
  }

  for (final hashtag in video.hashtags) {
    final normalized = hashtag.trim().toLowerCase();
    if (normalized == 'nsfw' || normalized == 'adult') {
      addLabel(creator, 'nudity');
    }
  }

  return (creator: creator, trusted: trusted);
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

  return ContentLabel.fromValue(value)?.value ?? normalized;
}
