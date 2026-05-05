// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'ቅንብሮች';

  @override
  String get settingsSecureAccount => 'የመለያዎን ደህንነት ይጠብቁ';

  @override
  String get settingsSessionExpired => 'ክፍለ ጊዜው አልፎበታል።';

  @override
  String get settingsSessionExpiredSubtitle => 'ሙሉ መዳረሻን ለመመለስ እንደገና ይግቡ';

  @override
  String get settingsCreatorAnalytics => 'የፈጣሪ ትንታኔ';

  @override
  String get settingsSupportCenter => 'የድጋፍ ማዕከል';

  @override
  String get settingsNotifications => 'ማሳወቂያዎች';

  @override
  String get settingsContentPreferences => 'የይዘት ምርጫዎች';

  @override
  String get settingsModerationControls => 'ልከኝነት መቆጣጠሪያዎች';

  @override
  String get settingsBlueskyPublishing => 'Bluesky ማተም';

  @override
  String get settingsBlueskyPublishingSubtitle => 'ወደ Bluesky መለጠፍን ያስተዳድሩ';

  @override
  String get settingsNostrSettings => 'Nostr ቅንብሮች';

  @override
  String get settingsIntegratedApps => 'የተዋሃዱ መተግበሪያዎች';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'በDivine ውስጥ የሚሰሩ የጸደቁ የሶስተኛ ወገን መተግበሪያዎች';

  @override
  String get settingsExperimentalFeatures => 'የሙከራ ባህሪያት';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'ሊያደናቅፉ የሚችሉ ለውጦች - ለማወቅ ከፈለጉ ይሞክሩት።';

  @override
  String get settingsLegal => 'ህጋዊ';

  @override
  String get settingsIntegrationPermissions => 'የውህደት ፈቃዶች';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'የሚታወሱ የውህደት ማጽደቆችን ይገምግሙ እና ይሽሩ';

  @override
  String settingsVersion(String version) {
    return 'ስሪት $version';
  }

  @override
  String get settingsVersionEmpty => 'ሥሪት';

  @override
  String get settingsDeveloperModeAlreadyEnabled => 'የገንቢ ሁነታ አስቀድሞ ነቅቷል።';

  @override
  String get settingsDeveloperModeEnabled => 'የገንቢ ሁነታ ነቅቷል!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count የገንቢ ሁነታን ለማንቃት ተጨማሪ መታ ማድረግ';
  }

  @override
  String get settingsInvites => 'ግብዣዎች';

  @override
  String get settingsSwitchAccount => 'መለያ ቀይር';

  @override
  String get settingsAddAnotherAccount => 'ሌላ መለያ ያክሉ';

  @override
  String get settingsUnsavedDraftsTitle => 'ያልተቀመጡ ረቂቆች';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ረቂቆች',
      one: 'ረቂቅ',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ረቂቆቹ',
      one: 'ረቂቁ',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ልታትማቸው ወይም ልትመለከታቸው',
      one: 'ልታትመው ወይም ልትመለከተው',
    );
    return 'ያልተቀመጡ $count $_temp0 አሉህ። አካውንት ስትቀይር $_temp1 ይቀመጣሉ፣ ግን መጀመሪያ $_temp2 ትችላለህ።';
  }

  @override
  String get settingsCancel => 'ተወው';

  @override
  String get settingsSwitchAnyway => 'ለማንኛውም ቀይር';

  @override
  String get settingsAppVersionLabel => 'የመተግበሪያ ስሪት';

  @override
  String get settingsAppLanguage => 'የመተግበሪያ ቋንቋ';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (የመሣሪያ ነባሪ)';
  }

  @override
  String get settingsAppLanguageTitle => 'የመተግበሪያ ቋንቋ';

  @override
  String get settingsAppLanguageDescription => 'የመተግበሪያውን በይነገጽ ቋንቋ ምረጥ';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'የመሣሪያውን ቋንቋ ተጠቀም';

  @override
  String get settingsGeneralTitle => 'አጠቃላይ ቅንብሮች';

  @override
  String get settingsContentSafetyTitle => 'ይዘት እና ደህንነት';

  @override
  String get generalSettingsSectionIntegrations => 'ውህደቶች';

  @override
  String get generalSettingsSectionViewing => 'ማየት';

  @override
  String get generalSettingsSectionCreating => 'መፍጠር';

  @override
  String get generalSettingsSectionApp => 'መተግበሪያ';

  @override
  String get generalSettingsClosedCaptions => 'የተዘጉ መግለጫዎች';

  @override
  String get generalSettingsClosedCaptionsSubtitle => 'ቪዲዮዎች መግለጫዎችን ሲያካትቱ አሳይ';

  @override
  String get generalSettingsVideoShape => 'የቪዲዮ ቅርጽ';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'ካሬ ቪዲዮዎች ብቻ';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait => 'ካሬ እና ቁመታዊ';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'የDivine ቪዲዮዎችን ሙሉ ድብልቅ አሳይ';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'ምግቦችን በክላሲክ ካሬ ቅርጽ ያቆዩ';

  @override
  String get contentPreferencesTitle => 'የይዘት ምርጫዎች';

  @override
  String get contentPreferencesContentFilters => 'የይዘት ማጣሪያዎች';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'የይዘት ማስጠንቀቂያ ማጣሪያዎችን ያቀናብሩ';

  @override
  String get contentPreferencesContentLanguage => 'የይዘት ቋንቋ';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (የመሣሪያ ነባሪ)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'ተመልካቾች ይዘትን ማጣራት እንዲችሉ ቪዲዮዎችዎን በቋንቋ መለያ ይስጡ።';

  @override
  String get contentPreferencesUseDeviceLanguage => 'የመሣሪያውን ቋንቋ ተጠቀም (ነባሪ)';

  @override
  String get contentPreferencesAudioSharing =>
      'የእኔን ኦዲዮ ለእንደገና ጥቅም ላይ እንዲውል አድርግ';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'ሲነቃ ሌሎች ከቪዲዮዎችዎ ኦዲዮን መጠቀም ይችላሉ።';

  @override
  String get contentPreferencesAccountLabels => 'መለያ መለያዎች';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'ይዘትዎን በራስ-ይሰይሙ';

  @override
  String get contentPreferencesAccountContentLabels => 'የመለያ ይዘት መለያዎች';

  @override
  String get contentPreferencesClearAll => 'ሁሉንም አጽዳ';

  @override
  String get contentPreferencesSelectAllThatApply => 'በመለያህ ላይ የሚመለከተውን ሁሉ ምረጥ';

  @override
  String get contentPreferencesDoneNoLabels => 'ተከናውኗል (ምንም መለያዎች የሉም)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'ተከናውኗል ($count ተመርጧል)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'የድምጽ ግቤት መሣሪያ';

  @override
  String get contentPreferencesAutoRecommended => 'ራስ-ሰር (የሚመከር)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'በጣም ጥሩውን ማይክሮፎን በራስ-ሰር ይመርጣል';

  @override
  String get contentPreferencesSelectAudioInput => 'የድምጽ ግቤትን ይምረጡ';

  @override
  String get contentPreferencesUnknownMicrophone => 'ያልታወቀ ማይክሮፎን';

  @override
  String get contentFiltersAdultContent => 'የአዋቂዎች ይዘት';

  @override
  String get contentFiltersViolenceGore => 'ግፍ እና ደም';

  @override
  String get contentFiltersSubstances => 'ንጥረ ነገሮች';

  @override
  String get contentFiltersOther => 'ሌላ';

  @override
  String get contentFiltersAgeGateMessage =>
      'የአዋቂዎች ይዘት ማጣሪያዎችን ለመክፈት በደህንነት እና ግላዊነት ቅንብሮች ውስጥ እድሜዎን ያረጋግጡ';

  @override
  String get contentFiltersShow => 'አሳይ';

  @override
  String get contentFiltersWarn => 'አስጠንቅቅ';

  @override
  String get contentFiltersFilterOut => 'አጣራ';

  @override
  String get profileBlockedAccountNotAvailable => 'ይህ መለያ አይገኝም';

  @override
  String profileErrorPrefix(Object error) {
    return 'ስህተት፡ $error';
  }

  @override
  String get profileInvalidId => 'ልክ ያልሆነ የመገለጫ መታወቂያ';

  @override
  String profileShareText(String displayName, String npub) {
    return '$displayName በDivine ላይ ይመልከቱ!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName በ Divine ላይ';
  }

  @override
  String profileShareFailed(Object error) {
    return 'መገለጫን ማጋራት አልተሳካም፦ $error';
  }

  @override
  String get profileEditProfile => 'መገለጫ አርትዕ';

  @override
  String get profileCreatorAnalytics => 'የፈጣሪ ትንታኔ';

  @override
  String get profileShareProfile => 'መገለጫ አጋራ';

  @override
  String get profileCopyPublicKey => 'የህዝብ ቁልፍ ቅዳ (npub)';

  @override
  String get profileGetEmbedCode => 'የተከተተ ኮድ ያግኙ';

  @override
  String get profilePublicKeyCopied => 'የህዝብ ቁልፍ ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get profileEmbedCodeCopied => 'ኮድ ክተት ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get profileRefreshTooltip => 'አድስ';

  @override
  String get profileRefreshSemanticLabel => 'መገለጫ አድስ';

  @override
  String get profileMoreTooltip => 'ተጨማሪ';

  @override
  String get profileMoreSemanticLabel => 'ተጨማሪ አማራጮች';

  @override
  String get profileAvatarLightboxBarrierLabel => 'አምሳያ ዝጋ';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'የአቫታር ቅድመ እይታን ዝጋ';

  @override
  String get profileFollowingLabel => 'በመከተል ላይ';

  @override
  String get profileFollowLabel => 'ተከተል';

  @override
  String get profileBlockedLabel => 'ታግዷል';

  @override
  String get profileFollowersLabel => 'ተከታዮች';

  @override
  String get profileFollowingStatLabel => 'በመከተል ላይ';

  @override
  String get profileVideosLabel => 'ቪዲዮዎች';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count ተጠቃሚዎች';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'አግድ $displayName?';
  }

  @override
  String get profileBlockExplanation => 'ተጠቃሚን ሲያግዱ፡-';

  @override
  String get profileBlockBulletHidePosts => 'ልጥፎቻቸው በምግብዎ ውስጥ አይታዩም።';

  @override
  String get profileBlockBulletCantView =>
      'መገለጫዎን ሊመለከቱዎት፣ እርስዎን መከተል ወይም ልጥፎችዎን ማየት አይችሉም።';

  @override
  String get profileBlockBulletNoNotify => 'ስለዚህ ለውጥ ማሳወቂያ አይደርሳቸውም።';

  @override
  String get profileBlockBulletYouCanView => 'አሁንም መገለጫቸውን ማየት ይችላሉ።';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'አግድ $displayName';
  }

  @override
  String get profileCancelButton => 'ሰርዝ';

  @override
  String get profileLearnMore => 'የበለጠ ተማር';

  @override
  String profileUnblockTitle(String displayName) {
    return 'የ$displayNameን እገዳ ልታነሳ?';
  }

  @override
  String get profileUnblockExplanation => 'የዚህን ተጠቃሚ እገዳ ስታነቁ፡-';

  @override
  String get profileUnblockBulletShowPosts => 'ልጥፎቻቸው በምግብዎ ውስጥ ይታያሉ።';

  @override
  String get profileUnblockBulletCanView =>
      'እነሱ የእርስዎን መገለጫ ማየት፣ እርስዎን መከተል እና ልጥፎችዎን ማየት ይችላሉ።';

  @override
  String get profileUnblockBulletNoNotify => 'ስለዚህ ለውጥ ማሳወቂያ አይደርሳቸውም።';

  @override
  String get profileLearnMoreAt => 'በ ላይ የበለጠ ይረዱ';

  @override
  String get profileUnblockButton => 'እገዳ አንሳ';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayNameን አትከተል';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'አግድ $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'እገዳን አንሳ $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayNameን ወደ ዝርዝር ጨምር';
  }

  @override
  String get profileUserBlockedTitle => 'ተጠቃሚ ታግዷል';

  @override
  String get profileUserBlockedContent => 'የዚህን ተጠቃሚ ይዘት በምግብዎ ውስጥ አያዩም።';

  @override
  String get profileUserBlockedUnblockHint =>
      'በማንኛውም ጊዜ ከመገለጫቸው ወይም በቅንብሮች > ደህንነት ውስጥ እገዳውን ማንሳት ትችላለህ።';

  @override
  String get profileCloseButton => 'ገጠመ';

  @override
  String get profileNoCollabsTitle => 'እስካሁን ምንም ትብብር የለም።';

  @override
  String get profileCollabsOwnEmpty => 'የምትተባበሩባቸው ቪዲዮዎች እዚህ ይታያሉ።';

  @override
  String get profileCollabsOtherEmpty => 'የሚተባበሩባቸው ቪዲዮዎች እዚህ ይታያሉ።';

  @override
  String get profileErrorLoadingCollabs => 'የትብብር ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoSavedVideosTitle => 'እስካሁን ምንም አልተቀመጠም።';

  @override
  String get profileSavedOwnEmpty =>
      'ቪዲዮዎችን ከማጋሪያ ሉህ ላይ ዕልባት አድርግ እና እዚህ ይታያሉ።';

  @override
  String get profileErrorLoadingSaved => 'የተቀመጡ ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoCommentsOwnTitle => 'እስካሁን ምንም አስተያየት የለም።';

  @override
  String get profileNoCommentsOtherTitle => 'እስካሁን ምንም አስተያየት የለም።';

  @override
  String get profileCommentsOwnEmpty => 'የእርስዎ አስተያየቶች እና ምላሾች እዚህ ይታያሉ።';

  @override
  String get profileCommentsOtherEmpty => 'የእነሱ አስተያየት እና ምላሾች እዚህ ይታያሉ.';

  @override
  String get profileErrorLoadingComments => 'አስተያየቶችን መጫን ላይ ስህተት';

  @override
  String get profileVideoRepliesSection => 'የቪዲዮ መልሶች';

  @override
  String get profileCommentsSection => 'አስተያየቶች';

  @override
  String get profileEditLabel => 'አርትዕ';

  @override
  String get profileLibraryLabel => 'ቤተ መፃህፍት';

  @override
  String get profileNoLikedVideosTitle => 'እስካሁን ምንም መውደዶች የሉም';

  @override
  String get profileLikedOwnEmpty =>
      'የሆነ ነገር ዓይንዎን ሲይዝ, ልብን ይንኩ. መውደዶችዎ እዚህ ይታያሉ።';

  @override
  String get profileLikedOtherEmpty => 'እስካሁን ዓይናቸውን የሳበ ነገር የለም። ጊዜ ስጠው።';

  @override
  String get profileErrorLoadingLiked => 'የተወደዱ ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileNoRepostsTitle => 'እስካሁን ምንም ድጋሚ የተለጠፈ የለም።';

  @override
  String get profileRepostsOwnEmpty =>
      'ማጋራት የሚገባ ነገር አየህ? እንደገና ይለጥፉት እና እዚህ ይታያል።';

  @override
  String get profileRepostsOtherEmpty => 'እስካሁን ምንም አላለፉም። ሲያደርጉ፣ እዚህ ይታያል።';

  @override
  String get profileErrorLoadingReposts => 'እንደገና የተለጠፉ ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get profileLoadingTitle => 'መገለጫን በመጫን ላይ...';

  @override
  String get profileLoadingSubtitle => 'ይሄ ጥቂት ጊዜ ሊወስድ ይችላል።';

  @override
  String get profileLoadingVideos => 'ቪዲዮዎችን በመጫን ላይ...';

  @override
  String get profileNoVideosTitle => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get profileNoVideosOwnSubtitle =>
      'መድረክህ ተዘጋጅቷል። መለጠፍ ይጀምሩ እና ቪዲዮዎችዎ እዚህ ይኖራሉ።';

  @override
  String get profileNoVideosOtherSubtitle => 'አለም እየጠበቀች ነው። እንዳያመልጥዎ ይከተሏቸው።';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'የቪዲዮ ድንክዬ $number';
  }

  @override
  String get profileShowMore => 'ተጨማሪ አሳይ';

  @override
  String get profileShowLess => 'ያነሰ አሳይ';

  @override
  String get profileCompleteYourProfile => 'መገለጫዎን ያጠናቅቁ';

  @override
  String get profileCompleteSubtitle => 'ለመጀመር የእርስዎን ስም፣ የህይወት ታሪክ እና ምስል ያክሉ';

  @override
  String get profileSetUpButton => 'አዋቅር';

  @override
  String get profileVerifyingEmail => 'ኢሜል በማረጋገጥ ላይ...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'የማረጋገጫ ማገናኛን ለማግኘት $emailን ያረጋግጡ';
  }

  @override
  String get profileWaitingForVerification => 'የኢሜይል ማረጋገጫን በመጠበቅ ላይ';

  @override
  String get profileVerificationFailed => 'ማረጋገጥ አልተሳካም።';

  @override
  String get profilePleaseTryAgain => 'እባክህ እንደገና ሞክር';

  @override
  String get profileSecureYourAccount => 'የመለያዎን ደህንነት ይጠብቁ';

  @override
  String get profileSecureSubtitle =>
      'መለያዎን በማንኛውም መሳሪያ ላይ ለማግኘት ኢሜይል እና የይለፍ ቃል ያክሉ';

  @override
  String get profileRetryButton => 'እንደገና ይሞክሩ';

  @override
  String get profileRegisterButton => 'ይመዝገቡ';

  @override
  String get profileSessionExpired => 'ክፍለ ጊዜው አልፎበታል።';

  @override
  String get profileSignInToRestore => 'ሙሉ መዳረሻን ለመመለስ እንደገና ይግቡ';

  @override
  String get profileSignInButton => 'ይግቡ';

  @override
  String get profileMaybeLaterLabel => 'ምናልባት በኋላ';

  @override
  String get profileSecurePrimaryButton => 'ኢሜይል እና የይለፍ ቃል ያክሉ';

  @override
  String get profileCompletePrimaryButton => 'መገለጫዎን ያዘምኑ';

  @override
  String get profileLoopsLabel => 'ቀለበቶች';

  @override
  String get profileLikesLabel => 'መውደዶች';

  @override
  String get profileMyLibraryLabel => 'የእኔ ቤተ-መጽሐፍት';

  @override
  String get profileMessageLabel => 'መልእክት';

  @override
  String get profileUserFallback => 'ተጠቃሚ';

  @override
  String get profileDismissTooltip => 'አሰናብት';

  @override
  String get profileLinkCopied => 'የመገለጫ አገናኝ ተቀድቷል።';

  @override
  String get profileSetupEditProfileTitle => 'መገለጫ አርትዕ';

  @override
  String get profileSetupBackLabel => 'ተመለስ';

  @override
  String get profileSetupAboutNostr => 'ስለ Nostr';

  @override
  String get profileSetupProfilePublished => 'መገለጫ በተሳካ ሁኔታ ታትሟል!';

  @override
  String get profileSetupCreateNewProfile => 'አዲስ መገለጫ ይፈጠር?';

  @override
  String get profileSetupNoExistingProfile =>
      'በእርስዎ ማስተላለፊያዎች ላይ ነባር መገለጫ አላገኘንም። ማተም አዲስ መገለጫ ይፈጥራል። ይቀጥል?';

  @override
  String get profileSetupPublishButton => 'አትም';

  @override
  String get profileSetupUsernameTaken => 'የተጠቃሚ ስም አሁን ተወስዷል። እባክዎ ሌላ ይምረጡ።';

  @override
  String get profileSetupClaimFailed =>
      'የተጠቃሚ ስም መጠየቅ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get profileSetupPublishFailed => 'መገለጫን ማተም አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get profileSetupNoRelaysConnected =>
      'አውታረ መረቡ ላይ መድረስ አልተቻለም። ግንኙነትዎን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get profileSetupRetryLabel => 'እንደገና ይሞክሩ';

  @override
  String get profileSetupDisplayNameLabel => 'የማሳያ ስም';

  @override
  String get profileSetupDisplayNameHint => 'ሰዎች እርስዎን እንዴት ማወቅ አለባቸው?';

  @override
  String get profileSetupDisplayNameHelper =>
      'የሚፈልጉት ማንኛውም ስም ወይም መለያ። ልዩ መሆን የለበትም።';

  @override
  String get profileSetupDisplayNameRequired => 'እባክዎ የማሳያ ስም ያስገቡ';

  @override
  String get profileSetupBioLabel => 'ባዮ (አማራጭ)';

  @override
  String get profileSetupBioHint => 'ስለራስዎ ለሰዎች ይንገሩ…';

  @override
  String get profileSetupPublicKeyLabel => 'የህዝብ ቁልፍ (npub)';

  @override
  String get profileSetupUsernameLabel => 'የተጠቃሚ ስም (አማራጭ)';

  @override
  String get profileSetupUsernameHint => 'የተጠቃሚ ስም';

  @override
  String get profileSetupUsernameHelper => 'ልዩ ማንነትህ በDivine ላይ';

  @override
  String get profileSetupProfileColorLabel => 'የመገለጫ ቀለም (አማራጭ)';

  @override
  String get profileSetupSaveButton => 'አስቀምጥ';

  @override
  String get profileSetupSavingButton => 'በማስቀመጥ ላይ...';

  @override
  String get profileSetupImageUrlTitle => 'ምስል ያክሉ URL';

  @override
  String get profileSetupPictureUploaded => 'የመገለጫ ስዕል በተሳካ ሁኔታ ተሰቅሏል!';

  @override
  String get profileSetupImageSelectionFailed =>
      'የምስል ምርጫ አልተሳካም። እባክህ በምትኩ ምስል URL ከታች ለጥፍ።';

  @override
  String get profileSetupImagesTypeGroup => 'ምስሎች';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'የካሜራ መዳረሻ አልተሳካም፦ $error';
  }

  @override
  String get profileSetupGotItButton => 'ገባኝ';

  @override
  String get profileSetupUploadFailedGeneric =>
      'ምስል መስቀል አልተሳካም። ቆይተህ እንደገና ሞክር።';

  @override
  String get profileSetupUploadNetworkError =>
      'የአውታረ መረብ ስህተት፡ እባክህ የበይነመረብ ግንኙነትህን ፈትሽ እና እንደገና ሞክር።';

  @override
  String get profileSetupUploadAuthError =>
      'የማረጋገጫ ስህተት፡ እባክዎ ዘግተው ለመውጣት ይሞክሩ።';

  @override
  String get profileSetupUploadFileTooLarge =>
      'ፋይሉ በጣም ትልቅ ነው፡ እባክዎን ትንሽ ምስል ይምረጡ (ከፍተኛ 10 ሜባ)።';

  @override
  String get profileSetupUploadServerError =>
      'ምስል መስቀል አልተሳካም። አገልጋዮቻችን ለጊዜው አይገኙም። ትንሽ ቆይተህ እንደገና ሞክር።';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'የመገለጫ ስዕል መስቀል በድር ላይ እስካሁን አይገኝም። የiOS ወይም Android መተግበሪያን ተጠቀም፣ ወይም የምስል URL ለጥፍ።';

  @override
  String get profileSetupUsernameChecking => 'ተገኝነትን በማጣራት ላይ...';

  @override
  String get profileSetupUsernameAvailable => 'የተጠቃሚ ስም አለ!';

  @override
  String get profileSetupUsernameTakenIndicator => 'የተጠቃሚ ስም አስቀድሞ ተወስዷል';

  @override
  String get profileSetupUsernameReserved => 'የተጠቃሚ ስም የተጠበቀ ነው።';

  @override
  String get profileSetupContactSupport => 'ድጋፍን ያነጋግሩ';

  @override
  String get profileSetupCheckAgain => 'እንደገና ያረጋግጡ';

  @override
  String get profileSetupUsernameBurned => 'ይህ የተጠቃሚ ስም ከአሁን በኋላ አይገኝም';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'ፊደሎች፣ ቁጥሮች እና ሰረዞች ብቻ ይፈቀዳሉ።';

  @override
  String get profileSetupUsernameInvalidLength =>
      'የተጠቃሚ ስም 3-20 ቁምፊዎች መሆን አለበት።';

  @override
  String get profileSetupUsernameNetworkError =>
      'ተገኝነትን ማረጋገጥ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get profileSetupUsernameInvalidFormatGeneric => 'የተሳሳተ የተጠቃሚ ስም ቅርጸት';

  @override
  String get profileSetupUsernameCheckFailed => 'ተገኝነትን ማረጋገጥ አልተሳካም።';

  @override
  String get profileSetupUsernameReservedTitle => 'የተጠቃሚ ስም ተቀምጧል';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'ስሙ $username የተጠበቀ ነው። ለምን ያንተ መሆን እንዳለበት ንገረን።';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ለምሳሌ. የእኔ የምርት ስም፣ የመድረክ ስም፣ ወዘተ ነው።';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'ድጋፍን አስቀድመው አነጋግረዋል? ለእርስዎ እንደተለቀቀ ለማየት \"እንደገና አረጋግጥ\" ን መታ ያድርጉ።';

  @override
  String get profileSetupSupportRequestSent => 'የድጋፍ ጥያቄ ተልኳል! በቅርቡ እንመለስዎታለን።';

  @override
  String get profileSetupCouldntOpenEmail =>
      'ኢሜይል መክፈት አልተቻለም። ወደ names@divine.video ላክ';

  @override
  String get profileSetupSendRequest => 'ጥያቄ ላክ';

  @override
  String get profileSetupPickColorTitle => 'ቀለም ይምረጡ';

  @override
  String get profileSetupSelectButton => 'ይምረጡ';

  @override
  String get profileSetupUseOwnNip05 => 'የራስህን NIP-05 አድራሻ ተጠቀም';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 አድራሻ';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'ልክ ያልሆነ NIP-05 ቅርጸት (ለምሳሌ name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'ለdivine.video ከላይ ያለውን የተጠቃሚ ስም መስክ ይጠቀሙ';

  @override
  String get profileSetupProfilePicturePreview => 'የመገለጫ ስዕል ቅድመ እይታ';

  @override
  String get nostrInfoIntroBuiltOn => 'ዳይቪን የተገነባው በNostr ላይ ነው፣';

  @override
  String get nostrInfoIntroDescription =>
      'ሳንሱርን የሚቋቋም ክፍት ፕሮቶኮል ሰዎች በአንድ ኩባንያ ወይም መድረክ ላይ ሳይመሰረቱ በመስመር ላይ እንዲግባቡ ያስችላቸዋል።';

  @override
  String get nostrInfoIntroIdentity => 'ለDivine ሲመዘገቡ አዲስ Nostr መታወቂያ ያገኛሉ።';

  @override
  String get nostrInfoOwnership =>
      'Nostr የእርስዎን ይዘት፣ ማንነት እና ማህበራዊ ግራፍ በባለቤትነት እንዲይዙ ያስችልዎታል፣ ይህም በብዙ መተግበሪያዎች ላይ ሊጠቀሙበት ይችላሉ። ውጤቱ የበለጠ ምርጫ፣ መቆለፊያው ያነሰ እና ጤናማ፣ የበለጠ ጠንካራ ማህበራዊ ኢንተርኔት ነው።';

  @override
  String get nostrInfoLingo => 'Nostr ሊንጎ፡-';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' የህዝብ Nostr አድራሻህ። ማጋራት ደህና ነው፣ ሌሎችም በNostr መተግበሪያዎች ላይ እንዲያገኙህ፣ እንዲከተሉህ ወይም መልዕክት እንዲልኩልህ ያስችላል።';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      'የእርስዎ የግል ቁልፍ እና የባለቤትነት ማረጋገጫ። የእርስዎን Nostr ማንነት ሙሉ ቁጥጥር ይሰጣል፣ ስለዚህ';

  @override
  String get nostrInfoNsecWarning => 'ሁልጊዜ በሚስጥር ይያዙት!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr የተጠቃሚ ስም፡-';

  @override
  String get nostrInfoUsernameDescription =>
      ' ለሰው የሚነበብ ስም (እንደ @name.divine.video) ከnpubህ ጋር የሚገናኝ። የNostr ማንነትህን እንደ ኢሜይል አድራሻ ለመለየትና ለማረጋገጥ ያቀላል።';

  @override
  String get nostrInfoLearnMoreAt => 'በ ላይ የበለጠ ይረዱ';

  @override
  String get nostrInfoGotIt => 'ገባኝ!';

  @override
  String get profileTabRefreshTooltip => 'አድስ';

  @override
  String get videoGridRefreshLabel => 'ተጨማሪ ቪዲዮዎችን በመፈለግ ላይ';

  @override
  String get videoGridOptionsTitle => 'የቪዲዮ አማራጮች';

  @override
  String get videoGridEditVideo => 'ቪዲዮ አርትዕ';

  @override
  String get videoGridEditVideoSubtitle => 'ርዕስ፣ መግለጫ እና ሃሽታጎችን ያዘምኑ';

  @override
  String get videoGridDeleteVideo => 'ቪዲዮ ሰርዝ';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'ይህን ቪዲዮ ከDivine አስወግድ። በሌሎች Nostr ደንበኞች ላይ አሁንም ሊታይ ይችላል።';

  @override
  String get videoGridDeleteConfirmTitle => 'ቪዲዮ ሰርዝ';

  @override
  String get videoGridDeleteConfirmMessage =>
      'ይሄ ይህን ቪዲዮ ከDivine እስከመጨረሻው ይሰርዘዋል። አሁንም ሌሎች ማስተላለፊያዎችን በሚጠቀሙ የሶስተኛ ወገን Nostr ደንበኞች ላይ ሊታይ ይችላል።';

  @override
  String get videoGridDeleteConfirmNote =>
      'ይህ የስረዛ ጥያቄን ወደ ማስተላለፊያዎች ይልካል። ማስታወሻ፡ አንዳንድ ማሰራጫዎች አሁንም የተሸጎጡ ቅጂዎች ሊኖራቸው ይችላል።';

  @override
  String get videoGridDeleteCancel => 'ሰርዝ';

  @override
  String get videoGridDeleteConfirm => 'ሰርዝ';

  @override
  String get videoGridDeletingContent => 'ይዘትን በመሰረዝ ላይ...';

  @override
  String get videoGridDeleteSuccess => 'ጥያቄውን ሰርዝ በተሳካ ሁኔታ ተልኳል።';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'ይዘትን መሰረዝ አልተሳካም፦ $error';
  }

  @override
  String get exploreTabClassics => 'ክላሲኮች';

  @override
  String get exploreTabNew => 'አዲስ';

  @override
  String get exploreTabPopular => 'ታዋቂ';

  @override
  String get exploreTabCategories => 'ምድቦች';

  @override
  String get exploreTabForYou => 'ለእርስዎ';

  @override
  String get exploreTabLists => 'ዝርዝሮች';

  @override
  String get exploreTabIntegratedApps => 'የተዋሃዱ መተግበሪያዎች';

  @override
  String get exploreNoVideosAvailable => 'ምንም ቪዲዮዎች የሉም';

  @override
  String exploreErrorPrefix(Object error) {
    return 'ስህተት፡ $error';
  }

  @override
  String get exploreDiscoverLists => 'ዝርዝሮችን ያግኙ';

  @override
  String get exploreAboutLists => 'ስለ ዝርዝሮች';

  @override
  String get exploreAboutListsDescription =>
      'ዝርዝሮች የDivine ይዘትን በሁለት መንገድ እንዲያደራጁ እና እንዲያዘጋጁ ያግዝዎታል፡';

  @override
  String get explorePeopleLists => 'የሰዎች ዝርዝሮች';

  @override
  String get explorePeopleListsDescription =>
      'የፈጣሪዎችን ቡድኖች ይከተሉ እና የቅርብ ጊዜ ቪዲዮዎቻቸውን ይመልከቱ';

  @override
  String get exploreVideoLists => 'የቪዲዮ ዝርዝሮች';

  @override
  String get exploreVideoListsDescription =>
      'በኋላ ለመመልከት የሚወዷቸውን ቪዲዮዎች አጫዋች ዝርዝሮችን ይፍጠሩ';

  @override
  String get exploreMyLists => 'የእኔ ዝርዝሮች';

  @override
  String get exploreSubscribedLists => 'የተመዘገቡ ዝርዝሮች';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'ዝርዝሮችን መጫን ላይ ስህተት፦ $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count አዳዲስ ቪዲዮዎች',
      one: '1 አዲስ ቪዲዮ',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count አዳዲስ ቪዲዮዎች ጫን',
      one: '1 አዲስ ቪዲዮ ጫን',
    );
    return '$_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'ቪዲዮን በመጫን ላይ...';

  @override
  String get videoPlayerPlayVideo => 'ቪዲዮ አጫውት።';

  @override
  String get videoPlayerMute => 'ቪዲዮ ድምጸ-ከል አድርግ';

  @override
  String get videoPlayerUnmute => 'የቪዲዮ ድምጸ-ከል አንሳ';

  @override
  String get videoPlayerEditVideo => 'ቪዲዮን ያርትዑ';

  @override
  String get videoPlayerEditVideoTooltip => 'ቪዲዮን ያርትዑ';

  @override
  String get contentWarningLabel => 'የይዘት ማስጠንቀቂያ';

  @override
  String get contentWarningNudity => 'እርቃንነት';

  @override
  String get contentWarningSexualContent => 'ወሲባዊ ይዘት';

  @override
  String get contentWarningPornography => 'የብልግና ሥዕሎች';

  @override
  String get contentWarningGraphicMedia => 'ግራፊክ ሚዲያ';

  @override
  String get contentWarningViolence => 'ብጥብጥ';

  @override
  String get contentWarningSelfHarm => 'ራስን መጉዳት።';

  @override
  String get contentWarningDrugUse => 'የመድሃኒት አጠቃቀም';

  @override
  String get contentWarningAlcohol => 'አልኮል';

  @override
  String get contentWarningTobacco => 'ትምባሆ';

  @override
  String get contentWarningGambling => 'ቁማር';

  @override
  String get contentWarningProfanity => 'ስድብ';

  @override
  String get contentWarningFlashingLights => 'ብልጭ ድርግም የሚሉ መብራቶች';

  @override
  String get contentWarningAiGenerated => 'በAI የተፈጠረ';

  @override
  String get contentWarningSpoiler => 'ስፒለር';

  @override
  String get contentWarningSensitiveContent => 'ሚስጥራዊነት ያለው ይዘት';

  @override
  String get contentWarningDescNudity => 'እርቃን ወይም ከፊል እርቃንነትን ይይዛል';

  @override
  String get contentWarningDescSexual => 'ወሲባዊ ይዘት ይዟል';

  @override
  String get contentWarningDescPorn => 'ግልጽ የሆነ የወሲብ ስራ ይዘት ይዟል';

  @override
  String get contentWarningDescGraphicMedia => 'ግራፊክ ወይም የሚረብሽ ምስሎችን ይዟል';

  @override
  String get contentWarningDescViolence => 'የጥቃት ይዘት ይዟል';

  @override
  String get contentWarningDescSelfHarm => 'ራስን መጉዳት ማጣቀሻዎችን ይዟል';

  @override
  String get contentWarningDescDrugs => 'ከመድኃኒት ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescAlcohol => 'ከአልኮል ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescTobacco => 'ከትንባሆ ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescGambling => 'ከቁማር ጋር የተያያዘ ይዘት ይዟል';

  @override
  String get contentWarningDescProfanity => 'ጠንካራ ቋንቋ ይይዛል';

  @override
  String get contentWarningDescFlashingLights =>
      'ብልጭ ድርግም የሚሉ መብራቶችን ይዟል (የፎቶ ትብነት ማስጠንቀቂያ)';

  @override
  String get contentWarningDescAiGenerated => 'ይህ ይዘት በ AI የመነጨ ነው።';

  @override
  String get contentWarningDescSpoiler => 'አጥፊዎችን ይይዛል';

  @override
  String get contentWarningDescContentWarning =>
      'ፈጣሪ ይህንን እንደ ሚስጥራዊነት ምልክት አድርጎታል።';

  @override
  String get contentWarningDescDefault => 'ፈጣሪ ይህንን ይዘት ጠቁሟል';

  @override
  String get contentWarningDetailsTitle => 'የይዘት ማስጠንቀቂያዎች';

  @override
  String get contentWarningDetailsSubtitle => 'ፈጣሪው እነዚህን መለያዎች ተግባራዊ አድርጓል፡-';

  @override
  String get contentWarningManageFilters => 'የይዘት ማጣሪያዎችን ያቀናብሩ';

  @override
  String get contentWarningViewAnyway => 'ለማንኛውም ይመልከቱ';

  @override
  String get contentWarningReportContentTooltip => 'ይዘትን ሪፖርት አድርግ';

  @override
  String get contentWarningBlockUserTooltip => 'ተጠቃሚን አግድ';

  @override
  String get contentWarningBlockedTitle => 'ይዘት ታግዷል';

  @override
  String get contentWarningBlockedPolicy => 'ይህ ይዘት በፖሊሲ ጥሰቶች ምክንያት ታግዷል።';

  @override
  String get contentWarningNoticeTitle => 'የይዘት ማሳሰቢያ';

  @override
  String get contentWarningPotentiallyHarmfulTitle => 'ሊጎዳ የሚችል ይዘት';

  @override
  String get contentWarningView => 'ይመልከቱ';

  @override
  String get contentWarningReportAction => 'ሪፖርት';

  @override
  String get contentWarningHideAllLikeThis => 'ሁሉንም እንደዚህ ያሉ ይዘቶችን ደብቅ';

  @override
  String get contentWarningNoFilterYet =>
      'ለዚህ ማስጠንቀቂያ እስካሁን ምንም የተቀመጠ ማጣሪያ የለም።';

  @override
  String get contentWarningHiddenConfirmation =>
      'ከአሁን በኋላ እንደዚህ አይነት ልጥፎችን እንደብቃለን።';

  @override
  String get videoErrorNotFound => 'ቪዲዮ አልተገኘም።';

  @override
  String get videoErrorNetwork => 'የአውታረ መረብ ስህተት';

  @override
  String get videoErrorTimeout => 'የመጫኛ ጊዜ ማብቂያ';

  @override
  String get videoErrorFormat =>
      'የቪዲዮ ቅርጸት ስህተት\n(እንደገና ይሞክሩ ወይም የተለየ አሳሽ ይጠቀሙ)';

  @override
  String get videoErrorUnsupportedFormat => 'የማይደገፍ የቪዲዮ ቅርጸት';

  @override
  String get videoErrorPlayback => 'የቪዲዮ መልሶ ማጫወት ስህተት';

  @override
  String get videoErrorAgeRestricted => 'በእድሜ የተገደበ ይዘት';

  @override
  String get videoErrorVerifyAge => 'ዕድሜን ያረጋግጡ';

  @override
  String get videoErrorRetry => 'እንደገና ይሞክሩ';

  @override
  String get videoErrorContentRestricted => 'ይዘት ተገድቧል';

  @override
  String get videoErrorContentRestrictedBody => 'ይህ ቪዲዮ በቅብብሎሽ ተገድቧል።';

  @override
  String get videoErrorVerifyAgeBody => 'ይህን ቪዲዮ ለማየት እድሜዎን ያረጋግጡ።';

  @override
  String get videoErrorSkip => 'ዝለል';

  @override
  String get videoErrorVerifyAgeButton => 'ዕድሜን ያረጋግጡ';

  @override
  String get videoFollowButtonFollowing => 'በመከተል ላይ';

  @override
  String get videoFollowButtonFollow => 'ተከተል';

  @override
  String get audioAttributionOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'በ@$creatorName የተነሳሳ';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'ከ@$name ጋር';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'ከ@$name +$count ጋር';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ተባባሪዎች',
      one: '1 ተባባሪ',
    );
    return '$_temp0። መገለጫውን ለማየት መታ አድርግ።';
  }

  @override
  String get listAttributionFallback => 'ዝርዝር';

  @override
  String get shareVideoLabel => 'ቪዲዮ አጋራ';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'ልጥፍ ለ$recipientName ተጋርቷል።';
  }

  @override
  String get shareFailedToSend => 'ቪዲዮ መላክ አልተሳካም።';

  @override
  String get shareAddedToBookmarks => 'ወደ ዕልባቶች ታክሏል።';

  @override
  String get shareRemovedFromBookmarks => 'ከዕልባቶች ተወግዷል';

  @override
  String get shareFailedToAddBookmark => 'ዕልባት ማከል አልተሳካም።';

  @override
  String get shareFailedToRemoveBookmark => 'ዕልባትን ማስወገድ አልተሳካም።';

  @override
  String get shareActionFailed => 'እርምጃ አልተሳካም።';

  @override
  String get shareWithTitle => 'ሼር በማድረግ ያካፍሉ።';

  @override
  String get shareFindPeople => 'ሰዎችን ያግኙ';

  @override
  String get shareFindPeopleMultiline => 'አግኝ\nሰዎች';

  @override
  String get shareSent => 'ተልኳል።';

  @override
  String get shareContactFallback => 'ተገናኝ';

  @override
  String get shareUserFallback => 'ተጠቃሚ';

  @override
  String shareSendingTo(String name) {
    return 'ወደ $name በመላክ ላይ';
  }

  @override
  String get shareMessageHint => 'አማራጭ መልእክት አክል...';

  @override
  String get videoActionUnlike => 'ከቪዲዮ በተቃራኒ';

  @override
  String get videoActionLike => 'ልክ እንደ ቪዲዮ';

  @override
  String get videoActionAutoLabel => 'ማጠናቀር';

  @override
  String get videoActionLikeLabel => 'እንደ';

  @override
  String get videoActionReplyLabel => 'መልስ';

  @override
  String get videoActionRepostLabel => 'እንደገና ይለጥፉ';

  @override
  String get videoActionShareLabel => 'አጋራ';

  @override
  String get videoActionAboutLabel => 'ስለ';

  @override
  String get videoActionEnableAutoAdvance => 'አውቶማቲክ ማስቀደምን አንቃ';

  @override
  String get videoActionDisableAutoAdvance => 'ራስ-ሰር ማስቀደምን አሰናክል';

  @override
  String get videoActionRemoveRepost => 'ድጋሚ ልጥፍን ያስወግዱ';

  @override
  String get videoActionRepost => 'ቪዲዮውን እንደገና ይለጥፉ';

  @override
  String get videoActionViewComments => 'አስተያየቶችን ይመልከቱ';

  @override
  String get videoActionMoreOptions => 'ተጨማሪ አማራጮች';

  @override
  String get videoActionHideSubtitles => 'የትርጉም ጽሑፎችን ደብቅ';

  @override
  String get videoActionShowSubtitles => 'የትርጉም ጽሑፎችን አሳይ';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'የቪዲዮ ዝርዝሮችን ይክፈቱ';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'የቪዲዮ ዝርዝሮችን ይክፈቱ';

  @override
  String videoDescriptionLoops(String count) {
    return '$count ሉፖች';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ሉፖች',
      one: 'ሉፕ',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'አይደለም Divine';

  @override
  String get metadataBadgeHumanMade => 'ሰው ሰራሽ';

  @override
  String get metadataSoundsLabel => 'ይሰማል።';

  @override
  String get metadataOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String get metadataVerificationLabel => 'ማረጋገጥ';

  @override
  String get metadataDeviceAttestation => 'የመሣሪያ ማረጋገጫ';

  @override
  String get metadataProofManifest => 'ማረጋገጫ አንጸባራቂ';

  @override
  String get metadataCreatorLabel => 'ፈጣሪ';

  @override
  String get metadataCollaboratorsLabel => 'ተባባሪዎች';

  @override
  String get metadataInspiredByLabel => 'ተመስጦ';

  @override
  String get metadataRepostedByLabel => 'በድጋሚ የተለጠፈው በ';

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ሉፖች',
      one: 'ሉፕ',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'መውደዶች';

  @override
  String get metadataCommentsLabel => 'አስተያየቶች';

  @override
  String get metadataRepostsLabel => 'ድጋሚ ልጥፎች';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'የተለጠፈው $date ላይ ነው።';
  }

  @override
  String get devOptionsTitle => 'የገንቢ አማራጮች';

  @override
  String get devOptionsPageLoadTimes => 'የገጽ ጭነት ጊዜያት';

  @override
  String get devOptionsNoPageLoads =>
      'እስካሁን ምንም የገጽ ጭነቶች አልተመዘገበም።\nየጊዜ ውሂብን ለማየት በመተግበሪያው ውስጥ ያስሱ።';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'የሚታይ፡ ${visibleMs}ms | ውሂብ፡ ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'በጣም ቀርፋፋ ስክሪኖች';

  @override
  String get devOptionsVideoPlaybackFormat => 'የቪዲዮ መልሶ ማጫወት ቅርጸት';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'አካባቢ ይቀየር?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'ወደ $envName ቀይር?\n\nይህ የተሸጎጠ የቪዲዮ ውሂብን ያጸዳል እና ከአዲሱ ሪሌይ ጋር እንደገና ይገናኛል።';
  }

  @override
  String get devOptionsCancel => 'ሰርዝ';

  @override
  String get devOptionsSwitch => 'ቀይር';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'ወደ $envName ተቀይሯል';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'ወደ $formatName ተቀይሯል - መሸጎጫ ጸድቷል።';
  }

  @override
  String get featureFlagTitle => 'የባህሪ ባንዲራዎች';

  @override
  String get featureFlagResetAllTooltip => 'ሁሉንም ባንዲራዎች ወደ ነባሪዎች ዳግም ያስጀምሩ';

  @override
  String get featureFlagResetToDefault => 'ወደ ነባሪ ዳግም አስጀምር';

  @override
  String get featureFlagAppRecovery => 'የመተግበሪያ መልሶ ማግኛ';

  @override
  String get featureFlagAppRecoveryDescription =>
      'መተግበሪያው እየተበላሸ ከሆነ ወይም እንግዳ ከሆነ፣ መሸጎጫውን ለማጽዳት ይሞክሩ።';

  @override
  String get featureFlagClearAllCache => 'ሁሉንም መሸጎጫ ያጽዱ';

  @override
  String get featureFlagCacheInfo => 'የመሸጎጫ መረጃ';

  @override
  String get featureFlagClearCacheTitle => 'ሁሉንም መሸጎጫ ይጽዱ?';

  @override
  String get featureFlagClearCacheMessage =>
      'ይህ የሚከተሉትን ጨምሮ ሁሉንም የተሸጎጠ ውሂብ ያጸዳል-\n• ማሳወቂያዎች\n• የተጠቃሚ መገለጫዎች\n• ዕልባቶች\n• ጊዜያዊ ፋይሎች\n\nእንደገና መግባት ያስፈልግዎታል። ይቀጥል?';

  @override
  String get featureFlagClearCache => 'መሸጎጫ አጽዳ';

  @override
  String get featureFlagClearingCache => 'መሸጎጫ በማጽዳት ላይ...';

  @override
  String get featureFlagSuccess => 'ስኬት';

  @override
  String get featureFlagError => 'ስህተት';

  @override
  String get featureFlagClearCacheSuccess =>
      'መሸጎጫ በተሳካ ሁኔታ ጸድቷል። እባክዎ መተግበሪያውን እንደገና ያስጀምሩት።';

  @override
  String get featureFlagClearCacheFailure =>
      'አንዳንድ መሸጎጫ ንጥሎችን ማጽዳት አልተሳካም። ለዝርዝሮች የምዝግብ ማስታወሻዎችን ይመልከቱ።';

  @override
  String get featureFlagOk => 'እሺ';

  @override
  String get featureFlagCacheInformation => 'መሸጎጫ መረጃ';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'ጠቅላላ የመሸጎጫ መጠን፡ $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'መሸጎጫ የሚከተሉትን ያጠቃልላል\n• የማሳወቂያ ታሪክ\n• የተጠቃሚ መገለጫ ውሂብ\n• የቪዲዮ ድንክዬዎች\n• ጊዜያዊ ፋይሎች\n• የውሂብ ጎታ ኢንዴክሶች';

  @override
  String get relaySettingsTitle => 'ቅብብሎሽ';

  @override
  String get relaySettingsInfoTitle => 'Divine ክፍት ስርዓት ነው - ግንኙነቶችዎን ይቆጣጠራሉ።';

  @override
  String get relaySettingsInfoDescription =>
      'እነዚህ ማስተላለፊያዎች የእርስዎን ይዘት ባልተማከለው Nostr አውታረ መረብ ላይ ያሰራጫሉ። እንደፈለጉ ማሰራጫዎችን ማከል ወይም ማስወገድ ይችላሉ።';

  @override
  String get relaySettingsLearnMoreNostr => 'ስለ Nostr ተጨማሪ ተማር →';

  @override
  String get relaySettingsFindPublicRelays => 'የህዝብ ሪሌዮችን በ nostr.co.uk ፈልግ →';

  @override
  String get relaySettingsAppNotFunctional => 'መተግበሪያ ተግባራዊ አይደለም።';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine ቪዲዮዎችን ለመጫን፣ ይዘትን ለመለጠፍ እና ውሂብ ለማመሳሰል ቢያንስ አንድ ቅብብል ያስፈልገዋል።';

  @override
  String get relaySettingsRestoreDefaultRelay => 'ነባሪ ቅብብሎሽ እነበረበት መልስ';

  @override
  String get relaySettingsAddCustomRelay => 'ብጁ ቅብብል ያክሉ';

  @override
  String get relaySettingsAddRelay => 'ቅብብል ጨምር';

  @override
  String get relaySettingsRetry => 'እንደገና ይሞክሩ';

  @override
  String get relaySettingsNoStats => 'እስካሁን ምንም ስታቲስቲክስ የለም።';

  @override
  String get relaySettingsConnection => 'ግንኙነት';

  @override
  String get relaySettingsConnected => 'ተገናኝቷል።';

  @override
  String get relaySettingsDisconnected => 'ግንኙነቱ ተቋርጧል';

  @override
  String get relaySettingsSessionDuration => 'የክፍለ ጊዜው ቆይታ';

  @override
  String get relaySettingsLastConnected => 'መጨረሻ የተገናኘው።';

  @override
  String get relaySettingsDisconnectedLabel => 'ግንኙነቱ ተቋርጧል';

  @override
  String get relaySettingsReason => 'ምክንያት';

  @override
  String get relaySettingsActiveSubscriptions => 'ንቁ የደንበኝነት ምዝገባዎች';

  @override
  String get relaySettingsTotalSubscriptions => 'ጠቅላላ የደንበኝነት ምዝገባዎች';

  @override
  String get relaySettingsEventsReceived => 'ክስተቶች ተቀብለዋል';

  @override
  String get relaySettingsEventsSent => 'ክስተቶች ተልከዋል።';

  @override
  String get relaySettingsRequestsThisSession => 'ይህንን ክፍለ ጊዜ ጠይቋል';

  @override
  String get relaySettingsFailedRequests => 'ያልተሳኩ ጥያቄዎች';

  @override
  String relaySettingsLastError(String error) {
    return 'የመጨረሻው ስህተት፡ $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'የማስተላለፊያ መረጃን በመጫን ላይ...';

  @override
  String get relaySettingsAboutRelay => 'ስለ ሪሌይ';

  @override
  String get relaySettingsSupportedNips => 'የሚደገፉ NIPዎች';

  @override
  String get relaySettingsSoftware => 'ሶፍትዌር';

  @override
  String get relaySettingsViewWebsite => 'ድህረ ገጽ ይመልከቱ';

  @override
  String get relaySettingsRemoveRelayTitle => 'ሪሌይ ይወገድ?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'እርግጠኛ ነዎት ይህን ቅብብል ማስወገድ ይፈልጋሉ?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'ሰርዝ';

  @override
  String get relaySettingsRemove => 'አስወግድ';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'የተወገደ ቅብብል፡ $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'ቅብብሎሽ ማስወገድ አልተሳካም።';

  @override
  String get relaySettingsForcingReconnection =>
      'የዝውውር ዳግም ግንኙነትን በማስገደድ ላይ...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'ከ $count ሪሌይ(ዎች) ጋር ተገናኝቷል!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'ከቅብብሎሽ ጋር መገናኘት አልተሳካም። እባክዎ የአውታረ መረብ ግንኙነትዎን ያረጋግጡ።';

  @override
  String get relaySettingsAddRelayTitle => 'ቅብብል ጨምር';

  @override
  String get relaySettingsAddRelayPrompt =>
      'ማከል የምትፈልገውን የሪሌይ WebSocket URL አስገባ:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'በ nostr.co.uk ላይ የህዝብ ማሰራጫዎችን ያስሱ';

  @override
  String get relaySettingsAdd => 'አክል';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'የተጨመረው ቅብብሎሽ፡ $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'ቅብብሎሽ ማከል አልተሳካም። እባክህ URLን ተመልከት እና እንደገና ሞክር።';

  @override
  String get relaySettingsInvalidUrl => 'ሪሌይ URL በ wss:// ወይም ws:// መጀመር አለበት።';

  @override
  String get relaySettingsInsecureUrl =>
      'የሪሌይ URL wss:// መጠቀም አለበት (ws:// ለlocalhost ብቻ ይፈቀዳል)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'ወደነበረበት የተመለሰ ነባሪ ቅብብሎሽ፡ $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'ነባሪ ቅብብሎሽ ወደነበረበት መመለስ አልተሳካም። እባክዎ የአውታረ መረብ ግንኙነትዎን ያረጋግጡ።';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'አሳሽ መክፈት አልተቻለም';

  @override
  String get relaySettingsFailedToOpenLink => 'አገናኝ መክፈት አልተሳካም።';

  @override
  String get relaySettingsExternalRelay => 'ውጫዊ ቅብብሎሽ';

  @override
  String get relaySettingsNotConnected => 'አልተገናኘም';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'ከ$duration በፊት ተቋርጧል';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count ደንበኝነቶች';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count ክስተቶች';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'ከ$duration በፊት';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine ለያልተማከለ ማተም Nostr ፕሮቶኮልን ይጠቀማል። ይዘትዎ በሚመርጧቸው ቅብብሎሾች ላይ ይኖራል፣ ቁልፎችዎም ማንነትዎ ናቸው።';

  @override
  String get nostrSettingsSectionNetwork => 'አውታረ መረብ';

  @override
  String get nostrSettingsSectionAccount => 'መለያ';

  @override
  String get nostrSettingsSectionDangerZone => 'አደገኛ ቦታ';

  @override
  String get nostrSettingsRelays => 'ቅብብሎሾች';

  @override
  String get nostrSettingsRelaysSubtitle => 'የNostr ቅብብሎሽ ግንኙነቶችን ያስተዳድሩ';

  @override
  String get nostrSettingsRelayDiagnostics => 'የቅብብሎሽ ምርመራ';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'የቅብብሎሽ ግንኙነትን እና የአውታረ መረብ ችግሮችን ያስሱ';

  @override
  String get nostrSettingsMediaServers => 'የሚዲያ አገልጋዮች';

  @override
  String get nostrSettingsMediaServersSubtitle => 'የBlossom ማስጫኛ አገልጋዮችን ያቀናብሩ';

  @override
  String get nostrSettingsDeveloperOptions => 'የገንቢ አማራጮች';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'የአካባቢ መቀየሪያ እና የማረሚያ ቅንብሮች';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'ሊያደናቅፉ የሚችሉ የባህሪ ባንዲራዎችን ቀይር።';

  @override
  String get nostrSettingsKeyManagement => 'የቁልፍ አስተዳደር';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'የNostr ቁልፎችዎን ወደ ውጭ ይላኩ፣ ምትኬ ያስቀምጡ እና ይመልሱ';

  @override
  String get nostrSettingsRemoveKeys => 'ቁልፎችን ከመሣሪያው አስወግድ';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'የግል ቁልፍዎን ከዚህ መሣሪያ ብቻ ይሰርዙ። ይዘትዎ በቅብብሎሾች ላይ ይቆያል፣ ግን መለያዎን እንደገና ለመጠቀም የnsec ምትኬዎን ያስፈልግዎታል።';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'ቁልፎችን ከዚህ መሣሪያ ማስወገድ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'ቁልፎችን ማስወገድ አልተሳካም፦ $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'መለያ እና ውሂብ ሰርዝ';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'መለያዎን እና ሁሉንም ይዘት ከNostr ቅብብሎሾች ላይ በቋሚነት ይሰርዙ። ይህ ሊመለስ አይችልም።';

  @override
  String get relayDiagnosticTitle => 'ቅብብል ምርመራዎች';

  @override
  String get relayDiagnosticRefreshTooltip => 'ምርመራዎችን ያድሱ';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'የመጨረሻው መታደስ፡ $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'የማስተላለፊያ ሁኔታ';

  @override
  String get relayDiagnosticInitialized => 'ተጀመረ';

  @override
  String get relayDiagnosticReady => 'ዝግጁ';

  @override
  String get relayDiagnosticNotInitialized => 'አልተጀመረም።';

  @override
  String get relayDiagnosticDatabaseEvents => 'የውሂብ ጎታ ክስተቶች';

  @override
  String get relayDiagnosticActiveSubscriptions => 'ንቁ የደንበኝነት ምዝገባዎች';

  @override
  String get relayDiagnosticExternalRelays => 'የውጭ ማስተላለፊያዎች';

  @override
  String get relayDiagnosticConfigured => 'የተዋቀረ';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count ቅብብል(ዎች)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'ተገናኝቷል።';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'የቪዲዮ ዝግጅቶች';

  @override
  String get relayDiagnosticHomeFeed => 'የቤት ምግብ';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get relayDiagnosticDiscovery => 'ግኝት';

  @override
  String get relayDiagnosticLoading => 'በመጫን ላይ';

  @override
  String get relayDiagnosticYes => 'አዎ';

  @override
  String get relayDiagnosticNo => 'አይ';

  @override
  String get relayDiagnosticTestDirectQuery => 'ቀጥተኛ መጠይቅን ሞክር';

  @override
  String get relayDiagnosticNetworkConnectivity => 'የአውታረ መረብ ግንኙነት';

  @override
  String get relayDiagnosticRunNetworkTest => 'የአውታረ መረብ ሙከራን አሂድ';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom አገልጋይ';

  @override
  String get relayDiagnosticTestAllEndpoints => 'ሁሉንም የመጨረሻ ነጥቦችን ይሞክሩ';

  @override
  String get relayDiagnosticStatus => 'ሁኔታ';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'ስህተት';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake ኤፒአይ';

  @override
  String get relayDiagnosticBaseUrl => 'መሰረታዊ URL';

  @override
  String get relayDiagnosticSummary => 'ማጠቃለያ';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount እሺ (አማካኝ ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'ሁሉንም እንደገና ሞክር';

  @override
  String get relayDiagnosticRetrying => 'እንደገና በመሞከር ላይ...';

  @override
  String get relayDiagnosticRetryConnection => 'ግንኙነትን እንደገና ይሞክሩ';

  @override
  String get relayDiagnosticTroubleshooting => 'መላ መፈለግ';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• አረንጓዴ ሁኔታ = የተገናኘ እና የሚሰራ\n• ቀይ ሁኔታ = ግንኙነት አልተሳካም።\n• የአውታረ መረብ ሙከራ ካልተሳካ የበይነመረብ ግንኙነትን ያረጋግጡ\n• ማስተላለፎች ከተዋቀሩ ግን ካልተገናኙ \"ግንኙነቱን እንደገና ሞክር\" ን ይንኩ።\n• ለማረም ይህንን ስክሪን ያንሱ';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'ሁሉም REST የመጨረሻ ነጥቦች ጤናማ ናቸው!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'አንዳንድ REST የመጨረሻ ነጥቦች አልተሳኩም - ዝርዝሮችን ከላይ ይመልከቱ';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'በመረጃ ቋት ውስጥ $count የቪዲዮ ክስተቶች ተገኝተዋል';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'መጠይቁ አልተሳካም፡ $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'ከ $count ሪሌይ(ዎች) ጋር ተገናኝቷል!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'ከማንኛውም ማስተላለፊያዎች ጋር መገናኘት አልተሳካም።';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'የግንኙነት ድጋሚ መሞከር አልተሳካም፦ $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'ተገናኝቷል እና የተረጋገጠ';

  @override
  String get relayDiagnosticConnectedOnly => 'ተገናኝቷል።';

  @override
  String get relayDiagnosticNotConnected => 'አልተገናኘም።';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'ምንም ቅብብሎሽ አልተዋቀረም።';

  @override
  String get relayDiagnosticFailed => 'አልተሳካም።';

  @override
  String get notificationSettingsTitle => 'ማሳወቂያዎች';

  @override
  String get notificationSettingsResetTooltip => 'ወደ ነባሪዎች ዳግም አስጀምር';

  @override
  String get notificationSettingsTypes => 'የማሳወቂያ ዓይነቶች';

  @override
  String get notificationSettingsLikes => 'መውደዶች';

  @override
  String get notificationSettingsLikesSubtitle => 'አንድ ሰው ቪዲዮዎችዎን ሲወድ';

  @override
  String get notificationSettingsComments => 'አስተያየቶች';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'አንድ ሰው በቪዲዮዎችዎ ላይ አስተያየት ሲሰጥ';

  @override
  String get notificationSettingsFollows => 'ይከተላል';

  @override
  String get notificationSettingsFollowsSubtitle => 'ሰው ሲከተልህ';

  @override
  String get notificationSettingsMentions => 'ይጠቅሳል';

  @override
  String get notificationSettingsMentionsSubtitle => 'እርስዎ ሲጠቀሱ';

  @override
  String get notificationSettingsReposts => 'ድጋሚ ልጥፎች';

  @override
  String get notificationSettingsRepostsSubtitle => 'አንድ ሰው ቪዲዮዎችህን በድጋሚ ሲለጥፍ';

  @override
  String get notificationSettingsSystem => 'ስርዓት';

  @override
  String get notificationSettingsSystemSubtitle =>
      'የመተግበሪያ ዝመናዎች እና የስርዓት መልዕክቶች';

  @override
  String get notificationSettingsPushNotificationsSection => 'ማሳወቂያዎችን ግፋ';

  @override
  String get notificationSettingsPushNotifications => 'ማሳወቂያዎችን ግፋ';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'መተግበሪያ ሲዘጋ ማሳወቂያዎችን ይቀበሉ';

  @override
  String get notificationSettingsSound => 'ድምፅ';

  @override
  String get notificationSettingsSoundSubtitle => 'ለማሳወቂያዎች ድምጽን ያጫውቱ';

  @override
  String get notificationSettingsVibration => 'ንዝረት';

  @override
  String get notificationSettingsVibrationSubtitle => 'ለማሳወቂያዎች ንዘር';

  @override
  String get notificationSettingsActions => 'ድርጊቶች';

  @override
  String get notificationSettingsMarkAllAsRead => 'ሁሉንም እንደተነበቡ ምልክት ያድርጉበት';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'ሁሉንም ማሳወቂያዎች እንደተነበቡ ምልክት ያድርጉባቸው';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'ሁሉም ማሳወቂያዎች እንደተነበቡ ምልክት ተደርጎባቸዋል';

  @override
  String get notificationSettingsResetToDefaults =>
      'ቅንብሮች ወደ ነባሪዎች ዳግም ተጀምረዋል።';

  @override
  String get notificationSettingsAbout => 'ስለ ማሳወቂያዎች';

  @override
  String get notificationSettingsAboutDescription =>
      'ማሳወቂያዎች የተጎላበተው በNostr ፕሮቶኮል ነው። የቅጽበታዊ ዝማኔዎች ከNostr ቅብብሎሽ ጋር ባለዎት ግንኙነት ይወሰናል። አንዳንድ ማሳወቂያዎች መዘግየቶች ሊኖራቸው ይችላል።';

  @override
  String get safetySettingsTitle => 'ደህንነት እና ግላዊነት';

  @override
  String get safetySettingsLabel => 'ቅንብሮች';

  @override
  String get safetySettingsWhatYouSee => 'የሚያዩት';

  @override
  String get safetySettingsWhatYouPublish => 'የሚያትሙት';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'በDivine የተስተናገዱ ቪዲዮዎችን ብቻ አሳይ';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'ከሌሎች የሚዲያ አስተናጋጆች የቀረቡ ቪዲዮዎችን ደብቅ';

  @override
  String get safetySettingsModeration => 'ሞደሬሽን';

  @override
  String get safetySettingsBlockedUsers => 'የታገዱ ተጠቃሚዎች';

  @override
  String get safetySettingsAgeVerification => 'የዕድሜ ማረጋገጫ';

  @override
  String get safetySettingsAgeConfirmation =>
      '18 ዓመት ወይም ከዚያ በላይ መሆኔን አረጋግጣለሁ።';

  @override
  String get safetySettingsAgeRequired => 'የአዋቂ ይዘት ለማየት ያስፈልጋል';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle => 'ይፋዊ የሽምግልና አገልግሎት (በነባሪ)';

  @override
  String get safetySettingsPeopleIFollow => 'የምከተላቸው ሰዎች';

  @override
  String get safetySettingsPeopleIFollowSubtitle => 'ለሚከተሏቸው ሰዎች መለያዎች ይመዝገቡ';

  @override
  String get safetySettingsAddCustomLabeler => 'ብጁ መሰየሚያ ያክሉ';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub አስገባ...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'ብጁ መለያ አክል';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'npub አድራሻ አስገባ';

  @override
  String get safetySettingsNoBlockedUsers => 'ምንም የታገዱ ተጠቃሚዎች የሉም';

  @override
  String get safetySettingsUnblock => 'እገዳ አንሳ';

  @override
  String get safetySettingsUserUnblocked => 'ተጠቃሚው ታግዷል';

  @override
  String get safetySettingsCancel => 'ሰርዝ';

  @override
  String get safetySettingsAdd => 'አክል';

  @override
  String get analyticsTitle => 'የፈጣሪ ትንታኔ';

  @override
  String get analyticsDiagnosticsTooltip => 'ምርመራዎች';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'ምርመራዎችን ቀያይር';

  @override
  String get analyticsRetry => 'እንደገና ይሞክሩ';

  @override
  String get analyticsUnableToLoad => 'ትንታኔዎችን መጫን አልተቻለም።';

  @override
  String get analyticsSignInRequired => 'የፈጣሪ ትንታኔን ለማየት ይግቡ።';

  @override
  String get analyticsViewDataUnavailable =>
      'ለእነዚህ ልጥፎች ከቅብብሎሽ እይታዎች በአሁኑ ጊዜ አይገኙም። መውደድ/አስተያየት/እንደገና መለጠፍ መለኪያዎች አሁንም ትክክል ናቸው።';

  @override
  String get analyticsViewDataTitle => 'ውሂብ ይመልከቱ';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'ተዘምኗል $time • ውጤቶች ሲገኙ መውደዶችን፣ አስተያየቶችን፣ ድጋሚ ልጥፎችን እና እይታዎችን ከFunnelcake ይጠቀማሉ።';
  }

  @override
  String get analyticsVideos => 'ቪዲዮዎች';

  @override
  String get analyticsViews => 'እይታዎች';

  @override
  String get analyticsInteractions => 'መስተጋብር';

  @override
  String get analyticsEngagement => 'ተሳትፎ';

  @override
  String get analyticsFollowers => 'ተከታዮች';

  @override
  String get analyticsAvgPerPost => 'አማካኝ/ልጥፍ';

  @override
  String get analyticsInteractionMix => 'መስተጋብር ድብልቅ';

  @override
  String get analyticsLikes => 'መውደዶች';

  @override
  String get analyticsComments => 'አስተያየቶች';

  @override
  String get analyticsReposts => 'ድጋሚ ልጥፎች';

  @override
  String get analyticsPerformanceHighlights => 'የአፈጻጸም ድምቀቶች';

  @override
  String get analyticsMostViewed => 'በብዛት የታዩት።';

  @override
  String get analyticsMostDiscussed => 'በብዛት ተወያይተዋል።';

  @override
  String get analyticsMostReposted => 'በጣም በድጋሚ የተለጠፈ';

  @override
  String get analyticsNoVideosYet => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get analyticsViewDataUnavailableShort => 'የእይታ ውሂብ አይገኝም';

  @override
  String analyticsViewsCount(String count) {
    return '$count እይታዎች';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count አስተያየቶች';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count ድጋሚ ልጥፎች';
  }

  @override
  String get analyticsTopContent => 'ከፍተኛ ይዘት';

  @override
  String get analyticsPublishPrompt => 'ደረጃዎችን ለማየት ጥቂት ቪዲዮዎችን ያትሙ።';

  @override
  String get analyticsEngagementRateExplainer =>
      'የቀኝ ጎን % = የተሳትፎ መጠን (ግንኙነቶች በእይታዎች የተከፋፈሉ)።';

  @override
  String get analyticsEngagementRateNoViews =>
      'የተሳትፎ መጠን የእይታ ውሂብ ያስፈልገዋል; እይታዎች እስኪገኙ ድረስ እሴቶች እንደ N/A ያሳያሉ።';

  @override
  String get analyticsEngagementLabel => 'ተሳትፎ';

  @override
  String get analyticsViewsUnavailable => 'እይታዎች አይገኙም።';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count መስተጋብር';
  }

  @override
  String get analyticsPostAnalytics => 'ትንታኔ ይለጥፉ';

  @override
  String get analyticsOpenPost => 'ፖስት ክፈት';

  @override
  String get analyticsRecentDailyInteractions => 'የቅርብ ጊዜ ዕለታዊ ግንኙነቶች';

  @override
  String get analyticsNoActivityYet => 'በዚህ ክልል ውስጥ እስካሁን ምንም እንቅስቃሴ የለም።';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'መስተጋብር = መውደዶች + አስተያየቶች + በፖስታ ቀን የተለጠፈ።';

  @override
  String get analyticsDailyBarExplainer =>
      'የአሞሌ ርዝመት በዚህ መስኮት ውስጥ ካለህ ከፍተኛ ቀን ጋር አንጻራዊ ነው።';

  @override
  String get analyticsAudienceSnapshot => 'የታዳሚዎች ቅጽበታዊ ገጽ እይታ';

  @override
  String analyticsFollowersCount(String count) {
    return 'ተከታዮች፡ $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'በመከተል፡ $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Funnelcake የታዳሚ ትንታኔ መጨረሻ ነጥቦችን ሲጨምር፣ የታዳሚ ምንጭ/ጂኦ/ጊዜ ዝርዝሮች ይሞላሉ።';

  @override
  String get analyticsRetention => 'ማቆየት።';

  @override
  String get analyticsRetentionWithViews =>
      'የማቆያ ኩርባ እና የምልከታ ጊዜ መከፋፈል በሰከንድ/በባልዲ ማቆየት ከFunnelcake ሲመጣ ይታያል።';

  @override
  String get analyticsRetentionWithoutViews =>
      'የእይታ+ሰዓት-ጊዜ ትንታኔ በFunnelcake እስኪመለስ ድረስ የማቆየት ውሂብ አይገኝም።';

  @override
  String get analyticsDiagnostics => 'ምርመራዎች';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'ጠቅላላ ቪዲዮዎች፡ $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'ከእይታዎች ጋር፡ $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'የጎደሉ እይታዎች፡ $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'ሃይድሬድ (ጅምላ)፡ $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'የደረቀ (/እይታዎች)፡ $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'ምንጮች፡ $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'የቋሚ መረጃን ተጠቀም';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'አዲስ Divine መለያ ይፍጠሩ';

  @override
  String get authSignInDifferentAccount => 'በተለየ መለያ ይግቡ';

  @override
  String get authSignBackIn => 'ተመልሰው ይግቡ';

  @override
  String get authTermsPrefix =>
      'ከላይ ያለውን አማራጭ በመምረጥ፣ ቢያንስ 16 ዓመት እንደሆናችሁ አረጋግጠዋል እና በዚህ ተስማምተዋል።';

  @override
  String get authTermsOfService => 'የአገልግሎት ውል';

  @override
  String get authPrivacyPolicy => 'የግላዊነት ፖሊሲ';

  @override
  String get authTermsAnd => ', እና';

  @override
  String get authSafetyStandards => 'የደህንነት ደረጃዎች';

  @override
  String get authAmberNotInstalled => 'Amber መተግበሪያ አልተጫነም።';

  @override
  String get authAmberConnectionFailed => 'ከAmber ጋር መገናኘት አልተሳካም';

  @override
  String get authPasswordResetSent =>
      'በዚያ ኢሜይል መለያ ካለ፣ የይለፍ ቃል ዳግም ማስጀመሪያ አገናኝ ተልኳል።';

  @override
  String get authSignInTitle => 'ይግቡ';

  @override
  String get authEmailLabel => 'ኢሜይል';

  @override
  String get authPasswordLabel => 'የይለፍ ቃል';

  @override
  String get authConfirmPasswordLabel => 'Confirm password';

  @override
  String get authEmailRequired => 'Email is required';

  @override
  String get authEmailInvalid => 'Please enter a valid email';

  @override
  String get authPasswordRequired => 'Password is required';

  @override
  String get authConfirmPasswordRequired => 'Please confirm your password';

  @override
  String get authPasswordsDoNotMatch => 'Passwords don\'t match';

  @override
  String get authForgotPassword => 'የይለፍ ቃል ረሱ?';

  @override
  String get authImportNostrKey => 'አስመጣ Nostr ቁልፍ';

  @override
  String get authConnectSignerApp => 'ከፈራሚ መተግበሪያ ጋር ይገናኙ';

  @override
  String get authSignInWithAmber => 'በAmber ግባ';

  @override
  String get authSignInOptionsTitle => 'የመግባት አማራጮች';

  @override
  String get authInfoEmailPasswordTitle => 'ኢሜይል እና የይለፍ ቃል';

  @override
  String get authInfoEmailPasswordDescription =>
      'በDivine መለያህ ግባ። በኢሜይል እና በይለፍ ቃል ከተመዘገብክ፣ እዚህ ተጠቀማቸው።';

  @override
  String get authInfoImportNostrKeyDescription =>
      'አስቀድሞ Nostr ማንነት አለህ? የእርስዎን nsec የግል ቁልፍ ከሌላ ደንበኛ ያስመጡ።';

  @override
  String get authInfoSignerAppTitle => 'Signer መተግበሪያ';

  @override
  String get authInfoSignerAppDescription =>
      'ለተሻሻለ ቁልፍ ደህንነት እንደ NIP-46 ተስማሚ የርቀት ፈራሚ በመጠቀም ይገናኙ።';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'የእርስዎን Nostr ቁልፎች ደህንነቱ በተጠበቀ ሁኔታ ለማስተዳደር የAmber ፈራሚ መተግበሪያን በAndroid ይጠቀሙ።';

  @override
  String get authCreateAccountTitle => 'መለያ ይፍጠሩ';

  @override
  String get authBackToInviteCode => 'ወደ ግብዣ ኮድ ተመለስ';

  @override
  String get authUseDivineNoBackup => 'ምንም ምትኬ ሳይኖር Divine ተጠቀም';

  @override
  String get authSkipConfirmTitle => 'አንድ የመጨረሻ ነገር...';

  @override
  String get authSkipConfirmKeyCreated =>
      'ገብተሃል! የእርስዎን Divine መለያ የሚያስተናግድ አስተማማኝ ቁልፍ እንፈጥራለን።';

  @override
  String get authSkipConfirmKeyOnly =>
      'ያለ ኢሜል፣ ይህ መለያ የእርስዎ መሆኑን የሚያውቅ ብቸኛው መንገድ የእርስዎ ቁልፍ ነው።';

  @override
  String get authSkipConfirmRecommendEmail =>
      'በመተግበሪያው ውስጥ ቁልፍዎን መድረስ ይችላሉ ፣ ግን ቴክኒካል ካልሆኑ አሁን ኢሜይል እና የይለፍ ቃል ማከል እንመክራለን። ይህ መሳሪያ ከጠፋብዎት ወይም ዳግም ካስጀመሩት ወደ መለያዎ መግባት እና ወደነበረበት መመለስ ቀላል ያደርገዋል።';

  @override
  String get authAddEmailPassword => 'ኢሜይል እና የይለፍ ቃል ያክሉ';

  @override
  String get authUseThisDeviceOnly => 'ይህንን መሳሪያ ብቻ ይጠቀሙ';

  @override
  String get authCompleteRegistration => 'ምዝገባዎን ያጠናቅቁ';

  @override
  String get authVerifying => 'በማረጋገጥ ላይ...';

  @override
  String get authVerificationLinkSent => 'የማረጋገጫ አገናኝ ልከናል ወደ፡-';

  @override
  String get authClickVerificationLink =>
      'እባክዎን በኢሜልዎ ውስጥ ያለውን አገናኝ ጠቅ ያድርጉ\nምዝገባዎን ያጠናቅቁ.';

  @override
  String get authPleaseWaitVerifying => 'እባክህ ኢሜልህን እስክናረጋግጥ ጠብቅ...';

  @override
  String get authWaitingForVerification => 'ማረጋገጫን በመጠበቅ ላይ';

  @override
  String get authOpenEmailApp => 'የኢሜል መተግበሪያን ይክፈቱ';

  @override
  String get authWelcomeToDivine => 'እንኳን ወደ Divine በደህና መጣህ!';

  @override
  String get authEmailVerified => 'ኢሜይልህ ተረጋግጧል።';

  @override
  String get authSigningYouIn => 'እርስዎን በማስገባት ላይ';

  @override
  String get authErrorTitle => 'ኧረ ወይኔ.';

  @override
  String get authVerificationFailed => 'ኢሜልህን ማረጋገጥ አልቻልንም።\nእባክዎ እንደገና ይሞክሩ።';

  @override
  String get authStartOver => 'እንደገና ጀምር';

  @override
  String get authEmailVerifiedLogin => 'ኢሜል ተረጋግጧል! ለመቀጠል እባክዎ ይግቡ።';

  @override
  String get authVerificationLinkExpired =>
      'ይህ የማረጋገጫ አገናኝ ከአሁን በኋላ የሚሰራ አይደለም።';

  @override
  String get authVerificationConnectionError =>
      'ኢሜይል ማረጋገጥ አልተቻለም። እባክዎ ግንኙነትዎን ያረጋግጡ እና እንደገና ይሞክሩ።';

  @override
  String get authWaitlistConfirmTitle => 'ገብተሃል!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'ዝመናዎችን በ$email እናጋራለን።\nተጨማሪ የግብዣ ኮዶች ሲገኙ፣ እንልክልሃለን።';
  }

  @override
  String get authOk => 'እሺ';

  @override
  String get authInviteUnavailable => 'የግብዣ መዳረሻ ለጊዜው አይገኝም።';

  @override
  String get authInviteUnavailableBody =>
      'ከአፍታ በኋላ እንደገና ይሞክሩ፣ ወይም ለመግባት እገዛ ከፈለጉ ድጋፍን ያግኙ።';

  @override
  String get authTryAgain => 'እንደገና ይሞክሩ';

  @override
  String get authContactSupport => 'ድጋፍን ያነጋግሩ';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email መክፈት አልተቻለም';
  }

  @override
  String get authAddInviteCode => 'የግብዣ ኮድዎን ያክሉ';

  @override
  String get authInviteCodeLabel => 'የግብዣ ኮድ';

  @override
  String get authEnterYourCode => 'ኮድዎን ያስገቡ';

  @override
  String get authNext => 'ቀጥሎ';

  @override
  String get authJoinWaitlist => 'የተጠባባቂ ዝርዝሩን ይቀላቀሉ';

  @override
  String get authJoinWaitlistTitle => 'የተጠባባቂ ዝርዝሩን ይቀላቀሉ';

  @override
  String get authJoinWaitlistDescription =>
      'ኢሜልዎን ያጋሩ እና መዳረሻ ሲከፈት ማሻሻያዎችን እንልካለን።';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'የመዳረሻ እገዛን ጋብዝ';

  @override
  String get authGeneratingConnection => 'ግንኙነት በማመንጨት ላይ...';

  @override
  String get authConnectedAuthenticating => 'ተገናኝቷል! በማረጋገጥ ላይ...';

  @override
  String get authConnectionTimedOut => 'ግንኙነቱ ጊዜው አልፎበታል።';

  @override
  String get authApproveConnection =>
      'በፈራሚ መተግበሪያዎ ውስጥ ያለውን ግንኙነት ማጽደቁን ያረጋግጡ።';

  @override
  String get authConnectionCancelled => 'ግንኙነት ተሰርዟል።';

  @override
  String get authConnectionCancelledMessage => 'ግንኙነቱ ተሰርዟል።';

  @override
  String get authConnectionFailed => 'ግንኙነት አልተሳካም።';

  @override
  String get authUnknownError => 'ያልታወቀ ስህተት ተከስቷል።';

  @override
  String get authUrlCopied => 'URL ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get authConnectToDivine => 'ከDivine ጋር ተገናኝ';

  @override
  String get authPasteBunkerUrl => 'bunker:// URL ለጥፍ';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'ልክ ያልሆነ Bunker URL። በ bunker:// መጀመር አለበት';

  @override
  String get authScanSignerApp => 'ከእርስዎ ጋር ይቃኙ\nለማገናኘት ፈራሚ መተግበሪያ።';

  @override
  String authWaitingForConnection(int seconds) {
    return 'ግንኙነትን በመጠበቅ ላይ... $secondsዎች';
  }

  @override
  String get authCopyUrl => 'ቅዳ URL';

  @override
  String get authShare => 'አጋራ';

  @override
  String get authAddBunker => 'ማሰሪያ ጨምር';

  @override
  String get authCompatibleSignerApps => 'ተኳኋኝ Signer መተግበሪያዎች';

  @override
  String get authFailedToConnect => 'መገናኘት አልተሳካም።';

  @override
  String get authResetPasswordTitle => 'የይለፍ ቃል ዳግም አስጀምር';

  @override
  String get authResetPasswordSubtitle =>
      'እባክዎ አዲሱን የይለፍ ቃልዎን ያስገቡ። ርዝመቱ ቢያንስ 8 ቁምፊዎች መሆን አለበት።';

  @override
  String get authNewPasswordLabel => 'አዲስ የይለፍ ቃል';

  @override
  String get authConfirmNewPasswordLabel => 'Confirm new password';

  @override
  String get authPasswordTooShort => 'የይለፍ ቃል ቢያንስ 8 ቁምፊዎች መሆን አለበት።';

  @override
  String get authPasswordResetSuccess => 'የይለፍ ቃል ዳግም ማስጀመር ተሳክቷል። እባክዎ ይግቡ።';

  @override
  String get authPasswordResetFailed => 'የይለፍ ቃል ዳግም ማስጀመር አልተሳካም።';

  @override
  String get authUnexpectedError => 'ያልተጠበቀ ስህተት ተከስቷል። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authUpdatePassword => 'የይለፍ ቃል አዘምን';

  @override
  String get authSecureAccountTitle => 'ደህንነቱ የተጠበቀ መለያ';

  @override
  String get authUnableToAccessKeys => 'ቁልፎችዎን መድረስ አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authRegistrationFailed => 'ምዝገባ አልተሳካም።';

  @override
  String get authRegistrationComplete => 'ምዝገባው ተጠናቅቋል። እባክህ ኢሜልህን አረጋግጥ።';

  @override
  String get authVerificationFailedTitle => 'ማረጋገጥ አልተሳካም።';

  @override
  String get authClose => 'ገጠመ';

  @override
  String get authAccountSecured => 'መለያ ደህንነቱ የተጠበቀ!';

  @override
  String get authAccountLinkedToEmail => 'መለያዎ አሁን ከኢሜይልዎ ጋር ተገናኝቷል።';

  @override
  String get authVerifyYourEmail => 'ኢሜልዎን ያረጋግጡ';

  @override
  String get authClickLinkContinue =>
      'ምዝገባውን ለማጠናቀቅ በኢሜልዎ ውስጥ ያለውን አገናኝ ጠቅ ያድርጉ። እስከዚያው መተግበሪያውን መጠቀም መቀጠል ይችላሉ።';

  @override
  String get authWaitingForVerificationEllipsis => 'ማረጋገጫን በመጠበቅ ላይ...';

  @override
  String get authContinueToApp => 'ወደ መተግበሪያ ይቀጥሉ';

  @override
  String get authResetPassword => 'የይለፍ ቃል ዳግም አስጀምር';

  @override
  String get authResetPasswordDescription =>
      'የኢሜል አድራሻዎን ያስገቡ እና የይለፍ ቃልዎን እንደገና የሚያስጀምሩበት አገናኝ እንልክልዎታለን።';

  @override
  String get authFailedToSendResetEmail => 'ዳግም ማስጀመር ኢሜይል መላክ አልተሳካም።';

  @override
  String get authUnexpectedErrorShort => 'ያልተጠበቀ ስህተት ተከስቷል።';

  @override
  String get authSending => 'በመላክ ላይ...';

  @override
  String get authSendResetLink => 'ዳግም ማስጀመሪያ አገናኝ ላክ';

  @override
  String get authEmailSent => 'ኢሜል ተልኳል!';

  @override
  String authResetLinkSentTo(String email) {
    return 'የይለፍ ቃል ዳግም ማስጀመሪያ አገናኝ ወደ $email ልከናል። የይለፍ ቃልዎን ለማዘመን እባክዎ በኢሜልዎ ውስጥ ያለውን አገናኝ ጠቅ ያድርጉ።';
  }

  @override
  String get authSignInButton => 'ይግቡ';

  @override
  String get authVerificationErrorTimeout =>
      'የማረጋገጫ ጊዜ አልቋል። እባክዎ እንደገና ለመመዝገብ ይሞክሩ።';

  @override
  String get authVerificationErrorMissingCode => 'ማረጋገጥ አልተሳካም - የፈቀዳ ኮድ ጠፍቷል።';

  @override
  String get authVerificationErrorPollFailed =>
      'ማረጋገጥ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authVerificationErrorNetworkExchange =>
      'በመለያ መግቢያ ጊዜ የአውታረ መረብ ስህተት። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get authVerificationErrorOAuthExchange =>
      'ማረጋገጥ አልተሳካም። እባክዎ እንደገና ለመመዝገብ ይሞክሩ።';

  @override
  String get authVerificationErrorSignInFailed =>
      'መግባት አልተሳካም። እባክህ ራስህ ለመግባት ሞክር።';

  @override
  String get authInviteErrorAlreadyUsed =>
      'ያ የግብዣ ኮድ ከአሁን በኋላ አይገኝም። ወደ የግብዣ ኮድዎ ይመለሱ፣ የተጠባባቂ ዝርዝሩን ይቀላቀሉ ወይም ድጋፍ ሰጪን ያግኙ።';

  @override
  String get authInviteErrorInvalid =>
      'ያ የግብዣ ኮድ አሁን መጠቀም አይቻልም። ወደ የግብዣ ኮድዎ ይመለሱ፣ የተጠባባቂ ዝርዝሩን ይቀላቀሉ ወይም ድጋፍ ሰጪን ያግኙ።';

  @override
  String get authInviteErrorTemporary =>
      'ግብዣህን አሁን ማረጋገጥ አልቻልንም። ወደ የግብዣ ኮድዎ ይመለሱ እና እንደገና ይሞክሩ፣ ወይም ድጋፍን ያግኙ።';

  @override
  String get authInviteErrorUnknown =>
      'ግብዣህን ማግበር አልቻልንም። ወደ የግብዣ ኮድዎ ይመለሱ፣ የተጠባባቂ ዝርዝሩን ይቀላቀሉ ወይም ድጋፍ ሰጪን ያግኙ።';

  @override
  String get shareSheetSave => 'አስቀምጥ';

  @override
  String get shareSheetSaveToGallery => 'ወደ ማዕከለ-ስዕላት አስቀምጥ';

  @override
  String get shareSheetSaveWithWatermark => 'በውሃ ምልክት አስቀምጥ';

  @override
  String get shareSheetSaveVideo => 'ቪዲዮ አስቀምጥ';

  @override
  String get shareSheetAddToClips => 'ወደ ቅንጥቦች ያክሉ';

  @override
  String get shareSheetAddedToClips => 'ወደ ቅንጥቦች ታክሏል።';

  @override
  String get shareSheetAddToClipsFailed => 'ወደ ቅንጥቦች ማከል አልተቻለም';

  @override
  String get shareSheetAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String get shareSheetCopy => 'ቅዳ';

  @override
  String get shareSheetShareVia => 'በ በኩል አጋራ';

  @override
  String get shareSheetReport => 'ሪፖርት አድርግ';

  @override
  String get shareSheetEventJson => 'ክስተት JSON';

  @override
  String get shareSheetEventId => 'የክስተት መታወቂያ';

  @override
  String get shareSheetMoreActions => 'ተጨማሪ ድርጊቶች';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'ወደ ካሜራ ጥቅል ተቀምጧል';

  @override
  String get watermarkDownloadShare => 'አጋራ';

  @override
  String get watermarkDownloadDone => 'ተከናውኗል';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'የፎቶዎች መዳረሻ ያስፈልጋል';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'ቪዲዮዎችን ለማስቀመጥ በቅንብሮች ውስጥ የፎቶዎች መዳረሻ ፍቀድ።';

  @override
  String get watermarkDownloadOpenSettings => 'ቅንብሮችን ይክፈቱ';

  @override
  String get watermarkDownloadNotNow => 'አሁን አይደለም';

  @override
  String get watermarkDownloadFailed => 'ማውረድ አልተሳካም።';

  @override
  String get watermarkDownloadDismiss => 'አሰናብት';

  @override
  String get watermarkDownloadStageDownloading => 'ቪዲዮን በማውረድ ላይ';

  @override
  String get watermarkDownloadStageWatermarking => 'የውሃ ምልክት ማከል';

  @override
  String get watermarkDownloadStageSaving => 'ወደ ካሜራ ጥቅል በማስቀመጥ ላይ';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'ቪዲዮውን ከአውታረ መረብ በማምጣት ላይ...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'የDivine የውሃ ምልክትን በመተግበር ላይ...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'በውሃ ምልክት የተደረገበትን ቪዲዮ ወደ ካሜራ ጥቅልዎ በማስቀመጥ ላይ...';

  @override
  String get uploadProgressVideoUpload => 'ቪዲዮ ሰቀላ';

  @override
  String get uploadProgressPause => 'ለአፍታ አቁም';

  @override
  String get uploadProgressResume => 'ከቆመበት ቀጥል';

  @override
  String get uploadProgressGoBack => 'ተመለስ';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'እንደገና ይሞክሩ ($count ግራ)';
  }

  @override
  String get uploadProgressDelete => 'ሰርዝ';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}d በፊት';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '$countሰ በፊት';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '$countደቂቃ በፊት';
  }

  @override
  String get uploadProgressJustNow => 'ልክ አሁን';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'በመስቀል ላይ $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'ባለበት ቆሟል $percent%';
  }

  @override
  String get badgeExplanationClose => 'ገጠመ';

  @override
  String get badgeExplanationOriginalVineArchive => 'ኦሪጅናል Vine መዝገብ ቤት';

  @override
  String get badgeExplanationCameraProof => 'የካሜራ ማረጋገጫ';

  @override
  String get badgeExplanationAuthenticitySignals => 'የትክክለኛነት ምልክቶች';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'ይህ ቪዲዮ ከInternet Archive የተመለሰ ኦሪጅናል Vine ነው።';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Vine በ2017 ከመዘጋቱ በፊት ArchiveTeam እና Internet Archive በሚሊዮኖች የሚቆጠሩ Vines ለትውልድ ለማቆየት ሰርተዋል። ይህ ይዘት የዚያ ታሪካዊ የጥበቃ ጥረት አካል ነው።';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'ኦሪጅናል ስታትስ፡ $loops ሉፖች';
  }

  @override
  String get badgeExplanationLearnVineArchive => 'ስለ Vine ማህደር አጠባበቅ የበለጠ ይረዱ';

  @override
  String get badgeExplanationLearnProofmode => 'ስለ ProofMode ማረጋገጫ ተጨማሪ ተማር';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'ስለ Divine ትክክለኛነት ምልክቶች የበለጠ ይወቁ';

  @override
  String get badgeExplanationInspectProofCheck => 'በProofCheck መሳሪያ መርምር';

  @override
  String get badgeExplanationInspectMedia => 'የሚዲያ ዝርዝሮችን መርምር';

  @override
  String get badgeExplanationProofmodeVerified =>
      'የዚህ ቪዲዮ ትክክለኛነት የተረጋገጠው የፕሮፍሞድ ቴክኖሎጂን በመጠቀም ነው።';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'ይህ ቪዲዮ የተስተናገደው በDivine ነው እና AI ማወቂያው በሰው ሰራሽ ሊሆን እንደሚችል ይጠቁማል፣ ነገር ግን ምስጠራ ካሜራ-ማረጋገጫ ውሂብን አያካትትም።';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'የአይአይ ማወቂያ ይህ ቪዲዮ የሰው ሰራሽ እንደሆነ ያሳያል፣ ምንም እንኳን ክሪፕቶግራፊክ የካሜራ ማረጋገጫ ውሂብን ባያካትትም።';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'ይህ ቪዲዮ የተስተናገደው በDivine ላይ ነው፣ ነገር ግን እስካሁን ክሪፕቶግራፊክ የካሜራ-ማረጋገጫ ውሂብን አያካትትም።';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'ይህ ቪዲዮ የሚስተናገደው ከDivine ውጪ ነው እና ምስጠራ ካሜራ-ማረጋገጫ ውሂብን አያካትትም።';

  @override
  String get badgeExplanationDeviceAttestation => 'የመሣሪያ ማረጋገጫ';

  @override
  String get badgeExplanationPgpSignature => 'PGP ፊርማ';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA የይዘት ምስክርነቶች';

  @override
  String get badgeExplanationProofManifest => 'ማረጋገጫ አንጸባራቂ';

  @override
  String get badgeExplanationAiDetection => 'AI ማግኘት';

  @override
  String get badgeExplanationAiNotScanned => 'AI ስካን፡ ገና አልተቃኘም።';

  @override
  String get badgeExplanationNoScanResults => 'እስካሁን ምንም የፍተሻ ውጤቶች አልተገኙም።';

  @override
  String get badgeExplanationCheckAiGenerated => 'AI የመነጨ መሆኑን ያረጋግጡ';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% በ AI የመነጨ ዕድል';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'የተቃኘው፡ $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator => 'በሰው አወያይ የተረጋገጠ';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'ፕላቲኒየም፡ የመሣሪያ ሃርድዌር ማረጋገጫ፣ የምስጠራ ፊርማዎች፣ የይዘት ምስክርነቶች (C2PA) እና AI ቅኝት የሰውን አመጣጥ ያረጋግጣል።';

  @override
  String get badgeExplanationVerificationGold =>
      'ወርቅ፡ በሃርድዌር ማረጋገጫ፣ ምስጢራዊ ፊርማዎች እና የይዘት ምስክርነቶች (C2PA) በእውነተኛ መሳሪያ ላይ ተይዟል።';

  @override
  String get badgeExplanationVerificationSilver =>
      'ብር፡ ክሪፕቶግራፊክ ፊርማዎች ይህ ቪዲዮ ከተቀዳ በኋላ እንዳልተለወጠ ያረጋግጣሉ።';

  @override
  String get badgeExplanationVerificationBronze => 'ነሐስ፡ መሰረታዊ የሜታዳታ ፊርማዎች አሉ።';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'ብር፡ AI ስካን ይህ ቪዲዮ በሰው የተፈጠረ ሊሆን እንደሚችል ያረጋግጣል።';

  @override
  String get badgeExplanationNoVerification => 'ለዚህ ቪዲዮ ምንም የማረጋገጫ ውሂብ አይገኝም።';

  @override
  String get shareMenuTitle => 'ቪዲዮ አጋራ';

  @override
  String get shareMenuReportAiContent => 'AI ይዘትን ሪፖርት አድርግ';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'ፈጣን ሪፖርት በ AI የመነጨ ይዘት ተጠርጥሯል።';

  @override
  String get shareMenuReportingAiContent => 'AI ይዘትን ሪፖርት በማድረግ ላይ...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'ይዘትን ሪፖርት ማድረግ አልተሳካም፦ $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'የኤአይ ይዘትን ሪፖርት ማድረግ አልተሳካም፦ $error';
  }

  @override
  String get shareMenuVideoStatus => 'የቪዲዮ ሁኔታ';

  @override
  String get shareMenuViewAllLists => 'ሁሉንም ዝርዝሮች ይመልከቱ →';

  @override
  String get shareMenuShareWith => 'ሼር በማድረግ ያካፍሉ።';

  @override
  String get shareMenuShareViaOtherApps => 'በሌሎች መተግበሪያዎች አጋራ';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'በሌሎች መተግበሪያዎች ያጋሩ ወይም አገናኝ ይቅዱ';

  @override
  String get shareMenuSaveToGallery => 'ወደ ማዕከለ-ስዕላት አስቀምጥ';

  @override
  String get shareMenuSaveOriginalSubtitle => 'የመጀመሪያውን ቪዲዮ ወደ ካሜራ ጥቅል አስቀምጥ';

  @override
  String get shareMenuSaveWithWatermark => 'በውሃ ምልክት አስቀምጥ';

  @override
  String get shareMenuSaveVideo => 'ቪዲዮ አስቀምጥ';

  @override
  String get shareMenuDownloadWithWatermark => 'በDivine የውሃ ምልክት ያውርዱ';

  @override
  String get shareMenuSaveVideoSubtitle => 'ቪዲዮን ወደ ካሜራ ጥቅል አስቀምጥ';

  @override
  String get shareMenuLists => 'ዝርዝሮች';

  @override
  String get shareMenuAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String get shareMenuAddToListSubtitle => 'ወደ የተመረጡ ዝርዝሮችዎ ያክሉ';

  @override
  String get shareMenuCreateNewList => 'አዲስ ዝርዝር ይፍጠሩ';

  @override
  String get shareMenuCreateNewListSubtitle => 'አዲስ የተሰበሰበ ስብስብ ይጀምሩ';

  @override
  String get shareMenuRemovedFromList => 'ከዝርዝሩ ተወግዷል';

  @override
  String get shareMenuFailedToRemoveFromList => 'ከዝርዝሩ ማስወገድ አልተሳካም።';

  @override
  String get shareMenuBookmarks => 'ዕልባቶች';

  @override
  String get shareMenuAddToBookmarks => 'ወደ ዕልባቶች ያክሉ';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'በኋላ ለማየት ያስቀምጡ';

  @override
  String get shareMenuAddToBookmarkSet => 'ወደ ዕልባት ስብስብ ያክሉ';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'በክምችቶች ውስጥ ያደራጁ';

  @override
  String get shareMenuFollowSets => 'የሰዎች ዝርዝሮች';

  @override
  String get shareMenuCreateFollowSet => 'የክትትል ስብስብ ይፍጠሩ';

  @override
  String get shareMenuCreateFollowSetSubtitle => 'በዚህ ፈጣሪ አዲስ ስብስብ ጀምር';

  @override
  String get shareMenuAddToFollowSet => 'ለመከተል አዘጋጅ ያክሉ';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count የሚገኙ ስብስቦችን ይከተሉ';
  }

  @override
  String get peopleListsAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String get peopleListsAddToListSubtitle =>
      'ይህንን ፈጣሪ ከዝርዝሮችዎ ውስጥ በአንዱ ያስቀምጡት።';

  @override
  String get peopleListsSheetTitle => 'ወደ ዝርዝር ያክሉ';

  @override
  String get peopleListsEmptyTitle => 'እስካሁን ምንም ዝርዝሮች የሉም';

  @override
  String get peopleListsEmptySubtitle => 'ሰዎችን መቧደን ለመጀመር ዝርዝር ይፍጠሩ።';

  @override
  String get peopleListsCreateList => 'ዝርዝር ይፍጠሩ';

  @override
  String get peopleListsNewListTitle => 'አዲስ ዝርዝር';

  @override
  String get peopleListsRouteTitle => 'የሰዎች ዝርዝር';

  @override
  String get peopleListsListNameLabel => 'የዝርዝር ስም';

  @override
  String get peopleListsListNameHint => 'የቅርብ ጓደኞች';

  @override
  String get peopleListsCreateButton => 'ፍጠር';

  @override
  String get peopleListsAddPeopleTitle => 'ሰዎችን ጨምር';

  @override
  String get peopleListsAddPeopleTooltip => 'ሰዎችን ጨምር';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'ሰዎችን ወደ ዝርዝር ያክሉ';

  @override
  String get peopleListsListNotFoundTitle => 'ዝርዝር አልተገኘም።';

  @override
  String get peopleListsListNotFoundSubtitle => 'ዝርዝር አልተገኘም። ተሰርዞ ሊሆን ይችላል።';

  @override
  String get peopleListsListDeletedSubtitle => 'ይህ ዝርዝር ተሰርዞ ሊሆን ይችላል።';

  @override
  String get peopleListsNoPeopleTitle => 'በዚህ ዝርዝር ውስጥ ምንም ሰዎች የሉም';

  @override
  String get peopleListsNoPeopleSubtitle => 'ለመጀመር አንዳንድ ሰዎችን ያክሉ';

  @override
  String get peopleListsNoVideosTitle => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get peopleListsNoVideosSubtitle => 'ከዝርዝር አባላት የመጡ ቪዲዮዎች እዚህ ይታያሉ';

  @override
  String get peopleListsNoVideosAvailable => 'ምንም ቪዲዮዎች የሉም';

  @override
  String get peopleListsFailedToLoadVideos => 'ቪዲዮዎችን መጫን አልተሳካም።';

  @override
  String get peopleListsVideoNotAvailable => 'ቪዲዮ አይገኝም';

  @override
  String get peopleListsBackToGridTooltip => 'ወደ ፍርግርግ ተመለስ';

  @override
  String get peopleListsErrorLoadingVideos => 'ቪዲዮዎችን መጫን ላይ ስህተት';

  @override
  String get peopleListsNoPeopleToAdd => 'ምንም የሚታከሉ ሰዎች የሉም።';

  @override
  String peopleListsAddToListName(String name) {
    return 'ወደ $name ጨምር';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'ሰዎችን ፈልግ';

  @override
  String get peopleListsAddPeopleError => 'ሰዎችን መጫን አልተቻለም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get peopleListsAddPeopleRetry => 'እንደገና ይሞክሩ';

  @override
  String get peopleListsAddButton => 'አክል';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'አክል $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'በ$count ዝርዝሮች ውስጥ',
      one: 'በ1 ዝርዝር ውስጥ',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'ይወገድ $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'ከዚህ ዝርዝር ውስጥ ይወገዳሉ.';

  @override
  String get peopleListsRemove => 'አስወግድ';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name ከዝርዝሩ ተወግዷል';
  }

  @override
  String get peopleListsUndo => 'ቀልብስ';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'መገለጫ ለ$name። ለማስወገድ በረጅሙ ተጫን።';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'ለ$name መገለጫ ይመልከቱ';
  }

  @override
  String get shareMenuAddedToBookmarks => 'ወደ ዕልባቶች ታክሏል!';

  @override
  String get shareMenuFailedToAddBookmark => 'ዕልባት ማከል አልተሳካም።';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return '\"$name\" የሚባል ዝርዝር ተፈጥሯል እና ቪዲዮ ታክሏል';
  }

  @override
  String get shareMenuManageContent => 'ይዘትን አስተዳድር';

  @override
  String get shareMenuEditVideo => 'ቪዲዮ አርትዕ';

  @override
  String get shareMenuEditVideoSubtitle => 'ርዕስ፣ መግለጫ እና ሃሽታጎችን ያዘምኑ';

  @override
  String get shareMenuDeleteVideo => 'ቪዲዮ ሰርዝ';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'ይህን ቪዲዮ ከDivine አስወግድ። በሌሎች Nostr ደንበኞች ላይ አሁንም ሊታይ ይችላል።';

  @override
  String get shareMenuDeleteWarning =>
      'ይህ የመሰረዝ ጥያቄን (NIP-09) ለሁሉም ማሰራጫዎች ይልካል። አንዳንድ ማሰራጫዎች አሁንም ይዘቱን ሊይዙት ይችላሉ።';

  @override
  String get shareMenuVideoInTheseLists => 'ቪዲዮው በእነዚህ ዝርዝሮች ውስጥ ነው፡-';

  @override
  String shareMenuVideoCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get shareMenuClose => 'ገጠመ';

  @override
  String get shareMenuDeleteConfirmation =>
      'ይሄ ይህን ቪዲዮ ከDivine እስከመጨረሻው ይሰርዘዋል። አሁንም ሌሎች ማስተላለፊያዎችን በሚጠቀሙ የሶስተኛ ወገን Nostr ደንበኞች ላይ ሊታይ ይችላል።';

  @override
  String get shareMenuCancel => 'ሰርዝ';

  @override
  String get shareMenuDelete => 'ሰርዝ';

  @override
  String get shareMenuDeletingContent => 'ይዘትን በመሰረዝ ላይ...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'ይዘትን መሰረዝ አልተሳካም፦ $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'ቪዲዮ ተሰርዟል።';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'መሰረዝ ገና ዝግጁ አይደለም። ከአፍታ በኋላ እንደገና ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedNotOwner => 'የእራስዎን ቪዲዮዎች ብቻ መሰረዝ ይችላሉ.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'እንደገና ይግቡ፣ ከዚያ ለመሰረዝ ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'የመሰረዝ ጥያቄውን መፈረም አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'ቅብብሎሹን መድረስ አልተቻለም። ግንኙነትዎን ይፈትሹ እና እንደገና ይሞክሩ።';

  @override
  String get shareMenuDeleteFailedGeneric => 'ይህን ቪዲዮ መሰረዝ አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get shareMenuFollowSetName => 'የቅንብር ስም ተከተል';

  @override
  String get shareMenuFollowSetNameHint => 'ለምሳሌ፣ የይዘት ፈጣሪዎች፣ ሙዚቀኞች፣ ወዘተ';

  @override
  String get shareMenuDescriptionOptional => 'መግለጫ (አማራጭ)';

  @override
  String get shareMenuCreate => 'ፍጠር';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return '\"$name\" የሚባል የመከተል ስብስብ ተፈጥሯል እና ፈጣሪ ታክሏል';
  }

  @override
  String get shareMenuDone => 'ተከናውኗል';

  @override
  String get shareMenuEditTitle => 'ርዕስ';

  @override
  String get shareMenuEditTitleHint => 'የቪዲዮ ርዕስ አስገባ';

  @override
  String get shareMenuEditDescription => 'መግለጫ';

  @override
  String get shareMenuEditDescriptionHint => 'የቪዲዮ መግለጫ ያስገቡ';

  @override
  String get shareMenuEditHashtags => 'ሃሽታጎች';

  @override
  String get shareMenuEditHashtagsHint => 'ነጠላ ሰረዝ፣ መለያየት፣ ሃሽታጎች';

  @override
  String get shareMenuEditMetadataNote =>
      'ማስታወሻ፡ ሜታዳታ ብቻ ነው ሊስተካከል የሚችለው። የቪዲዮ ይዘት ሊቀየር አይችልም።';

  @override
  String get shareMenuDeleting => 'በመሰረዝ ላይ...';

  @override
  String get shareMenuUpdate => 'አዘምን';

  @override
  String get shareMenuVideoUpdated => 'ቪዲዮው በተሳካ ሁኔታ ተዘምኗል';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'ቪዲዮውን ማዘመን አልተሳካም፦ $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'ቪዲዮውን መሰረዝ አልተሳካም፦ $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'ቪዲዮ ይሰረዝ?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'ይህ የስረዛ ጥያቄን ወደ ማስተላለፊያዎች ይልካል። ማስታወሻ፡ አንዳንድ ማሰራጫዎች አሁንም የተሸጎጡ ቅጂዎች ሊኖራቸው ይችላል።';

  @override
  String get shareMenuVideoDeletionRequested => 'ቪዲዮ ተሰርዟል።';

  @override
  String get shareMenuContentLabels => 'የይዘት መለያዎች';

  @override
  String get shareMenuAddContentLabels => 'የይዘት መለያዎችን ያክሉ';

  @override
  String get shareMenuClearAll => 'ሁሉንም አጽዳ';

  @override
  String get shareMenuCollaborators => 'ተባባሪዎች';

  @override
  String get shareMenuAddCollaborator => 'ተባባሪ ጋብዝ';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'እነሱን እንደ ተባባሪ ለመጋበዝ $nameን በጋራ መከተል አለቦት።';
  }

  @override
  String get shareMenuLoading => 'በመጫን ላይ...';

  @override
  String get shareMenuInspiredBy => 'ተመስጦ';

  @override
  String get shareMenuAddInspirationCredit => 'ተመስጦ ክሬዲት ያክሉ';

  @override
  String get shareMenuCreatorCannotBeReferenced => 'ይህ ፈጣሪ ሊጠቀስ አይችልም።';

  @override
  String get shareMenuUnknown => 'ያልታወቀ';

  @override
  String get shareMenuCreateBookmarkSet => 'የዕልባት ስብስብ ይፍጠሩ';

  @override
  String get shareMenuSetName => 'ስም አዘጋጅ';

  @override
  String get shareMenuSetNameHint => 'ለምሳሌ፡ ተወዳጆች፡ በኋላ ይመልከቱ፡ ወዘተ';

  @override
  String get shareMenuCreateNewSet => 'አዲስ ስብስብ ይፍጠሩ';

  @override
  String get shareMenuStartNewBookmarkCollection => 'አዲስ የዕልባት ስብስብ ጀምር';

  @override
  String get shareMenuNoBookmarkSets =>
      'እስካሁን ምንም ዕልባት አልተዘጋጀም። የመጀመሪያዎን ይፍጠሩ!';

  @override
  String get shareMenuError => 'ስህተት';

  @override
  String get shareMenuFailedToLoadBookmarkSets => 'የዕልባቶች ስብስቦችን መጫን አልተሳካም።';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\" ተፈጥሯል እና ቪዲዮ ታክሏል';
  }

  @override
  String get shareMenuUseThisSound => 'ይህንን ድምጽ ይጠቀሙ';

  @override
  String get shareMenuOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String get authSessionExpired => 'ክፍለ ጊዜዎ ጊዜው አልፎበታል። እባክዎ እንደገና ይግቡ።';

  @override
  String get authSignInFailed => 'መግባት አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get localeAppLanguage => 'የመተግበሪያ ቋንቋ';

  @override
  String get localeDeviceDefault => 'የመሣሪያ ነባሪ';

  @override
  String get localeSelectLanguage => 'ቋንቋ ይምረጡ';

  @override
  String get webAuthNotSupportedSecureMode =>
      'የድር ማረጋገጥ በአስተማማኝ ሁነታ አይደገፍም። እባክዎን ደህንነቱ የተጠበቀ ቁልፍ አስተዳደር ለማግኘት የሞባይል መተግበሪያን ይጠቀሙ።';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'የማረጋገጫ ውህደት አልተሳካም፦ $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'ያልተጠበቀ ስህተት፡ $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'እባክህ ማስቀመጫ አስገባ URI';

  @override
  String get webAuthConnectTitle => 'ከDivine ጋር ተገናኝ';

  @override
  String get webAuthChooseMethod => 'የመረጡትን Nostr የማረጋገጫ ዘዴ ይምረጡ';

  @override
  String get webAuthBrowserExtension => 'የአሳሽ ቅጥያ';

  @override
  String get webAuthRecommended => 'የሚመከር';

  @override
  String get webAuthNsecBunker => 'nsec ማሰሪያ';

  @override
  String get webAuthConnectRemoteSigner => 'ከርቀት ፈራሚ ጋር ይገናኙ';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'ከቅንጥብ ሰሌዳ ለጥፍ';

  @override
  String get webAuthConnectToBunker => 'ከBunker ጋር ተገናኝ';

  @override
  String get webAuthNewToNostr => 'ለNostr አዲስ?';

  @override
  String get webAuthNostrHelp =>
      'በጣም ቀላሉን ለማግኘት እንደ Alby ወይም nos2x ያለ አሳሽ ቅጥያ ጫን ወይም ደህንነቱ የተጠበቀ የርቀት ፊርማ nsec ተጠቀም።';

  @override
  String get soundsTitle => 'ይሰማል።';

  @override
  String get soundsSearchHint => 'ድምፆችን ፈልግ...';

  @override
  String get soundsPreviewUnavailable => 'ድምጽን አስቀድሞ ማየት አልተቻለም - ምንም ኦዲዮ የለም።';

  @override
  String soundsPreviewFailed(String error) {
    return 'ቅድመ እይታን ማጫወት አልተሳካም፦ $error';
  }

  @override
  String get soundsFeaturedSounds => 'ተለይተው የቀረቡ ድምፆች';

  @override
  String get soundsTrendingSounds => 'በመታየት ላይ ያሉ ድምፆች';

  @override
  String get soundsAllSounds => 'ሁሉም ድምጾች';

  @override
  String get soundsSearchResults => 'የፍለጋ ውጤቶች';

  @override
  String get soundsNoSoundsAvailable => 'ምንም ድምፆች የሉም';

  @override
  String get soundsNoSoundsDescription => 'ፈጣሪዎች ኦዲዮን ሲያጋሩ ድምጾች እዚህ ይታያሉ';

  @override
  String get soundsNoSoundsFound => 'ምንም ድምፆች አልተገኙም።';

  @override
  String get soundsNoSoundsFoundDescription => 'የተለየ የፍለጋ ቃል ይሞክሩ';

  @override
  String get soundsFailedToLoad => 'ድምጾችን መጫን አልተሳካም።';

  @override
  String get soundsRetry => 'እንደገና ይሞክሩ';

  @override
  String get soundsScreenLabel => 'ስክሪን ይሰማል።';

  @override
  String get profileTitle => 'መገለጫ';

  @override
  String get profileRefresh => 'አድስ';

  @override
  String get profileRefreshLabel => 'መገለጫ አድስ';

  @override
  String get profileMoreOptions => 'ተጨማሪ አማራጮች';

  @override
  String profileBlockedUser(String name) {
    return 'ታግዷል $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'ታግዷል $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'ያልተከተለ $name';
  }

  @override
  String profileError(String error) {
    return 'ስህተት፡ $error';
  }

  @override
  String get notificationsTabAll => 'ሁሉም';

  @override
  String get notificationsTabLikes => 'መውደዶች';

  @override
  String get notificationsTabComments => 'አስተያየቶች';

  @override
  String get notificationsTabFollows => 'ይከተላል';

  @override
  String get notificationsTabReposts => 'ድጋሚ ልጥፎች';

  @override
  String get notificationsFailedToLoad => 'ማሳወቂያዎችን መጫን አልተሳካም።';

  @override
  String get notificationsRetry => 'እንደገና ይሞክሩ';

  @override
  String get notificationsCheckingNew => 'አዲስ ማሳወቂያዎችን በመፈተሽ ላይ';

  @override
  String get notificationsNoneYet => 'እስካሁን ምንም ማሳወቂያዎች የሉም';

  @override
  String notificationsNoneForType(String type) {
    return 'ምንም $type ማሳወቂያዎች የሉም';
  }

  @override
  String get notificationsEmptyDescription => 'ሰዎች ከይዘትህ ጋር ሲገናኙ እዚህ ታየዋለህ';

  @override
  String get notificationsUnreadPrefix => 'ያልተነበበ ማስታወቂያ';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'የ$displayName መገለጫ ይመልከቱ';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'መገለጫዎችን ይመልከቱ';

  @override
  String notificationsLoadingType(String type) {
    return '$type ማሳወቂያዎችን በመጫን ላይ...';
  }

  @override
  String get notificationsInviteSingular => 'ከጓደኛዎ ጋር ለመጋራት 1 ግብዣ አለዎት!';

  @override
  String notificationsInvitePlural(int count) {
    return 'ከጓደኞችዎ ጋር ለመጋራት $count ግብዣዎች አሉዎት!';
  }

  @override
  String get notificationsVideoNotFound => 'ቪዲዮ አልተገኘም።';

  @override
  String get notificationsVideoUnavailable => 'ቪዲዮ አይገኝም';

  @override
  String get notificationsFromNotification => 'ከማስታወቂያ';

  @override
  String get feedFailedToLoadVideos => 'ቪዲዮዎችን መጫን አልተሳካም።';

  @override
  String get feedRetry => 'እንደገና ይሞክሩ';

  @override
  String get feedNoFollowedUsers =>
      'ምንም የተከተሉት ተጠቃሚዎች የሉም።\nቪዲዮዎቻቸውን እዚህ ለማየት አንድ ሰው ይከተሉ።';

  @override
  String get feedForYouEmpty =>
      'የእርስዎ ለአንተ ምግብ ባዶ ነው።\nቪዲዮዎችን ያስሱ እና ለመቅረጽ ፈጣሪዎችን ይከተሉ።';

  @override
  String get feedFollowingEmpty =>
      'እስካሁን ከምትከተላቸው ሰዎች ምንም ቪዲዮዎች የሉም።\nየሚወዷቸውን ፈጣሪዎች ያግኙ እና ይከተሉዋቸው።';

  @override
  String get feedLatestEmpty => 'እስካሁን ምንም አዲስ ቪዲዮዎች የሉም።\nበቅርቡ ተመልሰው ይመልከቱ።';

  @override
  String get feedExploreVideos => 'ቪዲዮዎችን ያስሱ';

  @override
  String get feedExternalVideoSlow => 'ውጫዊ ቪዲዮ ቀስ በቀስ በመጫን ላይ';

  @override
  String get feedSkip => 'ዝለል';

  @override
  String get uploadWaitingToUpload => 'ለመስቀል በመጠበቅ ላይ';

  @override
  String get uploadUploadingVideo => 'ቪዲዮ በመስቀል ላይ';

  @override
  String get uploadProcessingVideo => 'ቪዲዮን በመስራት ላይ';

  @override
  String get uploadProcessingComplete => 'ማካሄድ ተጠናቋል';

  @override
  String get uploadPublishedSuccessfully => 'በተሳካ ሁኔታ ታትሟል';

  @override
  String get uploadFailed => 'ሰቀላው አልተሳካም።';

  @override
  String get uploadRetrying => 'ሰቀላን እንደገና በመሞከር ላይ';

  @override
  String get uploadPaused => 'ሰቀላ ባለበት ቆሟል';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% ተጠናቋል';
  }

  @override
  String get uploadQueuedMessage => 'ቪዲዮዎ ለመስቀል ተሰልፏል';

  @override
  String get uploadUploadingMessage => 'ወደ አገልጋይ በመስቀል ላይ...';

  @override
  String get uploadProcessingMessage =>
      'ቪዲዮን በመስራት ላይ - ይህ ጥቂት ደቂቃዎችን ሊወስድ ይችላል።';

  @override
  String get uploadReadyToPublishMessage =>
      'ቪዲዮው በተሳካ ሁኔታ ተከናውኗል እና ለመታተም ዝግጁ ነው።';

  @override
  String get uploadPublishedMessage => 'ቪዲዮ ወደ መገለጫዎ ታትሟል';

  @override
  String get uploadFailedMessage => 'ሰቀላው አልተሳካም - እባክዎ እንደገና ይሞክሩ';

  @override
  String get uploadRetryingMessage => 'ሰቀላን እንደገና በመሞከር ላይ...';

  @override
  String get uploadPausedMessage => 'ሰቀላው ባለበት ቆሟል';

  @override
  String get uploadRetryButton => 'እንደገና ይሞክሩ';

  @override
  String uploadRetryFailed(String error) {
    return 'ሰቀላን እንደገና መሞከር አልተሳካም፦ $error';
  }

  @override
  String get userSearchPrompt => 'ተጠቃሚዎችን ይፈልጉ';

  @override
  String get userSearchNoResults => 'ምንም ተጠቃሚዎች አልተገኙም።';

  @override
  String get userSearchFailed => 'ፍለጋ አልተሳካም።';

  @override
  String get userPickerSearchByName => 'በስም ፈልግ';

  @override
  String get userPickerFilterByNameHint => 'በስም አጣራ...';

  @override
  String get userPickerSearchByNameHint => 'በስም ፈልግ...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name አስቀድሞ ታክሏል።';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return '$name ምረጥ';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'የእርስዎ ሠራተኞች እዚያ አሉ።';

  @override
  String get userPickerEmptyFollowListBody =>
      'የሚወዷቸውን ሰዎች ይከተሉ። ተመልሰው ሲከተሉ፣ መተባበር ይችላሉ።';

  @override
  String get userPickerGoBack => 'ተመለስ';

  @override
  String get userPickerTypeNameToSearch => 'ለመፈለግ ስም ይተይቡ';

  @override
  String get userPickerUnavailable => 'የተጠቃሚ ፍለጋ አይገኝም። እባክዎ ቆይተው እንደገና ይሞክሩ።';

  @override
  String get userPickerSearchFailedTryAgain => 'ፍለጋ አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get forgotPasswordTitle => 'የይለፍ ቃል ዳግም አስጀምር';

  @override
  String get forgotPasswordDescription =>
      'የኢሜል አድራሻዎን ያስገቡ እና የይለፍ ቃልዎን እንደገና የሚያስጀምሩበት አገናኝ እንልክልዎታለን።';

  @override
  String get forgotPasswordEmailLabel => 'ኢሜል አድራሻ';

  @override
  String get forgotPasswordCancel => 'ሰርዝ';

  @override
  String get forgotPasswordSendLink => 'የኢሜል ዳግም ማስጀመሪያ አገናኝ';

  @override
  String get ageVerificationContentWarning => 'የይዘት ማስጠንቀቂያ';

  @override
  String get ageVerificationTitle => 'የዕድሜ ማረጋገጫ';

  @override
  String get ageVerificationAdultDescription =>
      'ይህ ይዘት የጎልማሳ ቁሳቁስ ሊይዝ እንደሚችል ተጠቁሟል። እሱን ለማየት 18 ወይም ከዚያ በላይ መሆን አለቦት።';

  @override
  String get ageVerificationCreationDescription =>
      'ካሜራውን ለመጠቀም እና ይዘት ለመፍጠር ዕድሜዎ ቢያንስ 16 ዓመት መሆን አለበት።';

  @override
  String get ageVerificationAdultQuestion => 'ዕድሜዎ 18 ዓመት ወይም ከዚያ በላይ ነው?';

  @override
  String get ageVerificationCreationQuestion => 'ዕድሜዎ 16 ወይም ከዚያ በላይ ነው?';

  @override
  String get ageVerificationNo => 'አይ';

  @override
  String get ageVerificationYes => 'አዎ';

  @override
  String get shareLinkCopied => 'ማገናኛ ወደ ቅንጥብ ሰሌዳ ተቀድቷል።';

  @override
  String get shareFailedToCopy => 'አገናኙን መቅዳት አልተሳካም።';

  @override
  String get shareVideoSubject => 'ይህንን ቪዲዮ በDivine ላይ ይመልከቱ';

  @override
  String get shareFailedToShare => 'ማጋራት አልተሳካም።';

  @override
  String get shareVideoTitle => 'ቪዲዮ አጋራ';

  @override
  String get shareToApps => 'ለመተግበሪያዎች አጋራ';

  @override
  String get shareToAppsSubtitle => 'በመልዕክት፣ በማህበራዊ መተግበሪያዎች አጋራ';

  @override
  String get shareCopyWebLink => 'የድር ሊንክ ቅዳ';

  @override
  String get shareCopyWebLinkSubtitle => 'ሊጋራ የሚችል የድር አገናኝ ይቅዱ';

  @override
  String get shareCopyNostrLink => 'ቅዳ Nostr አገናኝ';

  @override
  String get shareCopyNostrLinkSubtitle => 'ለደንበኞች nevent አገናኝን ይቅዱ';

  @override
  String get navHome => 'ቤት';

  @override
  String get navExplore => 'ያስሱ';

  @override
  String get navInbox => 'የገቢ መልእክት ሳጥን';

  @override
  String get navProfile => 'መገለጫ';

  @override
  String get navSearch => 'ፈልግ';

  @override
  String get navSearchTooltip => 'ፈልግ';

  @override
  String get navMyProfile => 'የእኔ መገለጫ';

  @override
  String get navNotifications => 'ማሳወቂያዎች';

  @override
  String get navOpenCamera => 'ካሜራ ክፈት';

  @override
  String get navUnknown => 'ያልታወቀ';

  @override
  String get navExploreClassics => 'ክላሲኮች';

  @override
  String get navExploreNewVideos => 'አዳዲስ ቪዲዮዎች';

  @override
  String get navExploreTrending => 'በመታየት ላይ ያለ';

  @override
  String get navExploreForYou => 'ለእርስዎ';

  @override
  String get navExploreLists => 'ዝርዝሮች';

  @override
  String get routeErrorTitle => 'ስህተት';

  @override
  String get routeInvalidHashtag => 'ልክ ያልሆነ ሃሽታግ';

  @override
  String get routeInvalidConversationId => 'ልክ ያልሆነ የውይይት መታወቂያ';

  @override
  String get routeInvalidRequestId => 'ልክ ያልሆነ የጥያቄ መታወቂያ';

  @override
  String get routeInvalidListId => 'ልክ ያልሆነ ዝርዝር መታወቂያ';

  @override
  String get routeInvalidUserId => 'የተሳሳተ የተጠቃሚ መታወቂያ';

  @override
  String get routeInvalidVideoId => 'ልክ ያልሆነ የቪዲዮ መታወቂያ';

  @override
  String get routeInvalidSoundId => 'ልክ ያልሆነ የድምጽ መታወቂያ';

  @override
  String get routeInvalidCategory => 'ልክ ያልሆነ ምድብ';

  @override
  String get routeNoVideosToDisplay => 'ምንም የሚታዩ ቪዲዮዎች የሉም';

  @override
  String get routeInvalidProfileId => 'ልክ ያልሆነ የመገለጫ መታወቂያ';

  @override
  String get routeDefaultListName => 'ዝርዝር';

  @override
  String get supportTitle => 'የድጋፍ ማዕከል';

  @override
  String get supportContactSupport => 'ድጋፍን ያነጋግሩ';

  @override
  String get supportContactSupportSubtitle => 'ውይይት ይጀምሩ ወይም ያለፉ መልዕክቶችን ይመልከቱ';

  @override
  String get supportReportBug => 'ሳንካ ሪፖርት አድርግ';

  @override
  String get supportReportBugSubtitle => 'ከመተግበሪያው ጋር ቴክኒካዊ ጉዳዮች';

  @override
  String get supportRequestFeature => 'ባህሪ ይጠይቁ';

  @override
  String get supportRequestFeatureSubtitle => 'ማሻሻያ ወይም አዲስ ባህሪን ይጠቁሙ';

  @override
  String get supportSaveLogs => 'ምዝግብ ማስታወሻዎችን ያስቀምጡ';

  @override
  String get supportSaveLogsSubtitle => 'በእጅ ለመላክ የምዝግብ ማስታወሻዎችን ወደ ፋይል ይላኩ።';

  @override
  String get supportFaq => 'የሚጠየቁ ጥያቄዎች';

  @override
  String get supportFaqSubtitle => 'የተለመዱ ጥያቄዎች እና መልሶች';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'ስለ ማረጋገጫ እና ትክክለኛነት ይወቁ';

  @override
  String get supportLoginRequired => 'ድጋፍን ለማግኘት ይግቡ';

  @override
  String get supportExportingLogs => 'ምዝግብ ማስታወሻዎችን በመላክ ላይ...';

  @override
  String get supportExportLogsFailed => 'ምዝግብ ማስታወሻዎችን ወደ ውጭ መላክ አልተሳካም።';

  @override
  String get supportChatNotAvailable => 'የድጋፍ ውይይት አይገኝም';

  @override
  String get supportCouldNotOpenMessages => 'የድጋፍ መልዕክቶችን መክፈት አልተቻለም';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName መክፈት አልተቻለም';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return '$pageName: $errorን መክፈት ላይ ስህተት';
  }

  @override
  String get reportTitle => 'ይዘትን ሪፖርት አድርግ';

  @override
  String get reportWhyReporting => 'ይህን ይዘት ለምን ሪፖርት ያደርጋሉ?';

  @override
  String get reportPolicyNotice =>
      'Divine ይዘቱን በማስወገድ እና አጸያፊ ይዘቱን ያቀረበውን ተጠቃሚ በማስወጣት የይዘት ሪፖርቶችን በ24 ሰዓታት ውስጥ ይሰራል።';

  @override
  String get reportAdditionalDetails => 'ተጨማሪ ዝርዝሮች (አማራጭ)';

  @override
  String get reportBlockUser => 'ይህን ተጠቃሚ አግድ';

  @override
  String get reportCancel => 'ሰርዝ';

  @override
  String get reportSubmit => 'ሪፖርት አድርግ';

  @override
  String get reportSelectReason => 'እባክዎ ይህን ይዘት ሪፖርት ለማድረግ ምክንያት ይምረጡ';

  @override
  String get reportOtherRequiresDetails => '«ሌላ» ሲመርጡ እባክዎ ችግሩን ይግለጹ';

  @override
  String get reportDetailsRequired => 'እባክዎ ችግሩን ይግለጹ';

  @override
  String get reportReasonSpam => 'አይፈለጌ መልእክት ወይም የማይፈለግ ይዘት';

  @override
  String get reportReasonHarassment => 'ማስፈራራት፣ ማስፈራራት ወይም ማስፈራራት';

  @override
  String get reportReasonViolence => 'የጥቃት ወይም ጽንፈኛ ይዘት';

  @override
  String get reportReasonSexualContent => 'ወሲባዊ ወይም የአዋቂ ይዘት';

  @override
  String get reportReasonCopyright => 'የቅጂ መብት ጥሰት';

  @override
  String get reportReasonFalseInfo => 'የውሸት መረጃ';

  @override
  String get reportReasonCsam => 'የልጅ ደህንነት ጥሰት';

  @override
  String get reportReasonAiGenerated => 'በAI የተፈጠረ ይዘት';

  @override
  String get reportReasonOther => 'ሌላ የፖሊሲ ጥሰት';

  @override
  String reportFailed(Object error) {
    return 'ይዘትን ሪፖርት ማድረግ አልተሳካም፦ $error';
  }

  @override
  String get reportReceivedTitle => 'ሪፖርት ደርሷል';

  @override
  String get reportReceivedThankYou => 'Divine ደህንነትን ለመጠበቅ ስለረዱዎት እናመሰግናለን።';

  @override
  String get reportReceivedReviewNotice =>
      'ቡድናችን የእርስዎን ሪፖርት ተመልክቶ ተገቢውን እርምጃ ይወስዳል። ዝማኔዎችን በቀጥታ መልእክት ሊቀበሉ ይችላሉ።';

  @override
  String get reportLearnMore => 'የበለጠ ተማር';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'ገጠመ';

  @override
  String get listAddToList => 'ወደ ዝርዝር ያክሉ';

  @override
  String listVideoCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ሰዎች',
      one: '1 ሰው',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'በ';

  @override
  String get listNewList => 'አዲስ ዝርዝር';

  @override
  String get listDone => 'ተከናውኗል';

  @override
  String get listErrorLoading => 'ዝርዝሮችን መጫን ላይ ስህተት';

  @override
  String listRemovedFrom(String name) {
    return 'ከ$name ተወግዷል';
  }

  @override
  String listAddedTo(String name) {
    return 'ወደ $name ታክሏል።';
  }

  @override
  String get listCreateNewList => 'አዲስ ዝርዝር ይፍጠሩ';

  @override
  String get listNewPeopleList => 'አዲስ ሰዎች ዝርዝር';

  @override
  String get listCollaboratorsNone => 'ምንም';

  @override
  String get listAddCollaboratorTitle => 'ተባባሪ ጨምር';

  @override
  String get listCollaboratorSearchHint => 'diVine ፈልግ...';

  @override
  String get listNameLabel => 'የዝርዝር ስም';

  @override
  String get listDescriptionLabel => 'መግለጫ (አማራጭ)';

  @override
  String get listPublicList => 'የህዝብ ዝርዝር';

  @override
  String get listPublicListSubtitle => 'ሌሎች ሊከተሉት እና ይህንን ዝርዝር ማየት ይችላሉ።';

  @override
  String get listCancel => 'ሰርዝ';

  @override
  String get listCreate => 'ፍጠር';

  @override
  String get listCreateFailed => 'ዝርዝር መፍጠር አልተሳካም።';

  @override
  String get keyManagementTitle => 'Nostr ቁልፎች';

  @override
  String get keyManagementWhatAreKeys => 'Nostr ቁልፎች ምንድን ናቸው?';

  @override
  String get keyManagementExplanation =>
      'የNostr ማንነትህ የክሪፕቶግራፊ ቁልፍ ጥንድ ነው፡\n\n• የህዝብ ቁልፍህ (npub) እንደ ተጠቃሚ ስምህ ነው - በነጻ አጋራው\n• የግል ቁልፍህ (nsec) እንደ ይለፍ ቃልህ ነው - በሚስጥር ያዘው!\n\nnsecህ በማንኛውም Nostr መተግበሪያ ላይ መለያህን እንድትጠቀም ያስችልሃል።';

  @override
  String get keyManagementImportTitle => 'ነባር ቁልፍ አስመጣ';

  @override
  String get keyManagementImportSubtitle =>
      'Nostr መለያ አለህ? እዚህ ለመጠቀም የግል ቁልፍህን (nsec) ለጥፍ።';

  @override
  String get keyManagementImportButton => 'የማስመጣት ቁልፍ';

  @override
  String get keyManagementImportWarning => 'ይህ የአሁኑን ቁልፍ ይተካዋል!';

  @override
  String get keyManagementBackupTitle => 'የእርስዎን ቁልፍ ምትኬ ያስቀምጡ';

  @override
  String get keyManagementBackupSubtitle =>
      'መለያዎን በሌሎች Nostr መተግበሪያዎች ለመጠቀም የግል ቁልፍዎን (nsec) ያስቀምጡ።';

  @override
  String get keyManagementCopyNsec => 'የእኔን የግል ቁልፍ ቅዳ (nsec)';

  @override
  String get keyManagementNeverShare => 'የእርስዎን nsec ለማንም አያካፍሉ!';

  @override
  String get keyManagementPasteKey => 'እባክህ የግል ቁልፍህን ለጥፍ';

  @override
  String get keyManagementInvalidFormat =>
      'ልክ ያልሆነ የቁልፍ ቅርጸት። በ\"nsec1\" መጀመር አለበት';

  @override
  String get keyManagementConfirmImportTitle => 'ይህ ቁልፍ ይምጣ?';

  @override
  String get keyManagementConfirmImportBody =>
      'ይህ አሁን ያለዎትን ማንነት ከውጪ በመጣው ይተካዋል።\n\nመጀመሪያ ምትኬ ካላስቀመጥከው በስተቀር የአሁኑ ቁልፍህ ይጠፋል።';

  @override
  String get keyManagementImportConfirm => 'አስመጣ';

  @override
  String get keyManagementImportSuccess => 'ቁልፍ በተሳካ ሁኔታ ገብቷል!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'ቁልፍ ማስመጣት አልተሳካም፦ $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'የግል ቁልፍ ወደ ቅንጥብ ሰሌዳ ተቀድቷል!\n\nደህንነቱ በተጠበቀ ቦታ ያስቀምጡት።';

  @override
  String keyManagementExportFailed(Object error) {
    return 'ቁልፉን ወደ ውጭ መላክ አልተሳካም፦ $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Your public key (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copy public key';

  @override
  String get keyManagementPublicKeyCopied => 'Public key copied';

  @override
  String get profileEditPublicKeyLink => 'View your public key';

  @override
  String get saveOriginalSavedToCameraRoll => 'ወደ ካሜራ ጥቅል ተቀምጧል';

  @override
  String get saveOriginalShare => 'አጋራ';

  @override
  String get saveOriginalDone => 'ተከናውኗል';

  @override
  String get saveOriginalPhotosAccessNeeded => 'የፎቶዎች መዳረሻ ያስፈልጋል';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'ቪዲዮዎችን ለማስቀመጥ በቅንብሮች ውስጥ የፎቶዎች መዳረሻ ፍቀድ።';

  @override
  String get saveOriginalOpenSettings => 'ቅንብሮችን ይክፈቱ';

  @override
  String get saveOriginalNotNow => 'አሁን አይደለም';

  @override
  String get cameraPermissionNotNow => 'አሁን አይደለም';

  @override
  String get saveOriginalDownloadFailed => 'ማውረድ አልተሳካም።';

  @override
  String get saveOriginalDismiss => 'አሰናብት';

  @override
  String get saveOriginalDownloadingVideo => 'ቪዲዮን በማውረድ ላይ';

  @override
  String get saveOriginalSavingToCameraRoll => 'ወደ ካሜራ ጥቅል በማስቀመጥ ላይ';

  @override
  String get saveOriginalFetchingVideo => 'ቪዲዮውን ከአውታረ መረብ በማምጣት ላይ...';

  @override
  String get saveOriginalSavingVideo => 'የመጀመሪያውን ቪዲዮ ወደ ካሜራ ጥቅልዎ በማስቀመጥ ላይ...';

  @override
  String get soundTitle => 'ድምፅ';

  @override
  String get soundOriginalSound => 'ኦሪጅናል ድምጽ';

  @override
  String get soundVideosUsingThisSound => 'ይህን ድምፅ በመጠቀም ቪዲዮዎች';

  @override
  String get soundSourceVideo => 'ምንጭ ቪዲዮ';

  @override
  String get soundNoVideosYet => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get soundBeFirstToUse => 'ይህን ድምጽ ለመጠቀም የመጀመሪያው ይሁኑ!';

  @override
  String get soundFailedToLoadVideos => 'ቪዲዮዎችን መጫን አልተሳካም።';

  @override
  String get soundRetry => 'እንደገና ይሞክሩ';

  @override
  String get soundVideosUnavailable => 'ቪዲዮዎች አይገኙም።';

  @override
  String get soundCouldNotLoadDetails => 'የቪዲዮ ዝርዝሮችን መጫን አልተቻለም';

  @override
  String get soundPreview => 'ቅድመ እይታ';

  @override
  String get soundStop => 'ተወ';

  @override
  String get soundUseSound => 'ድምጽን ተጠቀም';

  @override
  String get soundUntitled => 'ርዕስ የሌለው ድምፅ';

  @override
  String get soundStopPreview => 'ቅድመ እይታን አቁም';

  @override
  String soundPreviewSemanticLabel(String title) {
    return '$titleን ቀድመው ያጫውቱ';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'የ$title ዝርዝሮችን ይመልከቱ';
  }

  @override
  String get soundNoVideoCount => 'እስካሁን ምንም ቪዲዮዎች የሉም';

  @override
  String get soundOneVideo => '1 ቪዲዮ';

  @override
  String soundVideoCount(int count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String get soundUnableToPreview => 'ድምጽን አስቀድሞ ማየት አልተቻለም - ምንም ኦዲዮ የለም።';

  @override
  String soundPreviewFailed(Object error) {
    return 'ቅድመ እይታን ማጫወት አልተሳካም፦ $error';
  }

  @override
  String get soundViewSource => 'ምንጭ ይመልከቱ';

  @override
  String get soundCloseTooltip => 'ገጠመ';

  @override
  String get exploreNotExploreRoute => 'የአሰሳ መንገድ አይደለም።';

  @override
  String get legalTitle => 'ህጋዊ';

  @override
  String get legalTermsOfService => 'የአገልግሎት ውል';

  @override
  String get legalTermsOfServiceSubtitle => 'የአጠቃቀም ደንቦች እና ሁኔታዎች';

  @override
  String get legalPrivacyPolicy => 'የግላዊነት ፖሊሲ';

  @override
  String get legalPrivacyPolicySubtitle => 'የእርስዎን ውሂብ እንዴት እንደምንይዝ';

  @override
  String get legalSafetyStandards => 'የደህንነት ደረጃዎች';

  @override
  String get legalSafetyStandardsSubtitle => 'የማህበረሰብ መመሪያዎች እና ደህንነት';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'የቅጂ መብት እና የማውረድ ፖሊሲ';

  @override
  String get legalOpenSourceLicenses => 'ክፍት ምንጭ ፍቃዶች';

  @override
  String get legalOpenSourceLicensesSubtitle => 'የሶስተኛ ወገን ጥቅል ባህሪያት';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName መክፈት አልተቻለም';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return '$pageName: $errorን መክፈት ላይ ስህተት';
  }

  @override
  String get categoryAction => 'ድርጊት';

  @override
  String get categoryAdventure => 'ጀብዱ';

  @override
  String get categoryAnimals => 'እንስሳት';

  @override
  String get categoryAnimation => 'አኒሜሽን';

  @override
  String get categoryArchitecture => 'አርክቴክቸር';

  @override
  String get categoryArt => 'ስነ ጥበብ';

  @override
  String get categoryAutomotive => 'አውቶሞቲቭ';

  @override
  String get categoryAwardShow => 'የሽልማት ትርዒት';

  @override
  String get categoryAwards => 'ሽልማቶች';

  @override
  String get categoryBaseball => 'ቤዝቦል';

  @override
  String get categoryBasketball => 'የቅርጫት ኳስ';

  @override
  String get categoryBeauty => 'ውበት';

  @override
  String get categoryBeverage => 'መጠጥ';

  @override
  String get categoryCars => 'መኪኖች';

  @override
  String get categoryCelebration => 'አከባበር';

  @override
  String get categoryCelebrities => 'ታዋቂ ሰዎች';

  @override
  String get categoryCelebrity => 'ታዋቂ ሰው';

  @override
  String get categoryCityscape => 'የከተማ ገጽታ';

  @override
  String get categoryComedy => 'አስቂኝ';

  @override
  String get categoryConcert => 'ኮንሰርት';

  @override
  String get categoryCooking => 'ምግብ ማብሰል';

  @override
  String get categoryCostume => 'አልባሳት';

  @override
  String get categoryCrafts => 'የእጅ ሥራዎች';

  @override
  String get categoryCrime => 'ወንጀል';

  @override
  String get categoryCulture => 'ባህል';

  @override
  String get categoryDance => 'ዳንስ';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'ድራማ';

  @override
  String get categoryEducation => 'ትምህርት';

  @override
  String get categoryEmotional => 'ስሜታዊ';

  @override
  String get categoryEmotions => 'ስሜቶች';

  @override
  String get categoryEntertainment => 'መዝናኛ';

  @override
  String get categoryEvent => 'ክስተት';

  @override
  String get categoryFamily => 'ቤተሰብ';

  @override
  String get categoryFans => 'ደጋፊዎች';

  @override
  String get categoryFantasy => 'ምናባዊ';

  @override
  String get categoryFashion => 'ቅጥ';

  @override
  String get categoryFestival => 'በዓል';

  @override
  String get categoryFilm => 'ፊልም';

  @override
  String get categoryFitness => 'የአካል ብቃት';

  @override
  String get categoryFood => 'ምግብ';

  @override
  String get categoryFootball => 'እግር ኳስ';

  @override
  String get categoryFurniture => 'የቤት ዕቃዎች';

  @override
  String get categoryGaming => 'ጨዋታ';

  @override
  String get categoryGolf => 'ጎልፍ';

  @override
  String get categoryGrooming => 'ማበጠር';

  @override
  String get categoryGuitar => 'ጊታር';

  @override
  String get categoryHalloween => 'ሃሎዊን';

  @override
  String get categoryHealth => 'ጤና';

  @override
  String get categoryHockey => 'ሆኪ';

  @override
  String get categoryHoliday => 'በዓል';

  @override
  String get categoryHome => 'ቤት';

  @override
  String get categoryHomeImprovement => 'የቤት መሻሻል';

  @override
  String get categoryHorror => 'አስፈሪ';

  @override
  String get categoryHospital => 'ሆስፒታል';

  @override
  String get categoryHumor => 'ቀልድ';

  @override
  String get categoryInteriorDesign => 'የውስጥ ንድፍ';

  @override
  String get categoryInterview => 'ቃለ መጠይቅ';

  @override
  String get categoryKids => 'ልጆች';

  @override
  String get categoryLifestyle => 'የአኗኗር ዘይቤ';

  @override
  String get categoryMagic => 'አስማት';

  @override
  String get categoryMakeup => 'ሜካፕ';

  @override
  String get categoryMedical => 'ሕክምና';

  @override
  String get categoryMusic => 'ሙዚቃ';

  @override
  String get categoryMystery => 'ምስጢር';

  @override
  String get categoryNature => 'ተፈጥሮ';

  @override
  String get categoryNews => 'ዜና';

  @override
  String get categoryOutdoor => 'ከቤት ውጭ';

  @override
  String get categoryParty => 'ፓርቲ';

  @override
  String get categoryPeople => 'ሰዎች';

  @override
  String get categoryPerformance => 'አፈጻጸም';

  @override
  String get categoryPets => 'የቤት እንስሳት';

  @override
  String get categoryPolitics => 'ፖለቲካ';

  @override
  String get categoryPrank => 'ፕራንክ';

  @override
  String get categoryPranks => 'ፕራንክ';

  @override
  String get categoryRealityShow => 'የእውነታ ትርኢት';

  @override
  String get categoryRelationship => 'ግንኙነት';

  @override
  String get categoryRelationships => 'ግንኙነቶች';

  @override
  String get categoryRomance => 'የፍቅር ጓደኝነት';

  @override
  String get categorySchool => 'ትምህርት ቤት';

  @override
  String get categoryScienceFiction => 'የሳይንስ ልብወለድ';

  @override
  String get categorySelfie => 'የራስ ፎቶ';

  @override
  String get categoryShopping => 'ግዢ';

  @override
  String get categorySkateboarding => 'የስኬትቦርዲንግ';

  @override
  String get categorySkincare => 'የቆዳ እንክብካቤ';

  @override
  String get categorySoccer => 'እግር ኳስ';

  @override
  String get categorySocialGathering => 'ማህበራዊ ስብሰባ';

  @override
  String get categorySocialMedia => 'ማህበራዊ ሚዲያ';

  @override
  String get categorySports => 'ስፖርት';

  @override
  String get categoryTalkShow => 'የውይይት ትዕይንት';

  @override
  String get categoryTech => 'ቴክ';

  @override
  String get categoryTechnology => 'ቴክኖሎጂ';

  @override
  String get categoryTelevision => 'ቴሌቪዥን';

  @override
  String get categoryToys => 'መጫወቻዎች';

  @override
  String get categoryTransportation => 'መጓጓዣ';

  @override
  String get categoryTravel => 'ጉዞ';

  @override
  String get categoryUrban => 'ከተማ';

  @override
  String get categoryViolence => 'ብጥብጥ';

  @override
  String get categoryVlog => 'ቪሎግ';

  @override
  String get categoryVlogging => 'ቭሎግ ማድረግ';

  @override
  String get categoryWrestling => 'ትግል';

  @override
  String get profileSetupUploadSuccess => 'የመገለጫ ስዕል በተሳካ ሁኔታ ተሰቅሏል!';

  @override
  String inboxReportedUser(String displayName) {
    return 'ሪፖርት ተደርጓል $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'ታግዷል $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'ታግዷል $displayName';
  }

  @override
  String get inboxRemovedConversation => 'ውይይት ተወግዷል';

  @override
  String get inboxEmptyTitle => 'እስካሁን ምንም መልዕክቶች የሉም';

  @override
  String get inboxEmptySubtitle => 'ያ + ቁልፍ አይነክሰውም።';

  @override
  String get inboxActionMute => 'ውይይት ድምጸ-ከል አድርግ';

  @override
  String inboxActionReport(String displayName) {
    return 'ሪፖርት $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'አግድ $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'እገዳን አንሳ $displayName';
  }

  @override
  String get inboxActionRemove => 'ውይይት አስወግድ';

  @override
  String get inboxRemoveConfirmTitle => 'ውይይት ይወገድ?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'ይህ ከ$displayName ጋር ያለህን ውይይት ይሰርዛል። ይህ እርምጃ ሊመለስ አይችልም።';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'አስወግድ';

  @override
  String get inboxConversationMuted => 'ውይይት ድምጸ-ከል ተደርጓል';

  @override
  String get inboxConversationUnmuted => 'ውይይቱ ድምጸ-ከል ተነስቷል።';

  @override
  String get inboxCollabInviteCardTitle => 'የተባባሪ ግብዣ';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role በዚህ ልጥፍ ላይ';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'ተቀበል';

  @override
  String get inboxCollabInviteIgnoreButton => 'ችላ በል';

  @override
  String get inboxCollabInviteAcceptedStatus => 'ተቀባይነት አግኝቷል';

  @override
  String get inboxCollabInviteIgnoredStatus => 'ችላ ተብሏል';

  @override
  String get inboxCollabInviteAcceptError => 'መቀበል አልተቻለም። እንደገና ይሞክሩ።';

  @override
  String get inboxCollabInviteSentStatus => 'ግብዣ ተልኳል።';

  @override
  String get inboxConversationCollabInvitePreview => 'የተባባሪ ግብዣ';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'በ$title ላይ እንድትተባበር ተጋብዘሃል፦ $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'በቪዲዮ ላይ እንድትተባበር ተጋብዘሃል፦ $url\n\nOpen diVine to review and accept.';
  }

  @override
  String get reportDialogCancel => 'ሰርዝ';

  @override
  String get reportDialogReport => 'ሪፖርት አድርግ';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'ርዕስ፡ $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'ቪዲዮ $current/$total';
  }

  @override
  String get exploreSearchHint => 'ይፈልጉ...';

  @override
  String categoryVideoCount(String count) {
    return '$count ቪዲዮዎች';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'የደንበኝነት ምዝገባን ማዘመን አልተሳካም፦ $error';
  }

  @override
  String get discoverListsTitle => 'ዝርዝሮችን ያግኙ';

  @override
  String get discoverListsFailedToLoad => 'ዝርዝሮችን መጫን አልተሳካም';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'ዝርዝሮችን መጫን አልተሳካም፦ $error';
  }

  @override
  String get discoverListsLoading => 'የህዝብ ዝርዝሮችን በመፈለግ ላይ...';

  @override
  String get discoverListsEmptyTitle => 'ምንም የህዝብ ዝርዝሮች አልተገኙም';

  @override
  String get discoverListsEmptySubtitle => 'ለአዳዲስ ዝርዝሮች ቆይተው ይመልከቱ';

  @override
  String get discoverListsByAuthorPrefix => 'በ';

  @override
  String get curatedListEmptyTitle => 'በዚህ ዝርዝር ውስጥ ምንም ቪዲዮዎች የሉም';

  @override
  String get curatedListEmptySubtitle => 'ለመጀመር ቪዲዮዎችን ያክሉ';

  @override
  String get curatedListLoadingVideos => 'ቪዲዮዎችን በመጫን ላይ...';

  @override
  String get curatedListFailedToLoad => 'ዝርዝሩን መጫን አልተሳካም';

  @override
  String get curatedListNoVideosAvailable => 'ምንም ቪዲዮዎች የሉም';

  @override
  String get curatedListVideoNotAvailable => 'ቪዲዮው አይገኝም';

  @override
  String get commonRetry => 'እንደገና ይሞክሩ';

  @override
  String get commonNext => 'ቀጥሎ';

  @override
  String get commonDelete => 'ሰርዝ';

  @override
  String get commonCancel => 'ሰርዝ';

  @override
  String get commonBack => 'ተመለስ';

  @override
  String get commonClose => 'ዝጋ';

  @override
  String get videoMetadataTags => 'መለያዎች';

  @override
  String get videoMetadataExpiration => 'የማለቂያ ጊዜ';

  @override
  String get videoMetadataExpirationNotExpire => 'ጊዜው አያልቅም።';

  @override
  String get videoMetadataExpirationOneDay => '1 ቀን';

  @override
  String get videoMetadataExpirationOneWeek => '1 ሳምንት';

  @override
  String get videoMetadataExpirationOneMonth => '1 ወር';

  @override
  String get videoMetadataExpirationOneYear => '1 አመት';

  @override
  String get videoMetadataExpirationOneDecade => '1 አስርት አመታት';

  @override
  String get videoMetadataContentWarnings => 'የይዘት ማስጠንቀቂያዎች';

  @override
  String get videoEditorStickers => 'ተለጣፊዎች';

  @override
  String get trendingTitle => 'በመታየት ላይ ያለ';

  @override
  String get proofmodeCheckAiGenerated => 'AI የመነጨ መሆኑን ያረጋግጡ';

  @override
  String get libraryDeleteConfirm => 'ሰርዝ';

  @override
  String get libraryWebUnavailableHeadline => 'ቤተ-መጽሐፍት በሞባይል መተግበሪያ ውስጥ ይገኛል።';

  @override
  String get libraryWebUnavailableDescription =>
      'ረቂቆች እና ክሊፖች በመሳሪያዎ ላይ ተቀምጠዋል፣ስለዚህ እነሱን ለማስተዳደር በስልክዎ ላይ Divineን ይክፈቱ።';

  @override
  String get libraryTabDrafts => 'ረቂቆች';

  @override
  String get libraryTabClips => 'ክሊፖች';

  @override
  String get librarySaveToCameraRollTooltip => 'ወደ ካሜራ ጥቅል አስቀምጥ';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'የተመረጡ ቅንጥቦችን ሰርዝ';

  @override
  String get libraryDeleteClipsTitle => 'ክሊፖችን ሰርዝ';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count የተመረጡ ክሊፖች',
      one: '1 የተመረጠ ክሊፕ',
    );
    return '$_temp0 መሰረዝ እርግጠኛ ነህ?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'ይህ እርምጃ ሊቀለበስ አይችልም። የቪዲዮ ፋይሎቹ እስከመጨረሻው ከመሣሪያዎ ይወገዳሉ።';

  @override
  String get libraryPreparingVideo => 'ቪዲዮ በማዘጋጀት ላይ...';

  @override
  String get libraryCreateVideo => 'ቪዲዮ ፍጠር';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች',
      one: '1 ክሊፕ',
    );
    return '$_temp0 ወደ $destination ተቀምጠዋል';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount ተቀምጧል፣ $failureCount አልተሳካም።';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination ፍቃድ ተከልክሏል።';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ክሊፖች ተሰርዘዋል',
      one: '1 ክሊፕ ተሰርዟል',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'ረቂቆችን መጫን አልተቻለም';

  @override
  String get libraryCouldNotLoadClips => 'ቅንጥቦችን መጫን አልተቻለም';

  @override
  String get libraryOpenErrorDescription =>
      'ቤተ-መጽሐፍትህን በመክፈት ላይ ሳለ የሆነ ችግር ተፈጥሯል። እንደገና መሞከር ይችላሉ።';

  @override
  String get libraryNoDraftsYetTitle => 'እስካሁን ምንም ረቂቅ የለም።';

  @override
  String get libraryNoDraftsYetSubtitle => 'እንደ ረቂቅ ያስቀመጥካቸው ቪዲዮዎች እዚህ ይታያሉ';

  @override
  String get libraryNoClipsYetTitle => 'እስካሁን ምንም ክሊፖች የሉም';

  @override
  String get libraryNoClipsYetSubtitle => 'የተቀዱ የቪዲዮ ቅንጥቦችህ እዚህ ይታያሉ';

  @override
  String get libraryDraftDeletedSnackbar => 'ረቂቅ ተሰርዟል።';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'ረቂቅን መሰረዝ አልተሳካም።';

  @override
  String get libraryDraftActionPost => 'ለጥፍ';

  @override
  String get libraryDraftActionEdit => 'አርትዕ';

  @override
  String get libraryDraftActionDelete => 'ረቂቅ ሰርዝ';

  @override
  String get libraryDeleteDraftTitle => 'ረቂቅ ሰርዝ';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'እርግጠኛ ነህ \"$title\" መሰረዝ ትፈልጋለህ?';
  }

  @override
  String get libraryDeleteClipTitle => 'ክሊፕን ሰርዝ';

  @override
  String get libraryDeleteClipMessage => 'እርግጠኛ ነዎት ይህን ክሊፕ መሰረዝ ይፈልጋሉ?';

  @override
  String get libraryClipSelectionTitle => 'ክሊፖች';

  @override
  String librarySecondsRemaining(String seconds) {
    return '$seconds ይቀራል';
  }

  @override
  String get libraryAddClips => 'አክል';

  @override
  String get libraryRecordVideo => 'ቪዲዮ ይቅረጹ';

  @override
  String get routerInvalidCreator => 'ልክ ያልሆነ ፈጣሪ';

  @override
  String get routerInvalidHashtagRoute => 'ልክ ያልሆነ የሃሽታግ መስመር';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'ቪዲዮዎችን መጫን አልተቻለም';

  @override
  String get categoryGalleryNoVideosInCategory => 'በዚህ ምድብ ውስጥ ምንም ቪዲዮዎች የሉም';

  @override
  String get categoryGallerySortOptionsLabel => 'የምድብ መደርደሪያ አማራጮች';

  @override
  String get categoryGallerySortHot => 'ታዋቂ';

  @override
  String get categoryGallerySortNew => 'አዲስ';

  @override
  String get categoryGallerySortClassic => 'ክላሲክ';

  @override
  String get categoryGallerySortForYou => 'ለእርስዎ';

  @override
  String get categoriesCouldNotLoadCategories => 'ምድቦችን መጫን አልተቻለም';

  @override
  String get categoriesNoCategoriesAvailable => 'ምንም ምድቦች የሉም';

  @override
  String get notificationsEmptyTitle => 'እስካሁን እንቅስቃሴ የለም';

  @override
  String get notificationsEmptySubtitle => 'ሰዎች ከይዘትዎ ጋር ሲገናኙ እዚህ ያያሉ';

  @override
  String get appsPermissionsTitle => 'የተዋሃዱ መተግበሪያዎች ፈቃዶች';

  @override
  String get appsPermissionsRevoke => 'ሰርዝ';

  @override
  String get appsPermissionsEmptyTitle => 'ምንም የተቀመጡ የተዋሃዱ መተግበሪያ ፈቃዶች የሉም';

  @override
  String get appsPermissionsEmptySubtitle =>
      'አንድ የመዳረሻ ፈቃድ እንዲታወስ ከፈቀዱ በኋላ የተፈቀዱ መተግበሪያዎች እዚህ ይታያሉ።';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName ፈቃድዎን ይፈልጋል';
  }

  @override
  String get nostrAppPermissionDescription =>
      'ይህ መተግበሪያ በDivine የተመረመረ sandbox በኩል መዳረሻ ይጠይቃል።';

  @override
  String get nostrAppPermissionOrigin => 'መነሻ';

  @override
  String get nostrAppPermissionMethod => 'ዘዴ';

  @override
  String get nostrAppPermissionCapability => 'ችሎታ';

  @override
  String get nostrAppPermissionEventKind => 'የክስተት አይነት';

  @override
  String get nostrAppPermissionAllow => 'ፍቀድ';

  @override
  String get bugReportSendReport => 'ሪፖርት ላክ';

  @override
  String get supportSubjectRequiredLabel => 'ርዕስ *';

  @override
  String get supportRequiredHelper => 'ያስፈልጋል';

  @override
  String get bugReportSubjectHint => 'የችግሩ አጭር ማጠቃለያ';

  @override
  String get bugReportDescriptionRequiredLabel => 'ምን ተከሰተ? *';

  @override
  String get bugReportDescriptionHint => 'ያጋጠመዎትን ችግር ይግለጹ';

  @override
  String get bugReportStepsLabel => 'ለመድገም የሚወሰዱ እርምጃዎች';

  @override
  String get bugReportStepsHint =>
      '1. ወደ... ይሂዱ\n2. ... ላይ መታ ያድርጉ\n3. ስህተቱን ይመልከቱ';

  @override
  String get bugReportExpectedBehaviorLabel => 'የሚጠበቀው ባህሪ';

  @override
  String get bugReportExpectedBehaviorHint => 'በምትኩ ምን መሆን ነበረበት?';

  @override
  String get bugReportDiagnosticsNotice => 'የመሳሪያ መረጃ እና ሎጎች በራስ-ሰር ይካተታሉ።';

  @override
  String get bugReportSuccessMessage =>
      'እናመሰግናለን! ሪፖርትዎን ተቀብለናል፣ Divineን ለማሻሻል እንጠቀምበታለን።';

  @override
  String get bugReportSendFailed => 'የሳንካ ሪፖርት መላክ አልተሳካም። እባክዎ ቆይተው ይሞክሩ።';

  @override
  String bugReportFailedWithError(String error) {
    return 'የሳንካ ሪፖርት መላክ አልተሳካም፦ $error';
  }

  @override
  String get featureRequestSendRequest => 'ጥያቄ ላክ';

  @override
  String get featureRequestSubjectHint => 'የሀሳብዎ አጭር ማጠቃለያ';

  @override
  String get featureRequestDescriptionRequiredLabel => 'ምን ይፈልጋሉ? *';

  @override
  String get featureRequestDescriptionHint => 'የሚፈልጉትን ባህሪ ይግለጹ';

  @override
  String get featureRequestUsefulnessLabel => 'ይህ እንዴት ይጠቅማል?';

  @override
  String get featureRequestUsefulnessHint => 'ይህ ባህሪ የሚሰጠውን ጥቅም ያብራሩ';

  @override
  String get featureRequestWhenLabel => 'ይህን መቼ ይጠቀማሉ?';

  @override
  String get featureRequestWhenHint => 'ይህ የሚረዳባቸውን ሁኔታዎች ይግለጹ';

  @override
  String get featureRequestSuccessMessage =>
      'እናመሰግናለን! የባህሪ ጥያቄዎን ተቀብለናል፣ እንመለከተዋለን።';

  @override
  String get featureRequestSendFailed => 'የባህሪ ጥያቄ መላክ አልተሳካም። እባክዎ ቆይተው ይሞክሩ።';

  @override
  String featureRequestFailedWithError(String error) {
    return 'የባህሪ ጥያቄ መላክ አልተሳካም፦ $error';
  }

  @override
  String get notificationFollowBack => 'ተመለስ ተከታተል።';

  @override
  String get followingTitle => 'የሚከተሉት';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName የሚከተላቸው';
  }

  @override
  String get followingFailedToLoadList => 'የሚከተለውን ዝርዝር መጫን አልተሳካም።';

  @override
  String get followingEmptyTitle => 'እስካሁን ማንንም አይከተሉም';

  @override
  String get followersTitle => 'ተከታዮች';

  @override
  String followersTitleForName(String displayName) {
    return 'የ$displayName ተከታዮች';
  }

  @override
  String get followersFailedToLoadList => 'የተከታዮች ዝርዝርን መጫን አልተሳካም።';

  @override
  String get followersEmptyTitle => 'እስካሁን ምንም ተከታዮች የሉም';

  @override
  String get followersUpdateFollowFailed =>
      'የመከተል ሁኔታን ማዘመን አልተሳካም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get reportMessageTitle => 'መልዕክትን ሪፖርት አድርግ';

  @override
  String get reportMessageWhyReporting => 'ይህን መልዕክት ለምን ሪፖርት ያደርጋሉ?';

  @override
  String get reportMessageSelectReason =>
      'እባክዎ ይህን መልዕክት ሪፖርት ለማድረግ ምክንያት ይምረጡ';

  @override
  String get newMessageTitle => 'አዲስ መልዕክት';

  @override
  String get newMessageFindPeople => 'ሰዎችን ይፈልጉ';

  @override
  String get newMessageNoContacts =>
      'ምንም እውቂያዎች አልተገኙም።\nሰዎችን ይከተሉ እና እዚህ ያያሉ።';

  @override
  String get newMessageNoUsersFound => 'ምንም ተጠቃሚዎች አልተገኙም';

  @override
  String get hashtagSearchTitle => 'ሃሽታጎችን ይፈልጉ';

  @override
  String get hashtagSearchSubtitle => 'በመታየት ላይ ያሉ ርዕሶችን እና ይዘትን ያግኙ';

  @override
  String hashtagSearchNoResults(String query) {
    return 'ለ\"$query\" ምንም ሃሽታጎች አልተገኙም';
  }

  @override
  String get hashtagSearchFailed => 'ፍለጋው አልተሳካም';

  @override
  String get userNotAvailableTitle => 'መለያው አይገኝም';

  @override
  String get userNotAvailableBody => 'ይህ መለያ አሁን አይገኝም።';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'ቅንብሮችን ማስቀመጥ አልተሳካም፦ $error';
  }

  @override
  String get blossomValidServerUrl =>
      'እባክዎ ትክክለኛ የአገልጋይ URL ያስገቡ (ለምሳሌ፦ https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'የBlossom ቅንብሮች ተቀምጠዋል';

  @override
  String get blossomSaveTooltip => 'አስቀምጥ';

  @override
  String get blossomAboutTitle => 'ስለ Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom ቪዲዮዎችን ወደ ማንኛውም ተኳሃኝ አገልጋይ ለመስቀል የሚያስችል ያልተማከለ የሚዲያ ማከማቻ ፕሮቶኮል ነው። በነባሪነት ቪዲዮዎች ወደ Divine የBlossom አገልጋይ ይሰቀላሉ። በምትኩ ብጁ አገልጋይ ለመጠቀም ከታች ያለውን አማራጭ ያንቁ።';

  @override
  String get blossomUseCustomServer => 'ብጁ Blossom አገልጋይ ተጠቀም';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'ቪዲዮዎች ወደ ብጁ Blossom አገልጋይዎ ይሰቀላሉ';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'ቪዲዮዎችዎ አሁን ወደ Divine የBlossom አገልጋይ እየተሰቀሉ ናቸው';

  @override
  String get blossomCustomServerUrl => 'ብጁ Blossom አገልጋይ URL';

  @override
  String get blossomCustomServerHelper => 'የብጁ Blossom አገልጋይዎን URL ያስገቡ';

  @override
  String get blossomPopularServers => 'ታዋቂ የBlossom አገልጋዮች';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom server URL must use https://';

  @override
  String get blueskyFailedToUpdateCrosspost => 'መስቀለኛ መንገድን ማዘመን አልተሳካም።';

  @override
  String get blueskySignInRequired => 'የBluesky ቅንብሮችን ለማስተዳደር ይግቡ';

  @override
  String get blueskyPublishVideos => 'ቪዲዮዎችን ወደ Bluesky አትም';

  @override
  String get blueskyEnabledSubtitle => 'ቪዲዮዎችዎ ወደ Bluesky ይታተማሉ';

  @override
  String get blueskyDisabledSubtitle => 'ቪዲዮዎችዎ ወደ Bluesky አይታተሙም';

  @override
  String get blueskyHandle => 'የBluesky መያዣ';

  @override
  String get blueskyStatus => 'ሁኔታ';

  @override
  String get blueskyStatusReady => 'መለያው ተዘጋጅቷል እና ዝግጁ ነው';

  @override
  String get blueskyStatusPending => 'መለያው በመዘጋጀት ላይ ነው...';

  @override
  String get blueskyStatusFailed => 'መለያውን ማዘጋጀት አልተሳካም';

  @override
  String get blueskyStatusDisabled => 'መለያው ተሰናክሏል';

  @override
  String get blueskyStatusNotLinked => 'ምንም የBluesky መለያ አልተገናኘም';

  @override
  String get invitesTitle => 'ጓደኞችን ይጋብዙ';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ግብዣዎች ለማመንጨት ዝግጁ ናቸው',
      one: '1 ግብዣ ለማመንጨት ዝግጁ ነው',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle => 'አንድ ለማጋራት ዝግጁ ሲሆኑ ኮድ ይፍጠሩ።';

  @override
  String get invitesGenerateButtonLabel => 'ግብዣ ይፍጠሩ';

  @override
  String get invitesNoneAvailable => 'አሁን ምንም ግብዣዎች የሉም';

  @override
  String get invitesShareWithPeople => 'diVineን ከሚያውቋቸው ሰዎች ጋር ያጋሩ';

  @override
  String get invitesUsedInvites => 'ያገለገሉ ግብዣዎች';

  @override
  String invitesShareMessage(String code) {
    return 'diVine ላይ አብረኝ ግባ! ለመጀመር የግብዣ ኮድ $code ተጠቀም፦\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'ግብዣ ቅዳ';

  @override
  String get invitesCopied => 'ግብዣው ተቀድቷል!';

  @override
  String get invitesShareInvite => 'ግብዣ አጋራ';

  @override
  String get invitesShareSubject => 'diVine ላይ አብረኝ ግባ';

  @override
  String get invitesClaimed => 'ተጠቅመዋል';

  @override
  String get invitesCouldNotLoad => 'ግብዣዎችን መጫን አልተቻለም';

  @override
  String get invitesRetry => 'እንደገና ሞክር';

  @override
  String get searchSomethingWentWrong => 'የሆነ ችግር ተፈጥሯል።';

  @override
  String get searchTryAgain => 'እንደገና ይሞክሩ';

  @override
  String get searchForLists => 'ዝርዝሮችን ይፈልጉ';

  @override
  String get searchFindCuratedVideoLists => 'የተመረጡ የቪዲዮ ዝርዝሮችን ያግኙ';

  @override
  String get searchEnterQuery => 'የፍለጋ ጥያቄ አስገባ';

  @override
  String get searchDiscoverSomethingInteresting => 'አንድ አስደሳች ነገር ያግኙ';

  @override
  String get searchPeopleSectionHeader => 'ሰዎች';

  @override
  String get searchPeopleLoadingLabel => 'የሰዎች ውጤቶችን በመጫን ላይ';

  @override
  String get searchTagsSectionHeader => 'መለያዎች';

  @override
  String get searchTagsLoadingLabel => 'የመለያ ውጤቶችን በመጫን ላይ';

  @override
  String get searchVideosSectionHeader => 'ቪዲዮዎች';

  @override
  String get searchVideosLoadingLabel => 'የቪዲዮ ውጤቶችን በመጫን ላይ';

  @override
  String get searchListsSectionHeader => 'ዝርዝሮች';

  @override
  String get searchListsLoadingLabel => 'የዝርዝር ውጤቶችን በመጫን ላይ';

  @override
  String get cameraAgeRestriction => 'ይዘት ለመፍጠር 16 ወይም ከዚያ በላይ መሆን አለቦት';

  @override
  String get featureRequestCancel => 'ሰርዝ';

  @override
  String keyImportError(String error) {
    return 'ስህተት፡ $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'የBunker ሪሌይ wss:// መጠቀም አለበት (ws:// ለlocalhost ብቻ ይፈቀዳል)';

  @override
  String get timeNow => 'አሁን';

  @override
  String timeShortMinutes(int count) {
    return '$countም';
  }

  @override
  String timeShortHours(int count) {
    return '$countሸ';
  }

  @override
  String timeShortDays(int count) {
    return '$countመ';
  }

  @override
  String timeShortWeeks(int count) {
    return '$countወ';
  }

  @override
  String timeShortMonths(int count) {
    return '$countሞ';
  }

  @override
  String timeShortYears(int count) {
    return '$countይ';
  }

  @override
  String get timeVerboseNow => 'አሁን';

  @override
  String timeAgo(String time) {
    return '$time በፊት';
  }

  @override
  String get timeToday => 'ዛሬ';

  @override
  String get timeYesterday => 'ትናንት';

  @override
  String get timeJustNow => 'ልክ አሁን';

  @override
  String timeMinutesAgo(int count) {
    return '$countደቂቃ በፊት';
  }

  @override
  String timeHoursAgo(int count) {
    return '$countሰ በፊት';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d በፊት';
  }

  @override
  String get draftTimeJustNow => 'ልክ አሁን';

  @override
  String get contentLabelNudity => 'እርቃንነት';

  @override
  String get contentLabelSexualContent => 'ወሲባዊ ይዘት';

  @override
  String get contentLabelPornography => 'የብልግና ሥዕሎች';

  @override
  String get contentLabelGraphicMedia => 'ግራፊክ ሚዲያ';

  @override
  String get contentLabelViolence => 'ብጥብጥ';

  @override
  String get contentLabelSelfHarm => 'ራስን መጉዳት/ ራስን ማጥፋት';

  @override
  String get contentLabelDrugUse => 'የመድሃኒት አጠቃቀም';

  @override
  String get contentLabelAlcohol => 'አልኮል';

  @override
  String get contentLabelTobacco => 'ትምባሆ/ማጨስ';

  @override
  String get contentLabelGambling => 'ቁማር';

  @override
  String get contentLabelProfanity => 'ስድብ';

  @override
  String get contentLabelHateSpeech => 'የጥላቻ ንግግር';

  @override
  String get contentLabelHarassment => 'ትንኮሳ';

  @override
  String get contentLabelFlashingLights => 'ብልጭ ድርግም የሚሉ መብራቶች';

  @override
  String get contentLabelAiGenerated => 'በAI የተፈጠረ';

  @override
  String get contentLabelDeepfake => 'ጥልቅ ሐሰት';

  @override
  String get contentLabelSpam => 'አይፈለጌ መልእክት';

  @override
  String get contentLabelScam => 'ማጭበርበር/ማጭበርበር';

  @override
  String get contentLabelSpoiler => 'ስፒለር';

  @override
  String get contentLabelMisleading => 'አሳሳች';

  @override
  String get contentLabelSensitiveContent => 'ሚስጥራዊነት ያለው ይዘት';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName ቪዲዮህን ወደውታል።';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName አስተያየትህን ወደውታል።';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName በቪዲዮዎ ላይ አስተያየት ሰጥቷል';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName አንተን መከተል ጀመረ';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName ጠቅሶሃል';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName ቪዲዮህን በድጋሚ ለጥፏል';
  }

  @override
  String get notificationRepliedToYourComment => 'ለአስተያየትዎ ምላሽ ሰጥተዋል';

  @override
  String get notificationAndConnector => 'እና';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ሌሎች',
      one: '1 ሌላ',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'አዲስ ማሻሻያ አለህ።';

  @override
  String get notificationSomeoneLikedYourVideo => 'አንድ ሰው ቪዲዮህን ወድዶታል።';

  @override
  String get commentReplyToPrefix => 'ድጋሚ፡';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get draftUntitled => 'ርዕስ አልባ';

  @override
  String get contentWarningNone => 'ምንም';

  @override
  String get textBackgroundNone => 'ምንም';

  @override
  String get textBackgroundSolid => 'ድፍን';

  @override
  String get textBackgroundHighlight => 'አድምቅ';

  @override
  String get textBackgroundTransparent => 'ግልጽ';

  @override
  String get textAlignLeft => 'ግራ';

  @override
  String get textAlignRight => 'ቀኝ';

  @override
  String get textAlignCenter => 'መሃል';

  @override
  String get cameraPermissionWebUnsupportedTitle => 'ካሜራ እስካሁን በድር ላይ አይደገፍም።';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'የካሜራ ቀረጻ እና ቀረጻ እስካሁን በድር ስሪት ውስጥ አይገኙም።';

  @override
  String get cameraPermissionBackToFeed => 'ወደ ምግብ ተመለስ';

  @override
  String get cameraPermissionErrorTitle => 'የፍቃድ ስህተት';

  @override
  String get cameraPermissionErrorDescription =>
      'ፈቃዶችን በመፈተሽ ላይ ሳለ የሆነ ችግር ተፈጥሯል።';

  @override
  String get cameraPermissionRetry => 'እንደገና ይሞክሩ';

  @override
  String get cameraPermissionAllowAccessTitle => 'የካሜራ እና ማይክሮፎን መዳረሻ ፍቀድ';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'ይህ በመተግበሪያው ውስጥ ቪዲዮዎችን እንዲቀርጹ እና እንዲያርትዑ ይፈቅድልዎታል፣ ምንም ተጨማሪ ነገር የለም።';

  @override
  String get cameraPermissionContinue => 'ቀጥል';

  @override
  String get cameraPermissionGoToSettings => 'ወደ ቅንብሮች ይሂዱ';

  @override
  String get videoRecorderWhySixSecondsTitle => 'ለምን ስድስት ሰከንዶች?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'ፈጣን ቅንጥቦች ለድንገተኛነት ቦታ ይፈጥራሉ። የ6 ሰከንድ ቅርጸት ትክክለኛ ጊዜዎችን በሚከሰቱበት ጊዜ እንዲይዙ ያግዝዎታል።';

  @override
  String get videoRecorderWhySixSecondsButton => 'ገባኝ!';

  @override
  String get videoRecorderUploadTitle => 'ለምን መጫን የለም?';

  @override
  String get videoRecorderUploadBody =>
      'በዲቫይን ላይ የምታየው በሰው የተሰራ ነው፦ ጥሬ እና በወቅቱ የተቀረጸ። በከፍተኛ የተዘጋጁ ወይም በAI የተፈጠሩ ጭነቶችን የሚፈቅዱ መድረኮች በተለየ መልኩ፣ የቀጥታ ካሜራ ተሞክሮን ትክክለኛነት እናስቀድማለን።';

  @override
  String get videoRecorderUploadBodyDetail =>
      'ፍጠራን ከመተግበሪያው ውስጥ በማቆየት፣ ይዘቱ እውነተኛ እና ያልተስተካከለ መሆኑን በተሻለ ሁኔታ ልንዋስ እንችላለን። ያን እውነተኛነት ለመጠበቅና ማህበረሰባችንን በተቻለ መጠን ከሰው ሰራሽ ይዘት ነጻ ለማድረግ፣ በአሁኑ ጊዜ ከውጪ ጋለሪ መጫን አንፈቅድም።';

  @override
  String get videoRecorderUploadBodyCta =>
      'እውነተኛ ነገር ለመቅረጽ ወደ Capture ወይም Classic ቀይር።';

  @override
  String get videoRecorderUploadLearnMore => 'ማረጋገጫ እንዴት እንደሚሰራ ተማር';

  @override
  String get videoRecorderAutosaveFoundTitle => 'በሂደት ላይ ያለ ስራ አግኝተናል';

  @override
  String get videoRecorderAutosaveFoundSubtitle => 'ካቆሙበት መቀጠል ይፈልጋሉ?';

  @override
  String get videoRecorderAutosaveContinueButton => 'አዎ ቀጥል።';

  @override
  String get videoRecorderAutosaveDiscardButton => 'አይ፣ አዲስ ቪዲዮ ጀምር';

  @override
  String get videoRecorderAutosaveRestoreFailure => 'ረቂቅዎን ወደነበረበት መመለስ አልተቻለም';

  @override
  String get videoRecorderStopRecordingTooltip => 'መቅዳት አቁም';

  @override
  String get videoRecorderStartRecordingTooltip => 'መቅዳት ጀምር';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'መቅዳት. ለማቆም የትኛውም ቦታ ላይ መታ ያድርጉ';

  @override
  String get videoRecorderTapToStartLabel => 'መቅዳት ለመጀመር የትኛውም ቦታ ላይ መታ ያድርጉ';

  @override
  String get videoRecorderDeleteLastClipLabel => 'የመጨረሻውን ቅንጥብ ሰርዝ';

  @override
  String get videoRecorderSwitchCameraLabel => 'ካሜራ ቀይር';

  @override
  String get videoRecorderToggleGridLabel => 'ፍርግርግ ቀያይር';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'የGhost ፍሬም ሁኔታ ቀይር';

  @override
  String get videoRecorderGhostFrameEnabled => 'Ghost ፍሬም በርቷል';

  @override
  String get videoRecorderGhostFrameDisabled => 'Ghost ፍሬም ጠፍቷል';

  @override
  String get videoRecorderClipDeletedMessage => 'ክሊፕ ተሰርዟል።';

  @override
  String get videoRecorderCloseLabel => 'የቪዲዮ መቅረጫ ዝጋ';

  @override
  String get videoRecorderContinueToEditorLabel => 'ወደ ቪዲዮ አርታዒ ይቀጥሉ';

  @override
  String get videoRecorderCaptureCloseLabel => 'ገጠመ';

  @override
  String get videoRecorderCaptureNextLabel => 'ቀጥሎ';

  @override
  String get videoRecorderToggleFlashLabel => 'ብልጭታ ቀያይር';

  @override
  String get videoRecorderCycleTimerLabel => 'የዑደት ሰዓት ቆጣሪ';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'ምጥጥን ቀያይር';

  @override
  String get videoRecorderLibraryEmptyLabel => 'ክሊፕ ቤተ-መጽሐፍት፣ ምንም ቅንጥቦች የሉም';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'የክሊፕ ቤተ-መዝገብ ክፈት፣ $clipCount ክሊፖች',
      one: 'የክሊፕ ቤተ-መዝገብ ክፈት፣ 1 ክሊፕ',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'ካሜራ';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'ካሜራ ክፈት';

  @override
  String get videoEditorLibraryLabel => 'ቤተ መፃህፍት';

  @override
  String get videoEditorTextLabel => 'ጽሑፍ';

  @override
  String get videoEditorDrawLabel => 'ይሳሉ';

  @override
  String get videoEditorFilterLabel => 'አጣራ';

  @override
  String get videoEditorAudioLabel => 'ኦዲዮ';

  @override
  String get videoEditorVolumeLabel => 'መጠን';

  @override
  String get videoEditorAddTitle => 'አክል';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'ቤተ መፃህፍት ክፈት';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'የድምጽ አርታዒን ክፈት';

  @override
  String get videoEditorOpenTextSemanticLabel => 'የጽሑፍ አርታዒን ክፈት';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'የስዕል አርታዒን ክፈት';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'የማጣሪያ አርታዒን ክፈት';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'ተለጣፊ አርታዒን ክፈት';

  @override
  String get videoEditorSaveDraftTitle => 'ረቂቅዎን ይቆጥቡ?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'አርትዖቶችዎን ለበለጠ ጊዜ ያቆዩት ወይም ያስወግዱዋቸው እና አርታዒውን ይተዉት።';

  @override
  String get videoEditorSaveDraftButton => 'ረቂቅ አስቀምጥ';

  @override
  String get videoEditorDiscardChangesButton => 'ለውጦችን አስወግድ';

  @override
  String get videoEditorKeepEditingButton => 'ማረምዎን ይቀጥሉ';

  @override
  String get videoEditorDeleteLayerDropZone => 'የንብርብር ጠብታ ዞን ሰርዝ';

  @override
  String get videoEditorReleaseToDeleteLayer => 'ንብርብር ለመሰረዝ ይልቀቁ';

  @override
  String get videoEditorDoneLabel => 'ተከናውኗል';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'ቪዲዮን ያጫውቱ ወይም ለአፍታ ያቁሙ';

  @override
  String get videoEditorCropSemanticLabel => 'ሰብል';

  @override
  String get videoEditorCannotSplitProcessing =>
      'ክሊፕ በሂደት ላይ እያለ መከፋፈል አይቻልም። እባክህ ጠብቅ።';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'የመክፈል ቦታው ልክ አይደለም። ሁለቱም ክሊፖች ቢያንስ ${minDurationMs}ms ርዝመት ሊኖራቸው ይገባል።';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'ክሊፕ ከቤተ-መጽሐፍት ያክሉ';

  @override
  String get videoEditorSaveSelectedClip => 'የተመረጠውን ቅንጥብ ያስቀምጡ';

  @override
  String get videoEditorSplitClip => 'የተከፈለ ቅንጥብ';

  @override
  String get videoEditorSaveClip => 'ቅንጥብ ያስቀምጡ';

  @override
  String get videoEditorDeleteClip => 'ቅንጥብ ሰርዝ';

  @override
  String get videoEditorClipSavedSuccess => 'ክሊፕ ወደ ቤተ-መጽሐፍት ተቀምጧል';

  @override
  String get videoEditorClipSaveFailed => 'ቅንጥብ ማስቀመጥ አልተሳካም።';

  @override
  String get videoEditorClipDeleted => 'ክሊፕ ተሰርዟል።';

  @override
  String get videoEditorColorPickerSemanticLabel => 'ቀለም መራጭ';

  @override
  String get videoEditorUndoSemanticLabel => 'ቀልብስ';

  @override
  String get videoEditorRedoSemanticLabel => 'ድገም';

  @override
  String get videoEditorTextColorSemanticLabel => 'የጽሑፍ ቀለም';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'የጽሑፍ አሰላለፍ';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'የጽሑፍ ዳራ';

  @override
  String get videoEditorFontSemanticLabel => 'ቅርጸ-ቁምፊ';

  @override
  String get videoEditorNoStickersFound => 'ምንም ተለጣፊዎች አልተገኙም።';

  @override
  String get videoEditorNoStickersAvailable => 'ምንም ተለጣፊዎች አይገኙም።';

  @override
  String get videoEditorFailedLoadStickers => 'ተለጣፊዎችን መጫን አልተሳካም።';

  @override
  String get videoEditorAdjustVolumeTitle => 'ድምጽን ያስተካክሉ';

  @override
  String get videoEditorRecordedAudioLabel => 'የተቀዳ ኦዲዮ';

  @override
  String get videoEditorCustomAudioLabel => 'ብጁ ኦዲዮ';

  @override
  String get videoEditorPlaySemanticLabel => 'ይጫወቱ';

  @override
  String get videoEditorPauseSemanticLabel => 'ለአፍታ አቁም';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'ኦዲዮ ድምጸ-ከል አድርግ';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'የድምጽ ድምጸ-ከል አንሳ';

  @override
  String get videoEditorDeleteLabel => 'ሰርዝ';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel => 'የተመረጠውን ንጥል ሰርዝ';

  @override
  String get videoEditorEditLabel => 'አርትዕ';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'የተመረጠውን ንጥል ያርትዑ';

  @override
  String get videoEditorDuplicateLabel => 'ማባዛት።';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel => 'የተመረጠውን ንጥል ያባዛ';

  @override
  String get videoEditorSplitLabel => 'ተከፈለ';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'የተመረጠውን ቅንጥብ ክፈል።';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'የጊዜ መስመር አርትዖትን ጨርስ';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'ቅድመ እይታን አጫውት።';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'ቅድመ እይታን ባለበት አቁም';

  @override
  String get videoEditorAudioUntitledSound => 'ርዕስ አልባ ድምጽ';

  @override
  String get videoEditorAudioUntitled => 'ርዕስ አልባ';

  @override
  String get videoEditorAudioAddAudio => 'ኦዲዮ ያክሉ';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'ምንም ድምፆች የሉም';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'ፈጣሪዎች ኦዲዮን ሲያጋሩ ድምጾች እዚህ ይታያሉ';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'ድምጾችን መጫን አልተሳካም።';

  @override
  String get videoEditorAudioSegmentInstruction => 'ለቪዲዮዎ የድምጽ ክፍሉን ይምረጡ';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'ማህበረሰብ';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'የቀስት መሣሪያ';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'መጥረጊያ መሳሪያ';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'ምልክት ማድረጊያ መሳሪያ';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'የእርሳስ መሳሪያ';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'ንብርብር እንደገና ይዘዙ $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'እንደገና ለመደርደር ይያዙ';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'የጊዜ መስመር አሳይ';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'የጊዜ መስመርን ደብቅ';

  @override
  String get videoEditorFeedPreviewContent =>
      'ከእነዚህ አካባቢዎች በስተጀርባ ይዘትን ከማስቀመጥ ተቆጠብ።';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine ኦሪጅናል';

  @override
  String get videoEditorStickerSearchHint => 'ተለጣፊዎችን ፈልግ...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'ቅርጸ-ቁምፊ ይምረጡ';

  @override
  String get videoEditorFontUnknown => 'ያልታወቀ';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'የመጫወቻ ቦታ ለመከፋፈል በተመረጠው ቅንጥብ ውስጥ መሆን አለበት።';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'ጅምር ይከርክሙ';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'መጨረሻውን ይከርክሙ';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'ቅንጥብ ይከርክሙ';

  @override
  String get videoEditorTimelineTrimClipHint => 'የቅንጥብ ቆይታ ለማስተካከል መያዣዎችን ይጎትቱ';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'ቅንጥብ መጎተት $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'የ$index የ$total፣ $duration ሴኮንዶች ቅንጥብ';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'እንደገና ለመደርደር በረጅሙ ተጫን';

  @override
  String get videoEditorClipGalleryInstruction =>
      'ለማርትዕ መታ ያድርጉ። እንደገና ለመደርደር ይያዙ እና ይጎትቱ።';

  @override
  String get videoEditorTimelineClipMoveLeft => 'ወደ ግራ ውሰድ';

  @override
  String get videoEditorTimelineClipMoveRight => 'ወደ ቀኝ አንቀሳቅስ';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'ለመጎተት በረጅሙ ተጫን';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'የቪዲዮ የጊዜ መስመር';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName፣ ተመርጧል';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'የቀለም መራጭን ይዝጉ';

  @override
  String get videoEditorPickColorTitle => 'ቀለም ይምረጡ';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'ቀለም ያረጋግጡ';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel => 'ሙሌት እና ብሩህነት';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'ሙሌት $saturation%፣ ብሩህነት $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'ሁ';

  @override
  String get videoEditorAddElementSemanticLabel => 'ኤለመንት አክል';

  @override
  String get videoEditorCloseSemanticLabel => 'ገጠመ';

  @override
  String get videoEditorDoneSemanticLabel => 'ተከናውኗል';

  @override
  String get videoEditorLevelSemanticLabel => 'ደረጃ';

  @override
  String get videoMetadataBackSemanticLabel => 'ተመለስ';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => 'የእገዛ ንግግርን አሰናብት';

  @override
  String get videoMetadataGotItButton => 'ገባኝ!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB ገደብ ላይ ደርሷል። ለመቀጠል አንዳንድ ይዘቶችን ያስወግዱ።';

  @override
  String get videoMetadataExpirationLabel => 'የማለቂያ ጊዜ';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => 'የማለቂያ ጊዜን ይምረጡ';

  @override
  String get videoMetadataTitleLabel => 'ርዕስ';

  @override
  String get videoMetadataDescriptionLabel => 'መግለጫ';

  @override
  String get videoMetadataTagsLabel => 'መለያዎች';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'ሰርዝ';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'መለያን ሰርዝ $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'የይዘት ማስጠንቀቂያ';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'የይዘት ማስጠንቀቂያዎችን ይምረጡ';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'በይዘትህ ላይ የሚመለከተውን ሁሉ ምረጥ';

  @override
  String get videoMetadataContentWarningDoneButton => 'ተከናውኗል';

  @override
  String get videoMetadataCollaboratorsLabel => 'ተባባሪዎች';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'ተባባሪ ጋብዝ';

  @override
  String get videoMetadataCollaboratorsHelpTooltip => 'ተባባሪዎች እንዴት እንደሚሠሩ';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max ተባባሪዎች';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel => 'ተባባሪውን ያስወግዱ';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'በዚህ ልጥፍ ላይ ተባባሪዎች እንደ ተባባሪ ፈጣሪዎች ተጋብዘዋል። እርስዎ በጋራ የሚከተሏቸውን ሰዎች ብቻ መጋበዝ ይችላሉ፣ እና ካረጋገጡ በኋላ እንደ ተባባሪዎች ሆነው ይታያሉ።';

  @override
  String get videoMetadataMutualFollowersSearchText => 'የጋራ ተከታዮች';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'እነሱን እንደ ተባባሪ ለመጋበዝ $nameን በጋራ መከተል አለቦት።';
  }

  @override
  String get videoMetadataInspiredByLabel => 'ተመስጦ';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'ተመስጦ የተዘጋጀ';

  @override
  String get videoMetadataInspiredByHelpTooltip => 'ማበረታቻ ምስጋናዎች እንዴት እንደሚሠሩ';

  @override
  String get videoMetadataInspiredByNone => 'ምንም';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'መለያ ለመስጠት ይህንን ይጠቀሙ። ተነሳሽነት ያለው ክሬዲት ከተባባሪዎች የተለየ ነው፡ ተጽዕኖን ይቀበላል፣ ነገር ግን አንድን ሰው እንደ ተባባሪ ፈጣሪ መለያ አይሰጥም።';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'ይህ ፈጣሪ ሊጠቀስ አይችልም።';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel => 'ተመስጦ አስወግድ';

  @override
  String get videoMetadataPostDetailsTitle => 'ዝርዝሮችን ይለጥፉ';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'ወደ ቤተ-መጽሐፍት ተቀምጧል';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'ማስቀመጥ አልተሳካም።';

  @override
  String get videoMetadataGoToLibraryButton => 'ወደ ቤተ-መጽሐፍት ሂድ';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'ለበኋላ አዝራር አስቀምጥ';

  @override
  String get videoMetadataRenderingVideoHint => 'ቪዲዮ በማቅረብ ላይ...';

  @override
  String get videoMetadataSavingVideoHint => 'ቪዲዮ በማስቀመጥ ላይ...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'ቪዲዮን ወደ ረቂቆች እና $destination አስቀምጥ';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'በኋላ ላይ አስቀምጥ';

  @override
  String get videoMetadataPostSemanticLabel => 'የመለጠፍ ቁልፍ';

  @override
  String get videoMetadataPublishVideoHint => 'ለመመገብ ቪዲዮ ያትሙ';

  @override
  String get videoMetadataFormNotReadyHint => 'ለማንቃት ቅጹን ይሙሉ';

  @override
  String get videoMetadataPostButton => 'ለጥፍ';

  @override
  String get videoMetadataOpenPreviewSemanticLabel => 'የልጥፍ ቅድመ እይታ ማያን ክፈት';

  @override
  String get videoMetadataShareTitle => 'አጋራ';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'የቪዲዮ ዝርዝሮች';

  @override
  String get videoMetadataClassicDoneButton => 'ተከናውኗል';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'ቅድመ እይታን አጫውት።';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'ቅድመ እይታን ባለበት አቁም';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'የቪዲዮ ቅድመ እይታን ዝጋ';

  @override
  String get videoMetadataRemoveSemanticLabel => 'አስወግድ';

  @override
  String get metadataCaptionsLabel => 'መግለጫ ጽሑፎች';

  @override
  String get metadataCaptionsEnabledSemantics => 'መግለጫ ጽሑፎች ለሁሉም ቪዲዮዎች ነቅተዋል።';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'መግለጫ ጽሑፎች ለሁሉም ቪዲዮዎች ተሰናክለዋል።';

  @override
  String get fullscreenFeedRemovedMessage => 'ቪዲዮ ተወግዷል';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Accept awards and check issued badge status.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesIntroTitle => 'Understand your badge trail';

  @override
  String get badgesIntroBody =>
      'See badge awards sent to you, choose what to pin to your Nostr profile, and check whether people accepted badges you issued.';

  @override
  String get badgesOpenApp => 'Open badges app';

  @override
  String get badgesLoadError => 'Could not load badges';

  @override
  String get badgesUpdateError => 'Could not update badge';

  @override
  String get badgesAwardedSectionTitle => 'Awarded to you';

  @override
  String get badgesAwardedEmptyTitle => 'No badge awards yet';

  @override
  String get badgesAwardedEmptySubtitle =>
      'When someone awards you a Nostr badge, it will land here.';

  @override
  String get badgesStatusAccepted => 'Accepted';

  @override
  String get badgesStatusNotAccepted => 'Not accepted';

  @override
  String get badgesActionRemove => 'Remove';

  @override
  String get badgesActionAccept => 'Accept';

  @override
  String get badgesActionReject => 'Reject';

  @override
  String get badgesIssuedSectionTitle => 'Issued by you';

  @override
  String get badgesIssuedEmptyTitle => 'No issued badges yet';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badges you issue will show acceptance status here.';

  @override
  String get badgesIssuedNoRecipients => 'No recipients found for this award.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepted by recipient';

  @override
  String get badgesRecipientWaitingStatus => 'Waiting for recipient';
}
