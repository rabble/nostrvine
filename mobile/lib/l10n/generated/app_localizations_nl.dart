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
  String get settingsSecureAccount => 'Secure Your Account';

  @override
  String get settingsSessionExpired => 'Session Expired';

  @override
  String get settingsSessionExpiredSubtitle =>
      'Sign in again to restore full access';

  @override
  String get settingsCreatorAnalytics => 'Creator Analytics';

  @override
  String get settingsSupportCenter => 'Support Center';

  @override
  String get settingsNotifications => 'Notifications';

  @override
  String get settingsContentPreferences => 'Content Preferences';

  @override
  String get settingsModerationControls => 'Moderation Controls';

  @override
  String get settingsBlueskyPublishing => 'Bluesky Publishing';

  @override
  String get settingsBlueskyPublishingSubtitle =>
      'Manage crossposting to Bluesky';

  @override
  String get settingsNostrSettings => 'Nostr Settings';

  @override
  String get settingsIntegratedApps => 'Integrated Apps';

  @override
  String get settingsIntegratedAppsSubtitle =>
      'Approved third-party apps that run inside Divine';

  @override
  String get settingsExperimentalFeatures => 'Experimental Features';

  @override
  String get settingsExperimentalFeaturesSubtitle =>
      'Tweaks that may hiccup—try them if you are curious.';

  @override
  String get settingsLegal => 'Legal';

  @override
  String get settingsIntegrationPermissions => 'Integration Permissions';

  @override
  String get settingsIntegrationPermissionsSubtitle =>
      'Review and revoke remembered integration approvals';

  @override
  String settingsVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsVersionEmpty => 'Version';

  @override
  String get settingsDeveloperModeAlreadyEnabled =>
      'Developer mode is already enabled';

  @override
  String get settingsDeveloperModeEnabled => 'Developer mode enabled!';

  @override
  String settingsDeveloperModeTapsRemaining(int count) {
    return '$count more taps to enable developer mode';
  }

  @override
  String get settingsInvites => 'Invites';

  @override
  String get settingsSwitchAccount => 'Switch account';

  @override
  String get settingsAddAnotherAccount => 'Add another account';

  @override
  String get settingsUnsavedDraftsTitle => 'Unsaved Drafts';

  @override
  String settingsUnsavedDraftsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'drafts',
      one: 'draft',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'drafts',
      one: 'draft',
    );
    String _temp2 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'them',
      one: 'it',
    );
    return 'You have $count unsaved $_temp0. Switching accounts will keep your $_temp1, but you may want to publish or review $_temp2 first.';
  }

  @override
  String get settingsCancel => 'Cancel';

  @override
  String get settingsSwitchAnyway => 'Switch Anyway';

  @override
  String get settingsAppVersionLabel => 'App version';

  @override
  String get contentPreferencesTitle => 'Content Preferences';

  @override
  String get contentPreferencesContentFilters => 'Content Filters';

  @override
  String get contentPreferencesContentFiltersSubtitle =>
      'Manage content warning filters';

  @override
  String get contentPreferencesContentLanguage => 'Content Language';

  @override
  String contentPreferencesContentLanguageDeviceDefault(String language) {
    return '$language (device default)';
  }

  @override
  String get contentPreferencesTagYourVideos =>
      'Tag your videos with a language so viewers can filter content.';

  @override
  String get contentPreferencesUseDeviceLanguage =>
      'Use device language (default)';

  @override
  String get contentPreferencesAudioSharing =>
      'Make my audio available for reuse';

  @override
  String get contentPreferencesAudioSharingSubtitle =>
      'When enabled, others can use audio from your videos';

  @override
  String get contentPreferencesAccountLabels => 'Account Labels';

  @override
  String get contentPreferencesAccountLabelsEmpty => 'Self-label your content';

  @override
  String get contentPreferencesAccountContentLabels => 'Account Content Labels';

  @override
  String get contentPreferencesClearAll => 'Clear All';

  @override
  String get contentPreferencesSelectAllThatApply =>
      'Select all that apply to your account';

  @override
  String get contentPreferencesDoneNoLabels => 'Done (No Labels)';

  @override
  String contentPreferencesDoneCount(int count) {
    return 'Done ($count selected)';
  }

  @override
  String get contentPreferencesAudioInputDevice => 'Audio Input Device';

  @override
  String get contentPreferencesAutoRecommended => 'Auto (recommended)';

  @override
  String get contentPreferencesAutoSelectsBest =>
      'Automatically selects the best microphone';

  @override
  String get contentPreferencesSelectAudioInput => 'Select Audio Input';

  @override
  String get contentPreferencesUnknownMicrophone => 'Unknown Microphone';
}
