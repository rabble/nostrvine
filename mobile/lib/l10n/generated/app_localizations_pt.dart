// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Portuguese (`pt`).
class AppLocalizationsPt extends AppLocalizations {
  AppLocalizationsPt([String locale = 'pt']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Configurações';

  @override
  String get settingsSecureAccount => 'Proteja sua conta';

  @override
  String get settingsSessionExpired => 'Sessão expirada';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Entre novamente para recuperar o acesso completo';

  @override
  String get settingsCreatorAnalytics => 'Estatísticas de criador';

  @override
  String get settingsSupportCenter => 'Central de suporte';

  @override
  String get settingsNotifications => 'Notificações';

  @override
  String get settingsContentPreferences => 'Preferências de conteúdo';

  @override
  String get settingsModerationControls => 'Controles de moderação';

  @override
  String get settingsBlueskyPublishing => 'Publicação no Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gerencie o crosspost para o Bluesky';

  @override
  String get settingsNostrSettings => 'Configurações do Nostr';

  @override
  String get settingsIntegratedApps => 'Apps integrados';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps de terceiros aprovados que rodam dentro do Divine';

  @override
  String get settingsExperimentalFeatures => 'Recursos experimentais';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Ajustes que podem dar chilique—experimente se estiver curioso.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permissões de integração';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Revise e revogue as aprovações de integração lembradas';

  @override
  String settingsVersion(String version) {
    return 'Versão $version';
  }

  @override
  String get settingsVersionEmpty => 'Versão';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'O modo desenvolvedor já está ativado';

  @override
  String get settingsDeveloperModeEnabled => 'Modo desenvolvedor ativado!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Mais $count toques para ativar o modo desenvolvedor';
  }

  @override
  String get settingsInvites => 'Convites';

  @override
  String get settingsSwitchAccount => 'Trocar de conta';

  @override
  String get settingsAddAnotherAccount => 'Adicionar outra conta';

  @override
  String get settingsUnsavedDraftsTitle => 'Rascunhos não salvos';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'rascunhos não salvos',
      one: 'rascunho não salvo',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'seus rascunhos',
      one: 'seu rascunho',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'eles',
      one: 'ele',
    );
    return 'Você tem $count $_temp0. Trocar de conta vai manter $_temp1, mas talvez você queira publicar ou revisar $_temp2 antes.';
  }

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsSwitchAnyway => 'Trocar mesmo assim';

  @override
  String get settingsAppVersionLabel => 'Versão do app';

  @override
  String get settingsAppLanguage => 'Idioma do app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (padrão do dispositivo)';
  }

  @override
  String get settingsAppLanguageTitle => 'Idioma do app';

  @override
  String get settingsAppLanguageDescription =>
      'Escolha o idioma da interface do app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Usar idioma do dispositivo';

  @override
  String get settingsGeneralTitle => 'Configurações gerais';

  @override
  String get settingsContentSafetyTitle => 'Conteúdo e segurança';

  @override
  String get generalSettingsSectionIntegrations => 'INTEGRAÇÕES';

  @override
  String get generalSettingsSectionViewing => 'VISUALIZAÇÃO';

  @override
  String get generalSettingsSectionCreating => 'CRIAÇÃO';

  @override
  String get generalSettingsSectionApp => 'APP';

  @override
  String get generalSettingsClosedCaptions => 'Legendas';

  @override
  String get generalSettingsClosedCaptionsSubtitle =>
      'Mostrar legendas quando os vídeos tiverem';

  @override
  String get generalSettingsVideoShape => 'Formato do vídeo';

  @override
  String get generalSettingsVideoShapeSquareOnly => 'Só vídeos quadrados';

  @override
  String get generalSettingsVideoShapeSquareAndPortrait => 'Quadrado e retrato';

  @override
  String get generalSettingsVideoShapeSquareAndPortraitSubtitle =>
      'Mostrar a mistura completa de vídeos do Divine';

  @override
  String get generalSettingsVideoShapeSquareOnlySubtitle =>
      'Mantenha os feeds no formato quadrado clássico';

  @override
  String get contentPreferencesTitle => 'Preferências de conteúdo';

  @override
  String get contentPreferencesContentFilters => 'Filtros de conteúdo';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gerencie os filtros de aviso de conteúdo';

  @override
  String get contentPreferencesContentLanguage => 'Idioma do conteúdo';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (padrão do dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Marque seus vídeos com um idioma para que os espectadores possam filtrar o conteúdo.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usar idioma do dispositivo (padrão)';

  @override
  String get contentPreferencesAudioSharing =>
      'Liberar meu áudio para reutilização';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Quando ativado, outras pessoas podem usar o áudio dos seus vídeos';

  @override
  String get contentPreferencesAccountLabels => 'Rótulos da conta';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Rótulos próprios para seu conteúdo';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Rótulos de conteúdo da conta';

  @override
  String get contentPreferencesClearAll => 'Limpar tudo';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Selecione tudo que se aplica à sua conta';

  @override
  String get contentPreferencesDoneNoLabels => 'Concluído (sem rótulos)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Concluído ($count selecionados)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispositivo de entrada de áudio';

  @override
  String get contentPreferencesAutoRecommended => 'Automático (recomendado)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Seleciona automaticamente o melhor microfone';

  @override
  String get contentPreferencesSelectAudioInput =>
      'Selecionar entrada de áudio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Microfone desconhecido';

  @override
  String get contentFiltersAdultContent => 'CONTEÚDO ADULTO';

  @override
  String get contentFiltersViolenceGore => 'VIOLÊNCIA E SANGUE';

  @override
  String get contentFiltersSubstances => 'SUBSTÂNCIAS';

  @override
  String get contentFiltersOther => 'OUTROS';

  @override
  String get contentFiltersAgeGateMessage =>
      'Verifique sua idade em Segurança e privacidade para liberar os filtros de conteúdo adulto';

  @override
  String get contentFiltersShow => 'Mostrar';

  @override
  String get contentFiltersWarn => 'Avisar';

  @override
  String get contentFiltersFilterOut => 'Filtrar';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Esta conta não está disponível';

  @override
  String profileErrorPrefix(Object error) {
    return 'Erro: $error';
  }

  @override
  String get profileInvalidId => 'ID de perfil inválido';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Confira $displayName no Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName no Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Falha ao compartilhar perfil: $error';
  }

  @override
  String get profileEditProfile => 'Editar perfil';

  @override
  String get profileCreatorAnalytics => 'Estatísticas de criador';

  @override
  String get profileShareProfile => 'Compartilhar perfil';

  @override
  String get profileCopyPublicKey => 'Copiar chave pública (npub)';

  @override
  String get profileGetEmbedCode => 'Obter código de incorporação';

  @override
  String get profilePublicKeyCopied =>
      'Chave pública copiada para a área de transferência';

  @override
  String get profileEmbedCodeCopied =>
      'Código de incorporação copiado para a área de transferência';

  @override
  String get profileRefreshTooltip => 'Atualizar';

  @override
  String get profileRefreshSemanticLabel => 'Atualizar perfil';

  @override
  String get profileMoreTooltip => 'Mais';

  @override
  String get profileMoreSemanticLabel => 'Mais opções';

  @override
  String get profileAvatarLightboxBarrierLabel => 'Fechar avatar';

  @override
  String get profileAvatarLightboxCloseSemanticLabel =>
      'Fechar pré-visualização do avatar';

  @override
  String get profileFollowingLabel => 'Seguindo';

  @override
  String get profileFollowLabel => 'Seguir';

  @override
  String get profileBlockedLabel => 'Bloqueado';

  @override
  String get profileFollowersLabel => 'Seguidores';

  @override
  String get profileFollowingStatLabel => 'Seguindo';

  @override
  String get profileVideosLabel => 'Vídeos';

  @override
  String profileCollaboratorInvitePendingHeadline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites still need to send',
      one: '1 collaborator invite still needs to send',
    );
    return '$_temp0';
  }

  @override
  String get profileCollaboratorInvitePendingDetail =>
      'We kept the invite queued. Retry it here.';

  @override
  String profileCollaboratorInvitePendingDetailWithTitle(String title) {
    return 'For \"$title\". Retry it here.';
  }

  @override
  String get profileCollaboratorInviteRetryAction => 'Retry';

  @override
  String get profileCollaboratorInviteRetryingAction => 'Retrying';

  @override
  String get profileCollaboratorInviteRetryUnavailable =>
      'Collaborator invite retry is unavailable right now.';

  @override
  String profileCollaboratorInviteRetryResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites still need to send.',
      one: '1 collaborator invite still needs to send.',
      zero: 'Collaborator invites sent.',
    );
    return '$_temp0';
  }

  @override
  String profileFollowerCountUsers(int count) {
    return '$count usuários';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Bloquear $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Quando você bloqueia alguém:';

  @override
  String get profileBlockBulletHidePosts =>
      'Os posts dessa pessoa não vão aparecer no seu feed.';

  @override
  String get profileBlockBulletCantView =>
      'Ela não poderá ver seu perfil, te seguir ou ver seus posts.';

  @override
  String get profileBlockBulletNoNotify =>
      'Ela não será notificada sobre essa mudança.';

  @override
  String get profileBlockBulletYouCanView =>
      'Você ainda poderá ver o perfil dela.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Bloquear $displayName';
  }

  @override
  String get profileCancelButton => 'Cancelar';

  @override
  String get profileLearnMore => 'Saiba mais';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Desbloquear $displayName?';
  }

  @override
  String get profileUnblockExplanation =>
      'Quando você desbloqueia essa pessoa:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Os posts dela vão voltar a aparecer no seu feed.';

  @override
  String get profileUnblockBulletCanView =>
      'Ela poderá ver seu perfil, te seguir e ver seus posts.';

  @override
  String get profileUnblockBulletNoNotify =>
      'Ela não será notificada sobre essa mudança.';

  @override
  String get profileLearnMoreAt => 'Saiba mais em ';

  @override
  String get profileUnblockButton => 'Desbloquear';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Deixar de seguir $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Bloquear $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Desbloquear $displayName';
  }

  @override
  String profileReportDisplayName(String displayName) {
    return 'Denunciar $displayName';
  }

  @override
  String profileAddToListDisplayName(String displayName) {
    return 'Adicionar $displayName a uma lista';
  }

  @override
  String get profileUserBlockedTitle => 'Usuário bloqueado';

  @override
  String get profileUserBlockedContent =>
      'Você não vai mais ver conteúdo desse usuário no seu feed.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Você pode desbloqueá-lo a qualquer momento no perfil dele ou em Configurações > Segurança.';

  @override
  String get profileCloseButton => 'Fechar';

  @override
  String get profileNoCollabsTitle => 'Sem colabs ainda';

  @override
  String get profileCollabsOwnEmpty =>
      'Vídeos em que você colabora vão aparecer aqui';

  @override
  String get profileCollabsOtherEmpty =>
      'Vídeos em que essa pessoa colabora vão aparecer aqui';

  @override
  String get profileErrorLoadingCollabs => 'Erro ao carregar vídeos de colab';

  @override
  String get profileNoSavedVideosTitle => 'Nada salvo ainda';

  @override
  String get profileSavedOwnEmpty =>
      'Salve vídeos pelo menu de compartilhamento e eles aparecem aqui.';

  @override
  String get profileErrorLoadingSaved => 'Erro ao carregar vídeos salvos';

  @override
  String get profileNoCommentsOwnTitle => 'Nenhum comentário ainda';

  @override
  String get profileNoCommentsOtherTitle => 'Sem comentários';

  @override
  String get profileCommentsOwnEmpty =>
      'Seus comentários e respostas vão aparecer aqui';

  @override
  String get profileCommentsOtherEmpty =>
      'Os comentários e respostas dessa pessoa vão aparecer aqui';

  @override
  String get profileErrorLoadingComments => 'Erro ao carregar comentários';

  @override
  String get profileVideoRepliesSection => 'Respostas em vídeo';

  @override
  String get profileCommentsSection => 'Comentários';

  @override
  String get profileEditLabel => 'Editar';

  @override
  String get profileLibraryLabel => 'Biblioteca';

  @override
  String get profileNoLikedVideosTitle => 'Sem vídeos curtidos ainda';

  @override
  String get profileLikedOwnEmpty => 'Vídeos que você curtir vão aparecer aqui';

  @override
  String get profileLikedOtherEmpty =>
      'Vídeos que essa pessoa curtir vão aparecer aqui';

  @override
  String get profileErrorLoadingLiked => 'Erro ao carregar vídeos curtidos';

  @override
  String get profileNoRepostsTitle => 'Sem reposts ainda';

  @override
  String get profileRepostsOwnEmpty =>
      'Vídeos que você repostar vão aparecer aqui';

  @override
  String get profileRepostsOtherEmpty =>
      'Vídeos que essa pessoa repostar vão aparecer aqui';

  @override
  String get profileErrorLoadingReposts => 'Erro ao carregar vídeos repostados';

  @override
  String get profileLoadingVideos => 'Carregando vídeos...';

  @override
  String get profileNoVideosTitle => 'Sem vídeos ainda';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Compartilhe seu primeiro vídeo para vê-lo aqui';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Este usuário ainda não compartilhou nenhum vídeo';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura do vídeo $number';
  }

  @override
  String get profileShowMore => 'Mostrar mais';

  @override
  String get profileShowLess => 'Mostrar menos';

  @override
  String get profileCompleteYourProfile => 'Complete seu perfil';

  @override
  String get profileCompleteSubtitle =>
      'Adicione seu nome, bio e foto para começar';

  @override
  String get profileSetUpButton => 'Configurar';

  @override
  String get profileVerifyingEmail => 'Verificando e-mail...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Confira $email para o link de verificação';
  }

  @override
  String get profileWaitingForVerification =>
      'Aguardando verificação de e-mail';

  @override
  String get profileVerificationFailed => 'Verificação falhou';

  @override
  String get profilePleaseTryAgain => 'Por favor, tente novamente';

  @override
  String get profileSecureYourAccount => 'Proteja sua conta';

  @override
  String get profileSecureSubtitle =>
      'Adicione e-mail e senha para recuperar sua conta em qualquer dispositivo';

  @override
  String get profileRetryButton => 'Tentar novamente';

  @override
  String get profileRegisterButton => 'Registrar';

  @override
  String get profileSessionExpired => 'Sessão expirada';

  @override
  String get profileSignInToRestore =>
      'Entre novamente para recuperar o acesso completo';

  @override
  String get profileSignInButton => 'Entrar';

  @override
  String get profileMaybeLaterLabel => 'Talvez depois';

  @override
  String get profileSecurePrimaryButton => 'Adicionar e-mail e senha';

  @override
  String get profileCompletePrimaryButton => 'Atualizar seu perfil';

  @override
  String get profileLoopsLabel => 'Loops';

  @override
  String get profileLikesLabel => 'Curtidas';

  @override
  String get profileMyLibraryLabel => 'Minha biblioteca';

  @override
  String get profileMessageLabel => 'Mensagem';

  @override
  String get profileUserFallback => 'usuário';

  @override
  String get profileDismissTooltip => 'Dispensar';

  @override
  String get profileLinkCopied => 'Link do perfil copiado';

  @override
  String get profileSetupEditProfileTitle => 'Editar perfil';

  @override
  String get profileSetupBackLabel => 'Voltar';

  @override
  String get profileSetupAboutNostr => 'Sobre o Nostr';

  @override
  String get profileSetupProfilePublished => 'Perfil publicado com sucesso!';

  @override
  String get profileSetupCreateNewProfile => 'Criar novo perfil?';

  @override
  String get profileSetupNoExistingProfile =>
      'Não encontramos um perfil existente nos seus relays. Publicar vai criar um novo perfil. Continuar?';

  @override
  String get profileSetupPublishButton => 'Publicar';

  @override
  String get profileSetupUsernameTaken =>
      'Esse nome de usuário acabou de ser pego. Escolha outro.';

  @override
  String get profileSetupClaimFailed =>
      'Falha ao reivindicar o nome de usuário. Tente novamente.';

  @override
  String get profileSetupPublishFailed =>
      'Falha ao publicar perfil. Tente novamente.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Não foi possível acessar a rede. Verifique sua conexão e tente novamente.';

  @override
  String get profileSetupRetryLabel => 'Tentar novamente';

  @override
  String get profileSetupDisplayNameLabel => 'Nome de exibição';

  @override
  String get profileSetupDisplayNameHint =>
      'Como as pessoas devem te conhecer?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Qualquer nome ou rótulo que você queira. Não precisa ser único.';

  @override
  String get profileSetupDisplayNameRequired =>
      'Por favor, insira um nome de exibição';

  @override
  String get profileSetupBioLabel => 'Bio (opcional)';

  @override
  String get profileSetupBioHint => 'Fale um pouco sobre você...';

  @override
  String get profileSetupWebsiteLabel => 'Website (Optional)';

  @override
  String get profileSetupWebsiteHint => 'https://yoursite.com';

  @override
  String get profileSetupPublicKeyLabel => 'Chave pública (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nome de usuário (opcional)';

  @override
  String get profileSetupUsernameHint => 'usuario';

  @override
  String get profileSetupUsernameHelper => 'Sua identidade única no Divine';

  @override
  String get profileSetupProfileColorLabel => 'Cor do perfil (opcional)';

  @override
  String get profileSetupSaveButton => 'Salvar';

  @override
  String get profileSetupSavingButton => 'Salvando...';

  @override
  String get profileSetupImageUrlTitle => 'Adicionar URL da imagem';

  @override
  String get profileSetupPictureUploaded =>
      'Foto de perfil enviada com sucesso!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Falha ao selecionar a imagem. Cole uma URL de imagem abaixo.';

  @override
  String get profileSetupImagesTypeGroup => 'imagens';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Falha no acesso à câmera: $error';
  }

  @override
  String get profileSetupGotItButton => 'Entendi';

  @override
  String get profileSetupUploadFailedGeneric =>
      'Não foi possível enviar a imagem. Tente novamente mais tarde.';

  @override
  String get profileSetupUploadNetworkError =>
      'Erro de rede: verifique sua conexão com a internet e tente novamente.';

  @override
  String get profileSetupUploadAuthError =>
      'Erro de autenticação: tente sair e entrar novamente.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Arquivo muito grande: escolha uma imagem menor (máx. 10 MB).';

  @override
  String get profileSetupUploadServerError =>
      'Não foi possível enviar a imagem. Nossos servidores estão temporariamente indisponíveis. Tente novamente em instantes.';

  @override
  String get profileSetupUploadUnsupportedOnWeb =>
      'O envio de foto de perfil ainda não está disponível na web. Use o app para iOS ou Android ou cole a URL de uma imagem.';

  @override
  String get profileSetupBannerSectionTitle => 'Banner';

  @override
  String get profileSetupBannerUploadButton => 'Enviar foto';

  @override
  String get profileSetupBannerClearButton => 'Remover banner';

  @override
  String get profileSetupBannerUploadSuccess => 'Banner atualizado';

  @override
  String get profileSetupUsernameChecking => 'Verificando disponibilidade...';

  @override
  String get profileSetupUsernameAvailable => 'Nome de usuário disponível!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Nome de usuário já em uso';

  @override
  String get profileSetupUsernameReserved => 'Nome de usuário reservado';

  @override
  String get profileSetupContactSupport => 'Contatar suporte';

  @override
  String get profileSetupCheckAgain => 'Verificar novamente';

  @override
  String get profileSetupUsernameBurned =>
      'Este nome de usuário não está mais disponível';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'São permitidos apenas letras, números e hífens';

  @override
  String get profileSetupUsernameInvalidLength =>
      'O nome de usuário deve ter de 3 a 63 caracteres';

  @override
  String get profileSetupUsernameNetworkError =>
      'Não foi possível verificar a disponibilidade. Tente novamente.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Formato de nome de usuário inválido';

  @override
  String get profileSetupUsernameCheckFailed =>
      'Falha ao verificar a disponibilidade';

  @override
  String get profileSetupUsernameReservedTitle => 'Nome de usuário reservado';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'O nome $username está reservado. Diga por que ele deveria ser seu.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Ex.: é minha marca, nome artístico, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Já entrou em contato com o suporte? Toque em \"Verificar novamente\" para ver se foi liberado pra você.';

  @override
  String get profileSetupSupportRequestSent =>
      'Solicitação de suporte enviada! Retornaremos em breve.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Não foi possível abrir o e-mail. Envie para: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Enviar solicitação';

  @override
  String get profileSetupPickColorTitle => 'Escolha uma cor';

  @override
  String get profileSetupSelectButton => 'Selecionar';

  @override
  String get profileSetupUseOwnNip05 => 'Usar seu próprio endereço NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Endereço NIP-05';

  @override
  String get profileSetupExternalNip05InvalidFormat =>
      'Formato NIP-05 inválido (ex.: nome@dominio.com)';

  @override
  String get profileSetupExternalNip05DivineDomain =>
      'Use o campo de nome de usuário acima para divine.video';

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
      'Pré-visualização da foto de perfil';

  @override
  String get nostrInfoIntroBuiltOn => 'O DiVine é construído sobre o Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' um protocolo aberto e resistente à censura que permite que as pessoas se comuniquem online sem depender de uma única empresa ou plataforma. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Quando você se cadastra no Divine, ganha uma nova identidade Nostr.';

  @override
  String get nostrInfoOwnership =>
      'O Nostr permite que você seja dono do seu conteúdo, identidade e grafo social, que podem ser usados em vários apps. O resultado é mais escolha, menos aprisionamento e uma internet social mais saudável e resiliente.';

  @override
  String get nostrInfoLingo => 'Termos do Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Seu endereço público no Nostr. É seguro compartilhar e permite que outras pessoas te encontrem, sigam ou te enviem mensagens pelos apps Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Sua chave privada e prova de propriedade. Ela dá controle total da sua identidade Nostr, então ';

  @override
  String get nostrInfoNsecWarning => 'mantenha sempre em segredo!';

  @override
  String get nostrInfoUsernameLabel => 'Nome de usuário Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Um nome legível (como @nome.divine.video) que aponta para sua npub. Ele torna sua identidade Nostr mais fácil de reconhecer e verificar, parecido com um endereço de e-mail.';

  @override
  String get nostrInfoLearnMoreAt => 'Saiba mais em ';

  @override
  String get nostrInfoGotIt => 'Entendi!';

  @override
  String get profileTabRefreshTooltip => 'Atualizar';

  @override
  String get videoGridRefreshLabel => 'Procurando mais vídeos';

  @override
  String get videoGridOptionsTitle => 'Opções do vídeo';

  @override
  String get videoGridEditVideo => 'Editar vídeo';

  @override
  String get videoGridEditVideoSubtitle =>
      'Atualize título, descrição e hashtags';

  @override
  String get videoGridDeleteVideo => 'Excluir vídeo';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Remover este conteúdo permanentemente';

  @override
  String get videoGridDeleteConfirmTitle => 'Excluir vídeo';

  @override
  String get videoGridDeleteConfirmMessage =>
      'Tem certeza que quer excluir este vídeo?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Isso vai enviar uma solicitação de exclusão (NIP-09) para todos os relays. Alguns relays podem manter o conteúdo mesmo assim.';

  @override
  String get videoGridDeleteCancel => 'Cancelar';

  @override
  String get videoGridDeleteConfirm => 'Excluir';

  @override
  String get videoGridDeletingContent => 'Excluindo conteúdo...';

  @override
  String get videoGridDeleteSuccess =>
      'Solicitação de exclusão enviada com sucesso';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Falha ao excluir conteúdo: $error';
  }

  @override
  String get exploreTabClassics => 'Clássicos';

  @override
  String get exploreTabNew => 'Novos';

  @override
  String get exploreTabPopular => 'Populares';

  @override
  String get exploreTabCategories => 'Categorias';

  @override
  String get exploreTabForYou => 'Para você';

  @override
  String get exploreTabLists => 'Listas';

  @override
  String get exploreTabIntegratedApps => 'Apps integrados';

  @override
  String get exploreNoVideosAvailable => 'Nenhum vídeo disponível';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Erro: $error';
  }

  @override
  String get exploreDiscoverLists => 'Descobrir listas';

  @override
  String get exploreAboutLists => 'Sobre listas';

  @override
  String get exploreAboutListsDescription =>
      'Listas te ajudam a organizar e curar conteúdo do Divine de duas formas:';

  @override
  String get explorePeopleLists => 'Listas de pessoas';

  @override
  String get explorePeopleListsDescription =>
      'Siga grupos de criadores e veja os últimos vídeos deles';

  @override
  String get exploreVideoLists => 'Listas de vídeos';

  @override
  String get exploreVideoListsDescription =>
      'Crie playlists dos seus vídeos favoritos para assistir depois';

  @override
  String get exploreMyLists => 'Minhas listas';

  @override
  String get exploreSubscribedLists => 'Listas inscritas';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Erro ao carregar listas: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos novos',
      one: '1 vídeo novo',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vídeos novos',
      one: 'vídeo novo',
    );
    return 'Carregar $count $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Carregando vídeo...';

  @override
  String get videoPlayerPlayVideo => 'Reproduzir vídeo';

  @override
  String get videoPlayerMute => 'Silenciar vídeo';

  @override
  String get videoPlayerUnmute => 'Ativar som do vídeo';

  @override
  String get videoPlayerEditVideo => 'Editar vídeo';

  @override
  String get videoPlayerEditVideoTooltip => 'Editar vídeo';

  @override
  String get videoPlayerTapHint =>
      'Toque para reproduzir ou pausar. Toque duplo para curtir.';

  @override
  String get videoSettingsMenuOpen => 'Abrir configurações de reprodução';

  @override
  String get videoSettingsMenuClose => 'Fechar configurações de reprodução';

  @override
  String get videoSettingsCaptionsEnable => 'Ativar legendas';

  @override
  String get videoSettingsCaptionsDisable => 'Desativar legendas';

  @override
  String get contentWarningLabel => 'Aviso de conteúdo';

  @override
  String get contentWarningNudity => 'Nudez';

  @override
  String get contentWarningSexualContent => 'Conteúdo sexual';

  @override
  String get contentWarningPornography => 'Pornografia';

  @override
  String get contentWarningGraphicMedia => 'Mídia gráfica';

  @override
  String get contentWarningViolence => 'Violência';

  @override
  String get contentWarningSelfHarm => 'Automutilação';

  @override
  String get contentWarningDrugUse => 'Uso de drogas';

  @override
  String get contentWarningAlcohol => 'Álcool';

  @override
  String get contentWarningTobacco => 'Tabaco';

  @override
  String get contentWarningGambling => 'Jogos de azar';

  @override
  String get contentWarningProfanity => 'Palavrões';

  @override
  String get contentWarningFlashingLights => 'Luzes piscantes';

  @override
  String get contentWarningAiGenerated => 'Gerado por IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Conteúdo sensível';

  @override
  String get contentWarningDescNudity => 'Contém nudez ou nudez parcial';

  @override
  String get contentWarningDescSexual => 'Contém conteúdo sexual';

  @override
  String get contentWarningDescPorn => 'Contém conteúdo pornográfico explícito';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contém imagens gráficas ou perturbadoras';

  @override
  String get contentWarningDescViolence => 'Contém conteúdo violento';

  @override
  String get contentWarningDescSelfHarm => 'Contém referências à automutilação';

  @override
  String get contentWarningDescDrugs => 'Contém conteúdo relacionado a drogas';

  @override
  String get contentWarningDescAlcohol =>
      'Contém conteúdo relacionado a álcool';

  @override
  String get contentWarningDescTobacco =>
      'Contém conteúdo relacionado a tabaco';

  @override
  String get contentWarningDescGambling =>
      'Contém conteúdo relacionado a jogos de azar';

  @override
  String get contentWarningDescProfanity => 'Contém linguagem forte';

  @override
  String get contentWarningDescFlashingLights =>
      'Contém luzes piscantes (aviso de fotossensibilidade)';

  @override
  String get contentWarningDescAiGenerated => 'Este conteúdo foi gerado por IA';

  @override
  String get contentWarningDescSpoiler => 'Contém spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'O criador marcou isso como sensível';

  @override
  String get contentWarningDescDefault => 'O criador sinalizou este conteúdo';

  @override
  String get contentWarningDetailsTitle => 'Avisos de conteúdo';

  @override
  String get contentWarningDetailsSubtitle =>
      'O criador aplicou os seguintes rótulos:';

  @override
  String get contentWarningManageFilters => 'Gerenciar filtros de conteúdo';

  @override
  String get contentWarningViewAnyway => 'Ver mesmo assim';

  @override
  String get contentWarningReportContentTooltip => 'Denunciar conteúdo';

  @override
  String get contentWarningBlockUserTooltip => 'Bloquear usuário';

  @override
  String get contentWarningBlockedTitle => 'Conteúdo bloqueado';

  @override
  String get contentWarningBlockedPolicy =>
      'Este conteúdo foi bloqueado por violar as políticas.';

  @override
  String get contentWarningNoticeTitle => 'Aviso de conteúdo';

  @override
  String get contentWarningPotentiallyHarmfulTitle =>
      'Conteúdo potencialmente nocivo';

  @override
  String get contentWarningView => 'Ver';

  @override
  String get contentWarningReportAction => 'Denunciar';

  @override
  String get contentWarningHideAllLikeThis => 'Ocultar todo conteúdo parecido';

  @override
  String get contentWarningNoFilterYet =>
      'Ainda não há filtro salvo para este aviso.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vamos ocultar posts assim a partir de agora.';

  @override
  String get videoErrorNotFound => 'Vídeo não encontrado';

  @override
  String get videoErrorNetwork => 'Erro de rede';

  @override
  String get videoErrorTimeout => 'Tempo de carregamento esgotado';

  @override
  String get videoErrorFormat =>
      'Erro no formato do vídeo\n(Tente novamente ou use outro navegador)';

  @override
  String get videoErrorUnsupportedFormat => 'Formato de vídeo não suportado';

  @override
  String get videoErrorPlayback => 'Erro na reprodução do vídeo';

  @override
  String get videoErrorAgeRestricted => 'Conteúdo com restrição de idade';

  @override
  String get videoErrorVerifyAge => 'Verificar idade';

  @override
  String get videoErrorRetry => 'Tentar novamente';

  @override
  String get videoErrorContentRestricted => 'Conteúdo restrito';

  @override
  String get videoErrorContentRestrictedBody =>
      'Este vídeo foi restringido pelo relay.';

  @override
  String get videoErrorVerifyAgeBody =>
      'Verifique sua idade para ver este vídeo.';

  @override
  String get videoErrorSkip => 'Pular';

  @override
  String get videoErrorVerifyAgeButton => 'Verificar idade';

  @override
  String get videoFollowButtonFollowing => 'Seguindo';

  @override
  String get videoFollowButtonFollow => 'Seguir';

  @override
  String get audioAttributionOriginalSound => 'Som original';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirado em @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'com @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'com @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colaboradores',
      one: '1 colaborador',
    );
    return '$_temp0. Toque para ver o perfil.';
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
    return '#$hashtag. Tap to view videos with this hashtag.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Compartilhar vídeo';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post compartilhado com $recipientName';
  }

  @override
  String get shareFailedToSend => 'Falha ao enviar vídeo';

  @override
  String get shareAddedToBookmarks => 'Adicionado aos favoritos';

  @override
  String get shareRemovedFromBookmarks => 'Removido dos favoritos';

  @override
  String get shareFailedToAddBookmark => 'Falha ao adicionar aos favoritos';

  @override
  String get shareFailedToRemoveBookmark => 'Falha ao remover dos favoritos';

  @override
  String get shareActionFailed => 'A ação falhou';

  @override
  String get shareWithTitle => 'Compartilhar com';

  @override
  String get shareFindPeople => 'Encontrar pessoas';

  @override
  String get shareFindPeopleMultiline => 'Encontrar\npessoas';

  @override
  String get shareSent => 'Enviado';

  @override
  String get shareContactFallback => 'Contato';

  @override
  String get shareUserFallback => 'Usuário';

  @override
  String shareSendingTo(String name) {
    return 'Enviando para $name';
  }

  @override
  String get shareMessageHint => 'Adicione uma mensagem opcional...';

  @override
  String get videoActionUnlike => 'Descurtir vídeo';

  @override
  String get videoActionLike => 'Curtir vídeo';

  @override
  String get videoActionAutoLabel => 'Auto';

  @override
  String get videoActionLikeLabel => 'Curtir';

  @override
  String get videoActionReplyLabel => 'Responder';

  @override
  String get videoActionRepostLabel => 'Repostar';

  @override
  String get videoActionShareLabel => 'Compartilhar';

  @override
  String get videoActionReportLabel => 'Denunciar';

  @override
  String get videoActionReport => 'Denunciar vídeo';

  @override
  String get videoActionEditLabel => 'Editar';

  @override
  String get videoActionEdit => 'Editar vídeo';

  @override
  String get videoActionAboutLabel => 'Sobre';

  @override
  String get videoActionEnableAutoAdvance => 'Ativar avanço automático';

  @override
  String get videoActionDisableAutoAdvance => 'Desativar avanço automático';

  @override
  String get videoActionRemoveRepost => 'Remover repost';

  @override
  String get videoActionRepost => 'Repostar vídeo';

  @override
  String get videoActionViewComments => 'Ver comentários';

  @override
  String get videoActionMoreOptions => 'Mais opções';

  @override
  String get videoActionHideSubtitles => 'Ocultar legendas';

  @override
  String get videoActionShowSubtitles => 'Mostrar legendas';

  @override
  String get videoEngagementLikersTitle => 'Curtido por';

  @override
  String get videoEngagementRepostersTitle => 'Repostado por';

  @override
  String get videoEngagementLikersEmpty => 'Ainda sem curtidas';

  @override
  String get videoEngagementRepostersEmpty => 'Ainda sem reposts';

  @override
  String get videoEngagementLoadFailed => 'Não foi possível carregar a lista';

  @override
  String get videoOverlayOpenMetadataFromTitle => 'Abrir detalhes do vídeo';

  @override
  String get videoOverlayOpenMetadataFromDescription =>
      'Abrir detalhes do vídeo';

  @override
  String get videoOverlayCommentBarHint => 'Add comment...';

  @override
  String get videoOverlayCommentBarSemanticLabel => 'Add a comment';

  @override
  String get videoOverlayCommentBarSendLabel => 'Send comment';

  @override
  String get videoOverlayCommentPostedSnackbar => 'Comment posted';

  @override
  String get videoOverlayCommentPostFailedSnackbar => 'Couldn\'t post comment';

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
  String get metadataBadgeNotDivine => 'Não-Divine';

  @override
  String get metadataBadgeHumanMade => 'Feito por humano';

  @override
  String get metadataSoundsLabel => 'Sons';

  @override
  String get metadataOriginalSound => 'Som original';

  @override
  String get metadataVerificationLabel => 'Verificação';

  @override
  String get metadataDeviceAttestation => 'Atestação do dispositivo';

  @override
  String get metadataProofManifest => 'Manifesto de prova';

  @override
  String get metadataCreatorLabel => 'Criador';

  @override
  String get metadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get metadataInspiredByLabel => 'Inspirado em';

  @override
  String get metadataRepostedByLabel => 'Repostado por';

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Curtidas';

  @override
  String get metadataCommentsLabel => 'Comentários';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String metadataPostedDateSemantics(String date) {
    return 'Publicado em $date';
  }

  @override
  String get devOptionsTitle => 'Opções do desenvolvedor';

  @override
  String get devOptionsPageLoadTimes => 'Tempos de carregamento de página';

  @override
  String get devOptionsNoPageLoads =>
      'Nenhum carregamento de página registrado ainda.\nNavegue pelo app para ver os dados de tempo.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visível: ${visibleMs}ms  |  Dados: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Telas mais lentas';

  @override
  String get devOptionsVideoPlaybackFormat => 'Formato de reprodução de vídeo';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Trocar ambiente?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Trocar para $envName?\n\nIsso vai limpar o cache de vídeos e reconectar ao novo relay.';
  }

  @override
  String get devOptionsCancel => 'Cancelar';

  @override
  String get devOptionsSwitch => 'Trocar';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Trocado para $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Trocado para $formatName — cache limpo';
  }

  @override
  String get featureFlagTitle => 'Feature flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Redefinir todas as flags para o padrão';

  @override
  String get featureFlagResetToDefault => 'Redefinir para o padrão';

  @override
  String get featureFlagAppRecovery => 'Recuperação do app';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Se o app estiver travando ou se comportando de forma estranha, tente limpar o cache.';

  @override
  String get featureFlagClearAllCache => 'Limpar todo o cache';

  @override
  String get featureFlagCacheInfo => 'Informações do cache';

  @override
  String get featureFlagClearCacheTitle => 'Limpar todo o cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'Isso vai limpar todos os dados em cache, incluindo:\n• Notificações\n• Perfis de usuários\n• Favoritos\n• Arquivos temporários\n\nVocê vai precisar entrar de novo. Continuar?';

  @override
  String get featureFlagClearCache => 'Limpar cache';

  @override
  String get featureFlagClearingCache => 'Limpando cache...';

  @override
  String get featureFlagSuccess => 'Sucesso';

  @override
  String get featureFlagError => 'Erro';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache limpo com sucesso. Reinicie o app.';

  @override
  String get featureFlagClearCacheFailure =>
      'Falha ao limpar alguns itens do cache. Verifique os logs para mais detalhes.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Informações do cache';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Tamanho total do cache: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'O cache inclui:\n• Histórico de notificações\n• Dados de perfil de usuários\n• Miniaturas de vídeo\n• Arquivos temporários\n• Índices do banco de dados';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'O Divine é um sistema aberto - você controla suas conexões';

  @override
  String get relaySettingsInfoDescription =>
      'Estes relays distribuem seu conteúdo pela rede descentralizada Nostr. Você pode adicionar ou remover relays como quiser.';

  @override
  String get relaySettingsLearnMoreNostr => 'Saiba mais sobre o Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Encontre relays públicos em nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App não funcional';

  @override
  String get relaySettingsRequiresRelay =>
      'O Divine precisa de pelo menos um relay para carregar vídeos, publicar conteúdo e sincronizar dados.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Restaurar relay padrão';

  @override
  String get relaySettingsAddCustomRelay => 'Adicionar relay personalizado';

  @override
  String get relaySettingsAddRelay => 'Adicionar relay';

  @override
  String get relaySettingsRetry => 'Tentar novamente';

  @override
  String get relaySettingsNoStats => 'Ainda não há estatísticas disponíveis';

  @override
  String get relaySettingsConnection => 'Conexão';

  @override
  String get relaySettingsConnected => 'Conectado';

  @override
  String get relaySettingsDisconnected => 'Desconectado';

  @override
  String get relaySettingsSessionDuration => 'Duração da sessão';

  @override
  String get relaySettingsLastConnected => 'Última conexão';

  @override
  String get relaySettingsDisconnectedLabel => 'Desconectado';

  @override
  String get relaySettingsReason => 'Motivo';

  @override
  String get relaySettingsActiveSubscriptions => 'Assinaturas ativas';

  @override
  String get relaySettingsTotalSubscriptions => 'Total de assinaturas';

  @override
  String get relaySettingsEventsReceived => 'Eventos recebidos';

  @override
  String get relaySettingsEventsSent => 'Eventos enviados';

  @override
  String get relaySettingsRequestsThisSession => 'Solicitações nesta sessão';

  @override
  String get relaySettingsFailedRequests => 'Solicitações falhas';

  @override
  String relaySettingsLastError(String error) {
    return 'Último erro: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo =>
      'Carregando informações do relay...';

  @override
  String get relaySettingsAboutRelay => 'Sobre o relay';

  @override
  String get relaySettingsSupportedNips => 'NIPs suportados';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Ver site';

  @override
  String get relaySettingsRemoveRelayTitle => 'Remover relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Tem certeza que quer remover este relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Cancelar';

  @override
  String get relaySettingsRemove => 'Remover';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay removido: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Falha ao remover o relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forçando reconexão do relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Conectado a $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Falha ao conectar aos relays. Verifique sua conexão de rede.';

  @override
  String get relaySettingsAddRelayTitle => 'Adicionar relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Digite a URL WebSocket do relay que você quer adicionar:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Navegue por relays públicos em nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Adicionar';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay adicionado: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Falha ao adicionar o relay. Verifique a URL e tente novamente.';

  @override
  String get relaySettingsInvalidUrl =>
      'A URL do relay deve começar com wss:// ou ws://';

  @override
  String get relaySettingsInsecureUrl =>
      'A URL do relay precisa usar wss:// (ws:// só é permitido em localhost)';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay padrão restaurado: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Falha ao restaurar o relay padrão. Verifique sua conexão de rede.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'Não foi possível abrir o navegador';

  @override
  String get relaySettingsFailedToOpenLink => 'Falha ao abrir o link';

  @override
  String get relaySettingsExternalRelay => 'Relay externo';

  @override
  String get relaySettingsNotConnected => 'Não conectado';

  @override
  String relaySettingsDisconnectedAgo(String duration) {
    return 'Desconectado há $duration';
  }

  @override
  String relaySettingsSubscriptionsSummary(int count) {
    return '$count inscrições';
  }

  @override
  String relaySettingsEventsSummary(String count) {
    return '$count eventos';
  }

  @override
  String relaySettingsTimeAgo(String duration) {
    return 'há $duration';
  }

  @override
  String get nostrSettingsIntro =>
      'O Divine usa o protocolo Nostr para publicação descentralizada. Seu conteúdo vive nos relays que você escolher, e suas chaves são sua identidade.';

  @override
  String get nostrSettingsSectionNetwork => 'Rede';

  @override
  String get nostrSettingsSectionAccount => 'Conta';

  @override
  String get nostrSettingsSectionDangerZone => 'Zona de perigo';

  @override
  String get nostrSettingsRelays => 'Relays';

  @override
  String get nostrSettingsRelaysSubtitle => 'Gerenciar conexões de relay Nostr';

  @override
  String get nostrSettingsRelayDiagnostics => 'Diagnóstico de relay';

  @override
  String get nostrSettingsRelayDiagnosticsSubtitle =>
      'Depure conectividade de relay e problemas de rede';

  @override
  String get nostrSettingsMediaServers => 'Servidores de mídia';

  @override
  String get nostrSettingsMediaServersSubtitle =>
      'Configurar servidores de upload Blossom';

  @override
  String get nostrSettingsDeveloperOptions => 'Opções de desenvolvedor';

  @override
  String get nostrSettingsDeveloperOptionsSubtitle =>
      'Seletor de ambiente e opções de depuração';

  @override
  String get nostrSettingsExperimentalFeaturesSubtitle =>
      'Ative flags de recursos que podem dar chilique.';

  @override
  String get nostrSettingsKeyManagement => 'Gerenciamento de chaves';

  @override
  String get nostrSettingsKeyManagementSubtitle =>
      'Exporte, faça backup e restaure suas chaves Nostr';

  @override
  String get nostrSettingsClientAttribution => 'Atribuição do cliente';

  @override
  String get nostrSettingsClientAttributionSubtitle =>
      'Inclua uma tag de cliente Divine nos eventos que você publica para que outros apps Nostr possam atribuí-los corretamente.';

  @override
  String get nostrSettingsRemoveKeys => 'Remover chaves do dispositivo';

  @override
  String get nostrSettingsRemoveKeysSubtitle =>
      'Apague sua chave privada apenas deste dispositivo. Seu conteúdo continua nos relays, mas você vai precisar do backup da nsec para acessar sua conta de novo.';

  @override
  String get nostrSettingsCouldNotRemoveKeys =>
      'Não foi possível remover as chaves deste dispositivo. Tente novamente.';

  @override
  String nostrSettingsFailedToRemoveKeys(String error) {
    return 'Falha ao remover chaves: $error';
  }

  @override
  String get nostrSettingsDeleteAccount => 'Excluir conta e dados';

  @override
  String get nostrSettingsDeleteAccountSubtitle =>
      'Apague PERMANENTEMENTE sua conta e TODO o conteúdo dos relays Nostr. Isso não pode ser desfeito.';

  @override
  String get relayDiagnosticTitle => 'Diagnósticos de relay';

  @override
  String get relayDiagnosticRefreshTooltip => 'Atualizar diagnósticos';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Última atualização: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Status do relay';

  @override
  String get relayDiagnosticInitialized => 'Inicializado';

  @override
  String get relayDiagnosticReady => 'Pronto';

  @override
  String get relayDiagnosticNotInitialized => 'Não inicializado';

  @override
  String get relayDiagnosticDatabaseEvents => 'Eventos do banco de dados';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Assinaturas ativas';

  @override
  String get relayDiagnosticExternalRelays => 'Relays externos';

  @override
  String get relayDiagnosticConfigured => 'Configurado';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Conectado';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Eventos de vídeo';

  @override
  String get relayDiagnosticHomeFeed => 'Feed principal';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count vídeos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Descoberta';

  @override
  String get relayDiagnosticLoading => 'Carregando';

  @override
  String get relayDiagnosticYes => 'Sim';

  @override
  String get relayDiagnosticNo => 'Não';

  @override
  String get relayDiagnosticTestDirectQuery => 'Testar consulta direta';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Conectividade de rede';

  @override
  String get relayDiagnosticRunNetworkTest => 'Executar teste de rede';

  @override
  String get relayDiagnosticBlossomServer => 'Servidor Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Testar todos os endpoints';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Erro';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL base';

  @override
  String get relayDiagnosticSummary => 'Resumo';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (média ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retestar tudo';

  @override
  String get relayDiagnosticRetrying => 'Tentando novamente...';

  @override
  String get relayDiagnosticRetryConnection => 'Tentar reconectar';

  @override
  String get relayDiagnosticTroubleshooting => 'Solução de problemas';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Status verde = Conectado e funcionando\n• Status vermelho = Falha na conexão\n• Se o teste de rede falhar, verifique a conexão com a internet\n• Se os relays estiverem configurados mas não conectados, toque em \"Tentar reconectar\"\n• Tire uma captura desta tela para debug';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'Todos os endpoints REST estão saudáveis!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Alguns endpoints REST falharam - veja os detalhes acima';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Encontrados $count eventos de vídeo no banco de dados';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Consulta falhou: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Conectado a $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Falha ao conectar a qualquer relay';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Tentativa de reconexão falhou: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Conectado e autenticado';

  @override
  String get relayDiagnosticConnectedOnly => 'Conectado';

  @override
  String get relayDiagnosticNotConnected => 'Não conectado';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'Nenhum relay configurado';

  @override
  String get relayDiagnosticFailed => 'Falhou';

  @override
  String get notificationSettingsTitle => 'Notificações';

  @override
  String get notificationSettingsResetTooltip => 'Redefinir para o padrão';

  @override
  String get notificationSettingsTypes => 'Tipos de notificação';

  @override
  String get notificationSettingsLikes => 'Curtidas';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Quando alguém curte seus vídeos';

  @override
  String get notificationSettingsComments => 'Comentários';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Quando alguém comenta nos seus vídeos';

  @override
  String get notificationSettingsFollows => 'Seguidores';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Quando alguém começa a te seguir';

  @override
  String get notificationSettingsMentions => 'Menções';

  @override
  String get notificationSettingsMentionsSubtitle => 'Quando você é mencionado';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Quando alguém reposta seus vídeos';

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
  String get notificationSettingsActions => 'Ações';

  @override
  String get notificationSettingsMarkAllAsRead => 'Marcar tudo como lido';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marcar todas as notificações como lidas';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Todas as notificações marcadas como lidas';

  @override
  String get notificationSettingsMarkAllAsReadFailed =>
      'Falha ao marcar todas como lidas';

  @override
  String get notificationSettingsResetToDefaults =>
      'Configurações redefinidas para o padrão';

  @override
  String get notificationSettingsAbout => 'Sobre as notificações';

  @override
  String get notificationSettingsAboutDescription =>
      'As notificações são alimentadas pelo protocolo Nostr. Atualizações em tempo real dependem da sua conexão com os relays Nostr. Algumas notificações podem ter atrasos.';

  @override
  String get safetySettingsTitle => 'Segurança e privacidade';

  @override
  String get safetySettingsLabel => 'CONFIGURAÇÕES';

  @override
  String get safetySettingsWhatYouSee => 'O QUE VOCÊ VÊ';

  @override
  String get safetySettingsWhatYouPublish => 'O QUE VOCÊ PUBLICA';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Mostrar apenas vídeos hospedados pelo Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ocultar vídeos servidos de outros hosts de mídia';

  @override
  String get safetySettingsModeration => 'MODERAÇÃO';

  @override
  String get safetySettingsBlockedUsers => 'USUÁRIOS BLOQUEADOS';

  @override
  String get safetySettingsAgeVerification => 'VERIFICAÇÃO DE IDADE';

  @override
  String get safetySettingsAgeConfirmation =>
      'Confirmo que tenho 18 anos ou mais';

  @override
  String get safetySettingsAgeRequired => 'Necessário para ver conteúdo adulto';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Serviço oficial de moderação (ativado por padrão)';

  @override
  String get safetySettingsPeopleIFollow => 'Pessoas que eu sigo';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Assinar rótulos de pessoas que você segue';

  @override
  String get safetySettingsAddCustomLabeler => 'Adicionar rótulo personalizado';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Digite a npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Adicionar rótulo personalizado';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Digite o endereço npub';

  @override
  String get safetySettingsNoBlockedUsers => 'Nenhum usuário bloqueado';

  @override
  String get safetySettingsUnblock => 'Desbloquear';

  @override
  String get safetySettingsUserUnblocked => 'Usuário desbloqueado';

  @override
  String get safetySettingsCancel => 'Cancelar';

  @override
  String get safetySettingsAdd => 'Adicionar';

  @override
  String get analyticsTitle => 'Estatísticas de criador';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnósticos';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Alternar diagnósticos';

  @override
  String get analyticsRetry => 'Tentar novamente';

  @override
  String get analyticsUnableToLoad =>
      'Não foi possível carregar as estatísticas.';

  @override
  String get analyticsSignInRequired =>
      'Entre para ver as estatísticas de criador.';

  @override
  String get analyticsViewDataUnavailable =>
      'As visualizações estão indisponíveis no relay para esses posts. As métricas de curtidas/comentários/reposts continuam precisas.';

  @override
  String get analyticsViewDataTitle => 'Dados de visualização';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Atualizado $time • Os scores usam curtidas, comentários, reposts e views/loops do Funnelcake quando disponíveis.';
  }

  @override
  String get analyticsVideos => 'Vídeos';

  @override
  String get analyticsViews => 'Visualizações';

  @override
  String get analyticsInteractions => 'Interações';

  @override
  String get analyticsEngagement => 'Engajamento';

  @override
  String get analyticsFollowers => 'Seguidores';

  @override
  String get analyticsAvgPerPost => 'Média/Post';

  @override
  String get analyticsInteractionMix => 'Mix de interações';

  @override
  String get analyticsLikes => 'Curtidas';

  @override
  String get analyticsComments => 'Comentários';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Destaques de desempenho';

  @override
  String get analyticsMostViewed => 'Mais visto';

  @override
  String get analyticsMostDiscussed => 'Mais comentado';

  @override
  String get analyticsMostReposted => 'Mais repostado';

  @override
  String get analyticsNoVideosYet => 'Sem vídeos ainda';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Dados de visualização indisponíveis';

  @override
  String analyticsViewsCount(String count) {
    return '$count visualizações';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count comentários';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Conteúdo em destaque';

  @override
  String get analyticsPublishPrompt =>
      'Publique alguns vídeos para ver o ranking.';

  @override
  String get analyticsEngagementRateExplainer =>
      '% à direita = taxa de engajamento (interações divididas por visualizações).';

  @override
  String get analyticsEngagementRateNoViews =>
      'A taxa de engajamento precisa de dados de visualização; os valores aparecem como N/A até as visualizações estarem disponíveis.';

  @override
  String get analyticsEngagementLabel => 'Engajamento';

  @override
  String get analyticsViewsUnavailable => 'visualizações indisponíveis';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interações';
  }

  @override
  String get analyticsPostAnalytics => 'Estatísticas do post';

  @override
  String get analyticsOpenPost => 'Abrir post';

  @override
  String get analyticsRecentDailyInteractions => 'Interações diárias recentes';

  @override
  String get analyticsNoActivityYet => 'Ainda sem atividade neste período.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interações = curtidas + comentários + reposts por data do post.';

  @override
  String get analyticsDailyBarExplainer =>
      'O tamanho da barra é relativo ao seu dia de maior engajamento nesta janela.';

  @override
  String get analyticsAudienceSnapshot => 'Resumo do público';

  @override
  String analyticsFollowersCount(String count) {
    return 'Seguidores: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Seguindo: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Detalhes do público por fonte/geografia/hora vão aparecer conforme o Funnelcake adicionar endpoints de estatísticas de público.';

  @override
  String get analyticsRetention => 'Retenção';

  @override
  String get analyticsRetentionWithViews =>
      'A curva de retenção e o detalhamento de tempo de visualização vão aparecer assim que os dados de retenção por segundo/faixa chegarem do Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Dados de retenção indisponíveis até que as estatísticas de visualização + tempo de reprodução sejam retornadas pelo Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnósticos';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total de vídeos: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Com visualizações: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Sem visualizações: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hidratado (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hidratado (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Fontes: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Usar dados de fixture';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Criar uma nova conta Divine';

  @override
  String get authCreateNewAccountShort => 'Create new account';

  @override
  String get authSignInDifferentAccount => 'Entrar com outra conta';

  @override
  String get authUseAnotherAccount => 'Use another account';

  @override
  String authContinueAs(String displayName) {
    return 'Continue as $displayName';
  }

  @override
  String get authRecoveryDraftsOwner =>
      'Seus rascunhos e clipes estão salvos nesta conta';

  @override
  String get authRecoveryOtherAccountWarning =>
      'Entrar aqui vai esconder esses rascunhos e clipes';

  @override
  String get authTermsPrefix =>
      'By selecting an option below, you confirm you are at least 16 years old (or have completed ';

  @override
  String get authTermsAgeAuthorizationCta => 'Divine age authorization';

  @override
  String get authTermsAfterAgeAuthorization => ') and agree to the ';

  @override
  String get authTermsOfService => 'Termos de Serviço';

  @override
  String get authPrivacyPolicy => 'Política de Privacidade';

  @override
  String get authTermsAnd => ', e ';

  @override
  String get authSafetyStandards => 'Padrões de Segurança';

  @override
  String get authAmberNotInstalled => 'O app Amber não está instalado';

  @override
  String get authAmberConnectionFailed => 'Falha ao conectar com o Amber';

  @override
  String get authPasswordResetSent =>
      'Se existir uma conta com esse e-mail, um link de redefinição de senha foi enviado.';

  @override
  String get authSignInTitle => 'Entrar';

  @override
  String get authEmailLabel => 'E-mail';

  @override
  String get authPasswordLabel => 'Senha';

  @override
  String get authConfirmPasswordLabel => 'Confirmar senha';

  @override
  String get authEmailRequired => 'O e-mail é obrigatório';

  @override
  String get authEmailInvalid => 'Insira um e-mail válido';

  @override
  String get authPasswordRequired => 'A senha é obrigatória';

  @override
  String get authConfirmPasswordRequired => 'Confirme sua senha';

  @override
  String get authPasswordsDoNotMatch => 'As senhas não coincidem';

  @override
  String get authForgotPassword => 'Esqueceu a senha?';

  @override
  String get authImportNostrKey => 'Importar chave Nostr';

  @override
  String get authConnectSignerApp => 'Conectar com um app signer';

  @override
  String get authSignInWithAmber => 'Entrar com Amber';

  @override
  String get authSignInWithBrowserExtension =>
      'Entrar com extensão do navegador';

  @override
  String get authNip07ConnectionFailed =>
      'Não foi possível conectar à sua extensão do navegador.';

  @override
  String get authNip07ExtensionNotFound =>
      'Nenhuma extensão do navegador encontrada. Instale Alby, nos2x ou outra extensão compatível com NIP-07.';

  @override
  String get authSignInOptionsTitle => 'Opções de login';

  @override
  String get authInfoEmailPasswordTitle => 'E-mail e senha';

  @override
  String get authInfoEmailPasswordDescription =>
      'Entre com sua conta Divine. Se você se registrou com e-mail e senha, use-os aqui.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Já tem uma identidade Nostr? Importe sua chave privada nsec de outro cliente.';

  @override
  String get authInfoSignerAppTitle => 'App Signer';

  @override
  String get authInfoSignerAppDescription =>
      'Conecte-se usando um signer remoto compatível com NIP-46, como o nsecBunker, para maior segurança da chave.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Use o app signer Amber no Android para gerenciar suas chaves Nostr com segurança.';

  @override
  String get authInfoBrowserExtensionTitle => 'Extensão do Navegador';

  @override
  String get authInfoBrowserExtensionDescription =>
      'Entre com uma extensão do navegador NIP-07 como Alby ou nos2x. Suas chaves ficam na extensão — Divine nunca as vê.';

  @override
  String get authCreateAccountTitle => 'Criar conta';

  @override
  String get authBackToInviteCode => 'Voltar para o código de convite';

  @override
  String get authUseDivineNoBackup => 'Usar o Divine sem backup';

  @override
  String get authSkipConfirmTitle => 'Só mais uma coisa...';

  @override
  String get authSkipConfirmKeyCreated =>
      'Você entrou! Vamos criar uma chave segura que alimenta sua conta Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Sem um e-mail, sua chave é a única forma do Divine saber que esta conta é sua.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Você pode acessar sua chave no app, mas, se você não for técnico, recomendamos adicionar um e-mail e senha agora. Isso facilita entrar e recuperar sua conta se você perder ou resetar este dispositivo.';

  @override
  String get authAddEmailPassword => 'Adicionar e-mail e senha';

  @override
  String get authUseThisDeviceOnly => 'Usar apenas este dispositivo';

  @override
  String get authCompleteRegistration => 'Complete seu registro';

  @override
  String get authVerifying => 'Verificando...';

  @override
  String get authVerificationLinkSent =>
      'Enviamos um link de verificação para:';

  @override
  String get authClickVerificationLink =>
      'Clique no link no seu e-mail para\ncompletar o registro.';

  @override
  String get authPleaseWaitVerifying =>
      'Aguarde enquanto verificamos seu e-mail...';

  @override
  String get authWaitingForVerification => 'Aguardando verificação';

  @override
  String get authOpenEmailApp => 'Abrir app de e-mail';

  @override
  String get authWelcomeToDivine => 'Bem-vindo ao Divine!';

  @override
  String get authEmailVerified => 'Seu e-mail foi verificado.';

  @override
  String get authSigningYouIn => 'Entrando';

  @override
  String get authErrorTitle => 'Opa.';

  @override
  String get authVerificationFailed =>
      'Falhamos ao verificar seu e-mail.\nTente novamente.';

  @override
  String get authStartOver => 'Começar de novo';

  @override
  String get authEmailVerifiedLogin =>
      'E-mail verificado! Faça login para continuar.';

  @override
  String get authVerificationLinkExpired =>
      'Este link de verificação não é mais válido.';

  @override
  String get authVerificationConnectionError =>
      'Não foi possível verificar o e-mail. Verifique sua conexão e tente novamente.';

  @override
  String get authWaitlistConfirmTitle => 'Você entrou!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Vamos mandar novidades para $email.\nQuando houver mais códigos de convite, enviaremos pra você.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'O acesso por convite está temporariamente indisponível.';

  @override
  String get authInviteUnavailableBody =>
      'Tente novamente em instantes ou entre em contato com o suporte se precisar de ajuda.';

  @override
  String get authTryAgain => 'Tentar novamente';

  @override
  String get authContactSupport => 'Contatar suporte';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Não foi possível abrir $email';
  }

  @override
  String get authAddInviteCode => 'Adicione seu código de convite';

  @override
  String get authInviteCodeLabel => 'Código de convite';

  @override
  String get authEnterYourCode => 'Digite seu código';

  @override
  String get authNext => 'Próximo';

  @override
  String get authJoinWaitlist => 'Entrar na lista de espera';

  @override
  String get authJoinWaitlistTitle => 'Entre na lista de espera';

  @override
  String get authJoinWaitlistDescription =>
      'Compartilhe seu e-mail e enviaremos novidades conforme o acesso for liberado.';

  @override
  String get authJoinWaitlistNewsletterOptIn => 'Send me Divine inspiration';

  @override
  String get authInviteAccessHelp => 'Ajuda com acesso por convite';

  @override
  String get authGeneratingConnection => 'Gerando conexão...';

  @override
  String get authConnectedAuthenticating => 'Conectado! Autenticando...';

  @override
  String get authConnectionTimedOut => 'Conexão expirou';

  @override
  String get authApproveConnection =>
      'Certifique-se de ter aprovado a conexão no seu app signer.';

  @override
  String get authConnectionCancelled => 'Conexão cancelada';

  @override
  String get authConnectionCancelledMessage => 'A conexão foi cancelada.';

  @override
  String get authConnectionFailed => 'Falha na conexão';

  @override
  String get authUnknownError => 'Ocorreu um erro desconhecido.';

  @override
  String get authUrlCopied => 'URL copiada para a área de transferência';

  @override
  String get authConnectToDivine => 'Conectar ao Divine';

  @override
  String get authPasteBunkerUrl => 'Colar URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker inválida. Ela deve começar com bunker://';

  @override
  String get authScanSignerApp => 'Escaneie com seu\napp signer para conectar.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Aguardando conexão... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copiar URL';

  @override
  String get authShare => 'Compartilhar';

  @override
  String get authAddBunker => 'Adicionar bunker';

  @override
  String get authCompatibleSignerApps => 'Apps signer compatíveis';

  @override
  String get authFailedToConnect => 'Falha ao conectar';

  @override
  String get authResetPasswordTitle => 'Redefinir senha';

  @override
  String get authResetPasswordSubtitle =>
      'Digite sua nova senha. Ela deve ter pelo menos 8 caracteres.';

  @override
  String get authNewPasswordLabel => 'Nova senha';

  @override
  String get authConfirmNewPasswordLabel => 'Confirmar nova senha';

  @override
  String get authPasswordTooShort => 'A senha deve ter pelo menos 8 caracteres';

  @override
  String get authPasswordResetSuccess =>
      'Senha redefinida com sucesso. Faça login.';

  @override
  String get authPasswordResetFailed => 'Falha ao redefinir a senha';

  @override
  String get authUnexpectedError =>
      'Ocorreu um erro inesperado. Tente novamente.';

  @override
  String get authUpdatePassword => 'Atualizar senha';

  @override
  String get authSecureAccountTitle => 'Proteger conta';

  @override
  String get authUnableToAccessKeys =>
      'Não foi possível acessar suas chaves. Tente novamente.';

  @override
  String get authRegistrationFailed => 'Falha no registro';

  @override
  String get authRegistrationComplete =>
      'Registro completo. Verifique seu e-mail.';

  @override
  String get authVerificationFailedTitle => 'Verificação falhou';

  @override
  String get authClose => 'Fechar';

  @override
  String get authAccountSecured => 'Conta protegida!';

  @override
  String get authAccountLinkedToEmail =>
      'Sua conta agora está vinculada ao seu e-mail.';

  @override
  String get authVerifyYourEmail => 'Verifique seu e-mail';

  @override
  String get authClickLinkContinue =>
      'Clique no link no seu e-mail para completar o registro. Você pode continuar usando o app enquanto isso.';

  @override
  String get authWaitingForVerificationEllipsis => 'Aguardando verificação...';

  @override
  String get authContinueToApp => 'Ir para o app';

  @override
  String get authResetPassword => 'Redefinir senha';

  @override
  String get authResetPasswordDescription =>
      'Digite seu endereço de e-mail e enviaremos um link para redefinir sua senha.';

  @override
  String get authFailedToSendResetEmail =>
      'Falha ao enviar o e-mail de redefinição.';

  @override
  String get authUnexpectedErrorShort => 'Ocorreu um erro inesperado.';

  @override
  String get authSending => 'Enviando...';

  @override
  String get authSendResetLink => 'Enviar link de redefinição';

  @override
  String get authEmailSent => 'E-mail enviado!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Enviamos um link de redefinição de senha para $email. Clique no link do e-mail para atualizar sua senha.';
  }

  @override
  String get authSignInButton => 'Entrar';

  @override
  String get authVerificationErrorTimeout =>
      'A verificação expirou. Tente se registrar novamente.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verificação falhou — código de autorização ausente.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verificação falhou. Tente novamente.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Erro de rede durante o login. Tente novamente.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verificação falhou. Tente se registrar novamente.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Falha no login. Tente entrar manualmente.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Esse código de convite não está mais disponível. Volte para o seu código de convite, entre na lista de espera ou contate o suporte.';

  @override
  String get authInviteErrorInvalid =>
      'Esse código de convite não pode ser usado agora. Volte para o seu código de convite, entre na lista de espera ou contate o suporte.';

  @override
  String get authInviteErrorTemporary =>
      'Não conseguimos confirmar seu convite agora. Volte para o seu código de convite e tente novamente ou contate o suporte.';

  @override
  String get authInviteErrorUnknown =>
      'Não conseguimos ativar seu convite. Volte para o seu código de convite, entre na lista de espera ou contate o suporte.';

  @override
  String get shareSheetSave => 'Salvar';

  @override
  String get shareSheetSaveToGallery => 'Salvar na galeria';

  @override
  String get shareSheetSaveWithWatermark => 'Salvar com marca d\'água';

  @override
  String get shareSheetSaveVideo => 'Salvar vídeo';

  @override
  String get shareSheetAddToClips => 'Adicionar aos clipes';

  @override
  String get shareSheetNameClipTitle => 'Name this clip';

  @override
  String get shareSheetNameClipSubtitle =>
      'Pick a name you\'ll recognize in your library.';

  @override
  String get shareSheetClipTitleLabel => 'Clip title';

  @override
  String get shareSheetSaveClip => 'Save clip';

  @override
  String shareSheetSavedClipToClips(String title) {
    return 'Saved \"$title\" to clips';
  }

  @override
  String get shareSheetUntitledClip => 'Untitled clip';

  @override
  String get shareSheetAddToClipsFailed =>
      'Não foi possível adicionar aos clipes';

  @override
  String get shareSheetAddToList => 'Adicionar à lista';

  @override
  String get shareSheetCopy => 'Copiar';

  @override
  String get shareSheetShareVia => 'Compartilhar via';

  @override
  String get shareSheetReport => 'Denunciar';

  @override
  String get shareSheetEventJson => 'JSON do evento';

  @override
  String get shareSheetEventId => 'ID do evento';

  @override
  String get shareSheetMoreActions => 'Mais ações';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Salvo no rolo da câmera';

  @override
  String get watermarkDownloadShare => 'Compartilhar';

  @override
  String get watermarkDownloadDone => 'Concluído';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Acesso a fotos necessário';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Para salvar vídeos, permita o acesso a Fotos nas Configurações.';

  @override
  String get watermarkDownloadOpenSettings => 'Abrir Configurações';

  @override
  String get watermarkDownloadNotNow => 'Agora não';

  @override
  String get watermarkDownloadFailed => 'Download falhou';

  @override
  String get watermarkDownloadDismiss => 'Dispensar';

  @override
  String get watermarkDownloadStageDownloading => 'Baixando vídeo';

  @override
  String get watermarkDownloadStageWatermarking => 'Adicionando marca d\'água';

  @override
  String get watermarkDownloadStageSaving => 'Salvando no rolo da câmera';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Buscando o vídeo na rede...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Aplicando a marca d\'água do Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Salvando o vídeo com marca d\'água no seu rolo da câmera...';

  @override
  String get uploadProgressVideoUpload => 'Upload de vídeo';

  @override
  String get uploadProgressPause => 'Pausar';

  @override
  String get uploadProgressResume => 'Retomar';

  @override
  String get uploadProgressGoBack => 'Voltar';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Tentar novamente ($count restantes)';
  }

  @override
  String get uploadProgressDelete => 'Excluir';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'há ${count}d';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'há ${count}h';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'há ${count}min';
  }

  @override
  String get uploadProgressJustNow => 'Agora mesmo';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Enviando $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Pausado $percent%';
  }

  @override
  String get badgeExplanationClose => 'Fechar';

  @override
  String get badgeExplanationOriginalVineArchive => 'Arquivo original do Vine';

  @override
  String get badgeExplanationCameraProof => 'Prova de câmera';

  @override
  String get badgeExplanationAuthenticitySignals => 'Sinais de autenticidade';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Este vídeo é um Vine original recuperado do Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Antes do Vine encerrar em 2017, o ArchiveTeam e o Internet Archive trabalharam para preservar milhões de Vines para a posteridade. Este conteúdo faz parte desse esforço histórico de preservação.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Estatísticas originais: $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Saiba mais sobre a preservação do arquivo do Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'Saiba mais sobre a verificação Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Saiba mais sobre os sinais de autenticidade do Divine';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspecionar com a ferramenta ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Inspecionar detalhes da mídia';

  @override
  String get badgeExplanationProofmodeVerified =>
      'A autenticidade deste vídeo é verificada usando a tecnologia Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Este vídeo está hospedado no Divine e a detecção de IA indica que provavelmente foi feito por humano, mas não inclui dados criptográficos de verificação de câmera.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'A detecção de IA indica que este vídeo provavelmente foi feito por humano, embora não inclua dados criptográficos de verificação de câmera.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Este vídeo está hospedado no Divine, mas ainda não inclui dados criptográficos de verificação de câmera.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Este vídeo está hospedado fora do Divine e não inclui dados criptográficos de verificação de câmera.';

  @override
  String get badgeExplanationDeviceAttestation => 'Atestação do dispositivo';

  @override
  String get badgeExplanationPgpSignature => 'Assinatura PGP';

  @override
  String get badgeExplanationC2paCredentials => 'Credenciais de conteúdo C2PA';

  @override
  String get badgeExplanationProofManifest => 'Manifesto de prova';

  @override
  String get badgeExplanationAiDetection => 'Detecção de IA';

  @override
  String get badgeExplanationAiNotScanned => 'Scan de IA: ainda não escaneado';

  @override
  String get badgeExplanationNoScanResults =>
      'Nenhum resultado de scan disponível ainda.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Verificar se é gerado por IA';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% de probabilidade de ser gerado por IA';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Escaneado por: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verificado por moderador humano';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platina: atestação de hardware do dispositivo, assinaturas criptográficas, Content Credentials (C2PA) e scan de IA confirma origem humana.';

  @override
  String get badgeExplanationVerificationGold =>
      'Ouro: capturado em um dispositivo real com atestação de hardware, assinaturas criptográficas e Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Prata: assinaturas criptográficas provam que este vídeo não foi alterado desde a gravação.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze: assinaturas básicas de metadados presentes.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Prata: scan de IA confirma que este vídeo provavelmente foi criado por humano.';

  @override
  String get badgeExplanationNoVerification =>
      'Nenhum dado de verificação disponível para este vídeo.';

  @override
  String get shareMenuTitle => 'Compartilhar vídeo';

  @override
  String get shareMenuReportAiContent => 'Denunciar conteúdo de IA';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Denuncie rapidamente suspeita de conteúdo gerado por IA';

  @override
  String get shareMenuReportingAiContent => 'Denunciando conteúdo de IA...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Falha ao denunciar conteúdo: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Falha ao denunciar conteúdo de IA: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Status do vídeo';

  @override
  String get shareMenuViewAllLists => 'Ver todas as listas →';

  @override
  String get shareMenuShareWith => 'Compartilhar com';

  @override
  String get shareMenuShareViaOtherApps => 'Compartilhar via outros apps';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Compartilhar via outros apps ou copiar o link';

  @override
  String get shareMenuSaveToGallery => 'Salvar na galeria';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Salvar vídeo original no rolo da câmera';

  @override
  String get shareMenuSaveWithWatermark => 'Salvar com marca d\'água';

  @override
  String get shareMenuSaveVideo => 'Salvar vídeo';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Baixar com marca d\'água do Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Salvar vídeo no rolo da câmera';

  @override
  String get shareMenuLists => 'Listas';

  @override
  String get shareMenuAddToList => 'Adicionar à lista';

  @override
  String get shareMenuAddToListSubtitle => 'Adicionar às suas listas curadas';

  @override
  String get shareMenuCreateNewList => 'Criar nova lista';

  @override
  String get shareMenuCreateNewListSubtitle => 'Comece uma nova coleção curada';

  @override
  String get shareMenuRemovedFromList => 'Removido da lista';

  @override
  String get shareMenuFailedToRemoveFromList => 'Falha ao remover da lista';

  @override
  String get shareMenuBookmarks => 'Favoritos';

  @override
  String get shareMenuAddToBookmarks => 'Adicionar aos favoritos';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Salvar para ver depois';

  @override
  String get shareMenuAddToBookmarkSet => 'Adicionar a coleção de favoritos';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organize em coleções';

  @override
  String get shareMenuFollowSets => 'Coleções de seguidos';

  @override
  String get shareMenuCreateFollowSet => 'Criar coleção de seguidos';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Comece uma nova coleção com este criador';

  @override
  String get shareMenuAddToFollowSet => 'Adicionar à coleção de seguidos';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count coleções de seguidos disponíveis';
  }

  @override
  String get peopleListsAddToList => 'Adicionar à lista';

  @override
  String get peopleListsAddToListSubtitle =>
      'Coloca este criador numa das tuas listas';

  @override
  String get peopleListsSheetTitle => 'Adicionar à lista';

  @override
  String get peopleListsEmptyTitle => 'Ainda sem listas';

  @override
  String get peopleListsEmptySubtitle =>
      'Cria uma lista para começar a agrupar pessoas.';

  @override
  String get peopleListsCreateList => 'Criar lista';

  @override
  String get peopleListsNewListTitle => 'Nova lista';

  @override
  String get peopleListsRouteTitle => 'Lista de pessoas';

  @override
  String get peopleListsListNameLabel => 'Nome da lista';

  @override
  String get peopleListsListNameHint => 'Amigos próximos';

  @override
  String get peopleListsCreateButton => 'Criar';

  @override
  String get peopleListsAddPeopleTitle => 'Adicionar pessoas';

  @override
  String get peopleListsAddPeopleTooltip => 'Adicionar pessoas';

  @override
  String get peopleListsAddPeopleSemanticLabel => 'Adicionar pessoas à lista';

  @override
  String get peopleListsListNotFoundTitle => 'Lista não encontrada';

  @override
  String get peopleListsListNotFoundSubtitle =>
      'Lista não encontrada. Pode ter sido eliminada.';

  @override
  String get peopleListsListDeletedSubtitle =>
      'Esta lista pode ter sido eliminada.';

  @override
  String get peopleListsNoPeopleTitle => 'Nenhuma pessoa nesta lista';

  @override
  String get peopleListsNoPeopleSubtitle => 'Adiciona pessoas para começar';

  @override
  String get peopleListsNoVideosTitle => 'Ainda sem vídeos';

  @override
  String get peopleListsNoVideosSubtitle =>
      'Os vídeos dos membros da lista aparecerão aqui';

  @override
  String get peopleListsNoVideosAvailable => 'Nenhum vídeo disponível';

  @override
  String get peopleListsFailedToLoadVideos => 'Falha ao carregar vídeos';

  @override
  String get peopleListsVideoNotAvailable => 'Vídeo não disponível';

  @override
  String get peopleListsBackToGridTooltip => 'Voltar à grelha';

  @override
  String get peopleListsErrorLoadingVideos => 'Erro ao carregar vídeos';

  @override
  String get peopleListsNoPeopleToAdd =>
      'Nenhuma pessoa disponível para adicionar.';

  @override
  String peopleListsAddToListName(String name) {
    return 'Adicionar a $name';
  }

  @override
  String get peopleListsAddPeopleSearchHint => 'Pesquisar pessoas';

  @override
  String get peopleListsAddPeopleError =>
      'Não foi possível carregar as pessoas. Tente novamente.';

  @override
  String get peopleListsAddPeopleRetry => 'Tentar novamente';

  @override
  String get peopleListsAddButton => 'Adicionar';

  @override
  String peopleListsAddButtonWithCount(int count) {
    return 'Adicionar $count';
  }

  @override
  String peopleListsInNLists(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Em $count listas',
      one: 'Em 1 lista',
    );
    return '$_temp0';
  }

  @override
  String peopleListsRemoveConfirmTitle(String name) {
    return 'Remover $name?';
  }

  @override
  String get peopleListsRemoveConfirmBody => 'Será removido/a desta lista.';

  @override
  String get peopleListsRemove => 'Remover';

  @override
  String peopleListsRemovedFromList(String name) {
    return '$name removido/a da lista';
  }

  @override
  String get peopleListsUndo => 'Desfazer';

  @override
  String peopleListsProfileLongPressHint(String name) {
    return 'Perfil de $name. Pressão longa para remover.';
  }

  @override
  String peopleListsViewProfileHint(String name) {
    return 'Ver perfil de $name';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Adicionado aos favoritos!';

  @override
  String get shareMenuFailedToAddBookmark => 'Falha ao adicionar aos favoritos';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Lista \"$name\" criada e vídeo adicionado';
  }

  @override
  String get shareMenuManageContent => 'Gerenciar conteúdo';

  @override
  String get shareMenuEditVideo => 'Editar vídeo';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Atualize título, descrição e hashtags';

  @override
  String get shareMenuDeleteVideo => 'Excluir vídeo';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Remover este conteúdo permanentemente';

  @override
  String get shareMenuDeleteWarning =>
      'Isso vai enviar uma solicitação de exclusão (NIP-09) para todos os relays. Alguns relays podem manter o conteúdo mesmo assim.';

  @override
  String get shareMenuVideoInTheseLists => 'O vídeo está nestas listas:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count vídeos';
  }

  @override
  String get shareMenuClose => 'Fechar';

  @override
  String get shareMenuDeleteConfirmation =>
      'Tem certeza que quer excluir este vídeo?';

  @override
  String get shareMenuCancel => 'Cancelar';

  @override
  String get shareMenuDelete => 'Excluir';

  @override
  String get shareMenuDeletingContent => 'Excluindo conteúdo...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Falha ao excluir conteúdo: $error';
  }

  @override
  String get shareMenuDeleteRequestSent =>
      'Solicitação de exclusão enviada com sucesso';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'A exclusão ainda não está pronta. Tenta de novo daqui a pouco.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Só podes apagar os teus próprios vídeos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Inicia sessão outra vez e tenta apagar.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Não foi possível assinar o pedido de exclusão. Tenta de novo.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'The relay wouldn\'t accept this delete request. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedRelayNoResponse =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Não foi possível apagar este vídeo. Tenta de novo.';

  @override
  String get shareMenuFollowSetName => 'Nome da coleção de seguidos';

  @override
  String get shareMenuFollowSetNameHint =>
      'ex.: Criadores de conteúdo, Músicos, etc.';

  @override
  String get shareMenuDescriptionOptional => 'Descrição (opcional)';

  @override
  String get shareMenuCreate => 'Criar';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Coleção de seguidos \"$name\" criada e criador adicionado';
  }

  @override
  String get shareMenuDone => 'Concluído';

  @override
  String get shareMenuEditTitle => 'Título';

  @override
  String get shareMenuEditTitleHint => 'Digite o título do vídeo';

  @override
  String get shareMenuEditDescription => 'Descrição';

  @override
  String get shareMenuEditDescriptionHint => 'Digite a descrição do vídeo';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'hashtags, separadas, por, vírgula';

  @override
  String get shareMenuEditMetadataNote =>
      'Nota: apenas os metadados podem ser editados. O conteúdo do vídeo não pode ser alterado.';

  @override
  String get shareMenuDeleting => 'Excluindo...';

  @override
  String get shareMenuUpdate => 'Atualizar';

  @override
  String get shareMenuChangeCover => 'Alterar capa';

  @override
  String get shareMenuCoverUploadingBackground =>
      'A miniatura está sendo enviada em segundo plano';

  @override
  String get shareMenuVideoUpdated => 'Vídeo atualizado com sucesso';

  @override
  String shareMenuVideoUpdatedWithInviteFailures(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count convites de colaboradores não foram enviados.',
      one: '1 convite de colaborador não foi enviado.',
    );
    return 'Vídeo atualizado, mas $_temp0';
  }

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Falha ao atualizar vídeo: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Falha ao excluir vídeo: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Excluir vídeo?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Isso vai enviar uma solicitação de exclusão para os relays. Nota: alguns relays ainda podem ter cópias em cache.';

  @override
  String get shareMenuVideoDeletionRequested => 'Exclusão de vídeo solicitada';

  @override
  String get shareMenuContentLabels => 'Rótulos de conteúdo';

  @override
  String get shareMenuAddContentLabels => 'Adicionar rótulos de conteúdo';

  @override
  String get shareMenuClearAll => 'Limpar tudo';

  @override
  String get shareMenuCollaborators => 'Colaboradores';

  @override
  String get shareMenuAddCollaborator => 'Adicionar colaborador';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Você precisa seguir e ser seguido por $name para adicioná-lo como colaborador.';
  }

  @override
  String get shareMenuLoading => 'Carregando...';

  @override
  String get shareMenuInspiredBy => 'Inspirado em';

  @override
  String get shareMenuAddInspirationCredit => 'Adicionar crédito de inspiração';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'Este criador não pode ser referenciado.';

  @override
  String get shareMenuUnknown => 'Desconhecido';

  @override
  String get shareMenuCreateBookmarkSet => 'Criar coleção de favoritos';

  @override
  String get shareMenuSetName => 'Nome da coleção';

  @override
  String get shareMenuSetNameHint => 'ex.: Favoritos, Ver depois, etc.';

  @override
  String get shareMenuCreateNewSet => 'Criar nova coleção';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Comece uma nova coleção de favoritos';

  @override
  String get shareMenuNoBookmarkSets =>
      'Ainda sem coleções de favoritos. Crie a primeira!';

  @override
  String get shareMenuError => 'Erro';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Falha ao carregar coleções de favoritos';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return '\"$name\" criada e vídeo adicionado';
  }

  @override
  String get shareMenuUseThisSound => 'Usar este som';

  @override
  String get shareMenuOriginalSound => 'Som original';

  @override
  String get authSessionExpired => 'Sua sessão expirou. Entre novamente.';

  @override
  String get authSignInFailed => 'Falha ao entrar. Tente novamente.';

  @override
  String get localeAppLanguage => 'Idioma do app';

  @override
  String get localeDeviceDefault => 'Padrão do dispositivo';

  @override
  String get localeSelectLanguage => 'Selecionar idioma';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Autenticação web não suportada no modo seguro. Use o app para celular para gerenciamento seguro de chaves.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Falha na integração de autenticação: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Erro inesperado: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Digite uma URI bunker';

  @override
  String get webAuthConnectTitle => 'Conectar ao Divine';

  @override
  String get webAuthChooseMethod =>
      'Escolha seu método preferido de autenticação Nostr';

  @override
  String get webAuthBrowserExtension => 'Extensão do navegador';

  @override
  String get webAuthRecommended => 'RECOMENDADO';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Conectar a um signer remoto';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Colar da área de transferência';

  @override
  String get webAuthConnectToBunker => 'Conectar ao bunker';

  @override
  String get webAuthNewToNostr => 'Novo no Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Instale uma extensão de navegador como Alby ou nos2x para a experiência mais fácil, ou use nsec bunker para assinatura remota segura.';

  @override
  String get soundsTitle => 'Sons';

  @override
  String get soundsSearchHint => 'Buscar sons...';

  @override
  String get soundsPreviewUnavailable =>
      'Não é possível pré-visualizar o som - sem áudio disponível';

  @override
  String soundsPreviewFailed(String error) {
    return 'Falha ao reproduzir pré-visualização: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Sons em destaque';

  @override
  String get soundsTrendingSounds => 'Sons em alta';

  @override
  String get soundsAllSounds => 'Todos os sons';

  @override
  String get soundsSearchResults => 'Resultados da busca';

  @override
  String get soundsNoSoundsAvailable => 'Nenhum som disponível';

  @override
  String get soundsNoSoundsDescription =>
      'Os sons vão aparecer aqui quando os criadores compartilharem áudio';

  @override
  String get soundsNoSoundsFound => 'Nenhum som encontrado';

  @override
  String get soundsNoSoundsFoundDescription => 'Tente outro termo de busca';

  @override
  String get soundsSavedToLibrary => 'Salvo em Sons';

  @override
  String get soundsAlreadySavedToLibrary => 'Já está em Sons';

  @override
  String get soundsSavedLibraryTitle => 'Meus sons';

  @override
  String get soundsSavedEmptyTitle => 'Nenhum som salvo ainda';

  @override
  String get soundsSavedEmptyDescription =>
      'Toque em Usar som em um vídeo para salvá-lo aqui.';

  @override
  String get soundsAvailabilityPrivate => 'Privado';

  @override
  String get soundsAvailabilityCommunity => 'Comunidade';

  @override
  String get soundsRemoveSavedSound => 'Remover som';

  @override
  String get soundsRemovedFromLibrary => 'Removido de Sons';

  @override
  String get soundsFailedToLoad => 'Falha ao carregar sons';

  @override
  String get soundsRetry => 'Tentar novamente';

  @override
  String get soundsScreenLabel => 'Tela de sons';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileRefresh => 'Atualizar';

  @override
  String get profileRefreshLabel => 'Atualizar perfil';

  @override
  String get profileMoreOptions => 'Mais opções';

  @override
  String profileBlockedUser(String name) {
    return '$name bloqueado';
  }

  @override
  String profileUnblockedUser(String name) {
    return '$name desbloqueado';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Deixou de seguir $name';
  }

  @override
  String profileError(String error) {
    return 'Erro: $error';
  }

  @override
  String get profileFeedError => 'Couldn\'t load videos.';

  @override
  String get profileFeedLoadMoreError =>
      'Couldn\'t load more videos. Pull to refresh.';

  @override
  String get notificationsTabAll => 'Todas';

  @override
  String get notificationsTabLikes => 'Curtidas';

  @override
  String get notificationsTabComments => 'Comentários';

  @override
  String get notificationsTabFollows => 'Seguidores';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Falha ao carregar notificações';

  @override
  String get notificationsRetry => 'Tentar novamente';

  @override
  String get notificationsRefreshError =>
      'Falha ao atualizar — mostrando o disponível';

  @override
  String get notificationsCheckingNew => 'verificando novas notificações';

  @override
  String get notificationsNoneYet => 'Sem notificações ainda';

  @override
  String notificationsNoneForType(String type) {
    return 'Sem notificações de $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Quando as pessoas interagirem com seu conteúdo, você vai ver aqui';

  @override
  String get notificationsUnreadPrefix => 'Notificação não lida';

  @override
  String notificationsBadgeUnread(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread notifications',
      one: '1 unread notification',
    );
    return '$_temp0';
  }

  @override
  String notificationsViewProfileSemanticLabel(String displayName) {
    return 'Ver o perfil de $displayName';
  }

  @override
  String get notificationsViewProfilesSemanticLabel => 'Ver perfis';

  @override
  String notificationsVideoThumbnailFor(String title) {
    return 'Miniatura do vídeo $title';
  }

  @override
  String get notificationsVideoThumbnail => 'Miniatura do vídeo';

  @override
  String notificationsLoadingType(String type) {
    return 'Carregando notificações de $type...';
  }

  @override
  String get notificationsInviteSingular =>
      'Você tem 1 convite para compartilhar com um amigo!';

  @override
  String notificationsInvitePlural(int count) {
    return 'Você tem $count convites para compartilhar com amigos!';
  }

  @override
  String get notificationsVideoNotFound => 'Vídeo não encontrado';

  @override
  String get notificationsVideoUnavailable => 'Vídeo indisponível';

  @override
  String get notificationsFromNotification => 'Da notificação';

  @override
  String get feedFailedToLoadVideos => 'Falha ao carregar vídeos';

  @override
  String get feedRetry => 'Tentar novamente';

  @override
  String get feedNoFollowedUsers =>
      'Nenhum usuário seguido.\nSiga alguém para ver os vídeos dessa pessoa aqui.';

  @override
  String get feedModeForYou => 'Para você';

  @override
  String get feedModeNew => 'Novo';

  @override
  String get feedModeFollowing => 'Seguindo';

  @override
  String feedModeSemanticLabel(String label) {
    return 'Modo do feed: $label';
  }

  @override
  String videoAuthorSemanticLabel(String displayName) {
    return 'Autor do vídeo: $displayName';
  }

  @override
  String get videoAuthorAvatarSemanticLabel => 'Avatar do autor';

  @override
  String get feedForYouEmpty =>
      'Seu feed Para você está vazio.\nExplore vídeos e siga criadores para personalizá-lo.';

  @override
  String get feedFollowingEmpty =>
      'Ainda não há vídeos das pessoas que você segue.\nEncontre criadores de que goste e siga-os.';

  @override
  String get feedLatestEmpty => 'Ainda não há vídeos novos.\nVolte em breve.';

  @override
  String get feedExploreVideos => 'Explorar vídeos';

  @override
  String get feedExternalVideoSlow => 'Vídeo externo carregando devagar';

  @override
  String get feedSkip => 'Pular';

  @override
  String get feedLoadingMore => 'Loading more videos…';

  @override
  String get uploadWaitingToUpload => 'Aguardando envio';

  @override
  String get uploadUploadingVideo => 'Enviando vídeo';

  @override
  String get uploadProcessingVideo => 'Processando vídeo';

  @override
  String get uploadProcessingComplete => 'Processamento concluído';

  @override
  String get uploadPublishedSuccessfully => 'Publicado com sucesso';

  @override
  String get uploadFailed => 'Falha no envio';

  @override
  String get uploadRetrying => 'Tentando enviar novamente';

  @override
  String get uploadPaused => 'Envio pausado';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% concluído';
  }

  @override
  String get uploadQueuedMessage => 'Seu vídeo está na fila de envio';

  @override
  String get uploadUploadingMessage => 'Enviando para o servidor...';

  @override
  String get uploadProcessingMessage =>
      'Processando vídeo - isso pode levar alguns minutos';

  @override
  String get uploadReadyToPublishMessage =>
      'Vídeo processado com sucesso e pronto para publicar';

  @override
  String get uploadPublishedMessage => 'Vídeo publicado no seu perfil';

  @override
  String get uploadFailedMessage => 'Falha no envio - tente novamente';

  @override
  String get uploadRetryingMessage => 'Tentando enviar novamente...';

  @override
  String get uploadPausedMessage => 'Envio pausado pelo usuário';

  @override
  String get uploadRetryButton => 'TENTAR DE NOVO';

  @override
  String uploadRetryFailed(String error) {
    return 'Falha ao tentar o envio novamente: $error';
  }

  @override
  String get userSearchPrompt => 'Buscar usuários';

  @override
  String get userSearchNoResults => 'Nenhum usuário encontrado';

  @override
  String get userSearchFailed => 'A busca falhou';

  @override
  String get userPickerSearchByName => 'Pesquisar por nome';

  @override
  String get userPickerFilterByNameHint => 'Filtrar por nome...';

  @override
  String get userPickerSearchByNameHint => 'Pesquisar por nome...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name já adicionado';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Selecionar $name';
  }

  @override
  String userPickerRemoveSelectionSemantics(String name) {
    return 'Remover $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Sua turma está por aí';

  @override
  String get userPickerEmptyFollowListBody =>
      'Siga pessoas com quem você combina. Quando elas seguirem você de volta, vocês podem colaborar.';

  @override
  String get userPickerGoBack => 'Voltar';

  @override
  String get userPickerTypeNameToSearch => 'Digite um nome para pesquisar';

  @override
  String get userPickerUnavailable =>
      'A busca de usuários está indisponível. Tente novamente mais tarde.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'A busca falhou. Tente novamente.';

  @override
  String get forgotPasswordTitle => 'Redefinir senha';

  @override
  String get forgotPasswordDescription =>
      'Digite seu endereço de e-mail e enviaremos um link para redefinir sua senha.';

  @override
  String get forgotPasswordEmailLabel => 'Endereço de e-mail';

  @override
  String get forgotPasswordCancel => 'Cancelar';

  @override
  String get forgotPasswordSendLink => 'Enviar link por e-mail';

  @override
  String get ageVerificationContentWarning => 'Aviso de conteúdo';

  @override
  String get ageVerificationTitle => 'Verificação de idade';

  @override
  String get ageVerificationAdultDescription =>
      'Este conteúdo foi sinalizado como podendo conter material adulto. Você precisa ter 18 anos ou mais para vê-lo.';

  @override
  String get ageVerificationCreationDescription =>
      'Para usar a câmera e criar conteúdo, você precisa ter pelo menos 16 anos.';

  @override
  String get ageVerificationAdultQuestion => 'Você tem 18 anos ou mais?';

  @override
  String get ageVerificationCreationQuestion => 'Você tem 16 anos ou mais?';

  @override
  String get ageVerificationNo => 'Não';

  @override
  String get ageVerificationYes => 'Sim';

  @override
  String get shareLinkCopied => 'Link copiado para a área de transferência';

  @override
  String get shareFailedToCopy => 'Falha ao copiar o link';

  @override
  String get shareVideoSubject => 'Confira este vídeo no Divine';

  @override
  String get shareFailedToShare => 'Falha ao compartilhar';

  @override
  String get shareVideoTitle => 'Compartilhar vídeo';

  @override
  String get shareToApps => 'Compartilhar para apps';

  @override
  String get shareToAppsSubtitle => 'Compartilhe via mensagens, apps sociais';

  @override
  String get shareCopyWebLink => 'Copiar link da web';

  @override
  String get shareCopyWebLinkSubtitle => 'Copiar link compartilhável da web';

  @override
  String get shareCopyNostrLink => 'Copiar link Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Copiar link nevent para clientes Nostr';

  @override
  String get navHome => 'Início';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navInbox => 'Caixa de entrada';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navSearch => 'Pesquisar';

  @override
  String get navSearchTooltip => 'Pesquisar';

  @override
  String get navMyProfile => 'Meu perfil';

  @override
  String get navNotifications => 'Notificações';

  @override
  String get navOpenCamera => 'Abrir câmera';

  @override
  String get navUnknown => 'Desconhecido';

  @override
  String get navExploreClassics => 'Clássicos';

  @override
  String get navExploreNewVideos => 'Novos vídeos';

  @override
  String get navExploreTrending => 'Em alta';

  @override
  String get navExploreForYou => 'Para você';

  @override
  String get navExploreLists => 'Listas';

  @override
  String get routeErrorTitle => 'Erro';

  @override
  String get routeInvalidHashtag => 'Hashtag inválida';

  @override
  String get routeInvalidConversationId => 'ID de conversa inválido';

  @override
  String get routeInvalidRequestId => 'ID de solicitação inválido';

  @override
  String get routeInvalidListId => 'ID de lista inválido';

  @override
  String get routeInvalidUserId => 'ID de usuário inválido';

  @override
  String get routeInvalidVideoId => 'ID de vídeo inválido';

  @override
  String get routeInvalidSoundId => 'ID de som inválido';

  @override
  String get routeInvalidCategory => 'Categoria inválida';

  @override
  String get routeNoVideosToDisplay => 'Nenhum vídeo para exibir';

  @override
  String get routeInvalidProfileId => 'ID de perfil inválido';

  @override
  String get routeUnknownPath => 'Essa página não existe no app.';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Central de suporte';

  @override
  String get supportContactSupport => 'Contatar o suporte';

  @override
  String get supportContactSupportSubtitle =>
      'Inicie uma conversa ou veja mensagens anteriores';

  @override
  String get supportReportBug => 'Reportar um bug';

  @override
  String get supportReportBugSubtitle => 'Problemas técnicos com o app';

  @override
  String get supportRequestFeature => 'Pedir uma funcionalidade';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sugira uma melhoria ou nova funcionalidade';

  @override
  String get supportSaveLogs => 'Salvar logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportar logs para um arquivo para envio manual';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Perguntas e respostas comuns';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Saiba mais sobre verificação e autenticidade';

  @override
  String get supportLoginRequired => 'Entre para contatar o suporte';

  @override
  String get supportExportingLogs => 'Exportando logs...';

  @override
  String get supportExportLogsFailed => 'Falha ao exportar logs';

  @override
  String supportLogsSavedTo(String path) {
    return 'Logs salvos em $path';
  }

  @override
  String get supportRevealLogsAction => 'Mostrar na pasta';

  @override
  String get supportChatNotAvailable => 'Chat de suporte indisponível';

  @override
  String get supportCouldNotOpenMessages =>
      'Não foi possível abrir as mensagens de suporte';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Não foi possível abrir $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Erro ao abrir $pageName: $error';
  }

  @override
  String get reportTitle => 'Denunciar conteúdo';

  @override
  String get reportWhyReporting =>
      'Por que você está denunciando este conteúdo?';

  @override
  String get reportPolicyNotice =>
      'O Divine vai agir sobre denúncias de conteúdo em até 24 horas, removendo o conteúdo e expulsando o usuário que o publicou.';

  @override
  String get reportAdditionalDetails => 'Detalhes adicionais (opcional)';

  @override
  String get reportBlockUser => 'Bloquear este usuário';

  @override
  String get reportCancel => 'Cancelar';

  @override
  String get reportSubmit => 'Denunciar';

  @override
  String get reportSelectReason =>
      'Selecione um motivo para denunciar este conteúdo';

  @override
  String get reportOtherRequiresDetails =>
      'Please describe the issue when selecting Other';

  @override
  String get reportDetailsRequired => 'Please describe the issue';

  @override
  String get reportReasonSpam => 'Spam ou conteúdo indesejado';

  @override
  String get reportReasonSpamSubtitle => 'Conteúdo indesejado ou repetitivo';

  @override
  String get reportReasonHarassment => 'Assédio, bullying ou ameaças';

  @override
  String get reportReasonHarassmentSubtitle =>
      'Respostas ou menções prejudiciais e indesejadas';

  @override
  String get reportReasonViolence => 'Conteúdo violento ou extremista';

  @override
  String get reportReasonViolenceSubtitle =>
      'Conteúdo violento, extremista ou prejudicial';

  @override
  String get reportReasonSexualContent => 'Conteúdo sexual ou adulto';

  @override
  String get reportReasonSexualContentSubtitle =>
      'Nudez, pornografia ou conteúdo explícito';

  @override
  String get reportReasonCopyright => 'Violação de direitos autorais';

  @override
  String get reportReasonCopyrightSubtitle =>
      'Uso não autorizado de propriedade intelectual';

  @override
  String get reportReasonFalseInfo => 'Informações falsas';

  @override
  String get reportReasonFalseInfoSubtitle => 'Alegações enganosas ou falsas';

  @override
  String get reportReasonChildSafety => 'Child Safety Violation';

  @override
  String get reportReasonChildSafetySubtitle =>
      'General concerns about minors\' safety';

  @override
  String get reportReasonCsam => 'Violação de segurança infantil';

  @override
  String get reportReasonCsamSubtitle =>
      'Conteúdo que explora ou coloca menores em perigo';

  @override
  String get reportReasonUnderageUser => 'User Appears Under 16';

  @override
  String get reportReasonUnderageUserSubtitle =>
      'Account holder appears to be underage';

  @override
  String get reportReasonAiGenerated => 'Conteúdo gerado por IA';

  @override
  String get reportReasonAiGeneratedSubtitle =>
      'Conteúdo suspeito de ser gerado por IA';

  @override
  String get reportReasonOther => 'Outra violação de política';

  @override
  String get reportReasonOtherSubtitle => 'Violações não listadas acima';

  @override
  String reportFailed(Object error) {
    return 'Falha ao denunciar conteúdo: $error';
  }

  @override
  String get reportReceivedTitle => 'Denúncia recebida';

  @override
  String get reportReceivedThankYou =>
      'Obrigado por ajudar a manter o Divine seguro.';

  @override
  String get reportReceivedReviewNotice =>
      'Nossa equipe vai revisar sua denúncia e tomar as medidas adequadas. Você pode receber atualizações por mensagem direta.';

  @override
  String get reportModerationDmDelayed =>
      'We couldn\'t reach the moderation team directly just now, but your report was received and will be reviewed.';

  @override
  String get reportContactModeration => 'Message the moderation team';

  @override
  String get reportLearnMore => 'Saiba mais';

  @override
  String get reportLearnMoreAt => 'Saiba mais em';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Fechar';

  @override
  String get listAddToList => 'Adicionar à lista';

  @override
  String listVideoCount(int count) {
    return '$count vídeos';
  }

  @override
  String listPersonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pessoas',
      one: '1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String get listByAuthorPrefix => 'Por ';

  @override
  String get listNewList => 'Nova lista';

  @override
  String get listDone => 'Concluído';

  @override
  String get listErrorLoading => 'Erro ao carregar listas';

  @override
  String listRemovedFrom(String name) {
    return 'Removido de $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Adicionado a $name';
  }

  @override
  String get listCreateNewList => 'Criar nova lista';

  @override
  String get listNewPeopleList => 'Nova lista de pessoas';

  @override
  String get listCollaboratorsNone => 'Nenhum';

  @override
  String get listAddCollaboratorTitle => 'Adicionar colaborador';

  @override
  String get listCollaboratorSearchHint => 'Pesquisar no diVine...';

  @override
  String get listNameLabel => 'Nome da lista';

  @override
  String get listDescriptionLabel => 'Descrição (opcional)';

  @override
  String get listPublicList => 'Lista pública';

  @override
  String get listPublicListSubtitle =>
      'Outras pessoas podem seguir e ver esta lista';

  @override
  String get listCancel => 'Cancelar';

  @override
  String get listCreate => 'Criar';

  @override
  String get listCreateFailed => 'Falha ao criar a lista';

  @override
  String get keyManagementTitle => 'Chaves Nostr';

  @override
  String get keyManagementWhatAreKeys => 'O que são chaves Nostr?';

  @override
  String get keyManagementExplanation =>
      'Sua identidade Nostr é um par de chaves criptográficas:\n\n• Sua chave pública (npub) é como seu nome de usuário - compartilhe à vontade\n• Sua chave privada (nsec) é como sua senha - mantenha em segredo!\n\nSua nsec permite acessar sua conta em qualquer app Nostr.';

  @override
  String get keyManagementImportTitle => 'Importar chave existente';

  @override
  String get keyManagementImportSubtitle =>
      'Já tem uma conta Nostr? Cole sua chave privada (nsec) para acessá-la aqui.';

  @override
  String get keyManagementImportButton => 'Importar chave';

  @override
  String get keyManagementImportWarning =>
      'Isso vai substituir sua chave atual!';

  @override
  String get keyManagementBackupTitle => 'Faça backup da sua chave';

  @override
  String get keyManagementBackupSubtitle =>
      'Salve sua chave privada (nsec) para usar sua conta em outros apps Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copiar minha chave privada (nsec)';

  @override
  String get keyManagementNeverShare =>
      'Nunca compartilhe sua nsec com ninguém!';

  @override
  String get keyManagementKeycastRemoteSigning =>
      'Esta conta assina com o Keycast. Nenhuma chave privada está armazenada neste dispositivo, portanto não há nsec para copiar aqui.';

  @override
  String get keyManagementPasteKey => 'Por favor, cole sua chave privada';

  @override
  String get keyManagementInvalidFormat =>
      'Formato de chave inválido. Deve começar com \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Importar esta chave?';

  @override
  String get keyManagementConfirmImportBody =>
      'Isso vai substituir sua identidade atual pela importada.\n\nSua chave atual será perdida a menos que você tenha feito backup antes.';

  @override
  String get keyManagementImportConfirm => 'Importar';

  @override
  String get keyManagementImportSuccess => 'Chave importada com sucesso!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Falha ao importar chave: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Chave privada copiada para a área de transferência!\n\nGuarde em um lugar seguro.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Falha ao exportar chave: $error';
  }

  @override
  String get keyManagementYourPublicKeyLabel => 'Sua chave pública (npub)';

  @override
  String get keyManagementCopyPublicKeyTooltip => 'Copiar chave pública';

  @override
  String get keyManagementPublicKeyCopied => 'Chave pública copiada';

  @override
  String get profileEditPublicKeyLink => 'Ver sua chave pública';

  @override
  String get saveOriginalSavedToCameraRoll => 'Salvo no rolo da câmera';

  @override
  String get saveOriginalShare => 'Compartilhar';

  @override
  String get saveOriginalDone => 'Concluído';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Acesso a fotos necessário';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Para salvar vídeos, permita o acesso a Fotos nas Configurações.';

  @override
  String get saveOriginalOpenSettings => 'Abrir Configurações';

  @override
  String get saveOriginalNotNow => 'Agora não';

  @override
  String get cameraPermissionNotNow => 'Agora não';

  @override
  String get saveOriginalDownloadFailed => 'Download falhou';

  @override
  String get saveOriginalDismiss => 'Dispensar';

  @override
  String get saveOriginalDownloadingVideo => 'Baixando vídeo';

  @override
  String get saveOriginalSavingToCameraRoll => 'Salvando no rolo da câmera';

  @override
  String get saveOriginalFetchingVideo => 'Buscando o vídeo na rede...';

  @override
  String get saveOriginalSavingVideo =>
      'Salvando o vídeo original no seu rolo da câmera...';

  @override
  String get soundTitle => 'Som';

  @override
  String get soundOriginalSound => 'Som original';

  @override
  String get soundVideosUsingThisSound => 'Vídeos que usam este som';

  @override
  String get soundSourceVideo => 'Vídeo de origem';

  @override
  String get soundNoVideosYet => 'Sem vídeos ainda';

  @override
  String get soundBeFirstToUse => 'Seja o primeiro a usar este som!';

  @override
  String get soundFailedToLoadVideos => 'Falha ao carregar vídeos';

  @override
  String get soundRetry => 'Tentar novamente';

  @override
  String get soundVideosUnavailable => 'Vídeos indisponíveis';

  @override
  String get soundCouldNotLoadDetails =>
      'Não foi possível carregar os detalhes do vídeo';

  @override
  String get soundPreview => 'Pré-visualizar';

  @override
  String get soundStop => 'Parar';

  @override
  String get soundUseSound => 'Usar som';

  @override
  String get soundUntitled => 'Som sem título';

  @override
  String get soundStopPreview => 'Parar pré-visualização';

  @override
  String soundPreviewSemanticLabel(String title) {
    return 'Pré-visualizar $title';
  }

  @override
  String soundViewDetailsSemanticLabel(String title) {
    return 'Ver detalhes de $title';
  }

  @override
  String get soundNoVideoCount => 'Sem vídeos ainda';

  @override
  String get soundOneVideo => '1 vídeo';

  @override
  String soundVideoCount(int count) {
    return '$count vídeos';
  }

  @override
  String get soundUnableToPreview =>
      'Não é possível pré-visualizar o som - sem áudio disponível';

  @override
  String soundPreviewFailed(Object error) {
    return 'Falha ao reproduzir pré-visualização: $error';
  }

  @override
  String get soundViewSource => 'Ver origem';

  @override
  String get soundCloseTooltip => 'Fechar';

  @override
  String get exploreNotExploreRoute => 'Não é uma rota de explorar';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Termos de Serviço';

  @override
  String get legalTermsOfServiceSubtitle => 'Termos e condições de uso';

  @override
  String get legalPrivacyPolicy => 'Política de Privacidade';

  @override
  String get legalPrivacyPolicySubtitle => 'Como lidamos com seus dados';

  @override
  String get legalSafetyStandards => 'Padrões de Segurança';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Diretrizes da comunidade e segurança';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Política de direitos autorais e remoção';

  @override
  String get legalOpenSourceLicenses => 'Licenças de código aberto';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atribuições de pacotes de terceiros';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Não foi possível abrir $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Erro ao abrir $pageName: $error';
  }

  @override
  String get categoryAction => 'Ação';

  @override
  String get categoryAdventure => 'Aventura';

  @override
  String get categoryAnimals => 'Animais';

  @override
  String get categoryAnimation => 'Animação';

  @override
  String get categoryArchitecture => 'Arquitetura';

  @override
  String get categoryArt => 'Arte';

  @override
  String get categoryAutomotive => 'Carros';

  @override
  String get categoryAwardShow => 'Premiação';

  @override
  String get categoryAwards => 'Prêmios';

  @override
  String get categoryBaseball => 'Beisebol';

  @override
  String get categoryBasketball => 'Basquete';

  @override
  String get categoryBeauty => 'Beleza';

  @override
  String get categoryBeverage => 'Bebidas';

  @override
  String get categoryCars => 'Carros';

  @override
  String get categoryCelebration => 'Comemoração';

  @override
  String get categoryCelebrities => 'Celebridades';

  @override
  String get categoryCelebrity => 'Celebridade';

  @override
  String get categoryCityscape => 'Paisagem urbana';

  @override
  String get categoryComedy => 'Comédia';

  @override
  String get categoryConcert => 'Show';

  @override
  String get categoryCooking => 'Culinária';

  @override
  String get categoryCostume => 'Fantasia';

  @override
  String get categoryCrafts => 'Artesanato';

  @override
  String get categoryCrime => 'Crime';

  @override
  String get categoryCulture => 'Cultura';

  @override
  String get categoryDance => 'Dança';

  @override
  String get categoryDiy => 'Faça você mesmo';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Educação';

  @override
  String get categoryEmotional => 'Emocionante';

  @override
  String get categoryEmotions => 'Emoções';

  @override
  String get categoryEntertainment => 'Entretenimento';

  @override
  String get categoryEvent => 'Evento';

  @override
  String get categoryFamily => 'Família';

  @override
  String get categoryFans => 'Fãs';

  @override
  String get categoryFantasy => 'Fantasia';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Cinema';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryFootball => 'Futebol americano';

  @override
  String get categoryFurniture => 'Móveis';

  @override
  String get categoryGaming => 'Games';

  @override
  String get categoryGolf => 'Golfe';

  @override
  String get categoryGrooming => 'Cuidados pessoais';

  @override
  String get categoryGuitar => 'Guitarra';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Saúde';

  @override
  String get categoryHockey => 'Hóquei';

  @override
  String get categoryHoliday => 'Feriado';

  @override
  String get categoryHome => 'Casa';

  @override
  String get categoryHomeImprovement => 'Reforma';

  @override
  String get categoryHorror => 'Terror';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Design de interiores';

  @override
  String get categoryInterview => 'Entrevista';

  @override
  String get categoryKids => 'Crianças';

  @override
  String get categoryLifestyle => 'Estilo de vida';

  @override
  String get categoryMagic => 'Mágica';

  @override
  String get categoryMakeup => 'Maquiagem';

  @override
  String get categoryMedical => 'Medicina';

  @override
  String get categoryMusic => 'Música';

  @override
  String get categoryMystery => 'Mistério';

  @override
  String get categoryNature => 'Natureza';

  @override
  String get categoryNews => 'Notícias';

  @override
  String get categoryOutdoor => 'Ar livre';

  @override
  String get categoryParty => 'Festa';

  @override
  String get categoryPeople => 'Pessoas';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Pets';

  @override
  String get categoryPolitics => 'Política';

  @override
  String get categoryPrank => 'Pegadinha';

  @override
  String get categoryPranks => 'Pegadinhas';

  @override
  String get categoryRealityShow => 'Reality show';

  @override
  String get categoryRelationship => 'Relacionamento';

  @override
  String get categoryRelationships => 'Relacionamentos';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'Escola';

  @override
  String get categoryScienceFiction => 'Ficção científica';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Compras';

  @override
  String get categorySkateboarding => 'Skate';

  @override
  String get categorySkincare => 'Cuidados com a pele';

  @override
  String get categorySoccer => 'Futebol';

  @override
  String get categorySocialGathering => 'Encontro';

  @override
  String get categorySocialMedia => 'Redes sociais';

  @override
  String get categorySports => 'Esportes';

  @override
  String get categoryTalkShow => 'Talk show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Tecnologia';

  @override
  String get categoryTelevision => 'Televisão';

  @override
  String get categoryToys => 'Brinquedos';

  @override
  String get categoryTransportation => 'Transporte';

  @override
  String get categoryTravel => 'Viagem';

  @override
  String get categoryUrban => 'Urbano';

  @override
  String get categoryViolence => 'Violência';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Luta livre';

  @override
  String get profileSetupUploadStaged =>
      'Enviada — toque em Salvar para aplicar';

  @override
  String inboxReportedUser(String displayName) {
    return '$displayName denunciado(a)';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return '$displayName bloqueado(a)';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return '$displayName desbloqueado(a)';
  }

  @override
  String get inboxRemovedConversation => 'Conversa removida';

  @override
  String get inboxRestoringMessages => 'Restaurando suas mensagens…';

  @override
  String get inboxEmptyTitle => 'Ainda sem mensagens';

  @override
  String get inboxEmptySubtitle => 'O botão + não morde.';

  @override
  String get inboxActionMute => 'Silenciar conversa';

  @override
  String inboxActionReport(String displayName) {
    return 'Denunciar $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Bloquear $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Desbloquear $displayName';
  }

  @override
  String get inboxActionRemove => 'Remover conversa';

  @override
  String get inboxRemoveConfirmTitle => 'Remover conversa?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Isso apagará sua conversa com $displayName. Esta ação não pode ser desfeita.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Remover';

  @override
  String get inboxConversationMuted => 'Conversa silenciada';

  @override
  String get inboxConversationUnmuted => 'Conversa com som ativado';

  @override
  String get inboxCollabInviteCardTitle => 'Convite para colaborar';

  @override
  String get inboxCollabInviteCardUntitledVideo => 'Vídeo sem título';

  @override
  String get clickableTextViewVideoLink => 'Ver vídeo';

  @override
  String get messageExternalLinkDialogTitle => 'Abrir link externo?';

  @override
  String messageExternalLinkDialogBody(String url) {
    return 'Este link leva a um site externo e pode não ser seguro:\n\n$url';
  }

  @override
  String get messageExternalLinkDialogOpen => 'Abrir';

  @override
  String get inboxCollabInviteCoPostButton => 'Co-publicar';

  @override
  String get inboxCollabInviteNotMineButton => 'Não é meu';

  @override
  String get inboxCollabInvitePreviewTitle => 'Convite para co-publicar';

  @override
  String inboxCollabInvitePreviewTitleFrom(String displayName) {
    return 'Convite para co-publicar de $displayName';
  }

  @override
  String get inboxCollabInviteTimelineConsequence =>
      'Co-publicar adiciona este vídeo à sua linha do tempo como uma colaboração.';

  @override
  String get inboxCollabInviteAcceptedStatus => 'Aceito';

  @override
  String get inboxCollabInviteIgnoredStatus => 'Ignorado';

  @override
  String get inboxCollabInviteAcceptError =>
      'Não foi possível aceitar. Tente novamente.';

  @override
  String get inboxCollabInviteSentStatus => 'Convite enviado';

  @override
  String get inboxConversationCollabInvitePreview => 'Convite para colaborar';

  @override
  String collaboratorInviteDmBody(String title, String url) {
    return 'Você foi convidado(a) para colaborar em $title: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String collaboratorInviteDmBodyUntitled(String url) {
    return 'Você foi convidado(a) para colaborar em um vídeo: $url\n\nOpen diVine to review and accept.';
  }

  @override
  String videoPublishCollaboratorInviteWarning(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborator invites did not send.',
      one: '1 collaborator invite did not send.',
    );
    return 'Video posted, but $_temp0';
  }

  @override
  String get dmSendFailedMessage => 'Falha ao enviar a mensagem';

  @override
  String get dmSendFailedRetry => 'Tentar novamente';

  @override
  String get dmSendPartialMessage =>
      'Enviado, mas não sincronizou com seus outros dispositivos';

  @override
  String get dmConversationLoadError =>
      'Não foi possível carregar as mensagens';

  @override
  String get dmMessageInputHint => 'Say something…';

  @override
  String get dmMessageBubbleSentHint => 'Sent message';

  @override
  String get dmMessageBubbleReceivedHint => 'Received message';

  @override
  String get dmMessageBubbleLongPressHint => 'Message actions';

  @override
  String get dmMessageActionCopyText => 'Copy text';

  @override
  String get dmMessageActionCopyVideoUrl => 'Copy video URL';

  @override
  String get dmMessageActionDeleteForEveryone => 'Delete for everyone';

  @override
  String get dmMessageActionReport => 'Report';

  @override
  String get dmReactionAddCustomA11yLabel => 'Add custom emoji reaction';

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
  String get dmFormatBold => 'Negrito';

  @override
  String get dmFormatItalic => 'Itálico';

  @override
  String get dmFormatStrikethrough => 'Tachado';

  @override
  String get dmFormatCode => 'Código';

  @override
  String get dmStatusPending => 'Enviando';

  @override
  String get dmStatusFailed => 'Falha ao enviar';

  @override
  String get dmStatusDeliveredSelfFailed =>
      'Entregue. Não será sincronizado com seus outros dispositivos.';

  @override
  String get inboxConversationActionsSheetLabel => 'Conversation actions';

  @override
  String inboxConversationTileLabel(String displayName) {
    return '$displayName conversation';
  }

  @override
  String get inboxConversationTileLongPressHint => 'Show conversation actions';

  @override
  String get reportDialogCancel => 'Cancelar';

  @override
  String get reportDialogReport => 'Denunciar';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Título: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Vídeo $current/$total';
  }

  @override
  String get exploreSearchHint => 'Buscar...';

  @override
  String categoryVideoCount(String count) {
    return '$count vídeos';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Falha ao atualizar assinatura: $error';
  }

  @override
  String get discoverListsTitle => 'Descobrir listas';

  @override
  String get discoverListsFailedToLoad => 'Falha ao carregar listas';

  @override
  String discoverListsFailedToLoadWithError(String error) {
    return 'Falha ao carregar listas: $error';
  }

  @override
  String get discoverListsLoading => 'Descobrindo listas públicas...';

  @override
  String get discoverListsEmptyTitle => 'Nenhuma lista pública encontrada';

  @override
  String get discoverListsEmptySubtitle =>
      'Volte mais tarde para ver novas listas';

  @override
  String get discoverListsByAuthorPrefix => 'por';

  @override
  String get curatedListEmptyTitle => 'Sem vídeos nesta lista';

  @override
  String get curatedListEmptySubtitle => 'Adicione alguns vídeos pra começar';

  @override
  String get curatedListLoadingVideos => 'Carregando vídeos...';

  @override
  String get curatedListFailedToLoad => 'Falha ao carregar lista';

  @override
  String get curatedListNoVideosAvailable => 'Nenhum vídeo disponível';

  @override
  String get curatedListVideoNotAvailable => 'Vídeo indisponível';

  @override
  String get curatedListActionsTooltip => 'List actions';

  @override
  String get curatedListUnfollowAction => 'Unfollow list';

  @override
  String get curatedListUnfollowedSnack => 'Unfollowed list';

  @override
  String get curatedListUnfollowFailed => 'Couldn\'t unfollow list';

  @override
  String get curatedListDeleteConfirmTitle => 'Delete list?';

  @override
  String get curatedListDeleteConfirmBody =>
      'This removes the list from relays. Videos in the list will not be deleted.';

  @override
  String get curatedListDeletedSnack => 'Deleted list';

  @override
  String get curatedListDeleteFailed => 'Couldn\'t delete list';

  @override
  String get peopleListsActionsTooltip => 'List actions';

  @override
  String get listDeleteAction => 'Delete list';

  @override
  String get peopleListsDeleteConfirmTitle => 'Delete list?';

  @override
  String get peopleListsDeleteConfirmBody =>
      'This removes the list for everyone. The people in it will not be unfollowed.';

  @override
  String get peopleListsDeleteFailed => 'Couldn\'t delete list';

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonNext => 'Próximo';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get commonBack => 'Voltar';

  @override
  String get commonClose => 'Fechar';

  @override
  String get videoMetadataEditCoverFailedSnackbar =>
      'Não foi possível atualizar a capa. Tente novamente.';

  @override
  String get videoMetadataEditCoverSuccessAnnouncement => 'Capa atualizada';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Validade';

  @override
  String get videoMetadataExpirationNotExpire => 'Não expira';

  @override
  String get videoMetadataExpirationOneDay => '1 dia';

  @override
  String get videoMetadataExpirationOneWeek => '1 semana';

  @override
  String get videoMetadataExpirationOneMonth => '1 mês';

  @override
  String get videoMetadataExpirationOneYear => '1 ano';

  @override
  String get videoMetadataExpirationOneDecade => '1 década';

  @override
  String get videoMetadataContentWarnings => 'Avisos de conteúdo';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Em alta';

  @override
  String get proofmodeCheckAiGenerated => 'Verificar se gerado por IA';

  @override
  String get libraryDeleteConfirm => 'Excluir';

  @override
  String get libraryWebUnavailableHeadline => 'A biblioteca fica no app móvel';

  @override
  String get libraryWebUnavailableDescription =>
      'Rascunhos e clipes ficam no seu dispositivo — abra o Divine no celular para gerenciá-los.';

  @override
  String get libraryTabDrafts => 'Rascunhos';

  @override
  String get libraryTabClips => 'Clipes';

  @override
  String get librarySaveToCameraRollTooltip => 'Salvar na galeria';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Excluir clipes selecionados';

  @override
  String get librarySelect => 'Selecionar';

  @override
  String get librarySortNewestCreation => 'Criação mais recente';

  @override
  String get librarySortOldestCreation => 'Criação mais antiga';

  @override
  String get librarySortLongestClip => 'Clipe mais longo';

  @override
  String get librarySortShortestClip => 'Clipe mais curto';

  @override
  String get librarySortSquareFirst => 'Quadrados primeiro';

  @override
  String get librarySortVerticalFirst => 'Verticais primeiro';

  @override
  String get libraryDeleteClipsTitle => 'Excluir clipes';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# clipes selecionados',
      one: '# clipe selecionado',
    );
    return 'Excluir $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'Não dá para desfazer. Os arquivos de vídeo serão removidos permanentemente do dispositivo.';

  @override
  String get libraryPreparingVideo => 'Preparando vídeo...';

  @override
  String get libraryCreateVideo => 'Criar vídeo';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes',
      one: '1 clipe',
    );
    return '$_temp0 salvos em $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount salvos, $failureCount falharam';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permissão negada para $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes excluídos',
      one: '1 clipe excluído',
    );
    return '$_temp0';
  }

  @override
  String get libraryClipsDeletedUndoLabel => 'Desfazer';

  @override
  String libraryTrashAutoDeletes(int daysLeft) {
    String _temp0 = intl.Intl.pluralLogic(
      daysLeft,
      locale: localeName,
      other: 'Será excluído automaticamente em $daysLeft dias',
      one: 'Será excluído automaticamente amanhã',
      zero: 'Será excluído automaticamente hoje',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'Não foi possível carregar os rascunhos';

  @override
  String get libraryCouldNotLoadClips => 'Não foi possível carregar os clipes';

  @override
  String get libraryOpenErrorDescription =>
      'Algo deu errado ao abrir a biblioteca. Tente de novo.';

  @override
  String get libraryNoDraftsYetTitle => 'Ainda não há rascunhos';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Vídeos salvos como rascunho aparecerão aqui';

  @override
  String get libraryNoClipsYetTitle => 'Ainda não há clipes';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Seus clipes gravados aparecerão aqui';

  @override
  String get libraryDraftDeletedSnackbar => 'Rascunho excluído';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Falha ao excluir rascunho';

  @override
  String get libraryDraftActionPost => 'Publicar';

  @override
  String get libraryDraftActionEdit => 'Editar';

  @override
  String get libraryDraftActionDelete => 'Excluir rascunho';

  @override
  String get libraryDeleteDraftTitle => 'Excluir rascunho';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Excluir \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Excluir clipe';

  @override
  String get libraryDeleteClipMessage => 'Excluir este clipe?';

  @override
  String get libraryClipSelectionTitle => 'Clipes';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Faltam ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Adicionar';

  @override
  String get libraryRecordVideo => 'Gravar um vídeo';

  @override
  String videoClipSemanticLabel(String duration) {
    return 'Clipe de vídeo, $duration segundos';
  }

  @override
  String get videoClipSemanticValueSelected => 'Selecionado';

  @override
  String get videoClipSemanticValueNotSelected => 'Não selecionado';

  @override
  String get videoClipSemanticHintDisabled => 'Desabilitado';

  @override
  String get videoClipSemanticHintSelect =>
      'Toque para selecionar, pressione por mais tempo para visualizar';

  @override
  String get videoClipSemanticHintDeselect =>
      'Toque para desmarcar, pressione por mais tempo para visualizar';

  @override
  String get routerInvalidCreator => 'Criador inválido';

  @override
  String get routerInvalidHashtagRoute => 'Rota de hashtag inválida';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Não foi possível carregar os vídeos';

  @override
  String get categoryGalleryNoVideosInCategory => 'Sem vídeos nesta categoria';

  @override
  String get categoryGallerySortOptionsLabel =>
      'Opções de ordenação da categoria';

  @override
  String get categoryGallerySortHot => 'Em alta';

  @override
  String get categoryGallerySortNew => 'Novos';

  @override
  String get categoryGallerySortClassic => 'Clássicos';

  @override
  String get categoryGallerySortForYou => 'Pra você';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Não foi possível carregar as categorias';

  @override
  String get categoriesNoCategoriesAvailable => 'Nenhuma categoria disponível';

  @override
  String get notificationsEmptyTitle => 'Sem atividade ainda';

  @override
  String get notificationsEmptySubtitle =>
      'Quando alguém interagir com seu conteúdo, você vê aqui';

  @override
  String get appsPermissionsTitle => 'Permissões de integração';

  @override
  String get appsPermissionsRevoke => 'Revogar';

  @override
  String get appsPermissionsEmptyTitle =>
      'Nenhuma permissão de integração salva';

  @override
  String get appsPermissionsEmptySubtitle =>
      'Integrações aprovadas aparecem aqui depois que você lembra uma aprovação de acesso.';

  @override
  String nostrAppPermissionTitle(String appName) {
    return '$appName quer sua aprovação';
  }

  @override
  String get nostrAppPermissionDescription =>
      'Este app está pedindo acesso pelo sandbox aprovado do Divine.';

  @override
  String get nostrAppPermissionOrigin => 'Origem';

  @override
  String get nostrAppPermissionMethod => 'Método';

  @override
  String get nostrAppPermissionCapability => 'Capacidade';

  @override
  String get nostrAppPermissionEventKind => 'Tipo de evento';

  @override
  String get nostrAppPermissionAllow => 'Permitir';

  @override
  String get appsDetailDefaultTitle => 'Integrated App';

  @override
  String get appsDetailNotFoundTitle => 'Integration not found';

  @override
  String get appsDetailNotFoundSubtitle =>
      'This approved integration is no longer available in Divine.';

  @override
  String get appsDetailHowItWorksTitle => 'How it works';

  @override
  String get appsDetailHowItWorksBody =>
      'This is an approved third-party app that runs inside Divine. Divine only grants reviewed capabilities for this integration, and blocks navigation outside its approved origins.';

  @override
  String get appsDetailAboutTitle => 'About';

  @override
  String get appsDetailPrimaryOriginTitle => 'Primary origin';

  @override
  String get appsDetailApprovedOriginsTitle => 'Approved origins';

  @override
  String get appsDetailCapabilitiesTitle => 'Available capabilities';

  @override
  String get appsDetailAskBeforeTitle => 'Ask before';

  @override
  String get appsDetailOpenButton => 'Open Integration';

  @override
  String get appsDetailNoneDeclared => 'None declared yet';

  @override
  String get appsDirectoryTitle => 'Integrated Apps';

  @override
  String get appsDirectoryIntroTitle => 'Approved third-party apps';

  @override
  String get appsDirectoryIntroBody =>
      'Approved third-party apps that run inside Divine';

  @override
  String get appsDirectoryErrorTitle => 'Could not load integrated apps';

  @override
  String get appsDirectoryErrorSubtitle =>
      'Pull to try the approved integrations again.';

  @override
  String get appsDirectoryEmptyTitle => 'No approved integrations yet';

  @override
  String get appsDirectoryEmptySubtitle =>
      'Approved third-party apps will appear here as Divine adds them.';

  @override
  String get appsDirectoryRefresh => 'Refresh';

  @override
  String get appsDirectoryUnsupportedTitle =>
      'Integrated Apps run in Divine mobile';

  @override
  String get appsDirectoryUnsupportedSubtitle =>
      'Approved integrations are only available on mobile for now.';

  @override
  String get appsSandboxUnavailableTitle => 'Integration unavailable';

  @override
  String get appsSandboxUnavailableBody =>
      'Open approved integrations from the Integrated Apps tab so Divine can apply the right access policy.';

  @override
  String get appsSandboxLoadingTitle => 'Loading integration';

  @override
  String get appsSandboxLoadingSubtitle =>
      'Checking the approved integration before launch.';

  @override
  String get appsSandboxBlockedTitle => 'Blocked for safety';

  @override
  String appsSandboxBlockedSubtitle(String uri) {
    return 'This integration tried to leave its approved origin.\n\n$uri';
  }

  @override
  String get shareCopiedPostLink => 'Link to post copied to clipboard';

  @override
  String get shareCopiedEventJson => 'Nostr event JSON copied to clipboard';

  @override
  String get shareCopiedEventId => 'Nostr event ID copied to clipboard';

  @override
  String get authHeroTaglineAuthentic => 'Authentic moments.';

  @override
  String get authHeroTaglineHuman => 'Human creativity.';

  @override
  String get keyImportFailedToImport =>
      'Failed to import key or connect bunker';

  @override
  String get keyImportInvalidBunkerUrl => 'Invalid bunker URL';

  @override
  String get keyImportInvalidFormat =>
      'Invalid format. Use nsec..., hex, ncryptsec1..., or bunker://...';

  @override
  String get keyImportInvalidNsecFormat =>
      'Invalid nsec format. Should be 63 characters';

  @override
  String get keyImportKeyFieldLabel => 'Private key or bunker URL';

  @override
  String get keyImportKeyRequired =>
      'Please enter your private key or bunker URL';

  @override
  String get keyImportPasswordRequired =>
      'Please enter the password for this encrypted key';

  @override
  String get keyImportSecurityWarningBody =>
      'Never share your private key with anyone. This key gives full access to your Nostr identity.';

  @override
  String get keyImportSecurityWarningTitle => 'Keep your private key secure!';

  @override
  String get keyImportSubtitle =>
      'Import your existing Nostr identity using your private key or a bunker URL.';

  @override
  String get keyImportTitle => 'Import your\nNostr identity';

  @override
  String get commentAuthorYouIndicator => 'You';

  @override
  String get commentOptionsDeleteSemanticLabel => 'Delete comment';

  @override
  String get commentOptionsEditSemanticLabel => 'Edit comment';

  @override
  String get commentOptionsFlagContentLabel => 'Flag Content';

  @override
  String get commentOptionsFlagContentSemanticLabel => 'Flag this content';

  @override
  String get commentOptionsFlagReasonPrompt =>
      'Select a reason for flagging this comment';

  @override
  String get commentOptionsFlagSubmit => 'Submit';

  @override
  String get commentOptionsTitle => 'Options';

  @override
  String get commentsEmptyClassicVineMessage =>
      'We\'re still working on importing old comments from the archive. They\'re not ready yet.';

  @override
  String get commentsEmptyClassicVineTitle => 'Classic Vine';

  @override
  String get commentsInputEditingLabel => 'Editing';

  @override
  String get commentsInputSemanticHint => 'Add a comment';

  @override
  String get commentsInputSemanticHintEdit => 'Edit comment';

  @override
  String get commentsInputSemanticHintReply => 'Add a reply';

  @override
  String get commentsInputSemanticLabel => 'Comment input';

  @override
  String get commentsInputSemanticLabelEdit => 'Edit input';

  @override
  String get commentsInputSemanticLabelReply => 'Reply input';

  @override
  String classicVinersViewProfileSemanticLabel(String displayName) {
    return 'View profile for $displayName';
  }

  @override
  String get classicsEmptyDescription => 'The Classics archive is being loaded';

  @override
  String get classicsEmptyTitle => 'No Classics Found';

  @override
  String get classicsErrorTitle => 'Failed to load Classics';

  @override
  String get classicsUnavailableDescription =>
      'Classics are only available when connected to Funnelcake relays.';

  @override
  String get classicsUnavailableSettingsHint =>
      'Switch to a Funnelcake-enabled relay in Settings to access the Classics archive.';

  @override
  String get classicsUnavailableTitle => 'Classics Unavailable';

  @override
  String get hashtagFeedEmptySubtitle =>
      'Be the first to post a video with this hashtag!';

  @override
  String hashtagFeedEmptyTitle(String hashtag) {
    return 'No videos found for #$hashtag';
  }

  @override
  String get hashtagFeedLoadingSubtitle => 'This may take a few moments';

  @override
  String hashtagFeedLoadingTitle(String hashtag) {
    return 'Loading videos about #$hashtag...';
  }

  @override
  String get hashtagInputHint => 'Add hashtags... #vine #nostr';

  @override
  String get newVideosTabEmptySubtitle => 'Check back later for new content';

  @override
  String get newVideosTabEmptyTitle => 'No videos in New Videos';

  @override
  String get popularVideosContextTitle => 'Popular Videos';

  @override
  String get popularVideosEmptySubtitle => 'Check back later for new content';

  @override
  String get popularVideosEmptyTitle => 'No videos in Popular Videos';

  @override
  String get popularVideosErrorTitle => 'Failed to load trending videos';

  @override
  String get popularVideosFeedSourceLabel => 'Popular feed source';

  @override
  String get trendingHashtagsLoading => 'Loading hashtags...';

  @override
  String trendingHashtagsViewVideosTagged(String hashtag) {
    return 'View videos tagged $hashtag';
  }

  @override
  String videoGridAuthorSemanticLabel(String name) {
    return 'Video author: $name';
  }

  @override
  String videoGridDescriptionSemanticLabel(String description) {
    return 'Video description: $description';
  }

  @override
  String get forYouAlgorithmChoiceBody =>
      'Divine\'s vision is to give you true algorithmic choice. Instead of being locked into a single black-box algorithm, you\'ll be able to choose from multiple recommendation approaches:';

  @override
  String get forYouAlgorithmChoiceChronological =>
      'Chronological timeline from creators you follow';

  @override
  String get forYouAlgorithmChoiceClosing =>
      'This puts you in control of your attention rather than leaving it up to the platform. You should know how your feed is curated and have the power to change it whenever you want.';

  @override
  String get forYouAlgorithmChoiceCustomFeeds =>
      'Community-created custom feeds for topics like music, comedy, or art';

  @override
  String get forYouAlgorithmChoicePersonalizedFeed =>
      'Personalized \"For You\" feed';

  @override
  String get forYouAlgorithmChoiceTitle => 'Your Algorithm, Your Choice';

  @override
  String get forYouAlgorithmChoiceTrending => 'Trending and popular content';

  @override
  String get forYouAlgorithmCommentsDescription =>
      'Strong signal — you were engaged enough to respond';

  @override
  String get forYouAlgorithmHowItWorksBody =>
      'Divine pays attention to how you interact with content to understand what you enjoy. Every time you watch a video, give it a reaction, leave a comment, or repost it, the system takes note.';

  @override
  String get forYouAlgorithmHowItWorksTitle => 'How It Works';

  @override
  String get forYouAlgorithmInteractionsIntro =>
      'Different actions signal different levels of interest:';

  @override
  String get forYouAlgorithmNewToDivineBody1 =>
      'If you haven\'t built up a viewing history yet, we show a mix of what\'s currently popular and trending alongside recent uploads. This gives you a great starting point to explore.';

  @override
  String get forYouAlgorithmNewToDivineBody2 =>
      'As you watch, like, and engage with content, recommendations gradually become more personalized. Over time, your For You feed surfaces videos from creators you might never have discovered on your own.';

  @override
  String get forYouAlgorithmNewToDivineTitle => 'New to Divine?';

  @override
  String get forYouAlgorithmOpenSourceBody =>
      'We\'re building an open system where developers can implement their own algorithms, and you can choose which ones to use — or opt out entirely.';

  @override
  String get forYouAlgorithmOpenSourceTitle => 'Open Source & Transparent';

  @override
  String get forYouAlgorithmReactionsDescription =>
      'Medium signal — a quick way to show appreciation';

  @override
  String get forYouAlgorithmReactionsTitle => 'Reactions';

  @override
  String get forYouAlgorithmRepostsDescription =>
      'Strongest signal — sharing with your followers is a powerful endorsement';

  @override
  String get forYouAlgorithmSubtitle =>
      'Powered by Gorse, an open-source recommendation engine';

  @override
  String get forYouAlgorithmTitle => 'The Divine Algorithm';

  @override
  String get forYouAlgorithmViewsDescription =>
      'Light signal — indicates basic interest';

  @override
  String get forYouEmptyDescription =>
      'Watch and like some videos to get personalized recommendations.';

  @override
  String get forYouEmptyTitle => 'No Recommendations Yet';

  @override
  String get forYouErrorTitle => 'Failed to load recommendations';

  @override
  String get forYouUnavailableDescription =>
      'Personalized recommendations require connection to Funnelcake.';

  @override
  String get forYouUnavailableTitle => 'For You Unavailable';

  @override
  String get inboxConversationOptionsLabel => 'Options';

  @override
  String get inboxConversationViewProfileButton => 'View profile';

  @override
  String get inboxMessageRequestsEmpty => 'No message requests';

  @override
  String inboxMessageRequestsSemanticLabel(int requestCount) {
    return 'Message requests, $requestCount pending';
  }

  @override
  String get inboxMessageRequestsTitle => 'Message requests';

  @override
  String get inboxMessagesTab => 'Messages';

  @override
  String inboxRequestTileLabel(String displayName) {
    return '$displayName message request';
  }

  @override
  String get inboxRequestTileSubtitle => 'Sent a message request';

  @override
  String get inboxRequestsMarkAllRead => 'Mark all requests as read';

  @override
  String get inboxRequestsRemoveAll => 'Remove all requests';

  @override
  String get messageRequestDeclineAndRemoveButton => 'Decline and remove';

  @override
  String messageRequestFollowersCount(String count) {
    return '$count Followers';
  }

  @override
  String messageRequestVideosCount(String count) {
    return '$count videos';
  }

  @override
  String messageRequestMessageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count messages',
      one: '1 message',
    );
    return '$_temp0';
  }

  @override
  String get messageRequestViewMessagesButton => 'View messages';

  @override
  String get messageRequestViewProfileButton => 'View profile';

  @override
  String messageRequestWantsToMessageYou(
    String displayName,
    String messageText,
  ) {
    return '$displayName wants to message you, they\'ve sent $messageText.';
  }

  @override
  String get deleteAccountConfirmationHint => 'Type DELETE';

  @override
  String get deleteAccountContentDeletionFailed =>
      'Failed to delete content from relays';

  @override
  String get deleteAccountDeleteAllContentButton => 'Delete All Content';

  @override
  String get deleteAccountFinalConfirmationBody =>
      'To confirm permanent deletion of ALL your content from Nostr relays, type:';

  @override
  String get deleteAccountFinalConfirmationTitle => '⚠️ Final Confirmation';

  @override
  String get deleteAccountKeyDeletionWarning =>
      'Account deleted, but your keys may not have been fully removed from this device. Go to Settings → Nostr Keys → Remove Keys to retry.';

  @override
  String get deleteAccountPreparingDeletion => 'Preparing deletion...';

  @override
  String deleteAccountProgressEvents(int current, int total) {
    return '$current / $total events';
  }

  @override
  String get deleteAccountRemoveKeysBody =>
      'This removes the local login for this account from this device. It won\'t delete your Divine account or Nostr identity.\n\nIf this is your last local account, you\'ll return to the login screen.';

  @override
  String get deleteAccountRemoveKeysConfirm => 'Remove from device';

  @override
  String get deleteAccountRemoveKeysTitle =>
      'Remove this account from this device?';

  @override
  String get deleteAccountServerDeletionFailed =>
      'Could not delete your account from the server. Please check your connection and try again.';

  @override
  String get deleteAccountSuccess => 'Your account has been deleted';

  @override
  String get exportProgressStageApplyingTextOverlay => 'Adding text overlay...';

  @override
  String get exportProgressStageComplete => 'Export complete!';

  @override
  String get exportProgressStageConcatenating => 'Combining clips...';

  @override
  String get exportProgressStageError => 'Export failed';

  @override
  String get exportProgressStageGeneratingThumbnail =>
      'Generating thumbnail...';

  @override
  String get exportProgressStageMixingAudio => 'Adding sound...';

  @override
  String get findPeopleAnonymousUser => 'Anonymous';

  @override
  String get findPeopleNoContacts =>
      'No contacts found.\nStart following people to see them here.';

  @override
  String get geoBlockedCityLabel => 'City';

  @override
  String get geoBlockedCountryLabel => 'Country';

  @override
  String get geoBlockedDefaultReason =>
      'This service is not available in your region due to local regulations.';

  @override
  String get geoBlockedLegalNotice =>
      'We respect your local laws and regulations. This restriction is based on your IP address location.';

  @override
  String get geoBlockedRegionLabel => 'Region';

  @override
  String get geoBlockedTitle => 'Service Unavailable';

  @override
  String get likedVideosEmpty => 'No liked videos';

  @override
  String get likedVideosInvalidRoute => 'Invalid route';

  @override
  String get likedVideosTitle => 'Liked Videos';

  @override
  String get ogVinerBadgeSemanticLabel => 'OG Viner';

  @override
  String get uploadFailureSheetRetryingSnackbar => 'Retrying upload…';

  @override
  String get uploadFailureSheetSaveToDraftsButton => 'Save to Drafts';

  @override
  String get uploadFailureSheetSavedToDraftsSnackbar => 'Saved to drafts';

  @override
  String get uploadFailureSheetTitle => 'Upload Failed';

  @override
  String get uploadFailureSheetTryAgainButton => 'Try Again';

  @override
  String get videoEditorAudioImportAudio => 'Import audio';

  @override
  String get videoEditorAudioImportFailed => 'Audio import failed.';

  @override
  String get videoIconPlaceholderLabel => 'Video';

  @override
  String videoInspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspired by $creatorName. Tap to view their profile.';
  }

  @override
  String get proofmodeBadgeAiScanPending => 'AI scan pending';

  @override
  String get proofmodeBadgeHumanMade => 'Human Made';

  @override
  String get proofmodeBadgeNotDivineHosted => 'Not Divine Hosted';

  @override
  String get proofmodeBadgeOriginal => 'Original';

  @override
  String get proofmodeBadgePossiblyAiGenerated => 'Possibly AI-Generated';

  @override
  String get proofmodeBadgeUnverified => 'Unverified';

  @override
  String get proofmodeConfirmedByModerator => 'Confirmed by human moderator';

  @override
  String get proofmodeExternalContentTitle => 'External Content';

  @override
  String get proofmodeHostedOnLabel => 'This video is hosted on:';

  @override
  String get proofmodeLikelyHumanCreated => 'Likely human-created';

  @override
  String get proofmodeNoProofDataAttached => 'No ProofMode data attached';

  @override
  String get proofmodeNotDivineHostedDisclaimer =>
      'This content is not hosted on Divine servers. We cannot fully guarantee its authenticity.';

  @override
  String get proofmodePossiblyAiGenerated => 'Possibly AI-generated';

  @override
  String get proofmodePublishedByLabel => 'Published by:';

  @override
  String searchFilterPillSemanticLabel(String filter) {
    return 'Filter: $filter';
  }

  @override
  String searchNoResultsFound(String query) {
    return 'No results found for \"$query\"';
  }

  @override
  String searchTagChipViewVideosTaggedLabel(String tag) {
    return 'View videos tagged $tag';
  }

  @override
  String audioAttributionRowSemanticLabel(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName by $creatorName. Tap to view sound details.';
  }

  @override
  String metadataSoundsOriginalSoundSemantics(String creatorName) {
    return 'Original sound by $creatorName. Tap to use this sound.';
  }

  @override
  String metadataSoundsSharedSoundSemantics(
    String soundName,
    String creatorName,
  ) {
    return 'Sound: $soundName by $creatorName. Tap to view details.';
  }

  @override
  String soundDetailLoadError(String error) {
    return 'Failed to load sound: $error';
  }

  @override
  String get soundDetailNotFoundMessage => 'This sound could not be found';

  @override
  String get soundDetailNotFoundTitle => 'Sound Not Found';

  @override
  String get videoFeedDescriptionSemanticLabel => 'Video description';

  @override
  String videoFeedLoopCountLabel(int count) {
    return '🔁 $count loops';
  }

  @override
  String get videoFeedLoopCountSemanticLabel => 'Video loop count';

  @override
  String get originalSoundUnavailableBody =>
      'Audio from this video is not available separately.';

  @override
  String originalSoundByCreator(String creatorName) {
    return 'Original sound - $creatorName';
  }

  @override
  String globalUploadPendingCount(int count) {
    return 'Pending Uploads ($count)';
  }

  @override
  String get ogVinerBadgeLabel => 'OG Viner';

  @override
  String shareVideoInListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'In $count lists',
      one: 'In 1 list',
    );
    return '$_temp0';
  }

  @override
  String get unfollowConfirmButton => 'Unfollow';

  @override
  String get videoClipSaveFailed => 'Failed to save clip';

  @override
  String videoClipSaveTo(String destination) {
    return 'Save to $destination';
  }

  @override
  String get videoClipDelete => 'Delete clip';

  @override
  String inspiredByAttributionSemanticLabel(String creatorName) {
    return 'Inspired by $creatorName. Tap to view their profile.';
  }

  @override
  String get bugReportSendReport => 'Enviar relatório';

  @override
  String get supportSubjectRequiredLabel => 'Assunto *';

  @override
  String get supportRequiredHelper => 'Obrigatório';

  @override
  String get bugReportSubjectHint => 'Resumo curto do problema';

  @override
  String get bugReportDescriptionRequiredLabel => 'O que aconteceu? *';

  @override
  String get bugReportDescriptionHint =>
      'Descreva o problema que você encontrou';

  @override
  String get bugReportStepsLabel => 'Passos para reproduzir';

  @override
  String get bugReportStepsHint =>
      '1. Vá para...\n2. Toque em...\n3. Veja o erro';

  @override
  String get bugReportExpectedBehaviorLabel => 'Comportamento esperado';

  @override
  String get bugReportExpectedBehaviorHint => 'O que deveria ter acontecido?';

  @override
  String get bugReportDiagnosticsNotice =>
      'Informações do dispositivo e logs serão incluídos automaticamente.';

  @override
  String get bugReportSuccessMessage =>
      'Valeu! Recebemos seu relatório e vamos usar pra deixar o Divine melhor.';

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
      'Falha ao enviar relatório de bug. Tente novamente mais tarde.';

  @override
  String bugReportFailedWithError(String error) {
    return 'Falha ao enviar relatório de bug: $error';
  }

  @override
  String get featureRequestSendRequest => 'Enviar pedido';

  @override
  String get featureRequestSubjectHint => 'Resumo curto da sua ideia';

  @override
  String get featureRequestDescriptionRequiredLabel => 'O que você quer? *';

  @override
  String get featureRequestDescriptionHint =>
      'Descreva o recurso que você quer';

  @override
  String get featureRequestUsefulnessLabel => 'Como isso seria útil?';

  @override
  String get featureRequestUsefulnessHint =>
      'Explique o benefício que esse recurso traria';

  @override
  String get featureRequestWhenLabel => 'Quando você usaria isso?';

  @override
  String get featureRequestWhenHint =>
      'Descreva as situações em que isso ajudaria';

  @override
  String get featureRequestSuccessMessage =>
      'Valeu! Recebemos seu pedido de recurso e vamos avaliar.';

  @override
  String get featureRequestSendFailed =>
      'Falha ao enviar pedido de recurso. Tente novamente mais tarde.';

  @override
  String featureRequestFailedWithError(String error) {
    return 'Falha ao enviar pedido de recurso: $error';
  }

  @override
  String get notificationFollowBack => 'Seguir de volta';

  @override
  String get followingTitle => 'Seguindo';

  @override
  String followingTitleForName(String displayName) {
    return 'Quem $displayName segue';
  }

  @override
  String get followingFailedToLoadList => 'Falha ao carregar lista de seguindo';

  @override
  String get followingEmptyTitle => 'Ainda não segue ninguém';

  @override
  String get followersTitle => 'Seguidores';

  @override
  String followersTitleForName(String displayName) {
    return 'Seguidores de $displayName';
  }

  @override
  String get followersFailedToLoadList =>
      'Falha ao carregar lista de seguidores';

  @override
  String get followersEmptyTitle => 'Sem seguidores ainda';

  @override
  String get followersUpdateFollowFailed =>
      'Falha ao atualizar status de seguir. Tente novamente.';

  @override
  String get reportMessageTitle => 'Denunciar mensagem';

  @override
  String get reportMessageWhyReporting =>
      'Por que você está denunciando esta mensagem?';

  @override
  String get reportMessageSelectReason =>
      'Escolha um motivo para denunciar esta mensagem';

  @override
  String get newMessageTitle => 'Nova mensagem';

  @override
  String get newMessageFindPeople => 'Encontrar pessoas';

  @override
  String get newMessageNoContacts =>
      'Nenhum contato encontrado.\nSiga pessoas para vê-las aqui.';

  @override
  String get newMessageNoUsersFound => 'Nenhum usuário encontrado';

  @override
  String get hashtagSearchTitle => 'Buscar hashtags';

  @override
  String get hashtagSearchSubtitle => 'Descubra tópicos em alta e conteúdo';

  @override
  String hashtagSearchNoResults(String query) {
    return 'Nenhuma hashtag encontrada para \"$query\"';
  }

  @override
  String get hashtagSearchFailed => 'Busca falhou';

  @override
  String get userNotAvailableTitle => 'Conta indisponível';

  @override
  String get userNotAvailableBody => 'Esta conta não está disponível agora.';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Falha ao salvar configurações: $error';
  }

  @override
  String get blossomValidServerUrl =>
      'Insira uma URL de servidor válida (ex.: https://blossom.band)';

  @override
  String get blossomSettingsSaved => 'Configurações do Blossom salvas';

  @override
  String get blossomSaveTooltip => 'Salvar';

  @override
  String get blossomAboutTitle => 'Sobre o Blossom';

  @override
  String get blossomAboutDescription =>
      'Blossom é um protocolo descentralizado de armazenamento de mídia que permite enviar vídeos para qualquer servidor compatível. Por padrão, os vídeos são enviados para o servidor Blossom do Divine. Ative a opção abaixo para usar um servidor personalizado.';

  @override
  String get blossomUseCustomServer => 'Usar servidor Blossom personalizado';

  @override
  String get blossomCustomServerEnabledSubtitle =>
      'Os vídeos serão enviados para seu servidor Blossom personalizado';

  @override
  String get blossomCustomServerDisabledSubtitle =>
      'Seus vídeos estão sendo enviados para o servidor Blossom do Divine';

  @override
  String get blossomCustomServerUrl => 'URL do servidor Blossom personalizado';

  @override
  String get blossomCustomServerHelper =>
      'Insira a URL do seu servidor Blossom personalizado';

  @override
  String get blossomPopularServers => 'Servidores Blossom populares';

  @override
  String get blossomServerUrlMustUseHttps =>
      'A URL do servidor Blossom precisa usar https://';

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Falha ao atualizar configuração de crosspost';

  @override
  String get blueskySignInRequired =>
      'Entre para gerenciar as configurações do Bluesky';

  @override
  String get blueskyPublishVideos => 'Publicar vídeos no Bluesky';

  @override
  String get blueskyEnabledSubtitle =>
      'Seus vídeos serão publicados no Bluesky';

  @override
  String get blueskyDisabledSubtitle =>
      'Seus vídeos não serão publicados no Bluesky';

  @override
  String get blueskyHandle => 'Handle do Bluesky';

  @override
  String get blueskyStatus => 'Status';

  @override
  String get blueskyStatusReady => 'Conta provisionada e pronta';

  @override
  String get blueskyStatusPending => 'Provisionando conta...';

  @override
  String get blueskyStatusFailed => 'Falha ao provisionar conta';

  @override
  String get blueskyStatusDisabled => 'Conta desativada';

  @override
  String get blueskyStatusNotLinked => 'Nenhuma conta do Bluesky vinculada';

  @override
  String get invitesTitle => 'Convidar amigos';

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
  String get invitesNoneAvailable => 'Sem convites disponíveis no momento';

  @override
  String get invitesShareWithPeople =>
      'Compartilhe o diVine com quem você conhece';

  @override
  String get invitesUsedInvites => 'Convites usados';

  @override
  String invitesShareMessage(String code) {
    return 'Vem pro diVine comigo! Use o código $code pra começar:\nhttps://divine.video/invite/$code';
  }

  @override
  String get invitesCopyInvite => 'Copiar convite';

  @override
  String get invitesCopied => 'Convite copiado!';

  @override
  String get invitesShareInvite => 'Compartilhar convite';

  @override
  String get invitesShareSubject => 'Vem pro diVine comigo';

  @override
  String get invitesClaimed => 'Resgatado';

  @override
  String get invitesCouldNotLoad => 'Não foi possível carregar os convites';

  @override
  String get invitesRetry => 'Tentar novamente';

  @override
  String get searchSomethingWentWrong => 'Algo deu errado';

  @override
  String get searchTryAgain => 'Tentar novamente';

  @override
  String get searchForLists => 'Buscar listas';

  @override
  String get searchFindCuratedVideoLists =>
      'Encontre listas de vídeos selecionados';

  @override
  String get searchEnterQuery => 'Digite uma busca';

  @override
  String get searchDiscoverSomethingInteresting => 'Descubra algo interessante';

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
  String get searchVideosSortOptionsLabel => 'Sort video results';

  @override
  String get searchVideosSortTrending => 'Hot';

  @override
  String get searchVideosSortLoops => 'Most loops';

  @override
  String get searchVideosSortEngagement => 'Most engaged';

  @override
  String get searchVideosSortRecent => 'Recent';

  @override
  String get searchListsSectionHeader => 'Listas';

  @override
  String get searchListsLoadingLabel => 'Carregando resultados de listas';

  @override
  String get cameraAgeRestriction =>
      'Você precisa ter 16 anos ou mais para criar conteúdo';

  @override
  String get featureRequestCancel => 'Cancelar';

  @override
  String keyImportError(String error) {
    return 'Erro: $error';
  }

  @override
  String get keyImportInsecureBunkerRelay =>
      'O relay do bunker precisa usar wss:// (ws:// só é permitido em localhost)';

  @override
  String get timeNow => 'agora';

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
    return '${count}d';
  }

  @override
  String timeShortWeeks(int count) {
    return '${count}sem';
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
  String get timeVerboseNow => 'Agora';

  @override
  String timeAgo(String time) {
    return '$time atrás';
  }

  @override
  String get timeToday => 'Hoje';

  @override
  String get timeYesterday => 'Ontem';

  @override
  String get timeJustNow => 'agora mesmo';

  @override
  String timeMinutesAgo(int count) {
    return '${count}min atrás';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h atrás';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d atrás';
  }

  @override
  String get draftTimeJustNow => 'Agora mesmo';

  @override
  String get contentLabelNudity => 'Nudez';

  @override
  String get contentLabelSexualContent => 'Conteúdo sexual';

  @override
  String get contentLabelPornography => 'Pornografia';

  @override
  String get contentLabelGraphicMedia => 'Conteúdo gráfico';

  @override
  String get contentLabelViolence => 'Violência';

  @override
  String get contentLabelSelfHarm => 'Automutilação/Suicídio';

  @override
  String get contentLabelDrugUse => 'Uso de drogas';

  @override
  String get contentLabelAlcohol => 'Álcool';

  @override
  String get contentLabelTobacco => 'Tabaco/Tabagismo';

  @override
  String get contentLabelGambling => 'Jogos de azar';

  @override
  String get contentLabelProfanity => 'Linguagem obscena';

  @override
  String get contentLabelHateSpeech => 'Discurso de ódio';

  @override
  String get contentLabelHarassment => 'Assédio';

  @override
  String get contentLabelFlashingLights => 'Luzes piscantes';

  @override
  String get contentLabelAiGenerated => 'Gerado por IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Golpe/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Enganoso';

  @override
  String get contentLabelSensitiveContent => 'Conteúdo sensível';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName curtiu seu vídeo';
  }

  @override
  String notificationLikedYourComment(String actorName) {
    return '$actorName curtiu seu comentário';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName comentou no seu vídeo';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName começou a seguir você';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName mencionou você';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName repostou seu vídeo';
  }

  @override
  String notificationRepliedToYourComment(String actorName) {
    return '$actorName respondeu ao teu comentário';
  }

  @override
  String get notificationAndConnector => 'e';

  @override
  String notificationOthersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'mais $count pessoas',
      one: 'mais 1 pessoa',
    );
    return '$_temp0';
  }

  @override
  String get notificationSystemUpdate => 'Você tem uma nova atualização';

  @override
  String get notificationSomeoneLikedYourVideo => 'Alguém curtiu seu vídeo';

  @override
  String get commentReplyToPrefix => 'Re:';

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
  String get draftUntitled => 'Sem título';

  @override
  String get contentWarningNone => 'Nenhum';

  @override
  String get textBackgroundNone => 'Nenhum';

  @override
  String get textBackgroundSolid => 'Sólido';

  @override
  String get textBackgroundHighlight => 'Destaque';

  @override
  String get textBackgroundTransparent => 'Transparente';

  @override
  String get textAlignLeft => 'Esquerda';

  @override
  String get textAlignRight => 'Direita';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'A câmera ainda não é compatível na web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'A captura e a gravação com câmera ainda não estão disponíveis na versão web.';

  @override
  String get cameraPermissionBackToFeed => 'Voltar ao feed';

  @override
  String get cameraPermissionErrorTitle => 'Erro de permissão';

  @override
  String get cameraPermissionErrorDescription =>
      'Ocorreu um erro ao verificar as permissões.';

  @override
  String get cameraPermissionRetry => 'Tentar novamente';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Permitir acesso à câmera e ao microfone';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Isso permite capturar e editar vídeos direto no app, nada além disso.';

  @override
  String get cameraPermissionContinue => 'Continuar';

  @override
  String get cameraPermissionGoToSettings => 'Ir para configurações';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Por que seis segundos?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Clipes curtos abrem espaço para a espontaneidade. O formato de 6 segundos ajuda você a capturar momentos autênticos enquanto acontecem.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Entendi!';

  @override
  String get videoRecorderUploadTitle => 'Por que sem upload?';

  @override
  String get videoRecorderUploadBody =>
      'O que você vê no Divine é feito por humanos: cru e capturado no momento. Diferente das plataformas que permitem uploads muito produzidos ou gerados por IA, priorizamos a autenticidade da experiência câmera-direta.';

  @override
  String get videoRecorderUploadBodyDetail =>
      'Ao manter a criação dentro do app, podemos garantir melhor que o conteúdo é real e sem edição. Não estamos abrindo uploads da galeria externa neste momento para proteger essa autenticidade e manter nossa comunidade livre de conteúdo sintético tanto quanto possível.';

  @override
  String get videoRecorderUploadBodyCta =>
      'Mude para Capture ou Classic para gravar algo real.';

  @override
  String get videoRecorderUploadLearnMore =>
      'Saiba como a verificação funciona';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Encontramos trabalho em andamento';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Você gostaria de continuar de onde parou?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Sim, continuar';

  @override
  String get videoRecorderAutosaveDiscardButton => 'Não, iniciar um novo vídeo';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Não foi possível restaurar seu rascunho';

  @override
  String get videoRecorderStopRecordingTooltip => 'Parar gravação';

  @override
  String get videoRecorderStartRecordingTooltip => 'Iniciar gravação';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Gravando. Toque em qualquer lugar para parar';

  @override
  String get videoRecorderTapToStartLabel =>
      'Toque em qualquer lugar para iniciar a gravação';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Excluir último clipe';

  @override
  String get videoRecorderSwitchCameraLabel => 'Trocar câmera';

  @override
  String videoRecorderZoomLevelLabel(String zoom) {
    return 'Zoom para $zoom×';
  }

  @override
  String get videoRecorderToggleGridLabel => 'Alternar grade';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Alternar quadro fantasma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Quadro fantasma ativado';

  @override
  String get videoRecorderGhostFrameDisabled => 'Quadro fantasma desativado';

  @override
  String get videoRecorderClipDeletedMessage => 'Clipe movido para a lixeira';

  @override
  String get videoRecorderClipUndoLabel => 'Desfazer';

  @override
  String get libraryTrashTitle => 'Excluídos recentemente';

  @override
  String get libraryTrashEmptyTitle => 'A lixeira está vazia';

  @override
  String get libraryTrashEmptySubtitle =>
      'Os clipes excluídos ficam aqui por 30 dias antes de serem removidos permanentemente.';

  @override
  String get libraryTrashRestoreLabel => 'Restaurar';

  @override
  String get libraryTrashDeleteNowLabel => 'Excluir agora';

  @override
  String get libraryTrashEmptyAllLabel => 'Esvaziar lixeira';

  @override
  String get libraryTrashDeleteConfirmTitle => 'Excluir clipe agora?';

  @override
  String get libraryTrashDeleteConfirmMessage =>
      'Isso remove o clipe da lixeira imediatamente.';

  @override
  String get libraryTrashEmptyConfirmTitle => 'Esvaziar lixeira?';

  @override
  String libraryTrashEmptyConfirmMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes',
      one: '1 clipe',
    );
    return 'Isso exclui permanentemente da lixeira $_temp0 agora mesmo.';
  }

  @override
  String get libraryTrashEntryLabel => 'Excluídos recentemente';

  @override
  String get videoRecorderCloseLabel => 'Fechar gravador de vídeo';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuar para o editor de vídeo';

  @override
  String get videoRecorderCaptureCloseLabel => 'Fechar';

  @override
  String get videoRecorderCaptureNextLabel => 'Próximo';

  @override
  String get videoRecorderToggleFlashLabel => 'Alternar flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Alternar temporizador';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Alternar proporção';

  @override
  String get videoRecorderStabilizationLabel => 'Estabilização';

  @override
  String get videoRecorderStabilizationModeOff => 'Desativada';

  @override
  String get videoRecorderStabilizationModeStandard => 'Padrão';

  @override
  String get videoRecorderStabilizationModeCinematic => 'Cinematográfica';

  @override
  String get videoRecorderStabilizationModeCinematicExtended =>
      'Cinematográfica ampliada';

  @override
  String get videoRecorderStabilizationModeAuto => 'Automática';

  @override
  String get videoRecorderLibraryEmptyLabel =>
      'Biblioteca de clipes, sem clipes';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Abrir biblioteca de clipes, $clipCount clipes',
      one: 'Abrir biblioteca de clipes, 1 clipe',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Câmera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Abrir câmera';

  @override
  String get videoEditorLibraryLabel => 'Biblioteca';

  @override
  String get videoEditorTextLabel => 'Texto';

  @override
  String get videoEditorDrawLabel => 'Desenhar';

  @override
  String get videoEditorFilterLabel => 'Filtro';

  @override
  String get videoEditorAudioLabel => 'Áudio';

  @override
  String get videoEditorAddTitle => 'Adicionar';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Abrir biblioteca';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Abrir editor de áudio';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Abrir editor de texto';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Abrir editor de desenho';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Abrir editor de filtros';

  @override
  String get videoEditorOpenStickerSemanticLabel => 'Abrir editor de stickers';

  @override
  String get videoEditorSaveDraftTitle => 'Salvar seu rascunho?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Guarde suas edições para depois ou descarte-as e saia do editor.';

  @override
  String get videoEditorSaveDraftButton => 'Salvar rascunho';

  @override
  String get videoEditorDiscardChangesButton => 'Descartar alterações';

  @override
  String get videoEditorKeepEditingButton => 'Continuar editando';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Área para soltar e excluir camada';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Solte para excluir a camada';

  @override
  String get videoEditorDoneLabel => 'Concluído';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Reproduzir ou pausar vídeo';

  @override
  String get videoEditorCropSemanticLabel => 'Recortar';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Não é possível dividir o clipe enquanto ele está sendo processado. Aguarde.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posição de divisão inválida. Ambos os clipes devem ter pelo menos $minDurationMs ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Adicionar clipe da biblioteca';

  @override
  String get videoEditorSaveSelectedClip => 'Salvar clipe selecionado';

  @override
  String get videoEditorSplitClip => 'Dividir clipe';

  @override
  String get videoEditorSaveClip => 'Salvar clipe';

  @override
  String get videoEditorDeleteClip => 'Excluir clipe';

  @override
  String get videoEditorClipSavedSuccess => 'Clipe salvo na biblioteca';

  @override
  String get videoEditorClipSaveFailed => 'Falha ao salvar clipe';

  @override
  String get videoEditorClipDeleted => 'Clipe excluído';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Seletor de cor';

  @override
  String get videoEditorUndoSemanticLabel => 'Desfazer';

  @override
  String get videoEditorRedoSemanticLabel => 'Refazer';

  @override
  String get videoEditorTextColorSemanticLabel => 'Cor do texto';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alinhamento do texto';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Fundo do texto';

  @override
  String get videoEditorFontSemanticLabel => 'Fonte';

  @override
  String get videoEditorNoStickersFound => 'Nenhum sticker encontrado';

  @override
  String get videoEditorNoStickersAvailable => 'Nenhum sticker disponível';

  @override
  String get videoEditorFailedLoadStickers => 'Falha ao carregar stickers';

  @override
  String get videoEditorAdjustVolumeTitle => 'Ajustar volume';

  @override
  String get videoEditorRecordedAudioLabel => 'Áudio gravado';

  @override
  String get videoEditorPlaySemanticLabel => 'Reproduzir';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausar';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Silenciar áudio';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Ativar áudio';

  @override
  String get videoEditorVolumeSemanticLabel => 'Ajustar volume';

  @override
  String videoEditorTimelineVolumePreview(int percent) {
    return 'Volume $percent%';
  }

  @override
  String get videoEditorTimelineSlideToAdjust => 'Deslize para ajustar';

  @override
  String get videoEditorOriginalAudioLabel => 'Áudio original';

  @override
  String videoEditorClipVolumeLabel(int index) {
    return 'Clipe $index';
  }

  @override
  String get videoEditorDeleteLabel => 'Excluir';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Excluir item selecionado';

  @override
  String get videoEditorEditLabel => 'Editar';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Editar item selecionado';

  @override
  String get videoEditorDuplicateLabel => 'Duplicar';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicar item selecionado';

  @override
  String get videoEditorSplitLabel => 'Dividir';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Dividir clipe selecionado';

  @override
  String get videoEditorExtractAudioLabel => 'Extrair áudio';

  @override
  String get videoEditorClipAudioTitle => 'Áudio do clip';

  @override
  String get videoEditorExtractAudioFromClipSemanticLabel =>
      'Extrair áudio do clipe e silenciar o original';

  @override
  String get videoEditorExtractAudioNoLocalFile =>
      'Não é possível extrair o áudio: o clipe não está disponível localmente.';

  @override
  String get videoEditorExtractAudioFailed =>
      'Não foi possível extrair o áudio. Por favor, tente novamente.';

  @override
  String get videoEditorSpeedLabel => 'Velocidade';

  @override
  String get videoEditorSetClipSpeedSemanticLabel =>
      'Definir a velocidade de reprodução do clipe selecionado';

  @override
  String get videoEditorReverseLabel => 'Inverter';

  @override
  String get videoEditorReverseClipSemanticLabel =>
      'Ativar ou desativar a reprodução inversa para o clipe selecionado';

  @override
  String get videoEditorReverseProgressLabel =>
      'Um momento, estamos invertendo seu clipe';

  @override
  String get videoEditorTransformLabel => 'Transformar';

  @override
  String get videoEditorTransformSelectedClipSemanticLabel =>
      'Cortar, girar ou inverter o clipe selecionado';

  @override
  String get videoEditorTransformProgressLabel =>
      'Um momento, estamos transformando seu clipe';

  @override
  String get videoEditorTransformFailed =>
      'Não foi possível transformar o clipe. Tente novamente.';

  @override
  String get videoEditorTransformNoLocalFile =>
      'Não é possível transformar: o clipe não está disponível localmente.';

  @override
  String get videoEditorTransformRotateLabel => 'Girar';

  @override
  String get videoEditorTransformFlipLabel => 'Inverter';

  @override
  String get videoEditorTransformRatioLabel => 'Proporção';

  @override
  String get videoEditorTransformResetLabel => 'Redefinir';

  @override
  String get videoEditorTransformApplySemanticLabel => 'Aplicar transformação';

  @override
  String get videoEditorTransformCancelSemanticLabel =>
      'Cancelar transformação';

  @override
  String get videoEditorTransformPlayLabel => 'Reproduzir';

  @override
  String get videoEditorTransformPauseLabel => 'Pausar';

  @override
  String get videoEditorReverseNoLocalFile =>
      'Não é possível inverter: o clipe não está disponível localmente.';

  @override
  String get videoEditorReverseFailed =>
      'Não foi possível inverter o clipe. Por favor, tente novamente.';

  @override
  String get videoEditorSpeedSheetTitle => 'Velocidade do clipe';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Finalizar edição da linha do tempo';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Reproduzir prévia';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Pausar prévia';

  @override
  String get videoEditorAudioUntitledSound => 'Som sem título';

  @override
  String get videoEditorAudioUntitled => 'Sem título';

  @override
  String get videoEditorAudioAddAudio => 'Adicionar áudio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'Nenhum som disponível';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Os sons aparecerão aqui quando criadores compartilharem áudio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Falha ao carregar sons';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Selecione o trecho de áudio para seu vídeo';

  @override
  String get videoEditorAudioCategoryDivine => 'OG Sounds';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunidade';

  @override
  String get videoEditorAudioCategoryFeatured => 'Destaques';

  @override
  String get videoEditorAudioCategoryMySounds => 'Meus sons';

  @override
  String get videoEditorAudioFeaturedEmptyTitle => 'Sons em destaque em breve';

  @override
  String get videoEditorAudioFeaturedEmptySubtitle =>
      'Soltaremos sons em destaque aqui assim que estiverem prontos.';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Ferramenta seta';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Ferramenta borracha';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Ferramenta marcador';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Ferramenta lápis';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Reordenar camada $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Pressione e segure para reordenar';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Mostrar linha do tempo';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ocultar linha do tempo';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evite posicionar conteúdo atrás dessas áreas.';

  @override
  String get videoEditorStickersDivineOriginals => 'Divine Originais';

  @override
  String get videoEditorStickerSearchHint => 'Buscar stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Selecionar fonte';

  @override
  String get videoEditorFontUnknown => 'Desconhecida';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'A cabeça de reprodução deve estar dentro do clipe selecionado para dividir.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Aparar início';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Aparar fim';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Aparar clipe';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Arraste as alças para ajustar a duração do clipe';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Arrastando clipe $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clipe $index de $total, $duration segundos';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Pressione e segure para reordenar';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Toque para editar. Pressione e arraste para reordenar.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Mover para a esquerda';

  @override
  String get videoEditorTimelineClipMoveRight => 'Mover para a direita';

  @override
  String videoEditorTimelineClipSelectedSemanticLabel(int index, int total) {
    return 'Clipe $index de $total, selecionado';
  }

  @override
  String videoEditorTimelineClipUnselectedSemanticLabel(int index, int total) {
    return 'Clipe $index de $total, não selecionado';
  }

  @override
  String get videoEditorMultiSelectLabel => 'Selecionar';

  @override
  String get videoEditorMultiSelectSemanticLabel => 'Selecionar vários clipes';

  @override
  String get videoEditorMultiSelectDoneSemanticLabel => 'Concluir seleção';

  @override
  String videoEditorMultiSelectCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clipes selecionados',
      one: '1 clipe selecionado',
      zero: 'Nenhum clipe selecionado',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorMergeLabel => 'Mesclar';

  @override
  String get videoEditorMergeSelectedClipsSemanticLabel =>
      'Mesclar clipes selecionados';

  @override
  String get videoEditorDeleteSelectedClipsSemanticLabel =>
      'Excluir clipes selecionados';

  @override
  String get videoEditorMergeProgressLabel =>
      'Um momento, estamos mesclando seus clipes';

  @override
  String get videoEditorMergeFailed =>
      'Não foi possível mesclar os clipes. Tente novamente.';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Pressione e segure para arrastar';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Linha do tempo do vídeo';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes min $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selecionada';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Fechar seletor de cor';

  @override
  String get videoEditorPickColorTitle => 'Escolher cor';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmar cor';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturação e brilho';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturação $saturation%, Brilho $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Matiz';

  @override
  String get videoEditorAddElementSemanticLabel => 'Adicionar elemento';

  @override
  String get videoEditorCloseSemanticLabel => 'Fechar';

  @override
  String get videoEditorDoneSemanticLabel => 'Concluído';

  @override
  String get videoEditorLevelSemanticLabel => 'Nível';

  @override
  String get videoMetadataBackSemanticLabel => 'Voltar';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Fechar diálogo de ajuda';

  @override
  String get videoMetadataGotItButton => 'Entendi!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Limite de 64 KB atingido. Remova parte do conteúdo para continuar.';

  @override
  String get videoMetadataExpirationLabel => 'Expiração';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Selecionar tempo de expiração';

  @override
  String get videoMetadataTitleLabel => 'Título';

  @override
  String get videoMetadataDescriptionLabel => 'Descrição';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Excluir';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Excluir tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Aviso de conteúdo';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Selecionar avisos de conteúdo';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selecione tudo que se aplica ao seu conteúdo';

  @override
  String get videoMetadataContentWarningDoneButton => 'Concluído';

  @override
  String get videoMetadataAudioReuseTitle => 'Publicar este som';

  @override
  String get videoMetadataAudioReuseSubtitle =>
      'Permita que outros salvem e reutilizem o áudio deste vídeo.';

  @override
  String get videoMetadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel =>
      'Adicionar colaborador';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Como os colaboradores funcionam';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max Colaboradores';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Remover colaborador';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Colaboradores são marcados como co-criadores nesta postagem. Você só pode adicionar pessoas que seguem uma à outra mutuamente, e elas aparecem nos metadados quando a postagem é publicada.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Seguidores mútuos';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Você precisa seguir mutuamente $name para adicioná-lo como colaborador.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspirado por';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Definir inspirado por';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Como funcionam os créditos de inspiração';

  @override
  String get videoMetadataInspiredByNone => 'Nenhum';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Use isso para dar atribuição. O crédito de inspirado por é diferente de colaboradores: reconhece influência, mas não marca alguém como co-criador.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'Este criador não pode ser referenciado.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Remover inspirado por';

  @override
  String get videoMetadataPostDetailsTitle => 'Detalhes da postagem';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Salvo na biblioteca';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Falha ao salvar';

  @override
  String get videoMetadataGoToLibraryButton => 'Ir para a biblioteca';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Botão salvar para depois';

  @override
  String get videoMetadataRenderingVideoHint => 'Renderizando vídeo...';

  @override
  String get videoMetadataSavingVideoHint => 'Salvando vídeo...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Salvar vídeo nos rascunhos e $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Salvar para depois';

  @override
  String get videoMetadataPostSemanticLabel => 'Botão publicar';

  @override
  String get videoMetadataPublishVideoHint => 'Publicar vídeo no feed';

  @override
  String get videoMetadataShareReplyToFeedTitle =>
      'Compartilhar também no meu feed';

  @override
  String get videoMetadataShareReplyToFeedSubtitle =>
      'Desligado mantém este vídeo apenas na conversa de comentários.';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Preencha o formulário para habilitar';

  @override
  String get videoMetadataPostButton => 'Publicar';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Abrir tela de pré-visualização da postagem';

  @override
  String get videoMetadataShareTitle => 'Compartilhar';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detalhes do vídeo';

  @override
  String get videoMetadataClassicDoneButton => 'Concluído';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Reproduzir prévia';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pausar prévia';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Fechar prévia do vídeo';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Remover';

  @override
  String get fullscreenFeedRemovedMessage => 'Vídeo removido';

  @override
  String get settingsBadgesTitle => 'Badges';

  @override
  String get settingsBadgesSubtitle =>
      'Aceite premiações e veja o status das badges emitidas.';

  @override
  String get badgesTitle => 'Badges';

  @override
  String get badgesIntroTitle => 'Entenda seu rastro de badges';

  @override
  String get badgesIntroBody =>
      'Veja as badges que você recebeu, escolha quais fixar no seu perfil Nostr e confira se as pessoas aceitaram as badges que você emitiu.';

  @override
  String get badgesOpenApp => 'Abrir app de badges';

  @override
  String get badgesLoadError => 'Não foi possível carregar as badges';

  @override
  String get badgesUpdateError => 'Não foi possível atualizar a badge';

  @override
  String get badgesAwardedSectionTitle => 'Recebidas por você';

  @override
  String get badgesAwardedEmptyTitle => 'Nenhuma badge recebida ainda';

  @override
  String get badgesAwardedEmptySubtitle =>
      'Quando alguém te der uma badge Nostr, ela aparece aqui.';

  @override
  String get badgesStatusAccepted => 'Aceita';

  @override
  String get badgesStatusNotAccepted => 'Não aceita';

  @override
  String get badgesActionRemove => 'Remover';

  @override
  String get badgesActionAccept => 'Aceitar';

  @override
  String get badgesActionReject => 'Recusar';

  @override
  String get badgesIssuedSectionTitle => 'Emitidas por você';

  @override
  String get badgesIssuedEmptyTitle => 'Nenhuma badge emitida ainda';

  @override
  String get badgesIssuedEmptySubtitle =>
      'As badges que você emitir vão mostrar o status de aceitação aqui.';

  @override
  String get badgesIssuedNoRecipients =>
      'Nenhum destinatário encontrado para esta premiação.';

  @override
  String get badgesRecipientAcceptedStatus => 'Aceita pelo destinatário';

  @override
  String get badgesRecipientWaitingStatus => 'Aguardando destinatário';

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
      'Why we won\'t tell you to just click back';

  @override
  String get minorAccountReviewUnder13HonestyBody =>
      'A lot of the internet is set up to reward people for saying whatever gets them through the gate. We don\'t think that\'s great. Yes, you could go back and say you\'re older than you are, but that wouldn\'t be honest, and we\'re not going to coach you into lying to get what you want.';

  @override
  String get minorAccountReviewUnder13LegalTitle =>
      'Why the answer is still no';

  @override
  String get minorAccountReviewUnder13LegalBody =>
      'We\'re trying to help young people use Divine in ways that are healthy and positive for them and the people around them. We also have to follow laws that are different in different places. So, if you\'re under 13, the answer is that you can\'t have your own account today.';

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
      'Why we ask a parent or guardian to be involved';

  @override
  String get minorAccountReviewParentConsentHonestyBody =>
      'Divine has to follow age-related laws around the world. We also know that most technical age gates are imperfect. Rather than pretending the rules don\'t exist or that it\'s cool to lie about your age, we want teens and families to make thoughtful decisions about how best to use Divine. That\'s why, for 13-15 year olds, we ask parents to be part of the account creation process.';

  @override
  String get minorAccountReviewParentConsentLegalBody =>
      'We also have to follow the law, and those rules are different depending on where someone lives. So instead of pretending the rules do not exist, we ask for a parent or guardian to be part of the process.';

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
      '13-15 account review help';

  @override
  String get minorAccountReviewParentConsentEmailBody =>
      'Hi Divine support,\n\nI am contacting Divine about an account for a teen who is 13 to 15.\n\nI have attached a short private video that shows:\n- the teen\n- a parent or guardian speaking on camera\n- that the teen has permission to use Divine\n- that the parent or guardian knows about the account and will supervise its use\n\nCountry/ies of residence:\n\nHelpful context:\n\nThanks.';

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
  String get commentsRecordVideoButtonLabel => 'Gravar comentário em vídeo';

  @override
  String get commentsOpenVideoLabel => 'Abrir comentário em vídeo';

  @override
  String get commentsMuteVideoReplyLabel => 'Silenciar resposta em vídeo';

  @override
  String get commentsUnmuteVideoReplyLabel => 'Ativar som da resposta em vídeo';

  @override
  String get commentsOpenReplyParentLabel =>
      'Abrir o vídeo ao qual isto responde';

  @override
  String get commentsReplyParentSectionTitle => 'Em resposta a';

  @override
  String commentsReplyParentLabel(String target) {
    return 'Responder a $target';
  }

  @override
  String get commentsReplyParentFallbackLabel => 'Responder ao vídeo';

  @override
  String verifiedAccountChipSemanticLabel(String platform, String identity) {
    return 'Conta $platform verificada: $identity';
  }

  @override
  String get profileEditVerifiedAccountsTitle => 'Contas verificadas';

  @override
  String get profileEditGetVerifiedCta => 'Verifique-se';

  @override
  String get profileEditGetVerifiedSubtitle =>
      'Conecte suas redes sociais para que as pessoas saibam que é você mesmo.';

  @override
  String profileWebsiteSemanticLabel(String url) {
    return 'Visit website: $url';
  }

  @override
  String get profileCouldNotOpenWebsite => 'Could not open website';

  @override
  String get videoMetadataEditCoverTitle => 'Editar capa';

  @override
  String get videoMetadataEditCoverCloseSemanticLabel =>
      'Fechar editor de capa';

  @override
  String get videoMetadataEditCoverConfirmSemanticLabel =>
      'Confirmar seleção de capa';

  @override
  String get videoMetadataEditCoverStripSemanticLabel =>
      'Percorra o vídeo para selecionar o quadro de capa';

  @override
  String get videoMetadataTagsPickerSearchHint => 'Pesquisar ou adicionar tags';

  @override
  String get videoMetadataTagsPickerEmptyHint =>
      'Adiciona tags para que outros descubram o teu vídeo';

  @override
  String get videoMetadataTagsPickerNoResults => 'Sem tags correspondentes';

  @override
  String videoMetadataTagsPickerAddTag(String tag) {
    return 'Adicionar «#$tag»';
  }

  @override
  String get authMinAgeNotice => 'Divine accounts are for ages 16 and up.';

  @override
  String get authUnder16Prefix => 'Not 16 yet? That\'s OK. ';

  @override
  String get authUnder16ChoicesCta => 'Here are your choices.';

  @override
  String get minorAccountReviewUnder13WhyTitle => 'Here\'s why';

  @override
  String get generalSettingsHoldToRecord => 'Segurar para gravar';

  @override
  String get generalSettingsHoldToRecordSubtitle =>
      'A gravação começa ao manter pressionado e para ao soltar';

  @override
  String get soundsPreviewFailedGeneric =>
      'Falha ao reproduzir pré-visualização';

  @override
  String uploadPublishedCountMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vídeos publicados no seu perfil',
      one: 'Vídeo publicado no seu perfil',
    );
    return '$_temp0';
  }

  @override
  String get dmMessageSendLabel => 'Send message';

  @override
  String get emojiPickerSearchHint => 'Pesquisar';

  @override
  String get emojiCategoryRecent => 'Recentes';

  @override
  String get emojiCategorySmileys => 'Smileys e pessoas';

  @override
  String get emojiCategoryAnimals => 'Animais e natureza';

  @override
  String get emojiCategoryFood => 'Comida e bebida';

  @override
  String get emojiCategoryActivities => 'Atividades';

  @override
  String get emojiCategoryTravel => 'Viagens e lugares';

  @override
  String get emojiCategoryObjects => 'Objetos';

  @override
  String get emojiCategorySymbols => 'Símbolos';

  @override
  String get emojiCategoryFlags => 'Bandeiras';

  @override
  String get videoEditorMarkerLabel => 'Marcador';

  @override
  String get videoEditorAddTimelineMarkerSemanticLabel =>
      'Adicionar marcador à linha do tempo';

  @override
  String get videoEditorRemoveTimelineMarkerSemanticLabel =>
      'Remover marcador da linha do tempo';

  @override
  String get videoEditorDeleteTimelineMarkerTitle => 'Excluir marcador?';

  @override
  String get videoEditorDeleteTimelineMarkerSubtitle =>
      'Isso remove o marcador da linha do tempo. Sua edição permanece intacta.';

  @override
  String get videoEditorVolumeLongPressHint =>
      'Silenciar ou ativar todas as faixas';

  @override
  String get videoEditorSplitFailed => 'Falha na divisão. Tente novamente.';
}
