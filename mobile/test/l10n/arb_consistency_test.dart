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

    test('Keycast remote signing copy is localized for every locale', () {
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
      final source = template['keyManagementKeycastRemoteSigning'];

      for (final file in arbFiles) {
        final arb = _readArb(file);

        expect(
          arb['keyManagementKeycastRemoteSigning'],
          isNot(source),
          reason:
              '${file.path} must not fall back to English for Keycast remote signing copy',
        );
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
  });
}

// Every key in app_en.arb is currently translated in all non-English locales.
// Add keys here only when a translation pass is intentionally deferred.
const _knownUntranslatedDebt = <String>{};

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
