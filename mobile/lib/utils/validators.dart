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

/// Why an email address failed validation.
///
/// The enum forms exist so a bloc can hold a validation outcome in state
/// without holding a localized string (see `state_management.md`); the
/// `validate*` string forms below map the same outcomes for screens that own
/// their own field errors.
enum EmailValidationError { missing, invalid }

/// Why a password failed validation.
enum PasswordValidationError { missing, tooShort }

/// Why a password confirmation failed validation.
enum ConfirmPasswordValidationError { missing, mismatch }

class Validators {
  static String normalizeAuthEmail(String value) => value.trim().toLowerCase();

  static String? validateEmail(
    String? value, {
    required AuthValidationMessages messages,
  }) => switch (emailError(value)) {
    EmailValidationError.missing => messages.emailRequired,
    EmailValidationError.invalid => messages.invalidEmail,
    null => null,
  };

  static EmailValidationError? emailError(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) {
      return EmailValidationError.missing;
    }

    final parts = email.split('@');
    if (parts.length != 2) {
      return EmailValidationError.invalid;
    }

    final localPart = parts[0];
    final domain = parts[1];
    if (localPart.isEmpty ||
        domain.isEmpty ||
        localPart.startsWith('.') ||
        localPart.endsWith('.') ||
        localPart.contains('..') ||
        domain.contains('..')) {
      return EmailValidationError.invalid;
    }

    final domainLabels = domain.split('.');
    if (domainLabels.length < 2 ||
        domainLabels.any(
          (label) =>
              label.isEmpty || label.startsWith('-') || label.endsWith('-'),
        ) ||
        domainLabels.last.length < 2) {
      return EmailValidationError.invalid;
    }

    final emailRegex = RegExp(
      r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@"
      '[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?'
      r'(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return EmailValidationError.invalid;
    }
    return null;
  }

  static String? validatePassword(
    String? value, {
    required AuthValidationMessages messages,
  }) => switch (passwordError(value)) {
    PasswordValidationError.missing => messages.passwordRequired,
    PasswordValidationError.tooShort => messages.passwordTooShort,
    null => null,
  };

  static PasswordValidationError? passwordError(String? value) {
    // Note: passwords are intentionally not trimmed — leading/trailing
    // whitespace is a legitimate part of a user's secret.
    if (value == null || value.isEmpty) {
      return PasswordValidationError.missing;
    }
    if (value.length < 8) {
      return PasswordValidationError.tooShort;
    }
    return null;
  }

  static String? validateConfirmPassword(
    String? value, {
    required String password,
    required AuthValidationMessages messages,
  }) => switch (confirmPasswordError(value, password: password)) {
    ConfirmPasswordValidationError.missing => messages.confirmPasswordRequired,
    ConfirmPasswordValidationError.mismatch => messages.passwordMismatch,
    null => null,
  };

  static ConfirmPasswordValidationError? confirmPasswordError(
    String? value, {
    required String password,
  }) {
    if (value == null || value.isEmpty) {
      return ConfirmPasswordValidationError.missing;
    }
    if (value != password) {
      return ConfirmPasswordValidationError.mismatch;
    }
    return null;
  }
}
