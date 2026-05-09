// ABOUTME: Tests that ARB locale files stay in sync with the English template.
// ABOUTME: Prevents generated l10n APIs from drifting from translated files.

import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

void main() {
  group('ARB consistency', () {
    test('all locales define the same message keys as app_en.arb', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      final templateKeys = _messageKeys(template);

      for (final file in arbFiles) {
        final arb = _readArb(file);
        final keys = _messageKeys(arb);

        expect(
          keys.difference(templateKeys),
          isEmpty,
          reason: '${file.path} has keys missing from app_en.arb',
        );
        expect(
          templateKeys.difference(keys).difference(_knownUntranslatedDebt),
          isEmpty,
          reason: '${file.path} is missing keys from app_en.arb',
        );
      }
    });
  });
}

// Keys grouped by feature. Each entry is awaiting a fresh full-pass
// translation across all 17 non-English locales. Tracking issue: #3814.
const _knownUntranslatedDebt = {
  // Sounds Library — saved sounds, preview, availability, library state.
  'soundUntitled',
  'soundStopPreview',
  'soundPreviewSemanticLabel',
  'soundViewDetailsSemanticLabel',
  'soundsSavedToLibrary',
  'soundsAlreadySavedToLibrary',
  'soundsSavedLibraryTitle',
  'soundsSavedEmptyTitle',
  'soundsSavedEmptyDescription',
  'soundsAvailabilityPrivate',
  'soundsAvailabilityCommunity',
  'soundsRemoveSavedSound',
  'soundsRemovedFromLibrary',
  // Video Editor – Audio Picker — fresh feature; audio category tabs and
  // empty states.
  'videoMetadataAudioReuseTitle',
  'videoMetadataAudioReuseSubtitle',
  'videoEditorAudioCategoryFeatured',
  'videoEditorAudioCategoryMySounds',
  'videoEditorAudioFeaturedEmptyTitle',
  'videoEditorAudioFeaturedEmptySubtitle',
  // Video Settings Menu — auto-advance / mute / captions popover toggles.
  'videoSettingsMenuOpen',
  'videoSettingsMenuClose',
  'videoSettingsCaptionsEnable',
  'videoSettingsCaptionsDisable',
  // Video Action Report / Edit — Report (renamed from Repost → Revine)
  // and Edit row buttons on the fullscreen video overlay.
  'videoActionReportLabel',
  'videoActionReport',
  'videoActionEditLabel',
  'videoActionEdit',
  // Report Reason Subtitles + Learn More — Apple-compliance pass on the
  // Report bottom sheet (each reason has a one-line scope subtitle, plus
  // the divine.video/safety learn-more link).
  'reportReasonSpamSubtitle',
  'reportReasonHarassmentSubtitle',
  'reportReasonViolenceSubtitle',
  'reportReasonSexualContentSubtitle',
  'reportReasonCopyrightSubtitle',
  'reportReasonFalseInfoSubtitle',
  'reportReasonCsamSubtitle',
  'reportReasonAiGeneratedSubtitle',
  'reportReasonOtherSubtitle',
  'reportLearnMoreAt',
  // Added by the desktop save-to-Downloads log export flow. Other locales
  // fall back to English until the next translation pass.
  'supportLogsSavedTo',
  'supportRevealLogsAction',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}
