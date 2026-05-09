// ABOUTME: Tests that ARB locale files stay in sync with the English template.
// ABOUTME: Prevents generated l10n APIs from drifting from translated files.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('ARB consistency', () {
    test('all locales define the same message keys as app_en.arb', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      final templateKeys = _messageKeys(template);

      for (final file in arbFiles) {
        final arb = _readArb(file);
        final keys = _messageKeys(arb);

        expect(
          keys.difference(templateKeys),
          isEmpty,
          reason: '${file.path} has keys missing from app_en.arb',
        );
        expect(
          templateKeys.difference(keys).difference(_knownUntranslatedDebt),
          isEmpty,
          reason: '${file.path} is missing keys from app_en.arb',
        );
      }
    });
  });
}

// Keys grouped by feature. Each entry is awaiting either real translations
// (small-batch gaps in a few locales) or a fresh full-pass translation
// across all 16 non-English locales. Tracking issue: #3814.
const _knownUntranslatedDebt = {
  // Profile Misc — saved-videos empty/error, "Maybe later", Secure /
  // Complete CTAs, library / loops / likes / messages labels, user
  // fallback noun.
  'profileNoSavedVideosTitle',
  'profileSavedOwnEmpty',
  'profileErrorLoadingSaved',
  'profileMaybeLaterLabel',
  'profileSecurePrimaryButton',
  'profileCompletePrimaryButton',
  'profileLoopsLabel',
  'profileLikesLabel',
  'profileMyLibraryLabel',
  'profileMessageLabel',
  'profileUserFallback',
  // Video Action Labels — Like / Reply / Repost / Share / About row
  // under the video.
  'videoActionLikeLabel',
  'videoActionReplyLabel',
  'videoActionRepostLabel',
  'videoActionShareLabel',
  'videoActionAboutLabel',
  // General Settings — section headers + closed-captions / video-shape
  // options.
  'settingsGeneralTitle',
  'generalSettingsSectionIntegrations',
  'generalSettingsSectionViewing',
  'generalSettingsSectionCreating',
  'generalSettingsSectionApp',
  'generalSettingsClosedCaptions',
  'generalSettingsClosedCaptionsSubtitle',
  'generalSettingsVideoShape',
  'generalSettingsVideoShapeSquareOnly',
  'generalSettingsVideoShapeSquareAndPortrait',
  'generalSettingsVideoShapeSquareAndPortraitSubtitle',
  'generalSettingsVideoShapeSquareOnlySubtitle',
  // Relay Settings — external relay status, time-ago strings, summaries,
  // and the #3362 wss:// scheme gate.
  'relaySettingsExternalRelay',
  'relaySettingsNotConnected',
  'relaySettingsDisconnectedAgo',
  'relaySettingsSubscriptionsSummary',
  'relaySettingsEventsSummary',
  'relaySettingsTimeAgo',
  'relaySettingsInsecureUrl',
  'keyImportInsecureBunkerRelay',
  // Nostr Settings — Network / Account / Danger Zone sections of the
  // Nostr settings screen.
  'nostrSettingsIntro',
  'nostrSettingsSectionNetwork',
  'nostrSettingsSectionAccount',
  'nostrSettingsSectionDangerZone',
  'nostrSettingsRelays',
  'nostrSettingsRelaysSubtitle',
  'nostrSettingsRelayDiagnostics',
  'nostrSettingsRelayDiagnosticsSubtitle',
  'nostrSettingsMediaServers',
  'nostrSettingsMediaServersSubtitle',
  'nostrSettingsDeveloperOptions',
  'nostrSettingsDeveloperOptionsSubtitle',
  'nostrSettingsExperimentalFeaturesSubtitle',
  'nostrSettingsKeyManagement',
  'nostrSettingsKeyManagementSubtitle',
  'nostrSettingsRemoveKeys',
  'nostrSettingsRemoveKeysSubtitle',
  'nostrSettingsCouldNotRemoveKeys',
  'nostrSettingsFailedToRemoveKeys',
  'nostrSettingsDeleteAccount',
  'nostrSettingsDeleteAccountSubtitle',
  // Bluesky Bridge Settings — cross-post status messages.
  'blueskySignInRequired',
  'blueskyPublishVideos',
  'blueskyEnabledSubtitle',
  'blueskyDisabledSubtitle',
  'blueskyHandle',
  'blueskyStatus',
  'blueskyStatusReady',
  'blueskyStatusPending',
  'blueskyStatusFailed',
  'blueskyStatusDisabled',
  'blueskyStatusNotLinked',
  // Badges Dashboard — issuance / acceptance flows (#3825). Translations
  // tracked in #3864.
  'settingsBadgesTitle',
  'settingsBadgesSubtitle',
  'badgesTitle',
  'badgesIntroTitle',
  'badgesIntroBody',
  'badgesOpenApp',
  'badgesLoadError',
  'badgesUpdateError',
  'badgesAwardedSectionTitle',
  'badgesAwardedEmptyTitle',
  'badgesAwardedEmptySubtitle',
  'badgesStatusAccepted',
  'badgesStatusNotAccepted',
  'badgesActionRemove',
  'badgesActionAccept',
  'badgesActionReject',
  'badgesIssuedSectionTitle',
  'badgesIssuedEmptyTitle',
  'badgesIssuedEmptySubtitle',
  'badgesIssuedNoRecipients',
  'badgesRecipientAcceptedStatus',
  'badgesRecipientWaitingStatus',
  // Sounds Library — saved sounds, preview, availability, library state.
  'soundUntitled',
  'soundStopPreview',
  'soundPreviewSemanticLabel',
  'soundViewDetailsSemanticLabel',
  'soundsSavedToLibrary',
  'soundsAlreadySavedToLibrary',
  'soundsSavedLibraryTitle',
  'soundsSavedEmptyTitle',
  'soundsSavedEmptyDescription',
  'soundsAvailabilityPrivate',
  'soundsAvailabilityCommunity',
  'soundsRemoveSavedSound',
  'soundsRemovedFromLibrary',
  // Video Editor – Audio Picker — fresh feature; audio category tabs and
  // empty states.
  'videoMetadataAudioReuseTitle',
  'videoMetadataAudioReuseSubtitle',
  'videoEditorAudioCategoryFeatured',
  'videoEditorAudioCategoryMySounds',
  'videoEditorAudioFeaturedEmptyTitle',
  'videoEditorAudioFeaturedEmptySubtitle',
  // Video Settings Menu — auto-advance / mute / captions popover toggles.
  'videoSettingsMenuOpen',
  'videoSettingsMenuClose',
  'videoSettingsCaptionsEnable',
  'videoSettingsCaptionsDisable',
  // Video Action Report / Edit — Report (renamed from Repost → Revine)
  // and Edit row buttons on the fullscreen video overlay.
  'videoActionReportLabel',
  'videoActionReport',
  'videoActionEditLabel',
  'videoActionEdit',
  // Report Reason Subtitles + Learn More — Apple-compliance pass on the
  // Report bottom sheet (each reason has a one-line scope subtitle, plus
  // the divine.video/safety learn-more link).
  'reportReasonSpamSubtitle',
  'reportReasonHarassmentSubtitle',
  'reportReasonViolenceSubtitle',
  'reportReasonSexualContentSubtitle',
  'reportReasonCopyrightSubtitle',
  'reportReasonFalseInfoSubtitle',
  'reportReasonCsamSubtitle',
  'reportReasonAiGeneratedSubtitle',
  'reportReasonOtherSubtitle',
  'reportLearnMoreAt',
  // Added by the desktop save-to-Downloads log export flow. Other locales
  // fall back to English until the next translation pass.
  'supportLogsSavedTo',
  'supportRevealLogsAction',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}
