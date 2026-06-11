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

    test('Keycast remote signing copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      final source = template['keyManagementKeycastRemoteSigning'];

      for (final file in arbFiles) {
        final arb = _readArb(file);

        expect(
          arb['keyManagementKeycastRemoteSigning'],
          isNot(source),
          reason:
              '${file.path} must not fall back to English for Keycast remote signing copy',
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
  // Search video sort labels use the English fallback until the next
  // translation pass picks up the new API-backed sort options.
  'searchVideosSortOptionsLabel',
  'searchVideosSortTrending',
  'searchVideosSortLoops',
  'searchVideosSortEngagement',
  'searchVideosSortRecent',
  // Added by the notifications redesign / avatar lightbox a11y pass.
  // Translators will pick these up in a follow-up pass; until then the
  // generated l10n APIs fall back to the English source.
  'profileAvatarLightboxBarrierLabel',
  'profileAvatarLightboxCloseSemanticLabel',
  'notificationsBadgeUnread',
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
  'profileCollaboratorInvitePendingHeadline',
  'profileCollaboratorInvitePendingDetail',
  'profileCollaboratorInvitePendingDetailWithTitle',
  'profileCollaboratorInviteRetryAction',
  'profileCollaboratorInviteRetryingAction',
  'profileCollaboratorInviteRetryUnavailable',
  'profileCollaboratorInviteRetryResult',
  'videoPublishCollaboratorInviteWarning',
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
  // Added by curated list overflow actions. Existing locales fall back to
  // English until the next translation pass.
  'curatedListActionsTooltip',
  'curatedListUnfollowAction',
  'curatedListUnfollowedSnack',
  'curatedListUnfollowFailed',
  // Added by owned curated-list delete actions. Existing locales fall back to
  // English until the next translation pass.
  'curatedListDeleteConfirmTitle',
  'curatedListDeleteConfirmBody',
  'curatedListDeletedSnack',
  'curatedListDeleteFailed',
  // Added by owned people-list delete actions. Existing locales fall back to
  // English until the next translation pass.
  'peopleListsActionsTooltip',
  'listDeleteAction',
  'peopleListsDeleteConfirmTitle',
  'peopleListsDeleteConfirmBody',
  'peopleListsDeleteFailed',
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
  // Added by the moderation-report confirmation state. English ships;
  // other locales fall back until the next translation pass.
  'reportModerationDmDelayed',
  'reportContactModeration',
  // Added by the desktop save-to-Downloads log export flow. Other locales
  // fall back to English until the next translation pass.
  'supportLogsSavedTo',
  'supportRevealLogsAction',
  // Added by the DM-screen l10n pass — migrates the conversation
  // long-press actions, the message-bubble long-press menu, the compose
  // field hint, and the conversation-row Semantics labels from
  // hardcoded English. Translators will pick these up in a follow-up
  // pass; until then non-English locales fall back to the English
  // source.
  'dmMessageInputHint',
  'dmMessageBubbleSentHint',
  'dmMessageBubbleReceivedHint',
  'dmMessageBubbleLongPressHint',
  'dmMessageActionCopyText',
  'dmMessageActionCopyVideoUrl',
  'dmMessageActionDeleteForEveryone',
  'dmMessageActionReport',
  'inboxConversationActionsSheetLabel',
  'inboxConversationTileLabel',
  'inboxConversationTileLongPressHint',
  // Added by the metadata-sheet redesign for the tappable hashtag chip
  // screen-reader hint. Existing locales fall back to English until the
  // next full translation pass.
  'metadataHashtagChipTapHint',
  // Added by the inline comment composer bar on the fullscreen video
  // feed (Explore / Search / Profile playback). Translators will pick
  // these up in a follow-up pass; until then non-English locales fall
  // back to the English source.
  'videoOverlayCommentBarHint',
  'videoOverlayCommentBarSemanticLabel',
  'videoOverlayCommentBarSendLabel',
  'videoOverlayCommentPostedSnackbar',
  'videoOverlayCommentPostFailedSnackbar',
  // Added by the end-of-feed loading pill on the fullscreen video feed.
  // Translators will pick this up in a follow-up pass; until then non-English
  // locales fall back to the English source.
  'feedLoadingMore',
  // Added while iterating on the under-16 review flow and adjacent editor /
  // profile / accessibility strings. Existing locales fall back to English
  // until the next translation pass.
  'bugReportAttachImages',
  'bugReportImagesCount',
  'bugReportRemoveImage',
  'bugReportUploadFailed',
  'minorAccountReviewParentConsentHonestyBody',
  'minorAccountReviewParentConsentHonestyTitle',
  'minorAccountReviewParentConsentLegalBody',
  'minorAccountReviewUnder13HonestyBody',
  'minorAccountReviewUnder13HonestyTitle',
  'minorAccountReviewUnder13LegalBody',
  'minorAccountReviewUnder13LegalTitle',
  'notificationSettingsMarkAllAsReadFailed',
  'profileChipTapHint',
  'profileSetupBannerClearButton',
  'profileSetupBannerSectionTitle',
  'profileSetupBannerUploadButton',
  'profileSetupBannerUploadSuccess',
  'userPickerRemoveSelectionSemantics',
  'videoCollaboratorPendingDecoration',
  'videoCollaboratorPendingSemanticLabel',
  'videoCollaboratorWithPendingSuffix',
  'videoEditorClipAudioTitle',
  'videoEditorExtractAudioFailed',
  'videoEditorExtractAudioFromClipSemanticLabel',
  'videoEditorExtractAudioLabel',
  'videoEditorExtractAudioNoLocalFile',
  'videoMetadataEditCoverCloseSemanticLabel',
  'videoMetadataEditCoverConfirmSemanticLabel',
  'videoMetadataEditCoverFailedSnackbar',
  'videoMetadataEditCoverStripSemanticLabel',
  'videoMetadataEditCoverSuccessAnnouncement',
  'videoMetadataEditCoverTitle',
  'videoMetadataTagsPickerAddTag',
  'videoMetadataTagsPickerEmptyHint',
  'videoMetadataTagsPickerNoResults',
  'videoMetadataTagsPickerSearchHint',
  'videoPlayerTapHint',
  // Added by the welcome-screen min-age + under-16 inline link redesign.
  // Translators will pick these up in a follow-up pass; until then non-English
  // locales fall back to the English source.
  'authMinAgeNotice',
  'authUnder16Prefix',
  'authUnder16ChoicesCta',
  // Added by the #3628 Apps / Integrations directory l10n pass. English ships;
  // translators will pick these up in a follow-up pass, until then non-English
  // locales fall back to the English source.
  'appsDetailDefaultTitle',
  'appsDetailNotFoundTitle',
  'appsDetailNotFoundSubtitle',
  'appsDetailHowItWorksTitle',
  'appsDetailHowItWorksBody',
  'appsDetailAboutTitle',
  'appsDetailPrimaryOriginTitle',
  'appsDetailApprovedOriginsTitle',
  'appsDetailCapabilitiesTitle',
  'appsDetailAskBeforeTitle',
  'appsDetailOpenButton',
  'appsDetailNoneDeclared',
  'appsDirectoryTitle',
  'appsDirectoryIntroTitle',
  'appsDirectoryIntroBody',
  'appsDirectoryErrorTitle',
  'appsDirectoryErrorSubtitle',
  'appsDirectoryEmptyTitle',
  'appsDirectoryEmptySubtitle',
  'appsDirectoryRefresh',
  'appsDirectoryUnsupportedTitle',
  'appsDirectoryUnsupportedSubtitle',
  'appsSandboxUnavailableTitle',
  'appsSandboxUnavailableBody',
  'appsSandboxLoadingTitle',
  'appsSandboxLoadingSubtitle',
  'appsSandboxBlockedTitle',
  'appsSandboxBlockedSubtitle',
  // #3628 Area K (below-UI-layer safe subset)
  'shareCopiedPostLink',
  'shareCopiedEventJson',
  'shareCopiedEventId',
  // Added by the #3628 hardcoded-string l10n sweep (per-area). English
  // ships; non-English locales fall back to the English source until the
  // next translation pass.
  // Auth
  'authHeroTaglineAuthentic',
  'authHeroTaglineHuman',
  'keyImportFailedToImport',
  'keyImportInvalidBunkerUrl',
  'keyImportInvalidFormat',
  'keyImportInvalidNsecFormat',
  'keyImportKeyFieldLabel',
  'keyImportKeyRequired',
  'keyImportPasswordRequired',
  'keyImportSecurityWarningBody',
  'keyImportSecurityWarningTitle',
  'keyImportSubtitle',
  'keyImportTitle',
  // Comments
  'commentAuthorYouIndicator',
  'commentOptionsDeleteSemanticLabel',
  'commentOptionsEditSemanticLabel',
  'commentOptionsFlagContentLabel',
  'commentOptionsFlagContentSemanticLabel',
  'commentOptionsFlagReasonPrompt',
  'commentOptionsFlagSubmit',
  'commentOptionsTitle',
  'commentsEmptyClassicVineMessage',
  'commentsEmptyClassicVineTitle',
  'commentsInputEditingLabel',
  'commentsInputSemanticHint',
  'commentsInputSemanticHintEdit',
  'commentsInputSemanticHintReply',
  'commentsInputSemanticLabel',
  'commentsInputSemanticLabelEdit',
  'commentsInputSemanticLabelReply',
  // Discovery
  'classicVinersViewProfileSemanticLabel',
  'classicsEmptyDescription',
  'classicsEmptyTitle',
  'classicsErrorTitle',
  'classicsUnavailableDescription',
  'classicsUnavailableSettingsHint',
  'classicsUnavailableTitle',
  'hashtagFeedEmptySubtitle',
  'hashtagFeedEmptyTitle',
  'hashtagFeedLoadingSubtitle',
  'hashtagFeedLoadingTitle',
  'hashtagInputHint',
  'newVideosTabEmptySubtitle',
  'newVideosTabEmptyTitle',
  'popularVideosContextTitle',
  'popularVideosEmptySubtitle',
  'popularVideosEmptyTitle',
  'popularVideosErrorTitle',
  'popularVideosFeedSourceLabel',
  'trendingHashtagsLoading',
  'trendingHashtagsViewVideosTagged',
  'videoGridAuthorSemanticLabel',
  'videoGridDescriptionSemanticLabel',
  // For-You
  'forYouAlgorithmChoiceBody',
  'forYouAlgorithmChoiceChronological',
  'forYouAlgorithmChoiceClosing',
  'forYouAlgorithmChoiceCustomFeeds',
  'forYouAlgorithmChoicePersonalizedFeed',
  'forYouAlgorithmChoiceTitle',
  'forYouAlgorithmChoiceTrending',
  'forYouAlgorithmCommentsDescription',
  'forYouAlgorithmHowItWorksBody',
  'forYouAlgorithmHowItWorksTitle',
  'forYouAlgorithmInteractionsIntro',
  'forYouAlgorithmNewToDivineBody1',
  'forYouAlgorithmNewToDivineBody2',
  'forYouAlgorithmNewToDivineTitle',
  'forYouAlgorithmOpenSourceBody',
  'forYouAlgorithmOpenSourceTitle',
  'forYouAlgorithmReactionsDescription',
  'forYouAlgorithmReactionsTitle',
  'forYouAlgorithmRepostsDescription',
  'forYouAlgorithmSubtitle',
  'forYouAlgorithmTitle',
  'forYouAlgorithmViewsDescription',
  'forYouEmptyDescription',
  'forYouEmptyTitle',
  'forYouErrorTitle',
  'forYouUnavailableDescription',
  'forYouUnavailableTitle',
  // Inbox
  'inboxConversationOptionsLabel',
  'inboxConversationViewProfileButton',
  'inboxMessageRequestsEmpty',
  'inboxMessageRequestsSemanticLabel',
  'inboxMessageRequestsTitle',
  'inboxMessagesTab',
  'inboxRequestTileLabel',
  'inboxRequestTileSubtitle',
  'inboxRequestsMarkAllRead',
  'inboxRequestsRemoveAll',
  'messageRequestDeclineAndRemoveButton',
  'messageRequestFollowersCount',
  'messageRequestVideosCount',
  'messageRequestMessageCount',
  'messageRequestViewMessagesButton',
  'messageRequestViewProfileButton',
  'messageRequestWantsToMessageYou',
  // Misc
  'deleteAccountConfirmationHint',
  'deleteAccountContentDeletionFailed',
  'deleteAccountDeleteAllContentButton',
  'deleteAccountFinalConfirmationBody',
  'deleteAccountFinalConfirmationTitle',
  'deleteAccountKeyDeletionWarning',
  'deleteAccountPreparingDeletion',
  'deleteAccountProgressEvents',
  'deleteAccountRemoveKeysBody',
  'deleteAccountRemoveKeysConfirm',
  'deleteAccountRemoveKeysTitle',
  'deleteAccountServerDeletionFailed',
  'deleteAccountSuccess',
  'exportProgressStageApplyingTextOverlay',
  'exportProgressStageComplete',
  'exportProgressStageConcatenating',
  'exportProgressStageError',
  'exportProgressStageGeneratingThumbnail',
  'exportProgressStageMixingAudio',
  'findPeopleAnonymousUser',
  'findPeopleNoContacts',
  'geoBlockedCityLabel',
  'geoBlockedCountryLabel',
  'geoBlockedDefaultReason',
  'geoBlockedLegalNotice',
  'geoBlockedRegionLabel',
  'geoBlockedTitle',
  'likedVideosEmpty',
  'likedVideosInvalidRoute',
  'likedVideosTitle',
  'ogVinerBadgeSemanticLabel',
  'uploadFailureSheetRetryingSnackbar',
  'uploadFailureSheetSaveToDraftsButton',
  'uploadFailureSheetSavedToDraftsSnackbar',
  'uploadFailureSheetTitle',
  'uploadFailureSheetTryAgainButton',
  'videoEditorAudioImportAudio',
  'videoEditorAudioImportFailed',
  'videoIconPlaceholderLabel',
  'videoInspiredByAttributionSemanticLabel',
  // ProofMode
  'proofmodeBadgeAiScanPending',
  'proofmodeBadgeHumanMade',
  'proofmodeBadgeNotDivineHosted',
  'proofmodeBadgeOriginal',
  'proofmodeBadgePossiblyAiGenerated',
  'proofmodeBadgeUnverified',
  'proofmodeConfirmedByModerator',
  'proofmodeExternalContentTitle',
  'proofmodeHostedOnLabel',
  'proofmodeLikelyHumanCreated',
  'proofmodeNoProofDataAttached',
  'proofmodeNotDivineHostedDisclaimer',
  'proofmodePossiblyAiGenerated',
  'proofmodePublishedByLabel',
  // Search
  'searchFilterPillSemanticLabel',
  'searchNoResultsFound',
  'searchTagChipViewVideosTaggedLabel',
  'searchVideosEmpty',
  // Sounds/Video-feed
  'audioAttributionRowSemanticLabel',
  'metadataSoundsOriginalSoundSemantics',
  'metadataSoundsSharedSoundSemantics',
  'soundDetailLoadError',
  'soundDetailNotFoundMessage',
  'soundDetailNotFoundTitle',
  'videoFeedDescriptionSemanticLabel',
  'videoFeedLoopCountLabel',
  'videoFeedLoopCountSemanticLabel',
  // #3628 sweep — inventory-parse-failure + swap-miss tail
  'originalSoundUnavailableBody',
  'originalSoundByCreator',
  'globalUploadPendingCount',
  'ogVinerBadgeLabel',
  'shareVideoInListsCount',
  'unfollowConfirmButton',
  'videoClipSaveFailed',
  'videoClipSaveTo',
  'videoClipDelete',
  'inspiredByAttributionSemanticLabel',
  // Added by the current l10n/UI pass. English ships; other locales fall back until the next translation pass.
  'shareSheetClipTitleLabel',
  'shareSheetNameClipSubtitle',
  'shareSheetNameClipTitle',
  'shareSheetSaveClip',
  'shareSheetSavedClipToClips',
  'shareSheetUntitledClip',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}
