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

    test('Keycast key export copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      const keys = [
        'keyManagementKeycastRemoteSigning',
        'keyManagementKeycastPasswordPrompt',
        'keyManagementKeycastCopyKey',
        'keyManagementKeycastWrongPassword',
        'keyManagementKeycastSignInAgain',
        'keyManagementKeycastEmailUnverified',
        'keyManagementKeycastDenied',
        'keyManagementKeycastGenericFailure',
      ];

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final key in keys) {
          expect(
            arb[key],
            isNot(template[key]),
            reason: '${file.path} must not fall back to English for $key',
          );
        }
      }
    });

    test('Nostr signature verification copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final key in _signatureVerificationKeys) {
          final value = arb[key];

          expect(
            value,
            isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
            reason: '${file.path} must define a non-empty $key message',
          );
          expect(
            value,
            isNot(template[key]),
            reason:
                '${file.path} must not fall back to English for Nostr '
                'signature verification copy',
          );
        }
      }
    });

    test('CSAM report reason does not collapse into child safety copy', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      for (final file in arbFiles) {
        final arb = _readArb(file);

        expect(
          arb['reportReasonCsam'],
          isNot(arb['reportReasonChildSafety']),
          reason:
              '${file.path} must keep CSAM distinct from child safety in the '
              'report reason title',
        );
        expect(
          arb['reportReasonCsamSubtitle'],
          isNot(arb['reportReasonChildSafetySubtitle']),
          reason:
              '${file.path} must keep CSAM distinct from child safety in the '
              'report reason subtitle',
        );
      }
    });

    test('age-gate signer-unreachable copy is localized for every locale', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));
      final source = template['videoErrorVerifyAgeSignerUnreachable'];

      for (final file in arbFiles) {
        final arb = _readArb(file);
        final value = arb['videoErrorVerifyAgeSignerUnreachable'];

        expect(
          value,
          isA<String>().having((s) => s.isNotEmpty, 'isNotEmpty', isTrue),
          reason:
              '${file.path} must define a non-empty signer-unreachable '
              'message',
        );
        expect(
          value,
          isNot(source),
          reason:
              '${file.path} must not fall back to English for the age-gate '
              'signer-unreachable message',
        );
        // The whole point of this key is a distinct remedy from the generic
        // verify-failed copy; a translation that collapses to that copy
        // silently defeats it.
        expect(
          value,
          isNot(arb['videoErrorVerifyAgeFailed']),
          reason:
              '${file.path} signer-unreachable copy must differ from its '
              'generic videoErrorVerifyAgeFailed copy',
        );
      }
    });

    test('every locale keeps the placeholders app_en.arb interpolates', () {
      final l10nDir = Directory('lib/l10n');
      final arbFiles =
          l10nDir
              .listSync()
              .whereType<File>()
              .where((file) => file.path.endsWith('.arb'))
              .where((file) => !file.path.endsWith('app_en.arb'))
              .toList()
            ..sort((a, b) => a.path.compareTo(b.path));

      final template = _readArb(File('lib/l10n/app_en.arb'));

      // Only placeholders whose value the English source actually substitutes.
      // A selector-only argument, such as the `count` in `{count, plural, ...}`,
      // interpolates nothing, so a language without that distinction may
      // legitimately render a bare noun instead.
      final interpolated = <String, Set<String>>{};
      for (final key in _messageKeys(template)) {
        final source = template[key];
        if (source is! String) continue;
        final used = _declaredPlaceholders(
          template,
          key,
        ).where((name) => _placeholderPattern(name).hasMatch(source)).toSet();
        if (used.isNotEmpty) interpolated[key] = used;
      }

      for (final file in arbFiles) {
        final arb = _readArb(file);

        for (final entry in interpolated.entries) {
          final value = arb[entry.key];
          if (value is! String) continue;

          for (final name in entry.value) {
            // gen-l10n takes the signature from the template, so a dropped
            // placeholder still compiles: the generated getter accepts the
            // argument and silently never renders it.
            expect(
              _placeholderPattern(name).hasMatch(value),
              isTrue,
              reason:
                  '${file.path} drops {$name} from ${entry.key}, so its value '
                  'would never reach the user',
            );
          }
        }
      }
    });
  });
}

// Add keys here only when a translation pass is intentionally deferred.
const _knownUntranslatedDebt = <String>{
  // #6366: manual crossposting from the share sheet; translation deferred
  // to the next l10n pass.
  'shareSheetCrosspost',
  'crosspostSheetTitle',
  'crosspostSheetSubtitle',
  'crosspostSubmit',
  'crosspostStatusQueued',
  'crosspostStatusUploading',
  'crosspostStatusProcessing',
  'crosspostStatusPosted',
  'crosspostStatusFailed',
  'crosspostStatusSkipped',
  'crosspostStatusNeedsReauth',
  'crosspostViewPost',
  'crosspostReconnectPrompt',
  'crosspostReconnect',
  'crosspostErrorNotOwner',
  'crosspostErrorNotEligible',
  'crosspostErrorNotConnected',
  'crosspostErrorUnauthorized',
  'crosspostErrorNetwork',
  'crosspostFailedGeneric',
  'crosspostStillWorking',
  'crosspostDone',
  // #6217: light-mode experiment copy; translation deferred until rollout.
  // #6126: opt-in username-burn strings; translation deferred to the l10n pass.
  'deleteAccountBurnUsernameFailed',
  'deleteAccountBurnUsernameReleased',
  'deleteAccountBurnUsernameToggle',
  'deleteAccountDeletionIncomplete',
  // #6137: identity + username-confirmation strings; translation deferred.
  'deleteAccountAccountChanged',
  'deleteAccountConfirmDeletePrompt',
  'deleteAccountConfirmUsernamePrompt',
  'deleteAccountConfirmationHintUsername',
  // Added by community content-warning tagging (#4771). Existing locales
  // fall back to English until the next translation pass.
  'communitySuggestTitle',
  'communitySuggestSubtitle',
  'communitySuggestSubmit',
  'communitySuggestSuccess',
  'communitySuggestFailure',
  'communitySuggestAlready',
  'communitySuggestActionLabel',
  // Added by the in-app email-verification PIN fallback (#5578). The English
  // source ships now; the non-English locales fall back to English until the
  // next translation pass picks these up.
  'authVerificationPinPrompt',
  'authVerificationPinFieldLabel',
  'authVerificationPinSubmit',
  'authVerificationResendPrompt',
  'authVerificationResend',
  'authVerificationResendCooldown',
  'authVerificationResendFailed',
  'authVerificationErrorPinInvalid',
  'authVerificationErrorPinExpired',
  'authVerificationErrorPinLocked',
  'authVerificationErrorPinFailed',
  'authVerificationErrorPinUnavailable',
  // Crossposting settings strings; translation deferred to the next
  // l10n pass. Tracked in #6398.
  'settingsCrosspostingTitle',
  'settingsCrosspostingSubtitle',
  'crosspostingSignInRequired',
  'crosspostingLoadFailed',
  'crosspostingNoPlatforms',
  'crosspostingRetry',
  'crosspostingNotConnected',
  'crosspostingConnected',
  'crosspostingNeedsReconnect',
  'crosspostingConnect',
  'crosspostingReconnect',
  'crosspostingDisconnect',
  'crosspostingModeOff',
  'crosspostingModeManual',
  'crosspostingModeManualSubtitle',
  'crosspostingModeAutomatic',
  'crosspostingModeAutomaticSubtitle',
  'crosspostingNotConnectedError',
  'crosspostingGenericError',
  'crosspostingCallbackTimeoutError',
  'crosspostingConnectionSuccess',
  'crosspostingConnectionFailed',
  'crosspostingConnectionDenied',
  // #6413: supporter subscription screen copy; translation deferred to the
  // next l10n pass. Non-English locales fall back to English.
  'supporterTitle',
  'supporterTileSubtitle',
  'supporterHeroTitle',
  'supporterHeroBody',
  'supporterActiveBadge',
  'supporterPurchasePending',
  'supporterPurchaseConfirming',
  'supporterStoreChecking',
  'supporterUnavailable',
  'supporterRestorePurchases',
  'supporterDismissError',
  'supporterErrorStoreUnavailable',
  'supporterErrorPurchaseFailed',
  'supporterErrorPurchasePending',
  'supporterErrorRestoreFailed',
  'supporterErrorOwnershipConflict',
  'supporterErrorVerificationUnavailable',
  'supporterErrorUnknown',
  'supporterDisclaimer',
};

const _signatureVerificationKeys = <String>{
  'nostrSettingsSignatureVerification',
  'nostrSettingsSignatureVerificationIntro',
  'nostrSettingsSignatureVerificationAll',
  'nostrSettingsSignatureVerificationAllSubtitle',
  'nostrSettingsSignatureVerificationUntrusted',
  'nostrSettingsSignatureVerificationUntrustedSubtitle',
  'nostrSettingsSignatureVerificationNonDivine',
  'nostrSettingsSignatureVerificationNonDivineSubtitle',
};

Map<String, Object?> _readArb(File file) {
  return (jsonDecode(file.readAsStringSync()) as Map).cast<String, Object?>();
}

Set<String> _messageKeys(Map<String, Object?> arb) {
  return arb.keys.where((key) => !key.startsWith('@')).toSet();
}

Set<String> _declaredPlaceholders(Map<String, Object?> arb, String key) {
  final metadata = arb['@$key'];
  if (metadata is! Map) return const {};
  final placeholders = metadata['placeholders'];
  if (placeholders is! Map) return const {};
  return placeholders.keys.map((name) => name.toString()).toSet();
}

RegExp _placeholderPattern(String name) {
  return RegExp(r'\{\s*' + RegExp.escape(name) + r'\s*\}');
}
