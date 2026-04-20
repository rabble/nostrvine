// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Polish (`pl`).
class AppLocalizationsPl extends AppLocalizations {
  AppLocalizationsPl([String locale = 'pl']) : super(locale);

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
  String get profileBlockedAccountNotAvailable => 'To konto jest niedostępne';

  @override
  String profileErrorPrefix(Object error) {
    return 'Błąd: $error';
  }

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
  String get profileLoadingTitle => 'Wczytywanie profilu...';

  @override
  String get profileLoadingSubtitle => 'To może chwilę potrwać';

  @override
  String get profileLoadingVideos => 'Wczytywanie filmów...';

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
  String profileSetupCameraAccessFailed(Object error) {
    return 'Dostęp do aparatu nieudany: $error';
  }

  @override
  String get profileSetupGotItButton => 'Rozumiem';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Nie udało się przesłać obrazu: $error';
  }

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
      'Nazwa użytkownika musi mieć 3-20 znaków';

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
  String get videoGridDeleteVideoSubtitle =>
      'Usuń ten film z Divine. Inne klienty Nostr mogą go nadal pokazywać.';

  @override
  String get videoGridDeleteConfirmTitle => 'Usuń film';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Ten film zostanie trwale usunięty z Divine. Może nadal być widoczny w innych klientach Nostr korzystających z innych przekaźników.';

  @override
  String get videoGridDeleteConfirmNote =>
      'To wyślе żądanie usunięcia do przekaźników. Uwaga: Niektóre przekaźniki mogą nadal mieć zbuforowane kopie.';

  @override
  String get videoGridDeleteCancel => 'Anuluj';

  @override
  String get videoGridDeleteConfirm => 'Usuń';

  @override
  String get videoGridDeletingContent => 'Usuwanie treści...';

  @override
  String get videoGridDeleteSuccess => 'Żądanie usunięcia wysłane pomyślnie';

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
  String get videoPlayerEditVideo => 'Edytuj film';

  @override
  String get videoPlayerEditVideoTooltip => 'Edytuj film';

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
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Udostępnij film';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post udostępniony z $recipientName';
  }

  @override
  String get shareFailedToSend => 'Nie udało się wysłać filmu';

  @override
  String get shareAddedToBookmarks => 'Dodano do zakładek';

  @override
  String get shareFailedToAddBookmark => 'Nie udało się dodać zakładki';

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
  String shareSendingTo(String name) {
    return 'Wysyłanie do $name';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Pętli',
      many: 'Pętli',
      few: 'Pętle',
      one: 'Pętla',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Polubienia';

  @override
  String get metadataCommentsLabel => 'Komentarze';

  @override
  String get metadataRepostsLabel => 'Reposty';

  @override
  String get devOptionsTitle => 'Opcje dewelopera';

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
      'Aktualizacje aplikacji i wiadomości systemowe';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Powiadomienia push';

  @override
  String get notificationSettingsPushNotifications => 'Powiadomienia push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Otrzymuj powiadomienia, gdy aplikacja jest zamknięta';

  @override
  String get notificationSettingsSound => 'Dźwięk';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Odtwarzaj dźwięk dla powiadomień';

  @override
  String get notificationSettingsVibration => 'Wibracje';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Wibruj przy powiadomieniach';

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
  String get authSignInDifferentAccount => 'Zaloguj się na inne konto';

  @override
  String get authSignBackIn => 'Zaloguj się z powrotem';

  @override
  String get authTermsPrefix =>
      'Wybierając opcję powyżej, potwierdzasz, że masz przynajmniej 16 lat i zgadzasz się z ';

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
  String get authForgotPassword => 'Zapomniałeś hasła?';

  @override
  String get authImportNostrKey => 'Importuj klucz Nostr';

  @override
  String get authConnectSignerApp => 'Połącz z aplikacją do podpisywania';

  @override
  String get authSignInWithAmber => 'Zaloguj się przez Amber';

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
  String get badgeExplanationClose => 'Zamknij';

  @override
  String get badgeExplanationOriginalVineArchive => 'Oryginalne archiwum Vine';

  @override
  String get badgeExplanationCameraProof => 'Dowód z aparatu';

  @override
  String get badgeExplanationAuthenticitySignals => 'Sygnały autentyczności';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Ten film to oryginalne Vine odzyskane z Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Zanim Vine zamknęło się w 2017 roku, ArchiveTeam i Internet Archive pracowały nad zachowaniem milionów Vineów dla potomności. Ta treść jest częścią tej historycznej akcji zachowania.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Oryginalne statystyki: $loops pętli';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Dowiedz się więcej o zachowaniu archiwum Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'Dowiedz się więcej o weryfikacji Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Dowiedz się więcej o sygnałach autentyczności Divine';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Sprawdź narzędziem ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Sprawdź szczegóły mediow';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Autentyczność tego filmu jest zweryfikowana technologią Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Ten film jest hostowany na Divine, a detekcja AI wskazuje, że jest prawdopodobnie stworzony przez człowieka, ale nie zawiera kryptograficznych danych weryfikacyjnych z aparatu.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Detekcja AI wskazuje, że ten film jest prawdopodobnie stworzony przez człowieka, choć nie zawiera kryptograficznych danych weryfikacyjnych z aparatu.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Ten film jest hostowany na Divine, ale jeszcze nie zawiera kryptograficznych danych weryfikacyjnych z aparatu.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Ten film jest hostowany poza Divine i nie zawiera kryptograficznych danych weryfikacyjnych z aparatu.';

  @override
  String get badgeExplanationDeviceAttestation => 'Atestacja urządzenia';

  @override
  String get badgeExplanationPgpSignature => 'Podpis PGP';

  @override
  String get badgeExplanationC2paCredentials => 'Poświadczenia treści C2PA';

  @override
  String get badgeExplanationProofManifest => 'Manifest dowodowy';

  @override
  String get badgeExplanationAiDetection => 'Detekcja AI';

  @override
  String get badgeExplanationAiNotScanned => 'Skan AI: Jeszcze nie zeskanowano';

  @override
  String get badgeExplanationNoScanResults => 'Brak dostępnych wyników skanu.';

  @override
  String get badgeExplanationCheckAiGenerated =>
      'Sprawdź, czy wygenerowane przez AI';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% prawdopodobieństwa, że wygenerowane przez AI';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Skanowane przez: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Zweryfikowane przez moderatora-człowieka';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platyna: Atestacja sprzętu urządzenia, podpisy kryptograficzne, poświadczenia treści (C2PA) i skan AI potwierdzają ludzkie pochodzenie.';

  @override
  String get badgeExplanationVerificationGold =>
      'Złoto: Nagrane na prawdziwym urządzeniu z atestacją sprzętu, podpisami kryptograficznymi i poświadczeniami treści (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Srebro: Podpisy kryptograficzne udowadniają, że film nie został zmieniony od momentu nagrania.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Brąz: Obecne są podstawowe podpisy metadanych.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Srebro: Skan AI potwierdza, że film jest prawdopodobnie stworzony przez człowieka.';

  @override
  String get badgeExplanationNoVerification =>
      'Brak danych weryfikacyjnych dla tego filmu.';

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
  String get shareMenuDeleteVideoSubtitle =>
      'Usuń ten film z Divine. Inne klienty Nostr mogą go nadal pokazywać.';

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
  String get shareMenuDeleteConfirmation =>
      'Ten film zostanie trwale usunięty z Divine. Może nadal być widoczny w innych klientach Nostr korzystających z innych przekaźników.';

  @override
  String get shareMenuCancel => 'Anuluj';

  @override
  String get shareMenuDelete => 'Usuń';

  @override
  String get shareMenuDeletingContent => 'Usuwanie treści...';

  @override
  String get shareMenuDeleteRequestSent => 'Film usunięty';

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
  String get shareMenuVideoUpdated => 'Film zaktualizowany pomyślnie';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Nie udało się zaktualizować filmu: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Usunąć film?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'To wyślе żądanie usunięcia do przekaźników. Uwaga: Niektóre przekaźniki mogą nadal mieć zbuforowane kopie.';

  @override
  String get shareMenuVideoDeletionRequested => 'Film usunięty';

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
  String get feedForYouEmpty =>
      'Twój kanał Dla Ciebie jest pusty.\nOdkrywaj filmy i obserwuj twórców, aby go ukształtować.';

  @override
  String get feedFollowingEmpty =>
      'Brak filmów od osób, które obserwujesz.\nZnajdź twórców, których lubisz i zacznij ich obserwować.';

  @override
  String get feedLatestEmpty => 'Brak nowych filmów.\nWróć tu wkrótce.';

  @override
  String get feedExploreVideos => 'Odkrywaj filmy';

  @override
  String get feedExternalVideoSlow => 'Zewnętrzny film wczytuje się powoli';

  @override
  String get feedSkip => 'Pomiń';

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
  String get reportReasonSpam => 'Spam lub niechciana treść';

  @override
  String get reportReasonHarassment => 'Nagabywanie, zniesławianie lub groźby';

  @override
  String get reportReasonViolence => 'Treści brutalne lub ekstremistyczne';

  @override
  String get reportReasonSexualContent => 'Treści seksualne lub dla dorosłych';

  @override
  String get reportReasonCopyright => 'Naruszenie praw autorskich';

  @override
  String get reportReasonFalseInfo => 'Fałszywe informacje';

  @override
  String get reportReasonCsam => 'Naruszenie bezpieczeństwa dzieci';

  @override
  String get reportReasonAiGenerated => 'Treść wygenerowana przez AI';

  @override
  String get reportReasonOther => 'Inne naruszenie regulaminu';

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
  String get reportLearnMore => 'Dowiedz się więcej';

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
  String get cameraPermissionNotNow => 'Nie teraz';

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
  String get profileSetupUploadSuccess =>
      'Zdjęcie profilowe przesłane pomyślnie!';

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
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Nie udało się zaktualizować subskrypcji: $error';
  }

  @override
  String get commonRetry => 'Ponów';

  @override
  String get commonDelete => 'Usuń';

  @override
  String get commonCancel => 'Anuluj';

  @override
  String get videoMetadataTags => 'Tagi';

  @override
  String get videoMetadataExpiration => 'Wygaśnięcie';

  @override
  String get videoMetadataContentWarnings => 'Ostrzeżenia o treści';

  @override
  String get videoEditorLayers => 'Warstwy';

  @override
  String get videoEditorStickers => 'Naklejki';

  @override
  String get trendingTitle => 'Na czasie';

  @override
  String get proofmodeCheckAiGenerated => 'Sprawdź, czy wygenerowane przez AI';

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
  String get routerInvalidCreator => 'Nieprawidłowy twórca';

  @override
  String get routerInvalidHashtagRoute => 'Nieprawidłowa ścieżka hashtagu';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Nie udało się załadować filmów';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Nie udało się załadować kategorii';

  @override
  String get notificationFollowBack => 'Zaobserwuj';

  @override
  String get followingFailedToLoadList =>
      'Nie udało się załadować listy obserwowanych';

  @override
  String get followersFailedToLoadList =>
      'Nie udało się załadować listy obserwujących';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Nie udało się zapisać ustawień: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Nie udało się zaktualizować ustawienia crosspostu';

  @override
  String get invitesTitle => 'Zaproś znajomych';

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
  String get cameraAgeRestriction =>
      'Musisz mieć co najmniej 16 lat, aby tworzyć treści';

  @override
  String get featureRequestCancel => 'Anuluj';

  @override
  String keyImportError(String error) {
    return 'Błąd: $error';
  }

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
  String get cameraPermissionContinue => 'Kontynuuj';

  @override
  String get cameraPermissionGoToSettings => 'Przejdź do ustawień';

  @override
  String get metadataCaptionsLabel => 'Captions';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Captions enabled for all videos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Captions disabled for all videos';
}
