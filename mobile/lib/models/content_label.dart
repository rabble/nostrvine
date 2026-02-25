// ABOUTME: Enum for NIP-32 content warning labels used in video self-labeling
// ABOUTME: Maps to content-warning namespace values for Nostr label events

/// Content warning labels for NIP-32 self-labeling.
///
/// Used when creators mark their videos or accounts as containing
/// sensitive content. Maps to `['l', value, 'content-warning']` tags.
///
/// Multiple labels can be applied to a single video or account.
enum ContentLabel {
  /// Contains nudity (non-sexual).
  nudity('nudity', 'Nudity'),

  /// Contains sexual content (suggestive but not explicit).
  sexual('sexual', 'Sexual Content'),

  /// Contains explicit pornographic content.
  porn('porn', 'Pornography'),

  /// Contains graphic or violent media (gore, injury, death).
  graphicMedia('graphic-media', 'Graphic Media'),

  /// Contains depictions of violence.
  violence('violence', 'Violence'),

  /// Contains content related to self-harm or suicide.
  selfHarm('self-harm', 'Self-Harm/Suicide'),

  /// Contains drug use or drug-related content.
  drugs('drugs', 'Drug Use'),

  /// Contains alcohol consumption.
  alcohol('alcohol', 'Alcohol'),

  /// Contains tobacco or smoking.
  tobacco('tobacco', 'Tobacco/Smoking'),

  /// Contains gambling content.
  gambling('gambling', 'Gambling'),

  /// Contains strong language or profanity.
  profanity('profanity', 'Profanity'),

  /// Contains hate speech or intolerant content.
  hate('hate', 'Hate Speech'),

  /// Contains harassment or bullying.
  harassment('harassment', 'Harassment'),

  /// Contains flashing lights (photosensitivity/seizure risk).
  flashingLights('flashing-lights', 'Flashing Lights'),

  /// Content is AI-generated or AI-assisted.
  aiGenerated('ai-generated', 'AI-Generated'),

  /// Contains spoilers for other media.
  spoiler('spoiler', 'Spoiler'),

  /// Contains misleading or unverified information.
  misleading('misleading', 'Misleading'),

  /// Contains other sensitive content not covered above.
  other('content-warning', 'Sensitive Content');

  const ContentLabel(this.value, this.displayName);

  /// The NIP-32 label value used in Nostr tags.
  final String value;

  /// Human-readable display name for UI.
  final String displayName;

  /// Parse a [ContentLabel] from its NIP-32 [value] string.
  ///
  /// Returns `null` if [value] does not match any known label.
  static ContentLabel? fromValue(String? value) {
    if (value == null || value.isEmpty) return null;
    for (final label in ContentLabel.values) {
      if (label.value == value) return label;
    }
    return null;
  }

  /// Parse multiple [ContentLabel]s from a comma-separated string.
  ///
  /// Returns an empty set if [csv] is null or empty.
  /// Unrecognized values are silently skipped.
  static Set<ContentLabel> fromCsv(String? csv) {
    if (csv == null || csv.isEmpty) return {};
    return csv
        .split(',')
        .map((v) => fromValue(v.trim()))
        .whereType<ContentLabel>()
        .toSet();
  }

  /// Serialize a set of [ContentLabel]s to a comma-separated string.
  ///
  /// Returns `null` if the set is empty.
  static String? toCsv(Set<ContentLabel> labels) {
    if (labels.isEmpty) return null;
    return labels.map((l) => l.value).join(',');
  }
}
