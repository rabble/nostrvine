// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Filipino Pilipino (`fil`).
class AppLocalizationsFil extends AppLocalizations {
  AppLocalizationsFil([String locale = 'fil']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Mga Setting';

  @override
  String get settingsSecureAccount => 'I-secure ang iyong account';

  @override
  String get settingsSessionExpired => 'Nag-expire na ang session';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Mag-sign in ulit para mabalik ang buong access';

  @override
  String get settingsCreatorAnalytics => 'Creator Analytics';

  @override
  String get settingsSupportCenter => 'Support Center';

  @override
  String get settingsNotifications => 'Mga Notification';

  @override
  String get settingsContentPreferences => 'Mga Content Preference';

  @override
  String get settingsModerationControls => 'Mga Moderation Control';

  @override
  String get settingsBlueskyPublishing => 'Bluesky Publishing';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Pamahalaan ang crossposting sa Bluesky';

  @override
  String get settingsNostrSettings => 'Mga Nostr Setting';

  @override
  String get settingsIntegratedApps => 'Mga Integrated App';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Mga inaprubahang third-party app na tumatakbo sa loob ng Divine';

  @override
  String get settingsExperimentalFeatures => 'Mga Experimental Feature';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Mga tweak na maaaring magka-glitch—subukan kung curious ka.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Mga Integration Permission';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Tingnan at bawiin ang mga naka-save na integration approval';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Naka-enable na ang developer mode';

  @override
  String get settingsDeveloperModeEnabled => 'Na-enable ang developer mode!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count pang tap para ma-enable ang developer mode';
  }

  @override
  String get settingsInvites => 'Mga Invite';

  @override
  String get settingsSwitchAccount => 'Magpalit ng account';

  @override
  String get settingsAddAnotherAccount => 'Magdagdag ng isa pang account';

  @override
  String get settingsUnsavedDraftsTitle => 'Mga Hindi Naka-save na Draft';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga draft',
      one: 'draft',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga draft',
      one: 'draft',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mga ito',
      one: 'draft na ito',
    );
    return 'Mayroon kang $count na hindi naka-save na $_temp0. Kapag nagpalit ka ng account, mananatili ang iyong $_temp1, pero baka gusto mong i-publish o tingnan muna ang $_temp2.';
  }

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSwitchAnyway => 'Magpalit pa rin';

  @override
  String get settingsAppVersionLabel => 'App version';

  @override
  String get settingsAppLanguage => 'Wika ng App';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (default ng device)';
  }

  @override
  String get settingsAppLanguageTitle => 'Wika ng App';

  @override
  String get settingsAppLanguageDescription =>
      'Piliin ang wika para sa interface ng app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Gamitin ang wika ng device';

  @override
  String get settingsGeneralTitle => 'General Settings';

  @override
  String get settingsContentSafetyTitle => 'Content at Safety';

  @override
  String get generalSettingsSectionIntegrations => 'MGA INTEGRATION';

  @override
  String get generalSettingsSectionViewing => 'PANONOOD';

  @override
  String get generalSettingsSectionCreating => 'PAGLIKHA';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get generalSettingsClosedCaptions => 'Closed Captions';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Ipakita ang captions kapag may captions ang video';

  @override
  String get generalSettingsVideoShape => 'Hugis ng Video';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Square videos lang';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait => 'Square at portrait';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Ipakita ang full mix ng Divine videos';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Panatilihin ang feeds sa classic na square format';

  @override
  String get contentPreferencesTitle => 'Mga Content Preference';

  @override
  String get contentPreferencesContentFilters => 'Mga Content Filter';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Pamahalaan ang mga content warning filter';

  @override
  String get contentPreferencesContentLanguage => 'Wika ng Content';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (default ng device)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag-an ang iyong mga video ng wika para mai-filter ng manonood ang content.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Gamitin ang wika ng device (default)';

  @override
  String get contentPreferencesAudioSharing =>
      'Gawing magagamit ng iba ang audio ko';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Kapag naka-enable, magagamit ng iba ang audio mula sa mga video mo';

  @override
  String get contentPreferencesAccountLabels => 'Mga Account Label';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'I-label mo ang sarili mong content';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Mga Account Content Label';

  @override
  String get contentPreferencesClearAll => 'I-clear lahat';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Piliin lahat ng tumutugma sa account mo';

  @override
  String get contentPreferencesDoneNoLabels => 'Tapos na (Walang Label)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Tapos na ($count napili)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio Input Device';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (recommended)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Awtomatikong pumipili ng pinakamagandang microphone';

  @override
  String get contentPreferencesSelectAudioInput => 'Pumili ng Audio Input';

  @override
  String get contentPreferencesUnknownMicrophone => 'Hindi Kilalang Microphone';

  @override
  String get contentFiltersAdultContent => 'ADULT CONTENT';

  @override
  String get contentFiltersViolenceGore => 'KARAHASAN AT GORE';

  @override
  String get contentFiltersSubstances => 'MGA SUBSTANSIYA';

  @override
  String get contentFiltersOther => 'IBA PA';

  @override
  String get contentFiltersAgeGateMessage =>
      'I-verify ang edad mo sa Safety & Privacy settings para i-unlock ang mga adult content filter';

  @override
  String get contentFiltersShow => 'Ipakita';

  @override
  String get contentFiltersWarn => 'Babala';

  @override
  String get contentFiltersFilterOut => 'I-filter Out';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Hindi available ang account na ito';

  @override
  String profileErrorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get profileInvalidId => 'Invalid ang profile ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Tingnan si $displayName sa Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return 'Si $displayName sa Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Hindi na-share ang profile: $error';
  }

  @override
  String get profileEditProfile => 'I-edit ang profile';

  @override
  String get profileCreatorAnalytics => 'Creator analytics';

  @override
  String get profileShareProfile => 'I-share ang profile';

  @override
  String get profileCopyPublicKey => 'Kopyahin ang public key (npub)';

  @override
  String get profileGetEmbedCode => 'Kunin ang embed code';

  @override
  String get profilePublicKeyCopied => 'Nakopya na sa clipboard ang public key';

  @override
  String get profileEmbedCodeCopied => 'Nakopya na sa clipboard ang embed code';

  @override
  String get profileRefreshTooltip => 'I-refresh';

  @override
  String get profileRefreshSemanticLabel => 'I-refresh ang profile';

  @override
  String get profileMoreTooltip => 'Higit pa';

  @override
  String get profileMoreSemanticLabel => 'Iba pang options';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Isara ang avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Isara ang avatar preview';

  @override
  String get profileFollowingLabel => 'Sinusundan';

  @override
  String get profileFollowLabel => 'Sundan';

  @override
  String get profileBlockedLabel => 'Naka-block';

  @override
  String get profileFollowersLabel => 'Mga Follower';

  @override
  String get profileFollowingStatLabel => 'Sinusundan';

  @override
  String get profileVideosLabel => 'Mga Video';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count user';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'I-block si $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Kapag nag-block ka ng user:';

  @override
  String get profileBlockBulletHidePosts =>
      'Hindi na lalabas ang mga post nila sa feed mo.';

  @override
  String get profileBlockBulletCantView =>
      'Hindi na nila makikita ang profile mo, hindi ka masusundan, at hindi makikita ang mga post mo.';

  @override
  String get profileBlockBulletNoNotify =>
      'Hindi sila aabisuhan tungkol sa pagbabagong ito.';

  @override
  String get profileBlockBulletYouCanView =>
      'Makikita mo pa rin ang profile nila.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'I-block si $displayName';
  }

  @override
  String get profileCancelButton => 'Cancel';

  @override
  String get profileLearnMore => 'Alamin pa';

  @override
  String profileUnblockTitle(String displayName) {
    return 'I-unblock si $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Kapag in-unblock mo ang user na ito:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Lalabas ang mga post nila sa feed mo.';

  @override
  String get profileUnblockBulletCanView =>
      'Makikita nila ang profile mo, masusundan ka nila, at makikita ang mga post mo.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Hindi sila aabisuhan tungkol sa pagbabagong ito.';

  @override
  String get profileLearnMoreAt => 'Alamin pa sa ';

  @override
  String get profileUnblockButton => 'I-unblock';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'I-unfollow si $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'I-block si $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'I-unblock si $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'I-report si $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Idagdag si $displayName sa isang list';
  }

  @override
  String get profileUserBlockedTitle => 'Na-block ang User';

  @override
  String get profileUserBlockedContent =>
      'Hindi mo na makikita ang content ng user na ito sa feed mo.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Maaari mo silang i-unblock kahit kailan mula sa profile nila o sa Settings > Safety.';

  @override
  String get profileCloseButton => 'Isara';

  @override
  String get profileNoCollabsTitle => 'Wala pang collab';

  @override
  String get profileCollabsOwnEmpty =>
      'Lalabas dito ang mga video na nag-collab ka.';

  @override
  String get profileCollabsOtherEmpty =>
      'Lalabas dito ang mga video na nag-collab sila.';

  @override
  String get profileErrorLoadingCollabs =>
      'May error sa pag-load ng mga collab video';

  @override
  String get profileNoSavedVideosTitle => 'Wala pang naka-save';

  @override
  String get profileSavedOwnEmpty =>
      'Mag-bookmark ng video mula sa share sheet at lalabas dito.';

  @override
  String get profileErrorLoadingSaved =>
      'May error sa pag-load ng saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'Wala pang komento';

  @override
  String get profileNoCommentsOtherTitle => 'Wala pang komento';

  @override
  String get profileCommentsOwnEmpty =>
      'Lalabas dito ang mga komento at reply mo.';

  @override
  String get profileCommentsOtherEmpty =>
      'Lalabas dito ang mga komento at reply nila.';

  @override
  String get profileErrorLoadingComments =>
      'May error sa pag-load ng mga komento';

  @override
  String get profileVideoRepliesSection => 'Mga Video Reply';

  @override
  String get profileCommentsSection => 'Mga Komento';

  @override
  String get profileEditLabel => 'I-edit';

  @override
  String get profileLibraryLabel => 'Library';

  @override
  String get profileNoLikedVideosTitle => 'Wala pang like';

  @override
  String get profileLikedOwnEmpty =>
      'Pag may nakita kang nakakaakit, i-tap ang puso. Lalabas dito ang mga like mo.';

  @override
  String get profileLikedOtherEmpty =>
      'Wala pa silang nagugustuhan. Hintayin mo lang.';

  @override
  String get profileErrorLoadingLiked =>
      'May error sa pag-load ng mga liked video';

  @override
  String get profileNoRepostsTitle => 'Wala pang repost';

  @override
  String get profileRepostsOwnEmpty =>
      'May nakita kang dapat ipasa? I-repost mo at lalabas ito dito.';

  @override
  String get profileRepostsOtherEmpty =>
      'Wala pa silang ipinasang content. Pag may inipasa, lalabas dito.';

  @override
  String get profileErrorLoadingReposts =>
      'May error sa pag-load ng mga reposted video';

  @override
  String get profileLoadingVideos => 'Naglo-load ang mga video...';

  @override
  String get profileNoVideosTitle => 'Wala pang video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Handa na ang stage mo. Magsimula nang mag-post at maglalagi rito ang mga video mo.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Naghihintay ang mundo. Sundan mo sila para hindi ka mahuli.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video thumbnail $number';
  }

  @override
  String get profileShowMore => 'Ipakita pa';

  @override
  String get profileShowLess => 'Ipakita nang mas kaunti';

  @override
  String get profileCompleteYourProfile => 'Kumpletuhin ang iyong profile';

  @override
  String get profileCompleteSubtitle =>
      'Idagdag ang iyong pangalan, bio, at larawan para makapagsimula';

  @override
  String get profileSetUpButton => 'I-set up';

  @override
  String get profileVerifyingEmail => 'Bineberipika ang email...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Tingnan ang $email para sa verification link';
  }

  @override
  String get profileWaitingForVerification =>
      'Naghihintay ng email verification';

  @override
  String get profileVerificationFailed => 'Nabigo ang Verification';

  @override
  String get profilePleaseTryAgain => 'Subukan ulit';

  @override
  String get profileSecureYourAccount => 'I-secure ang iyong account';

  @override
  String get profileSecureSubtitle =>
      'Magdagdag ng email at password para mabawi ang account mo sa kahit anong device';

  @override
  String get profileRetryButton => 'Subukan ulit';

  @override
  String get profileRegisterButton => 'Mag-register';

  @override
  String get profileSessionExpired => 'Nag-expire na ang session';

  @override
  String get profileSignInToRestore =>
      'Mag-sign in ulit para mabalik ang buong access';

  @override
  String get profileSignInButton => 'Mag-sign in';

  @override
  String get profileMaybeLaterLabel => 'Sa Susunod Na Lang';

  @override
  String get profileSecurePrimaryButton => 'Magdagdag ng Email at Password';

  @override
  String get profileCompletePrimaryButton => 'I-update ang Profile Mo';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Mga Like';

  @override
  String get profileMyLibraryLabel => 'Aking Library';

  @override
  String get profileMessageLabel => 'Message';

  @override
  String get profileUserFallback => 'user';

  @override
  String get profileDismissTooltip => 'Isara';

  @override
  String get profileLinkCopied => 'Nakopya na ang profile link';

  @override
  String get profileSetupEditProfileTitle => 'I-edit ang Profile';

  @override
  String get profileSetupBackLabel => 'Bumalik';

  @override
  String get profileSetupAboutNostr => 'Tungkol sa Nostr';

  @override
  String get profileSetupProfilePublished =>
      'Matagumpay na na-publish ang profile!';

  @override
  String get profileSetupCreateNewProfile => 'Gumawa ng bagong profile?';

  @override
  String get profileSetupNoExistingProfile =>
      'Wala kaming nakitang existing profile sa mga relay mo. Ang pag-publish ay gagawa ng bagong profile. Ituloy?';

  @override
  String get profileSetupPublishButton => 'I-publish';

  @override
  String get profileSetupUsernameTaken =>
      'Nakuha na ang username. Pumili ng iba.';

  @override
  String get profileSetupClaimFailed =>
      'Nabigong i-claim ang username. Subukan ulit.';

  @override
  String get profileSetupPublishFailed =>
      'Nabigong i-publish ang profile. Subukan ulit.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Hindi makonekta sa network. Tingnan ang koneksyon mo at subukan ulit.';

  @override
  String get profileSetupRetryLabel => 'Subukan ulit';

  @override
  String get profileSetupDisplayNameLabel => 'Display Name';

  @override
  String get profileSetupDisplayNameHint => 'Paano ka makikilala ng mga tao?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Anumang pangalan o label na gusto mo. Hindi kailangang unique.';

  @override
  String get profileSetupDisplayNameRequired => 'Maglagay ng display name';

  @override
  String get profileSetupBioLabel => 'Bio (Optional)';

  @override
  String get profileSetupBioHint => 'Sabihin sa iba ang tungkol sa iyo...';

  @override
  String get profileSetupPublicKeyLabel => 'Public key (npub)';

  @override
  String get profileSetupUsernameLabel => 'Username (Optional)';

  @override
  String get profileSetupUsernameHint => 'username';

  @override
  String get profileSetupUsernameHelper => 'Iyong unique na identity sa Divine';

  @override
  String get profileSetupProfileColorLabel => 'Kulay ng Profile (Optional)';

  @override
  String get profileSetupSaveButton => 'I-save';

  @override
  String get profileSetupSavingButton => 'Sine-save...';

  @override
  String get profileSetupImageUrlTitle => 'Magdagdag ng image URL';

  @override
  String get profileSetupPictureUploaded =>
      'Matagumpay na na-upload ang profile picture!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Nabigo ang pagpili ng larawan. I-paste na lang ang image URL sa baba.';

  @override
  String get profileSetupImagesTypeGroup => 'mga larawan';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Nabigo ang camera access: $error';
  }

  @override
  String get profileSetupGotItButton => 'Sige';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Nabigo ang upload. Subukan ulit mamaya.';

  @override
  String get profileSetupUploadNetworkError =>
      'Network error: Tingnan ang internet connection mo at subukan ulit.';

  @override
  String get profileSetupUploadAuthError =>
      'Authentication error: Subukang mag-log out at mag-log in ulit.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Masyadong malaki ang file: Pumili ng mas maliit na larawan (max 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Nabigo ang upload. Pansamantalang hindi available ang servers namin. Subukan ulit mamaya.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Hindi pa available sa web ang pag-upload ng profile picture. Gamitin ang iOS o Android app, o i-paste ang image URL.';

  @override
  String get profileSetupBannerSectionTitle => 'Banner';

  @override
  String get profileSetupBannerUploadButton => 'Mag-upload ng larawan';

  @override
  String get profileSetupBannerClearButton => 'I-clear ang banner';

  @override
  String get profileSetupBannerUploadSuccess => 'Na-update ang banner';

  @override
  String get profileSetupUsernameChecking => 'Tinitingnan ang availability...';

  @override
  String get profileSetupUsernameAvailable => 'Available ang username!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Nakuha na ang username';

  @override
  String get profileSetupUsernameReserved => 'Naka-reserve ang username';

  @override
  String get profileSetupContactSupport => 'Makipag-ugnayan sa support';

  @override
  String get profileSetupCheckAgain => 'Tingnan ulit';

  @override
  String get profileSetupUsernameBurned =>
      'Hindi na available ang username na ito';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Mga letra, numero, at gitling lang ang pwede';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Dapat 3-63 character ang username';

  @override
  String get profileSetupUsernameNetworkError =>
      'Hindi natingnan ang availability. Subukan ulit.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Invalid ang format ng username';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Nabigong tingnan ang availability';

  @override
  String get profileSetupUsernameReservedTitle => 'Naka-reserve ang username';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Ang pangalang $username ay naka-reserve. Sabihin mo sa amin kung bakit dapat sa iyo ito.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'hal. Brand name ko, stage name, atbp.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Nakipag-ugnayan ka na ba sa support? I-tap ang \"Tingnan ulit\" para makita kung naibigay na sa iyo.';

  @override
  String get profileSetupSupportRequestSent =>
      'Naipadala na ang support request! Babalikan ka namin agad.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Hindi nabuksan ang email. Ipadala sa: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Ipadala ang request';

  @override
  String get profileSetupPickColorTitle => 'Pumili ng kulay';

  @override
  String get profileSetupSelectButton => 'Piliin';

  @override
  String get profileSetupUseOwnNip05 =>
      'Gamitin ang sarili mong NIP-05 address';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Address';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Invalid NIP-05 format (hal., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Gamitin ang username field sa itaas para sa divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 address';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Gamitin ang divine.video username mo, o ituro ang handle mo sa isang NIP-05 address sa domain na kontrolado mo.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'I-save ang NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'Naisave ang NIP-05';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Hindi na-save ang NIP-05. Pakisubukan ulit.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Gamitin ang sarili mong NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'Ini-uugnay ng NIP-05 ang pangalang gaya ng you@yourdomain.com sa iyong Nostr identity. Kailangan mong kontrolado ang domain at naka-host ang verification file sa tamang path. Kapag mali ito, hindi ka mahahanap ng mga tao at mawawala ang verified handle mo. Magpatuloy lang kung na-set up mo na ito.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Magpatuloy';

  @override
  String get profileSetupNip05ConfirmCancel => 'Kanselahin';

  @override
  String get profileSetupProfilePicturePreview => 'Preview ng profile picture';

  @override
  String get nostrInfoIntroBuiltOn => 'Ang DiVine ay binuo sa Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' isang censorship-resistant na open protocol na nagbibigay-daan sa mga tao na makipag-usap online nang hindi umaasa sa iisang kompanya o platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Kapag nag-sign up ka sa Divine, makakakuha ka ng bagong Nostr identity.';

  @override
  String get nostrInfoOwnership =>
      'Ang Nostr ay nagbibigay sa iyo ng kontrol sa iyong content, identity, at social graph, na maaari mong gamitin sa iba\'t ibang app. Ang resulta ay mas maraming pagpipilian, mas kaunting lock-in, at mas malusog at matibay na social internet.';

  @override
  String get nostrInfoLingo => 'Mga termino sa Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Ang public Nostr address mo. Ligtas itong i-share at nagbibigay-daan sa iba na hanapin, sundan, o mag-message sa iyo sa iba\'t ibang Nostr app.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Ang private key mo at patunay ng pagmamay-ari. Nagbibigay ito ng buong kontrol sa Nostr identity mo, kaya ';

  @override
  String get nostrInfoNsecWarning => 'panatilihin itong sekreto!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr username:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Isang nababasang pangalan (tulad ng @name.divine.video) na naka-link sa npub mo. Ginagawa nitong mas madaling makilala at ma-verify ang Nostr identity mo, parang email address.';

  @override
  String get nostrInfoLearnMoreAt => 'Alamin pa sa ';

  @override
  String get nostrInfoGotIt => 'Sige!';

  @override
  String get profileTabRefreshTooltip => 'I-refresh';

  @override
  String get videoGridRefreshLabel => 'Naghahanap ng iba pang video';

  @override
  String get videoGridOptionsTitle => 'Mga Video Option';

  @override
  String get videoGridEditVideo => 'I-edit ang Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'I-update ang title, description, at hashtag';

  @override
  String get videoGridDeleteVideo => 'Burahin ang Video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Tanggalin ang video na ito sa Divine. Maaari pa rin itong lumabas sa ibang Nostr client.';

  @override
  String get videoGridDeleteConfirmTitle => 'Burahin ang Video';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Permanente nitong bubura ang video na ito sa Divine. Maaari pa rin itong lumabas sa third-party Nostr client na gumagamit ng ibang relay.';

  @override
  String get videoGridDeleteConfirmNote =>
      'Magpapadala ito ng deletion request sa mga relay. Tandaan: May mga relay na maaaring may cached copy pa.';

  @override
  String get videoGridDeleteCancel => 'Cancel';

  @override
  String get videoGridDeleteConfirm => 'Burahin';

  @override
  String get videoGridDeletingContent => 'Binubura ang content...';

  @override
  String get videoGridDeleteSuccess =>
      'Matagumpay na naipadala ang delete request';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Nabigong burahin ang content: $error';
  }

  @override
  String get exploreTabClassics => 'Klasiko';

  @override
  String get exploreTabNew => 'Bago';

  @override
  String get exploreTabPopular => 'Sikat';

  @override
  String get exploreTabCategories => 'Mga Category';

  @override
  String get exploreTabForYou => 'Para sa Iyo';

  @override
  String get exploreTabLists => 'Mga List';

  @override
  String get exploreTabIntegratedApps => 'Mga Integrated App';

  @override
  String get exploreNoVideosAvailable => 'Walang available na video';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get exploreDiscoverLists => 'Tuklasin ang mga List';

  @override
  String get exploreAboutLists => 'Tungkol sa mga List';

  @override
  String get exploreAboutListsDescription =>
      'Tinutulungan ka ng mga list na ayusin at i-curate ang Divine content sa dalawang paraan:';

  @override
  String get explorePeopleLists => 'Mga People List';

  @override
  String get explorePeopleListsDescription =>
      'Sundan ang mga grupo ng creator at tingnan ang kanilang mga pinakabagong video';

  @override
  String get exploreVideoLists => 'Mga Video List';

  @override
  String get exploreVideoListsDescription =>
      'Gumawa ng playlist ng iyong mga paboritong video para mapanood mamaya';

  @override
  String get exploreMyLists => 'Mga List Ko';

  @override
  String get exploreSubscribedLists => 'Mga Subscribed List';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'May error sa pag-load ng mga list: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bagong video',
      one: '1 bagong video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'video',
      one: 'video',
    );
    return 'I-load ang $count bagong $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Naglo-load ang video...';

  @override
  String get videoPlayerPlayVideo => 'I-play ang video';

  @override
  String get videoPlayerMute => 'I-mute ang video';

  @override
  String get videoPlayerUnmute => 'I-unmute ang video';

  @override
  String get videoPlayerEditVideo => 'I-edit ang video';

  @override
  String get videoPlayerEditVideoTooltip => 'I-edit ang video';

  @override
  String get videoPlayerTapHint =>
      'I-tap para i-play o i-pause. Mag-double tap para i-like.';

  @override
  String get videoSettingsMenuOpen => 'Buksan ang playback settings';

  @override
  String get videoSettingsMenuClose => 'Isara ang playback settings';

  @override
  String get videoSettingsCaptionsEnable => 'I-enable ang captions';

  @override
  String get videoSettingsCaptionsDisable => 'I-disable ang captions';

  @override
  String get contentWarningLabel => 'Content Warning';

  @override
  String get contentWarningNudity => 'Kahubaran';

  @override
  String get contentWarningSexualContent => 'Sexual Content';

  @override
  String get contentWarningPornography => 'Pornograpiya';

  @override
  String get contentWarningGraphicMedia => 'Graphic Media';

  @override
  String get contentWarningViolence => 'Karahasan';

  @override
  String get contentWarningSelfHarm => 'Self-Harm';

  @override
  String get contentWarningDrugUse => 'Paggamit ng Droga';

  @override
  String get contentWarningAlcohol => 'Alak';

  @override
  String get contentWarningTobacco => 'Tabako';

  @override
  String get contentWarningGambling => 'Sugal';

  @override
  String get contentWarningProfanity => 'Mura';

  @override
  String get contentWarningFlashingLights => 'Mga Kumikislap na Ilaw';

  @override
  String get contentWarningAiGenerated => 'AI-Generated';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Sensitibong Content';

  @override
  String get contentWarningDescNudity =>
      'Naglalaman ng kahubaran o bahagyang kahubaran';

  @override
  String get contentWarningDescSexual => 'Naglalaman ng sexual content';

  @override
  String get contentWarningDescPorn =>
      'Naglalaman ng tahasang pornographic content';

  @override
  String get contentWarningDescGraphicMedia =>
      'Naglalaman ng graphic o nakakagulat na imahe';

  @override
  String get contentWarningDescViolence => 'Naglalaman ng marahas na content';

  @override
  String get contentWarningDescSelfHarm =>
      'Naglalaman ng reference sa self-harm';

  @override
  String get contentWarningDescDrugs =>
      'Naglalaman ng content tungkol sa droga';

  @override
  String get contentWarningDescAlcohol =>
      'Naglalaman ng content tungkol sa alak';

  @override
  String get contentWarningDescTobacco =>
      'Naglalaman ng content tungkol sa tabako';

  @override
  String get contentWarningDescGambling =>
      'Naglalaman ng content tungkol sa sugal';

  @override
  String get contentWarningDescProfanity => 'Naglalaman ng malalakas na salita';

  @override
  String get contentWarningDescFlashingLights =>
      'Naglalaman ng kumikislap na ilaw (photosensitivity warning)';

  @override
  String get contentWarningDescAiGenerated =>
      'Ang content na ito ay gawa ng AI';

  @override
  String get contentWarningDescSpoiler => 'Naglalaman ng spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Minarkahan ito ng creator bilang sensitibo';

  @override
  String get contentWarningDescDefault =>
      'Minarkahan ng creator ang content na ito';

  @override
  String get contentWarningDetailsTitle => 'Mga Content Warning';

  @override
  String get contentWarningDetailsSubtitle =>
      'Inilapat ng creator ang mga label na ito:';

  @override
  String get contentWarningManageFilters => 'Pamahalaan ang mga content filter';

  @override
  String get contentWarningViewAnyway => 'Tingnan pa rin';

  @override
  String get contentWarningReportContentTooltip => 'I-report ang Content';

  @override
  String get contentWarningBlockUserTooltip => 'I-block ang User';

  @override
  String get contentWarningBlockedTitle => 'Naka-block ang Content';

  @override
  String get contentWarningBlockedPolicy =>
      'Na-block ang content na ito dahil sa policy violations.';

  @override
  String get contentWarningNoticeTitle => 'Content Notice';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Posibleng Nakakapinsalang Content';

  @override
  String get contentWarningView => 'Tingnan';

  @override
  String get contentWarningReportAction => 'I-report';

  @override
  String get contentWarningHideAllLikeThis =>
      'Itago lahat ng content na ganito';

  @override
  String get contentWarningNoFilterYet =>
      'Wala pang naka-save na filter para sa warning na ito.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Itatago na namin ang ganitong post mula ngayon.';

  @override
  String get videoErrorNotFound => 'Hindi nakita ang video';

  @override
  String get videoErrorNetwork => 'Network error';

  @override
  String get videoErrorTimeout => 'Nag-timeout ang loading';

  @override
  String get videoErrorFormat =>
      'Error sa format ng video\n(Subukan ulit o gumamit ng ibang browser)';

  @override
  String get videoErrorUnsupportedFormat =>
      'Hindi sinusuportahang video format';

  @override
  String get videoErrorPlayback => 'Error sa playback ng video';

  @override
  String get videoErrorAgeRestricted => 'Age-restricted content';

  @override
  String get videoErrorVerifyAge => 'I-verify ang Edad';

  @override
  String get videoErrorRetry => 'Subukan ulit';

  @override
  String get videoErrorContentRestricted => 'Restricted ang content';

  @override
  String get videoErrorContentRestrictedBody =>
      'Pinigilan ng relay ang video na ito.';

  @override
  String get videoErrorVerifyAgeBody =>
      'I-verify ang edad mo para mapanood ang video na ito.';

  @override
  String get videoErrorSkip => 'Laktawan';

  @override
  String get videoErrorVerifyAgeButton => 'I-verify ang edad';

  @override
  String get videoFollowButtonFollowing => 'Sinusundan';

  @override
  String get videoFollowButtonFollow => 'Sundan';

  @override
  String get audioAttributionOriginalSound => 'Original sound';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirasyon mula kay @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'kasama si @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'kasama si @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator',
      one: '1 collaborator',
    );
    return '$_temp0. I-tap para tingnan ang profile.';
  }

  @override
  String get videoCollaboratorPendingDecoration => 'Pending';

  @override
  String get videoCollaboratorPendingSemanticLabel => 'Pending collaborator';

  @override
  String videoCollaboratorWithPendingSuffix(String label, int pending) {
    return '$label ($pending pending)';
  }

  @override
  String profileChipTapHint(String name) {
    return '$name. Tap to view profile.';
  }

  @override
  String get listAttributionFallback => 'List';

  @override
  String get shareVideoLabel => 'I-share ang video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Naipadala ang post kay $recipientName';
  }

  @override
  String get shareFailedToSend => 'Nabigong ipadala ang video';

  @override
  String get shareAddedToBookmarks => 'Naidagdag sa bookmarks';

  @override
  String get shareRemovedFromBookmarks => 'Tinanggal sa bookmarks';

  @override
  String get shareFailedToAddBookmark => 'Nabigong magdagdag ng bookmark';

  @override
  String get shareFailedToRemoveBookmark => 'Nabigong tanggalin ang bookmark';

  @override
  String get shareActionFailed => 'Nabigo ang action';

  @override
  String get shareWithTitle => 'I-share kasama si';

  @override
  String get shareFindPeople => 'Maghanap ng tao';

  @override
  String get shareFindPeopleMultiline => 'Maghanap\nng tao';

  @override
  String get shareSent => 'Naipadala';

  @override
  String get shareContactFallback => 'Contact';

  @override
  String get shareUserFallback => 'User';

  @override
  String shareSendingTo(String name) {
    return 'Ipinapadala kay $name';
  }

  @override
  String get shareMessageHint => 'Magdagdag ng optional na mensahe...';

  @override
  String get videoActionUnlike => 'I-unlike ang video';

  @override
  String get videoActionLike => 'I-like ang video';

  @override
  String get videoActionAutoLabel => 'Compilation';

  @override
  String get videoActionLikeLabel => 'I-like';

  @override
  String get videoActionReplyLabel => 'Sumagot';

  @override
  String get videoActionRepostLabel => 'Revine';

  @override
  String get videoActionShareLabel => 'I-share';

  @override
  String get videoActionReportLabel => 'I-report';

  @override
  String get videoActionReport => 'I-report ang video';

  @override
  String get videoActionEditLabel => 'I-edit';

  @override
  String get videoActionEdit => 'I-edit ang video';

  @override
  String get videoActionAboutLabel => 'Tungkol';

  @override
  String get videoActionEnableAutoAdvance => 'I-enable ang auto advance';

  @override
  String get videoActionDisableAutoAdvance => 'I-disable ang auto advance';

  @override
  String get videoActionRemoveRepost => 'Tanggalin ang repost';

  @override
  String get videoActionRepost => 'I-repost ang video';

  @override
  String get videoActionViewComments => 'Tingnan ang mga komento';

  @override
  String get videoActionMoreOptions => 'Iba pang options';

  @override
  String get videoActionHideSubtitles => 'Itago ang subtitles';

  @override
  String get videoActionShowSubtitles => 'Ipakita ang subtitles';

  @override
  String get videoEngagementLikersTitle => 'Nag-like';

  @override
  String get videoEngagementRepostersTitle => 'Nag-repost';

  @override
  String get videoEngagementLikersEmpty => 'Wala pang nag-like';

  @override
  String get videoEngagementRepostersEmpty => 'Wala pang nag-repost';

  @override
  String get videoEngagementLoadFailed => 'Hindi ma-load ang listahan';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Buksan ang video details';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Buksan ang video details';

  @override
  String videoDescriptionLoops(String count) {
    return '$count loops';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loops',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Hindi Divine';

  @override
  String get metadataBadgeHumanMade => 'Gawa ng Tao';

  @override
  String get metadataSoundsLabel => 'Mga Tunog';

  @override
  String get metadataOriginalSound => 'Original sound';

  @override
  String get metadataVerificationLabel => 'Verification';

  @override
  String get metadataDeviceAttestation => 'Device attestation';

  @override
  String get metadataProofManifest => 'Proof manifest';

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Mga Collaborator';

  @override
  String get metadataInspiredByLabel => 'Inspirasyon mula kay';

  @override
  String get metadataRepostedByLabel => 'Na-repost ni';

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loops',
      one: 'Loop',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Mga Like';

  @override
  String get metadataCommentsLabel => 'Mga Komento';

  @override
  String get metadataRepostsLabel => 'Mga Repost';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Na-post noong $date';
  }

  @override
  String get devOptionsTitle => 'Developer Options';

  @override
  String get devOptionsPageLoadTimes => 'Mga Oras ng Page Load';

  @override
  String get devOptionsNoPageLoads =>
      'Wala pang naitalang page load.\nMag-navigate sa app para makita ang timing data.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Pinakamabagal na Screen';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video Playback Format';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Magpalit ng Environment?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Lipat sa $envName?\n\nIki-clear nito ang cached video data at magkokonekta sa bagong relay.';
  }

  @override
  String get devOptionsCancel => 'Cancel';

  @override
  String get devOptionsSwitch => 'Magpalit';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Lumipat sa $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Lumipat sa $formatName — na-clear ang cache';
  }

  @override
  String get featureFlagTitle => 'Mga Feature Flag';

  @override
  String get featureFlagResetAllTooltip => 'I-reset lahat ng flag sa default';

  @override
  String get featureFlagResetToDefault => 'I-reset sa default';

  @override
  String get featureFlagAppRecovery => 'App Recovery';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Kung nag-cra-crash o weird ang app, subukang i-clear ang cache.';

  @override
  String get featureFlagClearAllCache => 'I-clear lahat ng Cache';

  @override
  String get featureFlagCacheInfo => 'Cache Info';

  @override
  String get featureFlagClearCacheTitle => 'I-clear lahat ng Cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'Iki-clear nito ang lahat ng cached data kabilang ang:\n• Mga Notification\n• Mga User profile\n• Mga Bookmark\n• Mga Temporary file\n\nKakailanganin mong mag-log in ulit. Ituloy?';

  @override
  String get featureFlagClearCache => 'I-clear ang Cache';

  @override
  String get featureFlagClearingCache => 'Kine-clear ang cache...';

  @override
  String get featureFlagSuccess => 'Tagumpay';

  @override
  String get featureFlagError => 'Error';

  @override
  String get featureFlagClearCacheSuccess =>
      'Matagumpay na na-clear ang cache. I-restart ang app.';

  @override
  String get featureFlagClearCacheFailure =>
      'Nabigong i-clear ang ilang cache item. Tingnan ang logs para sa detalye.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Impormasyon ng Cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Total cache size: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Kasama sa cache:\n• Notification history\n• User profile data\n• Mga video thumbnail\n• Mga temporary file\n• Database indexes';

  @override
  String get relaySettingsTitle => 'Mga Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Open system ang Divine - ikaw ang may kontrol sa mga koneksyon mo';

  @override
  String get relaySettingsInfoDescription =>
      'Ang mga relay na ito ay namamahagi ng iyong content sa decentralized na Nostr network. Maaari kang magdagdag o magtanggal ng relay ayon sa gusto mo.';

  @override
  String get relaySettingsLearnMoreNostr => 'Alamin pa ang tungkol sa Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Maghanap ng public relay sa nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Hindi Gumagana ang App';

  @override
  String get relaySettingsRequiresRelay =>
      'Nangangailangan ang Divine ng kahit isang relay para mag-load ng video, mag-post ng content, at mag-sync ng data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Ibalik ang Default Relay';

  @override
  String get relaySettingsAddCustomRelay => 'Magdagdag ng Custom Relay';

  @override
  String get relaySettingsAddRelay => 'Magdagdag ng Relay';

  @override
  String get relaySettingsRetry => 'Subukan ulit';

  @override
  String get relaySettingsNoStats => 'Wala pang available na statistics';

  @override
  String get relaySettingsConnection => 'Koneksyon';

  @override
  String get relaySettingsConnected => 'Konektado';

  @override
  String get relaySettingsDisconnected => 'Hindi Konektado';

  @override
  String get relaySettingsSessionDuration => 'Tagal ng Session';

  @override
  String get relaySettingsLastConnected => 'Huling Konektado';

  @override
  String get relaySettingsDisconnectedLabel => 'Hindi Konektado';

  @override
  String get relaySettingsReason => 'Dahilan';

  @override
  String get relaySettingsActiveSubscriptions => 'Mga Active na Subscription';

  @override
  String get relaySettingsTotalSubscriptions => 'Kabuuang Subscription';

  @override
  String get relaySettingsEventsReceived => 'Mga Event na Natanggap';

  @override
  String get relaySettingsEventsSent => 'Mga Event na Naipadala';

  @override
  String get relaySettingsRequestsThisSession =>
      'Mga Request sa Session na Ito';

  @override
  String get relaySettingsFailedRequests => 'Mga Bigong Request';

  @override
  String relaySettingsLastError(String error) {
    return 'Huling Error: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Naglo-load ng impormasyon ng relay...';

  @override
  String get relaySettingsAboutRelay => 'Tungkol sa Relay';

  @override
  String get relaySettingsSupportedNips => 'Mga Suportadong NIP';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Tingnan ang Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Alisin ang Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Sigurado ka bang gusto mong alisin ang relay na ito?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Kanselahin';

  @override
  String get relaySettingsRemove => 'Alisin';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Inalis ang relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Hindi naalis ang relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Pinipilit ang muling pagkonekta sa relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Nakakonekta sa $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Hindi nakakonekta sa mga relay. Pakitsek ang iyong network connection.';

  @override
  String get relaySettingsAddRelayTitle => 'Magdagdag ng Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Ilagay ang WebSocket URL ng relay na gusto mong idagdag:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'I-browse ang mga public relay sa nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Idagdag';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Naidagdag na relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Hindi naidagdag ang relay. Pakitsek ang URL at subukan ulit.';

  @override
  String get relaySettingsInvalidUrl =>
      'Ang URL ng relay ay dapat magsimula sa wss:// o ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Dapat gumamit ng wss:// ang relay URL (pinapayagan lang ang ws:// para sa localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Naibalik ang default na relay: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Hindi naibalik ang default na relay. Pakitsek ang iyong network connection.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Hindi mabuksan ang browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Hindi mabuksan ang link';

  @override
  String get relaySettingsExternalRelay => 'External relay';

  @override
  String get relaySettingsNotConnected => 'Hindi konektado';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Nadiskonek $duration na ang nakalipas';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count subs';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count events';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration na ang nakalipas';
  }

  @override
  String get nostrSettingsIntro =>
      'Gumagamit ang Divine ng Nostr protocol para sa decentralized publishing. Naka-host sa mga napili mong relay ang content mo, at ang mga key mo ang iyong identity.';

  @override
  String get nostrSettingsSectionNetwork => 'Network';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Danger Zone';

  @override
  String get nostrSettingsRelays => 'Mga Relay';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'I-manage ang mga Nostr relay connection';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relay Diagnostics';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'I-debug ang relay connectivity at network issues';

  @override
  String get nostrSettingsMediaServers => 'Mga Media Server';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'I-configure ang mga Blossom upload server';

  @override
  String get nostrSettingsDeveloperOptions => 'Developer Options';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Environment switcher at debug settings';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'I-toggle ang mga feature flag na maaaring magka-hiccup.';

  @override
  String get nostrSettingsKeyManagement => 'Key Management';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'I-export, i-backup, at i-restore ang iyong Nostr keys';

  @override
  String get nostrSettingsRemoveKeys => 'Alisin ang mga Key sa Device';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Burahin ang private key mo sa device na ito lang. Mananatili ang content mo sa mga relay, pero kakailanganin mo ang nsec backup mo para ma-access ulit ang account mo.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Hindi naalis ang mga key sa device na ito. Subukan ulit.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Hindi naalis ang mga key: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Burahin ang Account at Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'PERMANENTENG burahin ang account mo at LAHAT ng content sa Nostr relays. Hindi na ito maibabalik.';

  @override
  String get relayDiagnosticTitle => 'Mga Relay Diagnostic';

  @override
  String get relayDiagnosticRefreshTooltip => 'I-refresh ang diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Huling refresh: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status ng Relay';

  @override
  String get relayDiagnosticInitialized => 'Na-initialize na';

  @override
  String get relayDiagnosticReady => 'Handa na';

  @override
  String get relayDiagnosticNotInitialized => 'Hindi pa na-initialize';

  @override
  String get relayDiagnosticDatabaseEvents => 'Mga Database Event';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Mga Aktibong Subscription';

  @override
  String get relayDiagnosticExternalRelays => 'Mga Panlabas na Relay';

  @override
  String get relayDiagnosticConfigured => 'Naka-configure';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Nakakonekta';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Mga Video Event';

  @override
  String get relayDiagnosticHomeFeed => 'Home Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Naglo-load';

  @override
  String get relayDiagnosticYes => 'Oo';

  @override
  String get relayDiagnosticNo => 'Hindi';

  @override
  String get relayDiagnosticTestDirectQuery => 'Subukan ang Direct Query';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Network Connectivity';

  @override
  String get relayDiagnosticRunNetworkTest => 'Patakbuhin ang Network Test';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Subukan Lahat ng Endpoint';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Base URL';

  @override
  String get relayDiagnosticSummary => 'Buod';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (avg ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Subukang Muli Lahat';

  @override
  String get relayDiagnosticRetrying => 'Sinusubukang muli...';

  @override
  String get relayDiagnosticRetryConnection => 'Subukang Muli ang Connection';

  @override
  String get relayDiagnosticTroubleshooting => 'Troubleshooting';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Berdeng status = Nakakonekta at gumagana\n• Pulang status = Nabigo ang connection\n• Kung nabigo ang network test, tsek ang internet connection\n• Kung naka-configure ang mga relay pero hindi konektado, i-tap ang \"Subukang Muli ang Connection\"\n• Mag-screenshot ng screen na ito para sa debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Lahat ng REST endpoint ay malusog!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'May ilang REST endpoint na nabigo - tingnan ang detalye sa itaas';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Nakahanap ng $count video event sa database';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Nabigo ang query: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Nakakonekta sa $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Hindi nakakonekta sa kahit anong relay';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Nabigo ang muling pagkonekta: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Nakakonekta at Authenticated';

  @override
  String get relayDiagnosticConnectedOnly => 'Nakakonekta';

  @override
  String get relayDiagnosticNotConnected => 'Hindi nakakonekta';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Walang naka-configure na relay';

  @override
  String get relayDiagnosticFailed => 'Nabigo';

  @override
  String get notificationSettingsTitle => 'Mga Notification';

  @override
  String get notificationSettingsResetTooltip => 'I-reset sa default';

  @override
  String get notificationSettingsTypes => 'Mga Uri ng Notification';

  @override
  String get notificationSettingsLikes => 'Mga Like';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Kapag may nag-like sa iyong mga video';

  @override
  String get notificationSettingsComments => 'Mga Comment';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Kapag may nag-comment sa iyong mga video';

  @override
  String get notificationSettingsFollows => 'Mga Follow';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Kapag may nag-follow sa iyo';

  @override
  String get notificationSettingsMentions => 'Mga Mention';

  @override
  String get notificationSettingsMentionsSubtitle => 'Kapag na-mention ka';

  @override
  String get notificationSettingsReposts => 'Mga Repost';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Kapag may nag-repost ng iyong mga video';

  @override
  String get notificationSettingsSystem => 'System';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Mga app update at system message';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Push Notification';

  @override
  String get notificationSettingsPushNotifications => 'Push Notification';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Tumanggap ng notification kahit nakasara ang app';

  @override
  String get notificationSettingsSound => 'Tunog';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Magpatugtog ng tunog para sa mga notification';

  @override
  String get notificationSettingsVibration => 'Vibration';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Mag-vibrate para sa mga notification';

  @override
  String get notificationSettingsActions => 'Mga Aksyon';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Markahang Lahat Bilang Nabasa';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Markahan lahat ng notification bilang nabasa na';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Lahat ng notification ay namarkahan bilang nabasa';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Hindi nagawang markahan lahat bilang nabasa';

  @override
  String get notificationSettingsResetToDefaults =>
      'Naibalik ang mga setting sa default';

  @override
  String get notificationSettingsAbout => 'Tungkol sa Mga Notification';

  @override
  String get notificationSettingsAboutDescription =>
      'Ang mga notification ay pinapagana ng Nostr protocol. Ang real-time na update ay nakadepende sa iyong koneksyon sa mga Nostr relay. May ilang notification na maaaring ma-delay.';

  @override
  String get safetySettingsTitle => 'Kaligtasan at Privacy';

  @override
  String get safetySettingsLabel => 'MGA SETTING';

  @override
  String get safetySettingsWhatYouSee => 'ANG NAKIKITA MO';

  @override
  String get safetySettingsWhatYouPublish => 'ANG PINO-POST MO';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Ipakita lang ang mga video na naka-host sa Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Itago ang mga video na galing sa ibang media host';

  @override
  String get safetySettingsModeration => 'MODERATION';

  @override
  String get safetySettingsBlockedUsers => 'MGA NA-BLOCK NA USER';

  @override
  String get safetySettingsAgeVerification => 'AGE VERIFICATION';

  @override
  String get safetySettingsAgeConfirmation =>
      'Kinukumpirma ko na ako ay 18 taong gulang o mas matanda';

  @override
  String get safetySettingsAgeRequired =>
      'Kailangan para makita ang adult content';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Opisyal na moderation service (naka-on bilang default)';

  @override
  String get safetySettingsPeopleIFollow => 'Mga taong fino-follow ko';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Mag-subscribe sa mga label mula sa mga taong fino-follow mo';

  @override
  String get safetySettingsAddCustomLabeler => 'Magdagdag ng Custom Labeler';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Ilagay ang npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Magdagdag ng custom labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Ilagay ang npub address';

  @override
  String get safetySettingsNoBlockedUsers => 'Walang na-block na user';

  @override
  String get safetySettingsUnblock => 'I-unblock';

  @override
  String get safetySettingsUserUnblocked => 'Na-unblock ang user';

  @override
  String get safetySettingsCancel => 'Kanselahin';

  @override
  String get safetySettingsAdd => 'Idagdag';

  @override
  String get analyticsTitle => 'Creator Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'I-toggle ang diagnostics';

  @override
  String get analyticsRetry => 'Subukan Ulit';

  @override
  String get analyticsUnableToLoad => 'Hindi na-load ang analytics.';

  @override
  String get analyticsSignInRequired =>
      'Mag-sign in para makita ang creator analytics.';

  @override
  String get analyticsViewDataUnavailable =>
      'Hindi makuha ngayon ang views mula sa relay para sa mga post na ito. Tama pa rin ang metrics ng like, comment, at repost.';

  @override
  String get analyticsViewDataTitle => 'View Data';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Na-update $time • Ginagamit ng mga score ang likes, comments, reposts, at views/loops mula sa Funnelcake kapag available.';
  }

  @override
  String get analyticsVideos => 'Mga Video';

  @override
  String get analyticsViews => 'Mga View';

  @override
  String get analyticsInteractions => 'Mga Interaction';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Mga Follower';

  @override
  String get analyticsAvgPerPost => 'Avg/Post';

  @override
  String get analyticsInteractionMix => 'Interaction Mix';

  @override
  String get analyticsLikes => 'Mga Like';

  @override
  String get analyticsComments => 'Mga Comment';

  @override
  String get analyticsReposts => 'Mga Repost';

  @override
  String get analyticsPerformanceHighlights => 'Mga Performance Highlight';

  @override
  String get analyticsMostViewed => 'Pinakamaraming napanood';

  @override
  String get analyticsMostDiscussed => 'Pinakamaraming napag-usapan';

  @override
  String get analyticsMostReposted => 'Pinakamaraming na-repost';

  @override
  String get analyticsNoVideosYet => 'Wala pang video';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Hindi available ang view data';

  @override
  String analyticsViewsCount(String count) {
    return '$count views';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count comments';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top Content';

  @override
  String get analyticsPublishPrompt =>
      'Mag-publish ng ilang video para makita ang ranking.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Right-side % = Engagement Rate (interactions na hinati sa views).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Kailangan ng Engagement Rate ng view data; lalabas N/A ang values hangga\'t hindi available ang views.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'hindi available ang views';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interactions';
  }

  @override
  String get analyticsPostAnalytics => 'Post Analytics';

  @override
  String get analyticsOpenPost => 'Buksan ang Post';

  @override
  String get analyticsRecentDailyInteractions =>
      'Kamakailang Pang-araw-araw na Interaction';

  @override
  String get analyticsNoActivityYet => 'Wala pang aktibidad sa range na ito.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = likes + comments + reposts ayon sa petsa ng post.';

  @override
  String get analyticsDailyBarExplainer =>
      'Ang haba ng bar ay base sa pinakamataas na araw mo sa window na ito.';

  @override
  String get analyticsAudienceSnapshot => 'Audience Snapshot';

  @override
  String analyticsFollowersCount(String count) {
    return 'Mga follower: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Fino-follow: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Lalabas ang audience source/geo/time breakdown habang nagdadagdag ang Funnelcake ng mga audience analytics endpoint.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Lalabas ang retention curve at watch-time breakdown kapag dumating na ang per-second/per-bucket retention mula sa Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Hindi available ang retention data hangga\'t hindi pa naibabalik ng Funnelcake ang view+watch-time analytics.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Kabuuang video: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'May views: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Walang views: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrated (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrated (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Mga source: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Gumamit ng fixture data';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Gumawa ng bagong Divine account';

  @override
  String get authSignInDifferentAccount =>
      'Mag-sign in gamit ang umiiral na account';

  @override
  String get authSignBackIn => 'Mag-sign in muli';

  @override
  String get authTermsPrefix =>
      'Sa pagpili ng opsyon sa itaas, kinukumpirma mo na ikaw ay 16 na taong gulang o mas matanda at sumasang-ayon sa ';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authTermsAnd => ', at ';

  @override
  String get authSafetyStandards => 'Safety Standards';

  @override
  String get authAmberNotInstalled => 'Hindi naka-install ang Amber app';

  @override
  String get authAmberConnectionFailed => 'Hindi nakakonekta sa Amber';

  @override
  String get authPasswordResetSent =>
      'Kung may account na umiiral sa email na iyon, naipadala na ang link para sa pag-reset ng password.';

  @override
  String get authSignInTitle => 'Mag-sign in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authConfirmPasswordLabel => 'Kumpirmahin ang password';

  @override
  String get authEmailRequired => 'Kailangan ang email';

  @override
  String get authEmailInvalid => 'Pakilagay ang valid na email';

  @override
  String get authPasswordRequired => 'Kailangan ang password';

  @override
  String get authConfirmPasswordRequired => 'Pakikumpirma ang iyong password';

  @override
  String get authPasswordsDoNotMatch => 'Hindi magkatugma ang mga password';

  @override
  String get authForgotPassword => 'Nakalimutan ang password?';

  @override
  String get authImportNostrKey => 'Mag-import ng Nostr key';

  @override
  String get authConnectSignerApp => 'Kumonekta gamit ang signer app';

  @override
  String get authSignInWithAmber => 'Mag-sign in gamit ang Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Mag-sign in gamit ang browser extension';

  @override
  String get authNip07ConnectionFailed =>
      'Hindi nakakonekta sa iyong browser extension.';

  @override
  String get authNip07ExtensionNotFound =>
      'Walang nahanap na browser extension. Mag-install ng Alby, nos2x, o iba pang NIP-07 compatible na extension.';

  @override
  String get authSignInOptionsTitle => 'Mga opsyon sa pag-sign in';

  @override
  String get authInfoEmailPasswordTitle => 'Email at Password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Mag-sign in gamit ang iyong Divine account. Kung nag-register ka gamit ang email at password, gamitin mo iyon dito.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'May Nostr identity ka na? I-import ang iyong nsec private key mula sa ibang client.';

  @override
  String get authInfoSignerAppTitle => 'Signer App';

  @override
  String get authInfoSignerAppDescription =>
      'Kumonekta gamit ang NIP-46 compatible na remote signer tulad ng nsecBunker para sa mas mahigpit na key security.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Gamitin ang Amber signer app sa Android para ligtas na pamahalaan ang iyong mga Nostr key.';

  @override
  String get authInfoBrowserExtensionTitle => 'Browser Extension';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Mag-sign in gamit ang NIP-07 browser extension tulad ng Alby o nos2x. Nananatili sa extension ang iyong mga key — hindi ito nakikita ng Divine.';

  @override
  String get authCreateAccountTitle => 'Gumawa ng account';

  @override
  String get authBackToInviteCode => 'Bumalik sa invite code';

  @override
  String get authUseDivineNoBackup => 'Gamitin ang Divine nang walang backup';

  @override
  String get authSkipConfirmTitle => 'Isang huling bagay...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Pasok ka na! Gagawa kami ng secure na key na magpapagana sa iyong Divine account.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Kung walang email, ang key mo ang tanging paraan para malaman ng Divine na sa iyo ang account na ito.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Pwede mong i-access ang key mo sa app, pero kung hindi ka technical, mas inirerekomenda namin na magdagdag ka na ng email at password ngayon. Mas madali ang pag-sign in at pagbalik sa account mo kapag nawala o na-reset ang device na ito.';

  @override
  String get authAddEmailPassword => 'Magdagdag ng email at password';

  @override
  String get authUseThisDeviceOnly => 'Sa device na ito lang gamitin';

  @override
  String get authCompleteRegistration => 'Kumpletuhin ang iyong registration';

  @override
  String get authVerifying => 'Vine-verify...';

  @override
  String get authVerificationLinkSent =>
      'Nagpadala kami ng verification link sa:';

  @override
  String get authClickVerificationLink =>
      'Pakiclick ang link sa iyong email para\nkumpletuhin ang iyong registration.';

  @override
  String get authPleaseWaitVerifying =>
      'Pakihintay habang vine-verify namin ang iyong email...';

  @override
  String get authWaitingForVerification => 'Naghihintay ng verification';

  @override
  String get authOpenEmailApp => 'Buksan ang email app';

  @override
  String get authWelcomeToDivine => 'Welcome sa Divine!';

  @override
  String get authEmailVerified => 'Na-verify na ang iyong email.';

  @override
  String get authSigningYouIn => 'Sini-sign in ka';

  @override
  String get authErrorTitle => 'Naku.';

  @override
  String get authVerificationFailed =>
      'Hindi na-verify ang iyong email.\nPakisubukang ulit.';

  @override
  String get authStartOver => 'Magsimulang muli';

  @override
  String get authEmailVerifiedLogin =>
      'Na-verify ang email! Pakilog in para magpatuloy.';

  @override
  String get authVerificationLinkExpired =>
      'Hindi na valid ang verification link na ito.';

  @override
  String get authVerificationConnectionError =>
      'Hindi na-verify ang email. Pakitsek ang iyong connection at subukang ulit.';

  @override
  String get authWaitlistConfirmTitle => 'Pasok ka na!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Magbabahagi kami ng update sa $email.\nKapag may mga bagong invite code na, ipapadala namin sa iyo.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Pansamantalang hindi available ang invite access.';

  @override
  String get authInviteUnavailableBody =>
      'Subukang ulit mamaya, o makipag-ugnayan sa support kung kailangan mo ng tulong para makapasok.';

  @override
  String get authTryAgain => 'Subukan ulit';

  @override
  String get authContactSupport => 'Makipag-ugnayan sa support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Hindi mabuksan ang $email';
  }

  @override
  String get authAddInviteCode => 'Idagdag ang iyong invite code';

  @override
  String get authInviteCodeLabel => 'Invite code';

  @override
  String get authEnterYourCode => 'Ilagay ang iyong code';

  @override
  String get authNext => 'Susunod';

  @override
  String get authJoinWaitlist => 'Sumali sa waitlist';

  @override
  String get authJoinWaitlistTitle => 'Sumali sa waitlist';

  @override
  String get authJoinWaitlistDescription =>
      'Ibahagi ang iyong email at magpapadala kami ng invite code kapag may bukas na access.';

  @override
  String get authJoinWaitlistNewsletterOptIn =>
      'Padalhan ako ng inspirasyon mula sa Divine';

  @override
  String get authInviteAccessHelp => 'Tulong sa invite access';

  @override
  String get authGeneratingConnection => 'Bumubuo ng connection...';

  @override
  String get authConnectedAuthenticating =>
      'Nakakonekta! Nagsa-authenticate...';

  @override
  String get authConnectionTimedOut => 'Nag-time out ang connection';

  @override
  String get authApproveConnection =>
      'Siguraduhin na inaprubahan mo ang connection sa iyong signer app.';

  @override
  String get authConnectionCancelled => 'Kinansela ang connection';

  @override
  String get authConnectionCancelledMessage => 'Kinansela ang connection.';

  @override
  String get authConnectionFailed => 'Nabigo ang connection';

  @override
  String get authUnknownError => 'May hindi inaasahang error na nangyari.';

  @override
  String get authUrlCopied => 'Nakopya ang URL sa clipboard';

  @override
  String get authConnectToDivine => 'Kumonekta sa Divine';

  @override
  String get authPasteBunkerUrl => 'I-paste ang bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Invalid ang bunker URL. Dapat magsimula ito sa bunker://';

  @override
  String get authScanSignerApp =>
      'I-scan gamit ang iyong\nsigner app para kumonekta.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Naghihintay ng connection... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Kopyahin ang URL';

  @override
  String get authShare => 'I-share';

  @override
  String get authAddBunker => 'Magdagdag ng bunker';

  @override
  String get authCompatibleSignerApps => 'Mga compatible na Signer app';

  @override
  String get authFailedToConnect => 'Hindi nakakonekta';

  @override
  String get authResetPasswordTitle => 'I-reset ang Password';

  @override
  String get authResetPasswordSubtitle =>
      'Pakilagay ang iyong bagong password. Dapat ay hindi bababa sa 8 character ang haba.';

  @override
  String get authNewPasswordLabel => 'Bagong Password';

  @override
  String get authConfirmNewPasswordLabel => 'Kumpirmahin ang bagong password';

  @override
  String get authPasswordTooShort =>
      'Dapat ay hindi bababa sa 8 character ang password';

  @override
  String get authPasswordResetSuccess =>
      'Matagumpay na na-reset ang password. Pakilog in.';

  @override
  String get authPasswordResetFailed => 'Hindi na-reset ang password';

  @override
  String get authUnexpectedError =>
      'May hindi inaasahang error na nangyari. Pakisubukang ulit.';

  @override
  String get authUpdatePassword => 'I-update ang password';

  @override
  String get authSecureAccountTitle => 'I-secure ang account';

  @override
  String get authUnableToAccessKeys =>
      'Hindi ma-access ang iyong mga key. Pakisubukang ulit.';

  @override
  String get authRegistrationFailed => 'Nabigo ang registration';

  @override
  String get authRegistrationComplete =>
      'Kumpleto na ang registration. Pakitsek ang iyong email.';

  @override
  String get authVerificationFailedTitle => 'Nabigo ang Verification';

  @override
  String get authClose => 'Isara';

  @override
  String get authAccountSecured => 'Na-secure na ang Account!';

  @override
  String get authAccountLinkedToEmail =>
      'Naka-link na ngayon ang iyong account sa iyong email.';

  @override
  String get authVerifyYourEmail => 'I-verify ang Iyong Email';

  @override
  String get authClickLinkContinue =>
      'I-click ang link sa iyong email para kumpletuhin ang registration. Pwede mo pa ring gamitin ang app habang naghihintay.';

  @override
  String get authWaitingForVerificationEllipsis =>
      'Naghihintay ng verification...';

  @override
  String get authContinueToApp => 'Magpatuloy sa App';

  @override
  String get authResetPassword => 'I-reset ang password';

  @override
  String get authResetPasswordDescription =>
      'Ilagay ang iyong email address at magpapadala kami ng link para i-reset ang iyong password.';

  @override
  String get authFailedToSendResetEmail => 'Hindi naipadala ang reset email.';

  @override
  String get authUnexpectedErrorShort =>
      'May hindi inaasahang error na nangyari.';

  @override
  String get authSending => 'Nagpapadala...';

  @override
  String get authSendResetLink => 'Ipadala ang reset link';

  @override
  String get authEmailSent => 'Naipadala ang email!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Nagpadala kami ng password reset link sa $email. Pakiclick ang link sa iyong email para i-update ang iyong password.';
  }

  @override
  String get authSignInButton => 'Mag-sign in';

  @override
  String get authVerificationErrorTimeout =>
      'Nag-time out ang verification. Pakisubukang mag-register ulit.';

  @override
  String get authVerificationErrorMissingCode =>
      'Nabigo ang verification — kulang ang authorization code.';

  @override
  String get authVerificationErrorPollFailed =>
      'Nabigo ang verification. Pakisubukang ulit.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'May network error habang nagsa-sign in. Pakisubukang ulit.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Nabigo ang verification. Pakisubukang mag-register ulit.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Nabigo ang sign-in. Pakisubukang mag-log in nang manu-mano.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Hindi na available ang invite code na iyon. Bumalik sa iyong invite code, sumali sa waitlist, o makipag-ugnayan sa support.';

  @override
  String get authInviteErrorInvalid =>
      'Hindi pwedeng gamitin ngayon ang invite code na iyon. Bumalik sa iyong invite code, sumali sa waitlist, o makipag-ugnayan sa support.';

  @override
  String get authInviteErrorTemporary =>
      'Hindi namin ma-confirm ang iyong invite ngayon. Bumalik sa iyong invite code at subukang ulit, o makipag-ugnayan sa support.';

  @override
  String get authInviteErrorUnknown =>
      'Hindi namin na-activate ang iyong invite. Bumalik sa iyong invite code, sumali sa waitlist, o makipag-ugnayan sa support.';

  @override
  String get shareSheetSave => 'I-save';

  @override
  String get shareSheetSaveToGallery => 'I-save sa Gallery';

  @override
  String get shareSheetSaveWithWatermark => 'I-save na may Watermark';

  @override
  String get shareSheetSaveVideo => 'I-save ang Video';

  @override
  String get shareSheetAddToClips => 'Idagdag sa clips';

  @override
  String get shareSheetAddedToClips => 'Naidagdag sa clips';

  @override
  String get shareSheetAddToClipsFailed => 'Hindi naidagdag sa clips';

  @override
  String get shareSheetAddToList => 'Idagdag sa List';

  @override
  String get shareSheetCopy => 'Kopyahin';

  @override
  String get shareSheetShareVia => 'I-share gamit ang';

  @override
  String get shareSheetReport => 'I-report';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'Event ID';

  @override
  String get shareSheetMoreActions => 'Iba pang aksyon';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Na-save sa Camera Roll';

  @override
  String get watermarkDownloadShare => 'I-share';

  @override
  String get watermarkDownloadDone => 'Tapos na';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Kailangan ng Photos Access';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Para makapag-save ng video, pahintulutan ang Photos access sa Settings.';

  @override
  String get watermarkDownloadOpenSettings => 'Buksan ang Settings';

  @override
  String get watermarkDownloadNotNow => 'Hindi Ngayon';

  @override
  String get watermarkDownloadFailed => 'Nabigo ang Download';

  @override
  String get watermarkDownloadDismiss => 'I-dismiss';

  @override
  String get watermarkDownloadStageDownloading => 'Dina-download ang Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Naglalagay ng Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Sina-save sa Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Kinukuha ang video mula sa network...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Inilalagay ang Divine watermark...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Sina-save ang naka-watermark na video sa iyong camera roll...';

  @override
  String get uploadProgressVideoUpload => 'Video Upload';

  @override
  String get uploadProgressPause => 'I-pause';

  @override
  String get uploadProgressResume => 'Ituloy';

  @override
  String get uploadProgressGoBack => 'Bumalik';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Subukang Ulit ($count natitira)';
  }

  @override
  String get uploadProgressDelete => 'Burahin';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}d ang nakalipas';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}h ang nakalipas';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}m ang nakalipas';
  }

  @override
  String get uploadProgressJustNow => 'Kanina lang';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Nag-a-upload $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Naka-pause $percent%';
  }

  @override
  String get badgeExplanationClose => 'Isara';

  @override
  String get badgeExplanationOriginalVineArchive => 'Original Vine Archive';

  @override
  String get badgeExplanationCameraProof => 'Camera Proof';

  @override
  String get badgeExplanationAuthenticitySignals => 'Mga Authenticity Signal';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Ang video na ito ay isang original Vine na nakuha mula sa Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Bago nagsara ang Vine noong 2017, nagtulungan ang ArchiveTeam at Internet Archive para mapreserba ang milyun-milyong Vine para sa kasaysayan. Ang content na ito ay bahagi ng makasaysayang preservation effort na iyon.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Original na stats: $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Alamin pa ang tungkol sa Vine archive preservation';

  @override
  String get badgeExplanationLearnProofmode =>
      'Alamin pa ang tungkol sa Proofmode verification';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Alamin pa ang tungkol sa Divine authenticity signals';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Suriin gamit ang ProofCheck Tool';

  @override
  String get badgeExplanationInspectMedia => 'Suriin ang detalye ng media';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Ang authenticity ng video na ito ay na-verify gamit ang Proofmode technology.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Naka-host sa Divine ang video na ito at ipinapahiwatig ng AI detection na malamang gawa ito ng tao, pero hindi pa ito kasama sa cryptographic camera-verification data.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Ipinapahiwatig ng AI detection na malamang gawa ng tao ang video na ito, kahit hindi pa ito may cryptographic camera-verification data.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Naka-host sa Divine ang video na ito, pero wala pa itong cryptographic camera-verification data.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Naka-host sa labas ng Divine ang video na ito at walang cryptographic camera-verification data.';

  @override
  String get badgeExplanationDeviceAttestation => 'Device attestation';

  @override
  String get badgeExplanationPgpSignature => 'PGP signature';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Proof manifest';

  @override
  String get badgeExplanationAiDetection => 'AI Detection';

  @override
  String get badgeExplanationAiNotScanned => 'AI scan: Hindi pa na-scan';

  @override
  String get badgeExplanationNoScanResults =>
      'Wala pang scan result na available.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Tingnan kung AI-generated';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% tsansa na AI-generated';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Sini-scan ng: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Na-verify ng human moderator';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platinum: Device hardware attestation, cryptographic signatures, Content Credentials (C2PA), at kinukumpirma ng AI scan na gawa ng tao.';

  @override
  String get badgeExplanationVerificationGold =>
      'Gold: Naitala sa totoong device na may hardware attestation, cryptographic signatures, at Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Silver: Pinapatunayan ng cryptographic signatures na hindi nabago ang video na ito mula nang itala.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze: May basic metadata signatures.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Silver: Kinukumpirma ng AI scan na malamang gawa ng tao ang video na ito.';

  @override
  String get badgeExplanationNoVerification =>
      'Walang available na verification data para sa video na ito.';

  @override
  String get shareMenuTitle => 'I-share ang Video';

  @override
  String get shareMenuReportAiContent => 'I-report ang AI Content';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Mabilisang i-report ang pinaghihinalaang AI-generated content';

  @override
  String get shareMenuReportingAiContent => 'Nire-report ang AI content...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Hindi nai-report ang content: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Hindi nai-report ang AI content: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Status ng Video';

  @override
  String get shareMenuViewAllLists => 'Tingnan lahat ng list →';

  @override
  String get shareMenuShareWith => 'I-share Sa';

  @override
  String get shareMenuShareViaOtherApps => 'I-share gamit ang ibang app';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'I-share gamit ang ibang app o kopyahin ang link';

  @override
  String get shareMenuSaveToGallery => 'I-save sa Gallery';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'I-save ang original na video sa camera roll';

  @override
  String get shareMenuSaveWithWatermark => 'I-save na may Watermark';

  @override
  String get shareMenuSaveVideo => 'I-save ang Video';

  @override
  String get shareMenuDownloadWithWatermark =>
      'I-download na may Divine watermark';

  @override
  String get shareMenuSaveVideoSubtitle => 'I-save ang video sa camera roll';

  @override
  String get shareMenuLists => 'Mga List';

  @override
  String get shareMenuAddToList => 'Idagdag sa List';

  @override
  String get shareMenuAddToListSubtitle => 'Idagdag sa iyong mga curated list';

  @override
  String get shareMenuCreateNewList => 'Gumawa ng Bagong List';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Magsimula ng bagong curated collection';

  @override
  String get shareMenuRemovedFromList => 'Inalis sa list';

  @override
  String get shareMenuFailedToRemoveFromList => 'Hindi naalis sa list';

  @override
  String get shareMenuBookmarks => 'Mga Bookmark';

  @override
  String get shareMenuAddToBookmarks => 'Idagdag sa Bookmarks';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'I-save para mapanood mamaya';

  @override
  String get shareMenuAddToBookmarkSet => 'Idagdag sa Bookmark Set';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Ayusin sa mga koleksyon';

  @override
  String get shareMenuFollowSets => 'Mga Listahan ng Tao';

  @override
  String get shareMenuCreateFollowSet => 'Gumawa ng Follow Set';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Magsimula ng bagong koleksyon kasama ang creator na ito';

  @override
  String get shareMenuAddToFollowSet => 'Idagdag sa Follow Set';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count follow sets ang available';
  }

  @override
  String get peopleListsAddToList => 'Idagdag sa listahan';

  @override
  String get peopleListsAddToListSubtitle =>
      'Ilagay ang creator na ito sa isa sa mga listahan mo';

  @override
  String get peopleListsSheetTitle => 'Idagdag sa listahan';

  @override
  String get peopleListsEmptyTitle => 'Wala pang listahan';

  @override
  String get peopleListsEmptySubtitle =>
      'Gumawa ng listahan para simulang igrupo ang mga tao.';

  @override
  String get peopleListsCreateList => 'Gumawa ng listahan';

  @override
  String get peopleListsNewListTitle => 'Bagong listahan';

  @override
  String get peopleListsRouteTitle => 'Listahan ng tao';

  @override
  String get peopleListsListNameLabel => 'Pangalan ng listahan';

  @override
  String get peopleListsListNameHint => 'Mga close friend';

  @override
  String get peopleListsCreateButton => 'Gumawa';

  @override
  String get peopleListsAddPeopleTitle => 'Magdagdag ng tao';

  @override
  String get peopleListsAddPeopleTooltip => 'Magdagdag ng tao';

  @override
  String get peopleListsAddPeopleSemanticLabel =>
      'Magdagdag ng tao sa listahan';

  @override
  String get peopleListsListNotFoundTitle => 'Hindi nakita ang listahan';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Hindi nakita ang listahan. Maaaring nabura na ito.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Maaaring nabura na ang listahang ito.';

  @override
  String get peopleListsNoPeopleTitle => 'Walang tao sa listahang ito';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Magdagdag ng mga tao para magsimula';

  @override
  String get peopleListsNoVideosTitle => 'Wala pang video';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Lalabas dito ang mga video mula sa mga miyembro ng listahan';

  @override
  String get peopleListsNoVideosAvailable => 'Walang available na video';

  @override
  String get peopleListsFailedToLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get peopleListsVideoNotAvailable => 'Hindi available ang video';

  @override
  String get peopleListsBackToGridTooltip => 'Bumalik sa grid';

  @override
  String get peopleListsErrorLoadingVideos =>
      'May error sa pag-load ng mga video';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Walang available na tao na maidadagdag.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Idagdag sa $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Maghanap ng tao';

  @override
  String get peopleListsAddPeopleError =>
      'Hindi na-load ang mga tao. Subukan ulit.';

  @override
  String get peopleListsAddPeopleRetry => 'Subukan ulit';

  @override
  String get peopleListsAddButton => 'Idagdag';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Idagdag ang $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Nasa $count listahan',
      one: 'Nasa 1 listahan',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Alisin si $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Aalisin sila sa listahang ito.';

  @override
  String get peopleListsRemove => 'Alisin';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Naalis si $name sa listahan';
  }

  @override
  String get peopleListsUndo => 'I-undo';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profile ni $name. Long press para alisin.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Tingnan ang profile ni $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Naidagdag sa bookmarks!';

  @override
  String get shareMenuFailedToAddBookmark => 'Hindi naidagdag ang bookmark';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Nagawa ang listahang \"$name\" at naidagdag ang video';
  }

  @override
  String get shareMenuManageContent => 'I-manage ang Content';

  @override
  String get shareMenuEditVideo => 'I-edit ang Video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'I-update ang title, description, at hashtags';

  @override
  String get shareMenuDeleteVideo => 'Burahin ang Video';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Alisin ang video na ito sa Divine. Maaari pa rin itong lumitaw sa ibang Nostr clients.';

  @override
  String get shareMenuDeleteWarning =>
      'Magpapadala ito ng delete request (NIP-09) sa lahat ng relays. May ibang relays na maaaring panatilihin pa rin ang content.';

  @override
  String get shareMenuVideoInTheseLists => 'Nasa mga listahang ito ang video:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count mga video';
  }

  @override
  String get shareMenuClose => 'Isara';

  @override
  String get shareMenuDeleteConfirmation =>
      'Permanenteng buburahin nito ang video na ito sa Divine. Maaari pa rin itong lumitaw sa third-party Nostr clients na gumagamit ng ibang relays.';

  @override
  String get shareMenuCancel => 'Kanselahin';

  @override
  String get shareMenuDelete => 'Burahin';

  @override
  String get shareMenuDeletingContent => 'Binubura ang content...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Hindi nabura ang content: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'Nabura ang video';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Hindi pa handa ang pagbubura. Subukan ulit mamaya.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Sariling video mo lang ang puwede mong burahin.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Mag-sign in ulit, tapos subukang burahin.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Hindi na-sign ang delete request. Subukan ulit.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Hindi maabot ang relay. Tingnan ang iyong koneksyon at subukan ulit.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Hindi nabura ang video na ito. Subukan ulit.';

  @override
  String get shareMenuFollowSetName => 'Pangalan ng Follow Set';

  @override
  String get shareMenuFollowSetNameHint =>
      'hal., Content Creators, Musicians, atbp.';

  @override
  String get shareMenuDescriptionOptional => 'Description (opsyonal)';

  @override
  String get shareMenuCreate => 'Gumawa';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Nagawa ang follow set na \"$name\" at naidagdag ang creator';
  }

  @override
  String get shareMenuDone => 'Tapos na';

  @override
  String get shareMenuEditTitle => 'Title';

  @override
  String get shareMenuEditTitleHint => 'Ilagay ang title ng video';

  @override
  String get shareMenuEditDescription => 'Description';

  @override
  String get shareMenuEditDescriptionHint => 'Ilagay ang description ng video';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'hashtags na pinaghihiwalay ng comma';

  @override
  String get shareMenuEditMetadataNote =>
      'Tandaan: Metadata lang ang puwedeng i-edit. Hindi mababago ang content ng video.';

  @override
  String get shareMenuDeleting => 'Binubura...';

  @override
  String get shareMenuUpdate => 'I-update';

  @override
  String get shareMenuVideoUpdated => 'Matagumpay na na-update ang video';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Hindi na-update ang video: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Hindi nabura ang video: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Burahin ang Video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Magpapadala ito ng deletion request sa mga relays. Tandaan: May ibang relays na maaaring may cached na kopya pa rin.';

  @override
  String get shareMenuVideoDeletionRequested => 'Nabura ang video';

  @override
  String get shareMenuContentLabels => 'Mga content label';

  @override
  String get shareMenuAddContentLabels => 'Magdagdag ng content labels';

  @override
  String get shareMenuClearAll => 'Burahin lahat';

  @override
  String get shareMenuCollaborators => 'Mga collaborator';

  @override
  String get shareMenuAddCollaborator => 'Mag-imbita ng collaborator';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Kailangan ninyong mag-follow ng isa\'t isa ni $name para ma-invite mo siya bilang collaborator.';
  }

  @override
  String get shareMenuLoading => 'Naglo-load...';

  @override
  String get shareMenuInspiredBy => 'Inspirado ng';

  @override
  String get shareMenuAddInspirationCredit => 'Magdagdag ng inspiration credit';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Hindi puwedeng i-reference ang creator na ito.';

  @override
  String get shareMenuUnknown => 'Hindi alam';

  @override
  String get shareMenuCreateBookmarkSet => 'Gumawa ng Bookmark Set';

  @override
  String get shareMenuSetName => 'Pangalan ng Set';

  @override
  String get shareMenuSetNameHint => 'hal., Favorites, Watch Later, atbp.';

  @override
  String get shareMenuCreateNewSet => 'Gumawa ng Bagong Set';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Magsimula ng bagong koleksyon ng bookmark';

  @override
  String get shareMenuNoBookmarkSets =>
      'Wala pang bookmark sets. Gumawa ng una mo!';

  @override
  String get shareMenuError => 'Error';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Hindi na-load ang mga bookmark set';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Nagawa ang \"$name\" at naidagdag ang video';
  }

  @override
  String get shareMenuUseThisSound => 'Gamitin ang sound na ito';

  @override
  String get shareMenuOriginalSound => 'Original na sound';

  @override
  String get authSessionExpired =>
      'Nag-expire na ang iyong session. Mag-sign in ulit.';

  @override
  String get authSignInFailed => 'Hindi nag-sign in. Subukan ulit.';

  @override
  String get localeAppLanguage => 'Wika ng App';

  @override
  String get localeDeviceDefault => 'Default ng device';

  @override
  String get localeSelectLanguage => 'Pumili ng Wika';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Hindi suportado ang web authentication sa secure mode. Gamitin ang mobile app para sa secure key management.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Hindi nag-integrate ang authentication: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Hindi inaasahang error: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Maglagay ng bunker URI';

  @override
  String get webAuthConnectTitle => 'Mag-connect sa Divine';

  @override
  String get webAuthChooseMethod =>
      'Piliin ang gusto mong paraan ng Nostr authentication';

  @override
  String get webAuthBrowserExtension => 'Browser Extension';

  @override
  String get webAuthRecommended => 'INIREREKOMENDA';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Mag-connect sa remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'I-paste mula sa clipboard';

  @override
  String get webAuthConnectToBunker => 'Mag-connect sa Bunker';

  @override
  String get webAuthNewToNostr => 'Bago ka sa Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Mag-install ng browser extension tulad ng Alby o nos2x para sa pinakamadaling karanasan, o gamitin ang nsec bunker para sa secure remote signing.';

  @override
  String get soundsTitle => 'Mga Sound';

  @override
  String get soundsSearchHint => 'Maghanap ng sounds...';

  @override
  String get soundsPreviewUnavailable =>
      'Hindi ma-preview ang sound - walang available na audio';

  @override
  String soundsPreviewFailed(String error) {
    return 'Hindi na-play ang preview: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Mga Featured Sound';

  @override
  String get soundsTrendingSounds => 'Mga Trending Sound';

  @override
  String get soundsAllSounds => 'Lahat ng Sound';

  @override
  String get soundsSearchResults => 'Mga Resulta ng Paghahanap';

  @override
  String get soundsNoSoundsAvailable => 'Walang available na sound';

  @override
  String get soundsNoSoundsDescription =>
      'Lalabas dito ang mga sound kapag may creators na nag-share ng audio';

  @override
  String get soundsNoSoundsFound => 'Walang nahanap na sound';

  @override
  String get soundsNoSoundsFoundDescription => 'Subukan ang ibang search term';

  @override
  String get soundsSavedToLibrary => 'Na-save sa Sounds';

  @override
  String get soundsAlreadySavedToLibrary => 'Nasa Sounds na';

  @override
  String get soundsSavedLibraryTitle => 'My Sounds';

  @override
  String get soundsSavedEmptyTitle => 'Wala pang naka-save na sound';

  @override
  String get soundsSavedEmptyDescription =>
      'I-tap ang Use Sound sa isang video para i-save ito dito.';

  @override
  String get soundsAvailabilityPrivate => 'Pribado';

  @override
  String get soundsAvailabilityCommunity => 'Komunidad';

  @override
  String get soundsRemoveSavedSound => 'Alisin ang sound';

  @override
  String get soundsRemovedFromLibrary => 'Naalis sa Sounds';

  @override
  String get soundsFailedToLoad => 'Hindi na-load ang sounds';

  @override
  String get soundsRetry => 'Subukan ulit';

  @override
  String get soundsScreenLabel => 'Sounds screen';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileRefresh => 'I-refresh';

  @override
  String get profileRefreshLabel => 'I-refresh ang profile';

  @override
  String get profileMoreOptions => 'Iba pang opsyon';

  @override
  String profileBlockedUser(String name) {
    return 'Na-block si $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Na-unblock si $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Na-unfollow si $name';
  }

  @override
  String profileError(String error) {
    return 'Error: $error';
  }

  @override
  String get notificationsTabAll => 'Lahat';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Comments';

  @override
  String get notificationsTabFollows => 'Follows';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Hindi na-load ang notifications';

  @override
  String get notificationsRetry => 'Subukan ulit';

  @override
  String get notificationsCheckingNew =>
      'tinitingnan kung may bagong notifications';

  @override
  String get notificationsNoneYet => 'Wala pang notifications';

  @override
  String notificationsNoneForType(String type) {
    return 'Walang $type na notifications';
  }

  @override
  String get notificationsEmptyDescription =>
      'Kapag may nag-interact sa content mo, makikita mo dito';

  @override
  String get notificationsUnreadPrefix => 'Hindi pa nababasang notification';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Tingnan ang profile ni $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel =>
      'Tingnan ang mga profile';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Thumbnail ng video para sa $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Thumbnail ng video';

  @override
  String notificationsLoadingType(String type) {
    return 'Nilo-load ang $type na notifications...';
  }

  @override
  String get notificationsInviteSingular =>
      'May 1 ka pang invite na puwedeng i-share sa kaibigan!';

  @override
  String notificationsInvitePlural(int count) {
    return 'May $count ka pang invites na puwedeng i-share sa mga kaibigan!';
  }

  @override
  String get notificationsVideoNotFound => 'Hindi nahanap ang video';

  @override
  String get notificationsVideoUnavailable => 'Hindi available ang video';

  @override
  String get notificationsFromNotification => 'Mula sa Notification';

  @override
  String get feedFailedToLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get feedRetry => 'Subukan ulit';

  @override
  String get feedNoFollowedUsers =>
      'Wala kang fino-follow.\nMag-follow ng tao para makita ang kanilang mga video dito.';

  @override
  String get feedModeForYou => 'Para Sa Iyo';

  @override
  String get feedModeNew => 'Bago';

  @override
  String get feedModeFollowing => 'Fino-follow';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Mode ng feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'May-akda ng video: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar ng may-akda';

  @override
  String get feedForYouEmpty =>
      'Walang laman ang For You feed mo.\nMag-explore ng video at mag-follow ng creators para mahubog ito.';

  @override
  String get feedFollowingEmpty =>
      'Wala pang video mula sa mga taong fino-follow mo.\nHumanap ng creators na gusto mo at i-follow sila.';

  @override
  String get feedLatestEmpty => 'Wala pang bagong video.\nBumalik mamaya.';

  @override
  String get feedExploreVideos => 'Mag-explore ng Video';

  @override
  String get feedExternalVideoSlow => 'Mabagal nag-lo-load ang external video';

  @override
  String get feedSkip => 'Laktawan';

  @override
  String get uploadWaitingToUpload => 'Naghihintay i-upload';

  @override
  String get uploadUploadingVideo => 'Nag-u-upload ng video';

  @override
  String get uploadProcessingVideo => 'Pino-process ang video';

  @override
  String get uploadProcessingComplete => 'Tapos na ang processing';

  @override
  String get uploadPublishedSuccessfully => 'Matagumpay na na-publish';

  @override
  String get uploadFailed => 'Hindi nag-upload';

  @override
  String get uploadRetrying => 'Sinusubukan ulit i-upload';

  @override
  String get uploadPaused => 'Naka-pause ang upload';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% tapos na';
  }

  @override
  String get uploadQueuedMessage => 'Naka-queue ang video mo para i-upload';

  @override
  String get uploadUploadingMessage => 'Nag-u-upload sa server...';

  @override
  String get uploadProcessingMessage =>
      'Pino-process ang video - maaaring tumagal ng ilang minuto';

  @override
  String get uploadReadyToPublishMessage =>
      'Matagumpay na na-process ang video at handa nang i-publish';

  @override
  String get uploadPublishedMessage => 'Na-publish na ang video sa profile mo';

  @override
  String get uploadFailedMessage => 'Hindi nag-upload - subukan ulit';

  @override
  String get uploadRetryingMessage => 'Sinusubukan ulit i-upload...';

  @override
  String get uploadPausedMessage => 'Naka-pause ang upload ng user';

  @override
  String get uploadRetryButton => 'SUBUKAN ULIT';

  @override
  String uploadRetryFailed(String error) {
    return 'Hindi nasubukan ulit i-upload: $error';
  }

  @override
  String get userSearchPrompt => 'Maghanap ng users';

  @override
  String get userSearchNoResults => 'Walang nahanap na user';

  @override
  String get userSearchFailed => 'Hindi nahanap';

  @override
  String get userPickerSearchByName => 'Hanapin ayon sa pangalan';

  @override
  String get userPickerFilterByNameHint => 'I-filter ayon sa pangalan...';

  @override
  String get userPickerSearchByNameHint => 'Hanapin ayon sa pangalan...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return 'Naidagdag na si $name';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Piliin si $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Remove $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Naghihintay sa iyo ang crew mo';

  @override
  String get userPickerEmptyFollowListBody =>
      'Mag-follow ng mga taong vibe mo. Kapag nag-follow back sila, puwede kayong mag-collab.';

  @override
  String get userPickerGoBack => 'Bumalik';

  @override
  String get userPickerTypeNameToSearch => 'Mag-type ng pangalan para maghanap';

  @override
  String get userPickerUnavailable =>
      'Hindi available ang user search. Subukan ulit mamaya.';

  @override
  String get userPickerSearchFailedTryAgain => 'Hindi nahanap. Subukan ulit.';

  @override
  String get forgotPasswordTitle => 'I-reset ang Password';

  @override
  String get forgotPasswordDescription =>
      'Ilagay ang iyong email address at magpapadala kami ng link para i-reset ang password mo.';

  @override
  String get forgotPasswordEmailLabel => 'Email Address';

  @override
  String get forgotPasswordCancel => 'Kanselahin';

  @override
  String get forgotPasswordSendLink => 'I-email ang Reset Link';

  @override
  String get ageVerificationContentWarning => 'Babala sa Content';

  @override
  String get ageVerificationTitle => 'Pagpapatunay ng Edad';

  @override
  String get ageVerificationAdultDescription =>
      'Na-flag ang content na ito bilang posibleng may adult material. Kailangan kang 18 taong gulang o mas matanda para mapanood ito.';

  @override
  String get ageVerificationCreationDescription =>
      'Para gamitin ang camera at gumawa ng content, kailangan kang 16 taong gulang o mas matanda.';

  @override
  String get ageVerificationAdultQuestion =>
      '18 taong gulang ka na ba o mas matanda?';

  @override
  String get ageVerificationCreationQuestion =>
      '16 taong gulang ka na ba o mas matanda?';

  @override
  String get ageVerificationNo => 'Hindi';

  @override
  String get ageVerificationYes => 'Oo';

  @override
  String get shareLinkCopied => 'Nakopya ang link sa clipboard';

  @override
  String get shareFailedToCopy => 'Hindi nakopya ang link';

  @override
  String get shareVideoSubject => 'Tingnan mo ang video na ito sa Divine';

  @override
  String get shareFailedToShare => 'Hindi na-share';

  @override
  String get shareVideoTitle => 'I-share ang Video';

  @override
  String get shareToApps => 'I-share sa Apps';

  @override
  String get shareToAppsSubtitle => 'I-share via messaging, social apps';

  @override
  String get shareCopyWebLink => 'Kopyahin ang Web Link';

  @override
  String get shareCopyWebLinkSubtitle => 'Kopyahin ang shareable na web link';

  @override
  String get shareCopyNostrLink => 'Kopyahin ang Nostr Link';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Kopyahin ang nevent link para sa Nostr clients';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSearch => 'Hanapin';

  @override
  String get navSearchTooltip => 'Hanapin';

  @override
  String get navMyProfile => 'Profile Ko';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navOpenCamera => 'Buksan ang camera';

  @override
  String get navUnknown => 'Hindi alam';

  @override
  String get navExploreClassics => 'Classics';

  @override
  String get navExploreNewVideos => 'Bagong Video';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Para Sa Iyo';

  @override
  String get navExploreLists => 'Mga Listahan';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Invalid na hashtag';

  @override
  String get routeInvalidConversationId => 'Invalid na conversation ID';

  @override
  String get routeInvalidRequestId => 'Invalid na request ID';

  @override
  String get routeInvalidListId => 'Invalid na list ID';

  @override
  String get routeInvalidUserId => 'Invalid na user ID';

  @override
  String get routeInvalidVideoId => 'Invalid na video ID';

  @override
  String get routeInvalidSoundId => 'Invalid na sound ID';

  @override
  String get routeInvalidCategory => 'Invalid na category';

  @override
  String get routeNoVideosToDisplay => 'Walang video na maipapakita';

  @override
  String get routeInvalidProfileId => 'Invalid na profile ID';

  @override
  String get routeUnknownPath => 'Wala ang page na iyon sa app.';

  @override
  String get routeDefaultListName => 'Listahan';

  @override
  String get supportTitle => 'Support Center';

  @override
  String get supportContactSupport => 'Makipag-ugnayan sa Support';

  @override
  String get supportContactSupportSubtitle =>
      'Magsimula ng usapan o tingnan ang mga lumang mensahe';

  @override
  String get supportReportBug => 'Mag-report ng Bug';

  @override
  String get supportReportBugSubtitle => 'Mga technical issue sa app';

  @override
  String get supportRequestFeature => 'Humiling ng Feature';

  @override
  String get supportRequestFeatureSubtitle =>
      'Magmungkahi ng improvement o bagong feature';

  @override
  String get supportSaveLogs => 'I-save ang Logs';

  @override
  String get supportSaveLogsSubtitle =>
      'I-export ang logs sa file para manual na maipadala';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Mga karaniwang tanong at sagot';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Alamin ang tungkol sa verification at authenticity';

  @override
  String get supportLoginRequired =>
      'Mag-log in para makipag-ugnayan sa support';

  @override
  String get supportExportingLogs => 'Nag-e-export ng logs...';

  @override
  String get supportExportLogsFailed => 'Hindi na-export ang logs';

  @override
  String supportLogsSavedTo(String path) {
    return 'Na-save ang logs sa $path';
  }

  @override
  String get supportRevealLogsAction => 'Ipakita sa folder';

  @override
  String get supportChatNotAvailable => 'Hindi available ang support chat';

  @override
  String get supportCouldNotOpenMessages =>
      'Hindi nabuksan ang support messages';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Hindi nabuksan ang $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Error sa pagbukas ng $pageName: $error';
  }

  @override
  String get reportTitle => 'I-report ang Content';

  @override
  String get reportWhyReporting => 'Bakit mo rine-report ang content na ito?';

  @override
  String get reportPolicyNotice =>
      'Aaksyunan ng Divine ang mga content report sa loob ng 24 oras sa pamamagitan ng pag-alis ng content at pag-eject sa user na nagbigay ng masamang content.';

  @override
  String get reportAdditionalDetails => 'Karagdagang detalye (opsyonal)';

  @override
  String get reportBlockUser => 'I-block ang user na ito';

  @override
  String get reportCancel => 'Kanselahin';

  @override
  String get reportSubmit => 'I-report';

  @override
  String get reportSelectReason =>
      'Pumili ng dahilan para i-report ang content na ito';

  @override
  String get reportOtherRequiresDetails =>
      'Pakilarawan ang isyu kapag pumili ka ng Iba pa';

  @override
  String get reportDetailsRequired => 'Pakilarawan ang isyu';

  @override
  String get reportReasonSpam => 'Spam o Hindi Gustong Content';

  @override
  String get reportReasonSpamSubtitle =>
      'Hindi gustong o paulit-ulit na content';

  @override
  String get reportReasonHarassment => 'Harassment, Bullying, o Pagbabanta';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Nakakapinsala at hindi gustong reply o mention';

  @override
  String get reportReasonViolence => 'Marahas o Extremist na Content';

  @override
  String get reportReasonViolenceSubtitle =>
      'Marahas, extremist, o nakakapinsalang content';

  @override
  String get reportReasonSexualContent => 'Sekswal o Adult na Content';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Hubad, porn, o explicit na content';

  @override
  String get reportReasonCopyright => 'Paglabag sa Copyright';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Hindi awtorisadong paggamit ng intellectual property';

  @override
  String get reportReasonFalseInfo => 'Maling Impormasyon';

  @override
  String get reportReasonFalseInfoSubtitle => 'Mapanlinlang o maling claim';

  @override
  String get reportReasonChildSafety => 'Child Safety Violation';

  @override
  String get reportReasonChildSafetySubtitle =>
      'General concerns about minors\' safety';

  @override
  String get reportReasonCsam => 'Child Sexual Abuse';

  @override
  String get reportReasonCsamSubtitle =>
      'Content depicting sexual abuse of minors';

  @override
  String get reportReasonUnderageUser => 'User Appears Under 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Account holder appears to be underage';

  @override
  String get reportReasonAiGenerated => 'AI-Generated na Content';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Pinaghihinalaang AI-generated content';

  @override
  String get reportReasonOther => 'Iba pang Paglabag sa Patakaran';

  @override
  String get reportReasonOtherSubtitle =>
      'Mga paglabag na hindi nakalista sa itaas';

  @override
  String reportFailed(Object error) {
    return 'Hindi na-report ang content: $error';
  }

  @override
  String get reportReceivedTitle => 'Natanggap ang Report';

  @override
  String get reportReceivedThankYou =>
      'Salamat sa pagtulong panatilihing ligtas ang Divine.';

  @override
  String get reportReceivedReviewNotice =>
      'Susuriin ng team namin ang report mo at gagawa ng naaangkop na aksyon. Maaari kang makatanggap ng updates via direct message.';

  @override
  String get reportLearnMore => 'Alamin Pa';

  @override
  String get reportLearnMoreAt => 'Alamin pa sa';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Isara';

  @override
  String get listAddToList => 'Idagdag sa Listahan';

  @override
  String listVideoCount(int count) {
    return '$count mga video';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tao',
      one: '1 tao',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Ni ';

  @override
  String get listNewList => 'Bagong Listahan';

  @override
  String get listDone => 'Tapos na';

  @override
  String get listErrorLoading => 'Error sa pag-load ng listahan';

  @override
  String listRemovedFrom(String name) {
    return 'Inalis sa $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Naidagdag sa $name';
  }

  @override
  String get listCreateNewList => 'Gumawa ng Bagong Listahan';

  @override
  String get listNewPeopleList => 'Bagong people list';

  @override
  String get listCollaboratorsNone => 'Wala';

  @override
  String get listAddCollaboratorTitle => 'Magdagdag ng collaborator';

  @override
  String get listCollaboratorSearchHint => 'Maghanap sa diVine...';

  @override
  String get listNameLabel => 'Pangalan ng Listahan';

  @override
  String get listDescriptionLabel => 'Description (opsyonal)';

  @override
  String get listPublicList => 'Public na Listahan';

  @override
  String get listPublicListSubtitle =>
      'Puwedeng i-follow at makita ng iba ang listahang ito';

  @override
  String get listCancel => 'Kanselahin';

  @override
  String get listCreate => 'Gumawa';

  @override
  String get listCreateFailed => 'Hindi nagawa ang listahan';

  @override
  String get keyManagementTitle => 'Nostr Keys';

  @override
  String get keyManagementWhatAreKeys => 'Ano ang Nostr keys?';

  @override
  String get keyManagementExplanation =>
      'Ang iyong Nostr identity ay isang cryptographic key pair:\n\n• Ang public key mo (npub) ay parang username mo - puwede mong i-share nang malaya\n• Ang private key mo (nsec) ay parang password mo - itago mo ito!\n\nAng nsec mo ang magbibigay sa iyo ng access sa account mo sa anumang Nostr app.';

  @override
  String get keyManagementImportTitle => 'Mag-import ng Existing na Key';

  @override
  String get keyManagementImportSubtitle =>
      'May Nostr account ka na? I-paste ang private key mo (nsec) para ma-access dito.';

  @override
  String get keyManagementImportButton => 'Mag-import ng Key';

  @override
  String get keyManagementImportWarning => 'Papalitan nito ang current key mo!';

  @override
  String get keyManagementBackupTitle => 'I-backup ang Key Mo';

  @override
  String get keyManagementBackupSubtitle =>
      'I-save ang private key mo (nsec) para magamit ang account mo sa ibang Nostr apps.';

  @override
  String get keyManagementCopyNsec => 'Kopyahin ang Private Key Ko (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Huwag i-share ang nsec mo sa kahit kanino!';

  @override
  String get keyManagementPasteKey => 'Pakipasta ang private key mo';

  @override
  String get keyManagementInvalidFormat =>
      'Invalid na format ng key. Kailangang mag-umpisa sa \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'I-import ang Key na Ito?';

  @override
  String get keyManagementConfirmImportBody =>
      'Papalitan nito ang kasalukuyang identity mo ng na-import.\n\nMawawala ang current key mo maliban kung na-backup mo na muna.';

  @override
  String get keyManagementImportConfirm => 'I-import';

  @override
  String get keyManagementImportSuccess => 'Matagumpay na na-import ang key!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Hindi na-import ang key: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Nakopya ang private key sa clipboard!\n\nItago ito sa ligtas na lugar.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Hindi na-export ang key: $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Ang public key mo (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Kopyahin ang public key';

  @override
  String get keyManagementPublicKeyCopied => 'Nakopya ang public key';

  @override
  String get profileEditPublicKeyLink => 'Tingnan ang public key mo';

  @override
  String get saveOriginalSavedToCameraRoll => 'Na-save sa Camera Roll';

  @override
  String get saveOriginalShare => 'I-share';

  @override
  String get saveOriginalDone => 'Tapos na';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Kailangan ng Access sa Photos';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Para mag-save ng video, payagan ang access sa Photos sa Settings.';

  @override
  String get saveOriginalOpenSettings => 'Buksan ang Settings';

  @override
  String get saveOriginalNotNow => 'Hindi muna';

  @override
  String get cameraPermissionNotNow => 'Hindi muna';

  @override
  String get saveOriginalDownloadFailed => 'Hindi Nag-download';

  @override
  String get saveOriginalDismiss => 'Isantabi';

  @override
  String get saveOriginalDownloadingVideo => 'Nagda-download ng Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Sini-save sa Camera Roll';

  @override
  String get saveOriginalFetchingVideo =>
      'Kinukuha ang video mula sa network...';

  @override
  String get saveOriginalSavingVideo =>
      'Sini-save ang original na video sa camera roll mo...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Original na sound';

  @override
  String get soundVideosUsingThisSound =>
      'Mga video na gumagamit ng sound na ito';

  @override
  String get soundSourceVideo => 'Source video';

  @override
  String get soundNoVideosYet => 'Wala pang video';

  @override
  String get soundBeFirstToUse => 'Maging unang gumamit ng sound na ito!';

  @override
  String get soundFailedToLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get soundRetry => 'Subukan ulit';

  @override
  String get soundVideosUnavailable => 'Hindi available ang mga video';

  @override
  String get soundCouldNotLoadDetails => 'Hindi na-load ang detalye ng video';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundStop => 'Itigil';

  @override
  String get soundUseSound => 'Gamitin ang Sound';

  @override
  String get soundUntitled => 'Sound na walang pamagat';

  @override
  String get soundStopPreview => 'Itigil ang preview';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'I-preview ang $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Tingnan ang details para sa $title';
  }

  @override
  String get soundNoVideoCount => 'Wala pang video';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count mga video';
  }

  @override
  String get soundUnableToPreview =>
      'Hindi ma-preview ang sound - walang available na audio';

  @override
  String soundPreviewFailed(Object error) {
    return 'Hindi na-play ang preview: $error';
  }

  @override
  String get soundViewSource => 'Tingnan ang source';

  @override
  String get soundCloseTooltip => 'Isara';

  @override
  String get exploreNotExploreRoute => 'Hindi explore route';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalTermsOfServiceSubtitle =>
      'Mga terms at kondisyon ng paggamit';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalPrivacyPolicySubtitle => 'Paano namin ina-handle ang data mo';

  @override
  String get legalSafetyStandards => 'Safety Standards';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Mga community guidelines at kaligtasan';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Patakaran sa copyright at takedown';

  @override
  String get legalOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Mga attribution sa third-party packages';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Hindi nabuksan ang $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Error sa pagbukas ng $pageName: $error';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Adventure';

  @override
  String get categoryAnimals => 'Mga Hayop';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Arkitektura';

  @override
  String get categoryArt => 'Sining';

  @override
  String get categoryAutomotive => 'Automotive';

  @override
  String get categoryAwardShow => 'Award Show';

  @override
  String get categoryAwards => 'Mga Award';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basketball';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Inumin';

  @override
  String get categoryCars => 'Mga Sasakyan';

  @override
  String get categoryCelebration => 'Pagdiriwang';

  @override
  String get categoryCelebrities => 'Mga Celebrity';

  @override
  String get categoryCelebrity => 'Celebrity';

  @override
  String get categoryCityscape => 'Cityscape';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Konsiyerto';

  @override
  String get categoryCooking => 'Pagluluto';

  @override
  String get categoryCostume => 'Kostyum';

  @override
  String get categoryCrafts => 'Crafts';

  @override
  String get categoryCrime => 'Krimen';

  @override
  String get categoryCulture => 'Kultura';

  @override
  String get categoryDance => 'Sayaw';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Edukasyon';

  @override
  String get categoryEmotional => 'Emotional';

  @override
  String get categoryEmotions => 'Mga Damdamin';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Pamilya';

  @override
  String get categoryFans => 'Mga Fan';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Estilo';

  @override
  String get categoryFestival => 'Pista';

  @override
  String get categoryFilm => 'Pelikula';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Pagkain';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Muwebles';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Grooming';

  @override
  String get categoryGuitar => 'Gitara';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Kalusugan';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Holiday';

  @override
  String get categoryHome => 'Bahay';

  @override
  String get categoryHomeImprovement => 'Home Improvement';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Ospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Interior Design';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Mga Bata';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magic';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryMedical => 'Medikal';

  @override
  String get categoryMusic => 'Musika';

  @override
  String get categoryMystery => 'Misteryo';

  @override
  String get categoryNature => 'Kalikasan';

  @override
  String get categoryNews => 'Balita';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Party';

  @override
  String get categoryPeople => 'Mga Tao';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Mga Alagang Hayop';

  @override
  String get categoryPolitics => 'Pulitika';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Mga Prank';

  @override
  String get categoryRealityShow => 'Reality Show';

  @override
  String get categoryRelationship => 'Relasyon';

  @override
  String get categoryRelationships => 'Mga Relasyon';

  @override
  String get categoryRomance => 'Romansa';

  @override
  String get categorySchool => 'Eskwela';

  @override
  String get categoryScienceFiction => 'Science Fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Skincare';

  @override
  String get categorySoccer => 'Soccer';

  @override
  String get categorySocialGathering => 'Pagtitipon';

  @override
  String get categorySocialMedia => 'Social Media';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryTalkShow => 'Talk Show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Teknolohiya';

  @override
  String get categoryTelevision => 'Telebisyon';

  @override
  String get categoryToys => 'Mga Laruan';

  @override
  String get categoryTransportation => 'Transportasyon';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Karahasan';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged =>
      'Na-upload na — i-tap ang I-save para ilapat';

  @override
  String inboxReportedUser(String displayName) {
    return 'Na-report si $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Na-block si $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Na-unblock si $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Inalis ang conversation';

  @override
  String get inboxEmptyTitle => 'Wala pang messages';

  @override
  String get inboxEmptySubtitle => 'Hindi ka kakagatin ng + button na \'yan.';

  @override
  String get inboxActionMute => 'I-mute ang conversation';

  @override
  String inboxActionReport(String displayName) {
    return 'I-report si $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'I-block si $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'I-unblock si $displayName';
  }

  @override
  String get inboxActionRemove => 'Alisin ang conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Alisin ang conversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Bubura nito ang conversation mo kay $displayName. Hindi na ito mababawi.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Alisin';

  @override
  String get inboxConversationMuted => 'Na-mute ang conversation';

  @override
  String get inboxConversationUnmuted => 'Na-unmute ang conversation';

  @override
  String get inboxCollabInviteCardTitle => 'Imbitasyon bilang collaborator';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role sa post na ito';
  }

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Video na walang pamagat';

  @override
  String get clickableTextViewVideoLink => 'Tingnan ang video';

  @override
  String get messageExternalLinkDialogTitle => 'Buksan ang external na link?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Papunta ang link na ito sa isang external na site at baka hindi ito ligtas:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Buksan';

  @override
  String get inboxCollabInviteAcceptButton => 'Tanggapin';

  @override
  String get inboxCollabInviteIgnoreButton => 'Balewalain';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Tinanggap';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Binalewala';

  @override
  String get inboxCollabInviteAcceptError => 'Hindi natanggap. Subukan ulit.';

  @override
  String get inboxCollabInviteSentStatus => 'Naipadala ang imbitasyon';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Imbitasyon bilang collaborator';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'In-imbita ka bilang collaborator sa $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'In-imbita ka bilang collaborator sa isang video: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String get dmSendFailedMessage => 'Hindi naipadala ang message';

  @override
  String get dmSendFailedRetry => 'Subukan ulit';

  @override
  String get dmSendPartialMessage =>
      'Naipadala, pero hindi nag-sync sa iba mong device';

  @override
  String get dmConversationLoadError => 'Hindi na-load ang mga message';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => 'Sent message';

  @override
  String get dmMessageBubbleReceivedHint => 'Received message';

  @override
  String get dmMessageBubbleLongPressHint => 'Message actions';

  @override
  String get dmMessageActionCopyText => 'Copy text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copy video URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Delete for everyone';

  @override
  String get dmMessageActionReport => 'Report';

  @override
  String get inboxConversationActionsSheetLabel => 'Conversation actions';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName conversation';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Show conversation actions';

  @override
  String get reportDialogCancel => 'Cancel';

  @override
  String get reportDialogReport => 'I-report';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Title: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Maghanap...';

  @override
  String categoryVideoCount(String count) {
    return '$count na video';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Hindi na-update ang subscription: $error';
  }

  @override
  String get discoverListsTitle => 'Tuklasin ang mga Listahan';

  @override
  String get discoverListsFailedToLoad => 'Hindi na-load ang mga listahan';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Hindi na-load ang mga listahan: $error';
  }

  @override
  String get discoverListsLoading => 'Naghahanap ng mga public list...';

  @override
  String get discoverListsEmptyTitle => 'Walang nakitang public list';

  @override
  String get discoverListsEmptySubtitle =>
      'Bumalik mamaya para sa mga bagong listahan';

  @override
  String get discoverListsByAuthorPrefix => 'ni';

  @override
  String get curatedListEmptyTitle => 'Walang video sa listahang ito';

  @override
  String get curatedListEmptySubtitle =>
      'Magdagdag ng mga video para magsimula';

  @override
  String get curatedListLoadingVideos => 'Naglo-load ng mga video...';

  @override
  String get curatedListFailedToLoad => 'Hindi na-load ang listahan';

  @override
  String get curatedListNoVideosAvailable => 'Walang available na video';

  @override
  String get curatedListVideoNotAvailable => 'Hindi available ang video';

  @override
  String get commonRetry => 'Subukan ulit';

  @override
  String get commonNext => 'Susunod';

  @override
  String get commonDelete => 'Burahin';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonBack => 'Bumalik';

  @override
  String get commonClose => 'Isara';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Couldn\'t update the cover. Try again.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Cover updated';

  @override
  String get videoMetadataTags => 'Mga Tag';

  @override
  String get videoMetadataExpiration => 'Pag-expire';

  @override
  String get videoMetadataExpirationNotExpire => 'Hindi mag-e-expire';

  @override
  String get videoMetadataExpirationOneDay => '1 araw';

  @override
  String get videoMetadataExpirationOneWeek => '1 linggo';

  @override
  String get videoMetadataExpirationOneMonth => '1 buwan';

  @override
  String get videoMetadataExpirationOneYear => '1 taon';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekada';

  @override
  String get videoMetadataContentWarnings => 'Mga Babala sa Content';

  @override
  String get videoEditorStickers => 'Mga Sticker';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get proofmodeCheckAiGenerated => 'Tingnan kung AI-generated';

  @override
  String get libraryDeleteConfirm => 'Burahin';

  @override
  String get libraryWebUnavailableHeadline =>
      'Available ang Library sa mobile app';

  @override
  String get libraryWebUnavailableDescription =>
      'Naka-save sa device mo ang mga draft at clip, kaya buksan ang Divine sa phone mo para i-manage ang mga ito.';

  @override
  String get libraryTabDrafts => 'Mga Draft';

  @override
  String get libraryTabClips => 'Mga Clip';

  @override
  String get librarySaveToCameraRollTooltip => 'I-save sa camera roll';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Burahin ang mga napiling clip';

  @override
  String get librarySelect => 'Piliin';

  @override
  String get librarySortNewestCreation => 'Pinakabagong ginawa';

  @override
  String get librarySortOldestCreation => 'Pinakalumang ginawa';

  @override
  String get librarySortLongestClip => 'Pinakamahabang clip';

  @override
  String get librarySortShortestClip => 'Pinakamaikling clip';

  @override
  String get librarySortSquareFirst => 'Unahin ang parisukat';

  @override
  String get librarySortVerticalFirst => 'Unahin ang patayo';

  @override
  String get libraryDeleteClipsTitle => 'Burahin ang mga Clip';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# napiling clip',
      one: '# napiling clip',
    );
    return 'Sigurado ka bang gusto mong burahin ang $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Hindi na ito mababawi. Permanenteng maaalis sa device mo ang mga video file.';

  @override
  String get libraryPreparingVideo => 'Hinahanda ang video...';

  @override
  String get libraryCreateVideo => 'Gumawa ng Video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '1 clip',
    );
    return '$_temp0 na-save sa $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount na-save, $failureCount ang nabigo';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Tinanggihan ang permission para sa $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip ang nabura',
      one: '1 clip ang nabura',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Hindi na-load ang mga draft';

  @override
  String get libraryCouldNotLoadClips => 'Hindi na-load ang mga clip';

  @override
  String get libraryOpenErrorDescription =>
      'May nangyaring problema habang binubuksan ang library mo. Pwede mong subukan ulit.';

  @override
  String get libraryNoDraftsYetTitle => 'Wala Pang Draft';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Lalabas dito ang mga video na ise-save mo bilang draft';

  @override
  String get libraryNoClipsYetTitle => 'Wala Pang Clip';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Lalabas dito ang mga na-record mong video clip';

  @override
  String get libraryDraftDeletedSnackbar => 'Nabura ang draft';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Hindi nabura ang draft';

  @override
  String get libraryDraftActionPost => 'I-post';

  @override
  String get libraryDraftActionEdit => 'I-edit';

  @override
  String get libraryDraftActionDelete => 'Burahin ang draft';

  @override
  String get libraryDeleteDraftTitle => 'Burahin ang Draft';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Sigurado ka bang gusto mong burahin ang \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Burahin ang Clip';

  @override
  String get libraryDeleteClipMessage =>
      'Sigurado ka bang gusto mong burahin ang clip na ito?';

  @override
  String get libraryClipSelectionTitle => 'Mga Clip';

  @override
  String librarySecondsRemaining(String seconds) {
    return '${seconds}s ang natitira';
  }

  @override
  String get libraryAddClips => 'Idagdag';

  @override
  String get libraryRecordVideo => 'Mag-record ng Video';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Video clip, $duration segundo';
  }

  @override
  String get videoClipSemanticValueSelected => 'Napili';

  @override
  String get videoClipSemanticValueNotSelected => 'Hindi napili';

  @override
  String get videoClipSemanticHintDisabled => 'Hindi pinagana';

  @override
  String get videoClipSemanticHintSelect =>
      'I-tap para piliin, pindutin nang matagal para i-preview';

  @override
  String get videoClipSemanticHintDeselect =>
      'I-tap para alisin ang pagpili, pindutin nang matagal para i-preview';

  @override
  String get routerInvalidCreator => 'Invalid na creator';

  @override
  String get routerInvalidHashtagRoute => 'Invalid na hashtag route';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Hindi na-load ang mga video';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Walang video sa category na ito';

  @override
  String get categoryGallerySortOptionsLabel => 'Mga sort option ng category';

  @override
  String get categoryGallerySortHot => 'Hot';

  @override
  String get categoryGallerySortNew => 'Bago';

  @override
  String get categoryGallerySortClassic => 'Classic';

  @override
  String get categoryGallerySortForYou => 'Para Sa\'yo';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Hindi na-load ang mga category';

  @override
  String get categoriesNoCategoriesAvailable => 'Walang available na category';

  @override
  String get notificationsEmptyTitle => 'Wala pang activity';

  @override
  String get notificationsEmptySubtitle =>
      'Kapag nag-interact ang mga tao sa content mo, makikita mo dito';

  @override
  String get appsPermissionsTitle => 'Mga Integration Permission';

  @override
  String get appsPermissionsRevoke => 'I-revoke';

  @override
  String get appsPermissionsEmptyTitle =>
      'Walang naka-save na integration permission';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Lalabas dito ang mga approved integration kapag may na-remember kang access approval.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return 'Hinihingi ng $appName ang pag-apruba mo';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Humihingi ng access ang app na ito gamit ang vetted sandbox ng Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origin';

  @override
  String get nostrAppPermissionMethod => 'Method';

  @override
  String get nostrAppPermissionCapability => 'Capability';

  @override
  String get nostrAppPermissionEventKind => 'Event kind';

  @override
  String get nostrAppPermissionAllow => 'Payagan';

  @override
  String get bugReportSendReport => 'Ipadala ang Report';

  @override
  String get supportSubjectRequiredLabel => 'Subject *';

  @override
  String get supportRequiredHelper => 'Kailangan';

  @override
  String get bugReportSubjectHint => 'Maikling buod ng problema';

  @override
  String get bugReportDescriptionRequiredLabel => 'Ano\'ng nangyari? *';

  @override
  String get bugReportDescriptionHint =>
      'I-describe ang problemang naranasan mo';

  @override
  String get bugReportStepsLabel => 'Mga Hakbang Para Maulit';

  @override
  String get bugReportStepsHint =>
      '1. Pumunta sa...\n2. I-tap ang...\n3. Lalabas ang error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Inaasahang Behavior';

  @override
  String get bugReportExpectedBehaviorHint => 'Ano sana dapat ang nangyari?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Awtomatikong isasama ang device info at logs.';

  @override
  String get bugReportSuccessMessage =>
      'Salamat! Natanggap namin ang report mo at gagamitin namin ito para mas gumanda ang Divine.';

  @override
  String get bugReportAttachImages => 'Attach images';

  @override
  String bugReportImagesCount(int count, int max) {
    return '$count of $max images selected';
  }

  @override
  String get bugReportRemoveImage => 'Remove image';

  @override
  String get bugReportUploadFailed =>
      'We couldn\'t upload the selected image. Try again or send the report without it.';

  @override
  String get bugReportSendFailed =>
      'Hindi naipadala ang bug report. Subukan ulit mamaya.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Hindi naipadala ang bug report: $error';
  }

  @override
  String get featureRequestSendRequest => 'Ipadala ang Request';

  @override
  String get featureRequestSubjectHint => 'Maikling buod ng idea mo';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Ano ang gusto mo? *';

  @override
  String get featureRequestDescriptionHint =>
      'I-describe ang feature na gusto mo';

  @override
  String get featureRequestUsefulnessLabel =>
      'Paano ito magiging kapaki-pakinabang?';

  @override
  String get featureRequestUsefulnessHint =>
      'Ipaliwanag kung anong benepisyo ang maibibigay ng feature na ito';

  @override
  String get featureRequestWhenLabel => 'Kailan mo ito gagamitin?';

  @override
  String get featureRequestWhenHint =>
      'I-describe ang mga sitwasyon kung saan makakatulong ito';

  @override
  String get featureRequestSuccessMessage =>
      'Salamat! Natanggap namin ang feature request mo at irereview namin ito.';

  @override
  String get featureRequestSendFailed =>
      'Hindi naipadala ang feature request. Subukan ulit mamaya.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Hindi naipadala ang feature request: $error';
  }

  @override
  String get notificationFollowBack => 'I-follow back';

  @override
  String get followingTitle => 'Fino-follow';

  @override
  String followingTitleForName(String displayName) {
    return 'Fino-follow ni $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Hindi na-load ang following list';

  @override
  String get followingEmptyTitle => 'Wala ka pang fino-follow';

  @override
  String get followersTitle => 'Mga Follower';

  @override
  String followersTitleForName(String displayName) {
    return 'Mga Follower ni $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Hindi na-load ang followers list';

  @override
  String get followersEmptyTitle => 'Wala pang follower';

  @override
  String get followersUpdateFollowFailed =>
      'Hindi na-update ang follow status. Subukan ulit.';

  @override
  String get reportMessageTitle => 'I-report ang Message';

  @override
  String get reportMessageWhyReporting =>
      'Bakit mo nire-report ang message na ito?';

  @override
  String get reportMessageSelectReason =>
      'Pumili ng dahilan para sa pag-report ng message na ito';

  @override
  String get newMessageTitle => 'Bagong message';

  @override
  String get newMessageFindPeople => 'Maghanap ng tao';

  @override
  String get newMessageNoContacts =>
      'Walang nakitang contact.\nMag-follow ng mga tao para makita sila dito.';

  @override
  String get newMessageNoUsersFound => 'Walang nakitang user';

  @override
  String get hashtagSearchTitle => 'Maghanap ng hashtag';

  @override
  String get hashtagSearchSubtitle => 'Tuklasin ang trending topics at content';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Walang nakitang hashtag para sa \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Nabigo ang paghahanap';

  @override
  String get userNotAvailableTitle => 'Hindi available ang account';

  @override
  String get userNotAvailableBody =>
      'Hindi available ang account na ito ngayon.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Hindi na-save ang settings: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Maglagay ng valid na server URL (hal., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Na-save ang Blossom settings';

  @override
  String get blossomSaveTooltip => 'I-save';

  @override
  String get blossomAboutTitle => 'Tungkol sa Blossom';

  @override
  String get blossomAboutDescription =>
      'Ang Blossom ay isang decentralized media storage protocol na nagpapahintulot sa iyong mag-upload ng video sa anumang compatible server. By default, naka-upload ang mga video sa Blossom server ng Divine. I-enable ang option sa baba para gumamit ng custom server.';

  @override
  String get blossomUseCustomServer => 'Gumamit ng Custom Blossom Server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Mag-u-upload ang mga video sa custom Blossom server mo';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Naka-upload ang mga video mo sa Blossom server ng Divine';

  @override
  String get blossomCustomServerUrl => 'Custom Blossom Server URL';

  @override
  String get blossomCustomServerHelper =>
      'Ilagay ang URL ng custom Blossom server mo';

  @override
  String get blossomPopularServers => 'Mga Popular na Blossom Server';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Dapat gumamit ng https:// ang Blossom server URL';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Hindi na-update ang crosspost setting';

  @override
  String get blueskySignInRequired =>
      'Mag-sign in para i-manage ang Bluesky settings';

  @override
  String get blueskyPublishVideos => 'Mag-publish ng mga video sa Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Ipa-publish ang mga video mo sa Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Hindi ipa-publish ang mga video mo sa Bluesky';

  @override
  String get blueskyHandle => 'Bluesky Handle';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Provisioned at ready na ang account';

  @override
  String get blueskyStatusPending => 'Pino-provision pa ang account...';

  @override
  String get blueskyStatusFailed => 'Nabigo ang provisioning ng account';

  @override
  String get blueskyStatusDisabled => 'Naka-disable ang account';

  @override
  String get blueskyStatusNotLinked => 'Walang Bluesky account na naka-link';

  @override
  String get invitesTitle => 'Mag-invite ng Kaibigan';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invite handa nang i-generate',
      one: '1 invite handa nang i-generate',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'I-generate ang code kapag handa ka nang mag-share.';

  @override
  String get invitesGenerateButtonLabel => 'I-generate ang invite';

  @override
  String get invitesNoneAvailable => 'Walang available na invite ngayon';

  @override
  String get invitesShareWithPeople => 'I-share ang diVine sa mga kakilala mo';

  @override
  String get invitesUsedInvites => 'Mga nagamit na invite';

  @override
  String invitesShareMessage(String code) {
    return 'Sumali sa akin sa diVine! Gamitin ang invite code $code para magsimula:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'I-copy ang invite';

  @override
  String get invitesCopied => 'Na-copy ang invite!';

  @override
  String get invitesShareInvite => 'I-share ang invite';

  @override
  String get invitesShareSubject => 'Sumali sa akin sa diVine';

  @override
  String get invitesClaimed => 'Na-claim';

  @override
  String get invitesCouldNotLoad => 'Hindi na-load ang mga invite';

  @override
  String get invitesRetry => 'Subukan ulit';

  @override
  String get searchSomethingWentWrong => 'May nangyaring problema';

  @override
  String get searchTryAgain => 'Subukan ulit';

  @override
  String get searchForLists => 'Maghanap ng mga list';

  @override
  String get searchFindCuratedVideoLists =>
      'Maghanap ng mga curated na video list';

  @override
  String get searchEnterQuery => 'Maglagay ng search query';

  @override
  String get searchDiscoverSomethingInteresting => 'Tumuklas ng kawili-wili';

  @override
  String get searchPeopleSectionHeader => 'Mga Tao';

  @override
  String get searchPeopleLoadingLabel =>
      'Naglo-load ng mga resulta para sa tao';

  @override
  String get searchTagsSectionHeader => 'Mga Tag';

  @override
  String get searchTagsLoadingLabel => 'Naglo-load ng mga resulta para sa tag';

  @override
  String get searchVideosSectionHeader => 'Mga Video';

  @override
  String get searchVideosLoadingLabel =>
      'Naglo-load ng mga resulta para sa video';

  @override
  String get searchListsSectionHeader => 'Mga List';

  @override
  String get searchListsLoadingLabel =>
      'Naglo-load ng mga resulta para sa list';

  @override
  String get cameraAgeRestriction =>
      'Dapat 16 taong gulang ka pataas para gumawa ng content';

  @override
  String get featureRequestCancel => 'Cancel';

  @override
  String keyImportError(String error) {
    return 'Error: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Dapat gumamit ng wss:// ang bunker relay (pinapayagan lang ang ws:// para sa localhost)';

  @override
  String get timeNow => 'ngayon';

  @override
  String timeShortMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeShortHours(int count) {
    return '${count}h';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}w';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeShortYears(int count) {
    return '${count}y';
  }

  @override
  String get timeVerboseNow => 'Ngayon';

  @override
  String timeAgo(String time) {
    return '$time ang nakaraan';
  }

  @override
  String get timeToday => 'Ngayong araw';

  @override
  String get timeYesterday => 'Kahapon';

  @override
  String get timeJustNow => 'kanina lang';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ang nakaraan';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ang nakaraan';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d ang nakaraan';
  }

  @override
  String get draftTimeJustNow => 'Kanina lang';

  @override
  String get contentLabelNudity => 'Kahubaran';

  @override
  String get contentLabelSexualContent => 'Sekswal na Content';

  @override
  String get contentLabelPornography => 'Pornograpiya';

  @override
  String get contentLabelGraphicMedia => 'Graphic na Media';

  @override
  String get contentLabelViolence => 'Karahasan';

  @override
  String get contentLabelSelfHarm => 'Self-Harm/Suicide';

  @override
  String get contentLabelDrugUse => 'Paggamit ng Droga';

  @override
  String get contentLabelAlcohol => 'Alak';

  @override
  String get contentLabelTobacco => 'Tabako/Paninigarilyo';

  @override
  String get contentLabelGambling => 'Sugal';

  @override
  String get contentLabelProfanity => 'Mura';

  @override
  String get contentLabelHateSpeech => 'Hate Speech';

  @override
  String get contentLabelHarassment => 'Harassment';

  @override
  String get contentLabelFlashingLights => 'Kumikislap na Ilaw';

  @override
  String get contentLabelAiGenerated => 'AI-Generated';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Scam/Pandaraya';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Nakakapagligaw';

  @override
  String get contentLabelSensitiveContent => 'Sensitibong Content';

  @override
  String notificationLikedYourVideo(String actorName) {
    return 'Ni-like ni $actorName ang video mo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return 'Ni-like ni $actorName ang comment mo';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return 'Nag-comment si $actorName sa video mo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return 'Sinimulan kang i-follow ni $actorName';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return 'Binanggit ka ni $actorName';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return 'Na-repost ni $actorName ang video mo';
  }

  @override
  String get notificationRepliedToYourComment => 'nag-reply sa comment mo';

  @override
  String get notificationAndConnector => 'at';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count iba pa',
      one: '1 iba pa',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'May bago kang update';

  @override
  String get notificationSomeoneLikedYourVideo => 'May nag-like sa video mo';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Itago ang keyboard';

  @override
  String get draftUntitled => 'Walang Pamagat';

  @override
  String get contentWarningNone => 'Wala';

  @override
  String get textBackgroundNone => 'Wala';

  @override
  String get textBackgroundSolid => 'Solid';

  @override
  String get textBackgroundHighlight => 'Highlight';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Kaliwa';

  @override
  String get textAlignRight => 'Kanan';

  @override
  String get textAlignCenter => 'Gitna';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Hindi pa supported ang camera sa web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Hindi pa available ang camera capture at recording sa web version.';

  @override
  String get cameraPermissionBackToFeed => 'Bumalik sa feed';

  @override
  String get cameraPermissionErrorTitle => 'Permission Error';

  @override
  String get cameraPermissionErrorDescription =>
      'May nangyaring problema habang sinusuri ang mga permission.';

  @override
  String get cameraPermissionRetry => 'Subukan ulit';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Payagan ang access sa camera at mikropono';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Pinapayagan ka nitong kumuha at mag-edit ng video dito mismo sa app, wala nang iba.';

  @override
  String get cameraPermissionContinue => 'Magpatuloy';

  @override
  String get cameraPermissionGoToSettings => 'Pumunta sa settings';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Bakit anim na segundo?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Ang mabilis na clip ay nagbibigay-daan sa pagiging spontaneous. Ang 6-second format ay tumutulong sa\'yong makuha ang mga authentic na sandali habang nangyayari.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Sige na!';

  @override
  String get videoRecorderUploadTitle => 'Bakit walang upload?';

  @override
  String get videoRecorderUploadBody =>
      'Ang nakikita mo sa Divine ay gawa ng tao: raw at kuha sa mismong sandali. Hindi tulad ng ibang platform na pumapayag ng highly produced o AI-generated na upload, inuuna namin ang authenticity ng camera-direct na karanasan.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Sa pamamagitan ng pananatili ng paggawa sa loob ng app, mas magagarantiyahan namin na ang content ay totoo at hindi na-edit. Hindi muna namin binubuksan ang external gallery upload sa ngayon para protektahan ang pagiging totoo at panatilihing libre ang community namin sa synthetic content hangga\'t kaya namin.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Lumipat sa Capture o Classic para mag-record ng tunay.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Alamin kung paano gumagana ang verification';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'May nahanap kaming work in progress';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Gusto mo bang ipagpatuloy kung saan ka tumigil?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Oo, ipagpatuloy';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Hindi, magsimula ng bagong video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Hindi na-restore ang draft mo';

  @override
  String get videoRecorderStopRecordingTooltip => 'Itigil ang pag-record';

  @override
  String get videoRecorderStartRecordingTooltip => 'Simulan ang pag-record';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Nagre-record. I-tap kahit saan para itigil';

  @override
  String get videoRecorderTapToStartLabel =>
      'I-tap kahit saan para magsimulang mag-record';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Burahin ang huling clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Magpalit ng camera';

  @override
  String get videoRecorderToggleGridLabel => 'I-toggle ang grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'I-toggle ang ghost frame';

  @override
  String get videoRecorderGhostFrameEnabled => 'Naka-enable ang ghost frame';

  @override
  String get videoRecorderGhostFrameDisabled => 'Naka-disable ang ghost frame';

  @override
  String get videoRecorderClipDeletedMessage => 'Nabura ang clip';

  @override
  String get videoRecorderCloseLabel => 'Isara ang video recorder';

  @override
  String get videoRecorderContinueToEditorLabel => 'Magpatuloy sa video editor';

  @override
  String get videoRecorderCaptureCloseLabel => 'Isara';

  @override
  String get videoRecorderCaptureNextLabel => 'Susunod';

  @override
  String get videoRecorderToggleFlashLabel => 'I-toggle ang flash';

  @override
  String get videoRecorderCycleTimerLabel => 'I-cycle ang timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'I-toggle ang aspect ratio';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clip library, walang clip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Buksan ang clip library, $clipCount clip',
      one: 'Buksan ang clip library, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Camera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Buksan ang camera';

  @override
  String get videoEditorLibraryLabel => 'Library';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Mag-drawing';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorVolumeLabel => 'Volume';

  @override
  String get videoEditorAddTitle => 'Idagdag';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Buksan ang Library';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Buksan ang audio editor';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Buksan ang text editor';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Buksan ang draw editor';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Buksan ang filter editor';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Buksan ang sticker editor';

  @override
  String get videoEditorSaveDraftTitle => 'I-save ang draft mo?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Itago ang mga edit para sa susunod, o burahin at lumabas sa editor.';

  @override
  String get videoEditorSaveDraftButton => 'I-save ang draft';

  @override
  String get videoEditorDiscardChangesButton => 'Burahin ang mga pagbabago';

  @override
  String get videoEditorKeepEditingButton => 'Magpatuloy sa pag-edit';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Drop zone para burahin ang layer';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Bitawan para burahin ang layer';

  @override
  String get videoEditorDoneLabel => 'Tapos na';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'I-play o i-pause ang video';

  @override
  String get videoEditorCropSemanticLabel => 'I-crop';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Hindi pwedeng i-split ang clip habang pinoproseso ito. Maghintay lang.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Invalid ang split position. Dapat hindi bababa sa ${minDurationMs}ms ang haba ng dalawang clip.';
  }

  @override
  String get videoEditorAddClipFromLibrary =>
      'Magdagdag ng clip mula sa Library';

  @override
  String get videoEditorSaveSelectedClip => 'I-save ang napiling clip';

  @override
  String get videoEditorSplitClip => 'I-split ang clip';

  @override
  String get videoEditorSaveClip => 'I-save ang clip';

  @override
  String get videoEditorDeleteClip => 'Burahin ang clip';

  @override
  String get videoEditorClipSavedSuccess => 'Na-save sa library ang clip';

  @override
  String get videoEditorClipSaveFailed => 'Hindi na-save ang clip';

  @override
  String get videoEditorClipDeleted => 'Nabura ang clip';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Color picker';

  @override
  String get videoEditorUndoSemanticLabel => 'Undo';

  @override
  String get videoEditorRedoSemanticLabel => 'Redo';

  @override
  String get videoEditorTextColorSemanticLabel => 'Kulay ng text';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alignment ng text';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Background ng text';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'Walang nahanap na sticker';

  @override
  String get videoEditorNoStickersAvailable => 'Walang available na sticker';

  @override
  String get videoEditorFailedLoadStickers => 'Hindi na-load ang mga sticker';

  @override
  String get videoEditorAdjustVolumeTitle => 'I-adjust ang volume';

  @override
  String get videoEditorRecordedAudioLabel => 'Na-record na audio';

  @override
  String get videoEditorCustomAudioLabel => 'Custom audio';

  @override
  String get videoEditorPlaySemanticLabel => 'I-play';

  @override
  String get videoEditorPauseSemanticLabel => 'I-pause';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'I-mute ang audio';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'I-unmute ang audio';

  @override
  String get videoEditorDeleteLabel => 'Burahin';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Burahin ang napiling item';

  @override
  String get videoEditorEditLabel => 'I-edit';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'I-edit ang napiling item';

  @override
  String get videoEditorDuplicateLabel => 'I-duplicate';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'I-duplicate ang napiling item';

  @override
  String get videoEditorSplitLabel => 'I-split';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'I-split ang napiling clip';

  @override
  String get videoEditorExtractAudioLabel => 'I-extract ang Audio';

  @override
  String get videoEditorClipAudioTitle => 'Clip Audio';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'I-extract ang audio mula sa clip at i-mute ang orihinal';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Hindi ma-extract ang audio: hindi available ang clip nang lokal.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Hindi na-extract ang audio. Pakisubukang muli.';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Tapusin ang pag-edit ng timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'I-play ang preview';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'I-pause ang preview';

  @override
  String get videoEditorAudioUntitledSound => 'Walang pamagat na sound';

  @override
  String get videoEditorAudioUntitled => 'Walang Pamagat';

  @override
  String get videoEditorAudioAddAudio => 'Magdagdag ng audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Walang available na sound';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Lalabas dito ang mga sound kapag may share ang mga creator ng audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Hindi na-load ang mga sound';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Piliin ang audio segment para sa video mo';

  @override
  String get videoEditorAudioCategoryDivine => 'Divine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Community';

  @override
  String get videoEditorAudioCategoryFeatured => 'Featured';

  @override
  String get videoEditorAudioCategoryMySounds => 'My Sounds';

  @override
  String get videoEditorAudioFeaturedEmptyTitle => 'Featured sounds malapit na';

  @override
  String get videoEditorAudioFeaturedEmptySubtitle =>
      'Maglalagay kami ng featured sounds dito kapag handa na sila.';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Arrow tool';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Eraser tool';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Marker tool';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Pencil tool';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'I-reorder ang layer $index';
  }

  @override
  String get videoEditorLayerReorderHint =>
      'Pindutin nang matagal para mag-reorder';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Ipakita ang timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Itago ang timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Iwasan ang paglalagay ng content sa likod ng mga area na ito.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originals';

  @override
  String get videoEditorStickerSearchHint => 'Maghanap ng mga sticker...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Pumili ng font';

  @override
  String get videoEditorFontUnknown => 'Hindi alam';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Dapat nasa loob ng napiling clip ang playhead para mag-split.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'I-trim ang simula';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'I-trim ang dulo';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'I-trim ang clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'I-drag ang mga handle para i-adjust ang haba ng clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Dina-drag ang clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index sa $total, $duration segundo';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Pindutin nang matagal para mag-reorder';

  @override
  String get videoEditorClipGalleryInstruction =>
      'I-tap para i-edit. Pindutin nang matagal at i-drag para mag-reorder.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Ilipat sa kaliwa';

  @override
  String get videoEditorTimelineClipMoveRight => 'Ilipat sa kanan';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Pindutin nang matagal para i-drag';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Video timeline';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, napili';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Isara ang color picker';

  @override
  String get videoEditorPickColorTitle => 'Pumili ng kulay';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Kumpirmahin ang kulay';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturation at brightness';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturation $saturation%, Brightness $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Hue';

  @override
  String get videoEditorAddElementSemanticLabel => 'Magdagdag ng element';

  @override
  String get videoEditorCloseSemanticLabel => 'Isara';

  @override
  String get videoEditorDoneSemanticLabel => 'Tapos na';

  @override
  String get videoEditorLevelSemanticLabel => 'Level';

  @override
  String get videoMetadataBackSemanticLabel => 'Bumalik';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'I-dismiss ang help dialog';

  @override
  String get videoMetadataGotItButton => 'Sige na!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Naabot na ang 64KB limit. Mag-alis ng content para magpatuloy.';

  @override
  String get videoMetadataExpirationLabel => 'Pag-expire';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Piliin ang oras ng pag-expire';

  @override
  String get videoMetadataTitleLabel => 'Pamagat';

  @override
  String get videoMetadataDescriptionLabel => 'Description';

  @override
  String get videoMetadataTagsLabel => 'Mga Tag';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Burahin';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Burahin ang Tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Babala sa Content';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Pumili ng mga content warning';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Piliin lahat ng tumutugma sa content mo';

  @override
  String get videoMetadataContentWarningDoneButton => 'Tapos na';

  @override
  String get videoMetadataAudioReuseTitle => 'I-publish ang sound na ito';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Hayaan ang iba na i-save at gamitin ulit ang audio ng video na ito.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Mga Collaborator';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Mag-imbita ng collaborator';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Paano gumagana ang mga collaborator';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max Collaborator';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Alisin ang collaborator';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Ang mga collaborator ay iniimbitahan bilang co-creator sa post na ito. Pwede mo lang i-imbita ang mga taong magkasundo kayong nag-fo-follow, at lalabas sila bilang collaborator pagkatapos nilang kumpirmahin.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Mga mutual follower';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Kailangan kayong magkasundong nag-fo-follow ni $name para i-imbita siya bilang collaborator.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspirado mula sa';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Itakda ang inspirado mula sa';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Paano gumagana ang inspiration credits';

  @override
  String get videoMetadataInspiredByNone => 'Wala';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Gamitin ito para magbigay ng credit. Iba ang inspired-by credit sa mga collaborator: kinikilala nito ang impluwensya, pero hindi tinatag ang isang tao bilang co-creator.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Hindi pwedeng i-reference ang creator na ito.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Alisin ang inspirado mula sa';

  @override
  String get videoMetadataPostDetailsTitle => 'Mga detalye ng post';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Na-save sa library';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Hindi na-save';

  @override
  String get videoMetadataGoToLibraryButton => 'Pumunta sa Library';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'Save for later button';

  @override
  String get videoMetadataRenderingVideoHint => 'Nire-render ang video...';

  @override
  String get videoMetadataSavingVideoHint => 'Sine-save ang video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'I-save ang video sa drafts at $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'I-save Para Mamaya';

  @override
  String get videoMetadataPostSemanticLabel => 'Post button';

  @override
  String get videoMetadataPublishVideoHint => 'I-publish ang video sa feed';

  @override
  String get videoMetadataShareReplyToFeedTitle => 'Ibahagi rin sa feed ko';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Kapag naka-off, sa thread lang ng komento mananatili ang video na ito.';

  @override
  String get videoMetadataFormNotReadyHint => 'Punan ang form para ma-enable';

  @override
  String get videoMetadataPostButton => 'I-post';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Buksan ang post preview screen';

  @override
  String get videoMetadataShareTitle => 'I-share';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Mga detalye ng video';

  @override
  String get videoMetadataClassicDoneButton => 'Tapos na';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'I-play ang preview';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'I-pause ang preview';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Isara ang video preview';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Alisin';

  @override
  String get fullscreenFeedRemovedMessage => 'Naalis ang video';

  @override
  String get settingsBadgesTitle => 'Mga Badge';

  @override
  String get settingsBadgesSubtitle =>
      'Tanggapin ang mga award at tingnan ang status ng issued badge.';

  @override
  String get badgesTitle => 'Mga Badge';

  @override
  String get badgesIntroTitle => 'Intindihin ang iyong badge trail';

  @override
  String get badgesIntroBody =>
      'Tingnan ang mga badge award na ipinadala sa iyo, piliin kung ano ang i-pin sa iyong Nostr profile, at tingnan kung tinanggap ng mga tao ang mga badge na inisyu mo.';

  @override
  String get badgesOpenApp => 'Buksan ang badges app';

  @override
  String get badgesLoadError => 'Hindi na-load ang mga badge';

  @override
  String get badgesUpdateError => 'Hindi na-update ang badge';

  @override
  String get badgesAwardedSectionTitle => 'Ginawad sa iyo';

  @override
  String get badgesAwardedEmptyTitle => 'Wala pang badge award';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Kapag may nag-award sa iyo ng Nostr badge, lalabas ito dito.';

  @override
  String get badgesStatusAccepted => 'Tinanggap';

  @override
  String get badgesStatusNotAccepted => 'Hindi tinanggap';

  @override
  String get badgesActionRemove => 'Alisin';

  @override
  String get badgesActionAccept => 'Tanggapin';

  @override
  String get badgesActionReject => 'Tanggihan';

  @override
  String get badgesIssuedSectionTitle => 'Inisyu mo';

  @override
  String get badgesIssuedEmptyTitle => 'Wala ka pang issued badge';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Lalabas dito ang acceptance status ng mga badge na ini-issue mo.';

  @override
  String get badgesIssuedNoRecipients =>
      'Walang nakitang recipient para sa award na ito.';

  @override
  String get badgesRecipientAcceptedStatus => 'Tinanggap ng recipient';

  @override
  String get badgesRecipientWaitingStatus => 'Naghihintay ng recipient';

  @override
  String get commentsRecordVideoButtonLabel => 'Mag-record ng video comment';

  @override
  String get commentsOpenVideoLabel => 'Buksan ang video comment';

  @override
  String get commentsMuteVideoReplyLabel => 'I-mute ang video reply';

  @override
  String get commentsUnmuteVideoReplyLabel => 'I-unmute ang video reply';

  @override
  String get commentsOpenReplyParentLabel =>
      'Buksan ang video na nire-replyan nito';

  @override
  String get commentsReplyParentSectionTitle => 'Reply sa video';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Reply kay $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Reply sa video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Na-verify na $platform account: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Mga na-verify na account';

  @override
  String get profileEditGetVerifiedCta => 'Magpa-verify';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'I-link ang iyong mga social media account para malaman ng mga tao na ikaw talaga ito.';

  @override
  String get videoMetadataEditCoverTitle => 'Edit cover';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel => 'Close cover editor';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Confirm cover selection';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Seek through video to select cover frame';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Maghanap o magdagdag ng tag';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Magdagdag ng tag para matuklasan ang video mo';

  @override
  String get videoMetadataTagsPickerNoResults => 'Walang tugmang tag';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Idagdag ang \"#$tag\"';
  }
}
