// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Spanish Castilian (`es`).
class AppLocalizationsEs extends AppLocalizations {
  AppLocalizationsEs([String locale = 'es']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Ajustes';

  @override
  String get settingsSecureAccount => 'Asegurá tu cuenta';

  @override
  String get settingsSessionExpired => 'Sesión vencida';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Iniciá sesión de nuevo para recuperar el acceso total';

  @override
  String get settingsCreatorAnalytics => 'Analíticas del creador';

  @override
  String get settingsSupportCenter => 'Centro de soporte';

  @override
  String get settingsNotifications => 'Notificaciones';

  @override
  String get settingsContentPreferences => 'Preferencias de contenido';

  @override
  String get settingsModerationControls => 'Controles de moderación';

  @override
  String get settingsBlueskyPublishing => 'Publicación en Bluesky';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Gestioná las publicaciones cruzadas a Bluesky';

  @override
  String get settingsNostrSettings => 'Ajustes de Nostr';

  @override
  String get settingsIntegratedApps => 'Apps integradas';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps de terceros aprobadas que funcionan dentro de Divine';

  @override
  String get settingsExperimentalFeatures => 'Funciones experimentales';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Novedades que pueden fallar—probalas si te pica la curiosidad.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permisos de integración';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Revisá y revocá las integraciones que autorizaste';

  @override
  String settingsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get settingsVersionEmpty => 'Versión';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'El modo desarrollador ya está activado';

  @override
  String get settingsDeveloperModeEnabled => '¡Modo desarrollador activado!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return 'Te faltan $count toques para activar el modo desarrollador';
  }

  @override
  String get settingsInvites => 'Invitaciones';

  @override
  String get settingsSwitchAccount => 'Cambiar de cuenta';

  @override
  String get settingsAddAnotherAccount => 'Agregar otra cuenta';

  @override
  String get settingsUnsavedDraftsTitle => 'Borradores sin guardar';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'borradores sin guardar',
      one: 'borrador sin guardar',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tus borradores',
      one: 'tu borrador',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'los',
      one: 'lo',
    );
    return 'Tenés $count $_temp0. Cambiar de cuenta va a mantener $_temp1, pero quizás quieras publicar o revisar$_temp2 primero.';
  }

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsSwitchAnyway => 'Cambiar igual';

  @override
  String get settingsAppVersionLabel => 'Versión de la app';

  @override
  String get settingsAppLanguage => 'Idioma de la app';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (predeterminado del dispositivo)';
  }

  @override
  String get settingsAppLanguageTitle => 'Idioma de la app';

  @override
  String get settingsAppLanguageDescription =>
      'Elegí el idioma para la interfaz de la app';

  @override
  String get settingsAppLanguageUseDeviceLanguage =>
      'Usar el idioma del dispositivo';

  @override
  String get contentPreferencesTitle => 'Preferencias de contenido';

  @override
  String get contentPreferencesContentFilters => 'Filtros de contenido';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Gestioná los filtros de advertencia de contenido';

  @override
  String get contentPreferencesContentLanguage => 'Idioma del contenido';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (predeterminado del dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etiquetá tus videos con un idioma para que quien mire pueda filtrar el contenido.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usar el idioma del dispositivo (predeterminado)';

  @override
  String get contentPreferencesAudioSharing =>
      'Permitir que reutilicen mi audio';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Si lo activás, otros pueden usar el audio de tus videos';

  @override
  String get contentPreferencesAccountLabels => 'Etiquetas de la cuenta';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Auto-etiquetá tu contenido';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etiquetas de contenido de la cuenta';

  @override
  String get contentPreferencesClearAll => 'Limpiar todo';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Seleccioná todas las que apliquen a tu cuenta';

  @override
  String get contentPreferencesDoneNoLabels => 'Listo (sin etiquetas)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Listo ($count seleccionadas)';
  }

  @override
  String get contentPreferencesAudioInputDevice =>
      'Dispositivo de entrada de audio';

  @override
  String get contentPreferencesAutoRecommended => 'Automático (recomendado)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Elige automáticamente el mejor micrófono';

  @override
  String get contentPreferencesSelectAudioInput => 'Elegí la entrada de audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Micrófono desconocido';

  @override
  String get profileBlockedAccountNotAvailable =>
      'Esta cuenta no está disponible';

  @override
  String profileErrorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get profileInvalidId => 'ID de perfil inválido';

  @override
  String profileShareText(String displayName, String npub) {
    return '¡Mirá a $displayName en Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName en Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'No se pudo compartir el perfil: $error';
  }

  @override
  String get profileEditProfile => 'Editar perfil';

  @override
  String get profileCreatorAnalytics => 'Analíticas del creador';

  @override
  String get profileShareProfile => 'Compartir perfil';

  @override
  String get profileCopyPublicKey => 'Copiar clave pública (npub)';

  @override
  String get profileGetEmbedCode => 'Obtener código de inserción';

  @override
  String get profilePublicKeyCopied => 'Clave pública copiada al portapapeles';

  @override
  String get profileEmbedCodeCopied =>
      'Código de inserción copiado al portapapeles';

  @override
  String get profileRefreshTooltip => 'Actualizar';

  @override
  String get profileRefreshSemanticLabel => 'Actualizar perfil';

  @override
  String get profileMoreTooltip => 'Más';

  @override
  String get profileMoreSemanticLabel => 'Más opciones';

  @override
  String get profileFollowingLabel => 'Siguiendo';

  @override
  String get profileFollowLabel => 'Seguir';

  @override
  String get profileBlockedLabel => 'Bloqueado';

  @override
  String get profileFollowersLabel => 'Seguidores';

  @override
  String get profileFollowingStatLabel => 'Siguiendo';

  @override
  String get profileVideosLabel => 'Videos';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count usuarios';
  }

  @override
  String profileBlockTitle(String displayName) {
    return '¿Bloquear a $displayName?';
  }

  @override
  String get profileBlockExplanation => 'Cuando bloqueás a alguien:';

  @override
  String get profileBlockBulletHidePosts =>
      'Sus publicaciones no van a aparecer en tus feeds.';

  @override
  String get profileBlockBulletCantView =>
      'No va a poder ver tu perfil, seguirte, ni ver tus publicaciones.';

  @override
  String get profileBlockBulletNoNotify => 'No le vamos a avisar del bloqueo.';

  @override
  String get profileBlockBulletYouCanView =>
      'Vos vas a poder seguir viendo su perfil.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Bloquear a $displayName';
  }

  @override
  String get profileCancelButton => 'Cancelar';

  @override
  String get profileLearnMore => 'Conocé más';

  @override
  String profileUnblockTitle(String displayName) {
    return '¿Desbloquear a $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'Cuando desbloqueás a alguien:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Sus publicaciones van a aparecer en tus feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'Va a poder ver tu perfil, seguirte y ver tus publicaciones.';

  @override
  String get profileUnblockBulletNoNotify => 'No le vamos a avisar del cambio.';

  @override
  String get profileLearnMoreAt => 'Conocé más en ';

  @override
  String get profileUnblockButton => 'Desbloquear';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Dejar de seguir a $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Bloquear a $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Desbloquear a $displayName';
  }

  @override
  String get profileUserBlockedTitle => 'Usuario bloqueado';

  @override
  String get profileUserBlockedContent =>
      'No vas a ver contenido de esta persona en tus feeds.';

  @override
  String get profileUserBlockedUnblockHint =>
      'Podés desbloquearla cuando quieras desde su perfil o en Ajustes > Seguridad.';

  @override
  String get profileCloseButton => 'Cerrar';

  @override
  String get profileNoCollabsTitle => 'Todavía no hay colabs';

  @override
  String get profileCollabsOwnEmpty =>
      'Los videos en los que colabores van a aparecer acá';

  @override
  String get profileCollabsOtherEmpty =>
      'Los videos en los que colabore van a aparecer acá';

  @override
  String get profileErrorLoadingCollabs =>
      'Error al cargar los videos en colab';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'Todavía no hay comentarios';

  @override
  String get profileNoCommentsOtherTitle => 'Sin comentarios';

  @override
  String get profileCommentsOwnEmpty =>
      'Tus comentarios y respuestas van a aparecer acá';

  @override
  String get profileCommentsOtherEmpty =>
      'Sus comentarios y respuestas van a aparecer acá';

  @override
  String get profileErrorLoadingComments => 'Error al cargar los comentarios';

  @override
  String get profileVideoRepliesSection => 'Respuestas en video';

  @override
  String get profileCommentsSection => 'Comentarios';

  @override
  String get profileEditLabel => 'Editar';

  @override
  String get profileLibraryLabel => 'Biblioteca';

  @override
  String get profileNoLikedVideosTitle => 'Todavía no hay videos que te gusten';

  @override
  String get profileLikedOwnEmpty =>
      'Los videos que te gusten van a aparecer acá';

  @override
  String get profileLikedOtherEmpty =>
      'Los videos que le gusten van a aparecer acá';

  @override
  String get profileErrorLoadingLiked =>
      'Error al cargar los videos con me gusta';

  @override
  String get profileNoRepostsTitle => 'Todavía no hay reposts';

  @override
  String get profileRepostsOwnEmpty =>
      'Los videos que republiques van a aparecer acá';

  @override
  String get profileRepostsOtherEmpty =>
      'Los videos que republique van a aparecer acá';

  @override
  String get profileErrorLoadingReposts =>
      'Error al cargar los videos reposteados';

  @override
  String get profileLoadingTitle => 'Cargando perfil...';

  @override
  String get profileLoadingSubtitle => 'Esto puede tardar unos segundos';

  @override
  String get profileLoadingVideos => 'Cargando videos...';

  @override
  String get profileNoVideosTitle => 'Todavía no hay videos';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Compartí tu primer video para verlo acá';

  @override
  String get profileNoVideosOtherSubtitle =>
      'Este usuario todavía no compartió ningún video';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Miniatura de video $number';
  }

  @override
  String get profileShowMore => 'Ver más';

  @override
  String get profileShowLess => 'Ver menos';

  @override
  String get profileCompleteYourProfile => 'Completá tu perfil';

  @override
  String get profileCompleteSubtitle =>
      'Agregá tu nombre, bio y foto para arrancar';

  @override
  String get profileSetUpButton => 'Configurar';

  @override
  String get profileVerifyingEmail => 'Verificando el email...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Revisá $email por el link de verificación';
  }

  @override
  String get profileWaitingForVerification =>
      'Esperando la verificación del email';

  @override
  String get profileVerificationFailed => 'Falló la verificación';

  @override
  String get profilePleaseTryAgain => 'Intentalo de nuevo';

  @override
  String get profileSecureYourAccount => 'Asegurá tu cuenta';

  @override
  String get profileSecureSubtitle =>
      'Agregá email y contraseña para recuperar tu cuenta en cualquier dispositivo';

  @override
  String get profileRetryButton => 'Reintentar';

  @override
  String get profileRegisterButton => 'Registrarse';

  @override
  String get profileSessionExpired => 'Sesión vencida';

  @override
  String get profileSignInToRestore =>
      'Iniciá sesión de nuevo para recuperar el acceso total';

  @override
  String get profileSignInButton => 'Iniciar sesión';

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
  String get profileDismissTooltip => 'Descartar';

  @override
  String get profileLinkCopied => 'Link del perfil copiado';

  @override
  String get profileSetupEditProfileTitle => 'Editar perfil';

  @override
  String get profileSetupBackLabel => 'Atrás';

  @override
  String get profileSetupAboutNostr => 'Sobre Nostr';

  @override
  String get profileSetupProfilePublished => '¡Perfil publicado con éxito!';

  @override
  String get profileSetupCreateNewProfile => '¿Crear un perfil nuevo?';

  @override
  String get profileSetupNoExistingProfile =>
      'No encontramos un perfil existente en tus relays. Al publicar vas a crear un perfil nuevo. ¿Continuamos?';

  @override
  String get profileSetupPublishButton => 'Publicar';

  @override
  String get profileSetupUsernameTaken =>
      'Ese nombre de usuario se acaba de ocupar. Elegí otro.';

  @override
  String get profileSetupClaimFailed =>
      'No se pudo reservar el nombre de usuario. Probá de nuevo.';

  @override
  String get profileSetupPublishFailed =>
      'No se pudo publicar el perfil. Probá de nuevo.';

  @override
  String get profileSetupDisplayNameLabel => 'Nombre a mostrar';

  @override
  String get profileSetupDisplayNameHint => '¿Cómo querés que te conozcan?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Cualquier nombre o apodo que quieras. No tiene que ser único.';

  @override
  String get profileSetupDisplayNameRequired => 'Ingresá un nombre a mostrar';

  @override
  String get profileSetupBioLabel => 'Bio (opcional)';

  @override
  String get profileSetupBioHint => 'Contale algo sobre vos...';

  @override
  String get profileSetupPublicKeyLabel => 'Clave pública (npub)';

  @override
  String get profileSetupUsernameLabel => 'Nombre de usuario (opcional)';

  @override
  String get profileSetupUsernameHint => 'nombredeusuario';

  @override
  String get profileSetupUsernameHelper => 'Tu identidad única en Divine';

  @override
  String get profileSetupProfileColorLabel => 'Color de perfil (opcional)';

  @override
  String get profileSetupSaveButton => 'Guardar';

  @override
  String get profileSetupSavingButton => 'Guardando...';

  @override
  String get profileSetupImageUrlTitle => 'Agregar URL de imagen';

  @override
  String get profileSetupPictureUploaded => '¡Foto de perfil subida con éxito!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Falló la selección de imagen. Pegá una URL de imagen abajo.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Falló el acceso a la cámara: $error';
  }

  @override
  String get profileSetupGotItButton => 'Entendido';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'No se pudo subir la imagen: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'Error de red: revisá tu conexión a internet y probá de nuevo.';

  @override
  String get profileSetupUploadAuthError =>
      'Error de autenticación: cerrá sesión y volvé a iniciarla.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'Archivo demasiado grande: elegí una imagen más chica (máx 10MB).';

  @override
  String get profileSetupUsernameChecking => 'Verificando disponibilidad...';

  @override
  String get profileSetupUsernameAvailable => '¡Nombre de usuario disponible!';

  @override
  String get profileSetupUsernameTakenIndicator =>
      'Ese nombre de usuario ya está ocupado';

  @override
  String get profileSetupUsernameReserved =>
      'Ese nombre de usuario está reservado';

  @override
  String get profileSetupContactSupport => 'Contactar a soporte';

  @override
  String get profileSetupCheckAgain => 'Verificar de nuevo';

  @override
  String get profileSetupUsernameBurned =>
      'Este nombre de usuario ya no está disponible';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Solo se permiten letras, números y guiones';

  @override
  String get profileSetupUsernameInvalidLength =>
      'El nombre de usuario tiene que tener entre 3 y 20 caracteres';

  @override
  String get profileSetupUsernameNetworkError =>
      'No pudimos verificar la disponibilidad. Probá de nuevo.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Formato de nombre de usuario inválido';

  @override
  String get profileSetupUsernameCheckFailed =>
      'No se pudo verificar la disponibilidad';

  @override
  String get profileSetupUsernameReservedTitle => 'Nombre de usuario reservado';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'El nombre $username está reservado. Contanos por qué debería ser tuyo.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'Ej: es mi marca, nombre artístico, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      '¿Ya hablaste con soporte? Tocá \"Verificar de nuevo\" para ver si te lo liberaron.';

  @override
  String get profileSetupSupportRequestSent =>
      '¡Pedido enviado! Te vamos a responder pronto.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'No se pudo abrir el email. Escribinos a: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Enviar pedido';

  @override
  String get profileSetupPickColorTitle => 'Elegí un color';

  @override
  String get profileSetupSelectButton => 'Seleccionar';

  @override
  String get profileSetupUseOwnNip05 => 'Usá tu propia dirección NIP-05';

  @override
  String get profileSetupNip05AddressLabel => 'Dirección NIP-05';

  @override
  String get profileSetupProfilePicturePreview =>
      'Vista previa de la foto de perfil';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine está construida sobre Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' un protocolo abierto y resistente a la censura que permite comunicarse online sin depender de una sola empresa o plataforma. ';

  @override
  String get nostrInfoIntroIdentity =>
      'Cuando te registrás en Divine, obtenés una nueva identidad en Nostr.';

  @override
  String get nostrInfoOwnership =>
      'Nostr te permite ser dueño de tu contenido, tu identidad y tu red social, y usarlos en muchas apps. El resultado: más opciones, menos lock-in, y un internet social más sano y resiliente.';

  @override
  String get nostrInfoLingo => 'Jerga de Nostr:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Tu dirección pública en Nostr. Es seguro compartirla y permite que otras personas te encuentren, te sigan o te manden mensajes en cualquier app de Nostr.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Tu clave privada y prueba de propiedad. Te da el control total de tu identidad en Nostr, así que ';

  @override
  String get nostrInfoNsecWarning => '¡siempre mantenela en secreto!';

  @override
  String get nostrInfoUsernameLabel => 'Nombre de usuario de Nostr:';

  @override
  String get nostrInfoUsernameDescription =>
      ' Un nombre fácil de leer (como @nombre.divine.video) que apunta a tu npub. Hace que tu identidad en Nostr sea más fácil de reconocer y verificar, parecido a una dirección de email.';

  @override
  String get nostrInfoLearnMoreAt => 'Conocé más en ';

  @override
  String get nostrInfoGotIt => '¡Entendido!';

  @override
  String get profileTabRefreshTooltip => 'Actualizar';

  @override
  String get videoGridRefreshLabel => 'Buscando más videos';

  @override
  String get videoGridOptionsTitle => 'Opciones del video';

  @override
  String get videoGridEditVideo => 'Editar video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Actualizá título, descripción y hashtags';

  @override
  String get videoGridDeleteVideo => 'Eliminar video';

  @override
  String get videoGridDeleteVideoSubtitle => 'Sacá este contenido para siempre';

  @override
  String get videoGridDeleteConfirmTitle => 'Eliminar video';

  @override
  String get videoGridDeleteConfirmMessage =>
      '¿Seguro que querés eliminar este video?';

  @override
  String get videoGridDeleteConfirmNote =>
      'Esto envía un pedido de eliminación (NIP-09) a todos los relays. Algunos relays todavía pueden mantener el contenido.';

  @override
  String get videoGridDeleteCancel => 'Cancelar';

  @override
  String get videoGridDeleteConfirm => 'Eliminar';

  @override
  String get videoGridDeletingContent => 'Eliminando contenido...';

  @override
  String get videoGridDeleteSuccess =>
      'Pedido de eliminación enviado con éxito';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'No se pudo eliminar el contenido: $error';
  }

  @override
  String get exploreTabClassics => 'Clásicos';

  @override
  String get exploreTabNew => 'Nuevos';

  @override
  String get exploreTabPopular => 'Populares';

  @override
  String get exploreTabCategories => 'Categorías';

  @override
  String get exploreTabForYou => 'Para vos';

  @override
  String get exploreTabLists => 'Listas';

  @override
  String get exploreTabIntegratedApps => 'Apps integradas';

  @override
  String get exploreNoVideosAvailable => 'No hay videos disponibles';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get exploreDiscoverLists => 'Descubrir listas';

  @override
  String get exploreAboutLists => 'Sobre las listas';

  @override
  String get exploreAboutListsDescription =>
      'Las listas te ayudan a organizar y curar contenido en Divine de dos formas:';

  @override
  String get explorePeopleLists => 'Listas de personas';

  @override
  String get explorePeopleListsDescription =>
      'Seguí grupos de creadores y mirá sus últimos videos';

  @override
  String get exploreVideoLists => 'Listas de videos';

  @override
  String get exploreVideoListsDescription =>
      'Armá playlists de tus videos favoritos para verlos después';

  @override
  String get exploreMyLists => 'Mis listas';

  @override
  String get exploreSubscribedLists => 'Listas suscritas';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Error al cargar las listas: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count videos nuevos',
      one: '1 video nuevo',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos nuevos',
      one: 'video nuevo',
    );
    return 'Cargar $count $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Cargando video...';

  @override
  String get videoPlayerPlayVideo => 'Reproducir video';

  @override
  String get videoPlayerMute => 'Silenciar video';

  @override
  String get videoPlayerUnmute => 'Activar sonido del video';

  @override
  String get videoPlayerEditVideo => 'Editar video';

  @override
  String get videoPlayerEditVideoTooltip => 'Editar video';

  @override
  String get contentWarningLabel => 'Advertencia de contenido';

  @override
  String get contentWarningNudity => 'Desnudez';

  @override
  String get contentWarningSexualContent => 'Contenido sexual';

  @override
  String get contentWarningPornography => 'Pornografía';

  @override
  String get contentWarningGraphicMedia => 'Contenido gráfico';

  @override
  String get contentWarningViolence => 'Violencia';

  @override
  String get contentWarningSelfHarm => 'Autolesiones';

  @override
  String get contentWarningDrugUse => 'Uso de drogas';

  @override
  String get contentWarningAlcohol => 'Alcohol';

  @override
  String get contentWarningTobacco => 'Tabaco';

  @override
  String get contentWarningGambling => 'Apuestas';

  @override
  String get contentWarningProfanity => 'Lenguaje fuerte';

  @override
  String get contentWarningFlashingLights => 'Luces intermitentes';

  @override
  String get contentWarningAiGenerated => 'Generado por IA';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Contenido sensible';

  @override
  String get contentWarningDescNudity => 'Contiene desnudez o desnudez parcial';

  @override
  String get contentWarningDescSexual => 'Contiene contenido sexual';

  @override
  String get contentWarningDescPorn =>
      'Contiene contenido pornográfico explícito';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contiene imágenes gráficas o perturbadoras';

  @override
  String get contentWarningDescViolence => 'Contiene contenido violento';

  @override
  String get contentWarningDescSelfHarm =>
      'Contiene referencias a autolesiones';

  @override
  String get contentWarningDescDrugs =>
      'Contiene contenido relacionado con drogas';

  @override
  String get contentWarningDescAlcohol =>
      'Contiene contenido relacionado con el alcohol';

  @override
  String get contentWarningDescTobacco =>
      'Contiene contenido relacionado con el tabaco';

  @override
  String get contentWarningDescGambling =>
      'Contiene contenido relacionado con apuestas';

  @override
  String get contentWarningDescProfanity => 'Contiene lenguaje fuerte';

  @override
  String get contentWarningDescFlashingLights =>
      'Contiene luces intermitentes (advertencia de fotosensibilidad)';

  @override
  String get contentWarningDescAiGenerated =>
      'Este contenido fue generado por IA';

  @override
  String get contentWarningDescSpoiler => 'Contiene spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'El creador lo marcó como sensible';

  @override
  String get contentWarningDescDefault => 'El creador marcó este contenido';

  @override
  String get contentWarningDetailsTitle => 'Advertencias de contenido';

  @override
  String get contentWarningDetailsSubtitle =>
      'El creador aplicó estas etiquetas:';

  @override
  String get contentWarningManageFilters => 'Gestionar filtros de contenido';

  @override
  String get contentWarningViewAnyway => 'Ver igual';

  @override
  String get contentWarningHideAllLikeThis =>
      'Ocultar todo el contenido como este';

  @override
  String get contentWarningNoFilterYet =>
      'Todavía no hay un filtro guardado para esta advertencia.';

  @override
  String get contentWarningHiddenConfirmation =>
      'Vamos a ocultar publicaciones como esta de ahora en más.';

  @override
  String get videoErrorNotFound => 'Video no encontrado';

  @override
  String get videoErrorNetwork => 'Error de red';

  @override
  String get videoErrorTimeout => 'Se agotó el tiempo de carga';

  @override
  String get videoErrorFormat =>
      'Error de formato de video\n(Probá de nuevo o usá otro navegador)';

  @override
  String get videoErrorUnsupportedFormat => 'Formato de video no soportado';

  @override
  String get videoErrorPlayback => 'Error de reproducción';

  @override
  String get videoErrorAgeRestricted => 'Contenido con restricción de edad';

  @override
  String get videoErrorVerifyAge => 'Verificar edad';

  @override
  String get videoErrorRetry => 'Reintentar';

  @override
  String get videoErrorContentRestricted => 'Contenido restringido';

  @override
  String get videoErrorContentRestrictedBody =>
      'Este video fue restringido por el relay.';

  @override
  String get videoErrorVerifyAgeBody => 'Verificá tu edad para ver este video.';

  @override
  String get videoErrorSkip => 'Saltar';

  @override
  String get videoErrorVerifyAgeButton => 'Verificar edad';

  @override
  String get videoFollowButtonFollowing => 'Siguiendo';

  @override
  String get videoFollowButtonFollow => 'Seguir';

  @override
  String get audioAttributionOriginalSound => 'Sonido original';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspirado en @$creatorName';
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
      other: '$count colaboradores',
      one: '1 colaborador',
    );
    return '$_temp0. Tocá para ver el perfil.';
  }

  @override
  String get listAttributionFallback => 'Lista';

  @override
  String get shareVideoLabel => 'Compartir video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Publicación compartida con $recipientName';
  }

  @override
  String get shareFailedToSend => 'No se pudo enviar el video';

  @override
  String get shareAddedToBookmarks => 'Agregado a marcadores';

  @override
  String get shareFailedToAddBookmark => 'No se pudo agregar el marcador';

  @override
  String get shareActionFailed => 'Falló la acción';

  @override
  String get shareWithTitle => 'Compartir con';

  @override
  String get shareFindPeople => 'Buscar personas';

  @override
  String get shareFindPeopleMultiline => 'Buscar\npersonas';

  @override
  String get shareSent => 'Enviado';

  @override
  String get shareContactFallback => 'Contacto';

  @override
  String get shareUserFallback => 'Usuario';

  @override
  String shareSendingTo(String name) {
    return 'Enviando a $name';
  }

  @override
  String get shareMessageHint => 'Agregá un mensaje (opcional)...';

  @override
  String get videoActionUnlike => 'Sacar me gusta';

  @override
  String get videoActionLike => 'Dar me gusta';

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
  String get videoActionEnableAutoAdvance => 'Activar avance automático';

  @override
  String get videoActionDisableAutoAdvance => 'Desactivar avance automático';

  @override
  String get videoActionRemoveRepost => 'Quitar repost';

  @override
  String get videoActionRepost => 'Repostear video';

  @override
  String get videoActionViewComments => 'Ver comentarios';

  @override
  String get videoActionMoreOptions => 'Más opciones';

  @override
  String get videoActionHideSubtitles => 'Ocultar subtítulos';

  @override
  String get videoActionShowSubtitles => 'Mostrar subtítulos';

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
      other: 'bucles',
      one: 'bucle',
    );
    return '$compactCount $_temp0';
  }

  @override
  String get metadataBadgeNotDivine => 'No es de Divine';

  @override
  String get metadataBadgeHumanMade => 'Hecho por humanos';

  @override
  String get metadataSoundsLabel => 'Sonidos';

  @override
  String get metadataOriginalSound => 'Sonido original';

  @override
  String get metadataVerificationLabel => 'Verificación';

  @override
  String get metadataDeviceAttestation => 'Atestación de dispositivo';

  @override
  String get metadataProofManifest => 'Manifiesto de prueba';

  @override
  String get metadataCreatorLabel => 'Creador';

  @override
  String get metadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get metadataInspiredByLabel => 'Inspirado en';

  @override
  String get metadataRepostedByLabel => 'Reposteado por';

  @override
  String metadataLoopsLabel(int count) {
    return 'Loops';
  }

  @override
  String get metadataLikesLabel => 'Me gusta';

  @override
  String get metadataCommentsLabel => 'Comentarios';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get devOptionsTitle => 'Opciones de desarrollador';

  @override
  String get devOptionsPageLoadTimes => 'Tiempos de carga de pantallas';

  @override
  String get devOptionsNoPageLoads =>
      'Todavía no se registraron cargas de pantalla.\nNavegá por la app para ver los tiempos.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible: ${visibleMs}ms  |  Datos: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Pantallas más lentas';

  @override
  String get devOptionsVideoPlaybackFormat =>
      'Formato de reproducción de video';

  @override
  String get devOptionsSwitchEnvironmentTitle => '¿Cambiar de entorno?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return '¿Cambiar a $envName?\n\nEsto va a limpiar la caché de videos y a reconectarse al nuevo relay.';
  }

  @override
  String get devOptionsCancel => 'Cancelar';

  @override
  String get devOptionsSwitch => 'Cambiar';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Cambiado a $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Cambiado a $formatName — caché limpiada';
  }

  @override
  String get featureFlagTitle => 'Feature flags';

  @override
  String get featureFlagResetAllTooltip =>
      'Restablecer todas las flags a los valores predeterminados';

  @override
  String get featureFlagResetToDefault => 'Restablecer al valor predeterminado';

  @override
  String get featureFlagAppRecovery => 'Recuperación de la app';

  @override
  String get featureFlagAppRecoveryDescription =>
      'Si la app se está cerrando o anda rara, probá limpiar la caché.';

  @override
  String get featureFlagClearAllCache => 'Limpiar toda la caché';

  @override
  String get featureFlagCacheInfo => 'Info de la caché';

  @override
  String get featureFlagClearCacheTitle => '¿Limpiar toda la caché?';

  @override
  String get featureFlagClearCacheMessage =>
      'Esto va a limpiar todos los datos cacheados, incluyendo:\n• Notificaciones\n• Perfiles de usuario\n• Marcadores\n• Archivos temporales\n\nVas a tener que iniciar sesión de nuevo. ¿Continuamos?';

  @override
  String get featureFlagClearCache => 'Limpiar caché';

  @override
  String get featureFlagClearingCache => 'Limpiando la caché...';

  @override
  String get featureFlagSuccess => 'Éxito';

  @override
  String get featureFlagError => 'Error';

  @override
  String get featureFlagClearCacheSuccess =>
      'Caché limpiada con éxito. Reiniciá la app.';

  @override
  String get featureFlagClearCacheFailure =>
      'No se pudieron limpiar algunos elementos de la caché. Mirá los logs para más detalles.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Información de la caché';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Tamaño total de la caché: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'La caché incluye:\n• Historial de notificaciones\n• Datos de perfiles\n• Miniaturas de videos\n• Archivos temporales\n• Índices de base de datos';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine es un sistema abierto: vos controlás tus conexiones';

  @override
  String get relaySettingsInfoDescription =>
      'Estos relays distribuyen tu contenido por la red descentralizada de Nostr. Podés agregar o quitar relays cuando quieras.';

  @override
  String get relaySettingsLearnMoreNostr => 'Conocé más sobre Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Buscá relays públicos en nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'La app no funciona';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine necesita al menos un relay para cargar videos, publicar contenido y sincronizar datos.';

  @override
  String get relaySettingsRestoreDefaultRelay =>
      'Restaurar el relay predeterminado';

  @override
  String get relaySettingsAddCustomRelay => 'Agregar relay personalizado';

  @override
  String get relaySettingsAddRelay => 'Agregar relay';

  @override
  String get relaySettingsRetry => 'Reintentar';

  @override
  String get relaySettingsNoStats => 'Todavía no hay estadísticas disponibles';

  @override
  String get relaySettingsConnection => 'Conexión';

  @override
  String get relaySettingsConnected => 'Conectado';

  @override
  String get relaySettingsDisconnected => 'Desconectado';

  @override
  String get relaySettingsSessionDuration => 'Duración de la sesión';

  @override
  String get relaySettingsLastConnected => 'Última conexión';

  @override
  String get relaySettingsDisconnectedLabel => 'Desconectado';

  @override
  String get relaySettingsReason => 'Motivo';

  @override
  String get relaySettingsActiveSubscriptions => 'Suscripciones activas';

  @override
  String get relaySettingsTotalSubscriptions => 'Suscripciones totales';

  @override
  String get relaySettingsEventsReceived => 'Eventos recibidos';

  @override
  String get relaySettingsEventsSent => 'Eventos enviados';

  @override
  String get relaySettingsRequestsThisSession => 'Pedidos en esta sesión';

  @override
  String get relaySettingsFailedRequests => 'Pedidos fallidos';

  @override
  String relaySettingsLastError(String error) {
    return 'Último error: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Cargando info del relay...';

  @override
  String get relaySettingsAboutRelay => 'Sobre el relay';

  @override
  String get relaySettingsSupportedNips => 'NIPs soportados';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'Ver sitio web';

  @override
  String get relaySettingsRemoveRelayTitle => '¿Quitar relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return '¿Seguro que querés quitar este relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Cancelar';

  @override
  String get relaySettingsRemove => 'Quitar';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Relay quitado: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'No se pudo quitar el relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forzando la reconexión al relay...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return '¡Conectado a $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'No se pudo conectar a los relays. Revisá tu conexión de red.';

  @override
  String get relaySettingsAddRelayTitle => 'Agregar relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Ingresá la URL WebSocket del relay que querés agregar:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Mirá relays públicos en nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Agregar';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Relay agregado: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'No se pudo agregar el relay. Revisá la URL y probá de nuevo.';

  @override
  String get relaySettingsInvalidUrl =>
      'La URL del relay tiene que empezar con wss:// o ws://';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Relay predeterminado restaurado: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'No se pudo restaurar el relay predeterminado. Revisá tu conexión de red.';

  @override
  String get relaySettingsCouldNotOpenBrowser =>
      'No se pudo abrir el navegador';

  @override
  String get relaySettingsFailedToOpenLink => 'No se pudo abrir el link';

  @override
  String get relayDiagnosticTitle => 'Diagnóstico de relays';

  @override
  String get relayDiagnosticRefreshTooltip => 'Actualizar diagnóstico';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Última actualización: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Estado del relay';

  @override
  String get relayDiagnosticInitialized => 'Inicializado';

  @override
  String get relayDiagnosticReady => 'Listo';

  @override
  String get relayDiagnosticNotInitialized => 'No inicializado';

  @override
  String get relayDiagnosticDatabaseEvents => 'Eventos en la base de datos';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Suscripciones activas';

  @override
  String get relayDiagnosticExternalRelays => 'Relays externos';

  @override
  String get relayDiagnosticConfigured => 'Configurados';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Conectados';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Eventos de video';

  @override
  String get relayDiagnosticHomeFeed => 'Feed principal';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count videos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Descubrimiento';

  @override
  String get relayDiagnosticLoading => 'Cargando';

  @override
  String get relayDiagnosticYes => 'Sí';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Probar consulta directa';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Conectividad de red';

  @override
  String get relayDiagnosticRunNetworkTest => 'Ejecutar test de red';

  @override
  String get relayDiagnosticBlossomServer => 'Servidor Blossom';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Probar todos los endpoints';

  @override
  String get relayDiagnosticStatus => 'Estado';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'API FunnelCake';

  @override
  String get relayDiagnosticBaseUrl => 'URL base';

  @override
  String get relayDiagnosticSummary => 'Resumen';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (promedio ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Volver a probar todo';

  @override
  String get relayDiagnosticRetrying => 'Reintentando...';

  @override
  String get relayDiagnosticRetryConnection => 'Reintentar conexión';

  @override
  String get relayDiagnosticTroubleshooting => 'Solución de problemas';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Estado verde = conectado y funcionando\n• Estado rojo = falló la conexión\n• Si falla el test de red, revisá la conexión a internet\n• Si los relays están configurados pero no conectados, tocá \"Reintentar conexión\"\n• Sacá una captura de esta pantalla para debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      '¡Todos los endpoints REST están bien!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Algunos endpoints REST fallaron: ver los detalles arriba';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Se encontraron $count eventos de video en la base de datos';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Falló la consulta: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return '¡Conectado a $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'No se pudo conectar a ningún relay';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Falló el reintento de conexión: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated => 'Conectado y autenticado';

  @override
  String get relayDiagnosticConnectedOnly => 'Conectado';

  @override
  String get relayDiagnosticNotConnected => 'No conectado';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'No hay relays configurados';

  @override
  String get relayDiagnosticFailed => 'Falló';

  @override
  String get notificationSettingsTitle => 'Notificaciones';

  @override
  String get notificationSettingsResetTooltip =>
      'Restablecer a valores predeterminados';

  @override
  String get notificationSettingsTypes => 'Tipos de notificación';

  @override
  String get notificationSettingsLikes => 'Me gusta';

  @override
  String get notificationSettingsLikesSubtitle =>
      'Cuando alguien le da me gusta a tus videos';

  @override
  String get notificationSettingsComments => 'Comentarios';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'Cuando alguien comenta tus videos';

  @override
  String get notificationSettingsFollows => 'Seguidores';

  @override
  String get notificationSettingsFollowsSubtitle =>
      'Cuando alguien empieza a seguirte';

  @override
  String get notificationSettingsMentions => 'Menciones';

  @override
  String get notificationSettingsMentionsSubtitle => 'Cuando te mencionan';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'Cuando alguien repostea tus videos';

  @override
  String get notificationSettingsSystem => 'Sistema';

  @override
  String get notificationSettingsSystemSubtitle =>
      'Actualizaciones de la app y mensajes del sistema';

  @override
  String get notificationSettingsPushNotificationsSection =>
      'Notificaciones push';

  @override
  String get notificationSettingsPushNotifications => 'Notificaciones push';

  @override
  String get notificationSettingsPushNotificationsSubtitle =>
      'Recibí notificaciones con la app cerrada';

  @override
  String get notificationSettingsSound => 'Sonido';

  @override
  String get notificationSettingsSoundSubtitle =>
      'Reproducir sonido en las notificaciones';

  @override
  String get notificationSettingsVibration => 'Vibración';

  @override
  String get notificationSettingsVibrationSubtitle =>
      'Vibrar en las notificaciones';

  @override
  String get notificationSettingsActions => 'Acciones';

  @override
  String get notificationSettingsMarkAllAsRead => 'Marcar todas como leídas';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Marcá todas las notificaciones como leídas';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'Todas las notificaciones marcadas como leídas';

  @override
  String get notificationSettingsResetToDefaults =>
      'Ajustes restablecidos a los valores predeterminados';

  @override
  String get notificationSettingsAbout => 'Sobre las notificaciones';

  @override
  String get notificationSettingsAboutDescription =>
      'Las notificaciones funcionan con el protocolo Nostr. Las actualizaciones en tiempo real dependen de tu conexión con los relays de Nostr. Algunas notificaciones pueden demorarse.';

  @override
  String get safetySettingsTitle => 'Seguridad y privacidad';

  @override
  String get safetySettingsLabel => 'AJUSTES';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Mostrar solo videos alojados en Divine';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Ocultá videos alojados en otros hosts de medios';

  @override
  String get safetySettingsModeration => 'MODERACIÓN';

  @override
  String get safetySettingsBlockedUsers => 'USUARIOS BLOQUEADOS';

  @override
  String get safetySettingsAgeVerification => 'VERIFICACIÓN DE EDAD';

  @override
  String get safetySettingsAgeConfirmation =>
      'Confirmo que tengo 18 años o más';

  @override
  String get safetySettingsAgeRequired =>
      'Necesario para ver contenido para adultos';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Servicio oficial de moderación (activado por defecto)';

  @override
  String get safetySettingsPeopleIFollow => 'Personas que sigo';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Suscribite a las etiquetas de las personas que seguís';

  @override
  String get safetySettingsAddCustomLabeler =>
      'Agregar etiquetador personalizado';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Ingresá un npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle =>
      'Agregar etiquetador personalizado';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle =>
      'Ingresá una dirección npub';

  @override
  String get safetySettingsNoBlockedUsers => 'No hay usuarios bloqueados';

  @override
  String get safetySettingsUnblock => 'Desbloquear';

  @override
  String get safetySettingsUserUnblocked => 'Usuario desbloqueado';

  @override
  String get safetySettingsCancel => 'Cancelar';

  @override
  String get safetySettingsAdd => 'Agregar';

  @override
  String get analyticsTitle => 'Analíticas del creador';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnóstico';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Alternar diagnóstico';

  @override
  String get analyticsRetry => 'Reintentar';

  @override
  String get analyticsUnableToLoad => 'No se pueden cargar las analíticas.';

  @override
  String get analyticsSignInRequired =>
      'Iniciá sesión para ver las analíticas del creador.';

  @override
  String get analyticsViewDataUnavailable =>
      'Las visualizaciones no están disponibles en el relay para estas publicaciones. Los me gusta, comentarios y reposts siguen siendo precisos.';

  @override
  String get analyticsViewDataTitle => 'Datos de visualizaciones';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Actualizado $time • Los puntajes usan me gusta, comentarios, reposts y visualizaciones/loops de Funnelcake cuando están disponibles.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Visualizaciones';

  @override
  String get analyticsInteractions => 'Interacciones';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Seguidores';

  @override
  String get analyticsAvgPerPost => 'Prom/post';

  @override
  String get analyticsInteractionMix => 'Mezcla de interacciones';

  @override
  String get analyticsLikes => 'Me gusta';

  @override
  String get analyticsComments => 'Comentarios';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Destacados de rendimiento';

  @override
  String get analyticsMostViewed => 'Más visto';

  @override
  String get analyticsMostDiscussed => 'Más comentado';

  @override
  String get analyticsMostReposted => 'Más reposteado';

  @override
  String get analyticsNoVideosYet => 'Todavía no hay videos';

  @override
  String get analyticsViewDataUnavailableShort =>
      'Datos de visualizaciones no disponibles';

  @override
  String analyticsViewsCount(String count) {
    return '$count visualizaciones';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count comentarios';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Contenido top';

  @override
  String get analyticsPublishPrompt =>
      'Publicá algunos videos para ver los rankings.';

  @override
  String get analyticsEngagementRateExplainer =>
      'El % del lado derecho = tasa de engagement (interacciones dividido visualizaciones).';

  @override
  String get analyticsEngagementRateNoViews =>
      'La tasa de engagement necesita datos de visualizaciones; los valores aparecen como N/A hasta que haya datos.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'visualizaciones no disponibles';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interacciones';
  }

  @override
  String get analyticsPostAnalytics => 'Analíticas de la publicación';

  @override
  String get analyticsOpenPost => 'Abrir publicación';

  @override
  String get analyticsRecentDailyInteractions =>
      'Interacciones diarias recientes';

  @override
  String get analyticsNoActivityYet =>
      'Todavía no hay actividad en este rango.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interacciones = me gusta + comentarios + reposts por fecha de publicación.';

  @override
  String get analyticsDailyBarExplainer =>
      'El largo de la barra es relativo a tu mejor día en esta ventana.';

  @override
  String get analyticsAudienceSnapshot => 'Instantánea de audiencia';

  @override
  String analyticsFollowersCount(String count) {
    return 'Seguidores: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Siguiendo: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Los desgloses de fuente/geografía/horario de audiencia van a aparecer cuando Funnelcake sume esos endpoints.';

  @override
  String get analyticsRetention => 'Retención';

  @override
  String get analyticsRetentionWithViews =>
      'La curva de retención y el desglose de tiempo de visualización van a aparecer cuando Funnelcake devuelva datos por segundo/intervalo.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Los datos de retención no están disponibles hasta que Funnelcake devuelva analíticas de visualizaciones y tiempo de visualización.';

  @override
  String get analyticsDiagnostics => 'Diagnóstico';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Videos totales: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'Con visualizaciones: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Sin visualizaciones: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hidratado (masivo): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hidratado (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Fuentes: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Usar datos de prueba';

  @override
  String get analyticsNa => 'N/D';

  @override
  String get authCreateNewAccount => 'Crear una cuenta nueva en Divine';

  @override
  String get authSignInDifferentAccount => 'Iniciar sesión con otra cuenta';

  @override
  String get authSignBackIn => 'Volver a iniciar sesión';

  @override
  String get authTermsPrefix =>
      'Al seleccionar una opción, confirmás que tenés al menos 16 años y aceptás los ';

  @override
  String get authTermsOfService => 'Términos del Servicio';

  @override
  String get authPrivacyPolicy => 'Política de Privacidad';

  @override
  String get authTermsAnd => ', y los ';

  @override
  String get authSafetyStandards => 'Estándares de Seguridad';

  @override
  String get authAmberNotInstalled => 'La app Amber no está instalada';

  @override
  String get authAmberConnectionFailed => 'No se pudo conectar con Amber';

  @override
  String get authPasswordResetSent =>
      'Si existe una cuenta con ese email, te enviamos un link para restablecer la contraseña.';

  @override
  String get authSignInTitle => 'Iniciar sesión';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Contraseña';

  @override
  String get authForgotPassword => '¿Olvidaste tu contraseña?';

  @override
  String get authImportNostrKey => 'Importar clave de Nostr';

  @override
  String get authConnectSignerApp => 'Conectar con una app firmante';

  @override
  String get authSignInWithAmber => 'Iniciar sesión con Amber';

  @override
  String get authSignInOptionsTitle => 'Opciones para iniciar sesión';

  @override
  String get authInfoEmailPasswordTitle => 'Email y contraseña';

  @override
  String get authInfoEmailPasswordDescription =>
      'Iniciá sesión con tu cuenta de Divine. Si te registraste con email y contraseña, usalos acá.';

  @override
  String get authInfoImportNostrKeyDescription =>
      '¿Ya tenés una identidad en Nostr? Importá tu clave privada nsec desde otro cliente.';

  @override
  String get authInfoSignerAppTitle => 'App firmante';

  @override
  String get authInfoSignerAppDescription =>
      'Conectate usando un firmante remoto compatible con NIP-46 como nsecBunker para mayor seguridad de tus claves.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Usá la app firmante Amber en Android para manejar tus claves de Nostr de forma segura.';

  @override
  String get authCreateAccountTitle => 'Crear cuenta';

  @override
  String get authBackToInviteCode => 'Volver al código de invitación';

  @override
  String get authUseDivineNoBackup => 'Usar Divine sin respaldo';

  @override
  String get authSkipConfirmTitle => 'Una última cosa...';

  @override
  String get authSkipConfirmKeyCreated =>
      '¡Estás adentro! Vamos a crear una clave segura para tu cuenta de Divine.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Sin un email, tu clave es la única forma que tiene Divine de saber que esta cuenta es tuya.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'Podés acceder a tu clave dentro de la app, pero si no sos muy técnico, te recomendamos agregar un email y contraseña ahora. Eso hace más fácil iniciar sesión y recuperar tu cuenta si perdés o reseteás este dispositivo.';

  @override
  String get authAddEmailPassword => 'Agregar email y contraseña';

  @override
  String get authUseThisDeviceOnly => 'Usar solo este dispositivo';

  @override
  String get authCompleteRegistration => 'Completá tu registro';

  @override
  String get authVerifying => 'Verificando...';

  @override
  String get authVerificationLinkSent =>
      'Te mandamos un link de verificación a:';

  @override
  String get authClickVerificationLink =>
      'Tocá el link en tu email para\ncompletar el registro.';

  @override
  String get authPleaseWaitVerifying =>
      'Esperá mientras verificamos tu email...';

  @override
  String get authWaitingForVerification => 'Esperando la verificación';

  @override
  String get authOpenEmailApp => 'Abrir la app de email';

  @override
  String get authWelcomeToDivine => '¡Bienvenido a Divine!';

  @override
  String get authEmailVerified => 'Tu email fue verificado.';

  @override
  String get authSigningYouIn => 'Iniciando sesión';

  @override
  String get authErrorTitle => 'Uy.';

  @override
  String get authVerificationFailed =>
      'No pudimos verificar tu email.\nProbá de nuevo.';

  @override
  String get authStartOver => 'Empezar de nuevo';

  @override
  String get authEmailVerifiedLogin =>
      '¡Email verificado! Iniciá sesión para continuar.';

  @override
  String get authVerificationLinkExpired =>
      'Este link de verificación ya no es válido.';

  @override
  String get authVerificationConnectionError =>
      'No se pudo verificar el email. Revisá tu conexión y probá de nuevo.';

  @override
  String get authWaitlistConfirmTitle => '¡Estás adentro!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'Te vamos a mandar novedades a $email.\nCuando haya más códigos de invitación disponibles, te los mandamos.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'El acceso por invitación está temporalmente no disponible.';

  @override
  String get authInviteUnavailableBody =>
      'Probá de nuevo en un rato, o contactá a soporte si necesitás ayuda para entrar.';

  @override
  String get authTryAgain => 'Probar de nuevo';

  @override
  String get authContactSupport => 'Contactar a soporte';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'No se pudo abrir $email';
  }

  @override
  String get authAddInviteCode => 'Agregá tu código de invitación';

  @override
  String get authInviteCodeLabel => 'Código de invitación';

  @override
  String get authEnterYourCode => 'Ingresá tu código';

  @override
  String get authNext => 'Siguiente';

  @override
  String get authJoinWaitlist => 'Unirme a la lista de espera';

  @override
  String get authJoinWaitlistTitle => 'Unite a la lista de espera';

  @override
  String get authJoinWaitlistDescription =>
      'Dejanos tu email y te mandamos novedades cuando haya cupos.';

  @override
  String get authInviteAccessHelp => 'Ayuda con el acceso por invitación';

  @override
  String get authGeneratingConnection => 'Generando conexión...';

  @override
  String get authConnectedAuthenticating => '¡Conectado! Autenticando...';

  @override
  String get authConnectionTimedOut => 'Se agotó el tiempo de conexión';

  @override
  String get authApproveConnection =>
      'Asegurate de haber aprobado la conexión en tu app firmante.';

  @override
  String get authConnectionCancelled => 'Conexión cancelada';

  @override
  String get authConnectionCancelledMessage => 'La conexión fue cancelada.';

  @override
  String get authConnectionFailed => 'Falló la conexión';

  @override
  String get authUnknownError => 'Ocurrió un error desconocido.';

  @override
  String get authUrlCopied => 'URL copiada al portapapeles';

  @override
  String get authConnectToDivine => 'Conectar con Divine';

  @override
  String get authPasteBunkerUrl => 'Pegá la URL bunker://';

  @override
  String get authBunkerUrlHint => 'URL bunker://';

  @override
  String get authInvalidBunkerUrl =>
      'URL bunker inválida. Tiene que empezar con bunker://';

  @override
  String get authScanSignerApp =>
      'Escaneá con tu\napp firmante para conectarte.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Esperando conexión... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copiar URL';

  @override
  String get authShare => 'Compartir';

  @override
  String get authAddBunker => 'Agregar bunker';

  @override
  String get authCompatibleSignerApps => 'Apps firmantes compatibles';

  @override
  String get authFailedToConnect => 'No se pudo conectar';

  @override
  String get authResetPasswordTitle => 'Restablecer contraseña';

  @override
  String get authResetPasswordSubtitle =>
      'Ingresá tu nueva contraseña. Tiene que tener al menos 8 caracteres.';

  @override
  String get authNewPasswordLabel => 'Nueva contraseña';

  @override
  String get authPasswordTooShort =>
      'La contraseña tiene que tener al menos 8 caracteres';

  @override
  String get authPasswordResetSuccess =>
      'Contraseña restablecida. Iniciá sesión.';

  @override
  String get authPasswordResetFailed =>
      'Falló el restablecimiento de la contraseña';

  @override
  String get authUnexpectedError =>
      'Ocurrió un error inesperado. Probá de nuevo.';

  @override
  String get authUpdatePassword => 'Actualizar contraseña';

  @override
  String get authSecureAccountTitle => 'Asegurá tu cuenta';

  @override
  String get authUnableToAccessKeys =>
      'No se pudo acceder a tus claves. Probá de nuevo.';

  @override
  String get authRegistrationFailed => 'Falló el registro';

  @override
  String get authRegistrationComplete => 'Registro completo. Revisá tu email.';

  @override
  String get authVerificationFailedTitle => 'Falló la verificación';

  @override
  String get authClose => 'Cerrar';

  @override
  String get authAccountSecured => '¡Cuenta asegurada!';

  @override
  String get authAccountLinkedToEmail =>
      'Tu cuenta ahora está vinculada a tu email.';

  @override
  String get authVerifyYourEmail => 'Verificá tu email';

  @override
  String get authClickLinkContinue =>
      'Tocá el link en tu email para completar el registro. Mientras tanto, podés seguir usando la app.';

  @override
  String get authWaitingForVerificationEllipsis =>
      'Esperando la verificación...';

  @override
  String get authContinueToApp => 'Ir a la app';

  @override
  String get authResetPassword => 'Restablecer contraseña';

  @override
  String get authResetPasswordDescription =>
      'Ingresá tu email y te mandamos un link para restablecer la contraseña.';

  @override
  String get authFailedToSendResetEmail =>
      'No se pudo enviar el email de restablecimiento.';

  @override
  String get authUnexpectedErrorShort => 'Ocurrió un error inesperado.';

  @override
  String get authSending => 'Enviando...';

  @override
  String get authSendResetLink => 'Enviar link de restablecimiento';

  @override
  String get authEmailSent => '¡Email enviado!';

  @override
  String authResetLinkSentTo(String email) {
    return 'Te mandamos un link de restablecimiento de contraseña a $email. Tocá el link en tu email para actualizar la contraseña.';
  }

  @override
  String get authSignInButton => 'Iniciar sesión';

  @override
  String get authVerificationErrorTimeout =>
      'Se agotó el tiempo de verificación. Registrate de nuevo.';

  @override
  String get authVerificationErrorMissingCode =>
      'Falló la verificación — falta el código de autorización.';

  @override
  String get authVerificationErrorPollFailed =>
      'Falló la verificación. Probá de nuevo.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Error de red al iniciar sesión. Probá de nuevo.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Falló la verificación. Registrate de nuevo.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Falló el inicio de sesión. Iniciá sesión manualmente.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'Ese código de invitación ya no está disponible. Volvé a tu código, unite a la lista de espera o contactá a soporte.';

  @override
  String get authInviteErrorInvalid =>
      'Ese código de invitación no se puede usar ahora. Volvé a tu código, unite a la lista de espera o contactá a soporte.';

  @override
  String get authInviteErrorTemporary =>
      'No pudimos confirmar tu invitación ahora. Volvé a tu código y probá de nuevo, o contactá a soporte.';

  @override
  String get authInviteErrorUnknown =>
      'No pudimos activar tu invitación. Volvé a tu código, unite a la lista de espera o contactá a soporte.';

  @override
  String get shareSheetSave => 'Guardar';

  @override
  String get shareSheetSaveToGallery => 'Guardar en la galería';

  @override
  String get shareSheetSaveWithWatermark => 'Guardar con marca de agua';

  @override
  String get shareSheetSaveVideo => 'Guardar video';

  @override
  String get shareSheetAddToList => 'Agregar a lista';

  @override
  String get shareSheetCopy => 'Copiar';

  @override
  String get shareSheetShareVia => 'Compartir vía';

  @override
  String get shareSheetReport => 'Reportar';

  @override
  String get shareSheetEventJson => 'JSON del evento';

  @override
  String get shareSheetEventId => 'ID del evento';

  @override
  String get shareSheetMoreActions => 'Más acciones';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Guardado en el carrete';

  @override
  String get watermarkDownloadShare => 'Compartir';

  @override
  String get watermarkDownloadDone => 'Listo';

  @override
  String get watermarkDownloadPhotosAccessNeeded =>
      'Se necesita acceso a Fotos';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'Para guardar videos, permití el acceso a Fotos en Ajustes.';

  @override
  String get watermarkDownloadOpenSettings => 'Abrir Ajustes';

  @override
  String get watermarkDownloadNotNow => 'Ahora no';

  @override
  String get watermarkDownloadFailed => 'Falló la descarga';

  @override
  String get watermarkDownloadDismiss => 'Descartar';

  @override
  String get watermarkDownloadStageDownloading => 'Descargando video';

  @override
  String get watermarkDownloadStageWatermarking => 'Aplicando marca de agua';

  @override
  String get watermarkDownloadStageSaving => 'Guardando en el carrete';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Obteniendo el video de la red...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Aplicando la marca de agua de Divine...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Guardando el video con marca de agua en tu carrete...';

  @override
  String get uploadProgressVideoUpload => 'Subida de video';

  @override
  String get uploadProgressPause => 'Pausar';

  @override
  String get uploadProgressResume => 'Reanudar';

  @override
  String get uploadProgressGoBack => 'Volver';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Reintentar ($count restantes)';
  }

  @override
  String get uploadProgressDelete => 'Eliminar';

  @override
  String uploadProgressDaysAgo(int count) {
    return 'hace ${count}d';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String get uploadProgressJustNow => 'Recién';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Subiendo $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Pausado $percent%';
  }

  @override
  String get badgeExplanationClose => 'Cerrar';

  @override
  String get badgeExplanationOriginalVineArchive => 'Archivo Vine original';

  @override
  String get badgeExplanationCameraProof => 'Prueba de cámara';

  @override
  String get badgeExplanationAuthenticitySignals => 'Señales de autenticidad';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'Este video es un Vine original recuperado del Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Antes de que Vine cerrara en 2017, ArchiveTeam y el Internet Archive trabajaron para preservar millones de Vines para la posteridad. Este contenido es parte de ese esfuerzo histórico de preservación.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Estadísticas originales: $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Conocé más sobre la preservación del archivo de Vine';

  @override
  String get badgeExplanationLearnProofmode =>
      'Conocé más sobre la verificación Proofmode';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Conocé más sobre las señales de autenticidad de Divine';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspeccionar con la herramienta ProofCheck';

  @override
  String get badgeExplanationInspectMedia => 'Inspeccionar detalles del medio';

  @override
  String get badgeExplanationProofmodeVerified =>
      'La autenticidad de este video está verificada con tecnología Proofmode.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'Este video está alojado en Divine y la detección de IA indica que probablemente fue hecho por humanos, pero no incluye datos criptográficos de verificación de cámara.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'La detección de IA indica que este video probablemente fue hecho por humanos, pero no incluye datos criptográficos de verificación de cámara.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'Este video está alojado en Divine, pero todavía no incluye datos criptográficos de verificación de cámara.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'Este video está alojado fuera de Divine y no incluye datos criptográficos de verificación de cámara.';

  @override
  String get badgeExplanationDeviceAttestation => 'Atestación de dispositivo';

  @override
  String get badgeExplanationPgpSignature => 'Firma PGP';

  @override
  String get badgeExplanationC2paCredentials =>
      'Credenciales de contenido C2PA';

  @override
  String get badgeExplanationProofManifest => 'Manifiesto de prueba';

  @override
  String get badgeExplanationAiDetection => 'Detección de IA';

  @override
  String get badgeExplanationAiNotScanned =>
      'Escaneo de IA: todavía no escaneado';

  @override
  String get badgeExplanationNoScanResults =>
      'Todavía no hay resultados de escaneo disponibles.';

  @override
  String get badgeExplanationCheckAiGenerated =>
      'Verificar si es generado por IA';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% de probabilidad de ser generado por IA';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Escaneado por: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verificado por un moderador humano';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platino: atestación de hardware del dispositivo, firmas criptográficas, credenciales de contenido (C2PA) y el escaneo de IA confirma origen humano.';

  @override
  String get badgeExplanationVerificationGold =>
      'Oro: capturado en un dispositivo real con atestación de hardware, firmas criptográficas y credenciales de contenido (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Plata: las firmas criptográficas demuestran que este video no se alteró desde que se grabó.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronce: hay firmas de metadatos básicas.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Plata: el escaneo de IA confirma que este video probablemente fue creado por humanos.';

  @override
  String get badgeExplanationNoVerification =>
      'No hay datos de verificación disponibles para este video.';

  @override
  String get shareMenuTitle => 'Compartir video';

  @override
  String get shareMenuReportAiContent => 'Reportar contenido de IA';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Reporte rápido de contenido sospechoso de ser generado por IA';

  @override
  String get shareMenuReportingAiContent => 'Reportando contenido de IA...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'No se pudo reportar el contenido: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'No se pudo reportar el contenido de IA: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Estado del video';

  @override
  String get shareMenuViewAllLists => 'Ver todas las listas →';

  @override
  String get shareMenuShareWith => 'Compartir con';

  @override
  String get shareMenuShareViaOtherApps => 'Compartir con otras apps';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Compartir con otras apps o copiar el link';

  @override
  String get shareMenuSaveToGallery => 'Guardar en la galería';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Guardar el video original en el carrete';

  @override
  String get shareMenuSaveWithWatermark => 'Guardar con marca de agua';

  @override
  String get shareMenuSaveVideo => 'Guardar video';

  @override
  String get shareMenuDownloadWithWatermark =>
      'Descargar con la marca de agua de Divine';

  @override
  String get shareMenuSaveVideoSubtitle => 'Guardar el video en el carrete';

  @override
  String get shareMenuLists => 'Listas';

  @override
  String get shareMenuAddToList => 'Agregar a lista';

  @override
  String get shareMenuAddToListSubtitle => 'Agregar a tus listas curadas';

  @override
  String get shareMenuCreateNewList => 'Crear lista nueva';

  @override
  String get shareMenuCreateNewListSubtitle =>
      'Arrancá una nueva colección curada';

  @override
  String get shareMenuRemovedFromList => 'Quitado de la lista';

  @override
  String get shareMenuFailedToRemoveFromList => 'No se pudo quitar de la lista';

  @override
  String get shareMenuBookmarks => 'Marcadores';

  @override
  String get shareMenuAddToBookmarks => 'Agregar a marcadores';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Guardar para ver más tarde';

  @override
  String get shareMenuAddToBookmarkSet => 'Agregar a un set de marcadores';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organizá en colecciones';

  @override
  String get shareMenuFollowSets => 'Sets de seguidos';

  @override
  String get shareMenuCreateFollowSet => 'Crear set de seguidos';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Arrancá una colección nueva con este creador';

  @override
  String get shareMenuAddToFollowSet => 'Agregar al set de seguidos';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count sets de seguidos disponibles';
  }

  @override
  String get shareMenuAddedToBookmarks => '¡Agregado a marcadores!';

  @override
  String get shareMenuFailedToAddBookmark => 'No se pudo agregar el marcador';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Se creó la lista \"$name\" y se agregó el video';
  }

  @override
  String get shareMenuManageContent => 'Gestionar contenido';

  @override
  String get shareMenuEditVideo => 'Editar video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Actualizá título, descripción y hashtags';

  @override
  String get shareMenuDeleteVideo => 'Eliminar video';

  @override
  String get shareMenuDeleteVideoSubtitle => 'Sacá este contenido para siempre';

  @override
  String get shareMenuDeleteWarning =>
      'Esto envía un pedido de eliminación (NIP-09) a todos los relays. Algunos relays todavía pueden mantener el contenido.';

  @override
  String get shareMenuVideoInTheseLists => 'El video está en estas listas:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get shareMenuClose => 'Cerrar';

  @override
  String get shareMenuDeleteConfirmation =>
      '¿Seguro que querés eliminar este video?';

  @override
  String get shareMenuCancel => 'Cancelar';

  @override
  String get shareMenuDelete => 'Eliminar';

  @override
  String get shareMenuDeletingContent => 'Eliminando contenido...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'No se pudo eliminar el contenido: $error';
  }

  @override
  String get shareMenuDeleteRequestSent =>
      'Pedido de eliminación enviado con éxito';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'El borrado no está listo todavía. Probá de nuevo en un momento.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'Solo podés borrar tus propios videos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Volvé a iniciar sesión y probá borrar de nuevo.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'No pudimos firmar el pedido de borrado. Probá de nuevo.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'No pudimos borrar este video. Probá de nuevo.';

  @override
  String get shareMenuFollowSetName => 'Nombre del set de seguidos';

  @override
  String get shareMenuFollowSetNameHint =>
      'ej: Creadores de contenido, Músicos, etc.';

  @override
  String get shareMenuDescriptionOptional => 'Descripción (opcional)';

  @override
  String get shareMenuCreate => 'Crear';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Se creó el set de seguidos \"$name\" y se agregó al creador';
  }

  @override
  String get shareMenuDone => 'Listo';

  @override
  String get shareMenuEditTitle => 'Título';

  @override
  String get shareMenuEditTitleHint => 'Ingresá el título del video';

  @override
  String get shareMenuEditDescription => 'Descripción';

  @override
  String get shareMenuEditDescriptionHint => 'Ingresá la descripción del video';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'hashtags, separados, por coma';

  @override
  String get shareMenuEditMetadataNote =>
      'Nota: solo se pueden editar los metadatos. El contenido del video no se puede cambiar.';

  @override
  String get shareMenuDeleting => 'Eliminando...';

  @override
  String get shareMenuUpdate => 'Actualizar';

  @override
  String get shareMenuVideoUpdated => 'Video actualizado con éxito';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'No se pudo actualizar el video: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'No se pudo eliminar el video: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => '¿Eliminar video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'Esto envía un pedido de eliminación a los relays. Nota: algunos relays todavía pueden tener copias en caché.';

  @override
  String get shareMenuVideoDeletionRequested =>
      'Eliminación del video solicitada';

  @override
  String get shareMenuContentLabels => 'Etiquetas de contenido';

  @override
  String get shareMenuAddContentLabels => 'Agregar etiquetas de contenido';

  @override
  String get shareMenuClearAll => 'Limpiar todo';

  @override
  String get shareMenuCollaborators => 'Colaboradores';

  @override
  String get shareMenuAddCollaborator => 'Agregar colaborador';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'Necesitás seguir mutuamente a $name para sumarle como colaborador.';
  }

  @override
  String get shareMenuLoading => 'Cargando...';

  @override
  String get shareMenuInspiredBy => 'Inspirado en';

  @override
  String get shareMenuAddInspirationCredit => 'Agregar crédito de inspiración';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'No se puede referenciar a este creador.';

  @override
  String get shareMenuUnknown => 'Desconocido';

  @override
  String get shareMenuCreateBookmarkSet => 'Crear set de marcadores';

  @override
  String get shareMenuSetName => 'Nombre del set';

  @override
  String get shareMenuSetNameHint => 'ej: Favoritos, Para ver después, etc.';

  @override
  String get shareMenuCreateNewSet => 'Crear nuevo set';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Arrancá una colección nueva de marcadores';

  @override
  String get shareMenuNoBookmarkSets =>
      'Todavía no tenés sets de marcadores. ¡Creá el primero!';

  @override
  String get shareMenuError => 'Error';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'No se pudieron cargar los sets de marcadores';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Se creó \"$name\" y se agregó el video';
  }

  @override
  String get shareMenuUseThisSound => 'Usar este sonido';

  @override
  String get shareMenuOriginalSound => 'Sonido original';

  @override
  String get authSessionExpired => 'Tu sesión expiró. Iniciá sesión de nuevo.';

  @override
  String get authSignInFailed => 'No se pudo iniciar sesión. Probá de nuevo.';

  @override
  String get localeAppLanguage => 'Idioma de la app';

  @override
  String get localeDeviceDefault => 'Predeterminado del dispositivo';

  @override
  String get localeSelectLanguage => 'Elegí un idioma';

  @override
  String get webAuthNotSupportedSecureMode =>
      'La autenticación web no está soportada en modo seguro. Usá la app móvil para gestionar claves de forma segura.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Falló la integración de autenticación: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Error inesperado: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Ingresá una URI de bunker';

  @override
  String get webAuthConnectTitle => 'Conectar con Divine';

  @override
  String get webAuthChooseMethod =>
      'Elegí tu método preferido de autenticación de Nostr';

  @override
  String get webAuthBrowserExtension => 'Extensión del navegador';

  @override
  String get webAuthRecommended => 'RECOMENDADO';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Conectar con un firmante remoto';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Pegar desde el portapapeles';

  @override
  String get webAuthConnectToBunker => 'Conectar al bunker';

  @override
  String get webAuthNewToNostr => '¿Sos nuevo en Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Instalá una extensión como Alby o nos2x para la experiencia más fácil, o usá nsec bunker para firma remota segura.';

  @override
  String get soundsTitle => 'Sonidos';

  @override
  String get soundsSearchHint => 'Buscar sonidos...';

  @override
  String get soundsPreviewUnavailable =>
      'No se puede previsualizar el sonido: no hay audio disponible';

  @override
  String soundsPreviewFailed(String error) {
    return 'No se pudo reproducir la previsualización: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Sonidos destacados';

  @override
  String get soundsTrendingSounds => 'Sonidos en tendencia';

  @override
  String get soundsAllSounds => 'Todos los sonidos';

  @override
  String get soundsSearchResults => 'Resultados de búsqueda';

  @override
  String get soundsNoSoundsAvailable => 'No hay sonidos disponibles';

  @override
  String get soundsNoSoundsDescription =>
      'Los sonidos van a aparecer acá cuando los creadores compartan audio';

  @override
  String get soundsNoSoundsFound => 'No se encontraron sonidos';

  @override
  String get soundsNoSoundsFoundDescription =>
      'Probá con otro término de búsqueda';

  @override
  String get soundsFailedToLoad => 'No se pudieron cargar los sonidos';

  @override
  String get soundsRetry => 'Reintentar';

  @override
  String get soundsScreenLabel => 'Pantalla de sonidos';

  @override
  String get profileTitle => 'Perfil';

  @override
  String get profileRefresh => 'Actualizar';

  @override
  String get profileRefreshLabel => 'Actualizar perfil';

  @override
  String get profileMoreOptions => 'Más opciones';

  @override
  String profileBlockedUser(String name) {
    return 'Bloqueaste a $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Desbloqueaste a $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Dejaste de seguir a $name';
  }

  @override
  String profileError(String error) {
    return 'Error: $error';
  }

  @override
  String get notificationsTabAll => 'Todas';

  @override
  String get notificationsTabLikes => 'Me gusta';

  @override
  String get notificationsTabComments => 'Comentarios';

  @override
  String get notificationsTabFollows => 'Seguidores';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad =>
      'No se pudieron cargar las notificaciones';

  @override
  String get notificationsRetry => 'Reintentar';

  @override
  String get notificationsCheckingNew => 'buscando notificaciones nuevas';

  @override
  String get notificationsNoneYet => 'Todavía no hay notificaciones';

  @override
  String notificationsNoneForType(String type) {
    return 'No hay notificaciones de $type';
  }

  @override
  String get notificationsEmptyDescription =>
      'Cuando la gente interactúe con tu contenido, lo vas a ver acá';

  @override
  String notificationsLoadingType(String type) {
    return 'Cargando notificaciones de $type...';
  }

  @override
  String get notificationsInviteSingular =>
      '¡Tenés 1 invitación para compartir con un amigo!';

  @override
  String notificationsInvitePlural(int count) {
    return '¡Tenés $count invitaciones para compartir con amigos!';
  }

  @override
  String get notificationsVideoNotFound => 'Video no encontrado';

  @override
  String get notificationsVideoUnavailable => 'Video no disponible';

  @override
  String get notificationsFromNotification => 'Desde una notificación';

  @override
  String get feedFailedToLoadVideos => 'No se pudieron cargar los videos';

  @override
  String get feedRetry => 'Reintentar';

  @override
  String get feedNoFollowedUsers =>
      'Todavía no seguís a nadie.\nSeguí a alguien para ver sus videos acá.';

  @override
  String get feedForYouEmpty =>
      'Tu feed Para ti está vacío.\nExplora videos y sigue a creadores para personalizarlo.';

  @override
  String get feedFollowingEmpty =>
      'Aún no hay videos de personas que sigues.\nEncuentra creadores que te gusten y síguelos.';

  @override
  String get feedLatestEmpty => 'Aún no hay videos nuevos.\nVuelve pronto.';

  @override
  String get feedExploreVideos => 'Explorar videos';

  @override
  String get feedExternalVideoSlow => 'Un video externo se carga lento';

  @override
  String get feedSkip => 'Saltar';

  @override
  String get uploadWaitingToUpload => 'Esperando para subir';

  @override
  String get uploadUploadingVideo => 'Subiendo video';

  @override
  String get uploadProcessingVideo => 'Procesando video';

  @override
  String get uploadProcessingComplete => 'Procesamiento completo';

  @override
  String get uploadPublishedSuccessfully => 'Publicado con éxito';

  @override
  String get uploadFailed => 'Falló la subida';

  @override
  String get uploadRetrying => 'Reintentando la subida';

  @override
  String get uploadPaused => 'Subida pausada';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% completo';
  }

  @override
  String get uploadQueuedMessage => 'Tu video está en la cola para subirse';

  @override
  String get uploadUploadingMessage => 'Subiendo al servidor...';

  @override
  String get uploadProcessingMessage =>
      'Procesando video — esto puede tardar unos minutos';

  @override
  String get uploadReadyToPublishMessage =>
      'Video procesado con éxito y listo para publicar';

  @override
  String get uploadPublishedMessage => 'Video publicado en tu perfil';

  @override
  String get uploadFailedMessage => 'Falló la subida — probá de nuevo';

  @override
  String get uploadRetryingMessage => 'Reintentando la subida...';

  @override
  String get uploadPausedMessage => 'Subida pausada por el usuario';

  @override
  String get uploadRetryButton => 'REINTENTAR';

  @override
  String uploadRetryFailed(String error) {
    return 'No se pudo reintentar la subida: $error';
  }

  @override
  String get userSearchPrompt => 'Buscar usuarios';

  @override
  String get userSearchNoResults => 'No se encontraron usuarios';

  @override
  String get userSearchFailed => 'Falló la búsqueda';

  @override
  String get userPickerSearchByName => 'Buscar por nombre';

  @override
  String get userPickerFilterByNameHint => 'Filtrar por nombre...';

  @override
  String get userPickerSearchByNameHint => 'Buscar por nombre...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name ya fue agregado';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Seleccionar $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Tu gente está ahí fuera';

  @override
  String get userPickerEmptyFollowListBody =>
      'Sigue a personas con las que conectas. Cuando te sigan de vuelta, pueden colaborar.';

  @override
  String get userPickerGoBack => 'Volver';

  @override
  String get userPickerTypeNameToSearch => 'Escribe un nombre para buscar';

  @override
  String get userPickerUnavailable =>
      'La búsqueda de usuarios no está disponible. Inténtalo de nuevo más tarde.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'La búsqueda falló. Inténtalo de nuevo.';

  @override
  String get forgotPasswordTitle => 'Restablecer contraseña';

  @override
  String get forgotPasswordDescription =>
      'Ingresá tu email y te mandamos un link para restablecer la contraseña.';

  @override
  String get forgotPasswordEmailLabel => 'Dirección de email';

  @override
  String get forgotPasswordCancel => 'Cancelar';

  @override
  String get forgotPasswordSendLink => 'Enviar link por email';

  @override
  String get ageVerificationContentWarning => 'Advertencia de contenido';

  @override
  String get ageVerificationTitle => 'Verificación de edad';

  @override
  String get ageVerificationAdultDescription =>
      'Este contenido fue marcado como potencialmente adulto. Tenés que tener 18 años o más para verlo.';

  @override
  String get ageVerificationCreationDescription =>
      'Para usar la cámara y crear contenido, tenés que tener al menos 16 años.';

  @override
  String get ageVerificationAdultQuestion => '¿Tenés 18 años o más?';

  @override
  String get ageVerificationCreationQuestion => '¿Tenés 16 años o más?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Sí';

  @override
  String get shareLinkCopied => 'Link copiado al portapapeles';

  @override
  String get shareFailedToCopy => 'No se pudo copiar el link';

  @override
  String get shareVideoSubject => 'Mirá este video en Divine';

  @override
  String get shareFailedToShare => 'No se pudo compartir';

  @override
  String get shareVideoTitle => 'Compartir video';

  @override
  String get shareToApps => 'Compartir con apps';

  @override
  String get shareToAppsSubtitle => 'Compartí por mensajería o apps sociales';

  @override
  String get shareCopyWebLink => 'Copiar link web';

  @override
  String get shareCopyWebLinkSubtitle => 'Copiar link web para compartir';

  @override
  String get shareCopyNostrLink => 'Copiar link de Nostr';

  @override
  String get shareCopyNostrLinkSubtitle =>
      'Copiar el link nevent para clientes de Nostr';

  @override
  String get navHome => 'Inicio';

  @override
  String get navExplore => 'Explorar';

  @override
  String get navInbox => 'Bandeja';

  @override
  String get navProfile => 'Perfil';

  @override
  String get navSearch => 'Buscar';

  @override
  String get navSearchTooltip => 'Buscar';

  @override
  String get navMyProfile => 'Mi perfil';

  @override
  String get navNotifications => 'Notificaciones';

  @override
  String get navOpenCamera => 'Abrir cámara';

  @override
  String get navUnknown => 'Desconocido';

  @override
  String get navExploreClassics => 'Clásicos';

  @override
  String get navExploreNewVideos => 'Videos nuevos';

  @override
  String get navExploreTrending => 'En tendencia';

  @override
  String get navExploreForYou => 'Para vos';

  @override
  String get navExploreLists => 'Listas';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Hashtag inválido';

  @override
  String get routeInvalidConversationId => 'ID de conversación inválido';

  @override
  String get routeInvalidRequestId => 'ID de pedido inválido';

  @override
  String get routeInvalidListId => 'ID de lista inválido';

  @override
  String get routeInvalidUserId => 'ID de usuario inválido';

  @override
  String get routeInvalidVideoId => 'ID de video inválido';

  @override
  String get routeInvalidSoundId => 'ID de sonido inválido';

  @override
  String get routeInvalidCategory => 'Categoría inválida';

  @override
  String get routeNoVideosToDisplay => 'No hay videos para mostrar';

  @override
  String get routeInvalidProfileId => 'ID de perfil inválido';

  @override
  String get routeDefaultListName => 'Lista';

  @override
  String get supportTitle => 'Centro de soporte';

  @override
  String get supportContactSupport => 'Contactar a soporte';

  @override
  String get supportContactSupportSubtitle =>
      'Empezá una conversación o mirá los mensajes anteriores';

  @override
  String get supportReportBug => 'Reportar un bug';

  @override
  String get supportReportBugSubtitle => 'Problemas técnicos con la app';

  @override
  String get supportRequestFeature => 'Pedir una función';

  @override
  String get supportRequestFeatureSubtitle =>
      'Sugerí una mejora o una función nueva';

  @override
  String get supportSaveLogs => 'Guardar logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Exportá los logs a un archivo para enviarlos manualmente';

  @override
  String get supportFaq => 'Preguntas frecuentes';

  @override
  String get supportFaqSubtitle => 'Preguntas y respuestas comunes';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Conocé sobre verificación y autenticidad';

  @override
  String get supportLoginRequired => 'Iniciá sesión para contactar a soporte';

  @override
  String get supportExportingLogs => 'Exportando logs...';

  @override
  String get supportExportLogsFailed => 'No se pudieron exportar los logs';

  @override
  String get supportChatNotAvailable => 'El chat de soporte no está disponible';

  @override
  String get supportCouldNotOpenMessages =>
      'No se pudieron abrir los mensajes de soporte';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'No se pudo abrir $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Error al abrir $pageName: $error';
  }

  @override
  String get reportTitle => 'Reportar contenido';

  @override
  String get reportWhyReporting => '¿Por qué estás reportando este contenido?';

  @override
  String get reportPolicyNotice =>
      'Divine va a actuar sobre los reportes de contenido dentro de las 24 horas, removiendo el contenido y expulsando al usuario que lo publicó.';

  @override
  String get reportAdditionalDetails => 'Detalles adicionales (opcional)';

  @override
  String get reportBlockUser => 'Bloquear a este usuario';

  @override
  String get reportCancel => 'Cancelar';

  @override
  String get reportSubmit => 'Reportar';

  @override
  String get reportSelectReason =>
      'Elegí un motivo para reportar este contenido';

  @override
  String get reportReasonSpam => 'Spam o contenido no deseado';

  @override
  String get reportReasonHarassment => 'Acoso, bullying o amenazas';

  @override
  String get reportReasonViolence => 'Contenido violento o extremista';

  @override
  String get reportReasonSexualContent => 'Contenido sexual o adulto';

  @override
  String get reportReasonCopyright => 'Infracción de derechos de autor';

  @override
  String get reportReasonFalseInfo => 'Información falsa';

  @override
  String get reportReasonCsam => 'Violación de la seguridad infantil';

  @override
  String get reportReasonAiGenerated => 'Contenido generado por IA';

  @override
  String get reportReasonOther => 'Otra violación de políticas';

  @override
  String reportFailed(Object error) {
    return 'No se pudo reportar el contenido: $error';
  }

  @override
  String get reportReceivedTitle => 'Reporte recibido';

  @override
  String get reportReceivedThankYou =>
      'Gracias por ayudar a mantener Divine seguro.';

  @override
  String get reportReceivedReviewNotice =>
      'Nuestro equipo va a revisar tu reporte y tomar las medidas necesarias. Quizás recibas novedades por mensaje directo.';

  @override
  String get reportLearnMore => 'Conocé más';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Cerrar';

  @override
  String get listAddToList => 'Agregar a lista';

  @override
  String listVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get listNewList => 'Lista nueva';

  @override
  String get listDone => 'Listo';

  @override
  String get listErrorLoading => 'Error al cargar las listas';

  @override
  String listRemovedFrom(String name) {
    return 'Quitado de $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Agregado a $name';
  }

  @override
  String get listCreateNewList => 'Crear lista nueva';

  @override
  String get listNameLabel => 'Nombre de la lista';

  @override
  String get listDescriptionLabel => 'Descripción (opcional)';

  @override
  String get listPublicList => 'Lista pública';

  @override
  String get listPublicListSubtitle => 'Otros pueden seguir y ver esta lista';

  @override
  String get listCancel => 'Cancelar';

  @override
  String get listCreate => 'Crear';

  @override
  String get listCreateFailed => 'No se pudo crear la lista';

  @override
  String get keyManagementTitle => 'Claves de Nostr';

  @override
  String get keyManagementWhatAreKeys => '¿Qué son las claves de Nostr?';

  @override
  String get keyManagementExplanation =>
      'Tu identidad en Nostr es un par de claves criptográficas:\n\n• Tu clave pública (npub) es como tu nombre de usuario — compartila tranqui\n• Tu clave privada (nsec) es como tu contraseña — ¡mantenela en secreto!\n\nTu nsec te permite acceder a tu cuenta en cualquier app de Nostr.';

  @override
  String get keyManagementImportTitle => 'Importar clave existente';

  @override
  String get keyManagementImportSubtitle =>
      '¿Ya tenés una cuenta en Nostr? Pegá tu clave privada (nsec) para acceder acá.';

  @override
  String get keyManagementImportButton => 'Importar clave';

  @override
  String get keyManagementImportWarning =>
      '¡Esto va a reemplazar tu clave actual!';

  @override
  String get keyManagementBackupTitle => 'Respaldá tu clave';

  @override
  String get keyManagementBackupSubtitle =>
      'Guardá tu clave privada (nsec) para usar tu cuenta en otras apps de Nostr.';

  @override
  String get keyManagementCopyNsec => 'Copiar mi clave privada (nsec)';

  @override
  String get keyManagementNeverShare => '¡Nunca compartas tu nsec con nadie!';

  @override
  String get keyManagementPasteKey => 'Pegá tu clave privada';

  @override
  String get keyManagementInvalidFormat =>
      'Formato de clave inválido. Tiene que empezar con \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => '¿Importar esta clave?';

  @override
  String get keyManagementConfirmImportBody =>
      'Esto va a reemplazar tu identidad actual con la importada.\n\nTu clave actual se va a perder salvo que la hayas respaldado antes.';

  @override
  String get keyManagementImportConfirm => 'Importar';

  @override
  String get keyManagementImportSuccess => '¡Clave importada con éxito!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'No se pudo importar la clave: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      '¡Clave privada copiada al portapapeles!\n\nGuardala en un lugar seguro.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'No se pudo exportar la clave: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Guardado en el carrete';

  @override
  String get saveOriginalShare => 'Compartir';

  @override
  String get saveOriginalDone => 'Listo';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Se necesita acceso a Fotos';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'Para guardar videos, permití el acceso a Fotos en Ajustes.';

  @override
  String get saveOriginalOpenSettings => 'Abrir Ajustes';

  @override
  String get saveOriginalNotNow => 'Ahora no';

  @override
  String get cameraPermissionNotNow => 'Ahora no';

  @override
  String get saveOriginalDownloadFailed => 'Falló la descarga';

  @override
  String get saveOriginalDismiss => 'Descartar';

  @override
  String get saveOriginalDownloadingVideo => 'Descargando video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Guardando en el carrete';

  @override
  String get saveOriginalFetchingVideo => 'Obteniendo el video de la red...';

  @override
  String get saveOriginalSavingVideo =>
      'Guardando el video original en tu carrete...';

  @override
  String get soundTitle => 'Sonido';

  @override
  String get soundOriginalSound => 'Sonido original';

  @override
  String get soundVideosUsingThisSound => 'Videos que usan este sonido';

  @override
  String get soundSourceVideo => 'Video de origen';

  @override
  String get soundNoVideosYet => 'Todavía no hay videos';

  @override
  String get soundBeFirstToUse => '¡Sé el primero en usar este sonido!';

  @override
  String get soundFailedToLoadVideos => 'No se pudieron cargar los videos';

  @override
  String get soundRetry => 'Reintentar';

  @override
  String get soundVideosUnavailable => 'Videos no disponibles';

  @override
  String get soundCouldNotLoadDetails =>
      'No se pudieron cargar los detalles del video';

  @override
  String get soundPreview => 'Previsualizar';

  @override
  String get soundStop => 'Parar';

  @override
  String get soundUseSound => 'Usar sonido';

  @override
  String get soundNoVideoCount => 'Todavía no hay videos';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get soundUnableToPreview =>
      'No se puede previsualizar el sonido: no hay audio disponible';

  @override
  String soundPreviewFailed(Object error) {
    return 'No se pudo reproducir la previsualización: $error';
  }

  @override
  String get soundViewSource => 'Ver origen';

  @override
  String get soundCloseTooltip => 'Cerrar';

  @override
  String get exploreNotExploreRoute => 'No es una ruta de explorar';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Términos del Servicio';

  @override
  String get legalTermsOfServiceSubtitle => 'Términos y condiciones de uso';

  @override
  String get legalPrivacyPolicy => 'Política de Privacidad';

  @override
  String get legalPrivacyPolicySubtitle => 'Cómo manejamos tus datos';

  @override
  String get legalSafetyStandards => 'Estándares de Seguridad';

  @override
  String get legalSafetyStandardsSubtitle =>
      'Pautas de la comunidad y seguridad';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Política de derechos de autor y de remoción';

  @override
  String get legalOpenSourceLicenses => 'Licencias de código abierto';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Atribuciones de paquetes de terceros';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'No se pudo abrir $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Error al abrir $pageName: $error';
  }

  @override
  String get categoryAction => 'Acción';

  @override
  String get categoryAdventure => 'Aventura';

  @override
  String get categoryAnimals => 'Animales';

  @override
  String get categoryAnimation => 'Animación';

  @override
  String get categoryArchitecture => 'Arquitectura';

  @override
  String get categoryArt => 'Arte';

  @override
  String get categoryAutomotive => 'Autos';

  @override
  String get categoryAwardShow => 'Entrega de premios';

  @override
  String get categoryAwards => 'Premios';

  @override
  String get categoryBaseball => 'Béisbol';

  @override
  String get categoryBasketball => 'Básquet';

  @override
  String get categoryBeauty => 'Belleza';

  @override
  String get categoryBeverage => 'Bebidas';

  @override
  String get categoryCars => 'Autos';

  @override
  String get categoryCelebration => 'Celebración';

  @override
  String get categoryCelebrities => 'Famosos';

  @override
  String get categoryCelebrity => 'Famoso';

  @override
  String get categoryCityscape => 'Paisaje urbano';

  @override
  String get categoryComedy => 'Comedia';

  @override
  String get categoryConcert => 'Concierto';

  @override
  String get categoryCooking => 'Cocina';

  @override
  String get categoryCostume => 'Disfraz';

  @override
  String get categoryCrafts => 'Manualidades';

  @override
  String get categoryCrime => 'Crimen';

  @override
  String get categoryCulture => 'Cultura';

  @override
  String get categoryDance => 'Baile';

  @override
  String get categoryDiy => 'Hazlo vos mismo';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Educación';

  @override
  String get categoryEmotional => 'Emotivo';

  @override
  String get categoryEmotions => 'Emociones';

  @override
  String get categoryEntertainment => 'Entretenimiento';

  @override
  String get categoryEvent => 'Evento';

  @override
  String get categoryFamily => 'Familia';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantasía';

  @override
  String get categoryFashion => 'Moda';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Cine';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Comida';

  @override
  String get categoryFootball => 'Fútbol americano';

  @override
  String get categoryFurniture => 'Muebles';

  @override
  String get categoryGaming => 'Videojuegos';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Cuidado personal';

  @override
  String get categoryGuitar => 'Guitarra';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Salud';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Feriado';

  @override
  String get categoryHome => 'Hogar';

  @override
  String get categoryHomeImprovement => 'Reformas del hogar';

  @override
  String get categoryHorror => 'Terror';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Diseño de interiores';

  @override
  String get categoryInterview => 'Entrevista';

  @override
  String get categoryKids => 'Chicos';

  @override
  String get categoryLifestyle => 'Estilo de vida';

  @override
  String get categoryMagic => 'Magia';

  @override
  String get categoryMakeup => 'Maquillaje';

  @override
  String get categoryMedical => 'Medicina';

  @override
  String get categoryMusic => 'Música';

  @override
  String get categoryMystery => 'Misterio';

  @override
  String get categoryNature => 'Naturaleza';

  @override
  String get categoryNews => 'Noticias';

  @override
  String get categoryOutdoor => 'Al aire libre';

  @override
  String get categoryParty => 'Fiesta';

  @override
  String get categoryPeople => 'Gente';

  @override
  String get categoryPerformance => 'Espectáculo';

  @override
  String get categoryPets => 'Mascotas';

  @override
  String get categoryPolitics => 'Política';

  @override
  String get categoryPrank => 'Broma';

  @override
  String get categoryPranks => 'Bromas';

  @override
  String get categoryRealityShow => 'Reality';

  @override
  String get categoryRelationship => 'Relación';

  @override
  String get categoryRelationships => 'Relaciones';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'Escuela';

  @override
  String get categoryScienceFiction => 'Ciencia ficción';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Compras';

  @override
  String get categorySkateboarding => 'Skate';

  @override
  String get categorySkincare => 'Cuidado de la piel';

  @override
  String get categorySoccer => 'Fútbol';

  @override
  String get categorySocialGathering => 'Encuentro social';

  @override
  String get categorySocialMedia => 'Redes sociales';

  @override
  String get categorySports => 'Deportes';

  @override
  String get categoryTalkShow => 'Programa de entrevistas';

  @override
  String get categoryTech => 'Tecno';

  @override
  String get categoryTechnology => 'Tecnología';

  @override
  String get categoryTelevision => 'Televisión';

  @override
  String get categoryToys => 'Juguetes';

  @override
  String get categoryTransportation => 'Transporte';

  @override
  String get categoryTravel => 'Viajes';

  @override
  String get categoryUrban => 'Urbano';

  @override
  String get categoryViolence => 'Violencia';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Lucha libre';

  @override
  String get profileSetupUploadSuccess => '¡Foto de perfil subida con éxito!';

  @override
  String inboxReportedUser(String displayName) {
    return 'Reportaste a $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Bloqueaste a $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Desbloqueaste a $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Conversación eliminada';

  @override
  String get inboxEmptyTitle => 'Aún no hay mensajes';

  @override
  String get inboxEmptySubtitle => 'El botón + no muerde.';

  @override
  String get inboxActionMute => 'Silenciar conversación';

  @override
  String inboxActionReport(String displayName) {
    return 'Reportar a $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Bloquear a $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Desbloquear a $displayName';
  }

  @override
  String get inboxActionRemove => 'Eliminar conversación';

  @override
  String get inboxRemoveConfirmTitle => '¿Eliminar conversación?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'Esto eliminará tu conversación con $displayName. Esta acción no se puede deshacer.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Eliminar';

  @override
  String get inboxConversationMuted => 'Conversación silenciada';

  @override
  String get inboxConversationUnmuted => 'Conversación sin silenciar';

  @override
  String get reportDialogCancel => 'Cancelar';

  @override
  String get reportDialogReport => 'Reportar';

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
    return 'Video $current/$total';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'No se pudo actualizar la suscripción: $error';
  }

  @override
  String get commonRetry => 'Reintentar';

  @override
  String get commonNext => 'Siguiente';

  @override
  String get commonDelete => 'Eliminar';

  @override
  String get commonCancel => 'Cancelar';

  @override
  String get videoMetadataTags => 'Etiquetas';

  @override
  String get videoMetadataExpiration => 'Vencimiento';

  @override
  String get videoMetadataExpirationNotExpire => 'No caduca';

  @override
  String get videoMetadataExpirationOneDay => '1 día';

  @override
  String get videoMetadataExpirationOneWeek => '1 semana';

  @override
  String get videoMetadataExpirationOneMonth => '1 mes';

  @override
  String get videoMetadataExpirationOneYear => '1 año';

  @override
  String get videoMetadataExpirationOneDecade => '1 década';

  @override
  String get videoMetadataContentWarnings => 'Advertencias de contenido';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Tendencias';

  @override
  String get proofmodeCheckAiGenerated => 'Verificar si fue generado por IA';

  @override
  String get libraryDeleteConfirm => 'Eliminar';

  @override
  String get libraryWebUnavailableHeadline =>
      'La biblioteca está en la app móvil';

  @override
  String get libraryWebUnavailableDescription =>
      'Los borradores y clips se guardan en tu dispositivo; abre Divine en el teléfono para gestionarlos.';

  @override
  String get libraryTabDrafts => 'Borradores';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get librarySaveToCameraRollTooltip => 'Guardar en el carrete';

  @override
  String get libraryDeleteSelectedClipsTooltip =>
      'Eliminar clips seleccionados';

  @override
  String get libraryDeleteClipsTitle => 'Eliminar clips';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# clips seleccionados',
      one: '# clip seleccionado',
    );
    return '¿Seguro que quieres eliminar $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'No se puede deshacer. Los archivos de video se eliminarán permanentemente de tu dispositivo.';

  @override
  String get libraryPreparingVideo => 'Preparando video...';

  @override
  String get libraryCreateVideo => 'Crear video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 guardados en $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount guardados, $failureCount fallidos';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return 'Permiso denegado para $destination';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Se eliminaron $count clips',
      one: 'Se eliminó 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts =>
      'No se pudieron cargar los borradores';

  @override
  String get libraryCouldNotLoadClips => 'No se pudieron cargar los clips';

  @override
  String get libraryOpenErrorDescription =>
      'Algo salió mal al abrir tu biblioteca. Puedes intentarlo de nuevo.';

  @override
  String get libraryNoDraftsYetTitle => 'Aún no hay borradores';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Los videos que guardes como borrador aparecerán aquí';

  @override
  String get libraryNoClipsYetTitle => 'Aún no hay clips';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Tus clips de video grabados aparecerán aquí';

  @override
  String get libraryDraftDeletedSnackbar => 'Borrador eliminado';

  @override
  String get libraryDraftDeleteFailedSnackbar =>
      'No se pudo eliminar el borrador';

  @override
  String get libraryDraftActionPost => 'Publicar';

  @override
  String get libraryDraftActionEdit => 'Editar';

  @override
  String get libraryDraftActionDelete => 'Eliminar borrador';

  @override
  String get libraryDeleteDraftTitle => 'Eliminar borrador';

  @override
  String libraryDeleteDraftMessage(String title) {
    return '¿Seguro que quieres eliminar \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Eliminar clip';

  @override
  String get libraryDeleteClipMessage =>
      '¿Seguro que quieres eliminar este clip?';

  @override
  String get libraryClipSelectionTitle => 'Clips';

  @override
  String librarySecondsRemaining(String seconds) {
    return 'Quedan ${seconds}s';
  }

  @override
  String get libraryAddClips => 'Añadir';

  @override
  String get libraryRecordVideo => 'Grabar un video';

  @override
  String get routerInvalidCreator => 'Creador no válido';

  @override
  String get routerInvalidHashtagRoute => 'Ruta de hashtag no válida';

  @override
  String get categoryGalleryCouldNotLoadVideos =>
      'No se pudieron cargar los videos';

  @override
  String get categoriesCouldNotLoadCategories =>
      'No se pudieron cargar las categorías';

  @override
  String get notificationFollowBack => 'Seguir de vuelta';

  @override
  String get followingFailedToLoadList =>
      'No se pudo cargar la lista de seguidos';

  @override
  String get followersFailedToLoadList =>
      'No se pudo cargar la lista de seguidores';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'No se pudieron guardar los ajustes: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'No se pudo actualizar la configuración de crosspost';

  @override
  String get invitesTitle => 'Invitar amigos';

  @override
  String get searchSomethingWentWrong => 'Algo salió mal';

  @override
  String get searchTryAgain => 'Reintentar';

  @override
  String get searchForLists => 'Buscar listas';

  @override
  String get searchFindCuratedVideoLists => 'Encontrá listas de videos curadas';

  @override
  String get searchEnterQuery => 'Ingresá una búsqueda';

  @override
  String get searchDiscoverSomethingInteresting => 'Descubrí algo interesante';

  @override
  String get searchListsSectionHeader => 'Listas';

  @override
  String get searchListsLoadingLabel => 'Cargando resultados de listas';

  @override
  String get cameraAgeRestriction =>
      'Tenés que tener 16 años o más para crear contenido';

  @override
  String get featureRequestCancel => 'Cancelar';

  @override
  String keyImportError(String error) {
    return 'Error: $error';
  }

  @override
  String get timeNow => 'ahora';

  @override
  String timeShortMinutes(int count) {
    return '${count}m';
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
  String get timeVerboseNow => 'Ahora';

  @override
  String timeAgo(String time) {
    return 'hace $time';
  }

  @override
  String get timeToday => 'Hoy';

  @override
  String get timeYesterday => 'Ayer';

  @override
  String get timeJustNow => 'recién';

  @override
  String timeMinutesAgo(int count) {
    return 'hace ${count}m';
  }

  @override
  String timeHoursAgo(int count) {
    return 'hace ${count}h';
  }

  @override
  String timeDaysAgo(int count) {
    return 'hace ${count}d';
  }

  @override
  String get draftTimeJustNow => 'Recién';

  @override
  String get contentLabelNudity => 'Desnudez';

  @override
  String get contentLabelSexualContent => 'Contenido sexual';

  @override
  String get contentLabelPornography => 'Pornografía';

  @override
  String get contentLabelGraphicMedia => 'Contenido explícito';

  @override
  String get contentLabelViolence => 'Violencia';

  @override
  String get contentLabelSelfHarm => 'Autolesión/Suicidio';

  @override
  String get contentLabelDrugUse => 'Consumo de drogas';

  @override
  String get contentLabelAlcohol => 'Alcohol';

  @override
  String get contentLabelTobacco => 'Tabaco/Fumar';

  @override
  String get contentLabelGambling => 'Apuestas';

  @override
  String get contentLabelProfanity => 'Lenguaje soez';

  @override
  String get contentLabelHateSpeech => 'Discurso de odio';

  @override
  String get contentLabelHarassment => 'Acoso';

  @override
  String get contentLabelFlashingLights => 'Luces intermitentes';

  @override
  String get contentLabelAiGenerated => 'Generado por IA';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Estafa/Fraude';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Engañoso';

  @override
  String get contentLabelSensitiveContent => 'Contenido sensible';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName le dio like a tu video';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName comentó tu video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName empezó a seguirte';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName te mencionó';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName compartió tu video';
  }

  @override
  String get draftUntitled => 'Sin título';

  @override
  String get contentWarningNone => 'Ninguna';

  @override
  String get textBackgroundNone => 'Ninguno';

  @override
  String get textBackgroundSolid => 'Sólido';

  @override
  String get textBackgroundHighlight => 'Resaltado';

  @override
  String get textBackgroundTransparent => 'Transparente';

  @override
  String get textAlignLeft => 'Izquierda';

  @override
  String get textAlignRight => 'Derecha';

  @override
  String get textAlignCenter => 'Centro';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'La cámara todavía no es compatible en la web';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'La captura y grabación con cámara todavía no están disponibles en la versión web.';

  @override
  String get cameraPermissionBackToFeed => 'Volver al feed';

  @override
  String get cameraPermissionErrorTitle => 'Error de permisos';

  @override
  String get cameraPermissionErrorDescription =>
      'Algo salió mal al verificar los permisos.';

  @override
  String get cameraPermissionRetry => 'Reintentar';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Permitir acceso a cámara y micrófono';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'Esto te permite capturar y editar videos aquí mismo en la app, nada más.';

  @override
  String get cameraPermissionContinue => 'Continuar';

  @override
  String get cameraPermissionGoToSettings => 'Ir a ajustes';

  @override
  String get videoRecorderWhySixSecondsTitle => '¿Por qué seis segundos?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Los clips cortos dejan espacio para la espontaneidad. El formato de 6 segundos te ayuda a capturar momentos auténticos tal como ocurren.';

  @override
  String get videoRecorderWhySixSecondsButton => '¡Entendido!';

  @override
  String get videoRecorderAutosaveFoundTitle =>
      'Encontramos trabajo en progreso';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      '¿Quieres continuar donde lo dejaste?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Sí, continuar';

  @override
  String get videoRecorderAutosaveDiscardButton =>
      'No, comenzar un video nuevo';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'No se pudo restaurar tu borrador';

  @override
  String get videoRecorderStopRecordingTooltip => 'Detener grabación';

  @override
  String get videoRecorderStartRecordingTooltip => 'Iniciar grabación';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Grabando. Toca en cualquier lugar para detener';

  @override
  String get videoRecorderTapToStartLabel =>
      'Toca en cualquier lugar para iniciar la grabación';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Eliminar último clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Cambiar cámara';

  @override
  String get videoRecorderToggleGridLabel => 'Mostrar u ocultar cuadrícula';

  @override
  String get videoRecorderToggleGhostFrameLabel =>
      'Mostrar u ocultar fotograma fantasma';

  @override
  String get videoRecorderGhostFrameEnabled => 'Fotograma fantasma activado';

  @override
  String get videoRecorderGhostFrameDisabled =>
      'Fotograma fantasma desactivado';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip eliminado';

  @override
  String get videoRecorderCloseLabel => 'Cerrar grabador de video';

  @override
  String get videoRecorderContinueToEditorLabel =>
      'Continuar al editor de video';

  @override
  String get videoRecorderCaptureCloseLabel => 'Cerrar';

  @override
  String get videoRecorderCaptureNextLabel => 'Siguiente';

  @override
  String get videoRecorderToggleFlashLabel => 'Activar o desactivar flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Cambiar temporizador';

  @override
  String get videoRecorderToggleAspectRatioLabel =>
      'Cambiar relación de aspecto';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Biblioteca de clips, sin clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Abrir biblioteca de clips, $clipCount clips',
      one: 'Abrir biblioteca de clips, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Cámara';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Abrir cámara';

  @override
  String get videoEditorLibraryLabel => 'Biblioteca';

  @override
  String get videoEditorTextLabel => 'Texto';

  @override
  String get videoEditorDrawLabel => 'Dibujar';

  @override
  String get videoEditorFilterLabel => 'Filtro';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorVolumeLabel => 'Volumen';

  @override
  String get videoEditorAddTitle => 'Agregar';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Abrir biblioteca';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Abrir editor de audio';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Abrir editor de texto';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Abrir editor de dibujo';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Abrir editor de filtros';

  @override
  String get videoEditorSaveDraftTitle => '¿Guardar tu borrador?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Guarda tus ediciones para más tarde o descártalas y sal del editor.';

  @override
  String get videoEditorSaveDraftButton => 'Guardar borrador';

  @override
  String get videoEditorDiscardChangesButton => 'Descartar cambios';

  @override
  String get videoEditorKeepEditingButton => 'Seguir editando';

  @override
  String get videoEditorDeleteLayerDropZone =>
      'Zona para soltar y eliminar capa';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Suelta para eliminar la capa';

  @override
  String get videoEditorDoneLabel => 'Listo';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Reproducir o pausar video';

  @override
  String get videoEditorCropSemanticLabel => 'Recortar';

  @override
  String get videoEditorCannotSplitProcessing =>
      'No se puede dividir el clip mientras se está procesando. Espera, por favor.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Posición de división no válida. Ambos clips deben durar al menos $minDurationMs ms.';
  }

  @override
  String get videoEditorAddClipFromLibrary =>
      'Agregar clip desde la biblioteca';

  @override
  String get videoEditorSaveSelectedClip => 'Guardar clip seleccionado';

  @override
  String get videoEditorSplitClip => 'Dividir clip';

  @override
  String get videoEditorSaveClip => 'Guardar clip';

  @override
  String get videoEditorDeleteClip => 'Eliminar clip';

  @override
  String get videoEditorClipSavedSuccess => 'Clip guardado en la biblioteca';

  @override
  String get videoEditorClipSaveFailed => 'No se pudo guardar el clip';

  @override
  String get videoEditorClipDeleted => 'Clip eliminado';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Selector de color';

  @override
  String get videoEditorUndoSemanticLabel => 'Deshacer';

  @override
  String get videoEditorRedoSemanticLabel => 'Rehacer';

  @override
  String get videoEditorTextColorSemanticLabel => 'Color de texto';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Alineación de texto';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Fondo de texto';

  @override
  String get videoEditorFontSemanticLabel => 'Fuente';

  @override
  String get videoEditorNoStickersFound => 'No se encontraron stickers';

  @override
  String get videoEditorNoStickersAvailable => 'No hay stickers disponibles';

  @override
  String get videoEditorFailedLoadStickers =>
      'No se pudieron cargar los stickers';

  @override
  String get videoEditorAdjustVolumeTitle => 'Ajustar volumen';

  @override
  String get videoEditorRecordedAudioLabel => 'Audio grabado';

  @override
  String get videoEditorCustomAudioLabel => 'Audio personalizado';

  @override
  String get videoEditorPlaySemanticLabel => 'Reproducir';

  @override
  String get videoEditorPauseSemanticLabel => 'Pausar';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Silenciar audio';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Activar audio';

  @override
  String get videoEditorDeleteLabel => 'Eliminar';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Eliminar elemento seleccionado';

  @override
  String get videoEditorEditLabel => 'Editar';

  @override
  String get videoEditorEditSelectedItemSemanticLabel =>
      'Editar elemento seleccionado';

  @override
  String get videoEditorDuplicateLabel => 'Duplicar';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicar elemento seleccionado';

  @override
  String get videoEditorSplitLabel => 'Dividir';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel =>
      'Dividir clip seleccionado';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Terminar edición de la línea de tiempo';

  @override
  String get videoEditorSortNewest => 'Más nuevos';

  @override
  String get videoEditorSortLongest => 'Más largos';

  @override
  String get videoEditorSortShortest => 'Más cortos';

  @override
  String videoEditorSortBySemanticLabel(String option) {
    return 'Ordenar por $option. Toca para cambiar el orden';
  }

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel =>
      'Reproducir vista previa';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Pausar vista previa';

  @override
  String get videoEditorAudioUntitledSound => 'Sonido sin título';

  @override
  String get videoEditorAudioSelectSoundSemanticLabel => 'Seleccionar sonido';

  @override
  String get videoEditorAudioUntitled => 'Sin título';

  @override
  String get videoEditorAudioAddAudio => 'Agregar audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle =>
      'No hay sonidos disponibles';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Los sonidos aparecerán aquí cuando los creadores compartan audio';

  @override
  String get videoEditorAudioNoSoundsFoundTitle => 'No se encontraron sonidos';

  @override
  String get videoEditorAudioNoSoundsFoundSubtitle =>
      'Prueba con otro término de búsqueda';

  @override
  String get videoEditorAudioFailedToLoadTitle =>
      'No se pudieron cargar los sonidos';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Selecciona el segmento de audio para tu video';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Herramienta flecha';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Herramienta borrador';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Herramienta marcador';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Herramienta lápiz';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Reordenar capa $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Mantén presionado para reordenar';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Mostrar línea de tiempo';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Ocultar línea de tiempo';

  @override
  String get videoEditorFeedPreviewContent =>
      'Evita colocar contenido detrás de estas áreas.';

  @override
  String get videoEditorStickerSearchHint => 'Buscar stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Seleccionar fuente';

  @override
  String get videoEditorFontUnknown => 'Desconocida';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'El cabezal de reproducción debe estar dentro del clip seleccionado para dividir.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Recortar inicio';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Recortar fin';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Recortar clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Arrastra los controles para ajustar la duración del clip';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Arrastrando clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index de $total, $duration segundos';
  }

  @override
  String get videoEditorTimelineClipReorderHint =>
      'Mantén presionado para reordenar';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Toca para editar. Mantén presionado y arrastra para reordenar.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Mover a la izquierda';

  @override
  String get videoEditorTimelineClipMoveRight => 'Mover a la derecha';

  @override
  String get videoEditorTimelineLongPressToDragHint =>
      'Mantén presionado para arrastrar';

  @override
  String get videoEditorVideoTimelineSemanticLabel =>
      'Línea de tiempo de video';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '$minutes m $seconds s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, seleccionado';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel =>
      'Cerrar selector de color';

  @override
  String get videoEditorPickColorTitle => 'Elegir color';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirmar color';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturación y brillo';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturación $saturation %, brillo $brightness %';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Tono';

  @override
  String get videoEditorAddElementSemanticLabel => 'Agregar elemento';

  @override
  String get videoEditorCloseSemanticLabel => 'Cerrar';

  @override
  String get videoEditorDoneSemanticLabel => 'Listo';

  @override
  String get videoEditorLevelSemanticLabel => 'Nivel';

  @override
  String get videoMetadataBackSemanticLabel => 'Atrás';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Cerrar diálogo de ayuda';

  @override
  String get videoMetadataGotItButton => '¡Entendido!';

  @override
  String get videoMetadataLimitReachedWarning =>
      'Se alcanzó el límite de 64 KB. Elimina parte del contenido para continuar.';

  @override
  String get videoMetadataExpirationLabel => 'Expiración';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Seleccionar tiempo de expiración';

  @override
  String get videoMetadataTitleLabel => 'Título';

  @override
  String get videoMetadataDescriptionLabel => 'Descripción';

  @override
  String get videoMetadataTagsLabel => 'Etiquetas';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Eliminar';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Eliminar etiqueta $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Advertencia de contenido';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Seleccionar advertencias de contenido';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Selecciona todo lo que aplique a tu contenido';

  @override
  String get videoMetadataContentWarningDoneButton => 'Listo';

  @override
  String get videoMetadataCollaboratorsLabel => 'Colaboradores';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Agregar colaborador';

  @override
  String get videoMetadataCollaboratorsHelpTooltip =>
      'Cómo funcionan los colaboradores';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max colaboradores';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Eliminar colaborador';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Los colaboradores se etiquetan como co-creadores en esta publicación. Solo puedes agregar personas a las que sigues mutuamente y aparecerán en los metadatos de la publicación al publicarla.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Seguidores mutuos';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'Necesitas seguir mutuamente a $name para agregarlo como colaborador.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspirado en';

  @override
  String get videoMetadataSetInspiredBySemanticLabel =>
      'Establecer inspirado en';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'Cómo funcionan los créditos de inspiración';

  @override
  String get videoMetadataInspiredByNone => 'Ninguno';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Usa esto para dar atribución. El crédito de inspiración es diferente de los colaboradores: reconoce la influencia, pero no etiqueta a alguien como co-creador.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'No se puede hacer referencia a este creador.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel =>
      'Eliminar inspirado en';

  @override
  String get videoMetadataPostDetailsTitle => 'Detalles de la publicación';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Guardado en la biblioteca';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'No se pudo guardar';

  @override
  String get videoMetadataGoToLibraryButton => 'Ir a la biblioteca';

  @override
  String get videoMetadataSaveForLaterSemanticLabel =>
      'Botón guardar para más tarde';

  @override
  String get videoMetadataRenderingVideoHint => 'Renderizando video...';

  @override
  String get videoMetadataSavingVideoHint => 'Guardando video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Guardar video en borradores y $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Guardar para más tarde';

  @override
  String get videoMetadataPostSemanticLabel => 'Botón publicar';

  @override
  String get videoMetadataPublishVideoHint => 'Publicar video en el feed';

  @override
  String get videoMetadataFormNotReadyHint =>
      'Completa el formulario para habilitar';

  @override
  String get videoMetadataPostButton => 'Publicar';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Abrir pantalla de vista previa de la publicación';

  @override
  String get videoMetadataShareTitle => 'Compartir';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Detalles del video';

  @override
  String get videoMetadataClassicDoneButton => 'Listo';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Reproducir vista previa';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pausar vista previa';

  @override
  String get videoMetadataClosePreviewSemanticLabel =>
      'Cerrar vista previa de video';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Eliminar';

  @override
  String get metadataCaptionsLabel => 'Subtítulos';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Subtítulos activados para todos los vídeos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Subtítulos desactivados para todos los vídeos';
}
