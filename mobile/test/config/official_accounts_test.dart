// ABOUTME: Tests for the pinned official-accounts config.
// ABOUTME: Pins the single-source contract between the moderation constants
// ABOUTME: here and ModerationLabelService's NIP-05 fallback.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/services/moderation_label_service.dart';

void main() {
  group('official accounts config', () {
    test('the moderation account is composed from the shared constants', () {
      expect(kModerationAccount.pubkeyHex, equals(kModerationPubkeyHex));
      expect(kModerationAccount.nip05, equals(kModerationNip05));
      expect(kModerationAccount.role, equals(OfficialAccountRole.moderation));
      expect(kPinnedOfficialAccounts, contains(kModerationAccount));
    });

    test('the HQ account is in the pinned set', () {
      expect(kHqAccount.role, equals(OfficialAccountRole.hq));
      expect(kPinnedOfficialAccounts, contains(kHqAccount));
    });

    // These were declared twice, byte for byte, before #6388. A second copy
    // drifting on the next rotation would point the labeler at one key and the
    // support row + protected-minor gate at another.
    test('ModerationLabelService forwards the config moderation pubkey', () {
      expect(
        ModerationLabelService.fallbackModerationPubkeyHex,
        equals(kModerationPubkeyHex),
      );
    });

    test('ModerationLabelService forwards the config moderation NIP-05', () {
      expect(
        ModerationLabelService.divineModerationNip05,
        equals(kModerationNip05),
      );
    });

    group('isModerationAccount', () {
      test('accepts the current key', () {
        expect(isModerationAccount(kModerationPubkeyHex), isTrue);
      });

      test('accepts every retired key', () {
        expect(kLegacyModerationPubkeys, isNotEmpty);
        for (final retired in kLegacyModerationPubkeys) {
          expect(
            isModerationAccount(retired),
            isTrue,
            reason: 'retired key $retired must still resolve as moderation',
          );
        }
      });

      test('rejects an unrelated pubkey', () {
        expect(isModerationAccount(kHqAccount.pubkeyHex), isFalse);
      });
    });

    group('isRetiredModerationAccount', () {
      test('accepts every retired key', () {
        expect(kLegacyModerationPubkeys, isNotEmpty);
        for (final retired in kLegacyModerationPubkeys) {
          expect(
            isRetiredModerationAccount(retired),
            isTrue,
            reason: 'retired key $retired must be recognised as retired',
          );
        }
      });

      // The load-bearing half: this predicate closes the composer and refuses
      // the send. Answering true for the live key would silently take the
      // whole support lane offline.
      test('rejects the current key', () {
        expect(isRetiredModerationAccount(kModerationPubkeyHex), isFalse);
      });

      test('rejects an unrelated pubkey', () {
        expect(isRetiredModerationAccount(kHqAccount.pubkeyHex), isFalse);
      });
    });

    // A rotation that forgot to drop the old key from the retired list would
    // collapse the pin's known-id set to a single entry and silently stop
    // de-duplicating.
    test('no retired key is also the current key', () {
      expect(kLegacyModerationPubkeys, isNot(contains(kModerationPubkeyHex)));
    });

    group('profile checkmark pubkeys', () {
      // Lookups lowercase the profile's pubkey before testing membership, so
      // an entry pasted in mixed case matches nobody — no crash, no analyzer
      // complaint, just a team member who never gets the checkmark.
      final checkmarkPubkeys = {
        ...kDivineTeamPubkeys,
        ...kLegacyProfileCheckmarkPubkeys,
      };

      test('every entry is a 64-character lowercase hex pubkey', () {
        for (final pubkey in checkmarkPubkeys) {
          expect(
            pubkey,
            matches(RegExp(r'^[0-9a-f]{64}$')),
            reason: '$pubkey is not a lowercase hex pubkey',
          );
        }
      });

      test('the two sets do not overlap', () {
        expect(
          kDivineTeamPubkeys.intersection(kLegacyProfileCheckmarkPubkeys),
          isEmpty,
        );
      });

      // Sebastian and Rabble are on the team list and in the curation
      // constants. The two lists grant different things and are allowed to
      // diverge, so this only pins that the shared entries agree today —
      // catching a typo in one copy, not forbidding a future split.
      test('shared entries agree with the curation constants', () {
        for (final pubkey in AppConstants.divineTeamPubkeys) {
          expect(kDivineTeamPubkeys, contains(pubkey));
        }
      });
    });
  });
}
