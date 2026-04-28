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
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

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
  String get profileLoadingTitle => 'Carregando perfil...';

  @override
  String get profileLoadingSubtitle => 'Isso pode levar alguns instantes';

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
  String profileSetupCameraAccessFailed(Object error) {
    return 'Falha no acesso à câmera: $error';
  }

  @override
  String get profileSetupGotItButton => 'Entendi';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Falha ao enviar imagem: $error';
  }

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
      'O nome de usuário deve ter de 3 a 20 caracteres';

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
  String get shareFailedToAddBookmark => 'Falha ao adicionar aos favoritos';

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
  String get videoOverlayOpenMetadataFromTitle => 'Open video details';

  @override
  String get videoOverlayOpenMetadataFromDescription => 'Open video details';

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
  String get notificationSettingsSystem => 'Sistema';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Atualizações do app e mensagens do sistema';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Notificações push';

  @override
  String get notificationSettingsPushNotifications => 'Notificações push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Receber notificações quando o app estiver fechado';

  @override
  String get notificationSettingsSound => 'Som';

  @override
  String get notificationSettingsSoundSubtitle => 'Tocar som nas notificações';

  @override
  String get notificationSettingsVibration => 'Vibração';

  @override
  String get notificationSettingsVibrationSubtitle => 'Vibrar nas notificações';

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
  String get authSignInDifferentAccount => 'Entrar com outra conta';

  @override
  String get authSignBackIn => 'Entrar de novo';

  @override
  String get authTermsPrefix =>
      'Ao selecionar uma opção acima, você confirma que tem pelo menos 16 anos e concorda com os ';

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
  String get authForgotPassword => 'Esqueceu a senha?';

  @override
  String get authImportNostrKey => 'Importar chave Nostr';

  @override
  String get authConnectSignerApp => 'Conectar com um app signer';

  @override
  String get authSignInWithAmber => 'Entrar com Amber';

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
  String get shareMenuVideoUpdated => 'Vídeo atualizado com sucesso';

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
  String get reportReasonSpam => 'Spam ou conteúdo indesejado';

  @override
  String get reportReasonHarassment => 'Assédio, bullying ou ameaças';

  @override
  String get reportReasonViolence => 'Conteúdo violento ou extremista';

  @override
  String get reportReasonSexualContent => 'Conteúdo sexual ou adulto';

  @override
  String get reportReasonCopyright => 'Violação de direitos autorais';

  @override
  String get reportReasonFalseInfo => 'Informações falsas';

  @override
  String get reportReasonCsam => 'Violação de segurança infantil';

  @override
  String get reportReasonAiGenerated => 'Conteúdo gerado por IA';

  @override
  String get reportReasonOther => 'Outra violação de política';

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
  String get reportLearnMore => 'Saiba mais';

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
  String get profileSetupUploadSuccess => 'Foto de perfil enviada com sucesso!';

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
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Falha ao atualizar assinatura: $error';
  }

  @override
  String get commonRetry => 'Tentar novamente';

  @override
  String get commonNext => 'Próximo';

  @override
  String get commonDelete => 'Excluir';

  @override
  String get commonCancel => 'Cancelar';

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
  String get routerInvalidCreator => 'Criador inválido';

  @override
  String get routerInvalidHashtagRoute => 'Rota de hashtag inválida';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'Não foi possível carregar os vídeos';

  @override
  String get categoriesCouldNotLoadCategories =>
      'Não foi possível carregar as categorias';

  @override
  String get notificationFollowBack => 'Seguir de volta';

  @override
  String get followingFailedToLoadList => 'Falha ao carregar lista de seguindo';

  @override
  String get followersFailedToLoadList =>
      'Falha ao carregar lista de seguidores';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Falha ao salvar configurações: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Falha ao atualizar configuração de crosspost';

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
  String get videoRecorderToggleGridLabel => 'Alternar grade';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Alternar quadro fantasma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Quadro fantasma ativado';

  @override
  String get videoRecorderGhostFrameDisabled => 'Quadro fantasma desativado';

  @override
  String get videoRecorderClipDeletedMessage => 'Clipe excluído';

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
  String get videoEditorVolumeLabel => 'Volume';

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
  String get videoEditorCustomAudioLabel => 'Áudio personalizado';

  @override
  String get videoEditorPlaySemanticLabel => 'Reproduzir';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausar';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Silenciar áudio';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Ativar áudio';

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
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Comunidade';

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
  String get metadataCaptionsLabel => 'Legendas';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Legendas ativadas para todos os vídeos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Legendas desativadas para todos os vídeos';

  @override
  String get fullscreenFeedRemovedMessage => 'Vídeo removido';
}
