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

const _knownUntranslatedDebt = {
  'profileNoSavedVideosTitle',
  'profileSavedOwnEmpty',
  'profileErrorLoadingSaved',
  'profileMaybeLaterLabel',
  'profileSecurePrimaryButton',
  'profileCompletePrimaryButton',
  'profileLoopsLabel',
  'profileLikesLabel',
  'profileMyLibraryLabel',
  'profileMessageLabel',
  'profileUserFallback',
  'videoActionLikeLabel',
  'videoActionReplyLabel',
  'videoActionRepostLabel',
  'videoActionShareLabel',
  'videoActionAboutLabel',
  'videoOverlayOpenMetadataFromTitle',
  'videoOverlayOpenMetadataFromDescription',
  // Added by the notifications redesign / avatar lightbox a11y pass.
  // Translators will pick these up in a follow-up pass; until then the
  // generated l10n APIs fall back to the English source.
  'profileAvatarLightboxBarrierLabel',
  'profileAvatarLightboxCloseSemanticLabel',
  'notificationsViewProfileSemanticLabel',
  'notificationsViewProfilesSemanticLabel',
  'notificationRepliedToYourComment',
  'notificationAndConnector',
  'notificationOthersCount',
  // Added by people-lists feature (investigate/list-management).
  // Translators will pick these up in a follow-up pass; until then the
  // generated l10n APIs fall back to the English source.
  'peopleListsAddButton',
  'peopleListsAddButtonWithCount',
  'peopleListsAddPeopleError',
  'peopleListsAddPeopleRetry',
  'peopleListsAddPeopleSearchHint',
  'peopleListsAddPeopleSemanticLabel',
  'peopleListsAddPeopleTitle',
  'peopleListsAddPeopleTooltip',
  'peopleListsAddToList',
  'peopleListsAddToListName',
  'peopleListsAddToListSubtitle',
  'peopleListsBackToGridTooltip',
  'peopleListsCreateButton',
  'peopleListsCreateList',
  'peopleListsEmptySubtitle',
  'peopleListsEmptyTitle',
  'peopleListsErrorLoadingVideos',
  'peopleListsFailedToLoadVideos',
  'peopleListsInNLists',
  'peopleListsListDeletedSubtitle',
  'peopleListsListNameHint',
  'peopleListsListNameLabel',
  'peopleListsListNotFoundSubtitle',
  'peopleListsListNotFoundTitle',
  'peopleListsNewListTitle',
  'peopleListsNoPeopleSubtitle',
  'peopleListsNoPeopleTitle',
  'peopleListsNoPeopleToAdd',
  'peopleListsNoVideosAvailable',
  'peopleListsNoVideosSubtitle',
  'peopleListsNoVideosTitle',
  'peopleListsProfileLongPressHint',
  'peopleListsRemove',
  'peopleListsRemoveConfirmBody',
  'peopleListsRemoveConfirmTitle',
  'peopleListsRemovedFromList',
  'peopleListsRouteTitle',
  'peopleListsSheetTitle',
  'peopleListsUndo',
  'peopleListsVideoNotAvailable',
  'peopleListsViewProfileHint',
  // Added by the #3362 relay-scheme security gate. English + Spanish are
  // translated; other locales fall back to English until the next pass.
  'relaySettingsInsecureUrl',
  'keyImportInsecureBunkerRelay',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}
