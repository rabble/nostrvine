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
  String get settingsTitle => 'Configuración';

  @override
  String get settingsSecureAccount => 'Asegurá tu cuenta';

  @override
  String get settingsSessionExpired => 'Sesión expirada';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Iniciá sesión de nuevo para restaurar el acceso completo';

  @override
  String get settingsCreatorAnalytics => 'Estadísticas de creador';

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
      'Gestioná la publicación cruzada a Bluesky';

  @override
  String get settingsNostrSettings => 'Configuración de Nostr';

  @override
  String get settingsIntegratedApps => 'Apps integradas';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Apps de terceros aprobadas que corren dentro de Divine';

  @override
  String get settingsExperimentalFeatures => 'Funciones experimentales';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Ajustes que pueden fallar—probalos si tenés curiosidad.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Permisos de integración';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Revisá y revocá las aprobaciones de integración guardadas';

  @override
  String settingsVersion(String version) {
    return 'Versión $version';
  }

  @override
  String get settingsVersionEmpty => 'Versión';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'El modo desarrollador ya está habilitado';

  @override
  String get settingsDeveloperModeEnabled => '¡Modo desarrollador activado!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count toques más para habilitar el modo desarrollador';
  }

  @override
  String get settingsInvites => 'Invitaciones';

  @override
  String get settingsSwitchAccount => 'Cambiar cuenta';

  @override
  String get settingsAddAnotherAccount => 'Agregar otra cuenta';

  @override
  String get settingsUnsavedDraftsTitle => 'Borradores sin guardar';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'borradores',
      one: 'borrador',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'borradores',
      one: 'borrador',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'los',
      one: 'lo',
    );
    return 'Tenés $count $_temp0 sin guardar. Cambiar de cuenta va a mantener tus $_temp1, pero quizás querás publicar o revisar$_temp2 primero.';
  }

  @override
  String get settingsCancel => 'Cancelar';

  @override
  String get settingsSwitchAnyway => 'Cambiar igual';

  @override
  String get settingsAppVersionLabel => 'Versión de la app';

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
    return '$language (por defecto del dispositivo)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Etiquetá tus videos con un idioma para que los espectadores puedan filtrar contenido.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Usar idioma del dispositivo (por defecto)';

  @override
  String get contentPreferencesAudioSharing =>
      'Hacer mi audio disponible para reutilización';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'Cuando está habilitado, otros pueden usar el audio de tus videos';

  @override
  String get contentPreferencesAccountLabels => 'Etiquetas de cuenta';

  @override
  String get contentPreferencesAccountLabelsEmpty =>
      'Autoetiquetá tu contenido';

  @override
  String get contentPreferencesAccountContentLabels =>
      'Etiquetas de contenido de la cuenta';

  @override
  String get contentPreferencesClearAll => 'Limpiar todo';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Seleccioná todas las que apliquen a tu cuenta';

  @override
  String get contentPreferencesDoneNoLabels => 'Listo (Sin etiquetas)';

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
      'Selecciona automáticamente el mejor micrófono';

  @override
  String get contentPreferencesSelectAudioInput =>
      'Seleccionar entrada de audio';

  @override
  String get contentPreferencesUnknownMicrophone => 'Micrófono desconocido';
}
