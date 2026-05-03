// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Bulgarian (`bg`).
class AppLocalizationsBg extends AppLocalizations {
  AppLocalizationsBg([String locale = 'bg']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Настройки';

  @override
  String get settingsSecureAccount => 'Защити акаунта си';

  @override
  String get settingsSessionExpired => 'Сесията изтече';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Влез отново, за да си върнеш пълния достъп';

  @override
  String get settingsCreatorAnalytics => 'Аналитика за творци';

  @override
  String get settingsSupportCenter => 'Помощен център';

  @override
  String get settingsNotifications => 'Известия';

  @override
  String get settingsContentPreferences => 'Предпочитания за съдържание';

  @override
  String get settingsModerationControls => 'Контроли за модерация';

  @override
  String get settingsBlueskyPublishing => 'Публикуване в Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Управлявай публикуването в Bluesky';

  @override
  String get settingsNostrSettings => 'Настройки за Nostr';

  @override
  String get settingsIntegratedApps => 'Свързани приложения';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Одобрени външни приложения, които работят в Divine';

  @override
  String get settingsExperimentalFeatures => 'Експериментални функции';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Малки експерименти, които може да се държат странно. Пробвай, ако ти е любопитно.';

  @override
  String get settingsLegal => 'Правни неща';

  @override
  String get settingsIntegrationPermissions => 'Разрешения за интеграции';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Прегледай и махни запомнените одобрения за интеграции';

  @override
  String settingsVersion(String version) {
    return 'Версия $version';
  }

  @override
  String get settingsVersionEmpty => 'Версия';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Режимът за разработчици вече е включен';

  @override
  String get settingsDeveloperModeEnabled =>
      'Режимът за разработчици е включен!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Още $count докосвания, за да включиш режима за разработчици';
  }

  @override
  String get settingsInvites => 'Покани';

  @override
  String get settingsSwitchAccount => 'Смени акаунта';

  @override
  String get settingsAddAnotherAccount => 'Добави друг акаунт';

  @override
  String get settingsUnsavedDraftsTitle => 'Незапазени чернови';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и чернови',
      one: 'а чернова',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'те ще се запазят',
      one: 'тя ще се запази',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ги публикуваш или прегледаш',
      one: 'я публикуваш или прегледаш',
    );
    return 'Имаш $count незапазен$_temp0. При смяна на акаунта $_temp1, но може първо да $_temp2.';
  }

  @override
  String get settingsCancel => 'Отказ';

  @override
  String get settingsSwitchAnyway => 'Смени въпреки това';

  @override
  String get settingsAppVersionLabel => 'Версия на приложението';

  @override
  String get settingsAppLanguage => 'Език на приложението';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (език на устройството)';
  }

  @override
  String get settingsAppLanguageTitle => 'Език на приложението';

  @override
  String get settingsAppLanguageDescription =>
      'Избери езика за интерфейса на приложението';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Използвай езика на устройството';

  @override
  String get settingsGeneralTitle => 'General Settings';

  @override
  String get settingsContentSafetyTitle => 'Content & Safety';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIONS';

  @override
  String get generalSettingsSectionViewing => 'VIEWING';

  @override
  String get generalSettingsSectionCreating => 'CREATING';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get generalSettingsClosedCaptions => 'Closed Captions';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Show captions when videos include them';

  @override
  String get generalSettingsVideoShape => 'Video Shape';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Square videos only';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait =>
      'Square and portrait';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Show the full mix of Divine videos';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Keep feeds in the classic square format';

  @override
  String get contentPreferencesTitle => 'Предпочитания за съдържание';

  @override
  String get contentPreferencesContentFilters => 'Филтри за съдържание';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Управлявай филтрите за предупреждения';

  @override
  String get contentPreferencesContentLanguage => 'Език на съдържанието';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (език на устройството)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Слагай език на видеата си, за да могат хората да филтрират какво гледат.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Използвай езика на устройството (по подразбиране)';

  @override
  String get contentPreferencesAudioSharing =>
      'Позволи моето аудио да се използва отново';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Когато е включено, други могат да използват аудио от твоите видеа';

  @override
  String get contentPreferencesAccountLabels => 'Етикети на акаунта';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Сам избираш етикетите за съдържанието си';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Етикети за съдържанието на акаунта';

  @override
  String get contentPreferencesClearAll => 'Изчисти всичко';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Избери всичко, което важи за акаунта ти';

  @override
  String get contentPreferencesDoneNoLabels => 'Готово (без етикети)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Готово ($count избрани)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Аудио вход';

  @override
  String get contentPreferencesAutoRecommended => 'Автоматично (препоръчано)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Автоматично избира най-добрия микрофон';

  @override
  String get contentPreferencesSelectAudioInput => 'Избери аудио вход';

  @override
  String get contentPreferencesUnknownMicrophone => 'Неизвестен микрофон';

  @override
  String get contentFiltersAdultContent => 'ADULT CONTENT';

  @override
  String get contentFiltersViolenceGore => 'VIOLENCE & GORE';

  @override
  String get contentFiltersSubstances => 'SUBSTANCES';

  @override
  String get contentFiltersOther => 'OTHER';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verify your age in Safety & Privacy settings to unlock adult content filters';

  @override
  String get contentFiltersShow => 'Show';

  @override
  String get contentFiltersWarn => 'Warn';

  @override
  String get contentFiltersFilterOut => 'Filter Out';

  @override
  String get profileBlockedAccountNotAvailable => 'Този акаунт не е наличен';

  @override
  String profileErrorPrefix(Object error) {
    return 'Грешка: $error';
  }

  @override
  String get profileInvalidId => 'Невалиден ID на профил';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Виж $displayName в Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName в Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Не успяхме да споделим профила: $error';
  }

  @override
  String get profileEditProfile => 'Редактирай профила';

  @override
  String get profileCreatorAnalytics => 'Анализ на създателя';

  @override
  String get profileShareProfile => 'Сподели профила';

  @override
  String get profileCopyPublicKey => 'Копирай публичния ключ (npub)';

  @override
  String get profileGetEmbedCode => 'Вземи код за вграждане';

  @override
  String get profilePublicKeyCopied => 'Публичният ключ е копиран';

  @override
  String get profileEmbedCodeCopied =>
      'Кодът за вграждане е копиран в клипборда';

  @override
  String get profileRefreshTooltip => 'Опресни';

  @override
  String get profileRefreshSemanticLabel => 'Опресняване на профила';

  @override
  String get profileMoreTooltip => 'Още';

  @override
  String get profileMoreSemanticLabel => 'Още опции';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Затваряне на аватара';

  @override
  String get profileAvatarLightboxCloseSemanticLabel => 'Затвори аватара';

  @override
  String get profileFollowingLabel => 'Следваш';

  @override
  String get profileFollowLabel => 'Следвай';

  @override
  String get profileBlockedLabel => 'Блокиран';

  @override
  String get profileFollowersLabel => 'Последователи';

  @override
  String get profileFollowingStatLabel => 'Следва';

  @override
  String get profileVideosLabel => 'Видеа';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count потребители';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Да блокираме $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Когато блокираш потребител:';

  @override
  String get profileBlockBulletHidePosts =>
      'Публикациите им няма да се показват в емисиите ти.';

  @override
  String get profileBlockBulletCantView =>
      'Няма да могат да виждат профила ти, да те следват или да виждат публикациите ти.';

  @override
  String get profileBlockBulletNoNotify =>
      'Те няма да бъдат уведомени за тази промяна.';

  @override
  String get profileBlockBulletYouCanView =>
      'Все още ще можеш да видиш профила им.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Блокирай $displayName';
  }

  @override
  String get profileCancelButton => 'Отказ';

  @override
  String get profileLearnMore => 'Научи повече';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Да отблокираме $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Когато отблокираш този потребител:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Публикациите им пак ще се показват в емисиите ти.';

  @override
  String get profileUnblockBulletCanView =>
      'Ще могат да виждат профила ти, да те следват и да виждат публикациите ти.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Те няма да бъдат уведомени за тази промяна.';

  @override
  String get profileLearnMoreAt => 'Научи повече на';

  @override
  String get profileUnblockButton => 'Разблокирай';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Спри да следваш $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Блокирай $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Отблокирай $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Добави $displayName към списък';
  }

  @override
  String get profileUserBlockedTitle => 'Потребителят е блокиран';

  @override
  String get profileUserBlockedContent =>
      'Няма да виждаш съдържание от този потребител във фийдовете си.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Можеш да отблокираш този профил по всяко време от профила му или от Настройки > Безопасност.';

  @override
  String get profileCloseButton => 'Затвори';

  @override
  String get profileNoCollabsTitle => 'Още няма колаборации';

  @override
  String get profileCollabsOwnEmpty =>
      'Видеата, в които участваш, ще се появят тук.';

  @override
  String get profileCollabsOtherEmpty =>
      'Видеата, в които участват, ще се появят тук.';

  @override
  String get profileErrorLoadingCollabs =>
      'Грешка при зареждане на видеата със сътрудничества';

  @override
  String get profileNoSavedVideosTitle => 'Още нищо не е запазено';

  @override
  String get profileSavedOwnEmpty =>
      'Запази видеа от менюто за споделяне и ще се появят тук.';

  @override
  String get profileErrorLoadingSaved =>
      'Грешка при зареждане на запазените видеа';

  @override
  String get profileNoCommentsOwnTitle => 'Още няма коментари';

  @override
  String get profileNoCommentsOtherTitle => 'Още няма коментари';

  @override
  String get profileCommentsOwnEmpty =>
      'Твоите коментари и отговори ще се появят тук.';

  @override
  String get profileCommentsOtherEmpty =>
      'Техните коментари и отговори ще се показват тук.';

  @override
  String get profileErrorLoadingComments => 'Грешка при зареждане на коментари';

  @override
  String get profileVideoRepliesSection => 'Видео отговори';

  @override
  String get profileCommentsSection => 'Коментари';

  @override
  String get profileEditLabel => 'Редактиране';

  @override
  String get profileLibraryLabel => 'Библиотека';

  @override
  String get profileNoLikedVideosTitle => 'Още няма харесвания';

  @override
  String get profileLikedOwnEmpty =>
      'Когато нещо ти хване окото, натисни сърцето. Харесванията ти ще се появят тук.';

  @override
  String get profileLikedOtherEmpty =>
      'Още нищо не им е хванало окото. Дай му време.';

  @override
  String get profileErrorLoadingLiked =>
      'Грешка при зареждане на харесаните видеа';

  @override
  String get profileNoRepostsTitle => 'Още няма репостове';

  @override
  String get profileRepostsOwnEmpty =>
      'Видя нещо, което си струва да споделиш? Публикувай го пак и ще се появи тук.';

  @override
  String get profileRepostsOtherEmpty =>
      'Още не са препубликували нищо. Когато го направят, ще се появи тук.';

  @override
  String get profileErrorLoadingReposts =>
      'Грешка при зареждане на репостнатите видеа';

  @override
  String get profileLoadingTitle => 'Профилът се зарежда...';

  @override
  String get profileLoadingSubtitle => 'Това може да отнеме няколко минути';

  @override
  String get profileLoadingVideos => 'Видеата се зареждат...';

  @override
  String get profileNoVideosTitle => 'Още няма видеа';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Сцената е твоя. Започни да публикуваш и видеата ти ще живеят тук.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Светът чака. Последвай ги, за да не изпуснеш нищо.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Миниатюра на видео $number';
  }

  @override
  String get profileShowMore => 'Покажи повече';

  @override
  String get profileShowLess => 'Покажи по-малко';

  @override
  String get profileCompleteYourProfile => 'Довърши профила си';

  @override
  String get profileCompleteSubtitle =>
      'Добави име, био и снимка, за да започнеш';

  @override
  String get profileSetUpButton => 'Настрой';

  @override
  String get profileVerifyingEmail => 'Проверяваме имейла...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Провери $email за линк за потвърждение';
  }

  @override
  String get profileWaitingForVerification => 'Изчакване на имейл потвърждение';

  @override
  String get profileVerificationFailed => 'Потвърждението не мина';

  @override
  String get profilePleaseTryAgain => 'Опитай пак';

  @override
  String get profileSecureYourAccount => 'Защити акаунта си';

  @override
  String get profileSecureSubtitle =>
      'Добави имейл и парола, за да възстановиш акаунта си на всяко устройство';

  @override
  String get profileRetryButton => 'Опитай пак';

  @override
  String get profileRegisterButton => 'Регистрирай се';

  @override
  String get profileSessionExpired => 'Сесията изтече';

  @override
  String get profileSignInToRestore =>
      'Влез отново, за да си върнеш пълния достъп';

  @override
  String get profileSignInButton => 'Вход';

  @override
  String get profileMaybeLaterLabel => 'Може би по-късно';

  @override
  String get profileSecurePrimaryButton => 'Добави имейл и парола';

  @override
  String get profileCompletePrimaryButton => 'Обнови профила си';

  @override
  String get profileLoopsLabel => 'Лупове';

  @override
  String get profileLikesLabel => 'Харесвания';

  @override
  String get profileMyLibraryLabel => 'Моята библиотека';

  @override
  String get profileMessageLabel => 'Съобщение';

  @override
  String get profileUserFallback => 'Потребител';

  @override
  String get profileDismissTooltip => 'Отхвърляне';

  @override
  String get profileLinkCopied => 'Връзката към профила е копирана';

  @override
  String get profileSetupEditProfileTitle => 'Редактиране на профил';

  @override
  String get profileSetupBackLabel => 'Назад';

  @override
  String get profileSetupAboutNostr => 'Относно Nostr';

  @override
  String get profileSetupProfilePublished => 'Профилът е публикуван успешно!';

  @override
  String get profileSetupCreateNewProfile => 'Създаване на нов профил?';

  @override
  String get profileSetupNoExistingProfile =>
      'Не намерихме съществуващ профил на релетата ти. Ако продължиш, ще създадем нов профил.';

  @override
  String get profileSetupPublishButton => 'Публикувай';

  @override
  String get profileSetupUsernameTaken =>
      'Това потребителско име току-що беше заето. Избери друго.';

  @override
  String get profileSetupClaimFailed =>
      'Не успяхме да запазим потребителското име. Опитай пак.';

  @override
  String get profileSetupPublishFailed =>
      'Профилът не се публикува. Опитай пак.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Не успяхме да се свържем с мрежата. Провери връзката си и опитай пак.';

  @override
  String get profileSetupRetryLabel => 'Опитай пак';

  @override
  String get profileSetupDisplayNameLabel => 'Име за показване';

  @override
  String get profileSetupDisplayNameHint => 'Как да те познават хората?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Каквото име или етикет искаш. Не е нужно да е уникално.';

  @override
  String get profileSetupDisplayNameRequired => 'Въведи име за показване';

  @override
  String get profileSetupBioLabel => 'Био (по избор)';

  @override
  String get profileSetupBioHint => 'Разкажи на хората за себе си...';

  @override
  String get profileSetupPublicKeyLabel => 'Публичен ключ (npub)';

  @override
  String get profileSetupUsernameLabel => 'Потребителско име (по избор)';

  @override
  String get profileSetupUsernameHint => 'Потребителско име';

  @override
  String get profileSetupUsernameHelper =>
      'Твоята уникална самоличност в Divine';

  @override
  String get profileSetupProfileColorLabel => 'Цвят на профила (по избор)';

  @override
  String get profileSetupSaveButton => 'Запази';

  @override
  String get profileSetupSavingButton => 'Запазва се...';

  @override
  String get profileSetupImageUrlTitle => 'Добави URL адрес на изображението';

  @override
  String get profileSetupPictureUploaded =>
      'Профилната снимка е качена успешно!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Не успяхме да изберем изображение. Постави URL на изображение по-долу.';

  @override
  String get profileSetupImagesTypeGroup => 'images';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Неуспешен достъп до камерата: $error';
  }

  @override
  String get profileSetupGotItButton => 'Разбрах';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Качването на изображението се провали. Опитай отново след малко.';

  @override
  String get profileSetupUploadNetworkError =>
      'Мрежова грешка: провери интернет връзката си и опитай пак.';

  @override
  String get profileSetupUploadAuthError =>
      'Грешка при удостоверяване: излез и влез отново.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Файлът е твърде голям. Избери по-малко изображение (макс. 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Качването на изображението се провали. Сървърите ни временно не са достъпни. Опитай пак след малко.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Качването на профилна снимка все още не е налично в уеб. Използвай приложението за iOS или Android или постави URL на изображение.';

  @override
  String get profileSetupUsernameChecking => 'Проверява се наличността...';

  @override
  String get profileSetupUsernameAvailable => 'Потребителското име е свободно!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Потребителското име вече е заето';

  @override
  String get profileSetupUsernameReserved => 'Потребителското име е запазено';

  @override
  String get profileSetupContactSupport => 'Свържи се с поддръжката';

  @override
  String get profileSetupCheckAgain => 'Провери пак';

  @override
  String get profileSetupUsernameBurned =>
      'Това потребителско име вече не е достъпно';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Разрешени са само букви, цифри и тирета';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Потребителското име трябва да е 3-20 знака';

  @override
  String get profileSetupUsernameNetworkError =>
      'Не можем да проверим дали е свободно. Опитай пак.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Невалиден формат на потребителското име';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Неуспешна проверка за наличност';

  @override
  String get profileSetupUsernameReservedTitle =>
      'Потребителското име е запазено';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Името $username е запазено. Кажи ни защо трябва да е твое.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Напр. Това е името на моята марка, сценично име и т.н.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Вече си се свързал с поддръжката? Натисни „Провери пак“, за да видиш дали е освободено за теб.';

  @override
  String get profileSetupSupportRequestSent =>
      'Заявката за поддръжка е изпратена! Ще се свържем с вас скоро.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Не можем да отворим имейл. Изпрати до: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Изпрати заявка';

  @override
  String get profileSetupPickColorTitle => 'Избери цвят';

  @override
  String get profileSetupSelectButton => 'Избери';

  @override
  String get profileSetupUseOwnNip05 => 'Използвай свой NIP-05 адрес';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Адрес';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Invalid NIP-05 format (e.g., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Use the username field above for divine.video';

  @override
  String get profileSetupProfilePicturePreview =>
      'Визуализация на профилна снимка';

  @override
  String get nostrInfoIntroBuiltOn => 'Divine е изграден върху Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' отворен протокол, устойчив на цензура, който позволява на хората да общуват онлайн, без да зависят от една компания или платформа. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Когато се регистрираш в Divine, получаваш нова Nostr самоличност.';

  @override
  String get nostrInfoOwnership =>
      'Nostr ти позволява да притежаваш съдържанието, самоличността и социалната си мрежа, които можеш да използваш в много приложения. Повече избор, по-малко заключване, по-здрав социален интернет.';

  @override
  String get nostrInfoLingo => 'Nostr речник:';

  @override
  String get nostrInfoNpubLabel => 'Npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Твоят публичен Nostr адрес. Безопасно е да го споделяш и помага на други да те намират, следват или да ти пишат в Nostr приложения.';

  @override
  String get nostrInfoNsecLabel => 'Nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Твоят частен ключ и доказателство за собственост. Дава пълен контрол върху Nostr самоличността ти, така че ';

  @override
  String get nostrInfoNsecWarning => 'Пази го в тайна!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr потребителско име:';

  @override
  String get nostrInfoUsernameDescription =>
      'Човешко име (като @name.divine.video), което сочи към твоя npub. Така Nostr самоличността ти се разпознава и потвърждава по-лесно, почти като имейл адрес.';

  @override
  String get nostrInfoLearnMoreAt => 'Научи повече на';

  @override
  String get nostrInfoGotIt => 'Ясно!';

  @override
  String get profileTabRefreshTooltip => 'Опресняване';

  @override
  String get videoGridRefreshLabel => 'Търсим още видеа';

  @override
  String get videoGridOptionsTitle => 'Опции за видеото';

  @override
  String get videoGridEditVideo => 'Редактирай видеото';

  @override
  String get videoGridEditVideoSubtitle =>
      'Актуализирай заглавие, описание и хаштагове';

  @override
  String get videoGridDeleteVideo => 'Изтрий видеото';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Премахни това видео от Divine. Може още да се вижда в други Nostr клиенти.';

  @override
  String get videoGridDeleteConfirmTitle => 'Изтрий видеото';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Това ще изтрие за постоянно това видео от Divine. Може още да се вижда в Nostr клиенти на трети страни, които използват други релета.';

  @override
  String get videoGridDeleteConfirmNote =>
      'Това ще изпрати заявка за изтриване до релетата. Забележка: Някои релета все още може да имат кеширани копия.';

  @override
  String get videoGridDeleteCancel => 'Отказ';

  @override
  String get videoGridDeleteConfirm => 'Изтрий';

  @override
  String get videoGridDeletingContent => 'Трием съдържанието...';

  @override
  String get videoGridDeleteSuccess => 'Заявката за изтриване е изпратена';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Неуспешно изтриване на съдържание: $error';
  }

  @override
  String get exploreTabClassics => 'Класики';

  @override
  String get exploreTabNew => 'Нови';

  @override
  String get exploreTabPopular => 'Популярни';

  @override
  String get exploreTabCategories => 'Категории';

  @override
  String get exploreTabForYou => 'За теб';

  @override
  String get exploreTabLists => 'Списъци';

  @override
  String get exploreTabIntegratedApps => 'Интегрирани приложения';

  @override
  String get exploreNoVideosAvailable => 'Няма налични видеа';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Грешка: $error';
  }

  @override
  String get exploreDiscoverLists => 'Открий списъци';

  @override
  String get exploreAboutLists => 'Относно списъците';

  @override
  String get exploreAboutListsDescription =>
      'Списъците ти помагат да организираш и управляваш Divine съдържание по два начина:';

  @override
  String get explorePeopleLists => 'Списъци с хора';

  @override
  String get explorePeopleListsDescription =>
      'Следвай групи от творци и виж най-новите им видеа';

  @override
  String get exploreVideoLists => 'Видео списъци';

  @override
  String get exploreVideoListsDescription =>
      'Създай плейлисти с любимите си видеа, за да ги гледаш по-късно';

  @override
  String get exploreMyLists => 'Моите списъци';

  @override
  String get exploreSubscribedLists => 'Абонирани списъци';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Грешка при зареждане на списъците: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count нови видеа',
      one: '1 ново видео',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и видеа',
      one: 'о видео',
    );
    return 'Зареди $count нов$_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Видеото се зарежда...';

  @override
  String get videoPlayerPlayVideo => 'Възпроизвеждане на видео';

  @override
  String get videoPlayerMute => 'Заглушаване на видеото';

  @override
  String get videoPlayerUnmute => 'Включване на звука на видеото';

  @override
  String get videoPlayerEditVideo => 'Редактиране на видео';

  @override
  String get videoPlayerEditVideoTooltip => 'Редактиране на видео';

  @override
  String get contentWarningLabel => 'Предупреждение за съдържание';

  @override
  String get contentWarningNudity => 'Голота';

  @override
  String get contentWarningSexualContent => 'Сексуално съдържание';

  @override
  String get contentWarningPornography => 'Порнография';

  @override
  String get contentWarningGraphicMedia => 'Графични медии';

  @override
  String get contentWarningViolence => 'Насилие';

  @override
  String get contentWarningSelfHarm => 'Самонараняване';

  @override
  String get contentWarningDrugUse => 'Употреба на наркотици';

  @override
  String get contentWarningAlcohol => 'Алкохол';

  @override
  String get contentWarningTobacco => 'Тютюн';

  @override
  String get contentWarningGambling => 'Хазарт';

  @override
  String get contentWarningProfanity => 'Ругатни';

  @override
  String get contentWarningFlashingLights => 'Мигащи светлини';

  @override
  String get contentWarningAiGenerated => 'AI-генерирано';

  @override
  String get contentWarningSpoiler => 'Спойлер';

  @override
  String get contentWarningSensitiveContent => 'Чувствително съдържание';

  @override
  String get contentWarningDescNudity => 'Съдържа голота или частична голота';

  @override
  String get contentWarningDescSexual => 'Съдържа сексуално съдържание';

  @override
  String get contentWarningDescPorn =>
      'Съдържа изрично порнографско съдържание';

  @override
  String get contentWarningDescGraphicMedia =>
      'Съдържа графични или смущаващи изображения';

  @override
  String get contentWarningDescViolence => 'Съдържа съдържание с насилие';

  @override
  String get contentWarningDescSelfHarm =>
      'Съдържа препратки към самонараняване';

  @override
  String get contentWarningDescDrugs =>
      'Съдържа съдържание, свързано с наркотици';

  @override
  String get contentWarningDescAlcohol =>
      'Съдържа съдържание, свързано с алкохол';

  @override
  String get contentWarningDescTobacco =>
      'Съдържа съдържание, свързано с тютюна';

  @override
  String get contentWarningDescGambling =>
      'Съдържа съдържание, свързано с хазарта';

  @override
  String get contentWarningDescProfanity => 'Съдържа силен език';

  @override
  String get contentWarningDescFlashingLights =>
      'Съдържа мигащи светлини (предупреждение за фоточувствителност)';

  @override
  String get contentWarningDescAiGenerated => 'Това съдържание е AI-генерирано';

  @override
  String get contentWarningDescSpoiler => 'Съдържа спойлери';

  @override
  String get contentWarningDescContentWarning =>
      'Създателят означи това като чувствително';

  @override
  String get contentWarningDescDefault => 'Създателят маркира това съдържание';

  @override
  String get contentWarningDetailsTitle => 'Предупреждения за съдържание';

  @override
  String get contentWarningDetailsSubtitle =>
      'Създателят е приложил тези етикети:';

  @override
  String get contentWarningManageFilters =>
      'Управление на филтри за съдържание';

  @override
  String get contentWarningViewAnyway => 'Виж все пак';

  @override
  String get contentWarningReportContentTooltip => 'Report Content';

  @override
  String get contentWarningBlockUserTooltip => 'Block User';

  @override
  String get contentWarningBlockedTitle => 'Content Blocked';

  @override
  String get contentWarningBlockedPolicy =>
      'This content has been blocked due to policy violations.';

  @override
  String get contentWarningNoticeTitle => 'Content Notice';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potentially Harmful Content';

  @override
  String get contentWarningView => 'View';

  @override
  String get contentWarningReportAction => 'Report';

  @override
  String get contentWarningHideAllLikeThis => 'Скрий всичко подобно';

  @override
  String get contentWarningNoFilterYet =>
      'Още няма запазен филтър за това предупреждение.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Отсега нататък ще скриваме публикации като тази.';

  @override
  String get videoErrorNotFound => 'Видеото не е намерено';

  @override
  String get videoErrorNetwork => 'Мрежова грешка';

  @override
  String get videoErrorTimeout => 'Зареждането изтече';

  @override
  String get videoErrorFormat =>
      'Грешка във видео формата\n(Опитай пак или използвай друг браузър)';

  @override
  String get videoErrorUnsupportedFormat => 'Неподдържан видео формат';

  @override
  String get videoErrorPlayback => 'Грешка при възпроизвеждане';

  @override
  String get videoErrorAgeRestricted => 'Съдържание с възрастово ограничение';

  @override
  String get videoErrorVerifyAge => 'Потвърди възрастта';

  @override
  String get videoErrorRetry => 'Опитай пак';

  @override
  String get videoErrorContentRestricted => 'Ограничено съдържание';

  @override
  String get videoErrorContentRestrictedBody =>
      'Това видео беше ограничено от релето.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Потвърди възрастта си, за да гледаш това видео.';

  @override
  String get videoErrorSkip => 'Пропусни';

  @override
  String get videoErrorVerifyAgeButton => 'Потвърди възрастта';

  @override
  String get videoFollowButtonFollowing => 'Следване';

  @override
  String get videoFollowButtonFollow => 'Следвай';

  @override
  String get audioAttributionOriginalSound => 'Оригинален звук';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Вдъхновен от @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'С @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'С @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count сътрудници',
      one: '1 сътрудник',
    );
    return '$_temp0. Докосни, за да видиш профила.';
  }

  @override
  String get listAttributionFallback => 'Списък';

  @override
  String get shareVideoLabel => 'Сподели видео';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Публикация, споделена с $recipientName';
  }

  @override
  String get shareFailedToSend => 'Не успяхме да изпратим видеото';

  @override
  String get shareAddedToBookmarks => 'Добавен към отметките';

  @override
  String get shareRemovedFromBookmarks => 'Премахнато от отметките';

  @override
  String get shareFailedToAddBookmark => 'Не успяхме да добавим отметка';

  @override
  String get shareFailedToRemoveBookmark => 'Не успяхме да премахнем отметката';

  @override
  String get shareActionFailed => 'Действието не мина';

  @override
  String get shareWithTitle => 'Сподели с';

  @override
  String get shareFindPeople => 'Намери хора';

  @override
  String get shareFindPeopleMultiline => 'Намери\nхора';

  @override
  String get shareSent => 'Изпратено';

  @override
  String get shareContactFallback => 'Контакт';

  @override
  String get shareUserFallback => 'Потребител';

  @override
  String shareSendingTo(String name) {
    return 'Изпращане до $name';
  }

  @override
  String get shareMessageHint => 'Добави съобщение (по избор)...';

  @override
  String get videoActionUnlike => 'Премахни харесването';

  @override
  String get videoActionLike => 'Харесай видеото';

  @override
  String get videoActionAutoLabel => 'Компилация';

  @override
  String get videoActionLikeLabel => 'Харесай';

  @override
  String get videoActionReplyLabel => 'Отговор';

  @override
  String get videoActionRepostLabel => 'Сподели пак';

  @override
  String get videoActionShareLabel => 'Сподели';

  @override
  String get videoActionAboutLabel => 'Инфо';

  @override
  String get videoActionEnableAutoAdvance =>
      'Включи автоматичното продължаване';

  @override
  String get videoActionDisableAutoAdvance =>
      'Изключи автоматичното продължаване';

  @override
  String get videoActionRemoveRepost => 'Премахни репоста';

  @override
  String get videoActionRepost => 'Сподели видеото пак';

  @override
  String get videoActionViewComments => 'Виж коментарите';

  @override
  String get videoActionMoreOptions => 'Още опции';

  @override
  String get videoActionHideSubtitles => 'Скрий субтитрите';

  @override
  String get videoActionShowSubtitles => 'Покажи субтитрите';

  @override
  String get videoOverlayOpenMetadataFromTitle =>
      'Отвори подробностите за видеото';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Отвори подробностите за видеото';

  @override
  String videoDescriptionLoops(String count) {
    return '$count лупа';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'лупа',
      one: 'луп',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Не е от Divine';

  @override
  String get metadataBadgeHumanMade => 'Направено от човек';

  @override
  String get metadataSoundsLabel => 'Звуци';

  @override
  String get metadataOriginalSound => 'Оригинален звук';

  @override
  String get metadataVerificationLabel => 'Проверка';

  @override
  String get metadataDeviceAttestation => 'Атестация на устройството';

  @override
  String get metadataProofManifest => 'Доказателствен манифест';

  @override
  String get metadataCreatorLabel => 'Създател';

  @override
  String get metadataCollaboratorsLabel => 'Сътрудници';

  @override
  String get metadataInspiredByLabel => 'Вдъхновено от';

  @override
  String get metadataRepostedByLabel => 'Повторно публикувано от';

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Лупове',
      one: 'Луп',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Харесвания';

  @override
  String get metadataCommentsLabel => 'Коментари';

  @override
  String get metadataRepostsLabel => 'Репостове';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Публикувано на $date';
  }

  @override
  String get devOptionsTitle => 'Опции за разработчици';

  @override
  String get devOptionsPageLoadTimes => 'Време за зареждане на страницата';

  @override
  String get devOptionsNoPageLoads =>
      'Още няма регистрирани зареждания на страници.\nРазгледай приложението, за да видиш данните за времето.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Видим: ${visibleMs}ms |  Данни: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Най-бавните екрани';

  @override
  String get devOptionsVideoPlaybackFormat =>
      'Формат за възпроизвеждане на видео';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Превключване на среда?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Превключване към $envName?\n\nТова ще изчисти кешираните видео данни и ще се свърже отново с новото реле.';
  }

  @override
  String get devOptionsCancel => 'Отказ';

  @override
  String get devOptionsSwitch => 'Превключване';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Превключено към $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Превключено към $formatName — кешът е изчистен';
  }

  @override
  String get featureFlagTitle => 'Флагове за функции';

  @override
  String get featureFlagResetAllTooltip =>
      'Нулирай всички флагове до стойностите по подразбиране';

  @override
  String get featureFlagResetToDefault =>
      'Нулирай до стойността по подразбиране';

  @override
  String get featureFlagAppRecovery => 'Възстановяване на приложението';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Ако приложението се срива или се държи странно, опитай да изчистиш кеша.';

  @override
  String get featureFlagClearAllCache => 'Изчистване на целия кеш';

  @override
  String get featureFlagCacheInfo => 'Информация за кеша';

  @override
  String get featureFlagClearCacheTitle => 'Изчистване на целия кеш?';

  @override
  String get featureFlagClearCacheMessage =>
      'Това ще изчисти всички кеширани данни, включително:\n• Известия\n• Потребителски профили\n• Отметки\n• Временни файлове\n\nЩе трябва да влезеш отново. Да продължим?';

  @override
  String get featureFlagClearCache => 'Изчистване на кеша';

  @override
  String get featureFlagClearingCache => 'Изчистване на кеша...';

  @override
  String get featureFlagSuccess => 'Успех';

  @override
  String get featureFlagError => 'Грешка';

  @override
  String get featureFlagClearCacheSuccess =>
      'Кешът е изчистен. Рестартирай приложението.';

  @override
  String get featureFlagClearCacheFailure =>
      'Не успяхме да изчистим някои елементи от кеша. Виж логовете за подробности.';

  @override
  String get featureFlagOk => 'Добре';

  @override
  String get featureFlagCacheInformation => 'Кеш информация';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Общ размер на кеша: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Кешът включва:\n• История на известията\n• Данни от потребителския профил\n• Видео миниатюри\n• Временни файлове\n• Индекси на бази данни';

  @override
  String get relaySettingsTitle => 'Релета';

  @override
  String get relaySettingsInfoTitle =>
      'Divine е отворена система - ти контролираш връзките си';

  @override
  String get relaySettingsInfoDescription =>
      'Тези релета разпространяват съдържанието ти в децентрализираната Nostr мрежа. Можеш да добавяш или махаш релета когато поискаш.';

  @override
  String get relaySettingsLearnMoreNostr => 'Научи повече за Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Намери публични релета на nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Приложението не функционира';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine изисква поне едно реле, за да зарежда видеа, да публикува съдържание и да синхронизира данни.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Възстановяване на релето по подразбиране';

  @override
  String get relaySettingsAddCustomRelay => 'Добави персонализирано реле';

  @override
  String get relaySettingsAddRelay => 'Добави реле';

  @override
  String get relaySettingsRetry => 'Опитай пак';

  @override
  String get relaySettingsNoStats => 'Все още няма налична статистика';

  @override
  String get relaySettingsConnection => 'Връзка';

  @override
  String get relaySettingsConnected => 'Свързано';

  @override
  String get relaySettingsDisconnected => 'Прекъснато';

  @override
  String get relaySettingsSessionDuration => 'Продължителност на сесията';

  @override
  String get relaySettingsLastConnected => 'Последно свързано';

  @override
  String get relaySettingsDisconnectedLabel => 'Прекъсната връзка';

  @override
  String get relaySettingsReason => 'Причина';

  @override
  String get relaySettingsActiveSubscriptions => 'Активни абонаменти';

  @override
  String get relaySettingsTotalSubscriptions => 'Общ брой абонаменти';

  @override
  String get relaySettingsEventsReceived => 'Получени събития';

  @override
  String get relaySettingsEventsSent => 'Изпратени събития';

  @override
  String get relaySettingsRequestsThisSession => 'Иска тази сесия';

  @override
  String get relaySettingsFailedRequests => 'Неуспешни заявки';

  @override
  String relaySettingsLastError(String error) {
    return 'Последна грешка: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Информацията за релето се зарежда...';

  @override
  String get relaySettingsAboutRelay => 'Относно релето';

  @override
  String get relaySettingsSupportedNips => 'Поддържани NIP';

  @override
  String get relaySettingsSoftware => 'Софтуер';

  @override
  String get relaySettingsViewWebsite => 'Виж уебсайта';

  @override
  String get relaySettingsRemoveRelayTitle => 'Да махнем ли релето?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Сигурен ли си, че искаш да премахнеш това реле?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Отказ';

  @override
  String get relaySettingsRemove => 'Махни';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Премахнато реле: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Премахването на релето не бе успешно';

  @override
  String get relaySettingsForcingReconnection =>
      'Принудително повторно свързване с релето...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Свързани сме с $count реле(та)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Не успяхме да се свържем с релетата. Провери мрежовата си връзка.';

  @override
  String get relaySettingsAddRelayTitle => 'Добави реле';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Въведи WebSocket URL на релето, което искаш да добавиш:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Разгледай публичните релета на nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Добави';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Добавено реле: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Не успяхме да добавим релето. Провери URL адреса и опитай пак.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL адресът за предаване трябва да започва с wss:// или ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay URL must use wss:// (ws:// is allowed only for localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Възстановено реле по подразбиране: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Не успяхме да възстановим релето по подразбиране. Провери мрежовата си връзка.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Браузърът не може да се отвори';

  @override
  String get relaySettingsFailedToOpenLink => 'Неуспешно отваряне на връзката';

  @override
  String get relaySettingsExternalRelay => 'External relay';

  @override
  String get relaySettingsNotConnected => 'Not connected';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Disconnected $duration ago';
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
    return '$duration ago';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine uses the Nostr protocol for decentralized publishing. Your content lives on relays you choose, and your keys are your identity.';

  @override
  String get nostrSettingsSectionNetwork => 'Network';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Danger Zone';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Manage Nostr relay connections';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relay Diagnostics';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug relay connectivity and network issues';

  @override
  String get nostrSettingsMediaServers => 'Media Servers';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configure Blossom upload servers';

  @override
  String get nostrSettingsDeveloperOptions => 'Developer Options';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Environment switcher and debug settings';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Toggle feature flags that may hiccup.';

  @override
  String get nostrSettingsKeyManagement => 'Key Management';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Export, backup, and restore your Nostr keys';

  @override
  String get nostrSettingsRemoveKeys => 'Remove Keys from Device';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Delete your private key from this device only. Your content stays on relays, but you\'ll need your nsec backup to access your account again.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Could not remove keys from this device. Please try again.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Failed to remove keys: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Delete Account and Data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'PERMANENTLY delete your account and ALL content from Nostr relays. This cannot be undone.';

  @override
  String get relayDiagnosticTitle => 'Релейна диагностика';

  @override
  String get relayDiagnosticRefreshTooltip => 'Обновяване на диагностиката';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Последно опресняване: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Състояние на релето';

  @override
  String get relayDiagnosticInitialized => 'Инициализирано';

  @override
  String get relayDiagnosticReady => 'Готови';

  @override
  String get relayDiagnosticNotInitialized => 'Не е инициализирано';

  @override
  String get relayDiagnosticDatabaseEvents => 'Събития в базата данни';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Активни абонаменти';

  @override
  String get relayDiagnosticExternalRelays => 'Външни релета';

  @override
  String get relayDiagnosticConfigured => 'Конфигуриран';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count реле(а)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Свързан';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Видео събития';

  @override
  String get relayDiagnosticHomeFeed => 'Домашна емисия';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count видеа';
  }

  @override
  String get relayDiagnosticDiscovery => 'Откриване';

  @override
  String get relayDiagnosticLoading => 'Зарежда се';

  @override
  String get relayDiagnosticYes => 'Да';

  @override
  String get relayDiagnosticNo => 'Не';

  @override
  String get relayDiagnosticTestDirectQuery => 'Тествай директна заявка';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Мрежова свързаност';

  @override
  String get relayDiagnosticRunNetworkTest => 'Изпълни мрежов тест';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom сървър';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Тествай всички ендпойнти';

  @override
  String get relayDiagnosticStatus => 'Статус';

  @override
  String get relayDiagnosticUrl => 'URL адрес';

  @override
  String get relayDiagnosticError => 'Грешка';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API на FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'Основен URL адрес';

  @override
  String get relayDiagnosticSummary => 'Резюме';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (ср. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Повторно тестване на всички';

  @override
  String get relayDiagnosticRetrying => 'Повторен опит...';

  @override
  String get relayDiagnosticRetryConnection => 'Повторен опит за свързване';

  @override
  String get relayDiagnosticTroubleshooting => 'Отстраняване на неизправности';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Зелен статус = свързано и работи\n• Червен статус = връзката не мина\n• Ако мрежовият тест не минава, провери интернет връзката\n• Ако релетата са конфигурирани, но не са свързани, натисни „Повторен опит за свързване“\n• Направи екранна снимка на този екран за отстраняване на проблеми';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Всички REST ендпойнти работят!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Някои REST ендпойнти не минаха - виж подробностите по-горе';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Намерени $count видео събития в базата данни';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Неуспешна заявка: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Свързани сме с $count реле(та)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Не успяхме да се свържем с нито едно реле';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Неуспешен повторен опит за свързване: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Свързан и удостоверен';

  @override
  String get relayDiagnosticConnectedOnly => 'Свързан';

  @override
  String get relayDiagnosticNotConnected => 'Не е свързан';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Няма конфигурирани релета';

  @override
  String get relayDiagnosticFailed => 'Неуспешно';

  @override
  String get notificationSettingsTitle => 'Известия';

  @override
  String get notificationSettingsResetTooltip =>
      'Възстановяване на настройките по подразбиране';

  @override
  String get notificationSettingsTypes => 'Видове известия';

  @override
  String get notificationSettingsLikes => 'Харесвания';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Когато някой хареса видеата ти';

  @override
  String get notificationSettingsComments => 'Коментари';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Когато някой коментира видеата ти';

  @override
  String get notificationSettingsFollows => 'Следва';

  @override
  String get notificationSettingsFollowsSubtitle => 'Когато някой те следва';

  @override
  String get notificationSettingsMentions => 'Споменавания';

  @override
  String get notificationSettingsMentionsSubtitle => 'Когато те споменат';

  @override
  String get notificationSettingsReposts => 'Репостове';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Когато някой препубликува видеата ти';

  @override
  String get notificationSettingsSystem => 'Система';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Актуализации на приложения и системни съобщения';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Насочени известия';

  @override
  String get notificationSettingsPushNotifications => 'Насочени известия';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Получавай известия, когато приложението е затворено';

  @override
  String get notificationSettingsSound => 'Звук';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Възпроизвеждане на звук за известия';

  @override
  String get notificationSettingsVibration => 'Вибрация';

  @override
  String get notificationSettingsVibrationSubtitle => 'Вибриране за известия';

  @override
  String get notificationSettingsActions => 'Действия';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Маркирай всички като прочетени';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Маркирай всички известия като прочетени';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Всички известия са маркирани като прочетени';

  @override
  String get notificationSettingsResetToDefaults =>
      'Настройките се нулират до стойностите по подразбиране';

  @override
  String get notificationSettingsAbout => 'Относно известията';

  @override
  String get notificationSettingsAboutDescription =>
      'Известията се захранват от Nostr. Обновяването в реално време зависи от връзката ти с Nostr релета. Някои известия може да закъсняват.';

  @override
  String get safetySettingsTitle => 'Безопасност и поверителност';

  @override
  String get safetySettingsLabel => 'НАСТРОЙКИ';

  @override
  String get safetySettingsWhatYouSee => 'WHAT YOU SEE';

  @override
  String get safetySettingsWhatYouPublish => 'WHAT YOU PUBLISH';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Показвай само видеа, хостнати от Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Скривай видеа, обслужвани от други медийни хостове';

  @override
  String get safetySettingsModeration => 'УМЕРЕНОСТ';

  @override
  String get safetySettingsBlockedUsers => 'БЛОКИРАНИ ПОТРЕБИТЕЛИ';

  @override
  String get safetySettingsAgeVerification => 'ПРОВЕРКА НА ВЪЗРАСТТА';

  @override
  String get safetySettingsAgeConfirmation =>
      'Потвърждавам, че съм навършил 18 години';

  @override
  String get safetySettingsAgeRequired =>
      'Изисква се за гледане на съдържание за възрастни';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Официална услуга за модериране (включена по подразбиране)';

  @override
  String get safetySettingsPeopleIFollow => 'Хора, които следвам';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Абонирай се за етикети от хората, които следваш';

  @override
  String get safetySettingsAddCustomLabeler => 'Добави персонализиран етикет';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Въведи npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Добави персонализиран етикет';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Въведи npub адрес';

  @override
  String get safetySettingsNoBlockedUsers => 'Няма блокирани потребители';

  @override
  String get safetySettingsUnblock => 'Разблокирай';

  @override
  String get safetySettingsUserUnblocked => 'Потребителят е деблокиран';

  @override
  String get safetySettingsCancel => 'Отказ';

  @override
  String get safetySettingsAdd => 'Добави';

  @override
  String get analyticsTitle => 'Анализ на създателите';

  @override
  String get analyticsDiagnosticsTooltip => 'Диагностика';

  @override
  String get analyticsDiagnosticsSemanticLabel =>
      'Превключване на диагностиката';

  @override
  String get analyticsRetry => 'Опитай пак';

  @override
  String get analyticsUnableToLoad => 'Анализът не може да се зареди.';

  @override
  String get analyticsSignInRequired =>
      'Влез, за да видиш анализите за създатели.';

  @override
  String get analyticsViewDataUnavailable =>
      'Данните за гледанията в момента не са достъпни от релето за тези публикации. Показателите за харесвания, коментари и репостове все още са точни.';

  @override
  String get analyticsViewDataTitle => 'Преглед на данни';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Обновено $time • Резултатите използват харесвания, коментари, репостове и гледания/лупове от Funnelcake, когато са налични.';
  }

  @override
  String get analyticsVideos => 'Видеа';

  @override
  String get analyticsViews => 'Гледания';

  @override
  String get analyticsInteractions => 'Взаимодействия';

  @override
  String get analyticsEngagement => 'Годеж';

  @override
  String get analyticsFollowers => 'Последователи';

  @override
  String get analyticsAvgPerPost => 'Ср./Публикация';

  @override
  String get analyticsInteractionMix => 'Смес за взаимодействие';

  @override
  String get analyticsLikes => 'Харесвания';

  @override
  String get analyticsComments => 'Коментари';

  @override
  String get analyticsReposts => 'Репостове';

  @override
  String get analyticsPerformanceHighlights => 'Акценти в изпълнението';

  @override
  String get analyticsMostViewed => 'Най-гледан';

  @override
  String get analyticsMostDiscussed => 'Най-обсъждани';

  @override
  String get analyticsMostReposted => 'Най-често публикувано';

  @override
  String get analyticsNoVideosYet => 'Още няма видеа';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Данните за гледанията са недостъпни';

  @override
  String analyticsViewsCount(String count) {
    return '$count показвания';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count коментара';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count репоста';
  }

  @override
  String get analyticsTopContent => 'Топ съдържание';

  @override
  String get analyticsPublishPrompt =>
      'Публикувай няколко видеа, за да видиш класациите.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% от дясната страна = процент на ангажираност (взаимодействия, разделени на показвания).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Процентът на ангажираност изисква данни за гледанията; стойностите се показват като N/A, докато липсват гледания.';

  @override
  String get analyticsEngagementLabel => 'Годеж';

  @override
  String get analyticsViewsUnavailable => 'Гледанията не са налични';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count взаимодействия';
  }

  @override
  String get analyticsPostAnalytics => 'Анализи на публикацията';

  @override
  String get analyticsOpenPost => 'Отвори публикацията';

  @override
  String get analyticsRecentDailyInteractions =>
      'Скорошни ежедневни взаимодействия';

  @override
  String get analyticsNoActivityYet =>
      'Все още няма активност в този диапазон.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Взаимодействия = харесвания + коментари + репостове по дата на публикуване.';

  @override
  String get analyticsDailyBarExplainer =>
      'Дължината на лентата е спрямо най-силния ти ден в този прозорец.';

  @override
  String get analyticsAudienceSnapshot => 'Моментна снимка на аудиторията';

  @override
  String analyticsFollowersCount(String count) {
    return 'Последователи: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Следвам: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Разбивките по източник на аудитория, гео и време ще се попълнят, когато Funnelcake добави ендпойнти за анализ на аудиторията.';

  @override
  String get analyticsRetention => 'Задържане';

  @override
  String get analyticsRetentionWithViews =>
      'Кривата на задържане и разбивката на времето за гледане ще се появят, след като задържането на секунда/на кофа пристигне от Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Данните за задържане не са налични, докато анализите за гледане+време за гледане не бъдат върнати от Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Диагностика';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Общо видеа: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'С гледания: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Липсващи гледания: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Попълнени (пакетно): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Хидратирани (/гледания): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Източници: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Използвай примерни данни';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Създай нов Divine акаунт';

  @override
  String get authSignInDifferentAccount => 'Влез с друг акаунт';

  @override
  String get authSignBackIn => 'Влез отново';

  @override
  String get authTermsPrefix =>
      'Като избереш опция по-горе, потвърждаваш, че си на 16 или повече и се съгласяваш с';

  @override
  String get authTermsOfService => 'Условия за ползване';

  @override
  String get authPrivacyPolicy => 'Политика за поверителност';

  @override
  String get authTermsAnd => ', и';

  @override
  String get authSafetyStandards => 'Стандарти за безопасност';

  @override
  String get authAmberNotInstalled => 'Приложението Amber не е инсталирано';

  @override
  String get authAmberConnectionFailed => 'Неуспешно свързване с Амбър';

  @override
  String get authPasswordResetSent =>
      'Ако има акаунт с този имейл, изпратихме линк за нулиране на паролата.';

  @override
  String get authSignInTitle => 'Влез';

  @override
  String get authEmailLabel => 'Имейл';

  @override
  String get authPasswordLabel => 'Парола';

  @override
  String get authConfirmPasswordLabel => 'Потвърди паролата';

  @override
  String get authEmailRequired => 'Имейлът е задължителен';

  @override
  String get authEmailInvalid => 'Моля, въведи валиден имейл';

  @override
  String get authPasswordRequired => 'Паролата е задължителна';

  @override
  String get authConfirmPasswordRequired => 'Моля, потвърди паролата си';

  @override
  String get authPasswordsDoNotMatch => 'Паролите не съвпадат';

  @override
  String get authForgotPassword => 'Забравена парола?';

  @override
  String get authImportNostrKey => 'Импортиране на ключ Nostr';

  @override
  String get authConnectSignerApp => 'Свържи приложение за подписване';

  @override
  String get authSignInWithAmber => 'Влез с Amber';

  @override
  String get authSignInOptionsTitle => 'Опции за влизане';

  @override
  String get authInfoEmailPasswordTitle => 'Имейл и парола';

  @override
  String get authInfoEmailPasswordDescription =>
      'Влез с Divine акаунта си. Ако си се регистрирал с имейл и парола, използвай ги тук.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Вече имаш Nostr самоличност? Импортирай частния си nsec ключ от друг клиент.';

  @override
  String get authInfoSignerAppTitle => 'Подписващо приложение';

  @override
  String get authInfoSignerAppDescription =>
      'Свържи NIP-46 съвместим отдалечен подписващ агент като nsecBunker за по-добра сигурност на ключовете.';

  @override
  String get authInfoAmberTitle => 'Амбър';

  @override
  String get authInfoAmberDescription =>
      'Използвай Amber Signer на Android, за да управляваш Nostr ключовете си сигурно.';

  @override
  String get authCreateAccountTitle => 'Създаване на акаунт';

  @override
  String get authBackToInviteCode => 'Назад към кода на поканата';

  @override
  String get authUseDivineNoBackup => 'Използвай Divine без резервно копие';

  @override
  String get authSkipConfirmTitle => 'Едно последно нещо...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Готово, вътре си! Ще създадем сигурен ключ за Divine акаунта ти.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Без имейл ключът ти е единственият начин Divine да разбере, че акаунтът е твой.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Можеш да намериш ключа си в приложението, но ако Nostr ключовете не са ти ежедневие, добави имейл и парола сега. Така по-лесно ще влизаш и ще си върнеш акаунта, ако изгубиш или нулираш това устройство.';

  @override
  String get authAddEmailPassword => 'Добави имейл и парола';

  @override
  String get authUseThisDeviceOnly => 'Използвай само това устройство';

  @override
  String get authCompleteRegistration => 'Завърши регистрацията си';

  @override
  String get authVerifying => 'Проверка...';

  @override
  String get authVerificationLinkSent =>
      'Изпратихме връзка за потвърждение на:';

  @override
  String get authClickVerificationLink =>
      'Натисни линка в имейла си, за да завършиш регистрацията.';

  @override
  String get authPleaseWaitVerifying =>
      'Изчакай, докато потвърдим имейла ти...';

  @override
  String get authWaitingForVerification => 'Чака се проверка';

  @override
  String get authOpenEmailApp => 'Отвори имейл приложението';

  @override
  String get authWelcomeToDivine => 'Радваме се, че си в Divine!';

  @override
  String get authEmailVerified => 'Имейлът ти е потвърден.';

  @override
  String get authSigningYouIn => 'Вписваме те';

  @override
  String get authErrorTitle => 'Опа.';

  @override
  String get authVerificationFailed =>
      'Не успяхме да потвърдим имейла ти.\nОпитай пак.';

  @override
  String get authStartOver => 'Започни отначало';

  @override
  String get authEmailVerifiedLogin =>
      'Имейлът е потвърден! Влез, за да продължиш.';

  @override
  String get authVerificationLinkExpired =>
      'Тази връзка за потвърждение вече не е валидна.';

  @override
  String get authVerificationConnectionError =>
      'Не можем да потвърдим имейла. Провери връзката си и опитай пак.';

  @override
  String get authWaitlistConfirmTitle => 'Вътре си!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Ще пращаме новини на $email.\nКогато има още кодове за покани, ще ти ги изпратим.';
  }

  @override
  String get authOk => 'Добре';

  @override
  String get authInviteUnavailable =>
      'Достъпът с покана временно не е наличен.';

  @override
  String get authInviteUnavailableBody =>
      'Опитай пак след малко или се свържи с поддръжката, ако имаш нужда от помощ при влизането.';

  @override
  String get authTryAgain => 'Опитай пак';

  @override
  String get authContactSupport => 'Свържи се с поддръжката';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Не може да се отвори $email';
  }

  @override
  String get authAddInviteCode => 'Добави своя код за покана';

  @override
  String get authInviteCodeLabel => 'Код за покана';

  @override
  String get authEnterYourCode => 'Въведи своя код';

  @override
  String get authNext => 'Следваща';

  @override
  String get authJoinWaitlist => 'Присъедини се към списъка с чакащи';

  @override
  String get authJoinWaitlistTitle => 'Присъедини се към списъка с чакащи';

  @override
  String get authJoinWaitlistDescription =>
      'Остави имейла си и ще ти пишем, когато достъпът се отвори.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Помощ с поканите';

  @override
  String get authGeneratingConnection => 'Генериране на връзка...';

  @override
  String get authConnectedAuthenticating => 'Свързан! Удостоверява се...';

  @override
  String get authConnectionTimedOut =>
      'Времето за изчакване на връзката изтече';

  @override
  String get authApproveConnection =>
      'Увери се, че връзката е одобрена в приложението ти за подписване.';

  @override
  String get authConnectionCancelled => 'Връзката е отменена';

  @override
  String get authConnectionCancelledMessage => 'Връзката беше прекратена.';

  @override
  String get authConnectionFailed => 'Връзката е неуспешна';

  @override
  String get authUnknownError => 'Възникна неизвестна грешка.';

  @override
  String get authUrlCopied => 'URL адресът е копиран в клипборда';

  @override
  String get authConnectToDivine => 'Свържи се с Divine';

  @override
  String get authPasteBunkerUrl => 'Постави bunker:// URL';

  @override
  String get authBunkerUrlHint => 'Bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Невалиден Bunker URL. Трябва да започва с bunker://';

  @override
  String get authScanSignerApp =>
      'Сканирай с приложението си за подписване, за да се свържеш.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Изчаква се връзка... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Копирай URL';

  @override
  String get authShare => 'Сподели';

  @override
  String get authAddBunker => 'Добави Bunker';

  @override
  String get authCompatibleSignerApps => 'Съвместими приложения за подписване';

  @override
  String get authFailedToConnect => 'Неуспешно свързване';

  @override
  String get authResetPasswordTitle => 'Нулиране на парола';

  @override
  String get authResetPasswordSubtitle =>
      'Въведи новата си парола. Трябва да е поне 8 знака.';

  @override
  String get authNewPasswordLabel => 'Нова парола';

  @override
  String get authConfirmNewPasswordLabel => 'Потвърди новата парола';

  @override
  String get authPasswordTooShort => 'Паролата трябва да е поне 8 знака';

  @override
  String get authPasswordResetSuccess => 'Паролата е сменена. Влез отново.';

  @override
  String get authPasswordResetFailed => 'Неуспешно нулиране на паролата';

  @override
  String get authUnexpectedError => 'Стана неочаквана грешка. Опитай пак.';

  @override
  String get authUpdatePassword => 'Актуализиране на паролата';

  @override
  String get authSecureAccountTitle => 'Защитен акаунт';

  @override
  String get authUnableToAccessKeys =>
      'Няма достъп до ключовете ти. Опитай пак.';

  @override
  String get authRegistrationFailed => 'Регистрацията не мина';

  @override
  String get authRegistrationComplete =>
      'Регистрацията е готова. Провери имейла си.';

  @override
  String get authVerificationFailedTitle => 'Потвърждението не мина';

  @override
  String get authClose => 'Затвори';

  @override
  String get authAccountSecured => 'Акаунтът е защитен!';

  @override
  String get authAccountLinkedToEmail =>
      'Акаунтът ти вече е свързан с имейла ти.';

  @override
  String get authVerifyYourEmail => 'Потвърди имейла си';

  @override
  String get authClickLinkContinue =>
      'Отвори линка в имейла си, за да завършиш регистрацията. Междувременно можеш да продължиш да използваш приложението.';

  @override
  String get authWaitingForVerificationEllipsis => 'Чакаме потвърждение...';

  @override
  String get authContinueToApp => 'Продължи към приложението';

  @override
  String get authResetPassword => 'Нулирай паролата';

  @override
  String get authResetPasswordDescription =>
      'Въведи имейл адреса си и ще ти изпратим линк за възстановяване на паролата.';

  @override
  String get authFailedToSendResetEmail =>
      'Не успяхме да изпратим имейл за нулиране.';

  @override
  String get authUnexpectedErrorShort => 'Стана неочаквана грешка.';

  @override
  String get authSending => 'Изпращаме...';

  @override
  String get authSendResetLink => 'Изпрати линк за нулиране';

  @override
  String get authEmailSent => 'Имейлът е изпратен!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Изпратихме линк за нулиране на паролата до $email. Натисни линка в имейла, за да обновиш паролата си.';
  }

  @override
  String get authSignInButton => 'Вход';

  @override
  String get authVerificationErrorTimeout =>
      'Потвърждението изтече. Опитай да се регистрираш отново.';

  @override
  String get authVerificationErrorMissingCode =>
      'Потвърждението не мина - липсва код за оторизация.';

  @override
  String get authVerificationErrorPollFailed =>
      'Потвърждението не мина. Опитай пак.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Мрежова грешка при влизане. Опитай пак.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Потвърждението не мина. Опитай да се регистрираш отново.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Входът не мина. Опитай да влезеш ръчно.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Този код за покана вече не е наличен. Върни се към кода за покана, присъедини се към списъка с чакащи или се свържи с поддръжката.';

  @override
  String get authInviteErrorInvalid =>
      'Този код за покана не може да се използва в момента. Върни се към кода за покана, присъедини се към списъка с чакащи или се свържи с поддръжката.';

  @override
  String get authInviteErrorTemporary =>
      'Не можахме да потвърдим поканата ти в момента. Върни се към кода за покана и опитай пак или се свържи с поддръжката.';

  @override
  String get authInviteErrorUnknown =>
      'Не успяхме да активираме поканата ти. Върни се към кода за покана, присъедини се към списъка с чакащи или се свържи с поддръжката.';

  @override
  String get shareSheetSave => 'Запази';

  @override
  String get shareSheetSaveToGallery => 'Запази в галерията';

  @override
  String get shareSheetSaveWithWatermark => 'Запази с воден знак';

  @override
  String get shareSheetSaveVideo => 'Запази видео';

  @override
  String get shareSheetAddToClips => 'Добави към клипове';

  @override
  String get shareSheetAddedToClips => 'Добавен към клипове';

  @override
  String get shareSheetAddToClipsFailed => 'Не можа да се добави към клипове';

  @override
  String get shareSheetAddToList => 'Добави към списъка';

  @override
  String get shareSheetCopy => 'Копие';

  @override
  String get shareSheetShareVia => 'Сподели чрез';

  @override
  String get shareSheetReport => 'Докладвай';

  @override
  String get shareSheetEventJson => 'Събитие JSON';

  @override
  String get shareSheetEventId => 'ID на събитието';

  @override
  String get shareSheetMoreActions => 'Още действия';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Запазено в галерията';

  @override
  String get watermarkDownloadShare => 'Сподели';

  @override
  String get watermarkDownloadDone => 'Готово';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Необходим е достъп до снимки';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'За да запазваш видеа, дай достъп до снимките в настройките.';

  @override
  String get watermarkDownloadOpenSettings => 'Отвори Настройки';

  @override
  String get watermarkDownloadNotNow => 'Не сега';

  @override
  String get watermarkDownloadFailed => 'Неуспешно изтегляне';

  @override
  String get watermarkDownloadDismiss => 'Отхвърляне';

  @override
  String get watermarkDownloadStageDownloading => 'Изтегляне на видео';

  @override
  String get watermarkDownloadStageWatermarking => 'Добавяне на воден знак';

  @override
  String get watermarkDownloadStageSaving => 'Запазване в галерията';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Видеото се извлича от мрежата...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Добавя се воден знак Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Видеото с воден знак се запазва в галерията...';

  @override
  String get uploadProgressVideoUpload => 'Качване на видео';

  @override
  String get uploadProgressPause => 'Пауза';

  @override
  String get uploadProgressResume => 'Продължи';

  @override
  String get uploadProgressGoBack => 'Назад';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Опитай пак ($count остават)';
  }

  @override
  String get uploadProgressDelete => 'Изтрий';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'Преди $count дни';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'Преди $countч';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'Преди $count мин';
  }

  @override
  String get uploadProgressJustNow => 'Току-що';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Качва се $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'На пауза $percent%';
  }

  @override
  String get badgeExplanationClose => 'Затвори';

  @override
  String get badgeExplanationOriginalVineArchive => 'Оригинален архив на Vine';

  @override
  String get badgeExplanationCameraProof => 'Доказателство от камерата';

  @override
  String get badgeExplanationAuthenticitySignals => 'Сигнали за автентичност';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Това видео е оригинален Vine, възстановен от Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Преди Vine да затвори през 2017 г., ArchiveTeam и Internet Archive работиха, за да запазят милиони Vines за поколенията. Това съдържание е част от тези усилия за запазване на историята.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Оригинални статистики: $loops лупа';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Научи повече за запазването на Vine архива';

  @override
  String get badgeExplanationLearnProofmode =>
      'Научи повече за проверката в Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Научи повече за Divine сигналите за автентичност';

  @override
  String get badgeExplanationInspectProofCheck => 'Провери с ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Провери подробностите за медията';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Автентичността на това видео е потвърдена с технологията Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Това видео е хостнато в Divine. AI проверката показва, че вероятно е направено от човек, но няма криптографски данни от камерата.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI проверката показва, че това видео вероятно е направено от човек, но няма криптографски данни от камерата.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Това видео е хостнато в Divine, но още няма криптографски данни от камерата.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Това видео е хостнато извън Divine и няма криптографски данни от камерата.';

  @override
  String get badgeExplanationDeviceAttestation => 'Атестация на устройството';

  @override
  String get badgeExplanationPgpSignature => 'PGP подпис';

  @override
  String get badgeExplanationC2paCredentials =>
      'C2PA Идентификационни данни за съдържание';

  @override
  String get badgeExplanationProofManifest => 'Доказателствен манифест';

  @override
  String get badgeExplanationAiDetection => 'AI проверка';

  @override
  String get badgeExplanationAiNotScanned => 'AI проверка: още не е сканирано';

  @override
  String get badgeExplanationNoScanResults =>
      'Още няма резултати от сканиране.';

  @override
  String get badgeExplanationCheckAiGenerated =>
      'Провери дали е генерирано от AI';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% вероятност да е генерирано от AI';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Сканирано от: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Проверено от човешки модератор';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platinum: Хардуерна атестация на устройството, криптографски подписи, идентификационни данни за съдържание (C2PA) и AI сканиране потвърждават човешкия произход.';

  @override
  String get badgeExplanationVerificationGold =>
      'Злато: Заснето на реално устройство с хардуерна атестация, криптографски подписи и идентификационни данни за съдържание (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Сребро: криптографските подписи доказват, че това видео не е било променяно след записа.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Бронз: Налице са подписи на основни метаданни.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Сребро: AI проверката потвърждава, че видеото вероятно е направено от човек.';

  @override
  String get badgeExplanationNoVerification =>
      'Няма данни за верификация за това видео.';

  @override
  String get shareMenuTitle => 'Сподели видео';

  @override
  String get shareMenuReportAiContent => 'Докладвай AI боклук';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Сигнал за съмнително AI-генерирано съдържание';

  @override
  String get shareMenuReportingAiContent => 'Докладваме AI съдържанието...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Не успяхме да докладваме съдържанието: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Не успяхме да докладваме AI съдържанието: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Състояние на видеото';

  @override
  String get shareMenuViewAllLists => 'Виж всички списъци →';

  @override
  String get shareMenuShareWith => 'Сподели с';

  @override
  String get shareMenuShareViaOtherApps => 'Сподели чрез други приложения';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Сподели чрез други приложения или копирай връзката';

  @override
  String get shareMenuSaveToGallery => 'Запази в галерията';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Запази оригиналното видео в галерията';

  @override
  String get shareMenuSaveWithWatermark => 'Запази с воден знак';

  @override
  String get shareMenuSaveVideo => 'Запази видео';

  @override
  String get shareMenuDownloadWithWatermark => 'Изтегли с воден знак Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Запази видеото в галерията';

  @override
  String get shareMenuLists => 'Списъци';

  @override
  String get shareMenuAddToList => 'Добави към списъка';

  @override
  String get shareMenuAddToListSubtitle => 'Добави към подбраните си списъци';

  @override
  String get shareMenuCreateNewList => 'Създаване на нов списък';

  @override
  String get shareMenuCreateNewListSubtitle => 'Започни нова подбрана колекция';

  @override
  String get shareMenuRemovedFromList => 'Премахнато от списъка';

  @override
  String get shareMenuFailedToRemoveFromList =>
      'Неуспешно премахване от списъка';

  @override
  String get shareMenuBookmarks => 'Отметки';

  @override
  String get shareMenuAddToBookmarks => 'Добави към отметки';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Запази за по-късен преглед';

  @override
  String get shareMenuAddToBookmarkSet => 'Добави към набора с отметки';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Организирай в колекции';

  @override
  String get shareMenuFollowSets => 'Списъци с хора';

  @override
  String get shareMenuCreateFollowSet => 'Създай списък за следване';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Започни нова колекция с този творец';

  @override
  String get shareMenuAddToFollowSet => 'Добави към набора за следване';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count налични списъка за следване';
  }

  @override
  String get peopleListsAddToList => 'Добави към списъка';

  @override
  String get peopleListsAddToListSubtitle =>
      'Постави този творец в един от списъците си';

  @override
  String get peopleListsSheetTitle => 'Добави към списък';

  @override
  String get peopleListsEmptyTitle => 'Още няма списъци';

  @override
  String get peopleListsEmptySubtitle =>
      'Създай списък, за да започнеш да групираш хора.';

  @override
  String get peopleListsCreateList => 'Създаване на списък';

  @override
  String get peopleListsNewListTitle => 'Нов списък';

  @override
  String get peopleListsRouteTitle => 'Списък с хора';

  @override
  String get peopleListsListNameLabel => 'Име на списък';

  @override
  String get peopleListsListNameHint => 'Близки приятели';

  @override
  String get peopleListsCreateButton => 'Създай';

  @override
  String get peopleListsAddPeopleTitle => 'Добави хора';

  @override
  String get peopleListsAddPeopleTooltip => 'Добави хора';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Добави хора към списъка';

  @override
  String get peopleListsListNotFoundTitle => 'Списъкът не е намерен';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Списъкът не е намерен. Може да е изтрит.';

  @override
  String get peopleListsListDeletedSubtitle => 'Този списък може да е изтрит.';

  @override
  String get peopleListsNoPeopleTitle => 'Няма хора в този списък';

  @override
  String get peopleListsNoPeopleSubtitle => 'Добави някого, за да започнеш';

  @override
  String get peopleListsNoVideosTitle => 'Още няма видеа';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Видеата от хората в списъка ще се появят тук';

  @override
  String get peopleListsNoVideosAvailable => 'Няма налични видеа';

  @override
  String get peopleListsFailedToLoadVideos => 'Не успяхме да заредим видеата';

  @override
  String get peopleListsVideoNotAvailable => 'Видеото не е налично';

  @override
  String get peopleListsBackToGridTooltip => 'Обратно към мрежата';

  @override
  String get peopleListsErrorLoadingVideos => 'Грешка при зареждане на видеа';

  @override
  String get peopleListsNoPeopleToAdd => 'Няма налични хора за добавяне.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Добави към $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Търси хора';

  @override
  String get peopleListsAddPeopleError =>
      'Не успяхме да заредим хората. Опитай пак.';

  @override
  String get peopleListsAddPeopleRetry => 'Опитай пак';

  @override
  String get peopleListsAddButton => 'Добави';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Добави $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'В $count списъка',
      one: 'В 1 списък',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Да премахнем $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Те ще бъдат премахнати от този списък.';

  @override
  String get peopleListsRemove => 'Премахни';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Премахнато $name от списъка';
  }

  @override
  String get peopleListsUndo => 'Отмяна';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Профил на $name. Натисни дълго, за да премахнеш.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Виж профила на $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Добавено към отметките!';

  @override
  String get shareMenuFailedToAddBookmark => 'Неуспешно добавяне на отметка';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Създаден е списък „$name“ и е добавено видео';
  }

  @override
  String get shareMenuManageContent => 'Управление на съдържанието';

  @override
  String get shareMenuEditVideo => 'Редактиране на видео';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Актуализирай заглавие, описание и хаштагове';

  @override
  String get shareMenuDeleteVideo => 'Изтрий видеото';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Премахни това видео от Divine. Може още да се вижда в други Nostr клиенти.';

  @override
  String get shareMenuDeleteWarning =>
      'Това изпраща заявка за изтриване (NIP-09) до всички релета. Някои релета все още могат да запазят съдържанието.';

  @override
  String get shareMenuVideoInTheseLists => 'Видеото е в тези списъци:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count видеа';
  }

  @override
  String get shareMenuClose => 'Затвори';

  @override
  String get shareMenuDeleteConfirmation =>
      'Това ще изтрие за постоянно това видео от Divine. Може още да се вижда в Nostr клиенти на трети страни, които използват други релета.';

  @override
  String get shareMenuCancel => 'Отказ';

  @override
  String get shareMenuDelete => 'Изтрий';

  @override
  String get shareMenuDeletingContent => 'Изтриване на съдържание...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Неуспешно изтриване на съдържание: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'Видеото е изтрито';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Изтриването още не е готово. Опитай пак след малко.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Можеш да триеш само собствените си видеа.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Влез отново, после пробвай да изтриеш.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Не успяхме да подпишем заявката за изтриване. Опитай пак.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Не можем да достигнем релето. Провери връзката си и опитай пак.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Не успяхме да изтрием това видео. Опитай пак.';

  @override
  String get shareMenuFollowSetName => 'Име на списъка за следване';

  @override
  String get shareMenuFollowSetNameHint =>
      'Например създатели на съдържание, музиканти и др.';

  @override
  String get shareMenuDescriptionOptional => 'Описание (по избор)';

  @override
  String get shareMenuCreate => 'Създай';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Създаден е списъкът за следване „$name“ и творецът е добавен';
  }

  @override
  String get shareMenuDone => 'Готово';

  @override
  String get shareMenuEditTitle => 'Заглавие';

  @override
  String get shareMenuEditTitleHint => 'Въведи заглавие на видеото';

  @override
  String get shareMenuEditDescription => 'Описание';

  @override
  String get shareMenuEditDescriptionHint => 'Въведи описание на видеото';

  @override
  String get shareMenuEditHashtags => 'Хаштагове';

  @override
  String get shareMenuEditHashtagsHint => 'Запетая, разделени, хаштагове';

  @override
  String get shareMenuEditMetadataNote =>
      'Забележка: Могат да се редактират само метаданни. Видеосъдържанието не може да се променя.';

  @override
  String get shareMenuDeleting => 'Изтриване...';

  @override
  String get shareMenuUpdate => 'Актуализация';

  @override
  String get shareMenuVideoUpdated => 'Видеото е обновено';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Не успяхме да обновим видеото: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Не успяхме да изтрием видеото: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Да изтрием видеото?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Това ще изпрати заявка за изтриване до релетата. Забележка: Някои релета все още може да имат кеширани копия.';

  @override
  String get shareMenuVideoDeletionRequested => 'Видеото е изтрито';

  @override
  String get shareMenuContentLabels => 'Етикети за съдържание';

  @override
  String get shareMenuAddContentLabels => 'Добави етикети за съдържание';

  @override
  String get shareMenuClearAll => 'Изчисти всички';

  @override
  String get shareMenuCollaborators => 'Сътрудници';

  @override
  String get shareMenuAddCollaborator => 'Покани сътрудник';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Трябва с $name да се следвате взаимно, за да поканиш този човек като сътрудник.';
  }

  @override
  String get shareMenuLoading => 'Зареждане...';

  @override
  String get shareMenuInspiredBy => 'Вдъхновен от';

  @override
  String get shareMenuAddInspirationCredit => 'Добави кредит за вдъхновение';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Този създател не може да бъде цитиран.';

  @override
  String get shareMenuUnknown => 'Неизвестен';

  @override
  String get shareMenuCreateBookmarkSet => 'Създай набор с отметки';

  @override
  String get shareMenuSetName => 'Задай име';

  @override
  String get shareMenuSetNameHint => 'Напр. Любими, Гледай по-късно и т.н.';

  @override
  String get shareMenuCreateNewSet => 'Създаване на нов набор';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Започни нова колекция от отметки';

  @override
  String get shareMenuNoBookmarkSets =>
      'Още няма набори с отметки. Създай първия си.';

  @override
  String get shareMenuError => 'Грешка';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Неуспешно зареждане на набори от отметки';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Създаде „$name“ и добави видео';
  }

  @override
  String get shareMenuUseThisSound => 'Използвай този звук';

  @override
  String get shareMenuOriginalSound => 'Оригинален звук';

  @override
  String get authSessionExpired => 'Сесията ти изтече. Влез отново.';

  @override
  String get authSignInFailed => 'Входът не мина. Опитай пак.';

  @override
  String get localeAppLanguage => 'Език на приложението';

  @override
  String get localeDeviceDefault => 'Езикът на устройството';

  @override
  String get localeSelectLanguage => 'Избери език';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Уеб удостоверяването не се поддържа в защитен режим. Използвай мобилното приложение, за да управляваш ключовете си сигурно.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Неуспешно интегриране на удостоверяването: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Неочаквана грешка: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Въведи Bunker URI';

  @override
  String get webAuthConnectTitle => 'Свържи се с Divine';

  @override
  String get webAuthChooseMethod =>
      'Избери предпочитания Nostr метод за удостоверяване';

  @override
  String get webAuthBrowserExtension => 'Разширение за браузър';

  @override
  String get webAuthRecommended => 'ПРЕПОРЪЧВА СЕ';

  @override
  String get webAuthNsecBunker => 'Nsec бункер';

  @override
  String get webAuthConnectRemoteSigner => 'Свържи отдалечен подписващ';

  @override
  String get webAuthBunkerHint => 'Бункер://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Поставяне от клипборда';

  @override
  String get webAuthConnectToBunker => 'Свържи се с Bunker';

  @override
  String get webAuthNewToNostr => 'Нов си в Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Инсталирай браузър разширение като Alby или nos2x за най-лесното изживяване, или използвай nsec bunker за сигурно отдалечено подписване.';

  @override
  String get soundsTitle => 'Звуци';

  @override
  String get soundsSearchHint => 'Звуци за търсене...';

  @override
  String get soundsPreviewUnavailable =>
      'Не може да се визуализира звук - няма наличен звук';

  @override
  String soundsPreviewFailed(String error) {
    return 'Неуспешно пускане на визуализация: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Представени звуци';

  @override
  String get soundsTrendingSounds => 'Набиращи популярност звуци';

  @override
  String get soundsAllSounds => 'Всички звуци';

  @override
  String get soundsSearchResults => 'Резултати от търсенето';

  @override
  String get soundsNoSoundsAvailable => 'Няма налични звуци';

  @override
  String get soundsNoSoundsDescription =>
      'Звуците ще се появят тук, когато творците споделят аудио';

  @override
  String get soundsNoSoundsFound => 'Няма намерени звуци';

  @override
  String get soundsNoSoundsFoundDescription => 'Пробвай с друго търсене';

  @override
  String get soundsFailedToLoad => 'Не успяхме да заредим звуците';

  @override
  String get soundsRetry => 'Опитай пак';

  @override
  String get soundsScreenLabel => 'Екран със звуци';

  @override
  String get profileTitle => 'Профил';

  @override
  String get profileRefresh => 'Опресняване';

  @override
  String get profileRefreshLabel => 'Опресняване на профила';

  @override
  String get profileMoreOptions => 'Още опции';

  @override
  String profileBlockedUser(String name) {
    return 'Блокиран $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Отблокиран $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Вече не следваш $name';
  }

  @override
  String profileError(String error) {
    return 'Грешка: $error';
  }

  @override
  String get notificationsTabAll => 'Всички';

  @override
  String get notificationsTabLikes => 'Харесвания';

  @override
  String get notificationsTabComments => 'Коментари';

  @override
  String get notificationsTabFollows => 'Следва';

  @override
  String get notificationsTabReposts => 'Репостове';

  @override
  String get notificationsFailedToLoad => 'Не успяхме да заредим известията';

  @override
  String get notificationsRetry => 'Опитай пак';

  @override
  String get notificationsCheckingNew => 'Проверяваме за нови известия';

  @override
  String get notificationsNoneYet => 'Още няма известия';

  @override
  String notificationsNoneForType(String type) {
    return 'Няма известия от тип $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Когато хората взаимодействат със съдържанието ти, ще го видиш тук';

  @override
  String get notificationsUnreadPrefix => 'Непрочетено известие';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Виж профила на $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Преглед на профили';

  @override
  String notificationsLoadingType(String type) {
    return 'Зареждат се $type известия...';
  }

  @override
  String get notificationsInviteSingular =>
      'Имаш 1 покана за споделяне с приятел!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Имаш $count покани за споделяне с приятели!';
  }

  @override
  String get notificationsVideoNotFound => 'Видеото не е намерено';

  @override
  String get notificationsVideoUnavailable => 'Видеото е недостъпно';

  @override
  String get notificationsFromNotification => 'От Известие';

  @override
  String get feedFailedToLoadVideos => 'Не успяхме да заредим видеата';

  @override
  String get feedRetry => 'Опитай пак';

  @override
  String get feedNoFollowedUsers =>
      'Още не следваш никого.\nПоследвай някого, за да виждаш видеата му тук.';

  @override
  String get feedForYouEmpty =>
      'Твоят фийд „За теб“ е празен.\nРазгледай видеа и последвай творци, за да го оформиш.';

  @override
  String get feedFollowingEmpty =>
      'Още няма видеа от хората, които следваш.\nНамери творци, които ти допадат, и ги последвай.';

  @override
  String get feedLatestEmpty => 'Още няма нови видеа.\nПровери пак скоро.';

  @override
  String get feedExploreVideos => 'Разгледай видеа';

  @override
  String get feedExternalVideoSlow => 'Външното видео се зарежда бавно';

  @override
  String get feedSkip => 'Пропускане';

  @override
  String get uploadWaitingToUpload => 'Чака качване';

  @override
  String get uploadUploadingVideo => 'Качва се видео';

  @override
  String get uploadProcessingVideo => 'Обработва се видео';

  @override
  String get uploadProcessingComplete => 'Обработката е готова';

  @override
  String get uploadPublishedSuccessfully => 'Публикувано. Видеото е навън.';

  @override
  String get uploadFailed => 'Качването не мина';

  @override
  String get uploadRetrying => 'Опитваме качването пак';

  @override
  String get uploadPaused => 'Качването е на пауза';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% готово';
  }

  @override
  String get uploadQueuedMessage => 'Видеото ти чака за качване';

  @override
  String get uploadUploadingMessage => 'Качваме към сървъра...';

  @override
  String get uploadProcessingMessage =>
      'Обработваме видеото - може да отнеме няколко минути';

  @override
  String get uploadReadyToPublishMessage =>
      'Видеото е обработено и готово за публикуване';

  @override
  String get uploadPublishedMessage => 'Видеото е публикувано в профила ти';

  @override
  String get uploadFailedMessage => 'Качването не мина - опитай пак';

  @override
  String get uploadRetryingMessage => 'Опитваме качването пак...';

  @override
  String get uploadPausedMessage => 'Качването е спряно от теб';

  @override
  String get uploadRetryButton => 'ОПИТАЙ ПАК';

  @override
  String uploadRetryFailed(String error) {
    return 'Неуспешен повторен опит за качване: $error';
  }

  @override
  String get userSearchPrompt => 'Търсене на потребители';

  @override
  String get userSearchNoResults => 'Няма намерени потребители';

  @override
  String get userSearchFailed => 'Търсенето не мина';

  @override
  String get userPickerSearchByName => 'Търсене по име';

  @override
  String get userPickerFilterByNameHint => 'Филтриране по име...';

  @override
  String get userPickerSearchByNameHint => 'Търсене по име...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name вече е добавен';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Избери $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Твоите хора са някъде там';

  @override
  String get userPickerEmptyFollowListBody =>
      'Последвай хора, с които си на една вълна. Когато те последват обратно, ще сте готови за колаборации.';

  @override
  String get userPickerGoBack => 'Върни се назад';

  @override
  String get userPickerTypeNameToSearch => 'Въведи име за търсене';

  @override
  String get userPickerUnavailable =>
      'Търсенето на потребители не е налично. Опитай пак по-късно.';

  @override
  String get userPickerSearchFailedTryAgain => 'Търсенето не мина. Опитай пак.';

  @override
  String get forgotPasswordTitle => 'Нулиране на парола';

  @override
  String get forgotPasswordDescription =>
      'Въведи имейл адреса си и ще ти изпратим линк за възстановяване на паролата.';

  @override
  String get forgotPasswordEmailLabel => 'Имейл адрес';

  @override
  String get forgotPasswordCancel => 'Отказ';

  @override
  String get forgotPasswordSendLink => 'Връзка за нулиране на имейл';

  @override
  String get ageVerificationContentWarning => 'Предупреждение за съдържание';

  @override
  String get ageVerificationTitle => 'Проверка на възрастта';

  @override
  String get ageVerificationAdultDescription =>
      'Това съдържание е маркирано като потенциално съдържание за възрастни. Трябва да си на 18 или повече, за да го видиш.';

  @override
  String get ageVerificationCreationDescription =>
      'За да използваш камерата и да създаваш съдържание, трябва да си на 16 или повече.';

  @override
  String get ageVerificationAdultQuestion => 'На 18 или повече ли си?';

  @override
  String get ageVerificationCreationQuestion => 'На 16 или повече ли си?';

  @override
  String get ageVerificationNo => 'Не';

  @override
  String get ageVerificationYes => 'Да';

  @override
  String get shareLinkCopied => 'Връзката е копирана в клипборда';

  @override
  String get shareFailedToCopy => 'Неуспешно копиране на връзката';

  @override
  String get shareVideoSubject => 'Виж това видео в Divine';

  @override
  String get shareFailedToShare => 'Неуспешно споделяне';

  @override
  String get shareVideoTitle => 'Сподели видео';

  @override
  String get shareToApps => 'Споделяне в Приложения';

  @override
  String get shareToAppsSubtitle =>
      'Споделяй чрез съобщения и социални приложения';

  @override
  String get shareCopyWebLink => 'Копирай уеб връзка';

  @override
  String get shareCopyWebLinkSubtitle => 'Копирай уеб връзката за споделяне';

  @override
  String get shareCopyNostrLink => 'Копирай Nostr връзката';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Копирай nevent връзката за Nostr клиенти';

  @override
  String get navHome => 'Начало';

  @override
  String get navExplore => 'Разгледай';

  @override
  String get navInbox => 'Входяща кутия';

  @override
  String get navProfile => 'Профил';

  @override
  String get navSearch => 'Търсене';

  @override
  String get navSearchTooltip => 'Търсене';

  @override
  String get navMyProfile => 'Моят профил';

  @override
  String get navNotifications => 'Известия';

  @override
  String get navOpenCamera => 'Отвори камерата';

  @override
  String get navUnknown => 'Неизвестно';

  @override
  String get navExploreClassics => 'Класика';

  @override
  String get navExploreNewVideos => 'Нови видеа';

  @override
  String get navExploreTrending => 'Тенденция';

  @override
  String get navExploreForYou => 'За теб';

  @override
  String get navExploreLists => 'Списъци';

  @override
  String get routeErrorTitle => 'Грешка';

  @override
  String get routeInvalidHashtag => 'Невалиден хаштаг';

  @override
  String get routeInvalidConversationId =>
      'Невалиден идентификатор на разговор';

  @override
  String get routeInvalidRequestId => 'Невалиден ID на заявката';

  @override
  String get routeInvalidListId => 'Невалиден идентификатор на списък';

  @override
  String get routeInvalidUserId => 'Невалиден потребителски идентификатор';

  @override
  String get routeInvalidVideoId => 'Невалиден идентификатор на видео';

  @override
  String get routeInvalidSoundId => 'Невалиден идентификатор на звука';

  @override
  String get routeInvalidCategory => 'Невалидна категория';

  @override
  String get routeNoVideosToDisplay => 'Няма видеа за показване';

  @override
  String get routeInvalidProfileId => 'Невалиден ID на потребителския профил';

  @override
  String get routeDefaultListName => 'Списък';

  @override
  String get supportTitle => 'Център за поддръжка';

  @override
  String get supportContactSupport => 'Свържи се с поддръжката';

  @override
  String get supportContactSupportSubtitle =>
      'Започни разговор или прегледай минали съобщения';

  @override
  String get supportReportBug => 'Докладване за грешка';

  @override
  String get supportReportBugSubtitle => 'Технически проблеми с приложението';

  @override
  String get supportRequestFeature => 'Заявка за функция';

  @override
  String get supportRequestFeatureSubtitle =>
      'Предложи подобрение или нова функция';

  @override
  String get supportSaveLogs => 'Запази логове';

  @override
  String get supportSaveLogsSubtitle =>
      'Експортирай логовете във файл за ръчно изпращане';

  @override
  String get supportFaq => 'ЧЗВ';

  @override
  String get supportFaqSubtitle => 'Често задавани въпроси и отговори';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'Научи за проверката и автентичността';

  @override
  String get supportLoginRequired => 'Влез, за да се свържеш с поддръжката';

  @override
  String get supportExportingLogs => 'Логовете се експортират...';

  @override
  String get supportExportLogsFailed => 'Не успяхме да експортираме логовете';

  @override
  String get supportChatNotAvailable => 'Чатът за поддръжка не е наличен';

  @override
  String get supportCouldNotOpenMessages =>
      'Не можах да отворя съобщения за поддръжка';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Не може да се отвори $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Грешка при отваряне на $pageName: $error';
  }

  @override
  String get reportTitle => 'Докладвай съдържание';

  @override
  String get reportWhyReporting => 'Защо подаваш сигнал за това съдържание?';

  @override
  String get reportPolicyNotice =>
      'Divine ще преглежда сигналите за съдържание до 24 часа и при нужда ще премахва съдържание или ще блокира акаунта, който го е публикувал.';

  @override
  String get reportAdditionalDetails => 'Допълнителни подробности (по избор)';

  @override
  String get reportBlockUser => 'Блокирай този потребител';

  @override
  String get reportCancel => 'Отказ';

  @override
  String get reportSubmit => 'Докладвай';

  @override
  String get reportSelectReason =>
      'Избери причина за докладване на това съдържание';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Спам или нежелано съдържание';

  @override
  String get reportReasonHarassment => 'Тормоз, малтретиране или заплахи';

  @override
  String get reportReasonViolence => 'Насилствено или екстремистко съдържание';

  @override
  String get reportReasonSexualContent =>
      'Сексуално съдържание или съдържание за възрастни';

  @override
  String get reportReasonCopyright => 'Нарушаване на авторски права';

  @override
  String get reportReasonFalseInfo => 'Невярна информация';

  @override
  String get reportReasonCsam => 'Нарушение на безопасността на детето';

  @override
  String get reportReasonAiGenerated => 'AI-генерирано съдържание';

  @override
  String get reportReasonOther => 'Друго нарушение на правилата';

  @override
  String reportFailed(Object error) {
    return 'Неуспешно докладване на съдържание: $error';
  }

  @override
  String get reportReceivedTitle => 'Докладът е получен';

  @override
  String get reportReceivedThankYou =>
      'Благодарим, че помагаш да запазим Divine безопасен.';

  @override
  String get reportReceivedReviewNotice =>
      'Екипът ни ще прегледа сигнала ти и ще предприеме нужните действия. Може да получаваш новини чрез директно съобщение.';

  @override
  String get reportLearnMore => 'Научи повече';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Затвори';

  @override
  String get listAddToList => 'Добави към списъка';

  @override
  String listVideoCount(int count) {
    return '$count видеа';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'By ';

  @override
  String get listNewList => 'Нов списък';

  @override
  String get listDone => 'Готово';

  @override
  String get listErrorLoading => 'Грешка при зареждане на списъците';

  @override
  String listRemovedFrom(String name) {
    return 'Премахнато от $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Добавено към $name';
  }

  @override
  String get listCreateNewList => 'Създаване на нов списък';

  @override
  String get listNewPeopleList => 'Нов списък с хора';

  @override
  String get listCollaboratorsNone => 'Няма';

  @override
  String get listAddCollaboratorTitle => 'Добави сътрудник';

  @override
  String get listCollaboratorSearchHint => 'Търсене diVine...';

  @override
  String get listNameLabel => 'Име на списък';

  @override
  String get listDescriptionLabel => 'Описание (по избор)';

  @override
  String get listPublicList => 'Публичен списък';

  @override
  String get listPublicListSubtitle =>
      'Други могат да следват и да видят този списък';

  @override
  String get listCancel => 'Отказ';

  @override
  String get listCreate => 'Създай';

  @override
  String get listCreateFailed => 'Неуспешно създаване на списък';

  @override
  String get keyManagementTitle => 'Nostr Ключове';

  @override
  String get keyManagementWhatAreKeys => 'Какво представляват ключовете Nostr?';

  @override
  String get keyManagementExplanation =>
      'Nostr самоличността ти е двойка криптографски ключове:\n\n• Публичният ти ключ (npub) е като потребителско име - споделяй го спокойно\n• Частният ти ключ (nsec) е като парола - пази го в тайна!\n\nТвоят nsec ти дава достъп до акаунта във всяко Nostr приложение.';

  @override
  String get keyManagementImportTitle => 'Импортиране на съществуващ ключ';

  @override
  String get keyManagementImportSubtitle =>
      'Вече имаш Nostr акаунт? Постави частния си ключ (nsec), за да го използваш тук.';

  @override
  String get keyManagementImportButton => 'Ключ за импортиране';

  @override
  String get keyManagementImportWarning => 'Това ще замени текущия ти ключ!';

  @override
  String get keyManagementBackupTitle => 'Архивирай ключа си';

  @override
  String get keyManagementBackupSubtitle =>
      'Запази частния си ключ (nsec), за да използваш акаунта си в други Nostr приложения.';

  @override
  String get keyManagementCopyNsec => 'Копирай личния ми ключ (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Никога не споделяй своя nsec с никого!';

  @override
  String get keyManagementPasteKey => 'Постави частния си ключ';

  @override
  String get keyManagementInvalidFormat =>
      'Невалиден формат на ключа. Трябва да започва с \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Импортиране на този ключ?';

  @override
  String get keyManagementConfirmImportBody =>
      'Това ще замени текущата ти самоличност с импортираната.\n\nТекущият ти ключ ще бъде загубен, освен ако първо не си го архивирал.';

  @override
  String get keyManagementImportConfirm => 'Импортиране';

  @override
  String get keyManagementImportSuccess => 'Ключът е импортиран успешно!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Неуспешно импортиране на ключ: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Частният ключ е копиран в клипборда!\n\nСъхранявайте го на сигурно място.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Неуспешно експортиране на ключ: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Запазено в галерията';

  @override
  String get saveOriginalShare => 'Сподели';

  @override
  String get saveOriginalDone => 'Готово';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Необходим е достъп до снимки';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'За да запазваш видеа, дай достъп до снимките в настройките.';

  @override
  String get saveOriginalOpenSettings => 'Отвори Настройки';

  @override
  String get saveOriginalNotNow => 'Не сега';

  @override
  String get cameraPermissionNotNow => 'Не сега';

  @override
  String get saveOriginalDownloadFailed => 'Неуспешно изтегляне';

  @override
  String get saveOriginalDismiss => 'Отхвърляне';

  @override
  String get saveOriginalDownloadingVideo => 'Изтегляне на видео';

  @override
  String get saveOriginalSavingToCameraRoll => 'Запазване в галерията';

  @override
  String get saveOriginalFetchingVideo => 'Видеото се извлича от мрежата...';

  @override
  String get saveOriginalSavingVideo =>
      'Оригиналното видео се запазва в галерията...';

  @override
  String get soundTitle => 'Звук';

  @override
  String get soundOriginalSound => 'Оригинален звук';

  @override
  String get soundVideosUsingThisSound => 'Видеоклипове, използващи този звук';

  @override
  String get soundSourceVideo => 'Източник на видео';

  @override
  String get soundNoVideosYet => 'Още няма видеа';

  @override
  String get soundBeFirstToUse => 'Бъдете първите, които използват този звук!';

  @override
  String get soundFailedToLoadVideos => 'Не успяхме да заредим видеата';

  @override
  String get soundRetry => 'Опитай пак';

  @override
  String get soundVideosUnavailable => 'Видеоклиповете са недостъпни';

  @override
  String get soundCouldNotLoadDetails =>
      'Подробностите за видеото не се заредиха';

  @override
  String get soundPreview => 'Преглед';

  @override
  String get soundStop => 'Спрете';

  @override
  String get soundUseSound => 'Използвай звук';

  @override
  String get soundUntitled => 'Untitled sound';

  @override
  String get soundStopPreview => 'Stop preview';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Preview $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'View details for $title';
  }

  @override
  String get soundNoVideoCount => 'Още няма видеа';

  @override
  String get soundOneVideo => '1 видео';

  @override
  String soundVideoCount(int count) {
    return '$count видеа';
  }

  @override
  String get soundUnableToPreview =>
      'Не може да се визуализира звук - няма наличен звук';

  @override
  String soundPreviewFailed(Object error) {
    return 'Неуспешно пускане на визуализация: $error';
  }

  @override
  String get soundViewSource => 'Виж източника';

  @override
  String get soundCloseTooltip => 'Затвори';

  @override
  String get exploreNotExploreRoute => 'Не е маршрут за изследване';

  @override
  String get legalTitle => 'Законни';

  @override
  String get legalTermsOfService => 'Условия за ползване';

  @override
  String get legalTermsOfServiceSubtitle => 'Правила и условия за ползване';

  @override
  String get legalPrivacyPolicy => 'Политика за поверителност';

  @override
  String get legalPrivacyPolicySubtitle => 'Как работим с данните ти';

  @override
  String get legalSafetyStandards => 'Стандарти за безопасност';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Правила на общността и безопасност';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Правила за авторско право и сваляне';

  @override
  String get legalOpenSourceLicenses => 'Лицензи за отворен код';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Приписвания на пакети на трети страни';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Не може да се отвори $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Грешка при отваряне на $pageName: $error';
  }

  @override
  String get categoryAction => 'Действие';

  @override
  String get categoryAdventure => 'Приключение';

  @override
  String get categoryAnimals => 'Животни';

  @override
  String get categoryAnimation => 'Анимация';

  @override
  String get categoryArchitecture => 'Архитектура';

  @override
  String get categoryArt => 'Чл';

  @override
  String get categoryAutomotive => 'Автомобилен';

  @override
  String get categoryAwardShow => 'Наградно шоу';

  @override
  String get categoryAwards => 'Награди';

  @override
  String get categoryBaseball => 'Бейзбол';

  @override
  String get categoryBasketball => 'Баскетбол';

  @override
  String get categoryBeauty => 'Красота';

  @override
  String get categoryBeverage => 'Напитка';

  @override
  String get categoryCars => 'Автомобили';

  @override
  String get categoryCelebration => 'Тържество';

  @override
  String get categoryCelebrities => 'Знаменитости';

  @override
  String get categoryCelebrity => 'Знаменитост';

  @override
  String get categoryCityscape => 'Градски пейзаж';

  @override
  String get categoryComedy => 'Комедия';

  @override
  String get categoryConcert => 'Концерт';

  @override
  String get categoryCooking => 'Готвене';

  @override
  String get categoryCostume => 'Костюм';

  @override
  String get categoryCrafts => 'Занаяти';

  @override
  String get categoryCrime => 'Престъпление';

  @override
  String get categoryCulture => 'Култура';

  @override
  String get categoryDance => 'Танцувай';

  @override
  String get categoryDiy => 'Направи си сам';

  @override
  String get categoryDrama => 'Драма';

  @override
  String get categoryEducation => 'Образование';

  @override
  String get categoryEmotional => 'Емоционален';

  @override
  String get categoryEmotions => 'Емоции';

  @override
  String get categoryEntertainment => 'Развлечение';

  @override
  String get categoryEvent => 'Събитие';

  @override
  String get categoryFamily => 'Семейство';

  @override
  String get categoryFans => 'Фенове';

  @override
  String get categoryFantasy => 'Фантазия';

  @override
  String get categoryFashion => 'Стил';

  @override
  String get categoryFestival => 'Фестивал';

  @override
  String get categoryFilm => 'Филм';

  @override
  String get categoryFitness => 'Фитнес';

  @override
  String get categoryFood => 'Храна';

  @override
  String get categoryFootball => 'Футбол';

  @override
  String get categoryFurniture => 'Мебели';

  @override
  String get categoryGaming => 'Игри';

  @override
  String get categoryGolf => 'Голф';

  @override
  String get categoryGrooming => 'Подстригване';

  @override
  String get categoryGuitar => 'Китара';

  @override
  String get categoryHalloween => 'Хелоуин';

  @override
  String get categoryHealth => 'Здраве';

  @override
  String get categoryHockey => 'Хокей';

  @override
  String get categoryHoliday => 'Празник';

  @override
  String get categoryHome => 'Начало';

  @override
  String get categoryHomeImprovement => 'Подобряване на дома';

  @override
  String get categoryHorror => 'Ужас';

  @override
  String get categoryHospital => 'Болница';

  @override
  String get categoryHumor => 'Хумор';

  @override
  String get categoryInteriorDesign => 'Интериорен дизайн';

  @override
  String get categoryInterview => 'Интервю';

  @override
  String get categoryKids => 'Деца';

  @override
  String get categoryLifestyle => 'Начин на живот';

  @override
  String get categoryMagic => 'Магия';

  @override
  String get categoryMakeup => 'Грим';

  @override
  String get categoryMedical => 'Медицински';

  @override
  String get categoryMusic => 'Музика';

  @override
  String get categoryMystery => 'Мистерия';

  @override
  String get categoryNature => 'Природата';

  @override
  String get categoryNews => 'Новини';

  @override
  String get categoryOutdoor => 'На открито';

  @override
  String get categoryParty => 'Парти';

  @override
  String get categoryPeople => 'Хора';

  @override
  String get categoryPerformance => 'Изпълнение';

  @override
  String get categoryPets => 'Домашни любимци';

  @override
  String get categoryPolitics => 'Политика';

  @override
  String get categoryPrank => 'Шега';

  @override
  String get categoryPranks => 'Шеги';

  @override
  String get categoryRealityShow => 'Риалити шоу';

  @override
  String get categoryRelationship => 'Връзка';

  @override
  String get categoryRelationships => 'Връзки';

  @override
  String get categoryRomance => 'Романтика';

  @override
  String get categorySchool => 'Училище';

  @override
  String get categoryScienceFiction => 'Научна фантастика';

  @override
  String get categorySelfie => 'Селфи';

  @override
  String get categoryShopping => 'Пазаруване';

  @override
  String get categorySkateboarding => 'Скейтборд';

  @override
  String get categorySkincare => 'Грижа за кожата';

  @override
  String get categorySoccer => 'Футбол';

  @override
  String get categorySocialGathering => 'Социално събиране';

  @override
  String get categorySocialMedia => 'Социални медии';

  @override
  String get categorySports => 'Спорт';

  @override
  String get categoryTalkShow => 'Ток шоу';

  @override
  String get categoryTech => 'Техн';

  @override
  String get categoryTechnology => 'Технология';

  @override
  String get categoryTelevision => 'Телевизия';

  @override
  String get categoryToys => 'Играчки';

  @override
  String get categoryTransportation => 'Транспорт';

  @override
  String get categoryTravel => 'Пътуване';

  @override
  String get categoryUrban => 'Градски';

  @override
  String get categoryViolence => 'Насилие';

  @override
  String get categoryVlog => 'Влог';

  @override
  String get categoryVlogging => 'Влогове';

  @override
  String get categoryWrestling => 'Борба';

  @override
  String get profileSetupUploadSuccess => 'Профилната снимка е качена успешно!';

  @override
  String inboxReportedUser(String displayName) {
    return 'Докладвано $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Блокиран $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Отблокиран $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Премахнат разговор';

  @override
  String get inboxEmptyTitle => 'Все още няма съобщения';

  @override
  String get inboxEmptySubtitle => 'Този бутон + няма да ухапе.';

  @override
  String get inboxActionMute => 'Заглушаване на разговора';

  @override
  String inboxActionReport(String displayName) {
    return 'Докладвай $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Блокирай $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Отблокирай $displayName';
  }

  @override
  String get inboxActionRemove => 'Премахни разговора';

  @override
  String get inboxRemoveConfirmTitle => 'Да премахнем разговора?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Това ще изтрие разговора ти с $displayName. Действието не може да бъде отменено.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Премахни';

  @override
  String get inboxConversationMuted => 'Разговорът е заглушен';

  @override
  String get inboxConversationUnmuted => 'Разговорът е включен';

  @override
  String get inboxCollabInviteCardTitle => 'Покана за сътрудник';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role на тази публикация';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'Приеми';

  @override
  String get inboxCollabInviteIgnoreButton => 'Игнорирайте';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Прието';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Игнорирани';

  @override
  String get inboxCollabInviteAcceptError =>
      'Не успяхме да приемем. Опитай пак.';

  @override
  String get inboxCollabInviteSentStatus => 'Поканата е изпратена';

  @override
  String get inboxConversationCollabInvitePreview => 'Покана за сътрудник';

  @override
  String get reportDialogCancel => 'Отказ';

  @override
  String get reportDialogReport => 'Докладвай';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Заглавие: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Видео $current/$total';
  }

  @override
  String get exploreSearchHint => 'Search...';

  @override
  String categoryVideoCount(String count) {
    return '$count videos';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Неуспешно актуализиране на абонамента: $error';
  }

  @override
  String get discoverListsTitle => 'Discover Lists';

  @override
  String get discoverListsFailedToLoad => 'Failed to load lists';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Failed to load lists: $error';
  }

  @override
  String get discoverListsLoading => 'Discovering public lists...';

  @override
  String get discoverListsEmptyTitle => 'No public lists found';

  @override
  String get discoverListsEmptySubtitle => 'Check back later for new lists';

  @override
  String get discoverListsByAuthorPrefix => 'by';

  @override
  String get curatedListEmptyTitle => 'No videos in this list';

  @override
  String get curatedListEmptySubtitle => 'Add some videos to get started';

  @override
  String get curatedListLoadingVideos => 'Loading videos...';

  @override
  String get curatedListFailedToLoad => 'Failed to load list';

  @override
  String get curatedListNoVideosAvailable => 'No videos available';

  @override
  String get curatedListVideoNotAvailable => 'Video not available';

  @override
  String get commonRetry => 'Опитай пак';

  @override
  String get commonNext => 'Следваща';

  @override
  String get commonDelete => 'Изтрий';

  @override
  String get commonCancel => 'Отказ';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get videoMetadataTags => 'Етикети';

  @override
  String get videoMetadataExpiration => 'Изтичане';

  @override
  String get videoMetadataExpirationNotExpire => 'Не изтича';

  @override
  String get videoMetadataExpirationOneDay => '1 ден';

  @override
  String get videoMetadataExpirationOneWeek => '1 седмица';

  @override
  String get videoMetadataExpirationOneMonth => '1 месец';

  @override
  String get videoMetadataExpirationOneYear => '1 година';

  @override
  String get videoMetadataExpirationOneDecade => '1 десетилетие';

  @override
  String get videoMetadataContentWarnings => 'Предупреждения за съдържанието';

  @override
  String get videoEditorStickers => 'Стикери';

  @override
  String get trendingTitle => 'Тенденция';

  @override
  String get proofmodeCheckAiGenerated => 'Провери дали е генерирано от AI';

  @override
  String get libraryDeleteConfirm => 'Изтриване';

  @override
  String get libraryWebUnavailableHeadline =>
      'Библиотеката е налична в мобилното приложение';

  @override
  String get libraryWebUnavailableDescription =>
      'Черновите и клиповете се пазят на устройството ти, затова отвори Divine на телефона си, за да ги управляваш.';

  @override
  String get libraryTabDrafts => 'Чернови';

  @override
  String get libraryTabClips => 'Клипове';

  @override
  String get librarySaveToCameraRollTooltip =>
      'Запазване в ролката на камерата';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Изтрийте избраните клипове';

  @override
  String get libraryDeleteClipsTitle => 'Изтриване на клипове';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# избрани клипа',
      one: '# избран клип',
    );
    return 'Сигурен ли си, че искаш да изтриеш $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Това действие не може да бъде отменено. Видео файловете ще бъдат премахнати за постоянно от твоето устройство.';

  @override
  String get libraryPreparingVideo => 'Видеоклипът се подготвя...';

  @override
  String get libraryCreateVideo => 'Създаване на видео';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа',
      one: '1 клип',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'и',
      one: '',
    );
    return '$_temp0 запазен$_temp1 в $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount запазено, $failureCount неуспешно';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Разрешението за $destination е отказано';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count клипа са изтрити',
      one: '1 клип е изтрит',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Не успяхме да заредим черновите';

  @override
  String get libraryCouldNotLoadClips => 'Не успяхме да заредим клиповете';

  @override
  String get libraryOpenErrorDescription =>
      'Нещо се обърка при отварянето на библиотеката ти. Пробвай пак.';

  @override
  String get libraryNoDraftsYetTitle => 'Още няма чернови';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Видеата, които запазиш като чернова, ще се появят тук';

  @override
  String get libraryNoClipsYetTitle => 'Още няма клипове';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Записаните ти видео клипове ще се появят тук';

  @override
  String get libraryDraftDeletedSnackbar => 'Черновата е изтрита';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Не успяхме да изтрием черновата';

  @override
  String get libraryDraftActionPost => 'Публикувай';

  @override
  String get libraryDraftActionEdit => 'Редактиране';

  @override
  String get libraryDraftActionDelete => 'Изтрий черновата';

  @override
  String get libraryDeleteDraftTitle => 'Изтрий чернова';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Сигурен ли си, че искаш да изтриеш „$title“?';
  }

  @override
  String get libraryDeleteClipTitle => 'Изтрий клип';

  @override
  String get libraryDeleteClipMessage =>
      'Сигурен ли си, че искаш да изтриеш този клип?';

  @override
  String get libraryClipSelectionTitle => 'Клипове';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Остават ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Добави';

  @override
  String get libraryRecordVideo => 'Запишете видео';

  @override
  String get routerInvalidCreator => 'Невалиден създател';

  @override
  String get routerInvalidHashtagRoute => 'Невалиден маршрут на хаштаг';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Не успяхме да заредим видеата';

  @override
  String get categoryGalleryNoVideosInCategory => 'No videos in this category';

  @override
  String get categoryGallerySortOptionsLabel => 'Category sort options';

  @override
  String get categoryGallerySortHot => 'Hot';

  @override
  String get categoryGallerySortNew => 'New';

  @override
  String get categoryGallerySortClassic => 'Classic';

  @override
  String get categoryGallerySortForYou => 'For You';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Не успяхме да заредим категориите';

  @override
  String get categoriesNoCategoriesAvailable => 'No categories available';

  @override
  String get notificationsEmptyTitle => 'No activity yet';

  @override
  String get notificationsEmptySubtitle =>
      'When people interact with your content, you\'ll see it here';

  @override
  String get appsPermissionsTitle => 'Integration Permissions';

  @override
  String get appsPermissionsRevoke => 'Revoke';

  @override
  String get appsPermissionsEmptyTitle => 'No saved integration permissions';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Approved integrations will appear here after you remember an access approval.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName wants your approval';
  }

  @override
  String get nostrAppPermissionDescription =>
      'This app is requesting access through Divine\'s vetted sandbox.';

  @override
  String get nostrAppPermissionOrigin => 'Origin';

  @override
  String get nostrAppPermissionMethod => 'Method';

  @override
  String get nostrAppPermissionCapability => 'Capability';

  @override
  String get nostrAppPermissionEventKind => 'Event kind';

  @override
  String get nostrAppPermissionAllow => 'Allow';

  @override
  String get bugReportSendReport => 'Send Report';

  @override
  String get supportSubjectRequiredLabel => 'Subject *';

  @override
  String get supportRequiredHelper => 'Required';

  @override
  String get bugReportSubjectHint => 'Brief summary of the issue';

  @override
  String get bugReportDescriptionRequiredLabel => 'What happened? *';

  @override
  String get bugReportDescriptionHint => 'Describe the issue you encountered';

  @override
  String get bugReportStepsLabel => 'Steps to Reproduce';

  @override
  String get bugReportStepsHint => '1. Go to...\n2. Tap on...\n3. See error';

  @override
  String get bugReportExpectedBehaviorLabel => 'Expected Behavior';

  @override
  String get bugReportExpectedBehaviorHint =>
      'What should have happened instead?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Device info and logs will be included automatically.';

  @override
  String get bugReportSuccessMessage =>
      'Thank you! We\'ve received your report and will use it to make Divine better.';

  @override
  String get bugReportSendFailed =>
      'Failed to send bug report. Please try again later.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Bug report failed to send: $error';
  }

  @override
  String get featureRequestSendRequest => 'Send Request';

  @override
  String get featureRequestSubjectHint => 'Brief summary of your idea';

  @override
  String get featureRequestDescriptionRequiredLabel => 'What would you like? *';

  @override
  String get featureRequestDescriptionHint => 'Describe the feature you want';

  @override
  String get featureRequestUsefulnessLabel => 'How would this be useful?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explain the benefit this feature would provide';

  @override
  String get featureRequestWhenLabel => 'When would you use this?';

  @override
  String get featureRequestWhenHint =>
      'Describe the situations where this would help';

  @override
  String get featureRequestSuccessMessage =>
      'Thank you! We\'ve received your feature request and will review it.';

  @override
  String get featureRequestSendFailed =>
      'Failed to send feature request. Please try again later.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Feature request failed to send: $error';
  }

  @override
  String get notificationFollowBack => 'Последвай обратно';

  @override
  String get followingTitle => 'Following';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName\'s Following';
  }

  @override
  String get followingFailedToLoadList =>
      'Неуспешно зареждане на следния списък';

  @override
  String get followingEmptyTitle => 'Not following anyone yet';

  @override
  String get followersTitle => 'Followers';

  @override
  String followersTitleForName(String displayName) {
    return '$displayName\'s Followers';
  }

  @override
  String get followersFailedToLoadList =>
      'Неуспешно зареждане на списъка с последователи';

  @override
  String get followersEmptyTitle => 'No followers yet';

  @override
  String get followersUpdateFollowFailed =>
      'Failed to update follow status. Please try again.';

  @override
  String get reportMessageTitle => 'Report Message';

  @override
  String get reportMessageWhyReporting => 'Why are you reporting this message?';

  @override
  String get reportMessageSelectReason =>
      'Please select a reason for reporting this message';

  @override
  String get newMessageTitle => 'New message';

  @override
  String get newMessageFindPeople => 'Find people';

  @override
  String get newMessageNoContacts =>
      'No contacts found.\nFollow people to see them here.';

  @override
  String get newMessageNoUsersFound => 'No users found';

  @override
  String get hashtagSearchTitle => 'Search for hashtags';

  @override
  String get hashtagSearchSubtitle => 'Discover trending topics and content';

  @override
  String hashtagSearchNoResults(String query) {
    return 'No hashtags found for \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Search failed';

  @override
  String get userNotAvailableTitle => 'Account not available';

  @override
  String get userNotAvailableBody => 'This account isn\'t available right now.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Неуспешно запазване на настройките: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Please enter a valid server URL (e.g., https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom settings saved';

  @override
  String get blossomSaveTooltip => 'Save';

  @override
  String get blossomAboutTitle => 'About Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom is a decentralized media storage protocol that allows you to upload videos to any compatible server. By default, videos are uploaded to Divine\'s Blossom server. Enable the option below to use a custom server instead.';

  @override
  String get blossomUseCustomServer => 'Use Custom Blossom Server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videos will be uploaded to your custom Blossom server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Your videos are currently being uploaded to Divine\'s Blossom server';

  @override
  String get blossomCustomServerUrl => 'Custom Blossom Server URL';

  @override
  String get blossomCustomServerHelper =>
      'Enter the URL of your custom Blossom server';

  @override
  String get blossomPopularServers => 'Popular Blossom Servers';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom server URL must use https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Неуспешно актуализиране на настройката за кръстосана публикация';

  @override
  String get blueskySignInRequired => 'Sign in to manage Bluesky settings';

  @override
  String get blueskyPublishVideos => 'Publish videos to Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Your videos will be published to Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Your videos will not be published to Bluesky';

  @override
  String get blueskyHandle => 'Bluesky Handle';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Account provisioned and ready';

  @override
  String get blueskyStatusPending => 'Account provisioning in progress...';

  @override
  String get blueskyStatusFailed => 'Account provisioning failed';

  @override
  String get blueskyStatusDisabled => 'Account disabled';

  @override
  String get blueskyStatusNotLinked => 'No Bluesky account linked';

  @override
  String get invitesTitle => 'Покани приятели';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count покани са готови за генериране',
      one: '1 покана е готова за генериране',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Генерирай код, когато си готов да го споделиш.';

  @override
  String get invitesGenerateButtonLabel => 'Генерирай покана';

  @override
  String get invitesNoneAvailable => 'No invites available right now';

  @override
  String get invitesShareWithPeople => 'Share diVine with people you know';

  @override
  String get invitesUsedInvites => 'Used invites';

  @override
  String invitesShareMessage(String code) {
    return 'Join me on diVine! Use invite code $code to get started:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copy invite';

  @override
  String get invitesCopied => 'Invite copied!';

  @override
  String get invitesShareInvite => 'Share invite';

  @override
  String get invitesShareSubject => 'Join me on diVine';

  @override
  String get invitesClaimed => 'Claimed';

  @override
  String get invitesCouldNotLoad => 'Could not load invites';

  @override
  String get invitesRetry => 'Retry';

  @override
  String get searchSomethingWentWrong => 'Нещо се обърка';

  @override
  String get searchTryAgain => 'Опитай пак';

  @override
  String get searchForLists => 'Търсете списъци';

  @override
  String get searchFindCuratedVideoLists => 'Намери подбрани видео списъци';

  @override
  String get searchEnterQuery => 'Въведи заявка за търсене';

  @override
  String get searchDiscoverSomethingInteresting => 'Открийте нещо интересно';

  @override
  String get searchPeopleSectionHeader => 'Хора';

  @override
  String get searchPeopleLoadingLabel => 'Зареждат се резултати за хора';

  @override
  String get searchTagsSectionHeader => 'Етикети';

  @override
  String get searchTagsLoadingLabel => 'Резултатите от етикета се зареждат';

  @override
  String get searchVideosSectionHeader => 'Видеоклипове';

  @override
  String get searchVideosLoadingLabel => 'Зареждат се видео резултати';

  @override
  String get searchListsSectionHeader => 'Списъци';

  @override
  String get searchListsLoadingLabel => 'Резултатите от списъка се зареждат';

  @override
  String get cameraAgeRestriction =>
      'Трябва да си на 16 или повече, за да създаваш съдържание';

  @override
  String get featureRequestCancel => 'Отказ';

  @override
  String keyImportError(String error) {
    return 'Грешка: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker relay must use wss:// (ws:// is allowed only for localhost)';

  @override
  String get timeNow => 'Сега';

  @override
  String timeShortMinutes(int count) {
    return '$countм';
  }

  @override
  String timeShortHours(int count) {
    return '$countч';
  }

  @override
  String timeShortDays(int count) {
    return '$countд';
  }

  @override
  String timeShortWeeks(int count) {
    return '$countседм';
  }

  @override
  String timeShortMonths(int count) {
    return '$countмес';
  }

  @override
  String timeShortYears(int count) {
    return '$countг';
  }

  @override
  String get timeVerboseNow => 'Сега';

  @override
  String timeAgo(String time) {
    return 'Преди $time';
  }

  @override
  String get timeToday => 'Днес';

  @override
  String get timeYesterday => 'Вчера';

  @override
  String get timeJustNow => 'Току-що';

  @override
  String timeMinutesAgo(int count) {
    return 'Преди $count мин';
  }

  @override
  String timeHoursAgo(int count) {
    return 'Преди $countч';
  }

  @override
  String timeDaysAgo(int count) {
    return 'Преди $count дни';
  }

  @override
  String get draftTimeJustNow => 'Току-що';

  @override
  String get contentLabelNudity => 'Голота';

  @override
  String get contentLabelSexualContent => 'Сексуално съдържание';

  @override
  String get contentLabelPornography => 'Порнография';

  @override
  String get contentLabelGraphicMedia => 'Графични медии';

  @override
  String get contentLabelViolence => 'Насилие';

  @override
  String get contentLabelSelfHarm => 'Самонараняване/самоубийство';

  @override
  String get contentLabelDrugUse => 'Употреба на наркотици';

  @override
  String get contentLabelAlcohol => 'Алкохол';

  @override
  String get contentLabelTobacco => 'Тютюн/пушене';

  @override
  String get contentLabelGambling => 'Хазарт';

  @override
  String get contentLabelProfanity => 'Ругатни';

  @override
  String get contentLabelHateSpeech => 'Реч на омразата';

  @override
  String get contentLabelHarassment => 'Тормоз';

  @override
  String get contentLabelFlashingLights => 'Мигащи светлини';

  @override
  String get contentLabelAiGenerated => 'Генерирано от AI';

  @override
  String get contentLabelDeepfake => 'Дийпфейк';

  @override
  String get contentLabelSpam => 'Спам';

  @override
  String get contentLabelScam => 'Скам/измама';

  @override
  String get contentLabelSpoiler => 'Спойлер';

  @override
  String get contentLabelMisleading => 'Подвеждащи';

  @override
  String get contentLabelSensitiveContent => 'Чувствително съдържание';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName хареса видеото ти';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName коментира видеото ти';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName започна да те следва';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName те спомена';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName сподели видеото ти пак';
  }

  @override
  String get notificationRepliedToYourComment => 'Отговори на коментара ти';

  @override
  String get notificationAndConnector => 'И';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count други',
      one: '1 друг',
    );
    return '$_temp0';
  }

  @override
  String get commentReplyToPrefix => 'Отг.:';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get draftUntitled => 'Без заглавие';

  @override
  String get contentWarningNone => 'Няма';

  @override
  String get textBackgroundNone => 'Няма';

  @override
  String get textBackgroundSolid => 'Твърди';

  @override
  String get textBackgroundHighlight => 'Маркирайте';

  @override
  String get textBackgroundTransparent => 'Прозрачен';

  @override
  String get textAlignLeft => 'Наляво';

  @override
  String get textAlignRight => 'Вярно';

  @override
  String get textAlignCenter => 'Център';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Камерата още не се поддържа в уеб';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Снимането и записът с камера още не са налични в уеб версията.';

  @override
  String get cameraPermissionBackToFeed => 'Назад към фийда';

  @override
  String get cameraPermissionErrorTitle => 'Грешка с разрешенията';

  @override
  String get cameraPermissionErrorDescription =>
      'Нещо се обърка, докато проверявахме разрешенията.';

  @override
  String get cameraPermissionRetry => 'Опитай пак';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Разреши достъп до камерата и микрофона';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Това ти позволява да записваш и редактираш видеа директно в приложението. Нищо повече.';

  @override
  String get cameraPermissionContinue => 'Продължи';

  @override
  String get cameraPermissionGoToSettings => 'Към настройките';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Защо шест секунди?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Кратките клипове оставят място за спонтанност. 6-секундният формат ти помага да хванеш истинските моменти, докато се случват.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Разбрах!';

  @override
  String get videoRecorderAutosaveFoundTitle => 'Намерихме започнато видео';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Искаш ли да продължиш оттам, докъдето стигна?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Да, продължете';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Не, започни ново видео';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Не успяхме да възстановим черновата ти';

  @override
  String get videoRecorderStopRecordingTooltip => 'Спрете записа';

  @override
  String get videoRecorderStartRecordingTooltip => 'Започни записа';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Записване. Докосни навсякъде, за да спрете';

  @override
  String get videoRecorderTapToStartLabel =>
      'Докосни произволно място, за да започнете да записвате';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Изтрий последния клип';

  @override
  String get videoRecorderSwitchCameraLabel => 'Смени камерата';

  @override
  String get videoRecorderToggleGridLabel => 'Превключване на мрежата';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Превключване на призрачна рамка';

  @override
  String get videoRecorderGhostFrameEnabled => 'Рамката призрак е активирана';

  @override
  String get videoRecorderGhostFrameDisabled =>
      'Призрачната рамка е деактивирана';

  @override
  String get videoRecorderClipDeletedMessage => 'Клипът е изтрит';

  @override
  String get videoRecorderCloseLabel => 'Затворете видеорекордер';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Продължете към видеоредактора';

  @override
  String get videoRecorderCaptureCloseLabel => 'Затвори';

  @override
  String get videoRecorderCaptureNextLabel => 'Следваща';

  @override
  String get videoRecorderToggleFlashLabel => 'Превключване на светкавицата';

  @override
  String get videoRecorderCycleTimerLabel => 'Цикъл таймер';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Превключване на пропорциите';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Библиотека с клипове, няма клипове';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Отвори библиотеката с клипове, $clipCount клипа',
      one: 'Отвори библиотеката с клипове, 1 клип',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Камера';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Отвори камерата';

  @override
  String get videoEditorLibraryLabel => 'Библиотека';

  @override
  String get videoEditorTextLabel => 'Текст';

  @override
  String get videoEditorDrawLabel => 'Начертайте';

  @override
  String get videoEditorFilterLabel => 'Филтър';

  @override
  String get videoEditorAudioLabel => 'Аудио';

  @override
  String get videoEditorVolumeLabel => 'Обем';

  @override
  String get videoEditorAddTitle => 'Добави';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Отвори библиотеката';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Отвори аудио редактора';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Отвори текстовия редактор';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Отвори редактора за рисуване';

  @override
  String get videoEditorOpenFilterSemanticLabel =>
      'Отвори редактора на филтъра';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Отвори редактора на стикери';

  @override
  String get videoEditorSaveDraftTitle => 'Да запазим черновата?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Запази редакциите си за по-късно или ги отхвърлете и напуснете редактора.';

  @override
  String get videoEditorSaveDraftButton => 'Запазване на черновата';

  @override
  String get videoEditorDiscardChangesButton => 'Отхвърляне на промените';

  @override
  String get videoEditorKeepEditingButton => 'Продължете да редактирате';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Изтриване на зоната за падане на слоя';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Пуснете, за да изтриете слой';

  @override
  String get videoEditorDoneLabel => 'Готово';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Пускане или пауза на видео';

  @override
  String get videoEditorCropSemanticLabel => 'Изрязване';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Не можеш да разделиш клипа, докато се обработва. Изчакай малко.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Разделената позиция е невалидна. И двата клипа трябва да са дълги поне ${minDurationMs}ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Добави клип от библиотеката';

  @override
  String get videoEditorSaveSelectedClip => 'Запази избрания клип';

  @override
  String get videoEditorSplitClip => 'Разделен клип';

  @override
  String get videoEditorSaveClip => 'Запазване на клипа';

  @override
  String get videoEditorDeleteClip => 'Изтрий клип';

  @override
  String get videoEditorClipSavedSuccess => 'Клипът е запазен в библиотеката';

  @override
  String get videoEditorClipSaveFailed => 'Не успяхме да запазим клипа';

  @override
  String get videoEditorClipDeleted => 'Клипът е изтрит';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Избор на цвят';

  @override
  String get videoEditorUndoSemanticLabel => 'Отмяна';

  @override
  String get videoEditorRedoSemanticLabel => 'Повторете';

  @override
  String get videoEditorTextColorSemanticLabel => 'Цвят на текста';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Подравняване на текст';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Текстов фон';

  @override
  String get videoEditorFontSemanticLabel => 'Шрифт';

  @override
  String get videoEditorNoStickersFound => 'Няма намерени стикери';

  @override
  String get videoEditorNoStickersAvailable => 'Няма налични стикери';

  @override
  String get videoEditorFailedLoadStickers => 'Не успяхме да заредим стикерите';

  @override
  String get videoEditorAdjustVolumeTitle => 'Регулирайте силата на звука';

  @override
  String get videoEditorRecordedAudioLabel => 'Записано аудио';

  @override
  String get videoEditorCustomAudioLabel => 'Персонализирано аудио';

  @override
  String get videoEditorPlaySemanticLabel => 'Играйте';

  @override
  String get videoEditorPauseSemanticLabel => 'Пауза';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Заглушаване на звука';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Включване на звука';

  @override
  String get videoEditorDeleteLabel => 'Изтрий';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Изтриване на избрания елемент';

  @override
  String get videoEditorEditLabel => 'Редактиране';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Редактиране на избрания елемент';

  @override
  String get videoEditorDuplicateLabel => 'Дубликат';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Дублиране на избрания елемент';

  @override
  String get videoEditorSplitLabel => 'Сплит';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Разделете избрания клип';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Завършете редактирането на времевата линия';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'Пусни предварителен преглед';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Пауза на прегледа';

  @override
  String get videoEditorAudioUntitledSound => 'Звук без заглавие';

  @override
  String get videoEditorAudioUntitled => 'Без заглавие';

  @override
  String get videoEditorAudioAddAudio => 'Добави аудио';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Няма налични звуци';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Звуците ще се появят тук, когато творците споделят аудио';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Не успяхме да заредим звуците';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Избери аудио сегмента за видеото си';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Общност';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Инструмент със стрелка';

  @override
  String get videoEditorDrawToolEraserSemanticLabel =>
      'Инструмент за изтриване';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Инструмент за маркер';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Инструмент молив';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Пренареждане на слой $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Задръжте за пренареждане';

  @override
  String get videoEditorShowTimelineSemanticLabel =>
      'Показване на времевата линия';

  @override
  String get videoEditorHideTimelineSemanticLabel =>
      'Скриване на времевата линия';

  @override
  String get videoEditorFeedPreviewContent =>
      'Избягвайте да поставяте съдържание зад тези области.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Оригинали';

  @override
  String get videoEditorStickerSearchHint => 'Търсене на стикери...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Избери шрифт';

  @override
  String get videoEditorFontUnknown => 'Неизвестен';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Главата за възпроизвеждане трябва да е в рамките на избрания клип, за да се раздели.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Подстригване начало';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Подстригване на края';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel =>
      'Подстригване на клипса';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Плъзни дръжките, за да настроиш дължината на клипа';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Плъзгане на клип $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Клип $index от $total, $duration секунди';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Натисни дълго, за да пренаредиш';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Докосни за редактиране. Задръжте и плъзнете, за да пренаредите.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Преместете се наляво';

  @override
  String get videoEditorTimelineClipMoveRight => 'Преместете се надясно';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Натисни дълго, за да плъзнеш';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Времева линия на видео';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, избрано';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Затворете инструмента за избор на цвят';

  @override
  String get videoEditorPickColorTitle => 'Избери цвят';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Потвърдете цвета';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Наситеност и яркост';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Наситеност $saturation%, яркост $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Нюанс';

  @override
  String get videoEditorAddElementSemanticLabel => 'Добави елемент';

  @override
  String get videoEditorCloseSemanticLabel => 'Затвори';

  @override
  String get videoEditorDoneSemanticLabel => 'Готово';

  @override
  String get videoEditorLevelSemanticLabel => 'Ниво';

  @override
  String get videoMetadataBackSemanticLabel => 'Назад';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Отхвърляне на диалоговия прозорец за помощ';

  @override
  String get videoMetadataGotItButton => 'Разбрах!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Лимитът от 64 KB е достигнат. Премахни малко съдържание, за да продължиш.';

  @override
  String get videoMetadataExpirationLabel => 'Изтичане';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Избери време на изтичане';

  @override
  String get videoMetadataTitleLabel => 'Заглавие';

  @override
  String get videoMetadataDescriptionLabel => 'Описание';

  @override
  String get videoMetadataTagsLabel => 'Етикети';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Изтрий';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Изтриване на маркер $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Предупреждение за съдържание';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Избери предупреждения за съдържание';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Избери всичко, което важи за съдържанието ти';

  @override
  String get videoMetadataContentWarningDoneButton => 'Готово';

  @override
  String get videoMetadataCollaboratorsLabel => 'Сътрудници';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Поканете сътрудник';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Как работят сътрудниците';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max сътрудници';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Премахни сътрудник';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Сътрудниците са поканени като съавтори на тази публикация. Можеш да поканиш само хора, с които взаимно се следвате, и те се показват като сътрудници, след като потвърдят.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Взаимни последователи';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Трябва с $name да се следвате взаимно, за да поканиш този човек като сътрудник.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Вдъхновено от';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Комплект, вдъхновен от';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Как работят кредитите за вдъхновение';

  @override
  String get videoMetadataInspiredByNone => 'Няма';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Използвай това за признание. „Вдъхновено от“ е различно от сътрудници: показва влияние, но не отбелязва човека като съавтор.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Този творец не може да бъде посочен.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Премахни вдъхновен от';

  @override
  String get videoMetadataPostDetailsTitle => 'Детайли за публикацията';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Запазено в библиотека';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Не успяхме да запазим';

  @override
  String get videoMetadataGoToLibraryButton => 'Отидете в библиотеката';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Бутон за запазване за по-късно';

  @override
  String get videoMetadataRenderingVideoHint => 'Изобразява се видео...';

  @override
  String get videoMetadataSavingVideoHint => 'Видеото се запазва...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Запази видеото в чернови и $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Запазване за по-късно';

  @override
  String get videoMetadataPostSemanticLabel => 'Бутон за публикуване';

  @override
  String get videoMetadataPublishVideoHint => 'Публикувай видео във фийда';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Попълни формата, за да продължиш';

  @override
  String get videoMetadataPostButton => 'Публикувай';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Отвори прегледа на публикацията';

  @override
  String get videoMetadataShareTitle => 'Сподели';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Детайли за видеото';

  @override
  String get videoMetadataClassicDoneButton => 'Готово';

  @override
  String get videoMetadataPlayPreviewSemanticLabel =>
      'Пусни предварителен преглед';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Пауза на прегледа';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Затворете визуализацията на видеото';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Премахни';

  @override
  String get metadataCaptionsLabel => 'Надписи';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Субтитрите са включени за всички видеа';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Субтитрите са изключени за всички видеа';

  @override
  String get fullscreenFeedRemovedMessage => 'Видеото е премахнато';

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
