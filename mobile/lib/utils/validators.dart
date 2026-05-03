import 'package:flutter/foundation.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Bundled error strings shown by [Validators]. Construct via
/// [AuthValidationMessages.fromL10n] in any code path that has a
/// [BuildContext]; only fall back to [englishDefaults] in tests or in
/// non-Flutter helpers where l10n is unavailable.
class AuthValidationMessages {
  const AuthValidationMessages({
    required this.emailRequired,
    required this.invalidEmail,
    required this.passwordRequired,
    required this.passwordTooShort,
    required this.confirmPasswordRequired,
    required this.passwordMismatch,
  });

  factory AuthValidationMessages.fromL10n(AppLocalizations l10n) {
    return AuthValidationMessages(
      emailRequired: l10n.authEmailRequired,
      invalidEmail: l10n.authEmailInvalid,
      passwordRequired: l10n.authPasswordRequired,
      passwordTooShort: l10n.authPasswordTooShort,
      confirmPasswordRequired: l10n.authConfirmPasswordRequired,
      passwordMismatch: l10n.authPasswordsDoNotMatch,
    );
  }

  /// English-only fallback. Intended for tests and non-Flutter helpers; do
  /// not use from screens or BLoCs that have access to localizations.
  @visibleForTesting
  static const englishDefaults = AuthValidationMessages(
    emailRequired: 'Email is required',
    invalidEmail: 'Please enter a valid email',
    passwordRequired: 'Password is required',
    passwordTooShort: 'Password must be at least 8 characters',
    confirmPasswordRequired: 'Please confirm your password',
    passwordMismatch: "Passwords don't match",
  );

  final String emailRequired;
  final String invalidEmail;
  final String passwordRequired;
  final String passwordTooShort;
  final String confirmPasswordRequired;
  final String passwordMismatch;
}

class Validators {
  static String? validateEmail(
    String? value, {
    required AuthValidationMessages messages,
  }) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return messages.emailRequired;
    }

    final parts = email.split('@');
    if (parts.length != 2) {
      return messages.invalidEmail;
    }

    final localPart = parts[0];
    final domain = parts[1];
    if (localPart.isEmpty ||
        domain.isEmpty ||
        localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..') ||
        domain.contains('..')) {
      return messages.invalidEmail;
    }

    final domainLabels = domain.split('.');
    if (domainLabels.length < 2 ||
        domainLabels.any(
          (label) =>
              label.isEmpty || label.startsWith('-') || label.endsWith('-'),
        ) ||
        domainLabels.last.length < 2) {
      return messages.invalidEmail;
    }

    final emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      '[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return messages.invalidEmail;
    }
    return null;
  }

  static String? validatePassword(
    String? value, {
    required AuthValidationMessages messages,
  }) {
    // Note: passwords are intentionally not trimmed — leading/trailing
    // whitespace is a legitimate part of a user's secret.
    if (value == null || value.isEmpty) {
      return messages.passwordRequired;
    }
    if (value.length < 8) {
      return messages.passwordTooShort;
    }
    return null;
  }

  static String? validateConfirmPassword(
    String? value, {
    required String password,
    required AuthValidationMessages messages,
  }) {
    if (value == null || value.isEmpty) {
      return messages.confirmPasswordRequired;
    }
    if (value != password) {
      return messages.passwordMismatch;
    }
    return null;
  }
}
