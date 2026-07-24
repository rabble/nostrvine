// ABOUTME: Central constants for Semantics identifiers used as UI-test
// ABOUTME: anchors (XCUITest screenshot pipeline, integration tests).

/// Stable `Semantics(identifier: ...)` values.
///
/// These surface as iOS `accessibilityIdentifier`s / Android resource ids,
/// so UI tests (including the fastlane screenshot suite under
/// `ios/DivineUITests`) can wait on them instead of brittle label text.
/// Keep values snake_case and never reuse one for a different widget.
abstract class SemanticIds {
  static const String classicVinersRow = 'classic_viners_row';

  static String classicVideoTile(int index) => 'classic_video_tile_$index';

  static const String humanMadeBadge = 'human_made_badge';
  static const String verificationSection = 'verification_section';

  static String cameraMode(String mode) => 'camera_mode_$mode';

  static const String profileStatsRow = 'profile_stats_row';

  static String listCard(int index) => 'list_card_$index';

  static const String shareWithSection = 'share_with_section';

  static String shareContact(int index) => 'share_contact_$index';

  static const String editorTimeline = 'editor_timeline';
}
