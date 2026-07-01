import 'package:models/models.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/moderation_label_service.dart';

/// Where an effective content-warning label came from.
///
/// Ordered by authority: a [creator] self-label or a [trustedLabeler] label is
/// authoritative; a [community] label is a viewer suggestion that crossed the
/// client-side display threshold and has not been confirmed by a moderator.
enum ContentLabelProvenance {
  /// The video's creator self-labelled (or a hashtag they set implies it).
  creator,

  /// A trusted kind-1985 labeler (Divine moderation / a followed labeler).
  trustedLabeler,

  /// Enough distinct Divine-identity viewers suggested it (#4771).
  community,
}

/// An effective content-warning label together with its [provenance].
typedef EffectiveContentLabel = ({
  String value,
  ContentLabelProvenance provenance,
});

/// Builds the effective moderation label set for a [VideoEvent].
///
/// Sources are merged in this order (first writer of a normalized value wins,
/// so a more authoritative source keeps its provenance):
/// - creator self-labels already present on the video
/// - trusted kind-1985 labels (addressable id, event id, content hash, pubkey)
/// - community-suggested labels that crossed the display threshold (#4771)
/// - `#nsfw` / `#adult` hashtag fallback
List<String> resolveEffectiveContentLabels(
  VideoEvent video, {
  ModerationLabelService? moderationLabelService,
  Set<String>? communityLabels,
}) => resolveEffectiveContentLabelsWithProvenance(
  video,
  moderationLabelService: moderationLabelService,
  communityLabels: communityLabels,
).map((label) => label.value).toList();

/// Like [resolveEffectiveContentLabels] but keeps each label's [provenance] so
/// the UI can distinguish authoritative labels from community suggestions.
List<EffectiveContentLabel> resolveEffectiveContentLabelsWithProvenance(
  VideoEvent video, {
  ModerationLabelService? moderationLabelService,
  Set<String>? communityLabels,
}) {
  final labels = <EffectiveContentLabel>[];
  final seen = <String>{};

  void addLabel(String? value, ContentLabelProvenance provenance) {
    final normalized = normalizeModerationLabelValue(value);
    if (normalized == null || !seen.add(normalized)) {
      return;
    }
    labels.add((value: normalized, provenance: provenance));
  }

  for (final label in video.contentWarningLabels) {
    addLabel(label, ContentLabelProvenance.creator);
  }

  if (moderationLabelService != null) {
    final addressableId = video.addressableId;
    if (addressableId != null && addressableId.isNotEmpty) {
      for (final label
          in moderationLabelService.getContentWarningsByAddressableId(
            addressableId,
          )) {
        addLabel(label.labelValue, ContentLabelProvenance.trustedLabeler);
      }
    }

    for (final label in moderationLabelService.getContentWarnings(video.id)) {
      addLabel(label.labelValue, ContentLabelProvenance.trustedLabeler);
    }

    final sha256 = video.sha256;
    if (sha256 != null && sha256.isNotEmpty) {
      for (final label in moderationLabelService.getContentWarningsByHash(
        sha256,
      )) {
        addLabel(label.labelValue, ContentLabelProvenance.trustedLabeler);
      }
    }

    for (final label in moderationLabelService.getLabelsForPubkey(
      video.pubkey,
    )) {
      addLabel(label.labelValue, ContentLabelProvenance.trustedLabeler);
    }
  }

  if (communityLabels != null) {
    for (final value in communityLabels) {
      addLabel(value, ContentLabelProvenance.community);
    }
  }

  for (final hashtag in video.hashtags) {
    final normalized = hashtag.trim().toLowerCase();
    if (normalized == 'nsfw' || normalized == 'adult') {
      addLabel('nudity', ContentLabelProvenance.creator);
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

  return ContentLabel.fromValue(value)?.value ?? normalized;
}
