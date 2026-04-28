// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Divine';

  @override
  String get settingsTitle => 'Settings';

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
  String get settingsAppLanguage => 'App Language';

  @override
  String settingsAppLanguageDeviceDefault(String language) {
    return '$language (device default)';
  }

  @override
  String get settingsAppLanguageTitle => 'App Language';

  @override
  String get settingsAppLanguageDescription =>
      'Choose the language for the app interface';

  @override
  String get settingsAppLanguageUseDeviceLanguage => 'Use device language';

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

  @override
  String get profileBlockedAccountNotAvailable =>
      'This account is not available';

  @override
  String profileErrorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get profileInvalidId => 'Invalid profile ID';

  @override
  String profileShareText(String displayName, String npub) {
    return 'Check out $displayName on Divine!\n\nhttps://divine.video/profile/$npub';
  }

  @override
  String profileShareSubject(String displayName) {
    return '$displayName on Divine';
  }

  @override
  String profileShareFailed(Object error) {
    return 'Failed to share profile: $error';
  }

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileCreatorAnalytics => 'Creator analytics';

  @override
  String get profileShareProfile => 'Share profile';

  @override
  String get profileCopyPublicKey => 'Copy public key (npub)';

  @override
  String get profileGetEmbedCode => 'Get embed code';

  @override
  String get profilePublicKeyCopied => 'Public key copied to clipboard';

  @override
  String get profileEmbedCodeCopied => 'Embed code copied to clipboard';

  @override
  String get profileRefreshTooltip => 'Refresh';

  @override
  String get profileRefreshSemanticLabel => 'Refresh profile';

  @override
  String get profileMoreTooltip => 'More';

  @override
  String get profileMoreSemanticLabel => 'More options';

  @override
  String get profileFollowingLabel => 'Following';

  @override
  String get profileFollowLabel => 'Follow';

  @override
  String get profileBlockedLabel => 'Blocked';

  @override
  String get profileFollowersLabel => 'Followers';

  @override
  String get profileFollowingStatLabel => 'Following';

  @override
  String get profileVideosLabel => 'Videos';

  @override
  String profileFollowerCountUsers(int count) {
    return '$count users';
  }

  @override
  String profileBlockTitle(String displayName) {
    return 'Block $displayName?';
  }

  @override
  String get profileBlockExplanation => 'When you block a user:';

  @override
  String get profileBlockBulletHidePosts =>
      'Their posts will not appear in your feeds.';

  @override
  String get profileBlockBulletCantView =>
      'They will be unable to view your profile, follow you, or view your posts.';

  @override
  String get profileBlockBulletNoNotify =>
      'They will not be notified of this change.';

  @override
  String get profileBlockBulletYouCanView =>
      'You will still be able to view their profile.';

  @override
  String profileBlockConfirmButton(String displayName) {
    return 'Block $displayName';
  }

  @override
  String get profileCancelButton => 'Cancel';

  @override
  String get profileLearnMore => 'Learn More';

  @override
  String profileUnblockTitle(String displayName) {
    return 'Unblock $displayName?';
  }

  @override
  String get profileUnblockExplanation => 'When you unblock this user:';

  @override
  String get profileUnblockBulletShowPosts =>
      'Their posts will appear in your feeds.';

  @override
  String get profileUnblockBulletCanView =>
      'They will be able to view your profile, follow you, and view your posts.';

  @override
  String get profileUnblockBulletNoNotify =>
      'They will not be notified of this change.';

  @override
  String get profileLearnMoreAt => 'Learn more at ';

  @override
  String get profileUnblockButton => 'Unblock';

  @override
  String profileUnfollowDisplayName(String displayName) {
    return 'Unfollow $displayName';
  }

  @override
  String profileBlockDisplayName(String displayName) {
    return 'Block $displayName';
  }

  @override
  String profileUnblockDisplayName(String displayName) {
    return 'Unblock $displayName';
  }

  @override
  String get profileUserBlockedTitle => 'User Blocked';

  @override
  String get profileUserBlockedContent =>
      'You won\'t see content from this user in your feeds.';

  @override
  String get profileUserBlockedUnblockHint =>
      'You can unblock them anytime from their profile or in Settings > Safety.';

  @override
  String get profileCloseButton => 'Close';

  @override
  String get profileNoCollabsTitle => 'No collabs yet';

  @override
  String get profileCollabsOwnEmpty =>
      'Videos you collaborate on will appear here.';

  @override
  String get profileCollabsOtherEmpty =>
      'Videos they collaborate on will appear here.';

  @override
  String get profileErrorLoadingCollabs => 'Error loading collab videos';

  @override
  String get profileNoSavedVideosTitle => 'Nothing saved yet';

  @override
  String get profileSavedOwnEmpty =>
      'Bookmark videos from the share sheet and they\'ll show up here.';

  @override
  String get profileErrorLoadingSaved => 'Error loading saved videos';

  @override
  String get profileNoCommentsOwnTitle => 'No comments yet';

  @override
  String get profileNoCommentsOtherTitle => 'No comments yet';

  @override
  String get profileCommentsOwnEmpty =>
      'Your comments and replies will appear here.';

  @override
  String get profileCommentsOtherEmpty =>
      'Their comments and replies will appear here.';

  @override
  String get profileErrorLoadingComments => 'Error loading comments';

  @override
  String get profileVideoRepliesSection => 'Video Replies';

  @override
  String get profileCommentsSection => 'Comments';

  @override
  String get profileEditLabel => 'Edit';

  @override
  String get profileLibraryLabel => 'Library';

  @override
  String get profileNoLikedVideosTitle => 'No likes yet';

  @override
  String get profileLikedOwnEmpty =>
      'When something catches your eye, tap the heart. Your likes will show up here.';

  @override
  String get profileLikedOtherEmpty =>
      'Nothing caught their eye yet. Give it time.';

  @override
  String get profileErrorLoadingLiked => 'Error loading liked videos';

  @override
  String get profileNoRepostsTitle => 'No reposts yet';

  @override
  String get profileRepostsOwnEmpty =>
      'See something worth sharing? Repost it and it\'ll appear here.';

  @override
  String get profileRepostsOtherEmpty =>
      'They haven\'t passed anything on yet. When they do, it\'ll show up here.';

  @override
  String get profileErrorLoadingReposts => 'Error loading reposted videos';

  @override
  String get profileLoadingTitle => 'Loading profile...';

  @override
  String get profileLoadingSubtitle => 'This may take a few moments';

  @override
  String get profileLoadingVideos => 'Loading videos...';

  @override
  String get profileNoVideosTitle => 'No videos yet';

  @override
  String get profileNoVideosOwnSubtitle =>
      'Your stage is set. Start posting and your videos will live here.';

  @override
  String get profileNoVideosOtherSubtitle =>
      'The world is waiting. Follow them so you don\'t miss it.';

  @override
  String profileVideoThumbnailLabel(int number) {
    return 'Video thumbnail $number';
  }

  @override
  String get profileShowMore => 'Show more';

  @override
  String get profileShowLess => 'Show less';

  @override
  String get profileCompleteYourProfile => 'Complete Your Profile';

  @override
  String get profileCompleteSubtitle =>
      'Add your name, bio, and picture to get started';

  @override
  String get profileSetUpButton => 'Set Up';

  @override
  String get profileVerifyingEmail => 'Verifying Email...';

  @override
  String profileCheckEmailVerification(String email) {
    return 'Check $email for verification link';
  }

  @override
  String get profileWaitingForVerification => 'Waiting for email verification';

  @override
  String get profileVerificationFailed => 'Verification Failed';

  @override
  String get profilePleaseTryAgain => 'Please try again';

  @override
  String get profileSecureYourAccount => 'Secure Your Account';

  @override
  String get profileSecureSubtitle =>
      'Add email & password to recover your account on any device';

  @override
  String get profileRetryButton => 'Retry';

  @override
  String get profileRegisterButton => 'Register';

  @override
  String get profileSessionExpired => 'Session Expired';

  @override
  String get profileSignInToRestore => 'Sign in again to restore full access';

  @override
  String get profileSignInButton => 'Sign in';

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
  String get profileDismissTooltip => 'Dismiss';

  @override
  String get profileLinkCopied => 'Profile link copied';

  @override
  String get profileSetupEditProfileTitle => 'Edit Profile';

  @override
  String get profileSetupBackLabel => 'Back';

  @override
  String get profileSetupAboutNostr => 'About Nostr';

  @override
  String get profileSetupProfilePublished => 'Profile published successfully!';

  @override
  String get profileSetupCreateNewProfile => 'Create new profile?';

  @override
  String get profileSetupNoExistingProfile =>
      'We didn\'t find an existing profile on your relays. Publishing will create a new profile. Continue?';

  @override
  String get profileSetupPublishButton => 'Publish';

  @override
  String get profileSetupUsernameTaken =>
      'Username was just taken. Please choose another.';

  @override
  String get profileSetupClaimFailed =>
      'Failed to claim username. Please try again.';

  @override
  String get profileSetupPublishFailed =>
      'Failed to publish profile. Please try again.';

  @override
  String get profileSetupNoRelaysConnected =>
      'Couldn\'t reach the network. Check your connection and try again.';

  @override
  String get profileSetupRetryLabel => 'Retry';

  @override
  String get profileSetupDisplayNameLabel => 'Display Name';

  @override
  String get profileSetupDisplayNameHint => 'How should people know you?';

  @override
  String get profileSetupDisplayNameHelper =>
      'Any name or label you want. Doesn\'t have to be unique.';

  @override
  String get profileSetupDisplayNameRequired => 'Please enter a display name';

  @override
  String get profileSetupBioLabel => 'Bio (Optional)';

  @override
  String get profileSetupBioHint => 'Tell people about yourself...';

  @override
  String get profileSetupPublicKeyLabel => 'Public key (npub)';

  @override
  String get profileSetupUsernameLabel => 'Username (Optional)';

  @override
  String get profileSetupUsernameHint => 'username';

  @override
  String get profileSetupUsernameHelper => 'Your unique identity on Divine';

  @override
  String get profileSetupProfileColorLabel => 'Profile Color (Optional)';

  @override
  String get profileSetupSaveButton => 'Save';

  @override
  String get profileSetupSavingButton => 'Saving...';

  @override
  String get profileSetupImageUrlTitle => 'Add image URL';

  @override
  String get profileSetupPictureUploaded =>
      'Profile picture uploaded successfully!';

  @override
  String get profileSetupImageSelectionFailed =>
      'Image selection failed. Please paste an image URL below instead.';

  @override
  String profileSetupCameraAccessFailed(Object error) {
    return 'Camera access failed: $error';
  }

  @override
  String get profileSetupGotItButton => 'Got it';

  @override
  String profileSetupUploadFailedGeneric(Object error) {
    return 'Failed to upload image: $error';
  }

  @override
  String get profileSetupUploadNetworkError =>
      'Network error: Please check your internet connection and try again.';

  @override
  String get profileSetupUploadAuthError =>
      'Authentication error: Please try logging out and back in.';

  @override
  String get profileSetupUploadFileTooLarge =>
      'File too large: Please choose a smaller image (max 10MB).';

  @override
  String get profileSetupUsernameChecking => 'Checking availability...';

  @override
  String get profileSetupUsernameAvailable => 'Username available!';

  @override
  String get profileSetupUsernameTakenIndicator => 'Username already taken';

  @override
  String get profileSetupUsernameReserved => 'Username is reserved';

  @override
  String get profileSetupContactSupport => 'Contact support';

  @override
  String get profileSetupCheckAgain => 'Check again';

  @override
  String get profileSetupUsernameBurned =>
      'This username is no longer available';

  @override
  String get profileSetupUsernameInvalidFormat =>
      'Only letters, numbers, and hyphens are allowed';

  @override
  String get profileSetupUsernameInvalidLength =>
      'Username must be 3-20 characters';

  @override
  String get profileSetupUsernameNetworkError =>
      'Could not check availability. Please try again.';

  @override
  String get profileSetupUsernameInvalidFormatGeneric =>
      'Invalid username format';

  @override
  String get profileSetupUsernameCheckFailed => 'Failed to check availability';

  @override
  String get profileSetupUsernameReservedTitle => 'Username reserved';

  @override
  String profileSetupUsernameReservedBody(String username) {
    return 'The name $username is reserved. Tell us why it should be yours.';
  }

  @override
  String get profileSetupUsernameReservedHint =>
      'e.g. It\'s my brand name, stage name, etc.';

  @override
  String get profileSetupUsernameReservedCheckHint =>
      'Already contacted support? Tap \"Check again\" to see if it\'s been released to you.';

  @override
  String get profileSetupSupportRequestSent =>
      'Support request sent! We\'ll get back to you soon.';

  @override
  String get profileSetupCouldntOpenEmail =>
      'Couldn\'t open email. Send to: names@divine.video';

  @override
  String get profileSetupSendRequest => 'Send request';

  @override
  String get profileSetupPickColorTitle => 'Pick a color';

  @override
  String get profileSetupSelectButton => 'Select';

  @override
  String get profileSetupUseOwnNip05 => 'Use your own NIP-05 address';

  @override
  String get profileSetupNip05AddressLabel => 'NIP-05 Address';

  @override
  String get profileSetupProfilePicturePreview => 'Profile picture preview';

  @override
  String get nostrInfoIntroBuiltOn => 'DiVine is built on Nostr,';

  @override
  String get nostrInfoIntroDescription =>
      ' a censorship-resistant open protocol that lets people communicate online without relying on a single company or platform. ';

  @override
  String get nostrInfoIntroIdentity =>
      'When you sign up for Divine, you get a new Nostr identity.';

  @override
  String get nostrInfoOwnership =>
      'Nostr lets you own your content, identity and social graph, which you can use across many apps. The result is more choice, less lock-in, and a healthier, more resilient social internet.';

  @override
  String get nostrInfoLingo => 'Nostr lingo:';

  @override
  String get nostrInfoNpubLabel => 'npub:';

  @override
  String get nostrInfoNpubDescription =>
      ' Your public Nostr address. It\'s safe to share and lets others find, follow, or message you across Nostr apps.';

  @override
  String get nostrInfoNsecLabel => 'nsec:';

  @override
  String get nostrInfoNsecDescription =>
      ' Your private key and proof of ownership. It gives full control of your Nostr identity, so ';

  @override
  String get nostrInfoNsecWarning => 'always keep it secret!';

  @override
  String get nostrInfoUsernameLabel => 'Nostr username:';

  @override
  String get nostrInfoUsernameDescription =>
      ' A human-readable name (like @name.divine.video) that links to your npub. It makes your Nostr identity easier to recognize and verify, similar to an email address.';

  @override
  String get nostrInfoLearnMoreAt => 'Learn more at ';

  @override
  String get nostrInfoGotIt => 'Got it!';

  @override
  String get profileTabRefreshTooltip => 'Refresh';

  @override
  String get videoGridRefreshLabel => 'Searching for more videos';

  @override
  String get videoGridOptionsTitle => 'Video Options';

  @override
  String get videoGridEditVideo => 'Edit Video';

  @override
  String get videoGridEditVideoSubtitle =>
      'Update title, description, and hashtags';

  @override
  String get videoGridDeleteVideo => 'Delete Video';

  @override
  String get videoGridDeleteVideoSubtitle =>
      'Remove this video from Divine. It may still appear on other Nostr clients.';

  @override
  String get videoGridDeleteConfirmTitle => 'Delete Video';

  @override
  String get videoGridDeleteConfirmMessage =>
      'This will permanently delete this video from Divine. It may still appear on third-party Nostr clients that use other relays.';

  @override
  String get videoGridDeleteConfirmNote =>
      'This will send a deletion request to relays. Note: Some relays may still have cached copies.';

  @override
  String get videoGridDeleteCancel => 'Cancel';

  @override
  String get videoGridDeleteConfirm => 'Delete';

  @override
  String get videoGridDeletingContent => 'Deleting content...';

  @override
  String get videoGridDeleteSuccess => 'Delete request sent successfully';

  @override
  String videoGridDeleteFailure(Object error) {
    return 'Failed to delete content: $error';
  }

  @override
  String get exploreTabClassics => 'Classics';

  @override
  String get exploreTabNew => 'New';

  @override
  String get exploreTabPopular => 'Popular';

  @override
  String get exploreTabCategories => 'Categories';

  @override
  String get exploreTabForYou => 'For You';

  @override
  String get exploreTabLists => 'Lists';

  @override
  String get exploreTabIntegratedApps => 'Integrated Apps';

  @override
  String get exploreNoVideosAvailable => 'No videos available';

  @override
  String exploreErrorPrefix(Object error) {
    return 'Error: $error';
  }

  @override
  String get exploreDiscoverLists => 'Discover Lists';

  @override
  String get exploreAboutLists => 'About Lists';

  @override
  String get exploreAboutListsDescription =>
      'Lists help you organize and curate Divine content in two ways:';

  @override
  String get explorePeopleLists => 'People Lists';

  @override
  String get explorePeopleListsDescription =>
      'Follow groups of creators and see their latest videos';

  @override
  String get exploreVideoLists => 'Video Lists';

  @override
  String get exploreVideoListsDescription =>
      'Create playlists of your favorite videos to watch later';

  @override
  String get exploreMyLists => 'My Lists';

  @override
  String get exploreSubscribedLists => 'Subscribed Lists';

  @override
  String exploreErrorLoadingLists(Object error) {
    return 'Error loading lists: $error';
  }

  @override
  String exploreNewVideosCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new videos',
      one: '1 new video',
    );
    return '$_temp0';
  }

  @override
  String exploreLoadNewVideosLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'videos',
      one: 'video',
    );
    return 'Load $count new $_temp0';
  }

  @override
  String get videoPlayerLoadingVideo => 'Loading video...';

  @override
  String get videoPlayerPlayVideo => 'Play video';

  @override
  String get videoPlayerMute => 'Mute video';

  @override
  String get videoPlayerUnmute => 'Unmute video';

  @override
  String get videoPlayerEditVideo => 'Edit video';

  @override
  String get videoPlayerEditVideoTooltip => 'Edit video';

  @override
  String get contentWarningLabel => 'Content Warning';

  @override
  String get contentWarningNudity => 'Nudity';

  @override
  String get contentWarningSexualContent => 'Sexual Content';

  @override
  String get contentWarningPornography => 'Pornography';

  @override
  String get contentWarningGraphicMedia => 'Graphic Media';

  @override
  String get contentWarningViolence => 'Violence';

  @override
  String get contentWarningSelfHarm => 'Self-Harm';

  @override
  String get contentWarningDrugUse => 'Drug Use';

  @override
  String get contentWarningAlcohol => 'Alcohol';

  @override
  String get contentWarningTobacco => 'Tobacco';

  @override
  String get contentWarningGambling => 'Gambling';

  @override
  String get contentWarningProfanity => 'Profanity';

  @override
  String get contentWarningFlashingLights => 'Flashing Lights';

  @override
  String get contentWarningAiGenerated => 'AI-Generated';

  @override
  String get contentWarningSpoiler => 'Spoiler';

  @override
  String get contentWarningSensitiveContent => 'Sensitive Content';

  @override
  String get contentWarningDescNudity => 'Contains nudity or partial nudity';

  @override
  String get contentWarningDescSexual => 'Contains sexual content';

  @override
  String get contentWarningDescPorn => 'Contains explicit pornographic content';

  @override
  String get contentWarningDescGraphicMedia =>
      'Contains graphic or disturbing imagery';

  @override
  String get contentWarningDescViolence => 'Contains violent content';

  @override
  String get contentWarningDescSelfHarm => 'Contains references to self-harm';

  @override
  String get contentWarningDescDrugs => 'Contains drug-related content';

  @override
  String get contentWarningDescAlcohol => 'Contains alcohol-related content';

  @override
  String get contentWarningDescTobacco => 'Contains tobacco-related content';

  @override
  String get contentWarningDescGambling => 'Contains gambling-related content';

  @override
  String get contentWarningDescProfanity => 'Contains strong language';

  @override
  String get contentWarningDescFlashingLights =>
      'Contains flashing lights (photosensitivity warning)';

  @override
  String get contentWarningDescAiGenerated =>
      'This content was generated by AI';

  @override
  String get contentWarningDescSpoiler => 'Contains spoilers';

  @override
  String get contentWarningDescContentWarning =>
      'Creator marked this as sensitive';

  @override
  String get contentWarningDescDefault => 'Creator flagged this content';

  @override
  String get contentWarningDetailsTitle => 'Content Warnings';

  @override
  String get contentWarningDetailsSubtitle =>
      'The creator applied these labels:';

  @override
  String get contentWarningManageFilters => 'Manage content filters';

  @override
  String get contentWarningViewAnyway => 'View Anyway';

  @override
  String get contentWarningHideAllLikeThis => 'Hide all content like this';

  @override
  String get contentWarningNoFilterYet =>
      'No saved filter for this warning yet.';

  @override
  String get contentWarningHiddenConfirmation =>
      'We\'ll hide posts like this from now on.';

  @override
  String get videoErrorNotFound => 'Video not found';

  @override
  String get videoErrorNetwork => 'Network error';

  @override
  String get videoErrorTimeout => 'Loading timeout';

  @override
  String get videoErrorFormat =>
      'Video format error\n(Try again or use different browser)';

  @override
  String get videoErrorUnsupportedFormat => 'Unsupported video format';

  @override
  String get videoErrorPlayback => 'Video playback error';

  @override
  String get videoErrorAgeRestricted => 'Age-restricted content';

  @override
  String get videoErrorVerifyAge => 'Verify Age';

  @override
  String get videoErrorRetry => 'Retry';

  @override
  String get videoErrorContentRestricted => 'Content restricted';

  @override
  String get videoErrorContentRestrictedBody =>
      'This video was restricted by the relay.';

  @override
  String get videoErrorVerifyAgeBody => 'Verify your age to view this video.';

  @override
  String get videoErrorSkip => 'Skip';

  @override
  String get videoErrorVerifyAgeButton => 'Verify age';

  @override
  String get videoFollowButtonFollowing => 'Following';

  @override
  String get videoFollowButtonFollow => 'Follow';

  @override
  String get audioAttributionOriginalSound => 'Original sound';

  @override
  String videoInspiredByAttribution(String creatorName) {
    return 'Inspired by @$creatorName';
  }

  @override
  String videoCollaboratorWithOne(String name) {
    return 'with @$name';
  }

  @override
  String videoCollaboratorWithMore(String name, int count) {
    return 'with @$name +$count';
  }

  @override
  String videoCollaboratorCountLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborators',
      one: '1 collaborator',
    );
    return '$_temp0. Tap to view profile.';
  }

  @override
  String get listAttributionFallback => 'List';

  @override
  String get shareVideoLabel => 'Share video';

  @override
  String sharePostSharedWith(String recipientName) {
    return 'Post shared with $recipientName';
  }

  @override
  String get shareFailedToSend => 'Failed to send video';

  @override
  String get shareAddedToBookmarks => 'Added to bookmarks';

  @override
  String get shareFailedToAddBookmark => 'Failed to add bookmark';

  @override
  String get shareActionFailed => 'Action failed';

  @override
  String get shareWithTitle => 'Share with';

  @override
  String get shareFindPeople => 'Find people';

  @override
  String get shareFindPeopleMultiline => 'Find\npeople';

  @override
  String get shareSent => 'Sent';

  @override
  String get shareContactFallback => 'Contact';

  @override
  String get shareUserFallback => 'User';

  @override
  String shareSendingTo(String name) {
    return 'Sending to $name';
  }

  @override
  String get shareMessageHint => 'Add optional message...';

  @override
  String get videoActionUnlike => 'Unlike video';

  @override
  String get videoActionLike => 'Like video';

  @override
  String get videoActionAutoLabel => 'Compilation';

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
  String get videoActionEnableAutoAdvance => 'Enable auto advance';

  @override
  String get videoActionDisableAutoAdvance => 'Disable auto advance';

  @override
  String get videoActionRemoveRepost => 'Remove repost';

  @override
  String get videoActionRepost => 'Repost video';

  @override
  String get videoActionViewComments => 'View comments';

  @override
  String get videoActionMoreOptions => 'More options';

  @override
  String get videoActionHideSubtitles => 'Hide subtitles';

  @override
  String get videoActionShowSubtitles => 'Show subtitles';

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
  String get metadataBadgeNotDivine => 'Not Divine';

  @override
  String get metadataBadgeHumanMade => 'Human-Made';

  @override
  String get metadataSoundsLabel => 'Sounds';

  @override
  String get metadataOriginalSound => 'Original sound';

  @override
  String get metadataVerificationLabel => 'Verification';

  @override
  String get metadataDeviceAttestation => 'Device attestation';

  @override
  String get metadataProofManifest => 'Proof manifest';

  @override
  String get metadataCreatorLabel => 'Creator';

  @override
  String get metadataCollaboratorsLabel => 'Collaborators';

  @override
  String get metadataInspiredByLabel => 'Inspired by';

  @override
  String get metadataRepostedByLabel => 'Reposted by';

  @override
  String metadataLoopsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loops',
      one: 'Loop',
    );
    return '$_temp0';
  }

  @override
  String get metadataLikesLabel => 'Likes';

  @override
  String get metadataCommentsLabel => 'Comments';

  @override
  String get metadataRepostsLabel => 'Reposts';

  @override
  String get devOptionsTitle => 'Developer Options';

  @override
  String get devOptionsPageLoadTimes => 'Page Load Times';

  @override
  String get devOptionsNoPageLoads =>
      'No page loads recorded yet.\nNavigate around the app to see timing data.';

  @override
  String devOptionsPageLoadVisible(String visibleMs, String dataMs) {
    return 'Visible: ${visibleMs}ms  |  Data: ${dataMs}ms';
  }

  @override
  String get devOptionsSlowestScreens => 'Slowest Screens';

  @override
  String get devOptionsVideoPlaybackFormat => 'Video Playback Format';

  @override
  String get devOptionsSwitchEnvironmentTitle => 'Switch Environment?';

  @override
  String devOptionsSwitchEnvironmentMessage(String envName) {
    return 'Switch to $envName?\n\nThis will clear cached video data and reconnect to the new relay.';
  }

  @override
  String get devOptionsCancel => 'Cancel';

  @override
  String get devOptionsSwitch => 'Switch';

  @override
  String devOptionsSwitchedTo(String envName) {
    return 'Switched to $envName';
  }

  @override
  String devOptionsSwitchedFormat(String formatName) {
    return 'Switched to $formatName — cache cleared';
  }

  @override
  String get featureFlagTitle => 'Feature Flags';

  @override
  String get featureFlagResetAllTooltip => 'Reset all flags to defaults';

  @override
  String get featureFlagResetToDefault => 'Reset to default';

  @override
  String get featureFlagAppRecovery => 'App Recovery';

  @override
  String get featureFlagAppRecoveryDescription =>
      'If the app is crashing or behaving strangely, try clearing the cache.';

  @override
  String get featureFlagClearAllCache => 'Clear All Cache';

  @override
  String get featureFlagCacheInfo => 'Cache Info';

  @override
  String get featureFlagClearCacheTitle => 'Clear All Cache?';

  @override
  String get featureFlagClearCacheMessage =>
      'This will clear all cached data including:\n• Notifications\n• User profiles\n• Bookmarks\n• Temporary files\n\nYou will need to log in again. Continue?';

  @override
  String get featureFlagClearCache => 'Clear Cache';

  @override
  String get featureFlagClearingCache => 'Clearing cache...';

  @override
  String get featureFlagSuccess => 'Success';

  @override
  String get featureFlagError => 'Error';

  @override
  String get featureFlagClearCacheSuccess =>
      'Cache cleared successfully. Please restart the app.';

  @override
  String get featureFlagClearCacheFailure =>
      'Failed to clear some cache items. Check logs for details.';

  @override
  String get featureFlagOk => 'OK';

  @override
  String get featureFlagCacheInformation => 'Cache Information';

  @override
  String featureFlagTotalCacheSize(String size) {
    return 'Total cache size: $size';
  }

  @override
  String get featureFlagCacheIncludes =>
      'Cache includes:\n• Notification history\n• User profile data\n• Video thumbnails\n• Temporary files\n• Database indexes';

  @override
  String get relaySettingsTitle => 'Relays';

  @override
  String get relaySettingsInfoTitle =>
      'Divine is an open system - you control your connections';

  @override
  String get relaySettingsInfoDescription =>
      'These relays distribute your content across the decentralized Nostr network. You can add or remove relays as you wish.';

  @override
  String get relaySettingsLearnMoreNostr => 'Learn more about Nostr →';

  @override
  String get relaySettingsFindPublicRelays =>
      'Find public relays at nostr.co.uk →';

  @override
  String get relaySettingsAppNotFunctional => 'App Not Functional';

  @override
  String get relaySettingsRequiresRelay =>
      'Divine requires at least one relay to load videos, post content, and sync data.';

  @override
  String get relaySettingsRestoreDefaultRelay => 'Restore Default Relay';

  @override
  String get relaySettingsAddCustomRelay => 'Add Custom Relay';

  @override
  String get relaySettingsAddRelay => 'Add Relay';

  @override
  String get relaySettingsRetry => 'Retry';

  @override
  String get relaySettingsNoStats => 'No statistics available yet';

  @override
  String get relaySettingsConnection => 'Connection';

  @override
  String get relaySettingsConnected => 'Connected';

  @override
  String get relaySettingsDisconnected => 'Disconnected';

  @override
  String get relaySettingsSessionDuration => 'Session Duration';

  @override
  String get relaySettingsLastConnected => 'Last Connected';

  @override
  String get relaySettingsDisconnectedLabel => 'Disconnected';

  @override
  String get relaySettingsReason => 'Reason';

  @override
  String get relaySettingsActiveSubscriptions => 'Active Subscriptions';

  @override
  String get relaySettingsTotalSubscriptions => 'Total Subscriptions';

  @override
  String get relaySettingsEventsReceived => 'Events Received';

  @override
  String get relaySettingsEventsSent => 'Events Sent';

  @override
  String get relaySettingsRequestsThisSession => 'Requests This Session';

  @override
  String get relaySettingsFailedRequests => 'Failed Requests';

  @override
  String relaySettingsLastError(String error) {
    return 'Last Error: $error';
  }

  @override
  String get relaySettingsLoadingRelayInfo => 'Loading relay info...';

  @override
  String get relaySettingsAboutRelay => 'About Relay';

  @override
  String get relaySettingsSupportedNips => 'Supported NIPs';

  @override
  String get relaySettingsSoftware => 'Software';

  @override
  String get relaySettingsViewWebsite => 'View Website';

  @override
  String get relaySettingsRemoveRelayTitle => 'Remove Relay?';

  @override
  String relaySettingsRemoveRelayMessage(String relayUrl) {
    return 'Are you sure you want to remove this relay?\n\n$relayUrl';
  }

  @override
  String get relaySettingsCancel => 'Cancel';

  @override
  String get relaySettingsRemove => 'Remove';

  @override
  String relaySettingsRemovedRelay(String relayUrl) {
    return 'Removed relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToRemoveRelay => 'Failed to remove relay';

  @override
  String get relaySettingsForcingReconnection =>
      'Forcing relay reconnection...';

  @override
  String relaySettingsConnectedToRelays(int count) {
    return 'Connected to $count relay(s)!';
  }

  @override
  String get relaySettingsFailedToConnectCheck =>
      'Failed to connect to relays. Please check your network connection.';

  @override
  String get relaySettingsAddRelayTitle => 'Add Relay';

  @override
  String get relaySettingsAddRelayPrompt =>
      'Enter the WebSocket URL of the relay you want to add:';

  @override
  String get relaySettingsBrowsePublicRelays =>
      'Browse public relays at nostr.co.uk';

  @override
  String get relaySettingsAdd => 'Add';

  @override
  String relaySettingsAddedRelay(String relayUrl) {
    return 'Added relay: $relayUrl';
  }

  @override
  String get relaySettingsFailedToAddRelay =>
      'Failed to add relay. Please check the URL and try again.';

  @override
  String get relaySettingsInvalidUrl =>
      'Relay URL must start with wss:// or ws://';

  @override
  String relaySettingsRestoredDefault(String defaultRelay) {
    return 'Restored default relay: $defaultRelay';
  }

  @override
  String get relaySettingsFailedToRestoreDefault =>
      'Failed to restore default relay. Please check your network connection.';

  @override
  String get relaySettingsCouldNotOpenBrowser => 'Could not open browser';

  @override
  String get relaySettingsFailedToOpenLink => 'Failed to open link';

  @override
  String get relayDiagnosticTitle => 'Relay Diagnostics';

  @override
  String get relayDiagnosticRefreshTooltip => 'Refresh diagnostics';

  @override
  String relayDiagnosticLastRefresh(String time) {
    return 'Last refresh: $time';
  }

  @override
  String get relayDiagnosticRelayStatus => 'Relay Status';

  @override
  String get relayDiagnosticInitialized => 'Initialized';

  @override
  String get relayDiagnosticReady => 'Ready';

  @override
  String get relayDiagnosticNotInitialized => 'Not initialized';

  @override
  String get relayDiagnosticDatabaseEvents => 'Database Events';

  @override
  String get relayDiagnosticActiveSubscriptions => 'Active Subscriptions';

  @override
  String get relayDiagnosticExternalRelays => 'External Relays';

  @override
  String get relayDiagnosticConfigured => 'Configured';

  @override
  String relayDiagnosticRelayCount(int count) {
    return '$count relay(s)';
  }

  @override
  String get relayDiagnosticConnectedLabel => 'Connected';

  @override
  String relayDiagnosticConnectedRatio(int connected, int total) {
    return '$connected/$total';
  }

  @override
  String get relayDiagnosticVideoEvents => 'Video Events';

  @override
  String get relayDiagnosticHomeFeed => 'Home Feed';

  @override
  String relayDiagnosticVideosCount(int count) {
    return '$count videos';
  }

  @override
  String get relayDiagnosticDiscovery => 'Discovery';

  @override
  String get relayDiagnosticLoading => 'Loading';

  @override
  String get relayDiagnosticYes => 'Yes';

  @override
  String get relayDiagnosticNo => 'No';

  @override
  String get relayDiagnosticTestDirectQuery => 'Test Direct Query';

  @override
  String get relayDiagnosticNetworkConnectivity => 'Network Connectivity';

  @override
  String get relayDiagnosticRunNetworkTest => 'Run Network Test';

  @override
  String get relayDiagnosticBlossomServer => 'Blossom Server';

  @override
  String get relayDiagnosticTestAllEndpoints => 'Test All Endpoints';

  @override
  String get relayDiagnosticStatus => 'Status';

  @override
  String get relayDiagnosticUrl => 'URL';

  @override
  String get relayDiagnosticError => 'Error';

  @override
  String get relayDiagnosticFunnelCakeApi => 'FunnelCake API';

  @override
  String get relayDiagnosticBaseUrl => 'Base URL';

  @override
  String get relayDiagnosticSummary => 'Summary';

  @override
  String relayDiagnosticEndpointSummary(
    int successCount,
    int totalCount,
    int avgMs,
  ) {
    return '$successCount/$totalCount OK (avg ${avgMs}ms)';
  }

  @override
  String get relayDiagnosticRetestAll => 'Retest All';

  @override
  String get relayDiagnosticRetrying => 'Retrying...';

  @override
  String get relayDiagnosticRetryConnection => 'Retry Connection';

  @override
  String get relayDiagnosticTroubleshooting => 'Troubleshooting';

  @override
  String get relayDiagnosticTroubleshootingGuide =>
      '• Green status = Connected and working\n• Red status = Connection failed\n• If network test fails, check internet connection\n• If relays are configured but not connected, tap \"Retry Connection\"\n• Screenshot this screen for debugging';

  @override
  String get relayDiagnosticAllEndpointsHealthy =>
      'All REST endpoints healthy!';

  @override
  String get relayDiagnosticSomeEndpointsFailed =>
      'Some REST endpoints failed - see details above';

  @override
  String relayDiagnosticFoundVideoEvents(int count) {
    return 'Found $count video events in database';
  }

  @override
  String relayDiagnosticQueryFailed(String error) {
    return 'Query failed: $error';
  }

  @override
  String relayDiagnosticConnectedToRelays(int count) {
    return 'Connected to $count relay(s)!';
  }

  @override
  String get relayDiagnosticFailedToConnect =>
      'Failed to connect to any relays';

  @override
  String relayDiagnosticConnectionRetryFailed(String error) {
    return 'Connection retry failed: $error';
  }

  @override
  String get relayDiagnosticConnectedAuthenticated =>
      'Connected & Authenticated';

  @override
  String get relayDiagnosticConnectedOnly => 'Connected';

  @override
  String get relayDiagnosticNotConnected => 'Not connected';

  @override
  String get relayDiagnosticNoRelaysConfigured => 'No relays configured';

  @override
  String get relayDiagnosticFailed => 'Failed';

  @override
  String get notificationSettingsTitle => 'Notifications';

  @override
  String get notificationSettingsResetTooltip => 'Reset to defaults';

  @override
  String get notificationSettingsTypes => 'Notification Types';

  @override
  String get notificationSettingsLikes => 'Likes';

  @override
  String get notificationSettingsLikesSubtitle =>
      'When someone likes your videos';

  @override
  String get notificationSettingsComments => 'Comments';

  @override
  String get notificationSettingsCommentsSubtitle =>
      'When someone comments on your videos';

  @override
  String get notificationSettingsFollows => 'Follows';

  @override
  String get notificationSettingsFollowsSubtitle => 'When someone follows you';

  @override
  String get notificationSettingsMentions => 'Mentions';

  @override
  String get notificationSettingsMentionsSubtitle => 'When you are mentioned';

  @override
  String get notificationSettingsReposts => 'Reposts';

  @override
  String get notificationSettingsRepostsSubtitle =>
      'When someone reposts your videos';

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
  String get notificationSettingsActions => 'Actions';

  @override
  String get notificationSettingsMarkAllAsRead => 'Mark All as Read';

  @override
  String get notificationSettingsMarkAllAsReadSubtitle =>
      'Mark all notifications as read';

  @override
  String get notificationSettingsAllMarkedAsRead =>
      'All notifications marked as read';

  @override
  String get notificationSettingsResetToDefaults =>
      'Settings reset to defaults';

  @override
  String get notificationSettingsAbout => 'About Notifications';

  @override
  String get notificationSettingsAboutDescription =>
      'Notifications are powered by the Nostr protocol. Real-time updates depend on your connection to Nostr relays. Some notifications may have delays.';

  @override
  String get safetySettingsTitle => 'Safety & Privacy';

  @override
  String get safetySettingsLabel => 'SETTINGS';

  @override
  String get safetySettingsShowDivineHostedOnly =>
      'Only show Divine-hosted videos';

  @override
  String get safetySettingsShowDivineHostedOnlySubtitle =>
      'Hide videos served from other media hosts';

  @override
  String get safetySettingsModeration => 'MODERATION';

  @override
  String get safetySettingsBlockedUsers => 'BLOCKED USERS';

  @override
  String get safetySettingsAgeVerification => 'AGE VERIFICATION';

  @override
  String get safetySettingsAgeConfirmation =>
      'I confirm I am 18 years or older';

  @override
  String get safetySettingsAgeRequired => 'Required to view adult content';

  @override
  String get safetySettingsDivine => 'Divine';

  @override
  String get safetySettingsDivineSubtitle =>
      'Official moderation service (on by default)';

  @override
  String get safetySettingsPeopleIFollow => 'People I follow';

  @override
  String get safetySettingsPeopleIFollowSubtitle =>
      'Subscribe to labels from people you follow';

  @override
  String get safetySettingsAddCustomLabeler => 'Add Custom Labeler';

  @override
  String get safetySettingsAddCustomLabelerHint => 'Enter npub...';

  @override
  String get safetySettingsAddCustomLabelerListTitle => 'Add custom labeler';

  @override
  String get safetySettingsAddCustomLabelerListSubtitle => 'Enter npub address';

  @override
  String get safetySettingsNoBlockedUsers => 'No blocked users';

  @override
  String get safetySettingsUnblock => 'Unblock';

  @override
  String get safetySettingsUserUnblocked => 'User unblocked';

  @override
  String get safetySettingsCancel => 'Cancel';

  @override
  String get safetySettingsAdd => 'Add';

  @override
  String get analyticsTitle => 'Creator Analytics';

  @override
  String get analyticsDiagnosticsTooltip => 'Diagnostics';

  @override
  String get analyticsDiagnosticsSemanticLabel => 'Toggle diagnostics';

  @override
  String get analyticsRetry => 'Retry';

  @override
  String get analyticsUnableToLoad => 'Unable to load analytics.';

  @override
  String get analyticsSignInRequired => 'Sign in to view creator analytics.';

  @override
  String get analyticsViewDataUnavailable =>
      'Views are currently unavailable from the relay for these posts. Like/comment/repost metrics are still accurate.';

  @override
  String get analyticsViewDataTitle => 'View Data';

  @override
  String analyticsUpdatedTimestamp(String time) {
    return 'Updated $time • Scores use likes, comments, reposts, and views/loops from Funnelcake when available.';
  }

  @override
  String get analyticsVideos => 'Videos';

  @override
  String get analyticsViews => 'Views';

  @override
  String get analyticsInteractions => 'Interactions';

  @override
  String get analyticsEngagement => 'Engagement';

  @override
  String get analyticsFollowers => 'Followers';

  @override
  String get analyticsAvgPerPost => 'Avg/Post';

  @override
  String get analyticsInteractionMix => 'Interaction Mix';

  @override
  String get analyticsLikes => 'Likes';

  @override
  String get analyticsComments => 'Comments';

  @override
  String get analyticsReposts => 'Reposts';

  @override
  String get analyticsPerformanceHighlights => 'Performance Highlights';

  @override
  String get analyticsMostViewed => 'Most viewed';

  @override
  String get analyticsMostDiscussed => 'Most discussed';

  @override
  String get analyticsMostReposted => 'Most reposted';

  @override
  String get analyticsNoVideosYet => 'No videos yet';

  @override
  String get analyticsViewDataUnavailableShort => 'View data unavailable';

  @override
  String analyticsViewsCount(String count) {
    return '$count views';
  }

  @override
  String analyticsCommentsCount(String count) {
    return '$count comments';
  }

  @override
  String analyticsRepostsCount(String count) {
    return '$count reposts';
  }

  @override
  String get analyticsTopContent => 'Top Content';

  @override
  String get analyticsPublishPrompt => 'Publish a few videos to see rankings.';

  @override
  String get analyticsEngagementRateExplainer =>
      'Right-side % = Engagement Rate (interactions divided by views).';

  @override
  String get analyticsEngagementRateNoViews =>
      'Engagement Rate needs view data; values show as N/A until views are available.';

  @override
  String get analyticsEngagementLabel => 'Engagement';

  @override
  String get analyticsViewsUnavailable => 'views unavailable';

  @override
  String analyticsInteractionsCount(String count) {
    return '$count interactions';
  }

  @override
  String get analyticsPostAnalytics => 'Post Analytics';

  @override
  String get analyticsOpenPost => 'Open Post';

  @override
  String get analyticsRecentDailyInteractions => 'Recent Daily Interactions';

  @override
  String get analyticsNoActivityYet => 'No activity in this range yet.';

  @override
  String get analyticsDailyInteractionsExplainer =>
      'Interactions = likes + comments + reposts by post date.';

  @override
  String get analyticsDailyBarExplainer =>
      'Bar length is relative to your highest day in this window.';

  @override
  String get analyticsAudienceSnapshot => 'Audience Snapshot';

  @override
  String analyticsFollowersCount(String count) {
    return 'Followers: $count';
  }

  @override
  String analyticsFollowingCount(String count) {
    return 'Following: $count';
  }

  @override
  String get analyticsAudiencePlaceholder =>
      'Audience source/geo/time breakdowns will populate as Funnelcake adds audience analytics endpoints.';

  @override
  String get analyticsRetention => 'Retention';

  @override
  String get analyticsRetentionWithViews =>
      'Retention curve and watch-time breakdown will appear once per-second/per-bucket retention arrives from Funnelcake.';

  @override
  String get analyticsRetentionWithoutViews =>
      'Retention data unavailable until view+watch-time analytics are returned by Funnelcake.';

  @override
  String get analyticsDiagnostics => 'Diagnostics';

  @override
  String analyticsDiagnosticsTotalVideos(int count) {
    return 'Total videos: $count';
  }

  @override
  String analyticsDiagnosticsWithViews(int count) {
    return 'With views: $count';
  }

  @override
  String analyticsDiagnosticsMissingViews(int count) {
    return 'Missing views: $count';
  }

  @override
  String analyticsDiagnosticsHydratedBulk(int count) {
    return 'Hydrated (bulk): $count';
  }

  @override
  String analyticsDiagnosticsHydratedViews(int count) {
    return 'Hydrated (/views): $count';
  }

  @override
  String analyticsDiagnosticsSources(String sources) {
    return 'Sources: $sources';
  }

  @override
  String get analyticsDiagnosticsUseFixture => 'Use fixture data';

  @override
  String get analyticsNa => 'N/A';

  @override
  String get authCreateNewAccount => 'Create a new Divine account';

  @override
  String get authSignInDifferentAccount => 'Sign in with a different account';

  @override
  String get authSignBackIn => 'Sign back in';

  @override
  String get authTermsPrefix =>
      'By selecting an option above, you confirm you are at least 16 years old and agree to the ';

  @override
  String get authTermsOfService => 'Terms of Service';

  @override
  String get authPrivacyPolicy => 'Privacy Policy';

  @override
  String get authTermsAnd => ', and ';

  @override
  String get authSafetyStandards => 'Safety Standards';

  @override
  String get authAmberNotInstalled => 'Amber app is not installed';

  @override
  String get authAmberConnectionFailed => 'Failed to connect with Amber';

  @override
  String get authPasswordResetSent =>
      'If an account exists with that email, a password reset link has been sent.';

  @override
  String get authSignInTitle => 'Sign in';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authImportNostrKey => 'Import Nostr key';

  @override
  String get authConnectSignerApp => 'Connect with a signer app';

  @override
  String get authSignInWithAmber => 'Sign in with Amber';

  @override
  String get authSignInOptionsTitle => 'Sign-in options';

  @override
  String get authInfoEmailPasswordTitle => 'Email & Password';

  @override
  String get authInfoEmailPasswordDescription =>
      'Sign in with your Divine account. If you registered with an email and password, use them here.';

  @override
  String get authInfoImportNostrKeyDescription =>
      'Already have a Nostr identity? Import your nsec private key from another client.';

  @override
  String get authInfoSignerAppTitle => 'Signer App';

  @override
  String get authInfoSignerAppDescription =>
      'Connect using a NIP-46 compatible remote signer like nsecBunker for enhanced key security.';

  @override
  String get authInfoAmberTitle => 'Amber';

  @override
  String get authInfoAmberDescription =>
      'Use the Amber signer app on Android to manage your Nostr keys securely.';

  @override
  String get authCreateAccountTitle => 'Create account';

  @override
  String get authBackToInviteCode => 'Back to invite code';

  @override
  String get authUseDivineNoBackup => 'Use Divine with no backup';

  @override
  String get authSkipConfirmTitle => 'One last thing...';

  @override
  String get authSkipConfirmKeyCreated =>
      'You\'re in! We\'ll create a secure key that powers your Divine account.';

  @override
  String get authSkipConfirmKeyOnly =>
      'Without an email, your key is the only way Divine knows this account is yours.';

  @override
  String get authSkipConfirmRecommendEmail =>
      'You can access your key in the app, but, if you\'re not technical we recommend adding an email and password now. It makes it easier to sign in and restore your account if you lose or reset this device.';

  @override
  String get authAddEmailPassword => 'Add email & password';

  @override
  String get authUseThisDeviceOnly => 'Use this device only';

  @override
  String get authCompleteRegistration => 'Complete your registration';

  @override
  String get authVerifying => 'Verifying...';

  @override
  String get authVerificationLinkSent => 'We sent a verification link to:';

  @override
  String get authClickVerificationLink =>
      'Please click the link in your email to\ncomplete your registration.';

  @override
  String get authPleaseWaitVerifying =>
      'Please wait while we verify your email...';

  @override
  String get authWaitingForVerification => 'Waiting for verification';

  @override
  String get authOpenEmailApp => 'Open email app';

  @override
  String get authWelcomeToDivine => 'Welcome to Divine!';

  @override
  String get authEmailVerified => 'Your email has been verified.';

  @override
  String get authSigningYouIn => 'Signing you in';

  @override
  String get authErrorTitle => 'Uh oh.';

  @override
  String get authVerificationFailed =>
      'We failed to verify your email.\nPlease try again.';

  @override
  String get authStartOver => 'Start over';

  @override
  String get authEmailVerifiedLogin =>
      'Email verified! Please log in to continue.';

  @override
  String get authVerificationLinkExpired =>
      'This verification link is no longer valid.';

  @override
  String get authVerificationConnectionError =>
      'Unable to verify email. Please check your connection and try again.';

  @override
  String get authWaitlistConfirmTitle => 'You\'re in!';

  @override
  String authWaitlistUpdatesAt(String email) {
    return 'We\'ll share updates at $email.\nWhen more invite codes are available, we\'ll send them your way.';
  }

  @override
  String get authOk => 'OK';

  @override
  String get authInviteUnavailable =>
      'Invite access is temporarily unavailable.';

  @override
  String get authInviteUnavailableBody =>
      'Try again in a moment, or contact support if you need help getting in.';

  @override
  String get authTryAgain => 'Try again';

  @override
  String get authContactSupport => 'Contact support';

  @override
  String authCouldNotOpenEmail(String email) {
    return 'Could not open $email';
  }

  @override
  String get authAddInviteCode => 'Add your invite code';

  @override
  String get authInviteCodeLabel => 'Invite code';

  @override
  String get authEnterYourCode => 'Enter your code';

  @override
  String get authNext => 'Next';

  @override
  String get authJoinWaitlist => 'Join waitlist';

  @override
  String get authJoinWaitlistTitle => 'Join the waitlist';

  @override
  String get authJoinWaitlistDescription =>
      'Share your email and we\'ll send updates as access opens up.';

  @override
  String get authInviteAccessHelp => 'Invite access help';

  @override
  String get authGeneratingConnection => 'Generating connection...';

  @override
  String get authConnectedAuthenticating => 'Connected! Authenticating...';

  @override
  String get authConnectionTimedOut => 'Connection timed out';

  @override
  String get authApproveConnection =>
      'Make sure you approved the connection in your signer app.';

  @override
  String get authConnectionCancelled => 'Connection cancelled';

  @override
  String get authConnectionCancelledMessage => 'The connection was cancelled.';

  @override
  String get authConnectionFailed => 'Connection failed';

  @override
  String get authUnknownError => 'An unknown error occurred.';

  @override
  String get authUrlCopied => 'URL copied to clipboard';

  @override
  String get authConnectToDivine => 'Connect to Divine';

  @override
  String get authPasteBunkerUrl => 'Paste bunker:// URL';

  @override
  String get authBunkerUrlHint => 'bunker:// URL';

  @override
  String get authInvalidBunkerUrl =>
      'Invalid bunker URL. It should start with bunker://';

  @override
  String get authScanSignerApp => 'Scan with your\nsigner app to connect.';

  @override
  String authWaitingForConnection(int seconds) {
    return 'Waiting for connection... ${seconds}s';
  }

  @override
  String get authCopyUrl => 'Copy URL';

  @override
  String get authShare => 'Share';

  @override
  String get authAddBunker => 'Add bunker';

  @override
  String get authCompatibleSignerApps => 'Compatible Signer apps';

  @override
  String get authFailedToConnect => 'Failed to connect';

  @override
  String get authResetPasswordTitle => 'Reset Password';

  @override
  String get authResetPasswordSubtitle =>
      'Please enter your new password. It must be at least 8 characters in length.';

  @override
  String get authNewPasswordLabel => 'New Password';

  @override
  String get authPasswordTooShort => 'Password must be at least 8 characters';

  @override
  String get authPasswordResetSuccess =>
      'Password reset successful. Please log in.';

  @override
  String get authPasswordResetFailed => 'Password reset failed';

  @override
  String get authUnexpectedError =>
      'An unexpected error occurred. Please try again.';

  @override
  String get authUpdatePassword => 'Update password';

  @override
  String get authSecureAccountTitle => 'Secure account';

  @override
  String get authUnableToAccessKeys =>
      'Unable to access your keys. Please try again.';

  @override
  String get authRegistrationFailed => 'Registration failed';

  @override
  String get authRegistrationComplete =>
      'Registration complete. Please check your email.';

  @override
  String get authVerificationFailedTitle => 'Verification Failed';

  @override
  String get authClose => 'Close';

  @override
  String get authAccountSecured => 'Account Secured!';

  @override
  String get authAccountLinkedToEmail =>
      'Your account is now linked to your email.';

  @override
  String get authVerifyYourEmail => 'Verify Your Email';

  @override
  String get authClickLinkContinue =>
      'Click the link in your email to complete registration. You can continue using the app in the meantime.';

  @override
  String get authWaitingForVerificationEllipsis =>
      'Waiting for verification...';

  @override
  String get authContinueToApp => 'Continue to App';

  @override
  String get authResetPassword => 'Reset password';

  @override
  String get authResetPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get authFailedToSendResetEmail => 'Failed to send reset email.';

  @override
  String get authUnexpectedErrorShort => 'An unexpected error occurred.';

  @override
  String get authSending => 'Sending...';

  @override
  String get authSendResetLink => 'Send reset link';

  @override
  String get authEmailSent => 'Email sent!';

  @override
  String authResetLinkSentTo(String email) {
    return 'We sent a password reset link to $email. Please click the link in your email to update your password.';
  }

  @override
  String get authSignInButton => 'Sign in';

  @override
  String get authVerificationErrorTimeout =>
      'Verification timed out. Please try registering again.';

  @override
  String get authVerificationErrorMissingCode =>
      'Verification failed — missing authorization code.';

  @override
  String get authVerificationErrorPollFailed =>
      'Verification failed. Please try again.';

  @override
  String get authVerificationErrorNetworkExchange =>
      'Network error during sign-in. Please try again.';

  @override
  String get authVerificationErrorOAuthExchange =>
      'Verification failed. Please try registering again.';

  @override
  String get authVerificationErrorSignInFailed =>
      'Sign-in failed. Please try logging in manually.';

  @override
  String get authInviteErrorAlreadyUsed =>
      'That invite code is no longer available. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get authInviteErrorInvalid =>
      'That invite code cannot be used right now. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get authInviteErrorTemporary =>
      'We couldn\'t confirm your invite right now. Go back to your invite code and try again, or contact support.';

  @override
  String get authInviteErrorUnknown =>
      'We couldn\'t activate your invite. Go back to your invite code, join the waitlist, or contact support.';

  @override
  String get shareSheetSave => 'Save';

  @override
  String get shareSheetSaveToGallery => 'Save to Gallery';

  @override
  String get shareSheetSaveWithWatermark => 'Save with Watermark';

  @override
  String get shareSheetSaveVideo => 'Save Video';

  @override
  String get shareSheetAddToList => 'Add to List';

  @override
  String get shareSheetCopy => 'Copy';

  @override
  String get shareSheetShareVia => 'Share via';

  @override
  String get shareSheetReport => 'Report';

  @override
  String get shareSheetEventJson => 'Event JSON';

  @override
  String get shareSheetEventId => 'Event ID';

  @override
  String get shareSheetMoreActions => 'More actions';

  @override
  String get watermarkDownloadSavedToCameraRoll => 'Saved to Camera Roll';

  @override
  String get watermarkDownloadShare => 'Share';

  @override
  String get watermarkDownloadDone => 'Done';

  @override
  String get watermarkDownloadPhotosAccessNeeded => 'Photos Access Needed';

  @override
  String get watermarkDownloadPhotosAccessDescription =>
      'To save videos, allow Photos access in Settings.';

  @override
  String get watermarkDownloadOpenSettings => 'Open Settings';

  @override
  String get watermarkDownloadNotNow => 'Not Now';

  @override
  String get watermarkDownloadFailed => 'Download Failed';

  @override
  String get watermarkDownloadDismiss => 'Dismiss';

  @override
  String get watermarkDownloadStageDownloading => 'Downloading Video';

  @override
  String get watermarkDownloadStageWatermarking => 'Adding Watermark';

  @override
  String get watermarkDownloadStageSaving => 'Saving to Camera Roll';

  @override
  String get watermarkDownloadStageDownloadingDesc =>
      'Fetching the video from the network...';

  @override
  String get watermarkDownloadStageWatermarkingDesc =>
      'Applying the Divine watermark...';

  @override
  String get watermarkDownloadStageSavingDesc =>
      'Saving the watermarked video to your camera roll...';

  @override
  String get uploadProgressVideoUpload => 'Video Upload';

  @override
  String get uploadProgressPause => 'Pause';

  @override
  String get uploadProgressResume => 'Resume';

  @override
  String get uploadProgressGoBack => 'Go Back';

  @override
  String uploadProgressRetryWithCount(int count) {
    return 'Retry ($count left)';
  }

  @override
  String get uploadProgressDelete => 'Delete';

  @override
  String uploadProgressDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String uploadProgressHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String uploadProgressMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String get uploadProgressJustNow => 'Just now';

  @override
  String uploadProgressUploadingPercent(int percent) {
    return 'Uploading $percent%';
  }

  @override
  String uploadProgressPausedPercent(int percent) {
    return 'Paused $percent%';
  }

  @override
  String get badgeExplanationClose => 'Close';

  @override
  String get badgeExplanationOriginalVineArchive => 'Original Vine Archive';

  @override
  String get badgeExplanationCameraProof => 'Camera Proof';

  @override
  String get badgeExplanationAuthenticitySignals => 'Authenticity Signals';

  @override
  String get badgeExplanationVineArchiveIntro =>
      'This video is an original Vine recovered from the Internet Archive.';

  @override
  String get badgeExplanationVineArchiveHistory =>
      'Before Vine shut down in 2017, ArchiveTeam and the Internet Archive worked to preserve millions of Vines for posterity. This content is part of that historic preservation effort.';

  @override
  String badgeExplanationOriginalStats(int loops) {
    return 'Original stats: $loops loops';
  }

  @override
  String get badgeExplanationLearnVineArchive =>
      'Learn more about the Vine archive preservation';

  @override
  String get badgeExplanationLearnProofmode =>
      'Learn more about Proofmode verification';

  @override
  String get badgeExplanationLearnAuthenticity =>
      'Learn more about Divine authenticity signals';

  @override
  String get badgeExplanationInspectProofCheck =>
      'Inspect with ProofCheck Tool';

  @override
  String get badgeExplanationInspectMedia => 'Inspect media details';

  @override
  String get badgeExplanationProofmodeVerified =>
      'This video\'s authenticity is verified using Proofmode technology.';

  @override
  String get badgeExplanationDivineHostedHumanMade =>
      'This video is hosted on Divine and AI detection indicates it is likely human-made, but it does not include cryptographic camera-verification data.';

  @override
  String get badgeExplanationHumanMadeNoCrypto =>
      'AI detection indicates this video is likely human-made, though it does not include cryptographic camera-verification data.';

  @override
  String get badgeExplanationDivineHostedNoCrypto =>
      'This video is hosted on Divine, but it does not include cryptographic camera-verification data yet.';

  @override
  String get badgeExplanationExternalNoCrypto =>
      'This video is hosted outside Divine and does not include cryptographic camera-verification data.';

  @override
  String get badgeExplanationDeviceAttestation => 'Device attestation';

  @override
  String get badgeExplanationPgpSignature => 'PGP signature';

  @override
  String get badgeExplanationC2paCredentials => 'C2PA Content Credentials';

  @override
  String get badgeExplanationProofManifest => 'Proof manifest';

  @override
  String get badgeExplanationAiDetection => 'AI Detection';

  @override
  String get badgeExplanationAiNotScanned => 'AI scan: Not yet scanned';

  @override
  String get badgeExplanationNoScanResults => 'No scan results available yet.';

  @override
  String get badgeExplanationCheckAiGenerated => 'Check if AI-generated';

  @override
  String badgeExplanationAiLikelihood(int percentage) {
    return '$percentage% likelihood of being AI-generated';
  }

  @override
  String badgeExplanationScannedBy(String source) {
    return 'Scanned by: $source';
  }

  @override
  String get badgeExplanationVerifiedByModerator =>
      'Verified by human moderator';

  @override
  String get badgeExplanationVerificationPlatinum =>
      'Platinum: Device hardware attestation, cryptographic signatures, Content Credentials (C2PA), and AI scan confirms human origin.';

  @override
  String get badgeExplanationVerificationGold =>
      'Gold: Captured on a real device with hardware attestation, cryptographic signatures, and Content Credentials (C2PA).';

  @override
  String get badgeExplanationVerificationSilver =>
      'Silver: Cryptographic signatures prove this video hasn\'t been altered since recording.';

  @override
  String get badgeExplanationVerificationBronze =>
      'Bronze: Basic metadata signatures are present.';

  @override
  String get badgeExplanationVerificationSilverAiScan =>
      'Silver: AI scan confirms this video is likely human-created.';

  @override
  String get badgeExplanationNoVerification =>
      'No verification data available for this video.';

  @override
  String get shareMenuTitle => 'Share Video';

  @override
  String get shareMenuReportAiContent => 'Report AI Content';

  @override
  String get shareMenuReportAiContentSubtitle =>
      'Quick report suspected AI-generated content';

  @override
  String get shareMenuReportingAiContent => 'Reporting AI content...';

  @override
  String shareMenuFailedToReportContent(String error) {
    return 'Failed to report content: $error';
  }

  @override
  String shareMenuFailedToReportAiContent(String error) {
    return 'Failed to report AI content: $error';
  }

  @override
  String get shareMenuVideoStatus => 'Video Status';

  @override
  String get shareMenuViewAllLists => 'View all lists →';

  @override
  String get shareMenuShareWith => 'Share With';

  @override
  String get shareMenuShareViaOtherApps => 'Share via other apps';

  @override
  String get shareMenuShareViaOtherAppsSubtitle =>
      'Share via other apps or copy link';

  @override
  String get shareMenuSaveToGallery => 'Save to Gallery';

  @override
  String get shareMenuSaveOriginalSubtitle =>
      'Save original video to camera roll';

  @override
  String get shareMenuSaveWithWatermark => 'Save with Watermark';

  @override
  String get shareMenuSaveVideo => 'Save Video';

  @override
  String get shareMenuDownloadWithWatermark => 'Download with Divine watermark';

  @override
  String get shareMenuSaveVideoSubtitle => 'Save video to camera roll';

  @override
  String get shareMenuLists => 'Lists';

  @override
  String get shareMenuAddToList => 'Add to List';

  @override
  String get shareMenuAddToListSubtitle => 'Add to your curated lists';

  @override
  String get shareMenuCreateNewList => 'Create New List';

  @override
  String get shareMenuCreateNewListSubtitle => 'Start a new curated collection';

  @override
  String get shareMenuRemovedFromList => 'Removed from list';

  @override
  String get shareMenuFailedToRemoveFromList => 'Failed to remove from list';

  @override
  String get shareMenuBookmarks => 'Bookmarks';

  @override
  String get shareMenuAddToBookmarks => 'Add to Bookmarks';

  @override
  String get shareMenuAddToBookmarksSubtitle => 'Save for later viewing';

  @override
  String get shareMenuAddToBookmarkSet => 'Add to Bookmark Set';

  @override
  String get shareMenuAddToBookmarkSetSubtitle => 'Organize in collections';

  @override
  String get shareMenuFollowSets => 'Follow Sets';

  @override
  String get shareMenuCreateFollowSet => 'Create Follow Set';

  @override
  String get shareMenuCreateFollowSetSubtitle =>
      'Start new collection with this creator';

  @override
  String get shareMenuAddToFollowSet => 'Add to Follow Set';

  @override
  String shareMenuFollowSetsAvailable(int count) {
    return '$count follow sets available';
  }

  @override
  String get shareMenuAddedToBookmarks => 'Added to bookmarks!';

  @override
  String get shareMenuFailedToAddBookmark => 'Failed to add bookmark';

  @override
  String shareMenuCreatedListAndAddedVideo(String name) {
    return 'Created list \"$name\" and added video';
  }

  @override
  String get shareMenuManageContent => 'Manage Content';

  @override
  String get shareMenuEditVideo => 'Edit Video';

  @override
  String get shareMenuEditVideoSubtitle =>
      'Update title, description, and hashtags';

  @override
  String get shareMenuDeleteVideo => 'Delete Video';

  @override
  String get shareMenuDeleteVideoSubtitle =>
      'Remove this video from Divine. It may still appear on other Nostr clients.';

  @override
  String get shareMenuDeleteWarning =>
      'This sends a delete request (NIP-09) to all relays. Some relays may still keep the content.';

  @override
  String get shareMenuVideoInTheseLists => 'Video is in these lists:';

  @override
  String shareMenuVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get shareMenuClose => 'Close';

  @override
  String get shareMenuDeleteConfirmation =>
      'This will permanently delete this video from Divine. It may still appear on third-party Nostr clients that use other relays.';

  @override
  String get shareMenuCancel => 'Cancel';

  @override
  String get shareMenuDelete => 'Delete';

  @override
  String get shareMenuDeletingContent => 'Deleting content...';

  @override
  String shareMenuFailedToDeleteContent(String error) {
    return 'Failed to delete content: $error';
  }

  @override
  String get shareMenuDeleteRequestSent => 'Video deleted';

  @override
  String get shareMenuDeleteFailedNotInitialized =>
      'Deletion isn\'t ready yet. Try again in a moment.';

  @override
  String get shareMenuDeleteFailedNotOwner =>
      'You can only delete your own videos.';

  @override
  String get shareMenuDeleteFailedNotAuthenticated =>
      'Sign in again, then try deleting.';

  @override
  String get shareMenuDeleteFailedCouldNotSign =>
      'Couldn\'t sign the delete request. Try again.';

  @override
  String get shareMenuDeleteFailedRelayRejected =>
      'Couldn\'t reach the relay. Check your connection and try again.';

  @override
  String get shareMenuDeleteFailedGeneric =>
      'Couldn\'t delete this video. Try again.';

  @override
  String get shareMenuFollowSetName => 'Follow Set Name';

  @override
  String get shareMenuFollowSetNameHint =>
      'e.g., Content Creators, Musicians, etc.';

  @override
  String get shareMenuDescriptionOptional => 'Description (optional)';

  @override
  String get shareMenuCreate => 'Create';

  @override
  String shareMenuCreatedFollowSetAndAddedCreator(String name) {
    return 'Created follow set \"$name\" and added creator';
  }

  @override
  String get shareMenuDone => 'Done';

  @override
  String get shareMenuEditTitle => 'Title';

  @override
  String get shareMenuEditTitleHint => 'Enter video title';

  @override
  String get shareMenuEditDescription => 'Description';

  @override
  String get shareMenuEditDescriptionHint => 'Enter video description';

  @override
  String get shareMenuEditHashtags => 'Hashtags';

  @override
  String get shareMenuEditHashtagsHint => 'comma, separated, hashtags';

  @override
  String get shareMenuEditMetadataNote =>
      'Note: Only metadata can be edited. Video content cannot be changed.';

  @override
  String get shareMenuDeleting => 'Deleting...';

  @override
  String get shareMenuUpdate => 'Update';

  @override
  String get shareMenuVideoUpdated => 'Video updated successfully';

  @override
  String shareMenuFailedToUpdateVideo(String error) {
    return 'Failed to update video: $error';
  }

  @override
  String shareMenuFailedToDeleteVideo(String error) {
    return 'Failed to delete video: $error';
  }

  @override
  String get shareMenuDeleteVideoQuestion => 'Delete Video?';

  @override
  String get shareMenuDeleteRelayWarning =>
      'This will send a deletion request to relays. Note: Some relays may still have cached copies.';

  @override
  String get shareMenuVideoDeletionRequested => 'Video deleted';

  @override
  String get shareMenuContentLabels => 'Content labels';

  @override
  String get shareMenuAddContentLabels => 'Add content labels';

  @override
  String get shareMenuClearAll => 'Clear all';

  @override
  String get shareMenuCollaborators => 'Collaborators';

  @override
  String get shareMenuAddCollaborator => 'Invite collaborator';

  @override
  String shareMenuMutualFollowRequired(String name) {
    return 'You need to mutually follow $name to invite them as a collaborator.';
  }

  @override
  String get shareMenuLoading => 'Loading...';

  @override
  String get shareMenuInspiredBy => 'Inspired by';

  @override
  String get shareMenuAddInspirationCredit => 'Add inspiration credit';

  @override
  String get shareMenuCreatorCannotBeReferenced =>
      'This creator cannot be referenced.';

  @override
  String get shareMenuUnknown => 'Unknown';

  @override
  String get shareMenuCreateBookmarkSet => 'Create Bookmark Set';

  @override
  String get shareMenuSetName => 'Set Name';

  @override
  String get shareMenuSetNameHint => 'e.g., Favorites, Watch Later, etc.';

  @override
  String get shareMenuCreateNewSet => 'Create New Set';

  @override
  String get shareMenuStartNewBookmarkCollection =>
      'Start a new bookmark collection';

  @override
  String get shareMenuNoBookmarkSets =>
      'No bookmark sets yet. Create your first one!';

  @override
  String get shareMenuError => 'Error';

  @override
  String get shareMenuFailedToLoadBookmarkSets =>
      'Failed to load bookmark sets';

  @override
  String shareMenuCreatedSetAndAddedVideo(String name) {
    return 'Created \"$name\" and added video';
  }

  @override
  String get shareMenuUseThisSound => 'Use this sound';

  @override
  String get shareMenuOriginalSound => 'Original sound';

  @override
  String get authSessionExpired =>
      'Your session has expired. Please sign in again.';

  @override
  String get authSignInFailed => 'Failed to sign in. Please try again.';

  @override
  String get localeAppLanguage => 'App Language';

  @override
  String get localeDeviceDefault => 'Device default';

  @override
  String get localeSelectLanguage => 'Select Language';

  @override
  String get webAuthNotSupportedSecureMode =>
      'Web authentication not supported in secure mode. Please use mobile app for secure key management.';

  @override
  String webAuthIntegrationFailed(String error) {
    return 'Authentication integration failed: $error';
  }

  @override
  String webAuthUnexpectedError(String error) {
    return 'Unexpected error: $error';
  }

  @override
  String get webAuthEnterBunkerUri => 'Please enter a bunker URI';

  @override
  String get webAuthConnectTitle => 'Connect to Divine';

  @override
  String get webAuthChooseMethod =>
      'Choose your preferred Nostr authentication method';

  @override
  String get webAuthBrowserExtension => 'Browser Extension';

  @override
  String get webAuthRecommended => 'RECOMMENDED';

  @override
  String get webAuthNsecBunker => 'nsec bunker';

  @override
  String get webAuthConnectRemoteSigner => 'Connect to a remote signer';

  @override
  String get webAuthBunkerHint => 'bunker://pubkey?relay=wss://...';

  @override
  String get webAuthPasteFromClipboard => 'Paste from clipboard';

  @override
  String get webAuthConnectToBunker => 'Connect to Bunker';

  @override
  String get webAuthNewToNostr => 'New to Nostr?';

  @override
  String get webAuthNostrHelp =>
      'Install a browser extension like Alby or nos2x for the easiest experience, or use nsec bunker for secure remote signing.';

  @override
  String get soundsTitle => 'Sounds';

  @override
  String get soundsSearchHint => 'Search sounds...';

  @override
  String get soundsPreviewUnavailable =>
      'Unable to preview sound - no audio available';

  @override
  String soundsPreviewFailed(String error) {
    return 'Failed to play preview: $error';
  }

  @override
  String get soundsFeaturedSounds => 'Featured Sounds';

  @override
  String get soundsTrendingSounds => 'Trending Sounds';

  @override
  String get soundsAllSounds => 'All Sounds';

  @override
  String get soundsSearchResults => 'Search Results';

  @override
  String get soundsNoSoundsAvailable => 'No sounds available';

  @override
  String get soundsNoSoundsDescription =>
      'Sounds will appear here when creators share audio';

  @override
  String get soundsNoSoundsFound => 'No sounds found';

  @override
  String get soundsNoSoundsFoundDescription => 'Try a different search term';

  @override
  String get soundsFailedToLoad => 'Failed to load sounds';

  @override
  String get soundsRetry => 'Retry';

  @override
  String get soundsScreenLabel => 'Sounds screen';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileRefresh => 'Refresh';

  @override
  String get profileRefreshLabel => 'Refresh profile';

  @override
  String get profileMoreOptions => 'More options';

  @override
  String profileBlockedUser(String name) {
    return 'Blocked $name';
  }

  @override
  String profileUnblockedUser(String name) {
    return 'Unblocked $name';
  }

  @override
  String profileUnfollowedUser(String name) {
    return 'Unfollowed $name';
  }

  @override
  String profileError(String error) {
    return 'Error: $error';
  }

  @override
  String get notificationsTabAll => 'All';

  @override
  String get notificationsTabLikes => 'Likes';

  @override
  String get notificationsTabComments => 'Comments';

  @override
  String get notificationsTabFollows => 'Follows';

  @override
  String get notificationsTabReposts => 'Reposts';

  @override
  String get notificationsFailedToLoad => 'Failed to load notifications';

  @override
  String get notificationsRetry => 'Retry';

  @override
  String get notificationsCheckingNew => 'checking for new notifications';

  @override
  String get notificationsNoneYet => 'No notifications yet';

  @override
  String notificationsNoneForType(String type) {
    return 'No $type notifications';
  }

  @override
  String get notificationsEmptyDescription =>
      'When people interact with your content, you\'ll see it here';

  @override
  String notificationsLoadingType(String type) {
    return 'Loading $type notifications...';
  }

  @override
  String get notificationsInviteSingular =>
      'You have 1 invite to share with a friend!';

  @override
  String notificationsInvitePlural(int count) {
    return 'You have $count invites to share with friends!';
  }

  @override
  String get notificationsVideoNotFound => 'Video not found';

  @override
  String get notificationsVideoUnavailable => 'Video unavailable';

  @override
  String get notificationsFromNotification => 'From Notification';

  @override
  String get feedFailedToLoadVideos => 'Failed to load videos';

  @override
  String get feedRetry => 'Retry';

  @override
  String get feedNoFollowedUsers =>
      'No followed users.\nFollow someone to see their videos here.';

  @override
  String get feedForYouEmpty =>
      'Your For You feed is empty.\nExplore videos and follow creators to shape it.';

  @override
  String get feedFollowingEmpty =>
      'No videos from people you follow yet.\nFind creators you like and follow them.';

  @override
  String get feedLatestEmpty => 'No new videos yet.\nCheck back soon.';

  @override
  String get feedExploreVideos => 'Explore Videos';

  @override
  String get feedExternalVideoSlow => 'External video loading slowly';

  @override
  String get feedSkip => 'Skip';

  @override
  String get uploadWaitingToUpload => 'Waiting to upload';

  @override
  String get uploadUploadingVideo => 'Uploading video';

  @override
  String get uploadProcessingVideo => 'Processing video';

  @override
  String get uploadProcessingComplete => 'Processing complete';

  @override
  String get uploadPublishedSuccessfully => 'Published successfully';

  @override
  String get uploadFailed => 'Upload failed';

  @override
  String get uploadRetrying => 'Retrying upload';

  @override
  String get uploadPaused => 'Upload paused';

  @override
  String uploadPercentComplete(int percent) {
    return '$percent% complete';
  }

  @override
  String get uploadQueuedMessage => 'Your video is queued for upload';

  @override
  String get uploadUploadingMessage => 'Uploading to server...';

  @override
  String get uploadProcessingMessage =>
      'Processing video - this may take a few minutes';

  @override
  String get uploadReadyToPublishMessage =>
      'Video processed successfully and ready to publish';

  @override
  String get uploadPublishedMessage => 'Video published to your profile';

  @override
  String get uploadFailedMessage => 'Upload failed - please try again';

  @override
  String get uploadRetryingMessage => 'Retrying upload...';

  @override
  String get uploadPausedMessage => 'Upload paused by user';

  @override
  String get uploadRetryButton => 'RETRY';

  @override
  String uploadRetryFailed(String error) {
    return 'Failed to retry upload: $error';
  }

  @override
  String get userSearchPrompt => 'Search for users';

  @override
  String get userSearchNoResults => 'No users found';

  @override
  String get userSearchFailed => 'Search failed';

  @override
  String get userPickerSearchByName => 'Search by name';

  @override
  String get userPickerFilterByNameHint => 'Filter by name...';

  @override
  String get userPickerSearchByNameHint => 'Search by name...';

  @override
  String userPickerAlreadyAddedSemantics(String name) {
    return '$name already added';
  }

  @override
  String userPickerSelectSemantics(String name) {
    return 'Select $name';
  }

  @override
  String get userPickerEmptyFollowListTitle => 'Your crew is out there';

  @override
  String get userPickerEmptyFollowListBody =>
      'Follow people you vibe with. When they follow back, you can collab.';

  @override
  String get userPickerGoBack => 'Go back';

  @override
  String get userPickerTypeNameToSearch => 'Type a name to search';

  @override
  String get userPickerUnavailable =>
      'User search is unavailable. Please try again later.';

  @override
  String get userPickerSearchFailedTryAgain =>
      'Search failed. Please try again.';

  @override
  String get forgotPasswordTitle => 'Reset Password';

  @override
  String get forgotPasswordDescription =>
      'Enter your email address and we\'ll send you a link to reset your password.';

  @override
  String get forgotPasswordEmailLabel => 'Email Address';

  @override
  String get forgotPasswordCancel => 'Cancel';

  @override
  String get forgotPasswordSendLink => 'Email Reset Link';

  @override
  String get ageVerificationContentWarning => 'Content Warning';

  @override
  String get ageVerificationTitle => 'Age Verification';

  @override
  String get ageVerificationAdultDescription =>
      'This content has been flagged as potentially containing adult material. You must be 18 or older to view it.';

  @override
  String get ageVerificationCreationDescription =>
      'To use the camera and create content, you must be at least 16 years old.';

  @override
  String get ageVerificationAdultQuestion =>
      'Are you 18 years of age or older?';

  @override
  String get ageVerificationCreationQuestion =>
      'Are you 16 years of age or older?';

  @override
  String get ageVerificationNo => 'No';

  @override
  String get ageVerificationYes => 'Yes';

  @override
  String get shareLinkCopied => 'Link copied to clipboard';

  @override
  String get shareFailedToCopy => 'Failed to copy link';

  @override
  String get shareVideoSubject => 'Check out this video on Divine';

  @override
  String get shareFailedToShare => 'Failed to share';

  @override
  String get shareVideoTitle => 'Share Video';

  @override
  String get shareToApps => 'Share to Apps';

  @override
  String get shareToAppsSubtitle => 'Share via messaging, social apps';

  @override
  String get shareCopyWebLink => 'Copy Web Link';

  @override
  String get shareCopyWebLinkSubtitle => 'Copy shareable web link';

  @override
  String get shareCopyNostrLink => 'Copy Nostr Link';

  @override
  String get shareCopyNostrLinkSubtitle => 'Copy nevent link for Nostr clients';

  @override
  String get navHome => 'Home';

  @override
  String get navExplore => 'Explore';

  @override
  String get navInbox => 'Inbox';

  @override
  String get navProfile => 'Profile';

  @override
  String get navSearch => 'Search';

  @override
  String get navSearchTooltip => 'Search';

  @override
  String get navMyProfile => 'My Profile';

  @override
  String get navNotifications => 'Notifications';

  @override
  String get navOpenCamera => 'Open camera';

  @override
  String get navUnknown => 'Unknown';

  @override
  String get navExploreClassics => 'Classics';

  @override
  String get navExploreNewVideos => 'New Videos';

  @override
  String get navExploreTrending => 'Trending';

  @override
  String get navExploreForYou => 'For You';

  @override
  String get navExploreLists => 'Lists';

  @override
  String get routeErrorTitle => 'Error';

  @override
  String get routeInvalidHashtag => 'Invalid hashtag';

  @override
  String get routeInvalidConversationId => 'Invalid conversation ID';

  @override
  String get routeInvalidRequestId => 'Invalid request ID';

  @override
  String get routeInvalidListId => 'Invalid list ID';

  @override
  String get routeInvalidUserId => 'Invalid user ID';

  @override
  String get routeInvalidVideoId => 'Invalid video ID';

  @override
  String get routeInvalidSoundId => 'Invalid sound ID';

  @override
  String get routeInvalidCategory => 'Invalid category';

  @override
  String get routeNoVideosToDisplay => 'No videos to display';

  @override
  String get routeInvalidProfileId => 'Invalid profile ID';

  @override
  String get routeDefaultListName => 'List';

  @override
  String get supportTitle => 'Support Center';

  @override
  String get supportContactSupport => 'Contact Support';

  @override
  String get supportContactSupportSubtitle =>
      'Start a conversation or view past messages';

  @override
  String get supportReportBug => 'Report a Bug';

  @override
  String get supportReportBugSubtitle => 'Technical issues with the app';

  @override
  String get supportRequestFeature => 'Request a Feature';

  @override
  String get supportRequestFeatureSubtitle =>
      'Suggest an improvement or new feature';

  @override
  String get supportSaveLogs => 'Save Logs';

  @override
  String get supportSaveLogsSubtitle =>
      'Export logs to file for manual sending';

  @override
  String get supportFaq => 'FAQ';

  @override
  String get supportFaqSubtitle => 'Common questions & answers';

  @override
  String get supportProofMode => 'ProofMode';

  @override
  String get supportProofModeSubtitle =>
      'Learn about verification and authenticity';

  @override
  String get supportLoginRequired => 'Log in to contact support';

  @override
  String get supportExportingLogs => 'Exporting logs...';

  @override
  String get supportExportLogsFailed => 'Failed to export logs';

  @override
  String get supportChatNotAvailable => 'Support chat not available';

  @override
  String get supportCouldNotOpenMessages => 'Could not open support messages';

  @override
  String supportCouldNotOpenPage(String pageName) {
    return 'Could not open $pageName';
  }

  @override
  String supportErrorOpeningPage(String pageName, Object error) {
    return 'Error opening $pageName: $error';
  }

  @override
  String get reportTitle => 'Report Content';

  @override
  String get reportWhyReporting => 'Why are you reporting this content?';

  @override
  String get reportPolicyNotice =>
      'Divine will act on content reports within 24 hours by removing the content and ejecting the user who provided the offending content.';

  @override
  String get reportAdditionalDetails => 'Additional details (optional)';

  @override
  String get reportBlockUser => 'Block this user';

  @override
  String get reportCancel => 'Cancel';

  @override
  String get reportSubmit => 'Report';

  @override
  String get reportSelectReason =>
      'Please select a reason for reporting this content';

  @override
  String get reportReasonSpam => 'Spam or Unwanted Content';

  @override
  String get reportReasonHarassment => 'Harassment, Bullying, or Threats';

  @override
  String get reportReasonViolence => 'Violent or Extremist Content';

  @override
  String get reportReasonSexualContent => 'Sexual or Adult Content';

  @override
  String get reportReasonCopyright => 'Copyright Violation';

  @override
  String get reportReasonFalseInfo => 'False Information';

  @override
  String get reportReasonCsam => 'Child Safety Violation';

  @override
  String get reportReasonAiGenerated => 'AI-Generated Content';

  @override
  String get reportReasonOther => 'Other Policy Violation';

  @override
  String reportFailed(Object error) {
    return 'Failed to report content: $error';
  }

  @override
  String get reportReceivedTitle => 'Report Received';

  @override
  String get reportReceivedThankYou =>
      'Thank you for helping keep Divine safe.';

  @override
  String get reportReceivedReviewNotice =>
      'Our team will review your report and take appropriate action. You may receive updates via direct message.';

  @override
  String get reportLearnMore => 'Learn More';

  @override
  String get reportSafetyUrl => 'divine.video/safety';

  @override
  String get reportClose => 'Close';

  @override
  String get listAddToList => 'Add to List';

  @override
  String listVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get listNewList => 'New List';

  @override
  String get listDone => 'Done';

  @override
  String get listErrorLoading => 'Error loading lists';

  @override
  String listRemovedFrom(String name) {
    return 'Removed from $name';
  }

  @override
  String listAddedTo(String name) {
    return 'Added to $name';
  }

  @override
  String get listCreateNewList => 'Create New List';

  @override
  String get listNameLabel => 'List Name';

  @override
  String get listDescriptionLabel => 'Description (optional)';

  @override
  String get listPublicList => 'Public List';

  @override
  String get listPublicListSubtitle => 'Others can follow and see this list';

  @override
  String get listCancel => 'Cancel';

  @override
  String get listCreate => 'Create';

  @override
  String get listCreateFailed => 'Failed to create list';

  @override
  String get keyManagementTitle => 'Nostr Keys';

  @override
  String get keyManagementWhatAreKeys => 'What are Nostr keys?';

  @override
  String get keyManagementExplanation =>
      'Your Nostr identity is a cryptographic key pair:\n\n• Your public key (npub) is like your username - share it freely\n• Your private key (nsec) is like your password - keep it secret!\n\nYour nsec lets you access your account on any Nostr app.';

  @override
  String get keyManagementImportTitle => 'Import Existing Key';

  @override
  String get keyManagementImportSubtitle =>
      'Already have a Nostr account? Paste your private key (nsec) to access it here.';

  @override
  String get keyManagementImportButton => 'Import Key';

  @override
  String get keyManagementImportWarning =>
      'This will replace your current key!';

  @override
  String get keyManagementBackupTitle => 'Backup Your Key';

  @override
  String get keyManagementBackupSubtitle =>
      'Save your private key (nsec) to use your account in other Nostr apps.';

  @override
  String get keyManagementCopyNsec => 'Copy My Private Key (nsec)';

  @override
  String get keyManagementNeverShare => 'Never share your nsec with anyone!';

  @override
  String get keyManagementPasteKey => 'Please paste your private key';

  @override
  String get keyManagementInvalidFormat =>
      'Invalid key format. Must start with \"nsec1\"';

  @override
  String get keyManagementConfirmImportTitle => 'Import This Key?';

  @override
  String get keyManagementConfirmImportBody =>
      'This will replace your current identity with the imported one.\n\nYour current key will be lost unless you backed it up first.';

  @override
  String get keyManagementImportConfirm => 'Import';

  @override
  String get keyManagementImportSuccess => 'Key imported successfully!';

  @override
  String keyManagementImportFailed(Object error) {
    return 'Failed to import key: $error';
  }

  @override
  String get keyManagementExportSuccess =>
      'Private key copied to clipboard!\n\nStore it somewhere safe.';

  @override
  String keyManagementExportFailed(Object error) {
    return 'Failed to export key: $error';
  }

  @override
  String get saveOriginalSavedToCameraRoll => 'Saved to Camera Roll';

  @override
  String get saveOriginalShare => 'Share';

  @override
  String get saveOriginalDone => 'Done';

  @override
  String get saveOriginalPhotosAccessNeeded => 'Photos Access Needed';

  @override
  String get saveOriginalPhotosAccessMessage =>
      'To save videos, allow Photos access in Settings.';

  @override
  String get saveOriginalOpenSettings => 'Open Settings';

  @override
  String get saveOriginalNotNow => 'Not Now';

  @override
  String get cameraPermissionNotNow => 'Not now';

  @override
  String get saveOriginalDownloadFailed => 'Download Failed';

  @override
  String get saveOriginalDismiss => 'Dismiss';

  @override
  String get saveOriginalDownloadingVideo => 'Downloading Video';

  @override
  String get saveOriginalSavingToCameraRoll => 'Saving to Camera Roll';

  @override
  String get saveOriginalFetchingVideo =>
      'Fetching the video from the network...';

  @override
  String get saveOriginalSavingVideo =>
      'Saving the original video to your camera roll...';

  @override
  String get soundTitle => 'Sound';

  @override
  String get soundOriginalSound => 'Original sound';

  @override
  String get soundVideosUsingThisSound => 'Videos using this sound';

  @override
  String get soundSourceVideo => 'Source video';

  @override
  String get soundNoVideosYet => 'No videos yet';

  @override
  String get soundBeFirstToUse => 'Be the first to use this sound!';

  @override
  String get soundFailedToLoadVideos => 'Failed to load videos';

  @override
  String get soundRetry => 'Retry';

  @override
  String get soundVideosUnavailable => 'Videos unavailable';

  @override
  String get soundCouldNotLoadDetails => 'Could not load video details';

  @override
  String get soundPreview => 'Preview';

  @override
  String get soundStop => 'Stop';

  @override
  String get soundUseSound => 'Use Sound';

  @override
  String get soundNoVideoCount => 'No videos yet';

  @override
  String get soundOneVideo => '1 video';

  @override
  String soundVideoCount(int count) {
    return '$count videos';
  }

  @override
  String get soundUnableToPreview =>
      'Unable to preview sound - no audio available';

  @override
  String soundPreviewFailed(Object error) {
    return 'Failed to play preview: $error';
  }

  @override
  String get soundViewSource => 'View source';

  @override
  String get soundCloseTooltip => 'Close';

  @override
  String get exploreNotExploreRoute => 'Not an explore route';

  @override
  String get legalTitle => 'Legal';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalTermsOfServiceSubtitle => 'Usage terms and conditions';

  @override
  String get legalPrivacyPolicy => 'Privacy Policy';

  @override
  String get legalPrivacyPolicySubtitle => 'How we handle your data';

  @override
  String get legalSafetyStandards => 'Safety Standards';

  @override
  String get legalSafetyStandardsSubtitle => 'Community guidelines and safety';

  @override
  String get legalDmca => 'DMCA';

  @override
  String get legalDmcaSubtitle => 'Copyright and takedown policy';

  @override
  String get legalOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get legalOpenSourceLicensesSubtitle =>
      'Third-party package attributions';

  @override
  String get legalAppName => 'Divine';

  @override
  String legalCouldNotOpenPage(String pageName) {
    return 'Could not open $pageName';
  }

  @override
  String legalErrorOpeningPage(String pageName, Object error) {
    return 'Error opening $pageName: $error';
  }

  @override
  String get categoryAction => 'Action';

  @override
  String get categoryAdventure => 'Adventure';

  @override
  String get categoryAnimals => 'Animals';

  @override
  String get categoryAnimation => 'Animation';

  @override
  String get categoryArchitecture => 'Architecture';

  @override
  String get categoryArt => 'Art';

  @override
  String get categoryAutomotive => 'Automotive';

  @override
  String get categoryAwardShow => 'Award Show';

  @override
  String get categoryAwards => 'Awards';

  @override
  String get categoryBaseball => 'Baseball';

  @override
  String get categoryBasketball => 'Basketball';

  @override
  String get categoryBeauty => 'Beauty';

  @override
  String get categoryBeverage => 'Beverage';

  @override
  String get categoryCars => 'Cars';

  @override
  String get categoryCelebration => 'Celebration';

  @override
  String get categoryCelebrities => 'Celebrities';

  @override
  String get categoryCelebrity => 'Celebrity';

  @override
  String get categoryCityscape => 'Cityscape';

  @override
  String get categoryComedy => 'Comedy';

  @override
  String get categoryConcert => 'Concert';

  @override
  String get categoryCooking => 'Cooking';

  @override
  String get categoryCostume => 'Costume';

  @override
  String get categoryCrafts => 'Crafts';

  @override
  String get categoryCrime => 'Crime';

  @override
  String get categoryCulture => 'Culture';

  @override
  String get categoryDance => 'Dance';

  @override
  String get categoryDiy => 'DIY';

  @override
  String get categoryDrama => 'Drama';

  @override
  String get categoryEducation => 'Education';

  @override
  String get categoryEmotional => 'Emotional';

  @override
  String get categoryEmotions => 'Emotions';

  @override
  String get categoryEntertainment => 'Entertainment';

  @override
  String get categoryEvent => 'Event';

  @override
  String get categoryFamily => 'Family';

  @override
  String get categoryFans => 'Fans';

  @override
  String get categoryFantasy => 'Fantasy';

  @override
  String get categoryFashion => 'Style';

  @override
  String get categoryFestival => 'Festival';

  @override
  String get categoryFilm => 'Film';

  @override
  String get categoryFitness => 'Fitness';

  @override
  String get categoryFood => 'Food';

  @override
  String get categoryFootball => 'Football';

  @override
  String get categoryFurniture => 'Furniture';

  @override
  String get categoryGaming => 'Gaming';

  @override
  String get categoryGolf => 'Golf';

  @override
  String get categoryGrooming => 'Grooming';

  @override
  String get categoryGuitar => 'Guitar';

  @override
  String get categoryHalloween => 'Halloween';

  @override
  String get categoryHealth => 'Health';

  @override
  String get categoryHockey => 'Hockey';

  @override
  String get categoryHoliday => 'Holiday';

  @override
  String get categoryHome => 'Home';

  @override
  String get categoryHomeImprovement => 'Home Improvement';

  @override
  String get categoryHorror => 'Horror';

  @override
  String get categoryHospital => 'Hospital';

  @override
  String get categoryHumor => 'Humor';

  @override
  String get categoryInteriorDesign => 'Interior Design';

  @override
  String get categoryInterview => 'Interview';

  @override
  String get categoryKids => 'Kids';

  @override
  String get categoryLifestyle => 'Lifestyle';

  @override
  String get categoryMagic => 'Magic';

  @override
  String get categoryMakeup => 'Makeup';

  @override
  String get categoryMedical => 'Medical';

  @override
  String get categoryMusic => 'Music';

  @override
  String get categoryMystery => 'Mystery';

  @override
  String get categoryNature => 'Nature';

  @override
  String get categoryNews => 'News';

  @override
  String get categoryOutdoor => 'Outdoor';

  @override
  String get categoryParty => 'Party';

  @override
  String get categoryPeople => 'People';

  @override
  String get categoryPerformance => 'Performance';

  @override
  String get categoryPets => 'Pets';

  @override
  String get categoryPolitics => 'Politics';

  @override
  String get categoryPrank => 'Prank';

  @override
  String get categoryPranks => 'Pranks';

  @override
  String get categoryRealityShow => 'Reality Show';

  @override
  String get categoryRelationship => 'Relationship';

  @override
  String get categoryRelationships => 'Relationships';

  @override
  String get categoryRomance => 'Romance';

  @override
  String get categorySchool => 'School';

  @override
  String get categoryScienceFiction => 'Science Fiction';

  @override
  String get categorySelfie => 'Selfie';

  @override
  String get categoryShopping => 'Shopping';

  @override
  String get categorySkateboarding => 'Skateboarding';

  @override
  String get categorySkincare => 'Skincare';

  @override
  String get categorySoccer => 'Soccer';

  @override
  String get categorySocialGathering => 'Social Gathering';

  @override
  String get categorySocialMedia => 'Social Media';

  @override
  String get categorySports => 'Sports';

  @override
  String get categoryTalkShow => 'Talk Show';

  @override
  String get categoryTech => 'Tech';

  @override
  String get categoryTechnology => 'Technology';

  @override
  String get categoryTelevision => 'Television';

  @override
  String get categoryToys => 'Toys';

  @override
  String get categoryTransportation => 'Transportation';

  @override
  String get categoryTravel => 'Travel';

  @override
  String get categoryUrban => 'Urban';

  @override
  String get categoryViolence => 'Violence';

  @override
  String get categoryVlog => 'Vlog';

  @override
  String get categoryVlogging => 'Vlogging';

  @override
  String get categoryWrestling => 'Wrestling';

  @override
  String get profileSetupUploadSuccess =>
      'Profile picture uploaded successfully!';

  @override
  String inboxReportedUser(String displayName) {
    return 'Reported $displayName';
  }

  @override
  String inboxBlockedUser(String displayName) {
    return 'Blocked $displayName';
  }

  @override
  String inboxUnblockedUser(String displayName) {
    return 'Unblocked $displayName';
  }

  @override
  String get inboxRemovedConversation => 'Removed conversation';

  @override
  String get inboxEmptyTitle => 'No messages yet';

  @override
  String get inboxEmptySubtitle => 'That + button won\'t bite.';

  @override
  String get inboxActionMute => 'Mute conversation';

  @override
  String inboxActionReport(String displayName) {
    return 'Report $displayName';
  }

  @override
  String inboxActionBlock(String displayName) {
    return 'Block $displayName';
  }

  @override
  String inboxActionUnblock(String displayName) {
    return 'Unblock $displayName';
  }

  @override
  String get inboxActionRemove => 'Remove conversation';

  @override
  String get inboxRemoveConfirmTitle => 'Remove conversation?';

  @override
  String inboxRemoveConfirmBody(String displayName) {
    return 'This will delete your conversation with $displayName. This action cannot be undone.';
  }

  @override
  String get inboxRemoveConfirmConfirm => 'Remove';

  @override
  String get inboxConversationMuted => 'Conversation muted';

  @override
  String get inboxConversationUnmuted => 'Conversation unmuted';

  @override
  String get reportDialogCancel => 'Cancel';

  @override
  String get reportDialogReport => 'Report';

  @override
  String exploreVideoId(String id) {
    return 'ID: $id';
  }

  @override
  String exploreVideoTitle(String title) {
    return 'Title: $title';
  }

  @override
  String exploreVideoCounter(int current, int total) {
    return 'Video $current/$total';
  }

  @override
  String discoverListsFailedToUpdateSubscription(String error) {
    return 'Failed to update subscription: $error';
  }

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonNext => 'Next';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get videoMetadataTags => 'Tags';

  @override
  String get videoMetadataExpiration => 'Expiration';

  @override
  String get videoMetadataExpirationNotExpire => 'Does not expire';

  @override
  String get videoMetadataExpirationOneDay => '1 day';

  @override
  String get videoMetadataExpirationOneWeek => '1 week';

  @override
  String get videoMetadataExpirationOneMonth => '1 month';

  @override
  String get videoMetadataExpirationOneYear => '1 year';

  @override
  String get videoMetadataExpirationOneDecade => '1 decade';

  @override
  String get videoMetadataContentWarnings => 'Content Warnings';

  @override
  String get videoEditorStickers => 'Stickers';

  @override
  String get trendingTitle => 'Trending';

  @override
  String get proofmodeCheckAiGenerated => 'Check if AI-generated';

  @override
  String get libraryDeleteConfirm => 'Delete';

  @override
  String get libraryWebUnavailableHeadline =>
      'Library is available in the mobile app';

  @override
  String get libraryWebUnavailableDescription =>
      'Drafts and clips are saved on your device, so open Divine on your phone to manage them.';

  @override
  String get libraryTabDrafts => 'Drafts';

  @override
  String get libraryTabClips => 'Clips';

  @override
  String get librarySaveToCameraRollTooltip => 'Save to camera roll';

  @override
  String get libraryDeleteSelectedClipsTooltip => 'Delete selected clips';

  @override
  String get libraryDeleteClipsTitle => 'Delete Clips';

  @override
  String libraryDeleteClipsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '# selected clips',
      one: '# selected clip',
    );
    return 'Are you sure you want to delete $_temp0?';
  }

  @override
  String get libraryDeleteClipsWarning =>
      'This action cannot be undone. The video files will be permanently removed from your device.';

  @override
  String get libraryPreparingVideo => 'Preparing video...';

  @override
  String get libraryCreateVideo => 'Create Video';

  @override
  String libraryClipsSavedToDestination(int count, String destination) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips',
      one: '1 clip',
    );
    return '$_temp0 saved to $destination';
  }

  @override
  String libraryClipsSavePartialResult(int successCount, int failureCount) {
    return '$successCount saved, $failureCount failed';
  }

  @override
  String libraryGalleryPermissionDenied(String destination) {
    return '$destination permission denied';
  }

  @override
  String libraryClipsDeletedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count clips deleted',
      one: '1 clip deleted',
    );
    return '$_temp0';
  }

  @override
  String get libraryCouldNotLoadDrafts => 'Couldn\'t load drafts';

  @override
  String get libraryCouldNotLoadClips => 'Couldn\'t load clips';

  @override
  String get libraryOpenErrorDescription =>
      'Something went wrong while opening your library. You can try again.';

  @override
  String get libraryNoDraftsYetTitle => 'No Drafts Yet';

  @override
  String get libraryNoDraftsYetSubtitle =>
      'Videos you save as draft will appear here';

  @override
  String get libraryNoClipsYetTitle => 'No Clips Yet';

  @override
  String get libraryNoClipsYetSubtitle =>
      'Your recorded video clips will appear here';

  @override
  String get libraryDraftDeletedSnackbar => 'Draft deleted';

  @override
  String get libraryDraftDeleteFailedSnackbar => 'Failed to delete draft';

  @override
  String get libraryDraftActionPost => 'Post';

  @override
  String get libraryDraftActionEdit => 'Edit';

  @override
  String get libraryDraftActionDelete => 'Delete draft';

  @override
  String get libraryDeleteDraftTitle => 'Delete Draft';

  @override
  String libraryDeleteDraftMessage(String title) {
    return 'Are you sure you want to delete \"$title\"?';
  }

  @override
  String get libraryDeleteClipTitle => 'Delete Clip';

  @override
  String get libraryDeleteClipMessage =>
      'Are you sure you want to delete this clip?';

  @override
  String get libraryClipSelectionTitle => 'Clips';

  @override
  String librarySecondsRemaining(String seconds) {
    return '${seconds}s remaining';
  }

  @override
  String get libraryAddClips => 'Add';

  @override
  String get libraryRecordVideo => 'Record a Video';

  @override
  String get routerInvalidCreator => 'Invalid creator';

  @override
  String get routerInvalidHashtagRoute => 'Invalid hashtag route';

  @override
  String get categoryGalleryCouldNotLoadVideos => 'Could not load videos';

  @override
  String get categoriesCouldNotLoadCategories => 'Could not load categories';

  @override
  String get notificationFollowBack => 'Follow back';

  @override
  String get followingFailedToLoadList => 'Failed to load following list';

  @override
  String get followersFailedToLoadList => 'Failed to load followers list';

  @override
  String get classicVinersTitle => 'OG Viners';

  @override
  String blossomFailedToSaveSettings(String error) {
    return 'Failed to save settings: $error';
  }

  @override
  String get blueskyFailedToUpdateCrosspost =>
      'Failed to update crosspost setting';

  @override
  String get invitesTitle => 'Invite Friends';

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
  String get searchSomethingWentWrong => 'Something went wrong';

  @override
  String get searchTryAgain => 'Try again';

  @override
  String get searchForLists => 'Search for lists';

  @override
  String get searchFindCuratedVideoLists => 'Find curated video lists';

  @override
  String get searchEnterQuery => 'Enter a search query';

  @override
  String get searchDiscoverSomethingInteresting =>
      'Discover something interesting';

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
  String get searchListsSectionHeader => 'Lists';

  @override
  String get searchListsLoadingLabel => 'Loading list results';

  @override
  String get cameraAgeRestriction =>
      'You must be 16 or older to create content';

  @override
  String get featureRequestCancel => 'Cancel';

  @override
  String keyImportError(String error) {
    return 'Error: $error';
  }

  @override
  String get timeNow => 'now';

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
    return '${count}w';
  }

  @override
  String timeShortMonths(int count) {
    return '${count}mo';
  }

  @override
  String timeShortYears(int count) {
    return '${count}y';
  }

  @override
  String get timeVerboseNow => 'Now';

  @override
  String timeAgo(String time) {
    return '$time ago';
  }

  @override
  String get timeToday => 'Today';

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    return '${count}m ago';
  }

  @override
  String timeHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String timeDaysAgo(int count) {
    return '${count}d ago';
  }

  @override
  String get draftTimeJustNow => 'Just now';

  @override
  String get contentLabelNudity => 'Nudity';

  @override
  String get contentLabelSexualContent => 'Sexual Content';

  @override
  String get contentLabelPornography => 'Pornography';

  @override
  String get contentLabelGraphicMedia => 'Graphic Media';

  @override
  String get contentLabelViolence => 'Violence';

  @override
  String get contentLabelSelfHarm => 'Self-Harm/Suicide';

  @override
  String get contentLabelDrugUse => 'Drug Use';

  @override
  String get contentLabelAlcohol => 'Alcohol';

  @override
  String get contentLabelTobacco => 'Tobacco/Smoking';

  @override
  String get contentLabelGambling => 'Gambling';

  @override
  String get contentLabelProfanity => 'Profanity';

  @override
  String get contentLabelHateSpeech => 'Hate Speech';

  @override
  String get contentLabelHarassment => 'Harassment';

  @override
  String get contentLabelFlashingLights => 'Flashing Lights';

  @override
  String get contentLabelAiGenerated => 'AI-Generated';

  @override
  String get contentLabelDeepfake => 'Deepfake';

  @override
  String get contentLabelSpam => 'Spam';

  @override
  String get contentLabelScam => 'Scam/Fraud';

  @override
  String get contentLabelSpoiler => 'Spoiler';

  @override
  String get contentLabelMisleading => 'Misleading';

  @override
  String get contentLabelSensitiveContent => 'Sensitive Content';

  @override
  String notificationLikedYourVideo(String actorName) {
    return '$actorName liked your video';
  }

  @override
  String notificationCommentedOnYourVideo(String actorName) {
    return '$actorName commented on your video';
  }

  @override
  String notificationStartedFollowing(String actorName) {
    return '$actorName started following you';
  }

  @override
  String notificationMentionedYou(String actorName) {
    return '$actorName mentioned you';
  }

  @override
  String notificationRepostedYourVideo(String actorName) {
    return '$actorName reposted your video';
  }

  @override
  String get draftUntitled => 'Untitled';

  @override
  String get contentWarningNone => 'None';

  @override
  String get textBackgroundNone => 'None';

  @override
  String get textBackgroundSolid => 'Solid';

  @override
  String get textBackgroundHighlight => 'Highlight';

  @override
  String get textBackgroundTransparent => 'Transparent';

  @override
  String get textAlignLeft => 'Left';

  @override
  String get textAlignRight => 'Right';

  @override
  String get textAlignCenter => 'Center';

  @override
  String get cameraPermissionWebUnsupportedTitle =>
      'Camera not supported on web yet';

  @override
  String get cameraPermissionWebUnsupportedDescription =>
      'Camera capture and recording are not available in the web version yet.';

  @override
  String get cameraPermissionBackToFeed => 'Back to feed';

  @override
  String get cameraPermissionErrorTitle => 'Permission Error';

  @override
  String get cameraPermissionErrorDescription =>
      'Something went wrong while checking permissions.';

  @override
  String get cameraPermissionRetry => 'Retry';

  @override
  String get cameraPermissionAllowAccessTitle =>
      'Allow camera & microphone access';

  @override
  String get cameraPermissionAllowAccessDescription =>
      'This allows you to capture and edit videos right here in the app, nothing more.';

  @override
  String get cameraPermissionContinue => 'Continue';

  @override
  String get cameraPermissionGoToSettings => 'Go to settings';

  @override
  String get videoRecorderWhySixSecondsTitle => 'Why six seconds?';

  @override
  String get videoRecorderWhySixSecondsSubtitle =>
      'Quick clips make space for spontaneity. The 6-second format helps you capture authentic moments as they happen.';

  @override
  String get videoRecorderWhySixSecondsButton => 'Got it!';

  @override
  String get videoRecorderAutosaveFoundTitle => 'We found work in progress';

  @override
  String get videoRecorderAutosaveFoundSubtitle =>
      'Would you like to continue where you left off?';

  @override
  String get videoRecorderAutosaveContinueButton => 'Yes, continue';

  @override
  String get videoRecorderAutosaveDiscardButton => 'No, start a new video';

  @override
  String get videoRecorderAutosaveRestoreFailure =>
      'Could not restore your draft';

  @override
  String get videoRecorderStopRecordingTooltip => 'Stop recording';

  @override
  String get videoRecorderStartRecordingTooltip => 'Start recording';

  @override
  String get videoRecorderRecordingTapToStopLabel =>
      'Recording. Tap anywhere to stop';

  @override
  String get videoRecorderTapToStartLabel => 'Tap anywhere to start recording';

  @override
  String get videoRecorderDeleteLastClipLabel => 'Delete last clip';

  @override
  String get videoRecorderSwitchCameraLabel => 'Switch camera';

  @override
  String get videoRecorderToggleGridLabel => 'Toggle grid';

  @override
  String get videoRecorderToggleGhostFrameLabel => 'Toggle ghost frame';

  @override
  String get videoRecorderGhostFrameEnabled => 'Ghost frame enabled';

  @override
  String get videoRecorderGhostFrameDisabled => 'Ghost frame disabled';

  @override
  String get videoRecorderClipDeletedMessage => 'Clip deleted';

  @override
  String get videoRecorderCloseLabel => 'Close video recorder';

  @override
  String get videoRecorderContinueToEditorLabel => 'Continue to video editor';

  @override
  String get videoRecorderCaptureCloseLabel => 'Close';

  @override
  String get videoRecorderCaptureNextLabel => 'Next';

  @override
  String get videoRecorderToggleFlashLabel => 'Toggle flash';

  @override
  String get videoRecorderCycleTimerLabel => 'Cycle timer';

  @override
  String get videoRecorderToggleAspectRatioLabel => 'Toggle aspect ratio';

  @override
  String get videoRecorderLibraryEmptyLabel => 'Clip library, no clips';

  @override
  String videoRecorderLibraryOpenLabel(int clipCount) {
    String _temp0 = intl.Intl.pluralLogic(
      clipCount,
      locale: localeName,
      other: 'Open clip library, $clipCount clips',
      one: 'Open clip library, 1 clip',
    );
    return '$_temp0';
  }

  @override
  String get videoEditorCameraLabel => 'Camera';

  @override
  String get videoEditorOpenCameraSemanticLabel => 'Open camera';

  @override
  String get videoEditorLibraryLabel => 'Library';

  @override
  String get videoEditorTextLabel => 'Text';

  @override
  String get videoEditorDrawLabel => 'Draw';

  @override
  String get videoEditorFilterLabel => 'Filter';

  @override
  String get videoEditorAudioLabel => 'Audio';

  @override
  String get videoEditorVolumeLabel => 'Volume';

  @override
  String get videoEditorAddTitle => 'Add';

  @override
  String get videoEditorOpenLibrarySemanticLabel => 'Open Library';

  @override
  String get videoEditorOpenAudioSemanticLabel => 'Open audio editor';

  @override
  String get videoEditorOpenTextSemanticLabel => 'Open text editor';

  @override
  String get videoEditorOpenDrawSemanticLabel => 'Open draw editor';

  @override
  String get videoEditorOpenFilterSemanticLabel => 'Open filter editor';

  @override
  String get videoEditorSaveDraftTitle => 'Save your draft?';

  @override
  String get videoEditorSaveDraftSubtitle =>
      'Keep your edits for later, or discard them and leave the editor.';

  @override
  String get videoEditorSaveDraftButton => 'Save draft';

  @override
  String get videoEditorDiscardChangesButton => 'Discard changes';

  @override
  String get videoEditorKeepEditingButton => 'Keep editing';

  @override
  String get videoEditorDeleteLayerDropZone => 'Delete layer drop zone';

  @override
  String get videoEditorReleaseToDeleteLayer => 'Release to delete layer';

  @override
  String get videoEditorDoneLabel => 'Done';

  @override
  String get videoEditorPlayPauseSemanticLabel => 'Play or pause video';

  @override
  String get videoEditorCropSemanticLabel => 'Crop';

  @override
  String get videoEditorCannotSplitProcessing =>
      'Cannot split clip while it is being processed. Please wait.';

  @override
  String videoEditorSplitPositionInvalid(int minDurationMs) {
    return 'Split position invalid. Both clips must be at least ${minDurationMs}ms long.';
  }

  @override
  String get videoEditorAddClipFromLibrary => 'Add clip from Library';

  @override
  String get videoEditorSaveSelectedClip => 'Save selected clip';

  @override
  String get videoEditorSplitClip => 'Split clip';

  @override
  String get videoEditorSaveClip => 'Save clip';

  @override
  String get videoEditorDeleteClip => 'Delete clip';

  @override
  String get videoEditorClipSavedSuccess => 'Clip saved to library';

  @override
  String get videoEditorClipSaveFailed => 'Failed to save clip';

  @override
  String get videoEditorClipDeleted => 'Clip deleted';

  @override
  String get videoEditorColorPickerSemanticLabel => 'Color picker';

  @override
  String get videoEditorUndoSemanticLabel => 'Undo';

  @override
  String get videoEditorRedoSemanticLabel => 'Redo';

  @override
  String get videoEditorTextColorSemanticLabel => 'Text color';

  @override
  String get videoEditorTextAlignmentSemanticLabel => 'Text alignment';

  @override
  String get videoEditorTextBackgroundSemanticLabel => 'Text background';

  @override
  String get videoEditorFontSemanticLabel => 'Font';

  @override
  String get videoEditorNoStickersFound => 'No stickers found';

  @override
  String get videoEditorNoStickersAvailable => 'No stickers available';

  @override
  String get videoEditorFailedLoadStickers => 'Failed to load stickers';

  @override
  String get videoEditorAdjustVolumeTitle => 'Adjust volume';

  @override
  String get videoEditorRecordedAudioLabel => 'Recorded audio';

  @override
  String get videoEditorCustomAudioLabel => 'Custom audio';

  @override
  String get videoEditorPlaySemanticLabel => 'Play';

  @override
  String get videoEditorPauseSemanticLabel => 'Pause';

  @override
  String get videoEditorMuteAudioSemanticLabel => 'Mute audio';

  @override
  String get videoEditorUnmuteAudioSemanticLabel => 'Unmute audio';

  @override
  String get videoEditorDeleteLabel => 'Delete';

  @override
  String get videoEditorDeleteSelectedItemSemanticLabel =>
      'Delete selected item';

  @override
  String get videoEditorEditLabel => 'Edit';

  @override
  String get videoEditorEditSelectedItemSemanticLabel => 'Edit selected item';

  @override
  String get videoEditorDuplicateLabel => 'Duplicate';

  @override
  String get videoEditorDuplicateSelectedItemSemanticLabel =>
      'Duplicate selected item';

  @override
  String get videoEditorSplitLabel => 'Split';

  @override
  String get videoEditorSplitSelectedClipSemanticLabel => 'Split selected clip';

  @override
  String get videoEditorFinishTimelineEditingSemanticLabel =>
      'Finish timeline editing';

  @override
  String get videoEditorAudioPlayPreviewSemanticLabel => 'Play preview';

  @override
  String get videoEditorAudioPausePreviewSemanticLabel => 'Pause preview';

  @override
  String get videoEditorAudioUntitledSound => 'Untitled sound';

  @override
  String get videoEditorAudioUntitled => 'Untitled';

  @override
  String get videoEditorAudioAddAudio => 'Add audio';

  @override
  String get videoEditorAudioNoSoundsAvailableTitle => 'No sounds available';

  @override
  String get videoEditorAudioNoSoundsAvailableSubtitle =>
      'Sounds will appear here when creators share audio';

  @override
  String get videoEditorAudioFailedToLoadTitle => 'Failed to load sounds';

  @override
  String get videoEditorAudioSegmentInstruction =>
      'Select the audio segment for your video';

  @override
  String get videoEditorAudioCategoryDivine => 'diVine';

  @override
  String get videoEditorAudioCategoryCommunity => 'Community';

  @override
  String get videoEditorDrawToolArrowSemanticLabel => 'Arrow tool';

  @override
  String get videoEditorDrawToolEraserSemanticLabel => 'Eraser tool';

  @override
  String get videoEditorDrawToolMarkerSemanticLabel => 'Marker tool';

  @override
  String get videoEditorDrawToolPencilSemanticLabel => 'Pencil tool';

  @override
  String videoEditorLayerReorderLabel(int index) {
    return 'Reorder layer $index';
  }

  @override
  String get videoEditorLayerReorderHint => 'Hold to reorder';

  @override
  String get videoEditorShowTimelineSemanticLabel => 'Show timeline';

  @override
  String get videoEditorHideTimelineSemanticLabel => 'Hide timeline';

  @override
  String get videoEditorFeedPreviewContent =>
      'Avoid placing content behind these areas.';

  @override
  String get videoEditorStickerSearchHint => 'Search stickers...';

  @override
  String get videoEditorSelectFontSemanticLabel => 'Select font';

  @override
  String get videoEditorFontUnknown => 'Unknown';

  @override
  String get videoEditorSplitPlayheadOutsideClip =>
      'Playhead must be within the selected clip to split.';

  @override
  String get videoEditorTimelineTrimStartSemanticLabel => 'Trim start';

  @override
  String get videoEditorTimelineTrimEndSemanticLabel => 'Trim end';

  @override
  String get videoEditorTimelineTrimClipSemanticLabel => 'Trim clip';

  @override
  String get videoEditorTimelineTrimClipHint =>
      'Drag handles to adjust clip duration';

  @override
  String videoEditorTimelineDraggingClipSemanticLabel(int index) {
    return 'Dragging clip $index';
  }

  @override
  String videoEditorTimelineClipSemanticLabel(
    int index,
    int total,
    String duration,
  ) {
    return 'Clip $index of $total, $duration seconds';
  }

  @override
  String get videoEditorTimelineClipReorderHint => 'Long press to reorder';

  @override
  String get videoEditorClipGalleryInstruction =>
      'Tap to edit. Hold and drag to reorder.';

  @override
  String get videoEditorTimelineClipMoveLeft => 'Move left';

  @override
  String get videoEditorTimelineClipMoveRight => 'Move right';

  @override
  String get videoEditorTimelineLongPressToDragHint => 'Long press to drag';

  @override
  String get videoEditorVideoTimelineSemanticLabel => 'Video timeline';

  @override
  String videoEditorTimelinePositionFormat(int minutes, String seconds) {
    return '${minutes}m ${seconds}s';
  }

  @override
  String videoEditorColorSelectedSemanticLabel(String colorName) {
    return '$colorName, selected';
  }

  @override
  String get videoEditorCloseColorPickerSemanticLabel => 'Close color picker';

  @override
  String get videoEditorPickColorTitle => 'Pick color';

  @override
  String get videoEditorConfirmColorSemanticLabel => 'Confirm color';

  @override
  String get videoEditorSaturationBrightnessSemanticLabel =>
      'Saturation and brightness';

  @override
  String videoEditorSaturationBrightnessValue(int saturation, int brightness) {
    return 'Saturation $saturation%, Brightness $brightness%';
  }

  @override
  String get videoEditorHueSemanticLabel => 'Hue';

  @override
  String get videoEditorAddElementSemanticLabel => 'Add element';

  @override
  String get videoEditorCloseSemanticLabel => 'Close';

  @override
  String get videoEditorDoneSemanticLabel => 'Done';

  @override
  String get videoEditorLevelSemanticLabel => 'Level';

  @override
  String get videoMetadataBackSemanticLabel => 'Back';

  @override
  String get videoMetadataDismissHelpDialogSemanticLabel =>
      'Dismiss help dialog';

  @override
  String get videoMetadataGotItButton => 'Got it!';

  @override
  String get videoMetadataLimitReachedWarning =>
      '64KB limit reached. Remove some content to continue.';

  @override
  String get videoMetadataExpirationLabel => 'Expiration';

  @override
  String get videoMetadataSelectExpirationSemanticLabel =>
      'Select expiration time';

  @override
  String get videoMetadataTitleLabel => 'Title';

  @override
  String get videoMetadataDescriptionLabel => 'Description';

  @override
  String get videoMetadataTagsLabel => 'Tags';

  @override
  String get videoMetadataDeleteTagSemanticLabel => 'Delete';

  @override
  String videoMetadataDeleteTagHint(String tag) {
    return 'Delete Tag $tag';
  }

  @override
  String get videoMetadataContentWarningLabel => 'Content Warning';

  @override
  String get videoMetadataSelectContentWarningsSemanticLabel =>
      'Select content warnings';

  @override
  String get videoMetadataContentWarningSelectAllThatApply =>
      'Select all that apply to your content';

  @override
  String get videoMetadataContentWarningDoneButton => 'Done';

  @override
  String get videoMetadataCollaboratorsLabel => 'Collaborators';

  @override
  String get videoMetadataAddCollaboratorSemanticLabel => 'Invite collaborator';

  @override
  String get videoMetadataCollaboratorsHelpTooltip => 'How collaborators work';

  @override
  String videoMetadataCollaboratorsCount(int count, int max) {
    return '$count/$max Collaborators';
  }

  @override
  String get videoMetadataRemoveCollaboratorSemanticLabel =>
      'Remove collaborator';

  @override
  String get videoMetadataCollaboratorsHelpMessage =>
      'Collaborators are invited as co-creators on this post. You can only invite people you mutually follow, and they appear as collaborators after they confirm.';

  @override
  String get videoMetadataMutualFollowersSearchText => 'Mutual followers';

  @override
  String videoMetadataMustMutuallyFollowSnackbar(String name) {
    return 'You need to mutually follow $name to invite them as a collaborator.';
  }

  @override
  String get videoMetadataInspiredByLabel => 'Inspired by';

  @override
  String get videoMetadataSetInspiredBySemanticLabel => 'Set inspired by';

  @override
  String get videoMetadataInspiredByHelpTooltip =>
      'How inspiration credits work';

  @override
  String get videoMetadataInspiredByNone => 'None';

  @override
  String get videoMetadataInspiredByHelpMessage =>
      'Use this to give attribution. Inspired-by credit is different from collaborators: it acknowledges influence, but does not tag someone as a co-creator.';

  @override
  String get videoMetadataCreatorCannotBeReferencedSnackbar =>
      'This creator cannot be referenced.';

  @override
  String get videoMetadataRemoveInspiredBySemanticLabel => 'Remove inspired by';

  @override
  String get videoMetadataPostDetailsTitle => 'Post details';

  @override
  String get videoMetadataSavedToLibrarySnackbar => 'Saved to library';

  @override
  String get videoMetadataFailedToSaveSnackbar => 'Failed to save';

  @override
  String get videoMetadataGoToLibraryButton => 'Go to Library';

  @override
  String get videoMetadataSaveForLaterSemanticLabel => 'Save for later button';

  @override
  String get videoMetadataRenderingVideoHint => 'Rendering video...';

  @override
  String get videoMetadataSavingVideoHint => 'Saving video...';

  @override
  String videoMetadataSaveToDraftsHint(String destination) {
    return 'Save video to drafts and $destination';
  }

  @override
  String get videoMetadataSaveForLaterButton => 'Save for Later';

  @override
  String get videoMetadataPostSemanticLabel => 'Post button';

  @override
  String get videoMetadataPublishVideoHint => 'Publish video to feed';

  @override
  String get videoMetadataFormNotReadyHint => 'Fill out the form to enable';

  @override
  String get videoMetadataPostButton => 'Post';

  @override
  String get videoMetadataOpenPreviewSemanticLabel =>
      'Open post preview screen';

  @override
  String get videoMetadataShareTitle => 'Share';

  @override
  String get videoMetadataVideoDetailsSubtitle => 'Video details';

  @override
  String get videoMetadataClassicDoneButton => 'Done';

  @override
  String get videoMetadataPlayPreviewSemanticLabel => 'Play preview';

  @override
  String get videoMetadataPausePreviewSemanticLabel => 'Pause preview';

  @override
  String get videoMetadataClosePreviewSemanticLabel => 'Close video preview';

  @override
  String get videoMetadataRemoveSemanticLabel => 'Remove';

  @override
  String get metadataCaptionsLabel => 'Captions';

  @override
  String get metadataCaptionsEnabledSemantics =>
      'Captions enabled for all videos';

  @override
  String get metadataCaptionsDisabledSemantics =>
      'Captions disabled for all videos';

  @override
  String get fullscreenFeedRemovedMessage => 'Video removed';
}
