// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Romanian Moldavian Moldovan (`ro`).
class AppLocalizationsRo extends AppLocalizations {
  AppLocalizationsRo([String locale = 'ro']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Setări';

  @override
  String get settingsSecureAccount => 'Securizează-ți contul';

  @override
  String get settingsSessionExpired => 'Sesiune expirată';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Autentifică-te din nou ca să recapeți acces complet';

  @override
  String get settingsCreatorAnalytics => 'Statistici pentru creatori';

  @override
  String get settingsSupportCenter => 'Centru de asistență';

  @override
  String get settingsNotifications => 'Notificări';

  @override
  String get settingsContentPreferences => 'Preferințe de conținut';

  @override
  String get settingsModerationControls => 'Controale de moderare';

  @override
  String get settingsBlueskyPublishing => 'Publicare pe Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gestionează postarea încrucișată pe Bluesky';

  @override
  String get settingsNostrSettings => 'Setări Nostr';

  @override
  String get settingsIntegratedApps => 'Aplicații integrate';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Aplicații terțe aprobate care rulează în Divine';

  @override
  String get settingsExperimentalFeatures => 'Funcții experimentale';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Chestii care s-ar putea să sughițe—încearcă-le dacă ești curios.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permisiuni de integrare';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Verifică și revocă aprobările memorate pentru integrări';

  @override
  String settingsVersion(String version) {
    return 'Versiunea $version';
  }

  @override
  String get settingsVersionEmpty => 'Versiune';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Modul dezvoltator e deja activat';

  @override
  String get settingsDeveloperModeEnabled => 'Mod dezvoltator activat!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de atingeri',
      few: '$count atingeri',
      one: 'o atingere',
    );
    return 'Încă $_temp0 ca să activezi modul dezvoltator';
  }

  @override
  String get settingsInvites => 'Invitații';

  @override
  String get settingsSwitchAccount => 'Schimbă contul';

  @override
  String get settingsAddAnotherAccount => 'Adaugă alt cont';

  @override
  String get settingsUnsavedDraftsTitle => 'Ciorne nesalvate';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ciorne',
      one: 'ciornă',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ciornele',
      one: 'ciorna',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'le',
      one: 'o',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'le',
      one: 'o',
    );
    return 'Ai $count $_temp0 nesalvate. Schimbarea contului âți va păstra $_temp1, dar poate vrei să $_temp2 publici sau să $_temp3 revizuiîi întâi.';
  }

  @override
  String get settingsCancel => 'Anulează';

  @override
  String get settingsSwitchAnyway => 'Schimbă oricum';

  @override
  String get settingsAppVersionLabel => 'Versiunea aplicației';

  @override
  String get settingsAppLanguage => 'Limba aplicației';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (implicit pe dispozitiv)';
  }

  @override
  String get settingsAppLanguageTitle => 'Limba aplicației';

  @override
  String get settingsAppLanguageDescription =>
      'Alege limba pentru interfața aplicației';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Folosește limba dispozitivului';

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
  String get contentPreferencesTitle => 'Preferințe de conținut';

  @override
  String get contentPreferencesContentFilters => 'Filtre de conținut';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gestionează filtrele pentru atenționări de conținut';

  @override
  String get contentPreferencesContentLanguage => 'Limba conținutului';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (implicit pe dispozitiv)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etichetează-ți videoclipurile cu o limbă, ca privitorii să poată filtra conținutul.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Folosește limba dispozitivului (implicit)';

  @override
  String get contentPreferencesAudioSharing =>
      'Fă audio-ul meu disponibil pentru refolosire';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Când e activat, alții pot folosi audio din videoclipurile tale';

  @override
  String get contentPreferencesAccountLabels => 'Etichete de cont';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-etichetează-ți conținutul';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etichete de conținut pentru cont';

  @override
  String get contentPreferencesClearAll => 'Șterge tot';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Selectează tot ce se potrivește contului tău';

  @override
  String get contentPreferencesDoneNoLabels => 'Gata (fără etichete)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Gata ($count selectate)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispozitiv de intrare audio';

  @override
  String get contentPreferencesAutoRecommended => 'Automat (recomandat)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Alege automat cel mai bun microfon';

  @override
  String get contentPreferencesSelectAudioInput => 'Alege intrarea audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Microfon necunoscut';

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
  String get profileBlockedAccountNotAvailable => 'Acest cont nu e disponibil';

  @override
  String profileErrorPrefix(Object error) {
    return 'Eroare: $error';
  }

  @override
  String get profileInvalidId => 'ID de profil invalid';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Aruncă o privire la $displayName pe Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName pe Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Nu am putut partaja profilul: $error';
  }

  @override
  String get profileEditProfile => 'Editează profilul';

  @override
  String get profileCreatorAnalytics => 'Statistici creator';

  @override
  String get profileShareProfile => 'Partajează profilul';

  @override
  String get profileCopyPublicKey => 'Copiază cheia publică (npub)';

  @override
  String get profileGetEmbedCode => 'Obține codul de încorporare';

  @override
  String get profilePublicKeyCopied => 'Cheia publică a fost copiată';

  @override
  String get profileEmbedCodeCopied => 'Codul de încorporare a fost copiat';

  @override
  String get profileRefreshTooltip => 'Reîncarcă';

  @override
  String get profileRefreshSemanticLabel => 'Reîncarcă profilul';

  @override
  String get profileMoreTooltip => 'Mai multe';

  @override
  String get profileMoreSemanticLabel => 'Mai multe opțiuni';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Închide avatarul';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Închide previzualizarea avatarului';

  @override
  String get profileFollowingLabel => 'Urmărit';

  @override
  String get profileFollowLabel => 'Urmărește';

  @override
  String get profileBlockedLabel => 'Blocat';

  @override
  String get profileFollowersLabel => 'Urmăritori';

  @override
  String get profileFollowingStatLabel => 'Urmăriți';

  @override
  String get profileVideosLabel => 'Videoclipuri';

  @override
  String profileFollowerCountUsers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de utilizatori',
      few: '$count utilizatori',
      one: '1 utilizator',
    );
    return '$_temp0';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Blochezi pe $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Când blochezi un utilizator:';

  @override
  String get profileBlockBulletHidePosts =>
      'Postările lui nu vor mai apărea în feedurile tale.';

  @override
  String get profileBlockBulletCantView =>
      'Nu va putea să-ți vadă profilul, să te urmărească sau să-ți vadă postările.';

  @override
  String get profileBlockBulletNoNotify =>
      'Nu va fi notificat despre această schimbare.';

  @override
  String get profileBlockBulletYouCanView =>
      'Tu încă vei putea să-i vezi profilul.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blochează pe $displayName';
  }

  @override
  String get profileCancelButton => 'Anulează';

  @override
  String get profileLearnMore => 'Află mai multe';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Deblochezi pe $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Când deblochezi acest utilizator:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Postările lui vor apărea în feedurile tale.';

  @override
  String get profileUnblockBulletCanView =>
      'Va putea să-ți vadă profilul, să te urmărească și să-ți vadă postările.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Nu va fi notificat despre această schimbare.';

  @override
  String get profileLearnMoreAt => 'Află mai multe la ';

  @override
  String get profileUnblockButton => 'Deblochează';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Nu mai urmări pe $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blochează pe $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Deblochează pe $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Adaugă $displayName la o listă';
  }

  @override
  String get profileUserBlockedTitle => 'Utilizator blocat';

  @override
  String get profileUserBlockedContent =>
      'Nu vei mai vedea conținut de la acest utilizator în feedurile tale.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Îl poți debloca oricând din profilul lui sau din Setări > Siguranță.';

  @override
  String get profileCloseButton => 'Închide';

  @override
  String get profileNoCollabsTitle => 'Încă nicio colaborare';

  @override
  String get profileCollabsOwnEmpty =>
      'Videoclipurile la care colaborezi vor apărea aici';

  @override
  String get profileCollabsOtherEmpty =>
      'Videoclipurile la care colaborează vor apărea aici';

  @override
  String get profileErrorLoadingCollabs => 'Eroare la încărcarea colaborărilor';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'Încă niciun comentariu';

  @override
  String get profileNoCommentsOtherTitle => 'Fără comentarii';

  @override
  String get profileCommentsOwnEmpty =>
      'Comentariile și răspunsurile tale vor apărea aici';

  @override
  String get profileCommentsOtherEmpty =>
      'Comentariile și răspunsurile lui vor apărea aici';

  @override
  String get profileErrorLoadingComments =>
      'Eroare la încărcarea comentariilor';

  @override
  String get profileVideoRepliesSection => 'Răspunsuri video';

  @override
  String get profileCommentsSection => 'Comentarii';

  @override
  String get profileEditLabel => 'Editează';

  @override
  String get profileLibraryLabel => 'Bibliotecă';

  @override
  String get profileNoLikedVideosTitle => 'Încă niciun videoclip apreciat';

  @override
  String get profileLikedOwnEmpty =>
      'Videoclipurile pe care le apreciezi vor apărea aici';

  @override
  String get profileLikedOtherEmpty =>
      'Videoclipurile pe care le apreciază vor apărea aici';

  @override
  String get profileErrorLoadingLiked =>
      'Eroare la încărcarea videoclipurilor apreciate';

  @override
  String get profileNoRepostsTitle => 'Încă nicio redistribuire';

  @override
  String get profileRepostsOwnEmpty =>
      'Videoclipurile pe care le redistribui vor apărea aici';

  @override
  String get profileRepostsOtherEmpty =>
      'Videoclipurile pe care le redistribuie vor apărea aici';

  @override
  String get profileErrorLoadingReposts =>
      'Eroare la încărcarea videoclipurilor redistribuite';

  @override
  String get profileLoadingTitle => 'Se încarcă profilul...';

  @override
  String get profileLoadingSubtitle => 'Poate dura câteva momente';

  @override
  String get profileLoadingVideos => 'Se încarcă videoclipurile...';

  @override
  String get profileNoVideosTitle => 'Încă niciun videoclip';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Distribuie primul tău videoclip ca să-l vezi aici';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Acest utilizator încă n-a distribuit niciun videoclip';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatură videoclip $number';
  }

  @override
  String get profileShowMore => 'Arată mai mult';

  @override
  String get profileShowLess => 'Arată mai puțin';

  @override
  String get profileCompleteYourProfile => 'Completează-ți profilul';

  @override
  String get profileCompleteSubtitle =>
      'Adaugă numele, bio și poza ca să începi';

  @override
  String get profileSetUpButton => 'Configurează';

  @override
  String get profileVerifyingEmail => 'Se verifică emailul...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Verifică $email pentru linkul de confirmare';
  }

  @override
  String get profileWaitingForVerification =>
      'Se așteaptă verificarea emailului';

  @override
  String get profileVerificationFailed => 'Verificare eșuată';

  @override
  String get profilePleaseTryAgain => 'Încearcă din nou';

  @override
  String get profileSecureYourAccount => 'Securizează-ți contul';

  @override
  String get profileSecureSubtitle =>
      'Adaugă email și parolă ca să-ți recuperezi contul pe orice dispozitiv';

  @override
  String get profileRetryButton => 'Reîncearcă';

  @override
  String get profileRegisterButton => 'Înscrie-te';

  @override
  String get profileSessionExpired => 'Sesiune expirată';

  @override
  String get profileSignInToRestore =>
      'Autentifică-te din nou ca să recapeți acces complet';

  @override
  String get profileSignInButton => 'Autentificare';

  @override
  String get profileMaybeLaterLabel => 'Maybe Later';

  @override
  String get profileSecurePrimaryButton => 'Add Email & Password';

  @override
  String get profileCompletePrimaryButton => 'Update Your Profile';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'My Library';

  @override
  String get profileMessageLabel => 'Message';

  @override
  String get profileUserFallback => 'user';

  @override
  String get profileDismissTooltip => 'Respinge';

  @override
  String get profileLinkCopied => 'Linkul profilului a fost copiat';

  @override
  String get profileSetupEditProfileTitle => 'Editează profilul';

  @override
  String get profileSetupBackLabel => 'Înapoi';

  @override
  String get profileSetupAboutNostr => 'Despre Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil publicat cu succes!';

  @override
  String get profileSetupCreateNewProfile => 'Creezi un profil nou?';

  @override
  String get profileSetupNoExistingProfile =>
      'N-am găsit un profil existent pe relay-urile tale. Publicarea va crea un profil nou. Continuăm?';

  @override
  String get profileSetupPublishButton => 'Publică';

  @override
  String get profileSetupUsernameTaken =>
      'Numele tocmai a fost luat. Alege altul.';

  @override
  String get profileSetupClaimFailed =>
      'N-am putut revendica numele. Încearcă din nou.';

  @override
  String get profileSetupPublishFailed =>
      'N-am putut publica profilul. Încearcă din nou.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Nu s-a putut accesa rețeaua. Verifică conexiunea și încearcă din nou.';

  @override
  String get profileSetupRetryLabel => 'Încearcă din nou';

  @override
  String get profileSetupDisplayNameLabel => 'Nume afișat';

  @override
  String get profileSetupDisplayNameHint => 'Cum să te știe oamenii?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Orice nume sau etichetă vrei. Nu trebuie să fie unic.';

  @override
  String get profileSetupDisplayNameRequired => 'Introdu un nume afișat';

  @override
  String get profileSetupBioLabel => 'Bio (opțional)';

  @override
  String get profileSetupBioHint => 'Spune-le oamenilor despre tine...';

  @override
  String get profileSetupPublicKeyLabel => 'Cheie publică (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nume de utilizator (opțional)';

  @override
  String get profileSetupUsernameHint => 'nume-utilizator';

  @override
  String get profileSetupUsernameHelper => 'Identitatea ta unică pe Divine';

  @override
  String get profileSetupProfileColorLabel => 'Culoarea profilului (opțional)';

  @override
  String get profileSetupSaveButton => 'Salvează';

  @override
  String get profileSetupSavingButton => 'Se salvează...';

  @override
  String get profileSetupImageUrlTitle => 'Adaugă URL de imagine';

  @override
  String get profileSetupPictureUploaded =>
      'Poză de profil încărcată cu succes!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Selectarea imaginii a eșuat. Lipește mai jos un URL de imagine.';

  @override
  String get profileSetupImagesTypeGroup => 'images';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Accesul la cameră a eșuat: $error';
  }

  @override
  String get profileSetupGotItButton => 'Am înțeles';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Încărcarea imaginii a eșuat. Încearcă din nou mai târziu.';

  @override
  String get profileSetupUploadNetworkError =>
      'Eroare de rețea: verifică conexiunea la internet și încearcă din nou.';

  @override
  String get profileSetupUploadAuthError =>
      'Eroare de autentificare: deconectează-te și autentifică-te din nou.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Fișier prea mare: alege o imagine mai mică (maxim 10MB).';

  @override
  String get profileSetupUploadServerError =>
      'Încărcarea imaginii a eșuat. Serverele noastre sunt temporar indisponibile. Încearcă din nou imediat.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Încărcarea pozei de profil nu este disponibilă încă pe web. Folosește aplicația de iOS sau Android ori lipește URL-ul unei imagini.';

  @override
  String get profileSetupUsernameChecking => 'Se verifică disponibilitatea...';

  @override
  String get profileSetupUsernameAvailable => 'Numele e disponibil!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Numele e deja luat';

  @override
  String get profileSetupUsernameReserved => 'Numele e rezervat';

  @override
  String get profileSetupContactSupport => 'Contactează asistența';

  @override
  String get profileSetupCheckAgain => 'Verifică din nou';

  @override
  String get profileSetupUsernameBurned => 'Acest nume nu mai e disponibil';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Sunt permise doar litere, cifre și cratime';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Numele trebuie să aibă 3-20 de caractere';

  @override
  String get profileSetupUsernameNetworkError =>
      'N-am putut verifica disponibilitatea. Încearcă din nou.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format invalid de nume';

  @override
  String get profileSetupUsernameCheckFailed =>
      'N-am putut verifica disponibilitatea';

  @override
  String get profileSetupUsernameReservedTitle => 'Nume rezervat';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Numele $username e rezervat. Spune-ne de ce ar trebui să fie al tău.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ex. E brandul meu, numele de scenă etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Ai contactat deja asistența? Apasă pe \"Verifică din nou\" ca să vezi dacă ți-a fost eliberat.';

  @override
  String get profileSetupSupportRequestSent =>
      'Cerere de asistență trimisă! Revenim la tine curând.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'N-am putut deschide emailul. Trimite la: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Trimite cererea';

  @override
  String get profileSetupPickColorTitle => 'Alege o culoare';

  @override
  String get profileSetupSelectButton => 'Selectează';

  @override
  String get profileSetupUseOwnNip05 => 'Folosește propria ta adresă NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Adresă NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Invalid NIP-05 format (e.g., name@domain.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Use the username field above for divine.video';

  @override
  String get profileSetupProfilePicturePreview =>
      'Previzualizare poză de profil';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine e construit pe Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocol deschis și rezistent la cenzură care permite oamenilor să comunice online fără să depindă de o singură companie sau platformă. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Când te înscrii pe Divine, primești o identitate Nostr nouă.';

  @override
  String get nostrInfoOwnership =>
      'Nostr țiţi lasă în posesie conținutul, identitatea și graful social, pe care le poți folosi în multe aplicații. Rezultă mai multă alegere, mai puțină dependență și un internet social mai sănătos și mai rezilient.';

  @override
  String get nostrInfoLingo => 'Jargon Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Adresa ta publică Nostr. E sigur s-o distribui și le permite altora să te găsească, să te urmărească sau să-ți trimită mesaje pe aplicații Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Cheia ta privată și dovada de proprietate. Îți dă control total asupra identității tale Nostr, așa că ';

  @override
  String get nostrInfoNsecWarning => 'ține-o mereu secretă!';

  @override
  String get nostrInfoUsernameLabel => 'Nume de utilizator Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nume ușor de citit (gen @nume.divine.video) care duce la npub-ul tău. Face identitatea ta Nostr mai ușor de recunoscut și verificat, ca o adresă de email.';

  @override
  String get nostrInfoLearnMoreAt => 'Află mai multe la ';

  @override
  String get nostrInfoGotIt => 'Am înțeles!';

  @override
  String get profileTabRefreshTooltip => 'Reîncarcă';

  @override
  String get videoGridRefreshLabel => 'Se caută mai multe videoclipuri';

  @override
  String get videoGridOptionsTitle => 'Opțiuni video';

  @override
  String get videoGridEditVideo => 'Editează videoclipul';

  @override
  String get videoGridEditVideoSubtitle =>
      'Actualizează titlul, descrierea și hashtagurile';

  @override
  String get videoGridDeleteVideo => 'Șterge videoclipul';

  @override
  String get videoGridDeleteVideoSubtitle => 'Elimină definitiv acest conținut';

  @override
  String get videoGridDeleteConfirmTitle => 'Șterge videoclipul';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Sigur vrei să ștergi acest videoclip?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Asta va trimite o cerere de ștergere (NIP-09) către toate relay-urile. Unele relay-uri pot păstra totuși conținutul.';

  @override
  String get videoGridDeleteCancel => 'Anulează';

  @override
  String get videoGridDeleteConfirm => 'Șterge';

  @override
  String get videoGridDeletingContent => 'Se șterge conținutul...';

  @override
  String get videoGridDeleteSuccess =>
      'Cererea de ștergere a fost trimisă cu succes';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'N-am putut șterge conținutul: $error';
  }

  @override
  String get exploreTabClassics => 'Clasice';

  @override
  String get exploreTabNew => 'Noi';

  @override
  String get exploreTabPopular => 'Populare';

  @override
  String get exploreTabCategories => 'Categorii';

  @override
  String get exploreTabForYou => 'Pentru tine';

  @override
  String get exploreTabLists => 'Liste';

  @override
  String get exploreTabIntegratedApps => 'Aplicații integrate';

  @override
  String get exploreNoVideosAvailable => 'Niciun videoclip disponibil';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Eroare: $error';
  }

  @override
  String get exploreDiscoverLists => 'Descoperă liste';

  @override
  String get exploreAboutLists => 'Despre liste';

  @override
  String get exploreAboutListsDescription =>
      'Listele te ajută să organizezi și să curaâezi conținutul Divine în două feluri:';

  @override
  String get explorePeopleLists => 'Liste de oameni';

  @override
  String get explorePeopleListsDescription =>
      'Urmărește grupuri de creatori și vezi cele mai noi videoclipuri ale lor';

  @override
  String get exploreVideoLists => 'Liste de videoclipuri';

  @override
  String get exploreVideoListsDescription =>
      'Creează playlisturi cu videoclipurile preferate ca să le vezi mai târziu';

  @override
  String get exploreMyLists => 'Listele mele';

  @override
  String get exploreSubscribedLists => 'Liste la care ești abonat';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Eroare la încărcarea listelor: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videoclipuri noi',
      one: '1 videoclip nou',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videoclipuri noi',
      one: 'videoclip nou',
    );
    return 'Încarcă $count $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Se încarcă videoclipul...';

  @override
  String get videoPlayerPlayVideo => 'Redă videoclipul';

  @override
  String get videoPlayerMute => 'Dezactivează sunetul videoclipului';

  @override
  String get videoPlayerUnmute => 'Activează sunetul videoclipului';

  @override
  String get videoPlayerEditVideo => 'Editează videoclipul';

  @override
  String get videoPlayerEditVideoTooltip => 'Editează videoclipul';

  @override
  String get contentWarningLabel => 'Atenționare de conținut';

  @override
  String get contentWarningNudity => 'Nuditate';

  @override
  String get contentWarningSexualContent => 'Conținut sexual';

  @override
  String get contentWarningPornography => 'Pornografie';

  @override
  String get contentWarningGraphicMedia => 'Imagini explicite';

  @override
  String get contentWarningViolence => 'Violență';

  @override
  String get contentWarningSelfHarm => 'Auto-vătămare';

  @override
  String get contentWarningDrugUse => 'Consum de droguri';

  @override
  String get contentWarningAlcohol => 'Alcool';

  @override
  String get contentWarningTobacco => 'Tutun';

  @override
  String get contentWarningGambling => 'Jocuri de noroc';

  @override
  String get contentWarningProfanity => 'Limbaj vulgar';

  @override
  String get contentWarningFlashingLights => 'Lumini care clipesc';

  @override
  String get contentWarningAiGenerated => 'Generat de AI';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Conținut sensibil';

  @override
  String get contentWarningDescNudity =>
      'Conține nuditate sau nuditate parțială';

  @override
  String get contentWarningDescSexual => 'Conține conținut sexual';

  @override
  String get contentWarningDescPorn => 'Conține conținut pornografic explicit';

  @override
  String get contentWarningDescGraphicMedia =>
      'Conține imagini explicite sau tulburătoare';

  @override
  String get contentWarningDescViolence => 'Conține conținut violent';

  @override
  String get contentWarningDescSelfHarm => 'Conține referințe la auto-vătămare';

  @override
  String get contentWarningDescDrugs => 'Conține conținut legat de droguri';

  @override
  String get contentWarningDescAlcohol => 'Conține conținut legat de alcool';

  @override
  String get contentWarningDescTobacco => 'Conține conținut legat de tutun';

  @override
  String get contentWarningDescGambling =>
      'Conține conținut legat de jocuri de noroc';

  @override
  String get contentWarningDescProfanity => 'Conține limbaj vulgar';

  @override
  String get contentWarningDescFlashingLights =>
      'Conține lumini care clipesc (avertisment de fotosensibilitate)';

  @override
  String get contentWarningDescAiGenerated =>
      'Acest conținut a fost generat de AI';

  @override
  String get contentWarningDescSpoiler => 'Conține spoilere';

  @override
  String get contentWarningDescContentWarning =>
      'Creatorul a marcat asta ca sensibil';

  @override
  String get contentWarningDescDefault => 'Creatorul a semnalat acest conținut';

  @override
  String get contentWarningDetailsTitle => 'Atenționări de conținut';

  @override
  String get contentWarningDetailsSubtitle =>
      'Creatorul a aplicat aceste etichete:';

  @override
  String get contentWarningManageFilters => 'Gestionează filtrele de conținut';

  @override
  String get contentWarningViewAnyway => 'Vezi oricum';

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
  String get contentWarningHideAllLikeThis =>
      'Ascunde tot conținutul de genul ăsta';

  @override
  String get contentWarningNoFilterYet =>
      'Încă n-ai un filtru salvat pentru această atenționare.';

  @override
  String get contentWarningHiddenConfirmation =>
      'De acum înainte ascundem postările de genul ăsta.';

  @override
  String get videoErrorNotFound => 'Videoclipul n-a fost găsit';

  @override
  String get videoErrorNetwork => 'Eroare de rețea';

  @override
  String get videoErrorTimeout => 'Timpul de încărcare a expirat';

  @override
  String get videoErrorFormat =>
      'Eroare de format video\n(Încearcă din nou sau folosește alt browser)';

  @override
  String get videoErrorUnsupportedFormat => 'Format video nesuportat';

  @override
  String get videoErrorPlayback => 'Eroare de redare video';

  @override
  String get videoErrorAgeRestricted => 'Conținut cu restricție de vârstă';

  @override
  String get videoErrorVerifyAge => 'Verifică vârsta';

  @override
  String get videoErrorRetry => 'Reîncearcă';

  @override
  String get videoErrorContentRestricted => 'Conținut restricționat';

  @override
  String get videoErrorContentRestrictedBody =>
      'Acest videoclip a fost restricționat de relay.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifică-ți vârsta ca să vezi acest videoclip.';

  @override
  String get videoErrorSkip => 'Sari peste';

  @override
  String get videoErrorVerifyAgeButton => 'Verifică vârsta';

  @override
  String get videoFollowButtonFollowing => 'Urmărit';

  @override
  String get videoFollowButtonFollow => 'Urmărește';

  @override
  String get audioAttributionOriginalSound => 'Sunet original';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirat de @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'cu @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'cu @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colaboratori',
      one: '1 colaborator',
    );
    return '$_temp0. Atinge pentru a vedea profilul.';
  }

  @override
  String get listAttributionFallback => 'Listă';

  @override
  String get shareVideoLabel => 'Partajează videoclipul';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Postare partajată cu $recipientName';
  }

  @override
  String get shareFailedToSend => 'N-am putut trimite videoclipul';

  @override
  String get shareAddedToBookmarks => 'Adăugat la semne de carte';

  @override
  String get shareRemovedFromBookmarks => 'Eliminat din semne de carte';

  @override
  String get shareFailedToAddBookmark => 'N-am putut adăuga semnul de carte';

  @override
  String get shareFailedToRemoveBookmark =>
      'N-am putut elimina semnul de carte';

  @override
  String get shareActionFailed => 'Acțiunea a eșuat';

  @override
  String get shareWithTitle => 'Partajează cu';

  @override
  String get shareFindPeople => 'Găsește oameni';

  @override
  String get shareFindPeopleMultiline => 'Găsește\noameni';

  @override
  String get shareSent => 'Trimis';

  @override
  String get shareContactFallback => 'Contact';

  @override
  String get shareUserFallback => 'Utilizator';

  @override
  String shareSendingTo(String name) {
    return 'Se trimite către $name';
  }

  @override
  String get shareMessageHint => 'Adaugă un mesaj opțional...';

  @override
  String get videoActionUnlike => 'Retrage aprecierea';

  @override
  String get videoActionLike => 'Apreciază videoclipul';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Like';

  @override
  String get videoActionReplyLabel => 'Reply';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Share';

  @override
  String get videoActionAboutLabel => 'About';

  @override
  String get videoActionEnableAutoAdvance => 'Activează avansarea automată';

  @override
  String get videoActionDisableAutoAdvance => 'Dezactivează avansarea automată';

  @override
  String get videoActionRemoveRepost => 'Elimină redistribuirea';

  @override
  String get videoActionRepost => 'Redistribuie videoclipul';

  @override
  String get videoActionViewComments => 'Vezi comentariile';

  @override
  String get videoActionMoreOptions => 'Mai multe opțiuni';

  @override
  String get videoActionHideSubtitles => 'Ascunde subtitrările';

  @override
  String get videoActionShowSubtitles => 'Arată subtitrările';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

  @override
  String videoDescriptionLoops(String count) {
    return '$count bucle';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bucle',
      one: 'buclă',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Nu e Divine';

  @override
  String get metadataBadgeHumanMade => 'Făcut de om';

  @override
  String get metadataSoundsLabel => 'Sunete';

  @override
  String get metadataOriginalSound => 'Sunet original';

  @override
  String get metadataVerificationLabel => 'Verificare';

  @override
  String get metadataDeviceAttestation => 'Atestare de dispozitiv';

  @override
  String get metadataProofManifest => 'Manifest de dovezi';

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Colaboratori';

  @override
  String get metadataInspiredByLabel => 'Inspirat de';

  @override
  String get metadataRepostedByLabel => 'Redistribuit de';

  @override
  String metadataLoopsLabel(int count) {
    return 'Bucle';
  }

  @override
  String get metadataLikesLabel => 'Aprecieri';

  @override
  String get metadataCommentsLabel => 'Comentarii';

  @override
  String get metadataRepostsLabel => 'Redistribuiri';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicat pe $date';
  }

  @override
  String get devOptionsTitle => 'Opțiuni dezvoltator';

  @override
  String get devOptionsPageLoadTimes => 'Timpi de încărcare a paginilor';

  @override
  String get devOptionsNoPageLoads =>
      'Nicio încărcare de pagină înregistrată încă.\nNavighează prin aplicație ca să vezi datele de timing.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Vizibil: ${visibleMs}ms  |  Date: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Cele mai lente ecrane';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format de redare video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Schimbi mediul?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Schimbi la $envName?\n\nAsta va șterge datele video din cache și se va reconecta la noul relay.';
  }

  @override
  String get devOptionsCancel => 'Anulează';

  @override
  String get devOptionsSwitch => 'Schimbă';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Schimbat la $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Schimbat la $formatName — cache șters';
  }

  @override
  String get featureFlagTitle => 'Indicatoare de funcții';

  @override
  String get featureFlagResetAllTooltip =>
      'Resetează toate indicatoarele la valorile implicite';

  @override
  String get featureFlagResetToDefault => 'Resetează la valoarea implicită';

  @override
  String get featureFlagAppRecovery => 'Recuperare aplicație';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Dacă aplicația se blochează sau se comportă ciudat, încearcă să goli cache-ul.';

  @override
  String get featureFlagClearAllCache => 'Golește tot cache-ul';

  @override
  String get featureFlagCacheInfo => 'Informații cache';

  @override
  String get featureFlagClearCacheTitle => 'Golești tot cache-ul?';

  @override
  String get featureFlagClearCacheMessage =>
      'Asta va șterge toate datele din cache, inclusiv:\n• Notificări\n• Profiluri de utilizator\n• Semne de carte\n• Fișiere temporare\n\nVa trebui să te autentifici din nou. Continuăm?';

  @override
  String get featureFlagClearCache => 'Golește cache-ul';

  @override
  String get featureFlagClearingCache => 'Se golește cache-ul...';

  @override
  String get featureFlagSuccess => 'Succes';

  @override
  String get featureFlagError => 'Eroare';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache-ul a fost golit cu succes. Repornește aplicația.';

  @override
  String get featureFlagClearCacheFailure =>
      'Unele elemente din cache n-au putut fi șterse. Verifică jurnalele pentru detalii.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Informații despre cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Dimensiunea totală a cache-ului: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cache-ul include:\n• Istoricul notificărilor\n• Datele profilurilor de utilizator\n• Miniaturi video\n• Fișiere temporare\n• Indexuri de baze de date';

  @override
  String get relaySettingsTitle => 'Relay-uri';

  @override
  String get relaySettingsInfoTitle =>
      'Divine e un sistem deschis - tu âți controlezi conexiunile';

  @override
  String get relaySettingsInfoDescription =>
      'Aceste relay-uri distribuie conținutul tău prin rețeaua descentralizată Nostr. Poți adăuga sau elimina relay-uri după cum vrei.';

  @override
  String get relaySettingsLearnMoreNostr => 'Află mai multe despre Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Găsește relay-uri publice la nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Aplicația nu e funcțională';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine are nevoie de cel puțin un relay ca să încarce videoclipuri, să publice conținut și să sincronizeze date.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Restabilește relay-ul implicit';

  @override
  String get relaySettingsAddCustomRelay => 'Adaugă relay personalizat';

  @override
  String get relaySettingsAddRelay => 'Adaugă relay';

  @override
  String get relaySettingsRetry => 'Reîncearcă';

  @override
  String get relaySettingsNoStats => 'Încă nicio statistică disponibilă';

  @override
  String get relaySettingsConnection => 'Conexiune';

  @override
  String get relaySettingsConnected => 'Conectat';

  @override
  String get relaySettingsDisconnected => 'Deconectat';

  @override
  String get relaySettingsSessionDuration => 'Durata sesiunii';

  @override
  String get relaySettingsLastConnected => 'Ultima conectare';

  @override
  String get relaySettingsDisconnectedLabel => 'Deconectat';

  @override
  String get relaySettingsReason => 'Motiv';

  @override
  String get relaySettingsActiveSubscriptions => 'Abonări active';

  @override
  String get relaySettingsTotalSubscriptions => 'Total abonări';

  @override
  String get relaySettingsEventsReceived => 'Evenimente primite';

  @override
  String get relaySettingsEventsSent => 'Evenimente trimise';

  @override
  String get relaySettingsRequestsThisSession => 'Cereri în această sesiune';

  @override
  String get relaySettingsFailedRequests => 'Cereri eșuate';

  @override
  String relaySettingsLastError(String error) {
    return 'Ultima eroare: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Se încarcă informațiile despre relay...';

  @override
  String get relaySettingsAboutRelay => 'Despre relay';

  @override
  String get relaySettingsSupportedNips => 'NIP-uri suportate';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Vezi site-ul';

  @override
  String get relaySettingsRemoveRelayTitle => 'Elimini relay-ul?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Sigur vrei să elimini acest relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Anulează';

  @override
  String get relaySettingsRemove => 'Elimină';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay eliminat: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'N-am putut elimina relay-ul';

  @override
  String get relaySettingsForcingReconnection =>
      'Se forțează reconectarea la relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de relay-uri',
      few: '$count relay-uri',
      one: '1 relay',
    );
    return 'Conectat la $_temp0!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'N-am putut conecta la relay-uri. Verifică-ți conexiunea la rețea.';

  @override
  String get relaySettingsAddRelayTitle => 'Adaugă relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Introdu URL-ul WebSocket al relay-ului pe care vrei să-l adaugi:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Răsfoiește relay-urile publice la nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Adaugă';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay adăugat: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'N-am putut adăuga relay-ul. Verifică URL-ul și încearcă din nou.';

  @override
  String get relaySettingsInvalidUrl =>
      'URL-ul relay-ului trebuie să înceapă cu wss:// sau ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay URL must use wss:// (ws:// is allowed only for localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay-ul implicit a fost restabilit: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'N-am putut restabili relay-ul implicit. Verifică-ți conexiunea la rețea.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'N-am putut deschide browserul';

  @override
  String get relaySettingsFailedToOpenLink => 'N-am putut deschide linkul';

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
  String get relayDiagnosticTitle => 'Diagnostice relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Reîncarcă diagnosticele';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Ultima reîncarcare: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Stare relay';

  @override
  String get relayDiagnosticInitialized => 'Inițializat';

  @override
  String get relayDiagnosticReady => 'Gata';

  @override
  String get relayDiagnosticNotInitialized => 'Neinițializat';

  @override
  String get relayDiagnosticDatabaseEvents => 'Evenimente din baza de date';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Abonări active';

  @override
  String get relayDiagnosticExternalRelays => 'Relay-uri externe';

  @override
  String get relayDiagnosticConfigured => 'Configurat';

  @override
  String relayDiagnosticRelayCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de relay-uri',
      few: '$count relay-uri',
      one: '1 relay',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Conectat';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Evenimente video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed principal';

  @override
  String relayDiagnosticVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get relayDiagnosticDiscovery => 'Descoperire';

  @override
  String get relayDiagnosticLoading => 'Se încarcă';

  @override
  String get relayDiagnosticYes => 'Da';

  @override
  String get relayDiagnosticNo => 'Nu';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testează interogarea directă';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Conectivitate rețea';

  @override
  String get relayDiagnosticRunNetworkTest => 'Rulează testul de rețea';

  @override
  String get relayDiagnosticBlossomServer => 'Server Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testează toate endpoint-urile';

  @override
  String get relayDiagnosticStatus => 'Stare';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Eroare';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL de bază';

  @override
  String get relayDiagnosticSummary => 'Sumar';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (medie ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retestează tot';

  @override
  String get relayDiagnosticRetrying => 'Se reîncearcă...';

  @override
  String get relayDiagnosticRetryConnection => 'Reîncearcă conexiunea';

  @override
  String get relayDiagnosticTroubleshooting => 'Depanare';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Stare verde = Conectat și funcțional\n• Stare roșie = Conexiunea a eșuat\n• Dacă testul de rețea eșuează, verifică conexiunea la internet\n• Dacă relay-urile sunt configurate dar neconectate, apasă \"Reîncearcă conexiunea\"\n• Fă o captură de ecran pentru depanare';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Toate endpoint-urile REST sunt sănătoase!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Unele endpoint-uri REST au eșuat - vezi detaliile mai sus';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de evenimente video',
      few: '$count evenimente video',
      one: '1 eveniment video',
    );
    return 'Am găsit $_temp0 în baza de date';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Interogarea a eșuat: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de relay-uri',
      few: '$count relay-uri',
      one: '1 relay',
    );
    return 'Conectat la $_temp0!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'N-am putut conecta la niciun relay';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Reîncercarea conexiunii a eșuat: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Conectat și autentificat';

  @override
  String get relayDiagnosticConnectedOnly => 'Conectat';

  @override
  String get relayDiagnosticNotConnected => 'Neconectat';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Niciun relay configurat';

  @override
  String get relayDiagnosticFailed => 'Eșuat';

  @override
  String get notificationSettingsTitle => 'Notificări';

  @override
  String get notificationSettingsResetTooltip =>
      'Resetează la valorile implicite';

  @override
  String get notificationSettingsTypes => 'Tipuri de notificări';

  @override
  String get notificationSettingsLikes => 'Aprecieri';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Când cineva âți apreciază videoclipurile';

  @override
  String get notificationSettingsComments => 'Comentarii';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Când cineva comentează la videoclipurile tale';

  @override
  String get notificationSettingsFollows => 'Urmăriri';

  @override
  String get notificationSettingsFollowsSubtitle => 'Când cineva te urmărește';

  @override
  String get notificationSettingsMentions => 'Menționări';

  @override
  String get notificationSettingsMentionsSubtitle => 'Când ești menționat';

  @override
  String get notificationSettingsReposts => 'Redistribuiri';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Când cineva âți redistribuie videoclipurile';

  @override
  String get notificationSettingsSystem => 'Sistem';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Actualizări de aplicație și mesaje de sistem';

  @override
  String get notificationSettingsPushNotificationsSection => 'Notificări push';

  @override
  String get notificationSettingsPushNotifications => 'Notificări push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Primește notificări când aplicația e închisă';

  @override
  String get notificationSettingsSound => 'Sunet';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Redă sunet pentru notificări';

  @override
  String get notificationSettingsVibration => 'Vibrație';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Vibrează pentru notificări';

  @override
  String get notificationSettingsActions => 'Acțiuni';

  @override
  String get notificationSettingsMarkAllAsRead => 'Marchează toate ca citite';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marchează toate notificările ca citite';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Toate notificările au fost marcate ca citite';

  @override
  String get notificationSettingsResetToDefaults =>
      'Setările au fost resetate la valorile implicite';

  @override
  String get notificationSettingsAbout => 'Despre notificări';

  @override
  String get notificationSettingsAboutDescription =>
      'Notificările sunt alimentate de protocolul Nostr. Actualizările în timp real depind de conexiunea ta la relay-urile Nostr. Unele notificări pot avea întârzieri.';

  @override
  String get safetySettingsTitle => 'Siguranță și confidențialitate';

  @override
  String get safetySettingsLabel => 'SETĂRI';

  @override
  String get safetySettingsWhatYouSee => 'WHAT YOU SEE';

  @override
  String get safetySettingsWhatYouPublish => 'WHAT YOU PUBLISH';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Arată doar videoclipurile găzduite de Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ascunde videoclipurile servite de alte găzduiri media';

  @override
  String get safetySettingsModeration => 'MODERARE';

  @override
  String get safetySettingsBlockedUsers => 'UTILIZATORI BLOCAȚI';

  @override
  String get safetySettingsAgeVerification => 'VERIFICARE VÂRSTĂ';

  @override
  String get safetySettingsAgeConfirmation =>
      'Confirm că am 18 ani sau mai mult';

  @override
  String get safetySettingsAgeRequired =>
      'Necesar pentru a vedea conținut pentru adulți';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Serviciu oficial de moderare (activat implicit)';

  @override
  String get safetySettingsPeopleIFollow => 'Oameni pe care âi urmăresc';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Abonează-te la etichete de la oameni pe care âi urmărești';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Adaugă etichetator personalizat';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Introdu npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Adaugă etichetator personalizat';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Introdu adresa npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Niciun utilizator blocat';

  @override
  String get safetySettingsUnblock => 'Deblochează';

  @override
  String get safetySettingsUserUnblocked => 'Utilizator deblocat';

  @override
  String get safetySettingsCancel => 'Anulează';

  @override
  String get safetySettingsAdd => 'Adaugă';

  @override
  String get analyticsTitle => 'Statistici creator';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostice';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Comută diagnosticele';

  @override
  String get analyticsRetry => 'Reîncearcă';

  @override
  String get analyticsUnableToLoad => 'Nu am putut încărca statisticile.';

  @override
  String get analyticsSignInRequired =>
      'Autentifică-te ca să vezi statisticile pentru creatori.';

  @override
  String get analyticsViewDataUnavailable =>
      'Vizualizările nu sunt disponibile momentan de la relay pentru aceste postări. Metricile de aprecieri/comentarii/redistribuiri sunt totuși corecte.';

  @override
  String get analyticsViewDataTitle => 'Date vizualizări';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Actualizat $time • Scorurile folosesc aprecieri, comentarii, redistribuiri și vizualizări/bucle de la Funnelcake când sunt disponibile.';
  }

  @override
  String get analyticsVideos => 'Videoclipuri';

  @override
  String get analyticsViews => 'Vizualizări';

  @override
  String get analyticsInteractions => 'Interacțiuni';

  @override
  String get analyticsEngagement => 'Implicare';

  @override
  String get analyticsFollowers => 'Urmăritori';

  @override
  String get analyticsAvgPerPost => 'Medie/Postare';

  @override
  String get analyticsInteractionMix => 'Mixul interacțiunilor';

  @override
  String get analyticsLikes => 'Aprecieri';

  @override
  String get analyticsComments => 'Comentarii';

  @override
  String get analyticsReposts => 'Redistribuiri';

  @override
  String get analyticsPerformanceHighlights => 'Repere de performanță';

  @override
  String get analyticsMostViewed => 'Cele mai vizualizate';

  @override
  String get analyticsMostDiscussed => 'Cele mai discutate';

  @override
  String get analyticsMostReposted => 'Cele mai redistribuite';

  @override
  String get analyticsNoVideosYet => 'Încă niciun videoclip';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Date de vizualizare indisponibile';

  @override
  String analyticsViewsCount(String count) {
    return '$count vizualizări';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count comentarii';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count redistribuiri';
  }

  @override
  String get analyticsTopContent => 'Conținut de top';

  @override
  String get analyticsPublishPrompt =>
      'Publică câteva videoclipuri ca să vezi clasamentele.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Procentul din dreapta = Rata de implicare (interacțiuni împărțite la vizualizări).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Rata de implicare are nevoie de date de vizualizare; valorile apar ca N/A până când sunt disponibile vizualizările.';

  @override
  String get analyticsEngagementLabel => 'Implicare';

  @override
  String get analyticsViewsUnavailable => 'vizualizări indisponibile';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interacțiuni';
  }

  @override
  String get analyticsPostAnalytics => 'Statistici postare';

  @override
  String get analyticsOpenPost => 'Deschide postarea';

  @override
  String get analyticsRecentDailyInteractions => 'Interacțiuni zilnice recente';

  @override
  String get analyticsNoActivityYet =>
      'Încă nicio activitate în acest interval.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interacțiuni = aprecieri + comentarii + redistribuiri după data postării.';

  @override
  String get analyticsDailyBarExplainer =>
      'Lungimea barei e relativă la cea mai bună zi a ta din această fereastră.';

  @override
  String get analyticsAudienceSnapshot => 'Instantaneu audiență';

  @override
  String analyticsFollowersCount(String count) {
    return 'Urmăritori: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Urmăriți: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Detaliile despre sursa/geografia/timpul audienței se vor popula pe măsură ce Funnelcake adaugă endpoint-uri de statistici de audiență.';

  @override
  String get analyticsRetention => 'Retenție';

  @override
  String get analyticsRetentionWithViews =>
      'Curba de retenție și defalcarea timpului de vizionare vor apărea odată ce retenția per secundă/bucketă ajunge de la Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Datele de retenție sunt indisponibile până când statisticile de vizualizări+timp de vizionare sunt returnate de Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostice';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total videoclipuri: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Cu vizualizări: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Fără vizualizări: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hidratate (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hidratate (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Surse: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Folosește date de test';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Creează un cont Divine nou';

  @override
  String get authSignInDifferentAccount => 'Autentifică-te cu un alt cont';

  @override
  String get authSignBackIn => 'Reautentifică-te';

  @override
  String get authTermsPrefix =>
      'Selecționând o opțiune de mai sus, confirmi că ai cel puțin 16 ani și ești de acord cu ';

  @override
  String get authTermsOfService => 'Termenii serviciului';

  @override
  String get authPrivacyPolicy => 'Politica de confidențialitate';

  @override
  String get authTermsAnd => ', și ';

  @override
  String get authSafetyStandards => 'Standardele de siguranță';

  @override
  String get authAmberNotInstalled => 'Aplicația Amber nu e instalată';

  @override
  String get authAmberConnectionFailed => 'N-am putut conecta cu Amber';

  @override
  String get authPasswordResetSent =>
      'Dacă există un cont cu acel email, am trimis un link de resetare a parolei.';

  @override
  String get authSignInTitle => 'Autentificare';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Parolă';

  @override
  String get authConfirmPasswordLabel => 'Confirmă parola';

  @override
  String get authEmailRequired => 'Emailul este obligatoriu';

  @override
  String get authEmailInvalid => 'Introdu o adresă de email validă';

  @override
  String get authPasswordRequired => 'Parola este obligatorie';

  @override
  String get authConfirmPasswordRequired => 'Confirmă parola';

  @override
  String get authPasswordsDoNotMatch => 'Parolele nu se potrivesc';

  @override
  String get authForgotPassword => 'Ai uitat parola?';

  @override
  String get authImportNostrKey => 'Importă cheia Nostr';

  @override
  String get authConnectSignerApp => 'Conectează o aplicație de semnare';

  @override
  String get authSignInWithAmber => 'Autentifică-te cu Amber';

  @override
  String get authSignInOptionsTitle => 'Opțiuni de autentificare';

  @override
  String get authInfoEmailPasswordTitle => 'Email și parolă';

  @override
  String get authInfoEmailPasswordDescription =>
      'Autentifică-te cu contul tău Divine. Dacă te-ai înregistrat cu email și parolă, folosește-le aici.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Ai deja o identitate Nostr? Importă cheia ta privată nsec dintr-un alt client.';

  @override
  String get authInfoSignerAppTitle => 'Aplicație de semnare';

  @override
  String get authInfoSignerAppDescription =>
      'Conectează-te cu un semnatar la distanță compatibil NIP-46 cum ar fi nsecBunker pentru securitate sporită a cheilor.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Folosește aplicația de semnare Amber pe Android ca să gestionezi cheile tale Nostr în siguranță.';

  @override
  String get authCreateAccountTitle => 'Creează cont';

  @override
  String get authBackToInviteCode => 'Înapoi la codul de invitație';

  @override
  String get authUseDivineNoBackup => 'Folosește Divine fără backup';

  @override
  String get authSkipConfirmTitle => 'Un ultim lucru...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Ești înăuntru! Creăm o cheie sigură care va alimenta contul tău Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Fără email, cheia ta e singurul mod prin care Divine știe că acest cont e al tău.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Poți accesa cheia în aplicație, dar, dacă nu ești tehnic, recomandăm să adaugi un email și o parolă acum. Face mai ușoară autentificarea și restabilirea contului dacă pierzi sau resetezi dispozitivul.';

  @override
  String get authAddEmailPassword => 'Adaugă email și parolă';

  @override
  String get authUseThisDeviceOnly => 'Folosește doar acest dispozitiv';

  @override
  String get authCompleteRegistration => 'Finalizează-ți înregistrarea';

  @override
  String get authVerifying => 'Se verifică...';

  @override
  String get authVerificationLinkSent => 'Am trimis un link de verificare la:';

  @override
  String get authClickVerificationLink =>
      'Apasă linkul din email ca\nsă finalizezi înregistrarea.';

  @override
  String get authPleaseWaitVerifying =>
      'Te rugăm să aștepți cât âți verificăm emailul...';

  @override
  String get authWaitingForVerification => 'Se așteaptă verificarea';

  @override
  String get authOpenEmailApp => 'Deschide aplicația de email';

  @override
  String get authWelcomeToDivine => 'Bun venit pe Divine!';

  @override
  String get authEmailVerified => 'Emailul tău a fost verificat.';

  @override
  String get authSigningYouIn => 'Te autentificăm';

  @override
  String get authErrorTitle => 'Ups.';

  @override
  String get authVerificationFailed =>
      'N-am reușit să-ți verificăm emailul.\nÎncearcă din nou.';

  @override
  String get authStartOver => 'Începe din nou';

  @override
  String get authEmailVerifiedLogin =>
      'Email verificat! Autentifică-te ca să continui.';

  @override
  String get authVerificationLinkExpired =>
      'Acest link de verificare nu mai e valid.';

  @override
  String get authVerificationConnectionError =>
      'Nu am putut verifica emailul. Verifică-ți conexiunea și încearcă din nou.';

  @override
  String get authWaitlistConfirmTitle => 'Ești înăuntru!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Vom da noutăți la $email.\nCând apar mai multe coduri de invitație, ți le trimitem.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Accesul prin invitație e temporar indisponibil.';

  @override
  String get authInviteUnavailableBody =>
      'Încearcă din nou într-un moment, sau contactează asistența dacă ai nevoie de ajutor ca să intri.';

  @override
  String get authTryAgain => 'Încearcă din nou';

  @override
  String get authContactSupport => 'Contactează asistența';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'N-am putut deschide $email';
  }

  @override
  String get authAddInviteCode => 'Adaugă codul de invitație';

  @override
  String get authInviteCodeLabel => 'Cod de invitație';

  @override
  String get authEnterYourCode => 'Introdu codul tău';

  @override
  String get authNext => 'Mai departe';

  @override
  String get authJoinWaitlist => 'Alătură-te listei de așteptare';

  @override
  String get authJoinWaitlistTitle => 'Alătură-te listei de așteptare';

  @override
  String get authJoinWaitlistDescription =>
      'Dă-ne emailul tău și âți vom trimite noutăți pe măsură ce se deschide accesul.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Ajutor pentru accesul prin invitație';

  @override
  String get authGeneratingConnection => 'Se generează conexiunea...';

  @override
  String get authConnectedAuthenticating => 'Conectat! Se autentifică...';

  @override
  String get authConnectionTimedOut => 'Conexiunea a expirat';

  @override
  String get authApproveConnection =>
      'Asigură-te că ai aprobat conexiunea în aplicația ta de semnare.';

  @override
  String get authConnectionCancelled => 'Conexiune anulată';

  @override
  String get authConnectionCancelledMessage => 'Conexiunea a fost anulată.';

  @override
  String get authConnectionFailed => 'Conexiunea a eșuat';

  @override
  String get authUnknownError => 'A apărut o eroare necunoscută.';

  @override
  String get authUrlCopied => 'URL copiat în clipboard';

  @override
  String get authConnectToDivine => 'Conectează-te la Divine';

  @override
  String get authPasteBunkerUrl => 'Lipește URL-ul bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker invalid. Ar trebui să înceapă cu bunker://';

  @override
  String get authScanSignerApp =>
      'Scanează cu aplicația ta\nde semnare ca să te conectezi.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Se așteaptă conexiunea... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copiază URL-ul';

  @override
  String get authShare => 'Partajează';

  @override
  String get authAddBunker => 'Adaugă bunker';

  @override
  String get authCompatibleSignerApps => 'Aplicații de semnare compatibile';

  @override
  String get authFailedToConnect => 'N-am putut conecta';

  @override
  String get authResetPasswordTitle => 'Resetează parola';

  @override
  String get authResetPasswordSubtitle =>
      'Introdu parola nouă. Trebuie să aibă cel puțin 8 caractere.';

  @override
  String get authNewPasswordLabel => 'Parolă nouă';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmă noua parolă';

  @override
  String get authPasswordTooShort =>
      'Parola trebuie să aibă cel puțin 8 caractere';

  @override
  String get authPasswordResetSuccess =>
      'Parola a fost resetată cu succes. Autentifică-te.';

  @override
  String get authPasswordResetFailed => 'Resetarea parolei a eșuat';

  @override
  String get authUnexpectedError =>
      'A apărut o eroare neașteptată. Încearcă din nou.';

  @override
  String get authUpdatePassword => 'Actualizează parola';

  @override
  String get authSecureAccountTitle => 'Securizează contul';

  @override
  String get authUnableToAccessKeys =>
      'Nu am putut accesa cheile tale. Încearcă din nou.';

  @override
  String get authRegistrationFailed => 'Înscrierea a eșuat';

  @override
  String get authRegistrationComplete =>
      'Înscriere finalizată. Verifică-ți emailul.';

  @override
  String get authVerificationFailedTitle => 'Verificare eșuată';

  @override
  String get authClose => 'Închide';

  @override
  String get authAccountSecured => 'Cont securizat!';

  @override
  String get authAccountLinkedToEmail =>
      'Contul tău e acum legat de emailul tău.';

  @override
  String get authVerifyYourEmail => 'Verifică-ți emailul';

  @override
  String get authClickLinkContinue =>
      'Apasă linkul din email ca să finalizezi înregistrarea. Poți continua să folosești aplicația între timp.';

  @override
  String get authWaitingForVerificationEllipsis => 'Se așteaptă verificarea...';

  @override
  String get authContinueToApp => 'Continuă în aplicație';

  @override
  String get authResetPassword => 'Resetează parola';

  @override
  String get authResetPasswordDescription =>
      'Introdu adresa ta de email și âți trimitem un link de resetare a parolei.';

  @override
  String get authFailedToSendResetEmail =>
      'N-am putut trimite emailul de resetare.';

  @override
  String get authUnexpectedErrorShort => 'A apărut o eroare neașteptată.';

  @override
  String get authSending => 'Se trimite...';

  @override
  String get authSendResetLink => 'Trimite linkul de resetare';

  @override
  String get authEmailSent => 'Email trimis!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Am trimis un link de resetare a parolei la $email. Apasă linkul din email ca să-ți actualizezi parola.';
  }

  @override
  String get authSignInButton => 'Autentificare';

  @override
  String get authVerificationErrorTimeout =>
      'Verificarea a expirat. Încearcă să te înregistrezi din nou.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verificare eșuată — cod de autorizare lipsă.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verificare eșuată. Încearcă din nou.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Eroare de rețea la autentificare. Încearcă din nou.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verificare eșuată. Încearcă să te înregistrezi din nou.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Autentificarea a eșuat. Încearcă să te conectezi manual.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Acest cod de invitație nu mai e disponibil. Întoarce-te la codul tău, alătură-te listei de așteptare sau contactează asistența.';

  @override
  String get authInviteErrorInvalid =>
      'Acest cod de invitație nu poate fi folosit acum. Întoarce-te la codul tău, alătură-te listei de așteptare sau contactează asistența.';

  @override
  String get authInviteErrorTemporary =>
      'N-am putut confirma invitația ta acum. Întoarce-te la codul tău și încearcă din nou, sau contactează asistența.';

  @override
  String get authInviteErrorUnknown =>
      'N-am putut activa invitația ta. Întoarce-te la codul tău, alătură-te listei de așteptare sau contactează asistența.';

  @override
  String get shareSheetSave => 'Salvează';

  @override
  String get shareSheetSaveToGallery => 'Salvează în galerie';

  @override
  String get shareSheetSaveWithWatermark => 'Salvează cu filigran';

  @override
  String get shareSheetSaveVideo => 'Salvează videoclipul';

  @override
  String get shareSheetAddToClips => 'Adaugă la clipuri';

  @override
  String get shareSheetAddedToClips => 'Adăugat la clipuri';

  @override
  String get shareSheetAddToClipsFailed => 'Nu s-a putut adăuga la clipuri';

  @override
  String get shareSheetAddToList => 'Adaugă la listă';

  @override
  String get shareSheetCopy => 'Copiază';

  @override
  String get shareSheetShareVia => 'Partajează prin';

  @override
  String get shareSheetReport => 'Raportează';

  @override
  String get shareSheetEventJson => 'JSON eveniment';

  @override
  String get shareSheetEventId => 'ID eveniment';

  @override
  String get shareSheetMoreActions => 'Mai multe acțiuni';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Salvat în galerie';

  @override
  String get watermarkDownloadShare => 'Partajează';

  @override
  String get watermarkDownloadDone => 'Gata';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'E nevoie de acces la Poze';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Pentru a salva videoclipuri, permite accesul la Poze în Setări.';

  @override
  String get watermarkDownloadOpenSettings => 'Deschide setările';

  @override
  String get watermarkDownloadNotNow => 'Nu acum';

  @override
  String get watermarkDownloadFailed => 'Descărcare eșuată';

  @override
  String get watermarkDownloadDismiss => 'Respinge';

  @override
  String get watermarkDownloadStageDownloading => 'Se descarcă videoclipul';

  @override
  String get watermarkDownloadStageWatermarking => 'Se adaugă filigranul';

  @override
  String get watermarkDownloadStageSaving => 'Se salvează în galerie';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Se aduce videoclipul din rețea...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Se aplică filigranul Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Se salvează videoclipul cu filigran în galeria ta...';

  @override
  String get uploadProgressVideoUpload => 'Încărcare videoclip';

  @override
  String get uploadProgressPause => 'Pauză';

  @override
  String get uploadProgressResume => 'Reia';

  @override
  String get uploadProgressGoBack => 'Înapoi';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Reîncearcă ($count rămase)';
  }

  @override
  String get uploadProgressDelete => 'Șterge';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'acum ${count}z';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'acum ${count}h';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'acum ${count}m';
  }

  @override
  String get uploadProgressJustNow => 'Chiar acum';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Se încarcă $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Pauză la $percent%';
  }

  @override
  String get badgeExplanationClose => 'Închide';

  @override
  String get badgeExplanationOriginalVineArchive => 'Arhivă Vine originală';

  @override
  String get badgeExplanationCameraProof => 'Dovadă de cameră';

  @override
  String get badgeExplanationAuthenticitySignals => 'Semnale de autenticitate';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Acest videoclip e un Vine original recuperat din Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Înainte ca Vine să se închidă în 2017, ArchiveTeam și Internet Archive au lucrat ca să păstreze milioane de Vine-uri pentru posteritate. Acest conținut face parte din acel efort istoric de conservare.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Statistici originale: $loops bucle';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Află mai multe despre conservarea arhivei Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'Află mai multe despre verificarea Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Află mai multe despre semnalele de autenticitate Divine';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspectează cu unealta ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Inspectează detaliile media';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Autenticitatea acestui videoclip e verificată cu tehnologia Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Acest videoclip e găzduit pe Divine și detecția AI indică că e probabil făcut de om, dar nu include date criptografice de verificare a camerei.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Detecția AI indică că acest videoclip e probabil făcut de om, deși nu include date criptografice de verificare a camerei.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Acest videoclip e găzduit pe Divine, dar încă nu include date criptografice de verificare a camerei.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Acest videoclip e găzduit în afara Divine și nu include date criptografice de verificare a camerei.';

  @override
  String get badgeExplanationDeviceAttestation => 'Atestare dispozitiv';

  @override
  String get badgeExplanationPgpSignature => 'Semnătură PGP';

  @override
  String get badgeExplanationC2paCredentials => 'Credentiale de conținut C2PA';

  @override
  String get badgeExplanationProofManifest => 'Manifest de dovezi';

  @override
  String get badgeExplanationAiDetection => 'Detecție AI';

  @override
  String get badgeExplanationAiNotScanned => 'Scanare AI: Încă nescanat';

  @override
  String get badgeExplanationNoScanResults =>
      'Încă nu sunt rezultate de scanare disponibile.';

  @override
  String get badgeExplanationCheckAiGenerated =>
      'Verifică dacă e generat de AI';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% probabilitate să fie generat de AI';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Scanat de: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verificat de un moderator uman';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platină: Atestare hardware de dispozitiv, semnături criptografice, credentiale de conținut (C2PA) și scanare AI confirmă originea umană.';

  @override
  String get badgeExplanationVerificationGold =>
      'Aur: Capturat pe un dispozitiv real cu atestare hardware, semnături criptografice și credentiale de conținut (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Argint: Semnăturile criptografice dovedesc că acest videoclip n-a fost modificat de la înregistrare.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronz: Sunt prezente semnături de metadate de bază.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Argint: Scanarea AI confirmă că acest videoclip e probabil creat de om.';

  @override
  String get badgeExplanationNoVerification =>
      'Nu sunt date de verificare disponibile pentru acest videoclip.';

  @override
  String get shareMenuTitle => 'Partajează videoclipul';

  @override
  String get shareMenuReportAiContent => 'Raportează conținut AI';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Raportează rapid conținut suspect de a fi generat de AI';

  @override
  String get shareMenuReportingAiContent => 'Se raportează conținutul AI...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'N-am putut raporta conținutul: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'N-am putut raporta conținutul AI: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Stare videoclip';

  @override
  String get shareMenuViewAllLists => 'Vezi toate listele →';

  @override
  String get shareMenuShareWith => 'Partajează cu';

  @override
  String get shareMenuShareViaOtherApps => 'Partajează prin alte aplicații';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Partajează prin alte aplicații sau copiază linkul';

  @override
  String get shareMenuSaveToGallery => 'Salvează în galerie';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Salvează videoclipul original în galerie';

  @override
  String get shareMenuSaveWithWatermark => 'Salvează cu filigran';

  @override
  String get shareMenuSaveVideo => 'Salvează videoclipul';

  @override
  String get shareMenuDownloadWithWatermark => 'Descarcă cu filigran Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Salvează videoclipul în galerie';

  @override
  String get shareMenuLists => 'Liste';

  @override
  String get shareMenuAddToList => 'Adaugă la listă';

  @override
  String get shareMenuAddToListSubtitle => 'Adaugă la listele tale curate';

  @override
  String get shareMenuCreateNewList => 'Creează o listă nouă';

  @override
  String get shareMenuCreateNewListSubtitle => 'Începe o nouă colecție curată';

  @override
  String get shareMenuRemovedFromList => 'Eliminat din listă';

  @override
  String get shareMenuFailedToRemoveFromList => 'N-am putut elimina din listă';

  @override
  String get shareMenuBookmarks => 'Semne de carte';

  @override
  String get shareMenuAddToBookmarks => 'Adaugă la semne de carte';

  @override
  String get shareMenuAddToBookmarksSubtitle =>
      'Salvează pentru vizualizare ulterioară';

  @override
  String get shareMenuAddToBookmarkSet => 'Adaugă la set de semne de carte';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organizează în colecții';

  @override
  String get shareMenuFollowSets => 'Seturi de urmărire';

  @override
  String get shareMenuCreateFollowSet => 'Creează un set de urmărire';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Începe o colecție nouă cu acest creator';

  @override
  String get shareMenuAddToFollowSet => 'Adaugă la setul de urmărire';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de seturi de urmărire disponibile',
      few: '$count seturi de urmărire disponibile',
      one: '1 set de urmărire disponibil',
    );
    return '$_temp0';
  }

  @override
  String get peopleListsAddToList => 'Adaugă la listă';

  @override
  String get peopleListsAddToListSubtitle =>
      'Pune acest creator în una dintre listele tale';

  @override
  String get peopleListsSheetTitle => 'Adaugă la listă';

  @override
  String get peopleListsEmptyTitle => 'Nicio listă încă';

  @override
  String get peopleListsEmptySubtitle =>
      'Creează o listă pentru a începe să grupezi persoane.';

  @override
  String get peopleListsCreateList => 'Creează listă';

  @override
  String get peopleListsNewListTitle => 'Listă nouă';

  @override
  String get peopleListsRouteTitle => 'Listă de persoane';

  @override
  String get peopleListsListNameLabel => 'Numele listei';

  @override
  String get peopleListsListNameHint => 'Prieteni apropiați';

  @override
  String get peopleListsCreateButton => 'Creează';

  @override
  String get peopleListsAddPeopleTitle => 'Adaugă persoane';

  @override
  String get peopleListsAddPeopleTooltip => 'Adaugă persoane';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Adaugă persoane la listă';

  @override
  String get peopleListsListNotFoundTitle => 'Lista nu a fost găsită';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista nu a fost găsită. Poate a fost ștearsă.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Această listă poate a fost ștearsă.';

  @override
  String get peopleListsNoPeopleTitle => 'Nicio persoană în această listă';

  @override
  String get peopleListsNoPeopleSubtitle => 'Adaugă persoane pentru a începe';

  @override
  String get peopleListsNoVideosTitle => 'Niciun videoclip încă';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videoclipurile membrilor listei vor apărea aici';

  @override
  String get peopleListsNoVideosAvailable => 'Niciun videoclip disponibil';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Încărcarea videoclipurilor a eșuat';

  @override
  String get peopleListsVideoNotAvailable => 'Videoclip indisponibil';

  @override
  String get peopleListsBackToGridTooltip => 'Înapoi la grilă';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Eroare la încărcarea videoclipurilor';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Nicio persoană disponibilă de adăugat.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Adaugă la $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Caută persoane';

  @override
  String get peopleListsAddPeopleError =>
      'Nu s-au putut încărca persoanele. Te rugăm să încerci din nou.';

  @override
  String get peopleListsAddPeopleRetry => 'Încearcă din nou';

  @override
  String get peopleListsAddButton => 'Adaugă';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Adaugă $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'În $count liste',
      few: 'În $count liste',
      one: 'Într-o listă',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Elimini $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Va fi eliminat/ă din această listă.';

  @override
  String get peopleListsRemove => 'Elimină';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name eliminat/ă din listă';
  }

  @override
  String get peopleListsUndo => 'Anulează';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profilul lui $name. Apasă lung pentru a elimina.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Vezi profilul lui $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Adăugat la semnele de carte!';

  @override
  String get shareMenuFailedToAddBookmark =>
      'N-am putut adăuga semnul de carte';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Lista \"$name\" creată și videoclipul adăugat';
  }

  @override
  String get shareMenuManageContent => 'Gestionează conținutul';

  @override
  String get shareMenuEditVideo => 'Editează videoclipul';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Actualizează titlul, descrierea și hashtagurile';

  @override
  String get shareMenuDeleteVideo => 'Șterge videoclipul';

  @override
  String get shareMenuDeleteVideoSubtitle => 'Elimină definitiv acest conținut';

  @override
  String get shareMenuDeleteWarning =>
      'Asta va trimite o cerere de ștergere (NIP-09) către toate relay-urile. Unele relay-uri pot păstra totuși conținutul.';

  @override
  String get shareMenuVideoInTheseLists => 'Videoclipul e în aceste liste:';

  @override
  String shareMenuVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get shareMenuClose => 'Închide';

  @override
  String get shareMenuDeleteConfirmation =>
      'Sigur vrei să ștergi acest videoclip?';

  @override
  String get shareMenuCancel => 'Anulează';

  @override
  String get shareMenuDelete => 'Șterge';

  @override
  String get shareMenuDeletingContent => 'Se șterge conținutul...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'N-am putut șterge conținutul: $error';
  }

  @override
  String get shareMenuDeleteRequestSent =>
      'Cererea de ștergere a fost trimisă cu succes';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Ștergerea nu e încă gata. Încearcă din nou peste un moment.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Poți șterge doar propriile videoclipuri.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Autentifică-te din nou, apoi încearcă să ștergi.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Nu am putut semna cererea de ștergere. Încearcă din nou.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Nu am putut șterge acest videoclip. Încearcă din nou.';

  @override
  String get shareMenuFollowSetName => 'Numele setului de urmărire';

  @override
  String get shareMenuFollowSetNameHint =>
      'ex. Creatori de conținut, Muzicieni etc.';

  @override
  String get shareMenuDescriptionOptional => 'Descriere (opțional)';

  @override
  String get shareMenuCreate => 'Creează';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Set de urmărire \"$name\" creat și creatorul adăugat';
  }

  @override
  String get shareMenuDone => 'Gata';

  @override
  String get shareMenuEditTitle => 'Titlu';

  @override
  String get shareMenuEditTitleHint => 'Introdu titlul videoclipului';

  @override
  String get shareMenuEditDescription => 'Descriere';

  @override
  String get shareMenuEditDescriptionHint => 'Introdu descrierea videoclipului';

  @override
  String get shareMenuEditHashtags => 'Hashtaguri';

  @override
  String get shareMenuEditHashtagsHint => 'hashtaguri, separate, prin virgulă';

  @override
  String get shareMenuEditMetadataNote =>
      'Notă: Doar metadatele pot fi editate. Conținutul video nu poate fi schimbat.';

  @override
  String get shareMenuDeleting => 'Se șterge...';

  @override
  String get shareMenuUpdate => 'Actualizează';

  @override
  String get shareMenuVideoUpdated => 'Videoclip actualizat cu succes';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'N-am putut actualiza videoclipul: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'N-am putut șterge videoclipul: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Ștergi videoclipul?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Asta va trimite o cerere de ștergere către relay-uri. Notă: Unele relay-uri pot avea încă copii în cache.';

  @override
  String get shareMenuVideoDeletionRequested =>
      'Cerere de ștergere a videoclipului trimisă';

  @override
  String get shareMenuContentLabels => 'Etichete de conținut';

  @override
  String get shareMenuAddContentLabels => 'Adaugă etichete de conținut';

  @override
  String get shareMenuClearAll => 'Șterge tot';

  @override
  String get shareMenuCollaborators => 'Colaboratori';

  @override
  String get shareMenuAddCollaborator => 'Adaugă colaborator';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Trebuie să te urmărești reciproc cu $name ca să-l adaugi drept colaborator.';
  }

  @override
  String get shareMenuLoading => 'Se încarcă...';

  @override
  String get shareMenuInspiredBy => 'Inspirat de';

  @override
  String get shareMenuAddInspirationCredit => 'Adaugă credit pentru inspirație';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Acest creator nu poate fi referit.';

  @override
  String get shareMenuUnknown => 'Necunoscut';

  @override
  String get shareMenuCreateBookmarkSet => 'Creează un set de semne de carte';

  @override
  String get shareMenuSetName => 'Numele setului';

  @override
  String get shareMenuSetNameHint =>
      'ex. Preferate, De vizionat mai târziu etc.';

  @override
  String get shareMenuCreateNewSet => 'Creează un set nou';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Începe o colecție nouă de semne de carte';

  @override
  String get shareMenuNoBookmarkSets =>
      'Încă nu ai seturi de semne de carte. Creează-l pe primul!';

  @override
  String get shareMenuError => 'Eroare';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'N-am putut încărca seturile de semne de carte';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Set \"$name\" creat și videoclipul adăugat';
  }

  @override
  String get shareMenuUseThisSound => 'Folosește acest sunet';

  @override
  String get shareMenuOriginalSound => 'Sunet original';

  @override
  String get authSessionExpired =>
      'Sesiunea ta a expirat. Autentifică-te din nou.';

  @override
  String get authSignInFailed => 'N-am putut autentifica. Încearcă din nou.';

  @override
  String get localeAppLanguage => 'Limba aplicației';

  @override
  String get localeDeviceDefault => 'Implicit dispozitiv';

  @override
  String get localeSelectLanguage => 'Alege limba';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autentificarea web nu e suportată în modul sigur. Folosește aplicația mobilă pentru gestionarea sigură a cheilor.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Integrarea de autentificare a eșuat: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Eroare neașteptată: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Introdu un URI bunker';

  @override
  String get webAuthConnectTitle => 'Conectează-te la Divine';

  @override
  String get webAuthChooseMethod =>
      'Alege metoda ta preferată de autentificare Nostr';

  @override
  String get webAuthBrowserExtension => 'Extensie de browser';

  @override
  String get webAuthRecommended => 'RECOMANDAT';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner =>
      'Conectează-te la un semnatar la distanță';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Lipește din clipboard';

  @override
  String get webAuthConnectToBunker => 'Conectează-te la Bunker';

  @override
  String get webAuthNewToNostr => 'Ești nou pe Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Instalează o extensie de browser ca Alby sau nos2x pentru cea mai ușoară experiență, sau folosește nsec bunker pentru semnare la distanță sigură.';

  @override
  String get soundsTitle => 'Sunete';

  @override
  String get soundsSearchHint => 'Caută sunete...';

  @override
  String get soundsPreviewUnavailable =>
      'Nu pot previzualiza sunetul - niciun audio disponibil';

  @override
  String soundsPreviewFailed(String error) {
    return 'N-am putut reda previzualizarea: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Sunete recomandate';

  @override
  String get soundsTrendingSounds => 'Sunete în trend';

  @override
  String get soundsAllSounds => 'Toate sunetele';

  @override
  String get soundsSearchResults => 'Rezultatele căutării';

  @override
  String get soundsNoSoundsAvailable => 'Niciun sunet disponibil';

  @override
  String get soundsNoSoundsDescription =>
      'Sunetele vor apărea aici când creatorii distribuie audio';

  @override
  String get soundsNoSoundsFound => 'Niciun sunet găsit';

  @override
  String get soundsNoSoundsFoundDescription => 'Încearcă alt termen de căutare';

  @override
  String get soundsFailedToLoad => 'N-am putut încărca sunetele';

  @override
  String get soundsRetry => 'Reîncearcă';

  @override
  String get soundsScreenLabel => 'Ecranul sunetelor';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Reîncarcă';

  @override
  String get profileRefreshLabel => 'Reîncarcă profilul';

  @override
  String get profileMoreOptions => 'Mai multe opțiuni';

  @override
  String profileBlockedUser(String name) {
    return 'L-ai blocat pe $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'L-ai deblocat pe $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Nu-l mai urmărești pe $name';
  }

  @override
  String profileError(String error) {
    return 'Eroare: $error';
  }

  @override
  String get notificationsTabAll => 'Toate';

  @override
  String get notificationsTabLikes => 'Aprecieri';

  @override
  String get notificationsTabComments => 'Comentarii';

  @override
  String get notificationsTabFollows => 'Urmăriri';

  @override
  String get notificationsTabReposts => 'Redistribuiri';

  @override
  String get notificationsFailedToLoad => 'N-am putut încărca notificările';

  @override
  String get notificationsRetry => 'Reîncearcă';

  @override
  String get notificationsCheckingNew => 'se verifică notificări noi';

  @override
  String get notificationsNoneYet => 'Încă nicio notificare';

  @override
  String notificationsNoneForType(String type) {
    return 'Nicio notificare de tip $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Când oamenii interacționează cu conținutul tău, vei vedea asta aici';

  @override
  String get notificationsUnreadPrefix => 'Notificare necitită';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Vezi profilul $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Vezi profilurile';

  @override
  String notificationsLoadingType(String type) {
    return 'Se încarcă notificările de tip $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'Ai 1 invitație de împărțit cu un prieten!';

  @override
  String notificationsInvitePlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de invitații',
      few: '$count invitații',
      one: '1 invitație',
    );
    return 'Ai $_temp0 de împărțit cu prietenii!';
  }

  @override
  String get notificationsVideoNotFound => 'Videoclipul n-a fost găsit';

  @override
  String get notificationsVideoUnavailable => 'Videoclip indisponibil';

  @override
  String get notificationsFromNotification => 'Din notificare';

  @override
  String get feedFailedToLoadVideos => 'N-am putut încărca videoclipurile';

  @override
  String get feedRetry => 'Reîncearcă';

  @override
  String get feedNoFollowedUsers =>
      'Niciun utilizator urmărit.\nUrmărește pe cineva ca să-i vezi videoclipurile aici.';

  @override
  String get feedForYouEmpty =>
      'Feedul tău Pentru tine este gol.\nExplorează videoclipuri și urmărește creatori pentru a-l modela.';

  @override
  String get feedFollowingEmpty =>
      'Încă nu există videoclipuri de la persoanele pe care le urmărești.\nGăsește creatori care îți plac și urmărește-i.';

  @override
  String get feedLatestEmpty =>
      'Încă nu există videoclipuri noi.\nRevino curând.';

  @override
  String get feedExploreVideos => 'Explorează videoclipuri';

  @override
  String get feedExternalVideoSlow => 'Videoclipul extern se încarcă încet';

  @override
  String get feedSkip => 'Sari peste';

  @override
  String get uploadWaitingToUpload => 'Se așteaptă încărcarea';

  @override
  String get uploadUploadingVideo => 'Se încarcă videoclipul';

  @override
  String get uploadProcessingVideo => 'Se procesează videoclipul';

  @override
  String get uploadProcessingComplete => 'Procesare finalizată';

  @override
  String get uploadPublishedSuccessfully => 'Publicat cu succes';

  @override
  String get uploadFailed => 'Încărcare eșuată';

  @override
  String get uploadRetrying => 'Se reîncearcă încărcarea';

  @override
  String get uploadPaused => 'Încărcare în pauză';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% finalizat';
  }

  @override
  String get uploadQueuedMessage =>
      'Videoclipul tău e în așteptare pentru încărcare';

  @override
  String get uploadUploadingMessage => 'Se încarcă pe server...';

  @override
  String get uploadProcessingMessage =>
      'Se procesează videoclipul - poate dura câteva minute';

  @override
  String get uploadReadyToPublishMessage =>
      'Videoclip procesat cu succes și gata de publicare';

  @override
  String get uploadPublishedMessage => 'Videoclip publicat pe profilul tău';

  @override
  String get uploadFailedMessage => 'Încărcarea a eșuat - încearcă din nou';

  @override
  String get uploadRetryingMessage => 'Se reîncearcă încărcarea...';

  @override
  String get uploadPausedMessage => 'Încărcare oprită de utilizator';

  @override
  String get uploadRetryButton => 'REÎNCEARCĂ';

  @override
  String uploadRetryFailed(String error) {
    return 'N-am putut reîncerca încărcarea: $error';
  }

  @override
  String get userSearchPrompt => 'Caută utilizatori';

  @override
  String get userSearchNoResults => 'Niciun utilizator găsit';

  @override
  String get userSearchFailed => 'Căutarea a eșuat';

  @override
  String get userPickerSearchByName => 'Caută după nume';

  @override
  String get userPickerFilterByNameHint => 'Filtrează după nume...';

  @override
  String get userPickerSearchByNameHint => 'Caută după nume...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name este deja adăugat';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Selectează $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Gașca ta e acolo';

  @override
  String get userPickerEmptyFollowListBody =>
      'Urmărește oameni cu care rezonezi. Când vă urmăriți reciproc, puteți colabora.';

  @override
  String get userPickerGoBack => 'Înapoi';

  @override
  String get userPickerTypeNameToSearch => 'Scrie un nume pentru a căuta';

  @override
  String get userPickerUnavailable =>
      'Căutarea utilizatorilor nu este disponibilă. Te rugăm să încerci din nou mai târziu.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Căutarea a eșuat. Încearcă din nou.';

  @override
  String get forgotPasswordTitle => 'Resetează parola';

  @override
  String get forgotPasswordDescription =>
      'Introdu adresa ta de email și âți trimitem un link de resetare a parolei.';

  @override
  String get forgotPasswordEmailLabel => 'Adresă de email';

  @override
  String get forgotPasswordCancel => 'Anulează';

  @override
  String get forgotPasswordSendLink => 'Trimite linkul de resetare';

  @override
  String get ageVerificationContentWarning => 'Atenționare de conținut';

  @override
  String get ageVerificationTitle => 'Verificare vârstă';

  @override
  String get ageVerificationAdultDescription =>
      'Acest conținut a fost marcat ca putând conține material pentru adulți. Trebuie să ai 18 ani sau mai mult ca să-l vezi.';

  @override
  String get ageVerificationCreationDescription =>
      'Ca să folosești camera și să creezi conținut, trebuie să ai cel puțin 16 ani.';

  @override
  String get ageVerificationAdultQuestion => 'Ai 18 ani sau mai mult?';

  @override
  String get ageVerificationCreationQuestion => 'Ai 16 ani sau mai mult?';

  @override
  String get ageVerificationNo => 'Nu';

  @override
  String get ageVerificationYes => 'Da';

  @override
  String get shareLinkCopied => 'Link copiat în clipboard';

  @override
  String get shareFailedToCopy => 'N-am putut copia linkul';

  @override
  String get shareVideoSubject => 'Vezi acest videoclip pe Divine';

  @override
  String get shareFailedToShare => 'N-am putut partaja';

  @override
  String get shareVideoTitle => 'Partajează videoclipul';

  @override
  String get shareToApps => 'Partajează în aplicații';

  @override
  String get shareToAppsSubtitle =>
      'Partajează prin aplicații de mesagerie sau sociale';

  @override
  String get shareCopyWebLink => 'Copiază linkul web';

  @override
  String get shareCopyWebLinkSubtitle => 'Copiază un link web de partajat';

  @override
  String get shareCopyNostrLink => 'Copiază linkul Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Copiază linkul nevent pentru clienții Nostr';

  @override
  String get navHome => 'Acasă';

  @override
  String get navExplore => 'Explorează';

  @override
  String get navInbox => 'Mesaje';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSearch => 'Caută';

  @override
  String get navSearchTooltip => 'Caută';

  @override
  String get navMyProfile => 'Profilul meu';

  @override
  String get navNotifications => 'Notificări';

  @override
  String get navOpenCamera => 'Deschide camera';

  @override
  String get navUnknown => 'Necunoscut';

  @override
  String get navExploreClassics => 'Clasice';

  @override
  String get navExploreNewVideos => 'Videoclipuri noi';

  @override
  String get navExploreTrending => 'În trend';

  @override
  String get navExploreForYou => 'Pentru tine';

  @override
  String get navExploreLists => 'Liste';

  @override
  String get routeErrorTitle => 'Eroare';

  @override
  String get routeInvalidHashtag => 'Hashtag invalid';

  @override
  String get routeInvalidConversationId => 'ID de conversație invalid';

  @override
  String get routeInvalidRequestId => 'ID de cerere invalid';

  @override
  String get routeInvalidListId => 'ID de listă invalid';

  @override
  String get routeInvalidUserId => 'ID de utilizator invalid';

  @override
  String get routeInvalidVideoId => 'ID de videoclip invalid';

  @override
  String get routeInvalidSoundId => 'ID de sunet invalid';

  @override
  String get routeInvalidCategory => 'Categorie invalidă';

  @override
  String get routeNoVideosToDisplay => 'Niciun videoclip de afișat';

  @override
  String get routeInvalidProfileId => 'ID de profil invalid';

  @override
  String get routeDefaultListName => 'Listă';

  @override
  String get supportTitle => 'Centru de asistență';

  @override
  String get supportContactSupport => 'Contactează asistența';

  @override
  String get supportContactSupportSubtitle =>
      'Începe o conversație sau vezi mesajele trecute';

  @override
  String get supportReportBug => 'Raportează un bug';

  @override
  String get supportReportBugSubtitle => 'Probleme tehnice cu aplicația';

  @override
  String get supportRequestFeature => 'Cere o funcție';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sugerează o îmbunătățire sau o funcție nouă';

  @override
  String get supportSaveLogs => 'Salvează jurnalele';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportă jurnalele într-un fișier pentru trimitere manuală';

  @override
  String get supportFaq => 'Întrebări frecvente';

  @override
  String get supportFaqSubtitle => 'Întrebări și răspunsuri comune';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Află despre verificare și autenticitate';

  @override
  String get supportLoginRequired =>
      'Autentifică-te ca să contactezi asistența';

  @override
  String get supportExportingLogs => 'Se exportă jurnalele...';

  @override
  String get supportExportLogsFailed => 'N-am putut exporta jurnalele';

  @override
  String get supportChatNotAvailable => 'Chatul de asistență nu e disponibil';

  @override
  String get supportCouldNotOpenMessages =>
      'N-am putut deschide mesajele de asistență';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'N-am putut deschide $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Eroare la deschiderea $pageName: $error';
  }

  @override
  String get reportTitle => 'Raportează conținut';

  @override
  String get reportWhyReporting => 'De ce raportezi acest conținut?';

  @override
  String get reportPolicyNotice =>
      'Divine va acționa asupra rapoartelor de conținut în 24 de ore eliminând conținutul și excluțând utilizatorul care a furnizat conținutul ofensator.';

  @override
  String get reportAdditionalDetails => 'Detalii suplimentare (opțional)';

  @override
  String get reportBlockUser => 'Blochează acest utilizator';

  @override
  String get reportCancel => 'Anulează';

  @override
  String get reportSubmit => 'Raportează';

  @override
  String get reportSelectReason =>
      'Alege un motiv pentru raportarea acestui conținut';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Spam sau conținut nedorit';

  @override
  String get reportReasonHarassment => 'Hărțuire, bullying sau amenințări';

  @override
  String get reportReasonViolence => 'Conținut violent sau extremist';

  @override
  String get reportReasonSexualContent => 'Conținut sexual sau pentru adulți';

  @override
  String get reportReasonCopyright => 'Încălcarea dreptului de autor';

  @override
  String get reportReasonFalseInfo => 'Informații false';

  @override
  String get reportReasonCsam => 'Încălcarea siguranței copiilor';

  @override
  String get reportReasonAiGenerated => 'Conținut generat de AI';

  @override
  String get reportReasonOther => 'Altă încălcare a politicii';

  @override
  String reportFailed(Object error) {
    return 'N-am putut raporta conținutul: $error';
  }

  @override
  String get reportReceivedTitle => 'Raport primit';

  @override
  String get reportReceivedThankYou =>
      'Mersi că ne ajuți să păstrăm Divine în siguranță.';

  @override
  String get reportReceivedReviewNotice =>
      'Echipa noastră âți va revizui raportul și va lua măsuri corespunzătoare. S-ar putea să primești actualizări prin mesaj direct.';

  @override
  String get reportLearnMore => 'Află mai multe';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Închide';

  @override
  String get listAddToList => 'Adaugă la listă';

  @override
  String listVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
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
  String get listNewList => 'Listă nouă';

  @override
  String get listDone => 'Gata';

  @override
  String get listErrorLoading => 'Eroare la încărcarea listelor';

  @override
  String listRemovedFrom(String name) {
    return 'Eliminat din $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Adăugat la $name';
  }

  @override
  String get listCreateNewList => 'Creează o listă nouă';

  @override
  String get listNewPeopleList => 'Listă nouă de persoane';

  @override
  String get listCollaboratorsNone => 'Niciunul';

  @override
  String get listAddCollaboratorTitle => 'Adaugă un colaborator';

  @override
  String get listCollaboratorSearchHint => 'Caută în diVine...';

  @override
  String get listNameLabel => 'Numele listei';

  @override
  String get listDescriptionLabel => 'Descriere (opțional)';

  @override
  String get listPublicList => 'Listă publică';

  @override
  String get listPublicListSubtitle =>
      'Alții pot urmări și vedea această listă';

  @override
  String get listCancel => 'Anulează';

  @override
  String get listCreate => 'Creează';

  @override
  String get listCreateFailed => 'N-am putut crea lista';

  @override
  String get keyManagementTitle => 'Chei Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Ce sunt cheile Nostr?';

  @override
  String get keyManagementExplanation =>
      'Identitatea ta Nostr e o pereche de chei criptografice:\n\n• Cheia publică (npub) e ca numele tău de utilizator - distribuie-o liber\n• Cheia privată (nsec) e ca parola ta - păstreaz-o secretă!\n\nNsec-ul âți permite să accesezi contul pe orice aplicație Nostr.';

  @override
  String get keyManagementImportTitle => 'Importă cheie existentă';

  @override
  String get keyManagementImportSubtitle =>
      'Ai deja un cont Nostr? Lipește cheia privată (nsec) ca să-l accesezi aici.';

  @override
  String get keyManagementImportButton => 'Importă cheia';

  @override
  String get keyManagementImportWarning => 'Asta âți va înlocui cheia curentă!';

  @override
  String get keyManagementBackupTitle => 'Fă backup la cheia ta';

  @override
  String get keyManagementBackupSubtitle =>
      'Salvează cheia privată (nsec) ca să-ți folosești contul în alte aplicații Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copiază cheia mea privată (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Nu împărți niciodată nsec-ul cu nimeni!';

  @override
  String get keyManagementPasteKey => 'Lipește cheia ta privată';

  @override
  String get keyManagementInvalidFormat =>
      'Format de cheie invalid. Trebuie să înceapă cu \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importăm această cheie?';

  @override
  String get keyManagementConfirmImportBody =>
      'Asta âți va înlocui identitatea curentă cu cea importată.\n\nCheia ta curentă va fi pierdută dacă n-ai făcut backup mai întâi.';

  @override
  String get keyManagementImportConfirm => 'Importă';

  @override
  String get keyManagementImportSuccess => 'Cheie importată cu succes!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'N-am putut importa cheia: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Cheia privată a fost copiată în clipboard!\n\nȚine-o într-un loc sigur.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'N-am putut exporta cheia: $error';
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
  String get saveOriginalSavedToCameraRoll => 'Salvat în galerie';

  @override
  String get saveOriginalShare => 'Partajează';

  @override
  String get saveOriginalDone => 'Gata';

  @override
  String get saveOriginalPhotosAccessNeeded => 'E nevoie de acces la Poze';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Pentru a salva videoclipuri, permite accesul la Poze în Setări.';

  @override
  String get saveOriginalOpenSettings => 'Deschide setările';

  @override
  String get saveOriginalNotNow => 'Nu acum';

  @override
  String get cameraPermissionNotNow => 'Nu acum';

  @override
  String get saveOriginalDownloadFailed => 'Descărcare eșuată';

  @override
  String get saveOriginalDismiss => 'Respinge';

  @override
  String get saveOriginalDownloadingVideo => 'Se descarcă videoclipul';

  @override
  String get saveOriginalSavingToCameraRoll => 'Se salvează în galerie';

  @override
  String get saveOriginalFetchingVideo => 'Se aduce videoclipul din rețea...';

  @override
  String get saveOriginalSavingVideo =>
      'Se salvează videoclipul original în galeria ta...';

  @override
  String get soundTitle => 'Sunet';

  @override
  String get soundOriginalSound => 'Sunet original';

  @override
  String get soundVideosUsingThisSound =>
      'Videoclipuri care folosesc acest sunet';

  @override
  String get soundSourceVideo => 'Videoclip sursă';

  @override
  String get soundNoVideosYet => 'Încă niciun videoclip';

  @override
  String get soundBeFirstToUse => 'Fii primul care folosește acest sunet!';

  @override
  String get soundFailedToLoadVideos => 'N-am putut încărca videoclipurile';

  @override
  String get soundRetry => 'Reîncearcă';

  @override
  String get soundVideosUnavailable => 'Videoclipuri indisponibile';

  @override
  String get soundCouldNotLoadDetails =>
      'N-am putut încărca detaliile videoclipului';

  @override
  String get soundPreview => 'Previzualizare';

  @override
  String get soundStop => 'Oprește';

  @override
  String get soundUseSound => 'Folosește sunetul';

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
  String get soundNoVideoCount => 'Încă niciun videoclip';

  @override
  String get soundOneVideo => '1 videoclip';

  @override
  String soundVideoCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count de videoclipuri',
      few: '$count videoclipuri',
      one: '1 videoclip',
    );
    return '$_temp0';
  }

  @override
  String get soundUnableToPreview =>
      'Nu pot previzualiza sunetul - niciun audio disponibil';

  @override
  String soundPreviewFailed(Object error) {
    return 'N-am putut reda previzualizarea: $error';
  }

  @override
  String get soundViewSource => 'Vezi sursa';

  @override
  String get soundCloseTooltip => 'Închide';

  @override
  String get exploreNotExploreRoute => 'Nu e o rută de explorare';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Termenii serviciului';

  @override
  String get legalTermsOfServiceSubtitle => 'Termeni și condiții de utilizare';

  @override
  String get legalPrivacyPolicy => 'Politica de confidențialitate';

  @override
  String get legalPrivacyPolicySubtitle => 'Cum gestionăm datele tale';

  @override
  String get legalSafetyStandards => 'Standarde de siguranță';

  @override
  String get legalSafetyStandardsSubtitle => 'Ghiduri comunitare și siguranță';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle =>
      'Politica de drepturi de autor și de eliminare';

  @override
  String get legalOpenSourceLicenses => 'Licențe open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atribuiri pentru pachetele terțe';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'N-am putut deschide $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Eroare la deschiderea $pageName: $error';
  }

  @override
  String get categoryAction => 'Acțiune';

  @override
  String get categoryAdventure => 'Aventură';

  @override
  String get categoryAnimals => 'Animale';

  @override
  String get categoryAnimation => 'Animație';

  @override
  String get categoryArchitecture => 'Arhitectură';

  @override
  String get categoryArt => 'Artă';

  @override
  String get categoryAutomotive => 'Auto';

  @override
  String get categoryAwardShow => 'Gală de premii';

  @override
  String get categoryAwards => 'Premii';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Baschet';

  @override
  String get categoryBeauty => 'Frumusețe';

  @override
  String get categoryBeverage => 'Băuturi';

  @override
  String get categoryCars => 'Mașini';

  @override
  String get categoryCelebration => 'Sărbătoare';

  @override
  String get categoryCelebrities => 'Vedete';

  @override
  String get categoryCelebrity => 'Vedetă';

  @override
  String get categoryCityscape => 'Peisaj urban';

  @override
  String get categoryComedy => 'Comedie';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Gătit';

  @override
  String get categoryCostume => 'Costum';

  @override
  String get categoryCrafts => 'Meșteșuguri';

  @override
  String get categoryCrime => 'Crimă';

  @override
  String get categoryCulture => 'Cultură';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Dramă';

  @override
  String get categoryEducation => 'Educație';

  @override
  String get categoryEmotional => 'Emoțional';

  @override
  String get categoryEmotions => 'Emoții';

  @override
  String get categoryEntertainment => 'Divertisment';

  @override
  String get categoryEvent => 'Eveniment';

  @override
  String get categoryFamily => 'Familie';

  @override
  String get categoryFans => 'Fani';

  @override
  String get categoryFantasy => 'Fantastic';

  @override
  String get categoryFashion => 'Modă';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Mâncare';

  @override
  String get categoryFootball => 'Fotbal american';

  @override
  String get categoryFurniture => 'Mobilier';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Îngrijire';

  @override
  String get categoryGuitar => 'Chitară';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Sănătate';

  @override
  String get categoryHockey => 'Hochei';

  @override
  String get categoryHoliday => 'Vacanță';

  @override
  String get categoryHome => 'Acasă';

  @override
  String get categoryHomeImprovement => 'Renovări';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Spital';

  @override
  String get categoryHumor => 'Umor';

  @override
  String get categoryInteriorDesign => 'Design interior';

  @override
  String get categoryInterview => 'Interviu';

  @override
  String get categoryKids => 'Copii';

  @override
  String get categoryLifestyle => 'Stil de viață';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Machiaj';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryMusic => 'Muzică';

  @override
  String get categoryMystery => 'Mister';

  @override
  String get categoryNature => 'Natură';

  @override
  String get categoryNews => 'Știri';

  @override
  String get categoryOutdoor => 'În aer liber';

  @override
  String get categoryParty => 'Petrecere';

  @override
  String get categoryPeople => 'Oameni';

  @override
  String get categoryPerformance => 'Spectacol';

  @override
  String get categoryPets => 'Animale de companie';

  @override
  String get categoryPolitics => 'Politică';

  @override
  String get categoryPrank => 'Farsă';

  @override
  String get categoryPranks => 'Farse';

  @override
  String get categoryRealityShow => 'Reality show';

  @override
  String get categoryRelationship => 'Relație';

  @override
  String get categoryRelationships => 'Relații';

  @override
  String get categoryRomance => 'Romantic';

  @override
  String get categorySchool => 'Școală';

  @override
  String get categoryScienceFiction => 'Science-fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Cumpărături';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Îngrijirea pielii';

  @override
  String get categorySoccer => 'Fotbal';

  @override
  String get categorySocialGathering => 'Reuniune';

  @override
  String get categorySocialMedia => 'Social media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Tehnologie';

  @override
  String get categoryTelevision => 'Televiziune';

  @override
  String get categoryToys => 'Jucării';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Călătorii';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Violență';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadSuccess =>
      'Fotografia de profil a fost încărcată cu succes!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName a fost raportat(ă)';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName a fost blocat(ă)';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName a fost deblocat(ă)';
  }

  @override
  String get inboxRemovedConversation => 'Conversație eliminată';

  @override
  String get inboxEmptyTitle => 'Încă niciun mesaj';

  @override
  String get inboxEmptySubtitle => 'Butonul + nu mușcă.';

  @override
  String get inboxActionMute => 'Dezactivează sunetul conversației';

  @override
  String inboxActionReport(String displayName) {
    return 'Raportează $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blochează $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Deblochează $displayName';
  }

  @override
  String get inboxActionRemove => 'Elimină conversația';

  @override
  String get inboxRemoveConfirmTitle => 'Elimini conversația?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Astfel, conversația ta cu $displayName va fi ștearsă. Această acțiune nu poate fi anulată.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Elimină';

  @override
  String get inboxConversationMuted => 'Conversație dezactivată';

  @override
  String get inboxConversationUnmuted => 'Conversație reactivată';

  @override
  String get inboxCollabInviteCardTitle => 'Invitație de colaborare';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role la această postare';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'Acceptă';

  @override
  String get inboxCollabInviteIgnoreButton => 'Ignoră';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Acceptată';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorată';

  @override
  String get inboxCollabInviteAcceptError =>
      'Nu s-a putut accepta. Încearcă din nou.';

  @override
  String get inboxCollabInviteSentStatus => 'Invitație trimisă';

  @override
  String get inboxConversationCollabInvitePreview => 'Invitație de colaborare';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Ai fost invitat(ă) să colaborezi la $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Ai fost invitat(ă) să colaborezi la un videoclip: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String get reportDialogCancel => 'Anulează';

  @override
  String get reportDialogReport => 'Raportează';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titlu: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String get exploreSearchHint => 'Search...';

  @override
  String categoryVideoCount(String count) {
    return '$count videos';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Nu s-a putut actualiza abonamentul: $error';
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
  String get commonRetry => 'Reîncearcă';

  @override
  String get commonNext => 'Următorul';

  @override
  String get commonDelete => 'Șterge';

  @override
  String get commonCancel => 'Anulează';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get videoMetadataTags => 'Etichete';

  @override
  String get videoMetadataExpiration => 'Expirare';

  @override
  String get videoMetadataExpirationNotExpire => 'Nu expiră';

  @override
  String get videoMetadataExpirationOneDay => '1 zi';

  @override
  String get videoMetadataExpirationOneWeek => '1 săptămână';

  @override
  String get videoMetadataExpirationOneMonth => '1 lună';

  @override
  String get videoMetadataExpirationOneYear => '1 an';

  @override
  String get videoMetadataExpirationOneDecade => '1 deceniu';

  @override
  String get videoMetadataContentWarnings => 'Avertismente de conținut';

  @override
  String get videoEditorStickers => 'Stickere';

  @override
  String get trendingTitle => 'În tendințe';

  @override
  String get proofmodeCheckAiGenerated => 'Verifică dacă este generat de AI';

  @override
  String get libraryDeleteConfirm => 'Șterge';

  @override
  String get libraryWebUnavailableHeadline =>
      'Biblioteca e în aplicația mobilă';

  @override
  String get libraryWebUnavailableDescription =>
      'Ciornele și clipurile sunt pe dispozitivul tău — deschide Divine pe telefon ca să le gestionezi.';

  @override
  String get libraryTabDrafts => 'Ciorne';

  @override
  String get libraryTabClips => 'Clipuri';

  @override
  String get librarySaveToCameraRollTooltip => 'Salvează în galerie';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Șterge clipurile selectate';

  @override
  String get libraryDeleteClipsTitle => 'Șterge clipurile';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# clipuri selectate',
      one: '# clip selectat',
    );
    return 'Ștergi $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Nu se poate anula. Fișierele video vor fi eliminate definitiv de pe dispozitiv.';

  @override
  String get libraryPreparingVideo => 'Se pregătește videoclipul...';

  @override
  String get libraryCreateVideo => 'Creează video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipuri',
      one: '1 clip',
    );
    return '$_temp0 salvate în $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount salvate, $failureCount eșuate';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permisiune refuzată pentru $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipuri șterse',
      one: '1 clip șters',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Nu s-au putut încărca ciornele';

  @override
  String get libraryCouldNotLoadClips => 'Nu s-au putut încărca clipurile';

  @override
  String get libraryOpenErrorDescription =>
      'Ceva nu a mers la deschiderea bibliotecii. Poți încerca din nou.';

  @override
  String get libraryNoDraftsYetTitle => 'Încă nu ai ciorne';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videoclipurile salvate ca ciornă apar aici';

  @override
  String get libraryNoClipsYetTitle => 'Încă nu ai clipuri';

  @override
  String get libraryNoClipsYetSubtitle => 'Clipurile înregistrate apar aici';

  @override
  String get libraryDraftDeletedSnackbar => 'Ciornă ștearsă';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Nu s-a putut șterge ciorna';

  @override
  String get libraryDraftActionPost => 'Publică';

  @override
  String get libraryDraftActionEdit => 'Editează';

  @override
  String get libraryDraftActionDelete => 'Șterge ciorna';

  @override
  String get libraryDeleteDraftTitle => 'Șterge ciorna';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Ștergi „$title”?';
  }

  @override
  String get libraryDeleteClipTitle => 'Șterge clipul';

  @override
  String get libraryDeleteClipMessage => 'Ștergi acest clip?';

  @override
  String get libraryClipSelectionTitle => 'Clipuri';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Au rămas ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Adaugă';

  @override
  String get libraryRecordVideo => 'Înregistrează un video';

  @override
  String get routerInvalidCreator => 'Creator invalid';

  @override
  String get routerInvalidHashtagRoute => 'Rută hashtag invalidă';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Nu s-au putut încărca videoclipurile';

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
      'Nu s-au putut încărca categoriile';

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
  String get notificationFollowBack => 'Urmărește înapoi';

  @override
  String get followingTitle => 'Following';

  @override
  String followingTitleForName(String displayName) {
    return '$displayName\'s Following';
  }

  @override
  String get followingFailedToLoadList =>
      'Nu s-a putut încărca lista de urmăriți';

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
      'Nu s-a putut încărca lista de urmăritori';

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
    return 'Nu s-au putut salva setările: $error';
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
      'Nu s-a putut actualiza setarea de crosspost';

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
  String get invitesTitle => 'Invită prieteni';

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
  String get searchSomethingWentWrong => 'Ceva nu a mers bine';

  @override
  String get searchTryAgain => 'Încearcă din nou';

  @override
  String get searchForLists => 'Caută liste';

  @override
  String get searchFindCuratedVideoLists =>
      'Găsește liste de videoclipuri selectate';

  @override
  String get searchEnterQuery => 'Introdu un termen de căutare';

  @override
  String get searchDiscoverSomethingInteresting => 'Descoperă ceva interesant';

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
  String get searchListsSectionHeader => 'Liste';

  @override
  String get searchListsLoadingLabel => 'Se încarcă rezultatele listelor';

  @override
  String get cameraAgeRestriction =>
      'Trebuie să ai cel puțin 16 ani pentru a crea conținut';

  @override
  String get featureRequestCancel => 'Anulează';

  @override
  String keyImportError(String error) {
    return 'Eroare: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker relay must use wss:// (ws:// is allowed only for localhost)';

  @override
  String get timeNow => 'acum';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}h';
  }

  @override
  String timeShortDays(int count) {
    return '${count}z';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}săpt';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}lu';
  }

  @override
  String timeShortYears(int count) {
    return '${count}a';
  }

  @override
  String get timeVerboseNow => 'Acum';

  @override
  String timeAgo(String time) {
    return 'acum $time';
  }

  @override
  String get timeToday => 'Astăzi';

  @override
  String get timeYesterday => 'Ieri';

  @override
  String get timeJustNow => 'chiar acum';

  @override
  String timeMinutesAgo(int count) {
    return 'acum ${count}min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'acum ${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'acum ${count}z';
  }

  @override
  String get draftTimeJustNow => 'Chiar acum';

  @override
  String get contentLabelNudity => 'Nuditate';

  @override
  String get contentLabelSexualContent => 'Conținut sexual';

  @override
  String get contentLabelPornography => 'Pornografie';

  @override
  String get contentLabelGraphicMedia => 'Conținut grafic';

  @override
  String get contentLabelViolence => 'Violență';

  @override
  String get contentLabelSelfHarm => 'Automutilare/Suicid';

  @override
  String get contentLabelDrugUse => 'Consum de droguri';

  @override
  String get contentLabelAlcohol => 'Alcool';

  @override
  String get contentLabelTobacco => 'Tutun/Fumat';

  @override
  String get contentLabelGambling => 'Jocuri de noroc';

  @override
  String get contentLabelProfanity => 'Limbaj vulgar';

  @override
  String get contentLabelHateSpeech => 'Discurs instigator la ură';

  @override
  String get contentLabelHarassment => 'Hărțuire';

  @override
  String get contentLabelFlashingLights => 'Lumini intermitente';

  @override
  String get contentLabelAiGenerated => 'Generat de AI';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Înșelăciune/Fraudă';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Înșelător';

  @override
  String get contentLabelSensitiveContent => 'Conținut sensibil';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName a apreciat videoclipul tău';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName a apreciat comentariul tău';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName a comentat la videoclipul tău';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName a început să te urmărească';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName te-a menționat';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName a redistribuit videoclipul tău';
  }

  @override
  String get notificationRepliedToYourComment => 'a răspuns la comentariul tău';

  @override
  String get notificationAndConnector => 'și';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'încă $count persoane',
      one: 'încă 1 persoană',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Ai o actualizare nouă';

  @override
  String get notificationSomeoneLikedYourVideo =>
      'Cineva a apreciat videoclipul tău';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get draftUntitled => 'Fără titlu';

  @override
  String get contentWarningNone => 'Niciunul';

  @override
  String get textBackgroundNone => 'Niciunul';

  @override
  String get textBackgroundSolid => 'Opac';

  @override
  String get textBackgroundHighlight => 'Evidențiere';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Stânga';

  @override
  String get textAlignRight => 'Dreapta';

  @override
  String get textAlignCenter => 'Centru';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Camera nu este încă acceptată pe web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Captura și înregistrarea cu camera nu sunt încă disponibile în versiunea web.';

  @override
  String get cameraPermissionBackToFeed => 'Înapoi la feed';

  @override
  String get cameraPermissionErrorTitle => 'Eroare de permisiuni';

  @override
  String get cameraPermissionErrorDescription =>
      'A apărut o eroare la verificarea permisiunilor.';

  @override
  String get cameraPermissionRetry => 'Încearcă din nou';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Permite accesul la cameră și microfon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Aceasta îți permite să capturezi și să editezi videoclipuri direct în aplicație, nimic mai mult.';

  @override
  String get cameraPermissionContinue => 'Continuă';

  @override
  String get cameraPermissionGoToSettings => 'Mergi la setări';

  @override
  String get videoRecorderWhySixSecondsTitle => 'De ce șase secunde?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Clipurile scurte lasă loc pentru spontaneitate. Formatul de 6 secunde te ajută să surprinzi momente autentice exact când se întâmplă.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Am înțeles!';

  @override
  String get videoRecorderUploadTitle => 'De ce fără upload?';

  @override
  String get videoRecorderUploadBody =>
      'Ceea ce vezi pe Divine este făcut de oameni: brut și capturat în moment. Spre deosebire de platformele care permit upload-uri puternic produse sau generate de IA, prioritizăm autenticitatea experienței directe din cameră.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Păstrând crearea în aplicație, putem garanta mai bine că conținutul este real și needitat. Nu deschidem upload-uri din galeria externă în acest moment pentru a proteja acea autenticitate și a menține comunitatea noastră liberă de conținut sintetic pe cât posibil.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Treci la Capture sau Classic ca să filmezi ceva real.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Află cum funcționează verificarea';

  @override
  String get videoRecorderAutosaveFoundTitle => 'Am găsit lucru în desfășurare';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Vrei să continui de unde ai rămas?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Da, continuă';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Nu, începe un videoclip nou';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Nu am putut restaura schița ta';

  @override
  String get videoRecorderStopRecordingTooltip => 'Oprește înregistrarea';

  @override
  String get videoRecorderStartRecordingTooltip => 'Începe înregistrarea';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Înregistrare în curs. Atinge oriunde pentru a opri';

  @override
  String get videoRecorderTapToStartLabel =>
      'Atinge oriunde pentru a începe înregistrarea';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Șterge ultimul clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Schimbă camera';

  @override
  String get videoRecorderToggleGridLabel => 'Activează/dezactivează grila';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Activează/dezactivează cadrul fantomă';

  @override
  String get videoRecorderGhostFrameEnabled => 'Cadru fantomă activat';

  @override
  String get videoRecorderGhostFrameDisabled => 'Cadru fantomă dezactivat';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip șters';

  @override
  String get videoRecorderCloseLabel => 'Închide înregistratorul video';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuă către editorul video';

  @override
  String get videoRecorderCaptureCloseLabel => 'Închide';

  @override
  String get videoRecorderCaptureNextLabel => 'Următorul';

  @override
  String get videoRecorderToggleFlashLabel => 'Activează/dezactivează blițul';

  @override
  String get videoRecorderCycleTimerLabel => 'Schimbă temporizatorul';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Schimbă raportul de aspect';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Bibliotecă de clipuri, fără clipuri';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Deschide biblioteca de clipuri, $clipCount clipuri',
      one: 'Deschide biblioteca de clipuri, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Cameră';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Deschide camera';

  @override
  String get videoEditorLibraryLabel => 'Bibliotecă';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Desen';

  @override
  String get videoEditorFilterLabel => 'Filtru';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorVolumeLabel => 'Volum';

  @override
  String get videoEditorAddTitle => 'Adaugă';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Deschide biblioteca';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Deschide editorul audio';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Deschide editorul de text';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Deschide editorul de desen';

  @override
  String get videoEditorOpenFilterSemanticLabel =>
      'Deschide editorul de filtre';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Deschide editorul de stickere';

  @override
  String get videoEditorSaveDraftTitle => 'Salvezi schița?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Păstrează editările pentru mai târziu sau renunță la ele și părăsește editorul.';

  @override
  String get videoEditorSaveDraftButton => 'Salvează schița';

  @override
  String get videoEditorDiscardChangesButton => 'Renunță la modificări';

  @override
  String get videoEditorKeepEditingButton => 'Continuă editarea';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Zonă de plasare pentru ștergerea stratului';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Eliberează pentru a șterge stratul';

  @override
  String get videoEditorDoneLabel => 'Gata';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'Redă sau pune pe pauză videoclipul';

  @override
  String get videoEditorCropSemanticLabel => 'Decupează';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Clipul nu poate fi împărțit în timp ce este procesat. Te rugăm să aștepți.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Poziție de împărțire invalidă. Ambele clipuri trebuie să aibă cel puțin $minDurationMs ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Adaugă clip din bibliotecă';

  @override
  String get videoEditorSaveSelectedClip => 'Salvează clipul selectat';

  @override
  String get videoEditorSplitClip => 'Împarte clipul';

  @override
  String get videoEditorSaveClip => 'Salvează clipul';

  @override
  String get videoEditorDeleteClip => 'Șterge clipul';

  @override
  String get videoEditorClipSavedSuccess => 'Clip salvat în bibliotecă';

  @override
  String get videoEditorClipSaveFailed => 'Nu s-a putut salva clipul';

  @override
  String get videoEditorClipDeleted => 'Clip șters';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Selector de culoare';

  @override
  String get videoEditorUndoSemanticLabel => 'Anulează';

  @override
  String get videoEditorRedoSemanticLabel => 'Refă';

  @override
  String get videoEditorTextColorSemanticLabel => 'Culoare text';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Aliniere text';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Fundal text';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'Nu au fost găsite stickere';

  @override
  String get videoEditorNoStickersAvailable => 'Nu sunt disponibile stickere';

  @override
  String get videoEditorFailedLoadStickers =>
      'Nu s-au putut încărca stickerele';

  @override
  String get videoEditorAdjustVolumeTitle => 'Ajustează volumul';

  @override
  String get videoEditorRecordedAudioLabel => 'Audio înregistrat';

  @override
  String get videoEditorCustomAudioLabel => 'Audio personalizat';

  @override
  String get videoEditorPlaySemanticLabel => 'Redă';

  @override
  String get videoEditorPauseSemanticLabel => 'Pauză';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Dezactivează sunetul';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Activează sunetul';

  @override
  String get videoEditorDeleteLabel => 'Șterge';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Șterge elementul selectat';

  @override
  String get videoEditorEditLabel => 'Editează';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Editează elementul selectat';

  @override
  String get videoEditorDuplicateLabel => 'Duplichează';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplichează elementul selectat';

  @override
  String get videoEditorSplitLabel => 'Împarte';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Împarte clipul selectat';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Finalizează editarea cronologiei';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Redă previzualizarea';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Pune previzualizarea pe pauză';

  @override
  String get videoEditorAudioUntitledSound => 'Sunet fără titlu';

  @override
  String get videoEditorAudioUntitled => 'Fără titlu';

  @override
  String get videoEditorAudioAddAudio => 'Adaugă audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Nu sunt sunete disponibile';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Sunetele vor apărea aici când creatorii vor partaja audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Nu s-au putut încărca sunetele';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Alege segmentul audio pentru videoclipul tău';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunitate';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Instrument săgeată';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Instrument radieră';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Instrument marker';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Instrument creion';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Reordonează stratul $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Ține apăsat pentru a reordona';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Afișează cronologia';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ascunde cronologia';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evită să plasezi conținut în spatele acestor zone.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originale';

  @override
  String get videoEditorStickerSearchHint => 'Caută stickere...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Selectează fontul';

  @override
  String get videoEditorFontUnknown => 'Necunoscut';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Capul de redare trebuie să fie în clipul selectat pentru a împărți.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Taie începutul';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Taie finalul';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Taie clipul';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Trage mânerele pentru a ajusta durata clipului';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Se trage clipul $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clipul $index din $total, $duration secunde';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Apăsare lungă pentru reordonare';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Atinge pentru editare. Ține apăsat și trage pentru reordonare.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Mută la stânga';

  @override
  String get videoEditorTimelineClipMoveRight => 'Mută la dreapta';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Apasă lung pentru a trage';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Cronologie video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selectat';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Închide selectorul de culoare';

  @override
  String get videoEditorPickColorTitle => 'Alege culoarea';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmă culoarea';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturație și luminozitate';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturație $saturation%, Luminozitate $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Nuanță';

  @override
  String get videoEditorAddElementSemanticLabel => 'Adaugă element';

  @override
  String get videoEditorCloseSemanticLabel => 'Închide';

  @override
  String get videoEditorDoneSemanticLabel => 'Gata';

  @override
  String get videoEditorLevelSemanticLabel => 'Nivel';

  @override
  String get videoMetadataBackSemanticLabel => 'Înapoi';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Închide dialogul de ajutor';

  @override
  String get videoMetadataGotItButton => 'Am înțeles!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limita de 64KB a fost atinsă. Elimină conținut pentru a continua.';

  @override
  String get videoMetadataExpirationLabel => 'Expirare';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Selectează timpul de expirare';

  @override
  String get videoMetadataTitleLabel => 'Titlu';

  @override
  String get videoMetadataDescriptionLabel => 'Descriere';

  @override
  String get videoMetadataTagsLabel => 'Etichete';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Șterge';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Șterge eticheta $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Avertisment de conținut';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Selectează avertismente de conținut';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selectează tot ce se aplică conținutului tău';

  @override
  String get videoMetadataContentWarningDoneButton => 'Gata';

  @override
  String get videoMetadataCollaboratorsLabel => 'Colaboratori';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Adaugă colaborator';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Cum funcționează colaboratorii';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max colaboratori';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Elimină colaborator';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Colaboratorii sunt etichetați ca și co-creatori ai acestei postări. Poți adăuga doar persoane pe care le urmăriți reciproc, iar ele apar în metadatele postării când este publicată.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Urmăritori reciproci';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Trebuie să vă urmăriți reciproc cu $name pentru a-l adăuga ca și colaborator.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspirat de';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Setează inspirat de';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Cum funcționează creditele de inspirație';

  @override
  String get videoMetadataInspiredByNone => 'Niciunul';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Folosește asta pentru a oferi atribuire. Creditul inspirat de este diferit de colaboratori: recunoaște influența, dar nu etichetează pe cineva ca și co-creator.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Nu se poate face referire la acest creator.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Elimină inspirat de';

  @override
  String get videoMetadataPostDetailsTitle => 'Detalii postare';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Salvat în bibliotecă';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Salvare eșuată';

  @override
  String get videoMetadataGoToLibraryButton => 'Mergi la bibliotecă';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Buton salvează pentru mai târziu';

  @override
  String get videoMetadataRenderingVideoHint => 'Se redă videoclipul...';

  @override
  String get videoMetadataSavingVideoHint => 'Se salvează videoclipul...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Salvează videoclipul în schițe și $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Salvează pentru mai târziu';

  @override
  String get videoMetadataPostSemanticLabel => 'Buton publică';

  @override
  String get videoMetadataPublishVideoHint => 'Publică videoclipul în feed';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Completează formularul pentru a activa';

  @override
  String get videoMetadataPostButton => 'Publică';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Deschide ecranul de previzualizare a postării';

  @override
  String get videoMetadataShareTitle => 'Distribuie';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detalii videoclip';

  @override
  String get videoMetadataClassicDoneButton => 'Gata';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Redă previzualizarea';

  @override
  String get videoMetadataPausePreviewSemanticLabel =>
      'Pune previzualizarea pe pauză';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Închide previzualizarea videoclipului';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Elimină';

  @override
  String get metadataCaptionsLabel => 'Subtitrări';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Subtitrări activate pentru toate videoclipurile';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Subtitrări dezactivate pentru toate videoclipurile';

  @override
  String get fullscreenFeedRemovedMessage => 'Videoclip eliminat';

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
