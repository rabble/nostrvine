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
  // Added by #3837 (Blossom URL scheme validation under strict ATS).
  // English fallback ships until translators pick this up.
  'blossomServerUrlMustUseHttps',
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
  'categoryGallerySortOptionsLabel',
  'categoryGallerySortHot',
  'categoryGallerySortNew',
  'categoryGallerySortClassic',
  'categoryGallerySortForYou',
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
  // Added with signup credential validation. Translated for es/fr/de/it/pt/
  // nl/sv/pl/ro/bg/id/tr; ja/ko/ar/am still fall back to English pending a
  // native-speaker translation pass.
  'authConfirmPasswordLabel',
  'authEmailRequired',
  'authEmailInvalid',
  'authPasswordRequired',
  'authConfirmPasswordRequired',
  'authPasswordsDoNotMatch',
  'authConfirmNewPasswordLabel',
  // Added by the report-reason validation fix (#3475). The strings exist
  // in app_en.arb but were not added to app_am.arb / app_bg.arb at the
  // time. Generated locale files fall back to English until translators
  // pick them up.
  'reportOtherRequiresDetails',
  'reportDetailsRequired',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}
