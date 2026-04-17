// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Italian (`it`).
class AppLocalizationsIt extends AppLocalizations {
  AppLocalizationsIt([String locale = 'it']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Impostazioni';

  @override
  String get settingsSecureAccount => 'Metti al sicuro il tuo account';

  @override
  String get settingsSessionExpired => 'Sessione scaduta';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Accedi di nuovo per ripristinare l\'accesso completo';

  @override
  String get settingsCreatorAnalytics => 'Statistiche creator';

  @override
  String get settingsSupportCenter => 'Centro assistenza';

  @override
  String get settingsNotifications => 'Notifiche';

  @override
  String get settingsContentPreferences => 'Preferenze contenuti';

  @override
  String get settingsModerationControls => 'Controlli di moderazione';

  @override
  String get settingsBlueskyPublishing => 'Pubblicazione su Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gestisci il crosspost su Bluesky';

  @override
  String get settingsNostrSettings => 'Impostazioni Nostr';

  @override
  String get settingsIntegratedApps => 'App integrate';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'App di terze parti approvate che girano dentro Divine';

  @override
  String get settingsExperimentalFeatures => 'Funzionalità sperimentali';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Chicche che potrebbero fare le bizze—provale se sei curioso.';

  @override
  String get settingsLegal => 'Legale';

  @override
  String get settingsIntegrationPermissions => 'Permessi di integrazione';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Controlla e revoca le approvazioni di integrazione salvate';

  @override
  String settingsVersion(String version) {
    return 'Versione $version';
  }

  @override
  String get settingsVersionEmpty => 'Versione';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'La modalità sviluppatore è già attiva';

  @override
  String get settingsDeveloperModeEnabled => 'Modalità sviluppatore attivata!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Altri $count tap per attivare la modalità sviluppatore';
  }

  @override
  String get settingsInvites => 'Inviti';

  @override
  String get settingsSwitchAccount => 'Cambia account';

  @override
  String get settingsAddAnotherAccount => 'Aggiungi un altro account';

  @override
  String get settingsUnsavedDraftsTitle => 'Bozze non salvate';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'bozze non salvate',
      one: 'bozza non salvata',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'le tue bozze verranno mantenute',
      one: 'la tua bozza verrà mantenuta',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'pubblicarle o rivederle',
      one: 'pubblicarla o rivederla',
    );
    return 'Hai $count $_temp0. Cambiando account $_temp1, ma potresti voler $_temp2 prima.';
  }

  @override
  String get settingsCancel => 'Annulla';

  @override
  String get settingsSwitchAnyway => 'Cambia comunque';

  @override
  String get settingsAppVersionLabel => 'Versione dell\'app';

  @override
  String get settingsAppLanguage => 'Lingua dell\'app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (predefinita del dispositivo)';
  }

  @override
  String get settingsAppLanguageTitle => 'Lingua dell\'app';

  @override
  String get settingsAppLanguageDescription =>
      'Scegli la lingua dell\'interfaccia dell\'app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Usa la lingua del dispositivo';

  @override
  String get contentPreferencesTitle => 'Preferenze contenuti';

  @override
  String get contentPreferencesContentFilters => 'Filtri contenuti';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gestisci i filtri per gli avvisi sui contenuti';

  @override
  String get contentPreferencesContentLanguage => 'Lingua dei contenuti';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (predefinita del dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etichetta i tuoi video con una lingua così chi guarda può filtrare i contenuti.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usa la lingua del dispositivo (predefinita)';

  @override
  String get contentPreferencesAudioSharing =>
      'Rendi disponibile il mio audio per il riutilizzo';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Quando attivo, altri possono usare l\'audio dei tuoi video';

  @override
  String get contentPreferencesAccountLabels => 'Etichette account';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-etichetta i tuoi contenuti';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etichette contenuti dell\'account';

  @override
  String get contentPreferencesClearAll => 'Cancella tutto';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Seleziona tutto ciò che vale per il tuo account';

  @override
  String get contentPreferencesDoneNoLabels => 'Fatto (nessuna etichetta)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Fatto ($count selezionate)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispositivo di ingresso audio';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (consigliato)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Seleziona automaticamente il microfono migliore';

  @override
  String get contentPreferencesSelectAudioInput => 'Seleziona ingresso audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Microfono sconosciuto';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Questo account non è disponibile';

  @override
  String profileErrorPrefix(Object error) {
    return 'Errore: $error';
  }

  @override
  String get profileInvalidId => 'ID profilo non valido';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Dai un\'occhiata a $displayName su Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName su Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Impossibile condividere il profilo: $error';
  }

  @override
  String get profileEditProfile => 'Modifica profilo';

  @override
  String get profileCreatorAnalytics => 'Statistiche creator';

  @override
  String get profileShareProfile => 'Condividi profilo';

  @override
  String get profileCopyPublicKey => 'Copia chiave pubblica (npub)';

  @override
  String get profileGetEmbedCode => 'Ottieni codice embed';

  @override
  String get profilePublicKeyCopied => 'Chiave pubblica copiata negli appunti';

  @override
  String get profileEmbedCodeCopied => 'Codice embed copiato negli appunti';

  @override
  String get profileRefreshTooltip => 'Aggiorna';

  @override
  String get profileRefreshSemanticLabel => 'Aggiorna profilo';

  @override
  String get profileMoreTooltip => 'Altro';

  @override
  String get profileMoreSemanticLabel => 'Altre opzioni';

  @override
  String get profileFollowingLabel => 'Segui già';

  @override
  String get profileFollowLabel => 'Segui';

  @override
  String get profileBlockedLabel => 'Bloccato';

  @override
  String get profileFollowersLabel => 'Follower';

  @override
  String get profileFollowingStatLabel => 'Seguiti';

  @override
  String get profileVideosLabel => 'Video';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count utenti';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Bloccare $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Quando blocchi un utente:';

  @override
  String get profileBlockBulletHidePosts =>
      'I suoi post non appariranno nei tuoi feed.';

  @override
  String get profileBlockBulletCantView =>
      'Non potrà vedere il tuo profilo, seguirti o vedere i tuoi post.';

  @override
  String get profileBlockBulletNoNotify =>
      'Non verrà avvisato di questo cambiamento.';

  @override
  String get profileBlockBulletYouCanView =>
      'Tu potrai comunque vedere il suo profilo.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Blocca $displayName';
  }

  @override
  String get profileCancelButton => 'Annulla';

  @override
  String get profileLearnMore => 'Scopri di più';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Sbloccare $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Quando sblocchi questo utente:';

  @override
  String get profileUnblockBulletShowPosts =>
      'I suoi post appariranno nei tuoi feed.';

  @override
  String get profileUnblockBulletCanView =>
      'Potrà vedere il tuo profilo, seguirti e vedere i tuoi post.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Non verrà avvisato di questo cambiamento.';

  @override
  String get profileLearnMoreAt => 'Scopri di più su ';

  @override
  String get profileUnblockButton => 'Sblocca';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Smetti di seguire $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Blocca $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Sblocca $displayName';
  }

  @override
  String get profileUserBlockedTitle => 'Utente bloccato';

  @override
  String get profileUserBlockedContent =>
      'Non vedrai più contenuti di questo utente nei tuoi feed.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Puoi sbloccarlo in qualsiasi momento dal suo profilo o in Impostazioni > Sicurezza.';

  @override
  String get profileCloseButton => 'Chiudi';

  @override
  String get profileNoCollabsTitle => 'Ancora nessuna collab';

  @override
  String get profileCollabsOwnEmpty =>
      'I video a cui collabori appariranno qui';

  @override
  String get profileCollabsOtherEmpty =>
      'I video a cui collabora appariranno qui';

  @override
  String get profileErrorLoadingCollabs =>
      'Errore nel caricamento dei video collab';

  @override
  String get profileNoCommentsOwnTitle => 'Ancora nessun commento';

  @override
  String get profileNoCommentsOtherTitle => 'Nessun commento';

  @override
  String get profileCommentsOwnEmpty =>
      'I tuoi commenti e le tue risposte appariranno qui';

  @override
  String get profileCommentsOtherEmpty =>
      'I suoi commenti e le sue risposte appariranno qui';

  @override
  String get profileErrorLoadingComments =>
      'Errore nel caricamento dei commenti';

  @override
  String get profileVideoRepliesSection => 'Video risposte';

  @override
  String get profileCommentsSection => 'Commenti';

  @override
  String get profileEditLabel => 'Modifica';

  @override
  String get profileLibraryLabel => 'Libreria';

  @override
  String get profileNoLikedVideosTitle => 'Ancora nessun video piaciuto';

  @override
  String get profileLikedOwnEmpty => 'I video che ti piacciono appariranno qui';

  @override
  String get profileLikedOtherEmpty =>
      'I video che gli piacciono appariranno qui';

  @override
  String get profileErrorLoadingLiked =>
      'Errore nel caricamento dei video piaciuti';

  @override
  String get profileNoRepostsTitle => 'Ancora nessun repost';

  @override
  String get profileRepostsOwnEmpty =>
      'I video che ripubblichi appariranno qui';

  @override
  String get profileRepostsOtherEmpty =>
      'I video che ripubblica appariranno qui';

  @override
  String get profileErrorLoadingReposts =>
      'Errore nel caricamento dei video ripubblicati';

  @override
  String get profileLoadingTitle => 'Caricamento profilo...';

  @override
  String get profileLoadingSubtitle => 'Potrebbe volerci qualche secondo';

  @override
  String get profileLoadingVideos => 'Caricamento video...';

  @override
  String get profileNoVideosTitle => 'Ancora nessun video';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Condividi il tuo primo video per vederlo qui';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Questo utente non ha ancora condiviso video';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura video $number';
  }

  @override
  String get profileShowMore => 'Mostra di più';

  @override
  String get profileShowLess => 'Mostra di meno';

  @override
  String get profileCompleteYourProfile => 'Completa il tuo profilo';

  @override
  String get profileCompleteSubtitle =>
      'Aggiungi nome, bio e foto per iniziare';

  @override
  String get profileSetUpButton => 'Configura';

  @override
  String get profileVerifyingEmail => 'Verifica email in corso...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Controlla $email per il link di verifica';
  }

  @override
  String get profileWaitingForVerification => 'In attesa della verifica email';

  @override
  String get profileVerificationFailed => 'Verifica fallita';

  @override
  String get profilePleaseTryAgain => 'Riprova';

  @override
  String get profileSecureYourAccount => 'Metti al sicuro il tuo account';

  @override
  String get profileSecureSubtitle =>
      'Aggiungi email e password per recuperare il tuo account su qualsiasi dispositivo';

  @override
  String get profileRetryButton => 'Riprova';

  @override
  String get profileRegisterButton => 'Registrati';

  @override
  String get profileSessionExpired => 'Sessione scaduta';

  @override
  String get profileSignInToRestore =>
      'Accedi di nuovo per ripristinare l\'accesso completo';

  @override
  String get profileSignInButton => 'Accedi';

  @override
  String get profileDismissTooltip => 'Ignora';

  @override
  String get profileLinkCopied => 'Link del profilo copiato';

  @override
  String get profileSetupEditProfileTitle => 'Modifica profilo';

  @override
  String get profileSetupBackLabel => 'Indietro';

  @override
  String get profileSetupAboutNostr => 'Info su Nostr';

  @override
  String get profileSetupProfilePublished => 'Profilo pubblicato con successo!';

  @override
  String get profileSetupCreateNewProfile => 'Creare un nuovo profilo?';

  @override
  String get profileSetupNoExistingProfile =>
      'Non abbiamo trovato un profilo esistente sui tuoi relay. Pubblicando ne creerai uno nuovo. Continuare?';

  @override
  String get profileSetupPublishButton => 'Pubblica';

  @override
  String get profileSetupUsernameTaken =>
      'Il nome utente è appena stato preso. Scegline un altro.';

  @override
  String get profileSetupClaimFailed =>
      'Impossibile rivendicare il nome utente. Riprova.';

  @override
  String get profileSetupPublishFailed =>
      'Impossibile pubblicare il profilo. Riprova.';

  @override
  String get profileSetupDisplayNameLabel => 'Nome visualizzato';

  @override
  String get profileSetupDisplayNameHint => 'Come ti devono conoscere?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Qualsiasi nome o etichetta. Non deve essere univoco.';

  @override
  String get profileSetupDisplayNameRequired =>
      'Inserisci un nome visualizzato';

  @override
  String get profileSetupBioLabel => 'Bio (opzionale)';

  @override
  String get profileSetupBioHint => 'Racconta qualcosa di te...';

  @override
  String get profileSetupPublicKeyLabel => 'Chiave pubblica (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nome utente (opzionale)';

  @override
  String get profileSetupUsernameHint => 'nomeutente';

  @override
  String get profileSetupUsernameHelper => 'La tua identità univoca su Divine';

  @override
  String get profileSetupProfileColorLabel => 'Colore profilo (opzionale)';

  @override
  String get profileSetupSaveButton => 'Salva';

  @override
  String get profileSetupSavingButton => 'Salvataggio...';

  @override
  String get profileSetupImageUrlTitle => 'Aggiungi URL immagine';

  @override
  String get profileSetupPictureUploaded =>
      'Foto profilo caricata con successo!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Selezione immagine fallita. Incolla qui sotto l\'URL di un\'immagine.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Accesso alla fotocamera fallito: $error';
  }

  @override
  String get profileSetupGotItButton => 'Capito';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Impossibile caricare l\'immagine: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'Errore di rete: controlla la connessione a internet e riprova.';

  @override
  String get profileSetupUploadAuthError =>
      'Errore di autenticazione: prova a uscire e a rientrare.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'File troppo grande: scegli un\'immagine più piccola (max 10MB).';

  @override
  String get profileSetupUsernameChecking => 'Controllo disponibilità...';

  @override
  String get profileSetupUsernameAvailable => 'Nome utente disponibile!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Nome utente già preso';

  @override
  String get profileSetupUsernameReserved => 'Nome utente riservato';

  @override
  String get profileSetupContactSupport => 'Contatta l\'assistenza';

  @override
  String get profileSetupCheckAgain => 'Controlla di nuovo';

  @override
  String get profileSetupUsernameBurned =>
      'Questo nome utente non è più disponibile';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Sono ammessi solo lettere, numeri e trattini';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Il nome utente deve avere da 3 a 20 caratteri';

  @override
  String get profileSetupUsernameNetworkError =>
      'Impossibile verificare la disponibilità. Riprova.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Formato nome utente non valido';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Verifica disponibilità fallita';

  @override
  String get profileSetupUsernameReservedTitle => 'Nome utente riservato';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Il nome $username è riservato. Dicci perché dovrebbe essere tuo.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'es. È il mio brand, nome d\'arte, ecc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Hai già contattato l\'assistenza? Tocca \"Controlla di nuovo\" per vedere se è stato rilasciato per te.';

  @override
  String get profileSetupSupportRequestSent =>
      'Richiesta di assistenza inviata! Ti risponderemo presto.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Impossibile aprire l\'email. Invia a: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Invia richiesta';

  @override
  String get profileSetupPickColorTitle => 'Scegli un colore';

  @override
  String get profileSetupSelectButton => 'Seleziona';

  @override
  String get profileSetupUseOwnNip05 => 'Usa il tuo indirizzo NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Indirizzo NIP-05';

  @override
  String get profileSetupProfilePicturePreview => 'Anteprima foto profilo';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine è costruito su Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocollo aperto resistente alla censura che permette alle persone di comunicare online senza dipendere da una singola azienda o piattaforma. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Quando ti iscrivi a Divine, ottieni una nuova identità Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr ti permette di possedere i tuoi contenuti, la tua identità e il tuo grafo sociale, che puoi usare in molte app. Il risultato è più scelta, meno lock-in e un internet sociale più sano e resiliente.';

  @override
  String get nostrInfoLingo => 'Il lessico di Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Il tuo indirizzo Nostr pubblico. È sicuro da condividere e permette ad altri di trovarti, seguirti o scriverti nelle app Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' La tua chiave privata e prova di proprietà. Ti dà il pieno controllo della tua identità Nostr, quindi ';

  @override
  String get nostrInfoNsecWarning => 'tienila sempre segreta!';

  @override
  String get nostrInfoUsernameLabel => 'Nome utente Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nome leggibile (tipo @name.divine.video) che è collegato al tuo npub. Rende la tua identità Nostr più facile da riconoscere e verificare, come un indirizzo email.';

  @override
  String get nostrInfoLearnMoreAt => 'Scopri di più su ';

  @override
  String get nostrInfoGotIt => 'Capito!';

  @override
  String get profileTabRefreshTooltip => 'Aggiorna';

  @override
  String get videoGridRefreshLabel => 'Ricerca di altri video in corso';

  @override
  String get videoGridOptionsTitle => 'Opzioni video';

  @override
  String get videoGridEditVideo => 'Modifica video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Aggiorna titolo, descrizione e hashtag';

  @override
  String get videoGridDeleteVideo => 'Elimina video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Rimuovi definitivamente questo contenuto';

  @override
  String get videoGridDeleteConfirmTitle => 'Elimina video';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Sei sicuro di voler eliminare questo video?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Verrà inviata una richiesta di eliminazione (NIP-09) a tutti i relay. Alcuni relay potrebbero comunque conservare il contenuto.';

  @override
  String get videoGridDeleteCancel => 'Annulla';

  @override
  String get videoGridDeleteConfirm => 'Elimina';

  @override
  String get videoGridDeletingContent => 'Eliminazione contenuto...';

  @override
  String get videoGridDeleteSuccess =>
      'Richiesta di eliminazione inviata con successo';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Impossibile eliminare il contenuto: $error';
  }

  @override
  String get exploreTabClassics => 'Classici';

  @override
  String get exploreTabNew => 'Nuovi';

  @override
  String get exploreTabPopular => 'Popolari';

  @override
  String get exploreTabCategories => 'Categorie';

  @override
  String get exploreTabForYou => 'Per te';

  @override
  String get exploreTabLists => 'Liste';

  @override
  String get exploreTabIntegratedApps => 'App integrate';

  @override
  String get exploreNoVideosAvailable => 'Nessun video disponibile';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Errore: $error';
  }

  @override
  String get exploreDiscoverLists => 'Scopri liste';

  @override
  String get exploreAboutLists => 'Info sulle liste';

  @override
  String get exploreAboutListsDescription =>
      'Le liste ti aiutano a organizzare e curare i contenuti di Divine in due modi:';

  @override
  String get explorePeopleLists => 'Liste di persone';

  @override
  String get explorePeopleListsDescription =>
      'Segui gruppi di creator e vedi i loro ultimi video';

  @override
  String get exploreVideoLists => 'Liste di video';

  @override
  String get exploreVideoListsDescription =>
      'Crea playlist dei tuoi video preferiti da guardare dopo';

  @override
  String get exploreMyLists => 'Le mie liste';

  @override
  String get exploreSubscribedLists => 'Liste iscritte';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Errore nel caricamento delle liste: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nuovi video',
      one: '1 nuovo video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nuovi video',
      one: 'nuovo video',
    );
    return 'Carica $count $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Caricamento video...';

  @override
  String get videoPlayerPlayVideo => 'Riproduci video';

  @override
  String get videoPlayerEditVideo => 'Modifica video';

  @override
  String get videoPlayerEditVideoTooltip => 'Modifica video';

  @override
  String get contentWarningLabel => 'Avviso sui contenuti';

  @override
  String get contentWarningNudity => 'Nudità';

  @override
  String get contentWarningSexualContent => 'Contenuto sessuale';

  @override
  String get contentWarningPornography => 'Pornografia';

  @override
  String get contentWarningGraphicMedia => 'Immagini esplicite';

  @override
  String get contentWarningViolence => 'Violenza';

  @override
  String get contentWarningSelfHarm => 'Autolesionismo';

  @override
  String get contentWarningDrugUse => 'Uso di droghe';

  @override
  String get contentWarningAlcohol => 'Alcol';

  @override
  String get contentWarningTobacco => 'Tabacco';

  @override
  String get contentWarningGambling => 'Gioco d\'azzardo';

  @override
  String get contentWarningProfanity => 'Volgarità';

  @override
  String get contentWarningFlashingLights => 'Luci lampeggianti';

  @override
  String get contentWarningAiGenerated => 'Generato da IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Contenuto sensibile';

  @override
  String get contentWarningDescNudity => 'Contiene nudità o nudità parziale';

  @override
  String get contentWarningDescSexual => 'Contiene contenuto sessuale';

  @override
  String get contentWarningDescPorn =>
      'Contiene contenuto pornografico esplicito';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contiene immagini esplicite o disturbanti';

  @override
  String get contentWarningDescViolence => 'Contiene contenuto violento';

  @override
  String get contentWarningDescSelfHarm =>
      'Contiene riferimenti all\'autolesionismo';

  @override
  String get contentWarningDescDrugs => 'Contiene contenuto legato alle droghe';

  @override
  String get contentWarningDescAlcohol =>
      'Contiene contenuto legato all\'alcol';

  @override
  String get contentWarningDescTobacco =>
      'Contiene contenuto legato al tabacco';

  @override
  String get contentWarningDescGambling =>
      'Contiene contenuto legato al gioco d\'azzardo';

  @override
  String get contentWarningDescProfanity => 'Contiene linguaggio forte';

  @override
  String get contentWarningDescFlashingLights =>
      'Contiene luci lampeggianti (avviso per fotosensibilità)';

  @override
  String get contentWarningDescAiGenerated =>
      'Questo contenuto è stato generato da un\'IA';

  @override
  String get contentWarningDescSpoiler => 'Contiene spoiler';

  @override
  String get contentWarningDescContentWarning =>
      'Il creator lo ha segnalato come sensibile';

  @override
  String get contentWarningDescDefault =>
      'Il creator ha segnalato questo contenuto';

  @override
  String get contentWarningDetailsTitle => 'Avvisi sui contenuti';

  @override
  String get contentWarningDetailsSubtitle =>
      'Il creator ha applicato queste etichette:';

  @override
  String get contentWarningManageFilters => 'Gestisci filtri contenuti';

  @override
  String get contentWarningViewAnyway => 'Guarda comunque';

  @override
  String get contentWarningHideAllLikeThis =>
      'Nascondi tutti i contenuti come questo';

  @override
  String get contentWarningNoFilterYet =>
      'Ancora nessun filtro salvato per questo avviso.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Da ora in poi nasconderemo i post come questo.';

  @override
  String get videoErrorNotFound => 'Video non trovato';

  @override
  String get videoErrorNetwork => 'Errore di rete';

  @override
  String get videoErrorTimeout => 'Timeout caricamento';

  @override
  String get videoErrorFormat =>
      'Errore formato video\n(Riprova o usa un browser diverso)';

  @override
  String get videoErrorUnsupportedFormat => 'Formato video non supportato';

  @override
  String get videoErrorPlayback => 'Errore di riproduzione video';

  @override
  String get videoErrorAgeRestricted => 'Contenuto con limite d\'età';

  @override
  String get videoErrorVerifyAge => 'Verifica età';

  @override
  String get videoErrorRetry => 'Riprova';

  @override
  String get videoErrorContentRestricted => 'Contenuto con restrizioni';

  @override
  String get videoErrorContentRestrictedBody =>
      'Questo video è stato limitato dal relay.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifica la tua età per vedere questo video.';

  @override
  String get videoErrorSkip => 'Salta';

  @override
  String get videoErrorVerifyAgeButton => 'Verifica età';

  @override
  String get videoFollowButtonFollowing => 'Segui già';

  @override
  String get videoFollowButtonFollow => 'Segui';

  @override
  String get audioAttributionOriginalSound => 'Audio originale';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Ispirato da @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'con @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'con @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaboratori',
      one: '1 collaboratore',
    );
    return '$_temp0. Tocca per vedere il profilo.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Condividi video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post condiviso con $recipientName';
  }

  @override
  String get shareFailedToSend => 'Impossibile inviare il video';

  @override
  String get shareAddedToBookmarks => 'Aggiunto ai segnalibri';

  @override
  String get shareFailedToAddBookmark => 'Impossibile aggiungere ai segnalibri';

  @override
  String get shareActionFailed => 'Azione fallita';

  @override
  String get shareWithTitle => 'Condividi con';

  @override
  String get shareFindPeople => 'Trova persone';

  @override
  String get shareFindPeopleMultiline => 'Trova\npersone';

  @override
  String get shareSent => 'Inviato';

  @override
  String get shareContactFallback => 'Contatto';

  @override
  String get shareUserFallback => 'Utente';

  @override
  String shareSendingTo(String name) {
    return 'Invio a $name';
  }

  @override
  String get shareMessageHint => 'Aggiungi un messaggio opzionale...';

  @override
  String get videoActionUnlike => 'Togli il mi piace al video';

  @override
  String get videoActionLike => 'Metti mi piace al video';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionEnableAutoAdvance => 'Attiva avanzamento automatico';

  @override
  String get videoActionDisableAutoAdvance =>
      'Disattiva avanzamento automatico';

  @override
  String get videoActionRemoveRepost => 'Rimuovi repost';

  @override
  String get videoActionRepost => 'Ripubblica video';

  @override
  String get videoActionViewComments => 'Vedi commenti';

  @override
  String get videoActionMoreOptions => 'Altre opzioni';

  @override
  String get videoActionHideSubtitles => 'Nascondi sottotitoli';

  @override
  String get videoActionShowSubtitles => 'Mostra sottotitoli';

  @override
  String videoDescriptionLoops(String count) {
    return '$count loop';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'loop',
      one: 'loop',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Non Divine';

  @override
  String get metadataBadgeHumanMade => 'Fatto da umani';

  @override
  String get metadataSoundsLabel => 'Suoni';

  @override
  String get metadataOriginalSound => 'Audio originale';

  @override
  String get metadataVerificationLabel => 'Verifica';

  @override
  String get metadataDeviceAttestation => 'Attestazione del dispositivo';

  @override
  String get metadataProofManifest => 'Manifesto di prova';

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Collaboratori';

  @override
  String get metadataInspiredByLabel => 'Ispirato da';

  @override
  String get metadataRepostedByLabel => 'Ripubblicato da';

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loop',
      one: 'Loop',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Mi piace';

  @override
  String get metadataCommentsLabel => 'Commenti';

  @override
  String get metadataRepostsLabel => 'Repost';

  @override
  String get devOptionsTitle => 'Opzioni sviluppatore';

  @override
  String get devOptionsPageLoadTimes => 'Tempi di caricamento pagina';

  @override
  String get devOptionsNoPageLoads =>
      'Ancora nessun caricamento di pagina registrato.\nNaviga nell\'app per vedere i dati sui tempi.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visibile: ${visibleMs}ms  |  Dati: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Schermate più lente';

  @override
  String get devOptionsVideoPlaybackFormat => 'Formato riproduzione video';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Cambiare ambiente?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Passare a $envName?\n\nQuesto cancellerà i dati video in cache e si riconnetterà al nuovo relay.';
  }

  @override
  String get devOptionsCancel => 'Annulla';

  @override
  String get devOptionsSwitch => 'Cambia';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Passato a $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Passato a $formatName — cache svuotata';
  }

  @override
  String get featureFlagTitle => 'Feature flag';

  @override
  String get featureFlagResetAllTooltip =>
      'Ripristina tutti i flag ai valori predefiniti';

  @override
  String get featureFlagResetToDefault => 'Ripristina predefinito';

  @override
  String get featureFlagAppRecovery => 'Ripristino app';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Se l\'app si blocca o si comporta in modo strano, prova a svuotare la cache.';

  @override
  String get featureFlagClearAllCache => 'Svuota tutta la cache';

  @override
  String get featureFlagCacheInfo => 'Info cache';

  @override
  String get featureFlagClearCacheTitle => 'Svuotare tutta la cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'Questo cancellerà tutti i dati in cache inclusi:\n• Notifiche\n• Profili utente\n• Segnalibri\n• File temporanei\n\nDovrai accedere di nuovo. Continuare?';

  @override
  String get featureFlagClearCache => 'Svuota cache';

  @override
  String get featureFlagClearingCache => 'Svuotamento cache...';

  @override
  String get featureFlagSuccess => 'Fatto';

  @override
  String get featureFlagError => 'Errore';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache svuotata con successo. Riavvia l\'app.';

  @override
  String get featureFlagClearCacheFailure =>
      'Impossibile svuotare alcuni elementi della cache. Controlla i log per i dettagli.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Informazioni cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Dimensione totale cache: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'La cache include:\n• Cronologia notifiche\n• Dati profilo utente\n• Miniature video\n• File temporanei\n• Indici del database';

  @override
  String get relaySettingsTitle => 'Relay';

  @override
  String get relaySettingsInfoTitle =>
      'Divine è un sistema aperto - tu controlli le tue connessioni';

  @override
  String get relaySettingsInfoDescription =>
      'Questi relay distribuiscono i tuoi contenuti sulla rete Nostr decentralizzata. Puoi aggiungere o rimuovere relay come preferisci.';

  @override
  String get relaySettingsLearnMoreNostr => 'Scopri di più su Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Trova relay pubblici su nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App non funzionante';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine richiede almeno un relay per caricare video, pubblicare contenuti e sincronizzare i dati.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Ripristina relay predefinito';

  @override
  String get relaySettingsAddCustomRelay => 'Aggiungi relay personalizzato';

  @override
  String get relaySettingsAddRelay => 'Aggiungi relay';

  @override
  String get relaySettingsRetry => 'Riprova';

  @override
  String get relaySettingsNoStats => 'Nessuna statistica ancora disponibile';

  @override
  String get relaySettingsConnection => 'Connessione';

  @override
  String get relaySettingsConnected => 'Connesso';

  @override
  String get relaySettingsDisconnected => 'Disconnesso';

  @override
  String get relaySettingsSessionDuration => 'Durata sessione';

  @override
  String get relaySettingsLastConnected => 'Ultima connessione';

  @override
  String get relaySettingsDisconnectedLabel => 'Disconnesso';

  @override
  String get relaySettingsReason => 'Motivo';

  @override
  String get relaySettingsActiveSubscriptions => 'Sottoscrizioni attive';

  @override
  String get relaySettingsTotalSubscriptions => 'Sottoscrizioni totali';

  @override
  String get relaySettingsEventsReceived => 'Eventi ricevuti';

  @override
  String get relaySettingsEventsSent => 'Eventi inviati';

  @override
  String get relaySettingsRequestsThisSession => 'Richieste in questa sessione';

  @override
  String get relaySettingsFailedRequests => 'Richieste fallite';

  @override
  String relaySettingsLastError(String error) {
    return 'Ultimo errore: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Caricamento info relay...';

  @override
  String get relaySettingsAboutRelay => 'Info sul relay';

  @override
  String get relaySettingsSupportedNips => 'NIP supportati';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Visita il sito';

  @override
  String get relaySettingsRemoveRelayTitle => 'Rimuovere il relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Sei sicuro di voler rimuovere questo relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Annulla';

  @override
  String get relaySettingsRemove => 'Rimuovi';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay rimosso: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay =>
      'Impossibile rimuovere il relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forzatura riconnessione relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Connesso a $count relay!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Impossibile connettersi ai relay. Controlla la connessione di rete.';

  @override
  String get relaySettingsAddRelayTitle => 'Aggiungi relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Inserisci l\'URL WebSocket del relay che vuoi aggiungere:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Sfoglia relay pubblici su nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Aggiungi';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay aggiunto: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Impossibile aggiungere il relay. Controlla l\'URL e riprova.';

  @override
  String get relaySettingsInvalidUrl =>
      'L\'URL del relay deve iniziare con wss:// o ws://';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay predefinito ripristinato: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Impossibile ripristinare il relay predefinito. Controlla la connessione di rete.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Impossibile aprire il browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Impossibile aprire il link';

  @override
  String get relayDiagnosticTitle => 'Diagnostica relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Aggiorna diagnostica';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Ultimo aggiornamento: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Stato relay';

  @override
  String get relayDiagnosticInitialized => 'Inizializzato';

  @override
  String get relayDiagnosticReady => 'Pronto';

  @override
  String get relayDiagnosticNotInitialized => 'Non inizializzato';

  @override
  String get relayDiagnosticDatabaseEvents => 'Eventi del database';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Sottoscrizioni attive';

  @override
  String get relayDiagnosticExternalRelays => 'Relay esterni';

  @override
  String get relayDiagnosticConfigured => 'Configurato';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connesso';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Eventi video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed home';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count video';
  }

  @override
  String get relayDiagnosticDiscovery => 'Scoperta';

  @override
  String get relayDiagnosticLoading => 'Caricamento';

  @override
  String get relayDiagnosticYes => 'Sì';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Test query diretta';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Connettività di rete';

  @override
  String get relayDiagnosticRunNetworkTest => 'Esegui test di rete';

  @override
  String get relayDiagnosticBlossomServer => 'Server Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testa tutti gli endpoint';

  @override
  String get relayDiagnosticStatus => 'Stato';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Errore';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL base';

  @override
  String get relayDiagnosticSummary => 'Riepilogo';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (media ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Ritesta tutto';

  @override
  String get relayDiagnosticRetrying => 'Nuovo tentativo...';

  @override
  String get relayDiagnosticRetryConnection => 'Riprova connessione';

  @override
  String get relayDiagnosticTroubleshooting => 'Risoluzione problemi';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Stato verde = connesso e funzionante\n• Stato rosso = connessione fallita\n• Se il test di rete fallisce, controlla la connessione internet\n• Se i relay sono configurati ma non connessi, tocca \"Riprova connessione\"\n• Fai uno screenshot di questa schermata per il debug';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tutti gli endpoint REST sono in salute!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Alcuni endpoint REST hanno fallito - vedi i dettagli sopra';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Trovati $count eventi video nel database';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Query fallita: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Connesso a $count relay!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Impossibile connettersi ad alcun relay';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Nuovo tentativo di connessione fallito: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Connesso e autenticato';

  @override
  String get relayDiagnosticConnectedOnly => 'Connesso';

  @override
  String get relayDiagnosticNotConnected => 'Non connesso';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Nessun relay configurato';

  @override
  String get relayDiagnosticFailed => 'Fallito';

  @override
  String get notificationSettingsTitle => 'Notifiche';

  @override
  String get notificationSettingsResetTooltip => 'Ripristina predefiniti';

  @override
  String get notificationSettingsTypes => 'Tipi di notifica';

  @override
  String get notificationSettingsLikes => 'Mi piace';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Quando qualcuno mette mi piace ai tuoi video';

  @override
  String get notificationSettingsComments => 'Commenti';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Quando qualcuno commenta i tuoi video';

  @override
  String get notificationSettingsFollows => 'Follow';

  @override
  String get notificationSettingsFollowsSubtitle => 'Quando qualcuno ti segue';

  @override
  String get notificationSettingsMentions => 'Menzioni';

  @override
  String get notificationSettingsMentionsSubtitle => 'Quando vieni menzionato';

  @override
  String get notificationSettingsReposts => 'Repost';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Quando qualcuno ripubblica i tuoi video';

  @override
  String get notificationSettingsSystem => 'Sistema';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Aggiornamenti dell\'app e messaggi di sistema';

  @override
  String get notificationSettingsPushNotificationsSection => 'Notifiche push';

  @override
  String get notificationSettingsPushNotifications => 'Notifiche push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Ricevi notifiche quando l\'app è chiusa';

  @override
  String get notificationSettingsSound => 'Suono';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Riproduci suono per le notifiche';

  @override
  String get notificationSettingsVibration => 'Vibrazione';

  @override
  String get notificationSettingsVibrationSubtitle => 'Vibra per le notifiche';

  @override
  String get notificationSettingsActions => 'Azioni';

  @override
  String get notificationSettingsMarkAllAsRead => 'Segna tutto come letto';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Segna tutte le notifiche come lette';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Tutte le notifiche segnate come lette';

  @override
  String get notificationSettingsResetToDefaults =>
      'Impostazioni ripristinate ai valori predefiniti';

  @override
  String get notificationSettingsAbout => 'Info sulle notifiche';

  @override
  String get notificationSettingsAboutDescription =>
      'Le notifiche sono alimentate dal protocollo Nostr. Gli aggiornamenti in tempo reale dipendono dalla tua connessione ai relay Nostr. Alcune notifiche potrebbero subire ritardi.';

  @override
  String get safetySettingsTitle => 'Sicurezza e privacy';

  @override
  String get safetySettingsLabel => 'IMPOSTAZIONI';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Mostra solo video ospitati su Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Nascondi i video serviti da altri host multimediali';

  @override
  String get safetySettingsModeration => 'MODERAZIONE';

  @override
  String get safetySettingsBlockedUsers => 'UTENTI BLOCCATI';

  @override
  String get safetySettingsAgeVerification => 'VERIFICA ETÀ';

  @override
  String get safetySettingsAgeConfirmation => 'Confermo di avere 18 anni o più';

  @override
  String get safetySettingsAgeRequired =>
      'Richiesto per vedere contenuti per adulti';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Servizio di moderazione ufficiale (attivo di default)';

  @override
  String get safetySettingsPeopleIFollow => 'Persone che seguo';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Iscriviti alle etichette delle persone che segui';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Aggiungi labeler personalizzato';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Inserisci npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Aggiungi labeler personalizzato';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Inserisci indirizzo npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Nessun utente bloccato';

  @override
  String get safetySettingsUnblock => 'Sblocca';

  @override
  String get safetySettingsUserUnblocked => 'Utente sbloccato';

  @override
  String get safetySettingsCancel => 'Annulla';

  @override
  String get safetySettingsAdd => 'Aggiungi';

  @override
  String get analyticsTitle => 'Statistiche creator';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostica';

  @override
  String get analyticsDiagnosticsSemanticLabel =>
      'Attiva/disattiva diagnostica';

  @override
  String get analyticsRetry => 'Riprova';

  @override
  String get analyticsUnableToLoad => 'Impossibile caricare le statistiche.';

  @override
  String get analyticsSignInRequired =>
      'Accedi per vedere le statistiche creator.';

  @override
  String get analyticsViewDataUnavailable =>
      'Le visualizzazioni al momento non sono disponibili dal relay per questi post. Mi piace/commenti/repost sono comunque accurati.';

  @override
  String get analyticsViewDataTitle => 'Dati visualizzazioni';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Aggiornato $time • I punteggi usano mi piace, commenti, repost e visualizzazioni/loop da Funnelcake quando disponibili.';
  }

  @override
  String get analyticsVideos => 'Video';

  @override
  String get analyticsViews => 'Visualizzazioni';

  @override
  String get analyticsInteractions => 'Interazioni';

  @override
  String get analyticsEngagement => 'Coinvolgimento';

  @override
  String get analyticsFollowers => 'Follower';

  @override
  String get analyticsAvgPerPost => 'Media/post';

  @override
  String get analyticsInteractionMix => 'Mix interazioni';

  @override
  String get analyticsLikes => 'Mi piace';

  @override
  String get analyticsComments => 'Commenti';

  @override
  String get analyticsReposts => 'Repost';

  @override
  String get analyticsPerformanceHighlights => 'Highlight performance';

  @override
  String get analyticsMostViewed => 'Più visto';

  @override
  String get analyticsMostDiscussed => 'Più commentato';

  @override
  String get analyticsMostReposted => 'Più ripubblicato';

  @override
  String get analyticsNoVideosYet => 'Ancora nessun video';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Dati visualizzazioni non disponibili';

  @override
  String analyticsViewsCount(String count) {
    return '$count visualizzazioni';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count commenti';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count repost';
  }

  @override
  String get analyticsTopContent => 'Contenuti top';

  @override
  String get analyticsPublishPrompt =>
      'Pubblica qualche video per vedere le classifiche.';

  @override
  String get analyticsEngagementRateExplainer =>
      'La % a destra = tasso di coinvolgimento (interazioni divise per visualizzazioni).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Il tasso di coinvolgimento richiede dati sulle visualizzazioni; i valori sono N/D finché non sono disponibili.';

  @override
  String get analyticsEngagementLabel => 'Coinvolgimento';

  @override
  String get analyticsViewsUnavailable => 'visualizzazioni non disponibili';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interazioni';
  }

  @override
  String get analyticsPostAnalytics => 'Statistiche post';

  @override
  String get analyticsOpenPost => 'Apri post';

  @override
  String get analyticsRecentDailyInteractions =>
      'Interazioni giornaliere recenti';

  @override
  String get analyticsNoActivityYet =>
      'Ancora nessuna attività in questo intervallo.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interazioni = mi piace + commenti + repost per data di post.';

  @override
  String get analyticsDailyBarExplainer =>
      'La lunghezza della barra è relativa al tuo giorno migliore in questo periodo.';

  @override
  String get analyticsAudienceSnapshot => 'Istantanea audience';

  @override
  String analyticsFollowersCount(String count) {
    return 'Follower: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Seguiti: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'I dettagli su sorgente/area geografica/tempo dell\'audience arriveranno quando Funnelcake aggiungerà gli endpoint di analytics dell\'audience.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'La curva di retention e la ripartizione del tempo di visione appariranno quando arriverà la retention per secondo/per bucket da Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Dati di retention non disponibili finché Funnelcake non restituirà le analytics di visualizzazioni+tempo di visione.';

  @override
  String get analyticsDiagnostics => 'Diagnostica';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Video totali: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Con visualizzazioni: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Senza visualizzazioni: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Idratati (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Idratati (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sorgenti: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Usa dati fixture';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Crea un nuovo account Divine';

  @override
  String get authSignInDifferentAccount => 'Accedi con un account diverso';

  @override
  String get authSignBackIn => 'Rientra';

  @override
  String get authTermsPrefix =>
      'Selezionando un\'opzione sopra, confermi di avere almeno 16 anni e accetti i ';

  @override
  String get authTermsOfService => 'Termini di servizio';

  @override
  String get authPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get authTermsAnd => ' e gli ';

  @override
  String get authSafetyStandards => 'Standard di sicurezza';

  @override
  String get authAmberNotInstalled => 'L\'app Amber non è installata';

  @override
  String get authAmberConnectionFailed => 'Impossibile connettersi con Amber';

  @override
  String get authPasswordResetSent =>
      'Se esiste un account con quell\'email, abbiamo inviato un link per reimpostare la password.';

  @override
  String get authSignInTitle => 'Accedi';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authForgotPassword => 'Password dimenticata?';

  @override
  String get authImportNostrKey => 'Importa chiave Nostr';

  @override
  String get authConnectSignerApp => 'Connettiti con un\'app signer';

  @override
  String get authSignInWithAmber => 'Accedi con Amber';

  @override
  String get authSignInOptionsTitle => 'Opzioni di accesso';

  @override
  String get authInfoEmailPasswordTitle => 'Email e password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Accedi con il tuo account Divine. Se ti sei registrato con email e password, usale qui.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Hai già un\'identità Nostr? Importa la tua chiave privata nsec da un altro client.';

  @override
  String get authInfoSignerAppTitle => 'App signer';

  @override
  String get authInfoSignerAppDescription =>
      'Connettiti usando un signer remoto compatibile NIP-46 come nsecBunker per una maggiore sicurezza della chiave.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Usa l\'app signer Amber su Android per gestire le tue chiavi Nostr in modo sicuro.';

  @override
  String get authCreateAccountTitle => 'Crea account';

  @override
  String get authBackToInviteCode => 'Torna al codice invito';

  @override
  String get authUseDivineNoBackup => 'Usa Divine senza backup';

  @override
  String get authSkipConfirmTitle => 'Un\'ultima cosa...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Sei dentro! Creeremo una chiave sicura che alimenterà il tuo account Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Senza un\'email, la tua chiave è l\'unico modo in cui Divine sa che questo account è tuo.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Puoi accedere alla tua chiave nell\'app, ma, se non sei un tipo tecnico, ti consigliamo di aggiungere un\'email e una password adesso. Rende più facile accedere e ripristinare il tuo account se perdi o resetti questo dispositivo.';

  @override
  String get authAddEmailPassword => 'Aggiungi email e password';

  @override
  String get authUseThisDeviceOnly => 'Usa solo questo dispositivo';

  @override
  String get authCompleteRegistration => 'Completa la registrazione';

  @override
  String get authVerifying => 'Verifica in corso...';

  @override
  String get authVerificationLinkSent =>
      'Abbiamo inviato un link di verifica a:';

  @override
  String get authClickVerificationLink =>
      'Clicca sul link nella tua email per\ncompletare la registrazione.';

  @override
  String get authPleaseWaitVerifying =>
      'Aspetta mentre verifichiamo la tua email...';

  @override
  String get authWaitingForVerification => 'In attesa di verifica';

  @override
  String get authOpenEmailApp => 'Apri app email';

  @override
  String get authWelcomeToDivine => 'Benvenuto su Divine!';

  @override
  String get authEmailVerified => 'La tua email è stata verificata.';

  @override
  String get authSigningYouIn => 'Accesso in corso';

  @override
  String get authErrorTitle => 'Ops.';

  @override
  String get authVerificationFailed =>
      'Non siamo riusciti a verificare la tua email.\nRiprova.';

  @override
  String get authStartOver => 'Ricomincia';

  @override
  String get authEmailVerifiedLogin =>
      'Email verificata! Accedi per continuare.';

  @override
  String get authVerificationLinkExpired =>
      'Questo link di verifica non è più valido.';

  @override
  String get authVerificationConnectionError =>
      'Impossibile verificare l\'email. Controlla la connessione e riprova.';

  @override
  String get authWaitlistConfirmTitle => 'Sei dentro!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Ti manderemo aggiornamenti a $email.\nQuando saranno disponibili altri codici invito, te li invieremo.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'L\'accesso tramite invito è temporaneamente non disponibile.';

  @override
  String get authInviteUnavailableBody =>
      'Riprova tra un momento o contatta l\'assistenza se hai bisogno di aiuto per entrare.';

  @override
  String get authTryAgain => 'Riprova';

  @override
  String get authContactSupport => 'Contatta l\'assistenza';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Impossibile aprire $email';
  }

  @override
  String get authAddInviteCode => 'Aggiungi il tuo codice invito';

  @override
  String get authInviteCodeLabel => 'Codice invito';

  @override
  String get authEnterYourCode => 'Inserisci il tuo codice';

  @override
  String get authNext => 'Avanti';

  @override
  String get authJoinWaitlist => 'Entra in lista d\'attesa';

  @override
  String get authJoinWaitlistTitle => 'Entra nella lista d\'attesa';

  @override
  String get authJoinWaitlistDescription =>
      'Condividi la tua email e ti manderemo aggiornamenti quando si aprirà l\'accesso.';

  @override
  String get authInviteAccessHelp => 'Aiuto accesso tramite invito';

  @override
  String get authGeneratingConnection => 'Generazione connessione...';

  @override
  String get authConnectedAuthenticating => 'Connesso! Autenticazione...';

  @override
  String get authConnectionTimedOut => 'Connessione scaduta';

  @override
  String get authApproveConnection =>
      'Assicurati di aver approvato la connessione nella tua app signer.';

  @override
  String get authConnectionCancelled => 'Connessione annullata';

  @override
  String get authConnectionCancelledMessage =>
      'La connessione è stata annullata.';

  @override
  String get authConnectionFailed => 'Connessione fallita';

  @override
  String get authUnknownError => 'Si è verificato un errore sconosciuto.';

  @override
  String get authUrlCopied => 'URL copiato negli appunti';

  @override
  String get authConnectToDivine => 'Connettiti a Divine';

  @override
  String get authPasteBunkerUrl => 'Incolla URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker non valido. Deve iniziare con bunker://';

  @override
  String get authScanSignerApp =>
      'Scansiona con la tua\napp signer per connetterti.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'In attesa di connessione... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copia URL';

  @override
  String get authShare => 'Condividi';

  @override
  String get authAddBunker => 'Aggiungi bunker';

  @override
  String get authCompatibleSignerApps => 'App signer compatibili';

  @override
  String get authFailedToConnect => 'Connessione fallita';

  @override
  String get authResetPasswordTitle => 'Reimposta password';

  @override
  String get authResetPasswordSubtitle =>
      'Inserisci la tua nuova password. Deve essere di almeno 8 caratteri.';

  @override
  String get authNewPasswordLabel => 'Nuova password';

  @override
  String get authPasswordTooShort =>
      'La password deve avere almeno 8 caratteri';

  @override
  String get authPasswordResetSuccess => 'Password reimpostata. Accedi.';

  @override
  String get authPasswordResetFailed => 'Reimpostazione password fallita';

  @override
  String get authUnexpectedError =>
      'Si è verificato un errore imprevisto. Riprova.';

  @override
  String get authUpdatePassword => 'Aggiorna password';

  @override
  String get authSecureAccountTitle => 'Metti al sicuro l\'account';

  @override
  String get authUnableToAccessKeys =>
      'Impossibile accedere alle tue chiavi. Riprova.';

  @override
  String get authRegistrationFailed => 'Registrazione fallita';

  @override
  String get authRegistrationComplete =>
      'Registrazione completata. Controlla la tua email.';

  @override
  String get authVerificationFailedTitle => 'Verifica fallita';

  @override
  String get authClose => 'Chiudi';

  @override
  String get authAccountSecured => 'Account messo al sicuro!';

  @override
  String get authAccountLinkedToEmail =>
      'Il tuo account è ora collegato alla tua email.';

  @override
  String get authVerifyYourEmail => 'Verifica la tua email';

  @override
  String get authClickLinkContinue =>
      'Clicca sul link nella tua email per completare la registrazione. Nel frattempo puoi continuare a usare l\'app.';

  @override
  String get authWaitingForVerificationEllipsis => 'In attesa di verifica...';

  @override
  String get authContinueToApp => 'Continua nell\'app';

  @override
  String get authResetPassword => 'Reimposta password';

  @override
  String get authResetPasswordDescription =>
      'Inserisci il tuo indirizzo email e ti manderemo un link per reimpostare la password.';

  @override
  String get authFailedToSendResetEmail =>
      'Impossibile inviare l\'email di reimpostazione.';

  @override
  String get authUnexpectedErrorShort =>
      'Si è verificato un errore imprevisto.';

  @override
  String get authSending => 'Invio...';

  @override
  String get authSendResetLink => 'Invia link di reimpostazione';

  @override
  String get authEmailSent => 'Email inviata!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Abbiamo inviato un link per reimpostare la password a $email. Clicca sul link nella tua email per aggiornare la password.';
  }

  @override
  String get authSignInButton => 'Accedi';

  @override
  String get authVerificationErrorTimeout =>
      'Verifica scaduta. Prova a registrarti di nuovo.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verifica fallita — codice di autorizzazione mancante.';

  @override
  String get authVerificationErrorPollFailed => 'Verifica fallita. Riprova.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Errore di rete durante l\'accesso. Riprova.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verifica fallita. Prova a registrarti di nuovo.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Accesso fallito. Prova ad accedere manualmente.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Quel codice invito non è più disponibile. Torna al tuo codice invito, entra nella lista d\'attesa o contatta l\'assistenza.';

  @override
  String get authInviteErrorInvalid =>
      'Quel codice invito non può essere usato adesso. Torna al tuo codice invito, entra nella lista d\'attesa o contatta l\'assistenza.';

  @override
  String get authInviteErrorTemporary =>
      'Non siamo riusciti a confermare il tuo invito in questo momento. Torna al tuo codice invito e riprova, oppure contatta l\'assistenza.';

  @override
  String get authInviteErrorUnknown =>
      'Non siamo riusciti ad attivare il tuo invito. Torna al tuo codice invito, entra nella lista d\'attesa o contatta l\'assistenza.';

  @override
  String get shareSheetSave => 'Salva';

  @override
  String get shareSheetSaveToGallery => 'Salva in galleria';

  @override
  String get shareSheetSaveWithWatermark => 'Salva con filigrana';

  @override
  String get shareSheetSaveVideo => 'Salva video';

  @override
  String get shareSheetAddToList => 'Aggiungi a lista';

  @override
  String get shareSheetCopy => 'Copia';

  @override
  String get shareSheetShareVia => 'Condividi tramite';

  @override
  String get shareSheetReport => 'Segnala';

  @override
  String get shareSheetEventJson => 'JSON evento';

  @override
  String get shareSheetEventId => 'ID evento';

  @override
  String get shareSheetMoreActions => 'Altre azioni';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Salvato nel rullino';

  @override
  String get watermarkDownloadShare => 'Condividi';

  @override
  String get watermarkDownloadDone => 'Fatto';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Accesso a Foto necessario';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Per salvare i video, consenti l\'accesso a Foto nelle Impostazioni.';

  @override
  String get watermarkDownloadOpenSettings => 'Apri impostazioni';

  @override
  String get watermarkDownloadNotNow => 'Non ora';

  @override
  String get watermarkDownloadFailed => 'Download fallito';

  @override
  String get watermarkDownloadDismiss => 'Ignora';

  @override
  String get watermarkDownloadStageDownloading => 'Download video';

  @override
  String get watermarkDownloadStageWatermarking => 'Aggiunta filigrana';

  @override
  String get watermarkDownloadStageSaving => 'Salvataggio nel rullino';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Recupero del video dalla rete...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Applicazione della filigrana Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Salvataggio del video con filigrana nel tuo rullino...';

  @override
  String get uploadProgressVideoUpload => 'Caricamento video';

  @override
  String get uploadProgressPause => 'Metti in pausa';

  @override
  String get uploadProgressResume => 'Riprendi';

  @override
  String get uploadProgressGoBack => 'Indietro';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Riprova ($count rimanenti)';
  }

  @override
  String get uploadProgressDelete => 'Elimina';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}g fa';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}h fa';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}m fa';
  }

  @override
  String get uploadProgressJustNow => 'Proprio ora';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Caricamento $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'In pausa $percent%';
  }

  @override
  String get badgeExplanationClose => 'Chiudi';

  @override
  String get badgeExplanationOriginalVineArchive => 'Archivio Vine originale';

  @override
  String get badgeExplanationCameraProof => 'Prova fotocamera';

  @override
  String get badgeExplanationAuthenticitySignals => 'Segnali di autenticità';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Questo video è un Vine originale recuperato dall\'Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Prima che Vine chiudesse nel 2017, ArchiveTeam e l\'Internet Archive hanno lavorato per preservare milioni di Vine per i posteri. Questo contenuto fa parte di quello sforzo storico di preservazione.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Statistiche originali: $loops loop';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Scopri di più sulla preservazione dell\'archivio Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'Scopri di più sulla verifica Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Scopri di più sui segnali di autenticità di Divine';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Ispeziona con lo strumento ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Ispeziona dettagli multimediali';

  @override
  String get badgeExplanationProofmodeVerified =>
      'L\'autenticità di questo video è verificata usando la tecnologia Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Questo video è ospitato su Divine e il rilevamento IA indica che è probabilmente fatto da umani, ma non include dati crittografici di verifica della fotocamera.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'Il rilevamento IA indica che questo video è probabilmente fatto da umani, anche se non include dati crittografici di verifica della fotocamera.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Questo video è ospitato su Divine, ma non include ancora dati crittografici di verifica della fotocamera.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Questo video è ospitato fuori da Divine e non include dati crittografici di verifica della fotocamera.';

  @override
  String get badgeExplanationDeviceAttestation =>
      'Attestazione del dispositivo';

  @override
  String get badgeExplanationPgpSignature => 'Firma PGP';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Manifesto di prova';

  @override
  String get badgeExplanationAiDetection => 'Rilevamento IA';

  @override
  String get badgeExplanationAiNotScanned => 'Scan IA: non ancora eseguito';

  @override
  String get badgeExplanationNoScanResults =>
      'Ancora nessun risultato di scansione disponibile.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Controlla se generato da IA';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% di probabilità che sia generato da IA';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Scansionato da: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verificato da un moderatore umano';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platinum: attestazione hardware del dispositivo, firme crittografiche, Content Credentials (C2PA) e scan IA conferma origine umana.';

  @override
  String get badgeExplanationVerificationGold =>
      'Gold: catturato su un dispositivo reale con attestazione hardware, firme crittografiche e Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Silver: le firme crittografiche dimostrano che questo video non è stato alterato dalla registrazione.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze: sono presenti firme di metadati di base.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Silver: lo scan IA conferma che questo video è probabilmente creato da umani.';

  @override
  String get badgeExplanationNoVerification =>
      'Nessun dato di verifica disponibile per questo video.';

  @override
  String get shareMenuTitle => 'Condividi video';

  @override
  String get shareMenuReportAiContent => 'Segnala contenuto IA';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Segnalazione rapida di contenuto sospetto generato da IA';

  @override
  String get shareMenuReportingAiContent =>
      'Segnalazione contenuto IA in corso...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Impossibile segnalare il contenuto: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Impossibile segnalare il contenuto IA: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Stato video';

  @override
  String get shareMenuViewAllLists => 'Vedi tutte le liste →';

  @override
  String get shareMenuShareWith => 'Condividi con';

  @override
  String get shareMenuShareViaOtherApps => 'Condividi con altre app';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Condividi con altre app o copia il link';

  @override
  String get shareMenuSaveToGallery => 'Salva in galleria';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Salva il video originale nel rullino';

  @override
  String get shareMenuSaveWithWatermark => 'Salva con filigrana';

  @override
  String get shareMenuSaveVideo => 'Salva video';

  @override
  String get shareMenuDownloadWithWatermark => 'Scarica con filigrana Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Salva video nel rullino';

  @override
  String get shareMenuLists => 'Liste';

  @override
  String get shareMenuAddToList => 'Aggiungi a lista';

  @override
  String get shareMenuAddToListSubtitle => 'Aggiungi alle tue liste curate';

  @override
  String get shareMenuCreateNewList => 'Crea nuova lista';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Inizia una nuova collezione curata';

  @override
  String get shareMenuRemovedFromList => 'Rimosso dalla lista';

  @override
  String get shareMenuFailedToRemoveFromList =>
      'Impossibile rimuovere dalla lista';

  @override
  String get shareMenuBookmarks => 'Segnalibri';

  @override
  String get shareMenuAddToBookmarks => 'Aggiungi ai segnalibri';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Salva per guardare dopo';

  @override
  String get shareMenuAddToBookmarkSet => 'Aggiungi al set di segnalibri';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organizza in collezioni';

  @override
  String get shareMenuFollowSets => 'Set di follow';

  @override
  String get shareMenuCreateFollowSet => 'Crea set di follow';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Inizia una nuova collezione con questo creator';

  @override
  String get shareMenuAddToFollowSet => 'Aggiungi al set di follow';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count set di follow disponibili';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Aggiunto ai segnalibri!';

  @override
  String get shareMenuFailedToAddBookmark =>
      'Impossibile aggiungere ai segnalibri';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Creata la lista \"$name\" e aggiunto il video';
  }

  @override
  String get shareMenuManageContent => 'Gestisci contenuto';

  @override
  String get shareMenuEditVideo => 'Modifica video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Aggiorna titolo, descrizione e hashtag';

  @override
  String get shareMenuDeleteVideo => 'Elimina video';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Rimuovi definitivamente questo contenuto';

  @override
  String get shareMenuVideoInTheseLists => 'Il video è in queste liste:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count video';
  }

  @override
  String get shareMenuClose => 'Chiudi';

  @override
  String get shareMenuDeleteConfirmation =>
      'Sei sicuro di voler eliminare questo video?';

  @override
  String get shareMenuDeleteWarning =>
      'Verrà inviata una richiesta di eliminazione (NIP-09) a tutti i relay. Alcuni relay potrebbero comunque conservare il contenuto.';

  @override
  String get shareMenuCancel => 'Annulla';

  @override
  String get shareMenuDelete => 'Elimina';

  @override
  String get shareMenuDeletingContent => 'Eliminazione contenuto...';

  @override
  String get shareMenuDeleteRequestSent =>
      'Richiesta di eliminazione inviata con successo';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Impossibile eliminare il contenuto: $error';
  }

  @override
  String get shareMenuFollowSetName => 'Nome set di follow';

  @override
  String get shareMenuFollowSetNameHint =>
      'es. Content creator, Musicisti, ecc.';

  @override
  String get shareMenuDescriptionOptional => 'Descrizione (opzionale)';

  @override
  String get shareMenuCreate => 'Crea';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Creato set di follow \"$name\" e aggiunto il creator';
  }

  @override
  String get shareMenuDone => 'Fatto';

  @override
  String get shareMenuEditTitle => 'Titolo';

  @override
  String get shareMenuEditTitleHint => 'Inserisci il titolo del video';

  @override
  String get shareMenuEditDescription => 'Descrizione';

  @override
  String get shareMenuEditDescriptionHint =>
      'Inserisci la descrizione del video';

  @override
  String get shareMenuEditHashtags => 'Hashtag';

  @override
  String get shareMenuEditHashtagsHint => 'hashtag, separati, da virgole';

  @override
  String get shareMenuEditMetadataNote =>
      'Nota: si possono modificare solo i metadati. Il contenuto del video non può essere cambiato.';

  @override
  String get shareMenuDeleting => 'Eliminazione...';

  @override
  String get shareMenuUpdate => 'Aggiorna';

  @override
  String get shareMenuVideoUpdated => 'Video aggiornato con successo';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Impossibile aggiornare il video: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Eliminare il video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Verrà inviata una richiesta di eliminazione ai relay. Nota: alcuni relay potrebbero avere ancora copie in cache.';

  @override
  String get shareMenuVideoDeletionRequested =>
      'Eliminazione del video richiesta';

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Impossibile eliminare il video: $error';
  }

  @override
  String get shareMenuContentLabels => 'Etichette contenuto';

  @override
  String get shareMenuAddContentLabels => 'Aggiungi etichette contenuto';

  @override
  String get shareMenuClearAll => 'Cancella tutto';

  @override
  String get shareMenuCollaborators => 'Collaboratori';

  @override
  String get shareMenuAddCollaborator => 'Aggiungi collaboratore';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Devi seguirvi a vicenda con $name per aggiungerlo come collaboratore.';
  }

  @override
  String get shareMenuLoading => 'Caricamento...';

  @override
  String get shareMenuInspiredBy => 'Ispirato da';

  @override
  String get shareMenuAddInspirationCredit => 'Aggiungi credito ispirazione';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Questo creator non può essere menzionato.';

  @override
  String get shareMenuUnknown => 'Sconosciuto';

  @override
  String get shareMenuCreateBookmarkSet => 'Crea set di segnalibri';

  @override
  String get shareMenuSetName => 'Nome set';

  @override
  String get shareMenuSetNameHint => 'es. Preferiti, Guarda dopo, ecc.';

  @override
  String get shareMenuCreateNewSet => 'Crea nuovo set';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Inizia una nuova collezione di segnalibri';

  @override
  String get shareMenuNoBookmarkSets =>
      'Ancora nessun set di segnalibri. Crea il tuo primo!';

  @override
  String get shareMenuError => 'Errore';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Impossibile caricare i set di segnalibri';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Creato \"$name\" e aggiunto il video';
  }

  @override
  String get shareMenuUseThisSound => 'Usa questo audio';

  @override
  String get shareMenuOriginalSound => 'Audio originale';

  @override
  String get authSessionExpired =>
      'La tua sessione è scaduta. Accedi di nuovo.';

  @override
  String get authSignInFailed => 'Accesso fallito. Riprova.';

  @override
  String get localeAppLanguage => 'Lingua dell\'app';

  @override
  String get localeDeviceDefault => 'Predefinita del dispositivo';

  @override
  String get localeSelectLanguage => 'Seleziona lingua';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autenticazione web non supportata in modalità sicura. Usa l\'app mobile per una gestione sicura delle chiavi.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Integrazione di autenticazione fallita: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Errore imprevisto: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Inserisci un URI bunker';

  @override
  String get webAuthConnectTitle => 'Connettiti a Divine';

  @override
  String get webAuthChooseMethod =>
      'Scegli il tuo metodo di autenticazione Nostr preferito';

  @override
  String get webAuthBrowserExtension => 'Estensione browser';

  @override
  String get webAuthRecommended => 'CONSIGLIATO';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Connettiti a un signer remoto';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Incolla dagli appunti';

  @override
  String get webAuthConnectToBunker => 'Connettiti al bunker';

  @override
  String get webAuthNewToNostr => 'Nuovo su Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Installa un\'estensione browser come Alby o nos2x per l\'esperienza più semplice, o usa nsec bunker per la firma remota sicura.';

  @override
  String get soundsTitle => 'Suoni';

  @override
  String get soundsSearchHint => 'Cerca suoni...';

  @override
  String get soundsPreviewUnavailable =>
      'Impossibile ascoltare l\'anteprima - nessun audio disponibile';

  @override
  String soundsPreviewFailed(String error) {
    return 'Impossibile riprodurre l\'anteprima: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Suoni in evidenza';

  @override
  String get soundsTrendingSounds => 'Suoni di tendenza';

  @override
  String get soundsAllSounds => 'Tutti i suoni';

  @override
  String get soundsSearchResults => 'Risultati ricerca';

  @override
  String get soundsNoSoundsAvailable => 'Nessun suono disponibile';

  @override
  String get soundsNoSoundsDescription =>
      'I suoni appariranno qui quando i creator condivideranno audio';

  @override
  String get soundsNoSoundsFound => 'Nessun suono trovato';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Prova un termine di ricerca diverso';

  @override
  String get soundsFailedToLoad => 'Impossibile caricare i suoni';

  @override
  String get soundsRetry => 'Riprova';

  @override
  String get soundsScreenLabel => 'Schermata suoni';

  @override
  String get profileTitle => 'Profilo';

  @override
  String get profileRefresh => 'Aggiorna';

  @override
  String get profileRefreshLabel => 'Aggiorna profilo';

  @override
  String get profileMoreOptions => 'Altre opzioni';

  @override
  String profileBlockedUser(String name) {
    return '$name bloccato';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name sbloccato';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Hai smesso di seguire $name';
  }

  @override
  String profileError(String error) {
    return 'Errore: $error';
  }

  @override
  String get notificationsTabAll => 'Tutte';

  @override
  String get notificationsTabLikes => 'Mi piace';

  @override
  String get notificationsTabComments => 'Commenti';

  @override
  String get notificationsTabFollows => 'Follow';

  @override
  String get notificationsTabReposts => 'Repost';

  @override
  String get notificationsFailedToLoad => 'Impossibile caricare le notifiche';

  @override
  String get notificationsRetry => 'Riprova';

  @override
  String get notificationsCheckingNew => 'controllo nuove notifiche';

  @override
  String get notificationsNoneYet => 'Ancora nessuna notifica';

  @override
  String notificationsNoneForType(String type) {
    return 'Nessuna notifica $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Quando le persone interagiranno con i tuoi contenuti, lo vedrai qui';

  @override
  String notificationsLoadingType(String type) {
    return 'Caricamento notifiche $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'Hai 1 invito da condividere con un amico!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Hai $count inviti da condividere con gli amici!';
  }

  @override
  String get notificationsVideoNotFound => 'Video non trovato';

  @override
  String get notificationsVideoUnavailable => 'Video non disponibile';

  @override
  String get notificationsFromNotification => 'Dalla notifica';

  @override
  String get feedFailedToLoadVideos => 'Impossibile caricare i video';

  @override
  String get feedRetry => 'Riprova';

  @override
  String get feedNoFollowedUsers =>
      'Nessun utente seguito.\nSegui qualcuno per vedere i suoi video qui.';

  @override
  String get feedForYouEmpty =>
      'Il tuo feed Per te è vuoto.\nEsplora i video e segui i creator per personalizzarlo.';

  @override
  String get feedFollowingEmpty =>
      'Ancora nessun video dalle persone che segui.\nTrova creator che ti piacciono e seguili.';

  @override
  String get feedLatestEmpty =>
      'Ancora nessun nuovo video.\nTorna a controllare a breve.';

  @override
  String get feedExploreVideos => 'Esplora video';

  @override
  String get feedExternalVideoSlow => 'Video esterno in caricamento lento';

  @override
  String get feedSkip => 'Salta';

  @override
  String get uploadWaitingToUpload => 'In attesa di caricamento';

  @override
  String get uploadUploadingVideo => 'Caricamento video';

  @override
  String get uploadProcessingVideo => 'Elaborazione video';

  @override
  String get uploadProcessingComplete => 'Elaborazione completata';

  @override
  String get uploadPublishedSuccessfully => 'Pubblicato con successo';

  @override
  String get uploadFailed => 'Caricamento fallito';

  @override
  String get uploadRetrying => 'Nuovo tentativo di caricamento';

  @override
  String get uploadPaused => 'Caricamento in pausa';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% completo';
  }

  @override
  String get uploadQueuedMessage => 'Il tuo video è in coda per il caricamento';

  @override
  String get uploadUploadingMessage => 'Caricamento sul server...';

  @override
  String get uploadProcessingMessage =>
      'Elaborazione del video - potrebbe volerci qualche minuto';

  @override
  String get uploadReadyToPublishMessage =>
      'Video elaborato con successo e pronto per la pubblicazione';

  @override
  String get uploadPublishedMessage => 'Video pubblicato sul tuo profilo';

  @override
  String get uploadFailedMessage => 'Caricamento fallito - riprova';

  @override
  String get uploadRetryingMessage => 'Nuovo tentativo di caricamento...';

  @override
  String get uploadPausedMessage => 'Caricamento messo in pausa dall\'utente';

  @override
  String get uploadRetryButton => 'RIPROVA';

  @override
  String uploadRetryFailed(String error) {
    return 'Nuovo tentativo di caricamento fallito: $error';
  }

  @override
  String get userSearchPrompt => 'Cerca utenti';

  @override
  String get userSearchNoResults => 'Nessun utente trovato';

  @override
  String get userSearchFailed => 'Ricerca fallita';

  @override
  String get forgotPasswordTitle => 'Reimposta password';

  @override
  String get forgotPasswordDescription =>
      'Inserisci il tuo indirizzo email e ti manderemo un link per reimpostare la password.';

  @override
  String get forgotPasswordEmailLabel => 'Indirizzo email';

  @override
  String get forgotPasswordCancel => 'Annulla';

  @override
  String get forgotPasswordSendLink => 'Invia link via email';

  @override
  String get ageVerificationContentWarning => 'Avviso sui contenuti';

  @override
  String get ageVerificationTitle => 'Verifica età';

  @override
  String get ageVerificationAdultDescription =>
      'Questo contenuto è stato segnalato come potenzialmente contenente materiale per adulti. Devi avere 18 anni o più per vederlo.';

  @override
  String get ageVerificationCreationDescription =>
      'Per usare la fotocamera e creare contenuti, devi avere almeno 16 anni.';

  @override
  String get ageVerificationAdultQuestion => 'Hai 18 anni o più?';

  @override
  String get ageVerificationCreationQuestion => 'Hai 16 anni o più?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Sì';

  @override
  String get shareLinkCopied => 'Link copiato negli appunti';

  @override
  String get shareFailedToCopy => 'Impossibile copiare il link';

  @override
  String get shareVideoSubject => 'Guarda questo video su Divine';

  @override
  String get shareFailedToShare => 'Condivisione fallita';

  @override
  String get shareVideoTitle => 'Condividi video';

  @override
  String get shareToApps => 'Condividi con app';

  @override
  String get shareToAppsSubtitle =>
      'Condividi tramite messaggistica, app social';

  @override
  String get shareCopyWebLink => 'Copia link web';

  @override
  String get shareCopyWebLinkSubtitle => 'Copia il link web condivisibile';

  @override
  String get shareCopyNostrLink => 'Copia link Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Copia il link nevent per i client Nostr';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Esplora';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profilo';

  @override
  String get navMyProfile => 'Il mio profilo';

  @override
  String get navNotifications => 'Notifiche';

  @override
  String get navOpenCamera => 'Apri fotocamera';

  @override
  String get navUnknown => 'Sconosciuto';

  @override
  String get navExploreClassics => 'Classici';

  @override
  String get navExploreNewVideos => 'Nuovi video';

  @override
  String get navExploreTrending => 'Di tendenza';

  @override
  String get navExploreForYou => 'Per te';

  @override
  String get navExploreLists => 'Liste';

  @override
  String get routeErrorTitle => 'Errore';

  @override
  String get routeInvalidHashtag => 'Hashtag non valido';

  @override
  String get routeInvalidConversationId => 'ID conversazione non valido';

  @override
  String get routeInvalidRequestId => 'ID richiesta non valido';

  @override
  String get routeInvalidListId => 'ID lista non valido';

  @override
  String get routeInvalidUserId => 'ID utente non valido';

  @override
  String get routeInvalidVideoId => 'ID video non valido';

  @override
  String get routeInvalidSoundId => 'ID audio non valido';

  @override
  String get routeInvalidCategory => 'Categoria non valida';

  @override
  String get routeNoVideosToDisplay => 'Nessun video da mostrare';

  @override
  String get routeInvalidProfileId => 'ID profilo non valido';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Centro assistenza';

  @override
  String get supportContactSupport => 'Contatta l\'assistenza';

  @override
  String get supportContactSupportSubtitle =>
      'Inizia una conversazione o vedi i messaggi passati';

  @override
  String get supportReportBug => 'Segnala un bug';

  @override
  String get supportReportBugSubtitle => 'Problemi tecnici con l\'app';

  @override
  String get supportRequestFeature => 'Richiedi una funzionalità';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggerisci un miglioramento o una nuova funzionalità';

  @override
  String get supportSaveLogs => 'Salva log';

  @override
  String get supportSaveLogsSubtitle =>
      'Esporta i log in un file per l\'invio manuale';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Domande frequenti e risposte';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Scopri di più su verifica e autenticità';

  @override
  String get supportLoginRequired => 'Accedi per contattare l\'assistenza';

  @override
  String get supportExportingLogs => 'Esportazione log...';

  @override
  String get supportExportLogsFailed => 'Esportazione log fallita';

  @override
  String get supportChatNotAvailable => 'Chat di assistenza non disponibile';

  @override
  String get supportCouldNotOpenMessages =>
      'Impossibile aprire i messaggi di assistenza';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Impossibile aprire $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Errore nell\'apertura di $pageName: $error';
  }

  @override
  String get reportTitle => 'Segnala contenuto';

  @override
  String get reportWhyReporting => 'Perché stai segnalando questo contenuto?';

  @override
  String get reportPolicyNotice =>
      'Divine agirà sulle segnalazioni di contenuti entro 24 ore rimuovendo il contenuto ed espellendo l\'utente che ha fornito il contenuto offensivo.';

  @override
  String get reportAdditionalDetails => 'Dettagli aggiuntivi (opzionali)';

  @override
  String get reportBlockUser => 'Blocca questo utente';

  @override
  String get reportCancel => 'Annulla';

  @override
  String get reportSubmit => 'Segnala';

  @override
  String get reportSelectReason =>
      'Seleziona un motivo per segnalare questo contenuto';

  @override
  String get reportReasonSpam => 'Spam o contenuto indesiderato';

  @override
  String get reportReasonHarassment => 'Molestie, bullismo o minacce';

  @override
  String get reportReasonViolence => 'Contenuto violento o estremista';

  @override
  String get reportReasonSexualContent => 'Contenuto sessuale o per adulti';

  @override
  String get reportReasonCopyright => 'Violazione del copyright';

  @override
  String get reportReasonFalseInfo => 'Informazioni false';

  @override
  String get reportReasonCsam => 'Violazione della sicurezza dei minori';

  @override
  String get reportReasonAiGenerated => 'Contenuto generato da IA';

  @override
  String get reportReasonOther => 'Altra violazione delle policy';

  @override
  String reportFailed(Object error) {
    return 'Impossibile segnalare il contenuto: $error';
  }

  @override
  String get reportReceivedTitle => 'Segnalazione ricevuta';

  @override
  String get reportReceivedThankYou =>
      'Grazie per aiutarci a mantenere Divine sicuro.';

  @override
  String get reportReceivedReviewNotice =>
      'Il nostro team esaminerà la tua segnalazione e prenderà i provvedimenti del caso. Potresti ricevere aggiornamenti tramite messaggio diretto.';

  @override
  String get reportLearnMore => 'Scopri di più';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Chiudi';

  @override
  String get listAddToList => 'Aggiungi a lista';

  @override
  String listVideoCount(int count) {
    return '$count video';
  }

  @override
  String get listNewList => 'Nuova lista';

  @override
  String get listDone => 'Fatto';

  @override
  String get listErrorLoading => 'Errore nel caricamento delle liste';

  @override
  String listRemovedFrom(String name) {
    return 'Rimosso da $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Aggiunto a $name';
  }

  @override
  String get listCreateNewList => 'Crea nuova lista';

  @override
  String get listNameLabel => 'Nome lista';

  @override
  String get listDescriptionLabel => 'Descrizione (opzionale)';

  @override
  String get listPublicList => 'Lista pubblica';

  @override
  String get listPublicListSubtitle =>
      'Altri possono seguire e vedere questa lista';

  @override
  String get listCancel => 'Annulla';

  @override
  String get listCreate => 'Crea';

  @override
  String get listCreateFailed => 'Impossibile creare la lista';

  @override
  String get keyManagementTitle => 'Chiavi Nostr';

  @override
  String get keyManagementWhatAreKeys => 'Cosa sono le chiavi Nostr?';

  @override
  String get keyManagementExplanation =>
      'La tua identità Nostr è una coppia di chiavi crittografiche:\n\n• La tua chiave pubblica (npub) è come il tuo nome utente - condividila liberamente\n• La tua chiave privata (nsec) è come la tua password - tienila segreta!\n\nLa tua nsec ti permette di accedere al tuo account su qualsiasi app Nostr.';

  @override
  String get keyManagementImportTitle => 'Importa chiave esistente';

  @override
  String get keyManagementImportSubtitle =>
      'Hai già un account Nostr? Incolla la tua chiave privata (nsec) per accedervi qui.';

  @override
  String get keyManagementImportButton => 'Importa chiave';

  @override
  String get keyManagementImportWarning =>
      'Questo sostituirà la tua chiave attuale!';

  @override
  String get keyManagementBackupTitle => 'Fai il backup della tua chiave';

  @override
  String get keyManagementBackupSubtitle =>
      'Salva la tua chiave privata (nsec) per usare il tuo account in altre app Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copia la mia chiave privata (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Non condividere mai la tua nsec con nessuno!';

  @override
  String get keyManagementPasteKey => 'Incolla la tua chiave privata';

  @override
  String get keyManagementInvalidFormat =>
      'Formato chiave non valido. Deve iniziare con \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importare questa chiave?';

  @override
  String get keyManagementConfirmImportBody =>
      'Questo sostituirà la tua identità attuale con quella importata.\n\nLa tua chiave attuale andrà persa a meno che tu non ne abbia fatto prima il backup.';

  @override
  String get keyManagementImportConfirm => 'Importa';

  @override
  String get keyManagementImportSuccess => 'Chiave importata con successo!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Impossibile importare la chiave: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Chiave privata copiata negli appunti!\n\nConservala in un posto sicuro.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Impossibile esportare la chiave: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Salvato nel rullino';

  @override
  String get saveOriginalShare => 'Condividi';

  @override
  String get saveOriginalDone => 'Fatto';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Accesso a Foto necessario';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Per salvare i video, consenti l\'accesso a Foto nelle Impostazioni.';

  @override
  String get saveOriginalOpenSettings => 'Apri impostazioni';

  @override
  String get saveOriginalNotNow => 'Non ora';

  @override
  String get cameraPermissionNotNow => 'Non ora';

  @override
  String get saveOriginalDownloadFailed => 'Download fallito';

  @override
  String get saveOriginalDismiss => 'Ignora';

  @override
  String get saveOriginalDownloadingVideo => 'Download video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Salvataggio nel rullino';

  @override
  String get saveOriginalFetchingVideo => 'Recupero del video dalla rete...';

  @override
  String get saveOriginalSavingVideo =>
      'Salvataggio del video originale nel tuo rullino...';

  @override
  String get soundTitle => 'Audio';

  @override
  String get soundOriginalSound => 'Audio originale';

  @override
  String get soundVideosUsingThisSound => 'Video che usano questo audio';

  @override
  String get soundSourceVideo => 'Video sorgente';

  @override
  String get soundNoVideosYet => 'Ancora nessun video';

  @override
  String get soundBeFirstToUse => 'Sii il primo a usare questo audio!';

  @override
  String get soundFailedToLoadVideos => 'Impossibile caricare i video';

  @override
  String get soundRetry => 'Riprova';

  @override
  String get soundVideosUnavailable => 'Video non disponibili';

  @override
  String get soundCouldNotLoadDetails =>
      'Impossibile caricare i dettagli del video';

  @override
  String get soundPreview => 'Anteprima';

  @override
  String get soundStop => 'Stop';

  @override
  String get soundUseSound => 'Usa audio';

  @override
  String get soundNoVideoCount => 'Ancora nessun video';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count video';
  }

  @override
  String get soundUnableToPreview =>
      'Impossibile ascoltare l\'anteprima - nessun audio disponibile';

  @override
  String soundPreviewFailed(Object error) {
    return 'Impossibile riprodurre l\'anteprima: $error';
  }

  @override
  String get soundViewSource => 'Vedi sorgente';

  @override
  String get soundCloseTooltip => 'Chiudi';

  @override
  String get exploreNotExploreRoute => 'Non è un percorso di esplorazione';

  @override
  String get legalTitle => 'Legale';

  @override
  String get legalTermsOfService => 'Termini di servizio';

  @override
  String get legalTermsOfServiceSubtitle => 'Termini e condizioni d\'uso';

  @override
  String get legalPrivacyPolicy => 'Informativa sulla privacy';

  @override
  String get legalPrivacyPolicySubtitle => 'Come gestiamo i tuoi dati';

  @override
  String get legalSafetyStandards => 'Standard di sicurezza';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Linee guida della community e sicurezza';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Politica su copyright e rimozioni';

  @override
  String get legalOpenSourceLicenses => 'Licenze open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Attribuzioni pacchetti di terze parti';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Impossibile aprire $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Errore nell\'apertura di $pageName: $error';
  }

  @override
  String get categoryAction => 'Azione';

  @override
  String get categoryAdventure => 'Avventura';

  @override
  String get categoryAnimals => 'Animali';

  @override
  String get categoryAnimation => 'Animazione';

  @override
  String get categoryArchitecture => 'Architettura';

  @override
  String get categoryArt => 'Arte';

  @override
  String get categoryAutomotive => 'Auto';

  @override
  String get categoryAwardShow => 'Premiazione';

  @override
  String get categoryAwards => 'Premi';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Bellezza';

  @override
  String get categoryBeverage => 'Bevande';

  @override
  String get categoryCars => 'Auto';

  @override
  String get categoryCelebration => 'Festa';

  @override
  String get categoryCelebrities => 'Celebrità';

  @override
  String get categoryCelebrity => 'Celebrità';

  @override
  String get categoryCityscape => 'Panorama urbano';

  @override
  String get categoryComedy => 'Commedia';

  @override
  String get categoryConcert => 'Concerto';

  @override
  String get categoryCooking => 'Cucina';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryCrafts => 'Fai da te';

  @override
  String get categoryCrime => 'Crimine';

  @override
  String get categoryCulture => 'Cultura';

  @override
  String get categoryDance => 'Danza';

  @override
  String get categoryDiy => 'Fai da te';

  @override
  String get categoryDrama => 'Drammatico';

  @override
  String get categoryEducation => 'Educazione';

  @override
  String get categoryEmotional => 'Emotivo';

  @override
  String get categoryEmotions => 'Emozioni';

  @override
  String get categoryEntertainment => 'Intrattenimento';

  @override
  String get categoryEvent => 'Evento';

  @override
  String get categoryFamily => 'Famiglia';

  @override
  String get categoryFans => 'Fan';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Cibo';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Arredamento';

  @override
  String get categoryGaming => 'Videogiochi';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Cura personale';

  @override
  String get categoryGuitar => 'Chitarra';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Salute';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Vacanze';

  @override
  String get categoryHome => 'Casa';

  @override
  String get categoryHomeImprovement => 'Ristrutturazione';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Ospedale';

  @override
  String get categoryHumor => 'Umorismo';

  @override
  String get categoryInteriorDesign => 'Interior design';

  @override
  String get categoryInterview => 'Intervista';

  @override
  String get categoryKids => 'Bambini';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magia';

  @override
  String get categoryMakeup => 'Trucco';

  @override
  String get categoryMedical => 'Medico';

  @override
  String get categoryMusic => 'Musica';

  @override
  String get categoryMystery => 'Mistero';

  @override
  String get categoryNature => 'Natura';

  @override
  String get categoryNews => 'Notizie';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Festa';

  @override
  String get categoryPeople => 'Persone';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Animali domestici';

  @override
  String get categoryPolitics => 'Politica';

  @override
  String get categoryPrank => 'Scherzo';

  @override
  String get categoryPranks => 'Scherzi';

  @override
  String get categoryRealityShow => 'Reality';

  @override
  String get categoryRelationship => 'Relazione';

  @override
  String get categoryRelationships => 'Relazioni';

  @override
  String get categoryRomance => 'Romantico';

  @override
  String get categorySchool => 'Scuola';

  @override
  String get categoryScienceFiction => 'Fantascienza';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboard';

  @override
  String get categorySkincare => 'Cura della pelle';

  @override
  String get categorySoccer => 'Calcio';

  @override
  String get categorySocialGathering => 'Ritrovo';

  @override
  String get categorySocialMedia => 'Social media';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Tecnologia';

  @override
  String get categoryTelevision => 'Televisione';

  @override
  String get categoryToys => 'Giocattoli';

  @override
  String get categoryTransportation => 'Trasporti';

  @override
  String get categoryTravel => 'Viaggi';

  @override
  String get categoryUrban => 'Urbano';

  @override
  String get categoryViolence => 'Violenza';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadSuccess => 'Foto profilo caricata con successo!';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName segnalato/a';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName bloccato/a';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName sbloccato/a';
  }

  @override
  String get inboxRemovedConversation => 'Conversazione rimossa';

  @override
  String get reportDialogCancel => 'Annulla';

  @override
  String get reportDialogReport => 'Segnala';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titolo: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Impossibile aggiornare l\'abbonamento: $error';
  }

  @override
  String get commonRetry => 'Riprova';

  @override
  String get commonDelete => 'Elimina';

  @override
  String get commonCancel => 'Annulla';

  @override
  String get videoMetadataTags => 'Tag';

  @override
  String get videoMetadataExpiration => 'Scadenza';

  @override
  String get videoMetadataContentWarnings => 'Avvisi sui contenuti';

  @override
  String get videoEditorLayers => 'Livelli';

  @override
  String get videoEditorStickers => 'Sticker';

  @override
  String get trendingTitle => 'Di tendenza';

  @override
  String get proofmodeCheckAiGenerated => 'Verifica se generato dall\'IA';

  @override
  String get libraryDeleteConfirm => 'Elimina';

  @override
  String get libraryWebUnavailableHeadline => 'La libreria è nell’app mobile';

  @override
  String get libraryWebUnavailableDescription =>
      'Bozze e clip sono salvate sul dispositivo: apri Divine sul telefono per gestirle.';

  @override
  String get libraryTabDrafts => 'Bozze';

  @override
  String get libraryTabClips => 'Clip';

  @override
  String get librarySaveToCameraRollTooltip => 'Salva nel rullino';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Elimina clip selezionate';

  @override
  String get libraryDeleteClipsTitle => 'Elimina clip';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# clip selezionate',
      one: '# clip selezionata',
    );
    return 'Vuoi eliminare $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Azione irreversibile. I file video verranno rimossi definitivamente dal dispositivo.';

  @override
  String get libraryPreparingVideo => 'Preparazione video...';

  @override
  String get libraryCreateVideo => 'Crea video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip',
      one: '1 clip',
    );
    return '$_temp0 salvati in $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount salvati, $failureCount non riusciti';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permesso negato per $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clip eliminati',
      one: '1 clip eliminato',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Impossibile caricare le bozze';

  @override
  String get libraryCouldNotLoadClips => 'Impossibile caricare le clip';

  @override
  String get libraryOpenErrorDescription =>
      'Qualcosa è andato storto aprendo la libreria. Riprova.';

  @override
  String get libraryNoDraftsYetTitle => 'Ancora nessuna bozza';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'I video salvati come bozza appariranno qui';

  @override
  String get libraryNoClipsYetTitle => 'Ancora nessuna clip';

  @override
  String get libraryNoClipsYetSubtitle => 'Le clip registrate appariranno qui';

  @override
  String get libraryDraftDeletedSnackbar => 'Bozza eliminata';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Eliminazione bozza non riuscita';

  @override
  String get libraryDraftActionPost => 'Pubblica';

  @override
  String get libraryDraftActionEdit => 'Modifica';

  @override
  String get libraryDraftActionDelete => 'Elimina bozza';

  @override
  String get libraryDeleteDraftTitle => 'Elimina bozza';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Vuoi eliminare \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Elimina clip';

  @override
  String get libraryDeleteClipMessage => 'Eliminare questa clip?';

  @override
  String get libraryClipSelectionTitle => 'Clip';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Ancora ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Aggiungi';

  @override
  String get libraryRecordVideo => 'Registra un video';

  @override
  String get routerInvalidCreator => 'Creatore non valido';

  @override
  String get routerInvalidHashtagRoute => 'Percorso hashtag non valido';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Impossibile caricare i video';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Impossibile caricare le categorie';

  @override
  String get notificationFollowBack => 'Segui a tua volta';

  @override
  String get followingFailedToLoadList =>
      'Impossibile caricare la lista dei seguiti';

  @override
  String get followersFailedToLoadList =>
      'Impossibile caricare la lista dei follower';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Impossibile salvare le impostazioni: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Impossibile aggiornare l\'impostazione di crosspost';

  @override
  String get invitesTitle => 'Invita amici';

  @override
  String get searchSomethingWentWrong => 'Qualcosa è andato storto';

  @override
  String get searchTryAgain => 'Riprova';

  @override
  String get searchForLists => 'Cerca liste';

  @override
  String get searchFindCuratedVideoLists => 'Trova liste di video curate';

  @override
  String get cameraAgeRestriction =>
      'Devi avere almeno 16 anni per creare contenuti';

  @override
  String get featureRequestCancel => 'Annulla';

  @override
  String keyImportError(String error) {
    return 'Errore: $error';
  }

  @override
  String get timeNow => 'ora';

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
    return '${count}g';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}set';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}me';
  }

  @override
  String timeShortYears(int count) {
    return '${count}a';
  }

  @override
  String get timeVerboseNow => 'Ora';

  @override
  String timeAgo(String time) {
    return '$time fa';
  }

  @override
  String get timeToday => 'Oggi';

  @override
  String get timeYesterday => 'Ieri';

  @override
  String get timeJustNow => 'adesso';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min fa';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h fa';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}g fa';
  }

  @override
  String get draftTimeJustNow => 'Adesso';

  @override
  String get contentLabelNudity => 'Nudità';

  @override
  String get contentLabelSexualContent => 'Contenuto sessuale';

  @override
  String get contentLabelPornography => 'Pornografia';

  @override
  String get contentLabelGraphicMedia => 'Contenuto esplicito';

  @override
  String get contentLabelViolence => 'Violenza';

  @override
  String get contentLabelSelfHarm => 'Autolesionismo/Suicidio';

  @override
  String get contentLabelDrugUse => 'Uso di droghe';

  @override
  String get contentLabelAlcohol => 'Alcol';

  @override
  String get contentLabelTobacco => 'Tabacco/Fumo';

  @override
  String get contentLabelGambling => 'Gioco d\'azzardo';

  @override
  String get contentLabelProfanity => 'Linguaggio volgare';

  @override
  String get contentLabelHateSpeech => 'Incitamento all\'odio';

  @override
  String get contentLabelHarassment => 'Molestie';

  @override
  String get contentLabelFlashingLights => 'Luci lampeggianti';

  @override
  String get contentLabelAiGenerated => 'Generato dall\'IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Truffa/Frode';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Fuorviante';

  @override
  String get contentLabelSensitiveContent => 'Contenuto sensibile';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName ha messo like al tuo video';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName ha commentato il tuo video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName ha iniziato a seguirti';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName ti ha menzionato';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName ha ricondiviso il tuo video';
  }

  @override
  String get draftUntitled => 'Senza titolo';

  @override
  String get contentWarningNone => 'Nessuno';

  @override
  String get textBackgroundNone => 'Nessuno';

  @override
  String get textBackgroundSolid => 'Pieno';

  @override
  String get textBackgroundHighlight => 'Evidenziato';

  @override
  String get textBackgroundTransparent => 'Trasparente';

  @override
  String get textAlignLeft => 'Sinistra';

  @override
  String get textAlignRight => 'Destra';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'La fotocamera non è ancora supportata sul web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'L\'acquisizione e la registrazione con fotocamera non sono ancora disponibili nella versione web.';

  @override
  String get cameraPermissionBackToFeed => 'Torna al feed';

  @override
  String get cameraPermissionErrorTitle => 'Errore di autorizzazione';

  @override
  String get cameraPermissionErrorDescription =>
      'Si è verificato un errore durante il controllo delle autorizzazioni.';

  @override
  String get cameraPermissionRetry => 'Riprova';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Consenti accesso a fotocamera e microfono';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Questo ti consente di registrare e modificare video direttamente nell\'app, niente di più.';

  @override
  String get cameraPermissionContinue => 'Continua';

  @override
  String get cameraPermissionGoToSettings => 'Vai alle impostazioni';

  @override
  String get metadataCaptionsLabel => 'Captions';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Captions enabled for all videos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Captions disabled for all videos';
}
