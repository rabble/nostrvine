// ABOUTME: Helper that maps a ContentLabel enum to its localized display name.
// ABOUTME: Falls back to the enum's non-localized displayName for unknown
// labels.

import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/content_label.dart';

/// Returns the localized display name for a [ContentLabel].
///
/// Callers in the UI layer pass `context.l10n` as [l10n].
String localizedContentLabelName(
  AppLocalizations l10n,
  ContentLabel label,
) => switch (label) {
  ContentLabel.nudity => l10n.contentLabelNudity,
  ContentLabel.sexual => l10n.contentLabelSexualContent,
  ContentLabel.porn => l10n.contentLabelPornography,
  ContentLabel.graphicMedia => l10n.contentLabelGraphicMedia,
  ContentLabel.violence => l10n.contentLabelViolence,
  ContentLabel.selfHarm => l10n.contentLabelSelfHarm,
  ContentLabel.drugs => l10n.contentLabelDrugUse,
  ContentLabel.alcohol => l10n.contentLabelAlcohol,
  ContentLabel.tobacco => l10n.contentLabelTobacco,
  ContentLabel.gambling => l10n.contentLabelGambling,
  ContentLabel.profanity => l10n.contentLabelProfanity,
  ContentLabel.hate => l10n.contentLabelHateSpeech,
  ContentLabel.harassment => l10n.contentLabelHarassment,
  ContentLabel.flashingLights => l10n.contentLabelFlashingLights,
  ContentLabel.aiGenerated => l10n.contentLabelAiGenerated,
  ContentLabel.deepfake => l10n.contentLabelDeepfake,
  ContentLabel.spam => l10n.contentLabelSpam,
  ContentLabel.scam => l10n.contentLabelScam,
  ContentLabel.spoiler => l10n.contentLabelSpoiler,
  ContentLabel.misleading => l10n.contentLabelMisleading,
  ContentLabel.other => l10n.contentLabelSensitiveContent,
};
