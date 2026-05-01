// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Inställningar';

  @override
  String get settingsSecureAccount => 'Säkra ditt konto';

  @override
  String get settingsSessionExpired => 'Sessionen har löpt ut';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Logga in igen för att återfå full åtkomst';

  @override
  String get settingsCreatorAnalytics => 'Kreatörsstatistik';

  @override
  String get settingsSupportCenter => 'Supportcenter';

  @override
  String get settingsNotifications => 'Aviseringar';

  @override
  String get settingsContentPreferences => 'Innehållsinställningar';

  @override
  String get settingsModerationControls => 'Modereringskontroller';

  @override
  String get settingsBlueskyPublishing => 'Bluesky-publicering';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Hantera korspostning till Bluesky';

  @override
  String get settingsNostrSettings => 'Nostr-inställningar';

  @override
  String get settingsIntegratedApps => 'Integrerade appar';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Godkända tredjepartsappar som körs inuti Divine';

  @override
  String get settingsExperimentalFeatures => 'Experimentella funktioner';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Finjusteringar som kan hicka—testa om du är nyfiken.';

  @override
  String get settingsLegal => 'Juridik';

  @override
  String get settingsIntegrationPermissions => 'Integrationsbehörigheter';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Granska och återkalla sparade integrationsgodkännanden';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Utvecklarläge är redan aktiverat';

  @override
  String get settingsDeveloperModeEnabled => 'Utvecklarläge aktiverat!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count tryck till för att aktivera utvecklarläge';
  }

  @override
  String get settingsInvites => 'Inbjudningar';

  @override
  String get settingsSwitchAccount => 'Byt konto';

  @override
  String get settingsAddAnotherAccount => 'Lägg till ett till konto';

  @override
  String get settingsUnsavedDraftsTitle => 'Osparade utkast';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'utkast',
      one: 'utkast',
    );
    return 'Du har $count osparade $_temp0. Att byta konto behåller dina utkast, men du kanske vill publicera eller granska dem först.';
  }

  @override
  String get settingsCancel => 'Avbryt';

  @override
  String get settingsSwitchAnyway => 'Byt ändå';

  @override
  String get settingsAppVersionLabel => 'Appversion';

  @override
  String get settingsAppLanguage => 'Appspråk';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (enhetens standard)';
  }

  @override
  String get settingsAppLanguageTitle => 'Appspråk';

  @override
  String get settingsAppLanguageDescription =>
      'Välj språk för appens gränssnitt';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Använd enhetens språk';

  @override
  String get contentPreferencesTitle => 'Innehållsinställningar';

  @override
  String get contentPreferencesContentFilters => 'Innehållsfilter';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Hantera filter för innehållsvarningar';

  @override
  String get contentPreferencesContentLanguage => 'Innehållsspråk';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (enhetens standard)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tagga dina videor med ett språk så tittarna kan filtrera innehåll.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Använd enhetens språk (standard)';

  @override
  String get contentPreferencesAudioSharing =>
      'Gör mitt ljud tillgängligt för återanvändning';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'När aktiverat kan andra använda ljud från dina videor';

  @override
  String get contentPreferencesAccountLabels => 'Kontoetiketter';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Självmärk ditt innehåll';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etiketter för kontoinnehåll';

  @override
  String get contentPreferencesClearAll => 'Rensa alla';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Välj allt som gäller för ditt konto';

  @override
  String get contentPreferencesDoneNoLabels => 'Klar (Inga etiketter)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Klar ($count valda)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Ljudingångsenhet';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (rekommenderas)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Väljer automatiskt den bästa mikrofonen';

  @override
  String get contentPreferencesSelectAudioInput => 'Välj ljudingång';

  @override
  String get contentPreferencesUnknownMicrophone => 'Okänd mikrofon';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Det här kontot är inte tillgängligt';

  @override
  String profileErrorPrefix(Object error) {
    return 'Fel: $error';
  }

  @override
  String get profileInvalidId => 'Ogiltigt profil-ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Kolla in $displayName på Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName på Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Kunde inte dela profil: $error';
  }

  @override
  String get profileEditProfile => 'Redigera profil';

  @override
  String get profileCreatorAnalytics => 'Kreatörsstatistik';

  @override
  String get profileShareProfile => 'Dela profil';

  @override
  String get profileCopyPublicKey => 'Kopiera publik nyckel (npub)';

  @override
  String get profileGetEmbedCode => 'Hämta inbäddningskod';

  @override
  String get profilePublicKeyCopied => 'Publik nyckel kopierad till urklipp';

  @override
  String get profileEmbedCodeCopied => 'Inbäddningskod kopierad till urklipp';

  @override
  String get profileRefreshTooltip => 'Uppdatera';

  @override
  String get profileRefreshSemanticLabel => 'Uppdatera profil';

  @override
  String get profileMoreTooltip => 'Mer';

  @override
  String get profileMoreSemanticLabel => 'Fler alternativ';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Stäng avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Stäng avatarförhandsvisning';

  @override
  String get profileFollowingLabel => 'Följer';

  @override
  String get profileFollowLabel => 'Följ';

  @override
  String get profileBlockedLabel => 'Blockerad';

  @override
  String get profileFollowersLabel => 'Följare';

  @override
  String get profileFollowingStatLabel => 'Följer';

  @override
  String get profileVideosLabel => 'Videor';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count användare';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Blockera $displayName?';
  }

  @override
  String get profileBlockExplanation => 'När du blockerar en användare:';

  @override
  String get profileBlockBulletHidePosts =>
      'Deras inlägg visas inte i dina flöden.';

  @override
  String get profileBlockBulletCantView =>
      'De kommer inte kunna se din profil, följa dig eller se dina inlägg.';

  @override
  String get profileBlockBulletNoNotify => 'De meddelas inte om denna ändring.';

  @override
  String get profileBlockBulletYouCanView =>
      'Du kommer fortfarande kunna se deras profil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blockera $displayName';
  }

  @override
  String get profileCancelButton => 'Avbryt';

  @override
  String get profileLearnMore => 'Läs mer';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Avblockera $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'När du avblockerar den här användaren:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Deras inlägg visas i dina flöden.';

  @override
  String get profileUnblockBulletCanView =>
      'De kommer kunna se din profil, följa dig och se dina inlägg.';

  @override
  String get profileUnblockBulletNoNotify =>
      'De meddelas inte om denna ändring.';

  @override
  String get profileLearnMoreAt => 'Läs mer på ';

  @override
  String get profileUnblockButton => 'Avblockera';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Sluta följa $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blockera $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Avblockera $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Lägg till $displayName i en lista';
  }

  @override
  String get profileUserBlockedTitle => 'Användare blockerad';

  @override
  String get profileUserBlockedContent =>
      'Du kommer inte se innehåll från den här användaren i dina flöden.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Du kan avblockera när som helst från deras profil eller under Inställningar > Säkerhet.';

  @override
  String get profileCloseButton => 'Stäng';

  @override
  String get profileNoCollabsTitle => 'Inga samarbeten än';

  @override
  String get profileCollabsOwnEmpty => 'Videor du samarbetar kring visas här';

  @override
  String get profileCollabsOtherEmpty => 'Videor de samarbetar kring visas här';

  @override
  String get profileErrorLoadingCollabs =>
      'Fel vid inläsning av samarbetsvideor';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'Inga kommentarer än';

  @override
  String get profileNoCommentsOtherTitle => 'Inga kommentarer';

  @override
  String get profileCommentsOwnEmpty => 'Dina kommentarer och svar visas här';

  @override
  String get profileCommentsOtherEmpty =>
      'Deras kommentarer och svar visas här';

  @override
  String get profileErrorLoadingComments => 'Fel vid inläsning av kommentarer';

  @override
  String get profileVideoRepliesSection => 'Videosvar';

  @override
  String get profileCommentsSection => 'Kommentarer';

  @override
  String get profileEditLabel => 'Redigera';

  @override
  String get profileLibraryLabel => 'Bibliotek';

  @override
  String get profileNoLikedVideosTitle => 'Inga gillade videor än';

  @override
  String get profileLikedOwnEmpty => 'Videor du gillar visas här';

  @override
  String get profileLikedOtherEmpty => 'Videor de gillar visas här';

  @override
  String get profileErrorLoadingLiked => 'Fel vid inläsning av gillade videor';

  @override
  String get profileNoRepostsTitle => 'Inga återpubliceringar än';

  @override
  String get profileRepostsOwnEmpty => 'Videor du återpublicerar visas här';

  @override
  String get profileRepostsOtherEmpty => 'Videor de återpublicerar visas här';

  @override
  String get profileErrorLoadingReposts =>
      'Fel vid inläsning av återpublicerade videor';

  @override
  String get profileLoadingTitle => 'Läser in profil...';

  @override
  String get profileLoadingSubtitle => 'Det här kan ta en liten stund';

  @override
  String get profileLoadingVideos => 'Läser in videor...';

  @override
  String get profileNoVideosTitle => 'Inga videor än';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Dela din första video för att se den här';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Den här användaren har inte delat några videor än';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Videominiatyr $number';
  }

  @override
  String get profileShowMore => 'Visa mer';

  @override
  String get profileShowLess => 'Visa mindre';

  @override
  String get profileCompleteYourProfile => 'Komplettera din profil';

  @override
  String get profileCompleteSubtitle =>
      'Lägg till namn, bio och bild för att komma igång';

  @override
  String get profileSetUpButton => 'Sätt upp';

  @override
  String get profileVerifyingEmail => 'Verifierar e-post...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Kolla $email efter verifieringslänk';
  }

  @override
  String get profileWaitingForVerification => 'Väntar på e-postverifiering';

  @override
  String get profileVerificationFailed => 'Verifiering misslyckades';

  @override
  String get profilePleaseTryAgain => 'Försök igen';

  @override
  String get profileSecureYourAccount => 'Säkra ditt konto';

  @override
  String get profileSecureSubtitle =>
      'Lägg till e-post och lösenord för att återställa ditt konto på vilken enhet som helst';

  @override
  String get profileRetryButton => 'Försök igen';

  @override
  String get profileRegisterButton => 'Registrera';

  @override
  String get profileSessionExpired => 'Sessionen har löpt ut';

  @override
  String get profileSignInToRestore =>
      'Logga in igen för att återfå full åtkomst';

  @override
  String get profileSignInButton => 'Logga in';

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
  String get profileDismissTooltip => 'Avfärda';

  @override
  String get profileLinkCopied => 'Profillänk kopierad';

  @override
  String get profileSetupEditProfileTitle => 'Redigera profil';

  @override
  String get profileSetupBackLabel => 'Tillbaka';

  @override
  String get profileSetupAboutNostr => 'Om Nostr';

  @override
  String get profileSetupProfilePublished => 'Profilen publicerades!';

  @override
  String get profileSetupCreateNewProfile => 'Skapa ny profil?';

  @override
  String get profileSetupNoExistingProfile =>
      'Vi hittade ingen befintlig profil på dina reler. Publicering skapar en ny profil. Fortsätta?';

  @override
  String get profileSetupPublishButton => 'Publicera';

  @override
  String get profileSetupUsernameTaken =>
      'Användarnamnet togs precis. Välj ett annat.';

  @override
  String get profileSetupClaimFailed =>
      'Kunde inte claima användarnamnet. Försök igen.';

  @override
  String get profileSetupPublishFailed =>
      'Kunde inte publicera profilen. Försök igen.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Kunde inte nå nätverket. Kontrollera din anslutning och försök igen.';

  @override
  String get profileSetupRetryLabel => 'Försök igen';

  @override
  String get profileSetupDisplayNameLabel => 'Visningsnamn';

  @override
  String get profileSetupDisplayNameHint => 'Hur ska folk känna dig?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Vilket namn eller etikett du vill. Behöver inte vara unikt.';

  @override
  String get profileSetupDisplayNameRequired => 'Ange ett visningsnamn';

  @override
  String get profileSetupBioLabel => 'Bio (valfritt)';

  @override
  String get profileSetupBioHint => 'Berätta om dig själv...';

  @override
  String get profileSetupPublicKeyLabel => 'Publik nyckel (npub)';

  @override
  String get profileSetupUsernameLabel => 'Användarnamn (valfritt)';

  @override
  String get profileSetupUsernameHint => 'användarnamn';

  @override
  String get profileSetupUsernameHelper => 'Din unika identitet på Divine';

  @override
  String get profileSetupProfileColorLabel => 'Profilfärg (valfritt)';

  @override
  String get profileSetupSaveButton => 'Spara';

  @override
  String get profileSetupSavingButton => 'Sparar...';

  @override
  String get profileSetupImageUrlTitle => 'Lägg till bild-URL';

  @override
  String get profileSetupPictureUploaded => 'Profilbilden laddades upp!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Bildval misslyckades. Klistra in en bild-URL nedan istället.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Kameraåtkomst misslyckades: $error';
  }

  @override
  String get profileSetupGotItButton => 'Jag fattar';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Kunde inte ladda upp bilden: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'Nätverksfel: Kolla din internetanslutning och försök igen.';

  @override
  String get profileSetupUploadAuthError =>
      'Autentiseringsfel: Logga ut och in igen.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Filen är för stor: Välj en mindre bild (max 10 MB).';

  @override
  String get profileSetupUsernameChecking => 'Kollar tillgänglighet...';

  @override
  String get profileSetupUsernameAvailable => 'Användarnamnet är ledigt!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Användarnamnet är redan taget';

  @override
  String get profileSetupUsernameReserved => 'Användarnamnet är reserverat';

  @override
  String get profileSetupContactSupport => 'Kontakta support';

  @override
  String get profileSetupCheckAgain => 'Kolla igen';

  @override
  String get profileSetupUsernameBurned =>
      'Det här användarnamnet är inte längre tillgängligt';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Endast bokstäver, siffror och bindestreck är tillåtna';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Användarnamnet måste vara 3–20 tecken';

  @override
  String get profileSetupUsernameNetworkError =>
      'Kunde inte kolla tillgänglighet. Försök igen.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Ogiltigt format på användarnamn';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Kunde inte kolla tillgänglighet';

  @override
  String get profileSetupUsernameReservedTitle =>
      'Användarnamnet är reserverat';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Namnet $username är reserverat. Berätta varför det borde vara ditt.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      't.ex. Det är mitt varumärkesnamn, artistnamn osv.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Har du redan kontaktat supporten? Tryck på \"Kolla igen\" för att se om det har släppts till dig.';

  @override
  String get profileSetupSupportRequestSent =>
      'Supportförfrågan skickad! Vi hör av oss snart.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Kunde inte öppna e-post. Skicka till: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Skicka förfrågan';

  @override
  String get profileSetupPickColorTitle => 'Välj en färg';

  @override
  String get profileSetupSelectButton => 'Välj';

  @override
  String get profileSetupUseOwnNip05 => 'Använd din egen NIP-05-adress';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05-adress';

  @override
  String get profileSetupProfilePicturePreview =>
      'Förhandsvisning av profilbild';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine är byggt på Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' ett censurresistent öppet protokoll som låter folk kommunicera online utan att förlita sig på ett enda företag eller en enda plattform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'När du skapar ett Divine-konto får du en ny Nostr-identitet.';

  @override
  String get nostrInfoOwnership =>
      'Nostr låter dig äga ditt innehåll, din identitet och ditt sociala nätverk, vilket du kan använda i många appar. Resultatet är fler valmöjligheter, mindre inlåsning och ett sundare, mer motståndskraftigt socialt internet.';

  @override
  String get nostrInfoLingo => 'Nostr-jargong:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Din publika Nostr-adress. Den är säker att dela och låter andra hitta, följa eller meddela dig i Nostr-appar.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Din privata nyckel och ditt ägandebevis. Den ger full kontroll över din Nostr-identitet, så ';

  @override
  String get nostrInfoNsecWarning => 'håll den alltid hemlig!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr-användarnamn:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Ett människoläsbart namn (som @namn.divine.video) som länkar till din npub. Det gör din Nostr-identitet lättare att känna igen och verifiera, ungefär som en e-postadress.';

  @override
  String get nostrInfoLearnMoreAt => 'Läs mer på ';

  @override
  String get nostrInfoGotIt => 'Uppfattat!';

  @override
  String get profileTabRefreshTooltip => 'Uppdatera';

  @override
  String get videoGridRefreshLabel => 'Söker efter fler videor';

  @override
  String get videoGridOptionsTitle => 'Videoalternativ';

  @override
  String get videoGridEditVideo => 'Redigera video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Uppdatera titel, beskrivning och hashtags';

  @override
  String get videoGridDeleteVideo => 'Ta bort video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Ta bort det här innehållet permanent';

  @override
  String get videoGridDeleteConfirmTitle => 'Ta bort video';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Är du säker på att du vill ta bort den här videon?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Detta skickar en borttagningsbegäran (NIP-09) till alla reler. Vissa reler kan fortfarande behålla innehållet.';

  @override
  String get videoGridDeleteCancel => 'Avbryt';

  @override
  String get videoGridDeleteConfirm => 'Ta bort';

  @override
  String get videoGridDeletingContent => 'Tar bort innehåll...';

  @override
  String get videoGridDeleteSuccess => 'Borttagningsbegäran skickad';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Kunde inte ta bort innehåll: $error';
  }

  @override
  String get exploreTabClassics => 'Klassiker';

  @override
  String get exploreTabNew => 'Nytt';

  @override
  String get exploreTabPopular => 'Populärt';

  @override
  String get exploreTabCategories => 'Kategorier';

  @override
  String get exploreTabForYou => 'För dig';

  @override
  String get exploreTabLists => 'Listor';

  @override
  String get exploreTabIntegratedApps => 'Integrerade appar';

  @override
  String get exploreNoVideosAvailable => 'Inga videor tillgängliga';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Fel: $error';
  }

  @override
  String get exploreDiscoverLists => 'Upptäck listor';

  @override
  String get exploreAboutLists => 'Om listor';

  @override
  String get exploreAboutListsDescription =>
      'Listor hjälper dig organisera och kuratera Divine-innehåll på två sätt:';

  @override
  String get explorePeopleLists => 'Personlistor';

  @override
  String get explorePeopleListsDescription =>
      'Följ grupper av kreatörer och se deras senaste videor';

  @override
  String get exploreVideoLists => 'Videolistor';

  @override
  String get exploreVideoListsDescription =>
      'Skapa spellistor med dina favoritvideor för att titta på senare';

  @override
  String get exploreMyLists => 'Mina listor';

  @override
  String get exploreSubscribedLists => 'Prenumererade listor';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Fel vid inläsning av listor: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya videor',
      one: '1 ny video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nya videor',
      one: 'ny video',
    );
    return 'Ladda $count $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Läser in video...';

  @override
  String get videoPlayerPlayVideo => 'Spela upp video';

  @override
  String get videoPlayerMute => 'Stäng av ljudet på videon';

  @override
  String get videoPlayerUnmute => 'Slå på ljudet för videon';

  @override
  String get videoPlayerEditVideo => 'Redigera video';

  @override
  String get videoPlayerEditVideoTooltip => 'Redigera video';

  @override
  String get contentWarningLabel => 'Innehållsvarning';

  @override
  String get contentWarningNudity => 'Nakenhet';

  @override
  String get contentWarningSexualContent => 'Sexuellt innehåll';

  @override
  String get contentWarningPornography => 'Pornografi';

  @override
  String get contentWarningGraphicMedia => 'Grafiskt material';

  @override
  String get contentWarningViolence => 'Våld';

  @override
  String get contentWarningSelfHarm => 'Självskada';

  @override
  String get contentWarningDrugUse => 'Drogbruk';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tobak';

  @override
  String get contentWarningGambling => 'Spel om pengar';

  @override
  String get contentWarningProfanity => 'Grovt språk';

  @override
  String get contentWarningFlashingLights => 'Blinkande ljus';

  @override
  String get contentWarningAiGenerated => 'AI-genererat';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Känsligt innehåll';

  @override
  String get contentWarningDescNudity =>
      'Innehåller nakenhet eller delvis nakenhet';

  @override
  String get contentWarningDescSexual => 'Innehåller sexuellt innehåll';

  @override
  String get contentWarningDescPorn =>
      'Innehåller explicit pornografiskt innehåll';

  @override
  String get contentWarningDescGraphicMedia =>
      'Innehåller grafiska eller störande bilder';

  @override
  String get contentWarningDescViolence => 'Innehåller våldsamt innehåll';

  @override
  String get contentWarningDescSelfHarm =>
      'Innehåller referenser till självskada';

  @override
  String get contentWarningDescDrugs => 'Innehåller drogrelaterat innehåll';

  @override
  String get contentWarningDescAlcohol =>
      'Innehåller alkoholrelaterat innehåll';

  @override
  String get contentWarningDescTobacco => 'Innehåller tobaksrelaterat innehåll';

  @override
  String get contentWarningDescGambling => 'Innehåller spelrelaterat innehåll';

  @override
  String get contentWarningDescProfanity => 'Innehåller grovt språk';

  @override
  String get contentWarningDescFlashingLights =>
      'Innehåller blinkande ljus (varning för ljuskänslighet)';

  @override
  String get contentWarningDescAiGenerated =>
      'Det här innehållet genererades av AI';

  @override
  String get contentWarningDescSpoiler => 'Innehåller spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'Kreatören markerade detta som känsligt';

  @override
  String get contentWarningDescDefault =>
      'Kreatören flaggade det här innehållet';

  @override
  String get contentWarningDetailsTitle => 'Innehållsvarningar';

  @override
  String get contentWarningDetailsSubtitle =>
      'Kreatören applicerade dessa etiketter:';

  @override
  String get contentWarningManageFilters => 'Hantera innehållsfilter';

  @override
  String get contentWarningViewAnyway => 'Visa ändå';

  @override
  String get contentWarningHideAllLikeThis => 'Dölj allt innehåll som det här';

  @override
  String get contentWarningNoFilterYet =>
      'Inget sparat filter för den här varningen än.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vi döljer inlägg som det här från och med nu.';

  @override
  String get videoErrorNotFound => 'Videon hittades inte';

  @override
  String get videoErrorNetwork => 'Nätverksfel';

  @override
  String get videoErrorTimeout => 'Timeout vid inläsning';

  @override
  String get videoErrorFormat =>
      'Fel i videoformat\n(Försök igen eller använd en annan webbläsare)';

  @override
  String get videoErrorUnsupportedFormat => 'Videoformat stöds inte';

  @override
  String get videoErrorPlayback => 'Fel vid videouppspelning';

  @override
  String get videoErrorAgeRestricted => 'Åldersbegränsat innehåll';

  @override
  String get videoErrorVerifyAge => 'Verifiera ålder';

  @override
  String get videoErrorRetry => 'Försök igen';

  @override
  String get videoErrorContentRestricted => 'Innehåll begränsat';

  @override
  String get videoErrorContentRestrictedBody =>
      'Den här videon har begränsats av relen.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifiera din ålder för att se den här videon.';

  @override
  String get videoErrorSkip => 'Hoppa över';

  @override
  String get videoErrorVerifyAgeButton => 'Verifiera ålder';

  @override
  String get videoFollowButtonFollowing => 'Följer';

  @override
  String get videoFollowButtonFollow => 'Följ';

  @override
  String get audioAttributionOriginalSound => 'Originalljud';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirerad av @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'med @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'med @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetspartner',
      one: '1 samarbetspartner',
    );
    return '$_temp0. Tryck för att se profil.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Dela video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Inlägg delat med $recipientName';
  }

  @override
  String get shareFailedToSend => 'Kunde inte skicka video';

  @override
  String get shareAddedToBookmarks => 'Tillagd i bokmärken';

  @override
  String get shareRemovedFromBookmarks => 'Borttagen från bokmärken';

  @override
  String get shareFailedToAddBookmark => 'Kunde inte lägga till bokmärket';

  @override
  String get shareFailedToRemoveBookmark => 'Kunde inte ta bort från bokmärken';

  @override
  String get shareActionFailed => 'Åtgärden misslyckades';

  @override
  String get shareWithTitle => 'Dela med';

  @override
  String get shareFindPeople => 'Hitta personer';

  @override
  String get shareFindPeopleMultiline => 'Hitta\npersoner';

  @override
  String get shareSent => 'Skickat';

  @override
  String get shareContactFallback => 'Kontakt';

  @override
  String get shareUserFallback => 'Användare';

  @override
  String shareSendingTo(String name) {
    return 'Skickar till $name';
  }

  @override
  String get shareMessageHint => 'Lägg till valfritt meddelande...';

  @override
  String get videoActionUnlike => 'Sluta gilla videon';

  @override
  String get videoActionLike => 'Gilla videon';

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
  String get videoActionEnableAutoAdvance => 'Aktivera automatisk fortsättning';

  @override
  String get videoActionDisableAutoAdvance =>
      'Inaktivera automatisk fortsättning';

  @override
  String get videoActionRemoveRepost => 'Ta bort återpublicering';

  @override
  String get videoActionRepost => 'Återpublicera video';

  @override
  String get videoActionViewComments => 'Visa kommentarer';

  @override
  String get videoActionMoreOptions => 'Fler alternativ';

  @override
  String get videoActionHideSubtitles => 'Dölj undertexter';

  @override
  String get videoActionShowSubtitles => 'Visa undertexter';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

  @override
  String videoDescriptionLoops(String count) {
    return '$count loopar';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loopar',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Inte Divine';

  @override
  String get metadataBadgeHumanMade => 'Gjord av människa';

  @override
  String get metadataSoundsLabel => 'Ljud';

  @override
  String get metadataOriginalSound => 'Originalljud';

  @override
  String get metadataVerificationLabel => 'Verifiering';

  @override
  String get metadataDeviceAttestation => 'Enhetsattestering';

  @override
  String get metadataProofManifest => 'Bevismanifest';

  @override
  String get metadataCreatorLabel => 'Kreatör';

  @override
  String get metadataCollaboratorsLabel => 'Samarbetspartner';

  @override
  String get metadataInspiredByLabel => 'Inspirerad av';

  @override
  String get metadataRepostedByLabel => 'Återpublicerad av';

  @override
  String metadataLoopsLabel(int count) {
    return 'Loopar';
  }

  @override
  String get metadataLikesLabel => 'Gillamarkeringar';

  @override
  String get metadataCommentsLabel => 'Kommentarer';

  @override
  String get metadataRepostsLabel => 'Återpubliceringar';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicerat den $date';
  }

  @override
  String get devOptionsTitle => 'Utvecklaralternativ';

  @override
  String get devOptionsPageLoadTimes => 'Sidladdningstider';

  @override
  String get devOptionsNoPageLoads =>
      'Inga sidladdningar registrerade än.\nNavigera i appen för att se tidsdata.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Synlig: $visibleMs ms  |  Data: $dataMs ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Långsammaste skärmarna';

  @override
  String get devOptionsVideoPlaybackFormat => 'Videouppspelningsformat';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Byta miljö?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Byta till $envName?\n\nDetta rensar cachad videodata och åternsluter till den nya relen.';
  }

  @override
  String get devOptionsCancel => 'Avbryt';

  @override
  String get devOptionsSwitch => 'Byt';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Bytte till $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Bytte till $formatName — cache rensad';
  }

  @override
  String get featureFlagTitle => 'Funktionsflaggor';

  @override
  String get featureFlagResetAllTooltip =>
      'Återställ alla flaggor till standard';

  @override
  String get featureFlagResetToDefault => 'Återställ till standard';

  @override
  String get featureFlagAppRecovery => 'Appåterställning';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Om appen kraschar eller beter sig konstigt, testa att rensa cachen.';

  @override
  String get featureFlagClearAllCache => 'Rensa all cache';

  @override
  String get featureFlagCacheInfo => 'Cacheinfo';

  @override
  String get featureFlagClearCacheTitle => 'Rensa all cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'Detta rensar all cachad data inklusive:\n• Aviseringar\n• Användarprofiler\n• Bokmärken\n• Temporära filer\n\nDu behöver logga in igen. Fortsätta?';

  @override
  String get featureFlagClearCache => 'Rensa cache';

  @override
  String get featureFlagClearingCache => 'Rensar cache...';

  @override
  String get featureFlagSuccess => 'Klart';

  @override
  String get featureFlagError => 'Fel';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cachen rensades. Starta om appen.';

  @override
  String get featureFlagClearCacheFailure =>
      'Kunde inte rensa vissa cacheobjekt. Kolla loggarna för detaljer.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Cacheinformation';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Total cachestorlek: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cachen innehåller:\n• Aviseringshistorik\n• Profildata\n• Videominiatyrer\n• Temporära filer\n• Databasindex';

  @override
  String get relaySettingsTitle => 'Reler';

  @override
  String get relaySettingsInfoTitle =>
      'Divine är ett öppet system – du styr dina anslutningar';

  @override
  String get relaySettingsInfoDescription =>
      'De här relerna distribuerar ditt innehåll över det decentraliserade Nostr-nätverket. Du kan lägga till eller ta bort reler som du vill.';

  @override
  String get relaySettingsLearnMoreNostr => 'Läs mer om Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Hitta publika reler på nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'Appen fungerar inte';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine kräver minst en rel för att ladda videor, publicera innehåll och synka data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Återställ standardrel';

  @override
  String get relaySettingsAddCustomRelay => 'Lägg till egen rel';

  @override
  String get relaySettingsAddRelay => 'Lägg till rel';

  @override
  String get relaySettingsRetry => 'Försök igen';

  @override
  String get relaySettingsNoStats => 'Ingen statistik tillgänglig än';

  @override
  String get relaySettingsConnection => 'Anslutning';

  @override
  String get relaySettingsConnected => 'Ansluten';

  @override
  String get relaySettingsDisconnected => 'Frånkopplad';

  @override
  String get relaySettingsSessionDuration => 'Sessionslängd';

  @override
  String get relaySettingsLastConnected => 'Senast ansluten';

  @override
  String get relaySettingsDisconnectedLabel => 'Frånkopplad';

  @override
  String get relaySettingsReason => 'Anledning';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktiva prenumerationer';

  @override
  String get relaySettingsTotalSubscriptions => 'Totala prenumerationer';

  @override
  String get relaySettingsEventsReceived => 'Mottagna händelser';

  @override
  String get relaySettingsEventsSent => 'Skickade händelser';

  @override
  String get relaySettingsRequestsThisSession =>
      'Förfrågningar i den här sessionen';

  @override
  String get relaySettingsFailedRequests => 'Misslyckade förfrågningar';

  @override
  String relaySettingsLastError(String error) {
    return 'Senaste fel: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Läser in relinfo...';

  @override
  String get relaySettingsAboutRelay => 'Om relen';

  @override
  String get relaySettingsSupportedNips => 'NIP:er som stöds';

  @override
  String get relaySettingsSoftware => 'Mjukvara';

  @override
  String get relaySettingsViewWebsite => 'Visa webbplats';

  @override
  String get relaySettingsRemoveRelayTitle => 'Ta bort rel?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Är du säker på att du vill ta bort den här relen?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Avbryt';

  @override
  String get relaySettingsRemove => 'Ta bort';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Rel borttagen: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Kunde inte ta bort relen';

  @override
  String get relaySettingsForcingReconnection => 'Tvingar återanslutning...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Ansluten till $count rel(er)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Kunde inte ansluta till reler. Kolla din nätverksanslutning.';

  @override
  String get relaySettingsAddRelayTitle => 'Lägg till rel';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Ange WebSocket-URL:en för relen du vill lägga till:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Bläddra bland publika reler på nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Lägg till';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Rel tillagd: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Kunde inte lägga till relen. Kolla URL:en och försök igen.';

  @override
  String get relaySettingsInvalidUrl =>
      'Rel-URL måste börja med wss:// eller ws://';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Återställde standardrel: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Kunde inte återställa standardrelen. Kolla din nätverksanslutning.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Kunde inte öppna webbläsaren';

  @override
  String get relaySettingsFailedToOpenLink => 'Kunde inte öppna länken';

  @override
  String get relayDiagnosticTitle => 'Reldiagnostik';

  @override
  String get relayDiagnosticRefreshTooltip => 'Uppdatera diagnostik';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Senaste uppdatering: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relstatus';

  @override
  String get relayDiagnosticInitialized => 'Initierad';

  @override
  String get relayDiagnosticReady => 'Redo';

  @override
  String get relayDiagnosticNotInitialized => 'Inte initierad';

  @override
  String get relayDiagnosticDatabaseEvents => 'Databashändelser';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktiva prenumerationer';

  @override
  String get relayDiagnosticExternalRelays => 'Externa reler';

  @override
  String get relayDiagnosticConfigured => 'Konfigurerad';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count rel(er)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Ansluten';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Videohändelser';

  @override
  String get relayDiagnosticHomeFeed => 'Hemflöde';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count videor';
  }

  @override
  String get relayDiagnosticDiscovery => 'Upptäck';

  @override
  String get relayDiagnosticLoading => 'Laddar';

  @override
  String get relayDiagnosticYes => 'Ja';

  @override
  String get relayDiagnosticNo => 'Nej';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testa direktförfrågan';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Nätverksanslutning';

  @override
  String get relayDiagnosticRunNetworkTest => 'Kör nätverkstest';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom-server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testa alla ändpunkter';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Fel';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake-API';

  @override
  String get relayDiagnosticBaseUrl => 'Bas-URL';

  @override
  String get relayDiagnosticSummary => 'Sammanfattning';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (snitt $avgMs ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Testa allt igen';

  @override
  String get relayDiagnosticRetrying => 'Försöker igen...';

  @override
  String get relayDiagnosticRetryConnection => 'Försök ansluta igen';

  @override
  String get relayDiagnosticTroubleshooting => 'Felsökning';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Grön status = Ansluten och fungerar\n• Röd status = Anslutningen misslyckades\n• Om nätverkstestet misslyckas, kolla internetanslutningen\n• Om reler är konfigurerade men inte anslutna, tryck på \"Försök ansluta igen\"\n• Ta en skärmdump av den här skärmen för felsökning';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Alla REST-ändpunkter är friska!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Vissa REST-ändpunkter misslyckades – se detaljer ovan';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Hittade $count videohändelser i databasen';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Förfrågan misslyckades: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Ansluten till $count rel(er)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Kunde inte ansluta till några reler';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Förnyat anslutningsförsök misslyckades: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Ansluten och autentiserad';

  @override
  String get relayDiagnosticConnectedOnly => 'Ansluten';

  @override
  String get relayDiagnosticNotConnected => 'Inte ansluten';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Inga reler konfigurerade';

  @override
  String get relayDiagnosticFailed => 'Misslyckades';

  @override
  String get notificationSettingsTitle => 'Aviseringar';

  @override
  String get notificationSettingsResetTooltip => 'Återställ till standard';

  @override
  String get notificationSettingsTypes => 'Aviseringstyper';

  @override
  String get notificationSettingsLikes => 'Gillamarkeringar';

  @override
  String get notificationSettingsLikesSubtitle =>
      'När någon gillar dina videor';

  @override
  String get notificationSettingsComments => 'Kommentarer';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'När någon kommenterar dina videor';

  @override
  String get notificationSettingsFollows => 'Följare';

  @override
  String get notificationSettingsFollowsSubtitle => 'När någon följer dig';

  @override
  String get notificationSettingsMentions => 'Omnämnanden';

  @override
  String get notificationSettingsMentionsSubtitle => 'När du omnämns';

  @override
  String get notificationSettingsReposts => 'Återpubliceringar';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'När någon återpublicerar dina videor';

  @override
  String get notificationSettingsSystem => 'System';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Appuppdateringar och systemmeddelanden';

  @override
  String get notificationSettingsPushNotificationsSection => 'Push-aviseringar';

  @override
  String get notificationSettingsPushNotifications => 'Push-aviseringar';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Få aviseringar när appen är stängd';

  @override
  String get notificationSettingsSound => 'Ljud';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Spela upp ljud för aviseringar';

  @override
  String get notificationSettingsVibration => 'Vibration';

  @override
  String get notificationSettingsVibrationSubtitle => 'Vibrera vid aviseringar';

  @override
  String get notificationSettingsActions => 'Åtgärder';

  @override
  String get notificationSettingsMarkAllAsRead => 'Markera alla som lästa';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Markera alla aviseringar som lästa';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Alla aviseringar markerade som lästa';

  @override
  String get notificationSettingsResetToDefaults =>
      'Inställningar återställda till standard';

  @override
  String get notificationSettingsAbout => 'Om aviseringar';

  @override
  String get notificationSettingsAboutDescription =>
      'Aviseringar drivs av Nostr-protokollet. Realtidsuppdateringar beror på din anslutning till Nostr-reler. Vissa aviseringar kan vara fördröjda.';

  @override
  String get safetySettingsTitle => 'Säkerhet och integritet';

  @override
  String get safetySettingsLabel => 'INSTÄLLNINGAR';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Visa endast Divine-hostade videor';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Dölj videor som serveras från andra mediavärdar';

  @override
  String get safetySettingsModeration => 'MODERERING';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKERADE ANVÄNDARE';

  @override
  String get safetySettingsAgeVerification => 'ÅLDERSVERIFIERING';

  @override
  String get safetySettingsAgeConfirmation =>
      'Jag bekräftar att jag är 18 år eller äldre';

  @override
  String get safetySettingsAgeRequired => 'Krävs för att se vuxeninnehåll';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Officiell modereringstjänst (på som standard)';

  @override
  String get safetySettingsPeopleIFollow => 'Personer jag följer';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Prenumerera på etiketter från personer du följer';

  @override
  String get safetySettingsAddCustomLabeler => 'Lägg till egen etiketterare';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Ange npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Lägg till egen etiketterare';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Ange npub-adress';

  @override
  String get safetySettingsNoBlockedUsers => 'Inga blockerade användare';

  @override
  String get safetySettingsUnblock => 'Avblockera';

  @override
  String get safetySettingsUserUnblocked => 'Användare avblockerad';

  @override
  String get safetySettingsCancel => 'Avbryt';

  @override
  String get safetySettingsAdd => 'Lägg till';

  @override
  String get analyticsTitle => 'Kreatörsstatistik';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostik';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Växla diagnostik';

  @override
  String get analyticsRetry => 'Försök igen';

  @override
  String get analyticsUnableToLoad => 'Kunde inte läsa in statistik.';

  @override
  String get analyticsSignInRequired =>
      'Logga in för att se kreatörsstatistik.';

  @override
  String get analyticsViewDataUnavailable =>
      'Visningar är för tillfället inte tillgängliga från relen för de här inläggen. Gillamarkeringar/kommentarer/återpubliceringar är fortfarande exakta.';

  @override
  String get analyticsViewDataTitle => 'Visningsdata';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Uppdaterad $time • Poäng använder gillamarkeringar, kommentarer, återpubliceringar och visningar/loopar från Funnelcake när tillgängliga.';
  }

  @override
  String get analyticsVideos => 'Videor';

  @override
  String get analyticsViews => 'Visningar';

  @override
  String get analyticsInteractions => 'Interaktioner';

  @override
  String get analyticsEngagement => 'Engagemang';

  @override
  String get analyticsFollowers => 'Följare';

  @override
  String get analyticsAvgPerPost => 'Snitt/inlägg';

  @override
  String get analyticsInteractionMix => 'Interaktionsmix';

  @override
  String get analyticsLikes => 'Gillamarkeringar';

  @override
  String get analyticsComments => 'Kommentarer';

  @override
  String get analyticsReposts => 'Återpubliceringar';

  @override
  String get analyticsPerformanceHighlights => 'Prestandahöjdpunkter';

  @override
  String get analyticsMostViewed => 'Mest sedda';

  @override
  String get analyticsMostDiscussed => 'Mest diskuterade';

  @override
  String get analyticsMostReposted => 'Mest återpublicerade';

  @override
  String get analyticsNoVideosYet => 'Inga videor än';

  @override
  String get analyticsViewDataUnavailableShort => 'Visningsdata otillgänglig';

  @override
  String analyticsViewsCount(String count) {
    return '$count visningar';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count kommentarer';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count återpubliceringar';
  }

  @override
  String get analyticsTopContent => 'Topp-innehåll';

  @override
  String get analyticsPublishPrompt =>
      'Publicera några videor för att se rankningar.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Högersidig % = engagemangsgrad (interaktioner delat med visningar).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Engagemangsgrad kräver visningsdata; värden visas som N/A tills visningar finns tillgängliga.';

  @override
  String get analyticsEngagementLabel => 'Engagemang';

  @override
  String get analyticsViewsUnavailable => 'visningar otillgängliga';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interaktioner';
  }

  @override
  String get analyticsPostAnalytics => 'Inläggsstatistik';

  @override
  String get analyticsOpenPost => 'Öppna inlägg';

  @override
  String get analyticsRecentDailyInteractions =>
      'Senaste dagliga interaktioner';

  @override
  String get analyticsNoActivityYet =>
      'Ingen aktivitet i det här intervallet än.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaktioner = gillamarkeringar + kommentarer + återpubliceringar per publiceringsdatum.';

  @override
  String get analyticsDailyBarExplainer =>
      'Stapellängden är relativ till din högsta dag i det här fönstret.';

  @override
  String get analyticsAudienceSnapshot => 'Publikmomentbild';

  @override
  String analyticsFollowersCount(String count) {
    return 'Följare: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Följer: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Publikkälla/geografi/tidsuppdelningar kommer att fyllas i när Funnelcake lägger till publikstatistikslutpunkter.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retentionskurva och visningstidsuppdelning visas när per-sekund/per-hink-retention kommer från Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retentionsdata otillgänglig tills visnings- och tittartidsstatistik returneras av Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostik';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Totalt antal videor: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Med visningar: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Saknar visningar: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrerade (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrerade (/visningar): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Källor: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Använd fixturedata';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Skapa ett nytt Divine-konto';

  @override
  String get authSignInDifferentAccount => 'Logga in med ett annat konto';

  @override
  String get authSignBackIn => 'Logga in igen';

  @override
  String get authTermsPrefix =>
      'Genom att välja ett alternativ ovan bekräftar du att du är minst 16 år gammal och godkänner ';

  @override
  String get authTermsOfService => 'Användarvillkor';

  @override
  String get authPrivacyPolicy => 'Integritetspolicy';

  @override
  String get authTermsAnd => ', och ';

  @override
  String get authSafetyStandards => 'Säkerhetsstandarder';

  @override
  String get authAmberNotInstalled => 'Amber-appen är inte installerad';

  @override
  String get authAmberConnectionFailed => 'Kunde inte ansluta med Amber';

  @override
  String get authPasswordResetSent =>
      'Om ett konto finns med den e-postadressen har en länk för lösenordsåterställning skickats.';

  @override
  String get authSignInTitle => 'Logga in';

  @override
  String get authEmailLabel => 'E-post';

  @override
  String get authPasswordLabel => 'Lösenord';

  @override
  String get authForgotPassword => 'Glömt lösenord?';

  @override
  String get authImportNostrKey => 'Importera Nostr-nyckel';

  @override
  String get authConnectSignerApp => 'Anslut med en sign-app';

  @override
  String get authSignInWithAmber => 'Logga in med Amber';

  @override
  String get authSignInOptionsTitle => 'Inloggningsalternativ';

  @override
  String get authInfoEmailPasswordTitle => 'E-post och lösenord';

  @override
  String get authInfoEmailPasswordDescription =>
      'Logga in med ditt Divine-konto. Om du registrerade dig med e-post och lösenord, använd dem här.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Har du redan en Nostr-identitet? Importera din nsec-privatnyckel från en annan klient.';

  @override
  String get authInfoSignerAppTitle => 'Sign-app';

  @override
  String get authInfoSignerAppDescription =>
      'Anslut med hjälp av en NIP-46-kompatibel fjärrsigner som nsecBunker för förbättrad nyckelsäkerhet.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Använd Amber-signappen på Android för att hantera dina Nostr-nycklar säkert.';

  @override
  String get authCreateAccountTitle => 'Skapa konto';

  @override
  String get authBackToInviteCode => 'Tillbaka till inbjudningskod';

  @override
  String get authUseDivineNoBackup => 'Använd Divine utan backup';

  @override
  String get authSkipConfirmTitle => 'En sista grej...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Du är inne! Vi skapar en säker nyckel som driver ditt Divine-konto.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Utan en e-post är din nyckel det enda sättet Divine vet att det här kontot är ditt.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Du kan nå din nyckel i appen, men om du inte är särskilt teknisk rekommenderar vi att du lägger till en e-post och ett lösenord nu. Det gör det enklare att logga in och återställa ditt konto om du tappar eller återställer den här enheten.';

  @override
  String get authAddEmailPassword => 'Lägg till e-post och lösenord';

  @override
  String get authUseThisDeviceOnly => 'Använd bara den här enheten';

  @override
  String get authCompleteRegistration => 'Slutför din registrering';

  @override
  String get authVerifying => 'Verifierar...';

  @override
  String get authVerificationLinkSent =>
      'Vi skickade en verifieringslänk till:';

  @override
  String get authClickVerificationLink =>
      'Klicka på länken i din e-post för att\nslutföra din registrering.';

  @override
  String get authPleaseWaitVerifying =>
      'Vänta medan vi verifierar din e-post...';

  @override
  String get authWaitingForVerification => 'Väntar på verifiering';

  @override
  String get authOpenEmailApp => 'Öppna e-postappen';

  @override
  String get authWelcomeToDivine => 'Välkommen till Divine!';

  @override
  String get authEmailVerified => 'Din e-post har verifierats.';

  @override
  String get authSigningYouIn => 'Loggar in dig';

  @override
  String get authErrorTitle => 'Oj då.';

  @override
  String get authVerificationFailed =>
      'Vi misslyckades att verifiera din e-post.\nFörsök igen.';

  @override
  String get authStartOver => 'Börja om';

  @override
  String get authEmailVerifiedLogin =>
      'E-post verifierad! Logga in för att fortsätta.';

  @override
  String get authVerificationLinkExpired =>
      'Den här verifieringslänken är inte längre giltig.';

  @override
  String get authVerificationConnectionError =>
      'Kunde inte verifiera e-post. Kolla din anslutning och försök igen.';

  @override
  String get authWaitlistConfirmTitle => 'Du är på listan!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Vi delar uppdateringar på $email.\nNär fler inbjudningskoder blir tillgängliga skickar vi dem till dig.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Inbjudningsåtkomst är tillfälligt otillgänglig.';

  @override
  String get authInviteUnavailableBody =>
      'Försök igen om en stund eller kontakta supporten om du behöver hjälp att komma in.';

  @override
  String get authTryAgain => 'Försök igen';

  @override
  String get authContactSupport => 'Kontakta support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Kunde inte öppna $email';
  }

  @override
  String get authAddInviteCode => 'Lägg till din inbjudningskod';

  @override
  String get authInviteCodeLabel => 'Inbjudningskod';

  @override
  String get authEnterYourCode => 'Ange din kod';

  @override
  String get authNext => 'Nästa';

  @override
  String get authJoinWaitlist => 'Ansluta till väntelistan';

  @override
  String get authJoinWaitlistTitle => 'Ansluta till väntelistan';

  @override
  String get authJoinWaitlistDescription =>
      'Dela din e-post så skickar vi uppdateringar när åtkomst öppnas.';

  @override
  String get authInviteAccessHelp => 'Hjälp med inbjudningsåtkomst';

  @override
  String get authGeneratingConnection => 'Genererar anslutning...';

  @override
  String get authConnectedAuthenticating => 'Ansluten! Autentiserar...';

  @override
  String get authConnectionTimedOut => 'Anslutningen tog slut på tid';

  @override
  String get authApproveConnection =>
      'Se till att du godkände anslutningen i din sign-app.';

  @override
  String get authConnectionCancelled => 'Anslutning avbruten';

  @override
  String get authConnectionCancelledMessage => 'Anslutningen avbröts.';

  @override
  String get authConnectionFailed => 'Anslutning misslyckades';

  @override
  String get authUnknownError => 'Ett okänt fel uppstod.';

  @override
  String get authUrlCopied => 'URL kopierad till urklipp';

  @override
  String get authConnectToDivine => 'Anslut till Divine';

  @override
  String get authPasteBunkerUrl => 'Klistra in bunker://-URL';

  @override
  String get authBunkerUrlHint => 'bunker://-URL';

  @override
  String get authInvalidBunkerUrl =>
      'Ogiltig bunker-URL. Den ska börja med bunker://';

  @override
  String get authScanSignerApp => 'Skanna med din\nsign-app för att ansluta.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Väntar på anslutning... $seconds s';
  }

  @override
  String get authCopyUrl => 'Kopiera URL';

  @override
  String get authShare => 'Dela';

  @override
  String get authAddBunker => 'Lägg till bunker';

  @override
  String get authCompatibleSignerApps => 'Kompatibla sign-appar';

  @override
  String get authFailedToConnect => 'Kunde inte ansluta';

  @override
  String get authResetPasswordTitle => 'Återställ lösenord';

  @override
  String get authResetPasswordSubtitle =>
      'Ange ditt nya lösenord. Det måste vara minst 8 tecken långt.';

  @override
  String get authNewPasswordLabel => 'Nytt lösenord';

  @override
  String get authPasswordTooShort => 'Lösenordet måste vara minst 8 tecken';

  @override
  String get authPasswordResetSuccess => 'Lösenordet återställdes. Logga in.';

  @override
  String get authPasswordResetFailed => 'Lösenordsåterställning misslyckades';

  @override
  String get authUnexpectedError => 'Ett oväntat fel uppstod. Försök igen.';

  @override
  String get authUpdatePassword => 'Uppdatera lösenord';

  @override
  String get authSecureAccountTitle => 'Säkra konto';

  @override
  String get authUnableToAccessKeys =>
      'Kunde inte komma åt dina nycklar. Försök igen.';

  @override
  String get authRegistrationFailed => 'Registrering misslyckades';

  @override
  String get authRegistrationComplete => 'Registrering klar. Kolla din e-post.';

  @override
  String get authVerificationFailedTitle => 'Verifiering misslyckades';

  @override
  String get authClose => 'Stäng';

  @override
  String get authAccountSecured => 'Konto säkrat!';

  @override
  String get authAccountLinkedToEmail =>
      'Ditt konto är nu kopplat till din e-post.';

  @override
  String get authVerifyYourEmail => 'Verifiera din e-post';

  @override
  String get authClickLinkContinue =>
      'Klicka på länken i din e-post för att slutföra registreringen. Du kan fortsätta använda appen under tiden.';

  @override
  String get authWaitingForVerificationEllipsis => 'Väntar på verifiering...';

  @override
  String get authContinueToApp => 'Fortsätt till appen';

  @override
  String get authResetPassword => 'Återställ lösenord';

  @override
  String get authResetPasswordDescription =>
      'Ange din e-postadress så skickar vi en länk för att återställa ditt lösenord.';

  @override
  String get authFailedToSendResetEmail =>
      'Kunde inte skicka återställningsmejl.';

  @override
  String get authUnexpectedErrorShort => 'Ett oväntat fel uppstod.';

  @override
  String get authSending => 'Skickar...';

  @override
  String get authSendResetLink => 'Skicka återställningslänk';

  @override
  String get authEmailSent => 'E-post skickad!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Vi skickade en återställningslänk till $email. Klicka på länken i din e-post för att uppdatera ditt lösenord.';
  }

  @override
  String get authSignInButton => 'Logga in';

  @override
  String get authVerificationErrorTimeout =>
      'Verifieringen tog slut på tid. Försök registrera dig igen.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifiering misslyckades – auktoriseringskod saknas.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verifiering misslyckades. Försök igen.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Nätverksfel vid inloggning. Försök igen.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifiering misslyckades. Försök registrera dig igen.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Inloggning misslyckades. Försök logga in manuellt.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Den inbjudningskoden är inte längre tillgänglig. Gå tillbaka till din inbjudningskod, gå med i väntelistan eller kontakta supporten.';

  @override
  String get authInviteErrorInvalid =>
      'Den inbjudningskoden kan inte användas just nu. Gå tillbaka till din inbjudningskod, gå med i väntelistan eller kontakta supporten.';

  @override
  String get authInviteErrorTemporary =>
      'Vi kunde inte bekräfta din inbjudan just nu. Gå tillbaka till din inbjudningskod och försök igen, eller kontakta supporten.';

  @override
  String get authInviteErrorUnknown =>
      'Vi kunde inte aktivera din inbjudan. Gå tillbaka till din inbjudningskod, gå med i väntelistan eller kontakta supporten.';

  @override
  String get shareSheetSave => 'Spara';

  @override
  String get shareSheetSaveToGallery => 'Spara i galleriet';

  @override
  String get shareSheetSaveWithWatermark => 'Spara med vattenmärke';

  @override
  String get shareSheetSaveVideo => 'Spara video';

  @override
  String get shareSheetAddToClips => 'Lägg till i klipp';

  @override
  String get shareSheetAddedToClips => 'Tillagt i klipp';

  @override
  String get shareSheetAddToClipsFailed => 'Kunde inte lägga till i klipp';

  @override
  String get shareSheetAddToList => 'Lägg till i lista';

  @override
  String get shareSheetCopy => 'Kopiera';

  @override
  String get shareSheetShareVia => 'Dela via';

  @override
  String get shareSheetReport => 'Rapportera';

  @override
  String get shareSheetEventJson => 'Händelse-JSON';

  @override
  String get shareSheetEventId => 'Händelse-ID';

  @override
  String get shareSheetMoreActions => 'Fler åtgärder';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Sparad i kamerarullen';

  @override
  String get watermarkDownloadShare => 'Dela';

  @override
  String get watermarkDownloadDone => 'Klar';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Fotoåtkomst behövs';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'För att spara videor, tillåt fotoåtkomst i Inställningar.';

  @override
  String get watermarkDownloadOpenSettings => 'Öppna inställningar';

  @override
  String get watermarkDownloadNotNow => 'Inte nu';

  @override
  String get watermarkDownloadFailed => 'Nedladdning misslyckades';

  @override
  String get watermarkDownloadDismiss => 'Avfärda';

  @override
  String get watermarkDownloadStageDownloading => 'Laddar ner video';

  @override
  String get watermarkDownloadStageWatermarking => 'Lägger till vattenmärke';

  @override
  String get watermarkDownloadStageSaving => 'Sparar i kamerarullen';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Hämtar videon från nätverket...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Lägger till Divine-vattenmärket...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Sparar den vattenmärkta videon i din kamerarulle...';

  @override
  String get uploadProgressVideoUpload => 'Videouppladdning';

  @override
  String get uploadProgressPause => 'Pausa';

  @override
  String get uploadProgressResume => 'Återuppta';

  @override
  String get uploadProgressGoBack => 'Gå tillbaka';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Försök igen ($count kvar)';
  }

  @override
  String get uploadProgressDelete => 'Ta bort';

  @override
  String uploadProgressDaysAgo(int count) {
    return '$count d sedan';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '$count h sedan';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '$count min sedan';
  }

  @override
  String get uploadProgressJustNow => 'Just nu';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Laddar upp $percent %';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Pausad $percent %';
  }

  @override
  String get badgeExplanationClose => 'Stäng';

  @override
  String get badgeExplanationOriginalVineArchive => 'Originalt Vine-arkiv';

  @override
  String get badgeExplanationCameraProof => 'Kamerabevis';

  @override
  String get badgeExplanationAuthenticitySignals => 'Äkthetssignaler';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Den här videon är en originalvine som återhämtats från Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Innan Vine stängde 2017 arbetade ArchiveTeam och Internet Archive för att bevara miljontals vines för framtiden. Det här innehållet är en del av den historiska bevarandeinsatsen.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Originalstatistik: $loops loopar';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Läs mer om Vine-arkivets bevarande';

  @override
  String get badgeExplanationLearnProofmode =>
      'Läs mer om Proofmode-verifiering';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Läs mer om Divines äkthetssignaler';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspektera med ProofCheck-verktyget';

  @override
  String get badgeExplanationInspectMedia => 'Inspektera mediadetaljer';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Den här videons äkthet är verifierad med Proofmode-teknik.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Den här videon hostas på Divine och AI-detektering indikerar att den troligen är mänskligt gjord, men den inkluderar inga kryptografiska kameraverifieringsdata.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI-detektering indikerar att den här videon troligen är mänskligt gjord, men den inkluderar inga kryptografiska kameraverifieringsdata.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Den här videon hostas på Divine, men den inkluderar ännu inga kryptografiska kameraverifieringsdata.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Den här videon hostas utanför Divine och inkluderar inga kryptografiska kameraverifieringsdata.';

  @override
  String get badgeExplanationDeviceAttestation => 'Enhetsattestering';

  @override
  String get badgeExplanationPgpSignature => 'PGP-signatur';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Bevismanifest';

  @override
  String get badgeExplanationAiDetection => 'AI-detektering';

  @override
  String get badgeExplanationAiNotScanned => 'AI-skanning: Inte skannad än';

  @override
  String get badgeExplanationNoScanResults =>
      'Inga skanningsresultat tillgängliga än.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Kontrollera om AI-genererad';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage % sannolikhet att vara AI-genererad';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Skannad av: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verifierad av mänsklig moderator';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platina: Enhetens hårdvaruattestering, kryptografiska signaturer, Content Credentials (C2PA) och AI-skanning bekräftar mänskligt ursprung.';

  @override
  String get badgeExplanationVerificationGold =>
      'Guld: Fotograferad på en riktig enhet med hårdvaruattestering, kryptografiska signaturer och Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Silver: Kryptografiska signaturer bevisar att den här videon inte har ändrats sedan inspelningen.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Brons: Grundläggande metadatasignaturer finns.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Silver: AI-skanning bekräftar att den här videon troligen är människoskapad.';

  @override
  String get badgeExplanationNoVerification =>
      'Ingen verifieringsdata tillgänglig för den här videon.';

  @override
  String get shareMenuTitle => 'Dela video';

  @override
  String get shareMenuReportAiContent => 'Rapportera AI-innehåll';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Snabbrapportera misstänkt AI-genererat innehåll';

  @override
  String get shareMenuReportingAiContent => 'Rapporterar AI-innehåll...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Kunde inte rapportera innehåll: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Kunde inte rapportera AI-innehåll: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Videostatus';

  @override
  String get shareMenuViewAllLists => 'Visa alla listor →';

  @override
  String get shareMenuShareWith => 'Dela med';

  @override
  String get shareMenuShareViaOtherApps => 'Dela via andra appar';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Dela via andra appar eller kopiera länk';

  @override
  String get shareMenuSaveToGallery => 'Spara i galleriet';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Spara originalvideon i kamerarullen';

  @override
  String get shareMenuSaveWithWatermark => 'Spara med vattenmärke';

  @override
  String get shareMenuSaveVideo => 'Spara video';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Ladda ner med Divine-vattenmärke';

  @override
  String get shareMenuSaveVideoSubtitle => 'Spara videon i kamerarullen';

  @override
  String get shareMenuLists => 'Listor';

  @override
  String get shareMenuAddToList => 'Lägg till i lista';

  @override
  String get shareMenuAddToListSubtitle => 'Lägg till i dina kuraterade listor';

  @override
  String get shareMenuCreateNewList => 'Skapa ny lista';

  @override
  String get shareMenuCreateNewListSubtitle => 'Starta en ny kuraterad samling';

  @override
  String get shareMenuRemovedFromList => 'Borttagen från listan';

  @override
  String get shareMenuFailedToRemoveFromList =>
      'Kunde inte ta bort från listan';

  @override
  String get shareMenuBookmarks => 'Bokmärken';

  @override
  String get shareMenuAddToBookmarks => 'Lägg till i bokmärken';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Spara för senare visning';

  @override
  String get shareMenuAddToBookmarkSet => 'Lägg till i bokmärkessamling';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organisera i samlingar';

  @override
  String get shareMenuFollowSets => 'Följsamlingar';

  @override
  String get shareMenuCreateFollowSet => 'Skapa följsamling';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Starta en ny samling med den här kreatören';

  @override
  String get shareMenuAddToFollowSet => 'Lägg till i följsamling';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count följsamlingar tillgängliga';
  }

  @override
  String get peopleListsAddToList => 'Add to list';

  @override
  String get peopleListsAddToListSubtitle =>
      'Put this creator in one of your lists';

  @override
  String get peopleListsSheetTitle => 'Add to list';

  @override
  String get peopleListsEmptyTitle => 'No lists yet';

  @override
  String get peopleListsEmptySubtitle =>
      'Create a list to start grouping people.';

  @override
  String get peopleListsCreateList => 'Create list';

  @override
  String get peopleListsNewListTitle => 'New list';

  @override
  String get peopleListsRouteTitle => 'People list';

  @override
  String get peopleListsListNameLabel => 'List name';

  @override
  String get peopleListsListNameHint => 'Close friends';

  @override
  String get peopleListsCreateButton => 'Create';

  @override
  String get peopleListsAddPeopleTitle => 'Add people';

  @override
  String get peopleListsAddPeopleTooltip => 'Add people';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Add people to list';

  @override
  String get peopleListsListNotFoundTitle => 'List not found';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'List not found. It may have been deleted.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'This list may have been deleted.';

  @override
  String get peopleListsNoPeopleTitle => 'No people in this list';

  @override
  String get peopleListsNoPeopleSubtitle => 'Add some people to get started';

  @override
  String get peopleListsNoVideosTitle => 'No videos yet';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videos from list members will appear here';

  @override
  String get peopleListsNoVideosAvailable => 'No videos available';

  @override
  String get peopleListsFailedToLoadVideos => 'Failed to load videos';

  @override
  String get peopleListsVideoNotAvailable => 'Video not available';

  @override
  String get peopleListsBackToGridTooltip => 'Back to grid';

  @override
  String get peopleListsErrorLoadingVideos => 'Error loading videos';

  @override
  String get peopleListsNoPeopleToAdd => 'No people available to add.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Add to $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Search people';

  @override
  String get peopleListsAddPeopleError =>
      'Couldn\'t load people. Please try again.';

  @override
  String get peopleListsAddPeopleRetry => 'Try again';

  @override
  String get peopleListsAddButton => 'Add';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Add $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lists',
      one: 'In 1 list',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Remove $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'They will be removed from this list.';

  @override
  String get peopleListsRemove => 'Remove';

  @override
  String peopleListsRemovedFromList(String name) {
    return 'Removed $name from list';
  }

  @override
  String get peopleListsUndo => 'Undo';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profile for $name. Long press to remove.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'View profile for $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Tillagd i bokmärken!';

  @override
  String get shareMenuFailedToAddBookmark => 'Kunde inte lägga till bokmärket';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Skapade listan \"$name\" och la till videon';
  }

  @override
  String get shareMenuManageContent => 'Hantera innehåll';

  @override
  String get shareMenuEditVideo => 'Redigera video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Uppdatera titel, beskrivning och hashtags';

  @override
  String get shareMenuDeleteVideo => 'Ta bort video';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Ta bort det här innehållet permanent';

  @override
  String get shareMenuDeleteWarning =>
      'Detta skickar en borttagningsbegäran (NIP-09) till alla reler. Vissa reler kan fortfarande behålla innehållet.';

  @override
  String get shareMenuVideoInTheseLists => 'Videon finns i de här listorna:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count videor';
  }

  @override
  String get shareMenuClose => 'Stäng';

  @override
  String get shareMenuDeleteConfirmation =>
      'Är du säker på att du vill ta bort den här videon?';

  @override
  String get shareMenuCancel => 'Avbryt';

  @override
  String get shareMenuDelete => 'Ta bort';

  @override
  String get shareMenuDeletingContent => 'Tar bort innehåll...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Kunde inte ta bort innehåll: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'Borttagningsbegäran skickad';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Borttagningen är inte redo än. Försök igen om en stund.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Du kan bara ta bort dina egna videor.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Logga in igen och försök ta bort.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Kunde inte signera borttagningsbegäran. Försök igen.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Kunde inte ta bort den här videon. Försök igen.';

  @override
  String get shareMenuFollowSetName => 'Namn på följsamling';

  @override
  String get shareMenuFollowSetNameHint => 't.ex. Kreatörer, Musiker osv.';

  @override
  String get shareMenuDescriptionOptional => 'Beskrivning (valfritt)';

  @override
  String get shareMenuCreate => 'Skapa';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Skapade följsamlingen \"$name\" och la till kreatören';
  }

  @override
  String get shareMenuDone => 'Klar';

  @override
  String get shareMenuEditTitle => 'Titel';

  @override
  String get shareMenuEditTitleHint => 'Ange videotitel';

  @override
  String get shareMenuEditDescription => 'Beskrivning';

  @override
  String get shareMenuEditDescriptionHint => 'Ange videobeskrivning';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'kommaseparerade, hashtags';

  @override
  String get shareMenuEditMetadataNote =>
      'Obs: Endast metadata kan redigeras. Själva videoinnehållet kan inte ändras.';

  @override
  String get shareMenuDeleting => 'Tar bort...';

  @override
  String get shareMenuUpdate => 'Uppdatera';

  @override
  String get shareMenuVideoUpdated => 'Videon uppdaterades';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Kunde inte uppdatera videon: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Kunde inte ta bort videon: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Ta bort video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Detta skickar en borttagningsbegäran till reler. Obs: Vissa reler kan fortfarande ha cachade kopior.';

  @override
  String get shareMenuVideoDeletionRequested => 'Videoborttagning begärd';

  @override
  String get shareMenuContentLabels => 'Innehållsetiketter';

  @override
  String get shareMenuAddContentLabels => 'Lägg till innehållsetiketter';

  @override
  String get shareMenuClearAll => 'Rensa alla';

  @override
  String get shareMenuCollaborators => 'Samarbetspartner';

  @override
  String get shareMenuAddCollaborator => 'Lägg till samarbetspartner';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Du och $name måste följa varandra för att du ska kunna lägga till dem som samarbetspartner.';
  }

  @override
  String get shareMenuLoading => 'Laddar...';

  @override
  String get shareMenuInspiredBy => 'Inspirerad av';

  @override
  String get shareMenuAddInspirationCredit => 'Lägg till inspirationskredit';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Den här kreatören kan inte refereras.';

  @override
  String get shareMenuUnknown => 'Okänd';

  @override
  String get shareMenuCreateBookmarkSet => 'Skapa bokmärkessamling';

  @override
  String get shareMenuSetName => 'Samlingsnamn';

  @override
  String get shareMenuSetNameHint => 't.ex. Favoriter, Titta senare osv.';

  @override
  String get shareMenuCreateNewSet => 'Skapa ny samling';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Starta en ny bokmärkessamling';

  @override
  String get shareMenuNoBookmarkSets =>
      'Inga bokmärkessamlingar än. Skapa din första!';

  @override
  String get shareMenuError => 'Fel';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Kunde inte läsa in bokmärkessamlingar';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Skapade \"$name\" och la till videon';
  }

  @override
  String get shareMenuUseThisSound => 'Använd det här ljudet';

  @override
  String get shareMenuOriginalSound => 'Originalljud';

  @override
  String get authSessionExpired => 'Din session har löpt ut. Logga in igen.';

  @override
  String get authSignInFailed => 'Kunde inte logga in. Försök igen.';

  @override
  String get localeAppLanguage => 'Appspråk';

  @override
  String get localeDeviceDefault => 'Enhetens standard';

  @override
  String get localeSelectLanguage => 'Välj språk';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Webbautentisering stöds inte i säkert läge. Använd mobilappen för säker nyckelhantering.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Autentiseringsintegrering misslyckades: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Oväntat fel: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Ange en bunker-URI';

  @override
  String get webAuthConnectTitle => 'Anslut till Divine';

  @override
  String get webAuthChooseMethod =>
      'Välj din föredragna Nostr-autentiseringsmetod';

  @override
  String get webAuthBrowserExtension => 'Webbläsartillägg';

  @override
  String get webAuthRecommended => 'REKOMMENDERAS';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Anslut till en fjärrsigner';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Klistra in från urklipp';

  @override
  String get webAuthConnectToBunker => 'Anslut till bunker';

  @override
  String get webAuthNewToNostr => 'Ny på Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installera ett webbläsartillägg som Alby eller nos2x för enklaste upplevelsen, eller använd nsec bunker för säker fjärrsignering.';

  @override
  String get soundsTitle => 'Ljud';

  @override
  String get soundsSearchHint => 'Sök ljud...';

  @override
  String get soundsPreviewUnavailable =>
      'Kan inte förhandsvisa ljud – inget ljud tillgängligt';

  @override
  String soundsPreviewFailed(String error) {
    return 'Kunde inte spela förhandsvisning: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Utvalda ljud';

  @override
  String get soundsTrendingSounds => 'Trendiga ljud';

  @override
  String get soundsAllSounds => 'Alla ljud';

  @override
  String get soundsSearchResults => 'Sökresultat';

  @override
  String get soundsNoSoundsAvailable => 'Inga ljud tillgängliga';

  @override
  String get soundsNoSoundsDescription =>
      'Ljud visas här när kreatörer delar ljud';

  @override
  String get soundsNoSoundsFound => 'Inga ljud hittades';

  @override
  String get soundsNoSoundsFoundDescription => 'Testa en annan sökterm';

  @override
  String get soundsFailedToLoad => 'Kunde inte läsa in ljud';

  @override
  String get soundsRetry => 'Försök igen';

  @override
  String get soundsScreenLabel => 'Ljudskärm';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Uppdatera';

  @override
  String get profileRefreshLabel => 'Uppdatera profil';

  @override
  String get profileMoreOptions => 'Fler alternativ';

  @override
  String profileBlockedUser(String name) {
    return 'Blockerade $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Avblockerade $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Slutade följa $name';
  }

  @override
  String profileError(String error) {
    return 'Fel: $error';
  }

  @override
  String get notificationsTabAll => 'Alla';

  @override
  String get notificationsTabLikes => 'Gillamarkeringar';

  @override
  String get notificationsTabComments => 'Kommentarer';

  @override
  String get notificationsTabFollows => 'Följare';

  @override
  String get notificationsTabReposts => 'Återpubliceringar';

  @override
  String get notificationsFailedToLoad => 'Kunde inte läsa in aviseringar';

  @override
  String get notificationsRetry => 'Försök igen';

  @override
  String get notificationsCheckingNew => 'kollar efter nya aviseringar';

  @override
  String get notificationsNoneYet => 'Inga aviseringar än';

  @override
  String notificationsNoneForType(String type) {
    return 'Inga $type-aviseringar';
  }

  @override
  String get notificationsEmptyDescription =>
      'När folk interagerar med ditt innehåll ser du det här';

  @override
  String get notificationsUnreadPrefix => 'Oläst avisering';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Visa ${displayName}s profil';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Visa profiler';

  @override
  String notificationsLoadingType(String type) {
    return 'Läser in $type-aviseringar...';
  }

  @override
  String get notificationsInviteSingular =>
      'Du har 1 inbjudan att dela med en vän!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Du har $count inbjudningar att dela med vänner!';
  }

  @override
  String get notificationsVideoNotFound => 'Videon hittades inte';

  @override
  String get notificationsVideoUnavailable => 'Videon är otillgänglig';

  @override
  String get notificationsFromNotification => 'Från avisering';

  @override
  String get feedFailedToLoadVideos => 'Kunde inte läsa in videor';

  @override
  String get feedRetry => 'Försök igen';

  @override
  String get feedNoFollowedUsers =>
      'Inga följda användare.\nFölj någon för att se deras videor här.';

  @override
  String get feedForYouEmpty =>
      'Ditt För dig-flöde är tomt.\nUtforska videor och följ kreatörer för att forma det.';

  @override
  String get feedFollowingEmpty =>
      'Inga videor från personer du följer än.\nHitta kreatörer du gillar och följ dem.';

  @override
  String get feedLatestEmpty => 'Inga nya videor än.\nTitta in igen snart.';

  @override
  String get feedExploreVideos => 'Upptäck videor';

  @override
  String get feedExternalVideoSlow => 'Extern video laddar långsamt';

  @override
  String get feedSkip => 'Hoppa över';

  @override
  String get uploadWaitingToUpload => 'Väntar på att laddas upp';

  @override
  String get uploadUploadingVideo => 'Laddar upp video';

  @override
  String get uploadProcessingVideo => 'Bearbetar video';

  @override
  String get uploadProcessingComplete => 'Bearbetning klar';

  @override
  String get uploadPublishedSuccessfully => 'Publicerad';

  @override
  String get uploadFailed => 'Uppladdning misslyckades';

  @override
  String get uploadRetrying => 'Försöker ladda upp igen';

  @override
  String get uploadPaused => 'Uppladdning pausad';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent % klart';
  }

  @override
  String get uploadQueuedMessage => 'Din video är i kö för uppladdning';

  @override
  String get uploadUploadingMessage => 'Laddar upp till servern...';

  @override
  String get uploadProcessingMessage =>
      'Bearbetar video – det här kan ta några minuter';

  @override
  String get uploadReadyToPublishMessage =>
      'Videon bearbetades och är redo att publiceras';

  @override
  String get uploadPublishedMessage => 'Videon publicerad till din profil';

  @override
  String get uploadFailedMessage => 'Uppladdning misslyckades – försök igen';

  @override
  String get uploadRetryingMessage => 'Försöker ladda upp igen...';

  @override
  String get uploadPausedMessage => 'Uppladdning pausad av användaren';

  @override
  String get uploadRetryButton => 'FÖRSÖK IGEN';

  @override
  String uploadRetryFailed(String error) {
    return 'Kunde inte försöka ladda upp igen: $error';
  }

  @override
  String get userSearchPrompt => 'Sök efter användare';

  @override
  String get userSearchNoResults => 'Inga användare hittades';

  @override
  String get userSearchFailed => 'Sökning misslyckades';

  @override
  String get userPickerSearchByName => 'Sök efter namn';

  @override
  String get userPickerFilterByNameHint => 'Filtrera efter namn...';

  @override
  String get userPickerSearchByNameHint => 'Sök efter namn...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name har redan lagts till';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Välj $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Ditt crew finns där ute';

  @override
  String get userPickerEmptyFollowListBody =>
      'Följ personer du vibbar med. När de följer tillbaka kan ni samarbeta.';

  @override
  String get userPickerGoBack => 'Gå tillbaka';

  @override
  String get userPickerTypeNameToSearch => 'Skriv ett namn för att söka';

  @override
  String get userPickerUnavailable =>
      'Användarsökning är inte tillgänglig. Försök igen senare.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Sökningen misslyckades. Försök igen.';

  @override
  String get forgotPasswordTitle => 'Återställ lösenord';

  @override
  String get forgotPasswordDescription =>
      'Ange din e-postadress så skickar vi en länk för att återställa ditt lösenord.';

  @override
  String get forgotPasswordEmailLabel => 'E-postadress';

  @override
  String get forgotPasswordCancel => 'Avbryt';

  @override
  String get forgotPasswordSendLink => 'E-posta återställningslänk';

  @override
  String get ageVerificationContentWarning => 'Innehållsvarning';

  @override
  String get ageVerificationTitle => 'Åldersverifiering';

  @override
  String get ageVerificationAdultDescription =>
      'Det här innehållet har flaggats som potentiellt innehållande vuxenmaterial. Du måste vara 18 eller äldre för att se det.';

  @override
  String get ageVerificationCreationDescription =>
      'För att använda kameran och skapa innehåll måste du vara minst 16 år gammal.';

  @override
  String get ageVerificationAdultQuestion => 'Är du 18 år eller äldre?';

  @override
  String get ageVerificationCreationQuestion => 'Är du 16 år eller äldre?';

  @override
  String get ageVerificationNo => 'Nej';

  @override
  String get ageVerificationYes => 'Ja';

  @override
  String get shareLinkCopied => 'Länk kopierad till urklipp';

  @override
  String get shareFailedToCopy => 'Kunde inte kopiera länken';

  @override
  String get shareVideoSubject => 'Kolla in den här videon på Divine';

  @override
  String get shareFailedToShare => 'Kunde inte dela';

  @override
  String get shareVideoTitle => 'Dela video';

  @override
  String get shareToApps => 'Dela till appar';

  @override
  String get shareToAppsSubtitle => 'Dela via meddelanden, sociala appar';

  @override
  String get shareCopyWebLink => 'Kopiera webblänk';

  @override
  String get shareCopyWebLinkSubtitle => 'Kopiera delbar webblänk';

  @override
  String get shareCopyNostrLink => 'Kopiera Nostr-länk';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Kopiera nevent-länk för Nostr-klienter';

  @override
  String get navHome => 'Hem';

  @override
  String get navExplore => 'Upptäck';

  @override
  String get navInbox => 'Inkorg';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSearch => 'Sök';

  @override
  String get navSearchTooltip => 'Sök';

  @override
  String get navMyProfile => 'Min profil';

  @override
  String get navNotifications => 'Aviseringar';

  @override
  String get navOpenCamera => 'Öppna kamera';

  @override
  String get navUnknown => 'Okänd';

  @override
  String get navExploreClassics => 'Klassiker';

  @override
  String get navExploreNewVideos => 'Nya videor';

  @override
  String get navExploreTrending => 'Trendar';

  @override
  String get navExploreForYou => 'För dig';

  @override
  String get navExploreLists => 'Listor';

  @override
  String get routeErrorTitle => 'Fel';

  @override
  String get routeInvalidHashtag => 'Ogiltig hashtag';

  @override
  String get routeInvalidConversationId => 'Ogiltigt konversations-ID';

  @override
  String get routeInvalidRequestId => 'Ogiltigt förfrågans-ID';

  @override
  String get routeInvalidListId => 'Ogiltigt list-ID';

  @override
  String get routeInvalidUserId => 'Ogiltigt användar-ID';

  @override
  String get routeInvalidVideoId => 'Ogiltigt video-ID';

  @override
  String get routeInvalidSoundId => 'Ogiltigt ljud-ID';

  @override
  String get routeInvalidCategory => 'Ogiltig kategori';

  @override
  String get routeNoVideosToDisplay => 'Inga videor att visa';

  @override
  String get routeInvalidProfileId => 'Ogiltigt profil-ID';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Supportcenter';

  @override
  String get supportContactSupport => 'Kontakta support';

  @override
  String get supportContactSupportSubtitle =>
      'Starta en konversation eller visa tidigare meddelanden';

  @override
  String get supportReportBug => 'Rapportera en bugg';

  @override
  String get supportReportBugSubtitle => 'Tekniska problem med appen';

  @override
  String get supportRequestFeature => 'Begär en funktion';

  @override
  String get supportRequestFeatureSubtitle =>
      'Föreslå en förbättring eller ny funktion';

  @override
  String get supportSaveLogs => 'Spara loggar';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportera loggar till fil för manuell sändning';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Vanliga frågor och svar';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle => 'Läs om verifiering och äkthet';

  @override
  String get supportLoginRequired => 'Logga in för att kontakta supporten';

  @override
  String get supportExportingLogs => 'Exporterar loggar...';

  @override
  String get supportExportLogsFailed => 'Kunde inte exportera loggar';

  @override
  String get supportChatNotAvailable => 'Supportchatten är inte tillgänglig';

  @override
  String get supportCouldNotOpenMessages =>
      'Kunde inte öppna supportmeddelanden';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Kunde inte öppna $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Fel vid öppning av $pageName: $error';
  }

  @override
  String get reportTitle => 'Rapportera innehåll';

  @override
  String get reportWhyReporting => 'Varför rapporterar du det här innehållet?';

  @override
  String get reportPolicyNotice =>
      'Divine agerar på innehållsrapporter inom 24 timmar genom att ta bort innehållet och stänga av användaren som tillhandahöll det felaktiga innehållet.';

  @override
  String get reportAdditionalDetails => 'Ytterligare detaljer (valfritt)';

  @override
  String get reportBlockUser => 'Blockera den här användaren';

  @override
  String get reportCancel => 'Avbryt';

  @override
  String get reportSubmit => 'Rapportera';

  @override
  String get reportSelectReason =>
      'Välj en anledning för att rapportera det här innehållet';

  @override
  String get reportReasonSpam => 'Skräppost eller ovälkommet innehåll';

  @override
  String get reportReasonHarassment => 'Trakasserier, mobbning eller hot';

  @override
  String get reportReasonViolence => 'Våldsamt eller extremistiskt innehåll';

  @override
  String get reportReasonSexualContent => 'Sexuellt eller vuxeninnehåll';

  @override
  String get reportReasonCopyright => 'Upphovsrättsbrott';

  @override
  String get reportReasonFalseInfo => 'Felaktig information';

  @override
  String get reportReasonCsam => 'Brott mot barns säkerhet';

  @override
  String get reportReasonAiGenerated => 'AI-genererat innehåll';

  @override
  String get reportReasonOther => 'Annat policybrott';

  @override
  String reportFailed(Object error) {
    return 'Kunde inte rapportera innehåll: $error';
  }

  @override
  String get reportReceivedTitle => 'Rapport mottagen';

  @override
  String get reportReceivedThankYou =>
      'Tack för att du hjälper till att hålla Divine säkert.';

  @override
  String get reportReceivedReviewNotice =>
      'Vårt team granskar din rapport och vidtar lämpliga åtgärder. Du kan få uppdateringar via direktmeddelande.';

  @override
  String get reportLearnMore => 'Läs mer';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Stäng';

  @override
  String get listAddToList => 'Lägg till i lista';

  @override
  String listVideoCount(int count) {
    return '$count videor';
  }

  @override
  String get listNewList => 'Ny lista';

  @override
  String get listDone => 'Klar';

  @override
  String get listErrorLoading => 'Fel vid inläsning av listor';

  @override
  String listRemovedFrom(String name) {
    return 'Borttagen från $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Tillagd i $name';
  }

  @override
  String get listCreateNewList => 'Skapa ny lista';

  @override
  String get listNewPeopleList => 'Ny personlista';

  @override
  String get listCollaboratorsNone => 'Inga';

  @override
  String get listAddCollaboratorTitle => 'Lägg till medarbetare';

  @override
  String get listCollaboratorSearchHint => 'Sök i diVine...';

  @override
  String get listNameLabel => 'Listnamn';

  @override
  String get listDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get listPublicList => 'Publik lista';

  @override
  String get listPublicListSubtitle => 'Andra kan följa och se den här listan';

  @override
  String get listCancel => 'Avbryt';

  @override
  String get listCreate => 'Skapa';

  @override
  String get listCreateFailed => 'Kunde inte skapa listan';

  @override
  String get keyManagementTitle => 'Nostr-nycklar';

  @override
  String get keyManagementWhatAreKeys => 'Vad är Nostr-nycklar?';

  @override
  String get keyManagementExplanation =>
      'Din Nostr-identitet är ett kryptografiskt nyckelpar:\n\n• Din publika nyckel (npub) är som ditt användarnamn – dela den fritt\n• Din privata nyckel (nsec) är som ditt lösenord – håll den hemlig!\n\nDin nsec låter dig nå ditt konto i vilken Nostr-app som helst.';

  @override
  String get keyManagementImportTitle => 'Importera befintlig nyckel';

  @override
  String get keyManagementImportSubtitle =>
      'Har du redan ett Nostr-konto? Klistra in din privata nyckel (nsec) för att nå det här.';

  @override
  String get keyManagementImportButton => 'Importera nyckel';

  @override
  String get keyManagementImportWarning =>
      'Detta ersätter din nuvarande nyckel!';

  @override
  String get keyManagementBackupTitle => 'Säkerhetskopiera din nyckel';

  @override
  String get keyManagementBackupSubtitle =>
      'Spara din privata nyckel (nsec) för att använda ditt konto i andra Nostr-appar.';

  @override
  String get keyManagementCopyNsec => 'Kopiera min privata nyckel (nsec)';

  @override
  String get keyManagementNeverShare => 'Dela aldrig din nsec med någon!';

  @override
  String get keyManagementPasteKey => 'Klistra in din privata nyckel';

  @override
  String get keyManagementInvalidFormat =>
      'Ogiltigt nyckelformat. Måste börja med \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importera den här nyckeln?';

  @override
  String get keyManagementConfirmImportBody =>
      'Detta ersätter din nuvarande identitet med den importerade.\n\nDin nuvarande nyckel går förlorad om du inte säkerhetskopierade den först.';

  @override
  String get keyManagementImportConfirm => 'Importera';

  @override
  String get keyManagementImportSuccess => 'Nyckeln importerades!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Kunde inte importera nyckeln: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Privat nyckel kopierad till urklipp!\n\nFörvara den på ett säkert ställe.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Kunde inte exportera nyckeln: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Sparad i kamerarullen';

  @override
  String get saveOriginalShare => 'Dela';

  @override
  String get saveOriginalDone => 'Klar';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Fotoåtkomst behövs';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'För att spara videor, tillåt fotoåtkomst i Inställningar.';

  @override
  String get saveOriginalOpenSettings => 'Öppna inställningar';

  @override
  String get saveOriginalNotNow => 'Inte nu';

  @override
  String get cameraPermissionNotNow => 'Inte nu';

  @override
  String get saveOriginalDownloadFailed => 'Nedladdning misslyckades';

  @override
  String get saveOriginalDismiss => 'Avfärda';

  @override
  String get saveOriginalDownloadingVideo => 'Laddar ner video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Sparar i kamerarullen';

  @override
  String get saveOriginalFetchingVideo => 'Hämtar videon från nätverket...';

  @override
  String get saveOriginalSavingVideo =>
      'Sparar originalvideon i din kamerarulle...';

  @override
  String get soundTitle => 'Ljud';

  @override
  String get soundOriginalSound => 'Originalljud';

  @override
  String get soundVideosUsingThisSound => 'Videor som använder det här ljudet';

  @override
  String get soundSourceVideo => 'Källvideo';

  @override
  String get soundNoVideosYet => 'Inga videor än';

  @override
  String get soundBeFirstToUse => 'Var först med att använda det här ljudet!';

  @override
  String get soundFailedToLoadVideos => 'Kunde inte läsa in videor';

  @override
  String get soundRetry => 'Försök igen';

  @override
  String get soundVideosUnavailable => 'Videor otillgängliga';

  @override
  String get soundCouldNotLoadDetails => 'Kunde inte läsa in videodetaljer';

  @override
  String get soundPreview => 'Förhandsvisning';

  @override
  String get soundStop => 'Stoppa';

  @override
  String get soundUseSound => 'Använd ljud';

  @override
  String get soundNoVideoCount => 'Inga videor än';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count videor';
  }

  @override
  String get soundUnableToPreview =>
      'Kan inte förhandsvisa ljud – inget ljud tillgängligt';

  @override
  String soundPreviewFailed(Object error) {
    return 'Kunde inte spela förhandsvisning: $error';
  }

  @override
  String get soundViewSource => 'Visa källa';

  @override
  String get soundCloseTooltip => 'Stäng';

  @override
  String get exploreNotExploreRoute => 'Inte en upptäcktsrutt';

  @override
  String get legalTitle => 'Juridik';

  @override
  String get legalTermsOfService => 'Användarvillkor';

  @override
  String get legalTermsOfServiceSubtitle => 'Användningsvillkor';

  @override
  String get legalPrivacyPolicy => 'Integritetspolicy';

  @override
  String get legalPrivacyPolicySubtitle => 'Hur vi hanterar dina data';

  @override
  String get legalSafetyStandards => 'Säkerhetsstandarder';

  @override
  String get legalSafetyStandardsSubtitle => 'Communityriktlinjer och säkerhet';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Upphovsrätt och borttagningspolicy';

  @override
  String get legalOpenSourceLicenses => 'Öppen källkod-licenser';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Tillskrivningar till tredjepartspaket';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Kunde inte öppna $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Fel vid öppning av $pageName: $error';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Äventyr';

  @override
  String get categoryAnimals => 'Djur';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Arkitektur';

  @override
  String get categoryArt => 'Konst';

  @override
  String get categoryAutomotive => 'Bilar';

  @override
  String get categoryAwardShow => 'Prisutdelning';

  @override
  String get categoryAwards => 'Priser';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Skönhet';

  @override
  String get categoryBeverage => 'Dryck';

  @override
  String get categoryCars => 'Bilar';

  @override
  String get categoryCelebration => 'Firande';

  @override
  String get categoryCelebrities => 'Kändisar';

  @override
  String get categoryCelebrity => 'Kändis';

  @override
  String get categoryCityscape => 'Stadsbild';

  @override
  String get categoryComedy => 'Komedi';

  @override
  String get categoryConcert => 'Konsert';

  @override
  String get categoryCooking => 'Matlagning';

  @override
  String get categoryCostume => 'Kostym';

  @override
  String get categoryCrafts => 'Hantverk';

  @override
  String get categoryCrime => 'Brott';

  @override
  String get categoryCulture => 'Kultur';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'Gör det själv';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Utbildning';

  @override
  String get categoryEmotional => 'Känslosam';

  @override
  String get categoryEmotions => 'Känslor';

  @override
  String get categoryEntertainment => 'Underhållning';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Familj';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Träning';

  @override
  String get categoryFood => 'Mat';

  @override
  String get categoryFootball => 'Amerikansk fotboll';

  @override
  String get categoryFurniture => 'Möbler';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Skötsel';

  @override
  String get categoryGuitar => 'Gitarr';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Hälsa';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Semester';

  @override
  String get categoryHome => 'Hem';

  @override
  String get categoryHomeImprovement => 'Renovering';

  @override
  String get categoryHorror => 'Skräck';

  @override
  String get categoryHospital => 'Sjukhus';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Inredning';

  @override
  String get categoryInterview => 'Intervju';

  @override
  String get categoryKids => 'Barn';

  @override
  String get categoryLifestyle => 'Livsstil';

  @override
  String get categoryMagic => 'Magi';

  @override
  String get categoryMakeup => 'Smink';

  @override
  String get categoryMedical => 'Medicin';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryMystery => 'Mysterium';

  @override
  String get categoryNature => 'Natur';

  @override
  String get categoryNews => 'Nyheter';

  @override
  String get categoryOutdoor => 'Utomhus';

  @override
  String get categoryParty => 'Fest';

  @override
  String get categoryPeople => 'Människor';

  @override
  String get categoryPerformance => 'Uppträdande';

  @override
  String get categoryPets => 'Husdjur';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Skämt';

  @override
  String get categoryPranks => 'Skämt';

  @override
  String get categoryRealityShow => 'Reality-show';

  @override
  String get categoryRelationship => 'Relation';

  @override
  String get categoryRelationships => 'Relationer';

  @override
  String get categoryRomance => 'Romantik';

  @override
  String get categorySchool => 'Skola';

  @override
  String get categoryScienceFiction => 'Science fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboard';

  @override
  String get categorySkincare => 'Hudvård';

  @override
  String get categorySoccer => 'Fotboll';

  @override
  String get categorySocialGathering => 'Sammankomst';

  @override
  String get categorySocialMedia => 'Sociala medier';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talkshow';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Teknologi';

  @override
  String get categoryTelevision => 'TV';

  @override
  String get categoryToys => 'Leksaker';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Resor';

  @override
  String get categoryUrban => 'Urbant';

  @override
  String get categoryViolence => 'Våld';

  @override
  String get categoryVlog => 'Vlogg';

  @override
  String get categoryVlogging => 'Vloggning';

  @override
  String get categoryWrestling => 'Brottning';

  @override
  String get profileSetupUploadSuccess => 'Profilbilden laddades upp!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName rapporterad';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName blockerad';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName avblockerad';
  }

  @override
  String get inboxRemovedConversation => 'Konversation borttagen';

  @override
  String get inboxEmptyTitle => 'Inga meddelanden än';

  @override
  String get inboxEmptySubtitle => '+-knappen bits inte.';

  @override
  String get inboxActionMute => 'Tysta konversation';

  @override
  String inboxActionReport(String displayName) {
    return 'Rapportera $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Blockera $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Avblockera $displayName';
  }

  @override
  String get inboxActionRemove => 'Ta bort konversation';

  @override
  String get inboxRemoveConfirmTitle => 'Ta bort konversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Detta tar bort din konversation med $displayName. Denna åtgärd kan inte ångras.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Ta bort';

  @override
  String get inboxConversationMuted => 'Konversation tystad';

  @override
  String get inboxConversationUnmuted => 'Konversation inte tystad';

  @override
  String get inboxCollabInviteCardTitle => 'Inbjudan att samarbeta';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role i det här inlägget';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'Acceptera';

  @override
  String get inboxCollabInviteIgnoreButton => 'Ignorera';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Accepterad';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorerad';

  @override
  String get inboxCollabInviteAcceptError =>
      'Det gick inte att acceptera. Försök igen.';

  @override
  String get inboxCollabInviteSentStatus => 'Inbjudan skickad';

  @override
  String get inboxConversationCollabInvitePreview => 'Inbjudan att samarbeta';

  @override
  String get reportDialogCancel => 'Avbryt';

  @override
  String get reportDialogReport => 'Rapportera';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titel: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Kunde inte uppdatera prenumerationen: $error';
  }

  @override
  String get commonRetry => 'Försök igen';

  @override
  String get commonNext => 'Nästa';

  @override
  String get commonDelete => 'Radera';

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get videoMetadataTags => 'Taggar';

  @override
  String get videoMetadataExpiration => 'Utgångsdatum';

  @override
  String get videoMetadataExpirationNotExpire => 'Löper inte ut';

  @override
  String get videoMetadataExpirationOneDay => '1 dag';

  @override
  String get videoMetadataExpirationOneWeek => '1 vecka';

  @override
  String get videoMetadataExpirationOneMonth => '1 månad';

  @override
  String get videoMetadataExpirationOneYear => '1 år';

  @override
  String get videoMetadataExpirationOneDecade => '1 decennium';

  @override
  String get videoMetadataContentWarnings => 'Innehållsvarningar';

  @override
  String get videoEditorStickers => 'Klistermärken';

  @override
  String get trendingTitle => 'Trendande';

  @override
  String get proofmodeCheckAiGenerated => 'Kontrollera om AI-genererat';

  @override
  String get libraryDeleteConfirm => 'Radera';

  @override
  String get libraryWebUnavailableHeadline => 'Biblioteket finns i mobilappen';

  @override
  String get libraryWebUnavailableDescription =>
      'Utkast och klipp sparas på enheten — öppna Divine i mobilen för att hantera dem.';

  @override
  String get libraryTabDrafts => 'Utkast';

  @override
  String get libraryTabClips => 'Klipp';

  @override
  String get librarySaveToCameraRollTooltip => 'Spara i kamerarullen';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Ta bort valda klipp';

  @override
  String get libraryDeleteClipsTitle => 'Ta bort klipp';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# valda klipp',
      one: '# valt klipp',
    );
    return 'Vill du ta bort $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Det går inte att ångra. Videofilerna tas bort permanent från enheten.';

  @override
  String get libraryPreparingVideo => 'Förbereder video...';

  @override
  String get libraryCreateVideo => 'Skapa video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp',
      one: '1 klipp',
    );
    return '$_temp0 sparade i $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount sparade, $failureCount misslyckades';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Behörighet nekad för $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp borttagna',
      one: '1 klipp borttaget',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Det gick inte att ladda utkast';

  @override
  String get libraryCouldNotLoadClips => 'Det gick inte att ladda klipp';

  @override
  String get libraryOpenErrorDescription =>
      'Något gick fel när biblioteket öppnades. Försök igen.';

  @override
  String get libraryNoDraftsYetTitle => 'Inga utkast än';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videor du sparar som utkast visas här';

  @override
  String get libraryNoClipsYetTitle => 'Inga klipp än';

  @override
  String get libraryNoClipsYetSubtitle => 'Dina inspelade videoklipp visas här';

  @override
  String get libraryDraftDeletedSnackbar => 'Utkast borttaget';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Det gick inte att ta bort utkastet';

  @override
  String get libraryDraftActionPost => 'Publicera';

  @override
  String get libraryDraftActionEdit => 'Redigera';

  @override
  String get libraryDraftActionDelete => 'Ta bort utkast';

  @override
  String get libraryDeleteDraftTitle => 'Ta bort utkast';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Vill du ta bort \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Ta bort klipp';

  @override
  String get libraryDeleteClipMessage => 'Vill du ta bort det här klippet?';

  @override
  String get libraryClipSelectionTitle => 'Klipp';

  @override
  String librarySecondsRemaining(String seconds) {
    return '${seconds}s kvar';
  }

  @override
  String get libraryAddClips => 'Lägg till';

  @override
  String get libraryRecordVideo => 'Spela in video';

  @override
  String get routerInvalidCreator => 'Ogiltig skapare';

  @override
  String get routerInvalidHashtagRoute => 'Ogiltig hashtagrutt';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Kunde inte ladda videor';

  @override
  String get categoriesCouldNotLoadCategories => 'Kunde inte ladda kategorier';

  @override
  String get notificationFollowBack => 'Följ tillbaka';

  @override
  String get followingFailedToLoadList => 'Kunde inte ladda följer-listan';

  @override
  String get followersFailedToLoadList => 'Kunde inte ladda följarlistan';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Kunde inte spara inställningarna: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Kunde inte uppdatera crosspost-inställningen';

  @override
  String get invitesTitle => 'Bjud in vänner';

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
  String get searchSomethingWentWrong => 'Något gick fel';

  @override
  String get searchTryAgain => 'Försök igen';

  @override
  String get searchForLists => 'Sök efter listor';

  @override
  String get searchFindCuratedVideoLists => 'Hitta kurerade videolistor';

  @override
  String get searchEnterQuery => 'Skriv en sökterm';

  @override
  String get searchDiscoverSomethingInteresting => 'Upptäck något intressant';

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
  String get searchListsSectionHeader => 'Listor';

  @override
  String get searchListsLoadingLabel => 'Laddar listresultat';

  @override
  String get cameraAgeRestriction =>
      'Du måste vara 16 år eller äldre för att skapa innehåll';

  @override
  String get featureRequestCancel => 'Avbryt';

  @override
  String keyImportError(String error) {
    return 'Fel: $error';
  }

  @override
  String get timeNow => 'nu';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}t';
  }

  @override
  String timeShortDays(int count) {
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}v';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}må';
  }

  @override
  String timeShortYears(int count) {
    return '$countå';
  }

  @override
  String get timeVerboseNow => 'Nu';

  @override
  String timeAgo(String time) {
    return '$time sedan';
  }

  @override
  String get timeToday => 'Idag';

  @override
  String get timeYesterday => 'Igår';

  @override
  String get timeJustNow => 'nyss';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min sedan';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}t sedan';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d sedan';
  }

  @override
  String get draftTimeJustNow => 'Nyss';

  @override
  String get contentLabelNudity => 'Nakenhet';

  @override
  String get contentLabelSexualContent => 'Sexuellt innehåll';

  @override
  String get contentLabelPornography => 'Pornografi';

  @override
  String get contentLabelGraphicMedia => 'Grafiskt innehåll';

  @override
  String get contentLabelViolence => 'Våld';

  @override
  String get contentLabelSelfHarm => 'Självskada/Självmord';

  @override
  String get contentLabelDrugUse => 'Droganvändning';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tobak/Rökning';

  @override
  String get contentLabelGambling => 'Spelande';

  @override
  String get contentLabelProfanity => 'Svordomar';

  @override
  String get contentLabelHateSpeech => 'Hatretorik';

  @override
  String get contentLabelHarassment => 'Trakasserier';

  @override
  String get contentLabelFlashingLights => 'Blinkande ljus';

  @override
  String get contentLabelAiGenerated => 'AI-genererat';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Bedrägeri';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Vilseledande';

  @override
  String get contentLabelSensitiveContent => 'Känsligt innehåll';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName gillade din video';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName kommenterade din video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName började följa dig';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName nämnde dig';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName delade din video';
  }

  @override
  String get notificationRepliedToYourComment => 'svarade på din kommentar';

  @override
  String get notificationAndConnector => 'och';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count till',
      one: '1 till',
    );
    return '$_temp0';
  }

  @override
  String get commentReplyToPrefix => 'Sv:';

  @override
  String get draftUntitled => 'Namnlös';

  @override
  String get contentWarningNone => 'Ingen';

  @override
  String get textBackgroundNone => 'Ingen';

  @override
  String get textBackgroundSolid => 'Heltäckande';

  @override
  String get textBackgroundHighlight => 'Markering';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Vänster';

  @override
  String get textAlignRight => 'Höger';

  @override
  String get textAlignCenter => 'Centrera';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kameran stöds inte på webben än';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Kamerainspelning och videoinspelning är ännu inte tillgängliga i webbversionen.';

  @override
  String get cameraPermissionBackToFeed => 'Tillbaka till flödet';

  @override
  String get cameraPermissionErrorTitle => 'Behörighetsfel';

  @override
  String get cameraPermissionErrorDescription =>
      'Något gick fel när behörigheterna kontrollerades.';

  @override
  String get cameraPermissionRetry => 'Försök igen';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Tillåt åtkomst till kamera och mikrofon';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Detta låter dig spela in och redigera videor direkt i appen, inget mer.';

  @override
  String get cameraPermissionContinue => 'Fortsätt';

  @override
  String get cameraPermissionGoToSettings => 'Gå till inställningar';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Varför sex sekunder?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Snabba klipp skapar utrymme för spontanitet. Formatet på 6 sekunder hjälper dig att fånga äkta ögonblick när de händer.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Jag fattar!';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Vi hittade ett pågående arbete';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Vill du fortsätta där du slutade?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ja, fortsätt';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Nej, starta en ny video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Det gick inte att återställa ditt utkast';

  @override
  String get videoRecorderStopRecordingTooltip => 'Stoppa inspelning';

  @override
  String get videoRecorderStartRecordingTooltip => 'Starta inspelning';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Spelar in. Tryck var som helst för att stoppa';

  @override
  String get videoRecorderTapToStartLabel =>
      'Tryck var som helst för att starta inspelningen';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Ta bort senaste klippet';

  @override
  String get videoRecorderSwitchCameraLabel => 'Byt kamera';

  @override
  String get videoRecorderToggleGridLabel => 'Växla rutnät';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Växla spökram';

  @override
  String get videoRecorderGhostFrameEnabled => 'Spökram aktiverad';

  @override
  String get videoRecorderGhostFrameDisabled => 'Spökram inaktiverad';

  @override
  String get videoRecorderClipDeletedMessage => 'Klipp borttaget';

  @override
  String get videoRecorderCloseLabel => 'Stäng videoinspelaren';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Fortsätt till videoredigeraren';

  @override
  String get videoRecorderCaptureCloseLabel => 'Stäng';

  @override
  String get videoRecorderCaptureNextLabel => 'Nästa';

  @override
  String get videoRecorderToggleFlashLabel => 'Växla blixt';

  @override
  String get videoRecorderCycleTimerLabel => 'Växla timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Växla bildförhållande';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Klippbibliotek, inga klipp';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Öppna klippbibliotek, $clipCount klipp',
      one: 'Öppna klippbibliotek, 1 klipp',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Kamera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Öppna kamera';

  @override
  String get videoEditorLibraryLabel => 'Bibliotek';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Rita';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorAudioLabel => 'Ljud';

  @override
  String get videoEditorVolumeLabel => 'Volym';

  @override
  String get videoEditorAddTitle => 'Lägg till';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Öppna bibliotek';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Öppna ljudredigerare';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Öppna textredigerare';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Öppna ritredigerare';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Öppna filtereditor';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Öppna klistermärkesredigerare';

  @override
  String get videoEditorSaveDraftTitle => 'Spara ditt utkast?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Spara dina redigeringar till senare, eller kasta dem och lämna redigeraren.';

  @override
  String get videoEditorSaveDraftButton => 'Spara utkast';

  @override
  String get videoEditorDiscardChangesButton => 'Kasta ändringar';

  @override
  String get videoEditorKeepEditingButton => 'Fortsätt redigera';

  @override
  String get videoEditorDeleteLayerDropZone => 'Släppzon för att ta bort lager';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Släpp för att ta bort lager';

  @override
  String get videoEditorDoneLabel => 'Klar';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Spela upp eller pausa video';

  @override
  String get videoEditorCropSemanticLabel => 'Beskär';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Kan inte dela klipp medan det bearbetas. Vänta.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Ogiltig delningsposition. Båda klippen måste vara minst $minDurationMs ms långa.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Lägg till klipp från bibliotek';

  @override
  String get videoEditorSaveSelectedClip => 'Spara valt klipp';

  @override
  String get videoEditorSplitClip => 'Dela klipp';

  @override
  String get videoEditorSaveClip => 'Spara klipp';

  @override
  String get videoEditorDeleteClip => 'Ta bort klipp';

  @override
  String get videoEditorClipSavedSuccess => 'Klipp sparat i bibliotek';

  @override
  String get videoEditorClipSaveFailed => 'Det gick inte att spara klipp';

  @override
  String get videoEditorClipDeleted => 'Klipp borttaget';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Färgväljare';

  @override
  String get videoEditorUndoSemanticLabel => 'Ångra';

  @override
  String get videoEditorRedoSemanticLabel => 'Gör om';

  @override
  String get videoEditorTextColorSemanticLabel => 'Textfärg';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Textjustering';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Textbakgrund';

  @override
  String get videoEditorFontSemanticLabel => 'Typsnitt';

  @override
  String get videoEditorNoStickersFound => 'Inga stickers hittades';

  @override
  String get videoEditorNoStickersAvailable => 'Inga stickers tillgängliga';

  @override
  String get videoEditorFailedLoadStickers =>
      'Det gick inte att ladda stickers';

  @override
  String get videoEditorAdjustVolumeTitle => 'Justera volym';

  @override
  String get videoEditorRecordedAudioLabel => 'Inspelat ljud';

  @override
  String get videoEditorCustomAudioLabel => 'Eget ljud';

  @override
  String get videoEditorPlaySemanticLabel => 'Spela';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausa';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Stäng av ljud';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Sätt på ljud';

  @override
  String get videoEditorDeleteLabel => 'Ta bort';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Ta bort valt objekt';

  @override
  String get videoEditorEditLabel => 'Redigera';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Redigera valt objekt';

  @override
  String get videoEditorDuplicateLabel => 'Duplicera';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicera valt objekt';

  @override
  String get videoEditorSplitLabel => 'Dela';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Dela valt klipp';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Avsluta redigering av tidslinje';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'Spela förhandsvisning';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Pausa förhandsvisning';

  @override
  String get videoEditorAudioUntitledSound => 'Namnlöst ljud';

  @override
  String get videoEditorAudioUntitled => 'Namnlös';

  @override
  String get videoEditorAudioAddAudio => 'Lägg till ljud';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Inga ljud tillgängliga';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Ljud visas här när skapare delar ljud';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Det gick inte att ladda ljud';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Välj ljudsegmentet för din video';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Gemenskap';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Pilverktyg';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Suddverktyg';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Markeringsverktyg';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Pennverktyg';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Ordna om lager $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Håll ned för att ordna om';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Visa tidslinje';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Dölj tidslinje';

  @override
  String get videoEditorFeedPreviewContent =>
      'Undvik att placera innehåll bakom dessa områden.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Original';

  @override
  String get videoEditorStickerSearchHint => 'Sök stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Välj typsnitt';

  @override
  String get videoEditorFontUnknown => 'Okänt';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Uppspelningshuvudet måste vara inom det valda klippet för att dela.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Trimma start';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Trimma slut';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Trimma klipp';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Dra handtagen för att justera klippets längd';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Drar klipp $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Klipp $index av $total, $duration sekunder';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Håll ned för att ordna om';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Tryck för att redigera. Håll ned och dra för att ändra ordning.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Flytta vänster';

  @override
  String get videoEditorTimelineClipMoveRight => 'Flytta höger';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'Håll ned för att dra';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Videotidslinje';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, vald';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Stäng färgväljare';

  @override
  String get videoEditorPickColorTitle => 'Välj färg';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Bekräfta färg';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Mättnad och ljusstyrka';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Mättnad $saturation%, Ljusstyrka $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Nyans';

  @override
  String get videoEditorAddElementSemanticLabel => 'Lägg till element';

  @override
  String get videoEditorCloseSemanticLabel => 'Stäng';

  @override
  String get videoEditorDoneSemanticLabel => 'Klar';

  @override
  String get videoEditorLevelSemanticLabel => 'Nivå';

  @override
  String get videoMetadataBackSemanticLabel => 'Tillbaka';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel => 'Stäng hjälpdialog';

  @override
  String get videoMetadataGotItButton => 'Jag fattar!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Gränsen på 64KB är nådd. Ta bort innehåll för att fortsätta.';

  @override
  String get videoMetadataExpirationLabel => 'Utgång';

  @override
  String get videoMetadataSelectExpirationSemanticLabel => 'Välj utgångstid';

  @override
  String get videoMetadataTitleLabel => 'Titel';

  @override
  String get videoMetadataDescriptionLabel => 'Beskrivning';

  @override
  String get videoMetadataTagsLabel => 'Taggar';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Ta bort';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Ta bort tagg $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Innehållsvarning';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Välj innehållsvarningar';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Välj allt som gäller för ditt innehåll';

  @override
  String get videoMetadataContentWarningDoneButton => 'Klar';

  @override
  String get videoMetadataCollaboratorsLabel => 'Samarbetspartners';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Lägg till samarbetspartner';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Så fungerar samarbetspartners';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max samarbetspartners';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Ta bort samarbetspartner';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Samarbetspartners taggas som medskapare i det här inlägget. Du kan bara lägga till personer som ni följer varandra ömsesidigt, och de visas i inläggets metadata när det publiceras.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Ömsesidiga följare';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Ni måste följa varandra ömsesidigt för att lägga till $name som samarbetspartner.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspirerad av';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Ange inspirerad av';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Så fungerar inspirationskrediter';

  @override
  String get videoMetadataInspiredByNone => 'Ingen';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Använd detta för att ge erkännande. Inspirerad av skiljer sig från samarbetspartners: det erkänner påverkan, men taggar inte någon som medskapare.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Den här skaparen kan inte refereras.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Ta bort inspirerad av';

  @override
  String get videoMetadataPostDetailsTitle => 'Inläggsdetaljer';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Sparad i bibliotek';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Det gick inte att spara';

  @override
  String get videoMetadataGoToLibraryButton => 'Gå till bibliotek';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Knapp spara till senare';

  @override
  String get videoMetadataRenderingVideoHint => 'Renderar video...';

  @override
  String get videoMetadataSavingVideoHint => 'Sparar video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Spara video till utkast och $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Spara till senare';

  @override
  String get videoMetadataPostSemanticLabel => 'Knapp publicera';

  @override
  String get videoMetadataPublishVideoHint => 'Publicera video i flödet';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Fyll i formuläret för att aktivera';

  @override
  String get videoMetadataPostButton => 'Publicera';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Öppna förhandsgranskningsskärm för inlägg';

  @override
  String get videoMetadataShareTitle => 'Dela';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Videodetaljer';

  @override
  String get videoMetadataClassicDoneButton => 'Klar';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Spela förhandsvisning';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pausa förhandsvisning';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Stäng videoförhandsvisning';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Ta bort';

  @override
  String get metadataCaptionsLabel => 'Undertexter';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Undertexter aktiverade för alla videor';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Undertexter inaktiverade för alla videor';

  @override
  String get fullscreenFeedRemovedMessage => 'Video borttagen';
}
