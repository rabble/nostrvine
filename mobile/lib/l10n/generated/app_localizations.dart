import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_id.dart';
import 'app_localizations_it.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_nl.dart';
import 'app_localizations_pl.dart';
import 'app_localizations_pt.dart';
import 'app_localizations_ro.dart';
import 'app_localizations_sv.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'generated/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('id'),
    Locale('it'),
    Locale('ja'),
    Locale('ko'),
    Locale('nl'),
    Locale('pl'),
    Locale('pt'),
    Locale('ro'),
    Locale('sv'),
    Locale('tr'),
  ];

  /// App title shown in task switcher
  ///
  /// In en, this message translates to:
  /// **'Divine'**
  String get appTitle;

  /// Settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsSecureAccount.
  ///
  /// In en, this message translates to:
  /// **'Secure Your Account'**
  String get settingsSecureAccount;

  /// No description provided for @settingsSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get settingsSessionExpired;

  /// No description provided for @settingsSessionExpiredSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to restore full access'**
  String get settingsSessionExpiredSubtitle;

  /// No description provided for @settingsCreatorAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Creator Analytics'**
  String get settingsCreatorAnalytics;

  /// No description provided for @settingsSupportCenter.
  ///
  /// In en, this message translates to:
  /// **'Support Center'**
  String get settingsSupportCenter;

  /// No description provided for @settingsNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get settingsNotifications;

  /// No description provided for @settingsContentPreferences.
  ///
  /// In en, this message translates to:
  /// **'Content Preferences'**
  String get settingsContentPreferences;

  /// No description provided for @settingsModerationControls.
  ///
  /// In en, this message translates to:
  /// **'Moderation Controls'**
  String get settingsModerationControls;

  /// No description provided for @settingsBlueskyPublishing.
  ///
  /// In en, this message translates to:
  /// **'Bluesky Publishing'**
  String get settingsBlueskyPublishing;

  /// No description provided for @settingsBlueskyPublishingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage crossposting to Bluesky'**
  String get settingsBlueskyPublishingSubtitle;

  /// No description provided for @settingsNostrSettings.
  ///
  /// In en, this message translates to:
  /// **'Nostr Settings'**
  String get settingsNostrSettings;

  /// No description provided for @settingsIntegratedApps.
  ///
  /// In en, this message translates to:
  /// **'Integrated Apps'**
  String get settingsIntegratedApps;

  /// No description provided for @settingsIntegratedAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Approved third-party apps that run inside Divine'**
  String get settingsIntegratedAppsSubtitle;

  /// No description provided for @settingsExperimentalFeatures.
  ///
  /// In en, this message translates to:
  /// **'Experimental Features'**
  String get settingsExperimentalFeatures;

  /// No description provided for @settingsExperimentalFeaturesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tweaks that may hiccup—try them if you are curious.'**
  String get settingsExperimentalFeaturesSubtitle;

  /// No description provided for @settingsLegal.
  ///
  /// In en, this message translates to:
  /// **'Legal'**
  String get settingsLegal;

  /// No description provided for @settingsIntegrationPermissions.
  ///
  /// In en, this message translates to:
  /// **'Integration Permissions'**
  String get settingsIntegrationPermissions;

  /// No description provided for @settingsIntegrationPermissionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Review and revoke remembered integration approvals'**
  String get settingsIntegrationPermissionsSubtitle;

  /// App version label in settings footer
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String settingsVersion(String version);

  /// Version label when version string is not yet loaded
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get settingsVersionEmpty;

  /// No description provided for @settingsDeveloperModeAlreadyEnabled.
  ///
  /// In en, this message translates to:
  /// **'Developer mode is already enabled'**
  String get settingsDeveloperModeAlreadyEnabled;

  /// No description provided for @settingsDeveloperModeEnabled.
  ///
  /// In en, this message translates to:
  /// **'Developer mode enabled!'**
  String get settingsDeveloperModeEnabled;

  /// No description provided for @settingsDeveloperModeTapsRemaining.
  ///
  /// In en, this message translates to:
  /// **'{count} more taps to enable developer mode'**
  String settingsDeveloperModeTapsRemaining(int count);

  /// No description provided for @settingsInvites.
  ///
  /// In en, this message translates to:
  /// **'Invites'**
  String get settingsInvites;

  /// No description provided for @settingsSwitchAccount.
  ///
  /// In en, this message translates to:
  /// **'Switch account'**
  String get settingsSwitchAccount;

  /// No description provided for @settingsAddAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Add another account'**
  String get settingsAddAnotherAccount;

  /// No description provided for @settingsUnsavedDraftsTitle.
  ///
  /// In en, this message translates to:
  /// **'Unsaved Drafts'**
  String get settingsUnsavedDraftsTitle;

  /// No description provided for @settingsUnsavedDraftsMessage.
  ///
  /// In en, this message translates to:
  /// **'You have {count} unsaved {count, plural, =1{draft} other{drafts}}. Switching accounts will keep your {count, plural, =1{draft} other{drafts}}, but you may want to publish or review {count, plural, =1{it} other{them}} first.'**
  String settingsUnsavedDraftsMessage(int count);

  /// No description provided for @settingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get settingsCancel;

  /// No description provided for @settingsSwitchAnyway.
  ///
  /// In en, this message translates to:
  /// **'Switch Anyway'**
  String get settingsSwitchAnyway;

  /// No description provided for @settingsAppVersionLabel.
  ///
  /// In en, this message translates to:
  /// **'App version'**
  String get settingsAppVersionLabel;

  /// Content preferences screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Content Preferences'**
  String get contentPreferencesTitle;

  /// No description provided for @contentPreferencesContentFilters.
  ///
  /// In en, this message translates to:
  /// **'Content Filters'**
  String get contentPreferencesContentFilters;

  /// No description provided for @contentPreferencesContentFiltersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage content warning filters'**
  String get contentPreferencesContentFiltersSubtitle;

  /// No description provided for @contentPreferencesContentLanguage.
  ///
  /// In en, this message translates to:
  /// **'Content Language'**
  String get contentPreferencesContentLanguage;

  /// No description provided for @contentPreferencesContentLanguageDeviceDefault.
  ///
  /// In en, this message translates to:
  /// **'{language} (device default)'**
  String contentPreferencesContentLanguageDeviceDefault(String language);

  /// No description provided for @contentPreferencesTagYourVideos.
  ///
  /// In en, this message translates to:
  /// **'Tag your videos with a language so viewers can filter content.'**
  String get contentPreferencesTagYourVideos;

  /// No description provided for @contentPreferencesUseDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language (default)'**
  String get contentPreferencesUseDeviceLanguage;

  /// No description provided for @contentPreferencesAudioSharing.
  ///
  /// In en, this message translates to:
  /// **'Make my audio available for reuse'**
  String get contentPreferencesAudioSharing;

  /// No description provided for @contentPreferencesAudioSharingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When enabled, others can use audio from your videos'**
  String get contentPreferencesAudioSharingSubtitle;

  /// No description provided for @contentPreferencesAccountLabels.
  ///
  /// In en, this message translates to:
  /// **'Account Labels'**
  String get contentPreferencesAccountLabels;

  /// No description provided for @contentPreferencesAccountLabelsEmpty.
  ///
  /// In en, this message translates to:
  /// **'Self-label your content'**
  String get contentPreferencesAccountLabelsEmpty;

  /// No description provided for @contentPreferencesAccountContentLabels.
  ///
  /// In en, this message translates to:
  /// **'Account Content Labels'**
  String get contentPreferencesAccountContentLabels;

  /// No description provided for @contentPreferencesClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear All'**
  String get contentPreferencesClearAll;

  /// No description provided for @contentPreferencesSelectAllThatApply.
  ///
  /// In en, this message translates to:
  /// **'Select all that apply to your account'**
  String get contentPreferencesSelectAllThatApply;

  /// No description provided for @contentPreferencesDoneNoLabels.
  ///
  /// In en, this message translates to:
  /// **'Done (No Labels)'**
  String get contentPreferencesDoneNoLabels;

  /// No description provided for @contentPreferencesDoneCount.
  ///
  /// In en, this message translates to:
  /// **'Done ({count} selected)'**
  String contentPreferencesDoneCount(int count);

  /// No description provided for @contentPreferencesAudioInputDevice.
  ///
  /// In en, this message translates to:
  /// **'Audio Input Device'**
  String get contentPreferencesAudioInputDevice;

  /// No description provided for @contentPreferencesAutoRecommended.
  ///
  /// In en, this message translates to:
  /// **'Auto (recommended)'**
  String get contentPreferencesAutoRecommended;

  /// No description provided for @contentPreferencesAutoSelectsBest.
  ///
  /// In en, this message translates to:
  /// **'Automatically selects the best microphone'**
  String get contentPreferencesAutoSelectsBest;

  /// No description provided for @contentPreferencesSelectAudioInput.
  ///
  /// In en, this message translates to:
  /// **'Select Audio Input'**
  String get contentPreferencesSelectAudioInput;

  /// No description provided for @contentPreferencesUnknownMicrophone.
  ///
  /// In en, this message translates to:
  /// **'Unknown Microphone'**
  String get contentPreferencesUnknownMicrophone;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>[
    'ar',
    'de',
    'en',
    'es',
    'fr',
    'id',
    'it',
    'ja',
    'ko',
    'nl',
    'pl',
    'pt',
    'ro',
    'sv',
    'tr',
  ].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'id':
      return AppLocalizationsId();
    case 'it':
      return AppLocalizationsIt();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'nl':
      return AppLocalizationsNl();
    case 'pl':
      return AppLocalizationsPl();
    case 'pt':
      return AppLocalizationsPt();
    case 'ro':
      return AppLocalizationsRo();
    case 'sv':
      return AppLocalizationsSv();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
