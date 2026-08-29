// ABOUTME: Tests the invite-gate reason-code -> localized-string mappings.

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/invite_gate/invite_gate_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/l10n/invite_gate_error_l10n.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('InviteGateErrorL10n', () {
    group('inviteCodeErrorMessage', () {
      test('maps every reason to a non-empty message', () {
        for (final error in InviteCodeError.values) {
          expect(
            l10n.inviteCodeErrorMessage(error),
            isNotEmpty,
            reason: 'no message for $error',
          );
        }
      });

      test('maps every reason to a distinct message', () {
        final messages = InviteCodeError.values
            .map(l10n.inviteCodeErrorMessage)
            .toList();
        expect(
          messages.toSet(),
          hasLength(messages.length),
          reason: 'two reasons resolve to the same copy',
        );
      });
    });

    group('inviteGateErrorMessage', () {
      test('maps every reason to a non-empty message', () {
        for (final error in InviteGateError.values) {
          expect(
            l10n.inviteGateErrorMessage(error),
            isNotEmpty,
            reason: 'no message for $error',
          );
        }
      });

      test('maps every reason to a distinct message', () {
        final messages = InviteGateError.values
            .map(l10n.inviteGateErrorMessage)
            .toList();
        expect(
          messages.toSet(),
          hasLength(messages.length),
          reason: 'two reasons resolve to the same copy',
        );
      });

      // InviteGateError.unknown is the only thing an inbound `?error=` link
      // can produce, so its copy must say nothing specific about the cause —
      // if it ever tried to, that would be the injection returning.
      test('unknown reads as a generic retry prompt', () {
        final message = l10n.inviteGateErrorMessage(InviteGateError.unknown);
        expect(message, isNotEmpty);
        for (final specific in const [
          InviteGateError.creatorFull,
          InviteGateError.inviteUnavailable,
          InviteGateError.checkFailed,
        ]) {
          expect(message, isNot(l10n.inviteGateErrorMessage(specific)));
        }
      });
    });

    test('every reason is localized per locale', () {
      final de = lookupAppLocalizations(const Locale('de'));
      for (final error in InviteCodeError.values) {
        expect(
          de.inviteCodeErrorMessage(error),
          isNot(l10n.inviteCodeErrorMessage(error)),
          reason: '$error is not translated for de',
        );
      }
      for (final error in InviteGateError.values) {
        expect(
          de.inviteGateErrorMessage(error),
          isNot(l10n.inviteGateErrorMessage(error)),
          reason: '$error is not translated for de',
        );
      }
    });
  });
}
