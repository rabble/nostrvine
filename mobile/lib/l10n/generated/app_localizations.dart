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

  /// No description provided for @settingsAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguage;

  /// Subtitle for app language tile when using device default
  ///
  /// In en, this message translates to:
  /// **'{language} (device default)'**
  String settingsAppLanguageDeviceDefault(String language);

  /// Title shown at top of locale picker bottom sheet
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get settingsAppLanguageTitle;

  /// No description provided for @settingsAppLanguageDescription.
  ///
  /// In en, this message translates to:
  /// **'Choose the language for the app interface'**
  String get settingsAppLanguageDescription;

  /// No description provided for @settingsAppLanguageUseDeviceLanguage.
  ///
  /// In en, this message translates to:
  /// **'Use device language'**
  String get settingsAppLanguageUseDeviceLanguage;

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

  /// No description provided for @profileBlockedAccountNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'This account is not available'**
  String get profileBlockedAccountNotAvailable;

  /// No description provided for @profileErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String profileErrorPrefix(Object error);

  /// No description provided for @profileInvalidId.
  ///
  /// In en, this message translates to:
  /// **'Invalid profile ID'**
  String get profileInvalidId;

  /// No description provided for @profileShareText.
  ///
  /// In en, this message translates to:
  /// **'Check out {displayName} on Divine!\n\nhttps://divine.video/profile/{npub}'**
  String profileShareText(String displayName, String npub);

  /// No description provided for @profileShareSubject.
  ///
  /// In en, this message translates to:
  /// **'{displayName} on Divine'**
  String profileShareSubject(String displayName);

  /// No description provided for @profileShareFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to share profile: {error}'**
  String profileShareFailed(Object error);

  /// No description provided for @profileEditProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit profile'**
  String get profileEditProfile;

  /// No description provided for @profileCreatorAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Creator analytics'**
  String get profileCreatorAnalytics;

  /// No description provided for @profileShareProfile.
  ///
  /// In en, this message translates to:
  /// **'Share profile'**
  String get profileShareProfile;

  /// No description provided for @profileCopyPublicKey.
  ///
  /// In en, this message translates to:
  /// **'Copy public key (npub)'**
  String get profileCopyPublicKey;

  /// No description provided for @profileGetEmbedCode.
  ///
  /// In en, this message translates to:
  /// **'Get embed code'**
  String get profileGetEmbedCode;

  /// No description provided for @profilePublicKeyCopied.
  ///
  /// In en, this message translates to:
  /// **'Public key copied to clipboard'**
  String get profilePublicKeyCopied;

  /// No description provided for @profileEmbedCodeCopied.
  ///
  /// In en, this message translates to:
  /// **'Embed code copied to clipboard'**
  String get profileEmbedCodeCopied;

  /// No description provided for @profileRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get profileRefreshTooltip;

  /// No description provided for @profileRefreshSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Refresh profile'**
  String get profileRefreshSemanticLabel;

  /// No description provided for @profileMoreTooltip.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get profileMoreTooltip;

  /// No description provided for @profileMoreSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get profileMoreSemanticLabel;

  /// No description provided for @profileFollowingLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowingLabel;

  /// No description provided for @profileFollowLabel.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get profileFollowLabel;

  /// No description provided for @profileBlockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocked'**
  String get profileBlockedLabel;

  /// No description provided for @profileFollowersLabel.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get profileFollowersLabel;

  /// No description provided for @profileFollowingStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get profileFollowingStatLabel;

  /// No description provided for @profileVideosLabel.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get profileVideosLabel;

  /// No description provided for @profileFollowerCountUsers.
  ///
  /// In en, this message translates to:
  /// **'{count} users'**
  String profileFollowerCountUsers(int count);

  /// No description provided for @profileBlockTitle.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}?'**
  String profileBlockTitle(String displayName);

  /// No description provided for @profileBlockExplanation.
  ///
  /// In en, this message translates to:
  /// **'When you block a user:'**
  String get profileBlockExplanation;

  /// No description provided for @profileBlockBulletHidePosts.
  ///
  /// In en, this message translates to:
  /// **'Their posts will not appear in your feeds.'**
  String get profileBlockBulletHidePosts;

  /// No description provided for @profileBlockBulletCantView.
  ///
  /// In en, this message translates to:
  /// **'They will be unable to view your profile, follow you, or view your posts.'**
  String get profileBlockBulletCantView;

  /// No description provided for @profileBlockBulletNoNotify.
  ///
  /// In en, this message translates to:
  /// **'They will not be notified of this change.'**
  String get profileBlockBulletNoNotify;

  /// No description provided for @profileBlockBulletYouCanView.
  ///
  /// In en, this message translates to:
  /// **'You will still be able to view their profile.'**
  String get profileBlockBulletYouCanView;

  /// No description provided for @profileBlockConfirmButton.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}'**
  String profileBlockConfirmButton(String displayName);

  /// No description provided for @profileCancelButton.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get profileCancelButton;

  /// No description provided for @profileLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn More'**
  String get profileLearnMore;

  /// No description provided for @profileUnblockTitle.
  ///
  /// In en, this message translates to:
  /// **'Unblock {displayName}?'**
  String profileUnblockTitle(String displayName);

  /// No description provided for @profileUnblockExplanation.
  ///
  /// In en, this message translates to:
  /// **'When you unblock this user:'**
  String get profileUnblockExplanation;

  /// No description provided for @profileUnblockBulletShowPosts.
  ///
  /// In en, this message translates to:
  /// **'Their posts will appear in your feeds.'**
  String get profileUnblockBulletShowPosts;

  /// No description provided for @profileUnblockBulletCanView.
  ///
  /// In en, this message translates to:
  /// **'They will be able to view your profile, follow you, and view your posts.'**
  String get profileUnblockBulletCanView;

  /// No description provided for @profileUnblockBulletNoNotify.
  ///
  /// In en, this message translates to:
  /// **'They will not be notified of this change.'**
  String get profileUnblockBulletNoNotify;

  /// No description provided for @profileLearnMoreAt.
  ///
  /// In en, this message translates to:
  /// **'Learn more at '**
  String get profileLearnMoreAt;

  /// No description provided for @profileUnblockButton.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get profileUnblockButton;

  /// No description provided for @profileUnfollowDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Unfollow {displayName}'**
  String profileUnfollowDisplayName(String displayName);

  /// No description provided for @profileBlockDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Block {displayName}'**
  String profileBlockDisplayName(String displayName);

  /// No description provided for @profileUnblockDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Unblock {displayName}'**
  String profileUnblockDisplayName(String displayName);

  /// No description provided for @profileUserBlockedTitle.
  ///
  /// In en, this message translates to:
  /// **'User Blocked'**
  String get profileUserBlockedTitle;

  /// No description provided for @profileUserBlockedContent.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see content from this user in your feeds.'**
  String get profileUserBlockedContent;

  /// No description provided for @profileUserBlockedUnblockHint.
  ///
  /// In en, this message translates to:
  /// **'You can unblock them anytime from their profile or in Settings > Safety.'**
  String get profileUserBlockedUnblockHint;

  /// No description provided for @profileCloseButton.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get profileCloseButton;

  /// No description provided for @profileNoCollabsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Collabs Yet'**
  String get profileNoCollabsTitle;

  /// No description provided for @profileCollabsOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos you collaborate on will appear here'**
  String get profileCollabsOwnEmpty;

  /// No description provided for @profileCollabsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos they collaborate on will appear here'**
  String get profileCollabsOtherEmpty;

  /// No description provided for @profileErrorLoadingCollabs.
  ///
  /// In en, this message translates to:
  /// **'Error loading collab videos'**
  String get profileErrorLoadingCollabs;

  /// No description provided for @profileNoCommentsOwnTitle.
  ///
  /// In en, this message translates to:
  /// **'No Comments Yet'**
  String get profileNoCommentsOwnTitle;

  /// No description provided for @profileNoCommentsOtherTitle.
  ///
  /// In en, this message translates to:
  /// **'No Comments'**
  String get profileNoCommentsOtherTitle;

  /// No description provided for @profileCommentsOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Your comments and replies will appear here'**
  String get profileCommentsOwnEmpty;

  /// No description provided for @profileCommentsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Their comments and replies will appear here'**
  String get profileCommentsOtherEmpty;

  /// No description provided for @profileErrorLoadingComments.
  ///
  /// In en, this message translates to:
  /// **'Error loading comments'**
  String get profileErrorLoadingComments;

  /// No description provided for @profileVideoRepliesSection.
  ///
  /// In en, this message translates to:
  /// **'Video Replies'**
  String get profileVideoRepliesSection;

  /// No description provided for @profileCommentsSection.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get profileCommentsSection;

  /// No description provided for @profileEditLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get profileEditLabel;

  /// No description provided for @profileLibraryLabel.
  ///
  /// In en, this message translates to:
  /// **'Library'**
  String get profileLibraryLabel;

  /// No description provided for @profileNoLikedVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'No Liked Videos Yet'**
  String get profileNoLikedVideosTitle;

  /// No description provided for @profileLikedOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos you like will appear here'**
  String get profileLikedOwnEmpty;

  /// No description provided for @profileLikedOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos they like will appear here'**
  String get profileLikedOtherEmpty;

  /// No description provided for @profileErrorLoadingLiked.
  ///
  /// In en, this message translates to:
  /// **'Error loading liked videos'**
  String get profileErrorLoadingLiked;

  /// No description provided for @profileNoRepostsTitle.
  ///
  /// In en, this message translates to:
  /// **'No Reposts Yet'**
  String get profileNoRepostsTitle;

  /// No description provided for @profileRepostsOwnEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos you repost will appear here'**
  String get profileRepostsOwnEmpty;

  /// No description provided for @profileRepostsOtherEmpty.
  ///
  /// In en, this message translates to:
  /// **'Videos they repost will appear here'**
  String get profileRepostsOtherEmpty;

  /// No description provided for @profileErrorLoadingReposts.
  ///
  /// In en, this message translates to:
  /// **'Error loading reposted videos'**
  String get profileErrorLoadingReposts;

  /// No description provided for @profileLoadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Loading profile...'**
  String get profileLoadingTitle;

  /// No description provided for @profileLoadingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This may take a few moments'**
  String get profileLoadingSubtitle;

  /// No description provided for @profileLoadingVideos.
  ///
  /// In en, this message translates to:
  /// **'Loading videos...'**
  String get profileLoadingVideos;

  /// No description provided for @profileNoVideosTitle.
  ///
  /// In en, this message translates to:
  /// **'No Videos Yet'**
  String get profileNoVideosTitle;

  /// No description provided for @profileNoVideosOwnSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share your first video to see it here'**
  String get profileNoVideosOwnSubtitle;

  /// No description provided for @profileNoVideosOtherSubtitle.
  ///
  /// In en, this message translates to:
  /// **'This user hasn\'t shared any videos yet'**
  String get profileNoVideosOtherSubtitle;

  /// No description provided for @profileVideoThumbnailLabel.
  ///
  /// In en, this message translates to:
  /// **'Video thumbnail {number}'**
  String profileVideoThumbnailLabel(int number);

  /// No description provided for @profileShowMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get profileShowMore;

  /// No description provided for @profileShowLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get profileShowLess;

  /// No description provided for @profileCompleteYourProfile.
  ///
  /// In en, this message translates to:
  /// **'Complete Your Profile'**
  String get profileCompleteYourProfile;

  /// No description provided for @profileCompleteSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add your name, bio, and picture to get started'**
  String get profileCompleteSubtitle;

  /// No description provided for @profileSetUpButton.
  ///
  /// In en, this message translates to:
  /// **'Set Up'**
  String get profileSetUpButton;

  /// No description provided for @profileVerifyingEmail.
  ///
  /// In en, this message translates to:
  /// **'Verifying Email...'**
  String get profileVerifyingEmail;

  /// No description provided for @profileCheckEmailVerification.
  ///
  /// In en, this message translates to:
  /// **'Check {email} for verification link'**
  String profileCheckEmailVerification(String email);

  /// No description provided for @profileWaitingForVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for email verification'**
  String get profileWaitingForVerification;

  /// No description provided for @profileVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get profileVerificationFailed;

  /// No description provided for @profilePleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again'**
  String get profilePleaseTryAgain;

  /// No description provided for @profileSecureYourAccount.
  ///
  /// In en, this message translates to:
  /// **'Secure Your Account'**
  String get profileSecureYourAccount;

  /// No description provided for @profileSecureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add email & password to recover your account on any device'**
  String get profileSecureSubtitle;

  /// No description provided for @profileRetryButton.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get profileRetryButton;

  /// No description provided for @profileRegisterButton.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get profileRegisterButton;

  /// No description provided for @profileSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Session Expired'**
  String get profileSessionExpired;

  /// No description provided for @profileSignInToRestore.
  ///
  /// In en, this message translates to:
  /// **'Sign in again to restore full access'**
  String get profileSignInToRestore;

  /// No description provided for @profileSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get profileSignInButton;

  /// No description provided for @profileDismissTooltip.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get profileDismissTooltip;

  /// No description provided for @profileLinkCopied.
  ///
  /// In en, this message translates to:
  /// **'Profile link copied'**
  String get profileLinkCopied;

  /// No description provided for @profileSetupEditProfileTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get profileSetupEditProfileTitle;

  /// No description provided for @profileSetupBackLabel.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get profileSetupBackLabel;

  /// No description provided for @profileSetupAboutNostr.
  ///
  /// In en, this message translates to:
  /// **'About Nostr'**
  String get profileSetupAboutNostr;

  /// No description provided for @profileSetupProfilePublished.
  ///
  /// In en, this message translates to:
  /// **'Profile published successfully!'**
  String get profileSetupProfilePublished;

  /// No description provided for @profileSetupCreateNewProfile.
  ///
  /// In en, this message translates to:
  /// **'Create new profile?'**
  String get profileSetupCreateNewProfile;

  /// No description provided for @profileSetupNoExistingProfile.
  ///
  /// In en, this message translates to:
  /// **'We didn\'t find an existing profile on your relays. Publishing will create a new profile. Continue?'**
  String get profileSetupNoExistingProfile;

  /// No description provided for @profileSetupPublishButton.
  ///
  /// In en, this message translates to:
  /// **'Publish'**
  String get profileSetupPublishButton;

  /// No description provided for @profileSetupUsernameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username was just taken. Please choose another.'**
  String get profileSetupUsernameTaken;

  /// No description provided for @profileSetupClaimFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to claim username. Please try again.'**
  String get profileSetupClaimFailed;

  /// No description provided for @profileSetupPublishFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to publish profile. Please try again.'**
  String get profileSetupPublishFailed;

  /// No description provided for @profileSetupDisplayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display Name'**
  String get profileSetupDisplayNameLabel;

  /// No description provided for @profileSetupDisplayNameHint.
  ///
  /// In en, this message translates to:
  /// **'How should people know you?'**
  String get profileSetupDisplayNameHint;

  /// No description provided for @profileSetupDisplayNameHelper.
  ///
  /// In en, this message translates to:
  /// **'Any name or label you want. Doesn\'t have to be unique.'**
  String get profileSetupDisplayNameHelper;

  /// No description provided for @profileSetupDisplayNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a display name'**
  String get profileSetupDisplayNameRequired;

  /// No description provided for @profileSetupBioLabel.
  ///
  /// In en, this message translates to:
  /// **'Bio (Optional)'**
  String get profileSetupBioLabel;

  /// No description provided for @profileSetupBioHint.
  ///
  /// In en, this message translates to:
  /// **'Tell people about yourself...'**
  String get profileSetupBioHint;

  /// No description provided for @profileSetupPublicKeyLabel.
  ///
  /// In en, this message translates to:
  /// **'Public key (npub)'**
  String get profileSetupPublicKeyLabel;

  /// No description provided for @profileSetupUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Username (Optional)'**
  String get profileSetupUsernameLabel;

  /// No description provided for @profileSetupUsernameHint.
  ///
  /// In en, this message translates to:
  /// **'username'**
  String get profileSetupUsernameHint;

  /// No description provided for @profileSetupUsernameHelper.
  ///
  /// In en, this message translates to:
  /// **'Your unique identity on Divine'**
  String get profileSetupUsernameHelper;

  /// No description provided for @profileSetupProfileColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Profile Color (Optional)'**
  String get profileSetupProfileColorLabel;

  /// No description provided for @profileSetupSaveButton.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get profileSetupSaveButton;

  /// No description provided for @profileSetupSavingButton.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get profileSetupSavingButton;

  /// No description provided for @profileSetupImageUrlTitle.
  ///
  /// In en, this message translates to:
  /// **'Add image URL'**
  String get profileSetupImageUrlTitle;

  /// No description provided for @profileSetupPictureUploaded.
  ///
  /// In en, this message translates to:
  /// **'Profile picture uploaded successfully!'**
  String get profileSetupPictureUploaded;

  /// No description provided for @profileSetupImageSelectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Image selection failed. Please paste an image URL below instead.'**
  String get profileSetupImageSelectionFailed;

  /// No description provided for @profileSetupCameraAccessFailed.
  ///
  /// In en, this message translates to:
  /// **'Camera access failed: {error}'**
  String profileSetupCameraAccessFailed(Object error);

  /// No description provided for @profileSetupGotItButton.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get profileSetupGotItButton;

  /// No description provided for @profileSetupUploadFailedGeneric.
  ///
  /// In en, this message translates to:
  /// **'Failed to upload image: {error}'**
  String profileSetupUploadFailedGeneric(Object error);

  /// No description provided for @profileSetupUploadNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error: Please check your internet connection and try again.'**
  String get profileSetupUploadNetworkError;

  /// No description provided for @profileSetupUploadAuthError.
  ///
  /// In en, this message translates to:
  /// **'Authentication error: Please try logging out and back in.'**
  String get profileSetupUploadAuthError;

  /// No description provided for @profileSetupUploadFileTooLarge.
  ///
  /// In en, this message translates to:
  /// **'File too large: Please choose a smaller image (max 10MB).'**
  String get profileSetupUploadFileTooLarge;

  /// No description provided for @profileSetupUsernameChecking.
  ///
  /// In en, this message translates to:
  /// **'Checking availability...'**
  String get profileSetupUsernameChecking;

  /// No description provided for @profileSetupUsernameAvailable.
  ///
  /// In en, this message translates to:
  /// **'Username available!'**
  String get profileSetupUsernameAvailable;

  /// No description provided for @profileSetupUsernameTakenIndicator.
  ///
  /// In en, this message translates to:
  /// **'Username already taken'**
  String get profileSetupUsernameTakenIndicator;

  /// No description provided for @profileSetupUsernameReserved.
  ///
  /// In en, this message translates to:
  /// **'Username is reserved'**
  String get profileSetupUsernameReserved;

  /// No description provided for @profileSetupContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get profileSetupContactSupport;

  /// No description provided for @profileSetupCheckAgain.
  ///
  /// In en, this message translates to:
  /// **'Check again'**
  String get profileSetupCheckAgain;

  /// No description provided for @profileSetupUsernameBurned.
  ///
  /// In en, this message translates to:
  /// **'This username is no longer available'**
  String get profileSetupUsernameBurned;

  /// No description provided for @profileSetupUsernameInvalidFormat.
  ///
  /// In en, this message translates to:
  /// **'Only letters, numbers, and hyphens are allowed'**
  String get profileSetupUsernameInvalidFormat;

  /// No description provided for @profileSetupUsernameInvalidLength.
  ///
  /// In en, this message translates to:
  /// **'Username must be 3-20 characters'**
  String get profileSetupUsernameInvalidLength;

  /// No description provided for @profileSetupUsernameNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Could not check availability. Please try again.'**
  String get profileSetupUsernameNetworkError;

  /// No description provided for @profileSetupUsernameInvalidFormatGeneric.
  ///
  /// In en, this message translates to:
  /// **'Invalid username format'**
  String get profileSetupUsernameInvalidFormatGeneric;

  /// No description provided for @profileSetupUsernameCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to check availability'**
  String get profileSetupUsernameCheckFailed;

  /// No description provided for @profileSetupUsernameReservedTitle.
  ///
  /// In en, this message translates to:
  /// **'Username reserved'**
  String get profileSetupUsernameReservedTitle;

  /// No description provided for @profileSetupUsernameReservedBody.
  ///
  /// In en, this message translates to:
  /// **'The name {username} is reserved. Tell us why it should be yours.'**
  String profileSetupUsernameReservedBody(String username);

  /// No description provided for @profileSetupUsernameReservedHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. It\'s my brand name, stage name, etc.'**
  String get profileSetupUsernameReservedHint;

  /// No description provided for @profileSetupUsernameReservedCheckHint.
  ///
  /// In en, this message translates to:
  /// **'Already contacted support? Tap \"Check again\" to see if it\'s been released to you.'**
  String get profileSetupUsernameReservedCheckHint;

  /// No description provided for @profileSetupSupportRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Support request sent! We\'ll get back to you soon.'**
  String get profileSetupSupportRequestSent;

  /// No description provided for @profileSetupCouldntOpenEmail.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open email. Send to: names@divine.video'**
  String get profileSetupCouldntOpenEmail;

  /// No description provided for @profileSetupSendRequest.
  ///
  /// In en, this message translates to:
  /// **'Send request'**
  String get profileSetupSendRequest;

  /// No description provided for @profileSetupPickColorTitle.
  ///
  /// In en, this message translates to:
  /// **'Pick a color'**
  String get profileSetupPickColorTitle;

  /// No description provided for @profileSetupSelectButton.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get profileSetupSelectButton;

  /// No description provided for @profileSetupUseOwnNip05.
  ///
  /// In en, this message translates to:
  /// **'Use your own NIP-05 address'**
  String get profileSetupUseOwnNip05;

  /// No description provided for @profileSetupNip05AddressLabel.
  ///
  /// In en, this message translates to:
  /// **'NIP-05 Address'**
  String get profileSetupNip05AddressLabel;

  /// No description provided for @profileSetupProfilePicturePreview.
  ///
  /// In en, this message translates to:
  /// **'Profile picture preview'**
  String get profileSetupProfilePicturePreview;

  /// No description provided for @nostrInfoIntroBuiltOn.
  ///
  /// In en, this message translates to:
  /// **'DiVine is built on Nostr,'**
  String get nostrInfoIntroBuiltOn;

  /// No description provided for @nostrInfoIntroDescription.
  ///
  /// In en, this message translates to:
  /// **' a censorship-resistant open protocol that lets people communicate online without relying on a single company or platform. '**
  String get nostrInfoIntroDescription;

  /// No description provided for @nostrInfoIntroIdentity.
  ///
  /// In en, this message translates to:
  /// **'When you sign up for Divine, you get a new Nostr identity.'**
  String get nostrInfoIntroIdentity;

  /// No description provided for @nostrInfoOwnership.
  ///
  /// In en, this message translates to:
  /// **'Nostr lets you own your content, identity and social graph, which you can use across many apps. The result is more choice, less lock-in, and a healthier, more resilient social internet.'**
  String get nostrInfoOwnership;

  /// No description provided for @nostrInfoLingo.
  ///
  /// In en, this message translates to:
  /// **'Nostr lingo:'**
  String get nostrInfoLingo;

  /// No description provided for @nostrInfoNpubLabel.
  ///
  /// In en, this message translates to:
  /// **'npub:'**
  String get nostrInfoNpubLabel;

  /// No description provided for @nostrInfoNpubDescription.
  ///
  /// In en, this message translates to:
  /// **' Your public Nostr address. It\'s safe to share and lets others find, follow, or message you across Nostr apps.'**
  String get nostrInfoNpubDescription;

  /// No description provided for @nostrInfoNsecLabel.
  ///
  /// In en, this message translates to:
  /// **'nsec:'**
  String get nostrInfoNsecLabel;

  /// No description provided for @nostrInfoNsecDescription.
  ///
  /// In en, this message translates to:
  /// **' Your private key and proof of ownership. It gives full control of your Nostr identity, so '**
  String get nostrInfoNsecDescription;

  /// No description provided for @nostrInfoNsecWarning.
  ///
  /// In en, this message translates to:
  /// **'always keep it secret!'**
  String get nostrInfoNsecWarning;

  /// No description provided for @nostrInfoUsernameLabel.
  ///
  /// In en, this message translates to:
  /// **'Nostr username:'**
  String get nostrInfoUsernameLabel;

  /// No description provided for @nostrInfoUsernameDescription.
  ///
  /// In en, this message translates to:
  /// **' A human-readable name (like @name.divine.video) that links to your npub. It makes your Nostr identity easier to recognize and verify, similar to an email address.'**
  String get nostrInfoUsernameDescription;

  /// No description provided for @nostrInfoLearnMoreAt.
  ///
  /// In en, this message translates to:
  /// **'Learn more at '**
  String get nostrInfoLearnMoreAt;

  /// No description provided for @nostrInfoGotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it!'**
  String get nostrInfoGotIt;

  /// No description provided for @profileTabRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get profileTabRefreshTooltip;

  /// No description provided for @videoGridRefreshLabel.
  ///
  /// In en, this message translates to:
  /// **'Searching for more videos'**
  String get videoGridRefreshLabel;

  /// No description provided for @videoGridOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Video Options'**
  String get videoGridOptionsTitle;

  /// No description provided for @videoGridEditVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit Video'**
  String get videoGridEditVideo;

  /// No description provided for @videoGridEditVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update title, description, and hashtags'**
  String get videoGridEditVideoSubtitle;

  /// No description provided for @videoGridDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete Video'**
  String get videoGridDeleteVideo;

  /// No description provided for @videoGridDeleteVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this content'**
  String get videoGridDeleteVideoSubtitle;

  /// No description provided for @videoGridDeleteConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Video'**
  String get videoGridDeleteConfirmTitle;

  /// No description provided for @videoGridDeleteConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this video?'**
  String get videoGridDeleteConfirmMessage;

  /// No description provided for @videoGridDeleteConfirmNote.
  ///
  /// In en, this message translates to:
  /// **'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.'**
  String get videoGridDeleteConfirmNote;

  /// No description provided for @videoGridDeleteCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get videoGridDeleteCancel;

  /// No description provided for @videoGridDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get videoGridDeleteConfirm;

  /// No description provided for @videoGridDeletingContent.
  ///
  /// In en, this message translates to:
  /// **'Deleting content...'**
  String get videoGridDeletingContent;

  /// No description provided for @videoGridDeleteSuccess.
  ///
  /// In en, this message translates to:
  /// **'Delete request sent successfully'**
  String get videoGridDeleteSuccess;

  /// No description provided for @videoGridDeleteFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete content: {error}'**
  String videoGridDeleteFailure(Object error);

  /// No description provided for @exploreTabClassics.
  ///
  /// In en, this message translates to:
  /// **'Classics'**
  String get exploreTabClassics;

  /// No description provided for @exploreTabNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get exploreTabNew;

  /// No description provided for @exploreTabPopular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get exploreTabPopular;

  /// No description provided for @exploreTabCategories.
  ///
  /// In en, this message translates to:
  /// **'Categories'**
  String get exploreTabCategories;

  /// No description provided for @exploreTabForYou.
  ///
  /// In en, this message translates to:
  /// **'For You'**
  String get exploreTabForYou;

  /// No description provided for @exploreTabLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get exploreTabLists;

  /// No description provided for @exploreTabIntegratedApps.
  ///
  /// In en, this message translates to:
  /// **'Integrated Apps'**
  String get exploreTabIntegratedApps;

  /// No description provided for @exploreNoVideosAvailable.
  ///
  /// In en, this message translates to:
  /// **'No videos available'**
  String get exploreNoVideosAvailable;

  /// No description provided for @exploreErrorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String exploreErrorPrefix(Object error);

  /// No description provided for @exploreDiscoverLists.
  ///
  /// In en, this message translates to:
  /// **'Discover Lists'**
  String get exploreDiscoverLists;

  /// No description provided for @exploreAboutLists.
  ///
  /// In en, this message translates to:
  /// **'About Lists'**
  String get exploreAboutLists;

  /// No description provided for @exploreAboutListsDescription.
  ///
  /// In en, this message translates to:
  /// **'Lists help you organize and curate Divine content in two ways:'**
  String get exploreAboutListsDescription;

  /// No description provided for @explorePeopleLists.
  ///
  /// In en, this message translates to:
  /// **'People Lists'**
  String get explorePeopleLists;

  /// No description provided for @explorePeopleListsDescription.
  ///
  /// In en, this message translates to:
  /// **'Follow groups of creators and see their latest videos'**
  String get explorePeopleListsDescription;

  /// No description provided for @exploreVideoLists.
  ///
  /// In en, this message translates to:
  /// **'Video Lists'**
  String get exploreVideoLists;

  /// No description provided for @exploreVideoListsDescription.
  ///
  /// In en, this message translates to:
  /// **'Create playlists of your favorite videos to watch later'**
  String get exploreVideoListsDescription;

  /// No description provided for @exploreMyLists.
  ///
  /// In en, this message translates to:
  /// **'My Lists'**
  String get exploreMyLists;

  /// No description provided for @exploreSubscribedLists.
  ///
  /// In en, this message translates to:
  /// **'Subscribed Lists'**
  String get exploreSubscribedLists;

  /// No description provided for @exploreErrorLoadingLists.
  ///
  /// In en, this message translates to:
  /// **'Error loading lists: {error}'**
  String exploreErrorLoadingLists(Object error);

  /// No description provided for @exploreNewVideosCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 new video} other{{count} new videos}}'**
  String exploreNewVideosCount(int count);

  /// No description provided for @exploreLoadNewVideosLabel.
  ///
  /// In en, this message translates to:
  /// **'Load {count} new {count, plural, =1{video} other{videos}}'**
  String exploreLoadNewVideosLabel(int count);

  /// No description provided for @videoPlayerLoadingVideo.
  ///
  /// In en, this message translates to:
  /// **'Loading video...'**
  String get videoPlayerLoadingVideo;

  /// No description provided for @videoPlayerPlayVideo.
  ///
  /// In en, this message translates to:
  /// **'Play video'**
  String get videoPlayerPlayVideo;

  /// No description provided for @videoPlayerEditVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get videoPlayerEditVideo;

  /// No description provided for @videoPlayerEditVideoTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit video'**
  String get videoPlayerEditVideoTooltip;

  /// No description provided for @contentWarningLabel.
  ///
  /// In en, this message translates to:
  /// **'Content Warning'**
  String get contentWarningLabel;

  /// No description provided for @contentWarningNudity.
  ///
  /// In en, this message translates to:
  /// **'Nudity'**
  String get contentWarningNudity;

  /// No description provided for @contentWarningSexualContent.
  ///
  /// In en, this message translates to:
  /// **'Sexual Content'**
  String get contentWarningSexualContent;

  /// No description provided for @contentWarningPornography.
  ///
  /// In en, this message translates to:
  /// **'Pornography'**
  String get contentWarningPornography;

  /// No description provided for @contentWarningGraphicMedia.
  ///
  /// In en, this message translates to:
  /// **'Graphic Media'**
  String get contentWarningGraphicMedia;

  /// No description provided for @contentWarningViolence.
  ///
  /// In en, this message translates to:
  /// **'Violence'**
  String get contentWarningViolence;

  /// No description provided for @contentWarningSelfHarm.
  ///
  /// In en, this message translates to:
  /// **'Self-Harm'**
  String get contentWarningSelfHarm;

  /// No description provided for @contentWarningDrugUse.
  ///
  /// In en, this message translates to:
  /// **'Drug Use'**
  String get contentWarningDrugUse;

  /// No description provided for @contentWarningAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Alcohol'**
  String get contentWarningAlcohol;

  /// No description provided for @contentWarningTobacco.
  ///
  /// In en, this message translates to:
  /// **'Tobacco'**
  String get contentWarningTobacco;

  /// No description provided for @contentWarningGambling.
  ///
  /// In en, this message translates to:
  /// **'Gambling'**
  String get contentWarningGambling;

  /// No description provided for @contentWarningProfanity.
  ///
  /// In en, this message translates to:
  /// **'Profanity'**
  String get contentWarningProfanity;

  /// No description provided for @contentWarningFlashingLights.
  ///
  /// In en, this message translates to:
  /// **'Flashing Lights'**
  String get contentWarningFlashingLights;

  /// No description provided for @contentWarningAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'AI-Generated'**
  String get contentWarningAiGenerated;

  /// No description provided for @contentWarningSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Spoiler'**
  String get contentWarningSpoiler;

  /// No description provided for @contentWarningSensitiveContent.
  ///
  /// In en, this message translates to:
  /// **'Sensitive Content'**
  String get contentWarningSensitiveContent;

  /// No description provided for @contentWarningDescNudity.
  ///
  /// In en, this message translates to:
  /// **'Contains nudity or partial nudity'**
  String get contentWarningDescNudity;

  /// No description provided for @contentWarningDescSexual.
  ///
  /// In en, this message translates to:
  /// **'Contains sexual content'**
  String get contentWarningDescSexual;

  /// No description provided for @contentWarningDescPorn.
  ///
  /// In en, this message translates to:
  /// **'Contains explicit pornographic content'**
  String get contentWarningDescPorn;

  /// No description provided for @contentWarningDescGraphicMedia.
  ///
  /// In en, this message translates to:
  /// **'Contains graphic or disturbing imagery'**
  String get contentWarningDescGraphicMedia;

  /// No description provided for @contentWarningDescViolence.
  ///
  /// In en, this message translates to:
  /// **'Contains violent content'**
  String get contentWarningDescViolence;

  /// No description provided for @contentWarningDescSelfHarm.
  ///
  /// In en, this message translates to:
  /// **'Contains references to self-harm'**
  String get contentWarningDescSelfHarm;

  /// No description provided for @contentWarningDescDrugs.
  ///
  /// In en, this message translates to:
  /// **'Contains drug-related content'**
  String get contentWarningDescDrugs;

  /// No description provided for @contentWarningDescAlcohol.
  ///
  /// In en, this message translates to:
  /// **'Contains alcohol-related content'**
  String get contentWarningDescAlcohol;

  /// No description provided for @contentWarningDescTobacco.
  ///
  /// In en, this message translates to:
  /// **'Contains tobacco-related content'**
  String get contentWarningDescTobacco;

  /// No description provided for @contentWarningDescGambling.
  ///
  /// In en, this message translates to:
  /// **'Contains gambling-related content'**
  String get contentWarningDescGambling;

  /// No description provided for @contentWarningDescProfanity.
  ///
  /// In en, this message translates to:
  /// **'Contains strong language'**
  String get contentWarningDescProfanity;

  /// No description provided for @contentWarningDescFlashingLights.
  ///
  /// In en, this message translates to:
  /// **'Contains flashing lights (photosensitivity warning)'**
  String get contentWarningDescFlashingLights;

  /// No description provided for @contentWarningDescAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'This content was generated by AI'**
  String get contentWarningDescAiGenerated;

  /// No description provided for @contentWarningDescSpoiler.
  ///
  /// In en, this message translates to:
  /// **'Contains spoilers'**
  String get contentWarningDescSpoiler;

  /// No description provided for @contentWarningDescContentWarning.
  ///
  /// In en, this message translates to:
  /// **'Creator marked this as sensitive'**
  String get contentWarningDescContentWarning;

  /// No description provided for @contentWarningDescDefault.
  ///
  /// In en, this message translates to:
  /// **'Creator flagged this content'**
  String get contentWarningDescDefault;

  /// No description provided for @contentWarningDetailsTitle.
  ///
  /// In en, this message translates to:
  /// **'Content Warnings'**
  String get contentWarningDetailsTitle;

  /// No description provided for @contentWarningDetailsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'The creator applied these labels:'**
  String get contentWarningDetailsSubtitle;

  /// No description provided for @contentWarningManageFilters.
  ///
  /// In en, this message translates to:
  /// **'Manage content filters'**
  String get contentWarningManageFilters;

  /// No description provided for @contentWarningViewAnyway.
  ///
  /// In en, this message translates to:
  /// **'View Anyway'**
  String get contentWarningViewAnyway;

  /// No description provided for @contentWarningHideAllLikeThis.
  ///
  /// In en, this message translates to:
  /// **'Hide all content like this'**
  String get contentWarningHideAllLikeThis;

  /// No description provided for @contentWarningNoFilterYet.
  ///
  /// In en, this message translates to:
  /// **'No saved filter for this warning yet.'**
  String get contentWarningNoFilterYet;

  /// No description provided for @contentWarningHiddenConfirmation.
  ///
  /// In en, this message translates to:
  /// **'We\'ll hide posts like this from now on.'**
  String get contentWarningHiddenConfirmation;

  /// No description provided for @videoErrorNotFound.
  ///
  /// In en, this message translates to:
  /// **'Video not found'**
  String get videoErrorNotFound;

  /// No description provided for @videoErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Network error'**
  String get videoErrorNetwork;

  /// No description provided for @videoErrorTimeout.
  ///
  /// In en, this message translates to:
  /// **'Loading timeout'**
  String get videoErrorTimeout;

  /// No description provided for @videoErrorFormat.
  ///
  /// In en, this message translates to:
  /// **'Video format error\n(Try again or use different browser)'**
  String get videoErrorFormat;

  /// No description provided for @videoErrorUnsupportedFormat.
  ///
  /// In en, this message translates to:
  /// **'Unsupported video format'**
  String get videoErrorUnsupportedFormat;

  /// No description provided for @videoErrorPlayback.
  ///
  /// In en, this message translates to:
  /// **'Video playback error'**
  String get videoErrorPlayback;

  /// No description provided for @videoErrorAgeRestricted.
  ///
  /// In en, this message translates to:
  /// **'Age-restricted content'**
  String get videoErrorAgeRestricted;

  /// No description provided for @videoErrorVerifyAge.
  ///
  /// In en, this message translates to:
  /// **'Verify Age'**
  String get videoErrorVerifyAge;

  /// No description provided for @videoErrorRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get videoErrorRetry;

  /// No description provided for @videoErrorContentRestricted.
  ///
  /// In en, this message translates to:
  /// **'Content restricted'**
  String get videoErrorContentRestricted;

  /// No description provided for @videoErrorContentRestrictedBody.
  ///
  /// In en, this message translates to:
  /// **'This video was restricted by the relay.'**
  String get videoErrorContentRestrictedBody;

  /// No description provided for @videoErrorVerifyAgeBody.
  ///
  /// In en, this message translates to:
  /// **'Verify your age to view this video.'**
  String get videoErrorVerifyAgeBody;

  /// No description provided for @videoErrorSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get videoErrorSkip;

  /// No description provided for @videoErrorVerifyAgeButton.
  ///
  /// In en, this message translates to:
  /// **'Verify age'**
  String get videoErrorVerifyAgeButton;

  /// No description provided for @videoFollowButtonFollowing.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get videoFollowButtonFollowing;

  /// No description provided for @videoFollowButtonFollow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get videoFollowButtonFollow;

  /// No description provided for @audioAttributionOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original sound'**
  String get audioAttributionOriginalSound;

  /// No description provided for @videoInspiredByAttribution.
  ///
  /// In en, this message translates to:
  /// **'Inspired by @{creatorName}'**
  String videoInspiredByAttribution(String creatorName);

  /// No description provided for @videoCollaboratorWithOne.
  ///
  /// In en, this message translates to:
  /// **'with @{name}'**
  String videoCollaboratorWithOne(String name);

  /// No description provided for @videoCollaboratorWithMore.
  ///
  /// In en, this message translates to:
  /// **'with @{name} +{count}'**
  String videoCollaboratorWithMore(String name, int count);

  /// No description provided for @videoCollaboratorCountLabel.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 collaborator} other{{count} collaborators}}. Tap to view profile.'**
  String videoCollaboratorCountLabel(int count);

  /// No description provided for @listAttributionFallback.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get listAttributionFallback;

  /// No description provided for @shareVideoLabel.
  ///
  /// In en, this message translates to:
  /// **'Share video'**
  String get shareVideoLabel;

  /// No description provided for @sharePostSharedWith.
  ///
  /// In en, this message translates to:
  /// **'Post shared with {recipientName}'**
  String sharePostSharedWith(String recipientName);

  /// No description provided for @shareFailedToSend.
  ///
  /// In en, this message translates to:
  /// **'Failed to send video'**
  String get shareFailedToSend;

  /// No description provided for @shareAddedToBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Added to bookmarks'**
  String get shareAddedToBookmarks;

  /// No description provided for @shareFailedToAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to add bookmark'**
  String get shareFailedToAddBookmark;

  /// No description provided for @shareActionFailed.
  ///
  /// In en, this message translates to:
  /// **'Action failed'**
  String get shareActionFailed;

  /// No description provided for @shareWithTitle.
  ///
  /// In en, this message translates to:
  /// **'Share with'**
  String get shareWithTitle;

  /// No description provided for @shareFindPeople.
  ///
  /// In en, this message translates to:
  /// **'Find people'**
  String get shareFindPeople;

  /// No description provided for @shareFindPeopleMultiline.
  ///
  /// In en, this message translates to:
  /// **'Find\npeople'**
  String get shareFindPeopleMultiline;

  /// No description provided for @shareSent.
  ///
  /// In en, this message translates to:
  /// **'Sent'**
  String get shareSent;

  /// No description provided for @shareContactFallback.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get shareContactFallback;

  /// No description provided for @shareUserFallback.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get shareUserFallback;

  /// No description provided for @shareSendingTo.
  ///
  /// In en, this message translates to:
  /// **'Sending to {name}'**
  String shareSendingTo(String name);

  /// No description provided for @shareMessageHint.
  ///
  /// In en, this message translates to:
  /// **'Add optional message...'**
  String get shareMessageHint;

  /// No description provided for @videoActionUnlike.
  ///
  /// In en, this message translates to:
  /// **'Unlike video'**
  String get videoActionUnlike;

  /// No description provided for @videoActionLike.
  ///
  /// In en, this message translates to:
  /// **'Like video'**
  String get videoActionLike;

  /// No description provided for @videoActionRemoveRepost.
  ///
  /// In en, this message translates to:
  /// **'Remove repost'**
  String get videoActionRemoveRepost;

  /// No description provided for @videoActionRepost.
  ///
  /// In en, this message translates to:
  /// **'Repost video'**
  String get videoActionRepost;

  /// No description provided for @videoActionViewComments.
  ///
  /// In en, this message translates to:
  /// **'View comments'**
  String get videoActionViewComments;

  /// No description provided for @videoActionMoreOptions.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get videoActionMoreOptions;

  /// No description provided for @videoActionHideSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Hide subtitles'**
  String get videoActionHideSubtitles;

  /// No description provided for @videoActionShowSubtitles.
  ///
  /// In en, this message translates to:
  /// **'Show subtitles'**
  String get videoActionShowSubtitles;

  /// No description provided for @videoDescriptionLoops.
  ///
  /// In en, this message translates to:
  /// **'{count} loops'**
  String videoDescriptionLoops(String count);

  /// No description provided for @metadataBadgeNotDivine.
  ///
  /// In en, this message translates to:
  /// **'Not Divine'**
  String get metadataBadgeNotDivine;

  /// No description provided for @metadataBadgeHumanMade.
  ///
  /// In en, this message translates to:
  /// **'Human-Made'**
  String get metadataBadgeHumanMade;

  /// No description provided for @metadataSoundsLabel.
  ///
  /// In en, this message translates to:
  /// **'Sounds'**
  String get metadataSoundsLabel;

  /// No description provided for @metadataOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original sound'**
  String get metadataOriginalSound;

  /// No description provided for @metadataVerificationLabel.
  ///
  /// In en, this message translates to:
  /// **'Verification'**
  String get metadataVerificationLabel;

  /// No description provided for @metadataDeviceAttestation.
  ///
  /// In en, this message translates to:
  /// **'Device attestation'**
  String get metadataDeviceAttestation;

  /// No description provided for @metadataProofManifest.
  ///
  /// In en, this message translates to:
  /// **'Proof manifest'**
  String get metadataProofManifest;

  /// No description provided for @metadataCreatorLabel.
  ///
  /// In en, this message translates to:
  /// **'Creator'**
  String get metadataCreatorLabel;

  /// No description provided for @metadataCollaboratorsLabel.
  ///
  /// In en, this message translates to:
  /// **'Collaborators'**
  String get metadataCollaboratorsLabel;

  /// No description provided for @metadataInspiredByLabel.
  ///
  /// In en, this message translates to:
  /// **'Inspired by'**
  String get metadataInspiredByLabel;

  /// No description provided for @metadataRepostedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Reposted by'**
  String get metadataRepostedByLabel;

  /// No description provided for @metadataLoopsLabel.
  ///
  /// In en, this message translates to:
  /// **'Loops'**
  String get metadataLoopsLabel;

  /// No description provided for @metadataLikesLabel.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get metadataLikesLabel;

  /// No description provided for @metadataCommentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get metadataCommentsLabel;

  /// No description provided for @metadataRepostsLabel.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get metadataRepostsLabel;

  /// Developer options screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Developer Options'**
  String get devOptionsTitle;

  /// No description provided for @devOptionsPageLoadTimes.
  ///
  /// In en, this message translates to:
  /// **'Page Load Times'**
  String get devOptionsPageLoadTimes;

  /// No description provided for @devOptionsNoPageLoads.
  ///
  /// In en, this message translates to:
  /// **'No page loads recorded yet.\nNavigate around the app to see timing data.'**
  String get devOptionsNoPageLoads;

  /// No description provided for @devOptionsPageLoadVisible.
  ///
  /// In en, this message translates to:
  /// **'Visible: {visibleMs}ms  |  Data: {dataMs}ms'**
  String devOptionsPageLoadVisible(String visibleMs, String dataMs);

  /// No description provided for @devOptionsSlowestScreens.
  ///
  /// In en, this message translates to:
  /// **'Slowest Screens'**
  String get devOptionsSlowestScreens;

  /// No description provided for @devOptionsVideoPlaybackFormat.
  ///
  /// In en, this message translates to:
  /// **'Video Playback Format'**
  String get devOptionsVideoPlaybackFormat;

  /// No description provided for @devOptionsSwitchEnvironmentTitle.
  ///
  /// In en, this message translates to:
  /// **'Switch Environment?'**
  String get devOptionsSwitchEnvironmentTitle;

  /// No description provided for @devOptionsSwitchEnvironmentMessage.
  ///
  /// In en, this message translates to:
  /// **'Switch to {envName}?\n\nThis will clear cached video data and reconnect to the new relay.'**
  String devOptionsSwitchEnvironmentMessage(String envName);

  /// No description provided for @devOptionsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get devOptionsCancel;

  /// No description provided for @devOptionsSwitch.
  ///
  /// In en, this message translates to:
  /// **'Switch'**
  String get devOptionsSwitch;

  /// No description provided for @devOptionsSwitchedTo.
  ///
  /// In en, this message translates to:
  /// **'Switched to {envName}'**
  String devOptionsSwitchedTo(String envName);

  /// No description provided for @devOptionsSwitchedFormat.
  ///
  /// In en, this message translates to:
  /// **'Switched to {formatName} — cache cleared'**
  String devOptionsSwitchedFormat(String formatName);

  /// Feature flags screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Feature Flags'**
  String get featureFlagTitle;

  /// No description provided for @featureFlagResetAllTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset all flags to defaults'**
  String get featureFlagResetAllTooltip;

  /// No description provided for @featureFlagResetToDefault.
  ///
  /// In en, this message translates to:
  /// **'Reset to default'**
  String get featureFlagResetToDefault;

  /// No description provided for @featureFlagAppRecovery.
  ///
  /// In en, this message translates to:
  /// **'App Recovery'**
  String get featureFlagAppRecovery;

  /// No description provided for @featureFlagAppRecoveryDescription.
  ///
  /// In en, this message translates to:
  /// **'If the app is crashing or behaving strangely, try clearing the cache.'**
  String get featureFlagAppRecoveryDescription;

  /// No description provided for @featureFlagClearAllCache.
  ///
  /// In en, this message translates to:
  /// **'Clear All Cache'**
  String get featureFlagClearAllCache;

  /// No description provided for @featureFlagCacheInfo.
  ///
  /// In en, this message translates to:
  /// **'Cache Info'**
  String get featureFlagCacheInfo;

  /// No description provided for @featureFlagClearCacheTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Cache?'**
  String get featureFlagClearCacheTitle;

  /// No description provided for @featureFlagClearCacheMessage.
  ///
  /// In en, this message translates to:
  /// **'This will clear all cached data including:\n• Notifications\n• User profiles\n• Bookmarks\n• Temporary files\n\nYou will need to log in again. Continue?'**
  String get featureFlagClearCacheMessage;

  /// No description provided for @featureFlagClearCache.
  ///
  /// In en, this message translates to:
  /// **'Clear Cache'**
  String get featureFlagClearCache;

  /// No description provided for @featureFlagClearingCache.
  ///
  /// In en, this message translates to:
  /// **'Clearing cache...'**
  String get featureFlagClearingCache;

  /// No description provided for @featureFlagSuccess.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get featureFlagSuccess;

  /// No description provided for @featureFlagError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get featureFlagError;

  /// No description provided for @featureFlagClearCacheSuccess.
  ///
  /// In en, this message translates to:
  /// **'Cache cleared successfully. Please restart the app.'**
  String get featureFlagClearCacheSuccess;

  /// No description provided for @featureFlagClearCacheFailure.
  ///
  /// In en, this message translates to:
  /// **'Failed to clear some cache items. Check logs for details.'**
  String get featureFlagClearCacheFailure;

  /// No description provided for @featureFlagOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get featureFlagOk;

  /// No description provided for @featureFlagCacheInformation.
  ///
  /// In en, this message translates to:
  /// **'Cache Information'**
  String get featureFlagCacheInformation;

  /// No description provided for @featureFlagTotalCacheSize.
  ///
  /// In en, this message translates to:
  /// **'Total cache size: {size}'**
  String featureFlagTotalCacheSize(String size);

  /// No description provided for @featureFlagCacheIncludes.
  ///
  /// In en, this message translates to:
  /// **'Cache includes:\n• Notification history\n• User profile data\n• Video thumbnails\n• Temporary files\n• Database indexes'**
  String get featureFlagCacheIncludes;

  /// Relay settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Relays'**
  String get relaySettingsTitle;

  /// No description provided for @relaySettingsInfoTitle.
  ///
  /// In en, this message translates to:
  /// **'Divine is an open system - you control your connections'**
  String get relaySettingsInfoTitle;

  /// No description provided for @relaySettingsInfoDescription.
  ///
  /// In en, this message translates to:
  /// **'These relays distribute your content across the decentralized Nostr network. You can add or remove relays as you wish.'**
  String get relaySettingsInfoDescription;

  /// No description provided for @relaySettingsLearnMoreNostr.
  ///
  /// In en, this message translates to:
  /// **'Learn more about Nostr →'**
  String get relaySettingsLearnMoreNostr;

  /// No description provided for @relaySettingsFindPublicRelays.
  ///
  /// In en, this message translates to:
  /// **'Find public relays at nostr.co.uk →'**
  String get relaySettingsFindPublicRelays;

  /// No description provided for @relaySettingsAppNotFunctional.
  ///
  /// In en, this message translates to:
  /// **'App Not Functional'**
  String get relaySettingsAppNotFunctional;

  /// No description provided for @relaySettingsRequiresRelay.
  ///
  /// In en, this message translates to:
  /// **'Divine requires at least one relay to load videos, post content, and sync data.'**
  String get relaySettingsRequiresRelay;

  /// No description provided for @relaySettingsRestoreDefaultRelay.
  ///
  /// In en, this message translates to:
  /// **'Restore Default Relay'**
  String get relaySettingsRestoreDefaultRelay;

  /// No description provided for @relaySettingsAddCustomRelay.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Relay'**
  String get relaySettingsAddCustomRelay;

  /// No description provided for @relaySettingsAddRelay.
  ///
  /// In en, this message translates to:
  /// **'Add Relay'**
  String get relaySettingsAddRelay;

  /// No description provided for @relaySettingsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get relaySettingsRetry;

  /// No description provided for @relaySettingsNoStats.
  ///
  /// In en, this message translates to:
  /// **'No statistics available yet'**
  String get relaySettingsNoStats;

  /// No description provided for @relaySettingsConnection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get relaySettingsConnection;

  /// No description provided for @relaySettingsConnected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relaySettingsConnected;

  /// No description provided for @relaySettingsDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get relaySettingsDisconnected;

  /// No description provided for @relaySettingsSessionDuration.
  ///
  /// In en, this message translates to:
  /// **'Session Duration'**
  String get relaySettingsSessionDuration;

  /// No description provided for @relaySettingsLastConnected.
  ///
  /// In en, this message translates to:
  /// **'Last Connected'**
  String get relaySettingsLastConnected;

  /// No description provided for @relaySettingsDisconnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get relaySettingsDisconnectedLabel;

  /// No description provided for @relaySettingsReason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get relaySettingsReason;

  /// No description provided for @relaySettingsActiveSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Active Subscriptions'**
  String get relaySettingsActiveSubscriptions;

  /// No description provided for @relaySettingsTotalSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Total Subscriptions'**
  String get relaySettingsTotalSubscriptions;

  /// No description provided for @relaySettingsEventsReceived.
  ///
  /// In en, this message translates to:
  /// **'Events Received'**
  String get relaySettingsEventsReceived;

  /// No description provided for @relaySettingsEventsSent.
  ///
  /// In en, this message translates to:
  /// **'Events Sent'**
  String get relaySettingsEventsSent;

  /// No description provided for @relaySettingsRequestsThisSession.
  ///
  /// In en, this message translates to:
  /// **'Requests This Session'**
  String get relaySettingsRequestsThisSession;

  /// No description provided for @relaySettingsFailedRequests.
  ///
  /// In en, this message translates to:
  /// **'Failed Requests'**
  String get relaySettingsFailedRequests;

  /// No description provided for @relaySettingsLastError.
  ///
  /// In en, this message translates to:
  /// **'Last Error: {error}'**
  String relaySettingsLastError(String error);

  /// No description provided for @relaySettingsLoadingRelayInfo.
  ///
  /// In en, this message translates to:
  /// **'Loading relay info...'**
  String get relaySettingsLoadingRelayInfo;

  /// No description provided for @relaySettingsAboutRelay.
  ///
  /// In en, this message translates to:
  /// **'About Relay'**
  String get relaySettingsAboutRelay;

  /// No description provided for @relaySettingsSupportedNips.
  ///
  /// In en, this message translates to:
  /// **'Supported NIPs'**
  String get relaySettingsSupportedNips;

  /// No description provided for @relaySettingsSoftware.
  ///
  /// In en, this message translates to:
  /// **'Software'**
  String get relaySettingsSoftware;

  /// No description provided for @relaySettingsViewWebsite.
  ///
  /// In en, this message translates to:
  /// **'View Website'**
  String get relaySettingsViewWebsite;

  /// No description provided for @relaySettingsRemoveRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove Relay?'**
  String get relaySettingsRemoveRelayTitle;

  /// No description provided for @relaySettingsRemoveRelayMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this relay?\n\n{relayUrl}'**
  String relaySettingsRemoveRelayMessage(String relayUrl);

  /// No description provided for @relaySettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get relaySettingsCancel;

  /// No description provided for @relaySettingsRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get relaySettingsRemove;

  /// No description provided for @relaySettingsRemovedRelay.
  ///
  /// In en, this message translates to:
  /// **'Removed relay: {relayUrl}'**
  String relaySettingsRemovedRelay(String relayUrl);

  /// No description provided for @relaySettingsFailedToRemoveRelay.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove relay'**
  String get relaySettingsFailedToRemoveRelay;

  /// No description provided for @relaySettingsForcingReconnection.
  ///
  /// In en, this message translates to:
  /// **'Forcing relay reconnection...'**
  String get relaySettingsForcingReconnection;

  /// No description provided for @relaySettingsConnectedToRelays.
  ///
  /// In en, this message translates to:
  /// **'Connected to {count} relay(s)!'**
  String relaySettingsConnectedToRelays(int count);

  /// No description provided for @relaySettingsFailedToConnectCheck.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to relays. Please check your network connection.'**
  String get relaySettingsFailedToConnectCheck;

  /// No description provided for @relaySettingsAddRelayTitle.
  ///
  /// In en, this message translates to:
  /// **'Add Relay'**
  String get relaySettingsAddRelayTitle;

  /// No description provided for @relaySettingsAddRelayPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter the WebSocket URL of the relay you want to add:'**
  String get relaySettingsAddRelayPrompt;

  /// No description provided for @relaySettingsBrowsePublicRelays.
  ///
  /// In en, this message translates to:
  /// **'Browse public relays at nostr.co.uk'**
  String get relaySettingsBrowsePublicRelays;

  /// No description provided for @relaySettingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get relaySettingsAdd;

  /// No description provided for @relaySettingsAddedRelay.
  ///
  /// In en, this message translates to:
  /// **'Added relay: {relayUrl}'**
  String relaySettingsAddedRelay(String relayUrl);

  /// No description provided for @relaySettingsFailedToAddRelay.
  ///
  /// In en, this message translates to:
  /// **'Failed to add relay. Please check the URL and try again.'**
  String get relaySettingsFailedToAddRelay;

  /// No description provided for @relaySettingsInvalidUrl.
  ///
  /// In en, this message translates to:
  /// **'Relay URL must start with wss:// or ws://'**
  String get relaySettingsInvalidUrl;

  /// No description provided for @relaySettingsRestoredDefault.
  ///
  /// In en, this message translates to:
  /// **'Restored default relay: {defaultRelay}'**
  String relaySettingsRestoredDefault(String defaultRelay);

  /// No description provided for @relaySettingsFailedToRestoreDefault.
  ///
  /// In en, this message translates to:
  /// **'Failed to restore default relay. Please check your network connection.'**
  String get relaySettingsFailedToRestoreDefault;

  /// No description provided for @relaySettingsCouldNotOpenBrowser.
  ///
  /// In en, this message translates to:
  /// **'Could not open browser'**
  String get relaySettingsCouldNotOpenBrowser;

  /// No description provided for @relaySettingsFailedToOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to open link'**
  String get relaySettingsFailedToOpenLink;

  /// Relay diagnostics screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Relay Diagnostics'**
  String get relayDiagnosticTitle;

  /// No description provided for @relayDiagnosticRefreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh diagnostics'**
  String get relayDiagnosticRefreshTooltip;

  /// No description provided for @relayDiagnosticLastRefresh.
  ///
  /// In en, this message translates to:
  /// **'Last refresh: {time}'**
  String relayDiagnosticLastRefresh(String time);

  /// No description provided for @relayDiagnosticRelayStatus.
  ///
  /// In en, this message translates to:
  /// **'Relay Status'**
  String get relayDiagnosticRelayStatus;

  /// No description provided for @relayDiagnosticInitialized.
  ///
  /// In en, this message translates to:
  /// **'Initialized'**
  String get relayDiagnosticInitialized;

  /// No description provided for @relayDiagnosticReady.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get relayDiagnosticReady;

  /// No description provided for @relayDiagnosticNotInitialized.
  ///
  /// In en, this message translates to:
  /// **'Not initialized'**
  String get relayDiagnosticNotInitialized;

  /// No description provided for @relayDiagnosticDatabaseEvents.
  ///
  /// In en, this message translates to:
  /// **'Database Events'**
  String get relayDiagnosticDatabaseEvents;

  /// No description provided for @relayDiagnosticActiveSubscriptions.
  ///
  /// In en, this message translates to:
  /// **'Active Subscriptions'**
  String get relayDiagnosticActiveSubscriptions;

  /// No description provided for @relayDiagnosticExternalRelays.
  ///
  /// In en, this message translates to:
  /// **'External Relays'**
  String get relayDiagnosticExternalRelays;

  /// No description provided for @relayDiagnosticConfigured.
  ///
  /// In en, this message translates to:
  /// **'Configured'**
  String get relayDiagnosticConfigured;

  /// No description provided for @relayDiagnosticRelayCount.
  ///
  /// In en, this message translates to:
  /// **'{count} relay(s)'**
  String relayDiagnosticRelayCount(int count);

  /// No description provided for @relayDiagnosticConnectedLabel.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relayDiagnosticConnectedLabel;

  /// No description provided for @relayDiagnosticConnectedRatio.
  ///
  /// In en, this message translates to:
  /// **'{connected}/{total}'**
  String relayDiagnosticConnectedRatio(int connected, int total);

  /// No description provided for @relayDiagnosticVideoEvents.
  ///
  /// In en, this message translates to:
  /// **'Video Events'**
  String get relayDiagnosticVideoEvents;

  /// No description provided for @relayDiagnosticHomeFeed.
  ///
  /// In en, this message translates to:
  /// **'Home Feed'**
  String get relayDiagnosticHomeFeed;

  /// No description provided for @relayDiagnosticVideosCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String relayDiagnosticVideosCount(int count);

  /// No description provided for @relayDiagnosticDiscovery.
  ///
  /// In en, this message translates to:
  /// **'Discovery'**
  String get relayDiagnosticDiscovery;

  /// No description provided for @relayDiagnosticLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading'**
  String get relayDiagnosticLoading;

  /// No description provided for @relayDiagnosticYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get relayDiagnosticYes;

  /// No description provided for @relayDiagnosticNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get relayDiagnosticNo;

  /// No description provided for @relayDiagnosticTestDirectQuery.
  ///
  /// In en, this message translates to:
  /// **'Test Direct Query'**
  String get relayDiagnosticTestDirectQuery;

  /// No description provided for @relayDiagnosticNetworkConnectivity.
  ///
  /// In en, this message translates to:
  /// **'Network Connectivity'**
  String get relayDiagnosticNetworkConnectivity;

  /// No description provided for @relayDiagnosticRunNetworkTest.
  ///
  /// In en, this message translates to:
  /// **'Run Network Test'**
  String get relayDiagnosticRunNetworkTest;

  /// No description provided for @relayDiagnosticBlossomServer.
  ///
  /// In en, this message translates to:
  /// **'Blossom Server'**
  String get relayDiagnosticBlossomServer;

  /// No description provided for @relayDiagnosticTestAllEndpoints.
  ///
  /// In en, this message translates to:
  /// **'Test All Endpoints'**
  String get relayDiagnosticTestAllEndpoints;

  /// No description provided for @relayDiagnosticStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get relayDiagnosticStatus;

  /// No description provided for @relayDiagnosticUrl.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get relayDiagnosticUrl;

  /// No description provided for @relayDiagnosticError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get relayDiagnosticError;

  /// No description provided for @relayDiagnosticFunnelCakeApi.
  ///
  /// In en, this message translates to:
  /// **'FunnelCake API'**
  String get relayDiagnosticFunnelCakeApi;

  /// No description provided for @relayDiagnosticBaseUrl.
  ///
  /// In en, this message translates to:
  /// **'Base URL'**
  String get relayDiagnosticBaseUrl;

  /// No description provided for @relayDiagnosticSummary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get relayDiagnosticSummary;

  /// No description provided for @relayDiagnosticEndpointSummary.
  ///
  /// In en, this message translates to:
  /// **'{successCount}/{totalCount} OK (avg {avgMs}ms)'**
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  );

  /// No description provided for @relayDiagnosticRetestAll.
  ///
  /// In en, this message translates to:
  /// **'Retest All'**
  String get relayDiagnosticRetestAll;

  /// No description provided for @relayDiagnosticRetrying.
  ///
  /// In en, this message translates to:
  /// **'Retrying...'**
  String get relayDiagnosticRetrying;

  /// No description provided for @relayDiagnosticRetryConnection.
  ///
  /// In en, this message translates to:
  /// **'Retry Connection'**
  String get relayDiagnosticRetryConnection;

  /// No description provided for @relayDiagnosticTroubleshooting.
  ///
  /// In en, this message translates to:
  /// **'Troubleshooting'**
  String get relayDiagnosticTroubleshooting;

  /// No description provided for @relayDiagnosticTroubleshootingGuide.
  ///
  /// In en, this message translates to:
  /// **'• Green status = Connected and working\n• Red status = Connection failed\n• If network test fails, check internet connection\n• If relays are configured but not connected, tap \"Retry Connection\"\n• Screenshot this screen for debugging'**
  String get relayDiagnosticTroubleshootingGuide;

  /// No description provided for @relayDiagnosticAllEndpointsHealthy.
  ///
  /// In en, this message translates to:
  /// **'All REST endpoints healthy!'**
  String get relayDiagnosticAllEndpointsHealthy;

  /// No description provided for @relayDiagnosticSomeEndpointsFailed.
  ///
  /// In en, this message translates to:
  /// **'Some REST endpoints failed - see details above'**
  String get relayDiagnosticSomeEndpointsFailed;

  /// No description provided for @relayDiagnosticFoundVideoEvents.
  ///
  /// In en, this message translates to:
  /// **'Found {count} video events in database'**
  String relayDiagnosticFoundVideoEvents(int count);

  /// No description provided for @relayDiagnosticQueryFailed.
  ///
  /// In en, this message translates to:
  /// **'Query failed: {error}'**
  String relayDiagnosticQueryFailed(String error);

  /// No description provided for @relayDiagnosticConnectedToRelays.
  ///
  /// In en, this message translates to:
  /// **'Connected to {count} relay(s)!'**
  String relayDiagnosticConnectedToRelays(int count);

  /// No description provided for @relayDiagnosticFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect to any relays'**
  String get relayDiagnosticFailedToConnect;

  /// No description provided for @relayDiagnosticConnectionRetryFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection retry failed: {error}'**
  String relayDiagnosticConnectionRetryFailed(String error);

  /// No description provided for @relayDiagnosticConnectedAuthenticated.
  ///
  /// In en, this message translates to:
  /// **'Connected & Authenticated'**
  String get relayDiagnosticConnectedAuthenticated;

  /// No description provided for @relayDiagnosticConnectedOnly.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get relayDiagnosticConnectedOnly;

  /// No description provided for @relayDiagnosticNotConnected.
  ///
  /// In en, this message translates to:
  /// **'Not connected'**
  String get relayDiagnosticNotConnected;

  /// No description provided for @relayDiagnosticNoRelaysConfigured.
  ///
  /// In en, this message translates to:
  /// **'No relays configured'**
  String get relayDiagnosticNoRelaysConfigured;

  /// No description provided for @relayDiagnosticFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get relayDiagnosticFailed;

  /// Notification settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationSettingsTitle;

  /// No description provided for @notificationSettingsResetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset to defaults'**
  String get notificationSettingsResetTooltip;

  /// No description provided for @notificationSettingsTypes.
  ///
  /// In en, this message translates to:
  /// **'Notification Types'**
  String get notificationSettingsTypes;

  /// No description provided for @notificationSettingsLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get notificationSettingsLikes;

  /// No description provided for @notificationSettingsLikesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone likes your videos'**
  String get notificationSettingsLikesSubtitle;

  /// No description provided for @notificationSettingsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get notificationSettingsComments;

  /// No description provided for @notificationSettingsCommentsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone comments on your videos'**
  String get notificationSettingsCommentsSubtitle;

  /// No description provided for @notificationSettingsFollows.
  ///
  /// In en, this message translates to:
  /// **'Follows'**
  String get notificationSettingsFollows;

  /// No description provided for @notificationSettingsFollowsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone follows you'**
  String get notificationSettingsFollowsSubtitle;

  /// No description provided for @notificationSettingsMentions.
  ///
  /// In en, this message translates to:
  /// **'Mentions'**
  String get notificationSettingsMentions;

  /// No description provided for @notificationSettingsMentionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When you are mentioned'**
  String get notificationSettingsMentionsSubtitle;

  /// No description provided for @notificationSettingsReposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get notificationSettingsReposts;

  /// No description provided for @notificationSettingsRepostsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'When someone reposts your videos'**
  String get notificationSettingsRepostsSubtitle;

  /// No description provided for @notificationSettingsSystem.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get notificationSettingsSystem;

  /// No description provided for @notificationSettingsSystemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'App updates and system messages'**
  String get notificationSettingsSystemSubtitle;

  /// No description provided for @notificationSettingsPushNotificationsSection.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get notificationSettingsPushNotificationsSection;

  /// No description provided for @notificationSettingsPushNotifications.
  ///
  /// In en, this message translates to:
  /// **'Push Notifications'**
  String get notificationSettingsPushNotifications;

  /// No description provided for @notificationSettingsPushNotificationsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Receive notifications when app is closed'**
  String get notificationSettingsPushNotificationsSubtitle;

  /// No description provided for @notificationSettingsSound.
  ///
  /// In en, this message translates to:
  /// **'Sound'**
  String get notificationSettingsSound;

  /// No description provided for @notificationSettingsSoundSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Play sound for notifications'**
  String get notificationSettingsSoundSubtitle;

  /// No description provided for @notificationSettingsVibration.
  ///
  /// In en, this message translates to:
  /// **'Vibration'**
  String get notificationSettingsVibration;

  /// No description provided for @notificationSettingsVibrationSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Vibrate for notifications'**
  String get notificationSettingsVibrationSubtitle;

  /// No description provided for @notificationSettingsActions.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get notificationSettingsActions;

  /// No description provided for @notificationSettingsMarkAllAsRead.
  ///
  /// In en, this message translates to:
  /// **'Mark All as Read'**
  String get notificationSettingsMarkAllAsRead;

  /// No description provided for @notificationSettingsMarkAllAsReadSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Mark all notifications as read'**
  String get notificationSettingsMarkAllAsReadSubtitle;

  /// No description provided for @notificationSettingsAllMarkedAsRead.
  ///
  /// In en, this message translates to:
  /// **'All notifications marked as read'**
  String get notificationSettingsAllMarkedAsRead;

  /// No description provided for @notificationSettingsResetToDefaults.
  ///
  /// In en, this message translates to:
  /// **'Settings reset to defaults'**
  String get notificationSettingsResetToDefaults;

  /// No description provided for @notificationSettingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About Notifications'**
  String get notificationSettingsAbout;

  /// No description provided for @notificationSettingsAboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.'**
  String get notificationSettingsAboutDescription;

  /// Safety settings screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Safety & Privacy'**
  String get safetySettingsTitle;

  /// No description provided for @safetySettingsLabel.
  ///
  /// In en, this message translates to:
  /// **'SETTINGS'**
  String get safetySettingsLabel;

  /// No description provided for @safetySettingsShowDivineHostedOnly.
  ///
  /// In en, this message translates to:
  /// **'Only show Divine-hosted videos'**
  String get safetySettingsShowDivineHostedOnly;

  /// No description provided for @safetySettingsShowDivineHostedOnlySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Hide videos served from other media hosts'**
  String get safetySettingsShowDivineHostedOnlySubtitle;

  /// No description provided for @safetySettingsModeration.
  ///
  /// In en, this message translates to:
  /// **'MODERATION'**
  String get safetySettingsModeration;

  /// No description provided for @safetySettingsBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'BLOCKED USERS'**
  String get safetySettingsBlockedUsers;

  /// No description provided for @safetySettingsAgeVerification.
  ///
  /// In en, this message translates to:
  /// **'AGE VERIFICATION'**
  String get safetySettingsAgeVerification;

  /// No description provided for @safetySettingsAgeConfirmation.
  ///
  /// In en, this message translates to:
  /// **'I confirm I am 18 years or older'**
  String get safetySettingsAgeConfirmation;

  /// No description provided for @safetySettingsAgeRequired.
  ///
  /// In en, this message translates to:
  /// **'Required to view adult content'**
  String get safetySettingsAgeRequired;

  /// No description provided for @safetySettingsDivine.
  ///
  /// In en, this message translates to:
  /// **'Divine'**
  String get safetySettingsDivine;

  /// No description provided for @safetySettingsDivineSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Official moderation service (on by default)'**
  String get safetySettingsDivineSubtitle;

  /// No description provided for @safetySettingsPeopleIFollow.
  ///
  /// In en, this message translates to:
  /// **'People I follow'**
  String get safetySettingsPeopleIFollow;

  /// No description provided for @safetySettingsPeopleIFollowSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Subscribe to labels from people you follow'**
  String get safetySettingsPeopleIFollowSubtitle;

  /// No description provided for @safetySettingsAddCustomLabeler.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Labeler'**
  String get safetySettingsAddCustomLabeler;

  /// No description provided for @safetySettingsAddCustomLabelerHint.
  ///
  /// In en, this message translates to:
  /// **'Enter npub...'**
  String get safetySettingsAddCustomLabelerHint;

  /// No description provided for @safetySettingsAddCustomLabelerListTitle.
  ///
  /// In en, this message translates to:
  /// **'Add custom labeler'**
  String get safetySettingsAddCustomLabelerListTitle;

  /// No description provided for @safetySettingsAddCustomLabelerListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter npub address'**
  String get safetySettingsAddCustomLabelerListSubtitle;

  /// No description provided for @safetySettingsNoBlockedUsers.
  ///
  /// In en, this message translates to:
  /// **'No blocked users'**
  String get safetySettingsNoBlockedUsers;

  /// No description provided for @safetySettingsUnblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get safetySettingsUnblock;

  /// No description provided for @safetySettingsUserUnblocked.
  ///
  /// In en, this message translates to:
  /// **'User unblocked'**
  String get safetySettingsUserUnblocked;

  /// No description provided for @safetySettingsCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get safetySettingsCancel;

  /// No description provided for @safetySettingsAdd.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get safetySettingsAdd;

  /// Creator analytics screen app bar title
  ///
  /// In en, this message translates to:
  /// **'Creator Analytics'**
  String get analyticsTitle;

  /// No description provided for @analyticsDiagnosticsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get analyticsDiagnosticsTooltip;

  /// No description provided for @analyticsDiagnosticsSemanticLabel.
  ///
  /// In en, this message translates to:
  /// **'Toggle diagnostics'**
  String get analyticsDiagnosticsSemanticLabel;

  /// No description provided for @analyticsRetry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get analyticsRetry;

  /// No description provided for @analyticsUnableToLoad.
  ///
  /// In en, this message translates to:
  /// **'Unable to load analytics.'**
  String get analyticsUnableToLoad;

  /// No description provided for @analyticsSignInRequired.
  ///
  /// In en, this message translates to:
  /// **'Sign in to view creator analytics.'**
  String get analyticsSignInRequired;

  /// No description provided for @analyticsViewDataUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Views are currently unavailable from the relay for these posts. Like/comment/repost metrics are still accurate.'**
  String get analyticsViewDataUnavailable;

  /// No description provided for @analyticsViewDataTitle.
  ///
  /// In en, this message translates to:
  /// **'View Data'**
  String get analyticsViewDataTitle;

  /// No description provided for @analyticsUpdatedTimestamp.
  ///
  /// In en, this message translates to:
  /// **'Updated {time} • Scores use likes, comments, reposts, and views/loops from Funnelcake when available.'**
  String analyticsUpdatedTimestamp(String time);

  /// No description provided for @analyticsVideos.
  ///
  /// In en, this message translates to:
  /// **'Videos'**
  String get analyticsVideos;

  /// No description provided for @analyticsViews.
  ///
  /// In en, this message translates to:
  /// **'Views'**
  String get analyticsViews;

  /// No description provided for @analyticsInteractions.
  ///
  /// In en, this message translates to:
  /// **'Interactions'**
  String get analyticsInteractions;

  /// No description provided for @analyticsEngagement.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get analyticsEngagement;

  /// No description provided for @analyticsFollowers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get analyticsFollowers;

  /// No description provided for @analyticsAvgPerPost.
  ///
  /// In en, this message translates to:
  /// **'Avg/Post'**
  String get analyticsAvgPerPost;

  /// No description provided for @analyticsInteractionMix.
  ///
  /// In en, this message translates to:
  /// **'Interaction Mix'**
  String get analyticsInteractionMix;

  /// No description provided for @analyticsLikes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get analyticsLikes;

  /// No description provided for @analyticsComments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get analyticsComments;

  /// No description provided for @analyticsReposts.
  ///
  /// In en, this message translates to:
  /// **'Reposts'**
  String get analyticsReposts;

  /// No description provided for @analyticsPerformanceHighlights.
  ///
  /// In en, this message translates to:
  /// **'Performance Highlights'**
  String get analyticsPerformanceHighlights;

  /// No description provided for @analyticsMostViewed.
  ///
  /// In en, this message translates to:
  /// **'Most viewed'**
  String get analyticsMostViewed;

  /// No description provided for @analyticsMostDiscussed.
  ///
  /// In en, this message translates to:
  /// **'Most discussed'**
  String get analyticsMostDiscussed;

  /// No description provided for @analyticsMostReposted.
  ///
  /// In en, this message translates to:
  /// **'Most reposted'**
  String get analyticsMostReposted;

  /// No description provided for @analyticsNoVideosYet.
  ///
  /// In en, this message translates to:
  /// **'No videos yet'**
  String get analyticsNoVideosYet;

  /// No description provided for @analyticsViewDataUnavailableShort.
  ///
  /// In en, this message translates to:
  /// **'View data unavailable'**
  String get analyticsViewDataUnavailableShort;

  /// No description provided for @analyticsViewsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} views'**
  String analyticsViewsCount(String count);

  /// No description provided for @analyticsCommentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} comments'**
  String analyticsCommentsCount(String count);

  /// No description provided for @analyticsRepostsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} reposts'**
  String analyticsRepostsCount(String count);

  /// No description provided for @analyticsTopContent.
  ///
  /// In en, this message translates to:
  /// **'Top Content'**
  String get analyticsTopContent;

  /// No description provided for @analyticsPublishPrompt.
  ///
  /// In en, this message translates to:
  /// **'Publish a few videos to see rankings.'**
  String get analyticsPublishPrompt;

  /// No description provided for @analyticsEngagementRateExplainer.
  ///
  /// In en, this message translates to:
  /// **'Right-side % = Engagement Rate (interactions divided by views).'**
  String get analyticsEngagementRateExplainer;

  /// No description provided for @analyticsEngagementRateNoViews.
  ///
  /// In en, this message translates to:
  /// **'Engagement Rate needs view data; values show as N/A until views are available.'**
  String get analyticsEngagementRateNoViews;

  /// No description provided for @analyticsEngagementLabel.
  ///
  /// In en, this message translates to:
  /// **'Engagement'**
  String get analyticsEngagementLabel;

  /// No description provided for @analyticsViewsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'views unavailable'**
  String get analyticsViewsUnavailable;

  /// No description provided for @analyticsInteractionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count} interactions'**
  String analyticsInteractionsCount(String count);

  /// No description provided for @analyticsPostAnalytics.
  ///
  /// In en, this message translates to:
  /// **'Post Analytics'**
  String get analyticsPostAnalytics;

  /// No description provided for @analyticsOpenPost.
  ///
  /// In en, this message translates to:
  /// **'Open Post'**
  String get analyticsOpenPost;

  /// No description provided for @analyticsRecentDailyInteractions.
  ///
  /// In en, this message translates to:
  /// **'Recent Daily Interactions'**
  String get analyticsRecentDailyInteractions;

  /// No description provided for @analyticsNoActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity in this range yet.'**
  String get analyticsNoActivityYet;

  /// No description provided for @analyticsDailyInteractionsExplainer.
  ///
  /// In en, this message translates to:
  /// **'Interactions = likes + comments + reposts by post date.'**
  String get analyticsDailyInteractionsExplainer;

  /// No description provided for @analyticsDailyBarExplainer.
  ///
  /// In en, this message translates to:
  /// **'Bar length is relative to your highest day in this window.'**
  String get analyticsDailyBarExplainer;

  /// No description provided for @analyticsAudienceSnapshot.
  ///
  /// In en, this message translates to:
  /// **'Audience Snapshot'**
  String get analyticsAudienceSnapshot;

  /// No description provided for @analyticsFollowersCount.
  ///
  /// In en, this message translates to:
  /// **'Followers: {count}'**
  String analyticsFollowersCount(String count);

  /// No description provided for @analyticsFollowingCount.
  ///
  /// In en, this message translates to:
  /// **'Following: {count}'**
  String analyticsFollowingCount(String count);

  /// No description provided for @analyticsAudiencePlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Audience source/geo/time breakdowns will populate as Funnelcake adds audience analytics endpoints.'**
  String get analyticsAudiencePlaceholder;

  /// No description provided for @analyticsRetention.
  ///
  /// In en, this message translates to:
  /// **'Retention'**
  String get analyticsRetention;

  /// No description provided for @analyticsRetentionWithViews.
  ///
  /// In en, this message translates to:
  /// **'Retention curve and watch-time breakdown will appear once per-second/per-bucket retention arrives from Funnelcake.'**
  String get analyticsRetentionWithViews;

  /// No description provided for @analyticsRetentionWithoutViews.
  ///
  /// In en, this message translates to:
  /// **'Retention data unavailable until view+watch-time analytics are returned by Funnelcake.'**
  String get analyticsRetentionWithoutViews;

  /// No description provided for @analyticsDiagnostics.
  ///
  /// In en, this message translates to:
  /// **'Diagnostics'**
  String get analyticsDiagnostics;

  /// No description provided for @analyticsDiagnosticsTotalVideos.
  ///
  /// In en, this message translates to:
  /// **'Total videos: {count}'**
  String analyticsDiagnosticsTotalVideos(int count);

  /// No description provided for @analyticsDiagnosticsWithViews.
  ///
  /// In en, this message translates to:
  /// **'With views: {count}'**
  String analyticsDiagnosticsWithViews(int count);

  /// No description provided for @analyticsDiagnosticsMissingViews.
  ///
  /// In en, this message translates to:
  /// **'Missing views: {count}'**
  String analyticsDiagnosticsMissingViews(int count);

  /// No description provided for @analyticsDiagnosticsHydratedBulk.
  ///
  /// In en, this message translates to:
  /// **'Hydrated (bulk): {count}'**
  String analyticsDiagnosticsHydratedBulk(int count);

  /// No description provided for @analyticsDiagnosticsHydratedViews.
  ///
  /// In en, this message translates to:
  /// **'Hydrated (/views): {count}'**
  String analyticsDiagnosticsHydratedViews(int count);

  /// No description provided for @analyticsDiagnosticsSources.
  ///
  /// In en, this message translates to:
  /// **'Sources: {sources}'**
  String analyticsDiagnosticsSources(String sources);

  /// No description provided for @analyticsDiagnosticsUseFixture.
  ///
  /// In en, this message translates to:
  /// **'Use fixture data'**
  String get analyticsDiagnosticsUseFixture;

  /// No description provided for @analyticsNa.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get analyticsNa;

  /// No description provided for @authCreateNewAccount.
  ///
  /// In en, this message translates to:
  /// **'Create a new Divine account'**
  String get authCreateNewAccount;

  /// No description provided for @authSignInDifferentAccount.
  ///
  /// In en, this message translates to:
  /// **'Sign in with a different account'**
  String get authSignInDifferentAccount;

  /// No description provided for @authSignBackIn.
  ///
  /// In en, this message translates to:
  /// **'Sign back in'**
  String get authSignBackIn;

  /// No description provided for @authTermsPrefix.
  ///
  /// In en, this message translates to:
  /// **'By selecting an option above, you confirm you are at least 16 years old and agree to the '**
  String get authTermsPrefix;

  /// No description provided for @authTermsOfService.
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get authTermsOfService;

  /// No description provided for @authPrivacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authPrivacyPolicy;

  /// No description provided for @authTermsAnd.
  ///
  /// In en, this message translates to:
  /// **', and '**
  String get authTermsAnd;

  /// No description provided for @authSafetyStandards.
  ///
  /// In en, this message translates to:
  /// **'Safety Standards'**
  String get authSafetyStandards;

  /// No description provided for @authAmberNotInstalled.
  ///
  /// In en, this message translates to:
  /// **'Amber app is not installed'**
  String get authAmberNotInstalled;

  /// No description provided for @authAmberConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect with Amber'**
  String get authAmberConnectionFailed;

  /// No description provided for @authPasswordResetSent.
  ///
  /// In en, this message translates to:
  /// **'If an account exists with that email, a password reset link has been sent.'**
  String get authPasswordResetSent;

  /// No description provided for @authSignInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInTitle;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authImportNostrKey.
  ///
  /// In en, this message translates to:
  /// **'Import Nostr key'**
  String get authImportNostrKey;

  /// No description provided for @authConnectSignerApp.
  ///
  /// In en, this message translates to:
  /// **'Connect with a signer app'**
  String get authConnectSignerApp;

  /// No description provided for @authSignInWithAmber.
  ///
  /// In en, this message translates to:
  /// **'Sign in with Amber'**
  String get authSignInWithAmber;

  /// No description provided for @authSignInOptionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign-in options'**
  String get authSignInOptionsTitle;

  /// No description provided for @authInfoEmailPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Email & Password'**
  String get authInfoEmailPasswordTitle;

  /// No description provided for @authInfoEmailPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Sign in with your Divine account. If you registered with an email and password, use them here.'**
  String get authInfoEmailPasswordDescription;

  /// No description provided for @authInfoImportNostrKeyDescription.
  ///
  /// In en, this message translates to:
  /// **'Already have a Nostr identity? Import your nsec private key from another client.'**
  String get authInfoImportNostrKeyDescription;

  /// No description provided for @authInfoSignerAppTitle.
  ///
  /// In en, this message translates to:
  /// **'Signer App'**
  String get authInfoSignerAppTitle;

  /// No description provided for @authInfoSignerAppDescription.
  ///
  /// In en, this message translates to:
  /// **'Connect using a NIP-46 compatible remote signer like nsecBunker for enhanced key security.'**
  String get authInfoSignerAppDescription;

  /// No description provided for @authInfoAmberTitle.
  ///
  /// In en, this message translates to:
  /// **'Amber'**
  String get authInfoAmberTitle;

  /// No description provided for @authInfoAmberDescription.
  ///
  /// In en, this message translates to:
  /// **'Use the Amber signer app on Android to manage your Nostr keys securely.'**
  String get authInfoAmberDescription;

  /// No description provided for @authCreateAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountTitle;

  /// No description provided for @authBackToInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Back to invite code'**
  String get authBackToInviteCode;

  /// No description provided for @authUseDivineNoBackup.
  ///
  /// In en, this message translates to:
  /// **'Use Divine with no backup'**
  String get authUseDivineNoBackup;

  /// No description provided for @authSkipConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'One last thing...'**
  String get authSkipConfirmTitle;

  /// No description provided for @authSkipConfirmKeyCreated.
  ///
  /// In en, this message translates to:
  /// **'You\'re in! We\'ll create a secure key that powers your Divine account.'**
  String get authSkipConfirmKeyCreated;

  /// No description provided for @authSkipConfirmKeyOnly.
  ///
  /// In en, this message translates to:
  /// **'Without an email, your key is the only way Divine knows this account is yours.'**
  String get authSkipConfirmKeyOnly;

  /// No description provided for @authSkipConfirmRecommendEmail.
  ///
  /// In en, this message translates to:
  /// **'You can access your key in the app, but, if you\'re not technical we recommend adding an email and password now. It makes it easier to sign in and restore your account if you lose or reset this device.'**
  String get authSkipConfirmRecommendEmail;

  /// No description provided for @authAddEmailPassword.
  ///
  /// In en, this message translates to:
  /// **'Add email & password'**
  String get authAddEmailPassword;

  /// No description provided for @authUseThisDeviceOnly.
  ///
  /// In en, this message translates to:
  /// **'Use this device only'**
  String get authUseThisDeviceOnly;

  /// No description provided for @authCompleteRegistration.
  ///
  /// In en, this message translates to:
  /// **'Complete your registration'**
  String get authCompleteRegistration;

  /// No description provided for @authVerifying.
  ///
  /// In en, this message translates to:
  /// **'Verifying...'**
  String get authVerifying;

  /// No description provided for @authVerificationLinkSent.
  ///
  /// In en, this message translates to:
  /// **'We sent a verification link to:'**
  String get authVerificationLinkSent;

  /// No description provided for @authClickVerificationLink.
  ///
  /// In en, this message translates to:
  /// **'Please click the link in your email to\ncomplete your registration.'**
  String get authClickVerificationLink;

  /// No description provided for @authPleaseWaitVerifying.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we verify your email...'**
  String get authPleaseWaitVerifying;

  /// No description provided for @authWaitingForVerification.
  ///
  /// In en, this message translates to:
  /// **'Waiting for verification'**
  String get authWaitingForVerification;

  /// No description provided for @authOpenEmailApp.
  ///
  /// In en, this message translates to:
  /// **'Open email app'**
  String get authOpenEmailApp;

  /// No description provided for @authWelcomeToDivine.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Divine!'**
  String get authWelcomeToDivine;

  /// No description provided for @authEmailVerified.
  ///
  /// In en, this message translates to:
  /// **'Your email has been verified.'**
  String get authEmailVerified;

  /// No description provided for @authSigningYouIn.
  ///
  /// In en, this message translates to:
  /// **'Signing you in'**
  String get authSigningYouIn;

  /// No description provided for @authErrorTitle.
  ///
  /// In en, this message translates to:
  /// **'Uh oh.'**
  String get authErrorTitle;

  /// No description provided for @authVerificationFailed.
  ///
  /// In en, this message translates to:
  /// **'We failed to verify your email.\nPlease try again.'**
  String get authVerificationFailed;

  /// No description provided for @authStartOver.
  ///
  /// In en, this message translates to:
  /// **'Start over'**
  String get authStartOver;

  /// No description provided for @authEmailVerifiedLogin.
  ///
  /// In en, this message translates to:
  /// **'Email verified! Please log in to continue.'**
  String get authEmailVerifiedLogin;

  /// No description provided for @authVerificationLinkExpired.
  ///
  /// In en, this message translates to:
  /// **'This verification link is no longer valid.'**
  String get authVerificationLinkExpired;

  /// No description provided for @authVerificationConnectionError.
  ///
  /// In en, this message translates to:
  /// **'Unable to verify email. Please check your connection and try again.'**
  String get authVerificationConnectionError;

  /// No description provided for @authWaitlistConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'You\'re in!'**
  String get authWaitlistConfirmTitle;

  /// Waitlist confirmation message with email
  ///
  /// In en, this message translates to:
  /// **'We\'ll share updates at {email}.\nWhen more invite codes are available, we\'ll send them your way.'**
  String authWaitlistUpdatesAt(String email);

  /// No description provided for @authOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get authOk;

  /// No description provided for @authInviteUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Invite access is temporarily unavailable.'**
  String get authInviteUnavailable;

  /// No description provided for @authInviteUnavailableBody.
  ///
  /// In en, this message translates to:
  /// **'Try again in a moment, or contact support if you need help getting in.'**
  String get authInviteUnavailableBody;

  /// No description provided for @authTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get authTryAgain;

  /// No description provided for @authContactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact support'**
  String get authContactSupport;

  /// Error when email client cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open {email}'**
  String authCouldNotOpenEmail(String email);

  /// No description provided for @authAddInviteCode.
  ///
  /// In en, this message translates to:
  /// **'Add your invite code'**
  String get authAddInviteCode;

  /// No description provided for @authInviteCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get authInviteCodeLabel;

  /// No description provided for @authEnterYourCode.
  ///
  /// In en, this message translates to:
  /// **'Enter your code'**
  String get authEnterYourCode;

  /// No description provided for @authNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get authNext;

  /// No description provided for @authJoinWaitlist.
  ///
  /// In en, this message translates to:
  /// **'Join waitlist'**
  String get authJoinWaitlist;

  /// No description provided for @authJoinWaitlistTitle.
  ///
  /// In en, this message translates to:
  /// **'Join the waitlist'**
  String get authJoinWaitlistTitle;

  /// No description provided for @authJoinWaitlistDescription.
  ///
  /// In en, this message translates to:
  /// **'Share your email and we\'ll send updates as access opens up.'**
  String get authJoinWaitlistDescription;

  /// No description provided for @authInviteAccessHelp.
  ///
  /// In en, this message translates to:
  /// **'Invite access help'**
  String get authInviteAccessHelp;

  /// No description provided for @authGeneratingConnection.
  ///
  /// In en, this message translates to:
  /// **'Generating connection...'**
  String get authGeneratingConnection;

  /// No description provided for @authConnectedAuthenticating.
  ///
  /// In en, this message translates to:
  /// **'Connected! Authenticating...'**
  String get authConnectedAuthenticating;

  /// No description provided for @authConnectionTimedOut.
  ///
  /// In en, this message translates to:
  /// **'Connection timed out'**
  String get authConnectionTimedOut;

  /// No description provided for @authApproveConnection.
  ///
  /// In en, this message translates to:
  /// **'Make sure you approved the connection in your signer app.'**
  String get authApproveConnection;

  /// No description provided for @authConnectionCancelled.
  ///
  /// In en, this message translates to:
  /// **'Connection cancelled'**
  String get authConnectionCancelled;

  /// No description provided for @authConnectionCancelledMessage.
  ///
  /// In en, this message translates to:
  /// **'The connection was cancelled.'**
  String get authConnectionCancelledMessage;

  /// No description provided for @authConnectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed'**
  String get authConnectionFailed;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'An unknown error occurred.'**
  String get authUnknownError;

  /// No description provided for @authUrlCopied.
  ///
  /// In en, this message translates to:
  /// **'URL copied to clipboard'**
  String get authUrlCopied;

  /// No description provided for @authConnectToDivine.
  ///
  /// In en, this message translates to:
  /// **'Connect to Divine'**
  String get authConnectToDivine;

  /// No description provided for @authPasteBunkerUrl.
  ///
  /// In en, this message translates to:
  /// **'Paste bunker:// URL'**
  String get authPasteBunkerUrl;

  /// No description provided for @authBunkerUrlHint.
  ///
  /// In en, this message translates to:
  /// **'bunker:// URL'**
  String get authBunkerUrlHint;

  /// No description provided for @authInvalidBunkerUrl.
  ///
  /// In en, this message translates to:
  /// **'Invalid bunker URL. It should start with bunker://'**
  String get authInvalidBunkerUrl;

  /// No description provided for @authScanSignerApp.
  ///
  /// In en, this message translates to:
  /// **'Scan with your\nsigner app to connect.'**
  String get authScanSignerApp;

  /// Waiting indicator with elapsed seconds
  ///
  /// In en, this message translates to:
  /// **'Waiting for connection... {seconds}s'**
  String authWaitingForConnection(int seconds);

  /// No description provided for @authCopyUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy URL'**
  String get authCopyUrl;

  /// No description provided for @authShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get authShare;

  /// No description provided for @authAddBunker.
  ///
  /// In en, this message translates to:
  /// **'Add bunker'**
  String get authAddBunker;

  /// No description provided for @authCompatibleSignerApps.
  ///
  /// In en, this message translates to:
  /// **'Compatible Signer apps'**
  String get authCompatibleSignerApps;

  /// No description provided for @authFailedToConnect.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect'**
  String get authFailedToConnect;

  /// No description provided for @authResetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authResetPasswordTitle;

  /// No description provided for @authResetPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Please enter your new password. It must be at least 8 characters in length.'**
  String get authResetPasswordSubtitle;

  /// No description provided for @authNewPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get authNewPasswordLabel;

  /// No description provided for @authPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 8 characters'**
  String get authPasswordTooShort;

  /// No description provided for @authPasswordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successful. Please log in.'**
  String get authPasswordResetSuccess;

  /// No description provided for @authPasswordResetFailed.
  ///
  /// In en, this message translates to:
  /// **'Password reset failed'**
  String get authPasswordResetFailed;

  /// No description provided for @authUnexpectedError.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred. Please try again.'**
  String get authUnexpectedError;

  /// No description provided for @authUpdatePassword.
  ///
  /// In en, this message translates to:
  /// **'Update password'**
  String get authUpdatePassword;

  /// No description provided for @authSecureAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Secure account'**
  String get authSecureAccountTitle;

  /// No description provided for @authUnableToAccessKeys.
  ///
  /// In en, this message translates to:
  /// **'Unable to access your keys. Please try again.'**
  String get authUnableToAccessKeys;

  /// No description provided for @authRegistrationFailed.
  ///
  /// In en, this message translates to:
  /// **'Registration failed'**
  String get authRegistrationFailed;

  /// No description provided for @authRegistrationComplete.
  ///
  /// In en, this message translates to:
  /// **'Registration complete. Please check your email.'**
  String get authRegistrationComplete;

  /// No description provided for @authVerificationFailedTitle.
  ///
  /// In en, this message translates to:
  /// **'Verification Failed'**
  String get authVerificationFailedTitle;

  /// No description provided for @authClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get authClose;

  /// No description provided for @authAccountSecured.
  ///
  /// In en, this message translates to:
  /// **'Account Secured!'**
  String get authAccountSecured;

  /// No description provided for @authAccountLinkedToEmail.
  ///
  /// In en, this message translates to:
  /// **'Your account is now linked to your email.'**
  String get authAccountLinkedToEmail;

  /// No description provided for @authVerifyYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Verify Your Email'**
  String get authVerifyYourEmail;

  /// No description provided for @authClickLinkContinue.
  ///
  /// In en, this message translates to:
  /// **'Click the link in your email to complete registration. You can continue using the app in the meantime.'**
  String get authClickLinkContinue;

  /// No description provided for @authWaitingForVerificationEllipsis.
  ///
  /// In en, this message translates to:
  /// **'Waiting for verification...'**
  String get authWaitingForVerificationEllipsis;

  /// No description provided for @authContinueToApp.
  ///
  /// In en, this message translates to:
  /// **'Continue to App'**
  String get authContinueToApp;

  /// No description provided for @authResetPassword.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authResetPassword;

  /// No description provided for @authResetPasswordDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we\'ll send you a link to reset your password.'**
  String get authResetPasswordDescription;

  /// No description provided for @authFailedToSendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Failed to send reset email.'**
  String get authFailedToSendResetEmail;

  /// No description provided for @authUnexpectedErrorShort.
  ///
  /// In en, this message translates to:
  /// **'An unexpected error occurred.'**
  String get authUnexpectedErrorShort;

  /// No description provided for @authSending.
  ///
  /// In en, this message translates to:
  /// **'Sending...'**
  String get authSending;

  /// No description provided for @authSendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendResetLink;

  /// No description provided for @authEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Email sent!'**
  String get authEmailSent;

  /// Confirmation message after reset link sent
  ///
  /// In en, this message translates to:
  /// **'We sent a password reset link to {email}. Please click the link in your email to update your password.'**
  String authResetLinkSentTo(String email);

  /// No description provided for @authSignInButton.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignInButton;

  /// No description provided for @shareSheetSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get shareSheetSave;

  /// No description provided for @shareSheetSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get shareSheetSaveToGallery;

  /// No description provided for @shareSheetSaveWithWatermark.
  ///
  /// In en, this message translates to:
  /// **'Save with Watermark'**
  String get shareSheetSaveWithWatermark;

  /// No description provided for @shareSheetSaveVideo.
  ///
  /// In en, this message translates to:
  /// **'Save Video'**
  String get shareSheetSaveVideo;

  /// No description provided for @shareSheetAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get shareSheetAddToList;

  /// No description provided for @shareSheetCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get shareSheetCopy;

  /// No description provided for @shareSheetShareVia.
  ///
  /// In en, this message translates to:
  /// **'Share via'**
  String get shareSheetShareVia;

  /// No description provided for @shareSheetReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get shareSheetReport;

  /// No description provided for @shareSheetEventJson.
  ///
  /// In en, this message translates to:
  /// **'Event JSON'**
  String get shareSheetEventJson;

  /// No description provided for @shareSheetEventId.
  ///
  /// In en, this message translates to:
  /// **'Event ID'**
  String get shareSheetEventId;

  /// No description provided for @shareSheetMoreActions.
  ///
  /// In en, this message translates to:
  /// **'More actions'**
  String get shareSheetMoreActions;

  /// No description provided for @watermarkDownloadSavedToCameraRoll.
  ///
  /// In en, this message translates to:
  /// **'Saved to Camera Roll'**
  String get watermarkDownloadSavedToCameraRoll;

  /// No description provided for @watermarkDownloadShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get watermarkDownloadShare;

  /// No description provided for @watermarkDownloadDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get watermarkDownloadDone;

  /// No description provided for @watermarkDownloadPhotosAccessNeeded.
  ///
  /// In en, this message translates to:
  /// **'Photos Access Needed'**
  String get watermarkDownloadPhotosAccessNeeded;

  /// No description provided for @watermarkDownloadPhotosAccessDescription.
  ///
  /// In en, this message translates to:
  /// **'To save videos, allow Photos access in Settings.'**
  String get watermarkDownloadPhotosAccessDescription;

  /// No description provided for @watermarkDownloadOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open Settings'**
  String get watermarkDownloadOpenSettings;

  /// No description provided for @watermarkDownloadNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not Now'**
  String get watermarkDownloadNotNow;

  /// No description provided for @watermarkDownloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download Failed'**
  String get watermarkDownloadFailed;

  /// No description provided for @watermarkDownloadDismiss.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get watermarkDownloadDismiss;

  /// No description provided for @watermarkDownloadStageDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading Video'**
  String get watermarkDownloadStageDownloading;

  /// No description provided for @watermarkDownloadStageWatermarking.
  ///
  /// In en, this message translates to:
  /// **'Adding Watermark'**
  String get watermarkDownloadStageWatermarking;

  /// No description provided for @watermarkDownloadStageSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving to Camera Roll'**
  String get watermarkDownloadStageSaving;

  /// No description provided for @watermarkDownloadStageDownloadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Fetching the video from the network...'**
  String get watermarkDownloadStageDownloadingDesc;

  /// No description provided for @watermarkDownloadStageWatermarkingDesc.
  ///
  /// In en, this message translates to:
  /// **'Applying the Divine watermark...'**
  String get watermarkDownloadStageWatermarkingDesc;

  /// No description provided for @watermarkDownloadStageSavingDesc.
  ///
  /// In en, this message translates to:
  /// **'Saving the watermarked video to your camera roll...'**
  String get watermarkDownloadStageSavingDesc;

  /// No description provided for @uploadProgressVideoUpload.
  ///
  /// In en, this message translates to:
  /// **'Video Upload'**
  String get uploadProgressVideoUpload;

  /// No description provided for @uploadProgressPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get uploadProgressPause;

  /// No description provided for @uploadProgressResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get uploadProgressResume;

  /// No description provided for @uploadProgressGoBack.
  ///
  /// In en, this message translates to:
  /// **'Go Back'**
  String get uploadProgressGoBack;

  /// No description provided for @uploadProgressRetryWithCount.
  ///
  /// In en, this message translates to:
  /// **'Retry ({count} left)'**
  String uploadProgressRetryWithCount(int count);

  /// No description provided for @uploadProgressDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get uploadProgressDelete;

  /// No description provided for @uploadProgressDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}d ago'**
  String uploadProgressDaysAgo(int count);

  /// No description provided for @uploadProgressHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String uploadProgressHoursAgo(int count);

  /// No description provided for @uploadProgressMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count}m ago'**
  String uploadProgressMinutesAgo(int count);

  /// No description provided for @uploadProgressJustNow.
  ///
  /// In en, this message translates to:
  /// **'Just now'**
  String get uploadProgressJustNow;

  /// No description provided for @uploadProgressUploadingPercent.
  ///
  /// In en, this message translates to:
  /// **'Uploading {percent}%'**
  String uploadProgressUploadingPercent(int percent);

  /// No description provided for @uploadProgressPausedPercent.
  ///
  /// In en, this message translates to:
  /// **'Paused {percent}%'**
  String uploadProgressPausedPercent(int percent);

  /// No description provided for @badgeExplanationClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get badgeExplanationClose;

  /// No description provided for @badgeExplanationOriginalVineArchive.
  ///
  /// In en, this message translates to:
  /// **'Original Vine Archive'**
  String get badgeExplanationOriginalVineArchive;

  /// No description provided for @badgeExplanationCameraProof.
  ///
  /// In en, this message translates to:
  /// **'Camera Proof'**
  String get badgeExplanationCameraProof;

  /// No description provided for @badgeExplanationAuthenticitySignals.
  ///
  /// In en, this message translates to:
  /// **'Authenticity Signals'**
  String get badgeExplanationAuthenticitySignals;

  /// No description provided for @badgeExplanationVineArchiveIntro.
  ///
  /// In en, this message translates to:
  /// **'This video is an original Vine recovered from the Internet Archive.'**
  String get badgeExplanationVineArchiveIntro;

  /// No description provided for @badgeExplanationVineArchiveHistory.
  ///
  /// In en, this message translates to:
  /// **'Before Vine shut down in 2017, ArchiveTeam and the Internet Archive worked to preserve millions of Vines for posterity. This content is part of that historic preservation effort.'**
  String get badgeExplanationVineArchiveHistory;

  /// No description provided for @badgeExplanationOriginalStats.
  ///
  /// In en, this message translates to:
  /// **'Original stats: {loops} loops'**
  String badgeExplanationOriginalStats(int loops);

  /// No description provided for @badgeExplanationLearnVineArchive.
  ///
  /// In en, this message translates to:
  /// **'Learn more about the Vine archive preservation'**
  String get badgeExplanationLearnVineArchive;

  /// No description provided for @badgeExplanationLearnProofmode.
  ///
  /// In en, this message translates to:
  /// **'Learn more about Proofmode verification'**
  String get badgeExplanationLearnProofmode;

  /// No description provided for @badgeExplanationLearnAuthenticity.
  ///
  /// In en, this message translates to:
  /// **'Learn more about Divine authenticity signals'**
  String get badgeExplanationLearnAuthenticity;

  /// No description provided for @badgeExplanationInspectProofCheck.
  ///
  /// In en, this message translates to:
  /// **'Inspect with ProofCheck Tool'**
  String get badgeExplanationInspectProofCheck;

  /// No description provided for @badgeExplanationInspectMedia.
  ///
  /// In en, this message translates to:
  /// **'Inspect media details'**
  String get badgeExplanationInspectMedia;

  /// No description provided for @badgeExplanationProofmodeVerified.
  ///
  /// In en, this message translates to:
  /// **'This video\'s authenticity is verified using Proofmode technology.'**
  String get badgeExplanationProofmodeVerified;

  /// No description provided for @badgeExplanationDivineHostedHumanMade.
  ///
  /// In en, this message translates to:
  /// **'This video is hosted on Divine and AI detection indicates it is likely human-made, but it does not include cryptographic camera-verification data.'**
  String get badgeExplanationDivineHostedHumanMade;

  /// No description provided for @badgeExplanationHumanMadeNoCrypto.
  ///
  /// In en, this message translates to:
  /// **'AI detection indicates this video is likely human-made, though it does not include cryptographic camera-verification data.'**
  String get badgeExplanationHumanMadeNoCrypto;

  /// No description provided for @badgeExplanationDivineHostedNoCrypto.
  ///
  /// In en, this message translates to:
  /// **'This video is hosted on Divine, but it does not include cryptographic camera-verification data yet.'**
  String get badgeExplanationDivineHostedNoCrypto;

  /// No description provided for @badgeExplanationExternalNoCrypto.
  ///
  /// In en, this message translates to:
  /// **'This video is hosted outside Divine and does not include cryptographic camera-verification data.'**
  String get badgeExplanationExternalNoCrypto;

  /// No description provided for @badgeExplanationDeviceAttestation.
  ///
  /// In en, this message translates to:
  /// **'Device attestation'**
  String get badgeExplanationDeviceAttestation;

  /// No description provided for @badgeExplanationPgpSignature.
  ///
  /// In en, this message translates to:
  /// **'PGP signature'**
  String get badgeExplanationPgpSignature;

  /// No description provided for @badgeExplanationC2paCredentials.
  ///
  /// In en, this message translates to:
  /// **'C2PA Content Credentials'**
  String get badgeExplanationC2paCredentials;

  /// No description provided for @badgeExplanationProofManifest.
  ///
  /// In en, this message translates to:
  /// **'Proof manifest'**
  String get badgeExplanationProofManifest;

  /// No description provided for @badgeExplanationAiDetection.
  ///
  /// In en, this message translates to:
  /// **'AI Detection'**
  String get badgeExplanationAiDetection;

  /// No description provided for @badgeExplanationAiNotScanned.
  ///
  /// In en, this message translates to:
  /// **'AI scan: Not yet scanned'**
  String get badgeExplanationAiNotScanned;

  /// No description provided for @badgeExplanationNoScanResults.
  ///
  /// In en, this message translates to:
  /// **'No scan results available yet.'**
  String get badgeExplanationNoScanResults;

  /// No description provided for @badgeExplanationCheckAiGenerated.
  ///
  /// In en, this message translates to:
  /// **'Check if AI-generated'**
  String get badgeExplanationCheckAiGenerated;

  /// No description provided for @badgeExplanationAiLikelihood.
  ///
  /// In en, this message translates to:
  /// **'{percentage}% likelihood of being AI-generated'**
  String badgeExplanationAiLikelihood(int percentage);

  /// No description provided for @badgeExplanationScannedBy.
  ///
  /// In en, this message translates to:
  /// **'Scanned by: {source}'**
  String badgeExplanationScannedBy(String source);

  /// No description provided for @badgeExplanationVerifiedByModerator.
  ///
  /// In en, this message translates to:
  /// **'Verified by human moderator'**
  String get badgeExplanationVerifiedByModerator;

  /// No description provided for @badgeExplanationVerificationPlatinum.
  ///
  /// In en, this message translates to:
  /// **'Platinum: Device hardware attestation, cryptographic signatures, Content Credentials (C2PA), and AI scan confirms human origin.'**
  String get badgeExplanationVerificationPlatinum;

  /// No description provided for @badgeExplanationVerificationGold.
  ///
  /// In en, this message translates to:
  /// **'Gold: Captured on a real device with hardware attestation, cryptographic signatures, and Content Credentials (C2PA).'**
  String get badgeExplanationVerificationGold;

  /// No description provided for @badgeExplanationVerificationSilver.
  ///
  /// In en, this message translates to:
  /// **'Silver: Cryptographic signatures prove this video hasn\'t been altered since recording.'**
  String get badgeExplanationVerificationSilver;

  /// No description provided for @badgeExplanationVerificationBronze.
  ///
  /// In en, this message translates to:
  /// **'Bronze: Basic metadata signatures are present.'**
  String get badgeExplanationVerificationBronze;

  /// No description provided for @badgeExplanationVerificationSilverAiScan.
  ///
  /// In en, this message translates to:
  /// **'Silver: AI scan confirms this video is likely human-created.'**
  String get badgeExplanationVerificationSilverAiScan;

  /// No description provided for @badgeExplanationNoVerification.
  ///
  /// In en, this message translates to:
  /// **'No verification data available for this video.'**
  String get badgeExplanationNoVerification;

  /// No description provided for @shareMenuTitle.
  ///
  /// In en, this message translates to:
  /// **'Share Video'**
  String get shareMenuTitle;

  /// No description provided for @shareMenuReportAiContent.
  ///
  /// In en, this message translates to:
  /// **'Report AI Content'**
  String get shareMenuReportAiContent;

  /// No description provided for @shareMenuReportAiContentSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Quick report suspected AI-generated content'**
  String get shareMenuReportAiContentSubtitle;

  /// No description provided for @shareMenuReportingAiContent.
  ///
  /// In en, this message translates to:
  /// **'Reporting AI content...'**
  String get shareMenuReportingAiContent;

  /// No description provided for @shareMenuFailedToReportContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to report content: {error}'**
  String shareMenuFailedToReportContent(String error);

  /// No description provided for @shareMenuFailedToReportAiContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to report AI content: {error}'**
  String shareMenuFailedToReportAiContent(String error);

  /// No description provided for @shareMenuVideoStatus.
  ///
  /// In en, this message translates to:
  /// **'Video Status'**
  String get shareMenuVideoStatus;

  /// No description provided for @shareMenuViewAllLists.
  ///
  /// In en, this message translates to:
  /// **'View all lists →'**
  String get shareMenuViewAllLists;

  /// No description provided for @shareMenuShareWith.
  ///
  /// In en, this message translates to:
  /// **'Share With'**
  String get shareMenuShareWith;

  /// No description provided for @shareMenuShareViaOtherApps.
  ///
  /// In en, this message translates to:
  /// **'Share via other apps'**
  String get shareMenuShareViaOtherApps;

  /// No description provided for @shareMenuShareViaOtherAppsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Share via other apps or copy link'**
  String get shareMenuShareViaOtherAppsSubtitle;

  /// No description provided for @shareMenuSaveToGallery.
  ///
  /// In en, this message translates to:
  /// **'Save to Gallery'**
  String get shareMenuSaveToGallery;

  /// No description provided for @shareMenuSaveOriginalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save original video to camera roll'**
  String get shareMenuSaveOriginalSubtitle;

  /// No description provided for @shareMenuSaveWithWatermark.
  ///
  /// In en, this message translates to:
  /// **'Save with Watermark'**
  String get shareMenuSaveWithWatermark;

  /// No description provided for @shareMenuSaveVideo.
  ///
  /// In en, this message translates to:
  /// **'Save Video'**
  String get shareMenuSaveVideo;

  /// No description provided for @shareMenuDownloadWithWatermark.
  ///
  /// In en, this message translates to:
  /// **'Download with Divine watermark'**
  String get shareMenuDownloadWithWatermark;

  /// No description provided for @shareMenuSaveVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save video to camera roll'**
  String get shareMenuSaveVideoSubtitle;

  /// No description provided for @shareMenuLists.
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get shareMenuLists;

  /// No description provided for @shareMenuAddToList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get shareMenuAddToList;

  /// No description provided for @shareMenuAddToListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Add to your curated lists'**
  String get shareMenuAddToListSubtitle;

  /// No description provided for @shareMenuCreateNewList.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get shareMenuCreateNewList;

  /// No description provided for @shareMenuCreateNewListSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start a new curated collection'**
  String get shareMenuCreateNewListSubtitle;

  /// No description provided for @shareMenuRemovedFromList.
  ///
  /// In en, this message translates to:
  /// **'Removed from list'**
  String get shareMenuRemovedFromList;

  /// No description provided for @shareMenuFailedToRemoveFromList.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove from list'**
  String get shareMenuFailedToRemoveFromList;

  /// No description provided for @shareMenuBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks'**
  String get shareMenuBookmarks;

  /// No description provided for @shareMenuAddToBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Add to Bookmarks'**
  String get shareMenuAddToBookmarks;

  /// No description provided for @shareMenuAddToBookmarksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Save for later viewing'**
  String get shareMenuAddToBookmarksSubtitle;

  /// No description provided for @shareMenuAddToBookmarkSet.
  ///
  /// In en, this message translates to:
  /// **'Add to Bookmark Set'**
  String get shareMenuAddToBookmarkSet;

  /// No description provided for @shareMenuAddToBookmarkSetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Organize in collections'**
  String get shareMenuAddToBookmarkSetSubtitle;

  /// No description provided for @shareMenuFollowSets.
  ///
  /// In en, this message translates to:
  /// **'Follow Sets'**
  String get shareMenuFollowSets;

  /// No description provided for @shareMenuCreateFollowSet.
  ///
  /// In en, this message translates to:
  /// **'Create Follow Set'**
  String get shareMenuCreateFollowSet;

  /// No description provided for @shareMenuCreateFollowSetSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Start new collection with this creator'**
  String get shareMenuCreateFollowSetSubtitle;

  /// No description provided for @shareMenuAddToFollowSet.
  ///
  /// In en, this message translates to:
  /// **'Add to Follow Set'**
  String get shareMenuAddToFollowSet;

  /// No description provided for @shareMenuFollowSetsAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count} follow sets available'**
  String shareMenuFollowSetsAvailable(int count);

  /// No description provided for @shareMenuAddedToBookmarks.
  ///
  /// In en, this message translates to:
  /// **'Added to bookmarks!'**
  String get shareMenuAddedToBookmarks;

  /// No description provided for @shareMenuFailedToAddBookmark.
  ///
  /// In en, this message translates to:
  /// **'Failed to add bookmark'**
  String get shareMenuFailedToAddBookmark;

  /// No description provided for @shareMenuCreatedListAndAddedVideo.
  ///
  /// In en, this message translates to:
  /// **'Created list \"{name}\" and added video'**
  String shareMenuCreatedListAndAddedVideo(String name);

  /// No description provided for @shareMenuManageContent.
  ///
  /// In en, this message translates to:
  /// **'Manage Content'**
  String get shareMenuManageContent;

  /// No description provided for @shareMenuEditVideo.
  ///
  /// In en, this message translates to:
  /// **'Edit Video'**
  String get shareMenuEditVideo;

  /// No description provided for @shareMenuEditVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update title, description, and hashtags'**
  String get shareMenuEditVideoSubtitle;

  /// No description provided for @shareMenuDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Delete Video'**
  String get shareMenuDeleteVideo;

  /// No description provided for @shareMenuDeleteVideoSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove this content'**
  String get shareMenuDeleteVideoSubtitle;

  /// No description provided for @shareMenuVideoInTheseLists.
  ///
  /// In en, this message translates to:
  /// **'Video is in these lists:'**
  String get shareMenuVideoInTheseLists;

  /// No description provided for @shareMenuVideoCount.
  ///
  /// In en, this message translates to:
  /// **'{count} videos'**
  String shareMenuVideoCount(int count);

  /// No description provided for @shareMenuClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get shareMenuClose;

  /// No description provided for @shareMenuDeleteConfirmation.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this video?'**
  String get shareMenuDeleteConfirmation;

  /// No description provided for @shareMenuDeleteWarning.
  ///
  /// In en, this message translates to:
  /// **'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.'**
  String get shareMenuDeleteWarning;

  /// No description provided for @shareMenuCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get shareMenuCancel;

  /// No description provided for @shareMenuDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get shareMenuDelete;

  /// No description provided for @shareMenuDeletingContent.
  ///
  /// In en, this message translates to:
  /// **'Deleting content...'**
  String get shareMenuDeletingContent;

  /// No description provided for @shareMenuDeleteRequestSent.
  ///
  /// In en, this message translates to:
  /// **'Delete request sent successfully'**
  String get shareMenuDeleteRequestSent;

  /// No description provided for @shareMenuFailedToDeleteContent.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete content: {error}'**
  String shareMenuFailedToDeleteContent(String error);

  /// No description provided for @shareMenuFollowSetName.
  ///
  /// In en, this message translates to:
  /// **'Follow Set Name'**
  String get shareMenuFollowSetName;

  /// No description provided for @shareMenuFollowSetNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Content Creators, Musicians, etc.'**
  String get shareMenuFollowSetNameHint;

  /// No description provided for @shareMenuDescriptionOptional.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get shareMenuDescriptionOptional;

  /// No description provided for @shareMenuCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get shareMenuCreate;

  /// No description provided for @shareMenuCreatedFollowSetAndAddedCreator.
  ///
  /// In en, this message translates to:
  /// **'Created follow set \"{name}\" and added creator'**
  String shareMenuCreatedFollowSetAndAddedCreator(String name);

  /// No description provided for @shareMenuDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get shareMenuDone;

  /// No description provided for @shareMenuEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get shareMenuEditTitle;

  /// No description provided for @shareMenuEditTitleHint.
  ///
  /// In en, this message translates to:
  /// **'Enter video title'**
  String get shareMenuEditTitleHint;

  /// No description provided for @shareMenuEditDescription.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get shareMenuEditDescription;

  /// No description provided for @shareMenuEditDescriptionHint.
  ///
  /// In en, this message translates to:
  /// **'Enter video description'**
  String get shareMenuEditDescriptionHint;

  /// No description provided for @shareMenuEditHashtags.
  ///
  /// In en, this message translates to:
  /// **'Hashtags'**
  String get shareMenuEditHashtags;

  /// No description provided for @shareMenuEditHashtagsHint.
  ///
  /// In en, this message translates to:
  /// **'comma, separated, hashtags'**
  String get shareMenuEditHashtagsHint;

  /// No description provided for @shareMenuEditMetadataNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Only metadata can be edited. Video content cannot be changed.'**
  String get shareMenuEditMetadataNote;

  /// No description provided for @shareMenuDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting...'**
  String get shareMenuDeleting;

  /// No description provided for @shareMenuUpdate.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get shareMenuUpdate;

  /// No description provided for @shareMenuVideoUpdated.
  ///
  /// In en, this message translates to:
  /// **'Video updated successfully'**
  String get shareMenuVideoUpdated;

  /// No description provided for @shareMenuFailedToUpdateVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to update video: {error}'**
  String shareMenuFailedToUpdateVideo(String error);

  /// No description provided for @shareMenuDeleteVideoQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Video?'**
  String get shareMenuDeleteVideoQuestion;

  /// No description provided for @shareMenuDeleteRelayWarning.
  ///
  /// In en, this message translates to:
  /// **'This will send a deletion request to relays. Note: Some relays may still have cached copies.'**
  String get shareMenuDeleteRelayWarning;

  /// No description provided for @shareMenuVideoDeletionRequested.
  ///
  /// In en, this message translates to:
  /// **'Video deletion requested'**
  String get shareMenuVideoDeletionRequested;

  /// No description provided for @shareMenuFailedToDeleteVideo.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete video: {error}'**
  String shareMenuFailedToDeleteVideo(String error);

  /// No description provided for @shareMenuContentLabels.
  ///
  /// In en, this message translates to:
  /// **'Content labels'**
  String get shareMenuContentLabels;

  /// No description provided for @shareMenuAddContentLabels.
  ///
  /// In en, this message translates to:
  /// **'Add content labels'**
  String get shareMenuAddContentLabels;

  /// No description provided for @shareMenuClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get shareMenuClearAll;

  /// No description provided for @shareMenuCollaborators.
  ///
  /// In en, this message translates to:
  /// **'Collaborators'**
  String get shareMenuCollaborators;

  /// No description provided for @shareMenuAddCollaborator.
  ///
  /// In en, this message translates to:
  /// **'Add collaborator'**
  String get shareMenuAddCollaborator;

  /// No description provided for @shareMenuMutualFollowRequired.
  ///
  /// In en, this message translates to:
  /// **'You need to mutually follow {name} to add them as a collaborator.'**
  String shareMenuMutualFollowRequired(String name);

  /// No description provided for @shareMenuLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get shareMenuLoading;

  /// No description provided for @shareMenuInspiredBy.
  ///
  /// In en, this message translates to:
  /// **'Inspired by'**
  String get shareMenuInspiredBy;

  /// No description provided for @shareMenuAddInspirationCredit.
  ///
  /// In en, this message translates to:
  /// **'Add inspiration credit'**
  String get shareMenuAddInspirationCredit;

  /// No description provided for @shareMenuCreatorCannotBeReferenced.
  ///
  /// In en, this message translates to:
  /// **'This creator cannot be referenced.'**
  String get shareMenuCreatorCannotBeReferenced;

  /// No description provided for @shareMenuUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get shareMenuUnknown;

  /// No description provided for @shareMenuCreateBookmarkSet.
  ///
  /// In en, this message translates to:
  /// **'Create Bookmark Set'**
  String get shareMenuCreateBookmarkSet;

  /// No description provided for @shareMenuSetName.
  ///
  /// In en, this message translates to:
  /// **'Set Name'**
  String get shareMenuSetName;

  /// No description provided for @shareMenuSetNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g., Favorites, Watch Later, etc.'**
  String get shareMenuSetNameHint;

  /// No description provided for @shareMenuCreateNewSet.
  ///
  /// In en, this message translates to:
  /// **'Create New Set'**
  String get shareMenuCreateNewSet;

  /// No description provided for @shareMenuStartNewBookmarkCollection.
  ///
  /// In en, this message translates to:
  /// **'Start a new bookmark collection'**
  String get shareMenuStartNewBookmarkCollection;

  /// No description provided for @shareMenuNoBookmarkSets.
  ///
  /// In en, this message translates to:
  /// **'No bookmark sets yet. Create your first one!'**
  String get shareMenuNoBookmarkSets;

  /// No description provided for @shareMenuError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get shareMenuError;

  /// No description provided for @shareMenuFailedToLoadBookmarkSets.
  ///
  /// In en, this message translates to:
  /// **'Failed to load bookmark sets'**
  String get shareMenuFailedToLoadBookmarkSets;

  /// No description provided for @shareMenuCreatedSetAndAddedVideo.
  ///
  /// In en, this message translates to:
  /// **'Created \"{name}\" and added video'**
  String shareMenuCreatedSetAndAddedVideo(String name);

  /// No description provided for @shareMenuUseThisSound.
  ///
  /// In en, this message translates to:
  /// **'Use this sound'**
  String get shareMenuUseThisSound;

  /// No description provided for @shareMenuOriginalSound.
  ///
  /// In en, this message translates to:
  /// **'Original sound'**
  String get shareMenuOriginalSound;

  /// No description provided for @authSessionExpired.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get authSessionExpired;

  /// No description provided for @authSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sign in. Please try again.'**
  String get authSignInFailed;

  /// No description provided for @localeAppLanguage.
  ///
  /// In en, this message translates to:
  /// **'App Language'**
  String get localeAppLanguage;

  /// No description provided for @localeDeviceDefault.
  ///
  /// In en, this message translates to:
  /// **'Device default'**
  String get localeDeviceDefault;

  /// No description provided for @localeSelectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get localeSelectLanguage;
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
