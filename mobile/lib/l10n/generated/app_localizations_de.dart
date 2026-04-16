// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsSecureAccount => 'Konto absichern';

  @override
  String get settingsSessionExpired => 'Sitzung abgelaufen';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Melde dich erneut an, um wieder vollen Zugriff zu haben';

  @override
  String get settingsCreatorAnalytics => 'Creator-Analytics';

  @override
  String get settingsSupportCenter => 'Support-Center';

  @override
  String get settingsNotifications => 'Benachrichtigungen';

  @override
  String get settingsContentPreferences => 'Inhaltseinstellungen';

  @override
  String get settingsModerationControls => 'Moderationseinstellungen';

  @override
  String get settingsBlueskyPublishing => 'Bluesky-Veröffentlichung';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Crossposting zu Bluesky verwalten';

  @override
  String get settingsNostrSettings => 'Nostr-Einstellungen';

  @override
  String get settingsIntegratedApps => 'Integrierte Apps';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Genehmigte Drittanbieter-Apps, die in Divine laufen';

  @override
  String get settingsExperimentalFeatures => 'Experimentelle Funktionen';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Spielereien, die noch holpern können—probier sie aus, wenn du neugierig bist.';

  @override
  String get settingsLegal => 'Rechtliches';

  @override
  String get settingsIntegrationPermissions => 'Integrations-Berechtigungen';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Gemerkte Integrations-Freigaben prüfen und widerrufen';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Entwicklermodus ist bereits aktiv';

  @override
  String get settingsDeveloperModeEnabled => 'Entwicklermodus aktiviert!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Noch $count Tippen, um den Entwicklermodus zu aktivieren';
  }

  @override
  String get settingsInvites => 'Einladungen';

  @override
  String get settingsSwitchAccount => 'Konto wechseln';

  @override
  String get settingsAddAnotherAccount => 'Weiteres Konto hinzufügen';

  @override
  String get settingsUnsavedDraftsTitle => 'Ungespeicherte Entwürfe';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entwürfe',
      one: 'Entwurf',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Entwürfe',
      one: 'Entwurf',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'sie',
      one: 'ihn',
    );
    return 'Du hast $count ungespeicherte $_temp0. Beim Kontowechsel bleiben deine $_temp1 erhalten, aber du solltest $_temp2 vorher vielleicht veröffentlichen oder durchgehen.';
  }

  @override
  String get settingsCancel => 'Abbrechen';

  @override
  String get settingsSwitchAnyway => 'Trotzdem wechseln';

  @override
  String get settingsAppVersionLabel => 'App-Version';

  @override
  String get settingsAppLanguage => 'App-Sprache';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (Gerätestandard)';
  }

  @override
  String get settingsAppLanguageTitle => 'App-Sprache';

  @override
  String get settingsAppLanguageDescription =>
      'Wähle die Sprache für die App-Oberfläche';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Gerätesprache verwenden';

  @override
  String get contentPreferencesTitle => 'Inhaltseinstellungen';

  @override
  String get contentPreferencesContentFilters => 'Inhaltsfilter';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Inhaltswarnungs-Filter verwalten';

  @override
  String get contentPreferencesContentLanguage => 'Inhaltssprache';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (Gerätestandard)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tagge deine Videos mit einer Sprache, damit Zuschauer filtern können.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Gerätesprache verwenden (Standard)';

  @override
  String get contentPreferencesAudioSharing =>
      'Mein Audio zur Wiederverwendung freigeben';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Wenn aktiviert, können andere Audio aus deinen Videos verwenden';

  @override
  String get contentPreferencesAccountLabels => 'Konto-Labels';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Kennzeichne deine Inhalte selbst';

  @override
  String get contentPreferencesAccountContentLabels => 'Konto-Inhalts-Labels';

  @override
  String get contentPreferencesClearAll => 'Alles löschen';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Wähle alles aus, was auf dein Konto zutrifft';

  @override
  String get contentPreferencesDoneNoLabels => 'Fertig (keine Labels)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Fertig ($count ausgewählt)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio-Eingabegerät';

  @override
  String get contentPreferencesAutoRecommended => 'Automatisch (empfohlen)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Wählt automatisch das beste Mikrofon';

  @override
  String get contentPreferencesSelectAudioInput => 'Audio-Eingabe wählen';

  @override
  String get contentPreferencesUnknownMicrophone => 'Unbekanntes Mikrofon';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Dieses Konto ist nicht verfügbar';

  @override
  String profileErrorPrefix(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get profileInvalidId => 'Ungültige Profil-ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Schau dir $displayName auf Divine an!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName auf Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Profil konnte nicht geteilt werden: $error';
  }

  @override
  String get profileEditProfile => 'Profil bearbeiten';

  @override
  String get profileCreatorAnalytics => 'Creator-Analytics';

  @override
  String get profileShareProfile => 'Profil teilen';

  @override
  String get profileCopyPublicKey => 'Public Key (npub) kopieren';

  @override
  String get profileGetEmbedCode => 'Embed-Code holen';

  @override
  String get profilePublicKeyCopied =>
      'Public Key in die Zwischenablage kopiert';

  @override
  String get profileEmbedCodeCopied =>
      'Embed-Code in die Zwischenablage kopiert';

  @override
  String get profileRefreshTooltip => 'Aktualisieren';

  @override
  String get profileRefreshSemanticLabel => 'Profil aktualisieren';

  @override
  String get profileMoreTooltip => 'Mehr';

  @override
  String get profileMoreSemanticLabel => 'Weitere Optionen';

  @override
  String get profileFollowingLabel => 'Gefolgt';

  @override
  String get profileFollowLabel => 'Folgen';

  @override
  String get profileBlockedLabel => 'Blockiert';

  @override
  String get profileFollowersLabel => 'Follower';

  @override
  String get profileFollowingStatLabel => 'Folgt';

  @override
  String get profileVideosLabel => 'Videos';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count Nutzer';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '$displayName blockieren?';
  }

  @override
  String get profileBlockExplanation => 'Wenn du einen Nutzer blockierst:';

  @override
  String get profileBlockBulletHidePosts =>
      'Seine Beiträge tauchen nicht mehr in deinen Feeds auf.';

  @override
  String get profileBlockBulletCantView =>
      'Er kann dein Profil nicht mehr ansehen, dir folgen oder deine Beiträge sehen.';

  @override
  String get profileBlockBulletNoNotify =>
      'Er wird nicht über die Änderung informiert.';

  @override
  String get profileBlockBulletYouCanView =>
      'Du kannst sein Profil weiterhin ansehen.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return '$displayName blockieren';
  }

  @override
  String get profileCancelButton => 'Abbrechen';

  @override
  String get profileLearnMore => 'Mehr erfahren';

  @override
  String profileUnblockTitle(String displayName) {
    return '$displayName entsperren?';
  }

  @override
  String get profileUnblockExplanation => 'Wenn du diesen Nutzer entsperrst:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Seine Beiträge erscheinen wieder in deinen Feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'Er kann dein Profil sehen, dir folgen und deine Beiträge ansehen.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Er wird nicht über die Änderung informiert.';

  @override
  String get profileLearnMoreAt => 'Mehr erfahren auf ';

  @override
  String get profileUnblockButton => 'Entsperren';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return '$displayName entfolgen';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return '$displayName blockieren';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return '$displayName entsperren';
  }

  @override
  String get profileUserBlockedTitle => 'Nutzer blockiert';

  @override
  String get profileUserBlockedContent =>
      'Du siehst keine Inhalte von diesem Nutzer mehr in deinen Feeds.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Du kannst ihn jederzeit über sein Profil oder unter Einstellungen > Sicherheit entsperren.';

  @override
  String get profileCloseButton => 'Schließen';

  @override
  String get profileNoCollabsTitle => 'Noch keine Collabs';

  @override
  String get profileCollabsOwnEmpty =>
      'Videos, bei denen du mitmachst, erscheinen hier';

  @override
  String get profileCollabsOtherEmpty =>
      'Videos, bei denen er mitmacht, erscheinen hier';

  @override
  String get profileErrorLoadingCollabs =>
      'Fehler beim Laden der Collab-Videos';

  @override
  String get profileNoCommentsOwnTitle => 'Noch keine Kommentare';

  @override
  String get profileNoCommentsOtherTitle => 'Keine Kommentare';

  @override
  String get profileCommentsOwnEmpty =>
      'Deine Kommentare und Antworten erscheinen hier';

  @override
  String get profileCommentsOtherEmpty =>
      'Seine Kommentare und Antworten erscheinen hier';

  @override
  String get profileErrorLoadingComments => 'Fehler beim Laden der Kommentare';

  @override
  String get profileVideoRepliesSection => 'Video-Antworten';

  @override
  String get profileCommentsSection => 'Kommentare';

  @override
  String get profileEditLabel => 'Bearbeiten';

  @override
  String get profileLibraryLabel => 'Bibliothek';

  @override
  String get profileNoLikedVideosTitle => 'Noch keine gelikten Videos';

  @override
  String get profileLikedOwnEmpty => 'Videos, die du likest, erscheinen hier';

  @override
  String get profileLikedOtherEmpty => 'Videos, die er likest, erscheinen hier';

  @override
  String get profileErrorLoadingLiked =>
      'Fehler beim Laden der gelikten Videos';

  @override
  String get profileNoRepostsTitle => 'Noch keine Reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Videos, die du repostest, erscheinen hier';

  @override
  String get profileRepostsOtherEmpty =>
      'Videos, die er repostest, erscheinen hier';

  @override
  String get profileErrorLoadingReposts => 'Fehler beim Laden der Reposts';

  @override
  String get profileLoadingTitle => 'Profil wird geladen...';

  @override
  String get profileLoadingSubtitle => 'Das kann einen Moment dauern';

  @override
  String get profileLoadingVideos => 'Videos werden geladen...';

  @override
  String get profileNoVideosTitle => 'Noch keine Videos';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Teile dein erstes Video, um es hier zu sehen';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Dieser Nutzer hat noch keine Videos geteilt';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video-Vorschaubild $number';
  }

  @override
  String get profileShowMore => 'Mehr anzeigen';

  @override
  String get profileShowLess => 'Weniger anzeigen';

  @override
  String get profileCompleteYourProfile => 'Profil vervollständigen';

  @override
  String get profileCompleteSubtitle =>
      'Füge Name, Bio und Bild hinzu, um loszulegen';

  @override
  String get profileSetUpButton => 'Einrichten';

  @override
  String get profileVerifyingEmail => 'E-Mail wird verifiziert...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Prüfe $email auf den Verifizierungslink';
  }

  @override
  String get profileWaitingForVerification => 'Warten auf E-Mail-Verifizierung';

  @override
  String get profileVerificationFailed => 'Verifizierung fehlgeschlagen';

  @override
  String get profilePleaseTryAgain => 'Bitte versuch es nochmal';

  @override
  String get profileSecureYourAccount => 'Konto absichern';

  @override
  String get profileSecureSubtitle =>
      'Füge E-Mail & Passwort hinzu, um dein Konto auf jedem Gerät wiederherzustellen';

  @override
  String get profileRetryButton => 'Erneut versuchen';

  @override
  String get profileRegisterButton => 'Registrieren';

  @override
  String get profileSessionExpired => 'Sitzung abgelaufen';

  @override
  String get profileSignInToRestore =>
      'Melde dich erneut an, um wieder vollen Zugriff zu haben';

  @override
  String get profileSignInButton => 'Anmelden';

  @override
  String get profileDismissTooltip => 'Schließen';

  @override
  String get profileLinkCopied => 'Profil-Link kopiert';

  @override
  String get profileSetupEditProfileTitle => 'Profil bearbeiten';

  @override
  String get profileSetupBackLabel => 'Zurück';

  @override
  String get profileSetupAboutNostr => 'Über Nostr';

  @override
  String get profileSetupProfilePublished =>
      'Profil erfolgreich veröffentlicht!';

  @override
  String get profileSetupCreateNewProfile => 'Neues Profil erstellen?';

  @override
  String get profileSetupNoExistingProfile =>
      'Wir haben kein bestehendes Profil auf deinen Relays gefunden. Beim Veröffentlichen wird ein neues Profil erstellt. Weitermachen?';

  @override
  String get profileSetupPublishButton => 'Veröffentlichen';

  @override
  String get profileSetupUsernameTaken =>
      'Der Benutzername wurde gerade vergeben. Bitte wähl einen anderen.';

  @override
  String get profileSetupClaimFailed =>
      'Benutzername konnte nicht reserviert werden. Bitte versuch es nochmal.';

  @override
  String get profileSetupPublishFailed =>
      'Profil konnte nicht veröffentlicht werden. Bitte versuch es nochmal.';

  @override
  String get profileSetupDisplayNameLabel => 'Anzeigename';

  @override
  String get profileSetupDisplayNameHint => 'Wie sollen dich die Leute kennen?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Beliebiger Name oder Label. Muss nicht einzigartig sein.';

  @override
  String get profileSetupDisplayNameRequired =>
      'Bitte gib einen Anzeigenamen ein';

  @override
  String get profileSetupBioLabel => 'Bio (optional)';

  @override
  String get profileSetupBioHint => 'Erzähl den Leuten etwas über dich...';

  @override
  String get profileSetupPublicKeyLabel => 'Public Key (npub)';

  @override
  String get profileSetupUsernameLabel => 'Benutzername (optional)';

  @override
  String get profileSetupUsernameHint => 'benutzername';

  @override
  String get profileSetupUsernameHelper =>
      'Deine einzigartige Identität auf Divine';

  @override
  String get profileSetupProfileColorLabel => 'Profilfarbe (optional)';

  @override
  String get profileSetupSaveButton => 'Speichern';

  @override
  String get profileSetupSavingButton => 'Wird gespeichert...';

  @override
  String get profileSetupImageUrlTitle => 'Bild-URL hinzufügen';

  @override
  String get profileSetupPictureUploaded =>
      'Profilbild erfolgreich hochgeladen!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Bildauswahl fehlgeschlagen. Bitte füg stattdessen eine Bild-URL unten ein.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Kamerazugriff fehlgeschlagen: $error';
  }

  @override
  String get profileSetupGotItButton => 'Verstanden';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Bild konnte nicht hochgeladen werden: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'Netzwerkfehler: Bitte prüf deine Internetverbindung und versuch es nochmal.';

  @override
  String get profileSetupUploadAuthError =>
      'Authentifizierungsfehler: Bitte melde dich ab und wieder an.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Datei zu groß: Bitte wähl ein kleineres Bild (max. 10MB).';

  @override
  String get profileSetupUsernameChecking => 'Verfügbarkeit wird geprüft...';

  @override
  String get profileSetupUsernameAvailable => 'Benutzername verfügbar!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Benutzername bereits vergeben';

  @override
  String get profileSetupUsernameReserved => 'Benutzername ist reserviert';

  @override
  String get profileSetupContactSupport => 'Support kontaktieren';

  @override
  String get profileSetupCheckAgain => 'Erneut prüfen';

  @override
  String get profileSetupUsernameBurned =>
      'Dieser Benutzername ist nicht mehr verfügbar';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Nur Buchstaben, Zahlen und Bindestriche sind erlaubt';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Benutzername muss 3-20 Zeichen lang sein';

  @override
  String get profileSetupUsernameNetworkError =>
      'Verfügbarkeit konnte nicht geprüft werden. Bitte versuch es nochmal.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Ungültiges Benutzernamen-Format';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Verfügbarkeit konnte nicht geprüft werden';

  @override
  String get profileSetupUsernameReservedTitle => 'Benutzername reserviert';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Der Name $username ist reserviert. Sag uns, warum er dir gehören sollte.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'z.B. Es ist mein Markenname, Künstlername usw.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Schon den Support kontaktiert? Tippe auf \"Erneut prüfen\", um zu sehen, ob er dir freigegeben wurde.';

  @override
  String get profileSetupSupportRequestSent =>
      'Support-Anfrage gesendet! Wir melden uns bald bei dir.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'E-Mail konnte nicht geöffnet werden. Sende an: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Anfrage senden';

  @override
  String get profileSetupPickColorTitle => 'Farbe wählen';

  @override
  String get profileSetupSelectButton => 'Auswählen';

  @override
  String get profileSetupUseOwnNip05 => 'Eigene NIP-05-Adresse verwenden';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05-Adresse';

  @override
  String get profileSetupProfilePicturePreview => 'Profilbild-Vorschau';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine basiert auf Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' einem zensurresistenten offenen Protokoll, das es Menschen ermöglicht, online zu kommunizieren, ohne von einem einzelnen Unternehmen oder einer Plattform abhängig zu sein. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Wenn du dich bei Divine anmeldest, bekommst du eine neue Nostr-Identität.';

  @override
  String get nostrInfoOwnership =>
      'Mit Nostr gehören dir deine Inhalte, deine Identität und dein soziales Netzwerk, die du in vielen Apps nutzen kannst. Das Ergebnis: mehr Auswahl, weniger Lock-in und ein gesünderes, widerstandsfähigeres soziales Internet.';

  @override
  String get nostrInfoLingo => 'Nostr-Vokabular:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Deine öffentliche Nostr-Adresse. Du kannst sie bedenkenlos teilen—damit finden dich andere, folgen dir oder schreiben dir in Nostr-Apps.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Dein privater Schlüssel und Eigentumsnachweis. Er gibt vollen Zugriff auf deine Nostr-Identität, also ';

  @override
  String get nostrInfoNsecWarning => 'halt ihn immer geheim!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr-Benutzername:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Ein lesbarer Name (wie @name.divine.video), der auf deinen npub verweist. Er macht deine Nostr-Identität leichter erkennbar und verifizierbar, ähnlich wie eine E-Mail-Adresse.';

  @override
  String get nostrInfoLearnMoreAt => 'Mehr erfahren auf ';

  @override
  String get nostrInfoGotIt => 'Verstanden!';

  @override
  String get profileTabRefreshTooltip => 'Aktualisieren';

  @override
  String get videoGridRefreshLabel => 'Suche nach weiteren Videos';

  @override
  String get videoGridOptionsTitle => 'Video-Optionen';

  @override
  String get videoGridEditVideo => 'Video bearbeiten';

  @override
  String get videoGridEditVideoSubtitle =>
      'Titel, Beschreibung und Hashtags aktualisieren';

  @override
  String get videoGridDeleteVideo => 'Video löschen';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Diesen Inhalt dauerhaft entfernen';

  @override
  String get videoGridDeleteConfirmTitle => 'Video löschen';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Bist du sicher, dass du dieses Video löschen willst?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Damit wird eine Löschanfrage (NIP-09) an alle Relays gesendet. Manche Relays behalten die Inhalte möglicherweise trotzdem.';

  @override
  String get videoGridDeleteCancel => 'Abbrechen';

  @override
  String get videoGridDeleteConfirm => 'Löschen';

  @override
  String get videoGridDeletingContent => 'Inhalt wird gelöscht...';

  @override
  String get videoGridDeleteSuccess => 'Löschanfrage erfolgreich gesendet';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Inhalt konnte nicht gelöscht werden: $error';
  }

  @override
  String get exploreTabClassics => 'Klassiker';

  @override
  String get exploreTabNew => 'Neu';

  @override
  String get exploreTabPopular => 'Beliebt';

  @override
  String get exploreTabCategories => 'Kategorien';

  @override
  String get exploreTabForYou => 'Für dich';

  @override
  String get exploreTabLists => 'Listen';

  @override
  String get exploreTabIntegratedApps => 'Integrierte Apps';

  @override
  String get exploreNoVideosAvailable => 'Keine Videos verfügbar';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Fehler: $error';
  }

  @override
  String get exploreDiscoverLists => 'Listen entdecken';

  @override
  String get exploreAboutLists => 'Über Listen';

  @override
  String get exploreAboutListsDescription =>
      'Listen helfen dir, Divine-Inhalte auf zwei Arten zu organisieren und zu kuratieren:';

  @override
  String get explorePeopleLists => 'Personen-Listen';

  @override
  String get explorePeopleListsDescription =>
      'Folge Gruppen von Creatorn und sieh ihre neuesten Videos';

  @override
  String get exploreVideoLists => 'Video-Listen';

  @override
  String get exploreVideoListsDescription =>
      'Erstelle Playlists deiner Lieblingsvideos, um sie später anzusehen';

  @override
  String get exploreMyLists => 'Meine Listen';

  @override
  String get exploreSubscribedLists => 'Abonnierte Listen';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Fehler beim Laden der Listen: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count neue Videos',
      one: '1 neues Video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: ' Videos',
      one: 's Video',
    );
    return '$count neue$_temp0 laden';
  }

  @override
  String get videoPlayerLoadingVideo => 'Video wird geladen...';

  @override
  String get videoPlayerPlayVideo => 'Video abspielen';

  @override
  String get videoPlayerEditVideo => 'Video bearbeiten';

  @override
  String get videoPlayerEditVideoTooltip => 'Video bearbeiten';

  @override
  String get contentWarningLabel => 'Inhaltswarnung';

  @override
  String get contentWarningNudity => 'Nacktheit';

  @override
  String get contentWarningSexualContent => 'Sexuelle Inhalte';

  @override
  String get contentWarningPornography => 'Pornografie';

  @override
  String get contentWarningGraphicMedia => 'Explizite Inhalte';

  @override
  String get contentWarningViolence => 'Gewalt';

  @override
  String get contentWarningSelfHarm => 'Selbstverletzung';

  @override
  String get contentWarningDrugUse => 'Drogenkonsum';

  @override
  String get contentWarningAlcohol => 'Alkohol';

  @override
  String get contentWarningTobacco => 'Tabak';

  @override
  String get contentWarningGambling => 'Glücksspiel';

  @override
  String get contentWarningProfanity => 'Vulgäre Sprache';

  @override
  String get contentWarningFlashingLights => 'Blinkende Lichter';

  @override
  String get contentWarningAiGenerated => 'KI-generiert';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Sensible Inhalte';

  @override
  String get contentWarningDescNudity => 'Enthält Nacktheit oder Teilnacktheit';

  @override
  String get contentWarningDescSexual => 'Enthält sexuelle Inhalte';

  @override
  String get contentWarningDescPorn =>
      'Enthält explizite pornografische Inhalte';

  @override
  String get contentWarningDescGraphicMedia =>
      'Enthält explizite oder verstörende Bilder';

  @override
  String get contentWarningDescViolence => 'Enthält gewalttätige Inhalte';

  @override
  String get contentWarningDescSelfHarm =>
      'Enthält Hinweise auf Selbstverletzung';

  @override
  String get contentWarningDescDrugs => 'Enthält drogenbezogene Inhalte';

  @override
  String get contentWarningDescAlcohol => 'Enthält alkoholbezogene Inhalte';

  @override
  String get contentWarningDescTobacco => 'Enthält tabakbezogene Inhalte';

  @override
  String get contentWarningDescGambling =>
      'Enthält glücksspielbezogene Inhalte';

  @override
  String get contentWarningDescProfanity => 'Enthält vulgäre Sprache';

  @override
  String get contentWarningDescFlashingLights =>
      'Enthält blinkende Lichter (Warnung bei Photosensibilität)';

  @override
  String get contentWarningDescAiGenerated =>
      'Dieser Inhalt wurde von KI generiert';

  @override
  String get contentWarningDescSpoiler => 'Enthält Spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Creator hat dies als sensibel markiert';

  @override
  String get contentWarningDescDefault =>
      'Creator hat diesen Inhalt gekennzeichnet';

  @override
  String get contentWarningDetailsTitle => 'Inhaltswarnungen';

  @override
  String get contentWarningDetailsSubtitle =>
      'Der Creator hat diese Labels gesetzt:';

  @override
  String get contentWarningManageFilters => 'Inhaltsfilter verwalten';

  @override
  String get contentWarningViewAnyway => 'Trotzdem ansehen';

  @override
  String get contentWarningHideAllLikeThis =>
      'Alle Inhalte wie diesen ausblenden';

  @override
  String get contentWarningNoFilterYet =>
      'Noch kein gespeicherter Filter für diese Warnung.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Wir blenden Beiträge wie diesen ab jetzt aus.';

  @override
  String get videoErrorNotFound => 'Video nicht gefunden';

  @override
  String get videoErrorNetwork => 'Netzwerkfehler';

  @override
  String get videoErrorTimeout => 'Zeitüberschreitung beim Laden';

  @override
  String get videoErrorFormat =>
      'Videoformat-Fehler\n(Versuch es nochmal oder mit einem anderen Browser)';

  @override
  String get videoErrorUnsupportedFormat => 'Nicht unterstütztes Videoformat';

  @override
  String get videoErrorPlayback => 'Video-Wiedergabefehler';

  @override
  String get videoErrorAgeRestricted => 'Altersbeschränkter Inhalt';

  @override
  String get videoErrorVerifyAge => 'Alter verifizieren';

  @override
  String get videoErrorRetry => 'Erneut versuchen';

  @override
  String get videoErrorContentRestricted => 'Inhalt eingeschränkt';

  @override
  String get videoErrorContentRestrictedBody =>
      'Dieses Video wurde vom Relay eingeschränkt.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifiziere dein Alter, um dieses Video zu sehen.';

  @override
  String get videoErrorSkip => 'Überspringen';

  @override
  String get videoErrorVerifyAgeButton => 'Alter verifizieren';

  @override
  String get videoFollowButtonFollowing => 'Gefolgt';

  @override
  String get videoFollowButtonFollow => 'Folgen';

  @override
  String get audioAttributionOriginalSound => 'Originalton';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspiriert von @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'mit @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'mit @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitwirkende',
      one: '1 Mitwirkender',
    );
    return '$_temp0. Tippe für das Profil.';
  }

  @override
  String get listAttributionFallback => 'Liste';

  @override
  String get shareVideoLabel => 'Video teilen';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Beitrag mit $recipientName geteilt';
  }

  @override
  String get shareFailedToSend => 'Video konnte nicht gesendet werden';

  @override
  String get shareAddedToBookmarks => 'Zu Lesezeichen hinzugefügt';

  @override
  String get shareFailedToAddBookmark =>
      'Lesezeichen konnte nicht hinzugefügt werden';

  @override
  String get shareActionFailed => 'Aktion fehlgeschlagen';

  @override
  String get shareWithTitle => 'Teilen mit';

  @override
  String get shareFindPeople => 'Leute finden';

  @override
  String get shareFindPeopleMultiline => 'Leute\nfinden';

  @override
  String get shareSent => 'Gesendet';

  @override
  String get shareContactFallback => 'Kontakt';

  @override
  String get shareUserFallback => 'Nutzer';

  @override
  String shareSendingTo(String name) {
    return 'Wird an $name gesendet';
  }

  @override
  String get shareMessageHint => 'Optionale Nachricht hinzufügen...';

  @override
  String get videoActionUnlike => 'Like entfernen';

  @override
  String get videoActionLike => 'Video liken';

  @override
  String get videoActionRemoveRepost => 'Repost entfernen';

  @override
  String get videoActionRepost => 'Video reposten';

  @override
  String get videoActionViewComments => 'Kommentare ansehen';

  @override
  String get videoActionMoreOptions => 'Weitere Optionen';

  @override
  String get videoActionHideSubtitles => 'Untertitel ausblenden';

  @override
  String get videoActionShowSubtitles => 'Untertitel anzeigen';

  @override
  String videoDescriptionLoops(String count) {
    return '$count Loops';
  }

  @override
  String get metadataBadgeNotDivine => 'Nicht Divine';

  @override
  String get metadataBadgeHumanMade => 'Von Menschenhand';

  @override
  String get metadataSoundsLabel => 'Sounds';

  @override
  String get metadataOriginalSound => 'Originalton';

  @override
  String get metadataVerificationLabel => 'Verifizierung';

  @override
  String get metadataDeviceAttestation => 'Geräteattestierung';

  @override
  String get metadataProofManifest => 'Proof-Manifest';

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Mitwirkende';

  @override
  String get metadataInspiredByLabel => 'Inspiriert von';

  @override
  String get metadataRepostedByLabel => 'Repostet von';

  @override
  String get metadataLoopsLabel => 'Loops';

  @override
  String get metadataLikesLabel => 'Likes';

  @override
  String get metadataCommentsLabel => 'Kommentare';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get devOptionsTitle => 'Entwickleroptionen';

  @override
  String get devOptionsPageLoadTimes => 'Seiten-Ladezeiten';

  @override
  String get devOptionsNoPageLoads =>
      'Noch keine Seitenladevorgänge aufgezeichnet.\nNavigiere durch die App, um Timing-Daten zu sehen.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Sichtbar: ${visibleMs}ms  |  Daten: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Langsamste Screens';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video-Wiedergabeformat';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Umgebung wechseln?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Zu $envName wechseln?\n\nDamit werden zwischengespeicherte Videodaten gelöscht und die Verbindung zum neuen Relay aufgebaut.';
  }

  @override
  String get devOptionsCancel => 'Abbrechen';

  @override
  String get devOptionsSwitch => 'Wechseln';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Zu $envName gewechselt';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Zu $formatName gewechselt — Cache geleert';
  }

  @override
  String get featureFlagTitle => 'Feature-Flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Alle Flags auf Standard zurücksetzen';

  @override
  String get featureFlagResetToDefault => 'Auf Standard zurücksetzen';

  @override
  String get featureFlagAppRecovery => 'App-Wiederherstellung';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Wenn die App abstürzt oder sich seltsam verhält, versuch den Cache zu leeren.';

  @override
  String get featureFlagClearAllCache => 'Gesamten Cache leeren';

  @override
  String get featureFlagCacheInfo => 'Cache-Info';

  @override
  String get featureFlagClearCacheTitle => 'Gesamten Cache leeren?';

  @override
  String get featureFlagClearCacheMessage =>
      'Damit werden alle zwischengespeicherten Daten gelöscht, einschließlich:\n• Benachrichtigungen\n• Nutzerprofile\n• Lesezeichen\n• Temporäre Dateien\n\nDu musst dich erneut anmelden. Weitermachen?';

  @override
  String get featureFlagClearCache => 'Cache leeren';

  @override
  String get featureFlagClearingCache => 'Cache wird geleert...';

  @override
  String get featureFlagSuccess => 'Erfolg';

  @override
  String get featureFlagError => 'Fehler';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache erfolgreich geleert. Bitte starte die App neu.';

  @override
  String get featureFlagClearCacheFailure =>
      'Einige Cache-Einträge konnten nicht geleert werden. Siehe Logs für Details.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Cache-Informationen';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Gesamte Cache-Größe: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cache umfasst:\n• Benachrichtigungsverlauf\n• Nutzerprofildaten\n• Video-Vorschaubilder\n• Temporäre Dateien\n• Datenbank-Indizes';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine ist ein offenes System - du kontrollierst deine Verbindungen';

  @override
  String get relaySettingsInfoDescription =>
      'Diese Relays verteilen deine Inhalte im dezentralen Nostr-Netzwerk. Du kannst Relays nach Belieben hinzufügen oder entfernen.';

  @override
  String get relaySettingsLearnMoreNostr => 'Mehr über Nostr erfahren →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Öffentliche Relays auf nostr.co.uk finden →';

  @override
  String get relaySettingsAppNotFunctional => 'App nicht funktionsfähig';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine benötigt mindestens ein Relay, um Videos zu laden, Inhalte zu posten und Daten zu synchronisieren.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Standard-Relay wiederherstellen';

  @override
  String get relaySettingsAddCustomRelay => 'Eigenes Relay hinzufügen';

  @override
  String get relaySettingsAddRelay => 'Relay hinzufügen';

  @override
  String get relaySettingsRetry => 'Erneut versuchen';

  @override
  String get relaySettingsNoStats => 'Noch keine Statistiken verfügbar';

  @override
  String get relaySettingsConnection => 'Verbindung';

  @override
  String get relaySettingsConnected => 'Verbunden';

  @override
  String get relaySettingsDisconnected => 'Getrennt';

  @override
  String get relaySettingsSessionDuration => 'Sitzungsdauer';

  @override
  String get relaySettingsLastConnected => 'Zuletzt verbunden';

  @override
  String get relaySettingsDisconnectedLabel => 'Getrennt';

  @override
  String get relaySettingsReason => 'Grund';

  @override
  String get relaySettingsActiveSubscriptions => 'Aktive Abonnements';

  @override
  String get relaySettingsTotalSubscriptions => 'Gesamtabonnements';

  @override
  String get relaySettingsEventsReceived => 'Empfangene Events';

  @override
  String get relaySettingsEventsSent => 'Gesendete Events';

  @override
  String get relaySettingsRequestsThisSession => 'Anfragen in dieser Sitzung';

  @override
  String get relaySettingsFailedRequests => 'Fehlgeschlagene Anfragen';

  @override
  String relaySettingsLastError(String error) {
    return 'Letzter Fehler: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Relay-Infos werden geladen...';

  @override
  String get relaySettingsAboutRelay => 'Über Relay';

  @override
  String get relaySettingsSupportedNips => 'Unterstützte NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Website ansehen';

  @override
  String get relaySettingsRemoveRelayTitle => 'Relay entfernen?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Bist du sicher, dass du dieses Relay entfernen willst?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Abbrechen';

  @override
  String get relaySettingsRemove => 'Entfernen';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay entfernt: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Relay konnte nicht entfernt werden';

  @override
  String get relaySettingsForcingReconnection =>
      'Relay-Verbindung wird erzwungen...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Mit $count Relay(s) verbunden!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Verbindung zu Relays fehlgeschlagen. Bitte prüf deine Netzwerkverbindung.';

  @override
  String get relaySettingsAddRelayTitle => 'Relay hinzufügen';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Gib die WebSocket-URL des Relays ein, das du hinzufügen willst:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Öffentliche Relays auf nostr.co.uk durchsuchen';

  @override
  String get relaySettingsAdd => 'Hinzufügen';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay hinzugefügt: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Relay konnte nicht hinzugefügt werden. Bitte prüf die URL und versuch es nochmal.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay-URL muss mit wss:// oder ws:// beginnen';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Standard-Relay wiederhergestellt: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Standard-Relay konnte nicht wiederhergestellt werden. Bitte prüf deine Netzwerkverbindung.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Browser konnte nicht geöffnet werden';

  @override
  String get relaySettingsFailedToOpenLink =>
      'Link konnte nicht geöffnet werden';

  @override
  String get relayDiagnosticTitle => 'Relay-Diagnose';

  @override
  String get relayDiagnosticRefreshTooltip => 'Diagnose aktualisieren';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Letzte Aktualisierung: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay-Status';

  @override
  String get relayDiagnosticInitialized => 'Initialisiert';

  @override
  String get relayDiagnosticReady => 'Bereit';

  @override
  String get relayDiagnosticNotInitialized => 'Nicht initialisiert';

  @override
  String get relayDiagnosticDatabaseEvents => 'Datenbank-Events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Aktive Abonnements';

  @override
  String get relayDiagnosticExternalRelays => 'Externe Relays';

  @override
  String get relayDiagnosticConfigured => 'Konfiguriert';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count Relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Verbunden';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video-Events';

  @override
  String get relayDiagnosticHomeFeed => 'Home-Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count Videos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Wird geladen';

  @override
  String get relayDiagnosticYes => 'Ja';

  @override
  String get relayDiagnosticNo => 'Nein';

  @override
  String get relayDiagnosticTestDirectQuery => 'Direkte Abfrage testen';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Netzwerkkonnektivität';

  @override
  String get relayDiagnosticRunNetworkTest => 'Netzwerktest starten';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom-Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Alle Endpoints testen';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Fehler';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake-API';

  @override
  String get relayDiagnosticBaseUrl => 'Basis-URL';

  @override
  String get relayDiagnosticSummary => 'Zusammenfassung';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (Durchschn. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Alle erneut testen';

  @override
  String get relayDiagnosticRetrying => 'Wird erneut versucht...';

  @override
  String get relayDiagnosticRetryConnection => 'Verbindung erneut versuchen';

  @override
  String get relayDiagnosticTroubleshooting => 'Fehlerbehebung';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Grüner Status = Verbunden und funktioniert\n• Roter Status = Verbindung fehlgeschlagen\n• Wenn der Netzwerktest fehlschlägt, prüf deine Internetverbindung\n• Wenn Relays konfiguriert, aber nicht verbunden sind, tippe auf \"Verbindung erneut versuchen\"\n• Mach einen Screenshot dieses Screens zum Debuggen';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Alle REST-Endpoints funktionieren!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Einige REST-Endpoints sind fehlgeschlagen - siehe Details oben';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '$count Video-Events in der Datenbank gefunden';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Abfrage fehlgeschlagen: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Mit $count Relay(s) verbunden!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Verbindung zu Relays fehlgeschlagen';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Verbindungsversuch fehlgeschlagen: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Verbunden & Authentifiziert';

  @override
  String get relayDiagnosticConnectedOnly => 'Verbunden';

  @override
  String get relayDiagnosticNotConnected => 'Nicht verbunden';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Keine Relays konfiguriert';

  @override
  String get relayDiagnosticFailed => 'Fehlgeschlagen';

  @override
  String get notificationSettingsTitle => 'Benachrichtigungen';

  @override
  String get notificationSettingsResetTooltip => 'Auf Standard zurücksetzen';

  @override
  String get notificationSettingsTypes => 'Benachrichtigungstypen';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Wenn jemand deine Videos likest';

  @override
  String get notificationSettingsComments => 'Kommentare';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Wenn jemand deine Videos kommentiert';

  @override
  String get notificationSettingsFollows => 'Follows';

  @override
  String get notificationSettingsFollowsSubtitle => 'Wenn dir jemand folgt';

  @override
  String get notificationSettingsMentions => 'Erwähnungen';

  @override
  String get notificationSettingsMentionsSubtitle => 'Wenn du erwähnt wirst';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Wenn jemand deine Videos repostet';

  @override
  String get notificationSettingsSystem => 'System';

  @override
  String get notificationSettingsSystemSubtitle =>
      'App-Updates und Systemnachrichten';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Push-Benachrichtigungen';

  @override
  String get notificationSettingsPushNotifications => 'Push-Benachrichtigungen';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Benachrichtigungen empfangen, wenn die App geschlossen ist';

  @override
  String get notificationSettingsSound => 'Ton';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Ton bei Benachrichtigungen abspielen';

  @override
  String get notificationSettingsVibration => 'Vibration';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Bei Benachrichtigungen vibrieren';

  @override
  String get notificationSettingsActions => 'Aktionen';

  @override
  String get notificationSettingsMarkAllAsRead => 'Alle als gelesen markieren';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Alle Benachrichtigungen als gelesen markieren';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Alle Benachrichtigungen als gelesen markiert';

  @override
  String get notificationSettingsResetToDefaults =>
      'Einstellungen auf Standard zurückgesetzt';

  @override
  String get notificationSettingsAbout => 'Über Benachrichtigungen';

  @override
  String get notificationSettingsAboutDescription =>
      'Benachrichtigungen werden über das Nostr-Protokoll bereitgestellt. Echtzeit-Updates hängen von deiner Verbindung zu den Nostr-Relays ab. Manche Benachrichtigungen können verzögert sein.';

  @override
  String get safetySettingsTitle => 'Sicherheit & Datenschutz';

  @override
  String get safetySettingsLabel => 'EINSTELLUNGEN';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Nur Divine-gehostete Videos anzeigen';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Videos von anderen Medien-Hosts ausblenden';

  @override
  String get safetySettingsModeration => 'MODERATION';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKIERTE NUTZER';

  @override
  String get safetySettingsAgeVerification => 'ALTERSVERIFIZIERUNG';

  @override
  String get safetySettingsAgeConfirmation =>
      'Ich bestätige, dass ich 18 Jahre oder älter bin';

  @override
  String get safetySettingsAgeRequired =>
      'Erforderlich, um Inhalte für Erwachsene zu sehen';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Offizieller Moderationsdienst (standardmäßig aktiv)';

  @override
  String get safetySettingsPeopleIFollow => 'Leute, denen ich folge';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Labels von Leuten abonnieren, denen du folgst';

  @override
  String get safetySettingsAddCustomLabeler => 'Eigenen Labeler hinzufügen';

  @override
  String get safetySettingsAddCustomLabelerHint => 'npub eingeben...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Eigenen Labeler hinzufügen';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'npub-Adresse eingeben';

  @override
  String get safetySettingsNoBlockedUsers => 'Keine blockierten Nutzer';

  @override
  String get safetySettingsUnblock => 'Entsperren';

  @override
  String get safetySettingsUserUnblocked => 'Nutzer entsperrt';

  @override
  String get safetySettingsCancel => 'Abbrechen';

  @override
  String get safetySettingsAdd => 'Hinzufügen';

  @override
  String get analyticsTitle => 'Creator-Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnose';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Diagnose umschalten';

  @override
  String get analyticsRetry => 'Erneut versuchen';

  @override
  String get analyticsUnableToLoad => 'Analytics konnten nicht geladen werden.';

  @override
  String get analyticsSignInRequired =>
      'Melde dich an, um Creator-Analytics zu sehen.';

  @override
  String get analyticsViewDataUnavailable =>
      'Aufrufe sind für diese Beiträge derzeit nicht vom Relay verfügbar. Like-, Kommentar- und Repost-Metriken sind trotzdem korrekt.';

  @override
  String get analyticsViewDataTitle => 'Aufrufdaten';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Aktualisiert $time • Scores nutzen Likes, Kommentare, Reposts und Aufrufe/Loops von Funnelcake, sofern verfügbar.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Aufrufe';

  @override
  String get analyticsInteractions => 'Interaktionen';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Follower';

  @override
  String get analyticsAvgPerPost => 'Ø/Beitrag';

  @override
  String get analyticsInteractionMix => 'Interaktions-Mix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Kommentare';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Performance-Highlights';

  @override
  String get analyticsMostViewed => 'Meistgesehen';

  @override
  String get analyticsMostDiscussed => 'Meistdiskutiert';

  @override
  String get analyticsMostReposted => 'Meistrepostet';

  @override
  String get analyticsNoVideosYet => 'Noch keine Videos';

  @override
  String get analyticsViewDataUnavailableShort => 'Aufrufdaten nicht verfügbar';

  @override
  String analyticsViewsCount(String count) {
    return '$count Aufrufe';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count Kommentare';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count Reposts';
  }

  @override
  String get analyticsTopContent => 'Top-Inhalte';

  @override
  String get analyticsPublishPrompt =>
      'Veröffentliche ein paar Videos, um Rankings zu sehen.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Rechts in % = Engagement-Rate (Interaktionen geteilt durch Aufrufe).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Die Engagement-Rate braucht Aufrufdaten; Werte erscheinen als N/V, bis Aufrufe verfügbar sind.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'Aufrufe nicht verfügbar';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count Interaktionen';
  }

  @override
  String get analyticsPostAnalytics => 'Beitrags-Analytics';

  @override
  String get analyticsOpenPost => 'Beitrag öffnen';

  @override
  String get analyticsRecentDailyInteractions =>
      'Tägliche Interaktionen der letzten Zeit';

  @override
  String get analyticsNoActivityYet =>
      'Noch keine Aktivität in diesem Zeitraum.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interaktionen = Likes + Kommentare + Reposts nach Beitragsdatum.';

  @override
  String get analyticsDailyBarExplainer =>
      'Balkenlänge ist relativ zu deinem besten Tag in diesem Zeitraum.';

  @override
  String get analyticsAudienceSnapshot => 'Publikums-Snapshot';

  @override
  String analyticsFollowersCount(String count) {
    return 'Follower: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Folgt: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Publikums-Aufschlüsselungen nach Quelle/Geo/Zeit werden verfügbar, sobald Funnelcake Publikums-Analytics-Endpoints hinzufügt.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retention-Kurve und Wiedergabezeit-Aufschlüsselung erscheinen, sobald Retention pro Sekunde/Bucket von Funnelcake verfügbar ist.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retention-Daten nicht verfügbar, bis Aufruf- und Wiedergabezeit-Analytics von Funnelcake zurückgegeben werden.';

  @override
  String get analyticsDiagnostics => 'Diagnose';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Videos insgesamt: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Mit Aufrufen: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Ohne Aufrufe: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydriert (Bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydriert (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Quellen: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Fixture-Daten verwenden';

  @override
  String get analyticsNa => 'N/V';

  @override
  String get authCreateNewAccount => 'Neues Divine-Konto erstellen';

  @override
  String get authSignInDifferentAccount => 'Mit anderem Konto anmelden';

  @override
  String get authSignBackIn => 'Wieder anmelden';

  @override
  String get authTermsPrefix =>
      'Indem du oben eine Option wählst, bestätigst du, dass du mindestens 16 Jahre alt bist und den ';

  @override
  String get authTermsOfService => 'Nutzungsbedingungen';

  @override
  String get authPrivacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get authTermsAnd => ', und ';

  @override
  String get authSafetyStandards => 'Sicherheitsstandards';

  @override
  String get authAmberNotInstalled => 'Amber-App ist nicht installiert';

  @override
  String get authAmberConnectionFailed => 'Verbindung zu Amber fehlgeschlagen';

  @override
  String get authPasswordResetSent =>
      'Wenn ein Konto mit dieser E-Mail existiert, wurde ein Link zum Passwort-Zurücksetzen gesendet.';

  @override
  String get authSignInTitle => 'Anmelden';

  @override
  String get authEmailLabel => 'E-Mail';

  @override
  String get authPasswordLabel => 'Passwort';

  @override
  String get authForgotPassword => 'Passwort vergessen?';

  @override
  String get authImportNostrKey => 'Nostr-Schlüssel importieren';

  @override
  String get authConnectSignerApp => 'Mit einer Signer-App verbinden';

  @override
  String get authSignInWithAmber => 'Mit Amber anmelden';

  @override
  String get authSignInOptionsTitle => 'Anmeldeoptionen';

  @override
  String get authInfoEmailPasswordTitle => 'E-Mail & Passwort';

  @override
  String get authInfoEmailPasswordDescription =>
      'Melde dich mit deinem Divine-Konto an. Wenn du dich mit einer E-Mail und einem Passwort registriert hast, nutze sie hier.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Du hast bereits eine Nostr-Identität? Importiere deinen nsec-Privatschlüssel von einem anderen Client.';

  @override
  String get authInfoSignerAppTitle => 'Signer-App';

  @override
  String get authInfoSignerAppDescription =>
      'Verbinde dich mit einem NIP-46-kompatiblen Remote-Signer wie nsecBunker für verbesserte Schlüsselsicherheit.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Nutze die Amber-Signer-App auf Android, um deine Nostr-Schlüssel sicher zu verwalten.';

  @override
  String get authCreateAccountTitle => 'Konto erstellen';

  @override
  String get authBackToInviteCode => 'Zurück zum Einladungscode';

  @override
  String get authUseDivineNoBackup => 'Divine ohne Backup verwenden';

  @override
  String get authSkipConfirmTitle => 'Noch eine Sache...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Du bist drin! Wir erstellen einen sicheren Schlüssel, der dein Divine-Konto antreibt.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Ohne E-Mail ist dein Schlüssel der einzige Weg, wie Divine weiß, dass dieses Konto dir gehört.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Du kannst in der App auf deinen Schlüssel zugreifen, aber wenn du nicht technisch versiert bist, empfehlen wir, jetzt eine E-Mail und ein Passwort hinzuzufügen. Damit ist es einfacher, dich anzumelden und dein Konto wiederherzustellen, wenn du dieses Gerät verlierst oder zurücksetzt.';

  @override
  String get authAddEmailPassword => 'E-Mail & Passwort hinzufügen';

  @override
  String get authUseThisDeviceOnly => 'Nur dieses Gerät verwenden';

  @override
  String get authCompleteRegistration => 'Registrierung abschließen';

  @override
  String get authVerifying => 'Wird verifiziert...';

  @override
  String get authVerificationLinkSent =>
      'Wir haben einen Verifizierungslink gesendet an:';

  @override
  String get authClickVerificationLink =>
      'Bitte klick auf den Link in deiner E-Mail, um\ndie Registrierung abzuschließen.';

  @override
  String get authPleaseWaitVerifying =>
      'Bitte warte, während wir deine E-Mail verifizieren...';

  @override
  String get authWaitingForVerification => 'Warten auf Verifizierung';

  @override
  String get authOpenEmailApp => 'E-Mail-App öffnen';

  @override
  String get authWelcomeToDivine => 'Willkommen bei Divine!';

  @override
  String get authEmailVerified => 'Deine E-Mail wurde verifiziert.';

  @override
  String get authSigningYouIn => 'Du wirst angemeldet';

  @override
  String get authErrorTitle => 'Hoppla.';

  @override
  String get authVerificationFailed =>
      'Wir konnten deine E-Mail nicht verifizieren.\nBitte versuch es nochmal.';

  @override
  String get authStartOver => 'Von vorne anfangen';

  @override
  String get authEmailVerifiedLogin =>
      'E-Mail verifiziert! Bitte melde dich an, um fortzufahren.';

  @override
  String get authVerificationLinkExpired =>
      'Dieser Verifizierungslink ist nicht mehr gültig.';

  @override
  String get authVerificationConnectionError =>
      'E-Mail konnte nicht verifiziert werden. Bitte prüf deine Verbindung und versuch es nochmal.';

  @override
  String get authWaitlistConfirmTitle => 'Du bist drin!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Wir schicken Updates an $email.\nSobald mehr Einladungscodes verfügbar sind, bekommst du welche.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Einladungszugang ist vorübergehend nicht verfügbar.';

  @override
  String get authInviteUnavailableBody =>
      'Versuch es gleich nochmal oder kontaktier den Support, wenn du Hilfe beim Reinkommen brauchst.';

  @override
  String get authTryAgain => 'Erneut versuchen';

  @override
  String get authContactSupport => 'Support kontaktieren';

  @override
  String authCouldNotOpenEmail(String email) {
    return '$email konnte nicht geöffnet werden';
  }

  @override
  String get authAddInviteCode => 'Einladungscode hinzufügen';

  @override
  String get authInviteCodeLabel => 'Einladungscode';

  @override
  String get authEnterYourCode => 'Gib deinen Code ein';

  @override
  String get authNext => 'Weiter';

  @override
  String get authJoinWaitlist => 'Auf Warteliste';

  @override
  String get authJoinWaitlistTitle => 'Auf die Warteliste';

  @override
  String get authJoinWaitlistDescription =>
      'Teile deine E-Mail und wir schicken Updates, sobald Zugang frei wird.';

  @override
  String get authInviteAccessHelp => 'Hilfe zum Einladungszugang';

  @override
  String get authGeneratingConnection => 'Verbindung wird erstellt...';

  @override
  String get authConnectedAuthenticating =>
      'Verbunden! Authentifizierung läuft...';

  @override
  String get authConnectionTimedOut => 'Verbindung abgelaufen';

  @override
  String get authApproveConnection =>
      'Stell sicher, dass du die Verbindung in deiner Signer-App bestätigt hast.';

  @override
  String get authConnectionCancelled => 'Verbindung abgebrochen';

  @override
  String get authConnectionCancelledMessage =>
      'Die Verbindung wurde abgebrochen.';

  @override
  String get authConnectionFailed => 'Verbindung fehlgeschlagen';

  @override
  String get authUnknownError => 'Ein unbekannter Fehler ist aufgetreten.';

  @override
  String get authUrlCopied => 'URL in die Zwischenablage kopiert';

  @override
  String get authConnectToDivine => 'Mit Divine verbinden';

  @override
  String get authPasteBunkerUrl => 'bunker://-URL einfügen';

  @override
  String get authBunkerUrlHint => 'bunker://-URL';

  @override
  String get authInvalidBunkerUrl =>
      'Ungültige Bunker-URL. Sie sollte mit bunker:// beginnen';

  @override
  String get authScanSignerApp =>
      'Scanne mit deiner\nSigner-App, um zu verbinden.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Warte auf Verbindung... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'URL kopieren';

  @override
  String get authShare => 'Teilen';

  @override
  String get authAddBunker => 'Bunker hinzufügen';

  @override
  String get authCompatibleSignerApps => 'Kompatible Signer-Apps';

  @override
  String get authFailedToConnect => 'Verbindung fehlgeschlagen';

  @override
  String get authResetPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get authResetPasswordSubtitle =>
      'Bitte gib dein neues Passwort ein. Es muss mindestens 8 Zeichen lang sein.';

  @override
  String get authNewPasswordLabel => 'Neues Passwort';

  @override
  String get authPasswordTooShort =>
      'Passwort muss mindestens 8 Zeichen lang sein';

  @override
  String get authPasswordResetSuccess =>
      'Passwort erfolgreich zurückgesetzt. Bitte melde dich an.';

  @override
  String get authPasswordResetFailed => 'Passwort-Zurücksetzen fehlgeschlagen';

  @override
  String get authUnexpectedError =>
      'Ein unerwarteter Fehler ist aufgetreten. Bitte versuch es nochmal.';

  @override
  String get authUpdatePassword => 'Passwort aktualisieren';

  @override
  String get authSecureAccountTitle => 'Konto absichern';

  @override
  String get authUnableToAccessKeys =>
      'Zugriff auf deine Schlüssel nicht möglich. Bitte versuch es nochmal.';

  @override
  String get authRegistrationFailed => 'Registrierung fehlgeschlagen';

  @override
  String get authRegistrationComplete =>
      'Registrierung abgeschlossen. Bitte prüf deine E-Mails.';

  @override
  String get authVerificationFailedTitle => 'Verifizierung fehlgeschlagen';

  @override
  String get authClose => 'Schließen';

  @override
  String get authAccountSecured => 'Konto abgesichert!';

  @override
  String get authAccountLinkedToEmail =>
      'Dein Konto ist jetzt mit deiner E-Mail verknüpft.';

  @override
  String get authVerifyYourEmail => 'E-Mail verifizieren';

  @override
  String get authClickLinkContinue =>
      'Klick auf den Link in deiner E-Mail, um die Registrierung abzuschließen. Du kannst die App in der Zwischenzeit weiter nutzen.';

  @override
  String get authWaitingForVerificationEllipsis => 'Warte auf Verifizierung...';

  @override
  String get authContinueToApp => 'Weiter zur App';

  @override
  String get authResetPassword => 'Passwort zurücksetzen';

  @override
  String get authResetPasswordDescription =>
      'Gib deine E-Mail-Adresse ein, und wir schicken dir einen Link zum Passwort-Zurücksetzen.';

  @override
  String get authFailedToSendResetEmail =>
      'Reset-E-Mail konnte nicht gesendet werden.';

  @override
  String get authUnexpectedErrorShort =>
      'Ein unerwarteter Fehler ist aufgetreten.';

  @override
  String get authSending => 'Wird gesendet...';

  @override
  String get authSendResetLink => 'Reset-Link senden';

  @override
  String get authEmailSent => 'E-Mail gesendet!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Wir haben einen Link zum Passwort-Zurücksetzen an $email gesendet. Bitte klick auf den Link in deiner E-Mail, um dein Passwort zu aktualisieren.';
  }

  @override
  String get authSignInButton => 'Anmelden';

  @override
  String get authVerificationErrorTimeout =>
      'Verifizierung abgelaufen. Bitte registriere dich erneut.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifizierung fehlgeschlagen — Autorisierungscode fehlt.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verifizierung fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Netzwerkfehler bei der Anmeldung. Bitte versuch es nochmal.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifizierung fehlgeschlagen. Bitte registriere dich erneut.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuch es mit einer manuellen Anmeldung.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Dieser Einladungscode ist nicht mehr verfügbar. Geh zurück zu deinem Einladungscode, tritt der Warteliste bei oder kontaktier den Support.';

  @override
  String get authInviteErrorInvalid =>
      'Dieser Einladungscode kann derzeit nicht verwendet werden. Geh zurück zu deinem Einladungscode, tritt der Warteliste bei oder kontaktier den Support.';

  @override
  String get authInviteErrorTemporary =>
      'Wir konnten deine Einladung gerade nicht bestätigen. Geh zurück zu deinem Einladungscode und versuch es nochmal oder kontaktier den Support.';

  @override
  String get authInviteErrorUnknown =>
      'Wir konnten deine Einladung nicht aktivieren. Geh zurück zu deinem Einladungscode, tritt der Warteliste bei oder kontaktier den Support.';

  @override
  String get shareSheetSave => 'Speichern';

  @override
  String get shareSheetSaveToGallery => 'In Galerie speichern';

  @override
  String get shareSheetSaveWithWatermark => 'Mit Wasserzeichen speichern';

  @override
  String get shareSheetSaveVideo => 'Video speichern';

  @override
  String get shareSheetAddToList => 'Zur Liste hinzufügen';

  @override
  String get shareSheetCopy => 'Kopieren';

  @override
  String get shareSheetShareVia => 'Teilen via';

  @override
  String get shareSheetReport => 'Melden';

  @override
  String get shareSheetEventJson => 'Event-JSON';

  @override
  String get shareSheetEventId => 'Event-ID';

  @override
  String get shareSheetMoreActions => 'Weitere Aktionen';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'In Aufnahmen gespeichert';

  @override
  String get watermarkDownloadShare => 'Teilen';

  @override
  String get watermarkDownloadDone => 'Fertig';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Fotozugriff erforderlich';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Um Videos zu speichern, erlaube den Fotozugriff in den Einstellungen.';

  @override
  String get watermarkDownloadOpenSettings => 'Einstellungen öffnen';

  @override
  String get watermarkDownloadNotNow => 'Nicht jetzt';

  @override
  String get watermarkDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get watermarkDownloadDismiss => 'Schließen';

  @override
  String get watermarkDownloadStageDownloading => 'Video wird heruntergeladen';

  @override
  String get watermarkDownloadStageWatermarking =>
      'Wasserzeichen wird hinzugefügt';

  @override
  String get watermarkDownloadStageSaving => 'Speichern in Aufnahmen';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Video wird aus dem Netzwerk geladen...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Divine-Wasserzeichen wird angewendet...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Video mit Wasserzeichen wird in deinen Aufnahmen gespeichert...';

  @override
  String get uploadProgressVideoUpload => 'Video-Upload';

  @override
  String get uploadProgressPause => 'Pausieren';

  @override
  String get uploadProgressResume => 'Fortsetzen';

  @override
  String get uploadProgressGoBack => 'Zurück';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Erneut versuchen (noch $count)';
  }

  @override
  String get uploadProgressDelete => 'Löschen';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'vor ${count}T';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'vor ${count}Std';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'vor ${count}Min';
  }

  @override
  String get uploadProgressJustNow => 'Gerade eben';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Lädt hoch $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Pausiert bei $percent%';
  }

  @override
  String get badgeExplanationClose => 'Schließen';

  @override
  String get badgeExplanationOriginalVineArchive => 'Original-Vine-Archiv';

  @override
  String get badgeExplanationCameraProof => 'Kamera-Nachweis';

  @override
  String get badgeExplanationAuthenticitySignals => 'Authentizitätssignale';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Dieses Video ist ein Original-Vine, das aus dem Internet Archive wiederhergestellt wurde.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Bevor Vine 2017 abgeschaltet wurde, haben ArchiveTeam und das Internet Archive daran gearbeitet, Millionen von Vines für die Nachwelt zu bewahren. Dieser Inhalt ist Teil dieses historischen Bewahrungsprojekts.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Originalstatistik: $loops Loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Mehr über die Bewahrung des Vine-Archivs erfahren';

  @override
  String get badgeExplanationLearnProofmode =>
      'Mehr über Proofmode-Verifizierung erfahren';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Mehr über Divine-Authentizitätssignale erfahren';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Mit ProofCheck-Tool inspizieren';

  @override
  String get badgeExplanationInspectMedia => 'Mediendetails inspizieren';

  @override
  String get badgeExplanationProofmodeVerified =>
      'Die Authentizität dieses Videos wird mit Proofmode-Technologie verifiziert.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Dieses Video wird auf Divine gehostet, und die KI-Erkennung deutet darauf hin, dass es wahrscheinlich von Menschen gemacht wurde, aber es enthält keine kryptografischen Kamera-Verifizierungsdaten.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Die KI-Erkennung deutet darauf hin, dass dieses Video wahrscheinlich von Menschen gemacht wurde, auch wenn es keine kryptografischen Kamera-Verifizierungsdaten enthält.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Dieses Video wird auf Divine gehostet, enthält aber noch keine kryptografischen Kamera-Verifizierungsdaten.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Dieses Video wird außerhalb von Divine gehostet und enthält keine kryptografischen Kamera-Verifizierungsdaten.';

  @override
  String get badgeExplanationDeviceAttestation => 'Geräteattestierung';

  @override
  String get badgeExplanationPgpSignature => 'PGP-Signatur';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Proof-Manifest';

  @override
  String get badgeExplanationAiDetection => 'KI-Erkennung';

  @override
  String get badgeExplanationAiNotScanned => 'KI-Scan: Noch nicht gescannt';

  @override
  String get badgeExplanationNoScanResults =>
      'Noch keine Scan-Ergebnisse verfügbar.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Auf KI-Generierung prüfen';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% Wahrscheinlichkeit, KI-generiert zu sein';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Gescannt von: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Von menschlichem Moderator verifiziert';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platin: Geräte-Hardware-Attestierung, kryptografische Signaturen, Content Credentials (C2PA) und KI-Scan bestätigt menschlichen Ursprung.';

  @override
  String get badgeExplanationVerificationGold =>
      'Gold: Auf einem echten Gerät mit Hardware-Attestierung, kryptografischen Signaturen und Content Credentials (C2PA) aufgenommen.';

  @override
  String get badgeExplanationVerificationSilver =>
      'Silber: Kryptografische Signaturen beweisen, dass dieses Video seit der Aufnahme nicht verändert wurde.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze: Grundlegende Metadaten-Signaturen vorhanden.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Silber: KI-Scan bestätigt, dass dieses Video wahrscheinlich von Menschen erstellt wurde.';

  @override
  String get badgeExplanationNoVerification =>
      'Keine Verifizierungsdaten für dieses Video verfügbar.';

  @override
  String get shareMenuTitle => 'Video teilen';

  @override
  String get shareMenuReportAiContent => 'KI-Inhalt melden';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Schnell vermuteten KI-generierten Inhalt melden';

  @override
  String get shareMenuReportingAiContent => 'KI-Inhalt wird gemeldet...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Inhalt konnte nicht gemeldet werden: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'KI-Inhalt konnte nicht gemeldet werden: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Video-Status';

  @override
  String get shareMenuViewAllLists => 'Alle Listen anzeigen →';

  @override
  String get shareMenuShareWith => 'Teilen mit';

  @override
  String get shareMenuShareViaOtherApps => 'Über andere Apps teilen';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Über andere Apps teilen oder Link kopieren';

  @override
  String get shareMenuSaveToGallery => 'In Galerie speichern';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Original-Video in Aufnahmen speichern';

  @override
  String get shareMenuSaveWithWatermark => 'Mit Wasserzeichen speichern';

  @override
  String get shareMenuSaveVideo => 'Video speichern';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Mit Divine-Wasserzeichen herunterladen';

  @override
  String get shareMenuSaveVideoSubtitle => 'Video in Aufnahmen speichern';

  @override
  String get shareMenuLists => 'Listen';

  @override
  String get shareMenuAddToList => 'Zur Liste hinzufügen';

  @override
  String get shareMenuAddToListSubtitle =>
      'Zu deinen kuratierten Listen hinzufügen';

  @override
  String get shareMenuCreateNewList => 'Neue Liste erstellen';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Eine neue kuratierte Sammlung starten';

  @override
  String get shareMenuRemovedFromList => 'Aus Liste entfernt';

  @override
  String get shareMenuFailedToRemoveFromList =>
      'Entfernen aus Liste fehlgeschlagen';

  @override
  String get shareMenuBookmarks => 'Lesezeichen';

  @override
  String get shareMenuAddToBookmarks => 'Zu Lesezeichen hinzufügen';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Für später speichern';

  @override
  String get shareMenuAddToBookmarkSet => 'Zu Lesezeichen-Set hinzufügen';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'In Sammlungen organisieren';

  @override
  String get shareMenuFollowSets => 'Follow-Sets';

  @override
  String get shareMenuCreateFollowSet => 'Follow-Set erstellen';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Neue Sammlung mit diesem Creator starten';

  @override
  String get shareMenuAddToFollowSet => 'Zu Follow-Set hinzufügen';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count Follow-Sets verfügbar';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Zu Lesezeichen hinzugefügt!';

  @override
  String get shareMenuFailedToAddBookmark =>
      'Lesezeichen konnte nicht hinzugefügt werden';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Liste \"$name\" erstellt und Video hinzugefügt';
  }

  @override
  String get shareMenuManageContent => 'Inhalt verwalten';

  @override
  String get shareMenuEditVideo => 'Video bearbeiten';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Titel, Beschreibung und Hashtags aktualisieren';

  @override
  String get shareMenuDeleteVideo => 'Video löschen';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Diesen Inhalt dauerhaft entfernen';

  @override
  String get shareMenuVideoInTheseLists => 'Video ist in diesen Listen:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count Videos';
  }

  @override
  String get shareMenuClose => 'Schließen';

  @override
  String get shareMenuDeleteConfirmation =>
      'Bist du sicher, dass du dieses Video löschen willst?';

  @override
  String get shareMenuDeleteWarning =>
      'Damit wird eine Löschanfrage (NIP-09) an alle Relays gesendet. Manche Relays behalten die Inhalte möglicherweise trotzdem.';

  @override
  String get shareMenuCancel => 'Abbrechen';

  @override
  String get shareMenuDelete => 'Löschen';

  @override
  String get shareMenuDeletingContent => 'Inhalt wird gelöscht...';

  @override
  String get shareMenuDeleteRequestSent => 'Löschanfrage erfolgreich gesendet';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Inhalt konnte nicht gelöscht werden: $error';
  }

  @override
  String get shareMenuFollowSetName => 'Follow-Set-Name';

  @override
  String get shareMenuFollowSetNameHint => 'z.B. Content-Creator, Musiker usw.';

  @override
  String get shareMenuDescriptionOptional => 'Beschreibung (optional)';

  @override
  String get shareMenuCreate => 'Erstellen';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Follow-Set \"$name\" erstellt und Creator hinzugefügt';
  }

  @override
  String get shareMenuDone => 'Fertig';

  @override
  String get shareMenuEditTitle => 'Titel';

  @override
  String get shareMenuEditTitleHint => 'Videotitel eingeben';

  @override
  String get shareMenuEditDescription => 'Beschreibung';

  @override
  String get shareMenuEditDescriptionHint => 'Videobeschreibung eingeben';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'komma, getrennte, hashtags';

  @override
  String get shareMenuEditMetadataNote =>
      'Hinweis: Nur Metadaten können bearbeitet werden. Video-Inhalte können nicht geändert werden.';

  @override
  String get shareMenuDeleting => 'Wird gelöscht...';

  @override
  String get shareMenuUpdate => 'Aktualisieren';

  @override
  String get shareMenuVideoUpdated => 'Video erfolgreich aktualisiert';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Video konnte nicht aktualisiert werden: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Video löschen?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Damit wird eine Löschanfrage an die Relays gesendet. Hinweis: Manche Relays haben möglicherweise noch zwischengespeicherte Kopien.';

  @override
  String get shareMenuVideoDeletionRequested => 'Video-Löschung angefordert';

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Video konnte nicht gelöscht werden: $error';
  }

  @override
  String get shareMenuContentLabels => 'Inhalts-Labels';

  @override
  String get shareMenuAddContentLabels => 'Inhalts-Labels hinzufügen';

  @override
  String get shareMenuClearAll => 'Alles löschen';

  @override
  String get shareMenuCollaborators => 'Mitwirkende';

  @override
  String get shareMenuAddCollaborator => 'Mitwirkenden hinzufügen';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Du musst $name gegenseitig folgen, um sie/ihn als Mitwirkenden hinzuzufügen.';
  }

  @override
  String get shareMenuLoading => 'Wird geladen...';

  @override
  String get shareMenuInspiredBy => 'Inspiriert von';

  @override
  String get shareMenuAddInspirationCredit => 'Inspirationsangabe hinzufügen';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Dieser Creator kann nicht referenziert werden.';

  @override
  String get shareMenuUnknown => 'Unbekannt';

  @override
  String get shareMenuCreateBookmarkSet => 'Lesezeichen-Set erstellen';

  @override
  String get shareMenuSetName => 'Set-Name';

  @override
  String get shareMenuSetNameHint => 'z.B. Favoriten, Später ansehen usw.';

  @override
  String get shareMenuCreateNewSet => 'Neues Set erstellen';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Eine neue Lesezeichen-Sammlung starten';

  @override
  String get shareMenuNoBookmarkSets =>
      'Noch keine Lesezeichen-Sets. Erstelle dein erstes!';

  @override
  String get shareMenuError => 'Fehler';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Lesezeichen-Sets konnten nicht geladen werden';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\" erstellt und Video hinzugefügt';
  }

  @override
  String get shareMenuUseThisSound => 'Diesen Sound verwenden';

  @override
  String get shareMenuOriginalSound => 'Originalton';

  @override
  String get authSessionExpired =>
      'Deine Sitzung ist abgelaufen. Bitte melde dich erneut an.';

  @override
  String get authSignInFailed =>
      'Anmeldung fehlgeschlagen. Bitte versuch es nochmal.';

  @override
  String get localeAppLanguage => 'App-Sprache';

  @override
  String get localeDeviceDefault => 'Gerätestandard';

  @override
  String get localeSelectLanguage => 'Sprache wählen';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web-Authentifizierung wird im sicheren Modus nicht unterstützt. Bitte nutze die mobile App für sichere Schlüsselverwaltung.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Authentifizierungs-Integration fehlgeschlagen: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Unerwarteter Fehler: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Bitte gib eine Bunker-URI ein';

  @override
  String get webAuthConnectTitle => 'Mit Divine verbinden';

  @override
  String get webAuthChooseMethod =>
      'Wähle deine bevorzugte Nostr-Authentifizierungsmethode';

  @override
  String get webAuthBrowserExtension => 'Browser-Erweiterung';

  @override
  String get webAuthRecommended => 'EMPFOHLEN';

  @override
  String get webAuthNsecBunker => 'nsec-Bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Mit einem Remote-Signer verbinden';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Aus Zwischenablage einfügen';

  @override
  String get webAuthConnectToBunker => 'Mit Bunker verbinden';

  @override
  String get webAuthNewToNostr => 'Neu bei Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installiere eine Browser-Erweiterung wie Alby oder nos2x für das einfachste Erlebnis oder nutze nsec-Bunker für sicheres Remote-Signing.';

  @override
  String get soundsTitle => 'Sounds';

  @override
  String get soundsSearchHint => 'Sounds suchen...';

  @override
  String get soundsPreviewUnavailable =>
      'Vorschau nicht möglich — kein Audio verfügbar';

  @override
  String soundsPreviewFailed(String error) {
    return 'Vorschau-Wiedergabe fehlgeschlagen: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Featured Sounds';

  @override
  String get soundsTrendingSounds => 'Trending Sounds';

  @override
  String get soundsAllSounds => 'Alle Sounds';

  @override
  String get soundsSearchResults => 'Suchergebnisse';

  @override
  String get soundsNoSoundsAvailable => 'Keine Sounds verfügbar';

  @override
  String get soundsNoSoundsDescription =>
      'Sounds erscheinen hier, wenn Creator Audio teilen';

  @override
  String get soundsNoSoundsFound => 'Keine Sounds gefunden';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Versuch einen anderen Suchbegriff';

  @override
  String get soundsFailedToLoad => 'Sounds konnten nicht geladen werden';

  @override
  String get soundsRetry => 'Erneut versuchen';

  @override
  String get soundsScreenLabel => 'Sounds-Screen';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Aktualisieren';

  @override
  String get profileRefreshLabel => 'Profil aktualisieren';

  @override
  String get profileMoreOptions => 'Weitere Optionen';

  @override
  String profileBlockedUser(String name) {
    return '$name blockiert';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name entsperrt';
  }

  @override
  String profileUnfollowedUser(String name) {
    return '$name entfolgt';
  }

  @override
  String profileError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get notificationsTabAll => 'Alle';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Kommentare';

  @override
  String get notificationsTabFollows => 'Follows';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad =>
      'Benachrichtigungen konnten nicht geladen werden';

  @override
  String get notificationsRetry => 'Erneut versuchen';

  @override
  String get notificationsCheckingNew => 'Suche nach neuen Benachrichtigungen';

  @override
  String get notificationsNoneYet => 'Noch keine Benachrichtigungen';

  @override
  String notificationsNoneForType(String type) {
    return 'Keine $type-Benachrichtigungen';
  }

  @override
  String get notificationsEmptyDescription =>
      'Wenn Leute mit deinen Inhalten interagieren, siehst du es hier';

  @override
  String notificationsLoadingType(String type) {
    return '$type-Benachrichtigungen werden geladen...';
  }

  @override
  String get notificationsInviteSingular =>
      'Du hast 1 Einladung, die du mit einem Freund teilen kannst!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Du hast $count Einladungen, die du mit Freunden teilen kannst!';
  }

  @override
  String get notificationsVideoNotFound => 'Video nicht gefunden';

  @override
  String get notificationsVideoUnavailable => 'Video nicht verfügbar';

  @override
  String get notificationsFromNotification => 'Aus Benachrichtigung';

  @override
  String get feedFailedToLoadVideos => 'Videos konnten nicht geladen werden';

  @override
  String get feedRetry => 'Erneut versuchen';

  @override
  String get feedNoFollowedUsers =>
      'Keine abonnierten Nutzer.\nFolge jemandem, um hier seine Videos zu sehen.';

  @override
  String get feedForYouEmpty =>
      'Your For You feed is empty.\nExplore videos and follow creators to shape it.';

  @override
  String get feedFollowingEmpty =>
      'No videos from people you follow yet.\nFind creators you like and follow them.';

  @override
  String get feedLatestEmpty => 'No new videos yet.\nCheck back soon.';

  @override
  String get feedExploreVideos => 'Videos entdecken';

  @override
  String get feedExternalVideoSlow => 'Externes Video lädt langsam';

  @override
  String get feedSkip => 'Überspringen';

  @override
  String get uploadWaitingToUpload => 'Warten auf Upload';

  @override
  String get uploadUploadingVideo => 'Video wird hochgeladen';

  @override
  String get uploadProcessingVideo => 'Video wird verarbeitet';

  @override
  String get uploadProcessingComplete => 'Verarbeitung abgeschlossen';

  @override
  String get uploadPublishedSuccessfully => 'Erfolgreich veröffentlicht';

  @override
  String get uploadFailed => 'Upload fehlgeschlagen';

  @override
  String get uploadRetrying => 'Upload wird erneut versucht';

  @override
  String get uploadPaused => 'Upload pausiert';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% abgeschlossen';
  }

  @override
  String get uploadQueuedMessage =>
      'Dein Video steht in der Upload-Warteschlange';

  @override
  String get uploadUploadingMessage => 'Wird zum Server hochgeladen...';

  @override
  String get uploadProcessingMessage =>
      'Video wird verarbeitet — das kann ein paar Minuten dauern';

  @override
  String get uploadReadyToPublishMessage =>
      'Video erfolgreich verarbeitet und bereit zur Veröffentlichung';

  @override
  String get uploadPublishedMessage => 'Video in deinem Profil veröffentlicht';

  @override
  String get uploadFailedMessage =>
      'Upload fehlgeschlagen — bitte versuch es nochmal';

  @override
  String get uploadRetryingMessage => 'Upload wird erneut versucht...';

  @override
  String get uploadPausedMessage => 'Upload vom Nutzer pausiert';

  @override
  String get uploadRetryButton => 'ERNEUT VERSUCHEN';

  @override
  String uploadRetryFailed(String error) {
    return 'Upload-Wiederholung fehlgeschlagen: $error';
  }

  @override
  String get userSearchPrompt => 'Nach Nutzern suchen';

  @override
  String get userSearchNoResults => 'Keine Nutzer gefunden';

  @override
  String get userSearchFailed => 'Suche fehlgeschlagen';

  @override
  String get forgotPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get forgotPasswordDescription =>
      'Gib deine E-Mail-Adresse ein, und wir schicken dir einen Link zum Passwort-Zurücksetzen.';

  @override
  String get forgotPasswordEmailLabel => 'E-Mail-Adresse';

  @override
  String get forgotPasswordCancel => 'Abbrechen';

  @override
  String get forgotPasswordSendLink => 'Reset-Link per E-Mail senden';

  @override
  String get ageVerificationContentWarning => 'Inhaltswarnung';

  @override
  String get ageVerificationTitle => 'Altersverifizierung';

  @override
  String get ageVerificationAdultDescription =>
      'Dieser Inhalt wurde als potenziell für Erwachsene markiert. Du musst 18 Jahre oder älter sein, um ihn zu sehen.';

  @override
  String get ageVerificationCreationDescription =>
      'Um die Kamera zu nutzen und Inhalte zu erstellen, musst du mindestens 16 Jahre alt sein.';

  @override
  String get ageVerificationAdultQuestion => 'Bist du 18 Jahre oder älter?';

  @override
  String get ageVerificationCreationQuestion => 'Bist du 16 Jahre oder älter?';

  @override
  String get ageVerificationNo => 'Nein';

  @override
  String get ageVerificationYes => 'Ja';

  @override
  String get shareLinkCopied => 'Link in die Zwischenablage kopiert';

  @override
  String get shareFailedToCopy => 'Link konnte nicht kopiert werden';

  @override
  String get shareVideoSubject => 'Schau dir dieses Video auf Divine an';

  @override
  String get shareFailedToShare => 'Teilen fehlgeschlagen';

  @override
  String get shareVideoTitle => 'Video teilen';

  @override
  String get shareToApps => 'An Apps teilen';

  @override
  String get shareToAppsSubtitle => 'Über Messaging- und Social-Apps teilen';

  @override
  String get shareCopyWebLink => 'Web-Link kopieren';

  @override
  String get shareCopyWebLinkSubtitle => 'Teilbaren Web-Link kopieren';

  @override
  String get shareCopyNostrLink => 'Nostr-Link kopieren';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'nevent-Link für Nostr-Clients kopieren';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Entdecken';

  @override
  String get navInbox => 'Posteingang';

  @override
  String get navProfile => 'Profil';

  @override
  String get navMyProfile => 'Mein Profil';

  @override
  String get navSearch => 'Suche';

  @override
  String get navNotifications => 'Benachrichtigungen';

  @override
  String get navSearchTooltip => 'Suche';

  @override
  String get navOpenCamera => 'Kamera öffnen';

  @override
  String get navUnknown => 'Unbekannt';

  @override
  String get navExploreClassics => 'Klassiker';

  @override
  String get navExploreNewVideos => 'Neue Videos';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'Für dich';

  @override
  String get navExploreLists => 'Listen';

  @override
  String get routeErrorTitle => 'Fehler';

  @override
  String get routeInvalidHashtag => 'Ungültiger Hashtag';

  @override
  String get routeInvalidConversationId => 'Ungültige Konversations-ID';

  @override
  String get routeInvalidRequestId => 'Ungültige Anfrage-ID';

  @override
  String get routeInvalidListId => 'Ungültige Listen-ID';

  @override
  String get routeInvalidUserId => 'Ungültige Nutzer-ID';

  @override
  String get routeInvalidVideoId => 'Ungültige Video-ID';

  @override
  String get routeInvalidSoundId => 'Ungültige Sound-ID';

  @override
  String get routeInvalidCategory => 'Ungültige Kategorie';

  @override
  String get routeNoVideosToDisplay => 'Keine Videos zum Anzeigen';

  @override
  String get routeInvalidProfileId => 'Ungültige Profil-ID';

  @override
  String get routeDefaultListName => 'Liste';

  @override
  String get supportTitle => 'Support-Center';

  @override
  String get supportContactSupport => 'Support kontaktieren';

  @override
  String get supportContactSupportSubtitle =>
      'Konversation starten oder vergangene Nachrichten ansehen';

  @override
  String get supportReportBug => 'Bug melden';

  @override
  String get supportReportBugSubtitle => 'Technische Probleme mit der App';

  @override
  String get supportRequestFeature => 'Feature wünschen';

  @override
  String get supportRequestFeatureSubtitle =>
      'Eine Verbesserung oder ein neues Feature vorschlagen';

  @override
  String get supportSaveLogs => 'Logs speichern';

  @override
  String get supportSaveLogsSubtitle =>
      'Logs als Datei exportieren, um sie manuell zu senden';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Häufige Fragen & Antworten';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Mehr über Verifizierung und Authentizität erfahren';

  @override
  String get supportLoginRequired =>
      'Melde dich an, um den Support zu kontaktieren';

  @override
  String get supportExportingLogs => 'Logs werden exportiert...';

  @override
  String get supportExportLogsFailed => 'Logs konnten nicht exportiert werden';

  @override
  String get supportChatNotAvailable => 'Support-Chat nicht verfügbar';

  @override
  String get supportCouldNotOpenMessages =>
      'Support-Nachrichten konnten nicht geöffnet werden';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return '$pageName konnte nicht geöffnet werden';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Fehler beim Öffnen von $pageName: $error';
  }

  @override
  String get reportTitle => 'Inhalt melden';

  @override
  String get reportWhyReporting => 'Warum meldest du diesen Inhalt?';

  @override
  String get reportPolicyNotice =>
      'Divine reagiert innerhalb von 24 Stunden auf Inhaltsmeldungen, indem der Inhalt entfernt und der Nutzer, der den problematischen Inhalt bereitgestellt hat, ausgeschlossen wird.';

  @override
  String get reportAdditionalDetails => 'Weitere Details (optional)';

  @override
  String get reportBlockUser => 'Diesen Nutzer blockieren';

  @override
  String get reportCancel => 'Abbrechen';

  @override
  String get reportSubmit => 'Melden';

  @override
  String get reportSelectReason =>
      'Bitte wähl einen Grund für die Meldung dieses Inhalts';

  @override
  String get reportReasonSpam => 'Spam oder unerwünschte Inhalte';

  @override
  String get reportReasonHarassment => 'Belästigung, Mobbing oder Drohungen';

  @override
  String get reportReasonViolence => 'Gewalttätige oder extremistische Inhalte';

  @override
  String get reportReasonSexualContent => 'Sexuelle oder Erwachseneninhalte';

  @override
  String get reportReasonCopyright => 'Urheberrechtsverletzung';

  @override
  String get reportReasonFalseInfo => 'Falschinformationen';

  @override
  String get reportReasonCsam => 'Verletzung der Kindersicherheit';

  @override
  String get reportReasonAiGenerated => 'KI-generierter Inhalt';

  @override
  String get reportReasonOther => 'Andere Richtlinienverletzung';

  @override
  String reportFailed(Object error) {
    return 'Inhalt konnte nicht gemeldet werden: $error';
  }

  @override
  String get reportReceivedTitle => 'Meldung erhalten';

  @override
  String get reportReceivedThankYou =>
      'Danke, dass du hilfst, Divine sicher zu halten.';

  @override
  String get reportReceivedReviewNotice =>
      'Unser Team prüft deine Meldung und ergreift entsprechende Maßnahmen. Du erhältst möglicherweise Updates per Direktnachricht.';

  @override
  String get reportLearnMore => 'Mehr erfahren';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Schließen';

  @override
  String get listAddToList => 'Zur Liste hinzufügen';

  @override
  String listVideoCount(int count) {
    return '$count Videos';
  }

  @override
  String get listNewList => 'Neue Liste';

  @override
  String get listDone => 'Fertig';

  @override
  String get listErrorLoading => 'Fehler beim Laden der Listen';

  @override
  String listRemovedFrom(String name) {
    return 'Aus $name entfernt';
  }

  @override
  String listAddedTo(String name) {
    return 'Zu $name hinzugefügt';
  }

  @override
  String get listCreateNewList => 'Neue Liste erstellen';

  @override
  String get listNameLabel => 'Listenname';

  @override
  String get listDescriptionLabel => 'Beschreibung (optional)';

  @override
  String get listPublicList => 'Öffentliche Liste';

  @override
  String get listPublicListSubtitle =>
      'Andere können folgen und diese Liste sehen';

  @override
  String get listCancel => 'Abbrechen';

  @override
  String get listCreate => 'Erstellen';

  @override
  String get listCreateFailed => 'Liste konnte nicht erstellt werden';

  @override
  String get keyManagementTitle => 'Nostr-Schlüssel';

  @override
  String get keyManagementWhatAreKeys => 'Was sind Nostr-Schlüssel?';

  @override
  String get keyManagementExplanation =>
      'Deine Nostr-Identität ist ein kryptografisches Schlüsselpaar:\n\n• Dein Public Key (npub) ist wie dein Benutzername — teil ihn gerne\n• Dein Private Key (nsec) ist wie dein Passwort — halt ihn geheim!\n\nDein nsec erlaubt dir, auf dein Konto in jeder Nostr-App zuzugreifen.';

  @override
  String get keyManagementImportTitle => 'Bestehenden Schlüssel importieren';

  @override
  String get keyManagementImportSubtitle =>
      'Du hast schon ein Nostr-Konto? Füg deinen Private Key (nsec) ein, um hier darauf zuzugreifen.';

  @override
  String get keyManagementImportButton => 'Schlüssel importieren';

  @override
  String get keyManagementImportWarning =>
      'Damit wird dein aktueller Schlüssel ersetzt!';

  @override
  String get keyManagementBackupTitle => 'Schlüssel sichern';

  @override
  String get keyManagementBackupSubtitle =>
      'Sichere deinen Private Key (nsec), um dein Konto in anderen Nostr-Apps zu nutzen.';

  @override
  String get keyManagementCopyNsec => 'Meinen Private Key (nsec) kopieren';

  @override
  String get keyManagementNeverShare =>
      'Teile deinen nsec niemals mit jemandem!';

  @override
  String get keyManagementPasteKey => 'Bitte füg deinen Private Key ein';

  @override
  String get keyManagementInvalidFormat =>
      'Ungültiges Schlüsselformat. Muss mit \"nsec1\" beginnen';

  @override
  String get keyManagementConfirmImportTitle => 'Diesen Schlüssel importieren?';

  @override
  String get keyManagementConfirmImportBody =>
      'Damit wird deine aktuelle Identität durch die importierte ersetzt.\n\nDein aktueller Schlüssel geht verloren, wenn du ihn nicht vorher gesichert hast.';

  @override
  String get keyManagementImportConfirm => 'Importieren';

  @override
  String get keyManagementImportSuccess => 'Schlüssel erfolgreich importiert!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Schlüssel konnte nicht importiert werden: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Private Key in die Zwischenablage kopiert!\n\nBewahre ihn sicher auf.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Schlüssel konnte nicht exportiert werden: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'In Aufnahmen gespeichert';

  @override
  String get saveOriginalShare => 'Teilen';

  @override
  String get saveOriginalDone => 'Fertig';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Fotozugriff erforderlich';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Um Videos zu speichern, erlaube den Fotozugriff in den Einstellungen.';

  @override
  String get saveOriginalOpenSettings => 'Einstellungen öffnen';

  @override
  String get saveOriginalNotNow => 'Nicht jetzt';

  @override
  String get cameraPermissionNotNow => 'Nicht jetzt';

  @override
  String get saveOriginalDownloadFailed => 'Download fehlgeschlagen';

  @override
  String get saveOriginalDismiss => 'Schließen';

  @override
  String get saveOriginalDownloadingVideo => 'Video wird heruntergeladen';

  @override
  String get saveOriginalSavingToCameraRoll => 'Speichern in Aufnahmen';

  @override
  String get saveOriginalFetchingVideo =>
      'Video wird aus dem Netzwerk geladen...';

  @override
  String get saveOriginalSavingVideo =>
      'Original-Video wird in deinen Aufnahmen gespeichert...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Originalton';

  @override
  String get soundVideosUsingThisSound => 'Videos, die diesen Sound nutzen';

  @override
  String get soundSourceVideo => 'Quellvideo';

  @override
  String get soundNoVideosYet => 'Noch keine Videos';

  @override
  String get soundBeFirstToUse =>
      'Sei die/der Erste, die/der diesen Sound nutzt!';

  @override
  String get soundFailedToLoadVideos => 'Videos konnten nicht geladen werden';

  @override
  String get soundRetry => 'Erneut versuchen';

  @override
  String get soundVideosUnavailable => 'Videos nicht verfügbar';

  @override
  String get soundCouldNotLoadDetails =>
      'Video-Details konnten nicht geladen werden';

  @override
  String get soundPreview => 'Vorschau';

  @override
  String get soundStop => 'Stopp';

  @override
  String get soundUseSound => 'Sound verwenden';

  @override
  String get soundNoVideoCount => 'Noch keine Videos';

  @override
  String get soundOneVideo => '1 Video';

  @override
  String soundVideoCount(int count) {
    return '$count Videos';
  }

  @override
  String get soundUnableToPreview =>
      'Vorschau nicht möglich — kein Audio verfügbar';

  @override
  String soundPreviewFailed(Object error) {
    return 'Vorschau-Wiedergabe fehlgeschlagen: $error';
  }

  @override
  String get soundViewSource => 'Quelle ansehen';

  @override
  String get soundCloseTooltip => 'Schließen';

  @override
  String get exploreNotExploreRoute => 'Keine Entdecken-Route';

  @override
  String get legalTitle => 'Rechtliches';

  @override
  String get legalTermsOfService => 'Nutzungsbedingungen';

  @override
  String get legalTermsOfServiceSubtitle => 'Nutzungsbedingungen';

  @override
  String get legalPrivacyPolicy => 'Datenschutzrichtlinie';

  @override
  String get legalPrivacyPolicySubtitle => 'Wie wir mit deinen Daten umgehen';

  @override
  String get legalSafetyStandards => 'Sicherheitsstandards';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Community-Richtlinien und Sicherheit';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Urheberrechts- und Takedown-Richtlinie';

  @override
  String get legalOpenSourceLicenses => 'Open-Source-Lizenzen';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Angaben zu Drittanbieter-Paketen';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return '$pageName konnte nicht geöffnet werden';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Fehler beim Öffnen von $pageName: $error';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Abenteuer';

  @override
  String get categoryAnimals => 'Tiere';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Architektur';

  @override
  String get categoryArt => 'Kunst';

  @override
  String get categoryAutomotive => 'Autos';

  @override
  String get categoryAwardShow => 'Preisverleihung';

  @override
  String get categoryAwards => 'Auszeichnungen';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basketball';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Getränke';

  @override
  String get categoryCars => 'Autos';

  @override
  String get categoryCelebration => 'Feier';

  @override
  String get categoryCelebrities => 'Promis';

  @override
  String get categoryCelebrity => 'Promi';

  @override
  String get categoryCityscape => 'Stadtbild';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Konzert';

  @override
  String get categoryCooking => 'Kochen';

  @override
  String get categoryCostume => 'Kostüm';

  @override
  String get categoryCrafts => 'Basteln';

  @override
  String get categoryCrime => 'Krimi';

  @override
  String get categoryCulture => 'Kultur';

  @override
  String get categoryDance => 'Tanz';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Bildung';

  @override
  String get categoryEmotional => 'Emotional';

  @override
  String get categoryEmotions => 'Emotionen';

  @override
  String get categoryEntertainment => 'Unterhaltung';

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
  String get categoryFood => 'Essen';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Möbel';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Körperpflege';

  @override
  String get categoryGuitar => 'Gitarre';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Gesundheit';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Urlaub';

  @override
  String get categoryHome => 'Zuhause';

  @override
  String get categoryHomeImprovement => 'Heimwerken';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Krankenhaus';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Inneneinrichtung';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Kinder';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Make-up';

  @override
  String get categoryMedical => 'Medizin';

  @override
  String get categoryMusic => 'Musik';

  @override
  String get categoryMystery => 'Mystery';

  @override
  String get categoryNature => 'Natur';

  @override
  String get categoryNews => 'News';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Party';

  @override
  String get categoryPeople => 'Menschen';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Haustiere';

  @override
  String get categoryPolitics => 'Politik';

  @override
  String get categoryPrank => 'Streich';

  @override
  String get categoryPranks => 'Streiche';

  @override
  String get categoryRealityShow => 'Reality-Show';

  @override
  String get categoryRelationship => 'Beziehung';

  @override
  String get categoryRelationships => 'Beziehungen';

  @override
  String get categoryRomance => 'Romantik';

  @override
  String get categorySchool => 'Schule';

  @override
  String get categoryScienceFiction => 'Science-Fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Hautpflege';

  @override
  String get categorySoccer => 'Fußball';

  @override
  String get categorySocialGathering => 'Gesellschaft';

  @override
  String get categorySocialMedia => 'Social Media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talkshow';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryTelevision => 'Fernsehen';

  @override
  String get categoryToys => 'Spielzeug';

  @override
  String get categoryTransportation => 'Verkehr';

  @override
  String get categoryTravel => 'Reisen';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Gewalt';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadSuccess => 'Profilbild erfolgreich hochgeladen!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName gemeldet';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName blockiert';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName entblockt';
  }

  @override
  String get inboxRemovedConversation => 'Unterhaltung entfernt';

  @override
  String get reportDialogCancel => 'Abbrechen';

  @override
  String get reportDialogReport => 'Melden';

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
    return 'Abo konnte nicht aktualisiert werden: $error';
  }

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Ablaufdatum';

  @override
  String get videoMetadataContentWarnings => 'Inhaltswarnungen';

  @override
  String get videoEditorLayers => 'Ebenen';

  @override
  String get videoEditorStickers => 'Sticker';

  @override
  String get trendingTitle => 'Im Trend';

  @override
  String get proofmodeCheckAiGenerated => 'Prüfen, ob KI-generiert';

  @override
  String get libraryDeleteConfirm => 'Löschen';

  @override
  String get libraryWebUnavailableHeadline =>
      'Mediathek ist in der mobilen App';

  @override
  String get libraryWebUnavailableDescription =>
      'Entwürfe und Clips werden auf deinem Gerät gespeichert. Öffne Divine auf dem Smartphone, um sie zu verwalten.';

  @override
  String get libraryTabDrafts => 'Entwürfe';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get librarySaveToCameraRollTooltip => 'In der Fotomediathek speichern';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Ausgewählte Clips löschen';

  @override
  String get libraryDeleteClipsTitle => 'Clips löschen';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# ausgewählte Clips',
      one: '# ausgewählten Clip',
    );
    return 'Möchtest du wirklich $_temp0 löschen?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Das kann nicht rückgängig gemacht werden. Die Videodateien werden dauerhaft von deinem Gerät entfernt.';

  @override
  String get libraryPreparingVideo => 'Video wird vorbereitet …';

  @override
  String get libraryCreateVideo => 'Video erstellen';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips',
      one: '1 Clip',
    );
    return '$_temp0 in $destination gespeichert';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount gespeichert, $failureCount fehlgeschlagen';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination: Berechtigung verweigert';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Clips gelöscht',
      one: '1 Clip gelöscht',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Entwürfe konnten nicht geladen werden';

  @override
  String get libraryCouldNotLoadClips => 'Clips konnten nicht geladen werden';

  @override
  String get libraryOpenErrorDescription =>
      'Beim Öffnen deiner Mediathek ist etwas schiefgelaufen. Versuch es noch einmal.';

  @override
  String get libraryNoDraftsYetTitle => 'Noch keine Entwürfe';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videos, die du als Entwurf speicherst, erscheinen hier';

  @override
  String get libraryNoClipsYetTitle => 'Noch keine Clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Deine aufgenommenen Videoclips erscheinen hier';

  @override
  String get libraryDraftDeletedSnackbar => 'Entwurf gelöscht';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Entwurf konnte nicht gelöscht werden';

  @override
  String get libraryDraftActionPost => 'Posten';

  @override
  String get libraryDraftActionEdit => 'Bearbeiten';

  @override
  String get libraryDraftActionDelete => 'Entwurf löschen';

  @override
  String get libraryDeleteDraftTitle => 'Entwurf löschen';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '„$title“ wirklich löschen?';
  }

  @override
  String get libraryDeleteClipTitle => 'Clip löschen';

  @override
  String get libraryDeleteClipMessage => 'Diesen Clip wirklich löschen?';

  @override
  String get libraryClipSelectionTitle => 'Clips';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Noch ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Hinzufügen';

  @override
  String get libraryRecordVideo => 'Video aufnehmen';

  @override
  String get routerInvalidCreator => 'Ungültiger Ersteller';

  @override
  String get routerInvalidHashtagRoute => 'Ungültige Hashtag-Route';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Videos konnten nicht geladen werden';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Kategorien konnten nicht geladen werden';

  @override
  String get notificationFollowBack => 'Zurückfolgen';

  @override
  String get followingFailedToLoadList =>
      'Folge-ich-Liste konnte nicht geladen werden';

  @override
  String get followersFailedToLoadList =>
      'Follower-Liste konnte nicht geladen werden';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Einstellungen konnten nicht gespeichert werden: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Crosspost-Einstellung konnte nicht aktualisiert werden';

  @override
  String get invitesTitle => 'Freunde einladen';

  @override
  String get searchSomethingWentWrong => 'Etwas ist schiefgelaufen';

  @override
  String get searchTryAgain => 'Erneut versuchen';

  @override
  String get searchForLists => 'Nach Listen suchen';

  @override
  String get searchFindCuratedVideoLists => 'Kuratierte Videolisten finden';

  @override
  String get cameraAgeRestriction =>
      'Du musst mindestens 16 Jahre alt sein, um Inhalte zu erstellen';

  @override
  String get featureRequestCancel => 'Abbrechen';

  @override
  String keyImportError(String error) {
    return 'Fehler: $error';
  }

  @override
  String get timeNow => 'jetzt';

  @override
  String timeShortMinutes(int count) {
    return '$count Min';
  }

  @override
  String timeShortHours(int count) {
    return '$count Std';
  }

  @override
  String timeShortDays(int count) {
    return '$count T';
  }

  @override
  String timeShortWeeks(int count) {
    return '$count W';
  }

  @override
  String timeShortMonths(int count) {
    return '$count Mo';
  }

  @override
  String timeShortYears(int count) {
    return '$count J';
  }

  @override
  String get timeVerboseNow => 'Jetzt';

  @override
  String timeAgo(String time) {
    return 'vor $time';
  }

  @override
  String get timeToday => 'Heute';

  @override
  String get timeYesterday => 'Gestern';

  @override
  String get timeJustNow => 'gerade eben';

  @override
  String timeMinutesAgo(int count) {
    return 'vor $count Min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'vor $count Std';
  }

  @override
  String timeDaysAgo(int count) {
    return 'vor $count T';
  }

  @override
  String get draftTimeJustNow => 'Gerade eben';

  @override
  String get contentLabelNudity => 'Nacktheit';

  @override
  String get contentLabelSexualContent => 'Sexueller Inhalt';

  @override
  String get contentLabelPornography => 'Pornografie';

  @override
  String get contentLabelGraphicMedia => 'Verstörende Inhalte';

  @override
  String get contentLabelViolence => 'Gewalt';

  @override
  String get contentLabelSelfHarm => 'Selbstverletzung/Suizid';

  @override
  String get contentLabelDrugUse => 'Drogenkonsum';

  @override
  String get contentLabelAlcohol => 'Alkohol';

  @override
  String get contentLabelTobacco => 'Tabak/Rauchen';

  @override
  String get contentLabelGambling => 'Glücksspiel';

  @override
  String get contentLabelProfanity => 'Vulgärsprache';

  @override
  String get contentLabelHateSpeech => 'Hassrede';

  @override
  String get contentLabelHarassment => 'Belästigung';

  @override
  String get contentLabelFlashingLights => 'Blitzlichter';

  @override
  String get contentLabelAiGenerated => 'KI-generiert';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Betrug';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Irreführend';

  @override
  String get contentLabelSensitiveContent => 'Sensibler Inhalt';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName hat dein Video geliked';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName hat dein Video kommentiert';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName folgt dir jetzt';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName hat dich erwähnt';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName hat dein Video geteilt';
  }

  @override
  String get draftUntitled => 'Ohne Titel';

  @override
  String get contentWarningNone => 'Keine';

  @override
  String get textBackgroundNone => 'Keine';

  @override
  String get textBackgroundSolid => 'Deckend';

  @override
  String get textBackgroundHighlight => 'Hervorhebung';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Links';

  @override
  String get textAlignRight => 'Rechts';

  @override
  String get textAlignCenter => 'Zentriert';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Kamera wird im Web noch nicht unterstützt';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Kameraaufnahme und -aufzeichnung sind in der Webversion noch nicht verfügbar.';

  @override
  String get cameraPermissionBackToFeed => 'Zurück zum Feed';

  @override
  String get cameraPermissionErrorTitle => 'Berechtigungsfehler';

  @override
  String get cameraPermissionErrorDescription =>
      'Beim Prüfen der Berechtigungen ist etwas schiefgelaufen.';

  @override
  String get cameraPermissionRetry => 'Erneut versuchen';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Kamera- und Mikrofonzugriff erlauben';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Damit kannst du Videos direkt hier in der App aufnehmen und bearbeiten, sonst nichts.';

  @override
  String get cameraPermissionContinue => 'Weiter';

  @override
  String get cameraPermissionGoToSettings => 'Zu den Einstellungen';
}
