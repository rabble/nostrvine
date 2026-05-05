// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Réglages';

  @override
  String get settingsSecureAccount => 'Sécurise ton compte';

  @override
  String get settingsSessionExpired => 'Session expirée';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Reconnecte-toi pour récupérer l\'accès complet';

  @override
  String get settingsCreatorAnalytics => 'Stats créateur';

  @override
  String get settingsSupportCenter => 'Centre d\'aide';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsContentPreferences => 'Préférences de contenu';

  @override
  String get settingsModerationControls => 'Contrôles de modération';

  @override
  String get settingsBlueskyPublishing => 'Publication Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gère la diffusion croisée vers Bluesky';

  @override
  String get settingsNostrSettings => 'Réglages Nostr';

  @override
  String get settingsIntegratedApps => 'Apps intégrées';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps tierces approuvées qui tournent dans Divine';

  @override
  String get settingsExperimentalFeatures => 'Fonctionnalités expérimentales';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Des réglages qui peuvent avoir des ratés—essaie-les si tu es curieux.';

  @override
  String get settingsLegal => 'Mentions légales';

  @override
  String get settingsIntegrationPermissions => 'Permissions d\'intégration';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Vérifie et révoque les approbations d\'intégration enregistrées';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Le mode développeur est déjà activé';

  @override
  String get settingsDeveloperModeEnabled => 'Mode développeur activé !';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Encore $count appuis pour activer le mode développeur';
  }

  @override
  String get settingsInvites => 'Invitations';

  @override
  String get settingsSwitchAccount => 'Changer de compte';

  @override
  String get settingsAddAnotherAccount => 'Ajouter un autre compte';

  @override
  String get settingsUnsavedDraftsTitle => 'Brouillons non enregistrés';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'brouillons',
      one: 'brouillon',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 's',
      one: '',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tes brouillons',
      one: 'ton brouillon',
    );
    String _temp3 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les',
      one: 'le',
    );
    return 'Tu as $count $_temp0 non enregistré$_temp1. Changer de compte va garder $_temp2, mais tu voudras peut-être $_temp3 publier ou relire d\'\'abord.';
  }

  @override
  String get settingsCancel => 'Annuler';

  @override
  String get settingsSwitchAnyway => 'Changer quand même';

  @override
  String get settingsAppVersionLabel => 'Version de l\'app';

  @override
  String get settingsAppLanguage => 'Langue de l\'app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (par défaut)';
  }

  @override
  String get settingsAppLanguageTitle => 'Langue de l\'app';

  @override
  String get settingsAppLanguageDescription =>
      'Choisis la langue de l\'interface';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Utiliser la langue de l\'appareil';

  @override
  String get settingsGeneralTitle => 'Réglages généraux';

  @override
  String get settingsContentSafetyTitle => 'Contenu et sécurité';

  @override
  String get generalSettingsSectionIntegrations => 'INTÉGRATIONS';

  @override
  String get generalSettingsSectionViewing => 'VISIONNAGE';

  @override
  String get generalSettingsSectionCreating => 'CRÉATION';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get generalSettingsClosedCaptions => 'Sous-titres';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Affiche les sous-titres quand les vidéos en proposent';

  @override
  String get generalSettingsVideoShape => 'Format des vidéos';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Vidéos carrées uniquement';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait => 'Carré et portrait';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Affiche tout le mix des vidéos Divine';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Garde les fils dans le format carré classique';

  @override
  String get contentPreferencesTitle => 'Préférences de contenu';

  @override
  String get contentPreferencesContentFilters => 'Filtres de contenu';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gère les filtres d\'avertissement';

  @override
  String get contentPreferencesContentLanguage => 'Langue du contenu';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (par défaut)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Étiquette tes vidéos avec une langue pour que les spectateurs puissent filtrer le contenu.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Utiliser la langue de l\'appareil (par défaut)';

  @override
  String get contentPreferencesAudioSharing => 'Rendre mon audio réutilisable';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Quand c\'est activé, les autres peuvent utiliser l\'audio de tes vidéos';

  @override
  String get contentPreferencesAccountLabels => 'Étiquettes de compte';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-étiquette ton contenu';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Étiquettes de contenu du compte';

  @override
  String get contentPreferencesClearAll => 'Tout effacer';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Sélectionne tout ce qui s\'applique à ton compte';

  @override
  String get contentPreferencesDoneNoLabels => 'Terminé (aucune étiquette)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Terminé ($count sélectionnées)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Périphérique d\'entrée audio';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (recommandé)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Sélectionne automatiquement le meilleur micro';

  @override
  String get contentPreferencesSelectAudioInput =>
      'Sélectionner l\'entrée audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Micro inconnu';

  @override
  String get contentFiltersAdultContent => 'CONTENU POUR ADULTES';

  @override
  String get contentFiltersViolenceGore => 'VIOLENCE ET HORREUR';

  @override
  String get contentFiltersSubstances => 'SUBSTANCES';

  @override
  String get contentFiltersOther => 'AUTRE';

  @override
  String get contentFiltersAgeGateMessage =>
      'Vérifie ton âge dans Sécurité et confidentialité pour débloquer les filtres de contenu pour adultes';

  @override
  String get contentFiltersShow => 'Afficher';

  @override
  String get contentFiltersWarn => 'Avertir';

  @override
  String get contentFiltersFilterOut => 'Filtrer';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Ce compte n\'est pas disponible';

  @override
  String profileErrorPrefix(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get profileInvalidId => 'ID de profil invalide';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Découvre $displayName sur Divine !\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName sur Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Échec du partage du profil : $error';
  }

  @override
  String get profileEditProfile => 'Modifier le profil';

  @override
  String get profileCreatorAnalytics => 'Stats créateur';

  @override
  String get profileShareProfile => 'Partager le profil';

  @override
  String get profileCopyPublicKey => 'Copier la clé publique (npub)';

  @override
  String get profileGetEmbedCode => 'Obtenir le code d\'intégration';

  @override
  String get profilePublicKeyCopied => 'Clé publique copiée';

  @override
  String get profileEmbedCodeCopied => 'Code d\'intégration copié';

  @override
  String get profileRefreshTooltip => 'Actualiser';

  @override
  String get profileRefreshSemanticLabel => 'Actualiser le profil';

  @override
  String get profileMoreTooltip => 'Plus';

  @override
  String get profileMoreSemanticLabel => 'Plus d\'options';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Fermer l\'avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Fermer l\'aperçu de l\'avatar';

  @override
  String get profileFollowingLabel => 'Abonné';

  @override
  String get profileFollowLabel => 'Suivre';

  @override
  String get profileBlockedLabel => 'Bloqué';

  @override
  String get profileFollowersLabel => 'Abonnés';

  @override
  String get profileFollowingStatLabel => 'Abonnements';

  @override
  String get profileVideosLabel => 'Vidéos';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count utilisateurs';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Bloquer $displayName ?';
  }

  @override
  String get profileBlockExplanation => 'Quand tu bloques quelqu\'un :';

  @override
  String get profileBlockBulletHidePosts =>
      'Ses posts n\'apparaîtront plus dans tes fils.';

  @override
  String get profileBlockBulletCantView =>
      'Il ne pourra plus voir ton profil, te suivre, ou voir tes posts.';

  @override
  String get profileBlockBulletNoNotify =>
      'Il ne sera pas prévenu du changement.';

  @override
  String get profileBlockBulletYouCanView =>
      'Tu pourras toujours voir son profil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Bloquer $displayName';
  }

  @override
  String get profileCancelButton => 'Annuler';

  @override
  String get profileLearnMore => 'En savoir plus';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Débloquer $displayName ?';
  }

  @override
  String get profileUnblockExplanation =>
      'Quand tu débloques cet utilisateur :';

  @override
  String get profileUnblockBulletShowPosts =>
      'Ses posts réapparaîtront dans tes fils.';

  @override
  String get profileUnblockBulletCanView =>
      'Il pourra voir ton profil, te suivre, et voir tes posts.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Il ne sera pas prévenu du changement.';

  @override
  String get profileLearnMoreAt => 'En savoir plus sur ';

  @override
  String get profileUnblockButton => 'Débloquer';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Ne plus suivre $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Bloquer $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Débloquer $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Ajouter $displayName à une liste';
  }

  @override
  String get profileUserBlockedTitle => 'Utilisateur bloqué';

  @override
  String get profileUserBlockedContent =>
      'Tu ne verras plus son contenu dans tes fils.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Tu peux le débloquer n\'importe quand depuis son profil ou dans Réglages > Sécurité.';

  @override
  String get profileCloseButton => 'Fermer';

  @override
  String get profileNoCollabsTitle => 'Pas encore de collabs';

  @override
  String get profileCollabsOwnEmpty =>
      'Les vidéos que tu co-réalises apparaîtront ici';

  @override
  String get profileCollabsOtherEmpty =>
      'Les vidéos qu\'il co-réalise apparaîtront ici';

  @override
  String get profileErrorLoadingCollabs => 'Erreur de chargement des collabs';

  @override
  String get profileNoSavedVideosTitle => 'Rien d\'enregistré pour l\'instant';

  @override
  String get profileSavedOwnEmpty =>
      'Mets des vidéos en favoris depuis le menu de partage et elles apparaîtront ici.';

  @override
  String get profileErrorLoadingSaved =>
      'Erreur de chargement des vidéos enregistrées';

  @override
  String get profileNoCommentsOwnTitle => 'Pas encore de commentaires';

  @override
  String get profileNoCommentsOtherTitle => 'Aucun commentaire';

  @override
  String get profileCommentsOwnEmpty =>
      'Tes commentaires et réponses apparaîtront ici';

  @override
  String get profileCommentsOtherEmpty =>
      'Ses commentaires et réponses apparaîtront ici';

  @override
  String get profileErrorLoadingComments =>
      'Erreur de chargement des commentaires';

  @override
  String get profileVideoRepliesSection => 'Réponses vidéo';

  @override
  String get profileCommentsSection => 'Commentaires';

  @override
  String get profileEditLabel => 'Modifier';

  @override
  String get profileLibraryLabel => 'Bibliothèque';

  @override
  String get profileNoLikedVideosTitle => 'Pas encore de vidéos aimées';

  @override
  String get profileLikedOwnEmpty => 'Les vidéos que tu aimes apparaîtront ici';

  @override
  String get profileLikedOtherEmpty =>
      'Les vidéos qu\'il aime apparaîtront ici';

  @override
  String get profileErrorLoadingLiked =>
      'Erreur de chargement des vidéos aimées';

  @override
  String get profileNoRepostsTitle => 'Pas encore de reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Les vidéos que tu reposte apparaîtront ici';

  @override
  String get profileRepostsOtherEmpty =>
      'Les vidéos qu\'il reposte apparaîtront ici';

  @override
  String get profileErrorLoadingReposts =>
      'Erreur de chargement des vidéos repostées';

  @override
  String get profileLoadingTitle => 'Chargement du profil...';

  @override
  String get profileLoadingSubtitle => 'Ça peut prendre un moment';

  @override
  String get profileLoadingVideos => 'Chargement des vidéos...';

  @override
  String get profileNoVideosTitle => 'Pas encore de vidéos';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Partage ta première vidéo pour la voir ici';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Cet utilisateur n\'a pas encore partagé de vidéos';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniature vidéo $number';
  }

  @override
  String get profileShowMore => 'Afficher plus';

  @override
  String get profileShowLess => 'Afficher moins';

  @override
  String get profileCompleteYourProfile => 'Complète ton profil';

  @override
  String get profileCompleteSubtitle =>
      'Ajoute ton nom, ta bio et ta photo pour commencer';

  @override
  String get profileSetUpButton => 'Configurer';

  @override
  String get profileVerifyingEmail => 'Vérification de l\'e-mail...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Regarde $email pour le lien de vérification';
  }

  @override
  String get profileWaitingForVerification =>
      'En attente de la vérification de l\'e-mail';

  @override
  String get profileVerificationFailed => 'Vérification échouée';

  @override
  String get profilePleaseTryAgain => 'Réessaie';

  @override
  String get profileSecureYourAccount => 'Sécurise ton compte';

  @override
  String get profileSecureSubtitle =>
      'Ajoute un e-mail et un mot de passe pour récupérer ton compte sur n\'importe quel appareil';

  @override
  String get profileRetryButton => 'Réessayer';

  @override
  String get profileRegisterButton => 'S\'inscrire';

  @override
  String get profileSessionExpired => 'Session expirée';

  @override
  String get profileSignInToRestore =>
      'Reconnecte-toi pour récupérer l\'accès complet';

  @override
  String get profileSignInButton => 'Se connecter';

  @override
  String get profileMaybeLaterLabel => 'Plus tard';

  @override
  String get profileSecurePrimaryButton => 'Ajouter e-mail et mot de passe';

  @override
  String get profileCompletePrimaryButton => 'Mettre à jour ton profil';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Likes';

  @override
  String get profileMyLibraryLabel => 'Ma bibliothèque';

  @override
  String get profileMessageLabel => 'Message';

  @override
  String get profileUserFallback => 'utilisateur';

  @override
  String get profileDismissTooltip => 'Fermer';

  @override
  String get profileLinkCopied => 'Lien du profil copié';

  @override
  String get profileSetupEditProfileTitle => 'Modifier le profil';

  @override
  String get profileSetupBackLabel => 'Retour';

  @override
  String get profileSetupAboutNostr => 'À propos de Nostr';

  @override
  String get profileSetupProfilePublished => 'Profil publié avec succès !';

  @override
  String get profileSetupCreateNewProfile => 'Créer un nouveau profil ?';

  @override
  String get profileSetupNoExistingProfile =>
      'On n\'a pas trouvé de profil existant sur tes relays. Publier va créer un nouveau profil. Continuer ?';

  @override
  String get profileSetupPublishButton => 'Publier';

  @override
  String get profileSetupUsernameTaken =>
      'Ce nom d\'utilisateur vient d\'être pris. Choisis-en un autre.';

  @override
  String get profileSetupClaimFailed =>
      'Échec de la réservation du nom d\'utilisateur. Réessaie.';

  @override
  String get profileSetupPublishFailed =>
      'Échec de la publication du profil. Réessaie.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Impossible d\'accéder au réseau. Vérifie ta connexion et réessaie.';

  @override
  String get profileSetupRetryLabel => 'Réessayer';

  @override
  String get profileSetupDisplayNameLabel => 'Nom affiché';

  @override
  String get profileSetupDisplayNameHint =>
      'Comment veux-tu qu\'on te reconnaisse ?';

  @override
  String get profileSetupDisplayNameHelper =>
      'N\'importe quel nom ou pseudo. Pas besoin qu\'il soit unique.';

  @override
  String get profileSetupDisplayNameRequired => 'Entre un nom affiché';

  @override
  String get profileSetupBioLabel => 'Bio (facultatif)';

  @override
  String get profileSetupBioHint => 'Parle un peu de toi...';

  @override
  String get profileSetupPublicKeyLabel => 'Clé publique (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nom d\'utilisateur (facultatif)';

  @override
  String get profileSetupUsernameHint => 'nomdutilisateur';

  @override
  String get profileSetupUsernameHelper => 'Ton identité unique sur Divine';

  @override
  String get profileSetupProfileColorLabel => 'Couleur du profil (facultatif)';

  @override
  String get profileSetupSaveButton => 'Enregistrer';

  @override
  String get profileSetupSavingButton => 'Enregistrement...';

  @override
  String get profileSetupImageUrlTitle => 'Ajouter une URL d\'image';

  @override
  String get profileSetupPictureUploaded =>
      'Photo de profil envoyée avec succès !';

  @override
  String get profileSetupImageSelectionFailed =>
      'Échec de la sélection d\'image. Colle plutôt une URL d\'image ci-dessous.';

  @override
  String get profileSetupImagesTypeGroup => 'images';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Accès caméra échoué : $error';
  }

  @override
  String get profileSetupGotItButton => 'Compris';

  @override
  String get profileSetupUploadFailedGeneric =>
      'L\'envoi de l\'image a échoué. Réessaie plus tard.';

  @override
  String get profileSetupUploadNetworkError =>
      'Erreur réseau : vérifie ta connexion internet et réessaie.';

  @override
  String get profileSetupUploadAuthError =>
      'Erreur d\'authentification : déconnecte-toi et reconnecte-toi.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Fichier trop gros : choisis une image plus petite (10 Mo max).';

  @override
  String get profileSetupUploadServerError =>
      'L\'envoi de l\'image a échoué. Nos serveurs sont temporairement indisponibles. Réessaie dans un instant.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'L\'envoi d\'une photo de profil n\'est pas encore disponible sur le web. Utilise l\'app iOS ou Android, ou colle l\'URL d\'une image.';

  @override
  String get profileSetupUsernameChecking =>
      'Vérification de la disponibilité...';

  @override
  String get profileSetupUsernameAvailable => 'Nom d\'utilisateur disponible !';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Nom d\'utilisateur déjà pris';

  @override
  String get profileSetupUsernameReserved => 'Nom d\'utilisateur réservé';

  @override
  String get profileSetupContactSupport => 'Contacter le support';

  @override
  String get profileSetupCheckAgain => 'Vérifier à nouveau';

  @override
  String get profileSetupUsernameBurned =>
      'Ce nom d\'utilisateur n\'est plus disponible';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Seuls les lettres, chiffres et tirets sont autorisés';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Le nom d\'utilisateur doit faire 3 à 20 caractères';

  @override
  String get profileSetupUsernameNetworkError =>
      'Impossible de vérifier la disponibilité. Réessaie.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Format de nom d\'utilisateur invalide';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Échec de la vérification de disponibilité';

  @override
  String get profileSetupUsernameReservedTitle => 'Nom d\'utilisateur réservé';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'Le nom $username est réservé. Dis-nous pourquoi il devrait être à toi.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'ex. c\'est mon nom de marque, mon nom de scène, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Déjà contacté le support ? Appuie sur « Vérifier à nouveau » pour voir s\'il t\'a été libéré.';

  @override
  String get profileSetupSupportRequestSent =>
      'Demande envoyée au support ! On te répondra bientôt.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Impossible d\'ouvrir l\'e-mail. Envoie à : names@divine.video';

  @override
  String get profileSetupSendRequest => 'Envoyer la demande';

  @override
  String get profileSetupPickColorTitle => 'Choisis une couleur';

  @override
  String get profileSetupSelectButton => 'Sélectionner';

  @override
  String get profileSetupUseOwnNip05 => 'Utiliser ta propre adresse NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Adresse NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Format NIP-05 invalide (ex. : nom@domaine.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Utilise le champ nom d\'utilisateur ci-dessus pour divine.video';

  @override
  String get profileSetupProfilePicturePreview =>
      'Aperçu de la photo de profil';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine tourne sur Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocole ouvert résistant à la censure qui permet aux gens de communiquer en ligne sans dépendre d\'une seule entreprise ou plateforme. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Quand tu t\'inscris sur Divine, tu reçois une nouvelle identité Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr te permet de posséder ton contenu, ton identité et ton graphe social, que tu peux utiliser dans plein d\'apps. Résultat : plus de choix, moins de dépendance, et un internet social plus sain et résilient.';

  @override
  String get nostrInfoLingo => 'Le jargon Nostr :';

  @override
  String get nostrInfoNpubLabel => 'npub :';

  @override
  String get nostrInfoNpubDescription =>
      ' Ton adresse Nostr publique. Tu peux la partager sans risque et les autres pourront te trouver, te suivre ou t\'envoyer des messages dans toutes les apps Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec :';

  @override
  String get nostrInfoNsecDescription =>
      ' Ta clé privée et preuve de propriété. Elle donne le contrôle complet de ton identité Nostr, donc ';

  @override
  String get nostrInfoNsecWarning => 'garde-la toujours secrète !';

  @override
  String get nostrInfoUsernameLabel => 'Nom d\'utilisateur Nostr :';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nom lisible (comme @nom.divine.video) qui pointe vers ton npub. Ça rend ton identité Nostr plus facile à reconnaître et vérifier, un peu comme une adresse e-mail.';

  @override
  String get nostrInfoLearnMoreAt => 'En savoir plus sur ';

  @override
  String get nostrInfoGotIt => 'Compris !';

  @override
  String get profileTabRefreshTooltip => 'Actualiser';

  @override
  String get videoGridRefreshLabel => 'Recherche de plus de vidéos';

  @override
  String get videoGridOptionsTitle => 'Options de la vidéo';

  @override
  String get videoGridEditVideo => 'Modifier la vidéo';

  @override
  String get videoGridEditVideoSubtitle =>
      'Mettre à jour titre, description et hashtags';

  @override
  String get videoGridDeleteVideo => 'Supprimer la vidéo';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Retirer ce contenu définitivement';

  @override
  String get videoGridDeleteConfirmTitle => 'Supprimer la vidéo';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Tu es sûr de vouloir supprimer cette vidéo ?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Cette action envoie une requête de suppression (NIP-09) à tous les relays. Certains relays peuvent garder le contenu.';

  @override
  String get videoGridDeleteCancel => 'Annuler';

  @override
  String get videoGridDeleteConfirm => 'Supprimer';

  @override
  String get videoGridDeletingContent => 'Suppression du contenu...';

  @override
  String get videoGridDeleteSuccess =>
      'Demande de suppression envoyée avec succès';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String get exploreTabClassics => 'Classiques';

  @override
  String get exploreTabNew => 'Nouveautés';

  @override
  String get exploreTabPopular => 'Populaire';

  @override
  String get exploreTabCategories => 'Catégories';

  @override
  String get exploreTabForYou => 'Pour toi';

  @override
  String get exploreTabLists => 'Listes';

  @override
  String get exploreTabIntegratedApps => 'Apps intégrées';

  @override
  String get exploreNoVideosAvailable => 'Aucune vidéo disponible';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Erreur : $error';
  }

  @override
  String get exploreDiscoverLists => 'Découvrir les listes';

  @override
  String get exploreAboutLists => 'À propos des listes';

  @override
  String get exploreAboutListsDescription =>
      'Les listes t\'aident à organiser et curater le contenu Divine de deux façons :';

  @override
  String get explorePeopleLists => 'Listes de personnes';

  @override
  String get explorePeopleListsDescription =>
      'Suis des groupes de créateurs et vois leurs dernières vidéos';

  @override
  String get exploreVideoLists => 'Listes de vidéos';

  @override
  String get exploreVideoListsDescription =>
      'Crée des playlists de tes vidéos préférées à regarder plus tard';

  @override
  String get exploreMyLists => 'Mes listes';

  @override
  String get exploreSubscribedLists => 'Listes abonnées';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Erreur de chargement des listes : $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nouvelles vidéos',
      one: '1 nouvelle vidéo',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'nouvelles vidéos',
      one: 'nouvelle vidéo',
    );
    return 'Charger $count $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Chargement de la vidéo...';

  @override
  String get videoPlayerPlayVideo => 'Lire la vidéo';

  @override
  String get videoPlayerMute => 'Couper le son de la vidéo';

  @override
  String get videoPlayerUnmute => 'Réactiver le son de la vidéo';

  @override
  String get videoPlayerEditVideo => 'Modifier la vidéo';

  @override
  String get videoPlayerEditVideoTooltip => 'Modifier la vidéo';

  @override
  String get contentWarningLabel => 'Avertissement de contenu';

  @override
  String get contentWarningNudity => 'Nudité';

  @override
  String get contentWarningSexualContent => 'Contenu sexuel';

  @override
  String get contentWarningPornography => 'Pornographie';

  @override
  String get contentWarningGraphicMedia => 'Médias choquants';

  @override
  String get contentWarningViolence => 'Violence';

  @override
  String get contentWarningSelfHarm => 'Automutilation';

  @override
  String get contentWarningDrugUse => 'Usage de drogues';

  @override
  String get contentWarningAlcohol => 'Alcool';

  @override
  String get contentWarningTobacco => 'Tabac';

  @override
  String get contentWarningGambling => 'Jeux d\'argent';

  @override
  String get contentWarningProfanity => 'Langage grossier';

  @override
  String get contentWarningFlashingLights => 'Lumières clignotantes';

  @override
  String get contentWarningAiGenerated => 'Généré par IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Contenu sensible';

  @override
  String get contentWarningDescNudity =>
      'Contient de la nudité ou de la nudité partielle';

  @override
  String get contentWarningDescSexual => 'Contient du contenu sexuel';

  @override
  String get contentWarningDescPorn =>
      'Contient du contenu pornographique explicite';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contient des images choquantes ou dérangeantes';

  @override
  String get contentWarningDescViolence => 'Contient du contenu violent';

  @override
  String get contentWarningDescSelfHarm =>
      'Contient des références à l\'automutilation';

  @override
  String get contentWarningDescDrugs => 'Contient du contenu lié aux drogues';

  @override
  String get contentWarningDescAlcohol => 'Contient du contenu lié à l\'alcool';

  @override
  String get contentWarningDescTobacco => 'Contient du contenu lié au tabac';

  @override
  String get contentWarningDescGambling =>
      'Contient du contenu lié aux jeux d\'argent';

  @override
  String get contentWarningDescProfanity => 'Contient un langage fort';

  @override
  String get contentWarningDescFlashingLights =>
      'Contient des lumières clignotantes (avertissement photosensibilité)';

  @override
  String get contentWarningDescAiGenerated => 'Ce contenu a été généré par IA';

  @override
  String get contentWarningDescSpoiler => 'Contient des spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'Le créateur a marqué ça comme sensible';

  @override
  String get contentWarningDescDefault => 'Le créateur a signalé ce contenu';

  @override
  String get contentWarningDetailsTitle => 'Avertissements de contenu';

  @override
  String get contentWarningDetailsSubtitle =>
      'Le créateur a appliqué ces étiquettes :';

  @override
  String get contentWarningManageFilters => 'Gérer les filtres de contenu';

  @override
  String get contentWarningViewAnyway => 'Voir quand même';

  @override
  String get contentWarningReportContentTooltip => 'Signaler le contenu';

  @override
  String get contentWarningBlockUserTooltip => 'Bloquer l\'utilisateur';

  @override
  String get contentWarningBlockedTitle => 'Contenu bloqué';

  @override
  String get contentWarningBlockedPolicy =>
      'Ce contenu a été bloqué pour violation des règles.';

  @override
  String get contentWarningNoticeTitle => 'Avertissement de contenu';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Contenu potentiellement choquant';

  @override
  String get contentWarningView => 'Voir';

  @override
  String get contentWarningReportAction => 'Signaler';

  @override
  String get contentWarningHideAllLikeThis => 'Masquer tout contenu de ce type';

  @override
  String get contentWarningNoFilterYet =>
      'Pas encore de filtre enregistré pour cet avertissement.';

  @override
  String get contentWarningHiddenConfirmation =>
      'On masquera les posts comme ça désormais.';

  @override
  String get videoErrorNotFound => 'Vidéo introuvable';

  @override
  String get videoErrorNetwork => 'Erreur réseau';

  @override
  String get videoErrorTimeout => 'Délai de chargement dépassé';

  @override
  String get videoErrorFormat =>
      'Erreur de format vidéo\n(Réessaie ou utilise un autre navigateur)';

  @override
  String get videoErrorUnsupportedFormat => 'Format vidéo non supporté';

  @override
  String get videoErrorPlayback => 'Erreur de lecture vidéo';

  @override
  String get videoErrorAgeRestricted => 'Contenu réservé aux adultes';

  @override
  String get videoErrorVerifyAge => 'Vérifier l\'âge';

  @override
  String get videoErrorRetry => 'Réessayer';

  @override
  String get videoErrorContentRestricted => 'Contenu restreint';

  @override
  String get videoErrorContentRestrictedBody =>
      'Cette vidéo a été restreinte par le relay.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Vérifie ton âge pour voir cette vidéo.';

  @override
  String get videoErrorSkip => 'Passer';

  @override
  String get videoErrorVerifyAgeButton => 'Vérifier l\'âge';

  @override
  String get videoFollowButtonFollowing => 'Abonné';

  @override
  String get videoFollowButtonFollow => 'Suivre';

  @override
  String get audioAttributionOriginalSound => 'Son original';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspiré par @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'avec @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'avec @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborateurs',
      one: '1 collaborateur',
    );
    return '$_temp0. Appuie pour voir le profil.';
  }

  @override
  String get listAttributionFallback => 'Liste';

  @override
  String get shareVideoLabel => 'Partager la vidéo';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post partagé avec $recipientName';
  }

  @override
  String get shareFailedToSend => 'Échec de l\'envoi de la vidéo';

  @override
  String get shareAddedToBookmarks => 'Ajouté aux favoris';

  @override
  String get shareRemovedFromBookmarks => 'Retiré des favoris';

  @override
  String get shareFailedToAddBookmark => 'Échec de l\'ajout aux favoris';

  @override
  String get shareFailedToRemoveBookmark => 'Échec du retrait des favoris';

  @override
  String get shareActionFailed => 'Action échouée';

  @override
  String get shareWithTitle => 'Partager avec';

  @override
  String get shareFindPeople => 'Trouver des gens';

  @override
  String get shareFindPeopleMultiline => 'Trouver\ndes gens';

  @override
  String get shareSent => 'Envoyé';

  @override
  String get shareContactFallback => 'Contact';

  @override
  String get shareUserFallback => 'Utilisateur';

  @override
  String shareSendingTo(String name) {
    return 'Envoi à $name';
  }

  @override
  String get shareMessageHint => 'Ajouter un message (facultatif)...';

  @override
  String get videoActionUnlike => 'Ne plus aimer la vidéo';

  @override
  String get videoActionLike => 'Aimer la vidéo';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'J\'aime';

  @override
  String get videoActionReplyLabel => 'Répondre';

  @override
  String get videoActionRepostLabel => 'Reposter';

  @override
  String get videoActionShareLabel => 'Partager';

  @override
  String get videoActionAboutLabel => 'À propos';

  @override
  String get videoActionEnableAutoAdvance => 'Activer le passage automatique';

  @override
  String get videoActionDisableAutoAdvance =>
      'Désactiver le passage automatique';

  @override
  String get videoActionRemoveRepost => 'Supprimer le repost';

  @override
  String get videoActionRepost => 'Reposter la vidéo';

  @override
  String get videoActionViewComments => 'Voir les commentaires';

  @override
  String get videoActionMoreOptions => 'Plus d\'options';

  @override
  String get videoActionHideSubtitles => 'Masquer les sous-titres';

  @override
  String get videoActionShowSubtitles => 'Afficher les sous-titres';

  @override
  String get videoOverlayOpenMetadataFromTitle =>
      'Ouvrir les détails de la vidéo';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Ouvrir les détails de la vidéo';

  @override
  String videoDescriptionLoops(String count) {
    return '$count loops';
  }

  @override
  String videoFeedLoopCountLine(String compactCount, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'boucles',
      one: 'boucle',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'Pas Divine';

  @override
  String get metadataBadgeHumanMade => 'Fait main';

  @override
  String get metadataSoundsLabel => 'Sons';

  @override
  String get metadataOriginalSound => 'Son original';

  @override
  String get metadataVerificationLabel => 'Vérification';

  @override
  String get metadataDeviceAttestation => 'Attestation d\'appareil';

  @override
  String get metadataProofManifest => 'Manifeste de preuve';

  @override
  String get metadataCreatorLabel => 'Créateur';

  @override
  String get metadataCollaboratorsLabel => 'Collaborateurs';

  @override
  String get metadataInspiredByLabel => 'Inspiré par';

  @override
  String get metadataRepostedByLabel => 'Reposté par';

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'J\'aime';

  @override
  String get metadataCommentsLabel => 'Commentaires';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publié le $date';
  }

  @override
  String get devOptionsTitle => 'Options développeur';

  @override
  String get devOptionsPageLoadTimes => 'Temps de chargement';

  @override
  String get devOptionsNoPageLoads =>
      'Aucun chargement de page enregistré pour le moment.\nNavigue dans l\'app pour voir les données de temps.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible : ${visibleMs}ms  |  Données : ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Écrans les plus lents';

  @override
  String get devOptionsVideoPlaybackFormat => 'Format de lecture vidéo';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Changer d\'environnement ?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Passer à $envName ?\n\nCette action va effacer les données vidéo en cache et se reconnecter au nouveau relay.';
  }

  @override
  String get devOptionsCancel => 'Annuler';

  @override
  String get devOptionsSwitch => 'Changer';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Passé à $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Passé à $formatName — cache effacé';
  }

  @override
  String get featureFlagTitle => 'Indicateurs de fonctionnalité';

  @override
  String get featureFlagResetAllTooltip => 'Réinitialiser tous les indicateurs';

  @override
  String get featureFlagResetToDefault => 'Réinitialiser par défaut';

  @override
  String get featureFlagAppRecovery => 'Récupération de l\'app';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Si l\'app plante ou se comporte bizarrement, essaie de vider le cache.';

  @override
  String get featureFlagClearAllCache => 'Vider tout le cache';

  @override
  String get featureFlagCacheInfo => 'Infos cache';

  @override
  String get featureFlagClearCacheTitle => 'Vider tout le cache ?';

  @override
  String get featureFlagClearCacheMessage =>
      'Ça va effacer toutes les données en cache, y compris :\n• Notifications\n• Profils utilisateurs\n• Favoris\n• Fichiers temporaires\n\nTu devras te reconnecter. Continuer ?';

  @override
  String get featureFlagClearCache => 'Vider le cache';

  @override
  String get featureFlagClearingCache => 'Vidage du cache...';

  @override
  String get featureFlagSuccess => 'Succès';

  @override
  String get featureFlagError => 'Erreur';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache vidé avec succès. Redémarre l\'app.';

  @override
  String get featureFlagClearCacheFailure =>
      'Échec du vidage de certains éléments. Vérifie les logs pour les détails.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Informations sur le cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Taille totale du cache : $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Le cache inclut :\n• Historique des notifications\n• Données de profil utilisateur\n• Miniatures vidéo\n• Fichiers temporaires\n• Index de base de données';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine est un système ouvert - tu contrôles tes connexions';

  @override
  String get relaySettingsInfoDescription =>
      'Ces relays distribuent ton contenu sur le réseau Nostr décentralisé. Tu peux en ajouter ou en retirer comme tu veux.';

  @override
  String get relaySettingsLearnMoreNostr => 'En savoir plus sur Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Trouve des relays publics sur nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App non fonctionnelle';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine a besoin d\'au moins un relay pour charger des vidéos, publier du contenu et synchroniser les données.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Restaurer le relay par défaut';

  @override
  String get relaySettingsAddCustomRelay => 'Ajouter un relay personnalisé';

  @override
  String get relaySettingsAddRelay => 'Ajouter un relay';

  @override
  String get relaySettingsRetry => 'Réessayer';

  @override
  String get relaySettingsNoStats =>
      'Aucune statistique disponible pour le moment';

  @override
  String get relaySettingsConnection => 'Connexion';

  @override
  String get relaySettingsConnected => 'Connecté';

  @override
  String get relaySettingsDisconnected => 'Déconnecté';

  @override
  String get relaySettingsSessionDuration => 'Durée de session';

  @override
  String get relaySettingsLastConnected => 'Dernière connexion';

  @override
  String get relaySettingsDisconnectedLabel => 'Déconnecté';

  @override
  String get relaySettingsReason => 'Raison';

  @override
  String get relaySettingsActiveSubscriptions => 'Abonnements actifs';

  @override
  String get relaySettingsTotalSubscriptions => 'Total des abonnements';

  @override
  String get relaySettingsEventsReceived => 'Événements reçus';

  @override
  String get relaySettingsEventsSent => 'Événements envoyés';

  @override
  String get relaySettingsRequestsThisSession => 'Requêtes cette session';

  @override
  String get relaySettingsFailedRequests => 'Requêtes échouées';

  @override
  String relaySettingsLastError(String error) {
    return 'Dernière erreur : $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Chargement des infos du relay...';

  @override
  String get relaySettingsAboutRelay => 'À propos du relay';

  @override
  String get relaySettingsSupportedNips => 'NIPs supportés';

  @override
  String get relaySettingsSoftware => 'Logiciel';

  @override
  String get relaySettingsViewWebsite => 'Voir le site web';

  @override
  String get relaySettingsRemoveRelayTitle => 'Retirer le relay ?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Tu es sûr de vouloir retirer ce relay ?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Annuler';

  @override
  String get relaySettingsRemove => 'Retirer';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay retiré : $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Échec du retrait du relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Reconnexion forcée au relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Connecté à $count relay(s) !';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Échec de la connexion aux relays. Vérifie ta connexion réseau.';

  @override
  String get relaySettingsAddRelayTitle => 'Ajouter un relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Entre l\'URL WebSocket du relay que tu veux ajouter :';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Parcours les relays publics sur nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Ajouter';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay ajouté : $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Échec de l\'ajout du relay. Vérifie l\'URL et réessaie.';

  @override
  String get relaySettingsInvalidUrl =>
      'L\'URL du relay doit commencer par wss:// ou ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'L\'URL du relay doit utiliser wss:// (ws:// est autorisé seulement pour localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay par défaut restauré : $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Échec de la restauration du relay par défaut. Vérifie ta connexion réseau.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Impossible d\'ouvrir le navigateur';

  @override
  String get relaySettingsFailedToOpenLink => 'Échec de l\'ouverture du lien';

  @override
  String get relaySettingsExternalRelay => 'Relay externe';

  @override
  String get relaySettingsNotConnected => 'Non connecté';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Déconnecté il y a $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count abos';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count événements';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'il y a $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'Divine utilise le protocole Nostr pour la publication décentralisée. Ton contenu vit sur les relays que tu choisis, et tes clés sont ton identité.';

  @override
  String get nostrSettingsSectionNetwork => 'Réseau';

  @override
  String get nostrSettingsSectionAccount => 'Compte';

  @override
  String get nostrSettingsSectionDangerZone => 'Zone de danger';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle =>
      'Gère les connexions aux relays Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnostics relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Débogue la connectivité des relays et les soucis réseau';

  @override
  String get nostrSettingsMediaServers => 'Serveurs média';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configure les serveurs d\'upload Blossom';

  @override
  String get nostrSettingsDeveloperOptions => 'Options développeur';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Sélecteur d\'environnement et réglages de débogage';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Active des feature flags qui peuvent avoir des ratés.';

  @override
  String get nostrSettingsKeyManagement => 'Gestion des clés';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exporte, sauvegarde et restaure tes clés Nostr';

  @override
  String get nostrSettingsRemoveKeys => 'Retirer les clés de l\'appareil';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Supprime ta clé privée de cet appareil uniquement. Ton contenu reste sur les relays, mais tu auras besoin de ta sauvegarde nsec pour accéder à nouveau à ton compte.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Impossible de retirer les clés de cet appareil. Réessaie.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Échec du retrait des clés : $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Supprimer le compte et les données';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Supprime DÉFINITIVEMENT ton compte et TOUT ton contenu des relays Nostr. Ça ne peut pas être annulé.';

  @override
  String get relayDiagnosticTitle => 'Diagnostics relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Actualiser les diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Dernière actualisation : $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'État du relay';

  @override
  String get relayDiagnosticInitialized => 'Initialisé';

  @override
  String get relayDiagnosticReady => 'Prêt';

  @override
  String get relayDiagnosticNotInitialized => 'Non initialisé';

  @override
  String get relayDiagnosticDatabaseEvents => 'Événements en base';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Abonnements actifs';

  @override
  String get relayDiagnosticExternalRelays => 'Relays externes';

  @override
  String get relayDiagnosticConfigured => 'Configuré';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connecté';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Événements vidéo';

  @override
  String get relayDiagnosticHomeFeed => 'Fil d\'accueil';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count vidéos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Découverte';

  @override
  String get relayDiagnosticLoading => 'Chargement';

  @override
  String get relayDiagnosticYes => 'Oui';

  @override
  String get relayDiagnosticNo => 'Non';

  @override
  String get relayDiagnosticTestDirectQuery => 'Tester une requête directe';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Connectivité réseau';

  @override
  String get relayDiagnosticRunNetworkTest => 'Lancer un test réseau';

  @override
  String get relayDiagnosticBlossomServer => 'Serveur Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Tester tous les endpoints';

  @override
  String get relayDiagnosticStatus => 'État';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Erreur';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL de base';

  @override
  String get relayDiagnosticSummary => 'Résumé';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (moy. ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retester tout';

  @override
  String get relayDiagnosticRetrying => 'Nouvelle tentative...';

  @override
  String get relayDiagnosticRetryConnection => 'Réessayer la connexion';

  @override
  String get relayDiagnosticTroubleshooting => 'Dépannage';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Vert = Connecté et fonctionnel\n• Rouge = Connexion échouée\n• Si le test réseau échoue, vérifie ta connexion internet\n• Si les relays sont configurés mais non connectés, appuie sur « Réessayer la connexion »\n• Fais une capture d\'écran pour le débogage';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Tous les endpoints REST sont sains !';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Certains endpoints REST ont échoué - voir les détails ci-dessus';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return '$count événements vidéo trouvés en base';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Requête échouée : $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Connecté à $count relay(s) !';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Échec de la connexion aux relays';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Nouvelle tentative de connexion échouée : $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Connecté et authentifié';

  @override
  String get relayDiagnosticConnectedOnly => 'Connecté';

  @override
  String get relayDiagnosticNotConnected => 'Non connecté';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Aucun relay configuré';

  @override
  String get relayDiagnosticFailed => 'Échec';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsResetTooltip => 'Réinitialiser par défaut';

  @override
  String get notificationSettingsTypes => 'Types de notifications';

  @override
  String get notificationSettingsLikes => 'J\'aime';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Quand quelqu\'un aime tes vidéos';

  @override
  String get notificationSettingsComments => 'Commentaires';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Quand quelqu\'un commente tes vidéos';

  @override
  String get notificationSettingsFollows => 'Abonnements';

  @override
  String get notificationSettingsFollowsSubtitle => 'Quand quelqu\'un te suit';

  @override
  String get notificationSettingsMentions => 'Mentions';

  @override
  String get notificationSettingsMentionsSubtitle => 'Quand tu es mentionné';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Quand quelqu\'un reposte tes vidéos';

  @override
  String get notificationSettingsSystem => 'Système';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Mises à jour de l\'app et messages système';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Notifications push';

  @override
  String get notificationSettingsPushNotifications => 'Notifications push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Recevoir des notifications quand l\'app est fermée';

  @override
  String get notificationSettingsSound => 'Son';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Jouer un son pour les notifications';

  @override
  String get notificationSettingsVibration => 'Vibration';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Vibrer pour les notifications';

  @override
  String get notificationSettingsActions => 'Actions';

  @override
  String get notificationSettingsMarkAllAsRead => 'Tout marquer comme lu';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marquer toutes les notifications comme lues';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Toutes les notifications marquées comme lues';

  @override
  String get notificationSettingsResetToDefaults =>
      'Réglages réinitialisés par défaut';

  @override
  String get notificationSettingsAbout => 'À propos des notifications';

  @override
  String get notificationSettingsAboutDescription =>
      'Les notifications fonctionnent grâce au protocole Nostr. Les mises à jour en temps réel dépendent de ta connexion aux relays Nostr. Certaines notifications peuvent avoir du retard.';

  @override
  String get safetySettingsTitle => 'Sécurité et confidentialité';

  @override
  String get safetySettingsLabel => 'RÉGLAGES';

  @override
  String get safetySettingsWhatYouSee => 'CE QUE TU VOIS';

  @override
  String get safetySettingsWhatYouPublish => 'CE QUE TU PUBLIES';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Afficher uniquement les vidéos hébergées par Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Masquer les vidéos servies par d\'autres hébergeurs média';

  @override
  String get safetySettingsModeration => 'MODÉRATION';

  @override
  String get safetySettingsBlockedUsers => 'UTILISATEURS BLOQUÉS';

  @override
  String get safetySettingsAgeVerification => 'VÉRIFICATION D\'ÂGE';

  @override
  String get safetySettingsAgeConfirmation =>
      'Je confirme avoir 18 ans ou plus';

  @override
  String get safetySettingsAgeRequired =>
      'Requis pour voir du contenu pour adultes';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Service de modération officiel (activé par défaut)';

  @override
  String get safetySettingsPeopleIFollow => 'Les gens que je suis';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'S\'abonner aux étiquettes des gens que tu suis';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Ajouter un étiqueteur personnalisé';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Entre le npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Ajouter un étiqueteur personnalisé';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Entre l\'adresse npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Aucun utilisateur bloqué';

  @override
  String get safetySettingsUnblock => 'Débloquer';

  @override
  String get safetySettingsUserUnblocked => 'Utilisateur débloqué';

  @override
  String get safetySettingsCancel => 'Annuler';

  @override
  String get safetySettingsAdd => 'Ajouter';

  @override
  String get analyticsTitle => 'Stats créateur';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Basculer les diagnostics';

  @override
  String get analyticsRetry => 'Réessayer';

  @override
  String get analyticsUnableToLoad => 'Impossible de charger les stats.';

  @override
  String get analyticsSignInRequired =>
      'Connecte-toi pour voir les stats créateur.';

  @override
  String get analyticsViewDataUnavailable =>
      'Les vues ne sont actuellement pas disponibles depuis le relay pour ces posts. Les métriques de j\'aime/commentaires/reposts sont toujours précises.';

  @override
  String get analyticsViewDataTitle => 'Données de vues';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Mis à jour $time • Les scores utilisent j\'aime, commentaires, reposts et vues/loops depuis Funnelcake quand c\'est disponible.';
  }

  @override
  String get analyticsVideos => 'Vidéos';

  @override
  String get analyticsViews => 'Vues';

  @override
  String get analyticsInteractions => 'Interactions';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Abonnés';

  @override
  String get analyticsAvgPerPost => 'Moy./Post';

  @override
  String get analyticsInteractionMix => 'Mix d\'interactions';

  @override
  String get analyticsLikes => 'J\'aime';

  @override
  String get analyticsComments => 'Commentaires';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Points forts de performance';

  @override
  String get analyticsMostViewed => 'Plus vue';

  @override
  String get analyticsMostDiscussed => 'Plus commentée';

  @override
  String get analyticsMostReposted => 'Plus repostée';

  @override
  String get analyticsNoVideosYet => 'Pas encore de vidéos';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Données de vues indisponibles';

  @override
  String analyticsViewsCount(String count) {
    return '$count vues';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count commentaires';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top contenu';

  @override
  String get analyticsPublishPrompt =>
      'Publie quelques vidéos pour voir les classements.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% à droite = taux d\'engagement (interactions divisées par vues).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Le taux d\'engagement a besoin des données de vues ; les valeurs s\'affichent en N/D tant que les vues ne sont pas disponibles.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'vues indisponibles';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interactions';
  }

  @override
  String get analyticsPostAnalytics => 'Stats du post';

  @override
  String get analyticsOpenPost => 'Ouvrir le post';

  @override
  String get analyticsRecentDailyInteractions =>
      'Interactions quotidiennes récentes';

  @override
  String get analyticsNoActivityYet =>
      'Pas encore d\'activité sur cette période.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = j\'aime + commentaires + reposts par date de post.';

  @override
  String get analyticsDailyBarExplainer =>
      'La longueur des barres est relative à ton meilleur jour sur cette fenêtre.';

  @override
  String get analyticsAudienceSnapshot => 'Aperçu de l\'audience';

  @override
  String analyticsFollowersCount(String count) {
    return 'Abonnés : $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Abonnements : $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Les répartitions source/géo/temps de l\'audience se rempliront quand Funnelcake ajoutera les endpoints d\'analytics d\'audience.';

  @override
  String get analyticsRetention => 'Rétention';

  @override
  String get analyticsRetentionWithViews =>
      'La courbe de rétention et la répartition du temps de visionnage apparaîtront quand la rétention par seconde/par tranche arrivera de Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Données de rétention indisponibles tant que les analytics vues+temps de visionnage ne sont pas retournées par Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Vidéos totales : $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Avec vues : $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Vues manquantes : $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydraté (bulk) : $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydraté (/views) : $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sources : $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Utiliser des données fixtures';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Créer un nouveau compte Divine';

  @override
  String get authSignInDifferentAccount => 'Se connecter avec un autre compte';

  @override
  String get authSignBackIn => 'Se reconnecter';

  @override
  String get authTermsPrefix =>
      'En choisissant une option ci-dessus, tu confirmes avoir au moins 16 ans et accepter les ';

  @override
  String get authTermsOfService => 'Conditions d\'utilisation';

  @override
  String get authPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get authTermsAnd => ', et les ';

  @override
  String get authSafetyStandards => 'Normes de sécurité';

  @override
  String get authAmberNotInstalled => 'L\'app Amber n\'est pas installée';

  @override
  String get authAmberConnectionFailed => 'Échec de la connexion avec Amber';

  @override
  String get authPasswordResetSent =>
      'Si un compte existe avec cet e-mail, un lien de réinitialisation du mot de passe a été envoyé.';

  @override
  String get authSignInTitle => 'Se connecter';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Mot de passe';

  @override
  String get authConfirmPasswordLabel => 'Confirmer le mot de passe';

  @override
  String get authEmailRequired => 'L\'e-mail est obligatoire';

  @override
  String get authEmailInvalid => 'Veuillez saisir un e-mail valide';

  @override
  String get authPasswordRequired => 'Le mot de passe est obligatoire';

  @override
  String get authConfirmPasswordRequired =>
      'Veuillez confirmer votre mot de passe';

  @override
  String get authPasswordsDoNotMatch =>
      'Les mots de passe ne correspondent pas';

  @override
  String get authForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authImportNostrKey => 'Importer une clé Nostr';

  @override
  String get authConnectSignerApp => 'Se connecter avec une app de signature';

  @override
  String get authSignInWithAmber => 'Se connecter avec Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Se connecter avec une extension de navigateur';

  @override
  String get authNip07ConnectionFailed =>
      'Impossible de se connecter à votre extension de navigateur.';

  @override
  String get authNip07ExtensionNotFound =>
      'Aucune extension de navigateur trouvée. Installez Alby, nos2x ou une autre extension compatible NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Options de connexion';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail et mot de passe';

  @override
  String get authInfoEmailPasswordDescription =>
      'Connecte-toi avec ton compte Divine. Si tu t\'es inscrit avec un e-mail et un mot de passe, utilise-les ici.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Tu as déjà une identité Nostr ? Importe ta clé privée nsec depuis un autre client.';

  @override
  String get authInfoSignerAppTitle => 'App de signature';

  @override
  String get authInfoSignerAppDescription =>
      'Connecte-toi avec un signataire distant compatible NIP-46 comme nsecBunker pour une sécurité de clé renforcée.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Utilise l\'app de signature Amber sur Android pour gérer tes clés Nostr en toute sécurité.';

  @override
  String get authInfoBrowserExtensionTitle => 'Extension de navigateur';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Connectez-vous avec une extension de navigateur NIP-07 comme Alby ou nos2x. Vos clés restent dans l\'extension — Divine ne les voit jamais.';

  @override
  String get authCreateAccountTitle => 'Créer un compte';

  @override
  String get authBackToInviteCode => 'Retour au code d\'invitation';

  @override
  String get authUseDivineNoBackup => 'Utiliser Divine sans sauvegarde';

  @override
  String get authSkipConfirmTitle => 'Une dernière chose...';

  @override
  String get authSkipConfirmKeyCreated =>
      'C\'est bon ! On va créer une clé sécurisée qui anime ton compte Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Sans e-mail, ta clé est le seul moyen pour Divine de savoir que ce compte est à toi.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Tu peux accéder à ta clé dans l\'app, mais si tu n\'es pas tech, on recommande d\'ajouter un e-mail et un mot de passe maintenant. Ça rend plus simple la connexion et la récupération de ton compte si tu perds ou réinitialises cet appareil.';

  @override
  String get authAddEmailPassword => 'Ajouter e-mail et mot de passe';

  @override
  String get authUseThisDeviceOnly => 'Utiliser uniquement cet appareil';

  @override
  String get authCompleteRegistration => 'Termine ton inscription';

  @override
  String get authVerifying => 'Vérification...';

  @override
  String get authVerificationLinkSent =>
      'On a envoyé un lien de vérification à :';

  @override
  String get authClickVerificationLink =>
      'Clique sur le lien dans ton e-mail pour\nterminer ton inscription.';

  @override
  String get authPleaseWaitVerifying =>
      'Patiente pendant qu\'on vérifie ton e-mail...';

  @override
  String get authWaitingForVerification => 'En attente de vérification';

  @override
  String get authOpenEmailApp => 'Ouvrir l\'app e-mail';

  @override
  String get authWelcomeToDivine => 'Bienvenue sur Divine !';

  @override
  String get authEmailVerified => 'Ton e-mail a été vérifié.';

  @override
  String get authSigningYouIn => 'On te connecte';

  @override
  String get authErrorTitle => 'Aïe.';

  @override
  String get authVerificationFailed =>
      'On n\'a pas pu vérifier ton e-mail.\nRéessaie.';

  @override
  String get authStartOver => 'Recommencer';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail vérifié ! Connecte-toi pour continuer.';

  @override
  String get authVerificationLinkExpired =>
      'Ce lien de vérification n\'est plus valide.';

  @override
  String get authVerificationConnectionError =>
      'Impossible de vérifier l\'e-mail. Vérifie ta connexion et réessaie.';

  @override
  String get authWaitlistConfirmTitle => 'C\'est bon !';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'On partagera les mises à jour à $email.\nQuand plus de codes d\'invitation seront disponibles, on t\'en enverra.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'L\'accès par invitation est temporairement indisponible.';

  @override
  String get authInviteUnavailableBody =>
      'Réessaie dans un moment, ou contacte le support si tu as besoin d\'aide pour entrer.';

  @override
  String get authTryAgain => 'Réessayer';

  @override
  String get authContactSupport => 'Contacter le support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Impossible d\'ouvrir $email';
  }

  @override
  String get authAddInviteCode => 'Ajoute ton code d\'invitation';

  @override
  String get authInviteCodeLabel => 'Code d\'invitation';

  @override
  String get authEnterYourCode => 'Entre ton code';

  @override
  String get authNext => 'Suivant';

  @override
  String get authJoinWaitlist => 'Rejoindre la liste d\'attente';

  @override
  String get authJoinWaitlistTitle => 'Rejoindre la liste d\'attente';

  @override
  String get authJoinWaitlistDescription =>
      'Partage ton e-mail et on t\'enverra des mises à jour dès que l\'accès s\'ouvre.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Aide pour l\'accès par invitation';

  @override
  String get authGeneratingConnection => 'Génération de la connexion...';

  @override
  String get authConnectedAuthenticating => 'Connecté ! Authentification...';

  @override
  String get authConnectionTimedOut => 'Délai de connexion dépassé';

  @override
  String get authApproveConnection =>
      'Assure-toi d\'avoir approuvé la connexion dans ton app de signature.';

  @override
  String get authConnectionCancelled => 'Connexion annulée';

  @override
  String get authConnectionCancelledMessage => 'La connexion a été annulée.';

  @override
  String get authConnectionFailed => 'Échec de la connexion';

  @override
  String get authUnknownError => 'Une erreur inconnue est survenue.';

  @override
  String get authUrlCopied => 'URL copiée dans le presse-papiers';

  @override
  String get authConnectToDivine => 'Se connecter à Divine';

  @override
  String get authPasteBunkerUrl => 'Colle l\'URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker invalide. Elle doit commencer par bunker://';

  @override
  String get authScanSignerApp =>
      'Scanne avec ton\napp de signature pour te connecter.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'En attente de connexion... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copier l\'URL';

  @override
  String get authShare => 'Partager';

  @override
  String get authAddBunker => 'Ajouter bunker';

  @override
  String get authCompatibleSignerApps => 'Apps de signature compatibles';

  @override
  String get authFailedToConnect => 'Échec de la connexion';

  @override
  String get authResetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get authResetPasswordSubtitle =>
      'Entre ton nouveau mot de passe. Il doit faire au moins 8 caractères.';

  @override
  String get authNewPasswordLabel => 'Nouveau mot de passe';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmer le nouveau mot de passe';

  @override
  String get authPasswordTooShort =>
      'Le mot de passe doit faire au moins 8 caractères';

  @override
  String get authPasswordResetSuccess =>
      'Mot de passe réinitialisé avec succès. Connecte-toi.';

  @override
  String get authPasswordResetFailed =>
      'Échec de la réinitialisation du mot de passe';

  @override
  String get authUnexpectedError =>
      'Une erreur inattendue est survenue. Réessaie.';

  @override
  String get authUpdatePassword => 'Mettre à jour le mot de passe';

  @override
  String get authSecureAccountTitle => 'Sécuriser le compte';

  @override
  String get authUnableToAccessKeys =>
      'Impossible d\'accéder à tes clés. Réessaie.';

  @override
  String get authRegistrationFailed => 'Échec de l\'inscription';

  @override
  String get authRegistrationComplete =>
      'Inscription terminée. Vérifie ton e-mail.';

  @override
  String get authVerificationFailedTitle => 'Vérification échouée';

  @override
  String get authClose => 'Fermer';

  @override
  String get authAccountSecured => 'Compte sécurisé !';

  @override
  String get authAccountLinkedToEmail =>
      'Ton compte est maintenant lié à ton e-mail.';

  @override
  String get authVerifyYourEmail => 'Vérifie ton e-mail';

  @override
  String get authClickLinkContinue =>
      'Clique sur le lien dans ton e-mail pour terminer l\'inscription. Tu peux continuer à utiliser l\'app en attendant.';

  @override
  String get authWaitingForVerificationEllipsis =>
      'En attente de vérification...';

  @override
  String get authContinueToApp => 'Continuer vers l\'app';

  @override
  String get authResetPassword => 'Réinitialiser le mot de passe';

  @override
  String get authResetPasswordDescription =>
      'Entre ton adresse e-mail et on t\'enverra un lien pour réinitialiser ton mot de passe.';

  @override
  String get authFailedToSendResetEmail =>
      'Échec de l\'envoi de l\'e-mail de réinitialisation.';

  @override
  String get authUnexpectedErrorShort => 'Une erreur inattendue est survenue.';

  @override
  String get authSending => 'Envoi...';

  @override
  String get authSendResetLink => 'Envoyer le lien';

  @override
  String get authEmailSent => 'E-mail envoyé !';

  @override
  String authResetLinkSentTo(String email) {
    return 'On a envoyé un lien de réinitialisation à $email. Clique sur le lien dans ton e-mail pour mettre à jour ton mot de passe.';
  }

  @override
  String get authSignInButton => 'Se connecter';

  @override
  String get authVerificationErrorTimeout =>
      'Délai de vérification dépassé. Essaie de t\'inscrire à nouveau.';

  @override
  String get authVerificationErrorMissingCode =>
      'Vérification échouée — code d\'autorisation manquant.';

  @override
  String get authVerificationErrorPollFailed =>
      'Vérification échouée. Réessaie.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Erreur réseau pendant la connexion. Réessaie.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Vérification échouée. Essaie de t\'inscrire à nouveau.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Connexion échouée. Essaie de te connecter manuellement.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Ce code d\'invitation n\'est plus disponible. Retourne à ton code d\'invitation, rejoins la liste d\'attente, ou contacte le support.';

  @override
  String get authInviteErrorInvalid =>
      'Ce code d\'invitation ne peut pas être utilisé pour l\'instant. Retourne à ton code d\'invitation, rejoins la liste d\'attente, ou contacte le support.';

  @override
  String get authInviteErrorTemporary =>
      'On n\'a pas pu confirmer ton invitation pour l\'instant. Retourne à ton code d\'invitation et réessaie, ou contacte le support.';

  @override
  String get authInviteErrorUnknown =>
      'On n\'a pas pu activer ton invitation. Retourne à ton code d\'invitation, rejoins la liste d\'attente, ou contacte le support.';

  @override
  String get shareSheetSave => 'Enregistrer';

  @override
  String get shareSheetSaveToGallery => 'Enregistrer dans la galerie';

  @override
  String get shareSheetSaveWithWatermark => 'Enregistrer avec filigrane';

  @override
  String get shareSheetSaveVideo => 'Enregistrer la vidéo';

  @override
  String get shareSheetAddToClips => 'Ajouter aux clips';

  @override
  String get shareSheetAddedToClips => 'Ajouté aux clips';

  @override
  String get shareSheetAddToClipsFailed => 'Impossible d\'ajouter aux clips';

  @override
  String get shareSheetAddToList => 'Ajouter à une liste';

  @override
  String get shareSheetCopy => 'Copier';

  @override
  String get shareSheetShareVia => 'Partager via';

  @override
  String get shareSheetReport => 'Signaler';

  @override
  String get shareSheetEventJson => 'JSON de l\'événement';

  @override
  String get shareSheetEventId => 'ID de l\'événement';

  @override
  String get shareSheetMoreActions => 'Plus d\'actions';

  @override
  String get watermarkDownloadSavedToCameraRoll =>
      'Enregistré dans la pellicule';

  @override
  String get watermarkDownloadShare => 'Partager';

  @override
  String get watermarkDownloadDone => 'Terminé';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Accès aux Photos requis';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Pour enregistrer les vidéos, autorise l\'accès aux Photos dans les Réglages.';

  @override
  String get watermarkDownloadOpenSettings => 'Ouvrir les Réglages';

  @override
  String get watermarkDownloadNotNow => 'Pas maintenant';

  @override
  String get watermarkDownloadFailed => 'Téléchargement échoué';

  @override
  String get watermarkDownloadDismiss => 'Ignorer';

  @override
  String get watermarkDownloadStageDownloading => 'Téléchargement de la vidéo';

  @override
  String get watermarkDownloadStageWatermarking => 'Ajout du filigrane';

  @override
  String get watermarkDownloadStageSaving => 'Enregistrement dans la pellicule';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Récupération de la vidéo depuis le réseau...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Application du filigrane Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Enregistrement de la vidéo avec filigrane dans ta pellicule...';

  @override
  String get uploadProgressVideoUpload => 'Envoi de vidéo';

  @override
  String get uploadProgressPause => 'Pause';

  @override
  String get uploadProgressResume => 'Reprendre';

  @override
  String get uploadProgressGoBack => 'Retour';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Réessayer ($count restants)';
  }

  @override
  String get uploadProgressDelete => 'Supprimer';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'il y a ${count}j';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'il y a ${count}h';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'il y a ${count}m';
  }

  @override
  String get uploadProgressJustNow => 'À l\'instant';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Envoi $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'En pause $percent%';
  }

  @override
  String get badgeExplanationClose => 'Fermer';

  @override
  String get badgeExplanationOriginalVineArchive => 'Archive Vine d\'origine';

  @override
  String get badgeExplanationCameraProof => 'Preuve caméra';

  @override
  String get badgeExplanationAuthenticitySignals => 'Signaux d\'authenticité';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Cette vidéo est un Vine d\'origine récupéré depuis l\'Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Avant la fermeture de Vine en 2017, ArchiveTeam et l\'Internet Archive ont travaillé pour préserver des millions de Vines pour la postérité. Ce contenu fait partie de cet effort historique de préservation.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Stats d\'origine : $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'En savoir plus sur la préservation de l\'archive Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'En savoir plus sur la vérification Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'En savoir plus sur les signaux d\'authenticité Divine';

  @override
  String get badgeExplanationInspectProofCheck => 'Inspecter avec ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Inspecter les détails du média';

  @override
  String get badgeExplanationProofmodeVerified =>
      'L\'authenticité de cette vidéo est vérifiée avec la technologie Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Cette vidéo est hébergée sur Divine et la détection IA indique qu\'elle est probablement faite par un humain, mais elle n\'inclut pas de données cryptographiques de vérification caméra.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'La détection IA indique que cette vidéo est probablement faite par un humain, même si elle n\'inclut pas de données cryptographiques de vérification caméra.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Cette vidéo est hébergée sur Divine, mais elle n\'inclut pas encore de données cryptographiques de vérification caméra.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Cette vidéo est hébergée en dehors de Divine et n\'inclut pas de données cryptographiques de vérification caméra.';

  @override
  String get badgeExplanationDeviceAttestation => 'Attestation d\'appareil';

  @override
  String get badgeExplanationPgpSignature => 'Signature PGP';

  @override
  String get badgeExplanationC2paCredentials => 'Content Credentials C2PA';

  @override
  String get badgeExplanationProofManifest => 'Manifeste de preuve';

  @override
  String get badgeExplanationAiDetection => 'Détection IA';

  @override
  String get badgeExplanationAiNotScanned => 'Scan IA : pas encore scanné';

  @override
  String get badgeExplanationNoScanResults =>
      'Aucun résultat de scan disponible pour le moment.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Vérifier si généré par IA';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% de probabilité d\'être généré par IA';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Scanné par : $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Vérifié par un modérateur humain';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platine : attestation matérielle de l\'appareil, signatures cryptographiques, Content Credentials (C2PA), et scan IA confirmant l\'origine humaine.';

  @override
  String get badgeExplanationVerificationGold =>
      'Or : capturée sur un vrai appareil avec attestation matérielle, signatures cryptographiques et Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Argent : les signatures cryptographiques prouvent que cette vidéo n\'a pas été modifiée depuis l\'enregistrement.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze : des signatures de métadonnées basiques sont présentes.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Argent : le scan IA confirme que cette vidéo est probablement créée par un humain.';

  @override
  String get badgeExplanationNoVerification =>
      'Aucune donnée de vérification disponible pour cette vidéo.';

  @override
  String get shareMenuTitle => 'Partager la vidéo';

  @override
  String get shareMenuReportAiContent => 'Signaler contenu IA';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Signalement rapide de contenu suspecté généré par IA';

  @override
  String get shareMenuReportingAiContent => 'Signalement du contenu IA...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Échec du signalement du contenu : $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Échec du signalement du contenu IA : $error';
  }

  @override
  String get shareMenuVideoStatus => 'État de la vidéo';

  @override
  String get shareMenuViewAllLists => 'Voir toutes les listes →';

  @override
  String get shareMenuShareWith => 'Partager avec';

  @override
  String get shareMenuShareViaOtherApps => 'Partager via d\'autres apps';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Partager via d\'autres apps ou copier le lien';

  @override
  String get shareMenuSaveToGallery => 'Enregistrer dans la galerie';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Enregistrer la vidéo originale dans la pellicule';

  @override
  String get shareMenuSaveWithWatermark => 'Enregistrer avec filigrane';

  @override
  String get shareMenuSaveVideo => 'Enregistrer la vidéo';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Télécharger avec le filigrane Divine';

  @override
  String get shareMenuSaveVideoSubtitle =>
      'Enregistrer la vidéo dans la pellicule';

  @override
  String get shareMenuLists => 'Listes';

  @override
  String get shareMenuAddToList => 'Ajouter à une liste';

  @override
  String get shareMenuAddToListSubtitle => 'Ajouter à tes listes curées';

  @override
  String get shareMenuCreateNewList => 'Créer une nouvelle liste';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Démarrer une nouvelle collection curée';

  @override
  String get shareMenuRemovedFromList => 'Retiré de la liste';

  @override
  String get shareMenuFailedToRemoveFromList => 'Échec du retrait de la liste';

  @override
  String get shareMenuBookmarks => 'Favoris';

  @override
  String get shareMenuAddToBookmarks => 'Ajouter aux favoris';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Garder pour plus tard';

  @override
  String get shareMenuAddToBookmarkSet => 'Ajouter à un ensemble de favoris';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organiser en collections';

  @override
  String get shareMenuFollowSets => 'Ensembles d\'abonnements';

  @override
  String get shareMenuCreateFollowSet => 'Créer un ensemble d\'abonnements';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Démarrer une nouvelle collection avec ce créateur';

  @override
  String get shareMenuAddToFollowSet => 'Ajouter à un ensemble d\'abonnements';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count ensembles d\'abonnements disponibles';
  }

  @override
  String get peopleListsAddToList => 'Ajouter à la liste';

  @override
  String get peopleListsAddToListSubtitle =>
      'Mets ce créateur dans une de tes listes';

  @override
  String get peopleListsSheetTitle => 'Ajouter à la liste';

  @override
  String get peopleListsEmptyTitle => 'Aucune liste pour l\'instant';

  @override
  String get peopleListsEmptySubtitle =>
      'Crée une liste pour commencer à regrouper des personnes.';

  @override
  String get peopleListsCreateList => 'Créer une liste';

  @override
  String get peopleListsNewListTitle => 'Nouvelle liste';

  @override
  String get peopleListsRouteTitle => 'Liste de personnes';

  @override
  String get peopleListsListNameLabel => 'Nom de la liste';

  @override
  String get peopleListsListNameHint => 'Amis proches';

  @override
  String get peopleListsCreateButton => 'Créer';

  @override
  String get peopleListsAddPeopleTitle => 'Ajouter des personnes';

  @override
  String get peopleListsAddPeopleTooltip => 'Ajouter des personnes';

  @override
  String get peopleListsAddPeopleSemanticLabel =>
      'Ajouter des personnes à la liste';

  @override
  String get peopleListsListNotFoundTitle => 'Liste introuvable';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Liste introuvable. Elle a peut-être été supprimée.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Cette liste a peut-être été supprimée.';

  @override
  String get peopleListsNoPeopleTitle => 'Aucune personne dans cette liste';

  @override
  String get peopleListsNoPeopleSubtitle =>
      'Ajoute des personnes pour commencer';

  @override
  String get peopleListsNoVideosTitle => 'Pas encore de vidéos';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Les vidéos des membres de la liste apparaîtront ici';

  @override
  String get peopleListsNoVideosAvailable => 'Aucune vidéo disponible';

  @override
  String get peopleListsFailedToLoadVideos =>
      'Impossible de charger les vidéos';

  @override
  String get peopleListsVideoNotAvailable => 'Vidéo non disponible';

  @override
  String get peopleListsBackToGridTooltip => 'Retour à la grille';

  @override
  String get peopleListsErrorLoadingVideos =>
      'Erreur lors du chargement des vidéos';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Aucune personne disponible à ajouter.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Ajouter à $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Rechercher des personnes';

  @override
  String get peopleListsAddPeopleError =>
      'Impossible de charger les personnes. Veuillez réessayer.';

  @override
  String get peopleListsAddPeopleRetry => 'Réessayer';

  @override
  String get peopleListsAddButton => 'Ajouter';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Ajouter $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Dans $count listes',
      one: 'Dans 1 liste',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Retirer $name ?';
  }

  @override
  String get peopleListsRemoveConfirmBody =>
      'Cette personne sera retirée de cette liste.';

  @override
  String get peopleListsRemove => 'Retirer';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name retiré(e) de la liste';
  }

  @override
  String get peopleListsUndo => 'Annuler';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Profil de $name. Appui long pour retirer.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Voir le profil de $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Ajouté aux favoris !';

  @override
  String get shareMenuFailedToAddBookmark => 'Échec de l\'ajout aux favoris';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Liste « $name » créée et vidéo ajoutée';
  }

  @override
  String get shareMenuManageContent => 'Gérer le contenu';

  @override
  String get shareMenuEditVideo => 'Modifier la vidéo';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Mettre à jour titre, description et hashtags';

  @override
  String get shareMenuDeleteVideo => 'Supprimer la vidéo';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Retirer ce contenu définitivement';

  @override
  String get shareMenuDeleteWarning =>
      'Cette action envoie une requête de suppression (NIP-09) à tous les relays. Certains relays peuvent garder le contenu.';

  @override
  String get shareMenuVideoInTheseLists => 'La vidéo est dans ces listes :';

  @override
  String shareMenuVideoCount(int count) {
    return '$count vidéos';
  }

  @override
  String get shareMenuClose => 'Fermer';

  @override
  String get shareMenuDeleteConfirmation =>
      'Tu es sûr de vouloir supprimer cette vidéo ?';

  @override
  String get shareMenuCancel => 'Annuler';

  @override
  String get shareMenuDelete => 'Supprimer';

  @override
  String get shareMenuDeletingContent => 'Suppression du contenu...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Échec de la suppression du contenu : $error';
  }

  @override
  String get shareMenuDeleteRequestSent =>
      'Demande de suppression envoyée avec succès';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'La suppression n\'est pas prête. Réessaie dans un instant.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Tu peux supprimer uniquement tes propres vidéos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Reconnecte-toi, puis réessaie de supprimer.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Impossible de signer la demande de suppression. Réessaie.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Impossible de supprimer cette vidéo. Réessaie.';

  @override
  String get shareMenuFollowSetName => 'Nom de l\'ensemble d\'abonnements';

  @override
  String get shareMenuFollowSetNameHint =>
      'ex. Créateurs de contenu, Musiciens, etc.';

  @override
  String get shareMenuDescriptionOptional => 'Description (facultatif)';

  @override
  String get shareMenuCreate => 'Créer';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Ensemble d\'abonnements « $name » créé et créateur ajouté';
  }

  @override
  String get shareMenuDone => 'Terminé';

  @override
  String get shareMenuEditTitle => 'Titre';

  @override
  String get shareMenuEditTitleHint => 'Entre le titre de la vidéo';

  @override
  String get shareMenuEditDescription => 'Description';

  @override
  String get shareMenuEditDescriptionHint => 'Entre la description de la vidéo';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'hashtags, séparés, par, virgules';

  @override
  String get shareMenuEditMetadataNote =>
      'Note : seules les métadonnées peuvent être modifiées. Le contenu vidéo ne peut pas être changé.';

  @override
  String get shareMenuDeleting => 'Suppression...';

  @override
  String get shareMenuUpdate => 'Mettre à jour';

  @override
  String get shareMenuVideoUpdated => 'Vidéo mise à jour avec succès';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Échec de la mise à jour de la vidéo : $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Échec de la suppression de la vidéo : $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Supprimer la vidéo ?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Cette action envoie une requête de suppression aux relays. Note : certains relays peuvent encore avoir des copies en cache.';

  @override
  String get shareMenuVideoDeletionRequested =>
      'Suppression de la vidéo demandée';

  @override
  String get shareMenuContentLabels => 'Étiquettes de contenu';

  @override
  String get shareMenuAddContentLabels => 'Ajouter des étiquettes de contenu';

  @override
  String get shareMenuClearAll => 'Tout effacer';

  @override
  String get shareMenuCollaborators => 'Collaborateurs';

  @override
  String get shareMenuAddCollaborator => 'Ajouter un collaborateur';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Tu dois suivre mutuellement $name pour l\'ajouter comme collaborateur.';
  }

  @override
  String get shareMenuLoading => 'Chargement...';

  @override
  String get shareMenuInspiredBy => 'Inspiré par';

  @override
  String get shareMenuAddInspirationCredit =>
      'Ajouter un crédit d\'inspiration';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Ce créateur ne peut pas être référencé.';

  @override
  String get shareMenuUnknown => 'Inconnu';

  @override
  String get shareMenuCreateBookmarkSet => 'Créer un ensemble de favoris';

  @override
  String get shareMenuSetName => 'Nom de l\'ensemble';

  @override
  String get shareMenuSetNameHint => 'ex. Favoris, À regarder plus tard, etc.';

  @override
  String get shareMenuCreateNewSet => 'Créer un nouvel ensemble';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Démarrer une nouvelle collection de favoris';

  @override
  String get shareMenuNoBookmarkSets =>
      'Pas encore d\'ensembles de favoris. Crée ton premier !';

  @override
  String get shareMenuError => 'Erreur';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Échec du chargement des ensembles de favoris';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '« $name » créé et vidéo ajoutée';
  }

  @override
  String get shareMenuUseThisSound => 'Utiliser ce son';

  @override
  String get shareMenuOriginalSound => 'Son original';

  @override
  String get authSessionExpired => 'Ta session a expiré. Reconnecte-toi.';

  @override
  String get authSignInFailed => 'Échec de la connexion. Réessaie.';

  @override
  String get localeAppLanguage => 'Langue de l\'app';

  @override
  String get localeDeviceDefault => 'Par défaut';

  @override
  String get localeSelectLanguage => 'Sélectionner la langue';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Authentification web non supportée en mode sécurisé. Utilise l\'app mobile pour une gestion sécurisée des clés.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Échec de l\'intégration d\'authentification : $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Erreur inattendue : $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Entre une URI bunker';

  @override
  String get webAuthConnectTitle => 'Se connecter à Divine';

  @override
  String get webAuthChooseMethod =>
      'Choisis ta méthode d\'authentification Nostr préférée';

  @override
  String get webAuthBrowserExtension => 'Extension de navigateur';

  @override
  String get webAuthRecommended => 'RECOMMANDÉ';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner =>
      'Se connecter à un signataire distant';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Coller depuis le presse-papiers';

  @override
  String get webAuthConnectToBunker => 'Se connecter au Bunker';

  @override
  String get webAuthNewToNostr => 'Nouveau sur Nostr ?';

  @override
  String get webAuthNostrHelp =>
      'Installe une extension de navigateur comme Alby ou nos2x pour la plus simple expérience, ou utilise nsec bunker pour la signature distante sécurisée.';

  @override
  String get soundsTitle => 'Sons';

  @override
  String get soundsSearchHint => 'Rechercher des sons...';

  @override
  String get soundsPreviewUnavailable =>
      'Impossible d\'écouter l\'aperçu - aucun audio disponible';

  @override
  String soundsPreviewFailed(String error) {
    return 'Échec de la lecture de l\'aperçu : $error';
  }

  @override
  String get soundsFeaturedSounds => 'Sons à la une';

  @override
  String get soundsTrendingSounds => 'Sons tendance';

  @override
  String get soundsAllSounds => 'Tous les sons';

  @override
  String get soundsSearchResults => 'Résultats de recherche';

  @override
  String get soundsNoSoundsAvailable => 'Aucun son disponible';

  @override
  String get soundsNoSoundsDescription =>
      'Les sons apparaîtront ici quand les créateurs partageront de l\'audio';

  @override
  String get soundsNoSoundsFound => 'Aucun son trouvé';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Essaie un autre terme de recherche';

  @override
  String get soundsFailedToLoad => 'Échec du chargement des sons';

  @override
  String get soundsRetry => 'Réessayer';

  @override
  String get soundsScreenLabel => 'Écran des sons';

  @override
  String get profileTitle => 'Profil';

  @override
  String get profileRefresh => 'Actualiser';

  @override
  String get profileRefreshLabel => 'Actualiser le profil';

  @override
  String get profileMoreOptions => 'Plus d\'options';

  @override
  String profileBlockedUser(String name) {
    return '$name bloqué';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name débloqué';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Tu ne suis plus $name';
  }

  @override
  String profileError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get notificationsTabAll => 'Tout';

  @override
  String get notificationsTabLikes => 'J\'aime';

  @override
  String get notificationsTabComments => 'Commentaires';

  @override
  String get notificationsTabFollows => 'Abonnements';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad =>
      'Échec du chargement des notifications';

  @override
  String get notificationsRetry => 'Réessayer';

  @override
  String get notificationsCheckingNew =>
      'vérification des nouvelles notifications';

  @override
  String get notificationsNoneYet => 'Pas encore de notifications';

  @override
  String notificationsNoneForType(String type) {
    return 'Aucune notification $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Quand les gens interagissent avec ton contenu, tu le verras ici';

  @override
  String get notificationsUnreadPrefix => 'Notification non lue';

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Voir le profil de $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Voir les profils';

  @override
  String notificationsLoadingType(String type) {
    return 'Chargement des notifications $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'Tu as 1 invitation à partager avec un ami !';

  @override
  String notificationsInvitePlural(int count) {
    return 'Tu as $count invitations à partager avec des amis !';
  }

  @override
  String get notificationsVideoNotFound => 'Vidéo introuvable';

  @override
  String get notificationsVideoUnavailable => 'Vidéo indisponible';

  @override
  String get notificationsFromNotification => 'Depuis la notification';

  @override
  String get feedFailedToLoadVideos => 'Échec du chargement des vidéos';

  @override
  String get feedRetry => 'Réessayer';

  @override
  String get feedNoFollowedUsers =>
      'Personne suivie.\nSuis quelqu\'un pour voir ses vidéos ici.';

  @override
  String get feedForYouEmpty =>
      'Ton fil Pour toi est vide.\nExplore des vidéos et abonne-toi à des créateurs pour le personnaliser.';

  @override
  String get feedFollowingEmpty =>
      'Aucune vidéo des personnes que tu suis pour le moment.\nTrouve des créateurs que tu aimes et abonne-toi à eux.';

  @override
  String get feedLatestEmpty =>
      'Aucune nouvelle vidéo pour le moment.\nReviens bientôt.';

  @override
  String get feedExploreVideos => 'Explorer les vidéos';

  @override
  String get feedExternalVideoSlow => 'Vidéo externe lente à charger';

  @override
  String get feedSkip => 'Passer';

  @override
  String get uploadWaitingToUpload => 'En attente d\'envoi';

  @override
  String get uploadUploadingVideo => 'Envoi de la vidéo';

  @override
  String get uploadProcessingVideo => 'Traitement de la vidéo';

  @override
  String get uploadProcessingComplete => 'Traitement terminé';

  @override
  String get uploadPublishedSuccessfully => 'Publié avec succès';

  @override
  String get uploadFailed => 'Échec de l\'envoi';

  @override
  String get uploadRetrying => 'Nouvelle tentative d\'envoi';

  @override
  String get uploadPaused => 'Envoi en pause';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% terminé';
  }

  @override
  String get uploadQueuedMessage =>
      'Ta vidéo est en file d\'attente pour l\'envoi';

  @override
  String get uploadUploadingMessage => 'Envoi vers le serveur...';

  @override
  String get uploadProcessingMessage =>
      'Traitement de la vidéo - ça peut prendre quelques minutes';

  @override
  String get uploadReadyToPublishMessage =>
      'Vidéo traitée avec succès et prête à publier';

  @override
  String get uploadPublishedMessage => 'Vidéo publiée sur ton profil';

  @override
  String get uploadFailedMessage => 'Échec de l\'envoi - réessaie';

  @override
  String get uploadRetryingMessage => 'Nouvelle tentative d\'envoi...';

  @override
  String get uploadPausedMessage => 'Envoi mis en pause par l\'utilisateur';

  @override
  String get uploadRetryButton => 'RÉESSAYER';

  @override
  String uploadRetryFailed(String error) {
    return 'Échec de la nouvelle tentative d\'envoi : $error';
  }

  @override
  String get userSearchPrompt => 'Rechercher des utilisateurs';

  @override
  String get userSearchNoResults => 'Aucun utilisateur trouvé';

  @override
  String get userSearchFailed => 'Échec de la recherche';

  @override
  String get userPickerSearchByName => 'Rechercher par nom';

  @override
  String get userPickerFilterByNameHint => 'Filtrer par nom...';

  @override
  String get userPickerSearchByNameHint => 'Rechercher par nom...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name déjà ajouté';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Sélectionner $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Ton crew est là dehors';

  @override
  String get userPickerEmptyFollowListBody =>
      'Suis des personnes avec qui tu vibes. Quand elles te suivent aussi, vous pouvez collaborer.';

  @override
  String get userPickerGoBack => 'Retour';

  @override
  String get userPickerTypeNameToSearch => 'Saisis un nom pour rechercher';

  @override
  String get userPickerUnavailable =>
      'La recherche d\'utilisateurs est indisponible. Réessaie plus tard.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'La recherche a échoué. Réessaie.';

  @override
  String get forgotPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get forgotPasswordDescription =>
      'Entre ton adresse e-mail et on t\'enverra un lien pour réinitialiser ton mot de passe.';

  @override
  String get forgotPasswordEmailLabel => 'Adresse e-mail';

  @override
  String get forgotPasswordCancel => 'Annuler';

  @override
  String get forgotPasswordSendLink => 'Envoyer le lien par e-mail';

  @override
  String get ageVerificationContentWarning => 'Avertissement de contenu';

  @override
  String get ageVerificationTitle => 'Vérification d\'âge';

  @override
  String get ageVerificationAdultDescription =>
      'Ce contenu a été signalé comme pouvant contenir du matériel pour adultes. Tu dois avoir 18 ans ou plus pour le voir.';

  @override
  String get ageVerificationCreationDescription =>
      'Pour utiliser la caméra et créer du contenu, tu dois avoir au moins 16 ans.';

  @override
  String get ageVerificationAdultQuestion => 'As-tu 18 ans ou plus ?';

  @override
  String get ageVerificationCreationQuestion => 'As-tu 16 ans ou plus ?';

  @override
  String get ageVerificationNo => 'Non';

  @override
  String get ageVerificationYes => 'Oui';

  @override
  String get shareLinkCopied => 'Lien copié dans le presse-papiers';

  @override
  String get shareFailedToCopy => 'Échec de la copie du lien';

  @override
  String get shareVideoSubject => 'Découvre cette vidéo sur Divine';

  @override
  String get shareFailedToShare => 'Échec du partage';

  @override
  String get shareVideoTitle => 'Partager la vidéo';

  @override
  String get shareToApps => 'Partager vers les apps';

  @override
  String get shareToAppsSubtitle => 'Partager via messagerie, apps sociales';

  @override
  String get shareCopyWebLink => 'Copier le lien web';

  @override
  String get shareCopyWebLinkSubtitle => 'Copier le lien web partageable';

  @override
  String get shareCopyNostrLink => 'Copier le lien Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Copier le lien nevent pour les clients Nostr';

  @override
  String get navHome => 'Accueil';

  @override
  String get navExplore => 'Explorer';

  @override
  String get navInbox => 'Boîte';

  @override
  String get navProfile => 'Profil';

  @override
  String get navSearch => 'Recherche';

  @override
  String get navSearchTooltip => 'Rechercher';

  @override
  String get navMyProfile => 'Mon profil';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navOpenCamera => 'Ouvrir la caméra';

  @override
  String get navUnknown => 'Inconnu';

  @override
  String get navExploreClassics => 'Classiques';

  @override
  String get navExploreNewVideos => 'Nouvelles vidéos';

  @override
  String get navExploreTrending => 'Tendance';

  @override
  String get navExploreForYou => 'Pour toi';

  @override
  String get navExploreLists => 'Listes';

  @override
  String get routeErrorTitle => 'Erreur';

  @override
  String get routeInvalidHashtag => 'Hashtag invalide';

  @override
  String get routeInvalidConversationId => 'ID de conversation invalide';

  @override
  String get routeInvalidRequestId => 'ID de requête invalide';

  @override
  String get routeInvalidListId => 'ID de liste invalide';

  @override
  String get routeInvalidUserId => 'ID d\'utilisateur invalide';

  @override
  String get routeInvalidVideoId => 'ID de vidéo invalide';

  @override
  String get routeInvalidSoundId => 'ID de son invalide';

  @override
  String get routeInvalidCategory => 'Catégorie invalide';

  @override
  String get routeNoVideosToDisplay => 'Aucune vidéo à afficher';

  @override
  String get routeInvalidProfileId => 'ID de profil invalide';

  @override
  String get routeDefaultListName => 'Liste';

  @override
  String get supportTitle => 'Centre d\'aide';

  @override
  String get supportContactSupport => 'Contacter le support';

  @override
  String get supportContactSupportSubtitle =>
      'Démarre une conversation ou consulte les messages passés';

  @override
  String get supportReportBug => 'Signaler un bug';

  @override
  String get supportReportBugSubtitle => 'Problèmes techniques avec l\'app';

  @override
  String get supportRequestFeature => 'Demander une fonctionnalité';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggérer une amélioration ou une nouvelle fonctionnalité';

  @override
  String get supportSaveLogs => 'Sauvegarder les logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Exporter les logs vers un fichier pour envoi manuel';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Questions et réponses courantes';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'En savoir plus sur la vérification et l\'authenticité';

  @override
  String get supportLoginRequired => 'Connecte-toi pour contacter le support';

  @override
  String get supportExportingLogs => 'Exportation des logs...';

  @override
  String get supportExportLogsFailed => 'Échec de l\'exportation des logs';

  @override
  String get supportChatNotAvailable => 'Chat du support indisponible';

  @override
  String get supportCouldNotOpenMessages =>
      'Impossible d\'ouvrir les messages du support';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Impossible d\'ouvrir $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Erreur d\'ouverture de $pageName : $error';
  }

  @override
  String get reportTitle => 'Signaler le contenu';

  @override
  String get reportWhyReporting => 'Pourquoi signales-tu ce contenu ?';

  @override
  String get reportPolicyNotice =>
      'Divine agira sur les signalements de contenu dans les 24 heures en retirant le contenu et en excluant l\'utilisateur qui a fourni le contenu en infraction.';

  @override
  String get reportAdditionalDetails => 'Détails supplémentaires (facultatif)';

  @override
  String get reportBlockUser => 'Bloquer cet utilisateur';

  @override
  String get reportCancel => 'Annuler';

  @override
  String get reportSubmit => 'Signaler';

  @override
  String get reportSelectReason =>
      'Sélectionne une raison pour signaler ce contenu';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Spam ou contenu indésirable';

  @override
  String get reportReasonHarassment => 'Harcèlement, intimidation ou menaces';

  @override
  String get reportReasonViolence => 'Contenu violent ou extrémiste';

  @override
  String get reportReasonSexualContent => 'Contenu sexuel ou pour adultes';

  @override
  String get reportReasonCopyright => 'Violation de droits d\'auteur';

  @override
  String get reportReasonFalseInfo => 'Fausses informations';

  @override
  String get reportReasonCsam => 'Violation de sécurité des enfants';

  @override
  String get reportReasonAiGenerated => 'Contenu généré par IA';

  @override
  String get reportReasonOther => 'Autre violation des règles';

  @override
  String reportFailed(Object error) {
    return 'Échec du signalement du contenu : $error';
  }

  @override
  String get reportReceivedTitle => 'Signalement reçu';

  @override
  String get reportReceivedThankYou =>
      'Merci de nous aider à garder Divine sûr.';

  @override
  String get reportReceivedReviewNotice =>
      'Notre équipe va examiner ton signalement et prendre les mesures appropriées. Tu pourras recevoir des mises à jour par message direct.';

  @override
  String get reportLearnMore => 'En savoir plus';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Fermer';

  @override
  String get listAddToList => 'Ajouter à une liste';

  @override
  String listVideoCount(int count) {
    return '$count vidéos';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personnes',
      one: '1 personne',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Par ';

  @override
  String get listNewList => 'Nouvelle liste';

  @override
  String get listDone => 'Terminé';

  @override
  String get listErrorLoading => 'Erreur de chargement des listes';

  @override
  String listRemovedFrom(String name) {
    return 'Retiré de $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Ajouté à $name';
  }

  @override
  String get listCreateNewList => 'Créer une nouvelle liste';

  @override
  String get listNewPeopleList => 'Nouvelle liste de personnes';

  @override
  String get listCollaboratorsNone => 'Aucun';

  @override
  String get listAddCollaboratorTitle => 'Ajouter un collaborateur';

  @override
  String get listCollaboratorSearchHint => 'Rechercher dans diVine...';

  @override
  String get listNameLabel => 'Nom de la liste';

  @override
  String get listDescriptionLabel => 'Description (facultatif)';

  @override
  String get listPublicList => 'Liste publique';

  @override
  String get listPublicListSubtitle =>
      'Les autres peuvent suivre et voir cette liste';

  @override
  String get listCancel => 'Annuler';

  @override
  String get listCreate => 'Créer';

  @override
  String get listCreateFailed => 'Échec de la création de la liste';

  @override
  String get keyManagementTitle => 'Clés Nostr';

  @override
  String get keyManagementWhatAreKeys => 'C\'est quoi les clés Nostr ?';

  @override
  String get keyManagementExplanation =>
      'Ton identité Nostr est une paire de clés cryptographiques :\n\n• Ta clé publique (npub) est comme ton nom d\'utilisateur - partage-la librement\n• Ta clé privée (nsec) est comme ton mot de passe - garde-la secrète !\n\nTa nsec te permet d\'accéder à ton compte sur n\'importe quelle app Nostr.';

  @override
  String get keyManagementImportTitle => 'Importer une clé existante';

  @override
  String get keyManagementImportSubtitle =>
      'Tu as déjà un compte Nostr ? Colle ta clé privée (nsec) pour y accéder ici.';

  @override
  String get keyManagementImportButton => 'Importer la clé';

  @override
  String get keyManagementImportWarning => 'Ça va remplacer ta clé actuelle !';

  @override
  String get keyManagementBackupTitle => 'Sauvegarder ta clé';

  @override
  String get keyManagementBackupSubtitle =>
      'Enregistre ta clé privée (nsec) pour utiliser ton compte dans d\'autres apps Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copier ma clé privée (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Ne partage jamais ta nsec avec qui que ce soit !';

  @override
  String get keyManagementPasteKey => 'Colle ta clé privée';

  @override
  String get keyManagementInvalidFormat =>
      'Format de clé invalide. Doit commencer par « nsec1 »';

  @override
  String get keyManagementConfirmImportTitle => 'Importer cette clé ?';

  @override
  String get keyManagementConfirmImportBody =>
      'Ça va remplacer ton identité actuelle par celle importée.\n\nTa clé actuelle sera perdue si tu ne l\'as pas sauvegardée avant.';

  @override
  String get keyManagementImportConfirm => 'Importer';

  @override
  String get keyManagementImportSuccess => 'Clé importée avec succès !';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Échec de l\'importation de la clé : $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Clé privée copiée dans le presse-papiers !\n\nRange-la dans un endroit sûr.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Échec de l\'exportation de la clé : $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Ta clé publique (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copier la clé publique';

  @override
  String get keyManagementPublicKeyCopied => 'Clé publique copiée';

  @override
  String get profileEditPublicKeyLink => 'Voir ta clé publique';

  @override
  String get saveOriginalSavedToCameraRoll => 'Enregistré dans la pellicule';

  @override
  String get saveOriginalShare => 'Partager';

  @override
  String get saveOriginalDone => 'Terminé';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Accès aux Photos requis';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Pour enregistrer les vidéos, autorise l\'accès aux Photos dans les Réglages.';

  @override
  String get saveOriginalOpenSettings => 'Ouvrir les Réglages';

  @override
  String get saveOriginalNotNow => 'Pas maintenant';

  @override
  String get cameraPermissionNotNow => 'Pas maintenant';

  @override
  String get saveOriginalDownloadFailed => 'Téléchargement échoué';

  @override
  String get saveOriginalDismiss => 'Ignorer';

  @override
  String get saveOriginalDownloadingVideo => 'Téléchargement de la vidéo';

  @override
  String get saveOriginalSavingToCameraRoll =>
      'Enregistrement dans la pellicule';

  @override
  String get saveOriginalFetchingVideo =>
      'Récupération de la vidéo depuis le réseau...';

  @override
  String get saveOriginalSavingVideo =>
      'Enregistrement de la vidéo originale dans ta pellicule...';

  @override
  String get soundTitle => 'Son';

  @override
  String get soundOriginalSound => 'Son original';

  @override
  String get soundVideosUsingThisSound => 'Vidéos utilisant ce son';

  @override
  String get soundSourceVideo => 'Vidéo source';

  @override
  String get soundNoVideosYet => 'Pas encore de vidéos';

  @override
  String get soundBeFirstToUse => 'Sois le premier à utiliser ce son !';

  @override
  String get soundFailedToLoadVideos => 'Échec du chargement des vidéos';

  @override
  String get soundRetry => 'Réessayer';

  @override
  String get soundVideosUnavailable => 'Vidéos indisponibles';

  @override
  String get soundCouldNotLoadDetails =>
      'Impossible de charger les détails de la vidéo';

  @override
  String get soundPreview => 'Aperçu';

  @override
  String get soundStop => 'Arrêter';

  @override
  String get soundUseSound => 'Utiliser ce son';

  @override
  String get soundUntitled => 'Son sans titre';

  @override
  String get soundStopPreview => 'Arrêter l\'aperçu';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Aperçu de $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Voir les détails de $title';
  }

  @override
  String get soundNoVideoCount => 'Pas encore de vidéos';

  @override
  String get soundOneVideo => '1 vidéo';

  @override
  String soundVideoCount(int count) {
    return '$count vidéos';
  }

  @override
  String get soundUnableToPreview =>
      'Impossible d\'écouter l\'aperçu - aucun audio disponible';

  @override
  String soundPreviewFailed(Object error) {
    return 'Échec de la lecture de l\'aperçu : $error';
  }

  @override
  String get soundViewSource => 'Voir la source';

  @override
  String get soundCloseTooltip => 'Fermer';

  @override
  String get exploreNotExploreRoute => 'Pas une route d\'exploration';

  @override
  String get legalTitle => 'Mentions légales';

  @override
  String get legalTermsOfService => 'Conditions d\'utilisation';

  @override
  String get legalTermsOfServiceSubtitle =>
      'Termes et conditions d\'utilisation';

  @override
  String get legalPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get legalPrivacyPolicySubtitle => 'Comment on traite tes données';

  @override
  String get legalSafetyStandards => 'Normes de sécurité';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Directives communautaires et sécurité';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Politique de droits d\'auteur et de retrait';

  @override
  String get legalOpenSourceLicenses => 'Licences open source';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Attributions des paquets tiers';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Impossible d\'ouvrir $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Erreur d\'ouverture de $pageName : $error';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Aventure';

  @override
  String get categoryAnimals => 'Animaux';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Architecture';

  @override
  String get categoryArt => 'Art';

  @override
  String get categoryAutomotive => 'Automobile';

  @override
  String get categoryAwardShow => 'Cérémonie';

  @override
  String get categoryAwards => 'Récompenses';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basket';

  @override
  String get categoryBeauty => 'Beauté';

  @override
  String get categoryBeverage => 'Boissons';

  @override
  String get categoryCars => 'Voitures';

  @override
  String get categoryCelebration => 'Fête';

  @override
  String get categoryCelebrities => 'Célébrités';

  @override
  String get categoryCelebrity => 'Célébrité';

  @override
  String get categoryCityscape => 'Paysage urbain';

  @override
  String get categoryComedy => 'Comédie';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Cuisine';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryCrafts => 'Loisirs créatifs';

  @override
  String get categoryCrime => 'Crime';

  @override
  String get categoryCulture => 'Culture';

  @override
  String get categoryDance => 'Danse';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drame';

  @override
  String get categoryEducation => 'Éducation';

  @override
  String get categoryEmotional => 'Émouvant';

  @override
  String get categoryEmotions => 'Émotions';

  @override
  String get categoryEntertainment => 'Divertissement';

  @override
  String get categoryEvent => 'Événement';

  @override
  String get categoryFamily => 'Famille';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantastique';

  @override
  String get categoryFashion => 'Mode';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Cuisine';

  @override
  String get categoryFootball => 'Football américain';

  @override
  String get categoryFurniture => 'Mobilier';

  @override
  String get categoryGaming => 'Jeux vidéo';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Soins';

  @override
  String get categoryGuitar => 'Guitare';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Santé';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Vacances';

  @override
  String get categoryHome => 'Maison';

  @override
  String get categoryHomeImprovement => 'Bricolage';

  @override
  String get categoryHorror => 'Horreur';

  @override
  String get categoryHospital => 'Hôpital';

  @override
  String get categoryHumor => 'Humour';

  @override
  String get categoryInteriorDesign => 'Déco d\'intérieur';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Enfants';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magie';

  @override
  String get categoryMakeup => 'Maquillage';

  @override
  String get categoryMedical => 'Médical';

  @override
  String get categoryMusic => 'Musique';

  @override
  String get categoryMystery => 'Mystère';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryNews => 'Actus';

  @override
  String get categoryOutdoor => 'Plein air';

  @override
  String get categoryParty => 'Fête';

  @override
  String get categoryPeople => 'Gens';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Animaux';

  @override
  String get categoryPolitics => 'Politique';

  @override
  String get categoryPrank => 'Blague';

  @override
  String get categoryPranks => 'Blagues';

  @override
  String get categoryRealityShow => 'Téléréalité';

  @override
  String get categoryRelationship => 'Relation';

  @override
  String get categoryRelationships => 'Relations';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'École';

  @override
  String get categoryScienceFiction => 'Science-fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skate';

  @override
  String get categorySkincare => 'Soins de la peau';

  @override
  String get categorySoccer => 'Foot';

  @override
  String get categorySocialGathering => 'Rassemblement';

  @override
  String get categorySocialMedia => 'Réseaux sociaux';

  @override
  String get categorySports => 'Sport';

  @override
  String get categoryTalkShow => 'Talk-show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technologie';

  @override
  String get categoryTelevision => 'Télévision';

  @override
  String get categoryToys => 'Jouets';

  @override
  String get categoryTransportation => 'Transport';

  @override
  String get categoryTravel => 'Voyage';

  @override
  String get categoryUrban => 'Urbain';

  @override
  String get categoryViolence => 'Violence';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Catch';

  @override
  String get profileSetupUploadSuccess =>
      'Photo de profil importée avec succès !';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName signalé(e)';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName bloqué(e)';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName débloqué(e)';
  }

  @override
  String get inboxRemovedConversation => 'Conversation supprimée';

  @override
  String get inboxEmptyTitle => 'Aucun message pour le moment';

  @override
  String get inboxEmptySubtitle => 'Le bouton + ne mord pas.';

  @override
  String get inboxActionMute => 'Mettre la conversation en sourdine';

  @override
  String inboxActionReport(String displayName) {
    return 'Signaler $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Bloquer $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Débloquer $displayName';
  }

  @override
  String get inboxActionRemove => 'Supprimer la conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Supprimer la conversation ?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Cela supprimera votre conversation avec $displayName. Cette action est irréversible.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Supprimer';

  @override
  String get inboxConversationMuted => 'Conversation mise en sourdine';

  @override
  String get inboxConversationUnmuted => 'Conversation réactivée';

  @override
  String get inboxCollabInviteCardTitle => 'Invitation à collaborer';

  @override
  String inboxCollabInviteCardRoleLabel(String role) {
    return '$role sur cette publication';
  }

  @override
  String get inboxCollabInviteAcceptButton => 'Accepter';

  @override
  String get inboxCollabInviteIgnoreButton => 'Ignorer';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Acceptée';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorée';

  @override
  String get inboxCollabInviteAcceptError =>
      'Impossible d\'accepter. Réessayez.';

  @override
  String get inboxCollabInviteSentStatus => 'Invitation envoyée';

  @override
  String get inboxConversationCollabInvitePreview => 'Invitation à collaborer';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Tu as été invité(e) à collaborer sur $title : $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Tu as été invité(e) à collaborer sur une vidéo : $url\n\nOpen diVine to review and accept.';
  }

  @override
  String get reportDialogCancel => 'Annuler';

  @override
  String get reportDialogReport => 'Signaler';

  @override
  String exploreVideoId(String id) {
    return 'ID : $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Titre : $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Vidéo $current/$total';
  }

  @override
  String get exploreSearchHint => 'Rechercher...';

  @override
  String categoryVideoCount(String count) {
    return '$count vidéos';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Impossible de mettre à jour l\'abonnement : $error';
  }

  @override
  String get discoverListsTitle => 'Découvrir des listes';

  @override
  String get discoverListsFailedToLoad => 'Échec du chargement des listes';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Échec du chargement des listes : $error';
  }

  @override
  String get discoverListsLoading => 'Recherche de listes publiques...';

  @override
  String get discoverListsEmptyTitle => 'Aucune liste publique trouvée';

  @override
  String get discoverListsEmptySubtitle =>
      'Reviens plus tard pour de nouvelles listes';

  @override
  String get discoverListsByAuthorPrefix => 'par';

  @override
  String get curatedListEmptyTitle => 'Aucune vidéo dans cette liste';

  @override
  String get curatedListEmptySubtitle => 'Ajoute des vidéos pour démarrer';

  @override
  String get curatedListLoadingVideos => 'Chargement des vidéos...';

  @override
  String get curatedListFailedToLoad => 'Échec du chargement de la liste';

  @override
  String get curatedListNoVideosAvailable => 'Aucune vidéo disponible';

  @override
  String get curatedListVideoNotAvailable => 'Vidéo indisponible';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonClose => 'Fermer';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Expiration';

  @override
  String get videoMetadataExpirationNotExpire => 'N\'expire pas';

  @override
  String get videoMetadataExpirationOneDay => '1 jour';

  @override
  String get videoMetadataExpirationOneWeek => '1 semaine';

  @override
  String get videoMetadataExpirationOneMonth => '1 mois';

  @override
  String get videoMetadataExpirationOneYear => '1 an';

  @override
  String get videoMetadataExpirationOneDecade => '1 décennie';

  @override
  String get videoMetadataContentWarnings => 'Avertissements de contenu';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Tendances';

  @override
  String get proofmodeCheckAiGenerated => 'Vérifier si généré par IA';

  @override
  String get libraryDeleteConfirm => 'Supprimer';

  @override
  String get libraryWebUnavailableHeadline =>
      'La bibliothèque est dans l’appli mobile';

  @override
  String get libraryWebUnavailableDescription =>
      'Les brouillons et clips sont enregistrés sur ton appareil : ouvre Divine sur ton téléphone pour les gérer.';

  @override
  String get libraryTabDrafts => 'Brouillons';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get librarySaveToCameraRollTooltip => 'Enregistrer dans Pellicule';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Supprimer les clips sélectionnés';

  @override
  String get libraryDeleteClipsTitle => 'Supprimer les clips';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# clips sélectionnés',
      one: '# clip sélectionné',
    );
    return 'Supprimer $_temp0 ?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Action irréversible. Les fichiers vidéo seront définitivement supprimés de ton appareil.';

  @override
  String get libraryPreparingVideo => 'Préparation de la vidéo...';

  @override
  String get libraryCreateVideo => 'Créer une vidéo';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 enregistré(s) dans $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount enregistrés, $failureCount échecs';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permission refusée pour $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips supprimés',
      one: '1 clip supprimé',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Impossible de charger les brouillons';

  @override
  String get libraryCouldNotLoadClips => 'Impossible de charger les clips';

  @override
  String get libraryOpenErrorDescription =>
      'Un problème est survenu en ouvrant ta bibliothèque. Réessaie.';

  @override
  String get libraryNoDraftsYetTitle => 'Pas encore de brouillons';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Les vidéos enregistrées en brouillon apparaîtront ici';

  @override
  String get libraryNoClipsYetTitle => 'Pas encore de clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Tes clips enregistrés apparaîtront ici';

  @override
  String get libraryDraftDeletedSnackbar => 'Brouillon supprimé';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'Échec de la suppression du brouillon';

  @override
  String get libraryDraftActionPost => 'Publier';

  @override
  String get libraryDraftActionEdit => 'Modifier';

  @override
  String get libraryDraftActionDelete => 'Supprimer le brouillon';

  @override
  String get libraryDeleteDraftTitle => 'Supprimer le brouillon';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Supprimer « $title » ?';
  }

  @override
  String get libraryDeleteClipTitle => 'Supprimer le clip';

  @override
  String get libraryDeleteClipMessage => 'Supprimer ce clip ?';

  @override
  String get libraryClipSelectionTitle => 'Clips';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Il reste ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Ajouter';

  @override
  String get libraryRecordVideo => 'Enregistrer une vidéo';

  @override
  String get routerInvalidCreator => 'Créateur non valide';

  @override
  String get routerInvalidHashtagRoute => 'Route de hashtag non valide';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Impossible de charger les vidéos';

  @override
  String get categoryGalleryNoVideosInCategory =>
      'Aucune vidéo dans cette catégorie';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Options de tri de la catégorie';

  @override
  String get categoryGallerySortHot => 'Tendance';

  @override
  String get categoryGallerySortNew => 'Nouveautés';

  @override
  String get categoryGallerySortClassic => 'Classiques';

  @override
  String get categoryGallerySortForYou => 'Pour toi';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Impossible de charger les catégories';

  @override
  String get categoriesNoCategoriesAvailable => 'Aucune catégorie disponible';

  @override
  String get notificationsEmptyTitle => 'Aucune activité pour l\'instant';

  @override
  String get notificationsEmptySubtitle =>
      'Quand les gens interagissent avec ton contenu, tu le verras ici';

  @override
  String get appsPermissionsTitle => 'Permissions d\'intégration';

  @override
  String get appsPermissionsRevoke => 'Révoquer';

  @override
  String get appsPermissionsEmptyTitle =>
      'Aucune permission d\'intégration enregistrée';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Les intégrations approuvées apparaîtront ici après que tu auras mémorisé une approbation d\'accès.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName demande ton approbation';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Cette app demande l\'accès via le sandbox vérifié de Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origine';

  @override
  String get nostrAppPermissionMethod => 'Méthode';

  @override
  String get nostrAppPermissionCapability => 'Capacité';

  @override
  String get nostrAppPermissionEventKind => 'Type d\'événement';

  @override
  String get nostrAppPermissionAllow => 'Autoriser';

  @override
  String get bugReportSendReport => 'Envoyer le rapport';

  @override
  String get supportSubjectRequiredLabel => 'Sujet *';

  @override
  String get supportRequiredHelper => 'Requis';

  @override
  String get bugReportSubjectHint => 'Bref résumé du problème';

  @override
  String get bugReportDescriptionRequiredLabel => 'Que s\'est-il passé ? *';

  @override
  String get bugReportDescriptionHint =>
      'Décris le problème que tu as rencontré';

  @override
  String get bugReportStepsLabel => 'Étapes pour reproduire';

  @override
  String get bugReportStepsHint =>
      '1. Aller à...\n2. Appuyer sur...\n3. Voir l\'erreur';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportement attendu';

  @override
  String get bugReportExpectedBehaviorHint =>
      'Que devait-il se passer à la place ?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Les infos de l\'appareil et les logs seront inclus automatiquement.';

  @override
  String get bugReportSuccessMessage =>
      'Merci ! On a bien reçu ton rapport et on s\'en servira pour améliorer Divine.';

  @override
  String get bugReportSendFailed =>
      'Échec de l\'envoi du rapport de bug. Réessaie plus tard.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Échec de l\'envoi du rapport de bug : $error';
  }

  @override
  String get featureRequestSendRequest => 'Envoyer la demande';

  @override
  String get featureRequestSubjectHint => 'Bref résumé de ton idée';

  @override
  String get featureRequestDescriptionRequiredLabel =>
      'Qu\'est-ce que tu aimerais ? *';

  @override
  String get featureRequestDescriptionHint =>
      'Décris la fonctionnalité que tu veux';

  @override
  String get featureRequestUsefulnessLabel => 'En quoi ce serait utile ?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explique le bénéfice que cette fonctionnalité apporterait';

  @override
  String get featureRequestWhenLabel => 'Quand l\'utiliserais-tu ?';

  @override
  String get featureRequestWhenHint => 'Décris les situations où ça aiderait';

  @override
  String get featureRequestSuccessMessage =>
      'Merci ! On a bien reçu ta demande de fonctionnalité et on va l\'examiner.';

  @override
  String get featureRequestSendFailed =>
      'Échec de l\'envoi de la demande de fonctionnalité. Réessaie plus tard.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Échec de l\'envoi de la demande de fonctionnalité : $error';
  }

  @override
  String get notificationFollowBack => 'Suivre en retour';

  @override
  String get followingTitle => 'Abonnements';

  @override
  String followingTitleForName(String displayName) {
    return 'Abonnements de $displayName';
  }

  @override
  String get followingFailedToLoadList =>
      'Impossible de charger la liste des abonnements';

  @override
  String get followingEmptyTitle => 'Aucun abonnement pour l\'instant';

  @override
  String get followersTitle => 'Abonnés';

  @override
  String followersTitleForName(String displayName) {
    return 'Abonnés de $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Impossible de charger la liste des abonnés';

  @override
  String get followersEmptyTitle => 'Aucun abonné pour l\'instant';

  @override
  String get followersUpdateFollowFailed =>
      'Échec de la mise à jour du suivi. Réessaie.';

  @override
  String get reportMessageTitle => 'Signaler le message';

  @override
  String get reportMessageWhyReporting => 'Pourquoi signales-tu ce message ?';

  @override
  String get reportMessageSelectReason =>
      'Sélectionne une raison pour signaler ce message';

  @override
  String get newMessageTitle => 'Nouveau message';

  @override
  String get newMessageFindPeople => 'Trouver des gens';

  @override
  String get newMessageNoContacts =>
      'Aucun contact trouvé.\nSuis des gens pour les voir ici.';

  @override
  String get newMessageNoUsersFound => 'Aucun utilisateur trouvé';

  @override
  String get hashtagSearchTitle => 'Rechercher des hashtags';

  @override
  String get hashtagSearchSubtitle =>
      'Découvre les sujets et contenus tendance';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Aucun hashtag trouvé pour « $query »';
  }

  @override
  String get hashtagSearchFailed => 'Échec de la recherche';

  @override
  String get userNotAvailableTitle => 'Compte indisponible';

  @override
  String get userNotAvailableBody =>
      'Ce compte n\'est pas disponible pour le moment.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Impossible de sauvegarder les paramètres : $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Entre une URL de serveur valide (ex. : https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Réglages Blossom enregistrés';

  @override
  String get blossomSaveTooltip => 'Enregistrer';

  @override
  String get blossomAboutTitle => 'À propos de Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom est un protocole décentralisé de stockage média qui te permet d\'uploader des vidéos sur n\'importe quel serveur compatible. Par défaut, les vidéos sont uploadées sur le serveur Blossom de Divine. Active l\'option ci-dessous pour utiliser un serveur personnalisé à la place.';

  @override
  String get blossomUseCustomServer =>
      'Utiliser un serveur Blossom personnalisé';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Les vidéos seront uploadées sur ton serveur Blossom personnalisé';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Tes vidéos sont actuellement uploadées sur le serveur Blossom de Divine';

  @override
  String get blossomCustomServerUrl => 'URL du serveur Blossom personnalisé';

  @override
  String get blossomCustomServerHelper =>
      'Entre l\'URL de ton serveur Blossom personnalisé';

  @override
  String get blossomPopularServers => 'Serveurs Blossom populaires';

  @override
  String get blossomServerUrlMustUseHttps =>
      'L\'URL du serveur Blossom doit utiliser https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Impossible de mettre à jour le paramètre de crosspost';

  @override
  String get blueskySignInRequired =>
      'Connecte-toi pour gérer les réglages Bluesky';

  @override
  String get blueskyPublishVideos => 'Publier les vidéos sur Bluesky';

  @override
  String get blueskyEnabledSubtitle => 'Tes vidéos seront publiées sur Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Tes vidéos ne seront pas publiées sur Bluesky';

  @override
  String get blueskyHandle => 'Identifiant Bluesky';

  @override
  String get blueskyStatus => 'Statut';

  @override
  String get blueskyStatusReady => 'Compte provisionné et prêt';

  @override
  String get blueskyStatusPending => 'Provisionnement du compte en cours...';

  @override
  String get blueskyStatusFailed => 'Échec du provisionnement du compte';

  @override
  String get blueskyStatusDisabled => 'Compte désactivé';

  @override
  String get blueskyStatusNotLinked => 'Aucun compte Bluesky lié';

  @override
  String get invitesTitle => 'Inviter des amis';

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
      'Aucune invitation disponible pour l\'instant';

  @override
  String get invitesShareWithPeople =>
      'Partage diVine avec les gens que tu connais';

  @override
  String get invitesUsedInvites => 'Invitations utilisées';

  @override
  String invitesShareMessage(String code) {
    return 'Rejoins-moi sur diVine ! Utilise le code d\'invitation $code pour démarrer :\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copier l\'invitation';

  @override
  String get invitesCopied => 'Invitation copiée !';

  @override
  String get invitesShareInvite => 'Partager l\'invitation';

  @override
  String get invitesShareSubject => 'Rejoins-moi sur diVine';

  @override
  String get invitesClaimed => 'Utilisée';

  @override
  String get invitesCouldNotLoad => 'Impossible de charger les invitations';

  @override
  String get invitesRetry => 'Réessayer';

  @override
  String get searchSomethingWentWrong => 'Quelque chose s\'est mal passé';

  @override
  String get searchTryAgain => 'Réessayer';

  @override
  String get searchForLists => 'Rechercher des listes';

  @override
  String get searchFindCuratedVideoLists =>
      'Trouve des listes de vidéos sélectionnées';

  @override
  String get searchEnterQuery => 'Saisis une recherche';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Découvre quelque chose d\'intéressant';

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
  String get searchListsSectionHeader => 'Listes';

  @override
  String get searchListsLoadingLabel => 'Chargement des résultats de listes';

  @override
  String get cameraAgeRestriction =>
      'Tu dois avoir 16 ans ou plus pour créer du contenu';

  @override
  String get featureRequestCancel => 'Annuler';

  @override
  String keyImportError(String error) {
    return 'Erreur : $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'Le relay bunker doit utiliser wss:// (ws:// est autorisé seulement pour localhost)';

  @override
  String get timeNow => 'maintenant';

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
    return '${count}j';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}sem';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeShortYears(int count) {
    return '${count}a';
  }

  @override
  String get timeVerboseNow => 'Maintenant';

  @override
  String timeAgo(String time) {
    return 'il y a $time';
  }

  @override
  String get timeToday => 'Aujourd\'hui';

  @override
  String get timeYesterday => 'Hier';

  @override
  String get timeJustNow => 'à l\'instant';

  @override
  String timeMinutesAgo(int count) {
    return 'il y a ${count}min';
  }

  @override
  String timeHoursAgo(int count) {
    return 'il y a ${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'il y a ${count}j';
  }

  @override
  String get draftTimeJustNow => 'À l\'instant';

  @override
  String get contentLabelNudity => 'Nudité';

  @override
  String get contentLabelSexualContent => 'Contenu sexuel';

  @override
  String get contentLabelPornography => 'Pornographie';

  @override
  String get contentLabelGraphicMedia => 'Contenu choquant';

  @override
  String get contentLabelViolence => 'Violence';

  @override
  String get contentLabelSelfHarm => 'Automutilation/Suicide';

  @override
  String get contentLabelDrugUse => 'Consommation de drogues';

  @override
  String get contentLabelAlcohol => 'Alcool';

  @override
  String get contentLabelTobacco => 'Tabac/Tabagisme';

  @override
  String get contentLabelGambling => 'Jeux d\'argent';

  @override
  String get contentLabelProfanity => 'Langage vulgaire';

  @override
  String get contentLabelHateSpeech => 'Discours haineux';

  @override
  String get contentLabelHarassment => 'Harcèlement';

  @override
  String get contentLabelFlashingLights => 'Lumières clignotantes';

  @override
  String get contentLabelAiGenerated => 'Généré par IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Arnaque/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Trompeur';

  @override
  String get contentLabelSensitiveContent => 'Contenu sensible';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName a aimé ta vidéo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName a aimé ton commentaire';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName a commenté ta vidéo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName a commencé à te suivre';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName t\'a mentionné';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName a repartagé ta vidéo';
  }

  @override
  String get notificationRepliedToYourComment => 'a répondu à ton commentaire';

  @override
  String get notificationAndConnector => 'et';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count autres',
      one: '1 autre',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Tu as une nouvelle mise à jour';

  @override
  String get notificationSomeoneLikedYourVideo => 'Quelqu\'un a aimé ta vidéo';

  @override
  String get commentReplyToPrefix => 'Re :';

  @override
  String get commentHideKeyboard => 'Hide keyboard';

  @override
  String get draftUntitled => 'Sans titre';

  @override
  String get contentWarningNone => 'Aucun';

  @override
  String get textBackgroundNone => 'Aucun';

  @override
  String get textBackgroundSolid => 'Opaque';

  @override
  String get textBackgroundHighlight => 'Surbrillance';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Gauche';

  @override
  String get textAlignRight => 'Droite';

  @override
  String get textAlignCenter => 'Centré';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'La caméra n\'est pas encore prise en charge sur le web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'La capture et l\'enregistrement vidéo avec la caméra ne sont pas encore disponibles dans la version web.';

  @override
  String get cameraPermissionBackToFeed => 'Retour au fil';

  @override
  String get cameraPermissionErrorTitle => 'Erreur d\'autorisation';

  @override
  String get cameraPermissionErrorDescription =>
      'Une erreur s\'est produite lors de la vérification des autorisations.';

  @override
  String get cameraPermissionRetry => 'Réessayer';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Autoriser l\'accès à la caméra et au micro';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Cela vous permet de capturer et de modifier des vidéos directement dans l\'application, rien de plus.';

  @override
  String get cameraPermissionContinue => 'Continuer';

  @override
  String get cameraPermissionGoToSettings => 'Aller aux paramètres';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Pourquoi six secondes ?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Les clips courts laissent place à la spontanéité. Le format de 6 secondes vous aide à capturer des moments authentiques au moment où ils se produisent.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Compris !';

  @override
  String get videoRecorderUploadTitle => 'Pourquoi pas d\'envoi ?';

  @override
  String get videoRecorderUploadBody =>
      'Ce que tu vois sur Divine est fait par des humains : brut et capturé sur le moment. Contrairement aux plateformes qui autorisent les envois très produits ou générés par IA, nous donnons la priorité à l\'authenticité de l\'expérience caméra-directe.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'En gardant la création à l\'intérieur de l\'app, nous pouvons mieux garantir que le contenu est réel et non édité. Nous n\'ouvrons pas les envois depuis la galerie externe pour le moment, afin de protéger cette authenticité et garder notre communauté libre de contenu synthétique autant que possible.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Passe à Capture ou Classic pour filmer quelque chose de réel.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Découvre comment fonctionne la vérification';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Nous avons trouvé un travail en cours';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Voulez-vous reprendre là où vous vous êtes arrêté ?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Oui, continuer';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'Non, démarrer une nouvelle vidéo';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Impossible de restaurer votre brouillon';

  @override
  String get videoRecorderStopRecordingTooltip => 'Arrêter l\'enregistrement';

  @override
  String get videoRecorderStartRecordingTooltip => 'Démarrer l\'enregistrement';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Enregistrement en cours. Appuyez n\'importe où pour arrêter';

  @override
  String get videoRecorderTapToStartLabel =>
      'Appuyez n\'importe où pour démarrer l\'enregistrement';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Supprimer le dernier clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Changer de caméra';

  @override
  String get videoRecorderToggleGridLabel => 'Afficher/masquer la grille';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Afficher/masquer le cadre fantôme';

  @override
  String get videoRecorderGhostFrameEnabled => 'Cadre fantôme activé';

  @override
  String get videoRecorderGhostFrameDisabled => 'Cadre fantôme désactivé';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip supprimé';

  @override
  String get videoRecorderCloseLabel => 'Fermer l\'enregistreur vidéo';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuer vers l\'éditeur vidéo';

  @override
  String get videoRecorderCaptureCloseLabel => 'Fermer';

  @override
  String get videoRecorderCaptureNextLabel => 'Suivant';

  @override
  String get videoRecorderToggleFlashLabel => 'Activer/désactiver le flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Changer le minuteur';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Changer le format d\'image';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Bibliothèque de clips, aucun clip';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Ouvrir la bibliothèque de clips, $clipCount clips',
      one: 'Ouvrir la bibliothèque de clips, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Caméra';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Ouvrir la caméra';

  @override
  String get videoEditorLibraryLabel => 'Bibliothèque';

  @override
  String get videoEditorTextLabel => 'Texte';

  @override
  String get videoEditorDrawLabel => 'Dessiner';

  @override
  String get videoEditorFilterLabel => 'Filtre';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorVolumeLabel => 'Volume';

  @override
  String get videoEditorAddTitle => 'Ajouter';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Ouvrir la bibliothèque';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Ouvrir l\'éditeur audio';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Ouvrir l\'éditeur de texte';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Ouvrir l\'éditeur de dessin';

  @override
  String get videoEditorOpenFilterSemanticLabel =>
      'Ouvrir l\'éditeur de filtres';

  @override
  String get videoEditorOpenStickerSemanticLabel =>
      'Ouvrir l\'éditeur de stickers';

  @override
  String get videoEditorSaveDraftTitle => 'Enregistrer votre brouillon ?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Conservez vos modifications pour plus tard, ou abandonnez-les et quittez l\'éditeur.';

  @override
  String get videoEditorSaveDraftButton => 'Enregistrer le brouillon';

  @override
  String get videoEditorDiscardChangesButton => 'Ignorer les modifications';

  @override
  String get videoEditorKeepEditingButton => 'Continuer la modification';

  @override
  String get videoEditorDeleteLayerDropZone => 'Zone de suppression de calque';

  @override
  String get videoEditorReleaseToDeleteLayer =>
      'Relâchez pour supprimer le calque';

  @override
  String get videoEditorDoneLabel => 'Terminé';

  @override
  String get videoEditorPlayPauseSemanticLabel =>
      'Lire ou mettre en pause la vidéo';

  @override
  String get videoEditorCropSemanticLabel => 'Rogner';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Impossible de scinder le clip pendant son traitement. Veuillez patienter.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Position de découpe invalide. Les deux clips doivent durer au moins $minDurationMs ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary =>
      'Ajouter un clip depuis la bibliothèque';

  @override
  String get videoEditorSaveSelectedClip => 'Enregistrer le clip sélectionné';

  @override
  String get videoEditorSplitClip => 'Scinder le clip';

  @override
  String get videoEditorSaveClip => 'Enregistrer le clip';

  @override
  String get videoEditorDeleteClip => 'Supprimer le clip';

  @override
  String get videoEditorClipSavedSuccess =>
      'Clip enregistré dans la bibliothèque';

  @override
  String get videoEditorClipSaveFailed => 'Échec de l\'enregistrement du clip';

  @override
  String get videoEditorClipDeleted => 'Clip supprimé';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Sélecteur de couleur';

  @override
  String get videoEditorUndoSemanticLabel => 'Annuler';

  @override
  String get videoEditorRedoSemanticLabel => 'Rétablir';

  @override
  String get videoEditorTextColorSemanticLabel => 'Couleur du texte';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alignement du texte';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Arrière-plan du texte';

  @override
  String get videoEditorFontSemanticLabel => 'Police';

  @override
  String get videoEditorNoStickersFound => 'Aucun sticker trouvé';

  @override
  String get videoEditorNoStickersAvailable => 'Aucun sticker disponible';

  @override
  String get videoEditorFailedLoadStickers =>
      'Échec du chargement des stickers';

  @override
  String get videoEditorAdjustVolumeTitle => 'Ajuster le volume';

  @override
  String get videoEditorRecordedAudioLabel => 'Audio enregistré';

  @override
  String get videoEditorCustomAudioLabel => 'Audio personnalisé';

  @override
  String get videoEditorPlaySemanticLabel => 'Lire';

  @override
  String get videoEditorPauseSemanticLabel => 'Pause';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Couper le son';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Réactiver le son';

  @override
  String get videoEditorDeleteLabel => 'Supprimer';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Supprimer l\'élément sélectionné';

  @override
  String get videoEditorEditLabel => 'Modifier';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Modifier l\'élément sélectionné';

  @override
  String get videoEditorDuplicateLabel => 'Dupliquer';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Dupliquer l\'élément sélectionné';

  @override
  String get videoEditorSplitLabel => 'Scinder';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Scinder le clip sélectionné';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Terminer l\'édition de la timeline';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Lire l\'aperçu';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel =>
      'Mettre l\'aperçu en pause';

  @override
  String get videoEditorAudioUntitledSound => 'Son sans titre';

  @override
  String get videoEditorAudioUntitled => 'Sans titre';

  @override
  String get videoEditorAudioAddAudio => 'Ajouter de l\'audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Aucun son disponible';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Les sons apparaîtront ici lorsque des créateurs partageront de l\'audio';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'Échec du chargement des sons';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Sélectionne le segment audio de ta vidéo';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Communauté';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Outil flèche';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Outil gomme';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Outil marqueur';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Outil crayon';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Réorganiser le calque $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Maintenez appuyé pour réorganiser';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Afficher la timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Masquer la timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Évitez de placer du contenu derrière ces zones.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originaux';

  @override
  String get videoEditorStickerSearchHint => 'Rechercher des stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Sélectionner une police';

  @override
  String get videoEditorFontUnknown => 'Inconnue';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'La tête de lecture doit se trouver dans le clip sélectionné pour pouvoir le scinder.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Rogner le début';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Rogner la fin';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Rogner le clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Faites glisser les poignées pour ajuster la durée du clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Déplacement du clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index sur $total, $duration secondes';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Appui long pour déplacer';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Appuie pour modifier. Maintiens appuyé et fais glisser pour réorganiser.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Déplacer vers la gauche';

  @override
  String get videoEditorTimelineClipMoveRight => 'Déplacer vers la droite';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Appui long pour glisser';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Timeline vidéo';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, sélectionnée';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Fermer le sélecteur de couleur';

  @override
  String get videoEditorPickColorTitle => 'Choisir une couleur';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmer la couleur';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturation et luminosité';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturation $saturation %, luminosité $brightness %';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Teinte';

  @override
  String get videoEditorAddElementSemanticLabel => 'Ajouter un élément';

  @override
  String get videoEditorCloseSemanticLabel => 'Fermer';

  @override
  String get videoEditorDoneSemanticLabel => 'Terminé';

  @override
  String get videoEditorLevelSemanticLabel => 'Niveau';

  @override
  String get videoMetadataBackSemanticLabel => 'Retour';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Fermer la fenêtre d\'aide';

  @override
  String get videoMetadataGotItButton => 'Compris !';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limite de 64 Ko atteinte. Supprimez du contenu pour continuer.';

  @override
  String get videoMetadataExpirationLabel => 'Expiration';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Sélectionner la durée d\'expiration';

  @override
  String get videoMetadataTitleLabel => 'Titre';

  @override
  String get videoMetadataDescriptionLabel => 'Description';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Supprimer';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Supprimer le tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Avertissement de contenu';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Sélectionner des avertissements de contenu';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Sélectionnez tout ce qui s\'applique à votre contenu';

  @override
  String get videoMetadataContentWarningDoneButton => 'Terminé';

  @override
  String get videoMetadataCollaboratorsLabel => 'Collaborateurs';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Ajouter un collaborateur';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Fonctionnement des collaborateurs';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max collaborateurs';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Supprimer un collaborateur';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Les collaborateurs sont identifiés comme co-créateurs sur cette publication. Vous pouvez uniquement ajouter des personnes avec lesquelles vous vous suivez mutuellement, et elles apparaîtront dans les métadonnées lors de la publication.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Abonnés mutuels';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Vous devez suivre mutuellement $name pour l\'ajouter en tant que collaborateur.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspiré par';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Définir inspiré par';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Fonctionnement des crédits d\'inspiration';

  @override
  String get videoMetadataInspiredByNone => 'Aucun';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Utilisez ceci pour attribuer le mérite. Le crédit \"inspiré par\" est différent des collaborateurs : il reconnaît l\'influence, mais n\'identifie pas quelqu\'un comme co-créateur.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Ce créateur ne peut pas être référencé.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Supprimer inspiré par';

  @override
  String get videoMetadataPostDetailsTitle => 'Détails de la publication';

  @override
  String get videoMetadataSavedToLibrarySnackbar =>
      'Enregistré dans la bibliothèque';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Échec de l\'enregistrement';

  @override
  String get videoMetadataGoToLibraryButton => 'Aller à la bibliothèque';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Bouton enregistrer pour plus tard';

  @override
  String get videoMetadataRenderingVideoHint => 'Rendu de la vidéo...';

  @override
  String get videoMetadataSavingVideoHint => 'Enregistrement de la vidéo...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Enregistrer la vidéo dans les brouillons et $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Enregistrer pour plus tard';

  @override
  String get videoMetadataPostSemanticLabel => 'Bouton publier';

  @override
  String get videoMetadataPublishVideoHint => 'Publier la vidéo dans le fil';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Remplissez le formulaire pour activer';

  @override
  String get videoMetadataPostButton => 'Publier';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Ouvrir l\'écran d\'aperçu de la publication';

  @override
  String get videoMetadataShareTitle => 'Partager';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Détails de la vidéo';

  @override
  String get videoMetadataClassicDoneButton => 'Terminé';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Lire l\'aperçu';

  @override
  String get videoMetadataPausePreviewSemanticLabel =>
      'Mettre l\'aperçu en pause';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Fermer l\'aperçu vidéo';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Supprimer';

  @override
  String get metadataCaptionsLabel => 'Sous-titres';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Sous-titres activés pour toutes les vidéos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Sous-titres désactivés pour toutes les vidéos';

  @override
  String get fullscreenFeedRemovedMessage => 'Vidéo supprimée';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Accepte les récompenses et vérifie le statut des badges délivrés.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesIntroTitle => 'Comprends ton parcours de badges';

  @override
  String get badgesIntroBody =>
      'Vois les récompenses de badges qu\'on t\'a envoyées, choisis ce que tu veux épingler sur ton profil Nostr, et vérifie si les gens ont accepté les badges que tu as délivrés.';

  @override
  String get badgesOpenApp => 'Ouvrir l\'app de badges';

  @override
  String get badgesLoadError => 'Impossible de charger les badges';

  @override
  String get badgesUpdateError => 'Impossible de mettre à jour le badge';

  @override
  String get badgesAwardedSectionTitle => 'Décernés à toi';

  @override
  String get badgesAwardedEmptyTitle =>
      'Aucune récompense de badge pour l\'instant';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Quand quelqu\'un te décerne un badge Nostr, il atterrira ici.';

  @override
  String get badgesStatusAccepted => 'Accepté';

  @override
  String get badgesStatusNotAccepted => 'Non accepté';

  @override
  String get badgesActionRemove => 'Retirer';

  @override
  String get badgesActionAccept => 'Accepter';

  @override
  String get badgesActionReject => 'Refuser';

  @override
  String get badgesIssuedSectionTitle => 'Délivrés par toi';

  @override
  String get badgesIssuedEmptyTitle => 'Aucun badge délivré pour l\'instant';

  @override
  String get badgesIssuedEmptySubtitle =>
      'Les badges que tu délivres afficheront leur statut d\'acceptation ici.';

  @override
  String get badgesIssuedNoRecipients =>
      'Aucun destinataire trouvé pour cette récompense.';

  @override
  String get badgesRecipientAcceptedStatus => 'Accepté par le destinataire';

  @override
  String get badgesRecipientWaitingStatus => 'En attente du destinataire';
}
