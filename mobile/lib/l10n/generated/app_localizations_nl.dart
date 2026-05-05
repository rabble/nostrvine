// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Instellingen';

  @override
  String get settingsSecureAccount => 'Beveilig je account';

  @override
  String get settingsSessionExpired => 'Sessie verlopen';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Log opnieuw in om volledige toegang te herstellen';

  @override
  String get settingsCreatorAnalytics => 'Creator-statistieken';

  @override
  String get settingsSupportCenter => 'Supportcentrum';

  @override
  String get settingsNotifications => 'Meldingen';

  @override
  String get settingsContentPreferences => 'Inhoudsvoorkeuren';

  @override
  String get settingsModerationControls => 'Moderatie-instellingen';

  @override
  String get settingsBlueskyPublishing => 'Bluesky-publicatie';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Beheer crossposting naar Bluesky';

  @override
  String get settingsNostrSettings => 'Nostr-instellingen';

  @override
  String get settingsIntegratedApps => 'Geïntegreerde apps';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Goedgekeurde externe apps die binnen Divine draaien';

  @override
  String get settingsExperimentalFeatures => 'Experimentele functies';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Tweaks die soms haperen—probeer ze als je nieuwsgierig bent.';

  @override
  String get settingsLegal => 'Juridisch';

  @override
  String get settingsIntegrationPermissions => 'Integratierechten';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Bekijk en trek onthouden integratiegoedkeuringen in';

  @override
  String settingsVersion(String version) {
    return 'Versie $version';
  }

  @override
  String get settingsVersionEmpty => 'Versie';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Ontwikkelaarsmodus is al ingeschakeld';

  @override
  String get settingsDeveloperModeEnabled => 'Ontwikkelaarsmodus ingeschakeld!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Nog $count keer tikken om ontwikkelaarsmodus in te schakelen';
  }

  @override
  String get settingsInvites => 'Uitnodigingen';

  @override
  String get settingsSwitchAccount => 'Wissel van account';

  @override
  String get settingsAddAnotherAccount => 'Nog een account toevoegen';

  @override
  String get settingsUnsavedDraftsTitle => 'Niet-opgeslagen concepten';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count niet-opgeslagen concepten',
      one: '1 niet-opgeslagen concept',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'je concepten',
      one: 'je concept',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'ze',
      one: 'het',
    );
    return 'Je hebt $_temp0. Als je van account wisselt blijven $_temp1 bewaard, maar misschien wil je $_temp2 eerst publiceren of nakijken.';
  }

  @override
  String get settingsCancel => 'Annuleren';

  @override
  String get settingsSwitchAnyway => 'Toch wisselen';

  @override
  String get settingsAppVersionLabel => 'App-versie';

  @override
  String get settingsAppLanguage => 'App-taal';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (standaard op apparaat)';
  }

  @override
  String get settingsAppLanguageTitle => 'App-taal';

  @override
  String get settingsAppLanguageDescription =>
      'Kies de taal voor de app-interface';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Gebruik apparaattaal';

  @override
  String get settingsGeneralTitle => 'Algemene instellingen';

  @override
  String get settingsContentSafetyTitle => 'Inhoud & veiligheid';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRATIES';

  @override
  String get generalSettingsSectionViewing => 'BEKIJKEN';

  @override
  String get generalSettingsSectionCreating => 'MAKEN';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get generalSettingsClosedCaptions => 'Ondertiteling';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Toon ondertiteling als video\'s die hebben';

  @override
  String get generalSettingsVideoShape => 'Videovorm';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Alleen vierkante video\'s';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait =>
      'Vierkant en portret';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Toon de volledige mix van Divine-video\'s';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Hou feeds in het klassieke vierkante formaat';

  @override
  String get contentPreferencesTitle => 'Inhoudsvoorkeuren';

  @override
  String get contentPreferencesContentFilters => 'Inhoudsfilters';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Beheer filters voor inhoudswaarschuwingen';

  @override
  String get contentPreferencesContentLanguage => 'Inhoudstaal';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (standaard op apparaat)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag je video\'s met een taal zodat kijkers inhoud kunnen filteren.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Gebruik apparaattaal (standaard)';

  @override
  String get contentPreferencesAudioSharing =>
      'Maak mijn audio beschikbaar voor hergebruik';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Als dit aanstaat kunnen anderen audio uit je video\'s gebruiken';

  @override
  String get contentPreferencesAccountLabels => 'Accountlabels';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Label je eigen inhoud';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Inhoudslabels voor account';

  @override
  String get contentPreferencesClearAll => 'Alles wissen';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Selecteer alles wat op jouw account van toepassing is';

  @override
  String get contentPreferencesDoneNoLabels => 'Klaar (geen labels)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Klaar ($count geselecteerd)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio-invoerapparaat';

  @override
  String get contentPreferencesAutoRecommended => 'Automatisch (aanbevolen)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Kiest automatisch de beste microfoon';

  @override
  String get contentPreferencesSelectAudioInput => 'Kies audio-invoer';

  @override
  String get contentPreferencesUnknownMicrophone => 'Onbekende microfoon';

  @override
  String get contentFiltersAdultContent => 'INHOUD VOOR VOLWASSENEN';

  @override
  String get contentFiltersViolenceGore => 'GEWELD & BLOED';

  @override
  String get contentFiltersSubstances => 'MIDDELEN';

  @override
  String get contentFiltersOther => 'OVERIG';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifieer je leeftijd bij Veiligheid & privacy om filters voor volwassen inhoud vrij te schakelen';

  @override
  String get contentFiltersShow => 'Tonen';

  @override
  String get contentFiltersWarn => 'Waarschuwen';

  @override
  String get contentFiltersFilterOut => 'Eruit filteren';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Dit account is niet beschikbaar';

  @override
  String profileErrorPrefix(Object error) {
    return 'Fout: $error';
  }

  @override
  String get profileInvalidId => 'Ongeldige profiel-ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Bekijk $displayName op Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName op Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Profiel delen mislukt: $error';
  }

  @override
  String get profileEditProfile => 'Profiel bewerken';

  @override
  String get profileCreatorAnalytics => 'Creator-statistieken';

  @override
  String get profileShareProfile => 'Profiel delen';

  @override
  String get profileCopyPublicKey => 'Publieke sleutel kopiëren (npub)';

  @override
  String get profileGetEmbedCode => 'Embedcode ophalen';

  @override
  String get profilePublicKeyCopied =>
      'Publieke sleutel gekopieerd naar klembord';

  @override
  String get profileEmbedCodeCopied => 'Embedcode gekopieerd naar klembord';

  @override
  String get profileRefreshTooltip => 'Vernieuwen';

  @override
  String get profileRefreshSemanticLabel => 'Profiel vernieuwen';

  @override
  String get profileMoreTooltip => 'Meer';

  @override
  String get profileMoreSemanticLabel => 'Meer opties';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Avatar sluiten';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Avatarvoorbeeld sluiten';

  @override
  String get profileFollowingLabel => 'Volgend';

  @override
  String get profileFollowLabel => 'Volgen';

  @override
  String get profileBlockedLabel => 'Geblokkeerd';

  @override
  String get profileFollowersLabel => 'Volgers';

  @override
  String get profileFollowingStatLabel => 'Volgend';

  @override
  String get profileVideosLabel => 'Video\'s';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count gebruikers';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName blokkeren?';
  }

  @override
  String get profileBlockExplanation => 'Als je iemand blokkeert:';

  @override
  String get profileBlockBulletHidePosts =>
      'Hun posts verschijnen niet meer in jouw feeds.';

  @override
  String get profileBlockBulletCantView =>
      'Ze kunnen jouw profiel niet bekijken, je niet volgen en je posts niet zien.';

  @override
  String get profileBlockBulletNoNotify => 'Ze krijgen hiervan geen melding.';

  @override
  String get profileBlockBulletYouCanView =>
      'Jij kunt hun profiel nog wel bekijken.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName blokkeren';
  }

  @override
  String get profileCancelButton => 'Annuleren';

  @override
  String get profileLearnMore => 'Meer info';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName deblokkeren?';
  }

  @override
  String get profileUnblockExplanation => 'Als je deze gebruiker deblokkeert:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Hun posts verschijnen weer in jouw feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'Ze kunnen jouw profiel bekijken, je volgen en je posts zien.';

  @override
  String get profileUnblockBulletNoNotify => 'Ze krijgen hiervan geen melding.';

  @override
  String get profileLearnMoreAt => 'Meer info op ';

  @override
  String get profileUnblockButton => 'Deblokkeren';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName ontvolgen';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName blokkeren';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName deblokkeren';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return '$displayName aan een lijst toevoegen';
  }

  @override
  String get profileUserBlockedTitle => 'Gebruiker geblokkeerd';

  @override
  String get profileUserBlockedContent =>
      'Je ziet geen inhoud meer van deze gebruiker in je feeds.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Je kunt ze altijd deblokkeren via hun profiel of bij Instellingen > Veiligheid.';

  @override
  String get profileCloseButton => 'Sluiten';

  @override
  String get profileNoCollabsTitle => 'Nog geen samenwerkingen';

  @override
  String get profileCollabsOwnEmpty =>
      'Video\'s waar je aan meewerkt verschijnen hier';

  @override
  String get profileCollabsOtherEmpty =>
      'Video\'s waar zij aan meewerken verschijnen hier';

  @override
  String get profileErrorLoadingCollabs =>
      'Fout bij laden van samenwerkingsvideo\'s';

  @override
  String get profileNoSavedVideosTitle => 'Nog niets bewaard';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark video\'s vanuit het deelmenu en ze duiken hier op.';

  @override
  String get profileErrorLoadingSaved => 'Fout bij laden van bewaarde video\'s';

  @override
  String get profileNoCommentsOwnTitle => 'Nog geen reacties';

  @override
  String get profileNoCommentsOtherTitle => 'Geen reacties';

  @override
  String get profileCommentsOwnEmpty =>
      'Je reacties en antwoorden verschijnen hier';

  @override
  String get profileCommentsOtherEmpty =>
      'Hun reacties en antwoorden verschijnen hier';

  @override
  String get profileErrorLoadingComments => 'Fout bij laden van reacties';

  @override
  String get profileVideoRepliesSection => 'Videoreacties';

  @override
  String get profileCommentsSection => 'Reacties';

  @override
  String get profileEditLabel => 'Bewerken';

  @override
  String get profileLibraryLabel => 'Bibliotheek';

  @override
  String get profileNoLikedVideosTitle => 'Nog geen gelikete video\'s';

  @override
  String get profileLikedOwnEmpty => 'Video\'s die je liket verschijnen hier';

  @override
  String get profileLikedOtherEmpty =>
      'Video\'s die zij liken verschijnen hier';

  @override
  String get profileErrorLoadingLiked => 'Fout bij laden van gelikete video\'s';

  @override
  String get profileNoRepostsTitle => 'Nog geen reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Video\'s die je repost verschijnen hier';

  @override
  String get profileRepostsOtherEmpty =>
      'Video\'s die zij reposten verschijnen hier';

  @override
  String get profileErrorLoadingReposts => 'Fout bij laden van reposts';

  @override
  String get profileLoadingTitle => 'Profiel laden...';

  @override
  String get profileLoadingSubtitle => 'Dit kan even duren';

  @override
  String get profileLoadingVideos => 'Video\'s laden...';

  @override
  String get profileNoVideosTitle => 'Nog geen video\'s';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Deel je eerste video om hem hier te zien';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Deze gebruiker heeft nog geen video\'s gedeeld';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Videominiatuur $number';
  }

  @override
  String get profileShowMore => 'Meer weergeven';

  @override
  String get profileShowLess => 'Minder weergeven';

  @override
  String get profileCompleteYourProfile => 'Maak je profiel af';

  @override
  String get profileCompleteSubtitle =>
      'Voeg je naam, bio en foto toe om te beginnen';

  @override
  String get profileSetUpButton => 'Instellen';

  @override
  String get profileVerifyingEmail => 'E-mail verifiëren...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Check $email voor de verificatielink';
  }

  @override
  String get profileWaitingForVerification => 'Wachten op e-mailverificatie';

  @override
  String get profileVerificationFailed => 'Verificatie mislukt';

  @override
  String get profilePleaseTryAgain => 'Probeer het opnieuw';

  @override
  String get profileSecureYourAccount => 'Beveilig je account';

  @override
  String get profileSecureSubtitle =>
      'Voeg e-mail & wachtwoord toe om je account op elk apparaat te herstellen';

  @override
  String get profileRetryButton => 'Opnieuw proberen';

  @override
  String get profileRegisterButton => 'Registreren';

  @override
  String get profileSessionExpired => 'Sessie verlopen';

  @override
  String get profileSignInToRestore =>
      'Log opnieuw in om volledige toegang te herstellen';

  @override
  String get profileSignInButton => 'Inloggen';

  @override
  String get profileMaybeLaterLabel => 'Misschien later';

  @override
  String get profileSecurePrimaryButton => 'E-mail & wachtwoord toevoegen';

  @override
  String get profileCompletePrimaryButton => 'Werk je profiel bij';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'Mijn bibliotheek';

  @override
  String get profileMessageLabel => 'Bericht';

  @override
  String get profileUserFallback => 'gebruiker';

  @override
  String get profileDismissTooltip => 'Sluiten';

  @override
  String get profileLinkCopied => 'Profiellink gekopieerd';

  @override
  String get profileSetupEditProfileTitle => 'Profiel bewerken';

  @override
  String get profileSetupBackLabel => 'Terug';

  @override
  String get profileSetupAboutNostr => 'Over Nostr';

  @override
  String get profileSetupProfilePublished => 'Profiel succesvol gepubliceerd!';

  @override
  String get profileSetupCreateNewProfile => 'Nieuw profiel aanmaken?';

  @override
  String get profileSetupNoExistingProfile =>
      'We vonden geen bestaand profiel op je relays. Publiceren maakt een nieuw profiel aan. Doorgaan?';

  @override
  String get profileSetupPublishButton => 'Publiceren';

  @override
  String get profileSetupUsernameTaken =>
      'Deze gebruikersnaam is net bezet. Kies een andere.';

  @override
  String get profileSetupClaimFailed =>
      'Gebruikersnaam claimen mislukt. Probeer het opnieuw.';

  @override
  String get profileSetupPublishFailed =>
      'Profiel publiceren mislukt. Probeer het opnieuw.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Kan het netwerk niet bereiken. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get profileSetupRetryLabel => 'Opnieuw';

  @override
  String get profileSetupDisplayNameLabel => 'Weergavenaam';

  @override
  String get profileSetupDisplayNameHint => 'Hoe moeten mensen je kennen?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Elke naam of label die je wilt. Hoeft niet uniek te zijn.';

  @override
  String get profileSetupDisplayNameRequired => 'Voer een weergavenaam in';

  @override
  String get profileSetupBioLabel => 'Bio (optioneel)';

  @override
  String get profileSetupBioHint => 'Vertel iets over jezelf...';

  @override
  String get profileSetupPublicKeyLabel => 'Publieke sleutel (npub)';

  @override
  String get profileSetupUsernameLabel => 'Gebruikersnaam (optioneel)';

  @override
  String get profileSetupUsernameHint => 'gebruikersnaam';

  @override
  String get profileSetupUsernameHelper => 'Je unieke identiteit op Divine';

  @override
  String get profileSetupProfileColorLabel => 'Profielkleur (optioneel)';

  @override
  String get profileSetupSaveButton => 'Opslaan';

  @override
  String get profileSetupSavingButton => 'Opslaan...';

  @override
  String get profileSetupImageUrlTitle => 'Afbeeldings-URL toevoegen';

  @override
  String get profileSetupPictureUploaded => 'Profielfoto succesvol geüpload!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Afbeelding kiezen mislukt. Plak hieronder een afbeeldings-URL.';

  @override
  String get profileSetupImagesTypeGroup => 'afbeeldingen';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Cameratoegang mislukt: $error';
  }

  @override
  String get profileSetupGotItButton => 'Begrepen';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Uploaden van afbeelding mislukt. Probeer het later opnieuw.';

  @override
  String get profileSetupUploadNetworkError =>
      'Netwerkfout: check je internetverbinding en probeer opnieuw.';

  @override
  String get profileSetupUploadAuthError =>
      'Authenticatiefout: log uit en weer in.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Bestand te groot: kies een kleinere afbeelding (max 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Uploaden van afbeelding mislukt. Onze servers zijn tijdelijk niet beschikbaar. Probeer het zo opnieuw.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'Het uploaden van een profielfoto is nog niet beschikbaar op web. Gebruik de iOS- of Android-app, of plak een afbeeldings-URL.';

  @override
  String get profileSetupUsernameChecking => 'Beschikbaarheid controleren...';

  @override
  String get profileSetupUsernameAvailable => 'Gebruikersnaam beschikbaar!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Gebruikersnaam al in gebruik';

  @override
  String get profileSetupUsernameReserved => 'Gebruikersnaam is gereserveerd';

  @override
  String get profileSetupContactSupport => 'Neem contact op met support';

  @override
  String get profileSetupCheckAgain => 'Opnieuw controleren';

  @override
  String get profileSetupUsernameBurned =>
      'Deze gebruikersnaam is niet meer beschikbaar';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Alleen letters, cijfers en koppeltekens zijn toegestaan';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Gebruikersnaam moet 3-20 tekens zijn';

  @override
  String get profileSetupUsernameNetworkError =>
      'Beschikbaarheid checken mislukt. Probeer opnieuw.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Ongeldig formaat voor gebruikersnaam';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Beschikbaarheid checken mislukt';

  @override
  String get profileSetupUsernameReservedTitle => 'Gebruikersnaam gereserveerd';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'De naam $username is gereserveerd. Vertel ons waarom hij van jou zou moeten zijn.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Bijv. het is mijn merknaam, artiestennaam, enz.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Al contact opgenomen met support? Tik op \"Opnieuw controleren\" om te zien of hij aan jou is toegewezen.';

  @override
  String get profileSetupSupportRequestSent =>
      'Supportverzoek verzonden! We nemen snel contact op.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'E-mail openen mislukt. Stuur naar: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Verzoek versturen';

  @override
  String get profileSetupPickColorTitle => 'Kies een kleur';

  @override
  String get profileSetupSelectButton => 'Selecteren';

  @override
  String get profileSetupUseOwnNip05 => 'Gebruik je eigen NIP-05-adres';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05-adres';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Ongeldig NIP-05-formaat (bijv. naam@domein.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Gebruik het gebruikersnaamveld hierboven voor divine.video';

  @override
  String get profileSetupProfilePicturePreview => 'Voorbeeld profielfoto';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine is gebouwd op Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' een censuurbestendig open protocol waarmee mensen online kunnen communiceren zonder afhankelijk te zijn van één bedrijf of platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Als je je aanmeldt bij Divine krijg je een nieuwe Nostr-identiteit.';

  @override
  String get nostrInfoOwnership =>
      'Met Nostr heb je je eigen inhoud, identiteit en sociale graaf in handen, die je in veel apps kunt gebruiken. Resultaat: meer keuze, minder lock-in en een gezonder, veerkrachtiger sociaal internet.';

  @override
  String get nostrInfoLingo => 'Nostr-jargon:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Je publieke Nostr-adres. Veilig om te delen: anderen kunnen je zo vinden, volgen of berichten sturen in Nostr-apps.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Je privésleutel en eigendomsbewijs. Hij geeft volledige controle over je Nostr-identiteit, dus ';

  @override
  String get nostrInfoNsecWarning => 'houd hem altijd geheim!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr-gebruikersnaam:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Een menselijk leesbare naam (zoals @naam.divine.video) die naar je npub verwijst. Het maakt je Nostr-identiteit makkelijker te herkennen en verifiëren, vergelijkbaar met een e-mailadres.';

  @override
  String get nostrInfoLearnMoreAt => 'Meer info op ';

  @override
  String get nostrInfoGotIt => 'Begrepen!';

  @override
  String get profileTabRefreshTooltip => 'Vernieuwen';

  @override
  String get videoGridRefreshLabel => 'Zoeken naar meer video\'s';

  @override
  String get videoGridOptionsTitle => 'Video-opties';

  @override
  String get videoGridEditVideo => 'Video bewerken';

  @override
  String get videoGridEditVideoSubtitle =>
      'Titel, beschrijving en hashtags bijwerken';

  @override
  String get videoGridDeleteVideo => 'Video verwijderen';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Deze inhoud definitief verwijderen';

  @override
  String get videoGridDeleteConfirmTitle => 'Video verwijderen';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Weet je zeker dat je deze video wilt verwijderen?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Dit stuurt een verwijderverzoek (NIP-09) naar alle relays. Sommige relays kunnen de inhoud alsnog bewaren.';

  @override
  String get videoGridDeleteCancel => 'Annuleren';

  @override
  String get videoGridDeleteConfirm => 'Verwijderen';

  @override
  String get videoGridDeletingContent => 'Inhoud verwijderen...';

  @override
  String get videoGridDeleteSuccess => 'Verwijderverzoek succesvol verstuurd';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Inhoud verwijderen mislukt: $error';
  }

  @override
  String get exploreTabClassics => 'Klassiekers';

  @override
  String get exploreTabNew => 'Nieuw';

  @override
  String get exploreTabPopular => 'Populair';

  @override
  String get exploreTabCategories => 'Categorieën';

  @override
  String get exploreTabForYou => 'Voor jou';

  @override
  String get exploreTabLists => 'Lijsten';

  @override
  String get exploreTabIntegratedApps => 'Geïntegreerde apps';

  @override
  String get exploreNoVideosAvailable => 'Geen video\'s beschikbaar';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Fout: $error';
  }

  @override
  String get exploreDiscoverLists => 'Lijsten ontdekken';

  @override
  String get exploreAboutLists => 'Over lijsten';

  @override
  String get exploreAboutListsDescription =>
      'Met lijsten kun je Divine-inhoud op twee manieren organiseren en samenstellen:';

  @override
  String get explorePeopleLists => 'Personenlijsten';

  @override
  String get explorePeopleListsDescription =>
      'Volg groepen makers en bekijk hun nieuwste video\'s';

  @override
  String get exploreVideoLists => 'Videolijsten';

  @override
  String get exploreVideoListsDescription =>
      'Maak afspeellijsten van je favoriete video\'s om later te bekijken';

  @override
  String get exploreMyLists => 'Mijn lijsten';

  @override
  String get exploreSubscribedLists => 'Gevolgde lijsten';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Fout bij laden van lijsten: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieuwe video\'\'s',
      one: '1 nieuwe video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nieuwe video\'\'s',
      one: '1 nieuwe video',
    );
    return '$_temp0 laden';
  }

  @override
  String get videoPlayerLoadingVideo => 'Video laden...';

  @override
  String get videoPlayerPlayVideo => 'Video afspelen';

  @override
  String get videoPlayerMute => 'Video dempen';

  @override
  String get videoPlayerUnmute => 'Videogeluid inschakelen';

  @override
  String get videoPlayerEditVideo => 'Video bewerken';

  @override
  String get videoPlayerEditVideoTooltip => 'Video bewerken';

  @override
  String get contentWarningLabel => 'Inhoudswaarschuwing';

  @override
  String get contentWarningNudity => 'Naaktheid';

  @override
  String get contentWarningSexualContent => 'Seksuele inhoud';

  @override
  String get contentWarningPornography => 'Pornografie';

  @override
  String get contentWarningGraphicMedia => 'Expliciete media';

  @override
  String get contentWarningViolence => 'Geweld';

  @override
  String get contentWarningSelfHarm => 'Zelfbeschadiging';

  @override
  String get contentWarningDrugUse => 'Drugsgebruik';

  @override
  String get contentWarningAlcohol => 'Alcohol';

  @override
  String get contentWarningTobacco => 'Tabak';

  @override
  String get contentWarningGambling => 'Gokken';

  @override
  String get contentWarningProfanity => 'Grof taalgebruik';

  @override
  String get contentWarningFlashingLights => 'Flitslichten';

  @override
  String get contentWarningAiGenerated => 'AI-gegenereerd';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Gevoelige inhoud';

  @override
  String get contentWarningDescNudity =>
      'Bevat naaktheid of gedeeltelijke naaktheid';

  @override
  String get contentWarningDescSexual => 'Bevat seksuele inhoud';

  @override
  String get contentWarningDescPorn => 'Bevat expliciete pornografische inhoud';

  @override
  String get contentWarningDescGraphicMedia =>
      'Bevat expliciete of verontrustende beelden';

  @override
  String get contentWarningDescViolence => 'Bevat gewelddadige inhoud';

  @override
  String get contentWarningDescSelfHarm =>
      'Bevat verwijzingen naar zelfbeschadiging';

  @override
  String get contentWarningDescDrugs => 'Bevat drugsgerelateerde inhoud';

  @override
  String get contentWarningDescAlcohol => 'Bevat alcoholgerelateerde inhoud';

  @override
  String get contentWarningDescTobacco => 'Bevat tabaksgerelateerde inhoud';

  @override
  String get contentWarningDescGambling => 'Bevat gokgerelateerde inhoud';

  @override
  String get contentWarningDescProfanity => 'Bevat grof taalgebruik';

  @override
  String get contentWarningDescFlashingLights =>
      'Bevat flitslichten (waarschuwing voor lichtgevoeligheid)';

  @override
  String get contentWarningDescAiGenerated =>
      'Deze inhoud is door AI gegenereerd';

  @override
  String get contentWarningDescSpoiler => 'Bevat spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'De maker heeft dit als gevoelig gemarkeerd';

  @override
  String get contentWarningDescDefault =>
      'De maker heeft deze inhoud gemarkeerd';

  @override
  String get contentWarningDetailsTitle => 'Inhoudswaarschuwingen';

  @override
  String get contentWarningDetailsSubtitle =>
      'De maker heeft deze labels toegepast:';

  @override
  String get contentWarningManageFilters => 'Inhoudsfilters beheren';

  @override
  String get contentWarningViewAnyway => 'Toch bekijken';

  @override
  String get contentWarningReportContentTooltip => 'Inhoud rapporteren';

  @override
  String get contentWarningBlockUserTooltip => 'Gebruiker blokkeren';

  @override
  String get contentWarningBlockedTitle => 'Inhoud geblokkeerd';

  @override
  String get contentWarningBlockedPolicy =>
      'Deze inhoud is geblokkeerd vanwege schending van het beleid.';

  @override
  String get contentWarningNoticeTitle => 'Inhoudsmelding';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Mogelijk schadelijke inhoud';

  @override
  String get contentWarningView => 'Bekijken';

  @override
  String get contentWarningReportAction => 'Rapporteren';

  @override
  String get contentWarningHideAllLikeThis => 'Verberg alle inhoud zoals deze';

  @override
  String get contentWarningNoFilterYet =>
      'Nog geen opgeslagen filter voor deze waarschuwing.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vanaf nu verbergen we posts zoals deze.';

  @override
  String get videoErrorNotFound => 'Video niet gevonden';

  @override
  String get videoErrorNetwork => 'Netwerkfout';

  @override
  String get videoErrorTimeout => 'Laden duurde te lang';

  @override
  String get videoErrorFormat =>
      'Videoformaatfout\n(Probeer opnieuw of gebruik een andere browser)';

  @override
  String get videoErrorUnsupportedFormat => 'Niet-ondersteund videoformaat';

  @override
  String get videoErrorPlayback => 'Fout bij afspelen video';

  @override
  String get videoErrorAgeRestricted => 'Leeftijdsbeperkte inhoud';

  @override
  String get videoErrorVerifyAge => 'Leeftijd verifiëren';

  @override
  String get videoErrorRetry => 'Opnieuw';

  @override
  String get videoErrorContentRestricted => 'Inhoud beperkt';

  @override
  String get videoErrorContentRestrictedBody =>
      'Deze video is beperkt door de relay.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifieer je leeftijd om deze video te bekijken.';

  @override
  String get videoErrorSkip => 'Overslaan';

  @override
  String get videoErrorVerifyAgeButton => 'Leeftijd verifiëren';

  @override
  String get videoFollowButtonFollowing => 'Volgend';

  @override
  String get videoFollowButtonFollow => 'Volgen';

  @override
  String get audioAttributionOriginalSound => 'Origineel geluid';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Geïnspireerd door @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'met @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'met @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samenwerkers',
      one: '1 samenwerker',
    );
    return '$_temp0. Tik om het profiel te bekijken.';
  }

  @override
  String get listAttributionFallback => 'Lijst';

  @override
  String get shareVideoLabel => 'Video delen';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post gedeeld met $recipientName';
  }

  @override
  String get shareFailedToSend => 'Video versturen mislukt';

  @override
  String get shareAddedToBookmarks => 'Toegevoegd aan bladwijzers';

  @override
  String get shareRemovedFromBookmarks => 'Verwijderd uit bladwijzers';

  @override
  String get shareFailedToAddBookmark => 'Bladwijzer toevoegen mislukt';

  @override
  String get shareFailedToRemoveBookmark =>
      'Verwijderen uit bladwijzers mislukt';

  @override
  String get shareActionFailed => 'Actie mislukt';

  @override
  String get shareWithTitle => 'Delen met';

  @override
  String get shareFindPeople => 'Mensen zoeken';

  @override
  String get shareFindPeopleMultiline => 'Mensen\nzoeken';

  @override
  String get shareSent => 'Verzonden';

  @override
  String get shareContactFallback => 'Contact';

  @override
  String get shareUserFallback => 'Gebruiker';

  @override
  String shareSendingTo(String name) {
    return 'Versturen naar $name';
  }

  @override
  String get shareMessageHint => 'Voeg optioneel een bericht toe...';

  @override
  String get videoActionUnlike => 'Like verwijderen';

  @override
  String get videoActionLike => 'Video liken';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Like';

  @override
  String get videoActionReplyLabel => 'Reageren';

  @override
  String get videoActionRepostLabel => 'Repost';

  @override
  String get videoActionShareLabel => 'Delen';

  @override
  String get videoActionAboutLabel => 'Over';

  @override
  String get videoActionEnableAutoAdvance => 'Automatisch doorgaan inschakelen';

  @override
  String get videoActionDisableAutoAdvance =>
      'Automatisch doorgaan uitschakelen';

  @override
  String get videoActionRemoveRepost => 'Repost verwijderen';

  @override
  String get videoActionRepost => 'Video reposten';

  @override
  String get videoActionViewComments => 'Reacties bekijken';

  @override
  String get videoActionMoreOptions => 'Meer opties';

  @override
  String get videoActionHideSubtitles => 'Ondertiteling verbergen';

  @override
  String get videoActionShowSubtitles => 'Ondertiteling tonen';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Videodetails openen';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Videodetails openen';

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
  String get metadataBadgeNotDivine => 'Niet Divine';

  @override
  String get metadataBadgeHumanMade => 'Door mensen gemaakt';

  @override
  String get metadataSoundsLabel => 'Geluiden';

  @override
  String get metadataOriginalSound => 'Origineel geluid';

  @override
  String get metadataVerificationLabel => 'Verificatie';

  @override
  String get metadataDeviceAttestation => 'Apparaatattestatie';

  @override
  String get metadataProofManifest => 'Proof-manifest';

  @override
  String get metadataCreatorLabel => 'Maker';

  @override
  String get metadataCollaboratorsLabel => 'Samenwerkers';

  @override
  String get metadataInspiredByLabel => 'Geïnspireerd door';

  @override
  String get metadataRepostedByLabel => 'Gerepost door';

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Likes';

  @override
  String get metadataCommentsLabel => 'Reacties';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Geplaatst op $date';
  }

  @override
  String get devOptionsTitle => 'Ontwikkelaarsopties';

  @override
  String get devOptionsPageLoadTimes => 'Laadtijden per pagina';

  @override
  String get devOptionsNoPageLoads =>
      'Nog geen paginaladingen geregistreerd.\nNavigeer door de app om timingdata te zien.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Zichtbaar: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Traagste schermen';

  @override
  String get devOptionsVideoPlaybackFormat => 'Videoformaat voor afspelen';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Omgeving wisselen?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Wisselen naar $envName?\n\nDit wist cached videodata en verbindt opnieuw met de nieuwe relay.';
  }

  @override
  String get devOptionsCancel => 'Annuleren';

  @override
  String get devOptionsSwitch => 'Wisselen';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Gewisseld naar $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Gewisseld naar $formatName — cache gewist';
  }

  @override
  String get featureFlagTitle => 'Feature flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Alle flags terugzetten naar standaard';

  @override
  String get featureFlagResetToDefault => 'Terug naar standaard';

  @override
  String get featureFlagAppRecovery => 'App-herstel';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Als de app crasht of gek doet, probeer dan de cache te wissen.';

  @override
  String get featureFlagClearAllCache => 'Alle cache wissen';

  @override
  String get featureFlagCacheInfo => 'Cache-info';

  @override
  String get featureFlagClearCacheTitle => 'Alle cache wissen?';

  @override
  String get featureFlagClearCacheMessage =>
      'Dit wist alle gecachte data, waaronder:\n• Meldingen\n• Gebruikersprofielen\n• Bladwijzers\n• Tijdelijke bestanden\n\nJe moet opnieuw inloggen. Doorgaan?';

  @override
  String get featureFlagClearCache => 'Cache wissen';

  @override
  String get featureFlagClearingCache => 'Cache wissen...';

  @override
  String get featureFlagSuccess => 'Gelukt';

  @override
  String get featureFlagError => 'Fout';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache succesvol gewist. Herstart de app.';

  @override
  String get featureFlagClearCacheFailure =>
      'Sommige cache-items zijn niet gewist. Check de logs voor details.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Cache-informatie';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Totale cache-grootte: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cache bevat:\n• Meldingsgeschiedenis\n• Gebruikersprofieldata\n• Videominiaturen\n• Tijdelijke bestanden\n• Database-indexen';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine is een open systeem — jij beheert je verbindingen';

  @override
  String get relaySettingsInfoDescription =>
      'Deze relays verspreiden jouw inhoud over het gedecentraliseerde Nostr-netwerk. Je kunt relays naar wens toevoegen of verwijderen.';

  @override
  String get relaySettingsLearnMoreNostr => 'Meer over Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Vind publieke relays op nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App niet functioneel';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine heeft minstens één relay nodig om video\'s te laden, inhoud te posten en data te synchroniseren.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Standaardrelay herstellen';

  @override
  String get relaySettingsAddCustomRelay => 'Eigen relay toevoegen';

  @override
  String get relaySettingsAddRelay => 'Relay toevoegen';

  @override
  String get relaySettingsRetry => 'Opnieuw';

  @override
  String get relaySettingsNoStats => 'Nog geen statistieken beschikbaar';

  @override
  String get relaySettingsConnection => 'Verbinding';

  @override
  String get relaySettingsConnected => 'Verbonden';

  @override
  String get relaySettingsDisconnected => 'Verbinding verbroken';

  @override
  String get relaySettingsSessionDuration => 'Sessieduur';

  @override
  String get relaySettingsLastConnected => 'Laatst verbonden';

  @override
  String get relaySettingsDisconnectedLabel => 'Verbinding verbroken';

  @override
  String get relaySettingsReason => 'Reden';

  @override
  String get relaySettingsActiveSubscriptions => 'Actieve abonnementen';

  @override
  String get relaySettingsTotalSubscriptions => 'Totaal abonnementen';

  @override
  String get relaySettingsEventsReceived => 'Ontvangen events';

  @override
  String get relaySettingsEventsSent => 'Verzonden events';

  @override
  String get relaySettingsRequestsThisSession => 'Verzoeken deze sessie';

  @override
  String get relaySettingsFailedRequests => 'Mislukte verzoeken';

  @override
  String relaySettingsLastError(String error) {
    return 'Laatste fout: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Relay-info laden...';

  @override
  String get relaySettingsAboutRelay => 'Over relay';

  @override
  String get relaySettingsSupportedNips => 'Ondersteunde NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Website bekijken';

  @override
  String get relaySettingsRemoveRelayTitle => 'Relay verwijderen?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Weet je zeker dat je deze relay wilt verwijderen?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Annuleren';

  @override
  String get relaySettingsRemove => 'Verwijderen';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay verwijderd: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Relay verwijderen mislukt';

  @override
  String get relaySettingsForcingReconnection =>
      'Relay opnieuw verbinden forceren...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Verbonden met $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Verbinden met relays mislukt. Check je netwerkverbinding.';

  @override
  String get relaySettingsAddRelayTitle => 'Relay toevoegen';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Voer de WebSocket-URL in van de relay die je wilt toevoegen:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Bekijk publieke relays op nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Toevoegen';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay toegevoegd: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Relay toevoegen mislukt. Check de URL en probeer opnieuw.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay-URL moet beginnen met wss:// of ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'Relay-URL moet wss:// gebruiken (ws:// is alleen toegestaan voor localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Standaardrelay hersteld: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Standaardrelay herstellen mislukt. Check je netwerkverbinding.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Browser openen mislukt';

  @override
  String get relaySettingsFailedToOpenLink => 'Link openen mislukt';

  @override
  String get relaySettingsExternalRelay => 'Externe relay';

  @override
  String get relaySettingsNotConnected => 'Niet verbonden';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return '$duration geleden verbroken';
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
    return '$duration geleden';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine gebruikt het Nostr-protocol voor decentraal publiceren. Je inhoud staat op relays die jij kiest, en je sleutels zijn je identiteit.';

  @override
  String get nostrSettingsSectionNetwork => 'Netwerk';

  @override
  String get nostrSettingsSectionAccount => 'Account';

  @override
  String get nostrSettingsSectionDangerZone => 'Gevarenzone';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Beheer Nostr-relayverbindingen';

  @override
  String get nostrSettingsRelayDiagnostics => 'Relaydiagnostiek';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Debug relayverbinding en netwerkproblemen';

  @override
  String get nostrSettingsMediaServers => 'Mediaservers';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configureer Blossom-uploadservers';

  @override
  String get nostrSettingsDeveloperOptions => 'Ontwikkelaarsopties';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Omgevingswisselaar en debug-instellingen';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Zet feature flags aan die soms haperen.';

  @override
  String get nostrSettingsKeyManagement => 'Sleutelbeheer';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exporteer, back-up en herstel je Nostr-sleutels';

  @override
  String get nostrSettingsRemoveKeys => 'Sleutels van apparaat verwijderen';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Verwijder je privésleutel alleen van dit apparaat. Je inhoud blijft op relays staan, maar je hebt je nsec-back-up nodig om weer bij je account te komen.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Sleutels konden niet van dit apparaat verwijderd worden. Probeer het opnieuw.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Verwijderen van sleutels mislukt: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Account en data verwijderen';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Verwijder je account en ALLE inhoud PERMANENT van Nostr-relays. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get relayDiagnosticTitle => 'Relay-diagnostiek';

  @override
  String get relayDiagnosticRefreshTooltip => 'Diagnostiek vernieuwen';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Laatste vernieuwing: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay-status';

  @override
  String get relayDiagnosticInitialized => 'Geïnitialiseerd';

  @override
  String get relayDiagnosticReady => 'Klaar';

  @override
  String get relayDiagnosticNotInitialized => 'Niet geïnitialiseerd';

  @override
  String get relayDiagnosticDatabaseEvents => 'Database-events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Actieve abonnementen';

  @override
  String get relayDiagnosticExternalRelays => 'Externe relays';

  @override
  String get relayDiagnosticConfigured => 'Geconfigureerd';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Verbonden';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video-events';

  @override
  String get relayDiagnosticHomeFeed => 'Home-feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video\'s';
  }

  @override
  String get relayDiagnosticDiscovery => 'Ontdekken';

  @override
  String get relayDiagnosticLoading => 'Laden';

  @override
  String get relayDiagnosticYes => 'Ja';

  @override
  String get relayDiagnosticNo => 'Nee';

  @override
  String get relayDiagnosticTestDirectQuery => 'Directe query testen';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Netwerkverbinding';

  @override
  String get relayDiagnosticRunNetworkTest => 'Netwerktest uitvoeren';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom-server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Alle endpoints testen';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Fout';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Basis-URL';

  @override
  String get relayDiagnosticSummary => 'Samenvatting';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (gem. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Alles opnieuw testen';

  @override
  String get relayDiagnosticRetrying => 'Opnieuw proberen...';

  @override
  String get relayDiagnosticRetryConnection => 'Verbinding opnieuw proberen';

  @override
  String get relayDiagnosticTroubleshooting => 'Probleemoplossing';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Groene status = verbonden en werkend\n• Rode status = verbinding mislukt\n• Als de netwerktest faalt, check je internetverbinding\n• Als relays geconfigureerd zijn maar niet verbonden, tik op \"Verbinding opnieuw proberen\"\n• Maak een screenshot van dit scherm voor debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Alle REST-endpoints gezond!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Sommige REST-endpoints faalden — zie details hierboven';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '$count video-events gevonden in database';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Query mislukt: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Verbonden met $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect => 'Verbinden met relays mislukt';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Verbinding opnieuw proberen mislukt: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Verbonden & geauthenticeerd';

  @override
  String get relayDiagnosticConnectedOnly => 'Verbonden';

  @override
  String get relayDiagnosticNotConnected => 'Niet verbonden';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Geen relays geconfigureerd';

  @override
  String get relayDiagnosticFailed => 'Mislukt';

  @override
  String get notificationSettingsTitle => 'Meldingen';

  @override
  String get notificationSettingsResetTooltip => 'Terug naar standaard';

  @override
  String get notificationSettingsTypes => 'Soorten meldingen';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Wanneer iemand je video\'s liket';

  @override
  String get notificationSettingsComments => 'Reacties';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Wanneer iemand op je video\'s reageert';

  @override
  String get notificationSettingsFollows => 'Volgers';

  @override
  String get notificationSettingsFollowsSubtitle => 'Wanneer iemand je volgt';

  @override
  String get notificationSettingsMentions => 'Vermeldingen';

  @override
  String get notificationSettingsMentionsSubtitle => 'Wanneer je wordt genoemd';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Wanneer iemand je video\'s repost';

  @override
  String get notificationSettingsSystem => 'Systeem';

  @override
  String get notificationSettingsSystemSubtitle =>
      'App-updates en systeemberichten';

  @override
  String get notificationSettingsPushNotificationsSection => 'Pushmeldingen';

  @override
  String get notificationSettingsPushNotifications => 'Pushmeldingen';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Ontvang meldingen als de app gesloten is';

  @override
  String get notificationSettingsSound => 'Geluid';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Speel geluid af bij meldingen';

  @override
  String get notificationSettingsVibration => 'Trillen';

  @override
  String get notificationSettingsVibrationSubtitle => 'Trillen bij meldingen';

  @override
  String get notificationSettingsActions => 'Acties';

  @override
  String get notificationSettingsMarkAllAsRead => 'Alles als gelezen markeren';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Markeer alle meldingen als gelezen';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Alle meldingen als gelezen gemarkeerd';

  @override
  String get notificationSettingsResetToDefaults =>
      'Instellingen teruggezet naar standaard';

  @override
  String get notificationSettingsAbout => 'Over meldingen';

  @override
  String get notificationSettingsAboutDescription =>
      'Meldingen werken via het Nostr-protocol. Realtime updates hangen af van je verbinding met Nostr-relays. Sommige meldingen kunnen vertraging hebben.';

  @override
  String get safetySettingsTitle => 'Veiligheid & privacy';

  @override
  String get safetySettingsLabel => 'INSTELLINGEN';

  @override
  String get safetySettingsWhatYouSee => 'WAT JIJ ZIET';

  @override
  String get safetySettingsWhatYouPublish => 'WAT JIJ PUBLICEERT';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Alleen op Divine gehoste video\'s tonen';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Verberg video\'s die bij andere mediahosts staan';

  @override
  String get safetySettingsModeration => 'MODERATIE';

  @override
  String get safetySettingsBlockedUsers => 'GEBLOKKEERDE GEBRUIKERS';

  @override
  String get safetySettingsAgeVerification => 'LEEFTIJDSVERIFICATIE';

  @override
  String get safetySettingsAgeConfirmation =>
      'Ik bevestig dat ik 18 jaar of ouder ben';

  @override
  String get safetySettingsAgeRequired =>
      'Vereist om inhoud voor volwassenen te bekijken';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Officiële moderatieservice (standaard aan)';

  @override
  String get safetySettingsPeopleIFollow => 'Mensen die ik volg';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Abonneer je op labels van mensen die je volgt';

  @override
  String get safetySettingsAddCustomLabeler => 'Eigen labeler toevoegen';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Voer npub in...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Eigen labeler toevoegen';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Voer npub-adres in';

  @override
  String get safetySettingsNoBlockedUsers => 'Geen geblokkeerde gebruikers';

  @override
  String get safetySettingsUnblock => 'Deblokkeren';

  @override
  String get safetySettingsUserUnblocked => 'Gebruiker gedeblokkeerd';

  @override
  String get safetySettingsCancel => 'Annuleren';

  @override
  String get safetySettingsAdd => 'Toevoegen';

  @override
  String get analyticsTitle => 'Creator-statistieken';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostiek';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Diagnostiek omschakelen';

  @override
  String get analyticsRetry => 'Opnieuw';

  @override
  String get analyticsUnableToLoad => 'Statistieken laden lukt niet.';

  @override
  String get analyticsSignInRequired =>
      'Log in om creator-statistieken te bekijken.';

  @override
  String get analyticsViewDataUnavailable =>
      'Weergaven zijn nu niet beschikbaar vanuit de relay voor deze posts. Likes/reacties/reposts-metrics kloppen nog wel.';

  @override
  String get analyticsViewDataTitle => 'Weergavedata';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Bijgewerkt $time • Scores gebruiken likes, reacties, reposts en views/loops van Funnelcake als beschikbaar.';
  }

  @override
  String get analyticsVideos => 'Video\'s';

  @override
  String get analyticsViews => 'Weergaven';

  @override
  String get analyticsInteractions => 'Interacties';

  @override
  String get analyticsEngagement => 'Betrokkenheid';

  @override
  String get analyticsFollowers => 'Volgers';

  @override
  String get analyticsAvgPerPost => 'Gem./post';

  @override
  String get analyticsInteractionMix => 'Interactiemix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Reacties';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Prestatie-hoogtepunten';

  @override
  String get analyticsMostViewed => 'Meest bekeken';

  @override
  String get analyticsMostDiscussed => 'Meest besproken';

  @override
  String get analyticsMostReposted => 'Meest gerepost';

  @override
  String get analyticsNoVideosYet => 'Nog geen video\'s';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Weergavedata niet beschikbaar';

  @override
  String analyticsViewsCount(String count) {
    return '$count weergaven';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count reacties';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top-inhoud';

  @override
  String get analyticsPublishPrompt =>
      'Publiceer een paar video\'s om de ranglijst te zien.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Rechts het % = betrokkenheidsratio (interacties gedeeld door weergaven).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Betrokkenheidsratio heeft weergavedata nodig; waarden tonen N.v.t. tot er weergaven beschikbaar zijn.';

  @override
  String get analyticsEngagementLabel => 'Betrokkenheid';

  @override
  String get analyticsViewsUnavailable => 'weergaven niet beschikbaar';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interacties';
  }

  @override
  String get analyticsPostAnalytics => 'Post-statistieken';

  @override
  String get analyticsOpenPost => 'Post openen';

  @override
  String get analyticsRecentDailyInteractions =>
      'Recente dagelijkse interacties';

  @override
  String get analyticsNoActivityYet => 'Nog geen activiteit in dit bereik.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interacties = likes + reacties + reposts op postdatum.';

  @override
  String get analyticsDailyBarExplainer =>
      'Balklengte is relatief tot je hoogste dag in dit venster.';

  @override
  String get analyticsAudienceSnapshot => 'Publieksoverzicht';

  @override
  String analyticsFollowersCount(String count) {
    return 'Volgers: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Volgend: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Publieksbron/geo/tijd-overzichten komen zodra Funnelcake publieksanalytics-endpoints toevoegt.';

  @override
  String get analyticsRetention => 'Retentie';

  @override
  String get analyticsRetentionWithViews =>
      'Retentiecurve en kijktijd-overzicht verschijnen zodra per-seconde/per-bucket-retentie binnenkomt van Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retentiedata niet beschikbaar tot weergave- en kijktijd-analytics binnenkomen van Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostiek';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Totaal video\'s: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Met weergaven: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Zonder weergaven: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Gehydrateerd (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Gehydrateerd (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Bronnen: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Fixture-data gebruiken';

  @override
  String get analyticsNa => 'N.v.t.';

  @override
  String get authCreateNewAccount => 'Nieuw Divine-account aanmaken';

  @override
  String get authSignInDifferentAccount => 'Inloggen met een ander account';

  @override
  String get authSignBackIn => 'Opnieuw inloggen';

  @override
  String get authTermsPrefix =>
      'Door hierboven een optie te kiezen bevestig je dat je minstens 16 jaar bent en ga je akkoord met de ';

  @override
  String get authTermsOfService => 'Servicevoorwaarden';

  @override
  String get authPrivacyPolicy => 'Privacybeleid';

  @override
  String get authTermsAnd => ', en ';

  @override
  String get authSafetyStandards => 'Veiligheidsstandaarden';

  @override
  String get authAmberNotInstalled => 'Amber-app is niet geïnstalleerd';

  @override
  String get authAmberConnectionFailed => 'Verbinden met Amber mislukt';

  @override
  String get authPasswordResetSent =>
      'Als er een account bestaat met dat e-mailadres, is er een link verstuurd om je wachtwoord te resetten.';

  @override
  String get authSignInTitle => 'Inloggen';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Wachtwoord';

  @override
  String get authConfirmPasswordLabel => 'Wachtwoord bevestigen';

  @override
  String get authEmailRequired => 'E-mail is verplicht';

  @override
  String get authEmailInvalid => 'Voer een geldig e-mailadres in';

  @override
  String get authPasswordRequired => 'Wachtwoord is verplicht';

  @override
  String get authConfirmPasswordRequired => 'Bevestig je wachtwoord';

  @override
  String get authPasswordsDoNotMatch => 'Wachtwoorden komen niet overeen';

  @override
  String get authForgotPassword => 'Wachtwoord vergeten?';

  @override
  String get authImportNostrKey => 'Nostr-sleutel importeren';

  @override
  String get authConnectSignerApp => 'Verbinden met een signer-app';

  @override
  String get authSignInWithAmber => 'Inloggen met Amber';

  @override
  String get authSignInOptionsTitle => 'Inlogopties';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail & wachtwoord';

  @override
  String get authInfoEmailPasswordDescription =>
      'Log in met je Divine-account. Als je geregistreerd bent met e-mail en wachtwoord, gebruik die dan hier.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Heb je al een Nostr-identiteit? Importeer je nsec privésleutel uit een andere client.';

  @override
  String get authInfoSignerAppTitle => 'Signer-app';

  @override
  String get authInfoSignerAppDescription =>
      'Verbind met een NIP-46-compatibele remote signer zoals nsecBunker voor extra sleutelbeveiliging.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Gebruik de Amber signer-app op Android om je Nostr-sleutels veilig te beheren.';

  @override
  String get authCreateAccountTitle => 'Account aanmaken';

  @override
  String get authBackToInviteCode => 'Terug naar invite-code';

  @override
  String get authUseDivineNoBackup => 'Divine gebruiken zonder back-up';

  @override
  String get authSkipConfirmTitle => 'Nog één ding...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Je zit erin! We maken een veilige sleutel die je Divine-account aandrijft.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Zonder e-mail is je sleutel de enige manier waarop Divine weet dat dit account van jou is.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Je kunt je sleutel in de app openen, maar als je niet technisch bent raden we aan nu een e-mail en wachtwoord toe te voegen. Het maakt inloggen en je account herstellen makkelijker als je dit apparaat kwijtraakt of reset.';

  @override
  String get authAddEmailPassword => 'E-mail & wachtwoord toevoegen';

  @override
  String get authUseThisDeviceOnly => 'Alleen dit apparaat gebruiken';

  @override
  String get authCompleteRegistration => 'Maak je registratie af';

  @override
  String get authVerifying => 'Verifiëren...';

  @override
  String get authVerificationLinkSent =>
      'We hebben een verificatielink gestuurd naar:';

  @override
  String get authClickVerificationLink =>
      'Klik op de link in je e-mail om\nje registratie af te ronden.';

  @override
  String get authPleaseWaitVerifying =>
      'Even geduld terwijl we je e-mail verifiëren...';

  @override
  String get authWaitingForVerification => 'Wachten op verificatie';

  @override
  String get authOpenEmailApp => 'E-mail-app openen';

  @override
  String get authWelcomeToDivine => 'Welkom bij Divine!';

  @override
  String get authEmailVerified => 'Je e-mailadres is geverifieerd.';

  @override
  String get authSigningYouIn => 'Je wordt ingelogd';

  @override
  String get authErrorTitle => 'Oei.';

  @override
  String get authVerificationFailed =>
      'We konden je e-mail niet verifiëren.\nProbeer het opnieuw.';

  @override
  String get authStartOver => 'Opnieuw beginnen';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail geverifieerd! Log in om door te gaan.';

  @override
  String get authVerificationLinkExpired =>
      'Deze verificatielink is niet meer geldig.';

  @override
  String get authVerificationConnectionError =>
      'E-mail verifiëren lukt niet. Check je verbinding en probeer opnieuw.';

  @override
  String get authWaitlistConfirmTitle => 'Je staat erop!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'We delen updates via $email.\nZodra er meer invite-codes beschikbaar zijn, sturen we die naar je toe.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Invite-toegang is tijdelijk niet beschikbaar.';

  @override
  String get authInviteUnavailableBody =>
      'Probeer het zo nog eens, of neem contact op met support als je hulp nodig hebt om binnen te komen.';

  @override
  String get authTryAgain => 'Opnieuw proberen';

  @override
  String get authContactSupport => 'Contact met support';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email openen lukt niet';
  }

  @override
  String get authAddInviteCode => 'Voeg je invite-code toe';

  @override
  String get authInviteCodeLabel => 'Invite-code';

  @override
  String get authEnterYourCode => 'Voer je code in';

  @override
  String get authNext => 'Volgende';

  @override
  String get authJoinWaitlist => 'Op de wachtlijst';

  @override
  String get authJoinWaitlistTitle => 'Op de wachtlijst';

  @override
  String get authJoinWaitlistDescription =>
      'Deel je e-mailadres en we sturen updates zodra toegang opengaat.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Hulp bij invite-toegang';

  @override
  String get authGeneratingConnection => 'Verbinding genereren...';

  @override
  String get authConnectedAuthenticating => 'Verbonden! Authenticeren...';

  @override
  String get authConnectionTimedOut => 'Verbinding duurde te lang';

  @override
  String get authApproveConnection =>
      'Zorg dat je de verbinding in je signer-app hebt goedgekeurd.';

  @override
  String get authConnectionCancelled => 'Verbinding geannuleerd';

  @override
  String get authConnectionCancelledMessage => 'De verbinding is geannuleerd.';

  @override
  String get authConnectionFailed => 'Verbinding mislukt';

  @override
  String get authUnknownError => 'Er is een onbekende fout opgetreden.';

  @override
  String get authUrlCopied => 'URL gekopieerd naar klembord';

  @override
  String get authConnectToDivine => 'Verbinden met Divine';

  @override
  String get authPasteBunkerUrl => 'Plak bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Ongeldige bunker-URL. Moet beginnen met bunker://';

  @override
  String get authScanSignerApp => 'Scan met je\nsigner-app om te verbinden.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Wachten op verbinding... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'URL kopiëren';

  @override
  String get authShare => 'Delen';

  @override
  String get authAddBunker => 'Bunker toevoegen';

  @override
  String get authCompatibleSignerApps => 'Compatibele signer-apps';

  @override
  String get authFailedToConnect => 'Verbinden mislukt';

  @override
  String get authResetPasswordTitle => 'Wachtwoord resetten';

  @override
  String get authResetPasswordSubtitle =>
      'Voer je nieuwe wachtwoord in. Minimaal 8 tekens.';

  @override
  String get authNewPasswordLabel => 'Nieuw wachtwoord';

  @override
  String get authConfirmNewPasswordLabel => 'Nieuw wachtwoord bevestigen';

  @override
  String get authPasswordTooShort => 'Wachtwoord moet minstens 8 tekens zijn';

  @override
  String get authPasswordResetSuccess => 'Wachtwoord gereset. Log in.';

  @override
  String get authPasswordResetFailed => 'Wachtwoord resetten mislukt';

  @override
  String get authUnexpectedError =>
      'Er is een onverwachte fout opgetreden. Probeer het opnieuw.';

  @override
  String get authUpdatePassword => 'Wachtwoord bijwerken';

  @override
  String get authSecureAccountTitle => 'Account beveiligen';

  @override
  String get authUnableToAccessKeys =>
      'Toegang tot je sleutels mislukt. Probeer het opnieuw.';

  @override
  String get authRegistrationFailed => 'Registratie mislukt';

  @override
  String get authRegistrationComplete =>
      'Registratie voltooid. Check je e-mail.';

  @override
  String get authVerificationFailedTitle => 'Verificatie mislukt';

  @override
  String get authClose => 'Sluiten';

  @override
  String get authAccountSecured => 'Account beveiligd!';

  @override
  String get authAccountLinkedToEmail =>
      'Je account is nu gekoppeld aan je e-mailadres.';

  @override
  String get authVerifyYourEmail => 'Verifieer je e-mail';

  @override
  String get authClickLinkContinue =>
      'Klik op de link in je e-mail om registratie af te ronden. Je kunt ondertussen de app blijven gebruiken.';

  @override
  String get authWaitingForVerificationEllipsis => 'Wachten op verificatie...';

  @override
  String get authContinueToApp => 'Door naar de app';

  @override
  String get authResetPassword => 'Wachtwoord resetten';

  @override
  String get authResetPasswordDescription =>
      'Voer je e-mailadres in en we sturen je een link om je wachtwoord te resetten.';

  @override
  String get authFailedToSendResetEmail => 'Resetmail versturen mislukt.';

  @override
  String get authUnexpectedErrorShort =>
      'Er is een onverwachte fout opgetreden.';

  @override
  String get authSending => 'Versturen...';

  @override
  String get authSendResetLink => 'Resetlink versturen';

  @override
  String get authEmailSent => 'E-mail verstuurd!';

  @override
  String authResetLinkSentTo(String email) {
    return 'We hebben een resetlink naar $email gestuurd. Klik op de link in je e-mail om je wachtwoord bij te werken.';
  }

  @override
  String get authSignInButton => 'Inloggen';

  @override
  String get authVerificationErrorTimeout =>
      'Verificatie duurde te lang. Probeer opnieuw te registreren.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verificatie mislukt — autorisatiecode ontbreekt.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verificatie mislukt. Probeer het opnieuw.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Netwerkfout tijdens inloggen. Probeer het opnieuw.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verificatie mislukt. Probeer opnieuw te registreren.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Inloggen mislukt. Probeer handmatig in te loggen.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Die invite-code is niet meer beschikbaar. Ga terug naar je invite-code, kom op de wachtlijst of neem contact op met support.';

  @override
  String get authInviteErrorInvalid =>
      'Die invite-code kan nu niet worden gebruikt. Ga terug naar je invite-code, kom op de wachtlijst of neem contact op met support.';

  @override
  String get authInviteErrorTemporary =>
      'We konden je invite nu niet bevestigen. Ga terug naar je invite-code en probeer het opnieuw, of neem contact op met support.';

  @override
  String get authInviteErrorUnknown =>
      'We konden je invite niet activeren. Ga terug naar je invite-code, kom op de wachtlijst of neem contact op met support.';

  @override
  String get shareSheetSave => 'Opslaan';

  @override
  String get shareSheetSaveToGallery => 'Opslaan in galerij';

  @override
  String get shareSheetSaveWithWatermark => 'Opslaan met watermerk';

  @override
  String get shareSheetSaveVideo => 'Video opslaan';

  @override
  String get shareSheetAddToClips => 'Toevoegen aan clips';

  @override
  String get shareSheetAddedToClips => 'Toegevoegd aan clips';

  @override
  String get shareSheetAddToClipsFailed => 'Kon niet toevoegen aan clips';

  @override
  String get shareSheetAddToList => 'Toevoegen aan lijst';

  @override
  String get shareSheetCopy => 'Kopiëren';

  @override
  String get shareSheetShareVia => 'Delen via';

  @override
  String get shareSheetReport => 'Melden';

  @override
  String get shareSheetEventJson => 'Event-JSON';

  @override
  String get shareSheetEventId => 'Event-ID';

  @override
  String get shareSheetMoreActions => 'Meer acties';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Opgeslagen in camerarol';

  @override
  String get watermarkDownloadShare => 'Delen';

  @override
  String get watermarkDownloadDone => 'Klaar';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Toegang tot Foto\'s nodig';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Om video\'s op te slaan, geef je in Instellingen toegang tot Foto\'s.';

  @override
  String get watermarkDownloadOpenSettings => 'Instellingen openen';

  @override
  String get watermarkDownloadNotNow => 'Niet nu';

  @override
  String get watermarkDownloadFailed => 'Download mislukt';

  @override
  String get watermarkDownloadDismiss => 'Sluiten';

  @override
  String get watermarkDownloadStageDownloading => 'Video downloaden';

  @override
  String get watermarkDownloadStageWatermarking => 'Watermerk toevoegen';

  @override
  String get watermarkDownloadStageSaving => 'Opslaan in camerarol';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Video ophalen van het netwerk...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Het Divine-watermerk toepassen...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'De video met watermerk in je camerarol opslaan...';

  @override
  String get uploadProgressVideoUpload => 'Video-upload';

  @override
  String get uploadProgressPause => 'Pauzeren';

  @override
  String get uploadProgressResume => 'Hervatten';

  @override
  String get uploadProgressGoBack => 'Terug';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Opnieuw ($count over)';
  }

  @override
  String get uploadProgressDelete => 'Verwijderen';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}d geleden';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}u geleden';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}m geleden';
  }

  @override
  String get uploadProgressJustNow => 'Zojuist';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Uploaden $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Gepauzeerd $percent%';
  }

  @override
  String get badgeExplanationClose => 'Sluiten';

  @override
  String get badgeExplanationOriginalVineArchive => 'Origineel Vine-archief';

  @override
  String get badgeExplanationCameraProof => 'Cameraproof';

  @override
  String get badgeExplanationAuthenticitySignals => 'Authenticiteitssignalen';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Deze video is een originele Vine, teruggehaald uit het Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Voor Vine in 2017 sloot, werkten ArchiveTeam en het Internet Archive samen om miljoenen Vines voor het nageslacht te bewaren. Deze inhoud is onderdeel van dat historische bewaarproject.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Originele stats: $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Meer over het behoud van het Vine-archief';

  @override
  String get badgeExplanationLearnProofmode =>
      'Meer over Proofmode-verificatie';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Meer over Divine-authenticiteitssignalen';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspecteren met ProofCheck-tool';

  @override
  String get badgeExplanationInspectMedia => 'Mediadetails inspecteren';

  @override
  String get badgeExplanationProofmodeVerified =>
      'De authenticiteit van deze video is geverifieerd met Proofmode-technologie.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Deze video staat op Divine en AI-detectie geeft aan dat hij waarschijnlijk door een mens is gemaakt, maar hij bevat geen cryptografische cameraverificatie-data.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI-detectie geeft aan dat deze video waarschijnlijk door een mens is gemaakt, maar hij bevat geen cryptografische cameraverificatie-data.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Deze video staat op Divine, maar bevat nog geen cryptografische cameraverificatie-data.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Deze video staat buiten Divine en bevat geen cryptografische cameraverificatie-data.';

  @override
  String get badgeExplanationDeviceAttestation => 'Apparaatattestatie';

  @override
  String get badgeExplanationPgpSignature => 'PGP-handtekening';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Proof-manifest';

  @override
  String get badgeExplanationAiDetection => 'AI-detectie';

  @override
  String get badgeExplanationAiNotScanned => 'AI-scan: nog niet gescand';

  @override
  String get badgeExplanationNoScanResults =>
      'Nog geen scanresultaten beschikbaar.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Check of AI-gegenereerd';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% kans dat het AI-gegenereerd is';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Gescand door: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Geverifieerd door menselijke moderator';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platina: apparaathardware-attestatie, cryptografische handtekeningen, Content Credentials (C2PA) en AI-scan bevestigt menselijke oorsprong.';

  @override
  String get badgeExplanationVerificationGold =>
      'Goud: opgenomen op een echt apparaat met hardware-attestatie, cryptografische handtekeningen en Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Zilver: cryptografische handtekeningen bewijzen dat deze video sinds de opname niet is aangepast.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Brons: basis-metadata-handtekeningen zijn aanwezig.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Zilver: AI-scan bevestigt dat deze video waarschijnlijk door een mens is gemaakt.';

  @override
  String get badgeExplanationNoVerification =>
      'Geen verificatiedata beschikbaar voor deze video.';

  @override
  String get shareMenuTitle => 'Video delen';

  @override
  String get shareMenuReportAiContent => 'AI-inhoud melden';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Snel vermoedelijk AI-gegenereerde inhoud melden';

  @override
  String get shareMenuReportingAiContent => 'AI-inhoud melden...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Inhoud melden mislukt: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'AI-inhoud melden mislukt: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Videostatus';

  @override
  String get shareMenuViewAllLists => 'Alle lijsten bekijken →';

  @override
  String get shareMenuShareWith => 'Delen met';

  @override
  String get shareMenuShareViaOtherApps => 'Delen via andere apps';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Delen via andere apps of link kopiëren';

  @override
  String get shareMenuSaveToGallery => 'Opslaan in galerij';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Originele video opslaan in camerarol';

  @override
  String get shareMenuSaveWithWatermark => 'Opslaan met watermerk';

  @override
  String get shareMenuSaveVideo => 'Video opslaan';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Downloaden met Divine-watermerk';

  @override
  String get shareMenuSaveVideoSubtitle => 'Video opslaan in camerarol';

  @override
  String get shareMenuLists => 'Lijsten';

  @override
  String get shareMenuAddToList => 'Toevoegen aan lijst';

  @override
  String get shareMenuAddToListSubtitle =>
      'Toevoegen aan je samengestelde lijsten';

  @override
  String get shareMenuCreateNewList => 'Nieuwe lijst maken';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Begin een nieuwe samengestelde collectie';

  @override
  String get shareMenuRemovedFromList => 'Verwijderd uit lijst';

  @override
  String get shareMenuFailedToRemoveFromList => 'Verwijderen uit lijst mislukt';

  @override
  String get shareMenuBookmarks => 'Bladwijzers';

  @override
  String get shareMenuAddToBookmarks => 'Toevoegen aan bladwijzers';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Bewaar om later te bekijken';

  @override
  String get shareMenuAddToBookmarkSet => 'Toevoegen aan bladwijzerset';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Orden in collecties';

  @override
  String get shareMenuFollowSets => 'Volgsets';

  @override
  String get shareMenuCreateFollowSet => 'Volgset maken';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Begin een nieuwe collectie met deze maker';

  @override
  String get shareMenuAddToFollowSet => 'Toevoegen aan volgset';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count volgsets beschikbaar';
  }

  @override
  String get peopleListsAddToList => 'Toevoegen aan lijst';

  @override
  String get peopleListsAddToListSubtitle =>
      'Voeg deze maker toe aan een van je lijsten';

  @override
  String get peopleListsSheetTitle => 'Toevoegen aan lijst';

  @override
  String get peopleListsEmptyTitle => 'Nog geen lijsten';

  @override
  String get peopleListsEmptySubtitle =>
      'Maak een lijst om mensen te groeperen.';

  @override
  String get peopleListsCreateList => 'Lijst aanmaken';

  @override
  String get peopleListsNewListTitle => 'Nieuwe lijst';

  @override
  String get peopleListsRouteTitle => 'Personenlijst';

  @override
  String get peopleListsListNameLabel => 'Lijstnaam';

  @override
  String get peopleListsListNameHint => 'Goede vrienden';

  @override
  String get peopleListsCreateButton => 'Aanmaken';

  @override
  String get peopleListsAddPeopleTitle => 'Mensen toevoegen';

  @override
  String get peopleListsAddPeopleTooltip => 'Mensen toevoegen';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Mensen aan lijst toevoegen';

  @override
  String get peopleListsListNotFoundTitle => 'Lijst niet gevonden';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lijst niet gevonden. Mogelijk is deze verwijderd.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Deze lijst is mogelijk verwijderd.';

  @override
  String get peopleListsNoPeopleTitle => 'Geen mensen in deze lijst';

  @override
  String get peopleListsNoPeopleSubtitle => 'Voeg mensen toe om te beginnen';

  @override
  String get peopleListsNoVideosTitle => 'Nog geen video\'s';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Video\'s van lijstleden verschijnen hier';

  @override
  String get peopleListsNoVideosAvailable => 'Geen video\'s beschikbaar';

  @override
  String get peopleListsFailedToLoadVideos => 'Video\'s laden mislukt';

  @override
  String get peopleListsVideoNotAvailable => 'Video niet beschikbaar';

  @override
  String get peopleListsBackToGridTooltip => 'Terug naar raster';

  @override
  String get peopleListsErrorLoadingVideos => 'Fout bij laden van video\'s';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Geen mensen beschikbaar om toe te voegen.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Toevoegen aan $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Mensen zoeken';

  @override
  String get peopleListsAddPeopleError =>
      'Kon mensen niet laden. Probeer het opnieuw.';

  @override
  String get peopleListsAddPeopleRetry => 'Opnieuw proberen';

  @override
  String get peopleListsAddButton => 'Toevoegen';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return '$count toevoegen';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lijsten',
      one: 'In 1 lijst',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return '$name verwijderen?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Ze worden uit deze lijst verwijderd.';

  @override
  String get peopleListsRemove => 'Verwijderen';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name verwijderd uit lijst';
  }

  @override
  String get peopleListsUndo => 'Ongedaan maken';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profiel van $name. Lang indrukken om te verwijderen.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Profiel van $name bekijken';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Toegevoegd aan bladwijzers!';

  @override
  String get shareMenuFailedToAddBookmark => 'Bladwijzer toevoegen mislukt';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Lijst \"$name\" aangemaakt en video toegevoegd';
  }

  @override
  String get shareMenuManageContent => 'Inhoud beheren';

  @override
  String get shareMenuEditVideo => 'Video bewerken';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Titel, beschrijving en hashtags bijwerken';

  @override
  String get shareMenuDeleteVideo => 'Video verwijderen';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Deze inhoud definitief verwijderen';

  @override
  String get shareMenuDeleteWarning =>
      'Dit stuurt een verwijderverzoek (NIP-09) naar alle relays. Sommige relays kunnen de inhoud alsnog bewaren.';

  @override
  String get shareMenuVideoInTheseLists => 'Video staat in deze lijsten:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video\'s';
  }

  @override
  String get shareMenuClose => 'Sluiten';

  @override
  String get shareMenuDeleteConfirmation =>
      'Weet je zeker dat je deze video wilt verwijderen?';

  @override
  String get shareMenuCancel => 'Annuleren';

  @override
  String get shareMenuDelete => 'Verwijderen';

  @override
  String get shareMenuDeletingContent => 'Inhoud verwijderen...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Inhoud verwijderen mislukt: $error';
  }

  @override
  String get shareMenuDeleteRequestSent =>
      'Verwijderverzoek succesvol verstuurd';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Verwijderen is nog niet klaar. Probeer het zo meteen opnieuw.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Je kunt alleen je eigen video\'s verwijderen.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Log opnieuw in en probeer te verwijderen.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Kon het verwijderverzoek niet ondertekenen. Probeer opnieuw.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Kon deze video niet verwijderen. Probeer opnieuw.';

  @override
  String get shareMenuFollowSetName => 'Naam volgset';

  @override
  String get shareMenuFollowSetNameHint =>
      'Bijv. content creators, muzikanten, enz.';

  @override
  String get shareMenuDescriptionOptional => 'Beschrijving (optioneel)';

  @override
  String get shareMenuCreate => 'Maken';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Volgset \"$name\" aangemaakt en maker toegevoegd';
  }

  @override
  String get shareMenuDone => 'Klaar';

  @override
  String get shareMenuEditTitle => 'Titel';

  @override
  String get shareMenuEditTitleHint => 'Voer videotitel in';

  @override
  String get shareMenuEditDescription => 'Beschrijving';

  @override
  String get shareMenuEditDescriptionHint => 'Voer videobeschrijving in';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'hashtags, gescheiden door, komma\'s';

  @override
  String get shareMenuEditMetadataNote =>
      'Let op: alleen metadata kan worden bewerkt. Video-inhoud kan niet worden gewijzigd.';

  @override
  String get shareMenuDeleting => 'Verwijderen...';

  @override
  String get shareMenuUpdate => 'Bijwerken';

  @override
  String get shareMenuVideoUpdated => 'Video succesvol bijgewerkt';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Video bijwerken mislukt: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Video verwijderen mislukt: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Video verwijderen?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Dit stuurt een verwijderverzoek naar relays. Let op: sommige relays hebben misschien nog gecachte kopieën.';

  @override
  String get shareMenuVideoDeletionRequested =>
      'Video-verwijdering aangevraagd';

  @override
  String get shareMenuContentLabels => 'Inhoudslabels';

  @override
  String get shareMenuAddContentLabels => 'Inhoudslabels toevoegen';

  @override
  String get shareMenuClearAll => 'Alles wissen';

  @override
  String get shareMenuCollaborators => 'Samenwerkers';

  @override
  String get shareMenuAddCollaborator => 'Samenwerker toevoegen';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Je moet $name wederzijds volgen om diegene als samenwerker toe te voegen.';
  }

  @override
  String get shareMenuLoading => 'Laden...';

  @override
  String get shareMenuInspiredBy => 'Geïnspireerd door';

  @override
  String get shareMenuAddInspirationCredit => 'Inspiratiecredit toevoegen';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Naar deze maker kan niet verwezen worden.';

  @override
  String get shareMenuUnknown => 'Onbekend';

  @override
  String get shareMenuCreateBookmarkSet => 'Bladwijzerset maken';

  @override
  String get shareMenuSetName => 'Setnaam';

  @override
  String get shareMenuSetNameHint => 'Bijv. favorieten, later bekijken, enz.';

  @override
  String get shareMenuCreateNewSet => 'Nieuwe set maken';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Begin een nieuwe bladwijzercollectie';

  @override
  String get shareMenuNoBookmarkSets =>
      'Nog geen bladwijzersets. Maak je eerste!';

  @override
  String get shareMenuError => 'Fout';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Laden van bladwijzersets mislukt';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\" aangemaakt en video toegevoegd';
  }

  @override
  String get shareMenuUseThisSound => 'Dit geluid gebruiken';

  @override
  String get shareMenuOriginalSound => 'Origineel geluid';

  @override
  String get authSessionExpired => 'Je sessie is verlopen. Log opnieuw in.';

  @override
  String get authSignInFailed => 'Inloggen mislukt. Probeer het opnieuw.';

  @override
  String get localeAppLanguage => 'App-taal';

  @override
  String get localeDeviceDefault => 'Apparaatstandaard';

  @override
  String get localeSelectLanguage => 'Kies taal';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Webauthenticatie wordt niet ondersteund in veilige modus. Gebruik de mobiele app voor veilig sleutelbeheer.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Authenticatie-integratie mislukt: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Onverwachte fout: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Voer een bunker-URI in';

  @override
  String get webAuthConnectTitle => 'Verbinden met Divine';

  @override
  String get webAuthChooseMethod =>
      'Kies je voorkeursmethode voor Nostr-authenticatie';

  @override
  String get webAuthBrowserExtension => 'Browserextensie';

  @override
  String get webAuthRecommended => 'AANBEVOLEN';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Verbinden met een remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Plakken uit klembord';

  @override
  String get webAuthConnectToBunker => 'Verbinden met Bunker';

  @override
  String get webAuthNewToNostr => 'Nieuw op Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installeer een browserextensie zoals Alby of nos2x voor de makkelijkste ervaring, of gebruik nsec bunker voor veilig remote signen.';

  @override
  String get soundsTitle => 'Geluiden';

  @override
  String get soundsSearchHint => 'Zoek geluiden...';

  @override
  String get soundsPreviewUnavailable =>
      'Geluid voorbeluisteren lukt niet — geen audio beschikbaar';

  @override
  String soundsPreviewFailed(String error) {
    return 'Voorbeluistering afspelen mislukt: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Uitgelichte geluiden';

  @override
  String get soundsTrendingSounds => 'Trending geluiden';

  @override
  String get soundsAllSounds => 'Alle geluiden';

  @override
  String get soundsSearchResults => 'Zoekresultaten';

  @override
  String get soundsNoSoundsAvailable => 'Geen geluiden beschikbaar';

  @override
  String get soundsNoSoundsDescription =>
      'Geluiden verschijnen hier wanneer makers audio delen';

  @override
  String get soundsNoSoundsFound => 'Geen geluiden gevonden';

  @override
  String get soundsNoSoundsFoundDescription => 'Probeer een andere zoekterm';

  @override
  String get soundsFailedToLoad => 'Laden van geluiden mislukt';

  @override
  String get soundsRetry => 'Opnieuw';

  @override
  String get soundsScreenLabel => 'Geluidenscherm';

  @override
  String get profileTitle => 'Profiel';

  @override
  String get profileRefresh => 'Vernieuwen';

  @override
  String get profileRefreshLabel => 'Profiel vernieuwen';

  @override
  String get profileMoreOptions => 'Meer opties';

  @override
  String profileBlockedUser(String name) {
    return '$name geblokkeerd';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name gedeblokkeerd';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name ontvolgd';
  }

  @override
  String profileError(String error) {
    return 'Fout: $error';
  }

  @override
  String get notificationsTabAll => 'Alles';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Reacties';

  @override
  String get notificationsTabFollows => 'Volgers';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Meldingen laden mislukt';

  @override
  String get notificationsRetry => 'Opnieuw';

  @override
  String get notificationsCheckingNew => 'checken op nieuwe meldingen';

  @override
  String get notificationsNoneYet => 'Nog geen meldingen';

  @override
  String notificationsNoneForType(String type) {
    return 'Geen $type-meldingen';
  }

  @override
  String get notificationsEmptyDescription =>
      'Als mensen met je inhoud interacteren, zie je het hier';

  @override
  String get notificationsUnreadPrefix => 'Ongelezen melding';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Profiel van $displayName bekijken';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Profielen bekijken';

  @override
  String notificationsLoadingType(String type) {
    return '$type-meldingen laden...';
  }

  @override
  String get notificationsInviteSingular =>
      'Je hebt 1 uitnodiging om met een vriend te delen!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Je hebt $count uitnodigingen om met vrienden te delen!';
  }

  @override
  String get notificationsVideoNotFound => 'Video niet gevonden';

  @override
  String get notificationsVideoUnavailable => 'Video niet beschikbaar';

  @override
  String get notificationsFromNotification => 'Vanuit melding';

  @override
  String get feedFailedToLoadVideos => 'Video\'s laden mislukt';

  @override
  String get feedRetry => 'Opnieuw';

  @override
  String get feedNoFollowedUsers =>
      'Geen gevolgde gebruikers.\nVolg iemand om hun video\'s hier te zien.';

  @override
  String get feedForYouEmpty =>
      'Je Voor jou-feed is leeg.\nVerken video\'s en volg makers om hem vorm te geven.';

  @override
  String get feedFollowingEmpty =>
      'Nog geen video\'s van mensen die je volgt.\nVind makers die je leuk vindt en volg ze.';

  @override
  String get feedLatestEmpty =>
      'Nog geen nieuwe video\'s.\nKom binnenkort terug.';

  @override
  String get feedExploreVideos => 'Video\'s verkennen';

  @override
  String get feedExternalVideoSlow => 'Externe video laadt traag';

  @override
  String get feedSkip => 'Overslaan';

  @override
  String get uploadWaitingToUpload => 'Wachten om te uploaden';

  @override
  String get uploadUploadingVideo => 'Video uploaden';

  @override
  String get uploadProcessingVideo => 'Video verwerken';

  @override
  String get uploadProcessingComplete => 'Verwerking klaar';

  @override
  String get uploadPublishedSuccessfully => 'Succesvol gepubliceerd';

  @override
  String get uploadFailed => 'Upload mislukt';

  @override
  String get uploadRetrying => 'Upload opnieuw proberen';

  @override
  String get uploadPaused => 'Upload gepauzeerd';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% klaar';
  }

  @override
  String get uploadQueuedMessage => 'Je video staat in de wachtrij voor upload';

  @override
  String get uploadUploadingMessage => 'Uploaden naar server...';

  @override
  String get uploadProcessingMessage =>
      'Video verwerken — dit kan een paar minuten duren';

  @override
  String get uploadReadyToPublishMessage =>
      'Video succesvol verwerkt en klaar om te publiceren';

  @override
  String get uploadPublishedMessage => 'Video gepubliceerd op je profiel';

  @override
  String get uploadFailedMessage => 'Upload mislukt — probeer het opnieuw';

  @override
  String get uploadRetryingMessage => 'Upload opnieuw proberen...';

  @override
  String get uploadPausedMessage => 'Upload gepauzeerd door gebruiker';

  @override
  String get uploadRetryButton => 'OPNIEUW';

  @override
  String uploadRetryFailed(String error) {
    return 'Upload opnieuw proberen mislukt: $error';
  }

  @override
  String get userSearchPrompt => 'Zoek gebruikers';

  @override
  String get userSearchNoResults => 'Geen gebruikers gevonden';

  @override
  String get userSearchFailed => 'Zoeken mislukt';

  @override
  String get userPickerSearchByName => 'Zoeken op naam';

  @override
  String get userPickerFilterByNameHint => 'Filteren op naam...';

  @override
  String get userPickerSearchByNameHint => 'Zoeken op naam...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name al toegevoegd';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Selecteer $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Je crew is daarbuiten';

  @override
  String get userPickerEmptyFollowListBody =>
      'Volg mensen met wie je klikt. Als ze je terugvolgen, kunnen jullie samenwerken.';

  @override
  String get userPickerGoBack => 'Ga terug';

  @override
  String get userPickerTypeNameToSearch => 'Typ een naam om te zoeken';

  @override
  String get userPickerUnavailable =>
      'Zoeken naar gebruikers is niet beschikbaar. Probeer het later opnieuw.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Zoeken is mislukt. Probeer het opnieuw.';

  @override
  String get forgotPasswordTitle => 'Wachtwoord resetten';

  @override
  String get forgotPasswordDescription =>
      'Voer je e-mailadres in en we sturen je een link om je wachtwoord te resetten.';

  @override
  String get forgotPasswordEmailLabel => 'E-mailadres';

  @override
  String get forgotPasswordCancel => 'Annuleren';

  @override
  String get forgotPasswordSendLink => 'Resetlink e-mailen';

  @override
  String get ageVerificationContentWarning => 'Inhoudswaarschuwing';

  @override
  String get ageVerificationTitle => 'Leeftijdsverificatie';

  @override
  String get ageVerificationAdultDescription =>
      'Deze inhoud is gemarkeerd als mogelijk materiaal voor volwassenen. Je moet 18 of ouder zijn om het te bekijken.';

  @override
  String get ageVerificationCreationDescription =>
      'Om de camera te gebruiken en inhoud te maken moet je minstens 16 zijn.';

  @override
  String get ageVerificationAdultQuestion => 'Ben je 18 jaar of ouder?';

  @override
  String get ageVerificationCreationQuestion => 'Ben je 16 jaar of ouder?';

  @override
  String get ageVerificationNo => 'Nee';

  @override
  String get ageVerificationYes => 'Ja';

  @override
  String get shareLinkCopied => 'Link gekopieerd naar klembord';

  @override
  String get shareFailedToCopy => 'Link kopiëren mislukt';

  @override
  String get shareVideoSubject => 'Check deze video op Divine';

  @override
  String get shareFailedToShare => 'Delen mislukt';

  @override
  String get shareVideoTitle => 'Video delen';

  @override
  String get shareToApps => 'Delen met apps';

  @override
  String get shareToAppsSubtitle => 'Delen via messaging- en social-apps';

  @override
  String get shareCopyWebLink => 'Weblink kopiëren';

  @override
  String get shareCopyWebLinkSubtitle => 'Deelbare weblink kopiëren';

  @override
  String get shareCopyNostrLink => 'Nostr-link kopiëren';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'nevent-link kopiëren voor Nostr-clients';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Ontdekken';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profiel';

  @override
  String get navSearch => 'Zoeken';

  @override
  String get navSearchTooltip => 'Zoeken';

  @override
  String get navMyProfile => 'Mijn profiel';

  @override
  String get navNotifications => 'Meldingen';

  @override
  String get navOpenCamera => 'Camera openen';

  @override
  String get navUnknown => 'Onbekend';

  @override
  String get navExploreClassics => 'Klassiekers';

  @override
  String get navExploreNewVideos => 'Nieuwe video\'s';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Voor jou';

  @override
  String get navExploreLists => 'Lijsten';

  @override
  String get routeErrorTitle => 'Fout';

  @override
  String get routeInvalidHashtag => 'Ongeldige hashtag';

  @override
  String get routeInvalidConversationId => 'Ongeldige gesprek-ID';

  @override
  String get routeInvalidRequestId => 'Ongeldige verzoek-ID';

  @override
  String get routeInvalidListId => 'Ongeldige lijst-ID';

  @override
  String get routeInvalidUserId => 'Ongeldige gebruikers-ID';

  @override
  String get routeInvalidVideoId => 'Ongeldige video-ID';

  @override
  String get routeInvalidSoundId => 'Ongeldige geluid-ID';

  @override
  String get routeInvalidCategory => 'Ongeldige categorie';

  @override
  String get routeNoVideosToDisplay => 'Geen video\'s om weer te geven';

  @override
  String get routeInvalidProfileId => 'Ongeldige profiel-ID';

  @override
  String get routeDefaultListName => 'Lijst';

  @override
  String get supportTitle => 'Supportcentrum';

  @override
  String get supportContactSupport => 'Contact met support';

  @override
  String get supportContactSupportSubtitle =>
      'Start een gesprek of bekijk eerdere berichten';

  @override
  String get supportReportBug => 'Bug melden';

  @override
  String get supportReportBugSubtitle => 'Technische problemen met de app';

  @override
  String get supportRequestFeature => 'Functie aanvragen';

  @override
  String get supportRequestFeatureSubtitle =>
      'Stel een verbetering of nieuwe functie voor';

  @override
  String get supportSaveLogs => 'Logs opslaan';

  @override
  String get supportSaveLogsSubtitle =>
      'Exporteer logs naar bestand om handmatig te versturen';

  @override
  String get supportFaq => 'Veelgestelde vragen';

  @override
  String get supportFaqSubtitle => 'Veelgestelde vragen & antwoorden';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Leer over verificatie en authenticiteit';

  @override
  String get supportLoginRequired =>
      'Log in om contact op te nemen met support';

  @override
  String get supportExportingLogs => 'Logs exporteren...';

  @override
  String get supportExportLogsFailed => 'Logs exporteren mislukt';

  @override
  String get supportChatNotAvailable => 'Supportchat niet beschikbaar';

  @override
  String get supportCouldNotOpenMessages => 'Supportberichten openen mislukt';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName openen mislukt';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Fout bij openen van $pageName: $error';
  }

  @override
  String get reportTitle => 'Inhoud melden';

  @override
  String get reportWhyReporting => 'Waarom meld je deze inhoud?';

  @override
  String get reportPolicyNotice =>
      'Divine handelt binnen 24 uur op meldingen van inhoud door de inhoud te verwijderen en de gebruiker die de schendende inhoud plaatste eruit te zetten.';

  @override
  String get reportAdditionalDetails => 'Extra details (optioneel)';

  @override
  String get reportBlockUser => 'Deze gebruiker blokkeren';

  @override
  String get reportCancel => 'Annuleren';

  @override
  String get reportSubmit => 'Melden';

  @override
  String get reportSelectReason =>
      'Selecteer een reden om deze inhoud te melden';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Spam of ongewenste inhoud';

  @override
  String get reportReasonHarassment => 'Intimidatie, pesten of bedreigingen';

  @override
  String get reportReasonViolence => 'Gewelddadige of extremistische inhoud';

  @override
  String get reportReasonSexualContent =>
      'Seksuele inhoud of inhoud voor volwassenen';

  @override
  String get reportReasonCopyright => 'Auteursrechtschending';

  @override
  String get reportReasonFalseInfo => 'Valse informatie';

  @override
  String get reportReasonCsam => 'Schending kinderveiligheid';

  @override
  String get reportReasonAiGenerated => 'AI-gegenereerde inhoud';

  @override
  String get reportReasonOther => 'Andere beleidsschending';

  @override
  String reportFailed(Object error) {
    return 'Inhoud melden mislukt: $error';
  }

  @override
  String get reportReceivedTitle => 'Melding ontvangen';

  @override
  String get reportReceivedThankYou =>
      'Bedankt dat je helpt Divine veilig te houden.';

  @override
  String get reportReceivedReviewNotice =>
      'Ons team bekijkt je melding en onderneemt passende actie. Je kunt updates ontvangen via directe berichten.';

  @override
  String get reportLearnMore => 'Meer info';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Sluiten';

  @override
  String get listAddToList => 'Toevoegen aan lijst';

  @override
  String listVideoCount(int count) {
    return '$count video\'s';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personen',
      one: '1 persoon',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Door ';

  @override
  String get listNewList => 'Nieuwe lijst';

  @override
  String get listDone => 'Klaar';

  @override
  String get listErrorLoading => 'Fout bij laden van lijsten';

  @override
  String listRemovedFrom(String name) {
    return 'Verwijderd uit $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Toegevoegd aan $name';
  }

  @override
  String get listCreateNewList => 'Nieuwe lijst maken';

  @override
  String get listNewPeopleList => 'Nieuwe personenlijst';

  @override
  String get listCollaboratorsNone => 'Geen';

  @override
  String get listAddCollaboratorTitle => 'Medewerker toevoegen';

  @override
  String get listCollaboratorSearchHint => 'Zoek in diVine...';

  @override
  String get listNameLabel => 'Lijstnaam';

  @override
  String get listDescriptionLabel => 'Beschrijving (optioneel)';

  @override
  String get listPublicList => 'Openbare lijst';

  @override
  String get listPublicListSubtitle =>
      'Anderen kunnen deze lijst volgen en zien';

  @override
  String get listCancel => 'Annuleren';

  @override
  String get listCreate => 'Maken';

  @override
  String get listCreateFailed => 'Lijst maken mislukt';

  @override
  String get keyManagementTitle => 'Nostr-sleutels';

  @override
  String get keyManagementWhatAreKeys => 'Wat zijn Nostr-sleutels?';

  @override
  String get keyManagementExplanation =>
      'Je Nostr-identiteit is een cryptografisch sleutelpaar:\n\n• Je publieke sleutel (npub) is als je gebruikersnaam — deel hem gerust\n• Je privésleutel (nsec) is als je wachtwoord — houd hem geheim!\n\nJe nsec geeft je toegang tot je account in elke Nostr-app.';

  @override
  String get keyManagementImportTitle => 'Bestaande sleutel importeren';

  @override
  String get keyManagementImportSubtitle =>
      'Heb je al een Nostr-account? Plak je privésleutel (nsec) om er hier toegang toe te krijgen.';

  @override
  String get keyManagementImportButton => 'Sleutel importeren';

  @override
  String get keyManagementImportWarning => 'Dit vervangt je huidige sleutel!';

  @override
  String get keyManagementBackupTitle => 'Maak een back-up van je sleutel';

  @override
  String get keyManagementBackupSubtitle =>
      'Sla je privésleutel (nsec) op om je account in andere Nostr-apps te gebruiken.';

  @override
  String get keyManagementCopyNsec => 'Mijn privésleutel kopiëren (nsec)';

  @override
  String get keyManagementNeverShare => 'Deel je nsec nooit met iemand!';

  @override
  String get keyManagementPasteKey => 'Plak je privésleutel';

  @override
  String get keyManagementInvalidFormat =>
      'Ongeldig sleutelformaat. Moet beginnen met \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Deze sleutel importeren?';

  @override
  String get keyManagementConfirmImportBody =>
      'Dit vervangt je huidige identiteit door de geïmporteerde.\n\nJe huidige sleutel is weg tenzij je eerst een back-up hebt gemaakt.';

  @override
  String get keyManagementImportConfirm => 'Importeren';

  @override
  String get keyManagementImportSuccess => 'Sleutel succesvol geïmporteerd!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Sleutel importeren mislukt: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Privésleutel gekopieerd naar klembord!\n\nBewaar hem ergens veilig.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Sleutel exporteren mislukt: $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Je publieke sleutel (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Publieke sleutel kopiëren';

  @override
  String get keyManagementPublicKeyCopied => 'Publieke sleutel gekopieerd';

  @override
  String get profileEditPublicKeyLink => 'Bekijk je publieke sleutel';

  @override
  String get saveOriginalSavedToCameraRoll => 'Opgeslagen in camerarol';

  @override
  String get saveOriginalShare => 'Delen';

  @override
  String get saveOriginalDone => 'Klaar';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Toegang tot Foto\'s nodig';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Om video\'s op te slaan, geef je in Instellingen toegang tot Foto\'s.';

  @override
  String get saveOriginalOpenSettings => 'Instellingen openen';

  @override
  String get saveOriginalNotNow => 'Niet nu';

  @override
  String get cameraPermissionNotNow => 'Niet nu';

  @override
  String get saveOriginalDownloadFailed => 'Download mislukt';

  @override
  String get saveOriginalDismiss => 'Sluiten';

  @override
  String get saveOriginalDownloadingVideo => 'Video downloaden';

  @override
  String get saveOriginalSavingToCameraRoll => 'Opslaan in camerarol';

  @override
  String get saveOriginalFetchingVideo => 'Video ophalen van het netwerk...';

  @override
  String get saveOriginalSavingVideo =>
      'Originele video in je camerarol opslaan...';

  @override
  String get soundTitle => 'Geluid';

  @override
  String get soundOriginalSound => 'Origineel geluid';

  @override
  String get soundVideosUsingThisSound => 'Video\'s die dit geluid gebruiken';

  @override
  String get soundSourceVideo => 'Bronvideo';

  @override
  String get soundNoVideosYet => 'Nog geen video\'s';

  @override
  String get soundBeFirstToUse => 'Wees de eerste die dit geluid gebruikt!';

  @override
  String get soundFailedToLoadVideos => 'Video\'s laden mislukt';

  @override
  String get soundRetry => 'Opnieuw';

  @override
  String get soundVideosUnavailable => 'Video\'s niet beschikbaar';

  @override
  String get soundCouldNotLoadDetails => 'Videodetails laden mislukt';

  @override
  String get soundPreview => 'Voorbeluisteren';

  @override
  String get soundStop => 'Stoppen';

  @override
  String get soundUseSound => 'Geluid gebruiken';

  @override
  String get soundUntitled => 'Geluid zonder titel';

  @override
  String get soundStopPreview => 'Preview stoppen';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Preview $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Details bekijken voor $title';
  }

  @override
  String get soundNoVideoCount => 'Nog geen video\'s';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video\'s';
  }

  @override
  String get soundUnableToPreview =>
      'Geluid voorbeluisteren lukt niet — geen audio beschikbaar';

  @override
  String soundPreviewFailed(Object error) {
    return 'Voorbeluistering afspelen mislukt: $error';
  }

  @override
  String get soundViewSource => 'Bron bekijken';

  @override
  String get soundCloseTooltip => 'Sluiten';

  @override
  String get exploreNotExploreRoute => 'Geen explore-route';

  @override
  String get legalTitle => 'Juridisch';

  @override
  String get legalTermsOfService => 'Servicevoorwaarden';

  @override
  String get legalTermsOfServiceSubtitle => 'Gebruiksvoorwaarden en -condities';

  @override
  String get legalPrivacyPolicy => 'Privacybeleid';

  @override
  String get legalPrivacyPolicySubtitle => 'Hoe we met je data omgaan';

  @override
  String get legalSafetyStandards => 'Veiligheidsstandaarden';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Communityrichtlijnen en veiligheid';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Auteursrecht- en verwijderbeleid';

  @override
  String get legalOpenSourceLicenses => 'Open source-licenties';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Attributies van externe packages';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName openen mislukt';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Fout bij openen van $pageName: $error';
  }

  @override
  String get categoryAction => 'Actie';

  @override
  String get categoryAdventure => 'Avontuur';

  @override
  String get categoryAnimals => 'Dieren';

  @override
  String get categoryAnimation => 'Animatie';

  @override
  String get categoryArchitecture => 'Architectuur';

  @override
  String get categoryArt => 'Kunst';

  @override
  String get categoryAutomotive => 'Auto\'s';

  @override
  String get categoryAwardShow => 'Awardshow';

  @override
  String get categoryAwards => 'Awards';

  @override
  String get categoryBaseball => 'Honkbal';

  @override
  String get categoryBasketball => 'Basketbal';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Drank';

  @override
  String get categoryCars => 'Auto\'s';

  @override
  String get categoryCelebration => 'Feest';

  @override
  String get categoryCelebrities => 'Beroemdheden';

  @override
  String get categoryCelebrity => 'Beroemdheid';

  @override
  String get categoryCityscape => 'Stadsgezicht';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Koken';

  @override
  String get categoryCostume => 'Kostuum';

  @override
  String get categoryCrafts => 'Knutselen';

  @override
  String get categoryCrime => 'Misdaad';

  @override
  String get categoryCulture => 'Cultuur';

  @override
  String get categoryDance => 'Dans';

  @override
  String get categoryDiy => 'Zelf doen';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Onderwijs';

  @override
  String get categoryEmotional => 'Emotioneel';

  @override
  String get categoryEmotions => 'Emoties';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Familie';

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
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Eten';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Meubels';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Verzorging';

  @override
  String get categoryGuitar => 'Gitaar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Gezondheid';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Vakantie';

  @override
  String get categoryHome => 'Thuis';

  @override
  String get categoryHomeImprovement => 'Klussen';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Ziekenhuis';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Interieur';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Kids';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Make-up';

  @override
  String get categoryMedical => 'Medisch';

  @override
  String get categoryMusic => 'Muziek';

  @override
  String get categoryMystery => 'Mysterie';

  @override
  String get categoryNature => 'Natuur';

  @override
  String get categoryNews => 'Nieuws';

  @override
  String get categoryOutdoor => 'Buiten';

  @override
  String get categoryParty => 'Feest';

  @override
  String get categoryPeople => 'Mensen';

  @override
  String get categoryPerformance => 'Optreden';

  @override
  String get categoryPets => 'Huisdieren';

  @override
  String get categoryPolitics => 'Politiek';

  @override
  String get categoryPrank => 'Grap';

  @override
  String get categoryPranks => 'Grappen';

  @override
  String get categoryRealityShow => 'Realityshow';

  @override
  String get categoryRelationship => 'Relatie';

  @override
  String get categoryRelationships => 'Relaties';

  @override
  String get categoryRomance => 'Romantiek';

  @override
  String get categorySchool => 'School';

  @override
  String get categoryScienceFiction => 'Sciencefiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Winkelen';

  @override
  String get categorySkateboarding => 'Skateboarden';

  @override
  String get categorySkincare => 'Huidverzorging';

  @override
  String get categorySoccer => 'Voetbal';

  @override
  String get categorySocialGathering => 'Samenkomst';

  @override
  String get categorySocialMedia => 'Social media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talkshow';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryTelevision => 'Televisie';

  @override
  String get categoryToys => 'Speelgoed';

  @override
  String get categoryTransportation => 'Vervoer';

  @override
  String get categoryTravel => 'Reizen';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Geweld';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vloggen';

  @override
  String get categoryWrestling => 'Worstelen';

  @override
  String get profileSetupUploadSuccess => 'Profielfoto succesvol geüpload!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName gerapporteerd';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName geblokkeerd';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName gedeblokkeerd';
  }

  @override
  String get inboxRemovedConversation => 'Gesprek verwijderd';

  @override
  String get inboxEmptyTitle => 'Nog geen berichten';

  @override
  String get inboxEmptySubtitle => 'Die +-knop bijt niet.';

  @override
  String get inboxActionMute => 'Gesprek dempen';

  @override
  String inboxActionReport(String displayName) {
    return '$displayName rapporteren';
  }

  @override
  String inboxActionBlock(String displayName) {
    return '$displayName blokkeren';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return '$displayName deblokkeren';
  }

  @override
  String get inboxActionRemove => 'Gesprek verwijderen';

  @override
  String get inboxRemoveConfirmTitle => 'Gesprek verwijderen?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Dit verwijdert je gesprek met $displayName. Deze actie kan niet ongedaan worden gemaakt.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Verwijderen';

  @override
  String get inboxConversationMuted => 'Gesprek gedempt';

  @override
  String get inboxConversationUnmuted => 'Gesprek niet meer gedempt';

  @override
  String get inboxCollabInviteCardTitle => 'Uitnodiging om samen te werken';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role bij deze post';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'Accepteren';

  @override
  String get inboxCollabInviteIgnoreButton => 'Negeren';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Geaccepteerd';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Genegeerd';

  @override
  String get inboxCollabInviteAcceptError =>
      'Accepteren is niet gelukt. Probeer het opnieuw.';

  @override
  String get inboxCollabInviteSentStatus => 'Uitnodiging verzonden';

  @override
  String get inboxConversationCollabInvitePreview =>
      'Uitnodiging om samen te werken';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Je bent uitgenodigd om samen te werken aan $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Je bent uitgenodigd om samen te werken aan een video: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String get reportDialogCancel => 'Annuleren';

  @override
  String get reportDialogReport => 'Rapporteren';

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
  String get exploreSearchHint => 'Zoeken...';

  @override
  String categoryVideoCount(String count) {
    return '$count video\'s';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Abonnement bijwerken mislukt: $error';
  }

  @override
  String get discoverListsTitle => 'Lijsten ontdekken';

  @override
  String get discoverListsFailedToLoad => 'Lijsten laden mislukt';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Lijsten laden mislukt: $error';
  }

  @override
  String get discoverListsLoading => 'Publieke lijsten worden ontdekt...';

  @override
  String get discoverListsEmptyTitle => 'Geen publieke lijsten gevonden';

  @override
  String get discoverListsEmptySubtitle =>
      'Kom later terug voor nieuwe lijsten';

  @override
  String get discoverListsByAuthorPrefix => 'door';

  @override
  String get curatedListEmptyTitle => 'Geen video\'s in deze lijst';

  @override
  String get curatedListEmptySubtitle => 'Voeg wat video\'s toe om te beginnen';

  @override
  String get curatedListLoadingVideos => 'Video\'s laden...';

  @override
  String get curatedListFailedToLoad => 'Lijst laden mislukt';

  @override
  String get curatedListNoVideosAvailable => 'Geen video\'s beschikbaar';

  @override
  String get curatedListVideoNotAvailable => 'Video niet beschikbaar';

  @override
  String get commonRetry => 'Opnieuw proberen';

  @override
  String get commonNext => 'Volgende';

  @override
  String get commonDelete => 'Verwijderen';

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get commonBack => 'Terug';

  @override
  String get commonClose => 'Sluiten';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Vervaldatum';

  @override
  String get videoMetadataExpirationNotExpire => 'Verloopt niet';

  @override
  String get videoMetadataExpirationOneDay => '1 dag';

  @override
  String get videoMetadataExpirationOneWeek => '1 week';

  @override
  String get videoMetadataExpirationOneMonth => '1 maand';

  @override
  String get videoMetadataExpirationOneYear => '1 jaar';

  @override
  String get videoMetadataExpirationOneDecade => '1 decennium';

  @override
  String get videoMetadataContentWarnings => 'Inhoudswaarschuwingen';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get proofmodeCheckAiGenerated => 'Controleren of AI-gegenereerd';

  @override
  String get libraryDeleteConfirm => 'Verwijderen';

  @override
  String get libraryWebUnavailableHeadline =>
      'Bibliotheek is beschikbaar in de mobiele app';

  @override
  String get libraryWebUnavailableDescription =>
      'Concepten en clips worden op je apparaat opgeslagen. Open Divine op je telefoon om ze te beheren.';

  @override
  String get libraryTabDrafts => 'Concepten';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get librarySaveToCameraRollTooltip => 'Opslaan in filmrol';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Geselecteerde clips verwijderen';

  @override
  String get libraryDeleteClipsTitle => 'Clips verwijderen';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# geselecteerde clips',
      one: '# geselecteerde clip',
    );
    return 'Weet je zeker dat je $_temp0 wilt verwijderen?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Dit kan niet ongedaan worden gemaakt. De videobestanden worden permanent van je apparaat verwijderd.';

  @override
  String get libraryPreparingVideo => 'Video voorbereiden...';

  @override
  String get libraryCreateVideo => 'Video maken';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 opgeslagen in $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount opgeslagen, $failureCount mislukt';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Toestemming geweigerd voor $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips verwijderd',
      one: '1 clip verwijderd',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Concepten konden niet worden geladen';

  @override
  String get libraryCouldNotLoadClips => 'Clips konden niet worden geladen';

  @override
  String get libraryOpenErrorDescription =>
      'Er ging iets mis bij het openen van je bibliotheek. Probeer het opnieuw.';

  @override
  String get libraryNoDraftsYetTitle => 'Nog geen concepten';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Video\'\'s die je als concept opslaat, verschijnen hier';

  @override
  String get libraryNoClipsYetTitle => 'Nog geen clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Je opgenomen videoclips verschijnen hier';

  @override
  String get libraryDraftDeletedSnackbar => 'Concept verwijderd';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Concept verwijderen mislukt';

  @override
  String get libraryDraftActionPost => 'Plaatsen';

  @override
  String get libraryDraftActionEdit => 'Bewerken';

  @override
  String get libraryDraftActionDelete => 'Concept verwijderen';

  @override
  String get libraryDeleteDraftTitle => 'Concept verwijderen';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Weet je zeker dat je \"$title\" wilt verwijderen?';
  }

  @override
  String get libraryDeleteClipTitle => 'Clip verwijderen';

  @override
  String get libraryDeleteClipMessage =>
      'Weet je zeker dat je deze clip wilt verwijderen?';

  @override
  String get libraryClipSelectionTitle => 'Clips';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Nog ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Toevoegen';

  @override
  String get libraryRecordVideo => 'Video opnemen';

  @override
  String get routerInvalidCreator => 'Ongeldige maker';

  @override
  String get routerInvalidHashtagRoute => 'Ongeldige hashtagroute';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Video\'s konden niet worden geladen';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Geen video\'s in deze categorie';

  @override
  String get categoryGallerySortOptionsLabel => 'Sorteeropties categorie';

  @override
  String get categoryGallerySortHot => 'Hot';

  @override
  String get categoryGallerySortNew => 'Nieuw';

  @override
  String get categoryGallerySortClassic => 'Klassiek';

  @override
  String get categoryGallerySortForYou => 'Voor jou';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Categorieën konden niet worden geladen';

  @override
  String get categoriesNoCategoriesAvailable => 'Geen categorieën beschikbaar';

  @override
  String get notificationsEmptyTitle => 'Nog geen activiteit';

  @override
  String get notificationsEmptySubtitle =>
      'Wanneer mensen reageren op je inhoud, zie je het hier';

  @override
  String get appsPermissionsTitle => 'Integratierechten';

  @override
  String get appsPermissionsRevoke => 'Intrekken';

  @override
  String get appsPermissionsEmptyTitle => 'Geen opgeslagen integratierechten';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Goedgekeurde integraties verschijnen hier nadat je een toegangsgoedkeuring onthoudt.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName vraagt jouw goedkeuring';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Deze app vraagt toegang via Divine\'s gecontroleerde sandbox.';

  @override
  String get nostrAppPermissionOrigin => 'Oorsprong';

  @override
  String get nostrAppPermissionMethod => 'Methode';

  @override
  String get nostrAppPermissionCapability => 'Bevoegdheid';

  @override
  String get nostrAppPermissionEventKind => 'Event-kind';

  @override
  String get nostrAppPermissionAllow => 'Toestaan';

  @override
  String get bugReportSendReport => 'Rapport verzenden';

  @override
  String get supportSubjectRequiredLabel => 'Onderwerp *';

  @override
  String get supportRequiredHelper => 'Verplicht';

  @override
  String get bugReportSubjectHint => 'Korte samenvatting van het probleem';

  @override
  String get bugReportDescriptionRequiredLabel => 'Wat is er gebeurd? *';

  @override
  String get bugReportDescriptionHint =>
      'Beschrijf het probleem dat je tegenkwam';

  @override
  String get bugReportStepsLabel => 'Stappen om te reproduceren';

  @override
  String get bugReportStepsHint => '1. Ga naar...\n2. Tik op...\n3. Zie fout';

  @override
  String get bugReportExpectedBehaviorLabel => 'Verwacht gedrag';

  @override
  String get bugReportExpectedBehaviorHint => 'Wat had er moeten gebeuren?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Apparaatinfo en logs worden automatisch meegestuurd.';

  @override
  String get bugReportSuccessMessage =>
      'Dank je! We hebben je rapport ontvangen en gebruiken het om Divine beter te maken.';

  @override
  String get bugReportSendFailed =>
      'Bugrapport verzenden mislukt. Probeer het later opnieuw.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Bugrapport verzenden mislukt: $error';
  }

  @override
  String get featureRequestSendRequest => 'Verzoek verzenden';

  @override
  String get featureRequestSubjectHint => 'Korte samenvatting van je idee';

  @override
  String get featureRequestDescriptionRequiredLabel => 'Wat zou je willen? *';

  @override
  String get featureRequestDescriptionHint =>
      'Beschrijf de functie die je wilt';

  @override
  String get featureRequestUsefulnessLabel => 'Hoe zou dit nuttig zijn?';

  @override
  String get featureRequestUsefulnessHint =>
      'Leg uit welk voordeel deze functie zou bieden';

  @override
  String get featureRequestWhenLabel => 'Wanneer zou je dit gebruiken?';

  @override
  String get featureRequestWhenHint =>
      'Beschrijf de situaties waarin dit zou helpen';

  @override
  String get featureRequestSuccessMessage =>
      'Dank je! We hebben je functieverzoek ontvangen en zullen het bekijken.';

  @override
  String get featureRequestSendFailed =>
      'Functieverzoek verzenden mislukt. Probeer het later opnieuw.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Functieverzoek verzenden mislukt: $error';
  }

  @override
  String get notificationFollowBack => 'Terugvolgen';

  @override
  String get followingTitle => 'Volgend';

  @override
  String followingTitleForName(String displayName) {
    return 'Volgers van $displayName';
  }

  @override
  String get followingFailedToLoadList => 'Volglijst kon niet worden geladen';

  @override
  String get followingEmptyTitle => 'Volgt nog niemand';

  @override
  String get followersTitle => 'Volgers';

  @override
  String followersTitleForName(String displayName) {
    return 'Volgers van $displayName';
  }

  @override
  String get followersFailedToLoadList => 'Volgerlijst kon niet worden geladen';

  @override
  String get followersEmptyTitle => 'Nog geen volgers';

  @override
  String get followersUpdateFollowFailed =>
      'Volgstatus bijwerken mislukt. Probeer het opnieuw.';

  @override
  String get reportMessageTitle => 'Bericht rapporteren';

  @override
  String get reportMessageWhyReporting => 'Waarom rapporteer je dit bericht?';

  @override
  String get reportMessageSelectReason =>
      'Kies een reden om dit bericht te rapporteren';

  @override
  String get newMessageTitle => 'Nieuw bericht';

  @override
  String get newMessageFindPeople => 'Mensen zoeken';

  @override
  String get newMessageNoContacts =>
      'Geen contacten gevonden.\nVolg mensen om ze hier te zien.';

  @override
  String get newMessageNoUsersFound => 'Geen gebruikers gevonden';

  @override
  String get hashtagSearchTitle => 'Zoek hashtags';

  @override
  String get hashtagSearchSubtitle => 'Ontdek trending onderwerpen en inhoud';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Geen hashtags gevonden voor \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Zoeken mislukt';

  @override
  String get userNotAvailableTitle => 'Account niet beschikbaar';

  @override
  String get userNotAvailableBody =>
      'Dit account is op dit moment niet beschikbaar.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Instellingen opslaan mislukt: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Voer een geldige server-URL in (bijv. https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Blossom-instellingen opgeslagen';

  @override
  String get blossomSaveTooltip => 'Opslaan';

  @override
  String get blossomAboutTitle => 'Over Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom is een gedecentraliseerd protocol voor mediaopslag waarmee je video\'s kunt uploaden naar elke compatibele server. Standaard worden video\'s geüpload naar Divine\'s Blossom-server. Schakel de optie hieronder in om een eigen server te gebruiken.';

  @override
  String get blossomUseCustomServer => 'Eigen Blossom-server gebruiken';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Video\'s worden geüpload naar je eigen Blossom-server';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Je video\'s worden momenteel geüpload naar Divine\'s Blossom-server';

  @override
  String get blossomCustomServerUrl => 'URL eigen Blossom-server';

  @override
  String get blossomCustomServerHelper =>
      'Voer de URL in van je eigen Blossom-server';

  @override
  String get blossomPopularServers => 'Populaire Blossom-servers';

  @override
  String get blossomServerUrlMustUseHttps =>
      'Blossom-server-URL moet https:// gebruiken';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Crosspost-instelling bijwerken mislukt';

  @override
  String get blueskySignInRequired =>
      'Log in om Bluesky-instellingen te beheren';

  @override
  String get blueskyPublishVideos => 'Video\'s publiceren naar Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Je video\'s worden gepubliceerd naar Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Je video\'s worden niet gepubliceerd naar Bluesky';

  @override
  String get blueskyHandle => 'Bluesky-handle';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Account aangemaakt en klaar';

  @override
  String get blueskyStatusPending => 'Account wordt aangemaakt...';

  @override
  String get blueskyStatusFailed => 'Account aanmaken mislukt';

  @override
  String get blueskyStatusDisabled => 'Account uitgeschakeld';

  @override
  String get blueskyStatusNotLinked => 'Geen Bluesky-account gekoppeld';

  @override
  String get invitesTitle => 'Vrienden uitnodigen';

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
  String get invitesNoneAvailable =>
      'Op dit moment geen uitnodigingen beschikbaar';

  @override
  String get invitesShareWithPeople => 'Deel diVine met mensen die je kent';

  @override
  String get invitesUsedInvites => 'Gebruikte uitnodigingen';

  @override
  String invitesShareMessage(String code) {
    return 'Doe met me mee op diVine! Gebruik invite-code $code om te beginnen:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Uitnodiging kopiëren';

  @override
  String get invitesCopied => 'Uitnodiging gekopieerd!';

  @override
  String get invitesShareInvite => 'Uitnodiging delen';

  @override
  String get invitesShareSubject => 'Doe met me mee op diVine';

  @override
  String get invitesClaimed => 'Geclaimd';

  @override
  String get invitesCouldNotLoad => 'Uitnodigingen konden niet geladen worden';

  @override
  String get invitesRetry => 'Opnieuw proberen';

  @override
  String get searchSomethingWentWrong => 'Er ging iets mis';

  @override
  String get searchTryAgain => 'Opnieuw proberen';

  @override
  String get searchForLists => 'Zoek naar lijsten';

  @override
  String get searchFindCuratedVideoLists => 'Vind samengestelde videolijsten';

  @override
  String get searchEnterQuery => 'Voer een zoekopdracht in';

  @override
  String get searchDiscoverSomethingInteresting => 'Ontdek iets interessants';

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
  String get searchListsSectionHeader => 'Lijsten';

  @override
  String get searchListsLoadingLabel => 'Lijstresultaten laden';

  @override
  String get cameraAgeRestriction =>
      'Je moet 16 jaar of ouder zijn om content te maken';

  @override
  String get featureRequestCancel => 'Annuleren';

  @override
  String keyImportError(String error) {
    return 'Fout: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Bunker-relay moet wss:// gebruiken (ws:// is alleen toegestaan voor localhost)';

  @override
  String get timeNow => 'nu';

  @override
  String timeShortMinutes(int count) {
    return '${count}min';
  }

  @override
  String timeShortHours(int count) {
    return '${count}u';
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
    return '${count}ma';
  }

  @override
  String timeShortYears(int count) {
    return '${count}j';
  }

  @override
  String get timeVerboseNow => 'Nu';

  @override
  String timeAgo(String time) {
    return '$time geleden';
  }

  @override
  String get timeToday => 'Vandaag';

  @override
  String get timeYesterday => 'Gisteren';

  @override
  String get timeJustNow => 'zojuist';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min geleden';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}u geleden';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d geleden';
  }

  @override
  String get draftTimeJustNow => 'Zojuist';

  @override
  String get contentLabelNudity => 'Naaktheid';

  @override
  String get contentLabelSexualContent => 'Seksuele inhoud';

  @override
  String get contentLabelPornography => 'Pornografie';

  @override
  String get contentLabelGraphicMedia => 'Schokkende media';

  @override
  String get contentLabelViolence => 'Geweld';

  @override
  String get contentLabelSelfHarm => 'Zelfbeschadiging/Suïcide';

  @override
  String get contentLabelDrugUse => 'Drugsgebruik';

  @override
  String get contentLabelAlcohol => 'Alcohol';

  @override
  String get contentLabelTobacco => 'Tabak/Roken';

  @override
  String get contentLabelGambling => 'Gokken';

  @override
  String get contentLabelProfanity => 'Grof taalgebruik';

  @override
  String get contentLabelHateSpeech => 'Haatspraak';

  @override
  String get contentLabelHarassment => 'Intimidatie';

  @override
  String get contentLabelFlashingLights => 'Flitsende lichten';

  @override
  String get contentLabelAiGenerated => 'AI-gegenereerd';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Oplichting/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Misleidend';

  @override
  String get contentLabelSensitiveContent => 'Gevoelige inhoud';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName vond je video leuk';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName vond je reactie leuk';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName heeft op je video gereageerd';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName volgt je nu';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName heeft je genoemd';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName heeft je video gedeeld';
  }

  @override
  String get notificationRepliedToYourComment =>
      'heeft op je reactie gereageerd';

  @override
  String get notificationAndConnector => 'en';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count anderen',
      one: '1 ander',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Je hebt een nieuwe update';

  @override
  String get notificationSomeoneLikedYourVideo => 'Iemand vond je video leuk';

  @override
  String get commentReplyToPrefix => 'Re:';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get draftUntitled => 'Naamloos';

  @override
  String get contentWarningNone => 'Geen';

  @override
  String get textBackgroundNone => 'Geen';

  @override
  String get textBackgroundSolid => 'Dekkend';

  @override
  String get textBackgroundHighlight => 'Markering';

  @override
  String get textBackgroundTransparent => 'Transparant';

  @override
  String get textAlignLeft => 'Links';

  @override
  String get textAlignRight => 'Rechts';

  @override
  String get textAlignCenter => 'Gecentreerd';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Camera wordt nog niet ondersteund op het web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Camerabeelden opnemen en video opnemen zijn nog niet beschikbaar in de webversie.';

  @override
  String get cameraPermissionBackToFeed => 'Terug naar feed';

  @override
  String get cameraPermissionErrorTitle => 'Machtigingsfout';

  @override
  String get cameraPermissionErrorDescription =>
      'Er is iets misgegaan bij het controleren van machtigingen.';

  @override
  String get cameraPermissionRetry => 'Opnieuw proberen';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Toegang tot camera en microfoon toestaan';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Hiermee kun je video\'s rechtstreeks in de app opnemen en bewerken, verder niets.';

  @override
  String get cameraPermissionContinue => 'Doorgaan';

  @override
  String get cameraPermissionGoToSettings => 'Naar instellingen';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Waarom zes seconden?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Korte clips geven ruimte aan spontaniteit. Het 6-secondenformaat helpt je om authentieke momenten vast te leggen terwijl ze gebeuren.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Begrepen!';

  @override
  String get videoRecorderUploadTitle => 'Waarom geen upload?';

  @override
  String get videoRecorderUploadBody =>
      'Wat je op Divine ziet, is door mensen gemaakt: rauw en op het moment vastgelegd. In tegenstelling tot platforms die zwaar geproduceerde of door AI gegenereerde uploads toestaan, geven we prioriteit aan de authenticiteit van de camera-directe ervaring.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Door creatie binnen de app te houden, kunnen we beter garanderen dat content echt en onbewerkt is. We openen op dit moment geen externe galerij-uploads om die echtheid te beschermen en onze community zoveel mogelijk vrij te houden van synthetische content.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Schakel over naar Capture of Classic om iets echts op te nemen.';

  @override
  String get videoRecorderUploadLearnMore => 'Ontdek hoe verificatie werkt';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'We hebben werk in uitvoering gevonden';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Wil je doorgaan waar je was gebleven?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Ja, doorgaan';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Nee, start een nieuwe video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Je concept kon niet worden hersteld';

  @override
  String get videoRecorderStopRecordingTooltip => 'Opname stoppen';

  @override
  String get videoRecorderStartRecordingTooltip => 'Opname starten';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Bezig met opnemen. Tik ergens om te stoppen';

  @override
  String get videoRecorderTapToStartLabel =>
      'Tik ergens om de opname te starten';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Laatste clip verwijderen';

  @override
  String get videoRecorderSwitchCameraLabel => 'Camera wisselen';

  @override
  String get videoRecorderToggleGridLabel => 'Raster in-/uitschakelen';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Spookframe in-/uitschakelen';

  @override
  String get videoRecorderGhostFrameEnabled => 'Spookframe ingeschakeld';

  @override
  String get videoRecorderGhostFrameDisabled => 'Spookframe uitgeschakeld';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip verwijderd';

  @override
  String get videoRecorderCloseLabel => 'Videorecorder sluiten';

  @override
  String get videoRecorderContinueToEditorLabel => 'Doorgaan naar video-editor';

  @override
  String get videoRecorderCaptureCloseLabel => 'Sluiten';

  @override
  String get videoRecorderCaptureNextLabel => 'Volgende';

  @override
  String get videoRecorderToggleFlashLabel => 'Flitser in-/uitschakelen';

  @override
  String get videoRecorderCycleTimerLabel => 'Timer wisselen';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Beeldverhouding wisselen';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clipbibliotheek, geen clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Clipbibliotheek openen, $clipCount clips',
      one: 'Clipbibliotheek openen, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Camera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Camera openen';

  @override
  String get videoEditorLibraryLabel => 'Bibliotheek';

  @override
  String get videoEditorTextLabel => 'Tekst';

  @override
  String get videoEditorDrawLabel => 'Tekenen';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorVolumeLabel => 'Volume';

  @override
  String get videoEditorAddTitle => 'Toevoegen';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Bibliotheek openen';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Audio-editor openen';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Teksteditor openen';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Tekeneditor openen';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Filtereditor openen';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Stickereditor openen';

  @override
  String get videoEditorSaveDraftTitle => 'Je concept opslaan?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Bewaar je bewerkingen voor later, of verwerp ze en verlaat de editor.';

  @override
  String get videoEditorSaveDraftButton => 'Concept opslaan';

  @override
  String get videoEditorDiscardChangesButton => 'Wijzigingen verwerpen';

  @override
  String get videoEditorKeepEditingButton => 'Doorgaan met bewerken';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Sleepzone om laag te verwijderen';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Loslaten om laag te verwijderen';

  @override
  String get videoEditorDoneLabel => 'Gereed';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Video afspelen of pauzeren';

  @override
  String get videoEditorCropSemanticLabel => 'Bijsnijden';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Kan clip niet splitsen terwijl deze wordt verwerkt. Even geduld.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Ongeldige splitpositie. Beide clips moeten minimaal $minDurationMs ms lang zijn.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Clip toevoegen uit bibliotheek';

  @override
  String get videoEditorSaveSelectedClip => 'Geselecteerde clip opslaan';

  @override
  String get videoEditorSplitClip => 'Clip splitsen';

  @override
  String get videoEditorSaveClip => 'Clip opslaan';

  @override
  String get videoEditorDeleteClip => 'Clip verwijderen';

  @override
  String get videoEditorClipSavedSuccess => 'Clip opgeslagen in bibliotheek';

  @override
  String get videoEditorClipSaveFailed => 'Clip opslaan mislukt';

  @override
  String get videoEditorClipDeleted => 'Clip verwijderd';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Kleurkiezer';

  @override
  String get videoEditorUndoSemanticLabel => 'Ongedaan maken';

  @override
  String get videoEditorRedoSemanticLabel => 'Opnieuw';

  @override
  String get videoEditorTextColorSemanticLabel => 'Tekstkleur';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Tekstuitlijning';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Tekstachtergrond';

  @override
  String get videoEditorFontSemanticLabel => 'Lettertype';

  @override
  String get videoEditorNoStickersFound => 'Geen stickers gevonden';

  @override
  String get videoEditorNoStickersAvailable => 'Geen stickers beschikbaar';

  @override
  String get videoEditorFailedLoadStickers => 'Stickers laden mislukt';

  @override
  String get videoEditorAdjustVolumeTitle => 'Volume aanpassen';

  @override
  String get videoEditorRecordedAudioLabel => 'Opgenomen audio';

  @override
  String get videoEditorCustomAudioLabel => 'Aangepaste audio';

  @override
  String get videoEditorPlaySemanticLabel => 'Afspelen';

  @override
  String get videoEditorPauseSemanticLabel => 'Pauzeren';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Audio dempen';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Audio inschakelen';

  @override
  String get videoEditorDeleteLabel => 'Verwijderen';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Geselecteerd item verwijderen';

  @override
  String get videoEditorEditLabel => 'Bewerken';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Geselecteerd item bewerken';

  @override
  String get videoEditorDuplicateLabel => 'Dupliceren';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Geselecteerd item dupliceren';

  @override
  String get videoEditorSplitLabel => 'Splitsen';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Geselecteerde clip splitsen';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Bewerken van tijdlijn voltooien';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Voorbeeld afspelen';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Voorbeeld pauzeren';

  @override
  String get videoEditorAudioUntitledSound => 'Naamloos geluid';

  @override
  String get videoEditorAudioUntitled => 'Naamloos';

  @override
  String get videoEditorAudioAddAudio => 'Audio toevoegen';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'Geen geluiden beschikbaar';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Geluiden verschijnen hier wanneer creators audio delen';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Geluiden laden mislukt';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Selecteer het audiofragment voor je video';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Gemeenschap';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Pijlgereedschap';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Gumgereedschap';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Markeergereedschap';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Potloodgereedschap';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Laag $index herordenen';
  }

  @override
  String get videoEditorLayerReorderHint => 'Vasthouden om te herordenen';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Tijdlijn tonen';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Tijdlijn verbergen';

  @override
  String get videoEditorFeedPreviewContent =>
      'Plaats geen content achter deze gebieden.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originelen';

  @override
  String get videoEditorStickerSearchHint => 'Stickers zoeken...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Lettertype selecteren';

  @override
  String get videoEditorFontUnknown => 'Onbekend';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'De afspeelkop moet binnen de geselecteerde clip staan om te splitsen.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Begin bijsnijden';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Einde bijsnijden';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Clip bijsnijden';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Sleep de handgrepen om de clipduur aan te passen';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Clip $index slepen';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index van $total, $duration seconden';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Lang indrukken om te slepen';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Tik om te bewerken. Houd vast en sleep om te herordenen.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Naar links verplaatsen';

  @override
  String get videoEditorTimelineClipMoveRight => 'Naar rechts verplaatsen';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Lang indrukken om te slepen';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Videotijdlijn';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, geselecteerd';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Kleurkiezer sluiten';

  @override
  String get videoEditorPickColorTitle => 'Kleur kiezen';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Kleur bevestigen';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Verzadiging en helderheid';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Verzadiging $saturation%, Helderheid $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Tint';

  @override
  String get videoEditorAddElementSemanticLabel => 'Element toevoegen';

  @override
  String get videoEditorCloseSemanticLabel => 'Sluiten';

  @override
  String get videoEditorDoneSemanticLabel => 'Gereed';

  @override
  String get videoEditorLevelSemanticLabel => 'Niveau';

  @override
  String get videoMetadataBackSemanticLabel => 'Terug';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Helpdialoog sluiten';

  @override
  String get videoMetadataGotItButton => 'Begrepen!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limiet van 64KB bereikt. Verwijder wat inhoud om door te gaan.';

  @override
  String get videoMetadataExpirationLabel => 'Vervaldatum';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Vervaltijd selecteren';

  @override
  String get videoMetadataTitleLabel => 'Titel';

  @override
  String get videoMetadataDescriptionLabel => 'Beschrijving';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Verwijderen';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Tag $tag verwijderen';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Inhoudswaarschuwing';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Inhoudswaarschuwingen selecteren';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selecteer alles wat van toepassing is op je inhoud';

  @override
  String get videoMetadataContentWarningDoneButton => 'Gereed';

  @override
  String get videoMetadataCollaboratorsLabel => 'Samenwerkers';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Samenwerker toevoegen';

  @override
  String get videoMetadataCollaboratorsHelpTooltip => 'Hoe samenwerkers werken';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max samenwerkers';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Samenwerker verwijderen';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Samenwerkers worden als mede-makers getagd in dit bericht. Je kunt alleen mensen toevoegen die jij en zij elkaar volgen. Ze verschijnen in de metadata wanneer het bericht wordt gepubliceerd.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Wederzijdse volgers';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Jullie moeten elkaar volgen om $name als samenwerker toe te voegen.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Geinspireerd door';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Geinspireerd door instellen';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Hoe inspiratievermeldingen werken';

  @override
  String get videoMetadataInspiredByNone => 'Geen';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Gebruik dit voor bronvermelding. Geinspireerd door is iets anders dan samenwerkers: het erkent invloed, maar tagt iemand niet als mede-maker.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Naar deze creator kan niet worden verwezen.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Geinspireerd door verwijderen';

  @override
  String get videoMetadataPostDetailsTitle => 'Berichtdetails';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Opgeslagen in bibliotheek';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Opslaan mislukt';

  @override
  String get videoMetadataGoToLibraryButton => 'Naar bibliotheek';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Knop opslaan voor later';

  @override
  String get videoMetadataRenderingVideoHint => 'Video renderen...';

  @override
  String get videoMetadataSavingVideoHint => 'Video opslaan...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Video opslaan in concepten en $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Opslaan voor later';

  @override
  String get videoMetadataPostSemanticLabel => 'Knop plaatsen';

  @override
  String get videoMetadataPublishVideoHint => 'Video publiceren naar feed';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Vul het formulier in om in te schakelen';

  @override
  String get videoMetadataPostButton => 'Plaatsen';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Scherm met berichtvoorbeeld openen';

  @override
  String get videoMetadataShareTitle => 'Delen';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Videodetails';

  @override
  String get videoMetadataClassicDoneButton => 'Gereed';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Voorbeeld afspelen';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Voorbeeld pauzeren';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Videovoorbeeld sluiten';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Verwijderen';

  @override
  String get metadataCaptionsLabel => 'Ondertitels';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Ondertitels ingeschakeld voor alle video\'s';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Ondertitels uitgeschakeld voor alle video\'s';

  @override
  String get fullscreenFeedRemovedMessage => 'Video verwijderd';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Accepteer onderscheidingen en bekijk de status van uitgereikte badges.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesIntroTitle => 'Begrijp je badge-spoor';

  @override
  String get badgesIntroBody =>
      'Bekijk badges die je zijn toegekend, kies welke je vastpint op je Nostr-profiel, en zie of mensen jouw uitgereikte badges hebben geaccepteerd.';

  @override
  String get badgesOpenApp => 'Badges-app openen';

  @override
  String get badgesLoadError => 'Badges konden niet geladen worden';

  @override
  String get badgesUpdateError => 'Badge kon niet bijgewerkt worden';

  @override
  String get badgesAwardedSectionTitle => 'Aan jou toegekend';

  @override
  String get badgesAwardedEmptyTitle => 'Nog geen badges toegekend';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Wanneer iemand je een Nostr-badge toekent, landt die hier.';

  @override
  String get badgesStatusAccepted => 'Geaccepteerd';

  @override
  String get badgesStatusNotAccepted => 'Niet geaccepteerd';

  @override
  String get badgesActionRemove => 'Verwijderen';

  @override
  String get badgesActionAccept => 'Accepteren';

  @override
  String get badgesActionReject => 'Weigeren';

  @override
  String get badgesIssuedSectionTitle => 'Door jou uitgereikt';

  @override
  String get badgesIssuedEmptyTitle => 'Nog geen uitgereikte badges';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Badges die je uitreikt tonen hier hun acceptatiestatus.';

  @override
  String get badgesIssuedNoRecipients =>
      'Geen ontvangers gevonden voor deze toekenning.';

  @override
  String get badgesRecipientAcceptedStatus => 'Geaccepteerd door ontvanger';

  @override
  String get badgesRecipientWaitingStatus => 'Wacht op ontvanger';
}
