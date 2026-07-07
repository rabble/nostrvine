// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

  @override
  String get feedTuningMoreLabel => 'Więcej takich';

  @override
  String get feedTuningLessLabel => 'Mniej takich';

  @override
  String get feedTuningUndo => 'Cofnij';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Otwórz przywołane wideo';

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Ustawienia';

  @override
  String get settingsSecureAccount => 'Zabezpiecz konto';

  @override
  String get settingsSessionExpired => 'Sesja wygasła';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Zaloguj się ponownie, żeby odzyskać pełny dostęp';

  @override
  String get settingsCreatorAnalytics => 'Statystyki twórcy';

  @override
  String get settingsSupportCenter => 'Centrum pomocy';

  @override
  String get settingsNotifications => 'Powiadomienia';

  @override
  String get settingsContentPreferences => 'Preferencje treści';

  @override
  String get settingsModerationControls => 'Ustawienia moderacji';

  @override
  String get settingsBlueskyPublishing => 'Publikowanie na Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Zarządzaj crosspostingiem na Bluesky';

  @override
  String get settingsNostrSettings => 'Ustawienia Nostr';

  @override
  String get settingsIntegratedApps => 'Zintegrowane aplikacje';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Zatwierdzone aplikacje innych firm działające wewnątrz Divine';

  @override
  String get settingsExperimentalFeatures => 'Funkcje eksperymentalne';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Nowinki, które mogą czkać—wypróbuj je, jeśli jesteś ciekawski.';

  @override
  String get settingsLegal => 'Informacje prawne';

  @override
  String get settingsIntegrationPermissions => 'Uprawnienia integracji';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Przejrzyj i cofnij zapamiętane zgody na integracje';

  @override
  String settingsVersion(String version) {
    return 'Wersja $version';
  }

  @override
  String get settingsVersionEmpty => 'Wersja';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Tryb dewelopera jest już włączony';

  @override
  String get settingsDeveloperModeEnabled => 'Tryb dewelopera włączony!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Jeszcze $count dotknięcia, żeby włączyć tryb dewelopera',
      many: 'Jeszcze $count dotknięć, żeby włączyć tryb dewelopera',
      few: 'Jeszcze $count dotknięcia, żeby włączyć tryb dewelopera',
      one: 'Jeszcze 1 dotknięcie, żeby włączyć tryb dewelopera',
    );
    return '$_temp0';
  }

  @override
  String get settingsInvites => 'Zaproszenia';

  @override
  String get settingsSwitchAccount => 'Przełącz konto';

  @override
  String get settingsAddAnotherAccount => 'Dodaj kolejne konto';

  @override
  String get settingsUnsavedDraftsTitle => 'Niezapisane wersje robocze';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'wersji roboczych',
      one: 'wersji roboczej',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'je',
      one: 'ją',
    );
    return 'Masz $count niezapisanych $_temp0. Przełączenie kont zachowa $_temp1, ale możesz chcieć je najpierw opublikować lub przejrzeć.';
  }

  @override
  String get settingsCancel => 'Anuluj';

  @override
  String get settingsSwitchAnyway => 'Przełącz mimo to';

  @override
  String get settingsAppVersionLabel => 'Wersja aplikacji';

  @override
  String get settingsAppLanguage => 'Język aplikacji';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (domyślny język urządzenia)';
  }

  @override
  String get settingsAppLanguageTitle => 'Język aplikacji';

  @override
  String get settingsAppLanguageDescription =>
      'Wybierz język interfejsu aplikacji';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Użyj języka urządzenia';

  @override
  String get settingsGeneralTitle => 'Ustawienia ogólne';

  @override
  String get settingsContentSafetyTitle => 'Treści i bezpieczeństwo';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRACJE';

  @override
  String get generalSettingsSectionViewing => 'OGLĄDANIE';

  @override
  String get generalSettingsSectionCreating => 'TWORZENIE';

  @override
  String get generalSettingsSectionApp => 'APLIKACJA';

  @override
  String get generalSettingsClosedCaptions => 'Napisy';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Pokazuj napisy, gdy filmy je zawierają';

  @override
  String get generalSettingsVideoShape => 'Kształt filmu';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Tylko kwadratowe filmy';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait =>
      'Kwadratowe i pionowe';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Pokazuj pełny miks filmów Divine';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Trzymaj feedy w klasycznym kwadratowym formacie';

  @override
  String get contentPreferencesTitle => 'Preferencje treści';

  @override
  String get contentPreferencesContentFilters => 'Filtry treści';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Zarządzaj filtrami ostrzeżeń o treściach';

  @override
  String get contentPreferencesContentLanguage => 'Język treści';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (domyślny język urządzenia)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Oznaczaj swoje filmy językiem, żeby widzowie mogli filtrować treści.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Użyj języka urządzenia (domyślnie)';

  @override
  String get contentPreferencesAudioSharing =>
      'Udostępniaj moje audio do ponownego użycia';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Gdy włączone, inni mogą używać dźwięku z twoich filmów';

  @override
  String get contentPreferencesAccountLabels => 'Etykiety konta';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Oznacz swoje treści';

  @override
  String get contentPreferencesAccountContentLabels => 'Etykiety treści konta';

  @override
  String get contentPreferencesClearAll => 'Wyczyść wszystko';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Zaznacz wszystkie pasujące do twojego konta';

  @override
  String get contentPreferencesDoneNoLabels => 'Gotowe (bez etykiet)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Gotowe (wybrano $count)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Urządzenie wejścia audio';

  @override
  String get contentPreferencesAutoRecommended => 'Automatycznie (zalecane)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Automatycznie wybiera najlepszy mikrofon';

  @override
  String get contentPreferencesSelectAudioInput => 'Wybierz wejście audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Nieznany mikrofon';

  @override
  String get contentFiltersAdultContent => 'TREŚCI DLA DOROSŁYCH';

  @override
  String get contentFiltersViolenceGore => 'PRZEMOC I DRASTYCZNE SCENY';

  @override
  String get contentFiltersSubstances => 'SUBSTANCJE';

  @override
  String get contentFiltersOther => 'INNE';

  @override
  String get contentFiltersAgeGateMessage =>
      'Zweryfikuj wiek w Bezpieczeństwie i prywatności, żeby odblokować filtry treści dla dorosłych';

  @override
  String get contentFiltersShow => 'Pokazuj';

  @override
  String get contentFiltersWarn => 'Ostrzegaj';

  @override
  String get contentFiltersFilterOut => 'Filtruj';

  @override
  String get profileBlockedAccountNotAvailable => 'To konto jest niedostępne';

  @override
  String get profileInvalidId => 'Nieprawidłowy ID profilu';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Sprawdź $displayName na Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName na Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Nie udało się udostępnić profilu: $error';
  }

  @override
  String get profileEditProfile => 'Edytuj profil';

  @override
  String get profileCreatorAnalytics => 'Statystyki twórcy';

  @override
  String get profileShareProfile => 'Udostępnij profil';

  @override
  String get profileCopyPublicKey => 'Skopiuj klucz publiczny (npub)';

  @override
  String get profileGetEmbedCode => 'Pobierz kod do osadzenia';

  @override
  String get profilePublicKeyCopied => 'Klucz publiczny skopiowany do schowka';

  @override
  String get profileEmbedCodeCopied => 'Kod do osadzenia skopiowany do schowka';

  @override
  String get profileRefreshTooltip => 'Odśwież';

  @override
  String get profileRefreshSemanticLabel => 'Odśwież profil';

  @override
  String get profileMoreTooltip => 'Więcej';

  @override
  String get profileMoreSemanticLabel => 'Więcej opcji';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Zamknij awatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Zamknij podgląd awatara';

  @override
  String get profileFollowingLabel => 'Obserwujesz';

  @override
  String get profileFollowLabel => 'Obserwuj';

  @override
  String get profileBlockedLabel => 'Zablokowany';

  @override
  String get profileFollowersLabel => 'Obserwujących';

  @override
  String get profileFollowingStatLabel => 'Obserwowanych';

  @override
  String get profileVideosLabel => 'Filmy';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia dla współtwórców wciąż czeka na wysłanie',
      many: '$count zaproszeń dla współtwórców wciąż czeka na wysłanie',
      few: '$count zaproszenia dla współtwórców wciąż czekają na wysłanie',
      one: '1 zaproszenie dla współtwórcy wciąż czeka na wysłanie',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Zaproszenie zostało w kolejce. Ponów je tutaj.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'Dla „$title”. Ponów je tutaj.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Ponów';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Ponawianie';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Ponawianie zaproszenia dla współtwórcy jest teraz niedostępne.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia dla współtwórców wciąż czeka na wysłanie.',
      many: '$count zaproszeń dla współtwórców wciąż czeka na wysłanie.',
      few: '$count zaproszenia dla współtwórców wciąż czekają na wysłanie.',
      one: '1 zaproszenie dla współtwórcy wciąż czeka na wysłanie.',
      zero: 'Zaproszenia dla współtwórców wysłane.',
    );
    return '$_temp0';
  }

  @override
  String profileCollaboratorInviteBlockedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count współtwórcy nie może otrzymywać zaproszeń.',
      many: '$count współtwórców nie może otrzymywać zaproszeń.',
      few: '$count współtwórcy nie mogą otrzymywać zaproszeń.',
      one: '1 współtwórca nie może otrzymywać zaproszeń.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count użytkownika',
      many: '$count użytkowników',
      few: '$count użytkowników',
      one: '1 użytkownik',
    );
    return '$_temp0';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Zablokować $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Gdy blokujesz użytkownika:';

  @override
  String get profileBlockBulletHidePosts =>
      'Jego posty nie będą pojawiać się w twoich kanałach.';

  @override
  String get profileBlockBulletCantView =>
      'Nie będzie mógł zobaczyć twojego profilu, obserwować cię ani oglądać twoich postów.';

  @override
  String get profileBlockBulletNoNotify =>
      'Nie zostanie powiadomiony o tej zmianie.';

  @override
  String get profileBlockBulletYouCanView =>
      'Wciąż będziesz mógł zobaczyć jego profil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Zablokuj $displayName';
  }

  @override
  String get profileCancelButton => 'Anuluj';

  @override
  String get profileLearnMore => 'Dowiedz się więcej';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Odblokować $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Gdy odblokujesz tego użytkownika:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Jego posty pojawią się w twoich kanałach.';

  @override
  String get profileUnblockBulletCanView =>
      'Będzie mógł zobaczyć twój profil, obserwować cię i oglądać twoje posty.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Nie zostanie powiadomiony o tej zmianie.';

  @override
  String get profileLearnMoreAt => 'Dowiedz się więcej na ';

  @override
  String get profileUnblockButton => 'Odblokuj';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Przestań obserwować $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Zablokuj $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Odblokuj $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Zgłoś $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Dodaj $displayName do listy';
  }

  @override
  String get profileUserBlockedTitle => 'Użytkownik zablokowany';

  @override
  String get profileUserBlockedContent =>
      'Nie będziesz widzieć treści tego użytkownika w swoich kanałach.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Możesz go odblokować w dowolnej chwili z jego profilu lub w Ustawienia > Bezpieczeństwo.';

  @override
  String get profileCloseButton => 'Zamknij';

  @override
  String get profileNoCollabsTitle => 'Brak współprac';

  @override
  String get profileCollabsOwnEmpty =>
      'Filmy, przy których współpracujesz, pojawią się tutaj';

  @override
  String get profileCollabsOtherEmpty =>
      'Filmy, przy których współpracuje, pojawią się tutaj';

  @override
  String get profileErrorLoadingCollabs =>
      'Błąd wczytywania filmów ze współprac';

  @override
  String get profileNoSavedVideosTitle => 'Nic jeszcze nie zapisano';

  @override
  String get profileSavedOwnEmpty =>
      'Dodawaj filmy do zakładek z menu udostępniania, a pojawią się tutaj.';

  @override
  String get profileErrorLoadingSaved => 'Błąd wczytywania zapisanych filmów';

  @override
  String get profileNoCommentsOwnTitle => 'Brak komentarzy';

  @override
  String get profileNoCommentsOtherTitle => 'Brak komentarzy';

  @override
  String get profileCommentsOwnEmpty =>
      'Twoje komentarze i odpowiedzi pojawią się tutaj';

  @override
  String get profileCommentsOtherEmpty =>
      'Jego komentarze i odpowiedzi pojawią się tutaj';

  @override
  String get profileErrorLoadingComments => 'Błąd wczytywania komentarzy';

  @override
  String get profileVideoRepliesSection => 'Odpowiedzi wideo';

  @override
  String get profileCommentsSection => 'Komentarze';

  @override
  String get profileEditLabel => 'Edytuj';

  @override
  String get profileLibraryLabel => 'Biblioteka';

  @override
  String get profileNoLikedVideosTitle => 'Brak polubionych filmów';

  @override
  String get profileLikedOwnEmpty =>
      'Polubione przez ciebie filmy pojawią się tutaj';

  @override
  String get profileLikedOtherEmpty =>
      'Polubione przez niego filmy pojawią się tutaj';

  @override
  String get profileErrorLoadingLiked => 'Błąd wczytywania polubionych filmów';

  @override
  String get profileNoRepostsTitle => 'Brak repostów';

  @override
  String get profileRepostsOwnEmpty => 'Twoje reposty pojawią się tutaj';

  @override
  String get profileRepostsOtherEmpty => 'Jego reposty pojawią się tutaj';

  @override
  String get profileErrorLoadingReposts =>
      'Błąd wczytywania repostowanych filmów';

  @override
  String get profileNoVideosTitle => 'Brak filmów';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Udostępnij swój pierwszy film, żeby go tu zobaczyć';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Ten użytkownik nie udostępnił jeszcze żadnych filmów';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura filmu $number';
  }

  @override
  String get profileShowMore => 'Pokaż więcej';

  @override
  String get profileShowLess => 'Pokaż mniej';

  @override
  String get profileCompleteYourProfile => 'Uzupełnij swój profil';

  @override
  String get profileCompleteSubtitle =>
      'Dodaj imię, bio i zdjęcie, żeby zacząć';

  @override
  String get profileSetUpButton => 'Skonfiguruj';

  @override
  String get profileVerifyingEmail => 'Weryfikowanie e-maila...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Sprawdź $email w poszukiwaniu linku weryfikacyjnego';
  }

  @override
  String get profileWaitingForVerification => 'Czekam na weryfikację e-maila';

  @override
  String get profileVerificationFailed => 'Weryfikacja nieudana';

  @override
  String get profilePleaseTryAgain => 'Spróbuj ponownie';

  @override
  String get profileSecureYourAccount => 'Zabezpiecz konto';

  @override
  String get profileSecureSubtitle =>
      'Dodaj e-mail i hasło, żeby odzyskać konto na dowolnym urządzeniu';

  @override
  String get profileRetryButton => 'Spróbuj ponownie';

  @override
  String get profileRegisterButton => 'Zarejestruj się';

  @override
  String get profileSessionExpired => 'Sesja wygasła';

  @override
  String get profileSignInToRestore =>
      'Zaloguj się ponownie, żeby odzyskać pełny dostęp';

  @override
  String get profileSignInButton => 'Zaloguj się';

  @override
  String get profileMaybeLaterLabel => 'Może później';

  @override
  String get profileSecurePrimaryButton => 'Dodaj e-mail i hasło';

  @override
  String get profileCompletePrimaryButton => 'Uzupełnij swój profil';

  @override
  String get profileLoopsLabel => 'Loopy';

  @override
  String get profileLikesLabel => 'Polubienia';

  @override
  String get profileMyLibraryLabel => 'Moja biblioteka';

  @override
  String get profileMessageLabel => 'Wiadomość';

  @override
  String get profileUserFallback => 'użytkownik';

  @override
  String get profileDismissTooltip => 'Odrzuć';

  @override
  String get profileLinkCopied => 'Link do profilu skopiowany';

  @override
  String get profileSetupEditProfileTitle => 'Edytuj profil';

  @override
  String get profileSetupBackLabel => 'Wstecz';

  @override
  String get profileSetupAboutNostr => 'O Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil opublikowany pomyślnie!';

  @override
  String get profileSetupCreateNewProfile => 'Utworzyć nowy profil?';

  @override
  String get profileSetupNoExistingProfile =>
      'Nie znaleźliśmy istniejącego profilu na twoich przekaźnikach. Publikacja utworzy nowy profil. Kontynuować?';

  @override
  String get profileSetupPublishButton => 'Opublikuj';

  @override
  String get profileSetupUsernameTaken =>
      'Nazwa użytkownika została właśnie zajęta. Wybierz inną.';

  @override
  String get profileSetupClaimFailed =>
      'Nie udało się zarezerwować nazwy użytkownika. Spróbuj ponownie.';

  @override
  String get profileSetupPublishFailed =>
      'Nie udało się opublikować profilu. Spróbuj ponownie.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Nie można połączyć się z siecią. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get profileSetupRetryLabel => 'Spróbuj ponownie';

  @override
  String get profileSetupDisplayNameLabel => 'Nazwa wyświetlana';

  @override
  String get profileSetupDisplayNameHint => 'Jak ludzie mają cię rozpoznawać?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Dowolna nazwa lub etykieta. Nie musi być unikalna.';

  @override
  String get profileSetupDisplayNameRequired => 'Wprowadź nazwę wyświetlaną';

  @override
  String get profileSetupBioLabel => 'Bio (opcjonalnie)';

  @override
  String get profileSetupBioHint => 'Powiedz coś o sobie...';

  @override
  String get profileSetupWebsiteLabel => 'Website (Optional)';

  @override
  String get profileSetupWebsiteHint => 'https://yoursite.com';

  @override
  String get profileSetupPublicKeyLabel => 'Klucz publiczny (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nazwa użytkownika (opcjonalnie)';

  @override
  String get profileSetupUsernameHint => 'nazwa_uzytkownika';

  @override
  String get profileSetupUsernameHelper => 'Twoja unikalna tożsamość na Divine';

  @override
  String get profileSetupProfileColorLabel => 'Kolor profilu (opcjonalnie)';

  @override
  String get profileSetupSaveButton => 'Zapisz';

  @override
  String get profileSetupSavingButton => 'Zapisywanie...';

  @override
  String get profileSetupImageUrlTitle => 'Dodaj URL obrazu';

  @override
  String get profileSetupPictureUploaded =>
      'Zdjęcie profilowe przesłane pomyślnie!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Wybór obrazu nieudany. Wklej URL obrazu poniżej.';

  @override
  String get profileSetupImagesTypeGroup => 'obrazy';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Dostęp do aparatu nieudany: $error';
  }

  @override
  String get profileSetupGotItButton => 'Rozumiem';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Nie udało się przesłać obrazu. Spróbuj ponownie później.';

  @override
  String get profileSetupUploadNetworkError =>
      'Błąd sieci: Sprawdź połączenie z internetem i spróbuj ponownie.';

  @override
  String get profileSetupUploadAuthError =>
      'Błąd uwierzytelnienia: Wyloguj się i zaloguj ponownie.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Plik za duży: Wybierz mniejszy obraz (maks. 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Nie udało się przesłać obrazu. Nasze serwery są tymczasowo niedostępne. Spróbuj ponownie za chwilę.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Przesyłanie zdjęcia profilowego nie jest jeszcze dostępne w wersji webowej. Użyj aplikacji na iOS lub Androida albo wklej URL obrazu.';

  @override
  String get profileSetupBannerSectionTitle => 'Baner';

  @override
  String get profileSetupBannerUploadButton => 'Prześlij zdjęcie';

  @override
  String get profileSetupBannerClearButton => 'Wyczyść baner';

  @override
  String get profileSetupBannerUploadSuccess => 'Baner zaktualizowany';

  @override
  String get profileSetupUsernameChecking => 'Sprawdzanie dostępności...';

  @override
  String get profileSetupUsernameAvailable => 'Nazwa użytkownika dostępna!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Nazwa użytkownika już zajęta';

  @override
  String get profileSetupUsernameReserved =>
      'Nazwa użytkownika jest zarezerwowana';

  @override
  String get profileSetupContactSupport => 'Skontaktuj się z pomocą';

  @override
  String get profileSetupCheckAgain => 'Sprawdź ponownie';

  @override
  String get profileSetupUsernameBurned =>
      'Ta nazwa użytkownika nie jest już dostępna';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Dozwolone są tylko litery, cyfry i myślniki';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Nazwa użytkownika musi mieć od 3 do 63 znaków';

  @override
  String get profileSetupUsernameNetworkError =>
      'Nie można sprawdzić dostępności. Spróbuj ponownie.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Nieprawidłowy format nazwy użytkownika';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Nie udało się sprawdzić dostępności';

  @override
  String get profileSetupUsernameReservedTitle =>
      'Nazwa użytkownika zarezerwowana';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Nazwa $username jest zarezerwowana. Powiedz nam, dlaczego ma należeć do ciebie.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'np. To moja nazwa marki, pseudonim sceniczny itp.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Już kontaktowałeś się z pomocą? Dotknij \"Sprawdź ponownie\", żeby zobaczyć, czy została ci przyznana.';

  @override
  String get profileSetupSupportRequestSent =>
      'Prośba o pomoc wysłana! Odezwiemy się wkrótce.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Nie można otworzyć e-maila. Wyślij na: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Wyślij prośbę';

  @override
  String get profileSetupPickColorTitle => 'Wybierz kolor';

  @override
  String get profileSetupSelectButton => 'Wybierz';

  @override
  String get profileSetupUseOwnNip05 => 'Użyj własnego adresu NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Adres NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Nieprawidłowy format NIP-05 (np. nazwa@domena.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Użyj pola nazwy użytkownika powyżej dla divine.video';

  @override
  String get nostrSettingsNip05Address => 'NIP-05 address';

  @override
  String get nostrSettingsNip05AddressSubtitle =>
      'Use your divine.video username, or point your handle at a NIP-05 address on a domain you control.';

  @override
  String get nostrSettingsNip05AddressHint => 'you@example.com';

  @override
  String get nostrSettingsNip05SaveAction => 'Save NIP-05';

  @override
  String get nostrSettingsNip05Saved => 'NIP-05 saved';

  @override
  String get nostrSettingsNip05SaveFailed =>
      'Couldn\'t save NIP-05. Please try again.';

  @override
  String get profileSetupNip05ConfirmTitle => 'Use your own NIP-05?';

  @override
  String get profileSetupNip05ConfirmBody =>
      'NIP-05 maps a name like you@yourdomain.com to your Nostr identity. You need to control the domain and host a verification file at the right path. If it\'s wrong, people can\'t find you and your verified handle disappears. Continue only if you\'ve set this up.';

  @override
  String get profileSetupNip05ConfirmContinue => 'Continue';

  @override
  String get profileSetupNip05ConfirmCancel => 'Cancel';

  @override
  String get profileSetupProfilePicturePreview => 'Podgląd zdjęcia profilowego';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine jest zbudowane na Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' otwartym protokole odpornym na cenzurę, który pozwala ludziom komunikować się online bez polegania na pojedynczej firmie czy platformie. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Gdy rejestrujesz się w Divine, otrzymujesz nową tożsamość Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr pozwala ci posiadać swoje treści, tożsamość i graf społeczny, których możesz używać w wielu aplikacjach. Efekt: więcej wyboru, mniej zamknięcia, zdrowszy i bardziej odporny społecznościowy internet.';

  @override
  String get nostrInfoLingo => 'Słownictwo Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Twój publiczny adres Nostr. Można go bezpiecznie udostępniać i pozwala innym znaleźć, obserwować lub napisać do ciebie w aplikacjach Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Twój klucz prywatny i dowód własności. Daje pełną kontrolę nad twoją tożsamością Nostr, więc ';

  @override
  String get nostrInfoNsecWarning => 'zawsze trzymaj go w tajemnicy!';

  @override
  String get nostrInfoUsernameLabel => 'Nazwa użytkownika Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Czytelna nazwa (jak @imie.divine.video), która linkuje do twojego npub. Ułatwia rozpoznanie i weryfikację twojej tożsamości Nostr, podobnie jak adres e-mail.';

  @override
  String get nostrInfoLearnMoreAt => 'Dowiedz się więcej na ';

  @override
  String get nostrInfoGotIt => 'Rozumiem!';

  @override
  String get profileTabRefreshTooltip => 'Odśwież';

  @override
  String get videoGridRefreshLabel => 'Szukanie większej liczby filmów';

  @override
  String get videoGridOptionsTitle => 'Opcje filmu';

  @override
  String get videoGridEditVideo => 'Edytuj film';

  @override
  String get videoGridEditVideoSubtitle => 'Zaktualizuj tytuł, opis i hashtagi';

  @override
  String get videoGridDeleteVideo => 'Usuń film';

  @override
  String get videoGridDeleteVideoSubtitle => 'Trwale usuń tę treść';

  @override
  String get videoGridDeleteConfirmTitle => 'Usuń film';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Na pewno chcesz usunąć ten film?';

  @override
  String get videoGridDeleteConfirmNote =>
      'To wyślе żądanie usunięcia (NIP-09) do wszystkich przekaźników. Niektóre przekaźniki mogą nadal zachować treść.';

  @override
  String get videoGridDeleteCancel => 'Anuluj';

  @override
  String get videoGridDeleteConfirm => 'Usuń';

  @override
  String get videoGridDeletingContent => 'Usuwanie treści...';

  @override
  String get videoGridDeleteSuccess => 'Żądanie usunięcia wysłane pomyślnie';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Nie udało się usunąć treści: $error';
  }

  @override
  String get exploreTabClassics => 'Klasyki';

  @override
  String get exploreTabNew => 'Nowe';

  @override
  String get exploreTabPopular => 'Popularne';

  @override
  String get exploreTabCategories => 'Kategorie';

  @override
  String get exploreTabForYou => 'Dla ciebie';

  @override
  String get exploreTabLists => 'Listy';

  @override
  String get exploreTabIntegratedApps => 'Zintegrowane aplikacje';

  @override
  String get exploreNoVideosAvailable => 'Brak dostępnych filmów';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Błąd: $error';
  }

  @override
  String get exploreDiscoverLists => 'Odkrywaj listy';

  @override
  String get exploreAboutLists => 'O listach';

  @override
  String get exploreAboutListsDescription =>
      'Listy pomagają ci porządkować i kuratorować treści Divine na dwa sposoby:';

  @override
  String get explorePeopleLists => 'Listy osób';

  @override
  String get explorePeopleListsDescription =>
      'Obserwuj grupy twórców i zobacz ich najnowsze filmy';

  @override
  String get exploreVideoLists => 'Listy filmów';

  @override
  String get exploreVideoListsDescription =>
      'Twórz playlisty ulubionych filmów do oglądania później';

  @override
  String get exploreMyLists => 'Moje listy';

  @override
  String get exploreSubscribedLists => 'Subskrybowane listy';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Błąd wczytywania list: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nowego filmu',
      many: '$count nowych filmów',
      few: '$count nowe filmy',
      one: '1 nowy film',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nowego filmu',
      many: '$count nowych filmów',
      few: '$count nowe filmy',
      one: '1 nowy film',
    );
    return 'Wczytaj $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Wczytywanie filmu...';

  @override
  String get videoPlayerPlayVideo => 'Odtwórz film';

  @override
  String get videoPlayerMute => 'Wycisz film';

  @override
  String get videoPlayerUnmute => 'Włącz dźwięk filmu';

  @override
  String get videoPlayerEditVideo => 'Edytuj film';

  @override
  String get videoPlayerEditVideoTooltip => 'Edytuj film';

  @override
  String get videoPlayerTapHint =>
      'Dotknij, aby odtworzyć lub wstrzymać. Dotknij dwukrotnie, aby polubić.';

  @override
  String get videoSettingsMenuOpen => 'Otwórz ustawienia odtwarzania';

  @override
  String get videoSettingsMenuClose => 'Zamknij ustawienia odtwarzania';

  @override
  String get videoSettingsCaptionsEnable => 'Włącz napisy';

  @override
  String get videoSettingsCaptionsDisable => 'Wyłącz napisy';

  @override
  String get contentWarningLabel => 'Ostrzeżenie o treści';

  @override
  String get contentWarningNudity => 'Nagość';

  @override
  String get contentWarningSexualContent => 'Treści seksualne';

  @override
  String get contentWarningPornography => 'Pornografia';

  @override
  String get contentWarningGraphicMedia => 'Drastyczne media';

  @override
  String get contentWarningViolence => 'Przemoc';

  @override
  String get contentWarningSelfHarm => 'Samookaleczenie';

  @override
  String get contentWarningDrugUse => 'Narkotyki';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tytoń';

  @override
  String get contentWarningGambling => 'Hazard';

  @override
  String get contentWarningProfanity => 'Wulgarny język';

  @override
  String get contentWarningFlashingLights => 'Migające światła';

  @override
  String get contentWarningAiGenerated => 'Wygenerowane przez AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Wrażliwe treści';

  @override
  String get contentWarningDescNudity => 'Zawiera nagość lub częściową nagość';

  @override
  String get contentWarningDescSexual => 'Zawiera treści seksualne';

  @override
  String get contentWarningDescPorn => 'Zawiera jawnie pornograficzne treści';

  @override
  String get contentWarningDescGraphicMedia =>
      'Zawiera drastyczne lub niepokojące obrazy';

  @override
  String get contentWarningDescViolence => 'Zawiera treści z przemocą';

  @override
  String get contentWarningDescSelfHarm =>
      'Zawiera odniesienia do samookaleczenia';

  @override
  String get contentWarningDescDrugs => 'Zawiera treści związane z narkotykami';

  @override
  String get contentWarningDescAlcohol => 'Zawiera treści związane z alkoholem';

  @override
  String get contentWarningDescTobacco => 'Zawiera treści związane z tytoniem';

  @override
  String get contentWarningDescGambling => 'Zawiera treści związane z hazardem';

  @override
  String get contentWarningDescProfanity => 'Zawiera mocny język';

  @override
  String get contentWarningDescFlashingLights =>
      'Zawiera migające światła (ostrzeżenie o fotowrażliwości)';

  @override
  String get contentWarningDescAiGenerated =>
      'Ta treść została wygenerowana przez AI';

  @override
  String get contentWarningDescSpoiler => 'Zawiera spoilery';

  @override
  String get contentWarningDescContentWarning =>
      'Twórca oznaczył to jako wrażliwe';

  @override
  String get contentWarningDescDefault => 'Twórca oflagował tę treść';

  @override
  String get contentWarningDetailsTitle => 'Ostrzeżenia o treściach';

  @override
  String get contentWarningDetailsSubtitle => 'Twórca zastosował te etykiety:';

  @override
  String get contentWarningManageFilters => 'Zarządzaj filtrami treści';

  @override
  String get contentWarningViewAnyway => 'Zobacz mimo to';

  @override
  String get contentWarningReportContentTooltip => 'Zgłoś treść';

  @override
  String get contentWarningBlockUserTooltip => 'Zablokuj użytkownika';

  @override
  String get contentWarningBlockedTitle => 'Treść zablokowana';

  @override
  String get contentWarningBlockedPolicy =>
      'Ta treść została zablokowana z powodu naruszenia zasad.';

  @override
  String get contentWarningNoticeTitle => 'Informacja o treści';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potencjalnie szkodliwa treść';

  @override
  String get contentWarningView => 'Zobacz';

  @override
  String get contentWarningReportAction => 'Zgłoś';

  @override
  String get contentWarningHideAllLikeThis => 'Ukrywaj wszystkie takie treści';

  @override
  String get contentWarningNoFilterYet =>
      'Brak zapisanego filtra dla tego ostrzeżenia.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Od teraz będziemy ukrywać takie posty.';

  @override
  String get videoErrorNotFound => 'Nie znaleziono filmu';

  @override
  String get videoErrorNetwork => 'Błąd sieci';

  @override
  String get videoErrorTimeout => 'Przekroczono czas wczytywania';

  @override
  String get videoErrorFormat =>
      'Błąd formatu filmu\n(Spróbuj ponownie lub użyj innej przeglądarki)';

  @override
  String get videoErrorUnsupportedFormat => 'Nieobsługiwany format filmu';

  @override
  String get videoErrorPlayback => 'Błąd odtwarzania filmu';

  @override
  String get videoErrorAgeRestricted => 'Treść z ograniczeniem wiekowym';

  @override
  String get videoErrorVerifyAge => 'Zweryfikuj wiek';

  @override
  String get videoErrorRetry => 'Spróbuj ponownie';

  @override
  String get videoErrorContentRestricted => 'Treść ograniczona';

  @override
  String get videoErrorContentRestrictedBody =>
      'Ten film został ograniczony przez przekaźnik.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Zweryfikuj swój wiek, żeby zobaczyć ten film.';

  @override
  String get videoErrorSkip => 'Pomiń';

  @override
  String get videoErrorVerifyAgeButton => 'Zweryfikuj wiek';

  @override
  String get videoErrorVerifyAgeFailed =>
      'Nie udało się zweryfikować Twojego wieku. Spróbuj ponownie.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Przekroczono czas weryfikacji. Sprawdź połączenie lub spróbuj ponownie za chwilę.';

  @override
  String get videoErrorAdultContentHidden =>
      'Treści dla dorosłych są wyłączone. Możesz je włączyć w Ustawienia → Filtry treści.';

  @override
  String videoDetailLoadError(String error) {
    return 'Nie udało się wczytać filmu: $error';
  }

  @override
  String get videoDetailContextTitle => 'Udostępniony film';

  @override
  String get videoDetailCloseSemanticLabel => 'Zamknij odtwarzacz wideo';

  @override
  String get videoFollowButtonFollowing => 'Obserwujesz';

  @override
  String get videoFollowButtonFollow => 'Obserwuj';

  @override
  String get audioAttributionOriginalSound => 'Oryginalny dźwięk';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Zainspirowane przez @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'z @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'z @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count współtwórcy',
      many: '$count współtwórców',
      few: '$count współtwórców',
      one: '1 współtwórca',
    );
    return '$_temp0. Dotknij, żeby zobaczyć profil.';
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
  String metadataHashtagChipTapHint(String hashtag) {
    return '#$hashtag. Dotknij, aby zobaczyć filmy z tym hashtagiem.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Udostępnij film';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post udostępniony z $recipientName';
  }

  @override
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Post udostępniony z $count osobami',
      many: 'Post udostępniony z $count osobami',
      few: 'Post udostępniony z $count osobami',
      one: 'Post udostępniony z $count osobą',
    );
    return '$_temp0';
  }

  @override
  String get shareFailedToSend => 'Nie udało się wysłać filmu';

  @override
  String get shareAddedToBookmarks => 'Dodano do zakładek';

  @override
  String get shareRemovedFromBookmarks => 'Usunięto z zakładek';

  @override
  String get shareFailedToAddBookmark => 'Nie udało się dodać zakładki';

  @override
  String get shareFailedToRemoveBookmark => 'Nie udało się usunąć zakładki';

  @override
  String get shareActionFailed => 'Akcja nieudana';

  @override
  String get shareWithTitle => 'Udostępnij z';

  @override
  String get shareFindPeople => 'Znajdź ludzi';

  @override
  String get shareFindPeopleMultiline => 'Znajdź\nludzi';

  @override
  String get shareSent => 'Wysłano';

  @override
  String get shareContactFallback => 'Kontakt';

  @override
  String get shareUserFallback => 'Użytkownik';

  @override
  String shareSelectedRecipientAnnouncement(String name) {
    return 'Wybrano $name';
  }

  @override
  String get shareMessageHint => 'Dodaj opcjonalną wiadomość...';

  @override
  String get videoActionUnlike => 'Cofnij polubienie';

  @override
  String get videoActionLike => 'Polub film';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Polub';

  @override
  String get videoActionReplyLabel => 'Odpowiedz';

  @override
  String get videoActionRepostLabel => 'Repostuj';

  @override
  String get videoActionShareLabel => 'Udostępnij';

  @override
  String get videoActionReportLabel => 'Zgłoś';

  @override
  String get videoActionReport => 'Zgłoś wideo';

  @override
  String get videoActionEditLabel => 'Edytuj';

  @override
  String get videoActionEdit => 'Edytuj wideo';

  @override
  String get videoActionAboutLabel => 'O filmie';

  @override
  String get videoActionEnableAutoAdvance =>
      'Włącz automatyczne przechodzenie dalej';

  @override
  String get videoActionDisableAutoAdvance =>
      'Wyłącz automatyczne przechodzenie dalej';

  @override
  String get videoActionRemoveRepost => 'Usuń repost';

  @override
  String get videoActionRepost => 'Repostuj film';

  @override
  String get videoActionViewComments => 'Zobacz komentarze';

  @override
  String get videoActionMoreOptions => 'Więcej opcji';

  @override
  String get videoActionHideSubtitles => 'Ukryj napisy';

  @override
  String get videoActionShowSubtitles => 'Pokaż napisy';

  @override
  String get videoEngagementLikersTitle => 'Polubione przez';

  @override
  String get videoEngagementRepostersTitle => 'Udostępnione przez';

  @override
  String get videoEngagementLikersEmpty => 'Brak polubień';

  @override
  String get videoEngagementRepostersEmpty => 'Brak udostępnień';

  @override
  String get videoEngagementLoadFailed => 'Nie udało się wczytać listy';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Otwórz szczegóły filmu';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Otwórz szczegóły filmu';

  @override
  String get videoOverlayCommentBarHint => 'Dodaj komentarz...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Dodaj komentarz';

  @override
  String get videoOverlayCommentBarSendLabel => 'Wyślij komentarz';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Komentarz opublikowany';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Nie udało się opublikować komentarza';

  @override
  String videoDescriptionLoops(String count) {
    return '$count pętli';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pętli',
      many: 'pętli',
      few: 'pętle',
      one: 'pętla',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Nie Divine';

  @override
  String get metadataBadgeHumanMade => 'Zrobione przez człowieka';

  @override
  String get metadataSoundsLabel => 'Dźwięki';

  @override
  String get metadataOriginalSound => 'Oryginalny dźwięk';

  @override
  String get metadataVerificationLabel => 'Weryfikacja';

  @override
  String get metadataDeviceAttestation => 'Atestacja urządzenia';

  @override
  String get metadataPgpSignature => 'Podpis PGP';

  @override
  String get metadataC2paCredentials => 'Poświadczenia treści C2PA';

  @override
  String get metadataProofManifest => 'Manifest dowodowy';

  @override
  String get metadataCreatorLabel => 'Twórca';

  @override
  String get metadataCollaboratorsLabel => 'Współtwórcy';

  @override
  String get metadataInspiredByLabel => 'Zainspirowane przez';

  @override
  String get metadataRepostedByLabel => 'Repostowane przez';

  @override
  String metadataLoopsLabel(int count) {
    return 'Pętle';
  }

  @override
  String get metadataLikesLabel => 'Polubienia';

  @override
  String get metadataCommentsLabel => 'Komentarze';

  @override
  String get metadataRepostsLabel => 'Reposty';

  @override
  String get metadataVineStatsLabel => 'Na Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops pętli · $likes polubień · $comments komentarzy · $reposts repostów';
  }

  @override
  String get metadataDivineStatsLabel => 'Na Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views wyświetleń · $likes polubień · $comments komentarzy · $reposts repostów';
  }

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Opublikowano $date';
  }

  @override
  String get devOptionsTitle => 'Opcje dewelopera';

  @override
  String get devOptionsDisableDeveloperMode => 'Wyłącz tryb dewelopera';

  @override
  String get devOptionsDisableDeveloperModeSubtitle =>
      'Ukryj opcje deweloperskie w ustawieniach';

  @override
  String get devOptionsDisableDeveloperModeToast => 'Tryb dewelopera wyłączony';

  @override
  String get devOptionsPageLoadTimes => 'Czasy ładowania stron';

  @override
  String get devOptionsNoPageLoads =>
      'Brak zarejestrowanych ładowań stron.\nPorusz się po aplikacji, żeby zobaczyć dane.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Widoczne: ${visibleMs}ms  |  Dane: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Najwolniejsze ekrany';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format odtwarzania wideo';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Przełączyć środowisko?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Przełączyć na $envName?\n\nTo wyczyści cache wideo i połączy ponownie z nowym przekaźnikiem.';
  }

  @override
  String get devOptionsCancel => 'Anuluj';

  @override
  String get devOptionsSwitch => 'Przełącz';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Przełączono na $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Przełączono na $formatName — cache wyczyszczony';
  }

  @override
  String get featureFlagTitle => 'Flagi funkcji';

  @override
  String get featureFlagResetAllTooltip =>
      'Zresetuj wszystkie flagi do domyślnych';

  @override
  String get featureFlagResetToDefault => 'Zresetuj do domyślnych';

  @override
  String get featureFlagAppRecovery => 'Odzyskiwanie aplikacji';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Jeśli aplikacja się crashuje lub dziwnie zachowuje, spróbuj wyczyścić cache.';

  @override
  String get featureFlagClearAllCache => 'Wyczyść cały cache';

  @override
  String get featureFlagCacheInfo => 'Informacje o cache';

  @override
  String get featureFlagClearCacheTitle => 'Wyczyścić cały cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'To wyczyści wszystkie dane z cache, w tym:\n• Powiadomienia\n• Profile użytkowników\n• Zakładki\n• Pliki tymczasowe\n\nBędziesz musiał zalogować się ponownie. Kontynuować?';

  @override
  String get featureFlagClearCache => 'Wyczyść cache';

  @override
  String get featureFlagClearingCache => 'Czyszczenie cache...';

  @override
  String get featureFlagSuccess => 'Sukces';

  @override
  String get featureFlagError => 'Błąd';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache wyczyszczony pomyślnie. Zrestartuj aplikację.';

  @override
  String get featureFlagClearCacheFailure =>
      'Nie udało się wyczyścić niektórych elementów cache. Sprawdź logi.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Informacje o cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Całkowity rozmiar cache: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cache zawiera:\n• Historię powiadomień\n• Dane profilu użytkownika\n• Miniatury filmów\n• Pliki tymczasowe\n• Indeksy bazy danych';

  @override
  String get relaySettingsTitle => 'Przekaźniki';

  @override
  String get relaySettingsInfoTitle =>
      'Divine to otwarty system - ty kontrolujesz swoje połączenia';

  @override
  String get relaySettingsInfoDescription =>
      'Te przekaźniki dystrybuują twoje treści w zdecentralizowanej sieci Nostr. Możesz dodawać lub usuwać przekaźniki według uznania.';

  @override
  String get relaySettingsLearnMoreNostr => 'Dowiedz się więcej o Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Znajdź publiczne przekaźniki na nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Aplikacja niedziałająca';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine wymaga przynajmniej jednego przekaźnika, żeby wczytać filmy, publikować treści i synchronizować dane.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Przywróć domyślny przekaźnik';

  @override
  String get relaySettingsAddCustomRelay => 'Dodaj własny przekaźnik';

  @override
  String get relaySettingsAddRelay => 'Dodaj przekaźnik';

  @override
  String get relaySettingsRetry => 'Spróbuj ponownie';

  @override
  String get relaySettingsNoStats => 'Brak dostępnych statystyk';

  @override
  String get relaySettingsConnection => 'Połączenie';

  @override
  String get relaySettingsConnected => 'Połączono';

  @override
  String get relaySettingsDisconnected => 'Rozłączono';

  @override
  String get relaySettingsSessionDuration => 'Czas trwania sesji';

  @override
  String get relaySettingsLastConnected => 'Ostatnie połączenie';

  @override
  String get relaySettingsDisconnectedLabel => 'Rozłączono';

  @override
  String get relaySettingsReason => 'Powód';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktywne subskrypcje';

  @override
  String get relaySettingsTotalSubscriptions => 'Łączna liczba subskrypcji';

  @override
  String get relaySettingsEventsReceived => 'Odebrane zdarzenia';

  @override
  String get relaySettingsEventsSent => 'Wysłane zdarzenia';

  @override
  String get relaySettingsRequestsThisSession => 'Żądania w tej sesji';

  @override
  String get relaySettingsFailedRequests => 'Nieudane żądania';

  @override
  String relaySettingsLastError(String error) {
    return 'Ostatni błąd: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Wczytywanie informacji o przekaźniku...';

  @override
  String get relaySettingsAboutRelay => 'O przekaźniku';

  @override
  String get relaySettingsSupportedNips => 'Obsługiwane NIP-y';

  @override
  String get relaySettingsSoftware => 'Oprogramowanie';

  @override
  String get relaySettingsViewWebsite => 'Zobacz stronę';

  @override
  String get relaySettingsRemoveRelayTitle => 'Usunąć przekaźnik?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Na pewno chcesz usunąć ten przekaźnik?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Anuluj';

  @override
  String get relaySettingsRemove => 'Usuń';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Usunięto przekaźnik: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Nie udało się usunąć przekaźnika';

  @override
  String get relaySettingsForcingReconnection =>
      'Wymuszanie ponownego połączenia z przekaźnikiem...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Połączono z $count przekaźnikami!',
      many: 'Połączono z $count przekaźnikami!',
      few: 'Połączono z $count przekaźnikami!',
      one: 'Połączono z 1 przekaźnikiem!',
    );
    return '$_temp0';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Nie udało się połączyć z przekaźnikami. Sprawdź połączenie z siecią.';

  @override
  String get relaySettingsAddRelayTitle => 'Dodaj przekaźnik';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Wprowadź URL WebSocket przekaźnika, który chcesz dodać:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Przeglądaj publiczne przekaźniki na nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Dodaj';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Dodano przekaźnik: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Nie udało się dodać przekaźnika. Sprawdź URL i spróbuj ponownie.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL przekaźnika musi zaczynać się od wss:// lub ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'URL przekaźnika musi używać wss:// (ws:// jest dozwolony tylko dla localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Przywrócono domyślny przekaźnik: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Nie udało się przywrócić domyślnego przekaźnika. Sprawdź połączenie z siecią.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Nie można otworzyć przeglądarki';

  @override
  String get relaySettingsFailedToOpenLink => 'Nie udało się otworzyć linku';

  @override
  String get relaySettingsExternalRelay => 'Zewnętrzny przekaźnik';

  @override
  String get relaySettingsNotConnected => 'Niepołączony';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Rozłączono $duration temu';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count sub.';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count zdarzeń';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return '$duration temu';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine używa protokołu Nostr do zdecentralizowanego publikowania. Twoje treści żyją na przekaźnikach, które wybierasz, a twoje klucze są twoją tożsamością.';

  @override
  String get nostrSettingsSectionNetwork => 'Sieć';

  @override
  String get nostrSettingsSectionAccount => 'Konto';

  @override
  String get nostrSettingsSectionDangerZone => 'Strefa zagrożenia';

  @override
  String get nostrSettingsRelays => 'Przekaźniki';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Zarządzaj połączeniami z przekaźnikami Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostyka przekaźników';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debuguj łączność z przekaźnikami i problemy sieciowe';

  @override
  String get nostrSettingsMediaServers => 'Serwery mediów';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Skonfiguruj serwery uploadu Blossom';

  @override
  String get settingsDeveloperOptions => 'Opcje deweloperskie';

  @override
  String get settingsDeveloperOptionsSubtitle =>
      'Przełącznik środowiska i ustawienia debugowania';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Włączaj flagi funkcji, które mogą czkać.';

  @override
  String get nostrSettingsKeyManagement => 'Zarządzanie kluczami';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Eksportuj, twórz kopie zapasowe i przywracaj swoje klucze Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Atrybucja klienta';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Dodawaj tag klienta Divine do publikowanych zdarzeń, aby inne aplikacje Nostr mogły je poprawnie przypisać.';

  @override
  String get nostrSettingsRemoveKeys => 'Usuń klucze z urządzenia';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Usuń swój klucz prywatny tylko z tego urządzenia. Twoje treści zostają na przekaźnikach, ale do ponownego dostępu do konta potrzebna będzie kopia zapasowa nsec.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Nie udało się usunąć kluczy z tego urządzenia. Spróbuj ponownie.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Nie udało się usunąć kluczy: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Usuń konto i dane';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'TRWALE usuń swoje konto i WSZYSTKIE treści z przekaźników Nostr. Tego nie da się cofnąć.';

  @override
  String get relayDiagnosticTitle => 'Diagnostyka przekaźnika';

  @override
  String get relayDiagnosticRefreshTooltip => 'Odśwież diagnostykę';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Ostatnie odświeżenie: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status przekaźnika';

  @override
  String get relayDiagnosticInitialized => 'Zainicjalizowany';

  @override
  String get relayDiagnosticReady => 'Gotowy';

  @override
  String get relayDiagnosticNotInitialized => 'Nie zainicjalizowany';

  @override
  String get relayDiagnosticDatabaseEvents => 'Zdarzenia w bazie danych';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktywne subskrypcje';

  @override
  String get relayDiagnosticExternalRelays => 'Zewnętrzne przekaźniki';

  @override
  String get relayDiagnosticConfigured => 'Skonfigurowane';

  @override
  String relayDiagnosticRelayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count przekaźnika',
      many: '$count przekaźników',
      few: '$count przekaźniki',
      one: '1 przekaźnik',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Połączono';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Zdarzenia wideo';

  @override
  String get relayDiagnosticHomeFeed => 'Kanał główny';

  @override
  String relayDiagnosticVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticDiscovery => 'Odkrywanie';

  @override
  String get relayDiagnosticLoading => 'Wczytywanie';

  @override
  String get relayDiagnosticYes => 'Tak';

  @override
  String get relayDiagnosticNo => 'Nie';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testuj bezpośrednie zapytanie';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Łączność sieciowa';

  @override
  String get relayDiagnosticRunNetworkTest => 'Uruchom test sieci';

  @override
  String get relayDiagnosticBlossomServer => 'Serwer Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testuj wszystkie endpointy';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Błąd';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Bazowy URL';

  @override
  String get relayDiagnosticSummary => 'Podsumowanie';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (śr. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retestuj wszystko';

  @override
  String get relayDiagnosticRetrying => 'Ponawianie...';

  @override
  String get relayDiagnosticRetryConnection => 'Ponów połączenie';

  @override
  String get relayDiagnosticTroubleshooting => 'Rozwiązywanie problemów';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Zielony status = Połączono i działa\n• Czerwony status = Połączenie nieudane\n• Jeśli test sieci nie powiedzie się, sprawdź połączenie z internetem\n• Jeśli przekaźniki są skonfigurowane, ale nie połączone, dotknij \"Ponów połączenie\"\n• Zrzut ekranu tego ekranu pomoże w debugowaniu';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Wszystkie endpointy REST działają!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Niektóre endpointy REST nie działają - zobacz szczegóły powyżej';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Znaleziono $count zdarzenia wideo w bazie',
      many: 'Znaleziono $count zdarzeń wideo w bazie',
      few: 'Znaleziono $count zdarzenia wideo w bazie',
      one: 'Znaleziono 1 zdarzenie wideo w bazie',
    );
    return '$_temp0';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Zapytanie nieudane: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Połączono z $count przekaźnikami!',
      many: 'Połączono z $count przekaźnikami!',
      few: 'Połączono z $count przekaźnikami!',
      one: 'Połączono z 1 przekaźnikiem!',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Nie udało się połączyć z żadnym przekaźnikiem';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Ponowne połączenie nieudane: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Połączono i uwierzytelniono';

  @override
  String get relayDiagnosticConnectedOnly => 'Połączono';

  @override
  String get relayDiagnosticNotConnected => 'Nie połączono';

  @override
  String get relayDiagnosticNoRelaysConfigured =>
      'Brak skonfigurowanych przekaźników';

  @override
  String get relayDiagnosticFailed => 'Nieudane';

  @override
  String get notificationSettingsTitle => 'Powiadomienia';

  @override
  String get notificationSettingsResetTooltip => 'Zresetuj do domyślnych';

  @override
  String get notificationSettingsTypes => 'Typy powiadomień';

  @override
  String get notificationSettingsLikes => 'Polubienia';

  @override
  String get notificationSettingsLikesSubtitle => 'Gdy ktoś polubi twoje filmy';

  @override
  String get notificationSettingsComments => 'Komentarze';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Gdy ktoś skomentuje twoje filmy';

  @override
  String get notificationSettingsFollows => 'Obserwacje';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Gdy ktoś zacznie cię obserwować';

  @override
  String get notificationSettingsMentions => 'Wzmianki';

  @override
  String get notificationSettingsMentionsSubtitle =>
      'Gdy zostaniesz wspomniany';

  @override
  String get notificationSettingsReposts => 'Reposty';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Gdy ktoś repostuje twoje filmy';

  @override
  String get notificationSettingsSystem => 'System';

  @override
  String get notificationSettingsSystemSubtitle =>
      'App updates and system messages';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Push Notifications';

  @override
  String get notificationSettingsPushNotifications => 'Push Notifications';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Receive notifications when app is closed';

  @override
  String get notificationSettingsSound => 'Sound';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Play sound for notifications';

  @override
  String get notificationSettingsVibration => 'Vibration';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Vibrate for notifications';

  @override
  String get notificationSettingsActions => 'Akcje';

  @override
  String get notificationSettingsMarkAllAsRead =>
      'Oznacz wszystkie jako przeczytane';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Oznacz wszystkie powiadomienia jako przeczytane';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Wszystkie powiadomienia oznaczone jako przeczytane';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Nie udało się oznaczyć wszystkich jako przeczytane';

  @override
  String get notificationSettingsResetToDefaults =>
      'Ustawienia zresetowane do domyślnych';

  @override
  String get notificationSettingsAbout => 'O powiadomieniach';

  @override
  String get notificationSettingsAboutDescription =>
      'Powiadomienia są zasilane przez protokół Nostr. Aktualizacje w czasie rzeczywistym zależą od twojego połączenia z przekaźnikami Nostr. Niektóre powiadomienia mogą mieć opóźnienia.';

  @override
  String get safetySettingsTitle => 'Bezpieczeństwo i prywatność';

  @override
  String get safetySettingsLabel => 'USTAWIENIA';

  @override
  String get safetySettingsWhatYouSee => 'CO WIDZISZ';

  @override
  String get safetySettingsWhatYouPublish => 'CO PUBLIKUJESZ';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Pokazuj tylko filmy hostowane na Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ukryj filmy serwowane z innych hostów mediów';

  @override
  String get safetySettingsModeration => 'MODERACJA';

  @override
  String get safetySettingsBlockedUsers => 'ZABLOKOWANI UŻYTKOWNICY';

  @override
  String get safetySettingsAgeVerification => 'WERYFIKACJA WIEKU';

  @override
  String get safetySettingsAgeConfirmation =>
      'Potwierdzam, że mam 18 lat lub więcej';

  @override
  String get safetySettingsAgeRequired =>
      'Wymagane do oglądania treści dla dorosłych';

  @override
  String get safetySettingsAgeLockedForMinor => 'Zablokowane dla twojego konta';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Oficjalna usługa moderacji (domyślnie włączona)';

  @override
  String get safetySettingsPeopleIFollow => 'Osoby, które obserwuję';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Subskrybuj etykiety od osób, które obserwujesz';

  @override
  String get safetySettingsAddCustomLabeler => 'Dodaj własny etykietę';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Wprowadź npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Dodaj własną etykietę';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Wprowadź adres npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Brak zablokowanych użytkowników';

  @override
  String get safetySettingsUnblock => 'Odblokuj';

  @override
  String get safetySettingsUserUnblocked => 'Użytkownik odblokowany';

  @override
  String get safetySettingsCancel => 'Anuluj';

  @override
  String get safetySettingsAdd => 'Dodaj';

  @override
  String get analyticsTitle => 'Statystyki twórcy';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostyka';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Przełącz diagnostykę';

  @override
  String get analyticsRetry => 'Spróbuj ponownie';

  @override
  String get analyticsUnableToLoad => 'Nie można wczytać statystyk.';

  @override
  String get analyticsSignInRequired =>
      'Zaloguj się, żeby zobaczyć statystyki twórcy.';

  @override
  String get analyticsViewDataUnavailable =>
      'Wyświetlenia są aktualnie niedostępne z przekaźnika dla tych postów. Metryki polubień, komentarzy i repostów są nadal dokładne.';

  @override
  String get analyticsViewDataTitle => 'Dane wyświetleń';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Zaktualizowano $time • Wyniki używają polubień, komentarzy, repostów i wyświetleń/pętli z Funnelcake, gdy są dostępne.';
  }

  @override
  String get analyticsVideos => 'Filmy';

  @override
  String get analyticsViews => 'Wyświetlenia';

  @override
  String get analyticsInteractions => 'Interakcje';

  @override
  String get analyticsEngagement => 'Zaangażowanie';

  @override
  String get analyticsFollowers => 'Obserwujących';

  @override
  String get analyticsAvgPerPost => 'Śr./post';

  @override
  String get analyticsInteractionMix => 'Miks interakcji';

  @override
  String get analyticsLikes => 'Polubienia';

  @override
  String get analyticsComments => 'Komentarze';

  @override
  String get analyticsReposts => 'Reposty';

  @override
  String get analyticsPerformanceHighlights => 'Najważniejsze wyniki';

  @override
  String get analyticsMostViewed => 'Najczęściej oglądane';

  @override
  String get analyticsMostDiscussed => 'Najczęściej dyskutowane';

  @override
  String get analyticsMostReposted => 'Najczęściej repostowane';

  @override
  String get analyticsNoVideosYet => 'Brak filmów';

  @override
  String get analyticsViewDataUnavailableShort => 'Dane wyświetleń niedostępne';

  @override
  String analyticsViewsCount(String count) {
    return '$count wyświetleń';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count komentarzy';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count repostów';
  }

  @override
  String get analyticsTopContent => 'Najlepsze treści';

  @override
  String get analyticsPublishPrompt =>
      'Opublikuj kilka filmów, żeby zobaczyć rankingi.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Prawa strona % = Wskaźnik zaangażowania (interakcje podzielone przez wyświetlenia).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Wskaźnik zaangażowania wymaga danych wyświetleń; wartości pokazują się jako N/D, dopóki wyświetlenia nie są dostępne.';

  @override
  String get analyticsEngagementLabel => 'Zaangażowanie';

  @override
  String get analyticsViewsUnavailable => 'wyświetlenia niedostępne';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interakcji';
  }

  @override
  String get analyticsPostAnalytics => 'Statystyki posta';

  @override
  String get analyticsOpenPost => 'Otwórz post';

  @override
  String get analyticsRecentDailyInteractions => 'Niedawne dzienne interakcje';

  @override
  String get analyticsNoActivityYet => 'Brak aktywności w tym zakresie.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interakcje = polubienia + komentarze + reposty według daty posta.';

  @override
  String get analyticsDailyBarExplainer =>
      'Długość paska jest względem twojego największego dnia w tym oknie.';

  @override
  String get analyticsAudienceSnapshot => 'Snapshot widowni';

  @override
  String analyticsFollowersCount(String count) {
    return 'Obserwujących: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Obserwowanych: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Podziały widowni źródło/geo/czas pojawią się, gdy Funnelcake doda endpointy statystyk widowni.';

  @override
  String get analyticsRetention => 'Retencja';

  @override
  String get analyticsRetentionWithViews =>
      'Krzywa retencji i podział czasu oglądania pojawią się, gdy retencja per-sekundę/per-kubeł przyjdzie z Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Dane retencji niedostępne, dopóki statystyki wyświetleń i czasu oglądania nie zostaną zwrócone przez Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostyka';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Łącznie filmów: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Z wyświetleniami: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Brakujące wyświetlenia: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Nawodnione (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Nawodnione (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Źródła: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Użyj danych testowych';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Utwórz nowe konto Divine';

  @override
  String get authCreateNewAccountShort => 'Create new account';

  @override
  String get authSignInDifferentAccount => 'Zaloguj się na inne konto';

  @override
  String get authUseAnotherAccount => 'Use another account';

  @override
  String authContinueAs(String displayName) {
    return 'Continue as $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Twoje szkice i klipy są zapisane dla tego konta';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Zalogowanie się tutaj ukryje te szkice i klipy';

  @override
  String get authTermsPrefix =>
      'By selecting an option below, you confirm you are at least 16 years old (or have completed ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine age authorization';

  @override
  String get authTermsAfterAgeAuthorization => ') and agree to the ';

  @override
  String get authTermsOfService => 'Regulaminem';

  @override
  String get authPrivacyPolicy => 'Polityką prywatności';

  @override
  String get authTermsAnd => ', oraz ';

  @override
  String get authSafetyStandards => 'Standardami bezpieczeństwa';

  @override
  String get authAmberNotInstalled => 'Aplikacja Amber nie jest zainstalowana';

  @override
  String get authAmberConnectionFailed => 'Nie udało się połączyć z Amber';

  @override
  String get authPasswordResetSent =>
      'Jeśli konto z tym e-mailem istnieje, link do resetu hasła został wysłany.';

  @override
  String get authSignInTitle => 'Zaloguj się';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Hasło';

  @override
  String get authConfirmPasswordLabel => 'Potwierdź hasło';

  @override
  String get authEmailRequired => 'E-mail jest wymagany';

  @override
  String get authEmailInvalid => 'Wprowadź prawidłowy e-mail';

  @override
  String get authPasswordRequired => 'Hasło jest wymagane';

  @override
  String get authConfirmPasswordRequired => 'Potwierdź swoje hasło';

  @override
  String get authPasswordsDoNotMatch => 'Hasła nie pasują do siebie';

  @override
  String get authForgotPassword => 'Zapomniałeś hasła?';

  @override
  String get authImportNostrKey => 'Importuj klucz Nostr';

  @override
  String get authConnectSignerApp => 'Połącz z aplikacją do podpisywania';

  @override
  String get authSignInWithAmber => 'Zaloguj się przez Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Zaloguj się przez rozszerzenie przeglądarki';

  @override
  String get authNip07ConnectionFailed =>
      'Nie udało się połączyć z rozszerzeniem przeglądarki.';

  @override
  String get authNip07ExtensionNotFound =>
      'Nie znaleziono rozszerzenia przeglądarki. Zainstaluj Alby, nos2x lub inne rozszerzenie zgodne z NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opcje logowania';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail i hasło';

  @override
  String get authInfoEmailPasswordDescription =>
      'Zaloguj się na swoje konto Divine. Jeśli rejestrowałeś się z e-mailem i hasłem, użyj ich tutaj.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Masz już tożsamość Nostr? Importuj swój klucz prywatny nsec z innego klienta.';

  @override
  String get authInfoSignerAppTitle => 'Aplikacja do podpisywania';

  @override
  String get authInfoSignerAppDescription =>
      'Połącz przez zgodnego z NIP-46 zdalnego sygnatariusza, jak nsecBunker, dla lepszego bezpieczeństwa kluczy.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Użyj aplikacji Amber na Androidzie, żeby bezpiecznie zarządzać kluczami Nostr.';

  @override
  String get authInfoBrowserExtensionTitle => 'Rozszerzenie przeglądarki';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Zaloguj się przez rozszerzenie przeglądarki NIP-07, takie jak Alby lub nos2x. Twoje klucze pozostają w rozszerzeniu — Divine nigdy ich nie widzi.';

  @override
  String get authCreateAccountTitle => 'Utwórz konto';

  @override
  String get authBackToInviteCode => 'Wróć do kodu zaproszenia';

  @override
  String get authUseDivineNoBackup => 'Używaj Divine bez kopii zapasowej';

  @override
  String get authSkipConfirmTitle => 'Ostatnia rzecz...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Jesteś w środku! Utworzymy bezpieczny klucz, który zasila twoje konto Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Bez e-maila twój klucz to jedyny sposób, w jaki Divine wie, że to konto należy do ciebie.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Możesz uzyskać dostęp do klucza w aplikacji, ale jeśli nie jesteś techniczny, polecamy dodanie e-maila i hasła teraz. Łatwiej będzie się logować i przywrócić konto, jeśli zgubisz lub zresetujesz to urządzenie.';

  @override
  String get authAddEmailPassword => 'Dodaj e-mail i hasło';

  @override
  String get authUseThisDeviceOnly => 'Używaj tylko tego urządzenia';

  @override
  String get authCompleteRegistration => 'Dokończ rejestrację';

  @override
  String get authVerifying => 'Weryfikowanie...';

  @override
  String get authVerificationLinkSent => 'Wysłaliśmy link weryfikacyjny do:';

  @override
  String get authClickVerificationLink =>
      'Kliknij link w e-mailu, żeby\ndokończyć rejestrację.';

  @override
  String get authPleaseWaitVerifying => 'Czekaj, weryfikujemy twój e-mail...';

  @override
  String get authWaitingForVerification => 'Czekam na weryfikację';

  @override
  String get authOpenEmailApp => 'Otwórz aplikację e-mail';

  @override
  String get authWelcomeToDivine => 'Witaj w Divine!';

  @override
  String get authEmailVerified => 'Twój e-mail został zweryfikowany.';

  @override
  String get authSigningYouIn => 'Logujemy cię';

  @override
  String get authErrorTitle => 'O nie.';

  @override
  String get authVerificationFailed =>
      'Nie udało nam się zweryfikować twojego e-maila.\nSpróbuj ponownie.';

  @override
  String get authStartOver => 'Zacznij od nowa';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail zweryfikowany! Zaloguj się, żeby kontynuować.';

  @override
  String get authVerificationLinkExpired =>
      'Ten link weryfikacyjny nie jest już ważny.';

  @override
  String get authVerificationConnectionError =>
      'Nie można zweryfikować e-maila. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get authWaitlistConfirmTitle => 'Jesteś w środku!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Będziemy dzielić się aktualizacjami na $email.\nGdy będą dostępne kolejne kody zaproszeń, wyślemy je do ciebie.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Dostęp z zaproszeniem jest chwilowo niedostępny.';

  @override
  String get authInviteUnavailableBody =>
      'Spróbuj ponownie za chwilę lub skontaktuj się z pomocą, jeśli potrzebujesz wejścia.';

  @override
  String get authTryAgain => 'Spróbuj ponownie';

  @override
  String get authContactSupport => 'Skontaktuj się z pomocą';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Nie można otworzyć $email';
  }

  @override
  String get authAddInviteCode => 'Dodaj swój kod zaproszenia';

  @override
  String get authInviteCodeLabel => 'Kod zaproszenia';

  @override
  String get authEnterYourCode => 'Wpisz swój kod';

  @override
  String get authNext => 'Dalej';

  @override
  String get authJoinWaitlist => 'Dołącz do listy oczekujących';

  @override
  String get authJoinWaitlistTitle => 'Dołącz do listy oczekujących';

  @override
  String get authJoinWaitlistDescription =>
      'Podaj swój e-mail, a będziemy wysyłać aktualizacje, gdy dostęp się otworzy.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Pomoc z dostępem z zaproszenia';

  @override
  String get authGeneratingConnection => 'Generowanie połączenia...';

  @override
  String get authConnectedAuthenticating => 'Połączono! Uwierzytelnianie...';

  @override
  String get authConnectionTimedOut => 'Przekroczono czas połączenia';

  @override
  String get authApproveConnection =>
      'Upewnij się, że zatwierdziłeś połączenie w aplikacji do podpisywania.';

  @override
  String get authConnectionCancelled => 'Połączenie anulowane';

  @override
  String get authConnectionCancelledMessage => 'Połączenie zostało anulowane.';

  @override
  String get authConnectionFailed => 'Połączenie nieudane';

  @override
  String get authUnknownError => 'Wystąpił nieznany błąd.';

  @override
  String get authBunkerRejectedConnection =>
      'Twoja aplikacja do podpisywania odrzuciła połączenie.';

  @override
  String get authNostrConnectStartFailed =>
      'Nie udało się połączyć z aplikacją do podpisywania. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get authNostrConnectInvalidSession =>
      'Ten link do połączenia jest już nieważny. Utwórz nowy.';

  @override
  String get authNostrConnectSetupFailed =>
      'Prawie gotowe — nie udało się dokończyć logowania. Spróbuj ponownie.';

  @override
  String get authUrlCopied => 'URL skopiowany do schowka';

  @override
  String get authConnectToDivine => 'Połącz z Divine';

  @override
  String get authPasteBunkerUrl => 'Wklej URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'Nieprawidłowy URL bunker. Powinien zaczynać się od bunker://';

  @override
  String get authScanSignerApp =>
      'Zeskanuj aplikacją\ndo podpisywania, żeby połączyć.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Czekam na połączenie... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Kopiuj URL';

  @override
  String get authShare => 'Udostępnij';

  @override
  String get authAddBunker => 'Dodaj bunker';

  @override
  String get authCompatibleSignerApps =>
      'Kompatybilne aplikacje do podpisywania';

  @override
  String get authFailedToConnect => 'Nie udało się połączyć';

  @override
  String get authResetPasswordTitle => 'Zresetuj hasło';

  @override
  String get authResetPasswordSubtitle =>
      'Wprowadź nowe hasło. Musi mieć przynajmniej 8 znaków.';

  @override
  String get authNewPasswordLabel => 'Nowe hasło';

  @override
  String get authConfirmNewPasswordLabel => 'Potwierdź nowe hasło';

  @override
  String get authPasswordTooShort => 'Hasło musi mieć przynajmniej 8 znaków';

  @override
  String get authPasswordResetSuccess => 'Reset hasła udany. Zaloguj się.';

  @override
  String get authPasswordResetFailed => 'Reset hasła nieudany';

  @override
  String get authUnexpectedError =>
      'Wystąpił nieoczekiwany błąd. Spróbuj ponownie.';

  @override
  String get authUpdatePassword => 'Zaktualizuj hasło';

  @override
  String get authSecureAccountTitle => 'Zabezpiecz konto';

  @override
  String get authUnableToAccessKeys =>
      'Nie można uzyskać dostępu do twoich kluczy. Spróbuj ponownie.';

  @override
  String get authRegistrationFailed => 'Rejestracja nieudana';

  @override
  String get authRegistrationComplete =>
      'Rejestracja ukończona. Sprawdź e-mail.';

  @override
  String get authVerificationFailedTitle => 'Weryfikacja nieudana';

  @override
  String get authClose => 'Zamknij';

  @override
  String get authAccountSecured => 'Konto zabezpieczone!';

  @override
  String get authAccountLinkedToEmail =>
      'Twoje konto jest teraz powiązane z twoim e-mailem.';

  @override
  String get authVerifyYourEmail => 'Zweryfikuj swój e-mail';

  @override
  String get authClickLinkContinue =>
      'Kliknij link w e-mailu, żeby dokończyć rejestrację. W międzyczasie możesz dalej korzystać z aplikacji.';

  @override
  String get authWaitingForVerificationEllipsis => 'Czekam na weryfikację...';

  @override
  String get authContinueToApp => 'Przejdź do aplikacji';

  @override
  String get authResetPassword => 'Zresetuj hasło';

  @override
  String get authResetPasswordDescription =>
      'Wprowadź swój adres e-mail, a wyślemy ci link do zresetowania hasła.';

  @override
  String get authFailedToSendResetEmail =>
      'Nie udało się wysłać e-maila z resetem.';

  @override
  String get authUnexpectedErrorShort => 'Wystąpił nieoczekiwany błąd.';

  @override
  String get authSending => 'Wysyłanie...';

  @override
  String get authSendResetLink => 'Wyślij link resetujący';

  @override
  String get authEmailSent => 'E-mail wysłany!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Wysłaliśmy link do zresetowania hasła na $email. Kliknij link w e-mailu, żeby zaktualizować hasło.';
  }

  @override
  String get authSignInButton => 'Zaloguj się';

  @override
  String get authVerificationErrorTimeout =>
      'Weryfikacja przekroczyła czas. Spróbuj zarejestrować się ponownie.';

  @override
  String get authVerificationErrorMissingCode =>
      'Weryfikacja nieudana — brak kodu autoryzacyjnego.';

  @override
  String get authVerificationErrorPollFailed =>
      'Weryfikacja nieudana. Spróbuj ponownie.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Błąd sieci podczas logowania. Spróbuj ponownie.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Weryfikacja nieudana. Spróbuj zarejestrować się ponownie.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Logowanie nieudane. Spróbuj zalogować się ręcznie.';

  @override
  String get authVerificationEmailAlreadyRegistered =>
      'Ten adres e-mail jest już zarejestrowany. Zaloguj się zamiast tego.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Ten kod zaproszenia nie jest już dostępny. Wróć do kodu zaproszenia, dołącz do listy oczekujących lub skontaktuj się z pomocą.';

  @override
  String get authInviteErrorInvalid =>
      'Ten kod zaproszenia nie może być teraz użyty. Wróć do kodu zaproszenia, dołącz do listy oczekujących lub skontaktuj się z pomocą.';

  @override
  String get authInviteErrorTemporary =>
      'Nie mogliśmy teraz potwierdzić twojego zaproszenia. Wróć do kodu zaproszenia i spróbuj ponownie, lub skontaktuj się z pomocą.';

  @override
  String get authInviteErrorUnknown =>
      'Nie mogliśmy aktywować twojego zaproszenia. Wróć do kodu zaproszenia, dołącz do listy oczekujących lub skontaktuj się z pomocą.';

  @override
  String get shareSheetSave => 'Zapisz';

  @override
  String get shareSheetSaveToGallery => 'Zapisz w galerii';

  @override
  String get shareSheetSaveWithWatermark => 'Zapisz ze znakiem wodnym';

  @override
  String get shareSheetSaveVideo => 'Zapisz film';

  @override
  String get shareSheetAddToClips => 'Dodaj do klipów';

  @override
  String get shareSheetNameClipTitle => 'Nazwij ten klip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Wybierz nazwę, którą rozpoznasz w swojej bibliotece.';

  @override
  String get shareSheetClipTitleLabel => 'Tytuł klipu';

  @override
  String get shareSheetSaveClip => 'Zapisz klip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Zapisano „$title” do klipów';
  }

  @override
  String get shareSheetUntitledClip => 'Klip bez tytułu';

  @override
  String get shareSheetAddToClipsFailed => 'Nie można dodać do klipów';

  @override
  String get shareSheetAddToList => 'Dodaj do listy';

  @override
  String get shareSheetCopy => 'Kopiuj';

  @override
  String get shareSheetShareVia => 'Udostępnij przez';

  @override
  String get shareSheetReport => 'Zgłoś';

  @override
  String get shareSheetEventJson => 'JSON zdarzenia';

  @override
  String get shareSheetEventId => 'ID zdarzenia';

  @override
  String get shareSheetMoreActions => 'Więcej akcji';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Zapisano w rolce aparatu';

  @override
  String get watermarkDownloadShare => 'Udostępnij';

  @override
  String get watermarkDownloadDone => 'Gotowe';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Potrzebny dostęp do zdjęć';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Aby zapisać filmy, zezwól na dostęp do Zdjęć w Ustawieniach.';

  @override
  String get watermarkDownloadOpenSettings => 'Otwórz Ustawienia';

  @override
  String get watermarkDownloadNotNow => 'Nie teraz';

  @override
  String get watermarkDownloadFailed => 'Pobieranie nieudane';

  @override
  String get watermarkDownloadDismiss => 'Odrzuć';

  @override
  String get watermarkDownloadStageDownloading => 'Pobieranie filmu';

  @override
  String get watermarkDownloadStageWatermarking => 'Dodawanie znaku wodnego';

  @override
  String get watermarkDownloadStageSaving => 'Zapisywanie w rolce aparatu';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Pobieranie filmu z sieci...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Nakładanie znaku wodnego Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Zapisywanie filmu ze znakiem wodnym w rolce aparatu...';

  @override
  String get uploadProgressVideoUpload => 'Przesyłanie filmu';

  @override
  String get uploadProgressPause => 'Wstrzymaj';

  @override
  String get uploadProgressResume => 'Wznów';

  @override
  String get uploadProgressGoBack => 'Wróć';

  @override
  String uploadProgressRetryWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'zostało $count próby',
      many: 'zostało $count prób',
      few: 'zostały $count próby',
      one: 'została 1 próba',
    );
    return 'Ponów ($_temp0)';
  }

  @override
  String get uploadProgressDelete => 'Usuń';

  @override
  String uploadProgressDaysAgo(int count) {
    return '$count d temu';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '$count godz. temu';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '$count min temu';
  }

  @override
  String get uploadProgressJustNow => 'Przed chwilą';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Przesyłanie $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Wstrzymano $percent%';
  }

  @override
  String get shareMenuTitle => 'Udostępnij film';

  @override
  String get shareMenuReportAiContent => 'Zgłoś treść AI';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Szybko zgłoś podejrzewaną treść wygenerowaną przez AI';

  @override
  String get shareMenuReportingAiContent => 'Zgłaszanie treści AI...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Nie udało się zgłosić treści: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Nie udało się zgłosić treści AI: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Status filmu';

  @override
  String get shareMenuViewAllLists => 'Zobacz wszystkie listy →';

  @override
  String get shareMenuShareWith => 'Udostępnij z';

  @override
  String get shareMenuShareViaOtherApps => 'Udostępnij przez inne aplikacje';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Udostępnij przez inne aplikacje lub skopiuj link';

  @override
  String get shareMenuSaveToGallery => 'Zapisz w galerii';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Zapisz oryginalny film w rolce aparatu';

  @override
  String get shareMenuSaveWithWatermark => 'Zapisz ze znakiem wodnym';

  @override
  String get shareMenuSaveVideo => 'Zapisz film';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Pobierz ze znakiem wodnym Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Zapisz film w rolce aparatu';

  @override
  String get shareMenuLists => 'Listy';

  @override
  String get shareMenuAddToList => 'Dodaj do listy';

  @override
  String get shareMenuAddToListSubtitle =>
      'Dodaj do swoich kuratorowanych list';

  @override
  String get shareMenuCreateNewList => 'Utwórz nową listę';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Zacznij nową kuratorowaną kolekcję';

  @override
  String get shareMenuRemovedFromList => 'Usunięto z listy';

  @override
  String get shareMenuFailedToRemoveFromList => 'Nie udało się usunąć z listy';

  @override
  String get shareMenuBookmarks => 'Zakładki';

  @override
  String get shareMenuAddToBookmarks => 'Dodaj do zakładek';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Zapisz na później';

  @override
  String get shareMenuAddToBookmarkSet => 'Dodaj do zestawu zakładek';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Zorganizuj w kolekcjach';

  @override
  String get shareMenuFollowSets => 'Zestawy obserwowanych';

  @override
  String get shareMenuCreateFollowSet => 'Utwórz zestaw obserwowanych';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Zacznij nową kolekcję z tym twórcą';

  @override
  String get shareMenuAddToFollowSet => 'Dodaj do zestawu obserwowanych';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zestawu obserwowanych dostępne',
      many: '$count zestawów obserwowanych dostępnych',
      few: '$count zestawy obserwowanych dostępne',
      one: '1 zestaw obserwowanych dostępny',
    );
    return '$_temp0';
  }

  @override
  String get peopleListsAddToList => 'Dodaj do listy';

  @override
  String get peopleListsAddToListSubtitle =>
      'Dodaj tego twórcę do jednej ze swoich list';

  @override
  String get peopleListsSheetTitle => 'Dodaj do listy';

  @override
  String get peopleListsEmptyTitle => 'Brak list';

  @override
  String get peopleListsEmptySubtitle =>
      'Utwórz listę, aby zacząć grupować osoby.';

  @override
  String get peopleListsCreateList => 'Utwórz listę';

  @override
  String get peopleListsNewListTitle => 'Nowa lista';

  @override
  String get peopleListsRouteTitle => 'Lista osób';

  @override
  String get peopleListsListNameLabel => 'Nazwa listy';

  @override
  String get peopleListsListNameHint => 'Bliscy znajomi';

  @override
  String get peopleListsCreateButton => 'Utwórz';

  @override
  String get peopleListsAddPeopleTitle => 'Dodaj osoby';

  @override
  String get peopleListsAddPeopleTooltip => 'Dodaj osoby';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Dodaj osoby do listy';

  @override
  String get peopleListsListNotFoundTitle => 'Lista nie znaleziona';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista nie znaleziona. Mogła zostać usunięta.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Ta lista mogła zostać usunięta.';

  @override
  String get peopleListsNoPeopleTitle => 'Brak osób na tej liście';

  @override
  String get peopleListsNoPeopleSubtitle => 'Dodaj osoby, aby zacząć';

  @override
  String get peopleListsNoVideosTitle => 'Brak filmów';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Filmy od członków listy pojawią się tutaj';

  @override
  String get peopleListsNoVideosAvailable => 'Brak dostępnych filmów';

  @override
  String get peopleListsFailedToLoadVideos => 'Nie udało się załadować filmów';

  @override
  String get peopleListsVideoNotAvailable => 'Film niedostępny';

  @override
  String get peopleListsBackToGridTooltip => 'Powrót do siatki';

  @override
  String get peopleListsErrorLoadingVideos => 'Błąd podczas ładowania filmów';

  @override
  String get peopleListsNoPeopleToAdd => 'Brak osób dostępnych do dodania.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Dodaj do $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Szukaj osób';

  @override
  String get peopleListsAddPeopleError =>
      'Nie udało się załadować osób. Spróbuj ponownie.';

  @override
  String get peopleListsAddPeopleRetry => 'Spróbuj ponownie';

  @override
  String get peopleListsAddButton => 'Dodaj';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Dodaj $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Na $count listach',
      many: 'Na $count listach',
      few: 'Na $count listach',
      one: 'Na 1 liście',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Usunąć $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Osoba zostanie usunięta z tej listy.';

  @override
  String get peopleListsRemove => 'Usuń';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Usunięto $name z listy';
  }

  @override
  String get peopleListsUndo => 'Cofnij';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil $name. Przytrzymaj, aby usunąć.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Zobacz profil $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Dodano do zakładek!';

  @override
  String get shareMenuFailedToAddBookmark => 'Nie udało się dodać zakładki';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Utworzono listę \"$name\" i dodano film';
  }

  @override
  String get shareMenuManageContent => 'Zarządzaj treścią';

  @override
  String get shareMenuEditVideo => 'Edytuj film';

  @override
  String get shareMenuEditVideoSubtitle => 'Zaktualizuj tytuł, opis i hashtagi';

  @override
  String get shareMenuDeleteVideo => 'Usuń film';

  @override
  String get shareMenuDeleteVideoSubtitle => 'Trwale usuń tę treść';

  @override
  String get shareMenuDeleteWarning =>
      'To wyślе żądanie usunięcia (NIP-09) do wszystkich przekaźników. Niektóre przekaźniki mogą nadal zachować treść.';

  @override
  String get shareMenuVideoInTheseLists => 'Film jest na tych listach:';

  @override
  String shareMenuVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String get shareMenuClose => 'Zamknij';

  @override
  String get shareMenuDeleteConfirmation => 'Na pewno chcesz usunąć ten film?';

  @override
  String get shareMenuCancel => 'Anuluj';

  @override
  String get shareMenuDelete => 'Usuń';

  @override
  String get shareMenuDeletingContent => 'Usuwanie treści...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Nie udało się usunąć treści: $error';
  }

  @override
  String get shareMenuDeleteRequestSent =>
      'Żądanie usunięcia wysłane pomyślnie';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Usuwanie nie jest jeszcze gotowe. Spróbuj ponownie za chwilę.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Możesz usuwać tylko własne filmy.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Zaloguj się ponownie i spróbuj usunąć.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Nie udało się podpisać żądania usunięcia. Spróbuj ponownie.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'The relay wouldn\'t accept this delete request. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Nie udało się usunąć tego filmu. Spróbuj ponownie.';

  @override
  String get shareMenuFollowSetName => 'Nazwa zestawu obserwowanych';

  @override
  String get shareMenuFollowSetNameHint => 'np. Twórcy treści, Muzycy itp.';

  @override
  String get shareMenuDescriptionOptional => 'Opis (opcjonalnie)';

  @override
  String get shareMenuCreate => 'Utwórz';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Utworzono zestaw obserwowanych \"$name\" i dodano twórcę';
  }

  @override
  String get shareMenuDone => 'Gotowe';

  @override
  String get shareMenuEditTitle => 'Tytuł';

  @override
  String get shareMenuEditTitleHint => 'Wpisz tytuł filmu';

  @override
  String get shareMenuEditDescription => 'Opis';

  @override
  String get shareMenuEditDescriptionHint => 'Wpisz opis filmu';

  @override
  String get shareMenuEditHashtags => 'Hashtagi';

  @override
  String get shareMenuEditHashtagsHint => 'hashtagi, oddzielone, przecinkami';

  @override
  String get shareMenuEditMetadataNote =>
      'Uwaga: Można edytować tylko metadane. Treści filmu nie można zmienić.';

  @override
  String get shareMenuDeleting => 'Usuwanie...';

  @override
  String get shareMenuUpdate => 'Zaktualizuj';

  @override
  String get shareMenuChangeCover => 'Zmień okładkę';

  @override
  String get shareMenuCoverUploadingBackground =>
      'Miniatura jest przesyłana w tle';

  @override
  String get shareMenuVideoUpdated => 'Film zaktualizowany pomyślnie';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszeń współpracowników nie zostało wysłanych.',
      one: '1 zaproszenie współpracownika nie zostało wysłane.',
    );
    return 'Film zaktualizowany, ale $_temp0';
  }

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Nie udało się zaktualizować filmu: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Nie udało się usunąć filmu: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Usunąć film?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'To wyślе żądanie usunięcia do przekaźników. Uwaga: Niektóre przekaźniki mogą nadal mieć zbuforowane kopie.';

  @override
  String get shareMenuVideoDeletionRequested => 'Zażądano usunięcia filmu';

  @override
  String get shareMenuContentLabels => 'Etykiety treści';

  @override
  String get shareMenuAddContentLabels => 'Dodaj etykiety treści';

  @override
  String get shareMenuClearAll => 'Wyczyść wszystko';

  @override
  String get shareMenuCollaborators => 'Współtwórcy';

  @override
  String get shareMenuAddCollaborator => 'Dodaj współtwórcę';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Musisz wzajemnie obserwować $name, żeby dodać go jako współtwórcę.';
  }

  @override
  String get shareMenuLoading => 'Wczytywanie...';

  @override
  String get shareMenuInspiredBy => 'Zainspirowane przez';

  @override
  String get shareMenuAddInspirationCredit => 'Dodaj źródło inspiracji';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Tego twórcy nie można przywołać.';

  @override
  String get shareMenuUnknown => 'Nieznany';

  @override
  String get shareMenuCreateBookmarkSet => 'Utwórz zestaw zakładek';

  @override
  String get shareMenuSetName => 'Nazwa zestawu';

  @override
  String get shareMenuSetNameHint => 'np. Ulubione, Obejrzyj później itp.';

  @override
  String get shareMenuCreateNewSet => 'Utwórz nowy zestaw';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Zacznij nową kolekcję zakładek';

  @override
  String get shareMenuNoBookmarkSets =>
      'Brak zestawów zakładek. Utwórz swój pierwszy!';

  @override
  String get shareMenuError => 'Błąd';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Nie udało się wczytać zestawów zakładek';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Utworzono \"$name\" i dodano film';
  }

  @override
  String get shareMenuUseThisSound => 'Użyj tego dźwięku';

  @override
  String get shareMenuOriginalSound => 'Oryginalny dźwięk';

  @override
  String get authSessionExpired => 'Twoja sesja wygasła. Zaloguj się ponownie.';

  @override
  String get authSignInFailed => 'Nie udało się zalogować. Spróbuj ponownie.';

  @override
  String get localeAppLanguage => 'Język aplikacji';

  @override
  String get localeDeviceDefault => 'Domyślny język urządzenia';

  @override
  String get localeSelectLanguage => 'Wybierz język';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Uwierzytelnianie przez WWW nie jest obsługiwane w trybie bezpiecznym. Użyj aplikacji mobilnej do bezpiecznego zarządzania kluczami.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Integracja uwierzytelnienia nieudana: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Nieoczekiwany błąd: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Wprowadź URI bunker';

  @override
  String get webAuthConnectTitle => 'Połącz z Divine';

  @override
  String get webAuthChooseMethod =>
      'Wybierz preferowaną metodę uwierzytelnienia Nostr';

  @override
  String get webAuthBrowserExtension => 'Rozszerzenie przeglądarki';

  @override
  String get webAuthRecommended => 'ZALECANE';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Połącz ze zdalnym sygnatariuszem';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Wklej ze schowka';

  @override
  String get webAuthConnectToBunker => 'Połącz z Bunker';

  @override
  String get webAuthNewToNostr => 'Nowy w Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Zainstaluj rozszerzenie przeglądarki jak Alby lub nos2x dla najprostszego doświadczenia, lub użyj nsec bunker dla bezpiecznego zdalnego podpisywania.';

  @override
  String get soundsTitle => 'Dźwięki';

  @override
  String get soundsSearchHint => 'Szukaj dźwięków...';

  @override
  String get soundsPreviewUnavailable =>
      'Nie można odtworzyć podglądu dźwięku - brak dostępnego audio';

  @override
  String soundsPreviewFailed(String error) {
    return 'Nie udało się odtworzyć podglądu: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Polecane dźwięki';

  @override
  String get soundsTrendingSounds => 'Trendy w dźwiękach';

  @override
  String get soundsAllSounds => 'Wszystkie dźwięki';

  @override
  String get soundsSearchResults => 'Wyniki wyszukiwania';

  @override
  String get soundsNoSoundsAvailable => 'Brak dostępnych dźwięków';

  @override
  String get soundsNoSoundsDescription =>
      'Dźwięki pojawią się tutaj, gdy twórcy udostępnią audio';

  @override
  String get soundsNoSoundsFound => 'Nie znaleziono dźwięków';

  @override
  String get soundsNoSoundsFoundDescription => 'Spróbuj innego wyszukiwania';

  @override
  String get soundsSavedToLibrary => 'Zapisano w Dźwiękach';

  @override
  String get soundsAlreadySavedToLibrary => 'Już w Dźwiękach';

  @override
  String get soundsSavedLibraryTitle => 'Moje dźwięki';

  @override
  String get soundsSavedEmptyTitle => 'Brak zapisanych dźwięków';

  @override
  String get soundsSavedEmptyDescription =>
      'Stuknij Użyj dźwięku w wideo, aby zapisać go tutaj.';

  @override
  String get soundsAvailabilityPrivate => 'Prywatne';

  @override
  String get soundsAvailabilityCommunity => 'Społeczność';

  @override
  String get soundsRemoveSavedSound => 'Usuń dźwięk';

  @override
  String get soundsRemovedFromLibrary => 'Usunięto z Dźwięków';

  @override
  String get soundsFailedToLoad => 'Nie udało się wczytać dźwięków';

  @override
  String get soundsRetry => 'Spróbuj ponownie';

  @override
  String get soundsScreenLabel => 'Ekran dźwięków';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Odśwież';

  @override
  String get profileRefreshLabel => 'Odśwież profil';

  @override
  String get profileMoreOptions => 'Więcej opcji';

  @override
  String profileBlockedUser(String name) {
    return 'Zablokowano $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Odblokowano $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Przestano obserwować $name';
  }

  @override
  String profileError(String error) {
    return 'Błąd: $error';
  }

  @override
  String get profileFeedError => 'Couldn\'t load videos.';

  @override
  String get profileFeedLoadMoreError =>
      'Couldn\'t load more videos. Pull to refresh.';

  @override
  String get notificationsTabAll => 'Wszystkie';

  @override
  String get notificationsTabLikes => 'Polubienia';

  @override
  String get notificationsTabComments => 'Komentarze';

  @override
  String get notificationsTabFollows => 'Obserwacje';

  @override
  String get notificationsTabReposts => 'Reposty';

  @override
  String get notificationsFailedToLoad => 'Nie udało się wczytać powiadomień';

  @override
  String get notificationsRetry => 'Spróbuj ponownie';

  @override
  String get notificationsRefreshError =>
      'Nie udało się odświeżyć — pokazuję dostępne';

  @override
  String get notificationsCheckingNew => 'sprawdzanie nowych powiadomień';

  @override
  String get notificationsNoneYet => 'Brak powiadomień';

  @override
  String notificationsNoneForType(String type) {
    return 'Brak powiadomień typu $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Gdy ludzie zaczną wchodzić w interakcję z twoimi treściami, zobaczysz to tutaj';

  @override
  String get notificationsUnreadPrefix => 'Nieprzeczytane powiadomienie';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieprzeczytanego powiadomienia',
      many: '$count nieprzeczytanych powiadomień',
      few: '$count nieprzeczytane powiadomienia',
      one: '1 nieprzeczytane powiadomienie',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Zobacz profil użytkownika $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Zobacz profile';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniatura wideo dla $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniatura wideo';

  @override
  String notificationsLoadingType(String type) {
    return 'Wczytywanie powiadomień typu $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'Masz 1 zaproszenie do podzielenia się z przyjacielem!';

  @override
  String notificationsInvitePlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Masz $count zaproszenia do podzielenia się z przyjaciółmi!',
      many: 'Masz $count zaproszeń do podzielenia się z przyjaciółmi!',
      few: 'Masz $count zaproszenia do podzielenia się z przyjaciółmi!',
      one: 'Masz 1 zaproszenie do podzielenia się z przyjaciółmi!',
    );
    return '$_temp0';
  }

  @override
  String get notificationsVideoNotFound => 'Nie znaleziono filmu';

  @override
  String get notificationsVideoUnavailable => 'Film niedostępny';

  @override
  String get notificationsFromNotification => 'Z powiadomienia';

  @override
  String get feedFailedToLoadVideos => 'Nie udało się wczytać filmów';

  @override
  String get feedRetry => 'Spróbuj ponownie';

  @override
  String get feedNoFollowedUsers =>
      'Nie obserwujesz nikogo.\nZacznij obserwować, żeby zobaczyć ich filmy tutaj.';

  @override
  String get feedModeForYou => 'Dla ciebie';

  @override
  String get feedModeNew => 'Nowe';

  @override
  String get feedModeFollowing => 'Obserwowane';

  @override
  String get feedModeClassics => 'Klasyki';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Tryb kanału: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autor filmu: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Awatar autora';

  @override
  String get feedForYouEmpty =>
      'Twój kanał Dla Ciebie jest pusty.\nOdkrywaj filmy i obserwuj twórców, aby go ukształtować.';

  @override
  String get feedFollowingEmpty =>
      'Brak filmów od osób, które obserwujesz.\nZnajdź twórców, których lubisz i zacznij ich obserwować.';

  @override
  String get feedLatestEmpty => 'Brak nowych filmów.\nWróć tu wkrótce.';

  @override
  String get feedClassicEmpty => 'Brak klasyków.\nWróć tu wkrótce.';

  @override
  String get feedExploreVideos => 'Odkrywaj filmy';

  @override
  String get feedExternalVideoSlow => 'Zewnętrzny film wczytuje się powoli';

  @override
  String get feedSkip => 'Pomiń';

  @override
  String get feedLoadingMore => 'Wczytywanie kolejnych filmów…';

  @override
  String get uploadWaitingToUpload => 'Czekam na przesłanie';

  @override
  String get uploadUploadingVideo => 'Przesyłanie filmu';

  @override
  String get uploadProcessingVideo => 'Przetwarzanie filmu';

  @override
  String get uploadProcessingComplete => 'Przetwarzanie zakończone';

  @override
  String get uploadPublishedSuccessfully => 'Opublikowano pomyślnie';

  @override
  String get uploadFailed => 'Przesyłanie nieudane';

  @override
  String get uploadRetrying => 'Ponawianie przesyłania';

  @override
  String get uploadPaused => 'Przesyłanie wstrzymane';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% ukończono';
  }

  @override
  String get uploadQueuedMessage => 'Twój film jest w kolejce do przesłania';

  @override
  String get uploadUploadingMessage => 'Przesyłanie na serwer...';

  @override
  String get uploadProcessingMessage =>
      'Przetwarzanie filmu - to może potrwać kilka minut';

  @override
  String get uploadReadyToPublishMessage =>
      'Film przetworzony pomyślnie i gotowy do publikacji';

  @override
  String get uploadPublishedMessage => 'Film opublikowany na twoim profilu';

  @override
  String get uploadFailedMessage => 'Przesyłanie nieudane - spróbuj ponownie';

  @override
  String get uploadRetryingMessage => 'Ponawianie przesyłania...';

  @override
  String get uploadPausedMessage => 'Przesyłanie wstrzymane przez użytkownika';

  @override
  String get uploadRetryButton => 'PONÓW';

  @override
  String uploadRetryFailed(String error) {
    return 'Nie udało się ponówić przesyłania: $error';
  }

  @override
  String get userSearchPrompt => 'Szukaj użytkowników';

  @override
  String get userSearchNoResults => 'Nie znaleziono użytkowników';

  @override
  String get userSearchFailed => 'Wyszukiwanie nieudane';

  @override
  String get userPickerSearchByName => 'Szukaj po nazwie';

  @override
  String get userPickerFilterByNameHint => 'Filtruj po nazwie...';

  @override
  String get userPickerSearchByNameHint => 'Szukaj po nazwie...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name już dodano';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Wybierz $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Usuń $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Twoja ekipa czeka';

  @override
  String get userPickerEmptyFollowListBody =>
      'Obserwuj osoby, z którymi nadajesz na tych samych falach. Gdy obserwujecie się wzajemnie, możecie współtworzyć.';

  @override
  String get userPickerGoBack => 'Wróć';

  @override
  String get userPickerTypeNameToSearch => 'Wpisz nazwę, aby wyszukać';

  @override
  String get userPickerUnavailable =>
      'Wyszukiwanie użytkowników jest niedostępne. Spróbuj ponownie później.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Wyszukiwanie nie powiodło się. Spróbuj ponownie.';

  @override
  String get forgotPasswordTitle => 'Zresetuj hasło';

  @override
  String get forgotPasswordDescription =>
      'Wprowadź swój adres e-mail, a wyślemy ci link do zresetowania hasła.';

  @override
  String get forgotPasswordEmailLabel => 'Adres e-mail';

  @override
  String get forgotPasswordCancel => 'Anuluj';

  @override
  String get forgotPasswordSendLink => 'Wyślij link resetujący';

  @override
  String get ageVerificationContentWarning => 'Ostrzeżenie o treści';

  @override
  String get ageVerificationTitle => 'Weryfikacja wieku';

  @override
  String get ageVerificationAdultDescription =>
      'Ta treść została oznaczona jako potencjalnie zawierająca materiały dla dorosłych. Musisz mieć 18 lat lub więcej, żeby ją oglądać.';

  @override
  String get ageVerificationCreationDescription =>
      'Żeby używać aparatu i tworzyć treści, musisz mieć przynajmniej 16 lat.';

  @override
  String get ageVerificationAdultQuestion => 'Masz 18 lat lub więcej?';

  @override
  String get ageVerificationCreationQuestion => 'Masz 16 lat lub więcej?';

  @override
  String get ageVerificationNo => 'Nie';

  @override
  String get ageVerificationYes => 'Tak';

  @override
  String get shareLinkCopied => 'Link skopiowany do schowka';

  @override
  String get shareFailedToCopy => 'Nie udało się skopiować linku';

  @override
  String get shareVideoSubject => 'Sprawdź ten film na Divine';

  @override
  String get shareFailedToShare => 'Nie udało się udostępnić';

  @override
  String get shareVideoTitle => 'Udostępnij film';

  @override
  String get shareToApps => 'Udostępnij do aplikacji';

  @override
  String get shareToAppsSubtitle =>
      'Udostępnij przez wiadomości, aplikacje społecznościowe';

  @override
  String get shareCopyWebLink => 'Kopiuj link WWW';

  @override
  String get shareCopyWebLinkSubtitle =>
      'Skopiuj link do udostępnienia w sieci';

  @override
  String get shareCopyNostrLink => 'Kopiuj link Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Skopiuj link nevent dla klientów Nostr';

  @override
  String get navHome => 'Główna';

  @override
  String get navExplore => 'Odkrywaj';

  @override
  String get navInbox => 'Skrzynka';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSearch => 'Szukaj';

  @override
  String get navSearchTooltip => 'Szukaj';

  @override
  String get navMyProfile => 'Mój profil';

  @override
  String get navNotifications => 'Powiadomienia';

  @override
  String get navOpenCamera => 'Otwórz aparat';

  @override
  String get navUnknown => 'Nieznane';

  @override
  String get navExploreClassics => 'Klasyki';

  @override
  String get navExploreNewVideos => 'Nowe filmy';

  @override
  String get navExploreTrending => 'Na topie';

  @override
  String get navExploreForYou => 'Dla ciebie';

  @override
  String get navExploreLists => 'Listy';

  @override
  String get routeErrorTitle => 'Błąd';

  @override
  String get routeInvalidHashtag => 'Nieprawidłowy hashtag';

  @override
  String get routeInvalidConversationId => 'Nieprawidłowy ID rozmowy';

  @override
  String get routeInvalidRequestId => 'Nieprawidłowy ID żądania';

  @override
  String get routeInvalidListId => 'Nieprawidłowy ID listy';

  @override
  String get routeInvalidUserId => 'Nieprawidłowy ID użytkownika';

  @override
  String get routeInvalidVideoId => 'Nieprawidłowy ID filmu';

  @override
  String get routeInvalidSoundId => 'Nieprawidłowy ID dźwięku';

  @override
  String get routeInvalidCategory => 'Nieprawidłowa kategoria';

  @override
  String get routeNoVideosToDisplay => 'Brak filmów do wyświetlenia';

  @override
  String get routeInvalidProfileId => 'Nieprawidłowy ID profilu';

  @override
  String get routeUnknownPath => 'Tej strony nie ma w aplikacji.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Centrum pomocy';

  @override
  String get supportContactSupport => 'Skontaktuj się z pomocą';

  @override
  String get supportContactSupportSubtitle =>
      'Zacznij rozmowę lub zobacz poprzednie wiadomości';

  @override
  String get supportReportBug => 'Zgłoś błąd';

  @override
  String get supportReportBugSubtitle => 'Problemy techniczne z aplikacją';

  @override
  String get supportRequestFeature => 'Poproś o funkcję';

  @override
  String get supportRequestFeatureSubtitle =>
      'Zasugeruj usprawnienie lub nową funkcję';

  @override
  String get supportSaveLogs => 'Zapisz logi';

  @override
  String get supportSaveLogsSubtitle =>
      'Eksportuj logi do pliku do ręcznego wysłania';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Częste pytania i odpowiedzi';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Dowiedz się o weryfikacji i autentyczności';

  @override
  String get supportLoginRequired =>
      'Zaloguj się, żeby skontaktować się z pomocą';

  @override
  String get supportExportingLogs => 'Eksportowanie logów...';

  @override
  String get supportExportLogsFailed => 'Nie udało się wyeksportować logów';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logi zapisano w $path';
  }

  @override
  String get supportRevealLogsAction => 'Pokaż w folderze';

  @override
  String get supportChatNotAvailable => 'Czat z pomocą niedostępny';

  @override
  String get supportCouldNotOpenMessages =>
      'Nie można otworzyć wiadomości pomocy';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Nie można otworzyć $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Błąd otwierania $pageName: $error';
  }

  @override
  String get reportTitle => 'Zgłoś treść';

  @override
  String get reportWhyReporting => 'Dlaczego zgłaszasz tę treść?';

  @override
  String get reportPolicyNotice =>
      'Divine zareaguje na zgłoszenia treści w ciągu 24 godzin, usuwając treść i wyrzucając użytkownika, który dostarczył obraźliwą treść.';

  @override
  String get reportAdditionalDetails => 'Dodatkowe szczegóły (opcjonalnie)';

  @override
  String get reportBlockUser => 'Zablokuj tego użytkownika';

  @override
  String get reportCancel => 'Anuluj';

  @override
  String get reportSubmit => 'Zgłoś';

  @override
  String get reportSelectReason => 'Wybierz powód zgłoszenia tej treści';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Spam lub niechciana treść';

  @override
  String get reportReasonSpamSubtitle =>
      'Niechciane lub powtarzające się treści';

  @override
  String get reportReasonHarassment => 'Nagabywanie, zniesławianie lub groźby';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Szkodliwe i niechciane odpowiedzi lub wzmianki';

  @override
  String get reportReasonViolence => 'Treści brutalne lub ekstremistyczne';

  @override
  String get reportReasonViolenceSubtitle =>
      'Treści brutalne, ekstremistyczne lub szkodliwe';

  @override
  String get reportReasonSexualContent => 'Treści seksualne lub dla dorosłych';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nagość, pornografia lub treści jednoznaczne';

  @override
  String get reportReasonCopyright => 'Naruszenie praw autorskich';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Nieuprawnione użycie własności intelektualnej';

  @override
  String get reportReasonFalseInfo => 'Fałszywe informacje';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Wprowadzające w błąd lub fałszywe twierdzenia';

  @override
  String get reportReasonChildSafety => 'Naruszenie bezpieczeństwa dzieci';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Ogólne obawy o bezpieczeństwo nieletnich';

  @override
  String get reportReasonCsam => 'Wykorzystywanie seksualne dzieci';

  @override
  String get reportReasonCsamSubtitle =>
      'Treści przedstawiające wykorzystywanie seksualne nieletnich';

  @override
  String get reportReasonUnderageUser =>
      'Użytkownik wygląda na osobę poniżej 16 lat';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Właściciel konta wygląda na osobę niepełnoletnią';

  @override
  String get reportReasonAiGenerated => 'Treść wygenerowana przez AI';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Treści podejrzane o wygenerowanie przez AI';

  @override
  String get reportReasonOther => 'Inne naruszenie regulaminu';

  @override
  String get reportReasonOtherSubtitle => 'Naruszenia niewymienione powyżej';

  @override
  String reportFailed(Object error) {
    return 'Nie udało się zgłosić treści: $error';
  }

  @override
  String get reportReceivedTitle => 'Zgłoszenie odebrane';

  @override
  String get reportReceivedThankYou =>
      'Dziękujemy za pomoc w utrzymaniu Divine bezpiecznym.';

  @override
  String get reportReceivedReviewNotice =>
      'Nasz zespół przejrzy twoje zgłoszenie i podejmie odpowiednie działania. Możesz otrzymać aktualizacje przez wiadomość bezpośrednią.';

  @override
  String get reportModerationDmDelayed =>
      'Nie udało nam się teraz bezpośrednio skontaktować z zespołem moderacji, ale twoje zgłoszenie zostało przyjęte i zostanie rozpatrzone.';

  @override
  String get reportContactModeration => 'Napisz do zespołu moderacji';

  @override
  String get reportLearnMore => 'Dowiedz się więcej';

  @override
  String get reportLearnMoreAt => 'Dowiedz się więcej na';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Zamknij';

  @override
  String get listAddToList => 'Dodaj do listy';

  @override
  String listVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count osoby',
      many: '$count osób',
      few: '$count osoby',
      one: '1 osoba',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Autor: ';

  @override
  String get listNewList => 'Nowa lista';

  @override
  String get listDone => 'Gotowe';

  @override
  String get listErrorLoading => 'Błąd wczytywania list';

  @override
  String listRemovedFrom(String name) {
    return 'Usunięto z $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Dodano do $name';
  }

  @override
  String get listCreateNewList => 'Utwórz nową listę';

  @override
  String get listNewPeopleList => 'Nowa lista osób';

  @override
  String get listCollaboratorsNone => 'Brak';

  @override
  String get listAddCollaboratorTitle => 'Dodaj współpracownika';

  @override
  String get listCollaboratorSearchHint => 'Szukaj w diVine...';

  @override
  String get listNameLabel => 'Nazwa listy';

  @override
  String get listDescriptionLabel => 'Opis (opcjonalnie)';

  @override
  String get listPublicList => 'Publiczna lista';

  @override
  String get listPublicListSubtitle =>
      'Inni mogą obserwować i widzieć tę listę';

  @override
  String get listCancel => 'Anuluj';

  @override
  String get listCreate => 'Utwórz';

  @override
  String get listCreateFailed => 'Nie udało się utworzyć listy';

  @override
  String get keyManagementTitle => 'Klucze Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Czym są klucze Nostr?';

  @override
  String get keyManagementExplanation =>
      'Twoja tożsamość Nostr to kryptograficzna para kluczy:\n\n• Twój klucz publiczny (npub) jest jak nazwa użytkownika - udostępniaj go swobodnie\n• Twój klucz prywatny (nsec) jest jak hasło - trzymaj w tajemnicy!\n\nTwój nsec pozwala ci uzyskać dostęp do konta w dowolnej aplikacji Nostr.';

  @override
  String get keyManagementImportTitle => 'Importuj istniejący klucz';

  @override
  String get keyManagementImportSubtitle =>
      'Masz już konto Nostr? Wklej swój klucz prywatny (nsec), żeby uzyskać tutaj dostęp.';

  @override
  String get keyManagementImportButton => 'Importuj klucz';

  @override
  String get keyManagementImportWarning => 'To zastąpi twój aktualny klucz!';

  @override
  String get keyManagementBackupTitle => 'Zrób kopię zapasową klucza';

  @override
  String get keyManagementBackupSubtitle =>
      'Zapisz swój klucz prywatny (nsec), żeby używać konta w innych aplikacjach Nostr.';

  @override
  String get keyManagementCopyNsec => 'Kopiuj mój klucz prywatny (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Nigdy nie udostępniaj swojego nsec nikomu!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'To konto podpisuje za pomocą Keycast. Na tym urządzeniu nie ma zapisanego klucza prywatnego, więc nie ma tu nsec do skopiowania.';

  @override
  String get keyManagementRestrictedTitle => 'Your keys are managed by Divine';

  @override
  String get keyManagementRestrictedBody =>
      'To keep your account safe, key backup and importing a different key aren\'t available here.';

  @override
  String get keyManagementPasteKey => 'Wklej swój klucz prywatny';

  @override
  String get keyManagementInvalidFormat =>
      'Nieprawidłowy format klucza. Musi zaczynać się od \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importować ten klucz?';

  @override
  String get keyManagementConfirmImportBody =>
      'To zastąpi twoją aktualną tożsamość importowaną.\n\nTwój aktualny klucz zostanie utracony, chyba że zrobiłeś najpierw kopię zapasową.';

  @override
  String get keyManagementImportConfirm => 'Importuj';

  @override
  String get keyManagementImportSuccess => 'Klucz zaimportowany pomyślnie!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Nie udało się zaimportować klucza: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Klucz prywatny skopiowany do schowka!\n\nPrzechowuj go w bezpiecznym miejscu.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Nie udało się wyeksportować klucza: $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Twój klucz publiczny (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Kopiuj klucz publiczny';

  @override
  String get keyManagementPublicKeyCopied => 'Skopiowano klucz publiczny';

  @override
  String get profileEditPublicKeyLink => 'Zobacz swój klucz publiczny';

  @override
  String get saveOriginalSavedToCameraRoll => 'Zapisano w rolce aparatu';

  @override
  String get saveOriginalShare => 'Udostępnij';

  @override
  String get saveOriginalDone => 'Gotowe';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Potrzebny dostęp do zdjęć';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Aby zapisać filmy, zezwól na dostęp do Zdjęć w Ustawieniach.';

  @override
  String get saveOriginalOpenSettings => 'Otwórz Ustawienia';

  @override
  String get saveOriginalNotNow => 'Nie teraz';

  @override
  String get saveOriginalDownloadFailed => 'Pobieranie nieudane';

  @override
  String get saveOriginalDismiss => 'Odrzuć';

  @override
  String get saveOriginalDownloadingVideo => 'Pobieranie filmu';

  @override
  String get saveOriginalSavingToCameraRoll => 'Zapisywanie w rolce aparatu';

  @override
  String get saveOriginalFetchingVideo => 'Pobieranie filmu z sieci...';

  @override
  String get saveOriginalSavingVideo =>
      'Zapisywanie oryginalnego filmu w rolce aparatu...';

  @override
  String get soundTitle => 'Dźwięk';

  @override
  String get soundOriginalSound => 'Oryginalny dźwięk';

  @override
  String get soundVideosUsingThisSound => 'Filmy używające tego dźwięku';

  @override
  String get soundSourceVideo => 'Film źródłowy';

  @override
  String get soundNoVideosYet => 'Brak filmów';

  @override
  String get soundBeFirstToUse => 'Bądź pierwszy, który użyje tego dźwięku!';

  @override
  String get soundFailedToLoadVideos => 'Nie udało się wczytać filmów';

  @override
  String get soundRetry => 'Spróbuj ponownie';

  @override
  String get soundVideosUnavailable => 'Filmy niedostępne';

  @override
  String get soundCouldNotLoadDetails => 'Nie można wczytać szczegółów filmu';

  @override
  String get soundPreview => 'Podgląd';

  @override
  String get soundStop => 'Zatrzymaj';

  @override
  String get soundUseSound => 'Użyj dźwięku';

  @override
  String get soundUntitled => 'Dźwięk bez tytułu';

  @override
  String get soundStopPreview => 'Zatrzymaj podgląd';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Odsłuchaj $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Zobacz szczegóły dźwięku $title';
  }

  @override
  String get soundNoVideoCount => 'Brak filmów';

  @override
  String get soundOneVideo => '1 film';

  @override
  String soundVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmu',
      many: '$count filmów',
      few: '$count filmy',
      one: '1 film',
    );
    return '$_temp0';
  }

  @override
  String get soundUnableToPreview =>
      'Nie można odtworzyć podglądu dźwięku - brak dostępnego audio';

  @override
  String soundPreviewFailed(Object error) {
    return 'Nie udało się odtworzyć podglądu: $error';
  }

  @override
  String get soundViewSource => 'Zobacz źródło';

  @override
  String get soundCloseTooltip => 'Zamknij';

  @override
  String get exploreNotExploreRoute => 'Nie jest trasa eksploracji';

  @override
  String get legalTitle => 'Informacje prawne';

  @override
  String get legalTermsOfService => 'Regulamin';

  @override
  String get legalTermsOfServiceSubtitle => 'Warunki i zasady użytkowania';

  @override
  String get legalPrivacyPolicy => 'Polityka prywatności';

  @override
  String get legalPrivacyPolicySubtitle => 'Jak obchodzimy się z twoimi danymi';

  @override
  String get legalSafetyStandards => 'Standardy bezpieczeństwa';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Wytyczne społeczności i bezpieczeństwo';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Polityka praw autorskich i usuwania';

  @override
  String get legalOpenSourceLicenses => 'Licencje open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atrybucje pakietów stron trzecich';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Nie można otworzyć $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Błąd otwierania $pageName: $error';
  }

  @override
  String get categoryAction => 'Akcja';

  @override
  String get categoryAdventure => 'Przygoda';

  @override
  String get categoryAnimals => 'Zwierzęta';

  @override
  String get categoryAnimation => 'Animacja';

  @override
  String get categoryArchitecture => 'Architektura';

  @override
  String get categoryArt => 'Sztuka';

  @override
  String get categoryAutomotive => 'Motoryzacja';

  @override
  String get categoryAwardShow => 'Gala nagród';

  @override
  String get categoryAwards => 'Nagrody';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Koszykówka';

  @override
  String get categoryBeauty => 'Uroda';

  @override
  String get categoryBeverage => 'Napoje';

  @override
  String get categoryCars => 'Samochody';

  @override
  String get categoryCelebration => 'Święto';

  @override
  String get categoryCelebrities => 'Celebryci';

  @override
  String get categoryCelebrity => 'Celebryta';

  @override
  String get categoryCityscape => 'Pejzaż miejski';

  @override
  String get categoryComedy => 'Komedia';

  @override
  String get categoryConcert => 'Koncert';

  @override
  String get categoryCooking => 'Gotowanie';

  @override
  String get categoryCostume => 'Kostium';

  @override
  String get categoryCrafts => 'Rękodzieło';

  @override
  String get categoryCrime => 'Kryminał';

  @override
  String get categoryCulture => 'Kultura';

  @override
  String get categoryDance => 'Taniec';

  @override
  String get categoryDiy => 'Zrób to sam';

  @override
  String get categoryDrama => 'Dramat';

  @override
  String get categoryEducation => 'Edukacja';

  @override
  String get categoryEmotional => 'Emocjonalne';

  @override
  String get categoryEmotions => 'Emocje';

  @override
  String get categoryEntertainment => 'Rozrywka';

  @override
  String get categoryEvent => 'Wydarzenie';

  @override
  String get categoryFamily => 'Rodzina';

  @override
  String get categoryFans => 'Fani';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festiwal';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Jedzenie';

  @override
  String get categoryFootball => 'Futbol';

  @override
  String get categoryFurniture => 'Meble';

  @override
  String get categoryGaming => 'Gry';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Pielęgnacja';

  @override
  String get categoryGuitar => 'Gitara';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Zdrowie';

  @override
  String get categoryHockey => 'Hokej';

  @override
  String get categoryHoliday => 'Wakacje';

  @override
  String get categoryHome => 'Dom';

  @override
  String get categoryHomeImprovement => 'Remont';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Szpital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Wnętrza';

  @override
  String get categoryInterview => 'Wywiad';

  @override
  String get categoryKids => 'Dzieci';

  @override
  String get categoryLifestyle => 'Styl życia';

  @override
  String get categoryMagic => 'Magia';

  @override
  String get categoryMakeup => 'Makijaż';

  @override
  String get categoryMedical => 'Medycyna';

  @override
  String get categoryMusic => 'Muzyka';

  @override
  String get categoryMystery => 'Tajemnica';

  @override
  String get categoryNature => 'Natura';

  @override
  String get categoryNews => 'Wiadomości';

  @override
  String get categoryOutdoor => 'Na świeżym powietrzu';

  @override
  String get categoryParty => 'Impreza';

  @override
  String get categoryPeople => 'Ludzie';

  @override
  String get categoryPerformance => 'Występ';

  @override
  String get categoryPets => 'Zwierzaki';

  @override
  String get categoryPolitics => 'Polityka';

  @override
  String get categoryPrank => 'Psikus';

  @override
  String get categoryPranks => 'Psikusy';

  @override
  String get categoryRealityShow => 'Reality show';

  @override
  String get categoryRelationship => 'Związek';

  @override
  String get categoryRelationships => 'Związki';

  @override
  String get categoryRomance => 'Romans';

  @override
  String get categorySchool => 'Szkoła';

  @override
  String get categoryScienceFiction => 'Science fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Zakupy';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Pielęgnacja skóry';

  @override
  String get categorySoccer => 'Piłka nożna';

  @override
  String get categorySocialGathering => 'Spotkanie';

  @override
  String get categorySocialMedia => 'Media społecznościowe';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologia';

  @override
  String get categoryTelevision => 'Telewizja';

  @override
  String get categoryToys => 'Zabawki';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Podróże';

  @override
  String get categoryUrban => 'Miejskie';

  @override
  String get categoryViolence => 'Przemoc';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogowanie';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadStaged =>
      'Przesłano — dotknij Zapisz, aby zastosować';

  @override
  String inboxReportedUser(String displayName) {
    return 'Zgłoszono $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Zablokowano $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Odblokowano $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Usunięto rozmowę';

  @override
  String get inboxRestoringMessages => 'Odzyskiwanie wiadomości…';

  @override
  String get inboxEmptyTitle => 'Brak wiadomości';

  @override
  String get inboxEmptySubtitle => 'Ten przycisk + nie gryzie.';

  @override
  String get inboxActionMute => 'Wycisz rozmowę';

  @override
  String inboxActionReport(String displayName) {
    return 'Zgłoś $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Zablokuj $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Odblokuj $displayName';
  }

  @override
  String get inboxActionRemove => 'Usuń rozmowę';

  @override
  String get inboxRemoveConfirmTitle => 'Usunąć rozmowę?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Spowoduje to usunięcie rozmowy z $displayName. Tej operacji nie można cofnąć.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Usuń';

  @override
  String get inboxConversationMuted => 'Wyciszono rozmowę';

  @override
  String get inboxConversationUnmuted => 'Wyłączono wyciszenie rozmowy';

  @override
  String get inboxCollabInviteCardTitle => 'Zaproszenie do współpracy';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Film bez tytułu';

  @override
  String get clickableTextViewVideoLink => 'Zobacz wideo';

  @override
  String get messageExternalLinkDialogTitle => 'Otworzyć link zewnętrzny?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Ten link prowadzi do zewnętrznej strony i może nie być bezpieczny:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Otwórz';

  @override
  String get inboxCollabInviteCoPostButton => 'Współopublikuj';

  @override
  String get inboxCollabInviteNotMineButton => 'Nie moje';

  @override
  String get inboxCollabInvitePreviewTitle =>
      'Zaproszenie do współopublikowania';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Zaproszenie do współopublikowania od $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Współopublikowanie doda ten film do Twojej osi czasu jako współpracę.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Zaakceptowano';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Zignorowano';

  @override
  String get inboxCollabInviteAcceptError =>
      'Nie udało się zaakceptować. Spróbuj ponownie.';

  @override
  String get inboxCollabInviteSentStatus => 'Zaproszenie wysłane';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Zaproszenie do współpracy';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Zaproszono Cię do współpracy nad $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Zaproszono Cię do współpracy nad filmem: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count zaproszenia dla współtwórców nie zostało wysłanych.',
      many: '$count zaproszeń dla współtwórców nie zostało wysłanych.',
      few: '$count zaproszenia dla współtwórców nie zostały wysłane.',
      one: '1 zaproszenie dla współtwórcy nie zostało wysłane.',
    );
    return 'Film opublikowany, ale $_temp0';
  }

  @override
  String get dmSendBlockedMessage =>
      'You can only message official Divine accounts';

  @override
  String get dmSendFailedMessage => 'Nie udało się wysłać wiadomości';

  @override
  String get dmSendFailedRetry => 'Spróbuj ponownie';

  @override
  String get dmSendPartialMessage =>
      'Wysłano, ale nie zsynchronizowano z twoimi innymi urządzeniami';

  @override
  String get dmConversationLoadError => 'Nie udało się wczytać wiadomości';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => 'Wysłana wiadomość';

  @override
  String get dmMessageBubbleReceivedHint => 'Otrzymana wiadomość';

  @override
  String get dmMessageBubbleLongPressHint => 'Akcje wiadomości';

  @override
  String get dmMessageActionCopyText => 'Kopiuj tekst';

  @override
  String get dmMessageActionCopyVideoUrl => 'Kopiuj URL filmu';

  @override
  String get dmMessageActionDeleteForEveryone => 'Usuń dla wszystkich';

  @override
  String get dmMessageActionReport => 'Zgłoś';

  @override
  String get dmReactionAddCustomA11yLabel => 'Add custom emoji reaction';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Wyślij wiadomość do $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Odpowiedz sobie…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Odpowiedz na ten reel';

  @override
  String get dmReelReplyViewChat => 'Zobacz czat';

  @override
  String get dmReelReplyViewChatA11yLabel => 'Otwórz czat';

  @override
  String get dmReelReplySentAnnouncement => 'Odpowiedź wysłana';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Zareagowano $emoji';
  }

  @override
  String get dmReelReplyFailed => 'Nie udało się wysłać';

  @override
  String dmReactionChipOwnA11yLabel(String emoji) {
    return 'Your reaction: $emoji';
  }

  @override
  String dmReactionChipOtherA11yLabel(String name, String emoji) {
    return '$name reacted with $emoji';
  }

  @override
  String dmReactionChipPendingA11yLabel(String emoji) {
    return 'Sending reaction: $emoji';
  }

  @override
  String get dmReactionChipFailedA11yLabel =>
      'Reaction failed, double tap to retry';

  @override
  String get dmReactionChipRetryAnnouncement => 'Retrying reaction';

  @override
  String get dmReactionsSheetTitle => 'Reakcje';

  @override
  String get dmReactionsViewA11yLabel => 'Zobacz, kto zareagował';

  @override
  String get dmReactionRemoveAction => 'Usuń';

  @override
  String get dmReactionRetryAction => 'Spróbuj ponownie';

  @override
  String get dmFormatBold => 'Pogrubienie';

  @override
  String get dmFormatItalic => 'Kursywa';

  @override
  String get dmFormatStrikethrough => 'Przekreślenie';

  @override
  String get dmFormatCode => 'Kod';

  @override
  String get dmStatusPending => 'Wysyłanie';

  @override
  String get dmStatusFailed => 'Nie udało się wysłać';

  @override
  String get dmStatusDeliveredSelfFailed =>
      'Dostarczone. Nie zsynchronizuje się z twoimi innymi urządzeniami.';

  @override
  String get inboxConversationActionsSheetLabel => 'Akcje konwersacji';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Konwersacja z $displayName';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Pokaż akcje konwersacji';

  @override
  String get reportDialogCancel => 'Anuluj';

  @override
  String get reportDialogReport => 'Zgłoś';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Tytuł: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Film $current/$total';
  }

  @override
  String get exploreSearchHint => 'Szukaj...';

  @override
  String categoryVideoCount(String count) {
    return '$count filmów';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Nie udało się zaktualizować subskrypcji: $error';
  }

  @override
  String get discoverListsTitle => 'Odkrywaj listy';

  @override
  String get discoverListsFailedToLoad => 'Nie udało się wczytać list';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Nie udało się wczytać list: $error';
  }

  @override
  String get discoverListsLoading => 'Odkrywanie publicznych list...';

  @override
  String get discoverListsEmptyTitle => 'Nie znaleziono publicznych list';

  @override
  String get discoverListsEmptySubtitle => 'Wróć później po nowe listy';

  @override
  String get discoverListsByAuthorPrefix => 'od';

  @override
  String get curatedListEmptyTitle => 'Brak filmów na tej liście';

  @override
  String get curatedListEmptySubtitle => 'Dodaj kilka filmów, żeby zacząć';

  @override
  String get curatedListLoadingVideos => 'Wczytywanie filmów...';

  @override
  String get curatedListFailedToLoad => 'Nie udało się wczytać listy';

  @override
  String get curatedListNoVideosAvailable => 'Brak dostępnych filmów';

  @override
  String get curatedListVideoNotAvailable => 'Film niedostępny';

  @override
  String get curatedListActionsTooltip => 'Akcje listy';

  @override
  String get curatedListUnfollowAction => 'Przestań obserwować listę';

  @override
  String get curatedListUnfollowedSnack => 'Przestano obserwować listę';

  @override
  String get curatedListUnfollowFailed =>
      'Nie udało się przestać obserwować listy';

  @override
  String get curatedListDeleteConfirmTitle => 'Usunąć listę?';

  @override
  String get curatedListDeleteConfirmBody =>
      'To usunie listę z przekaźników. Filmy z listy nie zostaną usunięte.';

  @override
  String get curatedListDeletedSnack => 'Lista usunięta';

  @override
  String get curatedListDeleteFailed => 'Nie udało się usunąć listy';

  @override
  String get peopleListsActionsTooltip => 'Akcje listy';

  @override
  String get listDeleteAction => 'Usuń listę';

  @override
  String get peopleListsDeleteConfirmTitle => 'Usunąć listę?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'To usunie listę dla wszystkich. Osoby z listy nie przestaną być obserwowane.';

  @override
  String get peopleListsDeleteFailed => 'Nie udało się usunąć listy';

  @override
  String get commonRetry => 'Ponów';

  @override
  String get commonSomethingWentWrong => 'Coś poszło nie tak';

  @override
  String get commonNext => 'Dalej';

  @override
  String get commonDelete => 'Usuń';

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get commonBack => 'Wstecz';

  @override
  String get commonClose => 'Zamknij';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Nie udało się zaktualizować okładki. Spróbuj ponownie.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement =>
      'Zaktualizowano okładkę';

  @override
  String get videoMetadataTags => 'Tagi';

  @override
  String get videoMetadataExpiration => 'Wygaśnięcie';

  @override
  String get videoMetadataExpirationNotExpire => 'Nie wygasa';

  @override
  String get videoMetadataExpirationOneDay => '1 dzień';

  @override
  String get videoMetadataExpirationOneWeek => '1 tydzień';

  @override
  String get videoMetadataExpirationOneMonth => '1 miesiąc';

  @override
  String get videoMetadataExpirationOneYear => '1 rok';

  @override
  String get videoMetadataExpirationOneDecade => '1 dekada';

  @override
  String get videoMetadataContentWarnings => 'Ostrzeżenia o treści';

  @override
  String get videoEditorStickers => 'Naklejki';

  @override
  String get trendingTitle => 'Na czasie';

  @override
  String get libraryDeleteConfirm => 'Usuń';

  @override
  String get libraryWebUnavailableHeadline =>
      'Biblioteka jest w aplikacji mobilnej';

  @override
  String get libraryWebUnavailableDescription =>
      'Wersje robocze i klipy są na urządzeniu — otwórz Divine w telefonie, żeby nimi zarządzać.';

  @override
  String get libraryTabDrafts => 'Wersje robocze';

  @override
  String get libraryTabClips => 'Klify';

  @override
  String get librarySaveToCameraRollTooltip => 'Zapisz w albumie';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Usuń wybrane klipy';

  @override
  String get librarySelect => 'Wybierz';

  @override
  String get librarySortNewestCreation => 'Najnowsze utworzone';

  @override
  String get librarySortOldestCreation => 'Najstarsze utworzone';

  @override
  String get librarySortLongestClip => 'Najdłuższy klip';

  @override
  String get librarySortShortestClip => 'Najkrótszy klip';

  @override
  String get librarySortSquareFirst => 'Najpierw kwadratowe';

  @override
  String get librarySortVerticalFirst => 'Najpierw pionowe';

  @override
  String get libraryDeleteClipsTitle => 'Usuń klipy';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# wybranych klipów',
      many: '# wybranych klipów',
      few: '# wybrane klipy',
      one: '# wybrany klip',
    );
    return 'Na pewno usunąć $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Tego nie cofniesz. Pliki wideo zostaną trwale usunięte z urządzenia.';

  @override
  String get libraryPreparingVideo => 'Przygotowywanie wideo...';

  @override
  String get libraryCreateVideo => 'Utwórz wideo';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zapisano $count klipów',
      many: 'Zapisano $count klipów',
      few: 'Zapisano $count klipy',
      one: 'Zapisano 1 klip',
    );
    return '$_temp0 w $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return 'Zapisano $successCount, niepowodzeń: $failureCount';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Odmowa uprawnień: $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Usunięto $count klipów',
      many: 'Usunięto $count klipów',
      few: 'Usunięto $count klipy',
      one: 'Usunięto 1 klip',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Cofnij';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Zostanie automatycznie usunięty za $daysLeft dni',
      one: 'Zostanie automatycznie usunięty jutro',
      zero: 'Zostanie automatycznie usunięty dzisiaj',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Nie udało się wczytać wersji roboczych';

  @override
  String get libraryCouldNotLoadClips => 'Nie udało się wczytać klipów';

  @override
  String get libraryOpenErrorDescription =>
      'Coś poszło nie tak przy otwieraniu biblioteki. Możesz spróbować ponownie.';

  @override
  String get libraryNoDraftsYetTitle => 'Brak wersji roboczych';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Wideo zapisane jako wersja robocza pojawi się tutaj';

  @override
  String get libraryNoClipsYetTitle => 'Brak klipów';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Nagrane klipy wideo pojawią się tutaj';

  @override
  String get libraryDraftDeletedSnackbar => 'Usunięto wersję roboczą';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Nie udało się usunąć wersji roboczej';

  @override
  String get libraryDraftActionPost => 'Opublikuj';

  @override
  String get libraryDraftActionEdit => 'Edytuj';

  @override
  String get libraryDraftActionDelete => 'Usuń wersję roboczą';

  @override
  String get libraryDeleteDraftTitle => 'Usuń wersję roboczą';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Na pewno usunąć „$title”?';
  }

  @override
  String get libraryDeleteClipTitle => 'Usuń klip';

  @override
  String get libraryDeleteClipMessage => 'Na pewno usunąć ten klip?';

  @override
  String get libraryClipSelectionTitle => 'Klify';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Zostało ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Dodaj';

  @override
  String get libraryRecordVideo => 'Nagraj wideo';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Klip wideo, $duration sekund';
  }

  @override
  String get videoClipSemanticValueSelected => 'Zaznaczono';

  @override
  String get videoClipSemanticValueNotSelected => 'Niezaznaczono';

  @override
  String get videoClipSemanticHintDisabled => 'Wyłączono';

  @override
  String get videoClipSemanticHintSelect =>
      'Dotknij, aby wybrać, przytrzymaj, aby podejrzeć';

  @override
  String get videoClipSemanticHintDeselect =>
      'Dotknij, aby odznaczyć, przytrzymaj, aby podejrzeć';

  @override
  String get routerInvalidCreator => 'Nieprawidłowy twórca';

  @override
  String get routerInvalidHashtagRoute => 'Nieprawidłowa ścieżka hashtagu';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Nie udało się załadować filmów';

  @override
  String get categoryGalleryNoVideosInCategory => 'Brak filmów w tej kategorii';

  @override
  String get categoryGallerySortOptionsLabel => 'Opcje sortowania kategorii';

  @override
  String get categoryGallerySortHot => 'Na czasie';

  @override
  String get categoryGallerySortNew => 'Nowe';

  @override
  String get categoryGallerySortClassic => 'Klasyki';

  @override
  String get categoryGallerySortForYou => 'Dla ciebie';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Nie udało się załadować kategorii';

  @override
  String get categoriesNoCategoriesAvailable => 'Brak dostępnych kategorii';

  @override
  String get notificationsEmptyTitle => 'Brak aktywności';

  @override
  String get notificationsEmptySubtitle =>
      'Gdy ludzie zaczną wchodzić w interakcję z twoimi treściami, zobaczysz to tutaj';

  @override
  String get appsPermissionsTitle => 'Uprawnienia integracji';

  @override
  String get appsPermissionsRevoke => 'Cofnij';

  @override
  String get appsPermissionsEmptyTitle =>
      'Brak zapamiętanych uprawnień integracji';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Zatwierdzone integracje pojawią się tutaj, gdy zapamiętasz zgodę na dostęp.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName prosi o twoją zgodę';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Ta aplikacja prosi o dostęp przez sprawdzoną piaskownicę Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Źródło';

  @override
  String get nostrAppPermissionMethod => 'Metoda';

  @override
  String get nostrAppPermissionCapability => 'Uprawnienie';

  @override
  String get nostrAppPermissionEventKind => 'Typ zdarzenia';

  @override
  String get nostrAppPermissionAllow => 'Zezwól';

  @override
  String get appsDetailDefaultTitle => 'Zintegrowana aplikacja';

  @override
  String get appsDetailNotFoundTitle => 'Nie znaleziono integracji';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Ta zatwierdzona integracja nie jest już dostępna w Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Jak to działa';

  @override
  String get appsDetailHowItWorksBody =>
      'To zatwierdzona aplikacja innej firmy, która działa wewnątrz Divine. Divine przyznaje tylko sprawdzone uprawnienia dla tej integracji i blokuje nawigację poza jej zatwierdzone źródła.';

  @override
  String get appsDetailAboutTitle => 'O aplikacji';

  @override
  String get appsDetailPrimaryOriginTitle => 'Główne źródło';

  @override
  String get appsDetailApprovedOriginsTitle => 'Zatwierdzone źródła';

  @override
  String get appsDetailCapabilitiesTitle => 'Dostępne uprawnienia';

  @override
  String get appsDetailAskBeforeTitle => 'Pytaj przed';

  @override
  String get appsDetailOpenButton => 'Otwórz integrację';

  @override
  String get appsDetailNoneDeclared => 'Nic jeszcze nie zadeklarowano';

  @override
  String get appsDirectoryTitle => 'Zintegrowane aplikacje';

  @override
  String get appsDirectoryIntroTitle => 'Zatwierdzone aplikacje innych firm';

  @override
  String get appsDirectoryIntroBody =>
      'Zatwierdzone aplikacje innych firm działające wewnątrz Divine';

  @override
  String get appsDirectoryErrorTitle =>
      'Nie udało się wczytać zintegrowanych aplikacji';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Pociągnij, aby ponownie spróbować zatwierdzonych integracji.';

  @override
  String get appsDirectoryEmptyTitle => 'Brak zatwierdzonych integracji';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Zatwierdzone aplikacje innych firm pojawią się tutaj, gdy Divine je doda.';

  @override
  String get appsDirectoryRefresh => 'Odśwież';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Zintegrowane aplikacje działają w Divine na urządzeniach mobilnych';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Zatwierdzone integracje są na razie dostępne tylko na urządzeniach mobilnych.';

  @override
  String get appsSandboxUnavailableTitle => 'Integracja niedostępna';

  @override
  String get appsSandboxUnavailableBody =>
      'Otwieraj zatwierdzone integracje z zakładki Zintegrowane aplikacje, aby Divine mogło zastosować właściwą politykę dostępu.';

  @override
  String get appsSandboxLoadingTitle => 'Wczytywanie integracji';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Sprawdzanie zatwierdzonej integracji przed uruchomieniem.';

  @override
  String get appsSandboxBlockedTitle => 'Zablokowane dla bezpieczeństwa';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Ta integracja próbowała opuścić swoje zatwierdzone źródło.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link do posta skopiowany do schowka';

  @override
  String get shareCopiedEventJson =>
      'JSON zdarzenia Nostr skopiowany do schowka';

  @override
  String get shareCopiedEventId => 'ID zdarzenia Nostr skopiowane do schowka';

  @override
  String get authHeroTaglineAuthentic => 'Autentyczne chwile.';

  @override
  String get authHeroTaglineHuman => 'Ludzka kreatywność.';

  @override
  String get keyImportFailedToImport =>
      'Nie udało się zaimportować klucza ani połączyć z bunkrem';

  @override
  String get keyImportInvalidBunkerUrl => 'Nieprawidłowy URL bunkra';

  @override
  String get keyImportInvalidFormat =>
      'Nieprawidłowy format. Użyj nsec..., hex, ncryptsec1... lub bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Nieprawidłowy format nsec. Powinien mieć 63 znaki';

  @override
  String get keyImportKeyFieldLabel => 'Klucz prywatny lub URL bunkra';

  @override
  String get keyImportKeyRequired =>
      'Wprowadź swój klucz prywatny lub URL bunkra';

  @override
  String get keyImportPasswordRequired =>
      'Wprowadź hasło do tego zaszyfrowanego klucza';

  @override
  String get keyImportSecurityWarningBody =>
      'Nigdy nie udostępniaj nikomu swojego klucza prywatnego. Ten klucz daje pełny dostęp do twojej tożsamości Nostr.';

  @override
  String get keyImportSecurityWarningTitle =>
      'Trzymaj swój klucz prywatny w bezpiecznym miejscu!';

  @override
  String get keyImportSubtitle =>
      'Zaimportuj swoją istniejącą tożsamość Nostr za pomocą klucza prywatnego lub URL bunkra.';

  @override
  String get keyImportTitle => 'Zaimportuj swoją\ntożsamość Nostr';

  @override
  String get commentAuthorYouIndicator => 'Ty';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Zobacz profil użytkownika $name';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Usuń komentarz';

  @override
  String get commentOptionsEditSemanticLabel => 'Edytuj komentarz';

  @override
  String get commentOptionsFlagContentLabel => 'Zgłoś treść';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Zgłoś tę treść';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Wybierz powód zgłoszenia tego komentarza';

  @override
  String get commentOptionsFlagSubmit => 'Wyślij';

  @override
  String get commentOptionsTitle => 'Opcje';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Wciąż pracujemy nad importem starych komentarzy z archiwum. Nie są jeszcze gotowe.';

  @override
  String get commentsEmptyClassicVineTitle => 'Klasyczny Vine';

  @override
  String get commentsInputEditingLabel => 'Edytowanie';

  @override
  String get commentsInputSemanticHint => 'Dodaj komentarz';

  @override
  String get commentsInputSemanticHintEdit => 'Edytuj komentarz';

  @override
  String get commentsInputSemanticHintReply => 'Dodaj odpowiedź';

  @override
  String get commentsInputSemanticLabel => 'Pole komentarza';

  @override
  String get commentsInputSemanticLabelEdit => 'Pole edycji';

  @override
  String get commentsInputSemanticLabelReply => 'Pole odpowiedzi';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Zobacz profil użytkownika $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Archiwum Klasyków jest wczytywane';

  @override
  String get classicsEmptyTitle => 'Nie znaleziono Klasyków';

  @override
  String get classicsErrorTitle => 'Nie udało się wczytać Klasyków';

  @override
  String get classicsUnavailableDescription =>
      'Klasyki są dostępne tylko po połączeniu z przekaźnikami Funnelcake.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Przełącz się na przekaźnik obsługujący Funnelcake w Ustawieniach, aby uzyskać dostęp do archiwum Klasyków.';

  @override
  String get classicsUnavailableTitle => 'Klasyki niedostępne';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Bądź pierwszą osobą, która opublikuje film z tym hashtagiem!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Nie znaleziono filmów dla #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'To może chwilę potrwać';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Wczytywanie filmów o #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Dodaj hashtagi... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Zajrzyj później po nowe treści';

  @override
  String get newVideosTabEmptyTitle => 'Brak filmów w Nowych filmach';

  @override
  String get popularVideosContextTitle => 'Popularne filmy';

  @override
  String get popularVideosEmptySubtitle => 'Zajrzyj później po nowe treści';

  @override
  String get popularVideosEmptyTitle => 'Brak filmów w Popularnych filmach';

  @override
  String get popularVideosErrorTitle =>
      'Nie udało się wczytać popularnych filmów';

  @override
  String get popularVideosFeedSourceLabel => 'Źródło popularnego kanału';

  @override
  String get trendingHashtagsLoading => 'Wczytywanie hashtagów...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Zobacz filmy oznaczone $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Autor filmu: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Opis filmu: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Wizją Divine jest dać ci prawdziwy wybór algorytmu. Zamiast być zamkniętym w jednym algorytmie działającym jak czarna skrzynka, będziesz mieć możliwość wyboru spośród wielu podejść do rekomendacji:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronologiczna oś czasu od obserwowanych twórców';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'To daje ci kontrolę nad twoją uwagą, zamiast zostawiać ją platformie. Powinieneś wiedzieć, jak twój kanał jest kuratorowany, i mieć możliwość zmiany tego, kiedy tylko chcesz.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Tworzone przez społeczność niestandardowe kanały na tematy takie jak muzyka, komedia czy sztuka';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Spersonalizowany kanał „Dla Ciebie”';

  @override
  String get forYouAlgorithmChoiceTitle => 'Twój algorytm, twój wybór';

  @override
  String get forYouAlgorithmChoiceTrending => 'Popularne i modne treści';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Silny sygnał — byłeś na tyle zaangażowany, by odpowiedzieć';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine zwraca uwagę na to, jak wchodzisz w interakcję z treściami, aby zrozumieć, co lubisz. Za każdym razem, gdy oglądasz film, reagujesz na niego, zostawiasz komentarz lub go repostujesz, system to odnotowuje.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Jak to działa';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Różne działania sygnalizują różny poziom zainteresowania:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Jeśli nie masz jeszcze historii oglądania, pokazujemy mieszankę tego, co obecnie popularne i modne, wraz z najnowszymi wgraniami. To daje ci świetny punkt wyjścia do odkrywania.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'W miarę jak oglądasz, lubisz i angażujesz się w treści, rekomendacje stopniowo stają się bardziej spersonalizowane. Z czasem twój kanał Dla Ciebie wyławia filmy od twórców, których być może nigdy nie odkryłbyś samodzielnie.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Jesteś nowy w Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Budujemy otwarty system, w którym deweloperzy mogą wdrażać własne algorytmy, a ty możesz wybrać, których używać — albo zrezygnować z nich całkowicie.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Otwarte źródło i przejrzystość';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Średni sygnał — szybki sposób na okazanie uznania';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reakcje';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Najsilniejszy sygnał — udostępnienie obserwującym to potężna rekomendacja';

  @override
  String get forYouAlgorithmSubtitle =>
      'Napędzany przez Gorse, silnik rekomendacji o otwartym kodzie źródłowym';

  @override
  String get forYouAlgorithmTitle => 'Algorytm Divine';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Lekki sygnał — wskazuje podstawowe zainteresowanie';

  @override
  String get forYouEmptyDescription =>
      'Obejrzyj i polub kilka filmów, aby otrzymać spersonalizowane rekomendacje.';

  @override
  String get forYouEmptyTitle => 'Brak rekomendacji';

  @override
  String get forYouErrorTitle => 'Nie udało się wczytać rekomendacji';

  @override
  String get forYouUnavailableDescription =>
      'Spersonalizowane rekomendacje wymagają połączenia z Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'Dla Ciebie niedostępne';

  @override
  String get inboxConversationOptionsLabel => 'Opcje';

  @override
  String get inboxConversationViewProfileButton => 'Zobacz profil';

  @override
  String get inboxMessageRequestsEmpty => 'Brak próśb o wiadomość';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Prośby o wiadomość, $requestCount oczekujących';
  }

  @override
  String get inboxMessageRequestsTitle => 'Prośby o wiadomość';

  @override
  String get inboxMessagesTab => 'Wiadomości';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Prośba o wiadomość od $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Wysłał prośbę o wiadomość';

  @override
  String get inboxRequestsMarkAllRead =>
      'Oznacz wszystkie prośby jako przeczytane';

  @override
  String get inboxRequestsRemoveAll => 'Usuń wszystkie prośby';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Odrzuć i usuń';

  @override
  String messageRequestFollowersCount(String count) {
    return '$count obserwujących';
  }

  @override
  String messageRequestVideosCount(String count) {
    return '$count filmów';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count wiadomości',
      many: '$count wiadomości',
      few: '$count wiadomości',
      one: '1 wiadomość',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Zobacz wiadomości';

  @override
  String get messageRequestViewProfileButton => 'Zobacz profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName chce do ciebie napisać, wysłał $messageText.';
  }

  @override
  String get deleteAccountConfirmationHint => 'Wpisz DELETE';

  @override
  String get deleteAccountContentDeletionFailed =>
      'Nie udało się usunąć treści z przekaźników';

  @override
  String get deleteAccountDeleteAllContentButton => 'Usuń wszystkie treści';

  @override
  String get deleteAccountFinalConfirmationBody =>
      'Aby potwierdzić trwałe usunięcie WSZYSTKICH twoich treści z przekaźników Nostr, wpisz:';

  @override
  String get deleteAccountFinalConfirmationTitle =>
      '⚠️ Ostateczne potwierdzenie';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Konto usunięte, ale twoje klucze mogły nie zostać w pełni usunięte z tego urządzenia. Przejdź do Ustawienia → Klucze Nostr → Usuń klucze, aby spróbować ponownie.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Account deleted and signed out, but some local data could not be removed from this device.';

  @override
  String get deleteAccountPreparingDeletion => 'Przygotowywanie usuwania...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total zdarzeń';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'To usuwa lokalne logowanie do tego konta z tego urządzenia. Nie usunie to twojego konta Divine ani tożsamości Nostr.\n\nTwoje wersje robocze i klipy pozostaną zapisane na tym urządzeniu dla tego konta. Jeśli to twoje ostatnie lokalne konto, wrócisz do ekranu logowania.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Usuń z urządzenia';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Usunąć to konto z tego urządzenia?';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Nie udało się usunąć twojego konta z serwera. Sprawdź połączenie i spróbuj ponownie.';

  @override
  String get deleteAccountSuccess => 'Twoje konto zostało usunięte';

  @override
  String get exportProgressStageApplyingTextOverlay =>
      'Dodawanie nakładki tekstowej...';

  @override
  String get exportProgressStageComplete => 'Eksport zakończony!';

  @override
  String get exportProgressStageConcatenating => 'Łączenie klipów...';

  @override
  String get exportProgressStageError => 'Eksport nie powiódł się';

  @override
  String get exportProgressStageGeneratingThumbnail =>
      'Generowanie miniatury...';

  @override
  String get exportProgressStageMixingAudio => 'Dodawanie dźwięku...';

  @override
  String get findPeopleAnonymousUser => 'Anonim';

  @override
  String get findPeopleNoContacts =>
      'Nie znaleziono kontaktów.\nZacznij obserwować ludzi, aby zobaczyć ich tutaj.';

  @override
  String get geoBlockedCityLabel => 'Miasto';

  @override
  String get geoBlockedCountryLabel => 'Kraj';

  @override
  String get geoBlockedDefaultReason =>
      'Ta usługa jest niedostępna w twoim regionie z powodu lokalnych przepisów.';

  @override
  String get geoBlockedLegalNotice =>
      'Szanujemy twoje lokalne prawa i przepisy. To ograniczenie opiera się na lokalizacji twojego adresu IP.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Usługa niedostępna';

  @override
  String get likedVideosEmpty => 'Brak polubionych filmów';

  @override
  String get likedVideosInvalidRoute => 'Nieprawidłowa trasa';

  @override
  String get likedVideosTitle => 'Polubione filmy';

  @override
  String get ogVinerBadgeSemanticLabel => 'OG Viner';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Ponawianie przesyłania…';

  @override
  String get uploadFailureSheetSaveToDraftsButton =>
      'Zapisz do wersji roboczych';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar =>
      'Zapisano do wersji roboczych';

  @override
  String get uploadFailureSheetTitle => 'Przesyłanie nie powiodło się';

  @override
  String get uploadFailureSheetTryAgainButton => 'Spróbuj ponownie';

  @override
  String get videoEditorAudioImportAudio => 'Zaimportuj dźwięk';

  @override
  String get videoEditorAudioImportFailed => 'Import dźwięku nie powiódł się.';

  @override
  String get videoIconPlaceholderLabel => 'Film';

  @override
  String videoInspiredByAttributionSemanticLabel(String creatorName) {
    return 'Zainspirowane przez $creatorName. Dotknij, aby zobaczyć jego profil.';
  }

  @override
  String get proofmodeBadgeAiScanPending => 'Skan AI w toku';

  @override
  String get proofmodeBadgeHumanMade => 'Stworzone przez człowieka';

  @override
  String get proofmodeBadgeNotDivineHosted => 'Nie hostowane przez Divine';

  @override
  String get proofmodeBadgeOriginal => 'Oryginał';

  @override
  String get proofmodeBadgePossiblyAiGenerated =>
      'Możliwe, że wygenerowane przez AI';

  @override
  String get proofmodeBadgeUnverified => 'Niezweryfikowane';

  @override
  String get proofmodeConfirmedByModerator =>
      'Potwierdzone przez moderatora-człowieka';

  @override
  String get proofmodeExternalContentTitle => 'Treść zewnętrzna';

  @override
  String get proofmodeHostedOnLabel => 'Ten film jest hostowany na:';

  @override
  String get proofmodeLikelyHumanCreated =>
      'Prawdopodobnie stworzone przez człowieka';

  @override
  String get proofmodeNoProofDataAttached => 'Nie dołączono danych ProofMode';

  @override
  String get proofmodeNotDivineHostedDisclaimer =>
      'Ta treść nie jest hostowana na serwerach Divine. Nie możemy w pełni zagwarantować jej autentyczności.';

  @override
  String get proofmodePossiblyAiGenerated =>
      'Możliwe, że wygenerowane przez AI';

  @override
  String get proofmodePublishedByLabel => 'Opublikowane przez:';

  @override
  String get publishErrorNotSignedIn => 'Zaloguj się, aby publikować filmy.';

  @override
  String get publishErrorNoRetry => 'Brak przesyłania do ponowienia.';

  @override
  String get publishErrorNoInternet =>
      'Brak połączenia z internetem. Sprawdź Wi-Fi lub dane komórkowe i spróbuj ponownie.';

  @override
  String get publishErrorServerUnreachable =>
      'Nie udało się połączyć z serwerem. Spróbuj ponownie za chwilę.';

  @override
  String get publishErrorTimeout =>
      'Przesyłanie przekroczyło limit czasu. Spróbuj użyć lepszego połączenia lub mniejszego filmu.';

  @override
  String get publishErrorTls =>
      'Bezpieczne połączenie nie powiodło się. Sprawdź swoją sieć — publiczne Wi-Fi może blokować przesyłanie.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Serwer multimediów ($serverName) jest niedostępny. Możesz wybrać inny w ustawieniach.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Plik wideo jest za duży dla serwera. Spróbuj go przyciąć lub obniżyć jakość.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Serwer multimediów ($serverName) napotkał błąd wewnętrzny. Możesz wybrać inny w ustawieniach.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Serwer multimediów ($serverName) jest chwilowo niedostępny. Spróbuj ponownie za moment lub wybierz inny w ustawieniach.';
  }

  @override
  String get publishErrorForbidden =>
      'Nie masz uprawnień, aby przesyłać na ten serwer.';

  @override
  String get publishErrorFileNotFound =>
      'Nie znaleziono pliku wideo. Mógł zostać usunięty. Nagraj ponownie i spróbuj jeszcze raz.';

  @override
  String get publishErrorLowStorage =>
      'Za mało miejsca w pamięci urządzenia. Zwolnij trochę miejsca i spróbuj ponownie.';

  @override
  String get publishErrorThumbnailFailed =>
      'Film został przesłany, ale nie udało się przygotować miniatury. Spróbuj ponownie.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Film został przesłany, ale nie udało się opublikować posta. Sprawdź ustawienia przekaźników i spróbuj ponownie.';

  @override
  String get publishErrorInterrupted =>
      'Przesyłanie zostało przerwane. Chcesz spróbować ponownie?';

  @override
  String get publishErrorGeneric => 'Coś poszło nie tak. Spróbuj ponownie.';

  @override
  String get publishErrorRateLimited =>
      'Zbyt wiele przesyłań w tej chwili. Poczekaj chwilę i spróbuj ponownie.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Sesja przesyłania wygasła. Spróbuj ponownie.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine nie ma uprawnień do przesyłania. Sprawdź uprawnienia aplikacji w ustawieniach i spróbuj ponownie.';

  @override
  String get publishErrorOutOfMemory =>
      'Za mało pamięci operacyjnej urządzenia. Zamknij kilka aplikacji i spróbuj ponownie.';

  @override
  String get publishErrorUnknownServer => 'Nieznany serwer';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filtr: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Brak wyników dla „$query”';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Zobacz filmy oznaczone $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Dźwięk: $soundName od $creatorName. Dotknij, aby zobaczyć szczegóły dźwięku.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Oryginalny dźwięk od $creatorName. Dotknij, aby użyć tego dźwięku.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Dźwięk: $soundName od $creatorName. Dotknij, aby zobaczyć szczegóły.';
  }

  @override
  String soundDetailLoadError(String error) {
    return 'Nie udało się wczytać dźwięku: $error';
  }

  @override
  String get soundDetailNotFoundMessage => 'Nie udało się znaleźć tego dźwięku';

  @override
  String get soundDetailNotFoundTitle => 'Nie znaleziono dźwięku';

  @override
  String get videoFeedDescriptionSemanticLabel => 'Opis filmu';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count pętli';
  }

  @override
  String get videoFeedLoopCountSemanticLabel => 'Liczba pętli filmu';

  @override
  String get originalSoundUnavailableBody =>
      'Dźwięk z tego filmu nie jest dostępny osobno.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Oryginalny dźwięk - $creatorName';
  }

  @override
  String globalUploadPendingCount(int count) {
    return 'Oczekujące przesyłania ($count)';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String shareVideoInListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Na $count listach',
      many: 'Na $count listach',
      few: 'Na $count listach',
      one: 'Na 1 liście',
    );
    return '$_temp0';
  }

  @override
  String get unfollowConfirmButton => 'Przestań obserwować';

  @override
  String get videoClipSaveFailed => 'Nie udało się zapisać klipu';

  @override
  String videoClipSaveTo(String destination) {
    return 'Zapisz do $destination';
  }

  @override
  String get videoClipDelete => 'Usuń klip';

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Zainspirowane przez $creatorName. Dotknij, aby zobaczyć jego profil.';
  }

  @override
  String get bugReportSendReport => 'Wyślij zgłoszenie';

  @override
  String get supportSubjectRequiredLabel => 'Temat *';

  @override
  String get supportRequiredHelper => 'Wymagane';

  @override
  String get bugReportSubjectHint => 'Krótkie podsumowanie problemu';

  @override
  String get bugReportDescriptionRequiredLabel => 'Co się stało? *';

  @override
  String get bugReportDescriptionHint => 'Opisz problem, na który natrafiłeś';

  @override
  String get bugReportStepsLabel => 'Kroki do odtworzenia';

  @override
  String get bugReportStepsHint =>
      '1. Przejdź do...\n2. Stuknij w...\n3. Zobacz błąd';

  @override
  String get bugReportExpectedBehaviorLabel => 'Oczekiwane zachowanie';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Co powinno się stać zamiast tego?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Informacje o urządzeniu i logi zostaną dołączone automatycznie.';

  @override
  String get bugReportSuccessMessage =>
      'Dzięki! Dostaliśmy twoje zgłoszenie i wykorzystamy je, żeby ulepszyć Divine.';

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
      'Nie udało się wysłać zgłoszenia błędu. Spróbuj ponownie później.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Nie udało się wysłać zgłoszenia błędu: $error';
  }

  @override
  String get featureRequestSendRequest => 'Wyślij prośbę';

  @override
  String get featureRequestSubjectHint =>
      'Krótkie podsumowanie twojego pomysłu';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Czego byś chciał? *';

  @override
  String get featureRequestDescriptionHint => 'Opisz funkcję, której chcesz';

  @override
  String get featureRequestUsefulnessLabel => 'Jak by to było przydatne?';

  @override
  String get featureRequestUsefulnessHint =>
      'Wyjaśnij, jaką korzyść dałaby ta funkcja';

  @override
  String get featureRequestWhenLabel => 'Kiedy byś tego użył?';

  @override
  String get featureRequestWhenHint =>
      'Opisz sytuacje, w których to by pomogło';

  @override
  String get featureRequestSuccessMessage =>
      'Dzięki! Dostaliśmy twoją prośbę i ją przejrzymy.';

  @override
  String get featureRequestSendFailed =>
      'Nie udało się wysłać prośby o funkcję. Spróbuj ponownie później.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Nie udało się wysłać prośby o funkcję: $error';
  }

  @override
  String get notificationFollowBack => 'Zaobserwuj';

  @override
  String get followingTitle => 'Obserwowani';

  @override
  String followingTitleForName(String displayName) {
    return 'Kogo obserwuje $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'Nie udało się załadować listy obserwowanych';

  @override
  String get followingEmptyTitle => 'Jeszcze nikogo nie obserwujesz';

  @override
  String get followersTitle => 'Obserwujący';

  @override
  String followersTitleForName(String displayName) {
    return 'Obserwujący $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Nie udało się załadować listy obserwujących';

  @override
  String get followersEmptyTitle => 'Jeszcze brak obserwujących';

  @override
  String get followersUpdateFollowFailed =>
      'Nie udało się zaktualizować statusu obserwowania. Spróbuj ponownie.';

  @override
  String get reportMessageTitle => 'Zgłoś wiadomość';

  @override
  String get reportMessageWhyReporting => 'Dlaczego zgłaszasz tę wiadomość?';

  @override
  String get reportMessageSelectReason =>
      'Wybierz powód zgłoszenia tej wiadomości';

  @override
  String get newMessageTitle => 'Nowa wiadomość';

  @override
  String get newMessageFindPeople => 'Znajdź ludzi';

  @override
  String get newMessageNoContacts =>
      'Brak kontaktów.\nObserwuj ludzi, żeby tu się pojawili.';

  @override
  String get newMessageNoUsersFound => 'Nie znaleziono użytkowników';

  @override
  String get hashtagSearchTitle => 'Szukaj hashtagów';

  @override
  String get hashtagSearchSubtitle => 'Odkrywaj popularne tematy i treści';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Nie znaleziono hashtagów dla \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Wyszukiwanie nieudane';

  @override
  String get userNotAvailableTitle => 'Konto niedostępne';

  @override
  String get userNotAvailableBody => 'To konto jest teraz niedostępne.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Nie udało się zapisać ustawień: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Wprowadź prawidłowy URL serwera (np. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Zapisano ustawienia Blossom';

  @override
  String get blossomSaveTooltip => 'Zapisz';

  @override
  String get blossomAboutTitle => 'O Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom to zdecentralizowany protokół przechowywania mediów, który pozwala uploadować filmy na dowolny kompatybilny serwer. Domyślnie filmy są uploadowane na serwer Blossom Divine. Włącz opcję poniżej, żeby zamiast tego użyć własnego serwera.';

  @override
  String get blossomUseCustomServer => 'Użyj własnego serwera Blossom';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Filmy będą uploadowane na twój własny serwer Blossom';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Twoje filmy są aktualnie uploadowane na serwer Blossom Divine';

  @override
  String get blossomCustomServerUrl => 'URL własnego serwera Blossom';

  @override
  String get blossomCustomServerHelper =>
      'Wprowadź URL swojego własnego serwera Blossom';

  @override
  String get blossomPopularServers => 'Popularne serwery Blossom';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL serwera Blossom musi używać https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Nie udało się zaktualizować ustawienia crosspostu';

  @override
  String get blueskySignInRequired =>
      'Zaloguj się, żeby zarządzać ustawieniami Bluesky';

  @override
  String get blueskyPublishVideos => 'Publikuj filmy na Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Twoje filmy będą publikowane na Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Twoje filmy nie będą publikowane na Bluesky';

  @override
  String get blueskyHandle => 'Nazwa Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Konto przygotowane i gotowe';

  @override
  String get blueskyStatusPending => 'Trwa przygotowywanie konta...';

  @override
  String get blueskyStatusFailed => 'Przygotowywanie konta nieudane';

  @override
  String get blueskyStatusDisabled => 'Konto wyłączone';

  @override
  String get blueskyStatusNotLinked => 'Brak powiązanego konta Bluesky';

  @override
  String get invitesTitle => 'Zaproś znajomych';

  @override
  String invitesGenerateCardTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invites ready to generate',
      one: '1 invite ready to generate',
    );
    return '$_temp0';
  }

  @override
  String get invitesGenerateCardSubtitle =>
      'Generate a code when you are ready to share one.';

  @override
  String get invitesGenerateButtonLabel => 'Generate invite';

  @override
  String get invitesNoneAvailable => 'Brak dostępnych zaproszeń w tej chwili';

  @override
  String get invitesShareWithPeople =>
      'Udostępniaj diVine ludziom, których znasz';

  @override
  String get invitesUsedInvites => 'Wykorzystane zaproszenia';

  @override
  String invitesShareMessage(String code) {
    return 'Dołącz do mnie na diVine! Użyj kodu zaproszenia $code, żeby zacząć:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Kopiuj zaproszenie';

  @override
  String get invitesCopied => 'Skopiowano zaproszenie!';

  @override
  String get invitesShareInvite => 'Udostępnij zaproszenie';

  @override
  String get invitesShareSubject => 'Dołącz do mnie na diVine';

  @override
  String get invitesClaimed => 'Wykorzystane';

  @override
  String get invitesCouldNotLoad => 'Nie udało się wczytać zaproszeń';

  @override
  String get invitesRetry => 'Spróbuj ponownie';

  @override
  String get searchSomethingWentWrong => 'Coś poszło nie tak';

  @override
  String get searchTryAgain => 'Spróbuj ponownie';

  @override
  String get searchForLists => 'Szukaj list';

  @override
  String get searchFindCuratedVideoLists =>
      'Znajdź wyselekcjonowane listy filmów';

  @override
  String get searchEnterQuery => 'Wpisz zapytanie';

  @override
  String get searchDiscoverSomethingInteresting => 'Odkryj coś ciekawego';

  @override
  String get searchPeopleSectionHeader => 'People';

  @override
  String get searchPeopleLoadingLabel => 'Loading people results';

  @override
  String get searchTagsSectionHeader => 'Tags';

  @override
  String get searchTagsLoadingLabel => 'Loading tag results';

  @override
  String get searchVideosSectionHeader => 'Videos';

  @override
  String get searchVideosLoadingLabel => 'Loading video results';

  @override
  String get searchVideosSortOptionsLabel => 'Sortuj wyniki filmów';

  @override
  String get searchVideosSortTrending => 'Na czasie';

  @override
  String get searchVideosSortLoops => 'Najwięcej pętli';

  @override
  String get searchVideosSortEngagement => 'Najbardziej angażujące';

  @override
  String get searchVideosSortRecent => 'Najnowsze';

  @override
  String get searchListsSectionHeader => 'Listy';

  @override
  String get searchListsLoadingLabel => 'Ładowanie wyników list';

  @override
  String get cameraAgeRestriction =>
      'Musisz mieć co najmniej 16 lat, aby tworzyć treści';

  @override
  String get featureRequestCancel => 'Anuluj';

  @override
  String keyImportError(String error) {
    return 'Błąd: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Przekaźnik bunker musi używać wss:// (ws:// jest dozwolony tylko dla localhost)';

  @override
  String get timeNow => 'teraz';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}g';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}tyg';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mie';
  }

  @override
  String timeShortYears(int count) {
    return '${count}r';
  }

  @override
  String get timeVerboseNow => 'Teraz';

  @override
  String timeAgo(String time) {
    return '$time temu';
  }

  @override
  String get timeToday => 'Dzisiaj';

  @override
  String get timeYesterday => 'Wczoraj';

  @override
  String get timeJustNow => 'przed chwilą';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min temu';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}g temu';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d temu';
  }

  @override
  String get draftTimeJustNow => 'Przed chwilą';

  @override
  String get contentLabelNudity => 'Nagość';

  @override
  String get contentLabelSexualContent => 'Treści seksualne';

  @override
  String get contentLabelPornography => 'Pornografia';

  @override
  String get contentLabelGraphicMedia => 'Drastyczne treści';

  @override
  String get contentLabelViolence => 'Przemoc';

  @override
  String get contentLabelSelfHarm => 'Samookaleczenie/Samobójstwo';

  @override
  String get contentLabelDrugUse => 'Używanie narkotyków';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tytoń/Palenie';

  @override
  String get contentLabelGambling => 'Hazard';

  @override
  String get contentLabelProfanity => 'Wulgaryzmy';

  @override
  String get contentLabelHateSpeech => 'Mowa nienawiści';

  @override
  String get contentLabelHarassment => 'Nękanie';

  @override
  String get contentLabelFlashingLights => 'Migające światła';

  @override
  String get contentLabelAiGenerated => 'Wygenerowane przez AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Oszustwo';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Wprowadzające w błąd';

  @override
  String get contentLabelSensitiveContent => 'Wrażliwe treści';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName polubił(a) Twoje wideo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName polubił(a) Twój komentarz';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName skomentował(a) Twoje wideo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName zaczął/zaczęła Cię obserwować';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName wspomniał(a) o Tobie';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName udostępnił(a) Twoje wideo';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName odpowiedział(a) na Twój komentarz';
  }

  @override
  String get notificationAndConnector => 'i';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count innych osób',
      one: '1 inna osoba',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Masz nową aktualizację';

  @override
  String get notificationSomeoneLikedYourVideo => 'Ktoś polubił(a) Twoje wideo';

  @override
  String get commentReplyToPrefix => 'Odp.:';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get commentsErrorLoadFailed => 'Failed to load comments';

  @override
  String get commentsErrorNotAuthenticatedComment =>
      'Please sign in to comment';

  @override
  String get commentsErrorPostCommentFailed => 'Failed to post comment';

  @override
  String get commentsErrorPostReplyFailed => 'Failed to post reply';

  @override
  String get commentsErrorEditFailed => 'Failed to edit comment';

  @override
  String get commentsErrorNotAuthenticatedInteract =>
      'Please sign in to interact';

  @override
  String get commentsErrorVoteFailed => 'Failed to vote on comment';

  @override
  String get commentsErrorReportFailed => 'Failed to report comment';

  @override
  String get commentsErrorBlockFailed => 'Failed to block user';

  @override
  String get commentsErrorDeleteFailed => 'Failed to delete comment';

  @override
  String commentsHeaderCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Comments',
      one: '$count Comment',
    );
    return '$_temp0';
  }

  @override
  String get commentsSortNew => 'New';

  @override
  String get commentsSortTop => 'Top';

  @override
  String get commentsSortOld => 'Old';

  @override
  String get commentsSortSemanticLabel => 'Comments sorting';

  @override
  String get commentReply => 'Reply';

  @override
  String get commentReplySemanticLabel => 'Reply to comment';

  @override
  String get commentUpvoteLabel => 'Upvote comment';

  @override
  String get commentRemoveUpvoteLabel => 'Remove upvote';

  @override
  String get commentDownvoteLabel => 'Downvote comment';

  @override
  String get commentRemoveDownvoteLabel => 'Remove downvote';

  @override
  String get commentsInputHint => 'Add comment...';

  @override
  String get commentsInputHintEdit => 'Edit comment...';

  @override
  String get commentsEmptyTitle => 'No comments yet';

  @override
  String get commentsEmptySubtitle => 'Get the party started!';

  @override
  String get commentsHeaderTitle => 'Comments';

  @override
  String get commentsHeaderCloseLabel => 'Close comments';

  @override
  String get draftUntitled => 'Bez tytułu';

  @override
  String get contentWarningNone => 'Brak';

  @override
  String get textBackgroundNone => 'Brak';

  @override
  String get textBackgroundSolid => 'Pełne';

  @override
  String get textBackgroundHighlight => 'Wyróżnienie';

  @override
  String get textBackgroundTransparent => 'Przezroczyste';

  @override
  String get textAlignLeft => 'Lewo';

  @override
  String get textAlignRight => 'Prawo';

  @override
  String get textAlignCenter => 'Środek';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Aparat nie jest jeszcze obsługiwany w wersji webowej';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Robienie zdjęć i nagrywanie kamerą nie są jeszcze dostępne w wersji webowej.';

  @override
  String get cameraPermissionBackToFeed => 'Wróć do feedu';

  @override
  String get cameraPermissionErrorTitle => 'Błąd uprawnień';

  @override
  String get cameraPermissionErrorDescription =>
      'Wystąpił błąd podczas sprawdzania uprawnień.';

  @override
  String get cameraPermissionRetry => 'Spróbuj ponownie';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Zezwól na dostęp do aparatu i mikrofonu';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'To pozwala nagrywać i edytować filmy bezpośrednio w aplikacji i nic więcej.';

  @override
  String get cameraPermissionGoToSettings => 'Przejdź do ustawień';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Dlaczego sześć sekund?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Krótkie klipy dają przestrzeń na spontaniczność. Format 6 sekund pomaga uchwycić autentyczne chwile w momencie, gdy się dzieją.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Rozumiem!';

  @override
  String get videoRecorderUploadTitle => 'Dlaczego nie ma uploadu?';

  @override
  String get videoRecorderUploadBody =>
      'To, co widzisz na Divine, zostało stworzone przez ludzi: surowe i uchwycone w danej chwili. W przeciwieństwie do platform, które zezwalają na mocno wyprodukowane lub generowane przez AI uploady, stawiamy na autentyczność doświadczenia bezpośrednio z kamery.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Trzymając tworzenie wewnątrz aplikacji, możemy lepiej zagwarantować, że treści są prawdziwe i niezmienione. Nie otwieramy obecnie uploadów z zewnętrznej galerii, aby chronić tę autentyczność i utrzymać naszą społeczność wolną od syntetycznych treści w jak największym stopniu.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Przełącz na Capture lub Classic, żeby nakręcić coś prawdziwego.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Dowiedz się, jak działa weryfikacja';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Znaleźliśmy niedokończoną pracę';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Czy chcesz kontynuować od miejsca, w którym skończyłeś?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Tak, kontynuuj';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Nie, rozpocznij nowy film';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Nie udało się przywrócić wersji roboczej';

  @override
  String get videoRecorderStopRecordingTooltip => 'Zatrzymaj nagrywanie';

  @override
  String get videoRecorderStartRecordingTooltip => 'Rozpocznij nagrywanie';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Nagrywanie. Dotknij dowolnego miejsca, aby zatrzymać';

  @override
  String get videoRecorderTapToStartLabel =>
      'Dotknij dowolnego miejsca, aby rozpocząć nagrywanie';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Usuń ostatni klip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Przełącz aparat';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Powiększ do $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Przełącz siatkę';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Przełącz klatkę odniesienia';

  @override
  String get videoRecorderGhostFrameEnabled => 'Klatka odniesienia włączona';

  @override
  String get videoRecorderGhostFrameDisabled => 'Klatka odniesienia wyłączona';

  @override
  String get videoRecorderClipDeletedMessage => 'Klip przeniesiony do kosza';

  @override
  String get videoRecorderClipUndoLabel => 'Cofnij';

  @override
  String get libraryTrashTitle => 'Ostatnio usunięte';

  @override
  String get libraryTrashEmptyTitle => 'Kosz jest pusty';

  @override
  String get libraryTrashEmptySubtitle =>
      'Usunięte klipy pozostają tutaj przez 30 dni, zanim zostaną trwale usunięte.';

  @override
  String get libraryTrashRestoreLabel => 'Przywróć';

  @override
  String get libraryTrashDeleteNowLabel => 'Usuń teraz';

  @override
  String get libraryTrashEmptyAllLabel => 'Opróżnij kosz';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Usunąć klip teraz?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'To od razu usunie klip z kosza.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Opróżnić kosz?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipów',
      one: '1 klip',
    );
    return 'To od razu trwale usunie z kosza $_temp0.';
  }

  @override
  String get libraryTrashEntryLabel => 'Ostatnio usunięte';

  @override
  String get videoRecorderCloseLabel => 'Zamknij rejestrator wideo';

  @override
  String get videoRecorderContinueToEditorLabel => 'Przejdź do edytora wideo';

  @override
  String get videoRecorderCaptureCloseLabel => 'Zamknij';

  @override
  String get videoRecorderCaptureNextLabel => 'Dalej';

  @override
  String get videoRecorderLipSyncAddAudioFirst => 'Dodaj audio przed nagraniem';

  @override
  String get videoRecorderToggleFlashLabel => 'Przełącz lampę błyskową';

  @override
  String get videoRecorderCycleTimerLabel => 'Zmień timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Przełącz proporcje';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilizacja';

  @override
  String get videoRecorderStabilizationModeOff => 'Wyłączona';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standardowa';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Filmowa';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Filmowa rozszerzona';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Zoptymalizowana pod podgląd';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Niskie opóźnienie';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automatyczna';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Biblioteka klipów, brak klipów';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Otwórz bibliotekę klipów, $clipCount klipów',
      one: 'Otwórz bibliotekę klipów, 1 klip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Otwórz kamerę';

  @override
  String get videoEditorLibraryLabel => 'Biblioteka';

  @override
  String get videoEditorTextLabel => 'Tekst';

  @override
  String get videoEditorDrawLabel => 'Rysuj';

  @override
  String get videoEditorFilterLabel => 'Filtr';

  @override
  String get videoEditorTuneLabel => 'Dostosuj';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Otwórz edytor korekt';

  @override
  String get videoEditorTuneBrightness => 'Jasność';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Nasycenie';

  @override
  String get videoEditorTuneExposure => 'Ekspozycja';

  @override
  String get videoEditorTuneHue => 'Odcień';

  @override
  String get videoEditorTuneTemperature => 'Temperatura';

  @override
  String get videoEditorTuneTint => 'Zabarwienie';

  @override
  String get videoEditorTuneFade => 'Zanikanie';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorAddTitle => 'Dodaj';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Otwórz bibliotekę';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Otwórz edytor audio';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Otwórz edytor tekstu';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Otwórz edytor rysowania';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Otwórz edytor filtrów';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Otwórz edytor naklejek';

  @override
  String get videoEditorSaveDraftTitle => 'Zapisać wersję roboczą?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Zachowaj edycje na później albo odrzuć je i opuść edytor.';

  @override
  String get videoEditorSaveDraftButton => 'Zapisz wersję roboczą';

  @override
  String get videoEditorDiscardChangesButton => 'Odrzuć zmiany';

  @override
  String get videoEditorKeepEditingButton => 'Kontynuuj edycję';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Strefa upuszczania do usuwania warstwy';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Puść, aby usunąć warstwę';

  @override
  String get videoEditorDoneLabel => 'Gotowe';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Odtwórz lub wstrzymaj wideo';

  @override
  String get videoEditorCropSemanticLabel => 'Przytnij';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Nie można podzielić klipu podczas przetwarzania. Poczekaj.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Nieprawidłowa pozycja podziału. Oba klipy muszą mieć co najmniej $minDurationMs ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Dodaj klip z biblioteki';

  @override
  String get videoEditorSaveSelectedClip => 'Zapisz wybrany klip';

  @override
  String get videoEditorSplitClip => 'Podziel klip';

  @override
  String get videoEditorSaveClip => 'Zapisz klip';

  @override
  String get videoEditorDeleteClip => 'Usuń klip';

  @override
  String get videoEditorClipSavedSuccess => 'Klip zapisany w bibliotece';

  @override
  String get videoEditorClipSaveFailed => 'Nie udało się zapisać klipu';

  @override
  String get videoEditorClipDeleted => 'Klip usunięty';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Wybór koloru';

  @override
  String get videoEditorUndoSemanticLabel => 'Cofnij';

  @override
  String get videoEditorRedoSemanticLabel => 'Ponów';

  @override
  String get videoEditorTextColorSemanticLabel => 'Kolor tekstu';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Wyrównanie tekstu';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Tło tekstu';

  @override
  String get videoEditorFontSemanticLabel => 'Czcionka';

  @override
  String get videoEditorNoStickersFound => 'Nie znaleziono naklejek';

  @override
  String get videoEditorNoStickersAvailable => 'Brak dostępnych naklejek';

  @override
  String get videoEditorFailedLoadStickers => 'Nie udało się wczytać naklejek';

  @override
  String get videoEditorAdjustVolumeTitle => 'Dostosuj głośność';

  @override
  String get videoEditorRecordedAudioLabel => 'Nagrane audio';

  @override
  String get videoEditorVoiceOverLabel => 'Narracja';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Nagranie $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Nagraj narrację';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Rozpocznij nagrywanie';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Zatrzymaj nagrywanie';

  @override
  String get videoEditorVoiceOverHint =>
      'Dotknij, aby nagrać. Dodaj dowolną liczbę ujęć.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nagrań',
      one: '1 nagranie',
      zero: 'Brak nagrań',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Usuń ostatnie nagranie';

  @override
  String get videoEditorVoiceOverPermissionTitle =>
      'Wymagany dostęp do mikrofonu';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Zezwól na dostęp do mikrofonu, aby nagrać narrację.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Otwórz ustawienia';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Rozpoczęto nagrywanie';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Zapisano nagranie';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Nagranie jest dłuższe niż Twój film';

  @override
  String get videoEditorPlaySemanticLabel => 'Odtwórz';

  @override
  String get videoEditorPauseSemanticLabel => 'Wstrzymaj';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Wycisz audio';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Włącz dźwięk';

  @override
  String get videoEditorVolumeSemanticLabel => 'Dostosuj głośność';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Głośność $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Przesuń, aby dostosować';

  @override
  String get videoEditorOriginalAudioLabel => 'Oryginalne audio';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klip $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Usuń';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Usuń wybrany element';

  @override
  String get videoEditorEditLabel => 'Edytuj';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Edytuj wybrany element';

  @override
  String get videoEditorDuplicateLabel => 'Duplikuj';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplikuj wybrany element';

  @override
  String get videoEditorCombineLabel => 'Połącz';

  @override
  String get videoEditorCombineDrawLayersSemanticLabel =>
      'Połącz wybrane rysunki w jedną warstwę';

  @override
  String get videoEditorSplitLabel => 'Podziel';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Podziel wybrany klip';

  @override
  String get videoEditorExtractAudioLabel => 'Wyodrębnij dźwięk';

  @override
  String get videoEditorClipAudioTitle => 'Dźwięk klipu';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Wyodrębnij dźwięk z klipu i wycisz oryginał';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Nie można wyodrębnić audio: klip nie jest dostępny lokalnie.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Nie udało się wyodrębnić audio. Spróbuj ponownie.';

  @override
  String get videoEditorSpeedLabel => 'Prędkość';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Ustaw prędkość odtwarzania dla wybranego klipu';

  @override
  String get videoEditorReverseLabel => 'Odwróć';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Włącz lub wyłącz odwrotne odtwarzanie dla wybranego klipu';

  @override
  String get videoEditorReverseProgressLabel =>
      'Chwileczkę, odwracamy Twój klip';

  @override
  String get videoEditorTransformLabel => 'Przekształć';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Przytnij, obróć lub odbij wybrany klip';

  @override
  String get videoEditorTransformProgressLabel =>
      'Chwila, przekształcamy Twój klip';

  @override
  String get videoEditorTransformFailed =>
      'Nie udało się przekształcić klipu. Spróbuj ponownie.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Nie można przekształcić: klip nie jest dostępny lokalnie.';

  @override
  String get videoEditorTransformRotateLabel => 'Obróć';

  @override
  String get videoEditorTransformFlipLabel => 'Odbij';

  @override
  String get videoEditorTransformRatioLabel => 'Proporcje';

  @override
  String get videoEditorTransformResetLabel => 'Resetuj';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Zastosuj przekształcenie';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Anuluj przekształcenie';

  @override
  String get videoEditorTransformPlayLabel => 'Odtwórz';

  @override
  String get videoEditorTransformPauseLabel => 'Pauza';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Nie można odwrócić: klip nie jest dostępny lokalnie.';

  @override
  String get videoEditorReverseFailed =>
      'Nie udało się odwrócić klipu. Spróbuj ponownie.';

  @override
  String get videoEditorSpeedSheetTitle => 'Prędkość klipu';

  @override
  String get videoEditorTransitionSheetTitle => 'Przejście';

  @override
  String get videoEditorTransitionNone => 'Brak';

  @override
  String get videoEditorTransitionDissolve => 'Przenikanie';

  @override
  String get videoEditorTransitionFadeToBlack => 'Ściemnienie do czerni';

  @override
  String get videoEditorTransitionFadeToWhite => 'Rozjaśnienie do bieli';

  @override
  String get videoEditorTransitionSlide => 'Wsuwanie';

  @override
  String get videoEditorTransitionPush => 'Wypychanie';

  @override
  String get videoEditorTransitionWipe => 'Wycieranie';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Edytuj przejście';

  @override
  String get videoEditorLoopTransitionSheetTitle => 'Przejście pętli';

  @override
  String get videoEditorLoopTransitionButtonSemanticLabel =>
      'Edytuj przejście pętli';

  @override
  String get videoEditorTransitionDuration => 'Czas trwania';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Skrócono, aby nie nakładała się na sąsiednie przejście.';

  @override
  String get videoEditorTransitionCurve => 'Krzywa';

  @override
  String get videoEditorTransitionDirection => 'Kierunek';

  @override
  String get videoEditorTransitionDirectionLeft => 'Lewo';

  @override
  String get videoEditorTransitionDirectionRight => 'Prawo';

  @override
  String get videoEditorTransitionDirectionUp => 'Góra';

  @override
  String get videoEditorTransitionDirectionDown => 'Dół';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Krzywa animacji $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animacja';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Edytuj animację warstwy';

  @override
  String get videoEditorLayerAnimationEnter => 'Wejście';

  @override
  String get videoEditorLayerAnimationLeave => 'Wyjście';

  @override
  String get videoEditorLayerAnimationFade => 'Zanikanie';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skaluj od';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Zakończ edycję osi czasu';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Odtwórz podgląd';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Wstrzymaj podgląd';

  @override
  String get videoEditorAudioUntitledSound => 'Nienazwany dźwięk';

  @override
  String get videoEditorAudioUntitled => 'Bez tytułu';

  @override
  String get videoEditorAudioAddAudio => 'Dodaj audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Brak dostępnych dźwięków';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Dźwięki pojawią się tutaj, gdy twórcy udostępnią audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Nie udało się wczytać dźwięków';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Wybierz fragment audio dla swojego filmu';

  @override
  String get videoEditorAudioCategoryDivine => 'OG Sounds';

  @override
  String get videoEditorAudioCategoryCommunity => 'Społeczność';

  @override
  String get videoEditorAudioCategoryFeatured => 'Wyróżnione';

  @override
  String get videoEditorAudioCategoryMySounds => 'Moje dźwięki';

  @override
  String get videoEditorAudioFeaturedEmptyTitle => 'Wyróżnione dźwięki wkrótce';

  @override
  String get videoEditorAudioFeaturedEmptySubtitle =>
      'Opublikujemy tu wyróżnione dźwięki, gdy będą gotowe.';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Narzędzie strzałki';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Narzędzie gumki';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Narzędzie markera';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Narzędzie ołówka';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Pokaż oś czasu';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ukryj oś czasu';

  @override
  String get videoEditorFeedPreviewContent =>
      'Unikaj umieszczania treści za tymi obszarami.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Oryginały';

  @override
  String get videoEditorStickerSearchHint => 'Szukaj naklejek...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Wybierz czcionkę';

  @override
  String get videoEditorFontUnknown => 'Nieznana';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Aby podzielić, głowica odtwarzania musi znajdować się w wybranym klipie.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Przytnij początek';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Przytnij koniec';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Przytnij klip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Przeciągnij uchwyty, aby dostosować długość klipu';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Przeciąganie klipu $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Klip $index z $total, $duration sekund';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Przytrzymaj, aby zmienić kolejność';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Dotknij, aby edytować. Przytrzymaj i przeciągnij, aby zmienić kolejność.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Przesuń w lewo';

  @override
  String get videoEditorTimelineClipMoveRight => 'Przesuń w prawo';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klip $index z $total, zaznaczony';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klip $index z $total, niezaznaczony';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Zaznacz';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Zaznacz wiele klipów';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Zakończ zaznaczanie';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Zaznaczono $count klipów',
      one: 'Zaznaczono 1 klip',
      zero: 'Nie zaznaczono klipów',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorLayerMultiSelectSemanticLabel =>
      'Wybierz wiele rysunków';

  @override
  String get videoEditorLayerMultiSelectDoneSemanticLabel =>
      'Zakończ wybieranie rysunków';

  @override
  String get videoEditorDeleteSelectedDrawingsSemanticLabel =>
      'Usuń wybrane rysunki';

  @override
  String videoEditorLayerMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Wybrano rysunki: $count',
      one: 'Wybrano 1 rysunek',
      zero: 'Nie wybrano rysunków',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Scal';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Scal zaznaczone klipy';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Usuń zaznaczone klipy';

  @override
  String get videoEditorMergeProgressLabel => 'Chwila, scalamy Twoje klipy';

  @override
  String get videoEditorMergeFailed =>
      'Nie udało się scalić klipów. Spróbuj ponownie.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Przytrzymaj, aby przeciągnąć';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Oś czasu wideo';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, wybrany';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Zamknij wybór koloru';

  @override
  String get videoEditorPickColorTitle => 'Wybierz kolor';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Potwierdź kolor';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Nasycenie i jasność';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Nasycenie $saturation%, jasność $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Odcień';

  @override
  String get videoEditorAddElementSemanticLabel => 'Dodaj element';

  @override
  String get videoEditorCloseSemanticLabel => 'Zamknij';

  @override
  String get videoEditorDoneSemanticLabel => 'Gotowe';

  @override
  String get videoEditorLevelSemanticLabel => 'Poziom';

  @override
  String get videoMetadataBackSemanticLabel => 'Wstecz';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Zamknij okno pomocy';

  @override
  String get videoMetadataGotItButton => 'Rozumiem!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Osiągnięto limit 64 KB. Usuń część treści, aby kontynuować.';

  @override
  String get videoMetadataExpirationLabel => 'Wygaśnięcie';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Wybierz czas wygaśnięcia';

  @override
  String get videoMetadataTitleLabel => 'Tytuł';

  @override
  String get videoMetadataDescriptionLabel => 'Opis';

  @override
  String get videoMetadataTagsLabel => 'Tagi';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Usuń';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Usuń tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Ostrzeżenie o treści';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Wybierz ostrzeżenia o treści';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Wybierz wszystko, co dotyczy Twojej treści';

  @override
  String get videoMetadataContentWarningDoneButton => 'Gotowe';

  @override
  String get videoMetadataAudioReuseTitle => 'Opublikuj ten dźwięk';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Pozwól innym zapisać i ponownie użyć dźwięku z tego wideo.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Współtwórcy';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Dodaj współtwórcę';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Jak działają współtwórcy';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max współtwórców';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel => 'Usuń współtwórcę';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Współtwórcy są oznaczani jako współautorzy tego posta. Możesz dodać tylko osoby, które obserwujecie się wzajemnie, a ich dane pojawią się w metadanych po publikacji.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Wzajemni obserwujący';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Aby dodać $name jako współtwórcę, musicie obserwować się wzajemnie.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Zainspirowane przez';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Ustaw zainspirowane przez';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Jak działają przypisania inspiracji';

  @override
  String get videoMetadataInspiredByNone => 'Brak';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Użyj tego, aby dodać przypisanie. Oznaczenie zainspirowane przez różni się od współtwórców: wskazuje wpływ, ale nie oznacza nikogo jako współautora.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Nie można odwołać się do tego twórcy.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Usuń zainspirowane przez';

  @override
  String get videoMetadataPostDetailsTitle => 'Szczegóły posta';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Zapisano w bibliotece';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Nie udało się zapisać';

  @override
  String get videoMetadataGoToLibraryButton => 'Przejdź do biblioteki';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Przycisk zapisz na później';

  @override
  String get videoMetadataRenderingVideoHint => 'Renderowanie wideo...';

  @override
  String get videoMetadataSavingVideoHint => 'Zapisywanie wideo...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Zapisz wideo w wersjach roboczych i $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Zapisz na później';

  @override
  String get videoMetadataPostSemanticLabel => 'Przycisk opublikuj';

  @override
  String get videoMetadataPublishVideoHint => 'Opublikuj wideo w feedzie';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Udostępnij też w moim feedzie';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Wyłączenie sprawia, że ten film zostaje tylko w wątku komentarzy.';

  @override
  String get videoMetadataFormNotReadyHint => 'Wypełnij formularz, aby włączyć';

  @override
  String get videoMetadataPostButton => 'Opublikuj';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Otwórz ekran podglądu posta';

  @override
  String get videoMetadataShareTitle => 'Udostępnij';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Szczegóły wideo';

  @override
  String get videoMetadataClassicDoneButton => 'Gotowe';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Odtwórz podgląd';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Wstrzymaj podgląd';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Zamknij podgląd wideo';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Usuń';

  @override
  String get fullscreenFeedRemovedMessage => 'Film usunięty';

  @override
  String get settingsBadgesTitle => 'Odznaki';

  @override
  String get settingsBadgesSubtitle =>
      'Akceptuj nagrody i sprawdzaj status wydanych odznak.';

  @override
  String get badgesTitle => 'Odznaki';

  @override
  String get badgesIntroTitle => 'Zrozum swój ślad odznak';

  @override
  String get badgesIntroBody =>
      'Zobacz odznaki przyznane tobie, wybierz, które przypiąć do profilu Nostr, i sprawdź, czy ludzie zaakceptowali odznaki, które wydałeś.';

  @override
  String get badgesOpenApp => 'Otwórz aplikację odznak';

  @override
  String get badgesLoadError => 'Nie udało się wczytać odznak';

  @override
  String get badgesUpdateError => 'Nie udało się zaktualizować odznaki';

  @override
  String get badgesAwardedSectionTitle => 'Przyznane tobie';

  @override
  String get badgesAwardedEmptyTitle => 'Jeszcze brak odznak';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Gdy ktoś przyzna ci odznakę Nostr, wyląduje tutaj.';

  @override
  String get badgesStatusAccepted => 'Zaakceptowano';

  @override
  String get badgesStatusNotAccepted => 'Niezaakceptowano';

  @override
  String get badgesActionRemove => 'Usuń';

  @override
  String get badgesActionAccept => 'Akceptuj';

  @override
  String get badgesActionReject => 'Odrzuć';

  @override
  String get badgesIssuedSectionTitle => 'Wydane przez ciebie';

  @override
  String get badgesIssuedEmptyTitle => 'Jeszcze brak wydanych odznak';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Odznaki, które wydasz, pokażą tutaj status akceptacji.';

  @override
  String get badgesIssuedNoRecipients =>
      'Nie znaleziono odbiorców tej nagrody.';

  @override
  String get badgesRecipientAcceptedStatus => 'Zaakceptowane przez odbiorcę';

  @override
  String get badgesRecipientWaitingStatus => 'Oczekiwanie na odbiorcę';

  @override
  String get profileBadgeAwardedBy => 'Awarded by';

  @override
  String get profileBadgeRecipients => 'Recipients';

  @override
  String profileBadgeMoreRecipients(int count) {
    return '+$count more';
  }

  @override
  String profileBadgeSemanticLabel(String name) {
    return '$name badge';
  }

  @override
  String get profileBadgeFallbackSemanticLabel => 'Badge';

  @override
  String get minorAccountReviewWelcomePageTitle => 'Family guide';

  @override
  String get minorAccountReviewWelcomeCta =>
      'Not 16 yet? That\'s OK. Here\'s what you can do.';

  @override
  String get minorAccountReviewWelcomeTitle => 'Not 16 yet? That\'s OK.';

  @override
  String get minorAccountReviewWelcomeBody =>
      'Rules for people under 16 vary depending on where you live. At Divine, we want families to talk it through together and decide what healthy social media use looks like.';

  @override
  String get minorAccountReviewModerationTitle => 'We need one more step';

  @override
  String get minorAccountReviewModerationBody =>
      'We were asked to take a closer look at this account because it may belong to someone under 16. This flow keeps the next steps private and points you to the right path for your age.';

  @override
  String get minorAccountReviewRulesTitle =>
      'The rules are not the same everywhere';

  @override
  String get minorAccountReviewRulesBody =>
      'Different countries and regions treat teen social media use differently. That is why we ask families to slow down, check the facts, and choose the next step together.';

  @override
  String get minorAccountReviewApproachTitle => 'How Divine thinks about it';

  @override
  String get minorAccountReviewApproachBody =>
      'We think healthy tech habits come from pausing, reflecting, and redirecting attention toward better things, not from spying on kids or turning parents into hall monitors. Research backs that up too.';

  @override
  String get minorAccountReviewLearnMoreTitle => 'More for families';

  @override
  String get minorAccountReviewKidsPolicyCta => 'Read Divine\'s kids policy';

  @override
  String get minorAccountReviewChooseAgeBandTitle =>
      'Choose the path that fits';

  @override
  String get minorAccountReviewUnder13Cta => 'Under 13';

  @override
  String get minorAccountReviewTeenCta => 'Age 13-15';

  @override
  String get minorAccountReviewFamilyResourcesTitle => 'Helpful for families';

  @override
  String get minorAccountReviewFamilyResourcesBody =>
      'Visit the Divine family guide for practical tips, conversation tools, and resources for helping teens use social media more safely.';

  @override
  String get minorAccountReviewFamilyResourcesCta =>
      'Get family guides and tips';

  @override
  String get minorAccountReviewFooter =>
      'If you are 16 or older and got sent here by mistake, contact Divine support so a real person can review it.';

  @override
  String get minorAccountReviewTitle => 'Account Review';

  @override
  String get minorAccountReviewCheckingStatusTitle =>
      'Checking account status...';

  @override
  String get minorAccountReviewCheckingStatusBody =>
      'Please wait while we confirm this account\'s current review status.';

  @override
  String get minorAccountReviewDefaultTitle => 'Account review required';

  @override
  String get minorAccountReviewDefaultBody =>
      'We need to review this account before it can use Divine normally.';

  @override
  String minorAccountReviewCaseId(String caseId) {
    return 'Case ID: $caseId';
  }

  @override
  String get minorAccountReviewCaseIdShortLabel => 'Case ID';

  @override
  String get minorAccountReviewRestrictionsTitle =>
      'What is restricted right now';

  @override
  String get minorAccountReviewRestrictionPosting =>
      'Posting and publishing are paused';

  @override
  String get minorAccountReviewRestrictionEngagement =>
      'Comments, likes, reposts, and follows are paused';

  @override
  String get minorAccountReviewRestrictionMessaging =>
      'Starting or replying to regular messages is paused';

  @override
  String get minorAccountReviewRestrictionSupport =>
      'Support and your moderation message remain available';

  @override
  String get minorAccountReviewOpenSupportCenter => 'Open Support Center';

  @override
  String get minorAccountReviewOpenModerationMessage =>
      'Open Moderation Message';

  @override
  String get minorAccountReviewOpenReviewPage => 'Open review page';

  @override
  String get minorAccountReviewCheckAgain => 'Check Again';

  @override
  String get minorAccountReviewLogOut => 'Log out';

  @override
  String get minorAccountReviewNextStepTitle => 'Next step';

  @override
  String get minorAccountReviewNextStepBody =>
      'Open the support center or your moderation message if you need help with this review.';

  @override
  String get minorAccountReviewInProgressTitle => 'Review in progress';

  @override
  String get minorAccountReviewInProgressBody =>
      'We have what we need for now. Our team is reviewing this case before restoring normal account access.';

  @override
  String get minorAccountReviewUnder13Title => 'Under-13 accounts';

  @override
  String minorAccountReviewUnder13Body(String supportEmail) {
    return 'If this account belongs to someone under 13, a parent or guardian must email $supportEmail and include the case ID.';
  }

  @override
  String get minorAccountReviewUnder13PublicTitle =>
      'We can\'t give you an account yet';

  @override
  String get minorAccountReviewUnder13PublicBody =>
      'Divine isn\'t built for kids under 13 and the social media rules around the world tie our hands.\n\nA lot of things on the internet push you to lie to get what you want, and we hate that. It\'s the wrong lesson for life, and we\'re not going to teach it to you here.';

  @override
  String get minorAccountReviewUnder13FamilyTitle =>
      'What your family can do instead';

  @override
  String get minorAccountReviewUnder13FamilyBody =>
      'A parent or guardian can hold the account and do the posting, and you can absolutely be in the videos with them. We want families to enjoy Divine in whatever way is right for them.';

  @override
  String get minorAccountReviewUnder13ComeBackTitle => 'When you turn 13';

  @override
  String get minorAccountReviewUnder13ComeBackBody =>
      'Depending on the rules where you live, you may be able to come back and apply for your own account. In that case, if you’re between 13 and 15, you’ll need consent from a parent or guardian.';

  @override
  String get minorAccountReviewUnder13HonestyTitle =>
      'Dlaczego nie powiemy ci po prostu „kliknij wstecz”';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Duża część internetu jest tak ustawiona, by nagradzać ludzi za mówienie tego, co pozwoli im przejść przez bramkę. Nie uważamy, że to dobre. Tak, mógłbyś wrócić i powiedzieć, że jesteś starszy, niż jesteś, ale to nie byłoby uczciwe, a my nie zamierzamy uczyć cię kłamania, żeby dostać to, czego chcesz.';

  @override
  String get minorAccountReviewUnder13LegalTitle =>
      'Dlaczego odpowiedź nadal brzmi „nie”';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Staramy się pomóc młodym ludziom korzystać z Divine w sposób zdrowy i pozytywny dla nich i osób wokół nich. Musimy też przestrzegać praw, które są różne w różnych miejscach. Więc jeśli masz mniej niż 13 lat, odpowiedź jest taka, że dzisiaj nie możesz mieć własnego konta.';

  @override
  String get minorAccountReviewTeenBody =>
      'If this account belongs to someone 13 to 15, use the moderation message or support path to follow the parental consent instructions.';

  @override
  String get minorAccountReviewParentConsentTitle =>
      'If the account will belong to someone 13 to 15';

  @override
  String get minorAccountReviewParentConsentBody =>
      'If parent or guardian contact is not possible or would put someone at risk, email Divine support and let us know.\n\nOtherwise, a parent or guardian should email Divine support with a short private video so our team can review the account and help with next steps.';

  @override
  String get minorAccountReviewParentConsentPauseNote =>
      'This is a pause, not a dead end. The account is not active until Divine support reviews the video.';

  @override
  String get minorAccountReviewParentConsentHonestyTitle =>
      'Dlaczego prosimy o zaangażowanie rodzica lub opiekuna';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine musi przestrzegać przepisów dotyczących wieku na całym świecie. Wiemy też, że większość technicznych bramek wiekowych jest niedoskonała. Zamiast udawać, że zasady nie istnieją, albo że fajnie jest kłamać na temat swojego wieku, chcemy, by nastolatki i rodziny podejmowały przemyślane decyzje o tym, jak najlepiej korzystać z Divine. Dlatego w przypadku osób w wieku 13-15 lat prosimy rodziców, by byli częścią procesu zakładania konta.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Musimy też przestrzegać prawa, a te zasady różnią się w zależności od miejsca zamieszkania. Więc zamiast udawać, że zasady nie istnieją, prosimy, by rodzic lub opiekun był częścią tego procesu.';

  @override
  String get minorAccountReviewParentConsentChecklist =>
      'What the video should show';

  @override
  String get minorAccountReviewParentConsentChecklistKid =>
      'The teen in the video';

  @override
  String get minorAccountReviewParentConsentChecklistPermission =>
      'A parent or guardian speaking on camera';

  @override
  String get minorAccountReviewParentConsentChecklistAgeBand =>
      'A clear statement that the teen is 13 to 15 and has permission to use Divine';

  @override
  String get minorAccountReviewParentConsentChecklistSupervision =>
      'A clear statement that the parent or guardian knows about the account and will supervise its use';

  @override
  String get minorAccountReviewParentConsentPrivacy => 'How to send it';

  @override
  String get minorAccountReviewParentConsentNeverPost =>
      'Attach the video when you email Divine support';

  @override
  String get minorAccountReviewParentConsentDoNotSave =>
      'Keep the video private and do not post it in the app';

  @override
  String get minorAccountReviewParentConsentOneMove =>
      'Our team will review it and reply with next steps';

  @override
  String get minorAccountReviewParentConsentEmailCta => 'Email Divine support';

  @override
  String get minorAccountReviewParentConsentEmailSubject =>
      'Divine Greenlight review help (ages 13-15)';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hi Divine support,\n\nI am contacting Divine about Divine Greenlight for a teen who is 13-15.\n\nI have attached a short private video that shows:\n- the teen\n- a parent or guardian speaking on camera\n- that the teen has permission to use Divine\n- that the parent or guardian knows about the account and will supervise its use\n\nCountry/ies of residence:\n\nHelpful context:\n\nThanks.';

  @override
  String get minorAccountReviewParentSupportInstructions =>
      'Parent Support Instructions';

  @override
  String get minorAccountReviewContinue => 'Continue';

  @override
  String get minorAccountReviewErrorTitle =>
      'We could not load your account review status.';

  @override
  String get minorAccountReviewErrorBody => 'Please try again in a moment.';

  @override
  String get minorAccountReviewTryAgain => 'Try Again';

  @override
  String get minorAccountReviewParentContactTitle => 'Parent Contact';

  @override
  String get minorAccountReviewParentContactHeading =>
      'Add a parent or guardian email';

  @override
  String minorAccountReviewParentContactBody(String caseId) {
    return 'We will use this address for the parental consent review on case $caseId.';
  }

  @override
  String get minorAccountReviewParentContactFieldLabel =>
      'Parent or guardian email';

  @override
  String get minorAccountReviewSubmitting => 'Submitting...';

  @override
  String get minorAccountReviewSubmitEmail => 'Submit Email';

  @override
  String get minorAccountReviewBackToReview => 'Back to Account Review';

  @override
  String get minorAccountReviewSubmissionReceivedTitle => 'Email submitted';

  @override
  String minorAccountReviewSubmissionReceivedBody(String email) {
    return 'We submitted $email for review. We\'ll email this address to confirm. Once your parent or guardian responds, your case will move forward. Use Check Again from the account review screen for updates.';
  }

  @override
  String get minorAccountReviewSubmissionReceivedLocalBody =>
      'We received the parent or guardian contact for this account. Our team will review it before restoring access.';

  @override
  String get minorAccountReviewMissingCase =>
      'We could not find an active review case for this account.';

  @override
  String get minorAccountReviewParentContactError =>
      'Could not submit the parent email. Please try again.';

  @override
  String get minorAccountReviewUnder13SupportTitle => 'Parent Support';

  @override
  String get minorAccountReviewUnder13Heading =>
      'A parent or guardian must contact Divine';

  @override
  String get minorAccountReviewUnder13SupportBody =>
      'For likely under-13 accounts, the next step is parent or guardian contact by email.';

  @override
  String get minorAccountReviewSupportEmailLabel => 'Support email';

  @override
  String get minorAccountReviewCopySupportEmail => 'Copy support email';

  @override
  String get minorAccountReviewSupportEmailCopied => 'Support email copied';

  @override
  String get minorAccountReviewCopyCaseId => 'Copy case ID';

  @override
  String get minorAccountReviewCaseIdCopied => 'Case ID copied';

  @override
  String get minorAccountReviewUnavailable => 'Unavailable';

  @override
  String get minorAccountReviewUnder13Instructions =>
      'Ask the parent or guardian to include the case ID and explain that they are contacting Divine about this account review.';

  @override
  String minorAccountReviewUnder13EmailSubject(String caseId) {
    return 'Under-13 account review for case $caseId';
  }

  @override
  String minorAccountReviewUnder13EmailBody(String caseId) {
    return 'Hi Divine support,\n\nI am the parent or guardian for a child under 13 and I am contacting Divine about account review case $caseId.\n\nThanks.';
  }

  @override
  String get devOptionsMinorReviewSimulationTitle =>
      'Minor Account Review Simulation';

  @override
  String get devOptionsMinorReviewCurrentStateLabel => 'Current state';

  @override
  String devOptionsMinorReviewStateRestricted(String state) {
    return 'Restricted ($state)';
  }

  @override
  String get devOptionsMinorReviewStateActive => 'Active';

  @override
  String get devOptionsMinorReviewStateLoading => 'Loading...';

  @override
  String get devOptionsMinorReviewStateError => 'Error loading state';

  @override
  String get devOptionsMinorReviewClearTitle => 'Clear simulation override';

  @override
  String get devOptionsMinorReviewClearSubtitle =>
      'Use backend or default active state again';

  @override
  String get devOptionsMinorReviewTeenTitle => 'Simulate 13-15 review case';

  @override
  String get devOptionsMinorReviewTeenSubtitle =>
      'Restricted account with parent contact path';

  @override
  String get devOptionsMinorReviewUnder13Title =>
      'Simulate under-13 support case';

  @override
  String get devOptionsMinorReviewUnder13Subtitle =>
      'Restricted account with parent-email-only instructions';

  @override
  String get devOptionsMinorReviewClearedToast =>
      'Minor account review simulation cleared';

  @override
  String get devOptionsMinorReviewTeenEnabledToast =>
      'Simulated 13-15 review case enabled';

  @override
  String get devOptionsMinorReviewUnder13EnabledToast =>
      'Simulated under-13 support case enabled';

  @override
  String get devOptionsProtectedMinorSimulationTitle =>
      'Protected Minor Simulation';

  @override
  String get devOptionsProtectedMinorCurrentStateLabel => 'Current state';

  @override
  String get devOptionsProtectedMinorStateProtected =>
      'Protected minor (13-15)';

  @override
  String get devOptionsProtectedMinorStateNotProtected => 'Not protected';

  @override
  String get devOptionsProtectedMinorStateLoading => 'Loading…';

  @override
  String get devOptionsProtectedMinorStateError => 'Error reading state';

  @override
  String get devOptionsProtectedMinorOverrideNone =>
      'No override (real account state)';

  @override
  String get devOptionsProtectedMinorOverrideProtected =>
      'Override: forced protected';

  @override
  String get devOptionsProtectedMinorOverrideNotProtected =>
      'Override: forced not protected';

  @override
  String get devOptionsProtectedMinorSimulateTitle =>
      'Simulate protected minor (13-15)';

  @override
  String get devOptionsProtectedMinorSimulateSubtitle =>
      'Force the protected-minor state to QA the #175/#176 protections';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorTitle =>
      'Simulate non-minor';

  @override
  String get devOptionsProtectedMinorSimulateNonMinorSubtitle =>
      'Force not-protected (explicit negative, distinct from no override)';

  @override
  String get devOptionsProtectedMinorClearTitle => 'Clear override';

  @override
  String get devOptionsProtectedMinorClearSubtitle =>
      'Return to the real Keycast-driven account state';

  @override
  String get devOptionsProtectedMinorEnabledToast =>
      'Protected-minor state forced on';

  @override
  String get devOptionsProtectedMinorNonMinorToast =>
      'Protected-minor state forced off';

  @override
  String get devOptionsProtectedMinorClearedToast =>
      'Protected-minor override cleared';

  @override
  String get commentsRecordVideoButtonLabel => 'Nagraj komentarz wideo';

  @override
  String get commentsOpenVideoLabel => 'Otwórz komentarz wideo';

  @override
  String get commentsMuteVideoReplyLabel => 'Wycisz odpowiedź wideo';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Włącz dźwięk odpowiedzi wideo';

  @override
  String get commentsOpenReplyParentLabel =>
      'Otwórz film, na który to odpowiada';

  @override
  String get commentsReplyParentSectionTitle => 'W odpowiedzi na';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Odpowiedź na $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Odpowiedź na film';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Zweryfikowane konto $platform: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Zweryfikowane konta';

  @override
  String get profileEditGetVerifiedCta => 'Zweryfikuj się';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Połącz swoje konta w mediach społecznościowych, żeby ludzie wiedzieli, że to naprawdę ty.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visit website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Could not open website';

  @override
  String get videoMetadataEditCoverTitle => 'Edytuj okładkę';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Zamknij edytor okładki';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Potwierdź wybór okładki';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Przewijaj wideo, aby wybrać klatkę okładki';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Szukaj lub dodaj tagi';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Dodaj tagi, aby inni odkryli Twój film';

  @override
  String get videoMetadataTagsPickerNoResults => 'Brak pasujących tagów';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Dodaj „#$tag\"';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Nie masz jeszcze 16 lat? To w porządku. ';

  @override
  String get authUnder16ChoicesCta => 'Oto twoje możliwości.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Here\'s why';

  @override
  String get generalSettingsHoldToRecord => 'Przytrzymaj, aby nagrywać';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Nagrywanie rozpoczyna się po przytrzymaniu i zatrzymuje się po zwolnieniu';

  @override
  String get soundsPreviewFailedGeneric => 'Nie udało się odtworzyć podglądu';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filmów opublikowanych na twoim profilu',
      many: '$count filmów opublikowanych na twoim profilu',
      few: '$count filmy opublikowane na twoim profilu',
      one: 'Film opublikowany na twoim profilu',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Send message';

  @override
  String get emojiPickerSearchHint => 'Szukaj';

  @override
  String get emojiCategoryRecent => 'Ostatnie';

  @override
  String get emojiCategorySmileys => 'Uśmiechy i ludzie';

  @override
  String get emojiCategoryAnimals => 'Zwierzęta i natura';

  @override
  String get emojiCategoryFood => 'Jedzenie i napoje';

  @override
  String get emojiCategoryActivities => 'Aktywności';

  @override
  String get emojiCategoryTravel => 'Podróże i miejsca';

  @override
  String get emojiCategoryObjects => 'Przedmioty';

  @override
  String get emojiCategorySymbols => 'Symbole';

  @override
  String get emojiCategoryFlags => 'Flagi';

  @override
  String get videoEditorMarkerLabel => 'Znacznik';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Dodaj znacznik osi czasu';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Usuń znacznik osi czasu';

  @override
  String get videoEditorRemoveTimelineMarkerAtPlayheadSemanticLabel =>
      'Usuń znacznik przy głowicy odtwarzania';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Usunąć znacznik?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Spowoduje to usunięcie znacznika z osi czasu. Twoja edycja pozostanie bez zmian.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Wycisz lub wyłącz wyciszenie wszystkich ścieżek';

  @override
  String get videoEditorSplitFailed => 'Podział nieudany. Spróbuj ponownie.';

  @override
  String get videoEditEditSubtitles => 'Edytuj napisy';

  @override
  String get subtitleEditorTitle => 'Edytuj napisy';

  @override
  String get subtitleEditorSave => 'Zapisz';

  @override
  String get subtitleEditorProcessing =>
      'Napisy są jeszcze generowane. Zajrzyj za chwilę.';

  @override
  String get subtitleEditorLoadError =>
      'Nie udało się wczytać napisów. Spróbuj ponownie.';

  @override
  String get subtitleEditorSaveSuccess => 'Napisy zaktualizowane';

  @override
  String get subtitleEditorSaveError =>
      'Nie udało się zapisać napisów. Spróbuj ponownie.';

  @override
  String get subtitleEditorRetry => 'Spróbuj ponownie';

  @override
  String get subtitleEditorCueHint => 'Tekst napisu';

  @override
  String get imageCropEditorRotateLabel => 'Obróć';

  @override
  String get imageCropEditorFlipLabel => 'Odbij';

  @override
  String get imageCropEditorResetLabel => 'Resetuj';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Anuluj kadrowanie';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Zastosuj kadrowanie';

  @override
  String get imageCropEditorProcessing => 'Stosowanie kadrowania…';

  @override
  String get backgroundUploadNotificationTitle => 'Przesyłanie wideo';

  @override
  String get monetizationSettingsTitle => 'Creator Support';

  @override
  String get monetizationSettingsSubtitle => 'Add tip and subscription links';

  @override
  String get monetizationSettingsIntroTitle => 'Outbound links only';

  @override
  String get monetizationSettingsIntroBody =>
      'Add creator-controlled destinations. Divine never handles the payment or unlocks in-app content from these links.';

  @override
  String monetizationSettingsConfiguredCount(int count) {
    return '$count active link(s) on your profile';
  }

  @override
  String get monetizationSettingsTipSection => 'Send a tip';

  @override
  String get monetizationSettingsSubscriptionSection => 'Subscribe / support';

  @override
  String get monetizationSettingsSave => 'Save support links';

  @override
  String get monetizationSettingsSaving => 'Saving...';

  @override
  String get monetizationSettingsSaved => 'Support links updated';

  @override
  String get monetizationSettingsSaveFailed =>
      'Could not save support links. Check your connection and try again.';

  @override
  String get monetizationSettingsErrorEmpty => 'Add a handle or URL.';

  @override
  String get monetizationSettingsErrorInvalid =>
      'That link does not look right.';

  @override
  String get monetizationSettingsErrorWrongProvider =>
      'Use a link for this provider.';

  @override
  String get monetizationSettingsHintCashApp => '\$cashtag or cash.app link';

  @override
  String get monetizationSettingsHintPayPal => 'PayPal.me handle or link';

  @override
  String get monetizationSettingsHintVenmo => 'Venmo handle or link';

  @override
  String get monetizationSettingsHintPatreon => 'Patreon handle or link';

  @override
  String get monetizationSettingsHintSubstack => 'Substack domain or link';

  @override
  String get monetizationSettingsHintMedium => 'Medium handle or link';

  @override
  String get monetizationSettingsHintOpenCollective =>
      'Open Collective slug or link';

  @override
  String get profileSupportSheetTitle => 'Support this creator';

  @override
  String get profileSupportSheetBody =>
      'These links open outside Divine. Nothing here unlocks content in the app.';

  @override
  String get profileSupportTipSection => 'Send a tip';

  @override
  String get profileSupportSubscriptionSection => 'Subscribe / support';

  @override
  String get profileSupportButtonLabel => 'Support';

  @override
  String get monetizationTipsSettingsTitle => 'Tips';

  @override
  String get monetizationTipsSettingsSubtitle => 'Add optional tip links';

  @override
  String get monetizationTipsSettingsIntroTitle => 'Optional tips only';

  @override
  String get monetizationTipsSettingsIntroBody =>
      'Tips are optional user-to-user gifts. They do not unlock content, subscriptions, features, ranking, visibility, or access in Divine.';

  @override
  String monetizationTipsSettingsConfiguredCount(int count) {
    return '$count active tip link(s) on your profile';
  }

  @override
  String get monetizationTipsSettingsSave => 'Save tip links';

  @override
  String get monetizationTipsSettingsSaved => 'Tip links updated';

  @override
  String get profileTipButtonLabel => 'Tip';

  @override
  String get profileTipSheetTitle => 'Tip this creator';

  @override
  String get profileTipSheetBody =>
      'Tips open outside Divine. They are optional and do not unlock content, subscriptions, features, or access in Divine.';

  @override
  String get settingsStorageTitle => 'Pamięć';

  @override
  String get settingsStorageCacheSectionTitle =>
      'Multimedia w pamięci podręcznej';

  @override
  String get settingsStorageCacheDescription =>
      'Filmy z kanału, miniatury i tymczasowe rendery w pamięci podręcznej. Ich wyczyszczenie jest bezpieczne – zostaną ponownie pobrane lub wygenerowane w razie potrzeby.';

  @override
  String get settingsStorageMeasuring => 'Obliczanie…';

  @override
  String settingsStorageCacheInUse(String size) {
    return 'Zajęte: $size';
  }

  @override
  String get settingsStorageClearButton => 'Wyczyść pamięć podręczną';

  @override
  String get settingsStorageClearConfirmTitle =>
      'Wyczyścić multimedia z pamięci podręcznej?';

  @override
  String settingsStorageClearConfirmMessage(String size) {
    return 'To zwolni $size. Twoja biblioteka klipów nie zostanie naruszona.';
  }

  @override
  String get settingsStorageClearConfirmAction => 'Wyczyść';

  @override
  String get settingsStorageCleared => 'Pamięć podręczna wyczyszczona';

  @override
  String get settingsStorageLibrarySectionTitle => 'Biblioteka klipów';

  @override
  String get settingsStorageLibraryDescription =>
      'Sprawdź uszkodzone klipy, których plik wideo jest niedostępny.';

  @override
  String get settingsStorageScanButton => 'Sprawdź bibliotekę';

  @override
  String get settingsStorageLibraryHealthy =>
      'Nie znaleziono uszkodzonych klipów';

  @override
  String settingsStorageBrokenClipsFound(int count) {
    return 'Znalezione uszkodzone klipy: $count';
  }

  @override
  String get settingsStorageRemoveBrokenButton => 'Usuń uszkodzone klipy';

  @override
  String get settingsStorageBrokenClipsRemoved => 'Uszkodzone klipy usunięte';

  @override
  String get settingsStorageError => 'Coś poszło nie tak';

  @override
  String get settingsStorageMaxSizeLabel =>
      'Maksymalny rozmiar pamięci podręcznej';

  @override
  String settingsStorageApproxVideos(int count) {
    return '≈ $count filmów';
  }

  @override
  String get settingsStorageRemoveBrokenConfirmTitle =>
      'Usunąć uszkodzone klipy?';

  @override
  String get nostrSettingsSignatureVerification => 'Signature verification';

  @override
  String get nostrSettingsSignatureVerificationIntro =>
      'Choose when Divine checks relay event signatures. Event IDs are always validated first.';

  @override
  String get nostrSettingsSignatureVerificationAll => 'All relays';

  @override
  String get nostrSettingsSignatureVerificationAllSubtitle =>
      'Safest. Verify every relay event signature.';

  @override
  String get nostrSettingsSignatureVerificationUntrusted => 'Untrusted relays';

  @override
  String get nostrSettingsSignatureVerificationUntrustedSubtitle =>
      'Skip checks for relays already in your configured pool.';

  @override
  String get nostrSettingsSignatureVerificationNonDivine => 'Non-Divine relays';

  @override
  String get nostrSettingsSignatureVerificationNonDivineSubtitle =>
      'Trust Divine relays, verify the rest.';
}
