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

const _knownUntranslatedDebt = {
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
  'videoActionLikeLabel',
  'videoActionReplyLabel',
  'videoActionRepostLabel',
  'videoActionShareLabel',
  'videoActionAboutLabel',
  'videoOverlayOpenMetadataFromTitle',
  'videoOverlayOpenMetadataFromDescription',
  // Added by the notifications redesign / avatar lightbox a11y pass.
  // Translators will pick these up in a follow-up pass; until then the
  // generated l10n APIs fall back to the English source.
  'profileAvatarLightboxBarrierLabel',
  'profileAvatarLightboxCloseSemanticLabel',
  'notificationsViewProfileSemanticLabel',
  'notificationsViewProfilesSemanticLabel',
  'notificationRepliedToYourComment',
  'notificationAndConnector',
  'notificationOthersCount',
  // Added while localizing the settings taxonomy and related settings flows
  // for Amharic. Existing locales fall back to English until the next
  // full translation pass.
  'settingsGeneralTitle',
  'settingsContentSafetyTitle',
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
  'contentFiltersAdultContent',
  'contentFiltersViolenceGore',
  'contentFiltersSubstances',
  'contentFiltersOther',
  'contentFiltersAgeGateMessage',
  'contentFiltersShow',
  'contentFiltersWarn',
  'contentFiltersFilterOut',
  'safetySettingsWhatYouSee',
  'safetySettingsWhatYouPublish',
  'relaySettingsExternalRelay',
  'relaySettingsNotConnected',
  'relaySettingsDisconnectedAgo',
  'relaySettingsSubscriptionsSummary',
  'relaySettingsEventsSummary',
  'relaySettingsTimeAgo',
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
  'blossomValidServerUrl',
  'blossomSettingsSaved',
  'blossomSaveTooltip',
  'blossomAboutTitle',
  'blossomAboutDescription',
  'blossomUseCustomServer',
  'blossomCustomServerEnabledSubtitle',
  'blossomCustomServerDisabledSubtitle',
  'blossomCustomServerUrl',
  'blossomCustomServerHelper',
  'blossomPopularServers',
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
  'invitesNoneAvailable',
  'invitesShareWithPeople',
  'invitesUsedInvites',
  'invitesShareMessage',
  'invitesCopyInvite',
  'invitesCopied',
  'invitesShareInvite',
  'invitesShareSubject',
  'invitesClaimed',
  'invitesCouldNotLoad',
  'invitesRetry',
  // Added while sweeping obvious remaining hardcoded UI strings for Amharic.
  // Existing locales fall back to English until the next full translation pass.
  'commonBack',
  'commonClose',
  'categoryGalleryNoVideosInCategory',
  'categoriesNoCategoriesAvailable',
  'notificationsEmptyTitle',
  'notificationsEmptySubtitle',
  'appsPermissionsRevoke',
  'nostrAppPermissionTitle',
  'nostrAppPermissionDescription',
  'nostrAppPermissionOrigin',
  'nostrAppPermissionMethod',
  'nostrAppPermissionCapability',
  'nostrAppPermissionEventKind',
  'nostrAppPermissionAllow',
  'bugReportSendReport',
  'featureRequestSendRequest',
  'followingTitle',
  'followingTitleForName',
  'followersTitle',
  'followersTitleForName',
  'followersUpdateFollowFailed',
  'reportMessageTitle',
  'reportMessageWhyReporting',
  'reportMessageSelectReason',
  'newMessageTitle',
  'newMessageFindPeople',
  'newMessageNoContacts',
  'newMessageNoUsersFound',
  'hashtagSearchTitle',
  'hashtagSearchSubtitle',
  'userNotAvailableTitle',
  'userNotAvailableBody',
  // Added after an Explore Amharic QA pass caught hardcoded search and video
  // count suffixes. Existing locales fall back to English until the next pass.
  'exploreSearchHint',
  'categoryVideoCount',
  'listPersonCount',
  'listByAuthorPrefix',
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
  'videoMetadataAudioReuseTitle',
  'videoMetadataAudioReuseSubtitle',
  'videoEditorAudioCategoryFeatured',
  'videoEditorAudioCategoryMySounds',
  'videoEditorAudioFeaturedEmptyTitle',
  'videoEditorAudioFeaturedEmptySubtitle',
  'profileSetupImagesTypeGroup',
  'profileSetupExternalNip05InvalidFormat',
  'profileSetupExternalNip05DivineDomain',
  'contentWarningReportContentTooltip',
  'contentWarningBlockUserTooltip',
  'contentWarningBlockedTitle',
  'contentWarningBlockedPolicy',
  'contentWarningNoticeTitle',
  'contentWarningPotentiallyHarmfulTitle',
  'contentWarningView',
  'contentWarningReportAction',
  'discoverListsTitle',
  'discoverListsFailedToLoad',
  'discoverListsFailedToLoadWithError',
  'discoverListsLoading',
  'discoverListsEmptyTitle',
  'discoverListsEmptySubtitle',
  'discoverListsByAuthorPrefix',
  'curatedListEmptyTitle',
  'curatedListEmptySubtitle',
  'curatedListLoadingVideos',
  'curatedListFailedToLoad',
  'curatedListNoVideosAvailable',
  'curatedListVideoNotAvailable',
  'appsPermissionsTitle',
  'appsPermissionsEmptyTitle',
  'appsPermissionsEmptySubtitle',
  'supportSubjectRequiredLabel',
  'supportRequiredHelper',
  'bugReportSubjectHint',
  'bugReportDescriptionRequiredLabel',
  'bugReportDescriptionHint',
  'bugReportStepsLabel',
  'bugReportStepsHint',
  'bugReportExpectedBehaviorLabel',
  'bugReportExpectedBehaviorHint',
  'bugReportDiagnosticsNotice',
  'bugReportSuccessMessage',
  'bugReportSendFailed',
  'bugReportFailedWithError',
  'featureRequestSubjectHint',
  'featureRequestDescriptionRequiredLabel',
  'featureRequestDescriptionHint',
  'featureRequestUsefulnessLabel',
  'featureRequestUsefulnessHint',
  'featureRequestWhenLabel',
  'featureRequestWhenHint',
  'featureRequestSuccessMessage',
  'featureRequestSendFailed',
  'featureRequestFailedWithError',
  'followingEmptyTitle',
  'followersEmptyTitle',
  'hashtagSearchNoResults',
  'hashtagSearchFailed',
  // Added by people-lists feature (investigate/list-management).
  // Translators will pick these up in a follow-up pass; until then the
  // generated l10n APIs fall back to the English source.
  'peopleListsAddButton',
  'peopleListsAddButtonWithCount',
  'peopleListsAddPeopleError',
  'peopleListsAddPeopleRetry',
  'peopleListsAddPeopleSearchHint',
  'peopleListsAddPeopleSemanticLabel',
  'peopleListsAddPeopleTitle',
  'peopleListsAddPeopleTooltip',
  'peopleListsAddToList',
  'peopleListsAddToListName',
  'peopleListsAddToListSubtitle',
  'peopleListsBackToGridTooltip',
  'peopleListsCreateButton',
  'peopleListsCreateList',
  'peopleListsEmptySubtitle',
  'peopleListsEmptyTitle',
  'peopleListsErrorLoadingVideos',
  'peopleListsFailedToLoadVideos',
  'peopleListsInNLists',
  'peopleListsListDeletedSubtitle',
  'peopleListsListNameHint',
  'peopleListsListNameLabel',
  'peopleListsListNotFoundSubtitle',
  'peopleListsListNotFoundTitle',
  'peopleListsNewListTitle',
  'peopleListsNoPeopleSubtitle',
  'peopleListsNoPeopleTitle',
  'peopleListsNoPeopleToAdd',
  'peopleListsNoVideosAvailable',
  'peopleListsNoVideosSubtitle',
  'peopleListsNoVideosTitle',
  'peopleListsProfileLongPressHint',
  'peopleListsRemove',
  'peopleListsRemoveConfirmBody',
  'peopleListsRemoveConfirmTitle',
  'peopleListsRemovedFromList',
  'peopleListsRouteTitle',
  'peopleListsSheetTitle',
  'peopleListsUndo',
  'peopleListsVideoNotAvailable',
  'peopleListsViewProfileHint',
  // Added by the #3362 relay-scheme security gate. English, Spanish, and
  // Amharic are translated; other locales fall back to English until the
  // next pass.
  'relaySettingsInsecureUrl',
  'keyImportInsecureBunkerRelay',
  // Added by the badges dashboard in #3825. Translations are tracked in
  // #3864; until that lands, non-English locales fall back to English.
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
  // Added by the home-feed playback-settings popover (auto-advance / mute /
  // captions toggles). Translators will pick these up in a follow-up pass;
  // until then non-English locales fall back to the English source.
  'videoSettingsMenuOpen',
  'videoSettingsMenuClose',
  'videoSettingsCaptionsEnable',
  'videoSettingsCaptionsDisable',
  // Added by the Report action button on the video overlay (renamed from
  // Repost → Revine). English ships; other locales fall back until a pass.
  'videoActionReportLabel',
  'videoActionReport',
  // Added by the Edit action button on the fullscreen video overlay
  // (replaces the per-video Compilation slot when viewing your own video).
  // English ships; translators will pick these up in a follow-up pass.
  'videoActionEditLabel',
  'videoActionEdit',
  // Added by the Apple-compliance pass on the Report bottom sheet — each
  // reason now has a one-line subtitle clarifying scope. English ships;
  // translators will pick these up in a follow-up pass.
  'reportReasonSpamSubtitle',
  'reportReasonHarassmentSubtitle',
  'reportReasonViolenceSubtitle',
  'reportReasonSexualContentSubtitle',
  'reportReasonCopyrightSubtitle',
  'reportReasonFalseInfoSubtitle',
  'reportReasonCsamSubtitle',
  'reportReasonAiGeneratedSubtitle',
  'reportReasonOtherSubtitle',
  // Split child-safety report reasons (#3489). reportReasonCsam changed
  // meaning from "Child Safety Violation" to "Child Sexual Abuse"; stale
  // translations removed. New keys added for the two new categories.
  'reportReasonCsam',
  'reportReasonChildSafety',
  'reportReasonChildSafetySubtitle',
  'reportReasonUnderageUser',
  'reportReasonUnderageUserSubtitle',
  // Added by the in-sheet Report confirmation state ("Learn more at
  // divine.video/safety" link). Falls back to English in non-English
  // locales until translated.
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
