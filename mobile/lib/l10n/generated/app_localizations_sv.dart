// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get feedTuningMoreLabel => 'Mer så här';

  @override
  String get feedTuningLessLabel => 'Mindre så här';

  @override
  String get feedTuningUndo => 'Ångra';

  @override
  String get dmMessageBubbleVideoReplyHint => 'Öppna den refererade videon';

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
  String get settingsGeneralTitle => 'Allmänna inställningar';

  @override
  String get settingsContentSafetyTitle => 'Innehåll och säkerhet';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIONER';

  @override
  String get generalSettingsSectionViewing => 'VISNING';

  @override
  String get generalSettingsSectionCreating => 'SKAPANDE';

  @override
  String get generalSettingsSectionApp => 'APPEN';

  @override
  String get generalSettingsClosedCaptions => 'Undertexter';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Visa undertexter när videor har dem';

  @override
  String get generalSettingsVideoShape => 'Videoform';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Endast kvadratiska videor';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait =>
      'Kvadrat och stående';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Visa hela mixen av Divine-videor';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Behåll flöden i klassiskt kvadratiskt format';

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
  String get contentFiltersAdultContent => 'VUXENINNEHÅLL';

  @override
  String get contentFiltersViolenceGore => 'VÅLD OCH BLOD';

  @override
  String get contentFiltersSubstances => 'SUBSTANSER';

  @override
  String get contentFiltersOther => 'ÖVRIGT';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifiera din ålder under Säkerhet och integritet för att låsa upp filter för vuxeninnehåll';

  @override
  String get contentFiltersShow => 'Visa';

  @override
  String get contentFiltersWarn => 'Varna';

  @override
  String get contentFiltersFilterOut => 'Filtrera bort';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Det här kontot är inte tillgängligt';

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
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetsinbjudningar behöver fortfarande skickas',
      one: '1 samarbetsinbjudan behöver fortfarande skickas',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'Vi köade inbjudan. Försök igen här.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'För \"$title\". Försök igen här.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Försök igen';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Försöker igen';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Det går inte att skicka samarbetsinbjudan igen just nu.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetsinbjudningar behöver fortfarande skickas.',
      one: '1 samarbetsinbjudan behöver fortfarande skickas.',
      zero: 'Samarbetsinbjudningar skickade.',
    );
    return '$_temp0';
  }

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
  String profileReportDisplayName(String displayName) {
    return 'Rapportera $displayName';
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
  String get profileNoSavedVideosTitle => 'Inget sparat än';

  @override
  String get profileSavedOwnEmpty =>
      'Bokmärk videor från dela-menyn så dyker de upp här.';

  @override
  String get profileErrorLoadingSaved => 'Kunde inte ladda sparade videor';

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
  String get profileMaybeLaterLabel => 'Kanske senare';

  @override
  String get profileSecurePrimaryButton => 'Lägg till e-post och lösenord';

  @override
  String get profileCompletePrimaryButton => 'Uppdatera din profil';

  @override
  String get profileLoopsLabel => 'Loopar';

  @override
  String get profileLikesLabel => 'Gilla-markeringar';

  @override
  String get profileMyLibraryLabel => 'Mitt bibliotek';

  @override
  String get profileMessageLabel => 'Meddelande';

  @override
  String get profileUserFallback => 'användare';

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
  String get profileSetupWebsiteLabel => 'Website (Optional)';

  @override
  String get profileSetupWebsiteHint => 'https://yoursite.com';

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
  String get profileSetupImagesTypeGroup => 'bilder';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Kameraåtkomst misslyckades: $error';
  }

  @override
  String get profileSetupGotItButton => 'Jag fattar';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Det gick inte att ladda upp bilden. Försök igen senare.';

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
  String get profileSetupUploadServerError =>
      'Det gick inte att ladda upp bilden. Våra servrar är tillfälligt otillgängliga. Försök igen om en liten stund.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Uppladdning av profilbild är inte tillgänglig på webben än. Använd iOS- eller Android-appen eller klistra in en bild-URL.';

  @override
  String get profileSetupBannerSectionTitle => 'Banner';

  @override
  String get profileSetupBannerUploadButton => 'Ladda upp foto';

  @override
  String get profileSetupBannerClearButton => 'Rensa banner';

  @override
  String get profileSetupBannerUploadSuccess => 'Banner uppdaterad';

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
      'Användarnamnet måste vara 3–63 tecken';

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
  String get profileSetupExternalNip05InvalidFormat =>
      'Ogiltigt NIP-05-format (t.ex. namn@domän.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Använd användarnamnsfältet ovan för divine.video';

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
  String get videoPlayerTapHint =>
      'Tryck för att spela eller pausa. Dubbeltryck för att gilla.';

  @override
  String get videoSettingsMenuOpen => 'Öppna uppspelningsinställningar';

  @override
  String get videoSettingsMenuClose => 'Stäng uppspelningsinställningar';

  @override
  String get videoSettingsCaptionsEnable => 'Aktivera textning';

  @override
  String get videoSettingsCaptionsDisable => 'Avaktivera textning';

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
  String get contentWarningReportContentTooltip => 'Rapportera innehåll';

  @override
  String get contentWarningBlockUserTooltip => 'Blockera användare';

  @override
  String get contentWarningBlockedTitle => 'Innehåll blockerat';

  @override
  String get contentWarningBlockedPolicy =>
      'Det här innehållet har blockerats på grund av riktlinjebrott.';

  @override
  String get contentWarningNoticeTitle => 'Innehållsvarning';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Potentiellt skadligt innehåll';

  @override
  String get contentWarningView => 'Visa';

  @override
  String get contentWarningReportAction => 'Rapportera';

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
  String get videoErrorVerifyAgeFailed =>
      'Det gick inte att verifiera din ålder. Försök igen.';

  @override
  String get videoErrorVerifyAgeSignerUnreachable =>
      'Timeout vid verifiering. Kontrollera din anslutning eller försök igen om en stund.';

  @override
  String get videoErrorAdultContentHidden =>
      'Innehåll för vuxna är avstängt. Du kan slå på det i Inställningar → Innehållsfilter.';

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
    return '#$hashtag. Tryck för att se videor med den här hashtaggen.';
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
  String sharePostSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Inlägg delat med $count personer',
      one: 'Inlägg delat med $count person',
    );
    return '$_temp0';
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
  String shareSelectedRecipientAnnouncement(String name) {
    return '$name vald';
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
  String get videoActionLikeLabel => 'Gilla';

  @override
  String get videoActionReplyLabel => 'Svara';

  @override
  String get videoActionRepostLabel => 'Dela vidare';

  @override
  String get videoActionShareLabel => 'Dela';

  @override
  String get videoActionReportLabel => 'Anmäl';

  @override
  String get videoActionReport => 'Anmäl video';

  @override
  String get videoActionEditLabel => 'Redigera';

  @override
  String get videoActionEdit => 'Redigera video';

  @override
  String get videoActionAboutLabel => 'Om';

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
  String get videoEngagementLikersTitle => 'Gillat av';

  @override
  String get videoEngagementRepostersTitle => 'Repostat av';

  @override
  String get videoEngagementLikersEmpty => 'Inga gillningar än';

  @override
  String get videoEngagementRepostersEmpty => 'Inga reposts än';

  @override
  String get videoEngagementLoadFailed => 'Det gick inte att läsa in listan';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Öppna videodetaljer';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Öppna videodetaljer';

  @override
  String get videoOverlayCommentBarHint => 'Lägg till kommentar...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Lägg till en kommentar';

  @override
  String get videoOverlayCommentBarSendLabel => 'Skicka kommentar';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Kommentar publicerad';

  @override
  String get videoOverlayCommentPostFailedSnackbar =>
      'Kunde inte publicera kommentaren';

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
  String get metadataPgpSignature => 'PGP-signatur';

  @override
  String get metadataC2paCredentials => 'C2PA Content Credentials';

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
  String get metadataVineStatsLabel => 'På Vine';

  @override
  String metadataVineStatsLine(
    String loops,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$loops loopar · $likes gillamarkeringar · $comments kommentarer · $reposts återpubliceringar';
  }

  @override
  String get metadataDivineStatsLabel => 'På Divine';

  @override
  String metadataDivineStatsLine(
    String views,
    String likes,
    String comments,
    String reposts,
  ) {
    return '$views visningar · $likes gillamarkeringar · $comments kommentarer · $reposts återpubliceringar';
  }

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
  String get relaySettingsInsecureUrl =>
      'Rel-URL måste använda wss:// (ws:// tillåts endast för localhost)';

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
  String get relaySettingsExternalRelay => 'Extern rel';

  @override
  String get relaySettingsNotConnected => 'Inte ansluten';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Frånkopplad för $duration sedan';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count prenumerationer';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count händelser';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'för $duration sedan';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine använder Nostr-protokollet för decentraliserad publicering. Ditt innehåll lever på reler du väljer, och dina nycklar är din identitet.';

  @override
  String get nostrSettingsSectionNetwork => 'Nätverk';

  @override
  String get nostrSettingsSectionAccount => 'Konto';

  @override
  String get nostrSettingsSectionDangerZone => 'Riskzon';

  @override
  String get nostrSettingsRelays => 'Reler';

  @override
  String get nostrSettingsRelaysSubtitle => 'Hantera Nostr-relanslutningar';

  @override
  String get nostrSettingsRelayDiagnostics => 'Reldiagnostik';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Felsök relanslutningar och nätverksproblem';

  @override
  String get nostrSettingsMediaServers => 'Mediaservrar';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Konfigurera Blossom-uppladdningsservrar';

  @override
  String get nostrSettingsDeveloperOptions => 'Utvecklaralternativ';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Miljöväxlare och felsökningsinställningar';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Slå på funktioner som kan hicka.';

  @override
  String get nostrSettingsKeyManagement => 'Nyckelhantering';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exportera, säkerhetskopiera och återställ dina Nostr-nycklar';

  @override
  String get nostrSettingsClientAttribution => 'Klientattribuering';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Lägg till en Divine-klienttagg på events du publicerar så att andra Nostr-appar kan attribuera dem korrekt.';

  @override
  String get nostrSettingsRemoveKeys => 'Ta bort nycklar från enheten';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Radera din privata nyckel från endast den här enheten. Ditt innehåll stannar på relerna, men du behöver din nsec-säkerhetskopia för att komma åt kontot igen.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Kunde inte ta bort nycklar från enheten. Försök igen.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Kunde inte ta bort nycklar: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Radera konto och data';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Radera PERMANENT ditt konto och ALLT innehåll från Nostr-reler. Detta kan inte ångras.';

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
  String get notificationSettingsMarkAllAsReadFailed =>
      'Kunde inte markera alla som lästa';

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
  String get safetySettingsWhatYouSee => 'VAD DU SER';

  @override
  String get safetySettingsWhatYouPublish => 'VAD DU PUBLICERAR';

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
  String get safetySettingsAgeLockedForMinor => 'Låst för ditt konto';

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
  String get authCreateNewAccountShort => 'Create new account';

  @override
  String get authSignInDifferentAccount => 'Logga in med ett annat konto';

  @override
  String get authUseAnotherAccount => 'Use another account';

  @override
  String authContinueAs(String displayName) {
    return 'Continue as $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Dina utkast och klipp är sparade för det här kontot';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Loggar du in här döljs de utkasten och klippen';

  @override
  String get authTermsPrefix =>
      'By selecting an option below, you confirm you are at least 16 years old (or have completed ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine age authorization';

  @override
  String get authTermsAfterAgeAuthorization => ') and agree to the ';

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
  String get authConfirmPasswordLabel => 'Bekräfta lösenord';

  @override
  String get authEmailRequired => 'E-post krävs';

  @override
  String get authEmailInvalid => 'Ange en giltig e-postadress';

  @override
  String get authPasswordRequired => 'Lösenord krävs';

  @override
  String get authConfirmPasswordRequired => 'Bekräfta ditt lösenord';

  @override
  String get authPasswordsDoNotMatch => 'Lösenorden matchar inte';

  @override
  String get authForgotPassword => 'Glömt lösenord?';

  @override
  String get authImportNostrKey => 'Importera Nostr-nyckel';

  @override
  String get authConnectSignerApp => 'Anslut med en sign-app';

  @override
  String get authSignInWithAmber => 'Logga in med Amber';

  @override
  String get authSignInWithBrowserExtension => 'Logga in med webbläsartillägg';

  @override
  String get authNip07ConnectionFailed =>
      'Det gick inte att ansluta till ditt webbläsartillägg.';

  @override
  String get authNip07ExtensionNotFound =>
      'Inget webbläsartillägg hittades. Installera Alby, nos2x eller ett annat NIP-07-kompatibelt tillägg.';

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
  String get authInfoBrowserExtensionTitle => 'Webbläsartillägg';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Logga in med ett NIP-07-webbläsartillägg som Alby eller nos2x. Dina nycklar stannar i tillägget — Divine ser dem aldrig.';

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
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

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
  String get authBunkerRejectedConnection =>
      'Din sign-app nekade anslutningen.';

  @override
  String get authNostrConnectStartFailed =>
      'Kunde inte nå sign-appen. Kontrollera din anslutning och försök igen.';

  @override
  String get authNostrConnectInvalidSession =>
      'Den här anslutningslänken är inte längre giltig. Starta en ny.';

  @override
  String get authNostrConnectSetupFailed =>
      'Nästan klart — vi kunde inte slutföra inloggningen. Försök igen.';

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
  String get authConfirmNewPasswordLabel => 'Bekräfta nytt lösenord';

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
  String get authVerificationEmailAlreadyRegistered =>
      'Den här mejladressen är redan registrerad. Logga in i stället.';

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
  String get shareSheetNameClipTitle => 'Namnge det här klippet';

  @override
  String get shareSheetNameClipSubtitle =>
      'Välj ett namn du känner igen i ditt bibliotek.';

  @override
  String get shareSheetClipTitleLabel => 'Klippets titel';

  @override
  String get shareSheetSaveClip => 'Spara klipp';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Sparade \"$title\" till klipp';
  }

  @override
  String get shareSheetUntitledClip => 'Namnlöst klipp';

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
  String get peopleListsAddToList => 'Lägg till i lista';

  @override
  String get peopleListsAddToListSubtitle =>
      'Lägg till den här skaparen i en av dina listor';

  @override
  String get peopleListsSheetTitle => 'Lägg till i lista';

  @override
  String get peopleListsEmptyTitle => 'Inga listor än';

  @override
  String get peopleListsEmptySubtitle =>
      'Skapa en lista för att börja gruppera personer.';

  @override
  String get peopleListsCreateList => 'Skapa lista';

  @override
  String get peopleListsNewListTitle => 'Ny lista';

  @override
  String get peopleListsRouteTitle => 'Personlista';

  @override
  String get peopleListsListNameLabel => 'Listnamn';

  @override
  String get peopleListsListNameHint => 'Nära vänner';

  @override
  String get peopleListsCreateButton => 'Skapa';

  @override
  String get peopleListsAddPeopleTitle => 'Lägg till personer';

  @override
  String get peopleListsAddPeopleTooltip => 'Lägg till personer';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Lägg till personer i listan';

  @override
  String get peopleListsListNotFoundTitle => 'Listan hittades inte';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Listan hittades inte. Den kan ha tagits bort.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Den här listan kan ha tagits bort.';

  @override
  String get peopleListsNoPeopleTitle => 'Inga personer i den här listan';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Lägg till personer för att komma igång';

  @override
  String get peopleListsNoVideosTitle => 'Inga videor än';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Videor från listmedlemmar visas här';

  @override
  String get peopleListsNoVideosAvailable => 'Inga videor tillgängliga';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Det gick inte att läsa in videor';

  @override
  String get peopleListsVideoNotAvailable => 'Video ej tillgänglig';

  @override
  String get peopleListsBackToGridTooltip => 'Tillbaka till rutnät';

  @override
  String get peopleListsErrorLoadingVideos => 'Fel vid inläsning av videor';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Inga personer tillgängliga att lägga till.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Lägg till i $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Sök personer';

  @override
  String get peopleListsAddPeopleError =>
      'Det gick inte att läsa in personer. Försök igen.';

  @override
  String get peopleListsAddPeopleRetry => 'Försök igen';

  @override
  String get peopleListsAddButton => 'Lägg till';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Lägg till $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I $count listor',
      one: 'I 1 lista',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Ta bort $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'De kommer att tas bort från den här listan.';

  @override
  String get peopleListsRemove => 'Ta bort';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name borttagen från listan';
  }

  @override
  String get peopleListsUndo => 'Ångra';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil för $name. Håll intryckt för att ta bort.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Visa profil för $name';
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
      'The relay wouldn\'t accept this delete request. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
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
  String get shareMenuChangeCover => 'Byt omslag';

  @override
  String get shareMenuCoverUploadingBackground =>
      'Miniatyren laddas upp i bakgrunden';

  @override
  String get shareMenuVideoUpdated => 'Videon uppdaterades';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudningar till medarbetare skickades inte.',
      one: '1 inbjudan till medarbetare skickades inte.',
    );
    return 'Videon uppdaterades, men $_temp0';
  }

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
  String get soundsSavedToLibrary => 'Sparat i Ljud';

  @override
  String get soundsAlreadySavedToLibrary => 'Finns redan i Ljud';

  @override
  String get soundsSavedLibraryTitle => 'Mina ljud';

  @override
  String get soundsSavedEmptyTitle => 'Inga sparade ljud ännu';

  @override
  String get soundsSavedEmptyDescription =>
      'Tryck på Använd ljud i en video för att spara det här.';

  @override
  String get soundsAvailabilityPrivate => 'Privat';

  @override
  String get soundsAvailabilityCommunity => 'Community';

  @override
  String get soundsRemoveSavedSound => 'Ta bort ljud';

  @override
  String get soundsRemovedFromLibrary => 'Borttaget från Ljud';

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
  String get profileFeedError => 'Couldn\'t load videos.';

  @override
  String get profileFeedLoadMoreError =>
      'Couldn\'t load more videos. Pull to refresh.';

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
  String get notificationsRefreshError =>
      'Kunde inte uppdatera — visar tillgängliga';

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
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count olästa aviseringar',
      one: '1 oläst avisering',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Visa ${displayName}s profil';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Visa profiler';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Videominiatyr för $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Videominiatyr';

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
  String get feedModeForYou => 'För dig';

  @override
  String get feedModeNew => 'Nytt';

  @override
  String get feedModeFollowing => 'Följer';

  @override
  String get feedModeClassics => 'Klassiker';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Flödesläge: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Videoförfattare: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Skapares avatar';

  @override
  String get feedForYouEmpty =>
      'Ditt För dig-flöde är tomt.\nUtforska videor och följ kreatörer för att forma det.';

  @override
  String get feedFollowingEmpty =>
      'Inga videor från personer du följer än.\nHitta kreatörer du gillar och följ dem.';

  @override
  String get feedLatestEmpty => 'Inga nya videor än.\nTitta in igen snart.';

  @override
  String get feedClassicEmpty => 'Inga klassiker än.\nTitta in igen snart.';

  @override
  String get feedExploreVideos => 'Upptäck videor';

  @override
  String get feedExternalVideoSlow => 'Extern video laddar långsamt';

  @override
  String get feedSkip => 'Hoppa över';

  @override
  String get feedLoadingMore => 'Läser in fler videor…';

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
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Ta bort $name';
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
  String get routeUnknownPath => 'Den sidan finns inte i appen.';

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
  String supportLogsSavedTo(String path) {
    return 'Loggar sparade i $path';
  }

  @override
  String get supportRevealLogsAction => 'Visa i mapp';

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
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Skräppost eller ovälkommet innehåll';

  @override
  String get reportReasonSpamSubtitle => 'Oönskat eller repetitivt innehåll';

  @override
  String get reportReasonHarassment => 'Trakasserier, mobbning eller hot';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Skadliga och oönskade svar eller omnämnanden';

  @override
  String get reportReasonViolence => 'Våldsamt eller extremistiskt innehåll';

  @override
  String get reportReasonViolenceSubtitle =>
      'Våldsamt, extremistiskt eller skadligt innehåll';

  @override
  String get reportReasonSexualContent => 'Sexuellt eller vuxeninnehåll';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nakenhet, porr eller explicit innehåll';

  @override
  String get reportReasonCopyright => 'Upphovsrättsbrott';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Otillåten användning av immateriella rättigheter';

  @override
  String get reportReasonFalseInfo => 'Felaktig information';

  @override
  String get reportReasonFalseInfoSubtitle =>
      'Vilseledande eller falska påståenden';

  @override
  String get reportReasonChildSafety => 'Brott mot barns säkerhet';

  @override
  String get reportReasonChildSafetySubtitle =>
      'Allmänna farhågor om minderårigas säkerhet';

  @override
  String get reportReasonCsam => 'Brott mot barns säkerhet';

  @override
  String get reportReasonCsamSubtitle =>
      'Innehåll som utnyttjar eller utsätter minderåriga för fara';

  @override
  String get reportReasonUnderageUser => 'Användaren verkar vara under 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Kontoinnehavaren verkar vara minderårig';

  @override
  String get reportReasonAiGenerated => 'AI-genererat innehåll';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Misstänkt AI-genererat innehåll';

  @override
  String get reportReasonOther => 'Annat policybrott';

  @override
  String get reportReasonOtherSubtitle => 'Överträdelser som inte listas ovan';

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
  String get reportModerationDmDelayed =>
      'Vi kunde inte nå modereringsteamet direkt just nu, men din anmälan togs emot och kommer att granskas.';

  @override
  String get reportContactModeration => 'Meddela modereringsteamet';

  @override
  String get reportLearnMore => 'Läs mer';

  @override
  String get reportLearnMoreAt => 'Läs mer på';

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
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Av ';

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
  String get keyManagementKeycastRemoteSigning =>
      'Det här kontot signerar med Keycast. Ingen privat nyckel är lagrad på den här enheten, så det finns inget nsec att kopiera här.';

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
  String get keyManagementYourPublicKeyLabel => 'Din publika nyckel (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Kopiera publik nyckel';

  @override
  String get keyManagementPublicKeyCopied => 'Publik nyckel kopierad';

  @override
  String get profileEditPublicKeyLink => 'Visa din publika nyckel';

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
  String get soundUntitled => 'Namnlöst ljud';

  @override
  String get soundStopPreview => 'Stoppa förhandsvisning';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Förhandsvisa $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Visa detaljer för $title';
  }

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
  String get profileSetupUploadStaged =>
      'Uppladdad — tryck på Spara för att tillämpa';

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
  String get inboxRestoringMessages => 'Återställer dina meddelanden…';

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
  String get inboxCollabInviteCardUntitledVideo => 'Video utan titel';

  @override
  String get clickableTextViewVideoLink => 'Visa video';

  @override
  String get messageExternalLinkDialogTitle => 'Öppna extern länk?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Den här länken går till en extern webbplats och kanske inte är säker:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Öppna';

  @override
  String get inboxCollabInviteCoPostButton => 'Sampublicera';

  @override
  String get inboxCollabInviteNotMineButton => 'Inte min';

  @override
  String get inboxCollabInvitePreviewTitle => 'Inbjudan att sampublicera';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Inbjudan att sampublicera från $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Sampublicering lägger till den här videon på din tidslinje som ett samarbete.';

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
  String collaboratorInviteDmBody(String title, String url) {
    return 'Du har bjudits in att samarbeta på $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Du har bjudits in att samarbeta på en video: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbetsinbjudningar skickades inte.',
      one: '1 samarbetsinbjudan skickades inte.',
    );
    return 'Videon publicerades, men $_temp0';
  }

  @override
  String get dmSendFailedMessage => 'Meddelandet kunde inte skickas';

  @override
  String get dmSendFailedRetry => 'Försök igen';

  @override
  String get dmSendPartialMessage =>
      'Skickat, men inte synkat till dina andra enheter';

  @override
  String get dmConversationLoadError =>
      'Det gick inte att läsa in meddelandena';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => 'Skickat meddelande';

  @override
  String get dmMessageBubbleReceivedHint => 'Mottaget meddelande';

  @override
  String get dmMessageBubbleLongPressHint => 'Meddelandeåtgärder';

  @override
  String get dmMessageActionCopyText => 'Kopiera text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Kopiera video-URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Ta bort för alla';

  @override
  String get dmMessageActionReport => 'Rapportera';

  @override
  String get dmReactionAddCustomA11yLabel => 'Add custom emoji reaction';

  @override
  String dmReelReplyComposerHint(String name) {
    return 'Meddela $name…';
  }

  @override
  String get dmReelReplyComposerHintSelf => 'Svara dig själv…';

  @override
  String get dmReelReplyComposerSemanticLabel => 'Svara på den här reelen';

  @override
  String get dmReelReplyViewChat => 'Visa chatt';

  @override
  String get dmReelReplyViewChatA11yLabel => 'Öppna chatt';

  @override
  String get dmReelReplySentAnnouncement => 'Svar skickat';

  @override
  String dmReelReactionSentAnnouncement(String emoji) {
    return 'Reagerade $emoji';
  }

  @override
  String get dmReelReactionSentPill => 'Reaktion skickad';

  @override
  String get dmReelReplyFailed => 'Det gick inte att skicka';

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
  String get dmReactionsSheetTitle => 'Reaktioner';

  @override
  String get dmReactionsViewA11yLabel => 'Se vilka som reagerat';

  @override
  String get dmReactionRemoveAction => 'Ta bort';

  @override
  String get dmReactionRetryAction => 'Försök igen';

  @override
  String get dmFormatBold => 'Fet';

  @override
  String get dmFormatItalic => 'Kursiv';

  @override
  String get dmFormatStrikethrough => 'Genomstruken';

  @override
  String get dmFormatCode => 'Kod';

  @override
  String get dmStatusPending => 'Skickar';

  @override
  String get dmStatusFailed => 'Kunde inte skicka';

  @override
  String get dmStatusDeliveredSelfFailed =>
      'Levererat. Synkas inte till dina andra enheter.';

  @override
  String get inboxConversationActionsSheetLabel => 'Konversationsåtgärder';

  @override
  String inboxConversationTileLabel(String displayName) {
    return 'Konversation med $displayName';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Visa konversationsåtgärder';

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
  String get exploreSearchHint => 'Sök...';

  @override
  String categoryVideoCount(String count) {
    return '$count videor';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Kunde inte uppdatera prenumerationen: $error';
  }

  @override
  String get discoverListsTitle => 'Upptäck listor';

  @override
  String get discoverListsFailedToLoad => 'Kunde inte ladda listor';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Kunde inte ladda listor: $error';
  }

  @override
  String get discoverListsLoading => 'Söker upp publika listor...';

  @override
  String get discoverListsEmptyTitle => 'Inga publika listor hittades';

  @override
  String get discoverListsEmptySubtitle => 'Kom tillbaka senare för nya listor';

  @override
  String get discoverListsByAuthorPrefix => 'av';

  @override
  String get curatedListEmptyTitle => 'Inga videor i den här listan';

  @override
  String get curatedListEmptySubtitle =>
      'Lägg till några videor för att komma igång';

  @override
  String get curatedListLoadingVideos => 'Laddar videor...';

  @override
  String get curatedListFailedToLoad => 'Kunde inte ladda listan';

  @override
  String get curatedListNoVideosAvailable => 'Inga videor tillgängliga';

  @override
  String get curatedListVideoNotAvailable => 'Video inte tillgänglig';

  @override
  String get curatedListActionsTooltip => 'Liståtgärder';

  @override
  String get curatedListUnfollowAction => 'Sluta följa lista';

  @override
  String get curatedListUnfollowedSnack => 'Slutade följa listan';

  @override
  String get curatedListUnfollowFailed => 'Kunde inte sluta följa listan';

  @override
  String get curatedListDeleteConfirmTitle => 'Ta bort lista?';

  @override
  String get curatedListDeleteConfirmBody =>
      'Detta tar bort listan från relerna. Videorna i listan tas inte bort.';

  @override
  String get curatedListDeletedSnack => 'Listan borttagen';

  @override
  String get curatedListDeleteFailed => 'Kunde inte ta bort listan';

  @override
  String get peopleListsActionsTooltip => 'Liståtgärder';

  @override
  String get listDeleteAction => 'Ta bort lista';

  @override
  String get peopleListsDeleteConfirmTitle => 'Ta bort lista?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'Detta tar bort listan för alla. Personerna i den slutar du inte följa.';

  @override
  String get peopleListsDeleteFailed => 'Kunde inte ta bort listan';

  @override
  String get commonRetry => 'Försök igen';

  @override
  String get commonSomethingWentWrong => 'Något gick fel';

  @override
  String get commonNext => 'Nästa';

  @override
  String get commonDelete => 'Radera';

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get commonBack => 'Tillbaka';

  @override
  String get commonClose => 'Stäng';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Det gick inte att uppdatera omslaget. Försök igen.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Omslag uppdaterat';

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
  String get librarySelect => 'Välj';

  @override
  String get librarySortNewestCreation => 'Senast skapade';

  @override
  String get librarySortOldestCreation => 'Äldst skapade';

  @override
  String get librarySortLongestClip => 'Längsta klipp';

  @override
  String get librarySortShortestClip => 'Kortaste klipp';

  @override
  String get librarySortSquareFirst => 'Kvadratiska först';

  @override
  String get librarySortVerticalFirst => 'Vertikala först';

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
  String get libraryClipsDeletedUndoLabel => 'Ångra';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Raderas automatiskt om $daysLeft dagar',
      one: 'Raderas automatiskt i morgon',
      zero: 'Raderas automatiskt i dag',
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
  String videoClipSemanticLabel(String duration) {
    return 'Videoklipp, $duration sekunder';
  }

  @override
  String get videoClipSemanticValueSelected => 'Valt';

  @override
  String get videoClipSemanticValueNotSelected => 'Inte valt';

  @override
  String get videoClipSemanticHintDisabled => 'Inaktiverat';

  @override
  String get videoClipSemanticHintSelect =>
      'Tryck för att välja, håll för förhandsgranskning';

  @override
  String get videoClipSemanticHintDeselect =>
      'Tryck för att avmarkera, håll för förhandsgranskning';

  @override
  String get routerInvalidCreator => 'Ogiltig skapare';

  @override
  String get routerInvalidHashtagRoute => 'Ogiltig hashtagrutt';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Kunde inte ladda videor';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Inga videor i den här kategorin';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Sorteringsalternativ för kategori';

  @override
  String get categoryGallerySortHot => 'Hett';

  @override
  String get categoryGallerySortNew => 'Nytt';

  @override
  String get categoryGallerySortClassic => 'Klassiskt';

  @override
  String get categoryGallerySortForYou => 'För dig';

  @override
  String get categoriesCouldNotLoadCategories => 'Kunde inte ladda kategorier';

  @override
  String get categoriesNoCategoriesAvailable => 'Inga kategorier tillgängliga';

  @override
  String get notificationsEmptyTitle => 'Ingen aktivitet än';

  @override
  String get notificationsEmptySubtitle =>
      'När folk interagerar med ditt innehåll dyker det upp här';

  @override
  String get appsPermissionsTitle => 'Integrationsbehörigheter';

  @override
  String get appsPermissionsRevoke => 'Återkalla';

  @override
  String get appsPermissionsEmptyTitle =>
      'Inga sparade integrationsbehörigheter';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Godkända integrationer dyker upp här efter att du sparat ett åtkomstgodkännande.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName vill ha ditt godkännande';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Den här appen begär åtkomst genom Divines granskade sandlåda.';

  @override
  String get nostrAppPermissionOrigin => 'Ursprung';

  @override
  String get nostrAppPermissionMethod => 'Metod';

  @override
  String get nostrAppPermissionCapability => 'Funktion';

  @override
  String get nostrAppPermissionEventKind => 'Händelsetyp';

  @override
  String get nostrAppPermissionAllow => 'Tillåt';

  @override
  String get appsDetailDefaultTitle => 'Integrerad app';

  @override
  String get appsDetailNotFoundTitle => 'Integrationen hittades inte';

  @override
  String get appsDetailNotFoundSubtitle =>
      'Den här godkända integrationen är inte längre tillgänglig i Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'Så fungerar det';

  @override
  String get appsDetailHowItWorksBody =>
      'Detta är en godkänd tredjepartsapp som körs inuti Divine. Divine beviljar bara granskade funktioner för den här integrationen och blockerar navigering utanför dess godkända ursprung.';

  @override
  String get appsDetailAboutTitle => 'Om';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primärt ursprung';

  @override
  String get appsDetailApprovedOriginsTitle => 'Godkända ursprung';

  @override
  String get appsDetailCapabilitiesTitle => 'Tillgängliga funktioner';

  @override
  String get appsDetailAskBeforeTitle => 'Fråga innan';

  @override
  String get appsDetailOpenButton => 'Öppna integration';

  @override
  String get appsDetailNoneDeclared => 'Inga deklarerade än';

  @override
  String get appsDirectoryTitle => 'Integrerade appar';

  @override
  String get appsDirectoryIntroTitle => 'Godkända tredjepartsappar';

  @override
  String get appsDirectoryIntroBody =>
      'Godkända tredjepartsappar som körs inuti Divine';

  @override
  String get appsDirectoryErrorTitle => 'Kunde inte läsa in integrerade appar';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Dra för att försöka med de godkända integrationerna igen.';

  @override
  String get appsDirectoryEmptyTitle => 'Inga godkända integrationer än';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Godkända tredjepartsappar dyker upp här när Divine lägger till dem.';

  @override
  String get appsDirectoryRefresh => 'Uppdatera';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Integrerade appar körs i Divine mobil';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Godkända integrationer är bara tillgängliga på mobil för tillfället.';

  @override
  String get appsSandboxUnavailableTitle => 'Integrationen är inte tillgänglig';

  @override
  String get appsSandboxUnavailableBody =>
      'Öppna godkända integrationer från fliken Integrerade appar så att Divine kan tillämpa rätt åtkomstpolicy.';

  @override
  String get appsSandboxLoadingTitle => 'Läser in integration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Kontrollerar den godkända integrationen innan start.';

  @override
  String get appsSandboxBlockedTitle => 'Blockerad av säkerhetsskäl';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'Den här integrationen försökte lämna sitt godkända ursprung.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Länk till inlägget kopierad till urklipp';

  @override
  String get shareCopiedEventJson =>
      'Nostr-händelsens JSON kopierad till urklipp';

  @override
  String get shareCopiedEventId => 'Nostr-händelsens ID kopierat till urklipp';

  @override
  String get authHeroTaglineAuthentic => 'Äkta ögonblick.';

  @override
  String get authHeroTaglineHuman => 'Mänsklig kreativitet.';

  @override
  String get keyImportFailedToImport =>
      'Kunde inte importera nyckel eller ansluta bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'Ogiltig bunker-URL';

  @override
  String get keyImportInvalidFormat =>
      'Ogiltigt format. Använd nsec..., hex, ncryptsec1... eller bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Ogiltigt nsec-format. Ska vara 63 tecken';

  @override
  String get keyImportKeyFieldLabel => 'Privat nyckel eller bunker-URL';

  @override
  String get keyImportKeyRequired => 'Ange din privata nyckel eller bunker-URL';

  @override
  String get keyImportPasswordRequired =>
      'Ange lösenordet för den här krypterade nyckeln';

  @override
  String get keyImportSecurityWarningBody =>
      'Dela aldrig din privata nyckel med någon. Nyckeln ger full åtkomst till din Nostr-identitet.';

  @override
  String get keyImportSecurityWarningTitle => 'Håll din privata nyckel säker!';

  @override
  String get keyImportSubtitle =>
      'Importera din befintliga Nostr-identitet med din privata nyckel eller en bunker-URL.';

  @override
  String get keyImportTitle => 'Importera din\nNostr-identitet';

  @override
  String get commentAuthorYouIndicator => 'Du';

  @override
  String commentAuthorAvatarSemanticLabel(String name) {
    return 'Visa ${name}s profil';
  }

  @override
  String get commentOptionsDeleteSemanticLabel => 'Ta bort kommentar';

  @override
  String get commentOptionsEditSemanticLabel => 'Redigera kommentar';

  @override
  String get commentOptionsFlagContentLabel => 'Flagga innehåll';

  @override
  String get commentOptionsFlagContentSemanticLabel =>
      'Flagga det här innehållet';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Välj en anledning till att flagga den här kommentaren';

  @override
  String get commentOptionsFlagSubmit => 'Skicka';

  @override
  String get commentOptionsTitle => 'Alternativ';

  @override
  String get commentsEmptyClassicVineMessage =>
      'Vi jobbar fortfarande med att importera gamla kommentarer från arkivet. De är inte klara än.';

  @override
  String get commentsEmptyClassicVineTitle => 'Klassiska Vine';

  @override
  String get commentsInputEditingLabel => 'Redigerar';

  @override
  String get commentsInputSemanticHint => 'Lägg till en kommentar';

  @override
  String get commentsInputSemanticHintEdit => 'Redigera kommentar';

  @override
  String get commentsInputSemanticHintReply => 'Lägg till ett svar';

  @override
  String get commentsInputSemanticLabel => 'Kommentarsfält';

  @override
  String get commentsInputSemanticLabelEdit => 'Redigeringsfält';

  @override
  String get commentsInputSemanticLabelReply => 'Svarsfält';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'Visa profil för $displayName';
  }

  @override
  String get classicsEmptyDescription => 'Klassiker-arkivet läses in';

  @override
  String get classicsEmptyTitle => 'Inga klassiker hittades';

  @override
  String get classicsErrorTitle => 'Kunde inte läsa in Klassiker';

  @override
  String get classicsUnavailableDescription =>
      'Klassiker är bara tillgängliga när du är ansluten till Funnelcake-reler.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Byt till en Funnelcake-aktiverad rel i Inställningar för att komma åt Klassiker-arkivet.';

  @override
  String get classicsUnavailableTitle => 'Klassiker är inte tillgängliga';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Bli först med att publicera en video med den här hashtaggen!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'Inga videor hittades för #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'Det kan ta en liten stund';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Läser in videor om #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Lägg till hashtaggar... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle =>
      'Kom tillbaka senare för nytt innehåll';

  @override
  String get newVideosTabEmptyTitle => 'Inga videor i Nya videor';

  @override
  String get popularVideosContextTitle => 'Populära videor';

  @override
  String get popularVideosEmptySubtitle =>
      'Kom tillbaka senare för nytt innehåll';

  @override
  String get popularVideosEmptyTitle => 'Inga videor i Populära videor';

  @override
  String get popularVideosErrorTitle => 'Kunde inte läsa in trendande videor';

  @override
  String get popularVideosFeedSourceLabel => 'Källa för populärt flöde';

  @override
  String get trendingHashtagsLoading => 'Läser in hashtaggar...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'Visa videor taggade med $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Videons skapare: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Videons beskrivning: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divines vision är att ge dig ett verkligt algoritmiskt val. I stället för att vara låst till en enda svart låda-algoritm kommer du att kunna välja mellan flera rekommendationssätt:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Kronologisk tidslinje från skapare du följer';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'Detta ger dig kontroll över din uppmärksamhet i stället för att lämna den till plattformen. Du bör veta hur ditt flöde kurateras och ha makten att ändra det när du vill.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Community-skapade egna flöden för ämnen som musik, komedi eller konst';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personligt \"För dig\"-flöde';

  @override
  String get forYouAlgorithmChoiceTitle => 'Din algoritm, ditt val';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trendande och populärt innehåll';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Stark signal — du var engagerad nog att svara';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine uppmärksammar hur du interagerar med innehåll för att förstå vad du gillar. Varje gång du tittar på en video, ger den en reaktion, lämnar en kommentar eller återpublicerar den så noterar systemet det.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'Så fungerar det';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Olika handlingar signalerar olika grader av intresse:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'Om du inte har byggt upp någon tittarhistorik än visar vi en blandning av det som är populärt och trendar just nu tillsammans med senaste uppladdningar. Det ger dig en bra utgångspunkt för att utforska.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'När du tittar, gillar och engagerar dig i innehåll blir rekommendationerna gradvis mer personliga. Med tiden lyfter ditt För dig-flöde fram videor från skapare du kanske aldrig hade upptäckt på egen hand.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'Ny på Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'Vi bygger ett öppet system där utvecklare kan implementera sina egna algoritmer, och du kan välja vilka du vill använda — eller välja bort dem helt.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Öppen källkod och transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Medelstark signal — ett snabbt sätt att visa uppskattning';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reaktioner';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Starkaste signalen — att dela med dina följare är ett kraftfullt stöd';

  @override
  String get forYouAlgorithmSubtitle =>
      'Drivs av Gorse, en rekommendationsmotor med öppen källkod';

  @override
  String get forYouAlgorithmTitle => 'Divine-algoritmen';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Svag signal — visar grundläggande intresse';

  @override
  String get forYouEmptyDescription =>
      'Titta på och gilla några videor för att få personliga rekommendationer.';

  @override
  String get forYouEmptyTitle => 'Inga rekommendationer än';

  @override
  String get forYouErrorTitle => 'Kunde inte läsa in rekommendationer';

  @override
  String get forYouUnavailableDescription =>
      'Personliga rekommendationer kräver anslutning till Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'För dig är inte tillgängligt';

  @override
  String get inboxConversationOptionsLabel => 'Alternativ';

  @override
  String get inboxConversationViewProfileButton => 'Visa profil';

  @override
  String get inboxMessageRequestsEmpty => 'Inga meddelandeförfrågningar';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Meddelandeförfrågningar, $requestCount väntande';
  }

  @override
  String get inboxMessageRequestsTitle => 'Meddelandeförfrågningar';

  @override
  String get inboxMessagesTab => 'Meddelanden';

  @override
  String inboxRequestTileLabel(String displayName) {
    return 'Meddelandeförfrågan från $displayName';
  }

  @override
  String get inboxRequestTileSubtitle => 'Skickade en meddelandeförfrågan';

  @override
  String get inboxRequestsMarkAllRead => 'Markera alla förfrågningar som lästa';

  @override
  String get inboxRequestsRemoveAll => 'Ta bort alla förfrågningar';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Avböj och ta bort';

  @override
  String messageRequestFollowersCount(String count) {
    return '$count följare';
  }

  @override
  String messageRequestVideosCount(String count) {
    return '$count videor';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meddelanden',
      one: '1 meddelande',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'Visa meddelanden';

  @override
  String get messageRequestViewProfileButton => 'Visa profil';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName vill skicka meddelanden till dig och har skickat $messageText.';
  }

  @override
  String get deleteAccountConfirmationHint => 'Skriv DELETE';

  @override
  String get deleteAccountContentDeletionFailed =>
      'Kunde inte ta bort innehåll från relerna';

  @override
  String get deleteAccountDeleteAllContentButton => 'Ta bort allt innehåll';

  @override
  String get deleteAccountFinalConfirmationBody =>
      'För att bekräfta permanent borttagning av ALLT ditt innehåll från Nostr-reler, skriv:';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Slutgiltig bekräftelse';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Kontot borttaget, men dina nycklar kan finnas kvar på den här enheten. Gå till Inställningar → Nostr-nycklar → Ta bort nycklar för att försöka igen.';

  @override
  String get deleteAccountLocalDataDeletionFailed =>
      'Account deleted and signed out, but some local data could not be removed from this device.';

  @override
  String get deleteAccountPreparingDeletion => 'Förbereder borttagning...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total händelser';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'Detta tar bort den lokala inloggningen för det här kontot från den här enheten. Det tar inte bort ditt Divine-konto eller din Nostr-identitet.\n\nDina utkast och klipp finns kvar sparade på den här enheten för det här kontot. Om det här är ditt sista lokala konto återgår du till inloggningsskärmen.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Ta bort från enheten';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Ta bort det här kontot från den här enheten?';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Kunde inte ta bort ditt konto från servern. Kontrollera din anslutning och försök igen.';

  @override
  String get deleteAccountSuccess => 'Ditt konto har tagits bort';

  @override
  String get exportProgressStageApplyingTextOverlay =>
      'Lägger till textöverlägg...';

  @override
  String get exportProgressStageComplete => 'Exporten är klar!';

  @override
  String get exportProgressStageConcatenating => 'Kombinerar klipp...';

  @override
  String get exportProgressStageError => 'Exporten misslyckades';

  @override
  String get exportProgressStageGeneratingThumbnail => 'Skapar miniatyrbild...';

  @override
  String get exportProgressStageMixingAudio => 'Lägger till ljud...';

  @override
  String get findPeopleAnonymousUser => 'Anonym';

  @override
  String get findPeopleNoContacts =>
      'Inga kontakter hittades.\nBörja följa personer för att se dem här.';

  @override
  String get geoBlockedCityLabel => 'Stad';

  @override
  String get geoBlockedCountryLabel => 'Land';

  @override
  String get geoBlockedDefaultReason =>
      'Tjänsten är inte tillgänglig i din region på grund av lokala regler.';

  @override
  String get geoBlockedLegalNotice =>
      'Vi respekterar dina lokala lagar och regler. Den här begränsningen baseras på platsen för din IP-adress.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Tjänsten är inte tillgänglig';

  @override
  String get likedVideosEmpty => 'Inga gillade videor';

  @override
  String get likedVideosInvalidRoute => 'Ogiltig rutt';

  @override
  String get likedVideosTitle => 'Gillade videor';

  @override
  String get ogVinerBadgeSemanticLabel => 'OG Viner';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Försöker ladda upp igen…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Spara till utkast';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Sparat till utkast';

  @override
  String get uploadFailureSheetTitle => 'Uppladdningen misslyckades';

  @override
  String get uploadFailureSheetTryAgainButton => 'Försök igen';

  @override
  String get videoEditorAudioImportAudio => 'Importera ljud';

  @override
  String get videoEditorAudioImportFailed => 'Ljudimporten misslyckades.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String videoInspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirerad av $creatorName. Tryck för att se deras profil.';
  }

  @override
  String get proofmodeBadgeAiScanPending => 'AI-skanning väntar';

  @override
  String get proofmodeBadgeHumanMade => 'Gjord av människa';

  @override
  String get proofmodeBadgeNotDivineHosted => 'Inte värd hos Divine';

  @override
  String get proofmodeBadgeOriginal => 'Original';

  @override
  String get proofmodeBadgePossiblyAiGenerated => 'Möjligen AI-genererad';

  @override
  String get proofmodeBadgeUnverified => 'Overifierad';

  @override
  String get proofmodeConfirmedByModerator => 'Bekräftad av mänsklig moderator';

  @override
  String get proofmodeExternalContentTitle => 'Externt innehåll';

  @override
  String get proofmodeHostedOnLabel => 'Den här videon är värd på:';

  @override
  String get proofmodeLikelyHumanCreated => 'Troligen skapad av människa';

  @override
  String get proofmodeNoProofDataAttached => 'Ingen ProofMode-data bifogad';

  @override
  String get proofmodeNotDivineHostedDisclaimer =>
      'Det här innehållet är inte värd på Divines servrar. Vi kan inte helt garantera dess äkthet.';

  @override
  String get proofmodePossiblyAiGenerated => 'Möjligen AI-genererad';

  @override
  String get proofmodePublishedByLabel => 'Publicerad av:';

  @override
  String get publishErrorNotSignedIn => 'Logga in för att publicera videor.';

  @override
  String get publishErrorNoRetry => 'Ingen uppladdning att försöka igen med.';

  @override
  String get publishErrorNoInternet =>
      'Ingen internetanslutning. Kontrollera ditt wifi eller mobildata och försök igen.';

  @override
  String get publishErrorServerUnreachable =>
      'Kunde inte nå servern. Försök igen om en stund.';

  @override
  String get publishErrorTimeout =>
      'Uppladdningen tog för lång tid. Prova en starkare anslutning eller en mindre video.';

  @override
  String get publishErrorTls =>
      'Den säkra anslutningen misslyckades. Kontrollera ditt nätverk – offentligt wifi kan blockera uppladdningar.';

  @override
  String publishErrorServerNotFound(String serverName) {
    return 'Mediaservern ($serverName) är inte tillgänglig. Du kan välja en annan i dina inställningar.';
  }

  @override
  String get publishErrorFileTooLarge =>
      'Videofilen är för stor för servern. Prova att korta ner den eller sänka kvaliteten.';

  @override
  String publishErrorServerInternalError(String serverName) {
    return 'Mediaservern ($serverName) råkade ut för ett internt fel. Du kan välja en annan i dina inställningar.';
  }

  @override
  String publishErrorServerDown(String serverName) {
    return 'Mediaservern ($serverName) är tillfälligt nere. Försök igen snart eller välj en annan i dina inställningar.';
  }

  @override
  String get publishErrorForbidden =>
      'Du har inte behörighet att ladda upp till den här servern.';

  @override
  String get publishErrorFileNotFound =>
      'Videofilen kunde inte hittas. Den kan ha raderats. Spela in på nytt och försök igen.';

  @override
  String get publishErrorLowStorage =>
      'Det finns inte tillräckligt med lagringsutrymme på enheten. Frigör utrymme och försök igen.';

  @override
  String get publishErrorThumbnailFailed =>
      'Videon laddades upp, men miniatyrbilden kunde inte skapas. Försök igen.';

  @override
  String get publishErrorNostrPublishFailed =>
      'Videon laddades upp men inlägget kunde inte publiceras. Kontrollera dina relinställningar och försök igen.';

  @override
  String get publishErrorInterrupted =>
      'Uppladdningen avbröts. Vill du försöka igen?';

  @override
  String get publishErrorGeneric => 'Något gick fel. Försök igen.';

  @override
  String get publishErrorRateLimited =>
      'För många uppladdningar just nu. Vänta en stund och försök igen.';

  @override
  String get publishErrorUploadSessionExpired =>
      'Din uppladdningssession har gått ut. Försök igen.';

  @override
  String get publishErrorPermissionDenied =>
      'Divine har inte behörighet att ladda upp. Kontrollera appens behörigheter i dina inställningar och försök igen.';

  @override
  String get publishErrorOutOfMemory =>
      'Enheten har ont om minne. Stäng några appar och försök igen.';

  @override
  String get publishErrorUnknownServer => 'Okänd server';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'Inga resultat hittades för \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'Visa videor taggade med $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Ljud: $soundName av $creatorName. Tryck för att se ljuddetaljer.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Originalljud av $creatorName. Tryck för att använda det här ljudet.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Ljud: $soundName av $creatorName. Tryck för att se detaljer.';
  }

  @override
  String soundDetailLoadError(String error) {
    return 'Kunde inte läsa in ljud: $error';
  }

  @override
  String get soundDetailNotFoundMessage => 'Det här ljudet kunde inte hittas';

  @override
  String get soundDetailNotFoundTitle => 'Ljudet hittades inte';

  @override
  String get videoFeedDescriptionSemanticLabel => 'Videons beskrivning';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loopar';
  }

  @override
  String get videoFeedLoopCountSemanticLabel => 'Videons antal loopar';

  @override
  String get originalSoundUnavailableBody =>
      'Ljudet från den här videon är inte tillgängligt separat.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Originalljud – $creatorName';
  }

  @override
  String globalUploadPendingCount(int count) {
    return 'Väntande uppladdningar ($count)';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String shareVideoInListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'I $count listor',
      one: 'I 1 lista',
    );
    return '$_temp0';
  }

  @override
  String get unfollowConfirmButton => 'Sluta följa';

  @override
  String get videoClipSaveFailed => 'Kunde inte spara klipp';

  @override
  String videoClipSaveTo(String destination) {
    return 'Spara till $destination';
  }

  @override
  String get videoClipDelete => 'Ta bort klipp';

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspirerad av $creatorName. Tryck för att se deras profil.';
  }

  @override
  String get bugReportSendReport => 'Skicka rapport';

  @override
  String get supportSubjectRequiredLabel => 'Ämne *';

  @override
  String get supportRequiredHelper => 'Obligatoriskt';

  @override
  String get bugReportSubjectHint => 'Kort sammanfattning av problemet';

  @override
  String get bugReportDescriptionRequiredLabel => 'Vad hände? *';

  @override
  String get bugReportDescriptionHint => 'Beskriv problemet du stötte på';

  @override
  String get bugReportStepsLabel => 'Steg för att återskapa';

  @override
  String get bugReportStepsHint => '1. Gå till...\n2. Tryck på...\n3. Se felet';

  @override
  String get bugReportExpectedBehaviorLabel => 'Förväntat beteende';

  @override
  String get bugReportExpectedBehaviorHint => 'Vad borde ha hänt istället?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Enhetsinfo och loggar inkluderas automatiskt.';

  @override
  String get bugReportSuccessMessage =>
      'Tack! Vi har fått din rapport och använder den för att göra Divine bättre.';

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
      'Kunde inte skicka buggrapporten. Försök igen senare.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Buggrapport kunde inte skickas: $error';
  }

  @override
  String get featureRequestSendRequest => 'Skicka önskemål';

  @override
  String get featureRequestSubjectHint => 'Kort sammanfattning av din idé';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Vad önskar du? *';

  @override
  String get featureRequestDescriptionHint => 'Beskriv funktionen du vill ha';

  @override
  String get featureRequestUsefulnessLabel =>
      'Hur skulle detta vara användbart?';

  @override
  String get featureRequestUsefulnessHint =>
      'Förklara nyttan funktionen skulle ge';

  @override
  String get featureRequestWhenLabel => 'När skulle du använda det?';

  @override
  String get featureRequestWhenHint =>
      'Beskriv situationerna där detta skulle hjälpa';

  @override
  String get featureRequestSuccessMessage =>
      'Tack! Vi har fått ditt önskemål och kommer att granska det.';

  @override
  String get featureRequestSendFailed =>
      'Kunde inte skicka funktionsönskemålet. Försök igen senare.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Funktionsönskemål kunde inte skickas: $error';
  }

  @override
  String get notificationFollowBack => 'Följ tillbaka';

  @override
  String get followingTitle => 'Följer';

  @override
  String followingTitleForName(String displayName) {
    return '${displayName}s följer';
  }

  @override
  String get followingFailedToLoadList => 'Kunde inte ladda följer-listan';

  @override
  String get followingEmptyTitle => 'Följer ingen än';

  @override
  String get followersTitle => 'Följare';

  @override
  String followersTitleForName(String displayName) {
    return '${displayName}s följare';
  }

  @override
  String get followersFailedToLoadList => 'Kunde inte ladda följarlistan';

  @override
  String get followersEmptyTitle => 'Inga följare än';

  @override
  String get followersUpdateFollowFailed =>
      'Kunde inte uppdatera följstatus. Försök igen.';

  @override
  String get reportMessageTitle => 'Rapportera meddelande';

  @override
  String get reportMessageWhyReporting =>
      'Varför rapporterar du det här meddelandet?';

  @override
  String get reportMessageSelectReason =>
      'Välj en anledning för att rapportera meddelandet';

  @override
  String get newMessageTitle => 'Nytt meddelande';

  @override
  String get newMessageFindPeople => 'Hitta personer';

  @override
  String get newMessageNoContacts =>
      'Inga kontakter hittades.\nFölj personer för att se dem här.';

  @override
  String get newMessageNoUsersFound => 'Inga användare hittades';

  @override
  String get hashtagSearchTitle => 'Sök efter hashtags';

  @override
  String get hashtagSearchSubtitle => 'Upptäck trendande ämnen och innehåll';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Inga hashtags hittades för \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Sökning misslyckades';

  @override
  String get userNotAvailableTitle => 'Konto ej tillgängligt';

  @override
  String get userNotAvailableBody =>
      'Det här kontot är inte tillgängligt just nu.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Kunde inte spara inställningarna: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Ange en giltig server-URL (t.ex. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom-inställningar sparade';

  @override
  String get blossomSaveTooltip => 'Spara';

  @override
  String get blossomAboutTitle => 'Om Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom är ett decentraliserat protokoll för medialagring som låter dig ladda upp videor till valfri kompatibel server. Som standard laddas videor upp till Divines Blossom-server. Aktivera alternativet nedan för att använda en egen server istället.';

  @override
  String get blossomUseCustomServer => 'Använd egen Blossom-server';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Videor laddas upp till din egen Blossom-server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Dina videor laddas just nu upp till Divines Blossom-server';

  @override
  String get blossomCustomServerUrl => 'URL till egen Blossom-server';

  @override
  String get blossomCustomServerHelper =>
      'Ange URL:en till din egen Blossom-server';

  @override
  String get blossomPopularServers => 'Populära Blossom-servrar';

  @override
  String get blossomServerUrlMustUseHttps =>
      'URL till Blossom-server måste använda https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Kunde inte uppdatera crosspost-inställningen';

  @override
  String get blueskySignInRequired =>
      'Logga in för att hantera Bluesky-inställningar';

  @override
  String get blueskyPublishVideos => 'Publicera videor till Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Dina videor publiceras till Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Dina videor publiceras inte till Bluesky';

  @override
  String get blueskyHandle => 'Bluesky-handtag';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Konto provisionerat och klart';

  @override
  String get blueskyStatusPending => 'Konto provisioneras...';

  @override
  String get blueskyStatusFailed => 'Kontoprovisionering misslyckades';

  @override
  String get blueskyStatusDisabled => 'Konto inaktiverat';

  @override
  String get blueskyStatusNotLinked => 'Inget Bluesky-konto kopplat';

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
  String get invitesNoneAvailable => 'Inga inbjudningar tillgängliga just nu';

  @override
  String get invitesShareWithPeople => 'Dela diVine med folk du känner';

  @override
  String get invitesUsedInvites => 'Använda inbjudningar';

  @override
  String invitesShareMessage(String code) {
    return 'Häng med mig på diVine! Använd inbjudningskoden $code för att komma igång:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Kopiera inbjudan';

  @override
  String get invitesCopied => 'Inbjudan kopierad!';

  @override
  String get invitesShareInvite => 'Dela inbjudan';

  @override
  String get invitesShareSubject => 'Häng med mig på diVine';

  @override
  String get invitesClaimed => 'Inlöst';

  @override
  String get invitesCouldNotLoad => 'Kunde inte ladda inbjudningar';

  @override
  String get invitesRetry => 'Försök igen';

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
  String get searchVideosSortOptionsLabel => 'Sortera videoresultat';

  @override
  String get searchVideosSortTrending => 'Hett';

  @override
  String get searchVideosSortLoops => 'Flest loopar';

  @override
  String get searchVideosSortEngagement => 'Mest engagemang';

  @override
  String get searchVideosSortRecent => 'Senaste';

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
  String get keyImportInsecureBunkerRelay =>
      'Bunker-rel måste använda wss:// (ws:// tillåts endast för localhost)';

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
  String notificationLikedYourComment(String actorName) {
    return '$actorName gillade din kommentar';
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
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName svarade på din kommentar';
  }

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
  String get notificationSystemUpdate => 'Du har en ny uppdatering';

  @override
  String get notificationSomeoneLikedYourVideo => 'Någon gillade din video';

  @override
  String get commentReplyToPrefix => 'Sv:';

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
  String get videoRecorderUploadTitle => 'Varför ingen uppladdning?';

  @override
  String get videoRecorderUploadBody =>
      'Det du ser på Divine är gjort av människor: rått och fångat i stunden. Till skillnad från plattformar som tillåter starkt producerade eller AI-genererade uppladdningar prioriterar vi äktheten i kamera-direkt-upplevelsen.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Genom att behålla skapandet i appen kan vi bättre garantera att innehållet är äkta och oredigerat. Vi öppnar inte upp för uppladdningar från externt galleri just nu, för att skydda den äktheten och hålla vår community fri från syntetiskt innehåll i största möjliga mån.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Byt till Capture eller Classic för att filma något äkta.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Läs om hur verifieringen fungerar';

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
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zooma till $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Växla rutnät';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Växla spökram';

  @override
  String get videoRecorderGhostFrameEnabled => 'Spökram aktiverad';

  @override
  String get videoRecorderGhostFrameDisabled => 'Spökram inaktiverad';

  @override
  String get videoRecorderClipDeletedMessage =>
      'Klipp flyttat till papperskorgen';

  @override
  String get videoRecorderClipUndoLabel => 'Ångra';

  @override
  String get libraryTrashTitle => 'Nyligen borttagna';

  @override
  String get libraryTrashEmptyTitle => 'Papperskorgen är tom';

  @override
  String get libraryTrashEmptySubtitle =>
      'Borttagna klipp finns kvar här i 30 dagar innan de tas bort permanent.';

  @override
  String get libraryTrashRestoreLabel => 'Återställ';

  @override
  String get libraryTrashDeleteNowLabel => 'Ta bort nu';

  @override
  String get libraryTrashEmptyAllLabel => 'Töm papperskorgen';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Radera klippet nu?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Detta tar bort klippet från papperskorgen direkt.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Töm papperskorgen?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp',
      one: '1 klipp',
    );
    return 'Detta raderar $_temp0 permanent från papperskorgen direkt.';
  }

  @override
  String get libraryTrashEntryLabel => 'Nyligen borttagna';

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
  String get videoRecorderLipSyncAddAudioFirst =>
      'Lägg till ljud innan inspelning';

  @override
  String get videoRecorderToggleFlashLabel => 'Växla blixt';

  @override
  String get videoRecorderCycleTimerLabel => 'Växla timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Växla bildförhållande';

  @override
  String get videoRecorderStabilizationLabel => 'Stabilisering';

  @override
  String get videoRecorderStabilizationModeOff => 'Av';

  @override
  String get videoRecorderStabilizationModeStandard => 'Standard';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Filmisk';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Filmisk utökad';

  @override
  String get videoRecorderStabilizationModePreviewOptimized =>
      'Förhandsoptimerad';

  @override
  String get videoRecorderStabilizationModeLowLatency => 'Låg latens';

  @override
  String get videoRecorderStabilizationModeAuto => 'Auto';

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
  String get videoEditorTuneLabel => 'Justera';

  @override
  String get videoEditorOpenTuneSemanticLabel => 'Öppna justeringsredigeraren';

  @override
  String get videoEditorTuneBrightness => 'Ljusstyrka';

  @override
  String get videoEditorTuneContrast => 'Kontrast';

  @override
  String get videoEditorTuneSaturation => 'Mättnad';

  @override
  String get videoEditorTuneExposure => 'Exponering';

  @override
  String get videoEditorTuneHue => 'Nyans';

  @override
  String get videoEditorTuneTemperature => 'Temperatur';

  @override
  String get videoEditorTuneTint => 'Färgton';

  @override
  String get videoEditorTuneFade => 'Uttoning';

  @override
  String get videoEditorAudioLabel => 'Ljud';

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
  String get videoEditorVoiceOverLabel => 'Voice-over';

  @override
  String videoEditorVoiceOverTakeName(int number) {
    return 'Inspelning $number';
  }

  @override
  String get videoEditorOpenVoiceOverSemanticLabel => 'Spela in en voice-over';

  @override
  String get videoEditorVoiceOverRecordSemanticLabel => 'Starta inspelning';

  @override
  String get videoEditorVoiceOverStopSemanticLabel => 'Stoppa inspelning';

  @override
  String get videoEditorVoiceOverHint =>
      'Tryck för att spela in. Lägg till hur många tagningar du vill.';

  @override
  String videoEditorVoiceOverRecordingsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inspelningar',
      one: '1 inspelning',
      zero: 'Inga inspelningar än',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorVoiceOverDeleteLast => 'Ta bort senaste inspelningen';

  @override
  String get videoEditorVoiceOverPermissionTitle => 'Mikrofonåtkomst krävs';

  @override
  String get videoEditorVoiceOverPermissionBody =>
      'Tillåt åtkomst till mikrofonen för att spela in en voice-over.';

  @override
  String get videoEditorVoiceOverOpenSettings => 'Öppna inställningar';

  @override
  String get videoEditorVoiceOverRecordingStarted => 'Inspelning startad';

  @override
  String get videoEditorVoiceOverRecordingSaved => 'Inspelning sparad';

  @override
  String get videoEditorVoiceOverTooLong =>
      'Inspelningen är längre än din video';

  @override
  String get videoEditorPlaySemanticLabel => 'Spela';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausa';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Stäng av ljud';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Sätt på ljud';

  @override
  String get videoEditorVolumeSemanticLabel => 'Justera volym';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volym $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Dra för att justera';

  @override
  String get videoEditorOriginalAudioLabel => 'Originalljud';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Klipp $index';
  }

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
  String get videoEditorExtractAudioLabel => 'Extrahera ljud';

  @override
  String get videoEditorClipAudioTitle => 'Klippljud';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extrahera ljud från klipp och tysta originalet';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Kan inte extrahera ljud: klippet är inte tillgängligt lokalt.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Kunde inte extrahera ljud. Försök igen.';

  @override
  String get videoEditorSpeedLabel => 'Hastighet';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Ange uppspelningshastighet för valt klipp';

  @override
  String get videoEditorReverseLabel => 'Baklänges';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Aktivera eller inaktivera omvänd uppspelning för valt klipp';

  @override
  String get videoEditorReverseProgressLabel =>
      'Ett ögonblick, vi vänder ditt klipp baklänges';

  @override
  String get videoEditorTransformLabel => 'Transformera';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Beskär, rotera eller vänd det valda klippet';

  @override
  String get videoEditorTransformProgressLabel =>
      'Ett ögonblick, vi transformerar ditt klipp';

  @override
  String get videoEditorTransformFailed =>
      'Det gick inte att transformera klippet. Försök igen.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Kan inte transformera: klippet är inte tillgängligt lokalt.';

  @override
  String get videoEditorTransformRotateLabel => 'Rotera';

  @override
  String get videoEditorTransformFlipLabel => 'Vänd';

  @override
  String get videoEditorTransformRatioLabel => 'Förhållande';

  @override
  String get videoEditorTransformResetLabel => 'Återställ';

  @override
  String get videoEditorTransformApplySemanticLabel =>
      'Tillämpa transformering';

  @override
  String get videoEditorTransformCancelSemanticLabel => 'Avbryt transformering';

  @override
  String get videoEditorTransformPlayLabel => 'Spela';

  @override
  String get videoEditorTransformPauseLabel => 'Pausa';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Kan inte vända baklänges: klippet är inte tillgängligt lokalt.';

  @override
  String get videoEditorReverseFailed =>
      'Kunde inte vända klippet baklänges. Försök igen.';

  @override
  String get videoEditorSpeedSheetTitle => 'Klipphastighet';

  @override
  String get videoEditorTransitionSheetTitle => 'Övergång';

  @override
  String get videoEditorTransitionNone => 'Ingen';

  @override
  String get videoEditorTransitionDissolve => 'Övertoning';

  @override
  String get videoEditorTransitionFadeToBlack => 'Tona till svart';

  @override
  String get videoEditorTransitionFadeToWhite => 'Tona till vitt';

  @override
  String get videoEditorTransitionSlide => 'Glidning';

  @override
  String get videoEditorTransitionPush => 'Putta';

  @override
  String get videoEditorTransitionWipe => 'Svep';

  @override
  String get videoEditorTransitionButtonSemanticLabel => 'Redigera övergång';

  @override
  String get videoEditorTransitionDuration => 'Längd';

  @override
  String get videoEditorTransitionDurationLimitedHint =>
      'Förkortad så att den inte överlappar den intilliggande övergången.';

  @override
  String get videoEditorTransitionCurve => 'Kurva';

  @override
  String get videoEditorTransitionDirection => 'Riktning';

  @override
  String get videoEditorTransitionDirectionLeft => 'Vänster';

  @override
  String get videoEditorTransitionDirectionRight => 'Höger';

  @override
  String get videoEditorTransitionDirectionUp => 'Upp';

  @override
  String get videoEditorTransitionDirectionDown => 'Ned';

  @override
  String videoEditorTransitionCurveOptionSemanticLabel(int number) {
    return 'Animeringskurva $number';
  }

  @override
  String get videoEditorLayerAnimationLabel => 'Animering';

  @override
  String get videoEditorLayerAnimationButtonSemanticLabel =>
      'Redigera lageranimering';

  @override
  String get videoEditorLayerAnimationEnter => 'In';

  @override
  String get videoEditorLayerAnimationLeave => 'Ut';

  @override
  String get videoEditorLayerAnimationFade => 'Toning';

  @override
  String get videoEditorLayerAnimationScale => 'Skala';

  @override
  String get videoEditorLayerAnimationScaleFrom => 'Skala från';

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
  String get videoEditorAudioCategoryDivine => 'OG Sounds';

  @override
  String get videoEditorAudioCategoryCommunity => 'Gemenskap';

  @override
  String get videoEditorAudioCategoryFeatured => 'Utvalda';

  @override
  String get videoEditorAudioCategoryMySounds => 'Mina ljud';

  @override
  String get videoEditorAudioFeaturedEmptyTitle => 'Utvalda ljud kommer snart';

  @override
  String get videoEditorAudioFeaturedEmptySubtitle =>
      'Vi släpper utvalda ljud här när de är klara.';

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
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Klipp $index av $total, markerat';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Klipp $index av $total, inte markerat';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Markera';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Markera flera klipp';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Slutför markering';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count klipp markerade',
      one: '1 klipp markerat',
      zero: 'Inga klipp markerade',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Slå samman';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Slå samman markerade klipp';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Ta bort markerade klipp';

  @override
  String get videoEditorMergeProgressLabel =>
      'Ett ögonblick, vi slår samman dina klipp';

  @override
  String get videoEditorMergeFailed =>
      'Det gick inte att slå samman klippen. Försök igen.';

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
  String get videoMetadataAudioReuseTitle => 'Publicera detta ljud';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Låt andra spara och återanvända videons ljud.';

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
  String get videoMetadataShareReplyToFeedTitle => 'Dela också i mitt flöde';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Av betyder att den här videon bara stannar i kommentarstråden.';

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
  String get fullscreenFeedRemovedMessage => 'Video borttagen';

  @override
  String get settingsBadgesTitle => 'Märken';

  @override
  String get settingsBadgesSubtitle =>
      'Acceptera utmärkelser och kolla status på utfärdade märken.';

  @override
  String get badgesTitle => 'Märken';

  @override
  String get badgesIntroTitle => 'Förstå ditt märkesspår';

  @override
  String get badgesIntroBody =>
      'Se märkesutmärkelser som skickats till dig, välj vilka du vill fästa på din Nostr-profil, och kolla om folk accepterat märken du utfärdat.';

  @override
  String get badgesOpenApp => 'Öppna märkesappen';

  @override
  String get badgesLoadError => 'Kunde inte ladda märken';

  @override
  String get badgesUpdateError => 'Kunde inte uppdatera märke';

  @override
  String get badgesAwardedSectionTitle => 'Tilldelade dig';

  @override
  String get badgesAwardedEmptyTitle => 'Inga märkesutmärkelser än';

  @override
  String get badgesAwardedEmptySubtitle =>
      'När någon tilldelar dig ett Nostr-märke landar det här.';

  @override
  String get badgesStatusAccepted => 'Accepterat';

  @override
  String get badgesStatusNotAccepted => 'Inte accepterat';

  @override
  String get badgesActionRemove => 'Ta bort';

  @override
  String get badgesActionAccept => 'Acceptera';

  @override
  String get badgesActionReject => 'Avvisa';

  @override
  String get badgesIssuedSectionTitle => 'Utfärdade av dig';

  @override
  String get badgesIssuedEmptyTitle => 'Inga utfärdade märken än';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Märken du utfärdar visar acceptansstatus här.';

  @override
  String get badgesIssuedNoRecipients =>
      'Inga mottagare hittades för den här utmärkelsen.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepterat av mottagare';

  @override
  String get badgesRecipientWaitingStatus => 'Väntar på mottagare';

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
      'Varför vi inte säger åt dig att bara klicka tillbaka';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'Mycket av internet är byggt för att belöna folk som säger vad som helst för att ta sig igenom grinden. Vi tycker inte att det är bra. Visst, du skulle kunna gå tillbaka och säga att du är äldre än du är, men det vore inte ärligt, och vi tänker inte lära dig att ljuga för att få som du vill.';

  @override
  String get minorAccountReviewUnder13LegalTitle => 'Varför svaret ändå är nej';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'Vi försöker hjälpa unga att använda Divine på sätt som är hälsosamma och positiva för dem och för människorna omkring dem. Vi måste också följa lagar som skiljer sig åt på olika platser. Så om du är under 13 är svaret att du inte kan ha ett eget konto i dag.';

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
      'Varför vi ber en förälder eller vårdnadshavare att vara delaktig';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine måste följa åldersrelaterade lagar runt om i världen. Vi vet också att de flesta tekniska ålderskontroller är bristfälliga. I stället för att låtsas att reglerna inte finns eller att det är coolt att ljuga om sin ålder vill vi att tonåringar och familjer ska fatta genomtänkta beslut om hur Divine bäst används. Därför ber vi föräldrar att vara en del av kontoskapandet för 13–15-åringar.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'Vi måste också följa lagen, och de reglerna skiljer sig åt beroende på var man bor. Så i stället för att låtsas att reglerna inte finns ber vi en förälder eller vårdnadshavare att vara en del av processen.';

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
  String get commentsRecordVideoButtonLabel => 'Spela in videokommentar';

  @override
  String get commentsOpenVideoLabel => 'Öppna videokommentar';

  @override
  String get commentsMuteVideoReplyLabel => 'Tysta videosvar';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Slå på ljud för videosvar';

  @override
  String get commentsOpenReplyParentLabel => 'Öppna videon som detta svarar på';

  @override
  String get commentsReplyParentSectionTitle => 'Som svar på';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Svar på $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Svar på video';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Verifierat $platform-konto: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Verifierade konton';

  @override
  String get profileEditGetVerifiedCta => 'Verifiera dig';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Koppla dina sociala medier-konton så folk vet att det är du.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visit website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Could not open website';

  @override
  String get videoMetadataEditCoverTitle => 'Redigera omslag';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Stäng omslagsredigerare';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Bekräfta omslagsval';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Sök igenom videon för att välja omslagsbild';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Sök eller lägg till taggar';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Lägg till taggar så att andra hittar din video';

  @override
  String get videoMetadataTagsPickerNoResults => 'Inga matchande taggar';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Lägg till ”#$tag”';
  }

  @override
  String get authMinAgeNotice => 'Divine Greenlight';

  @override
  String get authUnder16Prefix => 'Inte 16 än? Det är okej. ';

  @override
  String get authUnder16ChoicesCta => 'Här är dina alternativ.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Here\'s why';

  @override
  String get generalSettingsHoldToRecord => 'Håll inne för att spela in';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'Inspelning startar när du håller inne och stannar när du släpper';

  @override
  String get soundsPreviewFailedGeneric => 'Kunde inte spela förhandsvisning';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videor publicerade till din profil',
      one: 'Videon publicerad till din profil',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Send message';

  @override
  String get emojiPickerSearchHint => 'Sök';

  @override
  String get emojiCategoryRecent => 'Senaste';

  @override
  String get emojiCategorySmileys => 'Smileys och personer';

  @override
  String get emojiCategoryAnimals => 'Djur och natur';

  @override
  String get emojiCategoryFood => 'Mat och dryck';

  @override
  String get emojiCategoryActivities => 'Aktiviteter';

  @override
  String get emojiCategoryTravel => 'Resor och platser';

  @override
  String get emojiCategoryObjects => 'Objekt';

  @override
  String get emojiCategorySymbols => 'Symboler';

  @override
  String get emojiCategoryFlags => 'Flaggor';

  @override
  String get videoEditorMarkerLabel => 'Markör';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Lägg till tidslinjemarkör';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Ta bort tidslinjemarkör';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Radera markör?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Detta tar bort markören från tidslinjen. Din redigering behålls.';

  @override
  String get videoEditorVolumeLongPressHint => 'Tysta eller slå på alla spår';

  @override
  String get videoEditorSplitFailed => 'Delning misslyckades. Försök igen.';

  @override
  String get videoEditEditSubtitles => 'Redigera undertexter';

  @override
  String get subtitleEditorTitle => 'Redigera undertexter';

  @override
  String get subtitleEditorSave => 'Spara';

  @override
  String get subtitleEditorProcessing =>
      'Undertexter genereras fortfarande. Kom tillbaka om en stund.';

  @override
  String get subtitleEditorLoadError =>
      'Kunde inte läsa in undertexter. Försök igen.';

  @override
  String get subtitleEditorSaveSuccess => 'Undertexter uppdaterade';

  @override
  String get subtitleEditorSaveError =>
      'Kunde inte spara undertexter. Försök igen.';

  @override
  String get subtitleEditorRetry => 'Försök igen';

  @override
  String get subtitleEditorCueHint => 'Textningstext';

  @override
  String get imageCropEditorRotateLabel => 'Rotera';

  @override
  String get imageCropEditorFlipLabel => 'Vänd';

  @override
  String get imageCropEditorResetLabel => 'Återställ';

  @override
  String get imageCropEditorCloseSemanticLabel => 'Avbryt beskärning';

  @override
  String get imageCropEditorDoneSemanticLabel => 'Använd beskärning';

  @override
  String get imageCropEditorProcessing => 'Tillämpar beskärning…';

  @override
  String get backgroundUploadNotificationTitle => 'Laddar upp video';
}
