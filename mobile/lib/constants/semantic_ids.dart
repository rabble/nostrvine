// ABOUTME: Central constants for Semantics identifiers used as UI-test
// ABOUTME: anchors (XCUITest screenshot pipeline, integration tests).

/// Stable `Semantics(identifier: ...)` values.
///
/// These surface as iOS `accessibilityIdentifier`s / Android resource ids,
/// so UI tests (including the fastlane screenshot suite under
/// `ios/DivineUITests`) can wait on them instead of brittle label text.
/// Keep values snake_case and never reuse one for a different widget.
abstract class SemanticIds {
  static const String exploreTab = 'explore_tab';

  static const String classicVinersRow = 'classic_viners_row';

  static String classicVideoTile(int index) => 'classic_video_tile_$index';

  static const String videoTitle = 'video_title';

  static const String humanMadeBadge = 'human_made_badge';
  static const String verificationSection = 'verification_section';

  static String cameraMode(String mode) => 'camera_mode_$mode';
  static const String cameraRecordButton = 'camera_record_button';

  /// Recorder chrome. Close, next and delete-clip come from the capture
  /// stack, which capture, stop-motion and lip-sync all render; the library
  /// button lives in the bottom bar, which every mode renders. Every label
  /// behind these is localized, so the E2E capture flow drives them by id.
  static const String cameraCloseButton = 'camera_close_button';
  static const String cameraNextButton = 'camera_next_button';
  static const String cameraDeleteClipButton = 'camera_delete_clip_button';
  static const String cameraLibraryButton = 'camera_library_button';

  /// Capture-mode control rail, top to bottom. Lip-sync declares the same
  /// countdown-timer and stabilization support, so it renders this rail
  /// unchanged and drives it with the same E2E util.
  static const String cameraFlashButton = 'camera_flash_button';
  static const String cameraTimerButton = 'camera_timer_button';
  static const String cameraAspectRatioButton = 'camera_aspect_ratio_button';
  static const String cameraSwitchCameraButton = 'camera_switch_camera_button';
  static const String cameraStabilizationButton = 'camera_stabilization_button';

  /// Sound picker on [VideoEditorAudioChip]. Lip-sync puts it in the top-bar
  /// slot capture mode leaves empty, and because the two render an identical
  /// control rail it is the *only* thing separating those viewfinders — so
  /// `assertCaptureMode` asserts its absence.
  ///
  /// The chip is shared with the editor's audio-timing screen, which is a
  /// different route, so the id stays unambiguous on any one screen.
  static const String audioChip = 'audio_chip';

  /// The sound picker the chip opens. Every sound on the Divine tab is an
  /// asset shipped in `assets/sounds/sounds_manifest.json`, so this path is
  /// driveable without touching the relay — which is what lets the lip-sync
  /// E2E flow record against a real sound rather than only proving the
  /// no-sound gate blocks it.
  ///
  /// Tiles are indexed because the list is a search result: the E2E narrows it
  /// to one entry and takes index 0, rather than depending on the manifest's
  /// order.
  static const String audioSearchField = 'audio_search_field';

  static String audioSoundTile(int index) => 'audio_sound_tile_$index';

  static const String audioSelectionDoneButton = 'audio_selection_done_button';

  /// Welcome screen. The fresh-install and returning-user branches show
  /// different buttons, so each action gets its own id rather than being
  /// disambiguated by position.
  static const String authCreateAccountButton = 'create_account_button';
  static const String authSignInButton = 'sign_in_button';
  static const String authContinueAsButton = 'continue_as_button';
  static const String authUseAnotherAccountButton =
      'use_another_account_button';

  /// Invite gate. Account creation is gated on a code here, so these two sit
  /// on the critical path of every flow that signs up.
  static const String authInviteCodeField = 'invite_code_field';
  static const String authInviteSubmitButton = 'invite_submit_button';

  /// Settings rows on the path to signing the device out. removeKeys is the
  /// teardown of every E2E flow, so this route has to stay addressable.
  static const String settingsNostrRow = 'nostr_settings_tile';
  static const String settingsRemoveKeysRow = 'remove_keys_tile';

  static const String profileStatsRow = 'profile_stats_row';

  /// Opens Settings from the own-profile header. This is the only entry
  /// point to Settings in the app, so it gates every E2E flow that ends in
  /// key removal.
  static const String profileSettingsButton = 'settings_button';
  static const String profileBackButton = 'profile_back_button';
  static const String profileMoreButton = 'profile_more_button';

  static String listCard(int index) => 'list_card_$index';

  static String categoryTile(int index) => 'category_tile_$index';

  static const String shareButton = 'share_button';
  static const String shareWithSection = 'share_with_section';

  static String shareContact(int index) => 'share_contact_$index';

  static const String editorTimeline = 'editor_timeline';

  static const String videoDetailLoading = 'video_detail_loading';
}
